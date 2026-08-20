{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}

-- | Shared bounded acquisition for explicit Length authority files.
--
-- This leaf owns path admission, descriptor acquisition, byte accounting,
-- interruption, and cleanup.  Callers supply a strict bounded decoder and
-- keep their own document/error vocabulary.  The loader itself adds no path,
-- errno text, or source byte to a returned failure; a caller remains
-- responsible for keeping its decoder error sanitized.
--
-- On POSIX the final path component is opened once with @O_NOFOLLOW@,
-- @O_NONBLOCK@, @O_NOCTTY@, and @O_CLOEXEC@, and the descriptor must report a
-- regular file before any byte is read.  Ancestor symlinks remain possible,
-- as does in-place mutation of an already opened regular file.  The timeout
-- is a same-process interruption bound, not a hard kernel IO deadline;
-- uninterruptible filesystem work or close can outlive it.  Cleanup is
-- attempted before timeout or caller exceptions escape.  Windows fails closed
-- until an equivalent native handle/type implementation exists.
module Leant.Synth.Length.File.Acquire
  ( lengthFileMaximumPathCharacters
  , lengthFileMaximumTimeoutMilliseconds
  , LengthFileSource (..)
  , LengthFileAdmissionError (..)
  , LengthFileRequest
  , LengthFileLoadErrorClass (..)
  , LengthFileLoadError
  , mkLengthFileRequest
  , loadLengthFile
  , lengthFileLoadErrorClass
  , lengthFileLoadCleanupIncomplete
  ) where

import Control.Monad (unless, when)
#ifndef mingw32_HOST_OS
import Control.Exception (evaluate, mask, onException)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
#else
import Data.ByteString (ByteString)
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

-- | Longest admitted path, in characters; a longer path is refused before
-- any other admission check and observed only up to this maximum plus one.
lengthFileMaximumPathCharacters :: Natural
lengthFileMaximumPathCharacters = 4096

-- | Longest admitted same-process load timeout, in milliseconds.
lengthFileMaximumTimeoutMilliseconds :: Int
lengthFileMaximumTimeoutMilliseconds = 60000

-- | Raw explicit caller input.  Both fields remain lazy so productive path
-- admission wins before the timeout is inspected.
data LengthFileSource = LengthFileSource
  { lengthFileSourcePath :: FilePath
  , lengthFileSourceTimeoutMilliseconds :: Int
  }

-- | Pure refusal of one 'LengthFileSource', reported in admission order:
-- path length, empty path, embedded NUL, relative path, non-positive
-- timeout, then timeout above 'lengthFileMaximumTimeoutMilliseconds'.
-- Limit refusals carry the maximum and the observed count capped at
-- maximum plus one; no path text is retained.
data LengthFileAdmissionError
  = LengthFilePathCharacterLimitExceeded !Natural !Natural
  | LengthFilePathEmpty
  | LengthFilePathContainsNul
  | LengthFilePathNotAbsolute
  | LengthFileTimeoutNotPositive
  | LengthFileTimeoutLimitExceeded !Int !Int
  deriving (Eq, Ord, Show)

-- | An admitted absolute path and positive timeout.  Only
-- 'mkLengthFileRequest' constructs one, so 'loadLengthFile' never sees an
-- unadmitted source.
data LengthFileRequest = LengthFileRequest !FilePath !Int

-- | Sanitized primary reason one load failed: unsupported platform, open,
-- descriptor inspection, not a regular file, read, byte limit (the maximum
-- and the observed count capped at maximum plus one; checked against the
-- reported size before reading and again while reading), the caller's
-- decoder rejection, the same-process deadline, or a close that failed
-- after an otherwise successful load.  No path, errno text, or source byte
-- is retained.
data LengthFileLoadErrorClass decodeError
  = LengthFilePlatformUnsupported
  | LengthFileOpenFailed
  | LengthFileInspectFailed
  | LengthFileNotRegular
  | LengthFileReadFailed
  | LengthFileByteLimitExceeded !Natural !Natural
  | LengthFileDecodeRejected !decodeError
  | LengthFileDeadlineExceeded
  | LengthFileCleanupFailed
  deriving (Eq, Ord, Show)

-- | One load failure: its primary class plus whether descriptor cleanup
-- was left incomplete when the failure escaped.
data LengthFileLoadError decodeError = LengthFileLoadError
  !(LengthFileLoadErrorClass decodeError)
  !Bool
  deriving (Eq, Ord, Show)

-- | The primary failure class.
lengthFileLoadErrorClass
  :: LengthFileLoadError decodeError
  -> LengthFileLoadErrorClass decodeError
lengthFileLoadErrorClass (LengthFileLoadError primary _) = primary

-- | Whether the opened descriptor could not be closed before the failure
-- was returned.
lengthFileLoadCleanupIncomplete :: LengthFileLoadError decodeError -> Bool
lengthFileLoadCleanupIncomplete (LengthFileLoadError _ incomplete) = incomplete

-- | Admit a caller-supplied source without IO, in the fixed order listed on
-- 'LengthFileAdmissionError'.  Path admission is productive: an
-- unboundedly long path is rejected after observing at most the maximum
-- plus one characters, and before the timeout field is inspected.
mkLengthFileRequest
  :: LengthFileSource
  -> Either LengthFileAdmissionError LengthFileRequest
mkLengthFileRequest source = do
  let path = lengthFileSourcePath source
      observed = observedPathCharacters lengthFileMaximumPathCharacters path
  when (observed > lengthFileMaximumPathCharacters)
    $ Left $ LengthFilePathCharacterLimitExceeded
      lengthFileMaximumPathCharacters (lengthFileMaximumPathCharacters + 1)
  when (null path) $ Left LengthFilePathEmpty
  when ('\0' `elem` path) $ Left LengthFilePathContainsNul
  unless (isAbsolute path) $ Left LengthFilePathNotAbsolute
  let timeoutMilliseconds = lengthFileSourceTimeoutMilliseconds source
  when (timeoutMilliseconds <= 0) $ Left LengthFileTimeoutNotPositive
  when (timeoutMilliseconds > lengthFileMaximumTimeoutMilliseconds)
    $ Left $ LengthFileTimeoutLimitExceeded
      lengthFileMaximumTimeoutMilliseconds
      (lengthFileMaximumTimeoutMilliseconds + 1)
  Right $ LengthFileRequest path timeoutMilliseconds

observedPathCharacters :: Natural -> FilePath -> Natural
observedPathCharacters maximumValue = go 0
 where
  go !observed [] = observed
  go !observed (_ : remaining)
    | observed >= maximumValue = maximumValue + 1
    | otherwise = go (observed + 1) remaining

-- | Read at most the given number of bytes from an admitted request and
-- run the caller's strict decoder on them, all within the request's
-- same-process timeout.  The decoder's rejection is wrapped as
-- 'LengthFileDecodeRejected'; every other failure is the loader's own
-- sanitized class.  On Windows this fails closed with
-- 'LengthFilePlatformUnsupported'.
loadLengthFile
  :: Natural
  -> (ByteString -> Either decodeError value)
  -> LengthFileRequest
  -> IO (Either (LengthFileLoadError decodeError) value)
#ifdef mingw32_HOST_OS
loadLengthFile _ _ _ = pure $ Left $ LengthFileLoadError
  LengthFilePlatformUnsupported False
#else
loadLengthFile maximumBytes decoder
    (LengthFileRequest path timeoutMilliseconds) = do
  cleanupIncomplete <- newIORef False
  bounded <- timeout (timeoutMilliseconds * 1000)
    $ loadWithinDeadline cleanupIncomplete maximumBytes decoder path
  case bounded of
    Just result -> pure result
    Nothing -> do
      incomplete <- readIORef cleanupIncomplete
      pure $ Left $ LengthFileLoadError
        LengthFileDeadlineExceeded incomplete

loadWithinDeadline
  :: IORef Bool
  -> Natural
  -> (ByteString -> Either decodeError value)
  -> FilePath
  -> IO (Either (LengthFileLoadError decodeError) value)
loadWithinDeadline cleanupIncomplete maximumBytes decoder path =
  mask $ \restore -> do
    opened <- tryIOError $ openFd path ReadOnly acquisitionOpenFlags
    case opened of
      Left _ -> pure $ loadFailure LengthFileOpenFailed False
      Right descriptor -> do
        outcome <- restore (readFileWithin maximumBytes decoder descriptor)
          `onException` void (closeOwned cleanupIncomplete descriptor)
        closeIncomplete <- closeOwned cleanupIncomplete descriptor
        pure $ case outcome of
          Left primary -> Left $ LengthFileLoadError primary closeIncomplete
          Right _ | closeIncomplete -> loadFailure LengthFileCleanupFailed True
          Right value -> Right value

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

readFileWithin
  :: Natural
  -> (ByteString -> Either decodeError value)
  -> Fd
  -> IO (Either (LengthFileLoadErrorClass decodeError) value)
readFileWithin maximumBytes decoder descriptor = do
  inspected <- tryIOError $ getFdStatus descriptor
  case inspected of
    Left _ -> pure $ Left LengthFileInspectFailed
    Right status
      | not $ isRegularFile status -> pure $ Left LengthFileNotRegular
      | fileSize status > fromIntegral maximumBytes -> pure $ Left
          $ LengthFileByteLimitExceeded maximumBytes (maximumBytes + 1)
      | otherwise -> readChunks 0 []
 where
  readChunks !observed chunks = do
    let probeMaximum = maximumBytes + 1
        requested = min acquisitionChunkBytes $ probeMaximum - observed
    next <- tryIOError $ PosixByteString.fdRead descriptor
      $ fromIntegral requested
    case next of
      Left readFailure
        | isEOFError readFailure -> finish chunks
        | otherwise -> pure $ Left LengthFileReadFailed
      Right chunk
        | ByteString.null chunk -> finish chunks
        | otherwise ->
            let admitted = fromIntegral $ ByteString.length chunk
                following = observed + admitted
            in if following > maximumBytes
              then pure $ Left
                $ LengthFileByteLimitExceeded maximumBytes (maximumBytes + 1)
              else readChunks following (chunk : chunks)

  finish chunks = evaluate $ case decoder
      $ ByteString.concat $ reverse chunks of
    Left rejected -> Left $ LengthFileDecodeRejected rejected
    Right value -> Right value

acquisitionChunkBytes :: Natural
acquisitionChunkBytes = 32768

loadFailure
  :: LengthFileLoadErrorClass decodeError
  -> Bool
  -> Either (LengthFileLoadError decodeError) value
loadFailure primary incomplete = Left $ LengthFileLoadError primary incomplete
#endif
