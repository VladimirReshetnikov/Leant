-- | Explicit optional integration of finite-list-spine Length ranking.
--
-- This module owns the complete caller-facing transition from an explicitly
-- named configuration file to one reusable, activated ranking policy and the
-- file's fixed compatibility contract.  The configuration file's embedded
-- compatibility contract is a fixed startup choice for the process: every
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
  , lengthAssessmentModeActivationPolicy
  , LengthAssessmentRequestError (..)
  , ExplicitLengthAssessmentPermission
  , LengthAssessmentRequest
  , compatibilityLengthAssessmentRequest
  , authorizeExplicitLengthAssessmentRequest
  , explicitLengthAssessmentRequest
  , LengthAssessmentFailure (..)
  , LengthAssessmentResult
  , assessLengthVerificationBatch
  , assessLengthVerificationRequest
  , lengthAssessmentCandidates
  , lengthAssessmentRanking
  , lengthAssessmentFailure
  , lengthAssessmentPostVerificationResult
  ) where

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , assessVerifiedLengthCandidatesWithPolicy
  )
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
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingFailure
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
      LeanLengthContract

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

-- | One command's exact assessment choice.  Both the fixed compatibility path
-- and an explicit request enter the same enabled owner: one activated policy
-- beside one lazy contract.  The origin and lifetime of that passive contract
-- are not a second execution authority.  The disabled constructor preserves
-- the established non-strict identity path.
data LengthAssessmentRequest
  = LengthAssessmentRequestDisabled
  | LengthAssessmentEnabledRequest
      !LengthRankingPolicy
      LeanLengthContract

disabledLengthAssessmentMode :: LengthAssessmentMode
disabledLengthAssessmentMode = LengthAssessmentDisabled

-- | Select the established startup-fixed compatibility behavior without
-- inspecting the configured contract.  This is the exact no-option path.
compatibilityLengthAssessmentRequest
  :: LengthAssessmentMode
  -> LengthAssessmentRequest
compatibilityLengthAssessmentRequest mode = case mode of
  LengthAssessmentDisabled -> LengthAssessmentRequestDisabled
  LengthAssessmentConfigured _ policy contract ->
    LengthAssessmentEnabledRequest policy contract

-- | Authorize one explicit request before its path is admitted or read.
-- Matching a configured mode does not inspect its fixed compatibility
-- contract; a disabled mode fails without accepting a contract value.
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
  LengthAssessmentEnabledRequest policy contract

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
      loaded <- loadLengthRankingConfigurationFile request
      pure $ case loaded of
        Left failure -> Left $ LengthAssessmentFileLoadRejected failure
        Right disabled -> case
            activateLengthRankingConfiguration activation disabled of
          Left failure -> Left $ LengthAssessmentActivationRejected failure
          Right (policy, contract) -> Right
            $ LengthAssessmentConfigured activation policy contract

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
assessLengthVerificationBatch mode = assessLengthVerificationRequest
  $ compatibilityLengthAssessmentRequest mode

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
  LengthAssessmentEnabledRequest policy contract ->
    LengthAssessmentCompleted <$>
      assessVerifiedLengthCandidatesWithPolicy policy contract verification

lengthAssessmentCandidates
  :: LengthAssessmentResult
  -> [Verified DetailedVerificationVariant]
lengthAssessmentCandidates result = case result of
  LengthAssessmentSkipped verification ->
    skipPostVerificationAssessment verification
  LengthAssessmentCompleted assessed ->
    lengthPostVerificationCandidates assessed

-- | The receipt-associated compatibility ranking after the occurrence seal.
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
    Nothing -> case lengthPostVerificationRankingFailure assessed of
      Nothing -> Nothing
      Just failure -> Just $ LengthAssessmentRankingFailed failure
