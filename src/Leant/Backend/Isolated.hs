-- | A command-local pair of independent Lean backends restored from one
-- environment artifact.  This module deliberately owns the complete worker
-- lifetime: callers can lease a worker, but cannot extract or share its
-- underlying 'Backend'.
module Leant.Backend.Isolated
  ( IsolatedBackendPair
  , IsolatedBackendLease
  , IsolatedBackendFailure (..)
  , IsolatedBackendTransportFailure (..)
  , withIsolatedBackendPair
  , withIsolatedBackendLease
  , runIsolatedBackendCommand
  ) where

import Control.Concurrent (forkIOWithUnmask)
import Control.Concurrent.Async (cancel, wait, withAsync)
import Control.Concurrent.MVar
  ( MVar
  , newEmptyMVar
  , newMVar
  , putMVar
  , readMVar
  , withMVar
  )
import Control.Concurrent.STM
  ( STM
  , TVar
  , atomically
  , newTVar
  , readTVar
  , retry
  , writeTVar
  )
import Control.Exception
  ( IOException
  , SomeException
  , mask
  , onException
  , throwIO
  , try
  , uninterruptibleMask_
  )
import Data.Char (isSpace)
import Data.IORef
  ( IORef
  , atomicModifyIORef'
  , newIORef
  , readIORef
  )
import Data.List (sortOn)

import Leant.Backend
  ( Backend
  , BackendConfig
  , RequestError (..)
  , killBackend
  , request
  , spawnBackend
  )
import Leant.Json
  ( JValue (..)
  , jArray
  , jInt
  , jLookup
  , jString
  )

-- | A transport-level failure after a request entered a backend's protocol.
-- These failures retire that worker and poison the complete pair.
data IsolatedBackendTransportFailure
  = IsolatedBackendRequestTimeout
  | IsolatedBackendServerClosed String
  | IsolatedBackendBadResponse String
  | IsolatedBackendRequestInterrupted
  deriving (Eq, Show)

-- | Infrastructure failures are values.  Callback exceptions and unexpected
-- programmer exceptions are not converted to this type; the brackets finish
-- cleanup and then rethrow them.
data IsolatedBackendFailure
  = IsolatedBackendSpawnFailure Int String
  | IsolatedBackendSetupTransportFailure
      Int IsolatedBackendTransportFailure
  | IsolatedBackendSetupFatal Int String
  | IsolatedBackendSetupErrors Int [String]
  | IsolatedBackendSetupMissingEnvironment Int
  | IsolatedBackendRequestFailure IsolatedBackendTransportFailure
  | IsolatedBackendLeaseClosed
  | IsolatedBackendLeaseRetired IsolatedBackendTransportFailure
  | IsolatedBackendPairPoisoned IsolatedBackendTransportFailure
  | IsolatedBackendPairClosed
  | IsolatedBackendCleanupFailure
      (Maybe IsolatedBackendFailure) [String]
  deriving (Eq, Show)

-- | Exactly two workers and their private admission state.
data IsolatedBackendPair = IsolatedBackendPair
  { isolatedPairWorkers :: [IsolatedWorker]
  , isolatedPairState :: TVar IsolatedPairState
  , isolatedPairRequestTimeout :: Maybe Int
  }

-- | One checked-out worker.  Its constructor is hidden so it cannot be forged
-- or detached from the pair which owns it.
data IsolatedBackendLease = IsolatedBackendLease
  { isolatedLeasePair :: IsolatedBackendPair
  , isolatedLeaseWorker :: IsolatedWorker
  , isolatedLeaseActive :: TVar Bool
  }

data IsolatedWorker = IsolatedWorker
  { isolatedWorkerOrdinal :: !Int
  , isolatedWorkerBackend :: Backend
  , isolatedWorkerEnvironment :: !Integer
  , isolatedWorkerRequestLock :: MVar ()
  , isolatedWorkerRequestInFlight :: TVar Bool
  , isolatedWorkerRetired :: TVar
      (Maybe IsolatedBackendTransportFailure)
  }

data IsolatedPairState = IsolatedPairState
  { isolatedPairStatus :: IsolatedPairStatus
  , isolatedPairAvailable :: [IsolatedWorker]
  }

data IsolatedPairStatus
  = IsolatedPairHealthy
  | IsolatedPairPoisonedStatus IsolatedBackendTransportFailure
  | IsolatedPairClosedStatus

-- | Spawn and restore exactly two independent backends, run a callback, and
-- then kill and reap both workers (including workers still checked out by a
-- mis-scoped child thread).  A normal callback result is rejected when any
-- request poisoned the pair, even if the callback ignored that request's
-- 'Left'.
withIsolatedBackendPair
  :: BackendConfig
  -> FilePath
  -> Maybe Int
  -> (IsolatedBackendPair -> IO a)
  -> IO (Either IsolatedBackendFailure a)
withIsolatedBackendPair config artifact requestTimeout callback =
  mask $ \restore -> do
    -- Keep the ownership handoff masked: once acquisition returns a pair,
    -- this bracket must bind it before caller cancellation can be delivered.
    acquired <- acquireIsolatedBackendPair
      config artifact requestTimeout restore
    case acquired of
      Left failure -> pure $ Left failure
      Right pair -> do
        callbackResult <- tryAny $ restore $ callback pair
        cleanupResult <- tryAny $ closeIsolatedBackendPair pair
        case callbackResult of
          Left callbackFailure -> throwIO callbackFailure
          Right value -> case cleanupResult of
            Left cleanupException -> throwIO cleanupException
            Right (terminalStatus, cleanupFailures) ->
              pure $ attachCleanupFailures
                cleanupFailures $ case terminalStatus of
                IsolatedPairHealthy -> Right value
                IsolatedPairPoisonedStatus cause ->
                  Left $ IsolatedBackendPairPoisoned cause
                IsolatedPairClosedStatus ->
                  Left IsolatedBackendPairClosed

-- | Lease one worker for the whole callback.  At most two lease callbacks can
-- run simultaneously.  The worker is returned only while both it and the pair
-- remain healthy.
withIsolatedBackendLease
  :: IsolatedBackendPair
  -> (IsolatedBackendLease -> IO a)
  -> IO (Either IsolatedBackendFailure a)
withIsolatedBackendLease pair callback = mask $ \restore -> do
  -- A retrying STM checkout remains interruptible under 'mask', while a
  -- successful checkout cannot be interrupted before its release handler is
  -- installed.
  acquired <- atomically $ acquireLease pair
  case acquired of
    Left failure -> pure $ Left failure
    Right lease -> do
      callbackResult <- tryAny $ restore $ callback lease
      case callbackResult of
        Left callbackFailure -> do
          -- A failed callback may have left a child request behind.  Invalidate
          -- its token, returning an idle worker but retiring one whose request
          -- entered the protocol, then rethrow the primary exception.
          _ <- tryAny $ abortLease lease
          throwIO callbackFailure
        Right value -> do
          -- Invalidate before waiting: queued detached commands then fail
          -- admission, while one command which already passed admission may
          -- finish before this worker becomes available again.
          releaseResult <- tryAny $ releaseLease lease
          case releaseResult of
            Left releaseFailure -> throwIO releaseFailure
            Right () -> pure $ Right value

-- | Run a command in the environment restored into this worker.  Every
-- request contains exactly @cmd@ plus that process-local @env@.  Any @env@
-- returned in the response is deliberately ignored, so a lease remains on
-- its originally restored branch for its complete callback.
runIsolatedBackendCommand
  :: IsolatedBackendLease
  -> String
  -> IO (Either IsolatedBackendFailure JValue)
runIsolatedBackendCommand lease command =
  withMVar (isolatedWorkerRequestLock worker) $ \() ->
    mask $ \restore -> do
      admitted <- atomically $ requestAdmission lease
      case admitted of
        Left failure -> pure $ Left failure
        Right () -> do
          requested <- tryAny $ restore $ request
            (isolatedWorkerBackend worker)
            (isolatedPairRequestTimeout pair)
            (commandPayload
              (isolatedWorkerEnvironment worker) command)
          atomically $ writeTVar
            (isolatedWorkerRequestInFlight worker) False
          case requested of
            Left requestException -> do
              -- An async/programmer exception is primary.  Still poison and
              -- retire before rethrowing it, but never let a cleanup failure
              -- replace the exception which interrupted the request.
              _ <- tryAny $ retireWorker pair worker
                IsolatedBackendRequestInterrupted
              throwIO requestException
            Right (Right response) -> pure $ Right response
            Right (Left requestFailure) -> do
              let cause = transportFailure requestFailure
                  primary = IsolatedBackendRequestFailure cause
              cleanupFailure <- retireWorker pair worker cause
              pure $ case cleanupFailure of
                Nothing -> Left primary
                Just detail -> Left $ IsolatedBackendCleanupFailure
                  (Just primary) [detail]
 where
  pair = isolatedLeasePair lease
  worker = isolatedLeaseWorker lease

acquireIsolatedBackendPair
  :: BackendConfig
  -> FilePath
  -> Maybe Int
  -> ( IO (Either IsolatedBackendFailure IsolatedWorker)
       -> IO (Either IsolatedBackendFailure IsolatedWorker)
     )
  -> IO (Either IsolatedBackendFailure IsolatedBackendPair)
acquireIsolatedBackendPair config artifact requestTimeout restoreSetup = do
    -- The registry closes the ownership gap between each child's masked
    -- spawn handoff and this parent's ordered result handoff.  In particular,
    -- cancellation of the parent cannot strand a backend whose child had
    -- already finished (or whose setup was still in flight).
    registered <- newIORef []
    (withAsync
        (tryAny $ restoreSetup $ acquireWorker registered 1) $ \first ->
      withAsync
        (tryAny $ restoreSetup $ acquireWorker registered 2) $ \second -> do
        -- Both workers start concurrently, but observing worker one first
        -- preserves the old left-to-right failure contract.  A known
        -- worker-one failure cancels a possibly non-responsive sibling
        -- instead of waiting for an outcome which cannot replace it.
        firstResult <- wait first
        case firstResult of
          Left failure -> cancel second >> throwIO failure
          Right (Left failure) -> do
            cancel second
            registeredBackends registered
              >>= initializationFailure failure
          Right (Right firstWorker) -> do
            secondResult <- wait second
            backends <- registeredBackends registered
            case secondResult of
              Left failure -> throwIO failure
              Right (Left failure) ->
                initializationFailure failure backends
              Right (Right secondWorker) -> do
                state <- atomically $ newTVar IsolatedPairState
                  { isolatedPairStatus = IsolatedPairHealthy
                  , isolatedPairAvailable =
                      [firstWorker, secondWorker]
                  }
                pure $ Right IsolatedBackendPair
                  { isolatedPairWorkers =
                      [firstWorker, secondWorker]
                  , isolatedPairState = state
                  , isolatedPairRequestTimeout = requestTimeout
                  }) `onException`
                    cleanupRegisteredIgnoringFailures registered
 where
  acquireWorker registered ordinal = mask $ \restoreWorker -> do
    spawned <- tryIOException $ restoreWorker $ spawnBackend config
    case spawned of
      Left failure -> pure $ Left $ IsolatedBackendSpawnFailure ordinal
        $ show failure
      Right backend -> do
        -- Publish ownership while masked before setup becomes interruptible.
        atomicModifyIORef' registered $ \backends ->
          ((ordinal, backend) : backends, ())
        restoreWorker $ setupWorker ordinal backend artifact requestTimeout

  initializationFailure failure backends = do
    cleanupFailures <- cleanupBackendsUncancellable backends
    pure $ attachCleanupFailures cleanupFailures $ Left failure

registeredBackends :: IORef [(Int, Backend)] -> IO [(Int, Backend)]
registeredBackends registered = sortOn fst <$> readIORef registered

cleanupRegisteredIgnoringFailures :: IORef [(Int, Backend)] -> IO ()
cleanupRegisteredIgnoringFailures registered = do
  backends <- registeredBackends registered
  cleanupBackendsIgnoringFailures backends

setupWorker
  :: Int
  -> Backend
  -> FilePath
  -> Maybe Int
  -> IO (Either IsolatedBackendFailure IsolatedWorker)
setupWorker ordinal backend artifact requestTimeout = do
  restored <- request backend requestTimeout $ JObj
    [("unpickleEnvFrom", JStr artifact)]
  case restored of
    Left requestFailure -> pure $ Left
      $ IsolatedBackendSetupTransportFailure ordinal
      $ transportFailure requestFailure
    Right response
      | Just fatal <- responseFatal response ->
          pure $ Left $ IsolatedBackendSetupFatal ordinal $ trim fatal
      | not (null errors) ->
          pure $ Left $ IsolatedBackendSetupErrors ordinal errors
      | Just environment <- jLookup "env" response >>= jInt -> do
          requestLock <- newMVar ()
          (requestInFlight, retired) <- atomically $ (,)
            <$> newTVar False
            <*> newTVar Nothing
          pure $ Right IsolatedWorker
            { isolatedWorkerOrdinal = ordinal
            , isolatedWorkerBackend = backend
            , isolatedWorkerEnvironment = environment
            , isolatedWorkerRequestLock = requestLock
            , isolatedWorkerRequestInFlight = requestInFlight
            , isolatedWorkerRetired = retired
            }
      | otherwise -> pure $ Left
          $ IsolatedBackendSetupMissingEnvironment ordinal
     where
      errors = responseErrors response

commandPayload :: Integer -> String -> JValue
commandPayload environment command = JObj
  [ ("cmd", JStr command)
  , ("env", JInt environment)
  ]

responseFatal :: JValue -> Maybe String
responseFatal response = case jLookup "message" response of
  Just (JStr message)
    | Nothing <- jLookup "env" response -> Just message
  _ -> Nothing

responseErrors :: JValue -> [String]
responseErrors response =
  [ message
  | entry <- maybe [] id $ jLookup "messages" response >>= jArray
  , Just severity <- [jLookup "severity" entry >>= jString]
  , severity == "error"
  , Just message <- [jLookup "data" entry >>= jString]
  ]

acquireLease
  :: IsolatedBackendPair
  -> STM (Either IsolatedBackendFailure IsolatedBackendLease)
acquireLease pair = do
  state <- readTVar $ isolatedPairState pair
  case isolatedPairStatus state of
    IsolatedPairPoisonedStatus cause ->
      pure $ Left $ IsolatedBackendPairPoisoned cause
    IsolatedPairClosedStatus ->
      pure $ Left IsolatedBackendPairClosed
    IsolatedPairHealthy -> case isolatedPairAvailable state of
      [] -> retry
      worker : remaining -> do
        active <- newTVar True
        writeTVar (isolatedPairState pair) state
          { isolatedPairAvailable = remaining }
        pure $ Right IsolatedBackendLease
          { isolatedLeasePair = pair
          , isolatedLeaseWorker = worker
          , isolatedLeaseActive = active
          }

deactivateLease :: IsolatedBackendLease -> STM ()
deactivateLease lease =
  writeTVar (isolatedLeaseActive lease) False

returnLeaseWorker :: IsolatedBackendLease -> STM ()
returnLeaseWorker lease = do
  state <- readTVar $ isolatedPairState pair
  retired <- readTVar $ isolatedWorkerRetired worker
  case (isolatedPairStatus state, retired) of
    (IsolatedPairHealthy, Nothing) ->
      writeTVar (isolatedPairState pair) state
        { isolatedPairAvailable = worker
            : isolatedPairAvailable state }
    _ -> pure ()
 where
  pair = isolatedLeasePair lease
  worker = isolatedLeaseWorker lease

releaseLease :: IsolatedBackendLease -> IO ()
releaseLease lease = mask $ \_ -> do
  atomically $ deactivateLease lease
  synchronized <- tryAny $ withMVar requestLock $ \() ->
    atomically $ returnLeaseWorker lease
  case synchronized of
    Right () -> pure ()
    Left releaseFailure -> do
      -- Failure while performing a normal release is fail-stop.  It is not a
      -- callback failure: even if the request holder has just cleared its
      -- in-flight flag, the failed handoff must never make this worker
      -- available again.  Retire and kill it through an uncancellable owner,
      -- then preserve the release exception as primary.
      _ <- tryAny $ retireWorkerUncancellable pair worker
        IsolatedBackendRequestInterrupted
      throwIO releaseFailure
 where
  pair = isolatedLeasePair lease
  worker = isolatedLeaseWorker lease
  requestLock = isolatedWorkerRequestLock worker

abortLease :: IsolatedBackendLease -> IO ()
abortLease lease = mask $ \_ -> do
  requestInFlight <- atomically $ do
    deactivateLease lease
    readTVar $ isolatedWorkerRequestInFlight worker
  if requestInFlight
    then do
      _ <- retireWorker pair worker IsolatedBackendRequestInterrupted
      pure ()
    else do
      -- The atomic observation proves that no protocol request is active.
      -- A lock holder can therefore only be in the finite masked tail after
      -- admission/response; finish that handoff without manufacturing a
      -- transport interruption from a second cancellation.
      _ <- tryAny $ uninterruptibleMask_ $ withMVar requestLock $ \() ->
        atomically $ returnLeaseWorker lease
      pure ()
 where
  pair = isolatedLeasePair lease
  worker = isolatedLeaseWorker lease
  requestLock = isolatedWorkerRequestLock worker

requestAdmission
  :: IsolatedBackendLease
  -> STM (Either IsolatedBackendFailure ())
requestAdmission lease = do
  state <- readTVar $ isolatedPairState pair
  retired <- readTVar $ isolatedWorkerRetired worker
  active <- readTVar $ isolatedLeaseActive lease
  case (isolatedPairStatus state, active, retired) of
    (IsolatedPairClosedStatus, _, _) ->
      pure $ Left IsolatedBackendPairClosed
    (_, False, _) ->
      pure $ Left IsolatedBackendLeaseClosed
    (_, _, Just cause) ->
      pure $ Left $ IsolatedBackendLeaseRetired cause
    _ -> do
      writeTVar (isolatedWorkerRequestInFlight worker) True
      pure $ Right ()
 where
  pair = isolatedLeasePair lease
  worker = isolatedLeaseWorker lease

retireWorker
  :: IsolatedBackendPair
  -> IsolatedWorker
  -> IsolatedBackendTransportFailure
  -> IO (Maybe String)
retireWorker pair worker cause = do
  atomically $ markWorkerRetired pair worker cause
  killed <- tryIOException $ killBackend
    $ isolatedWorkerBackend worker
  pure $ case killed of
    Left failure -> Just $ workerLabel worker ++ ": " ++ show failure
    Right () -> Nothing

-- A failed normal-release handoff must finish retirement even when its cause
-- was caller cancellation.  The state transition happens before starting the
-- bounded independent cleanup owner, and waiting for that owner cannot itself
-- be interrupted.
retireWorkerUncancellable
  :: IsolatedBackendPair
  -> IsolatedWorker
  -> IsolatedBackendTransportFailure
  -> IO (Maybe String)
retireWorkerUncancellable pair worker cause = mask $ \_ -> do
  atomically $ markWorkerRetired pair worker cause
  cleanupFailures <- cleanupBackendsUncancellable
    [ ( isolatedWorkerOrdinal worker
      , isolatedWorkerBackend worker
      )
    ]
  pure $ case cleanupFailures of
    [] -> Nothing
    failure : _ -> Just failure

markWorkerRetired
  :: IsolatedBackendPair
  -> IsolatedWorker
  -> IsolatedBackendTransportFailure
  -> STM ()
markWorkerRetired pair worker cause = do
  writeTVar (isolatedWorkerRetired worker) $ Just cause
  state <- readTVar $ isolatedPairState pair
  case isolatedPairStatus state of
    IsolatedPairHealthy -> writeTVar
      (isolatedPairState pair) state
        { isolatedPairStatus = IsolatedPairPoisonedStatus cause
        , isolatedPairAvailable = []
        }
    _ -> pure ()

closeIsolatedBackendPair
  :: IsolatedBackendPair
  -> IO (IsolatedPairStatus, [String])
closeIsolatedBackendPair pair = mask $ \_ -> do
  terminalStatus <- atomically $ do
    state <- readTVar $ isolatedPairState pair
    writeTVar (isolatedPairState pair) state
      { isolatedPairStatus = IsolatedPairClosedStatus
      , isolatedPairAvailable = []
      }
    pure $ isolatedPairStatus state
  cleanupFailures <- cleanupBackendsUncancellable
    [ ( isolatedWorkerOrdinal worker
      , isolatedWorkerBackend worker
      )
    | worker <- isolatedPairWorkers pair
    ]
  pure (terminalStatus, cleanupFailures)

cleanupBackends :: [(Int, Backend)] -> IO [String]
cleanupBackends = go []
 where
  go failures [] = pure $ reverse failures
  go failures ((ordinal, backend) : remaining) = do
    cleaned <- tryIOException $ killBackend backend
    let failures' = case cleaned of
          Left failure ->
            ("worker " ++ show ordinal ++ ": " ++ show failure)
              : failures
          Right () -> failures
    go failures' remaining

cleanupBackendsIgnoringFailures :: [(Int, Backend)] -> IO ()
cleanupBackendsIgnoringFailures backends = do
  -- This runs only while preserving a primary exception from setup/spawn.
  -- Teardown is still attempted to completion, but that primary exception
  -- must be the one rethrown by 'onException'.
  _ <- tryAny $ cleanupBackendsUncancellable backends
  pure ()

-- Run the bounded backend lifecycle code in an independent unmasked thread.
-- The caller waits uninterruptibly only for that bounded owner, so caller
-- cancellation cannot skip a later worker while the lifecycle's own
-- 'timeout' operations remain effective.
cleanupBackendsUncancellable :: [(Int, Backend)] -> IO [String]
cleanupBackendsUncancellable backends = mask $ \_ -> do
  done <- newEmptyMVar
  _ <- forkIOWithUnmask $ \unmask -> do
    cleaned <- tryAny $ unmask $ cleanupBackends backends
    putMVar done cleaned
  result <- uninterruptibleMask_ $ readMVar done
  either throwIO pure result

attachCleanupFailures
  :: [String]
  -> Either IsolatedBackendFailure a
  -> Either IsolatedBackendFailure a
attachCleanupFailures [] result = result
attachCleanupFailures failures result = Left
  $ IsolatedBackendCleanupFailure (either Just (const Nothing) result)
  failures

transportFailure
  :: RequestError
  -> IsolatedBackendTransportFailure
transportFailure RequestTimeout = IsolatedBackendRequestTimeout
transportFailure (ServerClosed diagnostic) =
  IsolatedBackendServerClosed diagnostic
transportFailure (BadResponse diagnostic) =
  IsolatedBackendBadResponse diagnostic

workerLabel :: IsolatedWorker -> String
workerLabel worker = "worker " ++ show (isolatedWorkerOrdinal worker)

trim :: String -> String
trim = reverse . dropWhile isSpace . reverse . dropWhile isSpace

tryAny :: IO a -> IO (Either SomeException a)
tryAny = try

tryIOException :: IO a -> IO (Either IOException a)
tryIOException = try
