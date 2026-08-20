-- | Bounded acquisition of one explicit one-shot Length contract file.
--
-- Admission and transport reuse the same single-owner descriptor boundary as
-- the versionless startup configuration file.  This facade exposes only
-- contract-file vocabulary and can never decode or retain execution policy.
module Leant.Synth.Length.Contract.File.Acquire
  ( lengthContractFileDefaultTimeoutMilliseconds
  , lengthContractFileMaximumPathCharacters
  , lengthContractFileMaximumTimeoutMilliseconds
  , lengthContractFileLoadMaximumBytes
  , LengthContractFileSource (..)
  , LengthContractFileAdmissionError (..)
  , LengthContractFileRequest
  , LengthContractFileLoadErrorClass (..)
  , LengthContractFileLoadError
  , mkLengthContractFileRequest
  , loadLengthContractFile
  , lengthContractFileLoadErrorClass
  , lengthContractFileLoadCleanupIncomplete
  ) where

import Numeric.Natural (Natural)

import Leant.Json.Bounded (BoundedJsonLimits (..))
import Leant.Synth.Length.Contract (LeanLengthContractSelection)
import Leant.Synth.Length.Contract.File
  ( LengthContractFileError
  , decodeLengthContractFile
  , lengthContractFileJsonLimits
  )
import Leant.Synth.Length.File.Acquire
  ( LengthFileAdmissionError (..)
  , LengthFileLoadError
  , LengthFileLoadErrorClass (..)
  , LengthFileRequest
  , LengthFileSource (..)
  , lengthFileLoadCleanupIncomplete
  , lengthFileLoadErrorClass
  , lengthFileMaximumPathCharacters
  , lengthFileMaximumTimeoutMilliseconds
  , loadLengthFile
  , mkLengthFileRequest
  )

-- | Timeout a caller uses for a one-shot contract load when it supplies
-- none of its own.
lengthContractFileDefaultTimeoutMilliseconds :: Int
lengthContractFileDefaultTimeoutMilliseconds = 5000

-- | The shared file boundary's path-length ceiling, restated in
-- contract-file vocabulary.
lengthContractFileMaximumPathCharacters :: Natural
lengthContractFileMaximumPathCharacters = lengthFileMaximumPathCharacters

-- | The shared file boundary's timeout ceiling, restated in contract-file
-- vocabulary.
lengthContractFileMaximumTimeoutMilliseconds :: Int
lengthContractFileMaximumTimeoutMilliseconds =
  lengthFileMaximumTimeoutMilliseconds

-- | Most bytes one contract file may occupy: exactly the bounded JSON
-- grammar's total-byte limit, so acquisition never reads a document the
-- decoder would refuse for size.
lengthContractFileLoadMaximumBytes :: Natural
lengthContractFileLoadMaximumBytes =
  boundedJsonMaximumTotalBytes lengthContractFileJsonLimits

-- | Raw one-shot input.  Both fields remain lazy so path admission wins before
-- timeout demand and no file operation occurs during construction.
data LengthContractFileSource = LengthContractFileSource
  { lengthContractFileSourcePath :: FilePath
  , lengthContractFileSourceTimeoutMilliseconds :: Int
  }

-- | Pure refusal of one 'LengthContractFileSource', in the shared
-- boundary's admission order (path length, empty path, embedded NUL,
-- relative path, non-positive timeout, timeout above the ceiling); limit
-- refusals carry the maximum and the observed count capped at maximum plus
-- one.
data LengthContractFileAdmissionError
  = LengthContractFilePathCharacterLimitExceeded !Natural !Natural
  | LengthContractFilePathEmpty
  | LengthContractFilePathContainsNul
  | LengthContractFilePathNotAbsolute
  | LengthContractFileTimeoutNotPositive
  | LengthContractFileTimeoutLimitExceeded !Int !Int
  deriving (Eq, Ord, Show)

-- | Opaque admitted contract-file request.  Its strict generic request fixes
-- the finite path and timeout without exposing either value again.
data LengthContractFileRequest =
  LengthContractFileRequest !LengthFileRequest

-- | Sanitized primary reason one contract load failed; the shared
-- boundary's classes restated one-for-one, with the decoder's rejection
-- carried as 'LengthContractFileDecodeRejected'.
data LengthContractFileLoadErrorClass
  = LengthContractFilePlatformUnsupported
  | LengthContractFileOpenFailed
  | LengthContractFileInspectFailed
  | LengthContractFileNotRegular
  | LengthContractFileReadFailed
  | LengthContractFileByteLimitExceeded !Natural !Natural
  | LengthContractFileDecodeRejected !LengthContractFileError
  | LengthContractFileDeadlineExceeded
  | LengthContractFileCleanupFailed
  deriving (Eq, Ord, Show)

-- | One contract load failure: its primary class plus whether descriptor
-- cleanup was left incomplete.
data LengthContractFileLoadError = LengthContractFileLoadError
  !LengthContractFileLoadErrorClass
  !Bool
  deriving (Eq, Ord, Show)

-- | The primary failure class.
lengthContractFileLoadErrorClass
  :: LengthContractFileLoadError
  -> LengthContractFileLoadErrorClass
lengthContractFileLoadErrorClass
    (LengthContractFileLoadError failure _) = failure

-- | Whether the opened descriptor could not be closed before the failure
-- was returned.
lengthContractFileLoadCleanupIncomplete
  :: LengthContractFileLoadError
  -> Bool
lengthContractFileLoadCleanupIncomplete
    (LengthContractFileLoadError _ incomplete) = incomplete

-- | Admit a one-shot source through the shared boundary without IO,
-- reporting refusals in contract-file vocabulary.
mkLengthContractFileRequest
  :: LengthContractFileSource
  -> Either LengthContractFileAdmissionError LengthContractFileRequest
mkLengthContractFileRequest source =
  case mkLengthFileRequest $ LengthFileSource
      (lengthContractFileSourcePath source)
      (lengthContractFileSourceTimeoutMilliseconds source) of
    Left failure -> Left $ mapAdmissionError failure
    Right request -> Right $ LengthContractFileRequest request

-- | Read and decode one admitted contract file within its timeout, yielding
-- the passive scalar-or-product contract selection; the loader's and the
-- decoder's refusals are both returned in contract-file vocabulary.
loadLengthContractFile
  :: LengthContractFileRequest
  -> IO (Either LengthContractFileLoadError LeanLengthContractSelection)
loadLengthContractFile (LengthContractFileRequest request) = do
  loaded <- loadLengthFile lengthContractFileLoadMaximumBytes
    decodeLengthContractFile request
  pure $ case loaded of
    Left failure -> Left $ mapLoadError failure
    Right selection -> Right selection

mapAdmissionError
  :: LengthFileAdmissionError
  -> LengthContractFileAdmissionError
mapAdmissionError failure = case failure of
  LengthFilePathCharacterLimitExceeded maximumValue observed ->
    LengthContractFilePathCharacterLimitExceeded maximumValue observed
  LengthFilePathEmpty -> LengthContractFilePathEmpty
  LengthFilePathContainsNul -> LengthContractFilePathContainsNul
  LengthFilePathNotAbsolute -> LengthContractFilePathNotAbsolute
  LengthFileTimeoutNotPositive -> LengthContractFileTimeoutNotPositive
  LengthFileTimeoutLimitExceeded maximumValue observed ->
    LengthContractFileTimeoutLimitExceeded maximumValue observed

mapLoadError
  :: LengthFileLoadError LengthContractFileError
  -> LengthContractFileLoadError
mapLoadError failure = LengthContractFileLoadError
  (case lengthFileLoadErrorClass failure of
    LengthFilePlatformUnsupported -> LengthContractFilePlatformUnsupported
    LengthFileOpenFailed -> LengthContractFileOpenFailed
    LengthFileInspectFailed -> LengthContractFileInspectFailed
    LengthFileNotRegular -> LengthContractFileNotRegular
    LengthFileReadFailed -> LengthContractFileReadFailed
    LengthFileByteLimitExceeded maximumValue observed ->
      LengthContractFileByteLimitExceeded maximumValue observed
    LengthFileDecodeRejected rejected ->
      LengthContractFileDecodeRejected rejected
    LengthFileDeadlineExceeded -> LengthContractFileDeadlineExceeded
    LengthFileCleanupFailed -> LengthContractFileCleanupFailed)
  (lengthFileLoadCleanupIncomplete failure)
