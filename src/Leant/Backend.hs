{-# LANGUAGE CPP #-}

-- | Lean REPL backend process management: discovery of the repl executable,
-- spawning under @lake env@, and the JSON-over-stdio request cycle.
--
-- This ports the relevant parts of LeanInteract's server module: requests are
-- one JSON document followed by a blank line; responses are read until the
-- blank-line delimiter.
module Leant.Backend
  ( Backend
  , BackendConfig (..)
  , discoverReplExe
  , findBackendProject
  , findProject
  , isBuiltProject
  , spawnBackend
  , killBackend
  , request
  , RequestError (..)
  ) where

import Control.Concurrent
  ( ThreadId
  , forkIO
  , forkIOWithUnmask
  , killThread
  )
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , modifyMVar_
  , newEmptyMVar
  , newMVar
  , putMVar
  , readMVar
  )
import Control.Exception
  ( IOException
  , SomeException
  , finally
  , mask
  , mask_
  , onException
  , throwIO
  , try
  )
import Control.Monad (filterM, forM)
import qualified Data.ByteString as ByteString
import Data.List (sortOn)
import Data.Maybe (catMaybes, listToMaybe)
import Data.Ord (Down (..))
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import System.Directory
  ( canonicalizePath
  , doesDirectoryExist
  , doesFileExist
  , getCurrentDirectory
  , listDirectory
  , makeAbsolute
  )
import System.Environment (lookupEnv)
import System.Exit (ExitCode)
import System.FilePath ((</>), takeDirectory)
import System.IO
  ( BufferMode (..)
  , Handle
  , hClose
  , hFlush
  , hGetLine
  , hPutStr
  , hSetBinaryMode
  , hSetBuffering
  , hSetEncoding
  , hSetNewlineMode
  , universalNewlineMode
  , utf8
  )
import System.IO.Error (isDoesNotExistError, tryIOError)
import System.Process
  ( CreateProcess (..)
  , Pid
  , ProcessHandle
  , StdStream (..)
  , createProcess
  , getPid
  , proc
  , terminateProcess
  )
import System.Timeout (timeout)

#ifdef mingw32_HOST_OS
import System.Process (waitForProcess)
#else
import Control.Concurrent (threadDelay)
import Control.Exception (uninterruptibleMask_)
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
import System.Process (getProcessExitCode)
#endif

#ifndef mingw32_HOST_OS
import System.Posix.Signals
  ( Signal
  , nullSignal
  , sigKILL
  , sigTERM
  , signalProcessGroup
  )
#endif

import Leant.Json (JValue, encodeJson, parseJson)

-- | How to spawn the Lean REPL: the @lake@ executable, the repl executable
-- to run under @lake env@, and the project directory to run it in.
data BackendConfig = BackendConfig
  { bcLakePath :: FilePath
  , bcReplExe :: FilePath
  , bcWorkingDir :: FilePath
  }
  deriving (Show)

-- | One running Lean REPL process: its stdio handles, its process handle,
-- and the bounded stderr capture thread whose tail is reported when the
-- backend dies.
data Backend = Backend
  { beIn :: Handle
  , beOut :: Handle
  , beErr :: Handle
  , beProc :: ProcessHandle
  , beProcessGroupIdentifier :: Maybe Integer
  , beErrCapture :: MVar CapturedStderr
  , beErrDone :: MVar ()
  , beErrThread :: ThreadId
  , beCleanupState :: MVar BackendCleanupState
  }

data BackendCleanupState
  = BackendCleanupNotStarted
  | BackendCleanupRunning (MVar (Either SomeException ()))

data CapturedStderr = CapturedStderr
  { capturedStderrTruncated :: !Bool
  , capturedStderrBytes :: !ByteString.ByteString
  }

-- | Why one JSON request to the backend produced no usable response.
data RequestError
  = ServerClosed String   -- ^ backend died; payload is its bounded stderr tail
  | RequestTimeout
  | BadResponse String
  deriving (Show)

-- Discovery -----------------------------------------------------------------

-- | Locate a repl executable from a LeanInteract cache on this machine, or
-- honor the LEANT_BACKEND environment variable.
--
-- The cache layout is
--   <site-packages>/lean_interact/cache/<owner>/repl/<rev>/.lake/build/bin/repl.exe
discoverReplExe :: IO (Maybe FilePath)
discoverReplExe = do
  fromEnv <- lookupEnv "LEANT_BACKEND"
  case fromEnv of
    Just path -> do
      exists <- doesFileExist path
      pure (if exists then Just path else Nothing)
    Nothing -> do
      localAppData <- lookupEnv "LOCALAPPDATA"
      case localAppData of
        Nothing -> pure Nothing
        Just lad -> do
          let pythons = lad </> "Python"
          versions <- listDirIfExists pythons
          caches <- forM versions $ \v -> do
            let cache = pythons </> v </> "Lib" </> "site-packages"
                  </> "lean_interact" </> "cache"
            ok <- doesDirectoryExist cache
            pure (if ok then Just cache else Nothing)
          candidates <- concat <$> mapM replBinariesUnder (catMaybes caches)
          -- prefer newest toolchains (directory names embed the version)
          pure (listToMaybe (sortOn Down candidates))
 where
  listDirIfExists dir = do
    ok <- doesDirectoryExist dir
    if ok then listDirectory dir else pure []

  replBinariesUnder cache = do
    owners <- listSubdirs cache
    fmap concat . forM owners $ \owner -> do
      let replRoot = owner </> "repl"
      revs <- listSubdirs replRoot
      filterM doesFileExist (map binaryIn revs)

  binaryIn rev = rev </> ".lake" </> "build" </> "bin" </> "repl.exe"

  listSubdirs dir = do
    ok <- doesDirectoryExist dir
    if not ok
      then pure []
      else do
        entries <- listDirectory dir
        filterM doesDirectoryExist (map (dir </>) entries)

-- | Locate the Lake project which built a REPL executable. LeanInteract cache
-- roots vary between platforms and can insert additional project directories,
-- so derive this from the nearest real lakefile rather than a fixed number of
-- parent traversals from @.lake/build/bin/repl@.
findBackendProject :: FilePath -> IO (Maybe FilePath)
findBackendProject executable = do
  absolute <- makeAbsolute executable
  exists <- doesFileExist absolute
  resolved <- if exists then canonicalizePath absolute else pure absolute
  listToMaybe <$> filterM hasLakefile
    (ancestorDirectories $ takeDirectory resolved)

-- | Nearest enclosing Lake project that has been built, falling back to the
-- nearest project of any kind.
findProject :: IO (Maybe FilePath)
findProject = do
  currentDirectory <- getCurrentDirectory
  candidates <- filterM hasLakefile (ancestorDirectories currentDirectory)
  built <- filterM isBuiltProject candidates
  pure (listToMaybe built `orElse` listToMaybe candidates)
 where
  orElse (Just x) _ = Just x
  orElse Nothing y = y

ancestorDirectories :: FilePath -> [FilePath]
ancestorDirectories dir =
  dir : if parent == dir then [] else ancestorDirectories parent
 where
  parent = takeDirectory dir

hasLakefile :: FilePath -> IO Bool
hasLakefile dir = do
  toml <- doesFileExist (dir </> "lakefile.toml")
  lean <- doesFileExist (dir </> "lakefile.lean")
  pure (toml || lean)

-- | Whether a Lake project has already been built (its .lake build
-- library directory exists), so imports will resolve without a fresh
-- lake build.
isBuiltProject :: FilePath -> IO Bool
isBuiltProject dir =
  doesDirectoryExist (dir </> ".lake" </> "build" </> "lib" </> "lean")

-- Process lifecycle ---------------------------------------------------------

-- | Launch the Lean REPL backend under lake env with piped handles and
-- a dedicated stderr-capture thread.  Exceptions during startup tear the
-- partially created process down before propagating.
spawnBackend :: BackendConfig -> IO Backend
spawnBackend config = mask $ \restore -> do
  created <- createProcess
    (proc (bcLakePath config) ["env", bcReplExe config])
      { cwd = Just (bcWorkingDir config)
      , std_in = CreatePipe
      , std_out = CreatePipe
      , std_err = CreatePipe
      , create_group = True
      , use_process_jobs = True
      }
  let (_, _, _, process) = created
  processGroupIdentifier <- captureProcessGroupIdentifier process
  case processGroupIdentifier of
    Nothing -> do
      let (maybeIn, maybeOut, maybeErr, ph) = created
      cleanupIncompleteProcess maybeIn maybeOut maybeErr ph Nothing
      ioError $ userError
        "backend process did not expose its owned process-group identifier"
    Just _ -> case created of
      (Just hIn, Just hOut, Just hErr, ph) ->
        finish restore hIn hOut hErr ph processGroupIdentifier
          `onException` cleanupCreatedProcess hIn hOut hErr ph
            processGroupIdentifier
      (maybeIn, maybeOut, maybeErr, ph) -> do
        cleanupIncompleteProcess maybeIn maybeOut maybeErr ph
          processGroupIdentifier
        ioError $ userError "backend process did not create all three pipes"
 where
  finish restore hIn hOut hErr ph processGroupIdentifier = do
    _ <- restore $ do
      mapM_ prepareText [hIn, hOut]
      hSetBinaryMode hErr True
      hSetBuffering hErr NoBuffering
    capture <- newMVar $ CapturedStderr False ByteString.empty
    done <- newEmptyMVar
    cleanupState <- newMVar BackendCleanupNotStarted
    drainThread <- forkIOWithUnmask $ \unmask ->
      unmask (captureStderr hErr capture) `finally` putMVar done ()
    pure Backend
      { beIn = hIn
      , beOut = hOut
      , beErr = hErr
      , beProc = ph
      , beProcessGroupIdentifier = processGroupIdentifier
      , beErrCapture = capture
      , beErrDone = done
      , beErrThread = drainThread
      , beCleanupState = cleanupState
      }

  prepareText h = do
    hSetEncoding h utf8
    hSetNewlineMode h universalNewlineMode
    hSetBuffering h LineBuffering

cleanupCreatedProcess
  :: Handle
  -> Handle
  -> Handle
  -> ProcessHandle
  -> Maybe Integer
  -> IO ()
cleanupCreatedProcess hIn hOut hErr process processGroupIdentifier = do
  runCleanupActionsPreservingFirstFailure
    [ terminateProcessTree process processGroupIdentifier
    , closeQuietly hIn
    , closeQuietly hOut
    , closeQuietly hErr
    ]

cleanupIncompleteProcess
  :: Maybe Handle
  -> Maybe Handle
  -> Maybe Handle
  -> ProcessHandle
  -> Maybe Integer
  -> IO ()
cleanupIncompleteProcess maybeIn maybeOut maybeErr process
    processGroupIdentifier = do
  runCleanupActionsPreservingFirstFailure
    $ terminateProcessTree process processGroupIdentifier
    : map closeQuietly (catMaybes [maybeIn, maybeOut, maybeErr])

captureProcessGroupIdentifier :: ProcessHandle -> IO (Maybe Integer)
captureProcessGroupIdentifier process = do
  captured <- tryIOError $ getPid process
  pure $ case captured of
    Right (Just pid) -> Just $ toInteger (pid :: Pid)
    _ -> Nothing

-- | Terminate the complete process tree without ever addressing the caller's
-- process group.  POSIX children are born as leaders of a dedicated group,
-- whose identifier is captured before startup can return.  Keeping the direct
-- wrapper unreaped until after group escalation also prevents its numeric PID
-- from being reused while it is still being used as the group address.
-- Windows' @use_process_jobs@ makes 'terminateProcess' operate on the Job; its
-- matching bounded 'waitForProcess' observes all processes in that Job.
terminateProcessTree :: ProcessHandle -> Maybe Integer -> IO ()
terminateProcessTree process processGroupIdentifier =
#ifdef mingw32_HOST_OS
  mask_ $ do
    -- TerminateJobObject kills the whole Job; waitForProcess then waits for
    -- Job completion, rather than merely observing the already-exited wrapper.
    processGroupIdentifier `seq` pure ()
    terminateDirectProcess process
    waited <- boundedWaitForJobProcess
      process processReapWaitMicroseconds
    case waited of
      Just _ -> pure ()
      Nothing -> do
        terminateDirectProcess process
        waitedAgain <- boundedWaitForJobProcess
          process processReapWaitMicroseconds
        case waitedAgain of
          Just _ -> pure ()
          Nothing -> ioError $ userError
            "backend process Job did not complete after termination"
#else
  uninterruptibleMask_ $ do
    case processGroupIdentifier of
      Nothing -> do
        terminateDirectProcess process
        requireDirectProcessReaped process
      Just identifier -> do
        termResult <- signalOwnedProcessGroup sigTERM identifier
        case termResult of
          OwnedProcessGroupGone -> requireDirectProcessReaped process
          OwnedProcessGroupSignalled -> do
            groupGone <- waitForOwnedProcessGroup
              identifier processTerminationGraceMicroseconds
            if groupGone
              then requireDirectProcessReaped process
              else do
                killResult <- signalOwnedProcessGroup sigKILL identifier
                requireDirectProcessReaped process
                case killResult of
                  OwnedProcessGroupGone -> pure ()
                  OwnedProcessGroupSignalled -> do
                    killedGroupGone <- waitForOwnedProcessGroup identifier
                      processGroupKillWaitMicroseconds
                    if killedGroupGone
                      then pure ()
                      else ioError $ userError
                        "backend process group remained after SIGKILL"
#endif

terminateDirectProcess :: ProcessHandle -> IO ()
terminateDirectProcess process = do
  attempted <- tryIOError $ terminateProcess process
  case attempted of
    Right () -> pure ()
    Left failure
      | isDoesNotExistError failure -> pure ()
      | otherwise -> ioError failure

#ifndef mingw32_HOST_OS
requireDirectProcessReaped :: ProcessHandle -> IO ()
requireDirectProcessReaped process = do
  reaped <- boundedReapDirectProcess process processReapWaitMicroseconds
  case reaped of
    Just _ -> pure ()
    Nothing -> do
      terminateDirectProcess process
      reapedAfterFallback <- boundedReapDirectProcess
        process processReapWaitMicroseconds
      case reapedAfterFallback of
        Just _ -> pure ()
        Nothing -> ioError $ userError
          "backend wrapper did not exit after process-tree termination"

boundedReapDirectProcess
  :: ProcessHandle -> Int -> IO (Maybe ExitCode)
boundedReapDirectProcess process microseconds = do
  started <- getMonotonicTimeNSec
  let deadline = toInteger started + toInteger microseconds * 1000
  go deadline
 where
  go deadline = do
    observed <- getProcessExitCode process
    case observed of
      Just status -> pure $ Just status
      Nothing -> do
        now <- getMonotonicTimeNSec
        if toInteger now >= deadline
          then pure Nothing
          else do
            threadDelay $ boundedPollingDelay deadline now
            go deadline

boundedPollingDelay :: Integer -> Word64 -> Int
boundedPollingDelay deadline now = fromInteger
  $ max 1 $ min processPollingMicroseconds
  $ (deadline - toInteger now + 999) `div` 1000
#endif

#ifdef mingw32_HOST_OS
boundedWaitForJobProcess
  :: ProcessHandle -> Int -> IO (Maybe ExitCode)
boundedWaitForJobProcess process microseconds =
  timeout microseconds $ waitForProcess process
#endif

#ifndef mingw32_HOST_OS
data OwnedProcessGroupSignalResult
  = OwnedProcessGroupSignalled
  | OwnedProcessGroupGone

signalOwnedProcessGroup
  :: Signal -> Integer -> IO OwnedProcessGroupSignalResult
signalOwnedProcessGroup signal identifier = do
  signalled <- tryIOError $ signalProcessGroup signal $ fromInteger identifier
  case signalled of
    Right () -> pure OwnedProcessGroupSignalled
    Left failure
      | isDoesNotExistError failure -> pure OwnedProcessGroupGone
      | otherwise -> ioError failure

waitForOwnedProcessGroup :: Integer -> Int -> IO Bool
waitForOwnedProcessGroup identifier microseconds = do
  started <- getMonotonicTimeNSec
  let deadline = toInteger started + toInteger microseconds * 1000
  go deadline
 where
  go deadline = do
    observation <- signalOwnedProcessGroup nullSignal identifier
    case observation of
      OwnedProcessGroupGone -> pure True
      OwnedProcessGroupSignalled -> do
        now <- getMonotonicTimeNSec
        if toInteger now >= deadline
          then pure False
          else do
            threadDelay $ boundedPollingDelay deadline now
            go deadline
#endif

#ifndef mingw32_HOST_OS
processTerminationGraceMicroseconds :: Int
processTerminationGraceMicroseconds = 200000

processGroupKillWaitMicroseconds :: Int
processGroupKillWaitMicroseconds = 500000
#endif

processReapWaitMicroseconds :: Int
processReapWaitMicroseconds = 500000

#ifndef mingw32_HOST_OS
processPollingMicroseconds :: Integer
processPollingMicroseconds = 5000
#endif

closeQuietly :: Handle -> IO ()
closeQuietly handle = do
  _ <- try (hClose handle) :: IO (Either IOException ())
  pure ()

-- | Shut the backend down: close stdin, terminate and reap the process,
-- give the stderr-capture thread a bounded window to finish, then close
-- the remaining handles.
killBackend :: Backend -> IO ()
killBackend backend = mask_ $ do
  completion <- modifyMVar (beCleanupState backend) $ \state -> case state of
    BackendCleanupNotStarted -> do
      done <- newEmptyMVar
      _ <- forkIO $ do
        attempted <- try (cleanupBackend backend)
          :: IO (Either SomeException ())
        modifyMVar_ (beCleanupState backend) $ const $ pure $ case attempted of
          Right () -> BackendCleanupRunning done
          Left _ -> BackendCleanupNotStarted
        putMVar done attempted
      pure (BackendCleanupRunning done, done)
    BackendCleanupRunning done -> pure (state, done)
  readMVar completion >>= either throwIO pure

cleanupBackend :: Backend -> IO ()
cleanupBackend backend = mask_ $
  runCleanupActionsPreservingFirstFailure
    [ terminateProcessTree
        (beProc backend) (beProcessGroupIdentifier backend)
    , closeQuietly $ beIn backend
    , stopBackendStderrCapture backend
    , closeQuietly $ beOut backend
    , closeQuietly $ beErr backend
    ]

stopBackendStderrCapture :: Backend -> IO ()
stopBackendStderrCapture backend = do
  drained <- timeout 1000000 $ readMVar (beErrDone backend)
  case drained of
    Just () -> pure ()
    Nothing -> do
      killThread (beErrThread backend)
      _ <- timeout stderrCompletionWaitMicroseconds
        $ readMVar (beErrDone backend)
      pure ()

runCleanupActionsPreservingFirstFailure :: [IO ()] -> IO ()
runCleanupActionsPreservingFirstFailure [] = pure ()
runCleanupActionsPreservingFirstFailure (action : remaining) =
  runCleanupPreservingPrimaryFailure action
    $ runCleanupActionsPreservingFirstFailure remaining

runCleanupPreservingPrimaryFailure :: IO () -> IO () -> IO ()
runCleanupPreservingPrimaryFailure primaryAction cleanupAction =
  mask $ \restore -> do
    primaryResult <- try (restore primaryAction)
      :: IO (Either SomeException ())
    cleanupResult <- try cleanupAction
      :: IO (Either SomeException ())
    case primaryResult of
      Left primaryFailure -> throwIO primaryFailure
      Right () -> either throwIO pure cleanupResult

-- Request cycle -------------------------------------------------------------

-- | Send one request and read the blank-line-delimited JSON response.
request :: Backend -> Maybe Int {-^ timeout, seconds -} -> JValue
        -> IO (Either RequestError JValue)
request backend timeoutSecs payload = do
  sendResult <- try $ do
    hPutStr (beIn backend) (encodeJson payload ++ "\n\n")
    hFlush (beIn backend)
  case (sendResult :: Either IOException ()) of
    Left _ -> Left . ServerClosed <$> drainStderr backend
    Right () -> do
      response <- withTimeout (readResponse backend)
      case response of
        Nothing -> pure (Left RequestTimeout)
        Just (Left err) -> pure (Left err)
        Just (Right text) -> case parseJson text of
          Left err -> pure (Left (BadResponse (err ++ "\nin: " ++ text)))
          Right v -> pure (Right v)
 where
  withTimeout action = case timeoutSecs of
    Nothing -> Just <$> action
    Just secs -> timeout (secs * 1000000) action

readResponse :: Backend -> IO (Either RequestError String)
readResponse backend = go []
 where
  go acc = do
    line <- try (hGetLine (beOut backend))
    case (line :: Either IOException String) of
      Left _ -> Left . ServerClosed <$> drainStderr backend
      Right l
        | null l && not (null acc) -> pure (Right (unlines (reverse acc)))
        | null l -> go acc  -- leading blank line; keep waiting
        | otherwise -> go (l : acc)

drainStderr :: Backend -> IO String
drainStderr backend = do
  _ <- timeout stderrCompletionWaitMicroseconds
    $ readMVar (beErrDone backend)
  captured <- readMVar $ beErrCapture backend
  let marker
        | capturedStderrTruncated captured =
            "[earlier backend stderr truncated]\n"
        | otherwise = ""
  pure $ marker ++ Text.unpack (TextEncoding.decodeUtf8With lenientDecode
    $ capturedStderrBytes captured)

maximumCapturedStderrBytes :: Int
maximumCapturedStderrBytes = 64 * 1024

stderrReadChunkBytes :: Int
stderrReadChunkBytes = 4096

stderrCompletionWaitMicroseconds :: Int
stderrCompletionWaitMicroseconds = 1000000

captureStderr :: Handle -> MVar CapturedStderr -> IO ()
captureStderr handle capture = go
 where
  go = do
    observed <- try $ ByteString.hGetSome handle stderrReadChunkBytes
    case (observed :: Either IOException ByteString.ByteString) of
      Left _ -> pure ()
      Right bytes
        | ByteString.null bytes -> pure ()
        | otherwise -> do
            modifyMVar_ capture $ pure . appendCapturedStderr bytes
            go

appendCapturedStderr
  :: ByteString.ByteString
  -> CapturedStderr
  -> CapturedStderr
appendCapturedStderr incoming captured
  | incomingLength >= maximumCapturedStderrBytes = CapturedStderr
      (capturedStderrTruncated captured
        || not (ByteString.null $ capturedStderrBytes captured)
        || incomingLength > maximumCapturedStderrBytes)
      (ByteString.drop
        (incomingLength - maximumCapturedStderrBytes) incoming)
  | otherwise = CapturedStderr truncated retained
 where
  incomingLength = ByteString.length incoming
  previous = capturedStderrBytes captured
  previousRoom = maximumCapturedStderrBytes - incomingLength
  previousLength = ByteString.length previous
  dropped = max 0 $ previousLength - previousRoom
  retained = ByteString.drop dropped previous <> incoming
  truncated = capturedStderrTruncated captured || dropped > 0
