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
  , BackendTrace
  , BackendTraceEvent (..)
  , BackendTraceStage (..)
  , BackendTraceSnapshot (..)
  , newBackendTrace
  , newBackendTraceWithRequests
  , newBackendTraceWithRequestLimit
  , readBackendTrace
  , spawnBackendWithTrace
  , killBackend
  , request
  , requestWithTraceAnnotation
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
  , takeMVar
  )
import Control.Concurrent.Async (wait, withAsync)
import Control.Exception
  ( IOException
  , SomeException
  , evaluate
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
import Data.Foldable (toList)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Maybe (catMaybes, listToMaybe)
import Data.Ord (Down (..))
import qualified Data.Sequence as Seq
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
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
import System.Process (Pid, getProcessExitCode)
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

import Leant.Json (JValue (..), encodeJson, parseJson)

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
  , beOutLines :: MVar (Either IOException String)
  , beOutDone :: MVar ()
  , beOutThread :: ThreadId
  , beErrCapture :: MVar CapturedStderr
  , beErrDone :: MVar ()
  , beErrThread :: ThreadId
  , beCleanupState :: MVar BackendCleanupState
  , beTrace :: Maybe BackendTraceLink
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

-- | Optional transport observation. The ordinary constructor retains no
-- source text or payloads. Request capture requires a separate explicit opt-in.
-- Neither mode adds file IO or threads to the request path. Event capacity is
-- clamped to 0..16384; older events are dropped with an explicit count. Clocks
-- and bookkeeping share the request's deadline with sending and response reading.
data BackendTrace = BackendTrace
  !(IORef BackendTraceState) !(Maybe (IORef TraceRequestCapture))

-- Private, strict UTF-8 copies cannot retain a lazy candidate/source environment.
-- Only whole records are admitted, independently of the transport event ring.
data TraceRequestCapture = TraceRequestCapture
  { capturedRequestRowLimit :: !Int
  , capturedRequestBytes :: !Int
  , capturedRequestRows :: !(Seq.Seq TraceRequestRecord)
  , omittedRequestRows :: !Integer
  , omittedRequestPayloads :: !Integer
  , omittedRequestAnnotations :: !Integer
  , omittedRequestBytes :: !Integer
  , omittedRequestEncoding :: !Integer
  }

data TraceRequestRecord = TraceRequestRecord
  { capturedBackendId :: !Integer
  , capturedRequestId :: !Integer
  , capturedRequestStarted :: !Word64
  , capturedRequestCompleted :: !Word64
  , capturedRequestPayload :: !ByteString.ByteString
  , capturedRequestAnnotation :: !(Maybe ByteString.ByteString)
  }

data TraceRequestOmission
  = RequestRowLimit | RequestPayloadLimit | RequestAnnotationLimit | RequestByteLimit
  | RequestInvalidUnicode

requestRowLimit, requestPayloadLimit, requestAnnotationLimit, requestByteLimit :: Int
requestRowLimit = 128
requestPayloadLimit = 256 * 1024
requestAnnotationLimit = 8 * 1024
requestByteLimit = 4 * 1024 * 1024

data BackendTraceState = BackendTraceState
  { traceCapacity :: !Int
  , traceDropped :: !Integer
  , traceNextBackend :: !Integer
  , traceNextRequest :: !Integer
  , traceEvents :: !(Seq.Seq BackendTraceEvent)
  }

data BackendTraceLink = BackendTraceLink !BackendTrace !Integer

data BackendTraceEvent = BackendTraceEvent
  { backendTraceMonotonicNanoseconds :: !Word64
  , backendTraceBackendId :: !Integer
  , backendTraceRequestId :: !(Maybe Integer)
  , backendTraceStage :: !BackendTraceStage
  }
  deriving (Eq, Show)

-- | Stdout capture events belong to the backend, not an inferred request:
-- its read can start before a request is sent or finish after cancellation.
-- ProcessCreated reports only the public process API's owned wrapper PID.
-- In particular Windows Job handles may report Nothing; this is not a PID
-- for an inferred lake/repl descendant. An external owned-process census can
-- supply those identities without changing transport ownership.
data BackendTraceStage
  = TraceSpawnStarted
  | TraceProcessCreated !(Maybe Integer)
  | TracePipesReady
  | TraceSpawnFailed
  | TraceRequestStarted !(Maybe Int)
  | TraceWriteStarted
  | TraceWriteCompleted
  | TraceFlushCompleted
  | TraceSendFailed
  | TraceResponseReadStarted
  | TraceResponseFirstLine
  | TraceResponseDelimiter
  | TraceResponseReadCompleted
  | TraceRequestTimedOut
  | TraceResponseTransportFailed
  | TraceResponseParsed
  | TraceResponseInvalidJson
  | TraceRequestInterrupted
  | TraceStdoutReadStarted
  | TraceStdoutLineRead !Bool -- ^ True for an empty delimiter line.
  | TraceStdoutReadFailed
  | TraceStdoutQueued
  | TraceCleanupStarted
  | TraceCleanupCompleted
  | TraceCleanupFailed
  deriving (Eq, Show)

data BackendTraceSnapshot = BackendTraceSnapshot
  { backendTraceCapacity :: !Int
  , backendTraceDroppedEvents :: !Integer
  , backendTraceEvents :: [BackendTraceEvent]
  -- | Optional canonical-JSON request records; absent with 'newBackendTrace'.
  -- UTF-8 byte lengths exclude protocol framing and are not physical pipe bytes.
  , backendTraceRequestCapture :: Maybe JValue
  }
  deriving (Eq, Show)

newBackendTrace :: Int -> IO BackendTrace
newBackendTrace = newBackendTraceWithCapture Nothing

-- | Explicit local diagnostic opt-in: at most 128 whole requests, 256 KiB per
-- payload, 8 KiB per annotation and 4 MiB total retained UTF-8. These limits
-- affect observation only, never the request or synthesis admission policy.
newBackendTraceWithRequests :: Int -> IO BackendTrace
newBackendTraceWithRequests = newBackendTraceWithRequestLimit requestRowLimit

-- | Larger opt-in diagnostics may retain up to 1024 whole requests. The
-- per-record and aggregate byte limits are unchanged; zero rows never demand
-- optional metadata. The selected (clamped) limit is included in each snapshot.
newBackendTraceWithRequestLimit :: Int -> Int -> IO BackendTrace
newBackendTraceWithRequestLimit rows capacity = do
  capture <- newIORef $ TraceRequestCapture (max 0 $ min 1024 rows) 0 Seq.empty 0 0 0 0 0
  newBackendTraceWithCapture (Just capture) capacity

newBackendTraceWithCapture :: Maybe (IORef TraceRequestCapture) -> Int -> IO BackendTrace
newBackendTraceWithCapture capture capacity = do
  reference <- newIORef BackendTraceState
    { traceCapacity = max 0 (min 16384 capacity)
    , traceDropped = 0
    , traceNextBackend = 1
    , traceNextRequest = 1
    , traceEvents = Seq.empty
    }
  pure $ BackendTrace reference capture

-- | In insertion order. Concurrent capture/request timestamps need not be
-- sorted: an event can be preempted between reading the clock and insertion.
-- Reading a snapshot does not clear or otherwise change the trace.
readBackendTrace :: BackendTrace -> IO BackendTraceSnapshot
readBackendTrace (BackendTrace reference capture) = do
  state <- readIORef reference
  requests <- mapM (fmap traceRequestCaptureJson . readIORef) capture
  pure BackendTraceSnapshot
    { backendTraceCapacity = traceCapacity state
    , backendTraceDroppedEvents = traceDropped state
    , backendTraceEvents = toList $ traceEvents state
    , backendTraceRequestCapture = requests
    }

newTraceLink :: Maybe BackendTrace -> IO (Maybe BackendTraceLink)
newTraceLink Nothing = pure Nothing
newTraceLink (Just trace@(BackendTrace reference _)) = do
  identifier <- atomicModifyIORef' reference $ \state ->
    (state { traceNextBackend = traceNextBackend state + 1 }, traceNextBackend state)
  pure $ Just $ BackendTraceLink trace identifier

newTraceRequest :: Maybe BackendTraceLink -> IO (Maybe Integer)
newTraceRequest Nothing = pure Nothing
newTraceRequest (Just (BackendTraceLink (BackendTrace reference _) _)) =
  Just <$> atomicModifyIORef' reference (\state ->
    (state { traceNextRequest = traceNextRequest state + 1 }, traceNextRequest state))

recordTrace :: Maybe BackendTraceLink -> Maybe Integer -> BackendTraceStage -> IO ()
recordTrace Nothing _ _ = pure ()
recordTrace (Just (BackendTraceLink (BackendTrace reference _) identifier)) requestId stage = do
  observed <- getMonotonicTimeNSec
  let event = BackendTraceEvent observed identifier requestId stage
  atomicModifyIORef' reference $ \state ->
    let full = Seq.length (traceEvents state) >= traceCapacity state
        retained
          | traceCapacity state == 0 = Seq.empty
          | full = Seq.drop 1 (traceEvents state) Seq.|> event
          | otherwise = traceEvents state Seq.|> event
    in (state { traceEvents = retained
              , traceDropped = traceDropped state + if full then 1 else 0 }, ())

-- A disabled capture path neither reads another IORef nor evaluates an
-- annotation. An enabled capture shares the exact encoded String used to send,
-- copying only a bounded prefix while deciding whether the whole row fits.
captureTraceRequest
  :: Maybe BackendTraceLink -> Maybe Integer -> Maybe JValue -> String -> IO ()
captureTraceRequest
    (Just (BackendTraceLink (BackendTrace _ (Just reference)) backendId))
    (Just requestId) annotation encoded = do
  initial <- readIORef reference
  case fullCapture initial of
    Just omission -> omit omission
    Nothing -> do
      started <- getMonotonicTimeNSec
      prepared <- evaluate $ do
        body <- boundedTraceUtf8 RequestPayloadLimit requestPayloadLimit encoded
        label <- case annotation of
          Nothing -> Right Nothing
          Just value -> Just <$>
            boundedTraceUtf8 RequestAnnotationLimit requestAnnotationLimit (encodeJson value)
        let bytes = ByteString.length body + maybe 0 ByteString.length label
        bytes `seq` Right (body, label, bytes)
      case prepared of
        Left omission -> omit omission
        Right (body, label, bytes) -> do
          completed <- getMonotonicTimeNSec
          let row = TraceRequestRecord backendId requestId started completed body label
          row `seq` atomicModifyIORef' reference (\state ->
            -- Recheck admission atomically: one trace can observe distinct
            -- backends concurrently. No concurrent insertion can exceed a cap.
            case fullCapture state of
              Just omission -> (omitTraceRequest omission state, ())
              Nothing
                | capturedRequestBytes state + bytes > requestByteLimit ->
                    (omitTraceRequest RequestByteLimit state, ())
                | otherwise ->
                    (state
                      { capturedRequestBytes = capturedRequestBytes state + bytes
                      , capturedRequestRows = capturedRequestRows state Seq.|> row
                      }, ()))
 where
  omit omission = atomicModifyIORef' reference $ \state ->
    (omitTraceRequest omission state, ())
  fullCapture state
    | Seq.length (capturedRequestRows state) >= capturedRequestRowLimit state = Just RequestRowLimit
    | capturedRequestBytes state >= requestByteLimit = Just RequestByteLimit
    | otherwise = Nothing
captureTraceRequest _ _ _ _ = pure ()

-- At most limit+1 characters are inspected, even when the source is longer.
-- Checking the strict UTF-8 length also rejects multibyte overflow. A successful
-- result contains the entire canonical string, never a truncated prefix.
-- Reject isolated surrogates explicitly: Text.pack would replace them, which
-- would misrepresent the original String as an exact canonical request.
boundedTraceUtf8
  :: TraceRequestOmission -> Int -> String -> Either TraceRequestOmission ByteString.ByteString
boundedTraceUtf8 overflow limit source =
  let prefix = take (limit + 1) source
      bytes = TextEncoding.encodeUtf8 $ Text.pack prefix
      surrogate character = character >= '\xD800' && character <= '\xDFFF'
  in if any surrogate prefix then Left RequestInvalidUnicode
       else if ByteString.length bytes > limit then Left overflow else Right bytes

omitTraceRequest :: TraceRequestOmission -> TraceRequestCapture -> TraceRequestCapture
omitTraceRequest omission state = case omission of
  RequestRowLimit -> state { omittedRequestRows = omittedRequestRows state + 1 }
  RequestPayloadLimit -> state { omittedRequestPayloads = omittedRequestPayloads state + 1 }
  RequestAnnotationLimit -> state { omittedRequestAnnotations = omittedRequestAnnotations state + 1 }
  RequestByteLimit -> state { omittedRequestBytes = omittedRequestBytes state + 1 }
  RequestInvalidUnicode -> state { omittedRequestEncoding = omittedRequestEncoding state + 1 }

-- Snapshot conversion is outside request sending and response waiting. JSON
-- strings preserve the exact canonical text for local extraction and hashing;
-- annotation_json is null for genuinely unlabelled startup/replay requests.
traceRequestCaptureJson :: TraceRequestCapture -> JValue
traceRequestCaptureJson state = JObj
  [ ("format", JStr "leant-backend-request-capture-v1")
  , ("encoding", JStr "canonical encodeJson UTF-8 without protocol framing")
  , ("row_limit", JInt $ toInteger $ capturedRequestRowLimit state)
  , ("payload_byte_limit", JInt $ toInteger requestPayloadLimit)
  , ("annotation_byte_limit", JInt $ toInteger requestAnnotationLimit)
  , ("total_byte_limit", JInt $ toInteger requestByteLimit)
  , ("retained_bytes", JInt $ toInteger $ capturedRequestBytes state)
  , ("omitted_records", JInt $ sum $ map snd omissions)
  , ("omissions", JObj [(reason, JInt count) | (reason, count) <- omissions])
  , ("requests", JArr $ map recordJson $ toList $ capturedRequestRows state)
  ]
 where
  omissions =
    [ ("row_limit", omittedRequestRows state)
    , ("payload_byte_limit", omittedRequestPayloads state)
    , ("annotation_byte_limit", omittedRequestAnnotations state)
    , ("total_byte_limit", omittedRequestBytes state)
    , ("invalid_unicode", omittedRequestEncoding state)
    ]
  text = JStr . Text.unpack . TextEncoding.decodeUtf8
  recordJson row = JObj
    [ ("backend_id", JInt $ capturedBackendId row)
    , ("request_id", JInt $ capturedRequestId row)
    , ("capture_started_ns", JInt $ toInteger $ capturedRequestStarted row)
    , ("capture_completed_ns", JInt $ toInteger $ capturedRequestCompleted row)
    , ("payload_utf8_bytes", JInt $ toInteger $ ByteString.length $ capturedRequestPayload row)
    , ("annotation_utf8_bytes", JInt $ toInteger $
        maybe 0 ByteString.length $ capturedRequestAnnotation row)
    , ("payload_json", text $ capturedRequestPayload row)
    , ("annotation_json", maybe JNull text $ capturedRequestAnnotation row)
    ]

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
spawnBackend = spawnBackendObserved Nothing

spawnBackendWithTrace :: BackendTrace -> BackendConfig -> IO Backend
spawnBackendWithTrace trace config = do
  link <- newTraceLink (Just trace)
  recordTrace link Nothing TraceSpawnStarted
  spawnBackendObserved link config
    `onException` recordTrace link Nothing TraceSpawnFailed

spawnBackendObserved :: Maybe BackendTraceLink -> BackendConfig -> IO Backend
spawnBackendObserved trace config = mask $ \restore -> do
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
    Nothing | requiresProcessGroupIdentifier -> do
      let (maybeIn, maybeOut, maybeErr, ph) = created
      cleanupIncompleteProcess maybeIn maybeOut maybeErr ph Nothing
      ioError $ userError
        "backend process did not expose its owned process-group identifier"
    _ -> case created of
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
    -- This optional observation is inside the same owned cleanup boundary as
    -- handle preparation: a diagnostic failure cannot abandon the created Job.
    case trace of
      Nothing -> pure ()
      Just _ -> do
        identifier <- tryIOError $ getPid ph
        let available = case identifier of
              Right (Just pid) -> Just $ toInteger pid
              _ -> Nothing
        recordTrace trace Nothing $ TraceProcessCreated available
    _ <- restore $ do
      mapM_ prepareText [hIn, hOut]
      hSetBinaryMode hErr True
      hSetBuffering hErr NoBuffering
    capture <- newMVar $ CapturedStderr False ByteString.empty
    outputLines <- newEmptyMVar
    outputDone <- newEmptyMVar
    done <- newEmptyMVar
    cleanupState <- newMVar BackendCleanupNotStarted
    recordTrace trace Nothing TracePipesReady
    drainThread <- forkIOWithUnmask $ \unmask ->
      unmask (captureStderr hErr capture) `finally` putMVar done ()
    outputThread <- forkIOWithUnmask $ \unmask ->
      unmask (captureStdout trace hOut outputLines)
        `finally` putMVar outputDone ()
    pure Backend
      { beIn = hIn
      , beOut = hOut
      , beErr = hErr
      , beProc = ph
      , beProcessGroupIdentifier = processGroupIdentifier
      , beOutLines = outputLines
      , beOutDone = outputDone
      , beOutThread = outputThread
      , beErrCapture = capture
      , beErrDone = done
      , beErrThread = drainThread
      , beCleanupState = cleanupState
      , beTrace = trace
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
#ifdef mingw32_HOST_OS
-- A successful createProcess with use_process_jobs owns the Windows Job.
-- process-1.6 represents that ownership by OpenExtHandle; its public getPid
-- returns Nothing for that handle. POSIX-style group signalling
-- is neither needed nor used: termination and completion use the owned Job.
captureProcessGroupIdentifier _ = pure Nothing
#else
captureProcessGroupIdentifier process = do
  captured <- tryIOError $ getPid process
  pure $ case captured of
    Right (Just pid) -> Just $ toInteger (pid :: Pid)
    _ -> Nothing
#endif

requiresProcessGroupIdentifier :: Bool
#ifdef mingw32_HOST_OS
requiresProcessGroupIdentifier = False
#else
requiresProcessGroupIdentifier = True
#endif

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
  recordTrace (beTrace backend) Nothing TraceCleanupStarted
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
  (readMVar completion >>= either throwIO pure)
    `onException` recordTrace (beTrace backend) Nothing TraceCleanupFailed
  recordTrace (beTrace backend) Nothing TraceCleanupCompleted

cleanupBackend :: Backend -> IO ()
cleanupBackend backend = mask_ $
  runCleanupActionsPreservingFirstFailure
    [ terminateProcessTree
        (beProc backend) (beProcessGroupIdentifier backend)
    , closeQuietly $ beIn backend
    , stopBackendStdoutCapture backend
    , stopBackendStderrCapture backend
    , closeQuietly $ beOut backend
    , closeQuietly $ beErr backend
    ]

stopBackendStdoutCapture :: Backend -> IO ()
stopBackendStdoutCapture backend = do
  -- Process-tree termination has closed the pipe writers. Unlike stderr,
  -- unread stdout is no longer useful; do not spend a drain window waiting
  -- for a reader whose bounded queue has no remaining consumer.
  killThread $ beOutThread backend
  completed <- timeout stderrCompletionWaitMicroseconds
    $ readMVar (beOutDone backend)
  case completed of
    Just () -> pure ()
    Nothing -> ioError $ userError
      "backend stdout capture did not stop after process-tree termination"

stopBackendStderrCapture :: Backend -> IO ()
stopBackendStderrCapture backend =
  stopBackendCapture (beErrDone backend) (beErrThread backend)

stopBackendCapture :: MVar () -> ThreadId -> IO ()
stopBackendCapture done captureThread = do
  drained <- timeout 1000000 $ readMVar done
  case drained of
    Just () -> pure ()
    Nothing -> do
      killThread captureThread
      _ <- timeout stderrCompletionWaitMicroseconds
        $ readMVar done
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
request backend timeoutSecs payload =
  requestWithTraceAnnotation backend timeoutSecs payload Nothing

-- | Same request/response path, with optional local diagnostic metadata. The
-- annotation is deliberately lazy and ignored unless request capture is enabled.
-- Request IDs are allocated here, so callers cannot invent or reuse ownership.
requestWithTraceAnnotation
  :: Backend -> Maybe Int -> JValue -> Maybe JValue -> IO (Either RequestError JValue)
requestWithTraceAnnotation backend timeoutSecs payload annotation = do
  identifier <- newTraceRequest $ beTrace backend
  started <- getMonotonicTimeNSec
  let observe = recordTrace (beTrace backend) identifier
      encoded = encodeJson payload
      deadline = fmap (\seconds -> toInteger started
        + max 0 (toInteger seconds) * 1000000000) timeoutSecs
      beforeDeadline action = case deadline of
        Nothing -> Just <$> action
        Just absolute -> do
          now <- getMonotonicTimeNSec
          let remaining = absolute - toInteger now
              micros = min (toInteger (maxBound :: Int)) $ (remaining + 999) `div` 1000
          if remaining <= 0 then pure Nothing
            else timeout (fromInteger micros) action
      send = try $ do
        captureTraceRequest (beTrace backend) identifier annotation encoded
        observe TraceWriteStarted
        hPutStr (beIn backend) (encoded ++ "\n\n")
        observe TraceWriteCompleted
        hFlush (beIn backend)
        observe TraceFlushCompleted
      -- Windows pipe writes can defer asynchronous exceptions until the reader
      -- closes. Wait on an owned sender instead; on a send deadline, terminate
      -- the backend before joining that sender. No writer or partial protocol
      -- message may survive a returned timeout. Ordinary response timeouts keep
      -- the existing caller-owned retirement path.
      sendBeforeDeadline = withAsync send $ \sender ->
        (do sent <- beforeDeadline $ wait sender
            case sent of
              Nothing -> killBackend backend >> pure Nothing
              Just result -> pure $ Just result)
          `onException` killBackend backend
      perform = do
        observe $ TraceRequestStarted timeoutSecs
        sendResult <- sendBeforeDeadline
        completed <- case (sendResult :: Maybe (Either IOException ())) of
          Nothing -> pure Nothing
          Just sent -> beforeDeadline $ case sent of
            Left _ -> do
              observe TraceSendFailed
              Left . ServerClosed <$> drainStderr backend
            Right () -> do
              observe TraceResponseReadStarted
              response <- readResponse backend identifier
              case response of
                Left err -> do
                  observe TraceResponseTransportFailed
                  pure (Left err)
                Right text -> do
                  observe TraceResponseReadCompleted
                  case parseJson text of
                    Left err -> do
                      observe TraceResponseInvalidJson
                      pure (Left (BadResponse (err ++ "\nin: " ++ text)))
                    Right v -> do
                      observe TraceResponseParsed
                      pure (Right v)
        case completed of
          Nothing -> do
            observe TraceRequestTimedOut
            pure (Left RequestTimeout)
          Just response -> pure response
  perform `onException` observe TraceRequestInterrupted

readResponse :: Backend -> Maybe Integer -> IO (Either RequestError String)
readResponse backend identifier = go []
 where
  go acc = do
    line <- takeBackendOutputLine backend
    case (line :: Either IOException String) of
      Left _ -> Left . ServerClosed <$> drainStderr backend
      Right l
        | null l && not (null acc) -> do
            recordTrace (beTrace backend) identifier TraceResponseDelimiter
            pure (Right (unlines (reverse acc)))
        | null l -> go acc  -- leading blank line; keep waiting
        | otherwise -> do
            if null acc
              then recordTrace (beTrace backend) identifier TraceResponseFirstLine
              else pure ()
            go (l : acc)

-- Windows process pipes use a blocking read that cannot be interrupted by
-- System.Timeout. Keep that read in its owned capture thread and let requests
-- wait on an interruptible MVar instead. One pending line provides backpressure
-- without retaining an unbounded stream while a request is cancelled.
captureStdout :: Maybe BackendTraceLink -> Handle -> MVar (Either IOException String) -> IO ()
captureStdout trace handle outputLines = go
 where
  go = do
    recordTrace trace Nothing TraceStdoutReadStarted
    observed <- try $ hGetLine handle
    recordTrace trace Nothing $ case observed of
      Left _ -> TraceStdoutReadFailed
      Right line -> TraceStdoutLineRead $ null line
    putMVar outputLines observed
    recordTrace trace Nothing TraceStdoutQueued
    case observed of
      Left _ -> pure ()
      Right _ -> go

takeBackendOutputLine :: Backend -> IO (Either IOException String)
takeBackendOutputLine backend = mask_ $ do
  observed <- takeMVar $ beOutLines backend
  -- EOF is terminal, including for a subsequent request against a dead server.
  case observed of
    Left _ -> putMVar (beOutLines backend) observed
    Right _ -> pure ()
  pure observed

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
