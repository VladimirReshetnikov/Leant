-- | Bounded acquisition of one explicitly named Length-ranking policy file.
--
-- This compatibility facade preserves the established configuration-specific
-- API and failure vocabulary while delegating path, descriptor, byte,
-- interruption, and cleanup ownership to the shared Length file boundary.
-- The final path component is no-follow on POSIX; Windows fails closed.
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
  , loadLengthAssessmentConfigurationFile
  , lengthRankingConfigurationFileLoadErrorClass
  , lengthRankingConfigurationFileLoadCleanupIncomplete
  ) where

import Numeric.Natural (Natural)

import Leant.Json.Bounded (BoundedJsonLimits (..))
import Leant.Synth.Length.Configuration.File
  ( DisabledLengthRankingConfiguration
  , DisabledLengthAssessmentConfiguration
  , LengthRankingConfigurationFileError
  , decodeLengthAssessmentConfigurationFile
  , decodeLengthRankingConfigurationFile
  , lengthRankingConfigurationFileJsonLimits
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

lengthRankingConfigurationFileMaximumPathCharacters :: Natural
lengthRankingConfigurationFileMaximumPathCharacters =
  lengthFileMaximumPathCharacters

lengthRankingConfigurationFileMaximumTimeoutMilliseconds :: Int
lengthRankingConfigurationFileMaximumTimeoutMilliseconds =
  lengthFileMaximumTimeoutMilliseconds

lengthRankingConfigurationFileLoadMaximumBytes :: Natural
lengthRankingConfigurationFileLoadMaximumBytes =
  boundedJsonMaximumTotalBytes lengthRankingConfigurationFileJsonLimits

-- | Raw compatibility input.  Both fields remain lazy so productive path
-- admission wins before timeout demand, exactly as at the shared boundary.
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

-- | Opaque admitted compatibility-file request.  The strict retained generic
-- request preserves the former finite-path and finite-timeout demand point.
data LengthRankingConfigurationFileRequest =
  LengthRankingConfigurationFileRequest !LengthFileRequest

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

mkLengthRankingConfigurationFileRequest
  :: LengthRankingConfigurationFileSource
  -> Either
      LengthRankingConfigurationFileAdmissionError
      LengthRankingConfigurationFileRequest
mkLengthRankingConfigurationFileRequest source =
  case mkLengthFileRequest $ LengthFileSource
      (lengthRankingConfigurationFileSourcePath source)
      (lengthRankingConfigurationFileSourceTimeoutMilliseconds source) of
    Left failure -> Left $ mapAdmissionError failure
    Right request -> Right $ LengthRankingConfigurationFileRequest request

loadLengthRankingConfigurationFile
  :: LengthRankingConfigurationFileRequest
  -> IO
      (Either
        LengthRankingConfigurationFileLoadError
        DisabledLengthRankingConfiguration)
loadLengthRankingConfigurationFile
    (LengthRankingConfigurationFileRequest request) = do
  loaded <- loadLengthFile
    lengthRankingConfigurationFileLoadMaximumBytes
    decodeLengthRankingConfigurationFile
    request
  pure $ case loaded of
    Left failure -> Left $ mapLoadError failure
    Right value -> Right value

-- | Load the additive scalar-or-product startup selection through the exact
-- same admitted request and acquisition boundary as the scalar facade.
loadLengthAssessmentConfigurationFile
  :: LengthRankingConfigurationFileRequest
  -> IO
      (Either
        LengthRankingConfigurationFileLoadError
        DisabledLengthAssessmentConfiguration)
loadLengthAssessmentConfigurationFile
    (LengthRankingConfigurationFileRequest request) = do
  loaded <- loadLengthFile
    lengthRankingConfigurationFileLoadMaximumBytes
    decodeLengthAssessmentConfigurationFile
    request
  pure $ case loaded of
    Left failure -> Left $ mapLoadError failure
    Right value -> Right value

mapAdmissionError
  :: LengthFileAdmissionError
  -> LengthRankingConfigurationFileAdmissionError
mapAdmissionError failure = case failure of
  LengthFilePathCharacterLimitExceeded maximumValue observed ->
    LengthRankingConfigurationFilePathCharacterLimitExceeded
      maximumValue observed
  LengthFilePathEmpty -> LengthRankingConfigurationFilePathEmpty
  LengthFilePathContainsNul ->
    LengthRankingConfigurationFilePathContainsNul
  LengthFilePathNotAbsolute ->
    LengthRankingConfigurationFilePathNotAbsolute
  LengthFileTimeoutNotPositive ->
    LengthRankingConfigurationFileTimeoutNotPositive
  LengthFileTimeoutLimitExceeded maximumValue observed ->
    LengthRankingConfigurationFileTimeoutLimitExceeded
      maximumValue observed

mapLoadError
  :: LengthFileLoadError LengthRankingConfigurationFileError
  -> LengthRankingConfigurationFileLoadError
mapLoadError failure = LengthRankingConfigurationFileLoadError
  (case lengthFileLoadErrorClass failure of
    LengthFilePlatformUnsupported ->
      LengthRankingConfigurationFilePlatformUnsupported
    LengthFileOpenFailed -> LengthRankingConfigurationFileOpenFailed
    LengthFileInspectFailed -> LengthRankingConfigurationFileInspectFailed
    LengthFileNotRegular -> LengthRankingConfigurationFileNotRegular
    LengthFileReadFailed -> LengthRankingConfigurationFileReadFailed
    LengthFileByteLimitExceeded maximumValue observed ->
      LengthRankingConfigurationFileByteLimitExceeded maximumValue observed
    LengthFileDecodeRejected rejected ->
      LengthRankingConfigurationFileDecodeRejected rejected
    LengthFileDeadlineExceeded ->
      LengthRankingConfigurationFileDeadlineExceeded
    LengthFileCleanupFailed -> LengthRankingConfigurationFileCleanupFailed)
  (lengthFileLoadCleanupIncomplete failure)
