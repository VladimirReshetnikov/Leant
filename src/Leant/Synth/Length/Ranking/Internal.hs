{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Package-private implementation of conservative live Length ranking for
-- the scalar finite-list-spine domain.
--
-- The complete control flow (admission, preparation, the newest-first seed
-- bank, applicable-domain and origin-probe prefixes, live execution, stable
-- demotion, atomic fallback, and the usable-work owners) lives once in
-- "Leant.Synth.Length.Ranking.Generic" and is shared with the binary-product
-- domain.  This module owns the scalar instance of that generic core and the
-- nominal public vocabulary that instance produces: the assessment strengths,
-- the sanitized failure classes, the four assessment policies, and the opaque
-- ranking, candidate, and post-verification receipt types.  Every exported
-- name and signature is the established one; the values wrap the shared
-- structure in scalar newtypes so a scalar receipt can never be confused with
-- a product one.
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
  , promoteCounterexampleSeed
  , replayCounterexampleSeeds
  ) where

import Control.DeepSeq (NFData (rnf))
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthBooleanFiniteUnionLimits
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
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveUsableWorkBudget
  , SolverStatus (..)
  , ValidatedLengthApplicableDomain
  , ValidatedLengthCounterexample
  , ValidatedLengthCounterexampleSimplification
  , ValidatedLengthInputBox
  , lengthSMTLibLiveQueryCleanupIncomplete
  , lengthSMTLibLiveQueryObservationSolverStatus
  , lengthSMTLibLiveQueryPrimaryFailure
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
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareCheckedLengthQuery
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.Handoff (LengthHandoffRefusal (..))
import Leant.Synth.Length.Ranking.Generic hiding (replayCounterexampleSeeds)
import qualified Leant.Synth.Length.Ranking.Generic as Generic
import Leant.Synth.PostVerification
  ( PostVerificationBatch
  , PostVerificationCandidate
  , PostVerificationError
  , PostVerificationInput
  , postVerificationCandidateVerified
  )
import Leant.Synth.Verification (Verified)

-- | The scalar finite-list-spine ranking domain.  This tag selects the
-- 'LengthRankingDomain' instance below; every value type of this module is a
-- nominal wrapper around the shared structure at this tag.
data ScalarLength

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

-- | One callback receipt and the assessment made for that exact candidate.
-- The constructor stays private so receipts cannot be detached and paired
-- with another candidate's assessment.
newtype RankedLengthCandidate =
  RankedLengthCandidate (RankedCandidate ScalarLength)

-- | Zero-based position of this candidate in the caller's admitted input.
rankedLengthCandidateOriginalIndex :: RankedLengthCandidate -> Natural
rankedLengthCandidateOriginalIndex
    (RankedLengthCandidate (RankedCandidate index _ _)) = index

-- | The exact callback receipt this assessment was made for.
rankedLengthCandidateVerified
  :: RankedLengthCandidate
  -> Verified DetailedVerificationVariant
rankedLengthCandidateVerified
    (RankedLengthCandidate (RankedCandidate _ verified _)) = verified

-- | Legacy assessment projection; a preparation refusal reads as
-- 'Unassessed'.
rankedLengthCandidateAssessment
  :: RankedLengthCandidate
  -> LengthRankingAssessment
rankedLengthCandidateAssessment
    (RankedLengthCandidate (RankedCandidate _ _ state)) =
  candidateAssessment state

-- | Candidate-local pure preparation refusal, if one occurred.
--
-- 'Nothing' with 'Unassessed' means that preparation succeeded but an
-- operational batch failure atomically reset the assessment; callers should
-- inspect 'lengthRankingFailure' for that batch-wide cause.
rankedLengthCandidatePreparationRefusal
  :: RankedLengthCandidate
  -> Maybe LengthPreparationRefusalClass
rankedLengthCandidatePreparationRefusal
    (RankedLengthCandidate (RankedCandidate _ _ state)) =
  candidatePreparationRefusal state

-- | Metadata for a strict query-owned reduction of this exact candidate's
-- counterexample, when the optional bounded simplifier found one.  The
-- ordinary assessment always carries the final freshly replayed receipt.
rankedLengthCandidateCounterexampleSimplification
  :: RankedLengthCandidate
  -> Maybe ValidatedLengthCounterexampleSimplification
rankedLengthCandidateCounterexampleSimplification
    (RankedLengthCandidate (RankedCandidate _ _ state)) =
  candidateSimplification state

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
newtype LengthRanking = LengthRanking (Ranking ScalarLength)

-- | Every admitted candidate, reordered only by a successful assessment.
lengthRankingCandidates :: LengthRanking -> [RankedLengthCandidate]
lengthRankingCandidates (LengthRanking (Ranking candidates _)) =
  map RankedLengthCandidate candidates

-- | The batch-wide sanitized failure behind an all-'Unassessed' fallback.
lengthRankingFailure :: LengthRanking -> Maybe LengthRankingFailure
lengthRankingFailure (LengthRanking (Ranking _ failure)) = failure

-- | Internal ranking result which keeps one caller-owned occurrence handle
-- inseparable from the assessment derived from its receipt.  The association
-- is the only receipt-bearing field in this transient ranking record; the
-- trusted projection edge later erases that association deliberately.
newtype AssociatedRankedLengthCandidate association =
  AssociatedRankedLengthCandidate
    (AssociatedRankedCandidate ScalarLength association)

type role AssociatedRankedLengthCandidate nominal

-- | The caller-owned association (for example a batch-scoped occurrence
-- handle) carried unchanged beside one ranked candidate.
associatedRankedLengthCandidateAssociation
  :: AssociatedRankedLengthCandidate association
  -> association
associatedRankedLengthCandidateAssociation
    (AssociatedRankedLengthCandidate
      (AssociatedRankedCandidate _ association _)) = association

-- | Complete associated plan before its batch-scoped handles are erased.
newtype AssociatedLengthRanking association =
  AssociatedLengthRanking (AssociatedRanking ScalarLength association)

type role AssociatedLengthRanking nominal

-- | The ranked candidates in their proposed order, each still carrying its
-- association.
associatedLengthRankingCandidates
  :: AssociatedLengthRanking association
  -> [AssociatedRankedLengthCandidate association]
associatedLengthRankingCandidates
    (AssociatedLengthRanking (AssociatedRanking candidates _)) =
  map AssociatedRankedLengthCandidate candidates

-- | One exact sealed permutation and its receipt-free compatibility state.
-- The opaque value stores verified receipts only through the sealed batch.
newtype PostVerificationLengthRanking =
  PostVerificationLengthRanking (PostVerificationRanking ScalarLength)

-- | Seal one associated proposal and retain its receipt-free compatibility
-- state in the same fixed operation.  No package caller can pair a summary
-- with an independently sourced same-cardinality batch.
sealPostVerificationLengthRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedLengthRanking
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError PostVerificationLengthRanking
sealPostVerificationLengthRanking maximumCandidates input
    (AssociatedLengthRanking associated) =
  PostVerificationLengthRanking
    <$> sealPostVerificationRanking maximumCandidates input associated

-- | The sealed receipt batch: the sole owner of verified receipts inside a
-- post-verification ranking.
postVerificationLengthRankingBatch
  :: PostVerificationLengthRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthRankingBatch
    (PostVerificationLengthRanking (PostVerificationRanking batch _ _)) = batch

-- | The batch-wide ranking failure, if the run ended in one, without
-- materializing the receipt-bearing report.
postVerificationLengthRankingFailure
  :: PostVerificationLengthRanking
  -> Maybe LengthRankingFailure
postVerificationLengthRankingFailure
    (PostVerificationLengthRanking (PostVerificationRanking _ _ failure)) =
  failure

-- | Materialize the established association-free compatibility report from
-- the sole retained receipt owner and its receipt-free summary.
materializePostVerificationLengthRanking
  :: PostVerificationLengthRanking
  -> LengthRanking
materializePostVerificationLengthRanking
    (PostVerificationLengthRanking retained) =
  LengthRanking $ materializePostVerificationRanking retained

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

-- The four nominal policies collapse into the shared policy record at the
-- module boundary; the shared runner never sees the nominal constructors.
rankingPolicies
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> RankingPolicies
rankingPolicies inputBox applicableDomain originProbe simplification =
  RankingPolicies
    (case inputBox of
      LengthInputBoxRankingDisabled -> InputBoxDisabled
      LengthInputBoxRankingEnabled limits maximums ->
        InputBoxEnabled limits maximums)
    (case applicableDomain of
      LengthApplicableDomainRankingDisabled -> ApplicableDomainDisabled
      LengthApplicableDomainRankingEnabled boxLimits unionLimits ->
        ApplicableDomainEnabled boxLimits unionLimits)
    (case originProbe of
      LengthOriginProbeRankingDisabled -> OriginProbeDisabled
      LengthOriginProbeRankingEnabled -> OriginProbeEnabled)
    (case simplification of
      LengthCounterexampleSimplificationRankingDisabled ->
        SimplificationDisabled
      LengthCounterexampleSimplificationRankingEnabled limits ->
        SimplificationEnabled limits)

-- Established public runners --------------------------------------------------

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
rankVerifiedLengthCandidates =
  rankVerifiedWith LengthInputBoxRankingDisabled
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingDisabled
    LengthCounterexampleSimplificationRankingDisabled

-- | Opt in to one query-owned all-zero replay after the bounded MRU bank
-- misses and before live execution.  A counterexample follows the ordinary
-- receipt/MRU path; an ordinary replay miss has no positive authority.
rankVerifiedLengthCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithOriginProbe =
  rankVerifiedWith LengthInputBoxRankingDisabled
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingEnabled
    LengthCounterexampleSimplificationRankingDisabled

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
    limits maximums =
  rankVerifiedWith (LengthInputBoxRankingEnabled limits maximums)
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingDisabled
    LengthCounterexampleSimplificationRankingDisabled execution evaluation

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
rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe execution
    evaluation limits maximums =
  rankVerifiedWith (LengthInputBoxRankingEnabled limits maximums)
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingEnabled
    LengthCounterexampleSimplificationRankingDisabled execution evaluation

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
rankPostVerificationLengthCandidates =
  rankPostVerificationWith LengthInputBoxRankingDisabled
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingDisabled
    LengthCounterexampleSimplificationRankingDisabled

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
rankPostVerificationLengthCandidatesWithOriginProbe =
  rankPostVerificationWith LengthInputBoxRankingDisabled
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingEnabled
    LengthCounterexampleSimplificationRankingDisabled

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
rankPostVerificationLengthCandidatesWithInputBoxValidation execution
    evaluation limits maximums =
  rankPostVerificationWith (LengthInputBoxRankingEnabled limits maximums)
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingDisabled
    LengthCounterexampleSimplificationRankingDisabled execution evaluation

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
    execution evaluation limits maximums =
  rankPostVerificationWith (LengthInputBoxRankingEnabled limits maximums)
    LengthApplicableDomainRankingDisabled LengthOriginProbeRankingEnabled
    LengthCounterexampleSimplificationRankingDisabled execution evaluation

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
    simplificationPolicy =
  rankVerifiedLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager

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
    simplificationPolicy openingPolicy execution evaluation contract
    candidates = fmap (fmap $ LengthRanking . projectAssociatedRankingWith id)
  $ rankAssociatedCandidatesWithLiveSessionOpening @ScalarLength
      (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
        simplificationPolicy)
      openingPolicy execution evaluation contract id candidates

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
    simplificationPolicy =
  rankPostVerificationLengthCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager

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
    simplificationPolicy openingPolicy execution evaluation contract =
  fmap (fmap AssociatedLengthRanking)
    . rankAssociatedCandidatesWithLiveSessionOpening @ScalarLength
        (rankingPolicies inputBoxPolicy applicableDomainPolicy
          originProbePolicy simplificationPolicy)
        openingPolicy execution evaluation contract
        postVerificationCandidateVerified

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
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithUsableWorkBudget @ScalarLength budget
    (finalize . LengthRanking . projectAssociatedRankingWith id)
    forceLengthRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract id

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
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithUsableWorkBudget @ScalarLength budget
    (finalize . AssociatedLengthRanking)
    forceAssociatedLengthRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract postVerificationCandidateVerified

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
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithScopedUsableWorkBudget @ScalarLength budget
    (finalize . LengthRanking . projectAssociatedRankingWith id)
    forceLengthRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract id

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
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithScopedUsableWorkBudget @ScalarLength budget
    (finalize . AssociatedLengthRanking)
    forceAssociatedLengthRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract postVerificationCandidateVerified

-- Direct and associated eager runners under the four historical policies.
rankVerifiedWith
  :: LengthInputBoxRankingPolicy
  -> LengthApplicableDomainRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedWith inputBox applicableDomain originProbe simplification
    execution evaluation contract candidates =
  fmap (fmap $ LengthRanking . projectAssociatedRankingWith id)
    $ rankAssociatedCandidates @ScalarLength
        (rankingPolicies inputBox applicableDomain originProbe simplification)
        execution evaluation contract id candidates

rankPostVerificationWith
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
rankPostVerificationWith inputBox applicableDomain originProbe simplification
    execution evaluation contract =
  fmap (fmap AssociatedLengthRanking)
    . rankAssociatedCandidates @ScalarLength
        (rankingPolicies inputBox applicableDomain originProbe simplification)
        execution evaluation contract postVerificationCandidateVerified

forceLengthRankingOwnedResult :: LengthRanking -> ()
forceLengthRankingOwnedResult (LengthRanking ranking) =
  forceRankingOwnedResult ranking

forceAssociatedLengthRankingOwnedResult
  :: AssociatedLengthRanking association -> ()
forceAssociatedLengthRankingOwnedResult (AssociatedLengthRanking ranking) =
  forceAssociatedRankingOwnedResult ranking

-- Post-assessment preferences -------------------------------------------------

-- | Additive evidence-ordering opt-in for an association-free successful
-- ranking.  A positive finite-box receipt is preferred only when at least one
-- checked assignment satisfied the contract precondition.  Vacuous positive
-- receipts remain in the neutral partition, counterexamples remain last, and
-- relative order is stable within all three partitions.  Operational fallback
-- is returned literally so it cannot be mistaken for a successful preference.
preferNonVacuousBoundedPositiveLengthRanking
  :: LengthRanking
  -> LengthRanking
preferNonVacuousBoundedPositiveLengthRanking (LengthRanking ranking) =
  LengthRanking $ preferNonVacuousBoundedPositiveRanking ranking

-- | Occurrence-associated sibling applied before the post-verification
-- permutation seal.  The exact occurrence handle remains inseparable from its
-- assessment through the stable trichotomy.
preferNonVacuousBoundedPositiveAssociatedLengthRanking
  :: AssociatedLengthRanking association
  -> AssociatedLengthRanking association
preferNonVacuousBoundedPositiveAssociatedLengthRanking
    (AssociatedLengthRanking ranking) =
  AssociatedLengthRanking
    $ preferNonVacuousBoundedPositiveAssociatedRanking ranking

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainLengthRanking
  :: LengthRanking
  -> LengthRanking
preferNonVacuousApplicableDomainLengthRanking (LengthRanking ranking) =
  LengthRanking $ preferNonVacuousApplicableDomainRanking ranking

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedLengthRanking
  :: AssociatedLengthRanking association
  -> AssociatedLengthRanking association
preferNonVacuousApplicableDomainAssociatedLengthRanking
    (AssociatedLengthRanking ranking) =
  AssociatedLengthRanking
    $ preferNonVacuousApplicableDomainAssociatedRanking ranking

-- Seed bank -------------------------------------------------------------------

-- | Independently replay the newest-first seed bank against one exact checked
-- query; see the shared implementation for the miss discipline.
replayCounterexampleSeeds
  :: LengthEvaluationLimits
  -> CheckedLengthQuery
  -> [[Natural]]
  -> Maybe ([Natural], ValidatedLengthCounterexample)
replayCounterexampleSeeds = Generic.replayCounterexampleSeeds @ScalarLength

-- The domain instance ---------------------------------------------------------

instance LengthRankingDomain ScalarLength where
  type Contract ScalarLength = LeanLengthContract
  type Query ScalarLength = CheckedLengthQuery
  type Assessment ScalarLength = LengthRankingAssessment
  type FailureClass ScalarLength = LengthRankingFailureClass
  type Failure ScalarLength = LengthRankingFailure
  type Counterexample ScalarLength = ValidatedLengthCounterexample
  type InputBox ScalarLength = ValidatedLengthInputBox
  type ApplicableDomain ScalarLength = ValidatedLengthApplicableDomain
  type Simplification ScalarLength =
    ValidatedLengthCounterexampleSimplification
  type LiveError ScalarLength = LengthSMTLibLiveQueryError
  type LiveFailure ScalarLength = LengthSMTLibLiveQueryFailure
  type EvaluationError ScalarLength = LengthEvaluationError
  type InputBoxError ScalarLength = LengthInputBoxValidationError
  type DomainError ScalarLength = LengthApplicableDomainValidationError
  type SimplificationError ScalarLength =
    LengthCounterexampleSimplificationError

  prepareQuery contract verified =
    case prepareCheckedLengthQuery contract verified of
      Left refusal -> Left $ lengthHandoffPreparationRefusalClass refusal
      Right (Left refusal) -> Left $ lengthQueryPreparationRefusalClass refusal
      Right (Right query) -> Right query

  replayInputs evaluation query inputs = replayRejection
    $ replayLengthSMTLibCounterexampleInputs evaluation query inputs

  probeAtOrigin evaluation query = replayRejection
    $ probeLengthSMTLibCounterexampleAtOrigin evaluation query

  validateApplicableDomain evaluation inputBoxLimits unionLimits query =
    case validateLengthSMTLibQueryApplicableDomain
        evaluation inputBoxLimits unionLimits query of
      Left (LengthSMTLibApplicableDomainValidationAssociationRejected _) ->
        Left DomainAssociationRejected
      Left (LengthSMTLibApplicableDomainValidationRejected failure) ->
        Left $ DomainValidationRejected failure
      Right (LengthApplicableDomainInapplicable _) -> Right DomainInapplicable
      Right (LengthApplicableDomainCounterexample receipt) ->
        Right $ DomainCounterexample receipt
      Right (LengthApplicableDomainEstablished receipt) ->
        Right $ DomainEstablished receipt

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

  validateInputBox evaluation limits query maximums =
    case validateLengthSMTLibQueryInputBox evaluation limits query maximums of
      Left (LengthSMTLibInputBoxValidationRejected failure) ->
        Left $ BoxValidationRejected failure
      Left (LengthSMTLibInputBoxValidationAssociationRejected _) ->
        Left BoxAssociationRejected
      Right (LengthInputBoxCounterexample receipt) ->
        Right $ BoxCounterexample receipt
      Right (LengthInputBoxValidated receipt) -> Right $ BoxValidated receipt

  simplifyCounterexample evaluation limits query receipt =
    case simplifyLengthSMTLibQueryCounterexample
        evaluation limits query receipt of
      Left (LengthSMTLibCounterexampleSimplificationRejected
          (LengthCounterexampleSimplificationInputBoxValidationRejected
            LengthInputBoxAssignmentEvaluationRejected {})) ->
        Left SimplificationTrialRejected
      Left (LengthSMTLibCounterexampleSimplificationRejected failure) ->
        Left $ SimplificationRejected failure
      Left (LengthSMTLibCounterexampleSimplificationAssociationRejected _) ->
        Left SimplificationAssociationRejected
      Right simplification -> Right simplification

  simplificationCounterexample =
    validatedLengthCounterexampleSimplificationCounterexample
  counterexampleInputs = validatedLengthCounterexampleInputs
  inputBoxApplicableAssignmentCount =
    validatedLengthInputBoxApplicableAssignmentCount
  applicableDomainApplicableAssignmentCount =
    validatedLengthApplicableDomainApplicableAssignmentCount

  runLiveQuery evaluation session query =
    fmap (fmap gate) $ runLengthSMTLibLiveQuery evaluation session query
   where
    gate observation =
      case replayLengthSMTLibLiveQueryObservation query observation of
        Left LengthSMTLibLiveObservationQueryFingerprintMismatch ->
          LiveObservationRejected ObservationQueryFingerprintMismatch
        Left LengthSMTLibLiveObservationEvidenceProblemMismatch{} ->
          LiveObservationRejected ObservationEvidenceProblemMismatch
        Right Nothing -> LiveHeuristic
          $ lengthSMTLibLiveQueryObservationSolverStatus observation
        Right (Just receipt) -> LiveCounterexample receipt

  liveErrorPrimaryFailure = lengthSMTLibLiveQueryPrimaryFailure
  liveErrorCleanupIncomplete = lengthSMTLibLiveQueryCleanupIncomplete

  buildAssessment view = case view of
    ViewUnassessed -> Unassessed
    ViewHeuristic status -> Heuristic status
    ViewCounterexample receipt -> Counterexample receipt
    ViewBoundedPositive receipt -> BoundedPositive receipt
    ViewApplicableDomainEstablished receipt ->
      ApplicableDomainEstablished receipt

  viewAssessment assessment = case assessment of
    Unassessed -> ViewUnassessed
    Heuristic status -> ViewHeuristic status
    Counterexample receipt -> ViewCounterexample receipt
    BoundedPositive receipt -> ViewBoundedPositive receipt
    ApplicableDomainEstablished receipt ->
      ViewApplicableDomainEstablished receipt

  buildFailureClass view = case view of
    ViewLiveSessionFailed nested -> LengthRankingLiveSessionFailed nested
    ViewLiveQueryFailed nested -> LengthRankingLiveQueryFailed nested
    ViewQueryAssociationMismatch -> LengthRankingQueryAssociationMismatch
    ViewEvidenceReplayMismatch -> LengthRankingEvidenceReplayMismatch
    ViewOriginProbeEvaluationFailed nested ->
      LengthRankingOriginProbeEvaluationFailed nested
    ViewInputBoxValidationFailed nested ->
      LengthRankingInputBoxValidationFailed nested
    ViewApplicableDomainValidationFailed nested ->
      LengthRankingApplicableDomainValidationFailed nested
    ViewCounterexampleSimplificationFailed nested ->
      LengthRankingCounterexampleSimplificationFailed nested

  buildFailure = LengthRankingFailure
  failureCleanupIncomplete = lengthRankingFailureCleanupIncomplete

  forceAssessment assessment = case assessment of
    Unassessed -> ()
    Heuristic status -> status `seq` ()
    Counterexample receipt -> rnf receipt
    BoundedPositive receipt -> rnf receipt
    ApplicableDomainEstablished receipt -> rnf receipt

  forceSimplification = rnf

  forceFailure (LengthRankingFailure failureClass cleanup index) =
    forceFailureClass failureClass `seq` cleanup `seq` case index of
      Nothing -> ()
      Just retained -> retained `seq` ()
   where
    forceFailureClass failure = case failure of
      LengthRankingLiveSessionFailed nested -> rnf nested
      LengthRankingLiveQueryFailed nested -> rnf nested
      LengthRankingQueryAssociationMismatch -> ()
      LengthRankingEvidenceReplayMismatch -> ()
      LengthRankingOriginProbeEvaluationFailed nested -> rnf nested
      LengthRankingInputBoxValidationFailed nested -> rnf nested
      LengthRankingApplicableDomainValidationFailed nested -> rnf nested
      LengthRankingCounterexampleSimplificationFailed nested -> rnf nested

replayRejection
  :: Either LengthSMTLibInputReplayError value
  -> Either (ReplayRejection ScalarLength) value
replayRejection outcome = case outcome of
  Left (LengthSMTLibInputReplayEvaluationRejected failure) ->
    Left $ ReplayEvaluationRejected failure
  Left (LengthSMTLibInputReplayAssociationRejected _) ->
    Left ReplayAssociationRejected
  Right value -> Right value

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
