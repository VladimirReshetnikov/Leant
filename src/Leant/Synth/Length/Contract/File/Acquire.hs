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

lengthContractFileDefaultTimeoutMilliseconds :: Int
lengthContractFileDefaultTimeoutMilliseconds = 5000

lengthContractFileMaximumPathCharacters :: Natural
lengthContractFileMaximumPathCharacters = lengthFileMaximumPathCharacters

lengthContractFileMaximumTimeoutMilliseconds :: Int
lengthContractFileMaximumTimeoutMilliseconds =
  lengthFileMaximumTimeoutMilliseconds

lengthContractFileLoadMaximumBytes :: Natural
lengthContractFileLoadMaximumBytes =
  boundedJsonMaximumTotalBytes lengthContractFileJsonLimits

-- | Raw one-shot input.  Both fields remain lazy so path admission wins before
-- timeout demand and no file operation occurs during construction.
data LengthContractFileSource = LengthContractFileSource
  { lengthContractFileSourcePath :: FilePath
  , lengthContractFileSourceTimeoutMilliseconds :: Int
  }

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

data LengthContractFileLoadError = LengthContractFileLoadError
  !LengthContractFileLoadErrorClass
  !Bool
  deriving (Eq, Ord, Show)

lengthContractFileLoadErrorClass
  :: LengthContractFileLoadError
  -> LengthContractFileLoadErrorClass
lengthContractFileLoadErrorClass
    (LengthContractFileLoadError failure _) = failure

lengthContractFileLoadCleanupIncomplete
  :: LengthContractFileLoadError
  -> Bool
lengthContractFileLoadCleanupIncomplete
    (LengthContractFileLoadError _ incomplete) = incomplete

mkLengthContractFileRequest
  :: LengthContractFileSource
  -> Either LengthContractFileAdmissionError LengthContractFileRequest
mkLengthContractFileRequest source =
  case mkLengthFileRequest $ LengthFileSource
      (lengthContractFileSourcePath source)
      (lengthContractFileSourceTimeoutMilliseconds source) of
    Left failure -> Left $ mapAdmissionError failure
    Right request -> Right $ LengthContractFileRequest request

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
