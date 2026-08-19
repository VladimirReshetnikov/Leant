-- | Explicit ownership of live Length ranking policy.
--
-- Construction is pure and performs only Djex's bounded policy validation.
-- 'LengthRankingPolicy' owns reusable execution and replay policy plus
-- independent optional origin-probe, finite input-box, complete applicable-
-- domain, and non-vacuous positive-ordering policies, while a
-- 'LeanLengthContract' is supplied
-- separately for each ranking request.  The versionless startup-file grammar
-- retains its explicitly selected scalar or binary-product contract beside
-- this policy without introducing a second generic aggregate.
--
-- A successful value does not establish that the configured path resolves to
-- a usable executable, that a later live-session executable inspection matches
-- an optional SHA-256 expectation, or that the child has the required Z3
-- capability; those observations belong to the lexical live session opened by
-- each ranking run.  A caller-supplied contract likewise remains an assertion
-- until checked with each exact callback-verified candidate.
--
-- There is deliberately no default source, executable discovery, path
-- normalization, environment lookup, or projection of executable paths or
-- digest bytes from the opaque sealed value.  Closed classifiers report only
-- whether the retained execution policy contains a digest expectation and
-- which launch strategy it selects.
-- Callers must provide the complete execution and replay policy plus each
-- contract explicitly.  No runner retains a worker: established eager
-- policies delegate each eligible batch to the ranking layer's rank-N live
-- scope, while an explicitly deferred policy creates that scope only at the
-- first candidate which actually needs a live query.
module Leant.Synth.Length.Configuration
  ( LengthRankingPolicySource (..)
  , LengthRankingPolicy
  , mkLengthRankingPolicy
  , mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch
  , mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch
  , mkLengthRankingPolicyWithDescriptorBoundExecveCheckExecutableAccessLaunch
  , lengthRankingPolicyFromValidatedComponents
  , enableLengthRankingOriginProbe
  , enableLengthRankingInputBoxValidation
  , enableLengthRankingApplicableDomainValidation
  , enableLengthRankingCounterexampleSimplification
  , enableLengthRankingNonVacuousInputBoxPreference
  , enableLengthRankingNonVacuousApplicableDomainPreference
  , enableLengthRankingDeferredLiveSessionOpening
  , enableLengthRankingUsableWorkBudget
  , enableLengthRankingScopedUsableWorkBudget
  , lengthRankingPolicyExecutableDigestExpectation
  , lengthRankingPolicyExecutableLaunchStrategy
  , LengthRankingConfigurationError (..)
  , assessVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  , rankVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  , rankVerifiedLengthSpinePairCandidatesWithPolicy
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthBooleanFiniteUnionLimits
  , LengthEvaluationLimitError
  , LengthEvaluationLimitSource
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibExecutionConfigError
  , LengthSMTLibExecutionConfigSource
  , LengthSMTLibExecutionLimits
  , LengthSMTLibExecutableDigestExpectation
  , LengthSMTLibExecutableLaunchStrategy
  , LengthSMTLibLiveUsableWorkBudget
  , lengthSMTLibExecutionExecutableDigestExpectation
  , lengthSMTLibExecutionExecutableLaunchStrategy
  , mkLengthEvaluationLimits
  , mkLengthSMTLibDescriptorBoundExecutionConfig
  , mkLengthSMTLibDescriptorBoundEffectiveIDExecutableAccessExecutionConfig
  , mkLengthSMTLibDescriptorBoundExecveCheckExecutableAccessExecutionConfig
  , mkLengthSMTLibExecutionConfig
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Contract
  ( LeanLengthContract
  , LeanLengthSpinePairContract
  )
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingInputError
  , rankVerifiedLengthCandidates
  , rankVerifiedLengthCandidatesWithInputBoxValidation
  )
import Leant.Synth.Length.Ranking.Internal
  ( AssociatedLengthRanking
  , LengthApplicableDomainRankingPolicy (..)
  , LengthCounterexampleSimplificationRankingPolicy (..)
  , LengthInputBoxRankingPolicy (..)
  , LengthLiveSessionOpeningPolicy (..)
  , LengthOriginProbeRankingPolicy (..)
  , preferNonVacuousApplicableDomainAssociatedLengthRanking
  , preferNonVacuousApplicableDomainLengthRanking
  , preferNonVacuousBoundedPositiveAssociatedLengthRanking
  , preferNonVacuousBoundedPositiveLengthRanking
  , rankPostVerificationLengthCandidates
  , rankPostVerificationLengthCandidatesWithOriginProbe
  , rankPostVerificationLengthCandidatesWithInputBoxValidation
  , rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
  , rankVerifiedLengthCandidatesWithOriginProbe
  , rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  )
import Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationResult
  , assessVerifiedLengthCandidatesWith
  )
import Leant.Synth.Length.SpinePair.PostVerification.Internal
  ( LengthSpinePairPostVerificationResult
  , assessVerifiedLengthSpinePairCandidatesWith
  )
import Leant.Synth.Length.SpinePair.Ranking
  ( LengthSpinePairRanking
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  )
import Leant.Synth.Length.SpinePair.Ranking.Internal
  ( AssociatedLengthSpinePairRanking
  , LengthSpinePairApplicableDomainRankingPolicy (..)
  , LengthSpinePairCounterexampleSimplificationRankingPolicy (..)
  , LengthSpinePairInputBoxRankingPolicy (..)
  , LengthSpinePairOriginProbeRankingPolicy (..)
  , preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
  , preferNonVacuousApplicableDomainLengthSpinePairRanking
  , preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  , preferNonVacuousBoundedPositiveLengthSpinePairRanking
  , rankPostVerificationLengthSpinePairCandidates
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  )
import Leant.Synth.PostVerification (PostVerificationCandidate)
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  )

-- | Reusable source policy for live solver ownership and independent replay.
--
-- This contains no behavioral contract.  One admitted policy may therefore be
-- paired explicitly with different request-owned contracts without treating a
-- goal assertion as process configuration.
data LengthRankingPolicySource = LengthRankingPolicySource
  { lengthRankingPolicyExecutionLimits :: LengthSMTLibExecutionLimits
  , lengthRankingPolicyExecutionSource :: LengthSMTLibExecutionConfigSource
  , lengthRankingPolicyEvaluationSource :: LengthEvaluationLimitSource
  }

-- | Validated reusable policy with no process, worker, contract, or behavioral
-- verdict authority.  The constructor and all execution/validation material
-- remain private.
data LengthRankingPolicy = LengthRankingPolicy
  !LengthSMTLibExecutionConfig
  !LengthEvaluationLimits
  !LengthRankingInputBoxValidation
  !LengthRankingApplicableDomainValidation
  !LengthRankingOriginProbe
  !LengthRankingCounterexampleSimplification
  !LengthRankingNonVacuousInputBoxPreference
  !LengthRankingNonVacuousApplicableDomainPreference
  !LengthRankingLiveSessionOpening
  !LengthRankingUsableWorkBudget

-- | Private optional orchestration policy.  It contains no solver status,
-- query, receipt, or verdict; each enabled use must still pass Djex's exact
-- query-owned finite-box validation after a live @unsat@ trigger.
data LengthRankingInputBoxValidation
  = LengthRankingInputBoxValidationDisabled
  | LengthRankingInputBoxValidationEnabled !LengthInputBoxLimits [Natural]

-- | Private permission to attempt the current complete traversal of the
-- query-owned applicable domain. Missing bounds and bounded-admission refusals
-- remain ordinary misses.
data LengthRankingApplicableDomainValidation
  = LengthRankingApplicableDomainValidationDisabled
  | LengthRankingApplicableDomainValidationEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

-- | Private permission to run Djex's query-owned canonical origin replay
-- after the MRU bank misses and before a live query.  This retains no input
-- vector, arity, query, receipt, status, or behavioral verdict.
data LengthRankingOriginProbe
  = LengthRankingOriginProbeDisabled
  | LengthRankingOriginProbeEnabled

-- | Private permission to attempt Djex's bounded query-owned strict
-- simplification whenever any independently validated counterexample enters
-- the ranking pipeline.  The limit is shared as domain-neutral policy, while
-- scalar and product queries and receipts remain nominally separate.
data LengthRankingCounterexampleSimplification
  = LengthRankingCounterexampleSimplificationDisabled
  | LengthRankingCounterexampleSimplificationEnabled !LengthInputBoxLimits

-- | Private ranking-only authority.  It neither enables finite-box
-- validation nor changes which evidence is acquired.  The enabled branch may
-- only prefer a completed bounded-positive receipt whose applicable-assignment
-- count is nonzero; vacuous receipts remain neutral and counterexamples remain
-- last.
data LengthRankingNonVacuousInputBoxPreference
  = LengthRankingNonVacuousInputBoxPreferenceDisabled
  | LengthRankingNonVacuousInputBoxPreferenceEnabled

-- | Private ranking-only authority for independently established complete
-- applicable domains.  It neither enables traversal nor changes evidence
-- acquisition, and vacuous receipts remain neutral.
data LengthRankingNonVacuousApplicableDomainPreference
  = LengthRankingNonVacuousApplicableDomainPreferenceDisabled
  | LengthRankingNonVacuousApplicableDomainPreferenceEnabled

-- | Private process-opening strategy.  Eager is the exact historical policy;
-- deferred opening still performs complete pure admission and preparation but
-- creates the lexical worker only when the first live query is required.
data LengthRankingLiveSessionOpening
  = LengthRankingLiveSessionOpeningEager
  | LengthRankingLiveSessionOpeningDeferredUntilLiveQuery

-- | Optional shared usable-work authority.  The validated Djex value contains
-- a duration only; an absolute deadline is captured independently for every
-- admitted ranking batch.
data LengthRankingUsableWorkBudget
  = LengthRankingUsableWorkBudgetDisabled
  | LengthRankingUsableWorkBudgetEnabled
      !LengthRankingUsableWorkBudgetStrategy
      !LengthSMTLibLiveUsableWorkBudget

-- | Private selection between the established outer-observation owner and
-- the additive same-thread scoped/checkpointed owner.  Keeping the choice
-- inside the opaque ranking policy prevents a duration alone from granting
-- either orchestration strategy.
data LengthRankingUsableWorkBudgetStrategy
  = LengthRankingUsableWorkBudgetV1
  | LengthRankingUsableWorkBudgetScopedV2

-- | Pure validation failure in fixed execution-before-evaluation order.
data LengthRankingConfigurationError
  = LengthRankingExecutionConfigurationRejected
      !LengthSMTLibExecutionConfigError
  | LengthRankingEvaluationLimitsRejected
      !LengthEvaluationLimitError
  deriving (Eq, Ord, Show)

-- | Validate execution before replay limits without performing IO.  This
-- established constructor leaves the origin probe and finite-box validation
-- disabled; callers must derive either opt-in value explicitly.
mkLengthRankingPolicy
  :: LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicy = mkLengthRankingPolicyVia mkLengthSMTLibExecutionConfig

-- | Shared body of the four launch-flavored policy makers: validate the
-- flavor's execution config, then the replay limits, in that order, and
-- assemble the reusable policy with the origin probe and finite-box
-- validation disabled.
mkLengthRankingPolicyVia
  :: (LengthSMTLibExecutionLimits
      -> LengthSMTLibExecutionConfigSource
      -> Either LengthSMTLibExecutionConfigError LengthSMTLibExecutionConfig)
  -> LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicyVia mkExecution source = do
  execution <- case mkExecution
      (lengthRankingPolicyExecutionLimits source)
      (lengthRankingPolicyExecutionSource source) of
    Left failure -> Left $ LengthRankingExecutionConfigurationRejected failure
    Right validated -> Right validated
  evaluation <- case mkLengthEvaluationLimits
      (lengthRankingPolicyEvaluationSource source) of
    Left failure -> Left $ LengthRankingEvaluationLimitsRejected failure
    Right validated -> Right validated
  pure $ lengthRankingPolicyFromValidatedComponents execution evaluation

-- | Validate the same reusable policy while selecting Djex's additive
-- descriptor-bound executable launch.  Construction remains pure and retains
-- the established execution-before-evaluation failure order.  Source
-- inspection and sealed descriptor staging occur only in a later lexical live
-- session.
mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch
  :: LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicyWithDescriptorBoundExecutableLaunch =
  mkLengthRankingPolicyVia mkLengthSMTLibDescriptorBoundExecutionConfig

-- | Validate the same reusable policy while selecting Djex's additive
-- descriptor-bound effective-ID executable-access launch.  Construction
-- remains pure and retains the established execution-before-evaluation
-- failure order.  Effective-credential access checks, source inspection, and
-- sealed descriptor staging occur only in a later lexical live session.
mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch
  :: LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicyWithDescriptorBoundEffectiveIDExecutableAccessLaunch =
  mkLengthRankingPolicyVia
    mkLengthSMTLibDescriptorBoundEffectiveIDExecutableAccessExecutionConfig

-- | Validate the same reusable policy while selecting Djex's additive
-- descriptor-bound execve-check executable-access launch.  Construction
-- remains pure and retains the established execution-before-evaluation
-- failure order.  Effective-credential access checks, source and staged-image
-- execve checks, source inspection, and sealed descriptor staging occur only
-- in a later lexical live session.
mkLengthRankingPolicyWithDescriptorBoundExecveCheckExecutableAccessLaunch
  :: LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicyWithDescriptorBoundExecveCheckExecutableAccessLaunch =
  mkLengthRankingPolicyVia
    mkLengthSMTLibDescriptorBoundExecveCheckExecutableAccessExecutionConfig

-- | Assemble one reusable policy from already validated Djex execution and
-- replay authorities with the origin probe and finite-box validation disabled.
-- No validation is repeated and no IO is performed.
-- The current startup decoder uses this bridge after preserving
-- execution-before-evaluation validation precedence.
lengthRankingPolicyFromValidatedComponents
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicy
lengthRankingPolicyFromValidatedComponents execution evaluation =
  LengthRankingPolicy execution evaluation
    LengthRankingInputBoxValidationDisabled
    LengthRankingApplicableDomainValidationDisabled
    LengthRankingOriginProbeDisabled
    LengthRankingCounterexampleSimplificationDisabled
    LengthRankingNonVacuousInputBoxPreferenceDisabled
    LengthRankingNonVacuousApplicableDomainPreferenceDisabled
    LengthRankingLiveSessionOpeningEager
    LengthRankingUsableWorkBudgetDisabled

-- | Derive an origin-probing sibling without changing the validated
-- execution/evaluation authorities or any independently selected finite box.
-- The probe itself remains query-owned and is attempted only after all four
-- batch-local MRU vectors miss.  Its ordinary non-counterexample result is not
-- positive evidence and cannot suppress the subsequent live query.
enableLengthRankingOriginProbe
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingOriginProbe
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation _ simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation LengthRankingOriginProbeEnabled
    simplification inputBoxPreference applicableDomainPreference
    liveSessionOpening usableWorkBudget

-- | Derive an explicitly enabled finite-box policy without changing the
-- already validated execution/evaluation authorities or the reusable base
-- value.  The inclusive maxima remain caller-owned data until the exact query
-- independently validates width, values, Cartesian size, and every assignment.
-- A cyclic or mismatched vector therefore fails productively only if an
-- @unsat@ observation reaches that exact candidate; it is never treated as a
-- solver verdict or cached evidence.
enableLengthRankingInputBoxValidation
  :: LengthInputBoxLimits
  -> [Natural]
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingInputBoxValidation limits maximums
    (LengthRankingPolicy execution evaluation _ applicableDomainValidation
      originProbe simplification inputBoxPreference applicableDomainPreference
      liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation
    (LengthRankingInputBoxValidationEnabled limits maximums)
    applicableDomainValidation originProbe simplification inputBoxPreference
    applicableDomainPreference liveSessionOpening usableWorkBudget

-- | Enable the complete current applicable-domain algorithm without changing
-- execution, evaluation, origin probing, the optional caller-owned finite box,
-- or either ranking preference. The two independently validated limits bound
-- input enumeration and recursive Boolean finite-union construction. A
-- bounded-admission refusal remains an ordinary miss and falls through to the
-- established origin/live path.
enableLengthRankingApplicableDomainValidation
  :: LengthInputBoxLimits
  -> LengthBooleanFiniteUnionLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingApplicableDomainValidation
    inputBoxLimits unionLimits
    (LengthRankingPolicy execution evaluation inputBoxValidation _ originProbe
      simplification inputBoxPreference applicableDomainPreference
      liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    (LengthRankingApplicableDomainValidationEnabled
      inputBoxLimits unionLimits)
    originProbe simplification inputBoxPreference applicableDomainPreference
    liveSessionOpening usableWorkBudget

-- | Enable the same bounded, query-owned strict counterexample simplifier for
-- every counterexample source without changing source order or enabling any
-- source.  A bounded unavailability or absence of a strict improvement retains
-- the original receipt; admitted invariant/association failures remain
-- indexed and atomic in the ranking layer.
enableLengthRankingCounterexampleSimplification
  :: LengthInputBoxLimits
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingCounterexampleSimplification limits
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe _ inputBoxPreference
      applicableDomainPreference liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe
    (LengthRankingCounterexampleSimplificationEnabled limits)
    inputBoxPreference applicableDomainPreference liveSessionOpening
    usableWorkBudget

-- | Derive an explicit evidence-ordering sibling without enabling or changing
-- finite-box validation, origin probing, execution, evaluation, or contract
-- authority.  The derivation is compositional with the other two policy
-- builders.  If no non-vacuous bounded-positive receipt is acquired, it is an
-- ordering identity.
enableLengthRankingNonVacuousInputBoxPreference
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingNonVacuousInputBoxPreference
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification _
      applicableDomainPreference liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe simplification
    LengthRankingNonVacuousInputBoxPreferenceEnabled applicableDomainPreference
    liveSessionOpening usableWorkBudget

-- | Derive an independent ordering preference for non-vacuous complete-domain
-- receipts.  This does not enable traversal.  When composed with the existing
-- box preference it is applied afterward, yielding complete-domain positive,
-- finite-box positive, neutral, then counterexample partitions.
enableLengthRankingNonVacuousApplicableDomainPreference
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingNonVacuousApplicableDomainPreference
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      _ liveSessionOpening usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe simplification inputBoxPreference
    LengthRankingNonVacuousApplicableDomainPreferenceEnabled liveSessionOpening
    usableWorkBudget

-- | Derive a policy which delays lexical worker creation until the first live
-- query is actually required.  Pure admission, query preparation, MRU replay,
-- applicable-domain validation, and origin replay retain their established
-- order and may therefore complete a batch without opening the executable.
enableLengthRankingDeferredLiveSessionOpening
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingDeferredLiveSessionOpening
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference _ usableWorkBudget) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe simplification inputBoxPreference
    applicableDomainPreference
    LengthRankingLiveSessionOpeningDeferredUntilLiveQuery usableWorkBudget

-- | Derive a sibling whose admitted scalar or product ranking batches share
-- one Djex usable-work deadline.  The value is already validated; this pure
-- builder reads no clock and performs no IO.  Applying it again is last-wins.
enableLengthRankingUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingUsableWorkBudget budget
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening _) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe simplification inputBoxPreference
    applicableDomainPreference liveSessionOpening
    (LengthRankingUsableWorkBudgetEnabled
      LengthRankingUsableWorkBudgetV1 budget)

-- | Derive a sibling whose admitted scalar or product batch owns Djex's
-- same-thread scoped usable-work token.  The duration is already validated;
-- capture still occurs independently for every run after input admission and
-- before candidate preparation.  Applying either budget builder again is
-- last-wins across both strategies.
enableLengthRankingScopedUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingScopedUsableWorkBudget budget
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening _) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    applicableDomainValidation originProbe simplification inputBoxPreference
    applicableDomainPreference liveSessionOpening
    (LengthRankingUsableWorkBudgetEnabled
      LengthRankingUsableWorkBudgetScopedV2 budget)

-- | Classify only whether the sealed execution policy contains an executable
-- digest expectation.  This reveals neither the digest bytes nor the path and
-- does not claim that a later live executable matches the expectation.  The
-- separately retained request-owned contract is not inspected.
lengthRankingPolicyExecutableDigestExpectation
  :: LengthRankingPolicy
  -> LengthSMTLibExecutableDigestExpectation
lengthRankingPolicyExecutableDigestExpectation
    (LengthRankingPolicy execution _ _ _ _ _ _ _ _ _) =
  lengthSMTLibExecutionExecutableDigestExpectation execution

-- | Classify the executable-launch strategy retained by the sealed Djex
-- execution policy.  This reveals no path, descriptor, digest bytes, or live
-- launch observation and does not inspect a separately retained contract.
lengthRankingPolicyExecutableLaunchStrategy
  :: LengthRankingPolicy
  -> LengthSMTLibExecutableLaunchStrategy
lengthRankingPolicyExecutableLaunchStrategy
    (LengthRankingPolicy execution _ _ _ _ _ _ _ _ _) =
  lengthSMTLibExecutionExecutableLaunchStrategy execution

-- Apply the ranking-only preference after all behavioral acquisition has
-- completed.  The disabled branch returns the original action literally;
-- existing policies therefore retain their exact runner and demand behavior.
applyLengthRankingNonVacuousInputBoxPreference
  :: LengthRankingNonVacuousInputBoxPreference
  -> (ranking -> ranking)
  -> IO (Either failure ranking)
  -> IO (Either failure ranking)
applyLengthRankingNonVacuousInputBoxPreference preference prefer action =
  case preference of
    LengthRankingNonVacuousInputBoxPreferenceDisabled -> action
    LengthRankingNonVacuousInputBoxPreferenceEnabled ->
      fmap (fmap prefer) action

-- Applied outside the existing box transform so that, when both are enabled,
-- the complete-domain partition is selected after the box partition.
applyLengthRankingNonVacuousApplicableDomainPreference
  :: LengthRankingNonVacuousApplicableDomainPreference
  -> (ranking -> ranking)
  -> IO (Either failure ranking)
  -> IO (Either failure ranking)
applyLengthRankingNonVacuousApplicableDomainPreference preference prefer action =
  case preference of
    LengthRankingNonVacuousApplicableDomainPreferenceDisabled -> action
    LengthRankingNonVacuousApplicableDomainPreferenceEnabled ->
      fmap (fmap prefer) action

applyLengthRankingNonVacuousInputBoxPreferenceValue
  :: LengthRankingNonVacuousInputBoxPreference
  -> (ranking -> ranking)
  -> ranking
  -> ranking
applyLengthRankingNonVacuousInputBoxPreferenceValue preference prefer ranking =
  case preference of
    LengthRankingNonVacuousInputBoxPreferenceDisabled -> ranking
    LengthRankingNonVacuousInputBoxPreferenceEnabled -> prefer ranking

applyLengthRankingNonVacuousApplicableDomainPreferenceValue
  :: LengthRankingNonVacuousApplicableDomainPreference
  -> (ranking -> ranking)
  -> ranking
  -> ranking
applyLengthRankingNonVacuousApplicableDomainPreferenceValue preference prefer
    ranking = case preference of
  LengthRankingNonVacuousApplicableDomainPreferenceDisabled -> ranking
  LengthRankingNonVacuousApplicableDomainPreferenceEnabled -> prefer ranking

scalarInputBoxRankingPolicy
  :: LengthRankingInputBoxValidation
  -> LengthInputBoxRankingPolicy
scalarInputBoxRankingPolicy validation = case validation of
  LengthRankingInputBoxValidationDisabled -> LengthInputBoxRankingDisabled
  LengthRankingInputBoxValidationEnabled limits maximums ->
    LengthInputBoxRankingEnabled limits maximums

scalarApplicableDomainRankingPolicy
  :: LengthRankingApplicableDomainValidation
  -> LengthApplicableDomainRankingPolicy
scalarApplicableDomainRankingPolicy validation = case validation of
  LengthRankingApplicableDomainValidationDisabled ->
    LengthApplicableDomainRankingDisabled
  LengthRankingApplicableDomainValidationEnabled
      inputBoxLimits unionLimits ->
    LengthApplicableDomainRankingEnabled
      inputBoxLimits unionLimits

scalarOriginProbeRankingPolicy
  :: LengthRankingOriginProbe
  -> LengthOriginProbeRankingPolicy
scalarOriginProbeRankingPolicy policy = case policy of
  LengthRankingOriginProbeDisabled -> LengthOriginProbeRankingDisabled
  LengthRankingOriginProbeEnabled -> LengthOriginProbeRankingEnabled

scalarCounterexampleSimplificationRankingPolicy
  :: LengthRankingCounterexampleSimplification
  -> LengthCounterexampleSimplificationRankingPolicy
scalarCounterexampleSimplificationRankingPolicy policy = case policy of
  LengthRankingCounterexampleSimplificationDisabled ->
    LengthCounterexampleSimplificationRankingDisabled
  LengthRankingCounterexampleSimplificationEnabled limits ->
    LengthCounterexampleSimplificationRankingEnabled limits

spinePairInputBoxRankingPolicy
  :: LengthRankingInputBoxValidation
  -> LengthSpinePairInputBoxRankingPolicy
spinePairInputBoxRankingPolicy validation = case validation of
  LengthRankingInputBoxValidationDisabled ->
    LengthSpinePairInputBoxRankingDisabled
  LengthRankingInputBoxValidationEnabled limits maximums ->
    LengthSpinePairInputBoxRankingEnabled limits maximums

spinePairApplicableDomainRankingPolicy
  :: LengthRankingApplicableDomainValidation
  -> LengthSpinePairApplicableDomainRankingPolicy
spinePairApplicableDomainRankingPolicy validation = case validation of
  LengthRankingApplicableDomainValidationDisabled ->
    LengthSpinePairApplicableDomainRankingDisabled
  LengthRankingApplicableDomainValidationEnabled
      inputBoxLimits unionLimits ->
    LengthSpinePairApplicableDomainRankingEnabled
      inputBoxLimits unionLimits

liveSessionOpeningPolicy
  :: LengthRankingLiveSessionOpening
  -> LengthLiveSessionOpeningPolicy
liveSessionOpeningPolicy opening = case opening of
  LengthRankingLiveSessionOpeningEager -> LengthLiveSessionOpeningEager
  LengthRankingLiveSessionOpeningDeferredUntilLiveQuery ->
    LengthLiveSessionOpeningDeferredUntilLiveQuery

spinePairOriginProbeRankingPolicy
  :: LengthRankingOriginProbe
  -> LengthSpinePairOriginProbeRankingPolicy
spinePairOriginProbeRankingPolicy policy = case policy of
  LengthRankingOriginProbeDisabled ->
    LengthSpinePairOriginProbeRankingDisabled
  LengthRankingOriginProbeEnabled ->
    LengthSpinePairOriginProbeRankingEnabled

spinePairCounterexampleSimplificationRankingPolicy
  :: LengthRankingCounterexampleSimplification
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
spinePairCounterexampleSimplificationRankingPolicy policy = case policy of
  LengthRankingCounterexampleSimplificationDisabled ->
    LengthSpinePairCounterexampleSimplificationRankingDisabled
  LengthRankingCounterexampleSimplificationEnabled limits ->
    LengthSpinePairCounterexampleSimplificationRankingEnabled limits

-- | One ranking entrance: the process policy, the replay limits, the
-- request contract, and the batch.
type LengthRankingEntrance contract candidate ranking
  = LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> contract
  -> [candidate]
  -> IO (Either LengthRankingInputError ranking)

-- | The entrances one policy-driven ranking selects among, for one domain
-- (scalar or binary product) and one candidate shape (verified batch or
-- occurrence-associated post-verification batch), together with the two
-- ranking-only preferences of that receipt type.  'rankWithPolicy' holds the
-- selection once; the four public runners are entrance tables, so the
-- precedence between the eager historical runners, the deferred/validating
-- runner, and the two usable-work-budget owners is written in one place.
--
-- The three policy entrances take the private policy vocabulary of this
-- module; each table converts it to its domain's nominal ranking policies
-- through 'withScalarRankingPolicies' or 'withSpinePairRankingPolicies'.
data LengthRankingEntrances contract candidate ranking = LengthRankingEntrances
  { entranceEager :: LengthRankingEntrance contract candidate ranking
    -- ^ The exact historical runner: eager opening, no optional validation.
  , entranceEagerWithOriginProbe
      :: LengthRankingEntrance contract candidate ranking
  , entranceEagerWithInputBoxValidation
      :: LengthSMTLibExecutionConfig
      -> LengthEvaluationLimits
      -> LengthInputBoxLimits
      -> [Natural]
      -> contract
      -> [candidate]
      -> IO (Either LengthRankingInputError ranking)
  , entranceEagerWithInputBoxValidationAndOriginProbe
      :: LengthSMTLibExecutionConfig
      -> LengthEvaluationLimits
      -> LengthInputBoxLimits
      -> [Natural]
      -> contract
      -> [candidate]
      -> IO (Either LengthRankingInputError ranking)
  , entranceWithPolicies
      :: LengthRankingInputBoxValidation
      -> LengthRankingApplicableDomainValidation
      -> LengthRankingOriginProbe
      -> LengthRankingCounterexampleSimplification
      -> LengthLiveSessionOpeningPolicy
      -> LengthRankingEntrance contract candidate ranking
    -- ^ The complete policy runner used whenever applicable-domain
    -- validation, simplification, or deferred opening is enabled.
  , entranceWithUsableWorkBudget
      :: (ranking -> ranking)
      -> LengthSMTLibLiveUsableWorkBudget
      -> LengthRankingInputBoxValidation
      -> LengthRankingApplicableDomainValidation
      -> LengthRankingOriginProbe
      -> LengthRankingCounterexampleSimplification
      -> LengthLiveSessionOpeningPolicy
      -> LengthRankingEntrance contract candidate ranking
    -- ^ The established outer-observation budget owner; the first argument
    -- finalizes the receipt inside the budget scope.
  , entranceWithScopedUsableWorkBudget
      :: (ranking -> ranking)
      -> LengthSMTLibLiveUsableWorkBudget
      -> LengthRankingInputBoxValidation
      -> LengthRankingApplicableDomainValidation
      -> LengthRankingOriginProbe
      -> LengthRankingCounterexampleSimplification
      -> LengthLiveSessionOpeningPolicy
      -> LengthRankingEntrance contract candidate ranking
    -- ^ The additive same-thread scoped/checkpointed budget owner.
  , preferNonVacuousInputBox :: ranking -> ranking
  , preferNonVacuousApplicableDomain :: ranking -> ranking
  }

-- | Select the entrance one policy demands and apply the two ranking-only
-- preferences after all behavioral acquisition has completed.  Without a
-- usable-work budget the historical eager runners are entered exactly when
-- no deferred, applicable-domain, or simplification policy is enabled; the
-- disabled preference branches return the runner's action literally, so
-- established policies keep their exact runner and demand behavior.  Under a
-- budget the preferences are applied inside the budget owner instead.
rankWithPolicy
  :: LengthRankingEntrances contract candidate ranking
  -> LengthRankingPolicy
  -> contract
  -> [candidate]
  -> IO (Either LengthRankingInputError ranking)
rankWithPolicy entrances
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening usableWorkBudget) contract
    candidates = case usableWorkBudget of
  LengthRankingUsableWorkBudgetDisabled ->
    applyLengthRankingNonVacuousApplicableDomainPreference
      applicableDomainPreference (preferNonVacuousApplicableDomain entrances)
      $ applyLengthRankingNonVacuousInputBoxPreference inputBoxPreference
          (preferNonVacuousInputBox entrances)
      $ case
        (applicableDomainValidation, simplification, liveSessionOpening) of
        (LengthRankingApplicableDomainValidationDisabled,
            LengthRankingCounterexampleSimplificationDisabled,
            LengthRankingLiveSessionOpeningEager) ->
          case (inputBoxValidation, originProbe) of
            (LengthRankingInputBoxValidationDisabled,
                LengthRankingOriginProbeDisabled) ->
              entranceEager entrances execution evaluation contract candidates
            (LengthRankingInputBoxValidationDisabled,
                LengthRankingOriginProbeEnabled) ->
              entranceEagerWithOriginProbe entrances
                execution evaluation contract candidates
            (LengthRankingInputBoxValidationEnabled limits maximums,
                LengthRankingOriginProbeDisabled) ->
              entranceEagerWithInputBoxValidation entrances
                execution evaluation limits maximums contract candidates
            (LengthRankingInputBoxValidationEnabled limits maximums,
                LengthRankingOriginProbeEnabled) ->
              entranceEagerWithInputBoxValidationAndOriginProbe entrances
                execution evaluation limits maximums contract candidates
        _ ->
          entranceWithPolicies entrances inputBoxValidation
            applicableDomainValidation originProbe simplification
            (liveSessionOpeningPolicy liveSessionOpening)
            execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled LengthRankingUsableWorkBudgetV1
      budget ->
    entranceWithUsableWorkBudget entrances finalize budget inputBoxValidation
      applicableDomainValidation originProbe simplification
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled
      LengthRankingUsableWorkBudgetScopedV2 budget ->
    entranceWithScopedUsableWorkBudget entrances finalize budget
      inputBoxValidation applicableDomainValidation originProbe simplification
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
 where
  finalize =
    applyLengthRankingNonVacuousApplicableDomainPreferenceValue
      applicableDomainPreference (preferNonVacuousApplicableDomain entrances)
    . applyLengthRankingNonVacuousInputBoxPreferenceValue
        inputBoxPreference (preferNonVacuousInputBox entrances)

-- | Convert this module's private validation vocabulary to the scalar
-- domain's nominal ranking policies, in the order the runners take them.
withScalarRankingPolicies
  :: (LengthInputBoxRankingPolicy
      -> LengthApplicableDomainRankingPolicy
      -> LengthOriginProbeRankingPolicy
      -> LengthCounterexampleSimplificationRankingPolicy
      -> entrance)
  -> LengthRankingInputBoxValidation
  -> LengthRankingApplicableDomainValidation
  -> LengthRankingOriginProbe
  -> LengthRankingCounterexampleSimplification
  -> entrance
withScalarRankingPolicies runner inputBoxValidation
    applicableDomainValidation originProbe simplification =
  runner
    (scalarInputBoxRankingPolicy inputBoxValidation)
    (scalarApplicableDomainRankingPolicy applicableDomainValidation)
    (scalarOriginProbeRankingPolicy originProbe)
    (scalarCounterexampleSimplificationRankingPolicy simplification)

-- | Binary-product sibling of 'withScalarRankingPolicies'.
withSpinePairRankingPolicies
  :: (LengthSpinePairInputBoxRankingPolicy
      -> LengthSpinePairApplicableDomainRankingPolicy
      -> LengthSpinePairOriginProbeRankingPolicy
      -> LengthSpinePairCounterexampleSimplificationRankingPolicy
      -> entrance)
  -> LengthRankingInputBoxValidation
  -> LengthRankingApplicableDomainValidation
  -> LengthRankingOriginProbe
  -> LengthRankingCounterexampleSimplification
  -> entrance
withSpinePairRankingPolicies runner inputBoxValidation
    applicableDomainValidation originProbe simplification =
  runner
    (spinePairInputBoxRankingPolicy inputBoxValidation)
    (spinePairApplicableDomainRankingPolicy applicableDomainValidation)
    (spinePairOriginProbeRankingPolicy originProbe)
    (spinePairCounterexampleSimplificationRankingPolicy simplification)

-- | Run a verified batch under one reusable policy and one explicitly supplied
-- request contract.  Eager policies still open one fresh lexical worker for
-- every eligible call; an explicitly deferred policy may complete from
-- query-owned pure evidence without a process and otherwise opens once at the
-- first live miss.
rankVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithPolicy = rankWithPolicy LengthRankingEntrances
  { entranceEager = rankVerifiedLengthCandidates
  , entranceEagerWithOriginProbe = rankVerifiedLengthCandidatesWithOriginProbe
  , entranceEagerWithInputBoxValidation =
      rankVerifiedLengthCandidatesWithInputBoxValidation
  , entranceEagerWithInputBoxValidationAndOriginProbe =
      rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
  , entranceWithPolicies = withScalarRankingPolicies
      rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  , entranceWithUsableWorkBudget = \finalize budget ->
      withScalarRankingPolicies
        $ rankVerifiedLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
            finalize budget
  , entranceWithScopedUsableWorkBudget = \finalize budget ->
      withScalarRankingPolicies
        $ rankVerifiedLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
            finalize budget
  , preferNonVacuousInputBox = preferNonVacuousBoundedPositiveLengthRanking
  , preferNonVacuousApplicableDomain =
      preferNonVacuousApplicableDomainLengthRanking
  }

-- | Associated variant used by a batch-scoped post-verification adapter.
-- Caller-owned occurrence handles remain attached until that adapter validates
-- the final permutation and deliberately erases them.
rankPostVerificationLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithPolicy =
  rankWithPolicy LengthRankingEntrances
    { entranceEager = rankPostVerificationLengthCandidates
    , entranceEagerWithOriginProbe =
        rankPostVerificationLengthCandidatesWithOriginProbe
    , entranceEagerWithInputBoxValidation =
        rankPostVerificationLengthCandidatesWithInputBoxValidation
    , entranceEagerWithInputBoxValidationAndOriginProbe =
        rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
    , entranceWithPolicies = withScalarRankingPolicies
        rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    , entranceWithUsableWorkBudget = \finalize budget ->
        withScalarRankingPolicies
          $ rankPostVerificationLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
              finalize budget
    , entranceWithScopedUsableWorkBudget = \finalize budget ->
        withScalarRankingPolicies
          $ rankPostVerificationLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
              finalize budget
    , preferNonVacuousInputBox =
        preferNonVacuousBoundedPositiveAssociatedLengthRanking
    , preferNonVacuousApplicableDomain =
        preferNonVacuousApplicableDomainAssociatedLengthRanking
    }

-- | Assess one exact callback batch with an explicit reusable policy and
-- request-owned contract, then expose a report only through the generative
-- occurrence-permutation seal.
assessVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesWithPolicy policy contract =
  assessVerifiedLengthCandidatesWith
    $ rankPostVerificationLengthCandidatesWithPolicy policy contract

rankPostVerificationLengthCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithPolicyAndCounterexampleBankContext
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening usableWorkBudget)
    context contract candidates = case usableWorkBudget of
  LengthRankingUsableWorkBudgetDisabled ->
    applyLengthRankingNonVacuousApplicableDomainPreference
      applicableDomainPreference
      preferNonVacuousApplicableDomainAssociatedLengthRanking
      $ applyLengthRankingNonVacuousInputBoxPreference inputBoxPreference
          preferNonVacuousBoundedPositiveAssociatedLengthRanking
      $ rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
          context
          (scalarInputBoxRankingPolicy inputBoxValidation)
          (scalarApplicableDomainRankingPolicy applicableDomainValidation)
          (scalarOriginProbeRankingPolicy originProbe)
          (scalarCounterexampleSimplificationRankingPolicy simplification)
          (liveSessionOpeningPolicy liveSessionOpening)
          execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled LengthRankingUsableWorkBudgetV1
      budget ->
    rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
      finalize budget context
      (scalarInputBoxRankingPolicy inputBoxValidation)
      (scalarApplicableDomainRankingPolicy applicableDomainValidation)
      (scalarOriginProbeRankingPolicy originProbe)
      (scalarCounterexampleSimplificationRankingPolicy simplification)
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled
      LengthRankingUsableWorkBudgetScopedV2 budget ->
    rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
      finalize budget context
      (scalarInputBoxRankingPolicy inputBoxValidation)
      (scalarApplicableDomainRankingPolicy applicableDomainValidation)
      (scalarOriginProbeRankingPolicy originProbe)
      (scalarCounterexampleSimplificationRankingPolicy simplification)
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
 where
  finalize =
    applyLengthRankingNonVacuousApplicableDomainPreferenceValue
      applicableDomainPreference
      preferNonVacuousApplicableDomainAssociatedLengthRanking
      . applyLengthRankingNonVacuousInputBoxPreferenceValue
          inputBoxPreference
          preferNonVacuousBoundedPositiveAssociatedLengthRanking

-- | Filter-mode sibling of 'assessVerifiedLengthCandidatesWithPolicy'.  The
-- same policy selects the eager, budgeted, or scoped runner, but counterexample
-- replay and recording go through the supplied command-local bank instead of
-- the batch-local seed bank; the report is still exposed only through the
-- generative occurrence-permutation seal.
assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
    policy context contract =
  assessVerifiedLengthCandidatesWith
    $ rankPostVerificationLengthCandidatesWithPolicyAndCounterexampleBankContext
        policy context contract

-- | Run the nominal binary-product sibling under the same process/evaluation
-- policy.  The policy contains no scalar contract, query, or evidence
-- authority; all four branches enter pair-specific runners and receipts.
rankVerifiedLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithPolicy =
  rankWithPolicy LengthRankingEntrances
    { entranceEager = rankVerifiedLengthSpinePairCandidates
    , entranceEagerWithOriginProbe =
        rankVerifiedLengthSpinePairCandidatesWithOriginProbe
    , entranceEagerWithInputBoxValidation =
        rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
    , entranceEagerWithInputBoxValidationAndOriginProbe =
        rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    , entranceWithPolicies = withSpinePairRankingPolicies
        rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    , entranceWithUsableWorkBudget = \finalize budget ->
        withSpinePairRankingPolicies
          $ rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
              finalize budget
    , entranceWithScopedUsableWorkBudget = \finalize budget ->
        withSpinePairRankingPolicies
          $ rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
              finalize budget
    , preferNonVacuousInputBox =
        preferNonVacuousBoundedPositiveLengthSpinePairRanking
    , preferNonVacuousApplicableDomain =
        preferNonVacuousApplicableDomainLengthSpinePairRanking
    }

rankPostVerificationLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithPolicy =
  rankWithPolicy LengthRankingEntrances
    { entranceEager = rankPostVerificationLengthSpinePairCandidates
    , entranceEagerWithOriginProbe =
        rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
    , entranceEagerWithInputBoxValidation =
        rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
    , entranceEagerWithInputBoxValidationAndOriginProbe =
        rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    , entranceWithPolicies = withSpinePairRankingPolicies
        rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    , entranceWithUsableWorkBudget = \finalize budget ->
        withSpinePairRankingPolicies
          $ rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
              finalize budget
    , entranceWithScopedUsableWorkBudget = \finalize budget ->
        withSpinePairRankingPolicies
          $ rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
              finalize budget
    , preferNonVacuousInputBox =
        preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
    , preferNonVacuousApplicableDomain =
        preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
    }

-- | Assess one callback batch through the pair-specific occurrence seal.
assessVerifiedLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairPostVerificationResult
assessVerifiedLengthSpinePairCandidatesWithPolicy policy contract =
  assessVerifiedLengthSpinePairCandidatesWith
    $ rankPostVerificationLengthSpinePairCandidatesWithPolicy policy contract

rankPostVerificationLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
    (LengthRankingPolicy execution evaluation inputBoxValidation
      applicableDomainValidation originProbe simplification inputBoxPreference
      applicableDomainPreference liveSessionOpening usableWorkBudget)
    context contract candidates = case usableWorkBudget of
  LengthRankingUsableWorkBudgetDisabled ->
    applyLengthRankingNonVacuousApplicableDomainPreference
      applicableDomainPreference
      preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
      $ applyLengthRankingNonVacuousInputBoxPreference inputBoxPreference
          preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
      $ rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
          context
          (spinePairInputBoxRankingPolicy inputBoxValidation)
          (spinePairApplicableDomainRankingPolicy applicableDomainValidation)
          (spinePairOriginProbeRankingPolicy originProbe)
          (spinePairCounterexampleSimplificationRankingPolicy simplification)
          (liveSessionOpeningPolicy liveSessionOpening)
          execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled LengthRankingUsableWorkBudgetV1
      budget ->
    rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
      finalize budget context
      (spinePairInputBoxRankingPolicy inputBoxValidation)
      (spinePairApplicableDomainRankingPolicy applicableDomainValidation)
      (spinePairOriginProbeRankingPolicy originProbe)
      (spinePairCounterexampleSimplificationRankingPolicy simplification)
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
  LengthRankingUsableWorkBudgetEnabled
      LengthRankingUsableWorkBudgetScopedV2 budget ->
    rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
      finalize budget context
      (spinePairInputBoxRankingPolicy inputBoxValidation)
      (spinePairApplicableDomainRankingPolicy applicableDomainValidation)
      (spinePairOriginProbeRankingPolicy originProbe)
      (spinePairCounterexampleSimplificationRankingPolicy simplification)
      (liveSessionOpeningPolicy liveSessionOpening)
      execution evaluation contract candidates
 where
  finalize =
    applyLengthRankingNonVacuousApplicableDomainPreferenceValue
      applicableDomainPreference
      preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
      . applyLengthRankingNonVacuousInputBoxPreferenceValue
          inputBoxPreference
          preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking

-- | Filter-mode sibling of 'assessVerifiedLengthSpinePairCandidatesWithPolicy'.
-- The same policy selects the eager, budgeted, or scoped pair runner, but
-- counterexample replay and recording go through the supplied command-local
-- pair bank instead of the batch-local seed bank; the report is still exposed
-- only through the pair-specific occurrence seal.
assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthSpinePairContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairPostVerificationResult
assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
    policy context contract =
  assessVerifiedLengthSpinePairCandidatesWith
    $ rankPostVerificationLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
        policy context contract
