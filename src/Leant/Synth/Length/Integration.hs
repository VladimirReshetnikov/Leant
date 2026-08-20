{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Explicit optional integration of finite-spine Length ranking and
-- replay-authorized hard filtering.
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
  , lengthAssessmentRequestBehaviorMode
  , startupLengthAssessmentRequest
  , authorizeExplicitLengthAssessmentRequest
  , explicitLengthAssessmentRequest
  , LengthAssessmentContext
  , withLengthAssessmentRequestContext
  , lengthAssessmentContextBehaviorMode
  , LengthAssessmentFailure (..)
  , LengthAssessmentResult
  , assessLengthVerificationBatch
  , assessLengthVerificationRequest
  , assessLengthVerificationContext
  , lengthAssessmentCandidates
  , lengthAssessmentRanking
  , lengthAssessmentSpinePairRanking
  , lengthAssessmentFailure
  , lengthAssessmentPostVerificationResult
  , lengthAssessmentSpinePairPostVerificationResult
  , lengthAssessmentSelectionResult
  , lengthAssessmentSpinePairSelectionResult
  ) where

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthSMTLibExecutableLaunchStrategy
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Command (LengthBehaviorMode (..))
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
  , LeanLengthSpinePairContract
  )
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingFailure
  )
import Leant.Synth.Length.Selection
  ( LengthSelectionFailure
  , LengthSelectionResult
  , lengthSelectionCandidates
  , lengthSelectionFailure
  )
import Leant.Synth.Length.Selection.Internal
  ( selectVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext )
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
import Leant.Synth.Length.SpinePair.Selection
  ( LengthSpinePairSelectionFailure
  , LengthSpinePairSelectionResult
  , lengthSpinePairSelectionCandidates
  , lengthSpinePairSelectionFailure
  )
import Leant.Synth.Length.SpinePair.Selection.Internal
  ( selectVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext )
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
  | LengthAssessmentFilteringRequiresActivatedPolicy
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Opaque command-local permission retaining both the parsed behavior
-- authority and exactly the activated policy.  Main obtains this before
-- contract-file admission or IO, then associates the successfully decoded
-- passive contract without projecting either field.
data ExplicitLengthAssessmentPermission =
  ExplicitLengthAssessmentPermission
    !LengthBehaviorMode
    !LengthRankingPolicy

-- | One command's exact assessment choice.  Both the startup-fixed path and
-- an explicit request enter the same enabled owner: the parsed behavior
-- authority, one activated policy, and one lazy contract.  The origin and
-- lifetime of that passive contract are not a second execution authority.
-- The disabled constructor is reachable only for ranking and preserves the
-- established non-strict identity path.
data LengthAssessmentRequest
  = LengthAssessmentRequestDisabled
  | LengthAssessmentEnabledRequest
      !LengthBehaviorMode
      !LengthRankingPolicy
      LeanLengthContractSelection

-- | One command-local assessment owner.  Ranking contexts deliberately carry
-- no bank, while each filter context owns exactly one nominal mutable bank for
-- every batch assessed through that same context.  Contract fields remain lazy
-- so behavior classification never demands their contents.
data LengthAssessmentContext command
  = LengthAssessmentDisabledContext
  | LengthAssessmentScalarRankingContext
      !LengthRankingPolicy
      LeanLengthContract
  | LengthAssessmentSpinePairRankingContext
      !LengthRankingPolicy
      LeanLengthSpinePairContract
  | LengthAssessmentScalarFilteringContext
      !LengthRankingPolicy
      LeanLengthContract
      !(CounterexampleBank.LengthCounterexampleBankContext
          command ExferenceLocal)
  | LengthAssessmentSpinePairFilteringContext
      !LengthRankingPolicy
      LeanLengthSpinePairContract
      !(CounterexampleBank.LengthSpinePairCounterexampleBankContext
          command ExferenceLocal)

type role LengthAssessmentContext nominal

-- | Introduce the nominal lifetime for one request.  The compatibility request
-- runner below invokes this once per call; future command scheduling may keep
-- the context and feed multiple batches without changing this API.
withLengthAssessmentRequestContext
  :: LengthAssessmentRequest
  -> (forall command. LengthAssessmentContext command -> IO result)
  -> IO result
withLengthAssessmentRequestContext request action = case request of
  LengthAssessmentRequestDisabled ->
    action LengthAssessmentDisabledContext
  LengthAssessmentEnabledRequest behavior policy selection ->
    case (behavior, selection) of
      (LengthBehaviorRank, LeanLengthScalarContractSelection contract) ->
        action $ LengthAssessmentScalarRankingContext policy contract
      (LengthBehaviorRank, LeanLengthSpinePairContractSelection contract) ->
        action $ LengthAssessmentSpinePairRankingContext policy contract
      (LengthBehaviorFilter, LeanLengthScalarContractSelection contract) ->
        CounterexampleBank.withDefaultLengthCounterexampleBankContext
          $ \context -> action
              $ LengthAssessmentScalarFilteringContext
                  policy contract context
      (LengthBehaviorFilter, LeanLengthSpinePairContractSelection contract) ->
        CounterexampleBank.withDefaultLengthSpinePairCounterexampleBankContext
          $ \context -> action
              $ LengthAssessmentSpinePairFilteringContext
                  policy contract context

-- | The behavior selected by one command-local assessment context.  Filtering
-- contexts (those owning a counterexample bank) report 'LengthBehaviorFilter';
-- both ranking contexts and the disabled context report 'LengthBehaviorRank'.
-- Only the constructor is inspected; no policy or lazy contract is forced.
lengthAssessmentContextBehaviorMode
  :: LengthAssessmentContext command
  -> LengthBehaviorMode
lengthAssessmentContextBehaviorMode context = case context of
  LengthAssessmentDisabledContext -> LengthBehaviorRank
  LengthAssessmentScalarRankingContext {} -> LengthBehaviorRank
  LengthAssessmentSpinePairRankingContext {} -> LengthBehaviorRank
  LengthAssessmentScalarFilteringContext {} -> LengthBehaviorFilter
  LengthAssessmentSpinePairFilteringContext {} -> LengthBehaviorFilter

-- | The exact command-local behavior selected for this request.  Disabled
-- assessment is the established ranking identity.  The enabled projection
-- inspects only its strict behavior tag and does not force the retained lazy
-- contract.
lengthAssessmentRequestBehaviorMode
  :: LengthAssessmentRequest
  -> LengthBehaviorMode
lengthAssessmentRequestBehaviorMode request = case request of
  LengthAssessmentRequestDisabled -> LengthBehaviorRank
  LengthAssessmentEnabledRequest behavior _ _ -> behavior

-- | The mode Main uses when no Length configuration file was named.  It
-- holds no policy or contract, so assessment preserves callback order
-- without IO and an explicit contract request is refused.
disabledLengthAssessmentMode :: LengthAssessmentMode
disabledLengthAssessmentMode = LengthAssessmentDisabled

-- | Select the parsed operation over the startup-fixed contract without
-- inspecting that contract.  Disabled ranking remains the lazy identity;
-- disabled filtering is refused before any contract can be admitted or read.
startupLengthAssessmentRequest
  :: LengthBehaviorMode
  -> LengthAssessmentMode
  -> Either LengthAssessmentRequestError LengthAssessmentRequest
startupLengthAssessmentRequest behavior mode = case mode of
  LengthAssessmentDisabled -> case behavior of
    LengthBehaviorRank -> Right LengthAssessmentRequestDisabled
    LengthBehaviorFilter -> Left
      LengthAssessmentFilteringRequiresActivatedPolicy
  LengthAssessmentConfigured _ policy selection ->
    Right $ LengthAssessmentEnabledRequest behavior policy selection

-- | Authorize one explicit request before its path is admitted or read.
-- Matching a configured mode does not inspect its fixed startup contract; a
-- disabled mode fails without accepting a contract value.
authorizeExplicitLengthAssessmentRequest
  :: LengthBehaviorMode
  -> LengthAssessmentMode
  -> Either
      LengthAssessmentRequestError
      ExplicitLengthAssessmentPermission
authorizeExplicitLengthAssessmentRequest behavior mode = case mode of
  LengthAssessmentDisabled -> Left $ case behavior of
    LengthBehaviorRank ->
      LengthAssessmentExplicitContractRequiresActivatedPolicy
    LengthBehaviorFilter -> LengthAssessmentFilteringRequiresActivatedPolicy
  LengthAssessmentConfigured _ policy _ -> Right
    $ ExplicitLengthAssessmentPermission behavior policy

-- | Associate one successfully decoded passive contract with the exact
-- startup-activated policy.  The contract remains lazy and no IO occurs.
explicitLengthAssessmentRequest
  :: ExplicitLengthAssessmentPermission
  -> LeanLengthContractSelection
  -> LengthAssessmentRequest
explicitLengthAssessmentRequest
    (ExplicitLengthAssessmentPermission behavior policy) selection =
  LengthAssessmentEnabledRequest behavior policy selection

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

-- | One sanitized reason why an enabled operation preserved every verified
-- occurrence.  Candidate-local preparation refusal remains part of the rank
-- or selection report and is not inflated into a batch-wide failure here.
data LengthAssessmentFailure
  = LengthAssessmentPostVerificationFailed
      !LengthPostVerificationFailure
  | LengthAssessmentRankingFailed
      !LengthRankingFailure
  | LengthAssessmentSpinePairPostVerificationFailed
      !LengthSpinePairPostVerificationFailure
  | LengthAssessmentSpinePairRankingFailed
      !LengthSpinePairRankingFailure
  | LengthAssessmentSelectionFailed !LengthSelectionFailure
  | LengthAssessmentSpinePairSelectionFailed
      !LengthSpinePairSelectionFailure
  deriving (Eq, Ord, Show)

-- | Common result for disabled, ranking, and hard-selection paths.  The
-- skipped branch deliberately retains its batch lazily so constructing the
-- disabled result performs no candidate traversal or other IO.
data LengthAssessmentResult
  = LengthAssessmentSkipped
      (VerificationBatch DetailedVerificationVariant)
  | LengthAssessmentCompleted !LengthPostVerificationResult
  | LengthAssessmentSpinePairCompleted
      !LengthSpinePairPostVerificationResult
  | LengthAssessmentSelectionCompleted !LengthSelectionResult
  | LengthAssessmentSpinePairSelectionCompleted
      !LengthSpinePairSelectionResult

-- | Preserve callback order without IO when disabled.  When configured, check
-- the exact verified batch against the startup-fixed contract through the
-- existing occurrence-sealed Length adapter.  The current policy opens its
-- fresh lexical worker only at the first live miss.
assessLengthVerificationBatch
  :: LengthAssessmentMode
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationBatch mode = assessLengthVerificationRequest
  $ case mode of
    LengthAssessmentDisabled -> LengthAssessmentRequestDisabled
    LengthAssessmentConfigured _ policy selection ->
      LengthAssessmentEnabledRequest LengthBehaviorRank policy selection

-- | Assess one exact callback batch under the command-local contract choice.
-- Both contract lifetimes use the same occurrence-sealed policy runner.  The
-- disabled request retains the batch lazily and performs no IO.
assessLengthVerificationRequest
  :: LengthAssessmentRequest
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationRequest request verification =
  withLengthAssessmentRequestContext request $ \context ->
    assessLengthVerificationContext context verification

-- | Assess one batch through an already introduced command-local owner.
-- Reusing a filter context reuses its one nominal bank; rank contexts continue
-- through the established bank-free runners.
assessLengthVerificationContext
  :: LengthAssessmentContext command
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthAssessmentResult
assessLengthVerificationContext context verification = case context of
  LengthAssessmentDisabledContext ->
    pure $ LengthAssessmentSkipped verification
  LengthAssessmentScalarRankingContext policy contract ->
    LengthAssessmentCompleted <$>
      assessVerifiedLengthCandidatesWithPolicy policy contract verification
  LengthAssessmentSpinePairRankingContext policy contract ->
    LengthAssessmentSpinePairCompleted <$>
      assessVerifiedLengthSpinePairCandidatesWithPolicy
        policy contract verification
  LengthAssessmentScalarFilteringContext policy contract bank ->
    LengthAssessmentSelectionCompleted <$>
      selectVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
        policy bank contract verification
  LengthAssessmentSpinePairFilteringContext policy contract bank ->
    LengthAssessmentSpinePairSelectionCompleted <$>
      selectVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
        policy bank contract verification

-- | Effective verified candidates for the requested operation.  Ranking and
-- disabled assessment retain their established candidates; an accepted
-- filter returns only sealed survivors, while every filter failure preserves
-- the complete original batch.
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
  LengthAssessmentSelectionCompleted selected ->
    lengthSelectionCandidates selected
  LengthAssessmentSpinePairSelectionCompleted selected ->
    lengthSpinePairSelectionCandidates selected

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
  LengthAssessmentSelectionCompleted _ -> Nothing
  LengthAssessmentSpinePairSelectionCompleted _ -> Nothing

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
  LengthAssessmentSelectionCompleted _ -> Nothing
  LengthAssessmentSpinePairSelectionCompleted _ -> Nothing

-- | The underlying scalar-domain adapter result, present exactly when the
-- assessment ran under a scalar contract; disabled and spine-pair
-- assessments have none.
lengthAssessmentPostVerificationResult
  :: LengthAssessmentResult
  -> Maybe LengthPostVerificationResult
lengthAssessmentPostVerificationResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted assessed -> Just assessed
  LengthAssessmentSpinePairCompleted _ -> Nothing
  LengthAssessmentSelectionCompleted _ -> Nothing
  LengthAssessmentSpinePairSelectionCompleted _ -> Nothing

-- | The underlying binary-product adapter result, present exactly when the
-- assessment ran under a spine-pair contract; disabled and scalar
-- assessments have none.
lengthAssessmentSpinePairPostVerificationResult
  :: LengthAssessmentResult
  -> Maybe LengthSpinePairPostVerificationResult
lengthAssessmentSpinePairPostVerificationResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted _ -> Nothing
  LengthAssessmentSpinePairCompleted assessed -> Just assessed
  LengthAssessmentSelectionCompleted _ -> Nothing
  LengthAssessmentSpinePairSelectionCompleted _ -> Nothing

-- | Scalar hard-selection result, present only for an explicitly authorized
-- scalar filter request.
lengthAssessmentSelectionResult
  :: LengthAssessmentResult
  -> Maybe LengthSelectionResult
lengthAssessmentSelectionResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted _ -> Nothing
  LengthAssessmentSpinePairCompleted _ -> Nothing
  LengthAssessmentSelectionCompleted selected -> Just selected
  LengthAssessmentSpinePairSelectionCompleted _ -> Nothing

-- | Binary-product hard-selection result, nominally disjoint from scalar
-- selection and present only for an explicitly authorized filter request.
lengthAssessmentSpinePairSelectionResult
  :: LengthAssessmentResult
  -> Maybe LengthSpinePairSelectionResult
lengthAssessmentSpinePairSelectionResult result = case result of
  LengthAssessmentSkipped _ -> Nothing
  LengthAssessmentCompleted _ -> Nothing
  LengthAssessmentSpinePairCompleted _ -> Nothing
  LengthAssessmentSelectionCompleted _ -> Nothing
  LengthAssessmentSpinePairSelectionCompleted selected -> Just selected

-- | The batch-wide reason a configured assessment kept callback order, if
-- any.  An adapter rejection takes precedence over a ranking failure; a
-- skipped (disabled) assessment reports nothing.  Main prints this as a
-- warning beside the candidates.
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
  LengthAssessmentSelectionCompleted selected ->
    LengthAssessmentSelectionFailed <$> lengthSelectionFailure selected
  LengthAssessmentSpinePairSelectionCompleted selected ->
    LengthAssessmentSpinePairSelectionFailed <$>
      lengthSpinePairSelectionFailure selected
