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

import Control.Concurrent (ThreadId, forkIOWithUnmask, killThread)
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar_
  , newEmptyMVar
  , newMVar
  , putMVar
  , readMVar
  )
import Control.Exception (IOException, finally, mask, onException, try)
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
import System.Process
  ( CreateProcess (..)
  , ProcessHandle
  , StdStream (..)
  , createProcess
  , proc
  , terminateProcess
  , waitForProcess
  )
import System.Timeout (timeout)

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
  , beErrCapture :: MVar CapturedStderr
  , beErrDone :: MVar ()
  , beErrThread :: ThreadId
  }

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
      flip filterM (map binaryIn revs) doesFileExist

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
      }
  case created of
    (Just hIn, Just hOut, Just hErr, ph) ->
      finish restore hIn hOut hErr ph
        `onException` cleanupCreatedProcess hIn hOut hErr ph
    (maybeIn, maybeOut, maybeErr, ph) -> do
      cleanupIncompleteProcess maybeIn maybeOut maybeErr ph
      ioError $ userError "backend process did not create all three pipes"
 where
  finish restore hIn hOut hErr ph = do
    _ <- restore $ do
      mapM_ prepareText [hIn, hOut]
      hSetBinaryMode hErr True
      hSetBuffering hErr NoBuffering
    capture <- newMVar $ CapturedStderr False ByteString.empty
    done <- newEmptyMVar
    drainThread <- forkIOWithUnmask $ \unmask ->
      unmask (captureStderr hErr capture) `finally` putMVar done ()
    pure Backend
      { beIn = hIn
      , beOut = hOut
      , beErr = hErr
      , beProc = ph
      , beErrCapture = capture
      , beErrDone = done
      , beErrThread = drainThread
      }

  prepareText h = do
    hSetEncoding h utf8
    hSetNewlineMode h universalNewlineMode
    hSetBuffering h LineBuffering

cleanupCreatedProcess
  :: Handle -> Handle -> Handle -> ProcessHandle -> IO ()
cleanupCreatedProcess hIn hOut hErr process = do
  closeQuietly hIn
  terminateAndWait process
  mapM_ closeQuietly [hOut, hErr]

cleanupIncompleteProcess
  :: Maybe Handle
  -> Maybe Handle
  -> Maybe Handle
  -> ProcessHandle
  -> IO ()
cleanupIncompleteProcess maybeIn maybeOut maybeErr process = do
  mapM_ closeQuietly maybeIn
  terminateAndWait process
  mapM_ closeQuietly maybeOut
  mapM_ closeQuietly maybeErr

terminateAndWait :: ProcessHandle -> IO ()
terminateAndWait process = do
  _ <- try (terminateProcess process) :: IO (Either IOException ())
  _ <- try (waitForProcess process) :: IO (Either IOException ExitCode)
  pure ()

closeQuietly :: Handle -> IO ()
closeQuietly handle = do
  _ <- try (hClose handle) :: IO (Either IOException ())
  pure ()

-- | Shut the backend down: close stdin, terminate and reap the process,
-- give the stderr-capture thread a bounded window to finish, then close
-- the remaining handles.
killBackend :: Backend -> IO ()
killBackend backend = do
  closeQuietly $ beIn backend
  terminateAndWait $ beProc backend
  drained <- timeout 1000000 $ readMVar (beErrDone backend)
  case drained of
    Just () -> pure ()
    Nothing -> do
      killThread (beErrThread backend)
      _ <- timeout stderrCompletionWaitMicroseconds
        $ readMVar (beErrDone backend)
      pure ()
  mapM_ closeQuietly [beOut backend, beErr backend]

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
