-- | Explicit optional integration of finite-spine Length ranking.
--
-- This module owns the complete caller-facing transition from an explicitly
-- named configuration file to one reusable, activated ranking policy and the
-- file's fixed nominal domain selection and contract.  That selection is a
-- fixed startup choice for the process: every later verified batch is checked
-- against the same contract.  The current policy may finish from pure query-
-- owned evidence and otherwise gives the batch a fresh worker scope at its
-- first live miss.
-- This module also owns the disabled identity branch used by
-- Main.  Loading performs
-- bounded acquisition and closed activation only; no solver is launched until
-- the ranking policy actually requests its fresh lexical worker scope.
module Leant.Synth.Length.Integration
  ( LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationFileSource (..)
  , LengthAssessmentSetupError (..)
  , LengthAssessmentMode
  , disabledLengthAssessmentMode
  , loadLengthAssessmentMode
  , lengthAssessmentModeActivationPolicy
  , lengthAssessmentModeExecutableLaunchStrategy
  , LengthAssessmentRequestError (..)
  , ExplicitLengthAssessmentPermission
  , LengthAssessmentRequest
  , startupLengthAssessmentRequest
  , authorizeExplicitLengthAssessmentRequest
  , explicitLengthAssessmentRequest
  , explicitLengthAssessmentSelectionRequest
  , LengthAssessmentFailure (..)
  , LengthAssessmentResult
  , assessLengthVerificationBatch
  , assessLengthVerificationRequest
  , lengthAssessmentCandidates
  , lengthAssessmentRanking
  , lengthAssessmentSpinePairRanking
  , lengthAssessmentFailure
  , lengthAssessmentPostVerificationResult
  , lengthAssessmentSpinePairPostVerificationResult
  ) where

import Language.Haskell.Djex
  ( LengthSMTLibExecutableLaunchStrategy )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , assessVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  , lengthRankingPolicyExecutableLaunchStrategy
  )
import Leant.Synth.Length.Configuration.File
  ( LengthRankingConfigurationActivationError
  , LengthRankingConfigurationActivationPolicy (..)
  , activateLengthAssessmentConfiguration
  )
import Leant.Synth.Length.Configuration.File.Acquire
  ( LengthRankingConfigurationFileAdmissionError
  , LengthRankingConfigurationFileLoadError
  , LengthRankingConfigurationFileSource (..)
  , loadLengthAssessmentConfigurationFile
  , mkLengthRankingConfigurationFileRequest
  )
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure
  , LengthPostVerificationResult
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContract
  , LeanLengthContractSelection (..)
  )
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingFailure
  )
import Leant.Synth.Length.SpinePair.PostVerification
  ( LengthSpinePairPostVerificationFailure
  , LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationAdapterFailure
  , lengthSpinePairPostVerificationCandidates
  , lengthSpinePairPostVerificationRanking
  , lengthSpinePairPostVerificationRankingFailure
  )
import Leant.Synth.Length.SpinePair.Ranking
  ( LengthSpinePairRanking
  , LengthSpinePairRankingFailure
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
-- sealed, and explicitly activated fixed policy/contract pair.  The
-- constructor stays private so enabled values can arise only through the
-- complete setup path.
data LengthAssessmentMode
  = LengthAssessmentDisabled
  | LengthAssessmentConfigured
      !LengthRankingConfigurationActivationPolicy
      !LengthRankingPolicy
      LeanLengthContractSelection

-- | Closed refusal before a one-shot contract file may be touched.  An
-- explicit contract can reuse only a policy which passed startup activation;
-- the default disabled mode contains no execution authority to pair with it.
data LengthAssessmentRequestError
  = LengthAssessmentExplicitContractRequiresActivatedPolicy
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Opaque command-local permission retaining exactly the activated policy.
-- Main obtains this before contract-file admission or IO, then associates the
-- successfully decoded passive contract without projecting the policy.
data ExplicitLengthAssessmentPermission =
  ExplicitLengthAssessmentPermission !LengthRankingPolicy

-- | One command's exact assessment choice.  Both the startup-fixed path
-- and an explicit request enter the same enabled owner: one activated policy
-- beside one lazy contract.  The origin and lifetime of that passive contract
-- are not a second execution authority.  The disabled constructor preserves
-- the established non-strict identity path.
data LengthAssessmentRequest
  = LengthAssessmentRequestDisabled
  | LengthAssessmentEnabledRequest
      !LengthRankingPolicy
      LeanLengthContractSelection

disabledLengthAssessmentMode :: LengthAssessmentMode
disabledLengthAssessmentMode = LengthAssessmentDisabled

-- | Select the startup-fixed behavior without inspecting the configured
-- contract.  This is the exact no-option path.
startupLengthAssessmentRequest
  :: LengthAssessmentMode
  -> LengthAssessmentRequest
startupLengthAssessmentRequest mode = case mode of
  LengthAssessmentDisabled -> LengthAssessmentRequestDisabled
  LengthAssessmentConfigured _ policy selection ->
    LengthAssessmentEnabledRequest policy selection

-- | Authorize one explicit request before its path is admitted or read.
-- Matching a configured mode does not inspect its fixed startup contract; a
-- disabled mode fails without accepting a contract value.
authorizeExplicitLengthAssessmentRequest
  :: LengthAssessmentMode
  -> Either
      LengthAssessmentRequestError
      ExplicitLengthAssessmentPermission
authorizeExplicitLengthAssessmentRequest mode = case mode of
  LengthAssessmentDisabled -> Left
    LengthAssessmentExplicitContractRequiresActivatedPolicy
  LengthAssessmentConfigured _ policy _ -> Right
    $ ExplicitLengthAssessmentPermission policy

-- | Associate one successfully decoded passive contract with the exact
-- startup-activated policy.  The contract remains lazy and no IO occurs.
explicitLengthAssessmentRequest
  :: ExplicitLengthAssessmentPermission
  -> LeanLengthContract
  -> LengthAssessmentRequest
explicitLengthAssessmentRequest
    (ExplicitLengthAssessmentPermission policy) contract =
  LengthAssessmentEnabledRequest policy
    $ LeanLengthScalarContractSelection contract

-- | Associate one successfully decoded passive domain selection with the
-- exact startup-activated policy.  Main uses this domain-general entrance;
-- the scalar wrapper above remains available to callers which intentionally
-- accept only scalar contracts.
explicitLengthAssessmentSelectionRequest
  :: ExplicitLengthAssessmentPermission
  -> LeanLengthContractSelection
  -> LengthAssessmentRequest
explicitLengthAssessmentSelectionRequest
    (ExplicitLengthAssessmentPermission policy) selection =
  LengthAssessmentEnabledRequest policy selection

-- | The permission decision that actually released a configured mode.
-- This deliberately reports no executable path, digest bytes, or later
-- executable-match observation, and inspecting a configured policy does not
-- inspect the retained fixed contract.
lengthAssessmentModeActivationPolicy
  :: LengthAssessmentMode
  -> Maybe LengthRankingConfigurationActivationPolicy
lengthAssessmentModeActivationPolicy mode = case mode of
  LengthAssessmentDisabled -> Nothing
  LengthAssessmentConfigured activation _ _ -> Just activation

-- | Classify the closed executable-launch strategy retained by a configured
-- mode, including every descriptor-bound strategy, without exposing its
-- policy or inspecting the startup-fixed contract.  Disabled assessment owns
-- no solver-launch authority.
lengthAssessmentModeExecutableLaunchStrategy
  :: LengthAssessmentMode
  -> Maybe LengthSMTLibExecutableLaunchStrategy
lengthAssessmentModeExecutableLaunchStrategy mode = case mode of
  LengthAssessmentDisabled -> Nothing
  LengthAssessmentConfigured _ policy _ -> Just
    $ lengthRankingPolicyExecutableLaunchStrategy policy

-- | Admit and acquire exactly one caller-named file, then apply the explicit
-- pin policy.  Request admission happens before any IO.  Loading and activation
-- do not open a solver; the returned mode remains process-free.
loadLengthAssessmentMode
  :: LengthRankingConfigurationActivationPolicy
  -> LengthRankingConfigurationFileSource
  -> IO (Either LengthAssessmentSetupError LengthAssessmentMode)
loadLengthAssessmentMode activation source =
  case mkLengthRankingConfigurationFileRequest source of
    Left failure -> pure $ Left
      $ LengthAssessmentFileAdmissionRejected failure
    Right request -> do
      loaded <- loadLengthAssessmentConfigurationFile request
      pure $ case loaded of
        Left failure -> Left $ LengthAssessmentFileLoadRejected failure
        Right disabled -> case
            activateLengthAssessmentConfiguration activation disabled of
          Left failure -> Left $ LengthAssessmentActivationRejected failure
          Right (policy, selection) -> Right
            $ LengthAssessmentConfigured activation policy selection

-- | One sanitized reason why enabled ranking preserved callback order.
-- Candidate-local preparation refusal remains part of the ranking report and
-- is not inflated into a batch-wide failure here.
data LengthAssessmentFailure
  = LengthAssessmentPostVerificationFailed
      !LengthPostVerificationFailure
  | LengthAssessmentRankingFailed
      !LengthRankingFailure
  | LengthAssessmentSpinePairPostVerificationFailed
      !LengthSpinePairPostVerificationFailure
  | LengthAssessmentSpinePairRankingFailed
      !LengthSpinePairRankingFailure
  deriving (Eq, Ord, Show)

-- | Common result for disabled and configured post-verification paths.
-- The skipped branch deliberately retains its batch lazily so constructing the
-- disabled result performs no candidate traversal or other IO.
data LengthAssessmentResult
  = LengthAssessmentSkipped
      (VerificationBatch DetailedVerificationVariant)
  | LengthAssessmentCompleted !LengthPostVerificationResult
  | LengthAssessmentSpinePairCompleted
      !LengthSpinePairPostVerificationResult

-- | Preserve callback order without IO when disabled.  When configured, check
-- the exact verified batch against the startup-fixed contract through the
-- existing occurrence-sealed Length adapter.  The current policy opens its
-- fresh lexical worker only at the first live miss.
assessLengthVerificationBatch
  :: LengthAssessmentMode
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationBatch mode = assessLengthVerificationRequest
  $ startupLengthAssessmentRequest mode

-- | Assess one exact callback batch under the command-local contract choice.
-- Both contract lifetimes use the same occurrence-sealed policy runner.  The
-- disabled request retains the batch lazily and performs no IO.
assessLengthVerificationRequest
  :: LengthAssessmentRequest
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationRequest request verification = case request of
  LengthAssessmentRequestDisabled ->
    pure $ LengthAssessmentSkipped verification
  LengthAssessmentEnabledRequest policy selection -> case selection of
    LeanLengthScalarContractSelection contract ->
      LengthAssessmentCompleted <$>
        assessVerifiedLengthCandidatesWithPolicy policy contract verification
    LeanLengthSpinePairContractSelection contract ->
      LengthAssessmentSpinePairCompleted <$>
        assessVerifiedLengthSpinePairCandidatesWithPolicy
          policy contract verification

lengthAssessmentCandidates
  :: LengthAssessmentResult
  -> [Verified DetailedVerificationVariant]
lengthAssessmentCandidates result = case result of
  LengthAssessmentSkipped verification ->
    skipPostVerificationAssessment verification
  LengthAssessmentCompleted assessed ->
    lengthPostVerificationCandidates assessed
  LengthAssessmentSpinePairCompleted assessed ->
    lengthSpinePairPostVerificationCandidates assessed

-- | The receipt-associated scalar ranking after the occurrence seal.
-- Disabled assessment and rejected configured input have no ranking.  The
-- skipped branch deliberately does not inspect its retained batch, so callers
-- may decide whether semantic presentation is available without traversing a
-- disabled result.
lengthAssessmentRanking
  :: LengthAssessmentResult
  -> Maybe LengthRanking
lengthAssessmentRanking result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed ->
    lengthPostVerificationRanking assessed
  LengthAssessmentSpinePairCompleted _ -> Nothing

-- | The product-domain ranking after the occurrence seal.  Scalar and
-- disabled assessments have no product ranking.
lengthAssessmentSpinePairRanking
  :: LengthAssessmentResult
  -> Maybe LengthSpinePairRanking
lengthAssessmentSpinePairRanking result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted _ -> Nothing
  LengthAssessmentSpinePairCompleted assessed ->
    lengthSpinePairPostVerificationRanking assessed

lengthAssessmentPostVerificationResult
  :: LengthAssessmentResult
  -> Maybe LengthPostVerificationResult
lengthAssessmentPostVerificationResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed -> Just assessed
  LengthAssessmentSpinePairCompleted _ -> Nothing

lengthAssessmentSpinePairPostVerificationResult
  :: LengthAssessmentResult
  -> Maybe LengthSpinePairPostVerificationResult
lengthAssessmentSpinePairPostVerificationResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted _ -> Nothing
  LengthAssessmentSpinePairCompleted assessed -> Just assessed

lengthAssessmentFailure
  :: LengthAssessmentResult
  -> Maybe LengthAssessmentFailure
lengthAssessmentFailure result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed -> case
      lengthPostVerificationAdapterFailure assessed of
    Just failure -> Just $ LengthAssessmentPostVerificationFailed failure
    Nothing -> case lengthPostVerificationRankingFailure assessed of
      Nothing -> Nothing
      Just failure -> Just $ LengthAssessmentRankingFailed failure
  LengthAssessmentSpinePairCompleted assessed -> case
      lengthSpinePairPostVerificationAdapterFailure assessed of
    Just failure -> Just
      $ LengthAssessmentSpinePairPostVerificationFailed failure
    Nothing -> case lengthSpinePairPostVerificationRankingFailure assessed of
      Nothing -> Nothing
      Just failure -> Just $ LengthAssessmentSpinePairRankingFailed failure
