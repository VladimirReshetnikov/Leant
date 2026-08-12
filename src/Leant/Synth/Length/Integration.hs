-- | Explicit optional integration of finite-list-spine Length ranking.
--
-- This module owns the complete caller-facing transition from an explicitly
-- named configuration file to one reusable, activated ranking configuration.
-- The v1 file's contract is a fixed startup choice for the process: every
-- later verified batch is checked against that same contract, while every
-- eligible batch still gets a fresh worker scope.  This module also owns the
-- disabled identity branch used by Main.  Loading performs
-- bounded acquisition and closed activation only; no solver is launched until
-- an eligible verified batch is assessed, and every such batch still receives
-- a fresh lexical worker scope from the ranking layer.
module Leant.Synth.Length.Integration
  ( LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationFileSource (..)
  , LengthAssessmentSetupError (..)
  , LengthAssessmentMode
  , disabledLengthAssessmentMode
  , loadLengthAssessmentMode
  , lengthAssessmentModeEnabled
  , LengthAssessmentFailure (..)
  , LengthAssessmentResult
  , assessLengthVerificationBatch
  , lengthAssessmentCandidates
  , lengthAssessmentFailure
  , lengthAssessmentPostVerificationResult
  ) where

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingConfiguration )
import Leant.Synth.Length.Configuration.File
  ( LengthRankingConfigurationActivationError
  , LengthRankingConfigurationActivationPolicy (..)
  , activateLengthRankingConfiguration
  )
import Leant.Synth.Length.Configuration.File.Acquire
  ( LengthRankingConfigurationFileAdmissionError
  , LengthRankingConfigurationFileLoadError
  , LengthRankingConfigurationFileSource (..)
  , loadLengthRankingConfigurationFile
  , mkLengthRankingConfigurationFileRequest
  )
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure
  , LengthPostVerificationResult
  , assessVerifiedLengthCandidatesConfigured
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  )
import Leant.Synth.Length.Ranking
  ( LengthRankingFailure
  , lengthRankingFailure
  )
import Leant.Synth.PostVerification
  ( skipPostVerificationAssessment )
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  )

-- | Sanitized setup failure in exact admission, acquisition, activation order.
-- None of these constructors retains the configuration path, file bytes,
-- executable path, digest, contract names, or operating-system diagnostics.
data LengthAssessmentSetupError
  = LengthAssessmentFileAdmissionRejected
      !LengthRankingConfigurationFileAdmissionError
  | LengthAssessmentFileLoadRejected
      !LengthRankingConfigurationFileLoadError
  | LengthAssessmentActivationRejected
      !LengthRankingConfigurationActivationError
  deriving (Eq, Ord, Show)

-- | Either the established non-IO identity seam or one already decoded,
-- sealed, and explicitly activated fixed-contract configuration.  The
-- constructor stays private so enabled values can arise only through the
-- complete setup path.
data LengthAssessmentMode
  = LengthAssessmentDisabled
  | LengthAssessmentConfigured !LengthRankingConfiguration

disabledLengthAssessmentMode :: LengthAssessmentMode
disabledLengthAssessmentMode = LengthAssessmentDisabled

lengthAssessmentModeEnabled :: LengthAssessmentMode -> Bool
lengthAssessmentModeEnabled mode = case mode of
  LengthAssessmentDisabled -> False
  LengthAssessmentConfigured _ -> True

-- | Admit and acquire exactly one caller-named file, then apply the explicit
-- pin policy.  Request admission happens before any IO.  Loading and activation
-- do not open a solver; the returned configuration remains process-free.
loadLengthAssessmentMode
  :: LengthRankingConfigurationActivationPolicy
  -> LengthRankingConfigurationFileSource
  -> IO (Either LengthAssessmentSetupError LengthAssessmentMode)
loadLengthAssessmentMode activation source =
  case mkLengthRankingConfigurationFileRequest source of
    Left failure -> pure $ Left
      $ LengthAssessmentFileAdmissionRejected failure
    Right request -> do
      loaded <- loadLengthRankingConfigurationFile request
      pure $ case loaded of
        Left failure -> Left $ LengthAssessmentFileLoadRejected failure
        Right disabled -> case
            activateLengthRankingConfiguration activation disabled of
          Left failure -> Left $ LengthAssessmentActivationRejected failure
          Right configuration -> Right
            $ LengthAssessmentConfigured configuration

-- | One sanitized reason why enabled ranking preserved callback order.
-- Candidate-local preparation refusal remains part of the ranking report and
-- is not inflated into a batch-wide failure here.
data LengthAssessmentFailure
  = LengthAssessmentPostVerificationFailed
      !LengthPostVerificationFailure
  | LengthAssessmentRankingFailed
      !LengthRankingFailure
  deriving (Eq, Ord, Show)

-- | Common result for disabled and configured post-verification paths.
-- The skipped branch deliberately retains its batch lazily so constructing the
-- disabled result performs no candidate traversal or other IO.
data LengthAssessmentResult
  = LengthAssessmentSkipped
      (VerificationBatch DetailedVerificationVariant)
  | LengthAssessmentCompleted !LengthPostVerificationResult

-- | Preserve callback order without IO when disabled.  When configured, check
-- the exact verified batch against the startup-fixed contract through the
-- existing occurrence-sealed Length adapter.  Its ranking layer opens a fresh
-- lexical worker only if pure preparation produced an eligible query.
assessLengthVerificationBatch
  :: LengthAssessmentMode
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationBatch mode verification = case mode of
  LengthAssessmentDisabled -> pure $ LengthAssessmentSkipped verification
  LengthAssessmentConfigured configuration -> LengthAssessmentCompleted <$>
    assessVerifiedLengthCandidatesConfigured configuration verification

lengthAssessmentCandidates
  :: LengthAssessmentResult
  -> [Verified DetailedVerificationVariant]
lengthAssessmentCandidates result = case result of
  LengthAssessmentSkipped verification ->
    skipPostVerificationAssessment verification
  LengthAssessmentCompleted assessed ->
    lengthPostVerificationCandidates assessed

lengthAssessmentPostVerificationResult
  :: LengthAssessmentResult
  -> Maybe LengthPostVerificationResult
lengthAssessmentPostVerificationResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed -> Just assessed

lengthAssessmentFailure
  :: LengthAssessmentResult
  -> Maybe LengthAssessmentFailure
lengthAssessmentFailure result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed -> case
      lengthPostVerificationAdapterFailure assessed of
    Just failure -> Just $ LengthAssessmentPostVerificationFailed failure
    Nothing -> case lengthPostVerificationRanking assessed >>= lengthRankingFailure of
      Nothing -> Nothing
      Just failure -> Just $ LengthAssessmentRankingFailed failure
