{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live Length ranking.
--
-- This module is the only Leant layer which opens Djex's public live Length
-- session.  It first productively bounds the complete input, then prepares
-- every checked problem and canonical query before launching a worker.
-- Eligible candidates are processed serially in original order.  The
-- eager programmatic path opens one rank-N scope before the first candidate;
-- the additive deferred path enters that one scope only at the first actual live
-- miss, and an all-pure batch opens none.  Before a later live call, at most
-- four exact counterexample
-- input vectors are independently validated and replayed in newest-first
-- order against that candidate's checked query.  A replay hit avoids one live
-- query and promotes that vector; every all-miss follows the established live
-- path.  An independently enabled origin policy may next probe the canonical
-- all-zero vector owned by that exact query.  A hit enters the same receipt
-- and MRU path, while an ordinary miss proceeds to live execution.
-- An explicitly enabled policy may use a live @unsat@ only as the trigger for
-- independent, query-owned exhaustive validation of one finite input box.  A
-- validation counterexample enters the same exact receipt/MRU path; complete
-- bounded success stays neutral and a validation failure atomically resets
-- the batch.  The external status itself never becomes positive evidence.
--
-- A solver status is heuristic only.  A live observation can yield a
-- counterexample only after Djex's public query-first gate checks its exact
-- fingerprint and replays its evidence.  A seed hit can yield one only after
-- the later query independently validates the input vector against the checked
-- problem retained by that query and associates the resulting evidence back
-- to its own behavioral problem.  Even that receipt is finite-spine and
-- model-relative: it is neither a proof nor a claim about the source-level
-- realization of a Lean term.
-- Ranking therefore never prunes.  The established runners stably move
-- candidates with replayed counterexamples after every other candidate.  A
-- separate post-assessment opt-in may first prefer non-vacuous bounded-positive
-- receipts while leaving vacuous receipts neutral and counterexamples last;
-- source order is preserved within every partition.  The seed bank contains
-- only input vectors, not
-- cached verdicts, solver results, receipts, or proofs, and it never crosses a
-- ranking batch.
--
-- Historical entrances retain separate opener/finalizer and per-query host
-- windows.  The additive usable-work entrance instead captures one shared
-- owner after admission and before preparation.  It remains an observed
-- normal-return boundary, not an asynchronous watchdog: nested final readiness
-- and cleanup use fresh private windows, but the outer owner checks only after
-- those stages return and may then reject the batch.  Exceptions are not
-- caught here and retain the live facade's durable-cleanup behavior.
module Leant.Synth.Length.Ranking.Internal
  ( LengthRankingInputError (..)
  , LengthRankingAssessment (..)
  , LengthPreparationRefusalClass (..)
  , lengthPreparationRefusalClassCode
  , lengthHandoffPreparationRefusalClass
  , lengthQueryPreparationRefusalClass
  , RankedLengthCandidate
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidateVerified
  , rankedLengthCandidateAssessment
  , rankedLengthCandidateCounterexampleSimplification
  , rankedLengthCandidatePreparationRefusal
  , LengthRankingFailureClass (..)
  , LengthRankingFailure
  , lengthRankingFailureClass
  , lengthRankingFailureCleanupIncomplete
  , lengthRankingFailureOriginalIndex
  , LengthRanking
  , lengthRankingCandidates
  , lengthRankingFailure
  , preferNonVacuousBoundedPositiveLengthRanking
  , preferNonVacuousApplicableDomainLengthRanking
  , AssociatedRankedLengthCandidate
  , associatedRankedLengthCandidateAssociation
  , AssociatedLengthRanking
  , associatedLengthRankingCandidates
  , preferNonVacuousBoundedPositiveAssociatedLengthRanking
  , preferNonVacuousApplicableDomainAssociatedLengthRanking
  , PostVerificationLengthRanking
  , sealPostVerificationLengthRanking
  , postVerificationLengthRankingBatch
  , postVerificationLengthRankingFailure
  , materializePostVerificationLengthRanking
  , rankPostVerificationLengthCandidates
  , rankVerifiedLengthCandidates
  , rankPostVerificationLengthCandidatesWithOriginProbe
  , rankVerifiedLengthCandidatesWithOriginProbe
  , rankPostVerificationLengthCandidatesWithInputBoxValidation
  , rankVerifiedLengthCandidatesWithInputBoxValidation
  , rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
  , rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
  , LengthInputBoxRankingPolicy (..)
  , LengthApplicableDomainRankingPolicy (..)
  , LengthOriginProbeRankingPolicy (..)
  , LengthCounterexampleSimplificationRankingPolicy (..)
  , LengthLiveSessionOpeningPolicy (..)
  , rankVerifiedLengthCandidatesWithRankingPolicies
  , rankPostVerificationLengthCandidatesWithRankingPolicies
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankVerifiedLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  , rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  , promoteCounterexampleSeed
  , replayCounterexampleSeeds
  ) where

import Control.DeepSeq (NFData (rnf), force)
import Control.Exception (evaluate)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthBooleanFiniteUnionLimits
  , LengthApplicableDomainValidation (..)
  , LengthApplicableDomainValidationError (..)
  , LengthCounterexampleSimplificationError (..)
  , LengthEvaluationError
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthInputBoxValidationError (..)
  , LengthSMTLibApplicableDomainValidationError (..)
  , LengthSMTLibCounterexampleSimplificationError (..)
  , LengthSMTLibInputReplayError (..)
  , LengthSMTLibInputBoxValidationError (..)
  , LengthSMTLibExecutionConfig
  , LengthSMTLibQueryError (..)
  , LengthSMTLibLiveObservationReplayError (..)
  , LengthSMTLibLiveQueryError
  , LengthSMTLibLiveQueryFailure
  , LengthSMTLibLiveQueryObservation
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveScopedUsableWorkDeadline
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSMTLibLiveUsableWorkDeadline
  , SolverStatus (..)
  , ValidatedLengthApplicableDomain
  , ValidatedLengthCounterexample
  , ValidatedLengthCounterexampleSimplification
  , ValidatedLengthInputBox
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveQueryCleanupIncomplete
  , lengthSMTLibLiveQueryObservationSolverStatus
  , lengthSMTLibLiveQueryPrimaryFailure
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
  , probeLengthSMTLibCounterexampleAtOrigin
  , replayLengthSMTLibCounterexampleInputs
  , replayLengthSMTLibLiveQueryObservation
  , runLengthSMTLibLiveQuery
  , simplifyLengthSMTLibQueryCounterexample
  , validateLengthSMTLibQueryApplicableDomain
  , validateLengthSMTLibQueryInputBox
  , validatedLengthApplicableDomainApplicableAssignmentCount
  , validatedLengthCounterexampleInputs
  , validatedLengthCounterexampleSimplificationCounterexample
  , validatedLengthInputBoxApplicableAssignmentCount
  , checkLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveSession
  , withLengthSMTLibLiveSessionUnderScopedDeadline
  , withLengthSMTLibLiveSessionUnderDeadline
  , withLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveUsableWorkDeadline
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareCheckedLengthQuery
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.Handoff (LengthHandoffRefusal (..))
import Leant.Synth.PostVerification
  ( PostVerificationBatch
  , PostVerificationCandidate
  , PostVerificationError
  , PostVerificationInput
  , postVerificationBatchCandidates
  , postVerificationCandidateVerified
  , sealPostVerificationBatch
  )
import Leant.Synth.Verification (Verified)

-- | Productive rejection of maximum-plus-one input candidates.  The observed
-- count is capped at that first excess; an unbounded tail is never traversed.
data LengthRankingInputError = LengthRankingInputLimitExceeded
  { lengthRankingInputMaximumCandidates :: !Natural
  , lengthRankingInputObservedCandidatesAtLeast :: !Natural
  }
  deriving (Eq, Ord, Show)

-- | The public assessment strengths.  Heuristic status, finite-box success,
-- and complete applicable-domain establishment are neutral unless their
-- corresponding additive preference is explicitly enabled; every replayed
-- counterexample remains stably demoted.
data LengthRankingAssessment
  = Unassessed
  | Heuristic !SolverStatus
  | Counterexample !ValidatedLengthCounterexample
  | BoundedPositive !ValidatedLengthInputBox
  | ApplicableDomainEstablished !ValidatedLengthApplicableDomain
  deriving (Eq, Show)

-- | Stable, payload-free phase at which pure candidate preparation refused.
--
-- These classes are diagnostics only.  They are neither behavioral evidence
-- nor ranking strength, and their derived order must not influence candidate
-- selection.  Exact renderer text, source names, types, graph identities, and
-- nested Djex errors are never copied from the raw refusal into this
-- diagnostic.  The exact verified receipt and its sidecar remain attached to
-- the ranked candidate for association.
data LengthPreparationRefusalClass
  = LengthPreparationUnsupportedRoute
  | LengthPreparationTypedAuthorityUnavailable
  | LengthPreparationCandidateAssociationRejected
  | LengthPreparationRenderingAssociationRejected
  | LengthPreparationSpineBindingUnavailable
  | LengthPreparationProviderBindingUnavailable
  | LengthPreparationSessionRejected
  | LengthPreparationContractRejected
  | LengthPreparationCandidateSemanticsRejected
  | LengthPreparationQueryConstructionRejected
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Fixed machine-readable code containing no refusal payload.
lengthPreparationRefusalClassCode
  :: LengthPreparationRefusalClass
  -> String
lengthPreparationRefusalClassCode refusal = case refusal of
  LengthPreparationUnsupportedRoute -> "unsupported-route"
  LengthPreparationTypedAuthorityUnavailable ->
    "typed-authority-unavailable"
  LengthPreparationCandidateAssociationRejected ->
    "candidate-association-rejected"
  LengthPreparationRenderingAssociationRejected ->
    "rendering-association-rejected"
  LengthPreparationSpineBindingUnavailable ->
    "spine-binding-unavailable"
  LengthPreparationProviderBindingUnavailable ->
    "provider-binding-unavailable"
  LengthPreparationSessionRejected -> "session-rejected"
  LengthPreparationContractRejected -> "contract-rejected"
  LengthPreparationCandidateSemanticsRejected ->
    "candidate-semantics-rejected"
  LengthPreparationQueryConstructionRejected ->
    "query-construction-rejected"

-- | Private invariant separating a pure preparation refusal from the legacy
-- assessment projection.  Operational batch fallback is represented by
-- 'LengthCandidateAssessed' 'Unassessed', with no candidate-local refusal.
data LengthCandidateAssessment
  = LengthCandidatePreparationRefused !LengthPreparationRefusalClass
  | LengthCandidateAssessed
      !LengthRankingAssessment
      !(Maybe ValidatedLengthCounterexampleSimplification)

-- | One callback receipt and the assessment made for that exact candidate.
-- The constructor stays private so receipts cannot be detached and paired
-- with another candidate's assessment.
data RankedLengthCandidate = RankedLengthCandidate
  !Natural
  !(Verified DetailedVerificationVariant)
  !LengthCandidateAssessment

-- | Zero-based position of this candidate in the caller's admitted input.
rankedLengthCandidateOriginalIndex :: RankedLengthCandidate -> Natural
rankedLengthCandidateOriginalIndex (RankedLengthCandidate index _ _) = index

-- | The exact callback receipt this assessment was made for.
rankedLengthCandidateVerified
  :: RankedLengthCandidate
  -> Verified DetailedVerificationVariant
rankedLengthCandidateVerified (RankedLengthCandidate _ verified _) = verified

-- | Legacy assessment projection; a preparation refusal reads as
-- 'Unassessed'.
rankedLengthCandidateAssessment
  :: RankedLengthCandidate
  -> LengthRankingAssessment
rankedLengthCandidateAssessment (RankedLengthCandidate _ _ state) =
  candidateAssessment state

-- | Candidate-local pure preparation refusal, if one occurred.
--
-- 'Nothing' with 'Unassessed' means that preparation succeeded but an
-- operational batch failure atomically reset the assessment; callers should
-- inspect 'lengthRankingFailure' for that batch-wide cause.
rankedLengthCandidatePreparationRefusal
  :: RankedLengthCandidate
  -> Maybe LengthPreparationRefusalClass
rankedLengthCandidatePreparationRefusal (RankedLengthCandidate _ _ state) =
  candidatePreparationRefusal state

candidateAssessment :: LengthCandidateAssessment -> LengthRankingAssessment
candidateAssessment state = case state of
  LengthCandidatePreparationRefused _ -> Unassessed
  LengthCandidateAssessed assessment _ -> assessment

candidatePreparationRefusal
  :: LengthCandidateAssessment
  -> Maybe LengthPreparationRefusalClass
candidatePreparationRefusal state = case state of
  LengthCandidatePreparationRefused refusal -> Just refusal
  LengthCandidateAssessed _ _ -> Nothing

-- | Metadata for a strict query-owned reduction of this exact candidate's
-- counterexample, when the optional bounded simplifier found one.  The
-- ordinary assessment always carries the final freshly replayed receipt.
rankedLengthCandidateCounterexampleSimplification
  :: RankedLengthCandidate
  -> Maybe ValidatedLengthCounterexampleSimplification
rankedLengthCandidateCounterexampleSimplification
    (RankedLengthCandidate _ _ state) = case state of
  LengthCandidatePreparationRefused _ -> Nothing
  LengthCandidateAssessed _ simplification -> simplification

-- | Sanitized failure classes.  Nested live and bounded-evaluation failures
-- retain only Djex's closed public diagnostics; association and replay failures
-- deliberately discard their richer internal details here.  Pure
-- handoff/query-sealing refusals are ordinary per-candidate absence of
-- assessment rather than batch failures.
data LengthRankingFailureClass
  = LengthRankingLiveSessionFailed !LengthSMTLibLiveSessionFailure
  | LengthRankingLiveQueryFailed !LengthSMTLibLiveQueryFailure
  | LengthRankingQueryAssociationMismatch
  | LengthRankingEvidenceReplayMismatch
  | LengthRankingOriginProbeEvaluationFailed !LengthEvaluationError
  | LengthRankingInputBoxValidationFailed !LengthInputBoxValidationError
  | LengthRankingApplicableDomainValidationFailed
      !LengthApplicableDomainValidationError
  | LengthRankingCounterexampleSimplificationFailed
      !LengthCounterexampleSimplificationError
  deriving (Eq, Ord, Show)

-- | One fail-closed ranking failure.  The optional index is the safe,
-- zero-based position in the caller's admitted input, never a solver ordinal.
-- The Boolean copies only Djex's sanitized incomplete-cleanup observation.
data LengthRankingFailure = LengthRankingFailure
  !LengthRankingFailureClass
  !Bool
  !(Maybe Natural)
  deriving (Eq, Ord, Show)

-- | The sanitized batch-failure class.
lengthRankingFailureClass
  :: LengthRankingFailure
  -> LengthRankingFailureClass
lengthRankingFailureClass (LengthRankingFailure failure _ _) = failure

-- | Whether Djex reported that worker cleanup may be incomplete.
lengthRankingFailureCleanupIncomplete :: LengthRankingFailure -> Bool
lengthRankingFailureCleanupIncomplete
    (LengthRankingFailure _ incomplete _) = incomplete

-- | Safe original input index of the failing candidate, when one applies.
lengthRankingFailureOriginalIndex
  :: LengthRankingFailure
  -> Maybe Natural
lengthRankingFailureOriginalIndex (LengthRankingFailure _ _ index) = index

-- | Complete all-or-fallback result.  A successful value may be stably
-- reordered.  Any failure contains every original receipt in original order,
-- all 'Unassessed', plus one sanitized failure.
data LengthRanking = LengthRanking
  ![RankedLengthCandidate]
  !(Maybe LengthRankingFailure)

-- | Every admitted candidate, reordered only by a successful assessment.
lengthRankingCandidates :: LengthRanking -> [RankedLengthCandidate]
lengthRankingCandidates (LengthRanking candidates _) = candidates

-- | The batch-wide sanitized failure behind an all-'Unassessed' fallback.
lengthRankingFailure :: LengthRanking -> Maybe LengthRankingFailure
lengthRankingFailure (LengthRanking _ failure) = failure

-- | Internal ranking result which keeps one caller-owned occurrence handle
-- inseparable from the assessment derived from its receipt.  The association
-- is the only receipt-bearing field in this transient ranking record; the
-- trusted projection edge later erases that association deliberately.
data AssociatedRankedLengthCandidate association =
  AssociatedRankedLengthCandidate
    !Natural
    !association
    !LengthCandidateAssessment

type role AssociatedRankedLengthCandidate nominal

-- | The caller-owned occurrence handle this assessment was derived from.
-- This is the only receipt-bearing projection of the transient record.
associatedRankedLengthCandidateAssociation
  :: AssociatedRankedLengthCandidate association
  -> association
associatedRankedLengthCandidateAssociation
    (AssociatedRankedLengthCandidate _ association _) = association

-- | Complete associated plan before its batch-scoped handles are erased.
data AssociatedLengthRanking association = AssociatedLengthRanking
  ![AssociatedRankedLengthCandidate association]
  !(Maybe LengthRankingFailure)

type role AssociatedLengthRanking nominal

-- | Every admitted associated candidate, reordered only by a successful
-- assessment; on failure they stay in original order, all 'Unassessed'.
associatedLengthRankingCandidates
  :: AssociatedLengthRanking association
  -> [AssociatedRankedLengthCandidate association]
associatedLengthRankingCandidates
    (AssociatedLengthRanking candidates _) = candidates

-- | Project one association-free compatibility report through its fixed
-- receipt-bearing association.  This helper stays private: the direct runner
-- supplies 'id', while the package-private post-verification projection below
-- fixes the only permitted erasure for batch-scoped occurrence handles.  It
-- eagerly materializes the already bounded report spine so an erased epoch
-- handle cannot survive behind a public association-free result thunk.
projectAssociatedLengthRankingWith
  :: (association -> Verified DetailedVerificationVariant)
  -> AssociatedLengthRanking association
  -> LengthRanking
projectAssociatedLengthRankingWith verifiedFor
    (AssociatedLengthRanking candidates failure) =
  LengthRanking (projectCandidates [] candidates) failure
 where
  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthCandidate index association state : rest ->
      let projected = RankedLengthCandidate
            index (verifiedFor association) state
      in projected `seq`
          projectCandidates (projected : reversed) rest

-- | One exact sealed permutation and its receipt-free compatibility state.
-- The opaque value stores verified receipts only through the sealed batch.
-- Its already bounded summary spine is materialized eagerly so no erased
-- epoch handle can survive behind an accepted post-verification result.
data PostVerificationLengthRanking = PostVerificationLengthRanking
    !(PostVerificationBatch DetailedVerificationVariant)
    ![PostVerificationRankedCandidateSummary]
    !(Maybe LengthRankingFailure)

data PostVerificationRankedCandidateSummary =
  PostVerificationRankedCandidateSummary
    !Natural
    !LengthCandidateAssessment

-- | Seal one associated proposal and retain its receipt-free compatibility
-- state in the same fixed operation.  No package caller can pair a summary
-- with an independently sourced same-cardinality batch.  Receipt weak-head
-- demand deliberately matches the old complete-report projection even though
-- the values are now retained only by the sealed 'PostVerificationBatch'.
sealPostVerificationLengthRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedLengthRanking
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError PostVerificationLengthRanking
sealPostVerificationLengthRanking maximumCandidates input associated = do
  batch <- sealPostVerificationBatch maximumCandidates input
    $ map associatedRankedLengthCandidateAssociation
    $ associatedLengthRankingCandidates associated
  pure $ retain batch associated
 where
  retain batch (AssociatedLengthRanking candidates failure) =
    PostVerificationLengthRanking batch
      (projectCandidates [] candidates) failure

  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthCandidate index association state : rest ->
      let verified = postVerificationCandidateVerified association
          projected = PostVerificationRankedCandidateSummary index state
      in verified `seq` projected `seq`
          projectCandidates (projected : reversed) rest

-- | The sealed permutation batch, the sole owner of the verified receipts
-- behind this ranking.  Its candidates are in ranked order.
postVerificationLengthRankingBatch
  :: PostVerificationLengthRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthRankingBatch
    (PostVerificationLengthRanking batch _ _) = batch

-- | The batch-wide sanitized failure retained from the sealed associated
-- ranking, when its candidates were left 'Unassessed'.
postVerificationLengthRankingFailure
  :: PostVerificationLengthRanking
  -> Maybe LengthRankingFailure
postVerificationLengthRankingFailure
    (PostVerificationLengthRanking _ _ failure) = failure

-- | Materialize the established association-free compatibility report from
-- the sole retained receipt owner and its receipt-free summary.  Both inputs
-- are package-private products of the same successful seal.  A cardinality
-- mismatch therefore denotes an internal invariant violation rather than a
-- caller-controlled ranking failure.
materializePostVerificationLengthRanking
  :: PostVerificationLengthRanking
  -> LengthRanking
materializePostVerificationLengthRanking
    (PostVerificationLengthRanking batch summaries failure) =
  LengthRanking
    (materializeCandidates []
      (postVerificationBatchCandidates batch) summaries)
    failure
 where
  materializeCandidates reversed verifiedRemaining summaryRemaining =
    case (verifiedRemaining, summaryRemaining) of
      ([], []) -> reverse reversed
      (verified : verifiedRest,
          PostVerificationRankedCandidateSummary index state : summaryRest) ->
        let projected = RankedLengthCandidate index verified state
        in projected `seq` materializeCandidates
            (projected : reversed) verifiedRest summaryRest
      _ -> error
        "sealed post-verification ranking summary cardinality changed"

data PreparedLengthCandidate association
  = PreparedLengthCandidateUnassessed
      !Natural
      !association
      !LengthPreparationRefusalClass
  | PreparedLengthCandidateEligible
      !Natural
      !association
      !CheckedLengthQuery

-- | Private orchestration policy.  The disabled constructor is the exact
-- historical path.  The enabled constructor owns only an independently
-- checked traversal limit and caller-supplied finite maxima; it carries no
-- solver observation or behavioral verdict.
data LengthInputBoxRankingPolicy
  = LengthInputBoxRankingDisabled
  | LengthInputBoxRankingEnabled !LengthInputBoxLimits [Natural]

-- | Private permission to attempt the current complete query-owned validation
-- of the precondition-applicable input domain after every MRU miss. Admission
-- limits remain an ordinary miss and no solver observation is retained here.
data LengthApplicableDomainRankingPolicy
  = LengthApplicableDomainRankingDisabled
  | LengthApplicableDomainRankingEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

-- | Private query-owned pre-live probe policy.  The enabled constructor is
-- only permission to run Djex's canonical origin replay after every MRU miss;
-- it carries no arity, input vector, query, receipt, or verdict.
data LengthOriginProbeRankingPolicy
  = LengthOriginProbeRankingDisabled
  | LengthOriginProbeRankingEnabled

-- | Private permission to replace any independently replayed counterexample
-- with Djex's strictly smaller query-owned sibling.  The same bounded policy
-- is applied regardless of whether the starting receipt came from MRU replay,
-- applicable-domain traversal, the origin probe, live replay, or the
-- post-@unsat@ box.  @Nothing@ from Djex retains that exact starting receipt.
data LengthCounterexampleSimplificationRankingPolicy
  = LengthCounterexampleSimplificationRankingDisabled
  | LengthCounterexampleSimplificationRankingEnabled !LengthInputBoxLimits

-- | The four assessment policies that every internal ranking runner threads
-- together unchanged: bounded input-box validation, applicable-domain
-- validation, the origin probe, and counterexample simplification.  The
-- exported entry points still take the four positionally; they pack them
-- once here so the runner family below can pass one value.  The worker
-- opening policy stays separate because the deferred-opening runners omit it.
data LengthRankingPolicies = LengthRankingPolicies
  { inputBoxPolicyOf :: !LengthInputBoxRankingPolicy
  , applicableDomainPolicyOf :: !LengthApplicableDomainRankingPolicy
  , originProbePolicyOf :: !LengthOriginProbeRankingPolicy
  , simplificationPolicyOf :: !LengthCounterexampleSimplificationRankingPolicy
  }

-- | The established batch-local raw-vector MRU or one explicitly supplied
-- command-local nominal bank.  Existing ranking entrances always construct
-- the first branch; only the additive filter runner receives the second.
data LengthCounterexampleBankCursor command
  = LengthBatchLocalCounterexampleBank ![[Natural]]
  | LengthCommandLocalCounterexampleBank
      !(CounterexampleBank.LengthCounterexampleBankContext
          command ExferenceLocal)

type role LengthCounterexampleBankCursor nominal

-- | Exact source of one candidate-specific counterexample before optional
-- simplification.  A retained-bank hit keeps its command tag until either its
-- exact sample is promoted or its simplified successor is freshly recorded.
data LengthCounterexampleAcquisition command
  = LengthCounterexampleFromBatchReplay ![Natural]
  | LengthCounterexampleFromCommandReplay
      !(CounterexampleBank.LengthCounterexampleBankContextReplayHit
          command ExferenceLocal)
  | LengthCounterexampleFresh
      !CounterexampleBank.LengthCounterexampleBankReceiptOrigin

type role LengthCounterexampleAcquisition nominal

-- | Package-private worker-opening policy shared by the scalar and binary
-- product ranking implementations.  The eager constructor is the literal
-- historical behavior.  Deferred opening still admits and prepares the full
-- batch first, but opens a worker only after the first candidate whose pure
-- MRU/domain/origin prefix misses.
data LengthLiveSessionOpeningPolicy
  = LengthLiveSessionOpeningEager
  | LengthLiveSessionOpeningDeferredUntilLiveQuery
  deriving (Eq, Ord, Show)

-- | Rank one already Lean-callback-verified batch under an explicit behavioral
-- contract and explicit live/evaluation policies.
--
-- Input admission precedes all behavioral-preparation work. A successfully
-- checked problem is transient until query sealing; prepared state retains
-- only the caller-owned receipt association and query. An empty admitted batch
-- opens no worker. Every nonempty eligible batch uses exactly one live session
-- and processes its pre-sealed queries serially in original order; a later
-- seed-replay hit can avoid that query's live execution.
rankVerifiedLengthCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidates execution evaluation contract candidates = fmap
  (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidates
      (LengthRankingPolicies LengthInputBoxRankingDisabled
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingDisabled
        LengthCounterexampleSimplificationRankingDisabled)
      execution evaluation contract id candidates

-- | Opt in to one query-owned all-zero replay after the bounded MRU bank
-- misses and before live execution.  A counterexample follows the ordinary
-- receipt/MRU path; an ordinary replay miss has no positive authority.
rankVerifiedLengthCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithOriginProbe execution evaluation contract
    candidates = fmap
  (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidates
      (LengthRankingPolicies LengthInputBoxRankingDisabled
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingEnabled
        LengthCounterexampleSimplificationRankingDisabled)
      execution evaluation contract id candidates

-- | Opt in to independently validating one exact finite input box after a
-- live @unsat@ observation.  The solver status is only the trigger: Djex owns
-- traversal, evaluation, and exact query/problem association.  Existing
-- counterexample seed replay still runs first and can avoid the live call.
rankVerifiedLengthCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithInputBoxValidation execution evaluation
    limits maximums contract candidates = fmap
  (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidates
      (LengthRankingPolicies (LengthInputBoxRankingEnabled limits maximums)
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingDisabled
        LengthCounterexampleSimplificationRankingDisabled)
      execution evaluation contract id candidates

-- | Compose the independent pre-live origin probe with the established
-- post-@unsat@ finite-box validation.  A probe hit avoids the live query, so
-- no solver status exists which could schedule the box for that candidate.
rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums contract candidates = fmap
  (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidates
      (LengthRankingPolicies (LengthInputBoxRankingEnabled limits maximums)
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingEnabled
        LengthCounterexampleSimplificationRankingDisabled)
      execution evaluation contract id candidates

-- | Safe associated entry point for the post-verification seam.  The receipt
-- projection is fixed here so callers cannot rank one receipt while retaining
-- another occurrence's batch-scoped handle.
rankPostVerificationLengthCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidates execution evaluation contract =
  rankAssociatedLengthCandidates
      (LengthRankingPolicies LengthInputBoxRankingDisabled
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingDisabled
        LengthCounterexampleSimplificationRankingDisabled)
    execution evaluation contract
    postVerificationCandidateVerified

-- | Occurrence-associated origin-probe sibling used by the generative
-- post-verification permutation seal.
rankPostVerificationLengthCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithOriginProbe execution evaluation
    contract =
  rankAssociatedLengthCandidates
      (LengthRankingPolicies LengthInputBoxRankingDisabled
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingEnabled
        LengthCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

-- | Occurrence-associated opt-in used by the post-verification permutation
-- seal.  The finite-box receipt remains attached to the exact occurrence until
-- that seal deliberately erases the batch-scoped handle.
rankPostVerificationLengthCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithInputBoxValidation execution evaluation
    limits maximums contract =
  rankAssociatedLengthCandidates
    (LengthRankingPolicies (LengthInputBoxRankingEnabled limits maximums)
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingDisabled
        LengthCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

-- | Occurrence-associated composition of the pre-live origin probe and the
-- post-@unsat@ finite-box validator.
rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums contract =
  rankAssociatedLengthCandidates
    (LengthRankingPolicies (LengthInputBoxRankingEnabled limits maximums)
        LengthApplicableDomainRankingDisabled
        LengthOriginProbeRankingEnabled
        LengthCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

-- | Package-private complete policy entrance used by the opaque reusable
-- configuration owner.  The established public runners above keep passing
-- the literal disabled applicable-domain policy.
rankVerifiedLengthCandidatesWithRankingPolicies
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy execution evaluation contract candidates =
  rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager execution evaluation
    contract candidates


-- | Complete policy entrance with an explicit worker-opening strategy.  This
-- is package-private so programmatic policies and the current startup decoder
-- can opt in without widening the established public ranking surface.
rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy
    openingPolicy execution evaluation contract candidates = fmap
      (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidatesWithLiveSessionOpening policies openingPolicy
      execution evaluation contract id candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Occurrence-associated sibling of the complete private policy entrance.
rankPostVerificationLengthCandidatesWithRankingPolicies
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy execution evaluation contract =
  rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager execution evaluation
    contract


-- | Occurrence-associated sibling of the opening-aware complete entrance.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy
    openingPolicy execution evaluation contract =
  rankAssociatedLengthCandidatesWithLiveSessionOpening policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Budgeted complete-policy entrance.  Admission remains outside the shared
-- owner; every preparation, pure evidence pass, live operation, final ranking
-- transform, and ranking-owned result thunk is evaluated beneath the one
-- captured usable-work deadline.
rankVerifiedLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (LengthRanking -> LengthRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithRankingPoliciesAndUsableWorkBudget finalize
    budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthCandidatesWithUsableWorkBudget budget
    (finalize . projectAssociatedLengthRankingWith id)
    forceLengthRankingOwnedResult policies openingPolicy execution evaluation
    contract id candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Occurrence-associated budgeted sibling.  The caller supplies only the
-- closed stable ranking transform; occurrence associations retain their
-- established WHNF demand and are never given an 'NFData' requirement.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthCandidatesWithUsableWorkBudget budget finalize
    forceAssociatedLengthRankingOwnedResult policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Scoped/checkpointed complete-policy entrance.  It retains the v1
-- admission and atomic-result contract while selecting the additive
-- same-thread owner and explicit bounded-phase checkpoints.
rankVerifiedLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (LengthRanking -> LengthRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthCandidatesWithScopedUsableWorkBudget budget
    (finalize . projectAssociatedLengthRankingWith id)
    forceLengthRankingOwnedResult policies openingPolicy execution evaluation
    contract id candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Occurrence-associated scoped/checkpointed sibling.  Checkpointing never
-- projects or forces caller-owned occurrence handles beyond their established
-- weak-head boundary.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthCandidatesWithScopedUsableWorkBudget budget finalize
    forceAssociatedLengthRankingOwnedResult policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Additive occurrence-associated filter entrance using one caller-owned
-- nominal counterexample bank.  No established ranking entrance calls this
-- function; their raw four-vector MRU remains literal.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  :: CounterexampleBank.LengthCounterexampleBankContext command ExferenceLocal
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
    context inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedLengthCandidatesWithLiveSessionOpeningAndCursor
    (LengthCommandLocalCounterexampleBank context)
    policies openingPolicy execution evaluation contract
    postVerificationCandidateVerified
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Budgeted sibling of the counterexample-bank filter entrance.  Like the
-- bank-free budgeted runner, admission stays outside the shared owner and all
-- preparation, live work, and the caller's final transform run beneath the one
-- captured usable-work deadline, but counterexample replay and recording go
-- through the supplied command-local bank instead of the batch-local MRU.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  :: (AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> CounterexampleBank.LengthCounterexampleBankContext command ExferenceLocal
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
    finalize budget context inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy openingPolicy execution evaluation
    contract candidates =
  rankAssociatedLengthCandidatesWithUsableWorkBudgetAndCursor
    (LengthCommandLocalCounterexampleBank context)
    budget finalize forceAssociatedLengthRankingOwnedResult policies
    openingPolicy execution evaluation contract
    postVerificationCandidateVerified candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Scoped/checkpointed sibling of the counterexample-bank filter entrance.
-- It selects the same-thread scoped owner with explicit bounded-phase
-- checkpoints while replaying and recording counterexamples through the
-- supplied command-local bank instead of the batch-local MRU.
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  :: (AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> CounterexampleBank.LengthCounterexampleBankContext command ExferenceLocal
  -> LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
    finalize budget context inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy openingPolicy execution evaluation
    contract candidates =
  rankAssociatedLengthCandidatesWithScopedUsableWorkBudgetAndCursor
    (LengthCommandLocalCounterexampleBank context)
    budget finalize forceAssociatedLengthRankingOwnedResult policies
    openingPolicy execution evaluation contract
    postVerificationCandidateVerified candidates
 where
  policies = LengthRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


data LengthUsableWorkSnapshot association = LengthUsableWorkSnapshot
  ![PreparedLengthCandidate association]
  !Bool

type role LengthUsableWorkSnapshot nominal

rankAssociatedLengthCandidatesWithUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthRanking association -> result)
  -> (result -> ())
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthCandidatesWithUsableWorkBudget budget finish forceResult
    policies openingPolicy execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthCandidatesWithUsableWorkBudgetAndCursor
    (LengthBatchLocalCounterexampleBank []) budget finish forceResult
    policies openingPolicy execution evaluation contract verifiedFor
    associations

rankAssociatedLengthCandidatesWithUsableWorkBudgetAndCursor
  :: LengthCounterexampleBankCursor command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthRanking association -> result)
  -> (result -> ())
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthCandidatesWithUsableWorkBudgetAndCursor cursor budget
    finish forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveUsableWorkDeadline budget $ \deadline -> do
        let prepared = prepareCandidates contract verifiedFor admitted
            snapshot = LengthUsableWorkSnapshot prepared False
        _ <- evaluate $ forcePreparedLengthCandidates prepared
        snapshot `seq` writeIORef snapshotRef (Just snapshot)
        ranking <- runPreparedCandidatesUnderUsableWorkDeadline deadline
          execution evaluation policies openingPolicy cursor prepared
        let cleanupIncomplete = associatedLengthRankingCleanupIncomplete ranking
            completedSnapshot = LengthUsableWorkSnapshot
              prepared cleanupIncomplete
            result = finish ranking
        completedSnapshot `seq`
          writeIORef snapshotRef (Just completedSnapshot)
        _ <- evaluate $ forceResult result
        pure result
      case owned of
        Right result -> pure $ Right result
        Left ownerFailure -> do
          snapshot <- readIORef snapshotRef
          let cleanupIncomplete = case snapshot of
                Nothing -> False
                Just (LengthUsableWorkSnapshot _ incomplete) -> incomplete
              failure = ownerLengthRankingFailure
                cleanupIncomplete ownerFailure
              ranking = case snapshot of
                Nothing -> unpreparedUnassessedRanking admitted failure
                Just (LengthUsableWorkSnapshot prepared _) ->
                  unassessedRanking prepared failure
              result = finish ranking
          _ <- evaluate $ forceResult result
          pure $ Right result

rankAssociatedLengthCandidatesWithScopedUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthRanking association -> result)
  -> (result -> ())
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthCandidatesWithScopedUsableWorkBudget budget finish
    forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthCandidatesWithScopedUsableWorkBudgetAndCursor
    (LengthBatchLocalCounterexampleBank []) budget finish forceResult
    policies openingPolicy execution evaluation contract verifiedFor
    associations

rankAssociatedLengthCandidatesWithScopedUsableWorkBudgetAndCursor
  :: LengthCounterexampleBankCursor command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthRanking association -> result)
  -> (result -> ())
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthCandidatesWithScopedUsableWorkBudgetAndCursor cursor budget
    finish forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveScopedUsableWorkDeadline budget
        $ \deadline -> do
          initial <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
          case initial of
            Left failure -> pure $ Left failure
            Right () -> do
              let prepared = prepareCandidates contract verifiedFor admitted
                  snapshot = LengthUsableWorkSnapshot prepared False
              _ <- evaluate $ forcePreparedLengthCandidates prepared
              snapshot `seq` writeIORef snapshotRef (Just snapshot)
              afterPreparation <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              case afterPreparation of
                Left failure -> pure $ Left failure
                Right () -> do
                  ranked <-
                    runPreparedCandidatesUnderScopedUsableWorkDeadline
                      deadline execution evaluation policies openingPolicy
                      cursor prepared
                  case ranked of
                    Left failure -> pure $ Left failure
                    Right ranking -> do
                      let cleanupIncomplete =
                            associatedLengthRankingCleanupIncomplete ranking
                          completedSnapshot = LengthUsableWorkSnapshot
                            prepared cleanupIncomplete
                      completedSnapshot `seq`
                        writeIORef snapshotRef (Just completedSnapshot)
                      beforeResult <-
                        checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
                      case beforeResult of
                        Left failure -> pure $ Left failure
                        Right () -> do
                          let result = finish ranking
                          _ <- evaluate $ forceResult result
                          afterResult <-
                            checkLengthSMTLibLiveScopedUsableWorkDeadline
                              deadline
                          case afterResult of
                            Left failure -> pure $ Left failure
                            Right () -> pure $ Right result
      case owned of
        Left ownerFailure -> fallback snapshotRef admitted ownerFailure
        Right (Left checkpointFailure) ->
          fallback snapshotRef admitted checkpointFailure
        Right (Right result) -> pure $ Right result
 where
  fallback snapshotRef admitted failure = do
    snapshot <- readIORef snapshotRef
    let cleanupIncomplete = case snapshot of
          Nothing -> False
          Just (LengthUsableWorkSnapshot _ incomplete) -> incomplete
        rankingFailure = ownerLengthRankingFailure cleanupIncomplete failure
        ranking = case snapshot of
          Nothing -> unpreparedUnassessedRanking admitted rankingFailure
          Just (LengthUsableWorkSnapshot prepared _) ->
            unassessedRanking prepared rankingFailure
        result = finish ranking
    _ <- evaluate $ forceResult result
    pure $ Right result

runPreparedCandidatesUnderUsableWorkDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO (AssociatedLengthRanking association)
runPreparedCandidatesUnderUsableWorkDeadline deadline execution evaluation
    policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ AssociatedLengthRanking [] Nothing
  _ | not (hasEligibleCandidate prepared) -> pure $ AssociatedLengthRanking
        (map preparedCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
            $ \session -> runPreparedCandidates evaluation policies
                cursor session prepared
          pure $ case scoped of
            Left failure -> unassessedRanking prepared
              $ sessionRankingFailure failure
            Right (Left failure) -> unassessedRanking prepared failure
            Right (Right assessed) -> AssociatedLengthRanking
              (stableCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline
            deadline execution evaluation policies cursor prepared

runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO (AssociatedLengthRanking association)
runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline deadline
    execution evaluation policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLive
        evaluation applicableDomainPolicy originProbePolicy simplificationPolicy
        cursor prepared
  case beforeLive of
    PreparedLengthCandidatesCompleted assessed -> pure
      $ AssociatedLengthRanking (stableCounterexampleDemotion assessed) Nothing
    PreparedLengthCandidatesFailed failure -> pure
      $ unassessedRanking prepared failure
    PreparedLengthCandidatesNeedLive reversed nextCursor index association query
        rest -> do
      scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
        $ \session -> do
          observed <- runLengthSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Left $ queryRankingFailure index failure
            Right observation -> case
                assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                  simplificationPolicy index association query observation of
              Left failure -> pure $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceLengthCounterexampleBankCursor evaluation index
                  query (LengthCounterexampleFresh origin) assessed nextCursor
                case advanced of
                  Left failure -> pure $ Left failure
                  Right advancedCursor -> runPreparedCandidatesFrom evaluation
                    policies advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedRanking prepared
          $ sessionRankingFailure failure
        Right (Left failure) -> unassessedRanking prepared failure
        Right (Right assessed) -> AssociatedLengthRanking
          (stableCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


runPreparedCandidatesUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthRanking association))
runPreparedCandidatesUnderScopedUsableWorkDeadline deadline execution
    evaluation policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ Right $ AssociatedLengthRanking [] Nothing
  _ | not (hasEligibleCandidate prepared) -> pure $ Right
        $ AssociatedLengthRanking
            (map preparedCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
            deadline execution $ \session ->
              runPreparedCandidatesFromUnderScopedUsableWorkDeadline
                deadline evaluation policies cursor session [] prepared
          pure $ case scoped of
            Left failure -> Right $ unassessedRanking prepared
              $ sessionRankingFailure failure
            Right (Left failure) -> Left failure
            Right (Right (Left failure)) -> Right
              $ unassessedRanking prepared failure
            Right (Right (Right assessed)) -> Right
              $ AssociatedLengthRanking
                  (stableCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
            deadline execution evaluation policies cursor prepared

runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthRanking association))
runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
    deadline execution evaluation policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline
    deadline evaluation applicableDomainPolicy originProbePolicy
    simplificationPolicy cursor prepared
  case beforeLive of
    Left failure -> pure $ Left failure
    Right (PreparedLengthCandidatesCompleted assessed) -> pure $ Right
      $ AssociatedLengthRanking
          (stableCounterexampleDemotion assessed) Nothing
    Right (PreparedLengthCandidatesFailed failure) -> pure $ Right
      $ unassessedRanking prepared failure
    Right (PreparedLengthCandidatesNeedLive reversed nextCursor index
        association query rest) -> do
      scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
        deadline execution $ \session -> do
          observed <- runLengthSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Right $ Left
              $ queryRankingFailure index failure
            Right observation -> case
                assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                simplificationPolicy index association query observation of
              Left failure -> pure $ Right $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceLengthCounterexampleBankCursor evaluation
                  index query (LengthCounterexampleFresh origin) assessed
                  nextCursor
                case advanced of
                  Left failure -> pure $ Right $ Left failure
                  Right advancedCursor -> do
                    checkpoint <-
                      checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
                    case checkpoint of
                      Left failure -> pure $ Left failure
                      Right () ->
                        runPreparedCandidatesFromUnderScopedUsableWorkDeadline
                          deadline evaluation policies advancedCursor session
                          (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> Right $ unassessedRanking prepared
          $ sessionRankingFailure failure
        Right (Left failure) -> Left failure
        Right (Right (Left failure)) -> Right
          $ unassessedRanking prepared failure
        Right (Right (Right assessed)) -> Right
          $ AssociatedLengthRanking
              (stableCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


-- | Check after each complete pure candidate chain.  The individual MRU,
-- applicable-domain, origin, and simplification operations are independently
-- bounded and deliberately remain one indivisible checkpoint quantum.
runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (PreparedLengthCandidatesBeforeLive command association))
runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline deadline
    evaluation applicableDomainPolicy originProbePolicy simplificationPolicy
    initialCursor = go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ Right
      $ PreparedLengthCandidatesCompleted $ reverse reversed
    PreparedLengthCandidateUnassessed index association refusal : rest ->
      continue
        (AssociatedRankedLengthCandidate index association
          (LengthCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthCandidateEligible index association query : rest -> do
      replayed <- replayLengthCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Right
          $ PreparedLengthCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure $ Right
              $ PreparedLengthCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association
            query of
          Left failure -> pure $ Right
            $ PreparedLengthCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample evaluation
              originProbePolicy query of
            Left (LengthSMTLibInputReplayEvaluationRejected failure) -> pure
              $ Right $ PreparedLengthCandidatesFailed $ localRankingFailure
                  (LengthRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSMTLibInputReplayAssociationRejected _) -> pure
              $ Right $ PreparedLengthCandidatesFailed $ localRankingFailure
                  LengthRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query
                receipt of
              Left failure -> pure $ Right
                $ PreparedLengthCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              checkpoint <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              pure $ case checkpoint of
                Left failure -> Left failure
                Right () -> Right $ PreparedLengthCandidatesNeedLive
                  reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthCounterexampleBankCursor evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right
        $ PreparedLengthCandidatesFailed failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go reversed cursor rest

-- | Live sibling which checks after every completed candidate before any
-- following candidate can demand pure replay or another live transaction.
runPreparedCandidatesFromUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthCandidate association]
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (Either LengthRankingFailure
          [AssociatedRankedLengthCandidate association]))
runPreparedCandidatesFromUnderScopedUsableWorkDeadline deadline evaluation
    policies initialCursor session = go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ Right $ reverse reversed
    PreparedLengthCandidateUnassessed index association refusal : rest ->
      continue
        (AssociatedRankedLengthCandidate index association
          (LengthCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthCandidateEligible index association query : rest -> do
      replayed <- replayLengthCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Right $ Left failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation simplificationPolicy
              index association query receipt of
            Left failure -> pure $ Right $ Left failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association query of
          Left failure -> pure $ Right $ Left failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample evaluation
              originProbePolicy query of
            Left (LengthSMTLibInputReplayEvaluationRejected failure) -> pure
              $ Right $ Left $ localRankingFailure
                  (LengthRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSMTLibInputReplayAssociationRejected _) -> pure
              $ Right $ Left $ localRankingFailure
                  LengthRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ Right $ Left failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLengthSMTLibLiveQuery evaluation session query
              case observed of
                Left failure -> pure $ Right $ Left
                  $ queryRankingFailure index failure
                Right observation -> case
                    assessCandidateWithCounterexampleOrigin evaluation
                      inputBoxPolicy simplificationPolicy index association query
                      observation of
                  Left failure -> pure $ Right $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (LengthCounterexampleFresh origin) rest assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthCounterexampleBankCursor evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right $ Left failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go cursor reversed rest

-- | Rank caller-owned occurrences while retaining each occurrence handle
-- through preparation, live assessment, stable partitioning, and atomic
-- fallback.  The projection is not touched until complete input admission has
-- succeeded.
rankAssociatedLengthCandidates
  :: LengthRankingPolicies
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking association))
rankAssociatedLengthCandidates policies execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthCandidatesWithLiveSessionOpening policies
    LengthLiveSessionOpeningEager execution evaluation contract verifiedFor
    associations

rankAssociatedLengthCandidatesWithLiveSessionOpening
  :: LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking association))
rankAssociatedLengthCandidatesWithLiveSessionOpening policies openingPolicy
    execution evaluation contract verifiedFor associations =
  rankAssociatedLengthCandidatesWithLiveSessionOpeningAndCursor
    (LengthBatchLocalCounterexampleBank []) policies openingPolicy execution
    evaluation contract verifiedFor associations

rankAssociatedLengthCandidatesWithLiveSessionOpeningAndCursor
  :: LengthCounterexampleBankCursor command
  -> LengthRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking association))
rankAssociatedLengthCandidatesWithLiveSessionOpeningAndCursor cursor policies
    openingPolicy execution evaluation contract verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> case prepareCandidates contract verifiedFor admitted of
      [] -> pure $ Right $ AssociatedLengthRanking [] Nothing
      prepared
        | not (hasEligibleCandidate prepared) -> pure $ Right
            $ AssociatedLengthRanking
                (map preparedCandidateUnassessed prepared) Nothing
        | otherwise -> case openingPolicy of
            LengthLiveSessionOpeningEager -> do
              scoped <- withLengthSMTLibLiveSession execution
                $ \session -> runPreparedCandidates
                    evaluation policies cursor session prepared
              pure $ Right $ case scoped of
                Left failure -> unassessedRanking prepared
                  $ sessionRankingFailure failure
                Right (Left failure) ->
                  unassessedRanking prepared failure
                Right (Right assessed) -> AssociatedLengthRanking
                  (stableCounterexampleDemotion assessed) Nothing
            LengthLiveSessionOpeningDeferredUntilLiveQuery -> Right <$>
              runPreparedCandidatesWithDeferredLiveSessionOpening execution
                evaluation policies cursor prepared

admitCandidates
  :: Natural
  -> [candidate]
  -> Either LengthRankingInputError [candidate]
admitCandidates maximumCandidates = go 0 []
 where
  go observed reversed remaining
    | observed >= maximumCandidates = case remaining of
        [] -> Right $ reverse reversed
        _ : _ -> Left $ LengthRankingInputLimitExceeded
          maximumCandidates (maximumCandidates + 1)
    | otherwise = case remaining of
        [] -> Right $ reverse reversed
        candidate : rest -> go (observed + 1) (candidate : reversed) rest

prepareCandidates
  :: LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> [PreparedLengthCandidate association]
prepareCandidates contract verifiedFor = go 0 []
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let prepared = prepareCandidate index association
    in prepared `seq` go (index + 1) (prepared : reversed) rest

  prepareCandidate index association =
    let verified = verifiedFor association
    in case prepareCheckedLengthQuery contract verified of
      Left refusal -> PreparedLengthCandidateUnassessed
        index association
          $ lengthHandoffPreparationRefusalClass refusal
      Right (Left refusal) -> PreparedLengthCandidateUnassessed
        index association
          $ lengthQueryPreparationRefusalClass refusal
      Right (Right query) -> PreparedLengthCandidateEligible
        index association query

hasEligibleCandidate :: [PreparedLengthCandidate association] -> Bool
hasEligibleCandidate = any isEligible
 where
  isEligible prepared = case prepared of
    PreparedLengthCandidateUnassessed {} -> False
    PreparedLengthCandidateEligible {} -> True

preparedCandidateUnassessed
  :: PreparedLengthCandidate association
  -> AssociatedRankedLengthCandidate association
preparedCandidateUnassessed prepared = case prepared of
  PreparedLengthCandidateUnassessed index association refusal ->
    AssociatedRankedLengthCandidate
      index association $ LengthCandidatePreparationRefused refusal
  PreparedLengthCandidateEligible index association _ ->
    AssociatedRankedLengthCandidate index association
      $ LengthCandidateAssessed Unassessed Nothing

-- | Result of evaluating the pure prefix before a deferred worker exists.
-- The continuation is private and retains the exact prepared query only until
-- the single live-session scope is either entered or skipped.
data PreparedLengthCandidatesBeforeLive command association
  = PreparedLengthCandidatesCompleted
      ![AssociatedRankedLengthCandidate association]
  | PreparedLengthCandidatesFailed !LengthRankingFailure
  | PreparedLengthCandidatesNeedLive
      ![AssociatedRankedLengthCandidate association]
      !(LengthCounterexampleBankCursor command)
      !Natural
      !association
      !CheckedLengthQuery
      ![PreparedLengthCandidate association]

type role PreparedLengthCandidatesBeforeLive nominal nominal

runPreparedCandidatesWithDeferredLiveSessionOpening
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO (AssociatedLengthRanking association)
runPreparedCandidatesWithDeferredLiveSessionOpening execution evaluation
    policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy cursor prepared
  case beforeLive of
    PreparedLengthCandidatesCompleted assessed -> pure
      $ AssociatedLengthRanking (stableCounterexampleDemotion assessed) Nothing
    PreparedLengthCandidatesFailed failure -> pure
      $ unassessedRanking prepared failure
    PreparedLengthCandidatesNeedLive reversed nextCursor index association query
        rest -> do
      scoped <- withLengthSMTLibLiveSession execution $ \session -> do
        observed <- runLengthSMTLibLiveQuery evaluation session query
        case observed of
          Left failure -> pure $ Left $ queryRankingFailure index failure
          Right observation -> case
              assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                simplificationPolicy index association query observation of
            Left failure -> pure $ Left failure
            Right (assessed, origin) -> do
              advanced <- advanceLengthCounterexampleBankCursor evaluation index
                query (LengthCounterexampleFresh origin) assessed nextCursor
              case advanced of
                Left failure -> pure $ Left failure
                Right advancedCursor -> runPreparedCandidatesFrom evaluation
                  policies advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedRanking prepared
          $ sessionRankingFailure failure
        Right (Left failure) -> unassessedRanking prepared failure
        Right (Right assessed) -> AssociatedLengthRanking
          (stableCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


-- | Traverse only query-owned, solver-free sources.  A need-live continuation
-- records the triggering candidate after its pure chain has missed, so opening
-- the worker never repeats that chain.
runPreparedCandidatesBeforeLive
  :: LengthEvaluationLimits
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthCounterexampleBankCursor command
  -> [PreparedLengthCandidate association]
  -> IO (PreparedLengthCandidatesBeforeLive command association)
runPreparedCandidatesBeforeLive evaluation applicableDomainPolicy
    originProbePolicy simplificationPolicy initialCursor = go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ PreparedLengthCandidatesCompleted $ reverse reversed
    PreparedLengthCandidateUnassessed index association refusal : rest ->
      go (AssociatedRankedLengthCandidate index association
            (LengthCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthCandidateEligible index association query : rest -> do
      replayed <- replayLengthCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ PreparedLengthCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation simplificationPolicy
              index association query receipt of
            Left failure -> pure $ PreparedLengthCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association query of
          Left failure -> pure $ PreparedLengthCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample evaluation
              originProbePolicy query of
            Left (LengthSMTLibInputReplayEvaluationRejected failure) -> pure
              $ PreparedLengthCandidatesFailed $ localRankingFailure
                  (LengthRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSMTLibInputReplayAssociationRejected _) -> pure
              $ PreparedLengthCandidatesFailed $ localRankingFailure
                  LengthRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ PreparedLengthCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> pure $ PreparedLengthCandidatesNeedLive
              reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthCounterexampleBankCursor evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ PreparedLengthCandidatesFailed failure
      Right nextCursor -> go (assessed : reversed) nextCursor rest

runPreparedCandidates
  :: LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthRankingFailure
        [AssociatedRankedLengthCandidate association])
runPreparedCandidates evaluation policies cursor session =
  runPreparedCandidatesFrom evaluation policies cursor session []

runPreparedCandidatesFrom
  :: LengthEvaluationLimits
  -> LengthRankingPolicies
  -> LengthCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthCandidate association]
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthRankingFailure
        [AssociatedRankedLengthCandidate association])
runPreparedCandidatesFrom evaluation policies initialCursor session =
  go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthCandidateUnassessed
        index association refusal : rest ->
      go cursor
        (AssociatedRankedLengthCandidate index association
          (LengthCandidatePreparationRefused refusal) : reversed)
        rest
    PreparedLengthCandidateEligible index association query : rest -> do
      replayed <- replayLengthCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Left failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation simplificationPolicy
              index association query receipt of
            Left failure -> pure $ Left failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association query of
          Left failure -> pure $ Left failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample evaluation
              originProbePolicy query of
            Left (LengthSMTLibInputReplayEvaluationRejected failure) -> pure
              $ Left $ localRankingFailure
                  (LengthRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSMTLibInputReplayAssociationRejected _) -> pure
              $ Left $ localRankingFailure
                  LengthRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ Left failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLengthSMTLibLiveQuery evaluation session query
              case observed of
                Left failure -> pure $ Left $ queryRankingFailure index failure
                Right observation -> case
                    assessCandidateWithCounterexampleOrigin evaluation
                      inputBoxPolicy simplificationPolicy index association query
                      observation of
                  Left failure -> pure $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (LengthCounterexampleFresh origin) rest assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthCounterexampleBankCursor evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Left failure
      Right nextCursor ->
        go nextCursor (assessed : reversed) rest

-- | Attempt the current complete applicable-domain traversal. Inapplicability
-- under that algorithm and failures which prevent bounded traversal admission
-- are ordinary misses. Once admission succeeds,
-- evaluation/internal failures or an evidence association mismatch atomically
-- fail the indexed batch.
assessApplicableDomainCandidate
  :: LengthEvaluationLimits
  -> LengthApplicableDomainRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthQuery
  -> Either LengthRankingFailure
      (Maybe (AssociatedRankedLengthCandidate association))
assessApplicableDomainCandidate evaluation policy simplificationPolicy index
    association query =
  case policy of
    LengthApplicableDomainRankingDisabled -> Right Nothing
    LengthApplicableDomainRankingEnabled inputBoxLimits unionLimits -> case
        validateLengthSMTLibQueryApplicableDomain
          evaluation inputBoxLimits unionLimits query of
      Left (LengthSMTLibApplicableDomainValidationAssociationRejected _) ->
        Left $ localRankingFailure LengthRankingEvidenceReplayMismatch index
      Left (LengthSMTLibApplicableDomainValidationRejected failure)
        | applicableDomainAdmissionFailure failure -> Right Nothing
        | otherwise -> Left $ localRankingFailure
            (LengthRankingApplicableDomainValidationFailed failure) index
      Right (LengthApplicableDomainInapplicable _) -> Right Nothing
      Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
        simplifyCounterexampleAssessment evaluation simplificationPolicy
          index association query receipt
      Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
        $ AssociatedRankedLengthCandidate index association
        $ LengthCandidateAssessed
            (ApplicableDomainEstablished receipt) Nothing

applicableDomainAdmissionFailure :: LengthApplicableDomainValidationError -> Bool
applicableDomainAdmissionFailure failure = case failure of
  LengthApplicableDomainProblemInputLimitExceeded {} -> True
  LengthApplicableDomainGeneratedBranchLimitExceeded {} -> True
  LengthApplicableDomainRuleLimitExceeded {} -> True
  LengthApplicableDomainClosureInspectionLimitExceeded {} -> True
  LengthApplicableDomainRetainedBoxLimitExceeded {} -> True
  LengthApplicableDomainMaximumValueRejected {} -> True
  LengthApplicableDomainAssignmentVisitLimitExceeded {} -> True
  LengthApplicableDomainAssignmentLimitExceeded {} -> True
  LengthApplicableDomainAssignmentEvaluationRejected {} -> False
  LengthApplicableDomainInternalEnumerationInvariant -> False

-- | Run no replay at all on the compatibility path.  The enabled path
-- delegates arity and zero construction to the exact sealed query; Leant never
-- fabricates or retains an origin vector before a validated receipt exists.
probeOriginCounterexample
  :: LengthEvaluationLimits
  -> LengthOriginProbeRankingPolicy
  -> CheckedLengthQuery
  -> Either LengthSMTLibInputReplayError
      (Maybe ValidatedLengthCounterexample)
probeOriginCounterexample evaluation policy query = case policy of
  LengthOriginProbeRankingDisabled -> Right Nothing
  LengthOriginProbeRankingEnabled ->
    probeLengthSMTLibCounterexampleAtOrigin evaluation query

solverIndependentAcquisition :: LengthCounterexampleAcquisition command
solverIndependentAcquisition = LengthCounterexampleFresh
  CounterexampleBank.LengthCounterexampleBankReceiptFromSolverIndependentReplay

-- | Replay either the literal compatibility MRU or the caller-owned nominal
-- bank.  Expected per-sample refusals and bounded attempt unavailability are
-- ordinary misses; only structural bank failures become the established
-- indexed evidence-mismatch failure.
replayLengthCounterexampleBankCursor
  :: LengthEvaluationLimits
  -> Natural
  -> CheckedLengthQuery
  -> LengthCounterexampleBankCursor command
  -> IO
      (Either LengthRankingFailure
        (Maybe
          ( ValidatedLengthCounterexample
          , LengthCounterexampleAcquisition command
          )))
replayLengthCounterexampleBankCursor evaluation index query cursor =
  case cursor of
    LengthBatchLocalCounterexampleBank seedBank -> pure $ Right $ case
        replayCounterexampleSeeds evaluation query seedBank of
      Nothing -> Nothing
      Just (inputs, receipt) -> inputs `seq` Just
        (receipt, LengthCounterexampleFromBatchReplay inputs)
    LengthCommandLocalCounterexampleBank context -> do
      replayed <- CounterexampleBank.replayLengthCounterexampleBankInContext
        evaluation query context
      pure $ case replayed of
        Left _ -> Left $ localRankingFailure
          LengthRankingEvidenceReplayMismatch index
        Right outcome -> Right $ case outcome of
          CounterexampleBank.LengthCounterexampleBankContextReplayMiss _ ->
            Nothing
          CounterexampleBank.LengthCounterexampleBankContextReplayAttemptUnavailable
              _ _ -> Nothing
          CounterexampleBank.LengthCounterexampleBankContextReplayHit _ hit ->
            Just
              ( CounterexampleBank.lengthCounterexampleBankContextReplayHitCounterexample
                  hit
              , LengthCounterexampleFromCommandReplay hit
              )

-- | Install the authoritative successor of the cache side effect for one
-- completed assessment.  Recording deliberately leaves the assessment's
-- pre-record receipt untouched; the fresh receipt returned by the bank is
-- cache confirmation only.
advanceLengthCounterexampleBankCursor
  :: LengthEvaluationLimits
  -> Natural
  -> CheckedLengthQuery
  -> LengthCounterexampleAcquisition command
  -> AssociatedRankedLengthCandidate association
  -> LengthCounterexampleBankCursor command
  -> IO
      (Either LengthRankingFailure
        (LengthCounterexampleBankCursor command))
advanceLengthCounterexampleBankCursor evaluation index query acquisition
    assessed cursor = case assessed of
  AssociatedRankedLengthCandidate _ _ state -> case state of
    LengthCandidatePreparationRefused _ -> pure $ Right cursor
    LengthCandidateAssessed assessment simplification -> case assessment of
      Counterexample receipt -> advanceCounterexample receipt simplification
      _ -> pure $ Right cursor
 where
  advanceCounterexample receipt simplification = case cursor of
    LengthBatchLocalCounterexampleBank seedBank -> case acquisition of
      LengthCounterexampleFromCommandReplay _ -> pure $ Left
        $ localRankingFailure LengthRankingEvidenceReplayMismatch index
      LengthCounterexampleFromBatchReplay _ -> promoteBatch seedBank receipt
      LengthCounterexampleFresh _ -> promoteBatch seedBank receipt
    LengthCommandLocalCounterexampleBank context ->
      case (acquisition, simplification) of
        (LengthCounterexampleFromBatchReplay _, _) -> pure $ Left
          $ localRankingFailure LengthRankingEvidenceReplayMismatch index
        (LengthCounterexampleFromCommandReplay hit, Nothing) -> do
          promoted <-
            CounterexampleBank.promoteLengthCounterexampleBankReplayHitInContext
              hit context
          pure $ case promoted of
            Left _ -> Left $ localRankingFailure
              LengthRankingEvidenceReplayMismatch index
            Right () -> Right cursor
        _ -> do
          recorded <-
            CounterexampleBank.recordLengthCounterexampleBankReceiptInContext
              evaluation query (receiptOrigin simplification) receipt context
          pure $ case recorded of
            Left _ -> Left $ localRankingFailure
              LengthRankingEvidenceReplayMismatch index
            Right _ -> Right cursor

  promoteBatch seedBank receipt =
    let promoted = promoteCounterexampleSeed
          (validatedLengthCounterexampleInputs receipt) seedBank
    in promoted `seq` pure (Right
        $ LengthBatchLocalCounterexampleBank promoted)

  receiptOrigin simplification = case simplification of
    Just _ ->
      CounterexampleBank.LengthCounterexampleBankReceiptFromSimplificationReplay
    Nothing -> case acquisition of
      LengthCounterexampleFresh origin -> origin
      LengthCounterexampleFromBatchReplay _ ->
        CounterexampleBank.LengthCounterexampleBankReceiptFromSolverIndependentReplay
      LengthCounterexampleFromCommandReplay _ ->
        CounterexampleBank.LengthCounterexampleBankReceiptFromSolverIndependentReplay

-- | Replay the batch-local seed bank against one checked query, MRU first,
-- returning the first vector that independently yields a counterexample.
-- A seed is only an input vector from an exact receipt.  The later checked
-- query independently evaluates that vector against its own retained problem
-- and associates the resulting evidence back to that problem; no earlier
-- verdict, receipt, provider basis, query identity, or solver observation
-- crosses this edge.  Every rejection and ordinary non-counterexample is a
-- miss, so an older vector can still be attempted.
replayCounterexampleSeeds
  :: LengthEvaluationLimits
  -> CheckedLengthQuery
  -> [[Natural]]
  -> Maybe ([Natural], ValidatedLengthCounterexample)
replayCounterexampleSeeds evaluation query =
  go counterexampleSeedBankMaximumEntries
 where
  go remaining seedBank
    | remaining <= 0 = Nothing
    | otherwise = case seedBank of
        [] -> Nothing
        inputs : rest -> case
            replayLengthSMTLibCounterexampleInputs evaluation query inputs of
          Right (Just receipt) -> Just (inputs, receipt)
          Left (LengthSMTLibInputReplayEvaluationRejected _) ->
            go (remaining - 1) rest
          Left (LengthSMTLibInputReplayAssociationRejected _) ->
            go (remaining - 1) rest
          Right Nothing -> go (remaining - 1) rest

counterexampleSeedBankMaximumEntries :: Int
counterexampleSeedBankMaximumEntries = 4

-- | Promote one counterexample input vector to the front of the batch-local
-- seed bank.
-- Insert at the MRU end, remove every exact duplicate, retain at most the four
-- newest distinct vectors, and force that bounded value before it is retained
-- across another candidate.  The bank never contains receipts or query
-- metadata, and repeated promotions cannot accumulate a lazy history chain.
promoteCounterexampleSeed
  :: [Natural]
  -> [[Natural]]
  -> [[Natural]]
promoteCounterexampleSeed inputs seedBank = force $
  inputs : take (counterexampleSeedBankMaximumEntries - 1)
    (filter (/= inputs) seedBank)

assessedCounterexample
  :: Natural
  -> association
  -> ValidatedLengthCounterexample
  -> Maybe ValidatedLengthCounterexampleSimplification
  -> AssociatedRankedLengthCandidate association
assessedCounterexample index association receipt simplification =
  AssociatedRankedLengthCandidate index association
    $ LengthCandidateAssessed (Counterexample receipt) simplification

-- | Apply the optional simplifier at the single receipt-to-assessment seam.
-- A search-assignment evaluation rejection is a conservative failed trial and
-- retains the already authoritative starting receipt.  Every other admitted
-- simplification failure is an indexed batch failure.  Djex's successful
-- absence likewise retains the original and carries no metadata.
simplifyCounterexampleAssessment
  :: LengthEvaluationLimits
  -> LengthCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthQuery
  -> ValidatedLengthCounterexample
  -> Either LengthRankingFailure
      (AssociatedRankedLengthCandidate association)
simplifyCounterexampleAssessment evaluation policy index association query
    receipt = case policy of
  LengthCounterexampleSimplificationRankingDisabled -> Right
    $ assessedCounterexample index association receipt Nothing
  LengthCounterexampleSimplificationRankingEnabled limits -> case
      simplifyLengthSMTLibQueryCounterexample
        evaluation limits query receipt of
    Left (LengthSMTLibCounterexampleSimplificationRejected
        (LengthCounterexampleSimplificationInputBoxValidationRejected
          LengthInputBoxAssignmentEvaluationRejected {})) -> Right
      $ assessedCounterexample index association receipt Nothing
    Left (LengthSMTLibCounterexampleSimplificationRejected failure) ->
      Left $ localRankingFailure
        (LengthRankingCounterexampleSimplificationFailed failure) index
    Left (LengthSMTLibCounterexampleSimplificationAssociationRejected _) ->
      Left $ localRankingFailure LengthRankingEvidenceReplayMismatch index
    Right Nothing -> Right
      $ assessedCounterexample index association receipt Nothing
    Right (Just simplification) -> Right
      $ assessedCounterexample index association
          (validatedLengthCounterexampleSimplificationCounterexample
            simplification)
          (Just simplification)

assessCandidateWithCounterexampleOrigin
  :: LengthEvaluationLimits
  -> LengthInputBoxRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthQuery
  -> LengthSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthRankingFailure
      ( AssociatedRankedLengthCandidate association
      , CounterexampleBank.LengthCounterexampleBankReceiptOrigin
      )
assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
    simplificationPolicy index association
    query observation = do
  (assessment, origin) <- case
      replayLengthSMTLibLiveQueryObservation query observation of
    Left LengthSMTLibLiveObservationQueryFingerprintMismatch ->
      Left $ localRankingFailure LengthRankingQueryAssociationMismatch index
    Left LengthSMTLibLiveObservationEvidenceProblemMismatch{} ->
      Left $ localRankingFailure LengthRankingEvidenceReplayMismatch index
    Right Nothing -> assessStatus
      $ lengthSMTLibLiveQueryObservationSolverStatus observation
    Right (Just receipt) -> Right
      ( Counterexample receipt
      , CounterexampleBank.LengthCounterexampleBankReceiptFromLiveModel
      )
  case assessment of
    Counterexample receipt -> do
      assessed <- simplifyCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
      pure (assessed, origin)
    _ -> pure
      ( AssociatedRankedLengthCandidate index association
          $ LengthCandidateAssessed assessment Nothing
      , origin
      )
 where
  assessStatus status = case (status, inputBoxPolicy) of
    (SolverUnsatisfiable,
        LengthInputBoxRankingEnabled limits maximums) ->
      case validateLengthSMTLibQueryInputBox
          evaluation limits query maximums of
        Left (LengthSMTLibInputBoxValidationRejected failure) ->
          Left $ localRankingFailure
            (LengthRankingInputBoxValidationFailed failure) index
        Left (LengthSMTLibInputBoxValidationAssociationRejected _) ->
          Left $ localRankingFailure
            LengthRankingEvidenceReplayMismatch index
        Right (LengthInputBoxCounterexample receipt) ->
          Right
            ( Counterexample receipt
            , CounterexampleBank.LengthCounterexampleBankReceiptFromSolverIndependentReplay
            )
        Right (LengthInputBoxValidated receipt) ->
          Right
            ( BoundedPositive receipt
            , CounterexampleBank.LengthCounterexampleBankReceiptFromSolverIndependentReplay
            )
    _ -> Right
      ( Heuristic status
      , CounterexampleBank.LengthCounterexampleBankReceiptFromLiveModel
      )

stableCounterexampleDemotion
  :: [AssociatedRankedLengthCandidate association]
  -> [AssociatedRankedLengthCandidate association]
stableCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
 in retained ++ counterexamples
 where
  hasCounterexample (AssociatedRankedLengthCandidate _ _ state) =
    case candidateAssessment state of
      Counterexample _ -> True
      BoundedPositive _ -> False
      _ -> False

-- | Additive evidence-ordering opt-in for an association-free successful
-- ranking.  A positive finite-box receipt is preferred only when at least one
-- checked assignment satisfied the contract precondition.  Vacuous positive
-- receipts remain in the neutral partition, counterexamples remain last, and
-- relative order is stable within all three partitions.  Operational fallback
-- is returned literally so it cannot be mistaken for a successful preference.
preferNonVacuousBoundedPositiveLengthRanking
  :: LengthRanking
  -> LengthRanking
preferNonVacuousBoundedPositiveLengthRanking ranking = case ranking of
  LengthRanking _ (Just _) -> ranking
  LengthRanking candidates Nothing -> LengthRanking
    (preferNonVacuousBoundedPositiveCandidates candidates) Nothing

-- | Occurrence-associated sibling applied before the post-verification
-- permutation seal.  The exact occurrence handle remains inseparable from its
-- assessment through the stable trichotomy.
preferNonVacuousBoundedPositiveAssociatedLengthRanking
  :: AssociatedLengthRanking association
  -> AssociatedLengthRanking association
preferNonVacuousBoundedPositiveAssociatedLengthRanking ranking = case ranking of
  AssociatedLengthRanking _ (Just _) -> ranking
  AssociatedLengthRanking candidates Nothing -> AssociatedLengthRanking
    (preferNonVacuousBoundedPositiveAssociatedCandidates candidates) Nothing

preferNonVacuousBoundedPositiveCandidates
  :: [RankedLengthCandidate]
  -> [RankedLengthCandidate]
preferNonVacuousBoundedPositiveCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableRankedLengthCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive (RankedLengthCandidate _ _ state) =
    isNonVacuousBoundedPositive $ candidateAssessment state

preferNonVacuousBoundedPositiveAssociatedCandidates
  :: [AssociatedRankedLengthCandidate association]
  -> [AssociatedRankedLengthCandidate association]
preferNonVacuousBoundedPositiveAssociatedCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive
      (AssociatedRankedLengthCandidate _ _ state) =
    isNonVacuousBoundedPositive $ candidateAssessment state

stableRankedLengthCounterexampleDemotion
  :: [RankedLengthCandidate]
  -> [RankedLengthCandidate]
stableRankedLengthCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample (RankedLengthCandidate _ _ state) = case
      candidateAssessment state of
    Counterexample _ -> True
    _ -> False

isNonVacuousBoundedPositive :: LengthRankingAssessment -> Bool
isNonVacuousBoundedPositive assessment = case assessment of
  BoundedPositive receipt ->
    validatedLengthInputBoxApplicableAssignmentCount receipt > 0
  _ -> False

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainLengthRanking
  :: LengthRanking
  -> LengthRanking
preferNonVacuousApplicableDomainLengthRanking ranking = case ranking of
  LengthRanking _ (Just _) -> ranking
  LengthRanking candidates Nothing -> LengthRanking
    (preferNonVacuousApplicableDomainCandidates candidates) Nothing

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedLengthRanking
  :: AssociatedLengthRanking association
  -> AssociatedLengthRanking association
preferNonVacuousApplicableDomainAssociatedLengthRanking ranking = case
    ranking of
  AssociatedLengthRanking _ (Just _) -> ranking
  AssociatedLengthRanking candidates Nothing -> AssociatedLengthRanking
    (preferNonVacuousApplicableDomainAssociatedCandidates candidates) Nothing

preferNonVacuousApplicableDomainCandidates
  :: [RankedLengthCandidate]
  -> [RankedLengthCandidate]
preferNonVacuousApplicableDomainCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableRankedLengthCounterexampleDemotion retained
 where
  hasApplicableDomain (RankedLengthCandidate _ _ state) =
    isNonVacuousApplicableDomain $ candidateAssessment state

preferNonVacuousApplicableDomainAssociatedCandidates
  :: [AssociatedRankedLengthCandidate association]
  -> [AssociatedRankedLengthCandidate association]
preferNonVacuousApplicableDomainAssociatedCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableCounterexampleDemotion retained
 where
  hasApplicableDomain (AssociatedRankedLengthCandidate _ _ state) =
    isNonVacuousApplicableDomain $ candidateAssessment state

isNonVacuousApplicableDomain :: LengthRankingAssessment -> Bool
isNonVacuousApplicableDomain assessment = case assessment of
  ApplicableDomainEstablished receipt ->
    validatedLengthApplicableDomainApplicableAssignmentCount receipt > 0
  _ -> False

unassessedRanking
  :: [PreparedLengthCandidate association]
  -> LengthRankingFailure
  -> AssociatedLengthRanking association
unassessedRanking prepared failure = AssociatedLengthRanking
  (sanitizePreparedCandidates prepared)
  (Just failure)

-- Force the complete already-bounded fallback spine and each sanitized record
-- before exposing the result.  A lazy 'map' would hide the same public values
-- but could retain sealed queries, their checked problems, and command bytes
-- behind an unevaluated tail after an early live failure.
sanitizePreparedCandidates
  :: [PreparedLengthCandidate association]
  -> [AssociatedRankedLengthCandidate association]
sanitizePreparedCandidates = go []
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    candidate : rest ->
      let sanitized = preparedCandidateUnassessed candidate
      in sanitized `seq` go (sanitized : reversed) rest

unpreparedUnassessedRanking
  :: [association]
  -> LengthRankingFailure
  -> AssociatedLengthRanking association
unpreparedUnassessedRanking associations failure = AssociatedLengthRanking
  (go 0 [] associations) (Just failure)
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let candidate = AssociatedRankedLengthCandidate index association
          $ LengthCandidateAssessed Unassessed Nothing
    in candidate `seq` go (index + 1) (candidate : reversed) rest

associatedLengthRankingCleanupIncomplete
  :: AssociatedLengthRanking association
  -> Bool
associatedLengthRankingCleanupIncomplete
    (AssociatedLengthRanking _ Nothing) = False
associatedLengthRankingCleanupIncomplete
    (AssociatedLengthRanking _ (Just failure)) =
  lengthRankingFailureCleanupIncomplete failure

ownerLengthRankingFailure
  :: Bool
  -> LengthSMTLibLiveSessionError
  -> LengthRankingFailure
ownerLengthRankingFailure nestedCleanup ownerFailure =
  case sessionRankingFailure ownerFailure of
    LengthRankingFailure failure cleanup _ -> LengthRankingFailure failure
      (cleanup || nestedCleanup) Nothing

-- Force only ranking-owned structure.  Caller-owned verified receipts and
-- occurrence associations retain their established WHNF boundary.
forceLengthRankingOwnedResult :: LengthRanking -> ()
forceLengthRankingOwnedResult (LengthRanking candidates failure) =
  forceRankedLengthCandidates candidates `seq` forceLengthRankingFailure failure

forceAssociatedLengthRankingOwnedResult
  :: AssociatedLengthRanking association
  -> ()
forceAssociatedLengthRankingOwnedResult
    (AssociatedLengthRanking candidates failure) =
  forceAssociatedRankedLengthCandidates candidates `seq`
    forceLengthRankingFailure failure

forceRankedLengthCandidates :: [RankedLengthCandidate] -> ()
forceRankedLengthCandidates candidates = case candidates of
  [] -> ()
  RankedLengthCandidate index verified state : rest ->
    index `seq` verified `seq` forceLengthCandidateAssessment state `seq`
      forceRankedLengthCandidates rest

forceAssociatedRankedLengthCandidates
  :: [AssociatedRankedLengthCandidate association]
  -> ()
forceAssociatedRankedLengthCandidates candidates = case candidates of
  [] -> ()
  AssociatedRankedLengthCandidate index association state : rest ->
    index `seq` association `seq` forceLengthCandidateAssessment state `seq`
      forceAssociatedRankedLengthCandidates rest

forceLengthCandidateAssessment :: LengthCandidateAssessment -> ()
forceLengthCandidateAssessment state = case state of
  LengthCandidatePreparationRefused refusal -> refusal `seq` ()
  LengthCandidateAssessed assessment simplification ->
    forceLengthRankingAssessment assessment `seq` case simplification of
      Nothing -> ()
      Just receipt -> rnf receipt

forceLengthRankingAssessment :: LengthRankingAssessment -> ()
forceLengthRankingAssessment assessment = case assessment of
  Unassessed -> ()
  Heuristic status -> status `seq` ()
  Counterexample receipt -> rnf receipt
  BoundedPositive receipt -> rnf receipt
  ApplicableDomainEstablished receipt -> rnf receipt

forceLengthRankingFailure :: Maybe LengthRankingFailure -> ()
forceLengthRankingFailure failure = case failure of
  Nothing -> ()
  Just (LengthRankingFailure failureClass cleanup index) ->
    forceLengthRankingFailureClass failureClass `seq`
      cleanup `seq` forceLengthRankingFailureIndex index

forceLengthRankingFailureIndex :: Maybe Natural -> ()
forceLengthRankingFailureIndex index = case index of
  Nothing -> ()
  Just retained -> retained `seq` ()

forceLengthRankingFailureClass :: LengthRankingFailureClass -> ()
forceLengthRankingFailureClass failure = case failure of
  LengthRankingLiveSessionFailed nested -> rnf nested
  LengthRankingLiveQueryFailed nested -> rnf nested
  LengthRankingQueryAssociationMismatch -> ()
  LengthRankingEvidenceReplayMismatch -> ()
  LengthRankingOriginProbeEvaluationFailed nested -> rnf nested
  LengthRankingInputBoxValidationFailed nested -> rnf nested
  LengthRankingApplicableDomainValidationFailed nested -> rnf nested
  LengthRankingCounterexampleSimplificationFailed nested -> rnf nested

forcePreparedLengthCandidates
  :: [PreparedLengthCandidate association]
  -> ()
forcePreparedLengthCandidates prepared = case prepared of
  [] -> ()
  PreparedLengthCandidateUnassessed index association refusal : rest ->
    index `seq` association `seq` refusal `seq`
      forcePreparedLengthCandidates rest
  PreparedLengthCandidateEligible index association query : rest ->
    index `seq` association `seq` query `seq`
      forcePreparedLengthCandidates rest

-- | Reduce a checked-handoff refusal to its stable payload-free phase.
--
-- This classifier inspects only the already-known outer constructor.  Every
-- payload wildcard is intentional: evaluating, retaining, or rendering a raw
-- refusal payload could expose candidate text and private semantic authority.
lengthHandoffPreparationRefusalClass
  :: LengthHandoffRefusal
  -> LengthPreparationRefusalClass
lengthHandoffPreparationRefusalClass refusal = case refusal of
  LengthHandoffNotTypedRoute _ -> LengthPreparationUnsupportedRoute
  LengthHandoffMissingSemanticSidecar ->
    LengthPreparationTypedAuthorityUnavailable
  LengthHandoffRetargetedFragments ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffPremisesPresent ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffSearchGoalChanged ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffSourceGoalVariableMissing _ ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffRequestContextsPresent _ ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffRequestGoalChanged ->
    LengthPreparationCandidateAssociationRejected
  LengthHandoffTypedGraphLost _ ->
    LengthPreparationTypedAuthorityUnavailable
  LengthHandoffRendererRejected _ ->
    LengthPreparationRenderingAssociationRejected
  LengthHandoffRendererNotUnique _ ->
    LengthPreparationRenderingAssociationRejected
  LengthHandoffRendererOrdinalChanged _ ->
    LengthPreparationRenderingAssociationRejected
  LengthHandoffRendererTextChanged _ _ ->
    LengthPreparationRenderingAssociationRejected
  LengthHandoffFamilyUnavailable _ ->
    LengthPreparationSpineBindingUnavailable
  LengthHandoffConstructorUnavailable _ _ ->
    LengthPreparationSpineBindingUnavailable
  LengthHandoffProviderUnavailable _ ->
    LengthPreparationProviderBindingUnavailable
  LengthHandoffProviderAmbiguous _ _ ->
    LengthPreparationProviderBindingUnavailable
  LengthHandoffProviderVariableMissing _ _ ->
    LengthPreparationProviderBindingUnavailable
  LengthHandoffSessionRejected _ -> LengthPreparationSessionRejected
  LengthHandoffContractRejected _ -> LengthPreparationContractRejected
  LengthHandoffProblemRejected _ ->
    LengthPreparationCandidateSemanticsRejected

-- | Reduce a canonical-query construction refusal to its payload-free phase.
-- Like the handoff classifier, this is exhaustive and does not inspect fields.
lengthQueryPreparationRefusalClass
  :: LengthSMTLibQueryError
  -> LengthPreparationRefusalClass
lengthQueryPreparationRefusalClass refusal = case refusal of
  LengthSMTLibModuloDivisorZero ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibQuotientDivisorZero ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibUnexpectedResultVariable ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibInputVariableOutOfRange _ _ ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibNumeralBitLimitExceeded _ _ _ ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibCommandByteLimitExceeded _ _ _ ->
    LengthPreparationQueryConstructionRejected
  LengthSMTLibFingerprintByteLimitExceeded _ _ ->
    LengthPreparationQueryConstructionRejected

localRankingFailure
  :: LengthRankingFailureClass
  -> Natural
  -> LengthRankingFailure
localRankingFailure failure index = LengthRankingFailure
  failure False $ Just index

sessionRankingFailure
  :: LengthSMTLibLiveSessionError
  -> LengthRankingFailure
sessionRankingFailure failure = LengthRankingFailure
  (LengthRankingLiveSessionFailed
    $ lengthSMTLibLiveSessionPrimaryFailure failure)
  (lengthSMTLibLiveSessionCleanupIncomplete failure)
  Nothing

queryRankingFailure
  :: Natural
  -> LengthSMTLibLiveQueryError
  -> LengthRankingFailure
queryRankingFailure index failure = LengthRankingFailure
  (LengthRankingLiveQueryFailed
    $ lengthSMTLibLiveQueryPrimaryFailure failure)
  (lengthSMTLibLiveQueryCleanupIncomplete failure)
  (Just index)
