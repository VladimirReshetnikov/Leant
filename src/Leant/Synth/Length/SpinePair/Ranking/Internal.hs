{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Package-private implementation of conservative live binary-product
-- finite-spine Length ranking.  This is a nominal sibling of the scalar
-- ranking implementation: the complete control flow lives once in
-- "Leant.Synth.Length.Ranking.Generic", and this module owns the product
-- instance of that generic core together with the nominal public vocabulary
-- that instance produces (pair assessment strengths, sanitized failure
-- classes, the four assessment policies, and the opaque ranking, candidate,
-- and post-verification receipt types).  Every exported name and signature is
-- the established one; the values wrap the shared structure in product
-- newtypes so a pair receipt can never be confused with a scalar one.
module Leant.Synth.Length.SpinePair.Ranking.Internal
  ( LengthSpinePairRankingAssessment (..)
  , lengthSpinePairHandoffPreparationRefusalClass
  , lengthSpinePairQueryPreparationRefusalClass
  , RankedLengthSpinePairCandidate
  , rankedLengthSpinePairCandidateOriginalIndex
  , rankedLengthSpinePairCandidateVerified
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidateCounterexampleSimplification
  , rankedLengthSpinePairCandidatePreparationRefusal
  , LengthSpinePairRankingFailureClass (..)
  , LengthSpinePairRankingFailure
  , lengthSpinePairRankingFailureClass
  , lengthSpinePairRankingFailureCleanupIncomplete
  , lengthSpinePairRankingFailureOriginalIndex
  , LengthSpinePairRanking
  , lengthSpinePairRankingCandidates
  , lengthSpinePairRankingFailure
  , preferNonVacuousBoundedPositiveLengthSpinePairRanking
  , preferNonVacuousApplicableDomainLengthSpinePairRanking
  , AssociatedRankedLengthSpinePairCandidate
  , associatedRankedLengthSpinePairCandidateAssociation
  , AssociatedLengthSpinePairRanking
  , associatedLengthSpinePairRankingCandidates
  , preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  , preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
  , PostVerificationLengthSpinePairRanking
  , sealPostVerificationLengthSpinePairRanking
  , postVerificationLengthSpinePairRankingBatch
  , postVerificationLengthSpinePairRankingFailure
  , materializePostVerificationLengthSpinePairRanking
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankPostVerificationLengthSpinePairCandidates
  , rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , LengthSpinePairInputBoxRankingPolicy (..)
  , LengthSpinePairApplicableDomainRankingPolicy (..)
  , LengthSpinePairOriginProbeRankingPolicy (..)
  , LengthSpinePairCounterexampleSimplificationRankingPolicy (..)
  , rankVerifiedLengthSpinePairCandidatesWithRankingPolicies
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , promoteLengthSpinePairCounterexampleSeed
  , replayLengthSpinePairCounterexampleSeeds
  ) where

import Control.DeepSeq (NFData (rnf))
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthBooleanFiniteUnionLimits
  , LengthApplicableDomainValidation (..)
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSpinePairEvaluationError
  , LengthSpinePairCounterexampleSimplificationError (..)
  , LengthSpinePairApplicableDomainValidationError (..)
  , LengthSpinePairInputBoxValidationError (..)
  , LengthSpinePairSMTLibApplicableDomainValidationError (..)
  , LengthSpinePairSMTLibCounterexampleSimplificationError (..)
  , LengthSpinePairSMTLibInputBoxValidationError (..)
  , LengthSpinePairSMTLibInputReplayError (..)
  , LengthSpinePairSMTLibLiveObservationReplayError (..)
  , LengthSpinePairSMTLibLiveQueryError
  , LengthSpinePairSMTLibLiveQueryFailure
  , LengthSpinePairSMTLibQueryError (..)
  , SolverStatus (..)
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairInputBox
  , lengthSpinePairSMTLibLiveQueryCleanupIncomplete
  , lengthSpinePairSMTLibLiveQueryObservationSolverStatus
  , lengthSpinePairSMTLibLiveQueryPrimaryFailure
  , probeLengthSpinePairSMTLibCounterexampleAtOrigin
  , replayLengthSpinePairSMTLibCounterexampleInputs
  , replayLengthSpinePairSMTLibLiveQueryObservation
  , runLengthSpinePairSMTLibLiveQuery
  , simplifyLengthSpinePairSMTLibQueryCounterexample
  , validateLengthSpinePairSMTLibQueryApplicableDomain
  , validateLengthSpinePairSMTLibQueryInputBox
  , validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairCounterexampleInputs
  , validatedLengthSpinePairCounterexampleSimplificationCounterexample
  , validatedLengthSpinePairInputBoxApplicableAssignmentCount
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthSpinePairQuery
  , prepareCheckedLengthSpinePairQuery
  )
import Leant.Synth.Length.Contract (LeanLengthSpinePairContract)
import Leant.Synth.Length.Handoff
  ( LengthSpinePairHandoffRefusal (..))
import Leant.Synth.Length.Ranking.Internal
  ( lengthHandoffPreparationRefusalClass )
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
-- 'LengthSpinePairRankingDomain' instance below; every value type of this module is a
-- nominal wrapper around the shared structure at this tag.
data PairLength

-- | The public assessment strengths.  LengthSpinePairHeuristic status, finite-box success,
-- and complete applicable-domain establishment are neutral unless their
-- corresponding additive preference is explicitly enabled; every replayed
-- counterexample remains stably demoted.
data LengthSpinePairRankingAssessment
  = LengthSpinePairUnassessed
  | LengthSpinePairHeuristic !SolverStatus
  | LengthSpinePairCounterexample !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairBoundedPositive !ValidatedLengthSpinePairInputBox
  | LengthSpinePairApplicableDomainEstablished !ValidatedLengthSpinePairApplicableDomain
  deriving (Eq, Show)

-- | One callback receipt and the assessment made for that exact candidate.
-- The constructor stays private so receipts cannot be detached and paired
-- with another candidate's assessment.
newtype RankedLengthSpinePairCandidate =
  RankedLengthSpinePairCandidate (RankedCandidate PairLength)

-- | Zero-based position of this candidate in the caller's admitted input.
rankedLengthSpinePairCandidateOriginalIndex :: RankedLengthSpinePairCandidate -> Natural
rankedLengthSpinePairCandidateOriginalIndex
    (RankedLengthSpinePairCandidate (RankedCandidate index _ _)) = index

-- | The exact callback receipt this assessment was made for.
rankedLengthSpinePairCandidateVerified
  :: RankedLengthSpinePairCandidate
  -> Verified DetailedVerificationVariant
rankedLengthSpinePairCandidateVerified
    (RankedLengthSpinePairCandidate (RankedCandidate _ verified _)) = verified

-- | Legacy assessment projection; a preparation refusal reads as
-- 'LengthSpinePairUnassessed'.
rankedLengthSpinePairCandidateAssessment
  :: RankedLengthSpinePairCandidate
  -> LengthSpinePairRankingAssessment
rankedLengthSpinePairCandidateAssessment
    (RankedLengthSpinePairCandidate (RankedCandidate _ _ state)) =
  candidateAssessment state

-- | Candidate-local pure preparation refusal, if one occurred.
--
-- 'Nothing' with 'LengthSpinePairUnassessed' means that preparation succeeded but an
-- operational batch failure atomically reset the assessment; callers should
-- inspect 'lengthSpinePairRankingFailure' for that batch-wide cause.
rankedLengthSpinePairCandidatePreparationRefusal
  :: RankedLengthSpinePairCandidate
  -> Maybe LengthPreparationRefusalClass
rankedLengthSpinePairCandidatePreparationRefusal
    (RankedLengthSpinePairCandidate (RankedCandidate _ _ state)) =
  candidatePreparationRefusal state

-- | Metadata for a strict query-owned reduction of this exact candidate's
-- counterexample, when the optional bounded simplifier found one.  The
-- ordinary assessment always carries the final freshly replayed receipt.
rankedLengthSpinePairCandidateCounterexampleSimplification
  :: RankedLengthSpinePairCandidate
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
rankedLengthSpinePairCandidateCounterexampleSimplification
    (RankedLengthSpinePairCandidate (RankedCandidate _ _ state)) =
  candidateSimplification state

-- | Sanitized failure classes.  Nested live and bounded-evaluation failures
-- retain only Djex's closed public diagnostics; association and replay failures
-- deliberately discard their richer internal details here.  Pure
-- handoff/query-sealing refusals are ordinary per-candidate absence of
-- assessment rather than batch failures.
data LengthSpinePairRankingFailureClass
  = LengthSpinePairRankingLiveSessionFailed !LengthSMTLibLiveSessionFailure
  | LengthSpinePairRankingLiveQueryFailed !LengthSpinePairSMTLibLiveQueryFailure
  | LengthSpinePairRankingQueryAssociationMismatch
  | LengthSpinePairRankingEvidenceReplayMismatch
  | LengthSpinePairRankingOriginProbeEvaluationFailed !LengthSpinePairEvaluationError
  | LengthSpinePairRankingInputBoxValidationFailed !LengthSpinePairInputBoxValidationError
  | LengthSpinePairRankingApplicableDomainValidationFailed
      !LengthSpinePairApplicableDomainValidationError
  | LengthSpinePairRankingCounterexampleSimplificationFailed
      !LengthSpinePairCounterexampleSimplificationError
  deriving (Eq, Ord, Show)

-- | One fail-closed ranking failure.  The optional index is the safe,
-- zero-based position in the caller's admitted input, never a solver ordinal.
-- The Boolean copies only Djex's sanitized incomplete-cleanup observation.
data LengthSpinePairRankingFailure = LengthSpinePairRankingFailure
  !LengthSpinePairRankingFailureClass
  !Bool
  !(Maybe Natural)
  deriving (Eq, Ord, Show)

-- | The sanitized batch-failure class.
lengthSpinePairRankingFailureClass
  :: LengthSpinePairRankingFailure
  -> LengthSpinePairRankingFailureClass
lengthSpinePairRankingFailureClass (LengthSpinePairRankingFailure failure _ _) = failure

-- | Whether Djex reported that worker cleanup may be incomplete.
lengthSpinePairRankingFailureCleanupIncomplete :: LengthSpinePairRankingFailure -> Bool
lengthSpinePairRankingFailureCleanupIncomplete
    (LengthSpinePairRankingFailure _ incomplete _) = incomplete

-- | Safe original input index of the failing candidate, when one applies.
lengthSpinePairRankingFailureOriginalIndex
  :: LengthSpinePairRankingFailure
  -> Maybe Natural
lengthSpinePairRankingFailureOriginalIndex (LengthSpinePairRankingFailure _ _ index) = index

-- | Complete all-or-fallback result.  A successful value may be stably
-- reordered.  Any failure contains every original receipt in original order,
-- all 'LengthSpinePairUnassessed', plus one sanitized failure.
newtype LengthSpinePairRanking = LengthSpinePairRanking (Ranking PairLength)

-- | Every admitted candidate, reordered only by a successful assessment.
lengthSpinePairRankingCandidates :: LengthSpinePairRanking -> [RankedLengthSpinePairCandidate]
lengthSpinePairRankingCandidates (LengthSpinePairRanking (Ranking candidates _)) =
  map RankedLengthSpinePairCandidate candidates

-- | The batch-wide sanitized failure behind an all-'LengthSpinePairUnassessed' fallback.
lengthSpinePairRankingFailure :: LengthSpinePairRanking -> Maybe LengthSpinePairRankingFailure
lengthSpinePairRankingFailure (LengthSpinePairRanking (Ranking _ failure)) = failure

-- | Internal ranking result which keeps one caller-owned occurrence handle
-- inseparable from the assessment derived from its receipt.  The association
-- is the only receipt-bearing field in this transient ranking record; the
-- trusted projection edge later erases that association deliberately.
newtype AssociatedRankedLengthSpinePairCandidate association =
  AssociatedRankedLengthSpinePairCandidate
    (AssociatedRankedCandidate PairLength association)

type role AssociatedRankedLengthSpinePairCandidate nominal

-- | The caller-owned association (for example a batch-scoped occurrence
-- handle) carried unchanged beside one ranked candidate.
associatedRankedLengthSpinePairCandidateAssociation
  :: AssociatedRankedLengthSpinePairCandidate association
  -> association
associatedRankedLengthSpinePairCandidateAssociation
    (AssociatedRankedLengthSpinePairCandidate
      (AssociatedRankedCandidate _ association _)) = association

-- | Complete associated plan before its batch-scoped handles are erased.
newtype AssociatedLengthSpinePairRanking association =
  AssociatedLengthSpinePairRanking (AssociatedRanking PairLength association)

type role AssociatedLengthSpinePairRanking nominal

-- | The ranked candidates in their proposed order, each still carrying its
-- association.
associatedLengthSpinePairRankingCandidates
  :: AssociatedLengthSpinePairRanking association
  -> [AssociatedRankedLengthSpinePairCandidate association]
associatedLengthSpinePairRankingCandidates
    (AssociatedLengthSpinePairRanking (AssociatedRanking candidates _)) =
  map AssociatedRankedLengthSpinePairCandidate candidates

-- | One exact sealed permutation and its receipt-free compatibility state.
-- The opaque value stores verified receipts only through the sealed batch.
newtype PostVerificationLengthSpinePairRanking =
  PostVerificationLengthSpinePairRanking (PostVerificationRanking PairLength)

-- | Seal one associated proposal and retain its receipt-free compatibility
-- state in the same fixed operation.  No package caller can pair a summary
-- with an independently sourced same-cardinality batch.
sealPostVerificationLengthSpinePairRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedLengthSpinePairRanking
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError PostVerificationLengthSpinePairRanking
sealPostVerificationLengthSpinePairRanking maximumCandidates input
    (AssociatedLengthSpinePairRanking associated) =
  PostVerificationLengthSpinePairRanking
    <$> sealPostVerificationRanking maximumCandidates input associated

-- | The sealed receipt batch: the sole owner of verified receipts inside a
-- post-verification ranking.
postVerificationLengthSpinePairRankingBatch
  :: PostVerificationLengthSpinePairRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthSpinePairRankingBatch
    (PostVerificationLengthSpinePairRanking (PostVerificationRanking batch _ _)) = batch

-- | The batch-wide ranking failure, if the run ended in one, without
-- materializing the receipt-bearing report.
postVerificationLengthSpinePairRankingFailure
  :: PostVerificationLengthSpinePairRanking
  -> Maybe LengthSpinePairRankingFailure
postVerificationLengthSpinePairRankingFailure
    (PostVerificationLengthSpinePairRanking (PostVerificationRanking _ _ failure)) =
  failure

-- | Materialize the established association-free compatibility report from
-- the sole retained receipt owner and its receipt-free summary.
materializePostVerificationLengthSpinePairRanking
  :: PostVerificationLengthSpinePairRanking
  -> LengthSpinePairRanking
materializePostVerificationLengthSpinePairRanking
    (PostVerificationLengthSpinePairRanking retained) =
  LengthSpinePairRanking $ materializePostVerificationRanking retained

-- | Private orchestration policy.  The disabled constructor is the exact
-- historical path.  The enabled constructor owns only an independently
-- checked traversal limit and caller-supplied finite maxima; it carries no
-- solver observation or behavioral verdict.
data LengthSpinePairInputBoxRankingPolicy
  = LengthSpinePairInputBoxRankingDisabled
  | LengthSpinePairInputBoxRankingEnabled !LengthInputBoxLimits [Natural]

-- | Private permission to attempt the current complete query-owned validation
-- of the precondition-applicable input domain after every MRU miss. Admission
-- limits remain an ordinary miss and no solver observation is retained here.
data LengthSpinePairApplicableDomainRankingPolicy
  = LengthSpinePairApplicableDomainRankingDisabled
  | LengthSpinePairApplicableDomainRankingEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

-- | Private query-owned pre-live probe policy.  The enabled constructor is
-- only permission to run Djex's canonical origin replay after every MRU miss;
-- it carries no arity, input vector, query, receipt, or verdict.
data LengthSpinePairOriginProbeRankingPolicy
  = LengthSpinePairOriginProbeRankingDisabled
  | LengthSpinePairOriginProbeRankingEnabled

-- | Private permission to replace any independently replayed counterexample
-- with Djex's strictly smaller query-owned sibling.  The same bounded policy
-- is applied regardless of whether the starting receipt came from MRU replay,
-- applicable-domain traversal, the origin probe, live replay, or the
-- post-@unsat@ box.  @Nothing@ from Djex retains that exact starting receipt.
data LengthSpinePairCounterexampleSimplificationRankingPolicy
  = LengthSpinePairCounterexampleSimplificationRankingDisabled
  | LengthSpinePairCounterexampleSimplificationRankingEnabled !LengthInputBoxLimits

-- The four nominal policies collapse into the shared policy record at the
-- module boundary; the shared runner never sees the nominal constructors.
rankingPolicies
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> RankingPolicies
rankingPolicies inputBox applicableDomain originProbe simplification =
  RankingPolicies
    (case inputBox of
      LengthSpinePairInputBoxRankingDisabled -> InputBoxDisabled
      LengthSpinePairInputBoxRankingEnabled limits maximums ->
        InputBoxEnabled limits maximums)
    (case applicableDomain of
      LengthSpinePairApplicableDomainRankingDisabled -> ApplicableDomainDisabled
      LengthSpinePairApplicableDomainRankingEnabled boxLimits unionLimits ->
        ApplicableDomainEnabled boxLimits unionLimits)
    (case originProbe of
      LengthSpinePairOriginProbeRankingDisabled -> OriginProbeDisabled
      LengthSpinePairOriginProbeRankingEnabled -> OriginProbeEnabled)
    (case simplification of
      LengthSpinePairCounterexampleSimplificationRankingDisabled ->
        SimplificationDisabled
      LengthSpinePairCounterexampleSimplificationRankingEnabled limits ->
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
rankVerifiedLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidates =
  rankVerifiedWith LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled

-- | Opt in to one query-owned all-zero replay after the bounded MRU bank
-- misses and before live execution.  A counterexample follows the ordinary
-- receipt/MRU path; an ordinary replay miss has no positive authority.
rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithOriginProbe =
  rankVerifiedWith LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled

-- | Opt in to independently validating one exact finite input box after a
-- live @unsat@ observation.  The solver status is only the trigger: Djex owns
-- traversal, evaluation, and exact query/problem association.  Existing
-- counterexample seed replay still runs first and can avoid the live call.
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation execution evaluation
    limits maximums =
  rankVerifiedWith (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled execution evaluation

-- | Compose the independent pre-live origin probe with the established
-- post-@unsat@ finite-box validation.  A probe hit avoids the live query, so
-- no solver status exists which could schedule the box for that candidate.
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe execution
    evaluation limits maximums =
  rankVerifiedWith (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled execution evaluation

-- | Safe associated entry point for the post-verification seam.  The receipt
-- projection is fixed here so callers cannot rank one receipt while retaining
-- another occurrence's batch-scoped handle.
rankPostVerificationLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidates =
  rankPostVerificationWith LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled

-- | Occurrence-associated origin-probe sibling used by the generative
-- post-verification permutation seal.
rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithOriginProbe =
  rankPostVerificationWith LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled

-- | Occurrence-associated opt-in used by the post-verification permutation
-- seal.  The finite-box receipt remains attached to the exact occurrence until
-- that seal deliberately erases the batch-scoped handle.
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation execution
    evaluation limits maximums =
  rankPostVerificationWith (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled execution evaluation

-- | Occurrence-associated composition of the pre-live origin probe and the
-- post-@unsat@ finite-box validator.
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums =
  rankPostVerificationWith (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairApplicableDomainRankingDisabled LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled execution evaluation

-- | Package-private complete policy entrance used by the opaque reusable
-- configuration owner.  The established public runners above keep passing
-- the literal disabled applicable-domain policy.
rankVerifiedLengthSpinePairCandidatesWithRankingPolicies
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy =
  rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager

-- | Complete policy entrance with an explicit worker-opening strategy.  This
-- is package-private so programmatic policies and the current startup decoder
-- can opt in without widening the established public ranking surface.
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates = fmap (fmap $ LengthSpinePairRanking . projectAssociatedRankingWith id)
  $ rankAssociatedCandidatesWithLiveSessionOpening @PairLength
      (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
        simplificationPolicy)
      openingPolicy execution evaluation contract id candidates

-- | Occurrence-associated sibling of the complete private policy entrance.
rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy =
  rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy LengthLiveSessionOpeningEager

-- | Occurrence-associated sibling of the opening-aware complete entrance.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  fmap (fmap AssociatedLengthSpinePairRanking)
    . rankAssociatedCandidatesWithLiveSessionOpening @PairLength
        (rankingPolicies inputBoxPolicy applicableDomainPolicy
          originProbePolicy simplificationPolicy)
        openingPolicy execution evaluation contract
        postVerificationCandidateVerified

-- | Budgeted complete-policy entrance.  Admission remains outside the shared
-- owner; every preparation, pure evidence pass, live operation, final ranking
-- transform, and ranking-owned result thunk is evaluated beneath the one
-- captured usable-work deadline.
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (LengthSpinePairRanking -> LengthSpinePairRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget finalize
    budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithUsableWorkBudget @PairLength budget
    (finalize . LengthSpinePairRanking . projectAssociatedRankingWith id)
    forceLengthSpinePairRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract id

-- | Occurrence-associated budgeted sibling.  The caller supplies only the
-- closed stable ranking transform; occurrence associations retain their
-- established WHNF demand and are never given an 'NFData' requirement.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithUsableWorkBudget @PairLength budget
    (finalize . AssociatedLengthSpinePairRanking)
    forceAssociatedLengthSpinePairRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract postVerificationCandidateVerified

-- | Scoped/checkpointed complete-policy entrance.  It retains the v1
-- admission and atomic-result contract while selecting the additive
-- same-thread owner and explicit bounded-phase checkpoints.
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (LengthSpinePairRanking -> LengthSpinePairRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithScopedUsableWorkBudget @PairLength budget
    (finalize . LengthSpinePairRanking . projectAssociatedRankingWith id)
    forceLengthSpinePairRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract id

-- | Occurrence-associated scoped/checkpointed sibling.  Checkpointing never
-- projects or forces caller-owned occurrence handles beyond their established
-- weak-head boundary.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedCandidatesWithScopedUsableWorkBudget @PairLength budget
    (finalize . AssociatedLengthSpinePairRanking)
    forceAssociatedLengthSpinePairRankingOwnedResult
    (rankingPolicies inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy)
    openingPolicy execution evaluation contract postVerificationCandidateVerified

-- Direct and associated eager runners under the four historical policies.
rankVerifiedWith
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedWith inputBox applicableDomain originProbe simplification
    execution evaluation contract candidates =
  fmap (fmap $ LengthSpinePairRanking . projectAssociatedRankingWith id)
    $ rankAssociatedCandidates @PairLength
        (rankingPolicies inputBox applicableDomain originProbe simplification)
        execution evaluation contract id candidates

rankPostVerificationWith
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationWith inputBox applicableDomain originProbe simplification
    execution evaluation contract =
  fmap (fmap AssociatedLengthSpinePairRanking)
    . rankAssociatedCandidates @PairLength
        (rankingPolicies inputBox applicableDomain originProbe simplification)
        execution evaluation contract postVerificationCandidateVerified

forceLengthSpinePairRankingOwnedResult :: LengthSpinePairRanking -> ()
forceLengthSpinePairRankingOwnedResult (LengthSpinePairRanking ranking) =
  forceRankingOwnedResult ranking

forceAssociatedLengthSpinePairRankingOwnedResult
  :: AssociatedLengthSpinePairRanking association -> ()
forceAssociatedLengthSpinePairRankingOwnedResult (AssociatedLengthSpinePairRanking ranking) =
  forceAssociatedRankingOwnedResult ranking

-- Post-assessment preferences -------------------------------------------------

-- | Additive evidence-ordering opt-in for an association-free successful
-- ranking.  A positive finite-box receipt is preferred only when at least one
-- checked assignment satisfied the contract precondition.  Vacuous positive
-- receipts remain in the neutral partition, counterexamples remain last, and
-- relative order is stable within all three partitions.  Operational fallback
-- is returned literally so it cannot be mistaken for a successful preference.
preferNonVacuousBoundedPositiveLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousBoundedPositiveLengthSpinePairRanking (LengthSpinePairRanking ranking) =
  LengthSpinePairRanking $ preferNonVacuousBoundedPositiveRanking ranking

-- | Occurrence-associated sibling applied before the post-verification
-- permutation seal.  The exact occurrence handle remains inseparable from its
-- assessment through the stable trichotomy.
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
    (AssociatedLengthSpinePairRanking ranking) =
  AssociatedLengthSpinePairRanking
    $ preferNonVacuousBoundedPositiveAssociatedRanking ranking

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousApplicableDomainLengthSpinePairRanking (LengthSpinePairRanking ranking) =
  LengthSpinePairRanking $ preferNonVacuousApplicableDomainRanking ranking

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
    (AssociatedLengthSpinePairRanking ranking) =
  AssociatedLengthSpinePairRanking
    $ preferNonVacuousApplicableDomainAssociatedRanking ranking

-- Seed bank -------------------------------------------------------------------

-- | Independently replay the newest-first seed bank against one exact checked
-- query; see the shared implementation for the miss discipline.
replayLengthSpinePairCounterexampleSeeds
  :: LengthEvaluationLimits
  -> CheckedLengthSpinePairQuery
  -> [[Natural]]
  -> Maybe ([Natural], ValidatedLengthSpinePairCounterexample)
replayLengthSpinePairCounterexampleSeeds =
  Generic.replayCounterexampleSeeds @PairLength

-- | Nominal product-domain name of the shared seed-bank promotion.
promoteLengthSpinePairCounterexampleSeed
  :: [Natural]
  -> [[Natural]]
  -> [[Natural]]
promoteLengthSpinePairCounterexampleSeed = promoteCounterexampleSeed

-- The domain instance ---------------------------------------------------------

instance LengthRankingDomain PairLength where
  type Contract PairLength = LeanLengthSpinePairContract
  type Query PairLength = CheckedLengthSpinePairQuery
  type Assessment PairLength = LengthSpinePairRankingAssessment
  type FailureClass PairLength = LengthSpinePairRankingFailureClass
  type Failure PairLength = LengthSpinePairRankingFailure
  type Counterexample PairLength = ValidatedLengthSpinePairCounterexample
  type InputBox PairLength = ValidatedLengthSpinePairInputBox
  type ApplicableDomain PairLength = ValidatedLengthSpinePairApplicableDomain
  type Simplification PairLength =
    ValidatedLengthSpinePairCounterexampleSimplification
  type LiveError PairLength = LengthSpinePairSMTLibLiveQueryError
  type LiveFailure PairLength = LengthSpinePairSMTLibLiveQueryFailure
  type EvaluationError PairLength = LengthSpinePairEvaluationError
  type InputBoxError PairLength = LengthSpinePairInputBoxValidationError
  type DomainError PairLength = LengthSpinePairApplicableDomainValidationError
  type SimplificationError PairLength =
    LengthSpinePairCounterexampleSimplificationError

  prepareQuery contract verified =
    case prepareCheckedLengthSpinePairQuery contract verified of
      Left refusal -> Left $ lengthSpinePairHandoffPreparationRefusalClass refusal
      Right (Left refusal) -> Left $ lengthSpinePairQueryPreparationRefusalClass refusal
      Right (Right query) -> Right query

  replayInputs evaluation query inputs = replayRejection
    $ replayLengthSpinePairSMTLibCounterexampleInputs evaluation query inputs

  probeAtOrigin evaluation query = replayRejection
    $ probeLengthSpinePairSMTLibCounterexampleAtOrigin evaluation query

  validateApplicableDomain evaluation inputBoxLimits unionLimits query =
    case validateLengthSpinePairSMTLibQueryApplicableDomain
        evaluation inputBoxLimits unionLimits query of
      Left (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
        Left DomainAssociationRejected
      Left (LengthSpinePairSMTLibApplicableDomainValidationRejected failure) ->
        Left $ DomainValidationRejected failure
      Right (LengthApplicableDomainInapplicable _) -> Right DomainInapplicable
      Right (LengthApplicableDomainCounterexample receipt) ->
        Right $ DomainCounterexample receipt
      Right (LengthApplicableDomainEstablished receipt) ->
        Right $ DomainEstablished receipt

  applicableDomainAdmissionFailure failure = case failure of
    LengthSpinePairApplicableDomainProblemInputLimitExceeded {} -> True
    LengthSpinePairApplicableDomainGeneratedBranchLimitExceeded {} -> True
    LengthSpinePairApplicableDomainRuleLimitExceeded {} -> True
    LengthSpinePairApplicableDomainClosureInspectionLimitExceeded {} -> True
    LengthSpinePairApplicableDomainRetainedBoxLimitExceeded {} -> True
    LengthSpinePairApplicableDomainMaximumValueRejected {} -> True
    LengthSpinePairApplicableDomainAssignmentVisitLimitExceeded {} -> True
    LengthSpinePairApplicableDomainAssignmentLimitExceeded {} -> True
    LengthSpinePairApplicableDomainAssignmentEvaluationRejected {} -> False
    LengthSpinePairApplicableDomainInternalEnumerationInvariant -> False

  validateInputBox evaluation limits query maximums =
    case validateLengthSpinePairSMTLibQueryInputBox evaluation limits query maximums of
      Left (LengthSpinePairSMTLibInputBoxValidationRejected failure) ->
        Left $ BoxValidationRejected failure
      Left (LengthSpinePairSMTLibInputBoxValidationAssociationRejected _) ->
        Left BoxAssociationRejected
      Right (LengthInputBoxCounterexample receipt) ->
        Right $ BoxCounterexample receipt
      Right (LengthInputBoxValidated receipt) -> Right $ BoxValidated receipt

  simplifyCounterexample evaluation limits query receipt =
    case simplifyLengthSpinePairSMTLibQueryCounterexample
        evaluation limits query receipt of
      Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected
          (LengthSpinePairCounterexampleSimplificationInputBoxValidationRejected
            LengthSpinePairInputBoxAssignmentEvaluationRejected {})) ->
        Left SimplificationTrialRejected
      Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected failure) ->
        Left $ SimplificationRejected failure
      Left (LengthSpinePairSMTLibCounterexampleSimplificationAssociationRejected _) ->
        Left SimplificationAssociationRejected
      Right simplification -> Right simplification

  simplificationCounterexample =
    validatedLengthSpinePairCounterexampleSimplificationCounterexample
  counterexampleInputs = validatedLengthSpinePairCounterexampleInputs
  inputBoxApplicableAssignmentCount =
    validatedLengthSpinePairInputBoxApplicableAssignmentCount
  applicableDomainApplicableAssignmentCount =
    validatedLengthSpinePairApplicableDomainApplicableAssignmentCount

  runLiveQuery evaluation session query =
    fmap (fmap gate) $ runLengthSpinePairSMTLibLiveQuery evaluation session query
   where
    gate observation =
      case replayLengthSpinePairSMTLibLiveQueryObservation query observation of
        Left LengthSpinePairSMTLibLiveObservationQueryFingerprintMismatch ->
          LiveObservationRejected ObservationQueryFingerprintMismatch
        Left LengthSpinePairSMTLibLiveObservationEvidenceProblemMismatch{} ->
          LiveObservationRejected ObservationEvidenceProblemMismatch
        Right Nothing -> LiveHeuristic
          $ lengthSpinePairSMTLibLiveQueryObservationSolverStatus observation
        Right (Just receipt) -> LiveCounterexample receipt

  liveErrorPrimaryFailure = lengthSpinePairSMTLibLiveQueryPrimaryFailure
  liveErrorCleanupIncomplete = lengthSpinePairSMTLibLiveQueryCleanupIncomplete

  buildAssessment view = case view of
    ViewUnassessed -> LengthSpinePairUnassessed
    ViewHeuristic status -> LengthSpinePairHeuristic status
    ViewCounterexample receipt -> LengthSpinePairCounterexample receipt
    ViewBoundedPositive receipt -> LengthSpinePairBoundedPositive receipt
    ViewApplicableDomainEstablished receipt ->
      LengthSpinePairApplicableDomainEstablished receipt

  viewAssessment assessment = case assessment of
    LengthSpinePairUnassessed -> ViewUnassessed
    LengthSpinePairHeuristic status -> ViewHeuristic status
    LengthSpinePairCounterexample receipt -> ViewCounterexample receipt
    LengthSpinePairBoundedPositive receipt -> ViewBoundedPositive receipt
    LengthSpinePairApplicableDomainEstablished receipt ->
      ViewApplicableDomainEstablished receipt

  buildFailureClass view = case view of
    ViewLiveSessionFailed nested -> LengthSpinePairRankingLiveSessionFailed nested
    ViewLiveQueryFailed nested -> LengthSpinePairRankingLiveQueryFailed nested
    ViewQueryAssociationMismatch -> LengthSpinePairRankingQueryAssociationMismatch
    ViewEvidenceReplayMismatch -> LengthSpinePairRankingEvidenceReplayMismatch
    ViewOriginProbeEvaluationFailed nested ->
      LengthSpinePairRankingOriginProbeEvaluationFailed nested
    ViewInputBoxValidationFailed nested ->
      LengthSpinePairRankingInputBoxValidationFailed nested
    ViewApplicableDomainValidationFailed nested ->
      LengthSpinePairRankingApplicableDomainValidationFailed nested
    ViewCounterexampleSimplificationFailed nested ->
      LengthSpinePairRankingCounterexampleSimplificationFailed nested

  buildFailure = LengthSpinePairRankingFailure
  failureCleanupIncomplete = lengthSpinePairRankingFailureCleanupIncomplete

  forceAssessment assessment = case assessment of
    LengthSpinePairUnassessed -> ()
    LengthSpinePairHeuristic status -> status `seq` ()
    LengthSpinePairCounterexample receipt -> rnf receipt
    LengthSpinePairBoundedPositive receipt -> rnf receipt
    LengthSpinePairApplicableDomainEstablished receipt -> rnf receipt

  forceSimplification = rnf

  forceFailure (LengthSpinePairRankingFailure failureClass cleanup index) =
    forceFailureClass failureClass `seq` cleanup `seq` case index of
      Nothing -> ()
      Just retained -> retained `seq` ()
   where
    forceFailureClass failure = case failure of
      LengthSpinePairRankingLiveSessionFailed nested -> rnf nested
      LengthSpinePairRankingLiveQueryFailed nested -> rnf nested
      LengthSpinePairRankingQueryAssociationMismatch -> ()
      LengthSpinePairRankingEvidenceReplayMismatch -> ()
      LengthSpinePairRankingOriginProbeEvaluationFailed nested -> rnf nested
      LengthSpinePairRankingInputBoxValidationFailed nested -> rnf nested
      LengthSpinePairRankingApplicableDomainValidationFailed nested -> rnf nested
      LengthSpinePairRankingCounterexampleSimplificationFailed nested -> rnf nested

replayRejection
  :: Either LengthSpinePairSMTLibInputReplayError value
  -> Either (ReplayRejection PairLength) value
replayRejection outcome = case outcome of
  Left (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
    Left $ ReplayEvaluationRejected failure
  Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
    Left ReplayAssociationRejected
  Right value -> Right value

-- | Reduce a product-domain checked-handoff refusal to its stable payload-free
-- phase.  Shared refusals reuse the scalar classifier; the product-specific
-- outer constructors are classified here without inspecting payloads.

-- | Reduce a product-domain checked-handoff refusal to its stable payload-free
-- phase.  Shared refusals reuse the scalar classifier; the product-specific
-- outer constructors are classified here without inspecting payloads.
lengthSpinePairHandoffPreparationRefusalClass
  :: LengthSpinePairHandoffRefusal
  -> LengthPreparationRefusalClass
lengthSpinePairHandoffPreparationRefusalClass refusal = case refusal of
  LengthSpinePairHandoffSharedRefusal shared ->
    lengthHandoffPreparationRefusalClass shared
  LengthSpinePairHandoffResultNotCanonicalLeanProd ->
    LengthPreparationCandidateAssociationRejected
  LengthSpinePairHandoffComponentNotConfiguredSpine _ _ ->
    LengthPreparationSpineBindingUnavailable
  LengthSpinePairHandoffContractRejected _ ->
    LengthPreparationContractRejected
  LengthSpinePairHandoffProblemRejected _ ->
    LengthPreparationCandidateSemanticsRejected

-- | Reduce a pair-domain canonical-query construction refusal to its
-- payload-free phase.  Like the handoff classifier, this is exhaustive and
-- does not inspect fields.
lengthSpinePairQueryPreparationRefusalClass
  :: LengthSpinePairSMTLibQueryError
  -> LengthPreparationRefusalClass
lengthSpinePairQueryPreparationRefusalClass refusal = case refusal of
  LengthSpinePairSMTLibUnexpectedResultVariable -> rejected
  LengthSpinePairSMTLibInputVariableOutOfRange _ _ -> rejected
  LengthSpinePairSMTLibQuotientDivisorZero -> rejected
  LengthSpinePairSMTLibModuloDivisorZero -> rejected
  LengthSpinePairSMTLibNumeralBitLimitExceeded _ _ _ -> rejected
  LengthSpinePairSMTLibCommandByteLimitExceeded _ _ _ -> rejected
  LengthSpinePairSMTLibFingerprintByteLimitExceeded _ _ -> rejected
 where
  rejected = LengthPreparationQueryConstructionRejected
