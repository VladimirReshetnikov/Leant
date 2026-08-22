-- | A fail-soft, content-addressed cache for the compiled Lean serializer.
--
-- The cache is deliberately narrower than the session snapshot layer.  It is
-- used only for the pristine, import-free synthesis base, and its identity
-- includes a cheap high-resolution identity for the backend executable, the
-- working directory, exact generated source, and a format tag.  A miss or any
-- filesystem failure leaves the caller on the established dynamic-compilation
-- path.
module Leant.Synth.ToolingCache
  ( SynthesisToolingCache
  , SynthesisToolingCacheEntry
  , openSynthesisToolingCache
  , openSynthesisToolingCacheAt
  , synthesisToolingCacheSearchPath
  , synthesisToolingCacheEntry
  , synthesisToolingCacheModuleName
  , synthesisToolingCacheABI
  , synthesisToolingCacheArtifactPath
  , synthesisToolingCacheArtifactExists
  , withSynthesisToolingCacheExportPath
  , invalidateSynthesisToolingCacheEntry
  ) where

import Control.Exception (IOException, mask, onException, try)
import Control.Monad (unless, when)
import System.Directory
  ( XdgDirectory (XdgCache)
  , createDirectoryIfMissing
  , doesFileExist
  , getFileSize
  , getModificationTime
  , getXdgDirectory
  , makeAbsolute
  , removeFile
  , renameFile
  )
import System.FilePath
  ( normalise
  , takeDirectory
  , takeFileName
  , (</>)
  )
import System.IO (hClose, openBinaryTempFile)
import System.IO.Error
  ( catchIOError
  , tryIOError
  )

import Leant.Session.Snapshot (synthesisToolingABI)

-- | One process-start cache authority.  Its root is placed on the Lean search
-- path before any backend is spawned; entries are derived later, when the
-- exact rated serializer source is known.
data SynthesisToolingCache = SynthesisToolingCache
  { toolingCacheRoot :: FilePath
  , toolingCacheBackendIdentity :: String
  , toolingCacheWorkingDirectory :: FilePath
  }

-- | One exact generated module.  Constructors remain private so callers
-- cannot pair an ABI marker with an unrelated artifact path.
data SynthesisToolingCacheEntry = SynthesisToolingCacheEntry
  { toolingCacheEntryModuleName :: String
  , toolingCacheEntryABI :: String
  , toolingCacheEntryArtifactPath :: FilePath
  }

cacheFormat :: String
cacheFormat = "leant-compiled-synthesis-tooling-v1"

-- | Open the user's standard cache directory.  Failure disables the cache;
-- synthesis itself must never depend on optional cache discovery.
openSynthesisToolingCache
  :: FilePath
  -- ^ absolute backend executable
  -> FilePath
  -- ^ absolute backend working directory
  -> IO (Maybe SynthesisToolingCache)
openSynthesisToolingCache backend workingDirectory = do
  rootOr <- tryIOError $ getXdgDirectory XdgCache
    ("leant" </> "synthesis-tooling-v1") >>= makeAbsolute
  case rootOr of
    Left _ -> pure Nothing
    Right root -> openSynthesisToolingCacheAt root backend workingDirectory

-- | Deterministic-root variant used by the package-private tests.
openSynthesisToolingCacheAt
  :: FilePath
  -> FilePath
  -> FilePath
  -> IO (Maybe SynthesisToolingCache)
openSynthesisToolingCacheAt root backend workingDirectory = do
  opened <- try $ do
    absoluteRoot <- makeAbsolute root
    absoluteBackend <- makeAbsolute backend
    createDirectoryIfMissing True (absoluteRoot </> "LeantSynthCache")
    backendBytes <- getFileSize absoluteBackend
    backendModified <- getModificationTime absoluteBackend
    pure SynthesisToolingCache
      { toolingCacheRoot = absoluteRoot
      , toolingCacheBackendIdentity = unlines
          [ "backend-path=" ++ normalise absoluteBackend
          , "backend-bytes=" ++ show backendBytes
          , "backend-modified=" ++ show backendModified
          ]
      , toolingCacheWorkingDirectory = normalise workingDirectory
      }
  pure $ either (const Nothing) Just
    (opened :: Either IOException SynthesisToolingCache)

-- | Directory which must be appended to @LEAN_PATH@ for this cache authority.
synthesisToolingCacheSearchPath :: SynthesisToolingCache -> FilePath
synthesisToolingCacheSearchPath = toolingCacheRoot

-- | Derive an entry from the exact generated Lean source.  Reading a typical
-- REPL executable in full would allocate hundreds of MiB in every short-lived
-- Leant process, defeating the cache.  The absolute path, byte count, and
-- high-resolution modification time instead provide a cheap accidental-
-- staleness identity.  The Lean loader and an in-module ABI equality check
-- remain the final validity gates before use.  This is an opportunistic build
-- cache, not a security boundary: deliberately replacing a backend while
-- preserving all three metadata fields requires removing the cache manually.
synthesisToolingCacheEntry
  :: SynthesisToolingCache
  -> String
  -> SynthesisToolingCacheEntry
synthesisToolingCacheEntry cache source = SynthesisToolingCacheEntry
  { toolingCacheEntryModuleName = moduleName
  , toolingCacheEntryABI = abi
  , toolingCacheEntryArtifactPath = toolingCacheRoot cache
      </> "LeantSynthCache" </> (leaf ++ ".olean")
  }
 where
  identity = unlines
    [ cacheFormat
    , toolingCacheBackendIdentity cache
    , "working-directory=" ++ toolingCacheWorkingDirectory cache
    ] ++ source
  abi = synthesisToolingABI identity
  leaf = 'K' : drop (length "leant-synth-fnv1a64-") abi
  moduleName = "LeantSynthCache." ++ leaf

synthesisToolingCacheModuleName :: SynthesisToolingCacheEntry -> String
synthesisToolingCacheModuleName = toolingCacheEntryModuleName

synthesisToolingCacheABI :: SynthesisToolingCacheEntry -> String
synthesisToolingCacheABI = toolingCacheEntryABI

synthesisToolingCacheArtifactPath
  :: SynthesisToolingCacheEntry
  -> FilePath
synthesisToolingCacheArtifactPath = toolingCacheEntryArtifactPath

-- | A lookup error is indistinguishable from a miss.  The caller will use the
-- dynamic compiler, which is the semantic oracle.
synthesisToolingCacheArtifactExists
  :: SynthesisToolingCacheEntry
  -> IO Bool
synthesisToolingCacheArtifactExists entry = do
  found <- tryIOError $ doesFileExist
    (synthesisToolingCacheArtifactPath entry)
  pure $ either (const False) id found

-- | Reserve an absent sibling path, run the established dynamic compiler,
-- then publish the produced module only when the callback explicitly marks
-- it complete.  An already-present same-key artifact is retained; concurrent
-- same-key writers may atomically replace one valid artifact with another.
-- Filesystem failures are cache misses; callback exceptions and cancellation
-- remain primary and clean the temporary artifact.
withSynthesisToolingCacheExportPath
  :: SynthesisToolingCacheEntry
  -> (Maybe FilePath -> IO (value, Bool))
  -> IO value
withSynthesisToolingCacheExportPath entry action = mask $ \restore -> do
  reserved <- tryIOError $ reserveAbsentSibling destination
  case reserved of
    Left _ -> fst <$> restore (action Nothing)
    Right temporary -> do
      (value, complete) <- restore (action (Just temporary))
        `onException` removeQuietly temporary
      _ <- (tryIOError $ when complete
          $ publishIfAbsent temporary destination)
        `onException` removeQuietly temporary
      removeQuietly temporary
      pure value
 where
  destination = synthesisToolingCacheArtifactPath entry

-- | Remove an entry which Lean rejected.  Failure is intentionally ignored:
-- the current command still has the dynamic path, and a later process can
-- retry the same validation without risking user state.
invalidateSynthesisToolingCacheEntry
  :: SynthesisToolingCacheEntry
  -> IO ()
invalidateSynthesisToolingCacheEntry =
  removeQuietly . synthesisToolingCacheArtifactPath

reserveAbsentSibling :: FilePath -> IO FilePath
reserveAbsentSibling target = do
  (path, handle) <- openBinaryTempFile (takeDirectory target)
    (takeFileName target ++ ".tmp")
  let cleanup = do
        catchIOError (hClose handle) (const $ pure ())
        removeQuietly path
  (do
      hClose handle
      removeFile path
      pure path)
    `onException` cleanup

publishIfAbsent :: FilePath -> FilePath -> IO ()
publishIfAbsent temporary destination = do
  complete <- doesFileExist temporary
  when complete $ do
    exists <- doesFileExist destination
    unless exists $ do
      published <- tryIOError $ renameFile temporary destination
      case published of
        Right () -> pure ()
        Left _ -> pure ()

removeQuietly :: FilePath -> IO ()
removeQuietly path = catchIOError (removeFile path) (const $ pure ())
