{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}

-- | Bounded acquisition of one explicitly named Length-ranking policy file.
--
-- This module deliberately stops at 'DisabledLengthRankingConfiguration'.  It
-- performs no discovery, activation, solver launch, or Main/REPL integration.
-- On POSIX the final path component is opened once with @O_NOFOLLOW@,
-- @O_NONBLOCK@, @O_NOCTTY@, and @O_CLOEXEC@; the descriptor is required to be
-- regular before any byte is read.  Ancestor symlinks are not excluded, and a
-- regular file can still be modified in place while it is being read.
--
-- The timeout is a same-process interruption bound, not a hard kernel IO
-- deadline.  Descriptor cleanup is attempted before timeout or caller async
-- exceptions propagate, but an uninterruptible filesystem operation or close
-- can outlive the requested interval.  Windows fails closed until an
-- equivalent native handle/type implementation exists.
module Leant.Synth.Length.Configuration.File.Acquire
  ( lengthRankingConfigurationFileMaximumPathCharacters
  , lengthRankingConfigurationFileMaximumTimeoutMilliseconds
  , lengthRankingConfigurationFileLoadMaximumBytes
  , LengthRankingConfigurationFileSource (..)
  , LengthRankingConfigurationFileAdmissionError (..)
  , LengthRankingConfigurationFileRequest
  , LengthRankingConfigurationFileLoadErrorClass (..)
  , LengthRankingConfigurationFileLoadError
  , mkLengthRankingConfigurationFileRequest
  , loadLengthRankingConfigurationFile
  , lengthRankingConfigurationFileLoadErrorClass
  , lengthRankingConfigurationFileLoadCleanupIncomplete
  ) where

#ifndef mingw32_HOST_OS
import Control.Exception (evaluate, mask, onException)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
#endif
import Numeric.Natural (Natural)
import System.FilePath (isAbsolute)
#ifndef mingw32_HOST_OS
import System.IO.Error (isEOFError, tryIOError)
import System.Posix.Files (fileSize, getFdStatus, isRegularFile)
import System.Posix.IO
  ( OpenFileFlags (..)
  , OpenMode (ReadOnly)
  , closeFd
  , defaultFileFlags
  , openFd
  )
import qualified System.Posix.IO.ByteString as PosixByteString
import System.Posix.Types (Fd)
import System.Timeout (timeout)
#endif

import Leant.Json.Bounded (BoundedJsonLimits (..))
import Leant.Synth.Length.Configuration.File
  ( DisabledLengthRankingConfiguration
  , LengthRankingConfigurationFileError
  , decodeLengthRankingConfigurationFile
  , lengthRankingConfigurationFileJsonLimits
  )

lengthRankingConfigurationFileMaximumPathCharacters :: Natural
lengthRankingConfigurationFileMaximumPathCharacters = 4096

lengthRankingConfigurationFileMaximumTimeoutMilliseconds :: Int
lengthRankingConfigurationFileMaximumTimeoutMilliseconds = 60000

lengthRankingConfigurationFileLoadMaximumBytes :: Natural
lengthRankingConfigurationFileLoadMaximumBytes =
  boundedJsonMaximumTotalBytes lengthRankingConfigurationFileJsonLimits

-- | Raw caller input.  The fields intentionally remain lazy so an oversized
-- or cyclic path is rejected before the timeout field is demanded.
data LengthRankingConfigurationFileSource =
  LengthRankingConfigurationFileSource
    { lengthRankingConfigurationFileSourcePath :: FilePath
    , lengthRankingConfigurationFileSourceTimeoutMilliseconds :: Int
    }

data LengthRankingConfigurationFileAdmissionError
  = LengthRankingConfigurationFilePathCharacterLimitExceeded
      !Natural !Natural
  | LengthRankingConfigurationFilePathEmpty
  | LengthRankingConfigurationFilePathContainsNul
  | LengthRankingConfigurationFilePathNotAbsolute
  | LengthRankingConfigurationFileTimeoutNotPositive
  | LengthRankingConfigurationFileTimeoutLimitExceeded !Int !Int
  deriving (Eq, Ord, Show)

-- | A finite explicit path and timeout.  The constructor stays private so a
-- caller cannot bypass the admission order or fabricate an unbounded request.
data LengthRankingConfigurationFileRequest =
  LengthRankingConfigurationFileRequest !FilePath !Int

data LengthRankingConfigurationFileLoadErrorClass
  = LengthRankingConfigurationFilePlatformUnsupported
  | LengthRankingConfigurationFileOpenFailed
  | LengthRankingConfigurationFileInspectFailed
  | LengthRankingConfigurationFileNotRegular
  | LengthRankingConfigurationFileReadFailed
  | LengthRankingConfigurationFileByteLimitExceeded !Natural !Natural
  | LengthRankingConfigurationFileDecodeRejected
      !LengthRankingConfigurationFileError
  | LengthRankingConfigurationFileDeadlineExceeded
  | LengthRankingConfigurationFileCleanupFailed
  deriving (Eq, Ord, Show)

-- | Sanitized primary failure plus whether descriptor cleanup was observed to
-- fail or was interrupted.  No path, errno text, or file byte is retained.
data LengthRankingConfigurationFileLoadError =
  LengthRankingConfigurationFileLoadError
    !LengthRankingConfigurationFileLoadErrorClass
    !Bool
  deriving (Eq, Ord, Show)

lengthRankingConfigurationFileLoadErrorClass
  :: LengthRankingConfigurationFileLoadError
  -> LengthRankingConfigurationFileLoadErrorClass
lengthRankingConfigurationFileLoadErrorClass
    (LengthRankingConfigurationFileLoadError failure _) = failure

lengthRankingConfigurationFileLoadCleanupIncomplete
  :: LengthRankingConfigurationFileLoadError
  -> Bool
lengthRankingConfigurationFileLoadCleanupIncomplete
    (LengthRankingConfigurationFileLoadError _ incomplete) = incomplete

-- | Admit the path productively at maximum plus one, then validate its exact
-- spelling and the finite timeout.  Nothing is read or inspected here.
mkLengthRankingConfigurationFileRequest
  :: LengthRankingConfigurationFileSource
  -> Either
      LengthRankingConfigurationFileAdmissionError
      LengthRankingConfigurationFileRequest
mkLengthRankingConfigurationFileRequest source = do
  let path = lengthRankingConfigurationFileSourcePath source
      observed = observedPathCharacters
        lengthRankingConfigurationFileMaximumPathCharacters path
  if observed > lengthRankingConfigurationFileMaximumPathCharacters
    then Left $ LengthRankingConfigurationFilePathCharacterLimitExceeded
      lengthRankingConfigurationFileMaximumPathCharacters
      (lengthRankingConfigurationFileMaximumPathCharacters + 1)
    else pure ()
  case path of
    [] -> Left LengthRankingConfigurationFilePathEmpty
    _ -> pure ()
  if '\0' `elem` path
    then Left LengthRankingConfigurationFilePathContainsNul
    else pure ()
  if isAbsolute path
    then pure ()
    else Left LengthRankingConfigurationFilePathNotAbsolute
  let timeoutMilliseconds =
        lengthRankingConfigurationFileSourceTimeoutMilliseconds source
  if timeoutMilliseconds <= 0
    then Left LengthRankingConfigurationFileTimeoutNotPositive
    else pure ()
  if timeoutMilliseconds >
      lengthRankingConfigurationFileMaximumTimeoutMilliseconds
    then Left $ LengthRankingConfigurationFileTimeoutLimitExceeded
      lengthRankingConfigurationFileMaximumTimeoutMilliseconds
      (lengthRankingConfigurationFileMaximumTimeoutMilliseconds + 1)
    else Right $ LengthRankingConfigurationFileRequest
      path timeoutMilliseconds

observedPathCharacters :: Natural -> FilePath -> Natural
observedPathCharacters maximumValue = go 0
 where
  go !observed [] = observed
  go !observed (_ : remaining)
    | observed >= maximumValue = maximumValue + 1
    | otherwise = go (observed + 1) remaining

loadLengthRankingConfigurationFile
  :: LengthRankingConfigurationFileRequest
  -> IO
      (Either
        LengthRankingConfigurationFileLoadError
        DisabledLengthRankingConfiguration)
#ifdef mingw32_HOST_OS
loadLengthRankingConfigurationFile _ = pure $ Left
  $ LengthRankingConfigurationFileLoadError
      LengthRankingConfigurationFilePlatformUnsupported False
#else
loadLengthRankingConfigurationFile
    (LengthRankingConfigurationFileRequest path timeoutMilliseconds) = do
  cleanupIncomplete <- newIORef False
  bounded <- timeout (timeoutMilliseconds * 1000)
    $ loadWithinDeadline cleanupIncomplete path
  case bounded of
    Just result -> pure result
    Nothing -> do
      incomplete <- readIORef cleanupIncomplete
      pure $ Left $ LengthRankingConfigurationFileLoadError
        LengthRankingConfigurationFileDeadlineExceeded incomplete

loadWithinDeadline
  :: IORef Bool
  -> FilePath
  -> IO
      (Either
        LengthRankingConfigurationFileLoadError
        DisabledLengthRankingConfiguration)
loadWithinDeadline cleanupIncomplete path = mask $ \restore -> do
  opened <- tryIOError $ openFd path ReadOnly acquisitionOpenFlags
  case opened of
    Left _ -> pure $ loadFailure LengthRankingConfigurationFileOpenFailed
      False
    Right descriptor -> do
      outcome <- restore (readConfiguration descriptor)
        `onException` void (closeOwned cleanupIncomplete descriptor)
      closeIncomplete <- closeOwned cleanupIncomplete descriptor
      pure $ case outcome of
        Left primary -> Left $ LengthRankingConfigurationFileLoadError
          primary closeIncomplete
        Right _ | closeIncomplete -> loadFailure
          LengthRankingConfigurationFileCleanupFailed True
        Right configuration -> Right configuration

acquisitionOpenFlags :: OpenFileFlags
acquisitionOpenFlags = defaultFileFlags
  { nofollow = True
  , nonBlock = True
  , noctty = True
  , cloexec = True
  }

closeOwned :: IORef Bool -> Fd -> IO Bool
closeOwned cleanupIncomplete descriptor = do
  writeIORef cleanupIncomplete True
  closed <- tryIOError $ closeFd descriptor
  case closed of
    Left _ -> pure True
    Right () -> writeIORef cleanupIncomplete False >> pure False

readConfiguration
  :: Fd
  -> IO
      (Either
        LengthRankingConfigurationFileLoadErrorClass
        DisabledLengthRankingConfiguration)
readConfiguration descriptor = do
  inspected <- tryIOError $ getFdStatus descriptor
  case inspected of
    Left _ -> pure $ Left LengthRankingConfigurationFileInspectFailed
    Right status
      | not $ isRegularFile status -> pure $ Left
          LengthRankingConfigurationFileNotRegular
      | fileSize status >
          fromIntegral lengthRankingConfigurationFileLoadMaximumBytes ->
          pure $ Left $ LengthRankingConfigurationFileByteLimitExceeded
            lengthRankingConfigurationFileLoadMaximumBytes
            (lengthRankingConfigurationFileLoadMaximumBytes + 1)
      | otherwise -> readChunks 0 []
 where
  readChunks !observed chunks = do
    let probeMaximum = lengthRankingConfigurationFileLoadMaximumBytes + 1
        requested = min acquisitionChunkBytes $ probeMaximum - observed
    next <- tryIOError $ PosixByteString.fdRead descriptor
      $ fromIntegral requested
    case next of
      Left failure
        | isEOFError failure -> finish chunks
        | otherwise -> pure $ Left LengthRankingConfigurationFileReadFailed
      Right chunk
        | ByteString.null chunk -> finish chunks
        | otherwise ->
            let admitted = fromIntegral $ ByteString.length chunk
                following = observed + admitted
            in if following > lengthRankingConfigurationFileLoadMaximumBytes
              then pure $ Left
                $ LengthRankingConfigurationFileByteLimitExceeded
                    lengthRankingConfigurationFileLoadMaximumBytes
                    (lengthRankingConfigurationFileLoadMaximumBytes + 1)
              else readChunks following (chunk : chunks)

  finish chunks = evaluate $ case decodeLengthRankingConfigurationFile
      $ ByteString.concat $ reverse chunks of
    Left failure -> Left
      $ LengthRankingConfigurationFileDecodeRejected failure
    Right configuration -> Right configuration

acquisitionChunkBytes :: Natural
acquisitionChunkBytes = 32768

loadFailure
  :: LengthRankingConfigurationFileLoadErrorClass
  -> Bool
  -> Either
      LengthRankingConfigurationFileLoadError
      DisabledLengthRankingConfiguration
loadFailure failure cleanupIncomplete = Left
  $ LengthRankingConfigurationFileLoadError failure cleanupIncomplete
#endif
