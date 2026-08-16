-- | Bounded acquisition of one explicitly named Length-ranking policy file.
--
-- This configuration-specific boundary delegates path, descriptor, byte,
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
  , loadLengthAssessmentConfigurationFile
  , lengthRankingConfigurationFileLoadErrorClass
  , lengthRankingConfigurationFileLoadCleanupIncomplete
  ) where

import Numeric.Natural (Natural)

import Leant.Json.Bounded (BoundedJsonLimits (..))
import Leant.Synth.Length.Configuration.File
  ( DisabledLengthAssessmentConfiguration
  , LengthRankingConfigurationFileError
  , decodeLengthAssessmentConfigurationFile
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

-- | The shared file boundary's path-length ceiling, restated in
-- configuration-file vocabulary.
lengthRankingConfigurationFileMaximumPathCharacters :: Natural
lengthRankingConfigurationFileMaximumPathCharacters =
  lengthFileMaximumPathCharacters

-- | The shared file boundary's timeout ceiling, restated in
-- configuration-file vocabulary.
lengthRankingConfigurationFileMaximumTimeoutMilliseconds :: Int
lengthRankingConfigurationFileMaximumTimeoutMilliseconds =
  lengthFileMaximumTimeoutMilliseconds

-- | Most bytes one startup file may occupy: exactly the bounded JSON
-- grammar's total-byte limit, so acquisition never reads a document the
-- decoder would refuse for size.
lengthRankingConfigurationFileLoadMaximumBytes :: Natural
lengthRankingConfigurationFileLoadMaximumBytes =
  boundedJsonMaximumTotalBytes lengthRankingConfigurationFileJsonLimits

-- | Raw startup input.  Both fields remain lazy so productive path
-- admission wins before timeout demand, exactly as at the shared boundary.
data LengthRankingConfigurationFileSource =
  LengthRankingConfigurationFileSource
    { lengthRankingConfigurationFileSourcePath :: FilePath
    , lengthRankingConfigurationFileSourceTimeoutMilliseconds :: Int
    }

-- | Pure refusal of one 'LengthRankingConfigurationFileSource', in the
-- shared boundary's admission order (path length, empty path, embedded
-- NUL, relative path, non-positive timeout, timeout above the ceiling);
-- limit refusals carry the maximum and the observed count capped at
-- maximum plus one.
data LengthRankingConfigurationFileAdmissionError
  = LengthRankingConfigurationFilePathCharacterLimitExceeded
      !Natural !Natural
  | LengthRankingConfigurationFilePathEmpty
  | LengthRankingConfigurationFilePathContainsNul
  | LengthRankingConfigurationFilePathNotAbsolute
  | LengthRankingConfigurationFileTimeoutNotPositive
  | LengthRankingConfigurationFileTimeoutLimitExceeded !Int !Int
  deriving (Eq, Ord, Show)

-- | Opaque admitted configuration-file request.  The strict retained generic
-- request preserves the former finite-path and finite-timeout demand point.
data LengthRankingConfigurationFileRequest =
  LengthRankingConfigurationFileRequest !LengthFileRequest

-- | Sanitized primary reason one startup-file load failed; the shared
-- boundary's classes restated one-for-one, with the decoder's rejection
-- carried as 'LengthRankingConfigurationFileDecodeRejected'.
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

-- | One startup-file load failure: its primary class plus whether
-- descriptor cleanup was left incomplete.
data LengthRankingConfigurationFileLoadError =
  LengthRankingConfigurationFileLoadError
    !LengthRankingConfigurationFileLoadErrorClass
    !Bool
  deriving (Eq, Ord, Show)

-- | The primary failure class.
lengthRankingConfigurationFileLoadErrorClass
  :: LengthRankingConfigurationFileLoadError
  -> LengthRankingConfigurationFileLoadErrorClass
lengthRankingConfigurationFileLoadErrorClass
    (LengthRankingConfigurationFileLoadError failure _) = failure

-- | Whether the opened descriptor could not be closed before the failure
-- was returned.
lengthRankingConfigurationFileLoadCleanupIncomplete
  :: LengthRankingConfigurationFileLoadError
  -> Bool
lengthRankingConfigurationFileLoadCleanupIncomplete
    (LengthRankingConfigurationFileLoadError _ incomplete) = incomplete

-- | Admit a startup source through the shared boundary without IO,
-- reporting refusals in configuration-file vocabulary.
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

-- | Load the scalar-or-product startup selection through the admitted request
-- and shared bounded acquisition boundary.
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
