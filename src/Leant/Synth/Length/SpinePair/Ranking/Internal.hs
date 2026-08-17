{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live binary-product
-- finite-spine Length ranking.  This is a nominal sibling of the scalar
-- ranking implementation: it shares only domain-neutral policy, admission,
-- and diagnostic vocabulary.  Its additive post-assessment preference keeps
-- pair receipts and occurrence handles nominal throughout the stable
-- non-vacuous-positive/neutral/counterexample trichotomy.
-- Its additive usable-work entrance is the nominal product sibling of the
-- scalar owner: admission precedes capture, preparation and live work share
-- one deadline, and the outer normal-return check observes the completed
-- nested final-readiness/cleanup stages without interrupting them.
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
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  , promoteLengthSpinePairCounterexampleSeed
  , replayLengthSpinePairCounterexampleSeeds
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
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveScopedUsableWorkDeadline
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSMTLibLiveUsableWorkDeadline
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
  , LengthSpinePairSMTLibLiveQueryObservation
  , LengthSpinePairSMTLibQueryError (..)
  , SolverStatus (..)
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairInputBox
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
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
  , checkLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveSession
  , withLengthSMTLibLiveSessionUnderScopedDeadline
  , withLengthSMTLibLiveSessionUnderDeadline
  , withLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveUsableWorkDeadline
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthSpinePairQuery
  , prepareCheckedLengthSpinePairQuery
  )
import Leant.Synth.Length.Contract (LeanLengthSpinePairContract)
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.Handoff
  ( LengthSpinePairHandoffRefusal (..))
import Leant.Synth.Length.Ranking.Internal
  ( LengthLiveSessionOpeningPolicy (..)
  , LengthPreparationRefusalClass (..)
  , LengthRankingInputError (..)
  , lengthHandoffPreparationRefusalClass
  )
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

-- | Pair-domain assessment strengths.  Positive receipts affect ordering only
-- through their independent additive preferences; every independently
-- replayed counterexample remains stably demoted.
data LengthSpinePairRankingAssessment
  = LengthSpinePairUnassessed
  | LengthSpinePairHeuristic !SolverStatus
  | LengthSpinePairCounterexample
      !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairBoundedPositive !ValidatedLengthSpinePairInputBox
  | LengthSpinePairApplicableDomainEstablished
      !ValidatedLengthSpinePairApplicableDomain
  deriving (Eq, Show)

data LengthSpinePairCandidateAssessment
  = LengthSpinePairCandidatePreparationRefused
      !LengthPreparationRefusalClass
  | LengthSpinePairCandidateAssessed
      !LengthSpinePairRankingAssessment
      !(Maybe ValidatedLengthSpinePairCounterexampleSimplification)

-- | One callback receipt and the pair-domain assessment made for that exact
-- candidate.  The constructor stays private so receipts cannot be detached
-- and paired with another candidate's assessment.
data RankedLengthSpinePairCandidate = RankedLengthSpinePairCandidate
  !Natural
  !(Verified DetailedVerificationVariant)
  !LengthSpinePairCandidateAssessment

-- | Zero-based position of this candidate in the caller's admitted input.
rankedLengthSpinePairCandidateOriginalIndex
  :: RankedLengthSpinePairCandidate
  -> Natural
rankedLengthSpinePairCandidateOriginalIndex
    (RankedLengthSpinePairCandidate index _ _) = index

-- | The exact callback receipt this assessment was made for.
rankedLengthSpinePairCandidateVerified
  :: RankedLengthSpinePairCandidate
  -> Verified DetailedVerificationVariant
rankedLengthSpinePairCandidateVerified
    (RankedLengthSpinePairCandidate _ verified _) = verified

-- | Assessment projection; a preparation refusal reads as
-- 'LengthSpinePairUnassessed'.
rankedLengthSpinePairCandidateAssessment
  :: RankedLengthSpinePairCandidate
  -> LengthSpinePairRankingAssessment
rankedLengthSpinePairCandidateAssessment
    (RankedLengthSpinePairCandidate _ _ state) =
  spinePairCandidateAssessment state

-- | Candidate-local pure preparation refusal, if one occurred.
--
-- 'Nothing' with 'LengthSpinePairUnassessed' means that preparation
-- succeeded but an operational batch failure atomically reset the
-- assessment; callers should inspect 'lengthSpinePairRankingFailure' for
-- that batch-wide cause.
rankedLengthSpinePairCandidatePreparationRefusal
  :: RankedLengthSpinePairCandidate
  -> Maybe LengthPreparationRefusalClass
rankedLengthSpinePairCandidatePreparationRefusal
    (RankedLengthSpinePairCandidate _ _ state) =
  spinePairCandidatePreparationRefusal state

spinePairCandidateAssessment
  :: LengthSpinePairCandidateAssessment
  -> LengthSpinePairRankingAssessment
spinePairCandidateAssessment state = case state of
  LengthSpinePairCandidatePreparationRefused _ ->
    LengthSpinePairUnassessed
  LengthSpinePairCandidateAssessed assessment _ -> assessment

spinePairCandidatePreparationRefusal
  :: LengthSpinePairCandidateAssessment
  -> Maybe LengthPreparationRefusalClass
spinePairCandidatePreparationRefusal state = case state of
  LengthSpinePairCandidatePreparationRefused refusal -> Just refusal
  LengthSpinePairCandidateAssessed _ _ -> Nothing

-- | Metadata for a strict query-owned reduction of this exact candidate's
-- pair counterexample, when the optional bounded simplifier found one.  The
-- ordinary assessment always carries the final freshly replayed receipt.
rankedLengthSpinePairCandidateCounterexampleSimplification
  :: RankedLengthSpinePairCandidate
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
rankedLengthSpinePairCandidateCounterexampleSimplification
    (RankedLengthSpinePairCandidate _ _ state) = case state of
  LengthSpinePairCandidatePreparationRefused _ -> Nothing
  LengthSpinePairCandidateAssessed _ simplification -> simplification

-- | Sanitized pair-domain failure classes.  Nested live and
-- bounded-evaluation failures retain only Djex's closed public diagnostics;
-- association and replay failures deliberately discard their richer internal
-- details here.  Pure handoff/query-sealing refusals are ordinary
-- per-candidate absence of assessment rather than batch failures.
data LengthSpinePairRankingFailureClass
  = LengthSpinePairRankingLiveSessionFailed
      !LengthSMTLibLiveSessionFailure
  | LengthSpinePairRankingLiveQueryFailed
      !LengthSpinePairSMTLibLiveQueryFailure
  | LengthSpinePairRankingQueryAssociationMismatch
  | LengthSpinePairRankingEvidenceReplayMismatch
  | LengthSpinePairRankingOriginProbeEvaluationFailed
      !LengthSpinePairEvaluationError
  | LengthSpinePairRankingInputBoxValidationFailed
      !LengthSpinePairInputBoxValidationError
  | LengthSpinePairRankingApplicableDomainValidationFailed
      !LengthSpinePairApplicableDomainValidationError
  | LengthSpinePairRankingCounterexampleSimplificationFailed
      !LengthSpinePairCounterexampleSimplificationError
  deriving (Eq, Ord, Show)

-- | One fail-closed pair ranking failure.  The optional index is the safe,
-- zero-based position in the caller's admitted input, never a solver
-- ordinal.  The Boolean copies only Djex's sanitized incomplete-cleanup
-- observation.
data LengthSpinePairRankingFailure = LengthSpinePairRankingFailure
  !LengthSpinePairRankingFailureClass
  !Bool
  !(Maybe Natural)
  deriving (Eq, Ord, Show)

-- | The sanitized batch-failure class.
lengthSpinePairRankingFailureClass
  :: LengthSpinePairRankingFailure
  -> LengthSpinePairRankingFailureClass
lengthSpinePairRankingFailureClass
    (LengthSpinePairRankingFailure failure _ _) = failure

-- | Whether Djex reported that worker cleanup may be incomplete.
lengthSpinePairRankingFailureCleanupIncomplete
  :: LengthSpinePairRankingFailure
  -> Bool
lengthSpinePairRankingFailureCleanupIncomplete
    (LengthSpinePairRankingFailure _ incomplete _) = incomplete

-- | Safe original input index of the failing candidate, when one applies.
lengthSpinePairRankingFailureOriginalIndex
  :: LengthSpinePairRankingFailure
  -> Maybe Natural
lengthSpinePairRankingFailureOriginalIndex
    (LengthSpinePairRankingFailure _ _ index) = index

-- | Complete all-or-fallback pair result.  A successful value may be stably
-- reordered.  Any failure contains every original receipt in original order,
-- all 'LengthSpinePairUnassessed', plus one sanitized failure.
data LengthSpinePairRanking = LengthSpinePairRanking
  ![RankedLengthSpinePairCandidate]
  !(Maybe LengthSpinePairRankingFailure)

-- | Every admitted candidate, reordered only by a successful assessment.
lengthSpinePairRankingCandidates
  :: LengthSpinePairRanking
  -> [RankedLengthSpinePairCandidate]
lengthSpinePairRankingCandidates
    (LengthSpinePairRanking candidates _) = candidates

-- | The batch-wide sanitized failure behind an
-- all-'LengthSpinePairUnassessed' fallback.
lengthSpinePairRankingFailure
  :: LengthSpinePairRanking
  -> Maybe LengthSpinePairRankingFailure
lengthSpinePairRankingFailure
    (LengthSpinePairRanking _ failure) = failure

-- | Internal pair ranking result which keeps one caller-owned occurrence
-- handle inseparable from the assessment derived from its receipt.  The
-- association is the only receipt-bearing field in this transient ranking
-- record; the trusted projection edge later erases that association
-- deliberately.
data AssociatedRankedLengthSpinePairCandidate association =
  AssociatedRankedLengthSpinePairCandidate
    !Natural
    !association
    !LengthSpinePairCandidateAssessment

type role AssociatedRankedLengthSpinePairCandidate nominal

-- | The caller-owned occurrence handle this assessment was derived from.
-- This is the only receipt-bearing projection of the transient record.
associatedRankedLengthSpinePairCandidateAssociation
  :: AssociatedRankedLengthSpinePairCandidate association
  -> association
associatedRankedLengthSpinePairCandidateAssociation
    (AssociatedRankedLengthSpinePairCandidate _ association _) = association

-- | Complete associated pair plan before its batch-scoped handles are erased.
data AssociatedLengthSpinePairRanking association =
  AssociatedLengthSpinePairRanking
    ![AssociatedRankedLengthSpinePairCandidate association]
    !(Maybe LengthSpinePairRankingFailure)

type role AssociatedLengthSpinePairRanking nominal

-- | Every admitted associated candidate, reordered only by a successful
-- assessment; on failure they stay in original order, all
-- 'LengthSpinePairUnassessed'.
associatedLengthSpinePairRankingCandidates
  :: AssociatedLengthSpinePairRanking association
  -> [AssociatedRankedLengthSpinePairCandidate association]
associatedLengthSpinePairRankingCandidates
    (AssociatedLengthSpinePairRanking candidates _) = candidates

projectAssociatedLengthSpinePairRankingWith
  :: (association -> Verified DetailedVerificationVariant)
  -> AssociatedLengthSpinePairRanking association
  -> LengthSpinePairRanking
projectAssociatedLengthSpinePairRankingWith verifiedFor
    (AssociatedLengthSpinePairRanking candidates failure) =
  LengthSpinePairRanking (go [] candidates) failure
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthSpinePairCandidate index association state : rest ->
      let projected = RankedLengthSpinePairCandidate
            index (verifiedFor association) state
      in projected `seq` go (projected : reversed) rest

-- | One exact sealed permutation and its receipt-free pair compatibility
-- state.  The opaque value stores verified receipts only through the sealed
-- batch.  Its already bounded summary spine is materialized eagerly so no
-- erased epoch handle can survive behind an accepted post-verification
-- result.
data PostVerificationLengthSpinePairRanking =
  PostVerificationLengthSpinePairRanking
    !(PostVerificationBatch DetailedVerificationVariant)
    ![PostVerificationLengthSpinePairCandidateSummary]
    !(Maybe LengthSpinePairRankingFailure)

data PostVerificationLengthSpinePairCandidateSummary =
  PostVerificationLengthSpinePairCandidateSummary
    !Natural
    !LengthSpinePairCandidateAssessment

-- | Seal one associated pair proposal and retain its receipt-free
-- compatibility state in the same fixed operation.  No package caller can
-- pair a summary with an independently sourced same-cardinality batch.
-- Receipt weak-head demand deliberately matches the complete-report
-- projection even though the values are retained only by the sealed
-- 'PostVerificationBatch'.
sealPostVerificationLengthSpinePairRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedLengthSpinePairRanking
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError PostVerificationLengthSpinePairRanking
sealPostVerificationLengthSpinePairRanking maximumCandidates input associated =
    do
  batch <- sealPostVerificationBatch maximumCandidates input
    $ map associatedRankedLengthSpinePairCandidateAssociation
    $ associatedLengthSpinePairRankingCandidates associated
  pure $ retain batch associated
 where
  retain batch
      (AssociatedLengthSpinePairRanking candidates failure) =
    PostVerificationLengthSpinePairRanking batch
      (projectCandidates [] candidates) failure

  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthSpinePairCandidate
        index association state : rest ->
      let verified = postVerificationCandidateVerified association
          projected = PostVerificationLengthSpinePairCandidateSummary
            index state
      in verified `seq` projected `seq`
          projectCandidates (projected : reversed) rest

-- | The sealed permutation batch, the sole owner of the verified receipts
-- behind this pair ranking.  Its candidates are in ranked order.
postVerificationLengthSpinePairRankingBatch
  :: PostVerificationLengthSpinePairRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthSpinePairRankingBatch
    (PostVerificationLengthSpinePairRanking batch _ _) = batch

-- | The batch-wide sanitized failure retained from the sealed associated
-- pair ranking, when its candidates were left 'LengthSpinePairUnassessed'.
postVerificationLengthSpinePairRankingFailure
  :: PostVerificationLengthSpinePairRanking
  -> Maybe LengthSpinePairRankingFailure
postVerificationLengthSpinePairRankingFailure
    (PostVerificationLengthSpinePairRanking _ _ failure) = failure

-- | Materialize the association-free pair compatibility report from the sole
-- retained receipt owner and its receipt-free summary.  Both inputs are
-- package-private products of the same successful seal.  A cardinality
-- mismatch therefore denotes an internal invariant violation rather than a
-- caller-controlled ranking failure.
materializePostVerificationLengthSpinePairRanking
  :: PostVerificationLengthSpinePairRanking
  -> LengthSpinePairRanking
materializePostVerificationLengthSpinePairRanking
    (PostVerificationLengthSpinePairRanking batch summaries failure) =
  LengthSpinePairRanking
    (materialize [] (postVerificationBatchCandidates batch) summaries)
    failure
 where
  materialize reversed verifiedRemaining summaryRemaining =
    case (verifiedRemaining, summaryRemaining) of
      ([], []) -> reverse reversed
      (verified : verifiedRest,
          PostVerificationLengthSpinePairCandidateSummary
            index state : summaryRest) ->
        let projected = RankedLengthSpinePairCandidate index verified state
        in projected `seq` materialize
            (projected : reversed) verifiedRest summaryRest
      _ -> error
        "sealed product post-verification ranking summary cardinality changed"

data PreparedLengthSpinePairCandidate association
  = PreparedLengthSpinePairCandidateUnassessed
      !Natural
      !association
      !LengthPreparationRefusalClass
  | PreparedLengthSpinePairCandidateEligible
      !Natural
      !association
      !CheckedLengthSpinePairQuery

-- | Pair-domain finite input-box validation policy.  The disabled
-- constructor skips the post-@unsat@ box entirely.  The enabled constructor
-- owns only an independently checked traversal limit and caller-supplied
-- finite maxima; it carries no solver observation or behavioral verdict.
data LengthSpinePairInputBoxRankingPolicy
  = LengthSpinePairInputBoxRankingDisabled
  | LengthSpinePairInputBoxRankingEnabled
      !LengthInputBoxLimits [Natural]

-- | Permission to attempt the complete query-owned validation of the
-- precondition-applicable pair input domain after every counterexample-bank
-- miss.  Admission limits remain an ordinary miss and no solver observation
-- is retained here.
data LengthSpinePairApplicableDomainRankingPolicy
  = LengthSpinePairApplicableDomainRankingDisabled
  | LengthSpinePairApplicableDomainRankingEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

-- | Query-owned pre-live probe policy.  The enabled constructor is only
-- permission to run Djex's canonical pair origin replay after every
-- counterexample-bank miss; it carries no input vector, query, receipt, or
-- verdict.
data LengthSpinePairOriginProbeRankingPolicy
  = LengthSpinePairOriginProbeRankingDisabled
  | LengthSpinePairOriginProbeRankingEnabled

-- | Permission to replace any independently replayed pair counterexample with
-- Djex's strictly smaller query-owned sibling.  The same bounded policy is
-- applied regardless of where the starting receipt came from.  @Nothing@ from
-- Djex retains that exact starting receipt.
data LengthSpinePairCounterexampleSimplificationRankingPolicy
  = LengthSpinePairCounterexampleSimplificationRankingDisabled
  | LengthSpinePairCounterexampleSimplificationRankingEnabled
      !LengthInputBoxLimits

-- | The four assessment policies that every internal ranking runner threads
-- together unchanged: bounded input-box validation, applicable-domain
-- validation, the origin probe, and counterexample simplification.  The
-- exported entry points still take the four positionally; they pack them
-- once here so the runner family below can pass one value.  The worker
-- opening policy stays separate because the deferred-opening runners omit it.
data LengthSpinePairRankingPolicies = LengthSpinePairRankingPolicies
  { inputBoxPolicyOf :: !LengthSpinePairInputBoxRankingPolicy
  , applicableDomainPolicyOf :: !LengthSpinePairApplicableDomainRankingPolicy
  , originProbePolicyOf :: !LengthSpinePairOriginProbeRankingPolicy
  , simplificationPolicyOf
      :: !LengthSpinePairCounterexampleSimplificationRankingPolicy
  }

data LengthSpinePairCounterexampleBankCursor command
  = LengthSpinePairBatchLocalCounterexampleBank ![[Natural]]
  | LengthSpinePairCommandLocalCounterexampleBank
      !(CounterexampleBank.LengthSpinePairCounterexampleBankContext
          command ExferenceLocal)

type role LengthSpinePairCounterexampleBankCursor nominal

data LengthSpinePairCounterexampleAcquisition command
  = LengthSpinePairCounterexampleFromBatchReplay ![Natural]
  | LengthSpinePairCounterexampleFromCommandReplay
      !(CounterexampleBank.LengthSpinePairCounterexampleBankContextReplayHit
          command ExferenceLocal)
  | LengthSpinePairCounterexampleFresh
      !CounterexampleBank.BankReceiptOrigin

type role LengthSpinePairCounterexampleAcquisition nominal

-- | Rank one already Lean-callback-verified batch under an explicit
-- binary-product behavioral contract and explicit live/evaluation policies.
--
-- Input admission precedes all behavioral-preparation work.  An empty
-- admitted batch, or one with no eligible candidate, opens no worker.  Every
-- nonempty eligible batch uses exactly one live session and processes its
-- pre-sealed queries serially in original order; a later seed-replay hit can
-- avoid that query's live execution.
rankVerifiedLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidates execution evaluation contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairRankingPolicies LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
        execution evaluation contract id candidates

-- | Opt in to one query-owned pair origin replay after the bounded seed bank
-- misses and before live execution.  A counterexample follows the ordinary
-- receipt/seed-bank path; an ordinary replay miss has no positive authority.
rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithOriginProbe
    execution evaluation contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairRankingPolicies LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
        execution evaluation contract id candidates

-- | Opt in to independently validating one exact finite pair input box after
-- a live @unsat@ observation.  The solver status is only the trigger: Djex
-- owns traversal, evaluation, and exact query/problem association.  Seed
-- replay still runs first and can avoid the live call.
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
    execution evaluation limits maximums contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairRankingPolicies
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
        execution evaluation contract id candidates

-- | Compose the pre-live pair origin probe with the post-@unsat@ finite-box
-- validation.  A probe hit avoids the live query, so no solver status exists
-- which could schedule the box for that candidate.
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairRankingPolicies
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
        execution evaluation contract id candidates

-- | Safe associated pair entry point for the post-verification seam.  The
-- receipt projection is fixed here so callers cannot rank one receipt while
-- retaining another occurrence's batch-scoped handle.
rankPostVerificationLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidates execution evaluation contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairRankingPolicies LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

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
rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
    execution evaluation contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairRankingPolicies LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

-- | Occurrence-associated opt-in used by the post-verification permutation
-- seal.  The finite-box receipt remains attached to the exact occurrence
-- until that seal deliberately erases the batch-scoped handle.
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
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
    execution evaluation limits maximums contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairRankingPolicies
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

-- | Occurrence-associated composition of the pre-live pair origin probe and
-- the post-@unsat@ finite-box validator.
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
    execution evaluation limits maximums contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairRankingPolicies
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled)
    execution evaluation contract postVerificationCandidateVerified

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
    simplificationPolicy execution
    evaluation contract candidates =
  rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy
    LengthLiveSessionOpeningEager execution evaluation contract candidates


-- | Complete pair policy entrance with an explicit worker-opening strategy.
-- This is package-private so programmatic policies and the current startup
-- decoder can opt in without widening the established public ranking
-- surface.
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
    simplificationPolicy
    openingPolicy execution evaluation contract candidates = fmap
      (fmap $ projectAssociatedLengthSpinePairRankingWith id)
  $ rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening policies
      openingPolicy
      execution evaluation contract id candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


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
    simplificationPolicy execution
    evaluation contract =
  rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy
      simplificationPolicy
    LengthLiveSessionOpeningEager execution evaluation contract


-- | Occurrence-associated sibling of the opening-aware complete pair
-- entrance.
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
    simplificationPolicy
    openingPolicy execution evaluation contract =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening policies
    openingPolicy
    execution evaluation contract postVerificationCandidateVerified
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Budgeted complete pair-policy entrance.  Admission remains outside the
-- shared owner; every preparation, pure evidence pass, live operation, final
-- ranking transform, and ranking-owned result thunk is evaluated beneath the
-- one captured usable-work deadline.
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
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget
    (finalize . projectAssociatedLengthSpinePairRankingWith id)
    forceLengthSpinePairRankingOwnedResult policies openingPolicy
    execution evaluation contract id candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Occurrence-associated budgeted pair sibling.  The caller supplies only
-- the closed stable ranking transform; occurrence associations retain their
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
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget finalize
    forceAssociatedLengthSpinePairRankingOwnedResult policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Scoped/checkpointed complete pair-policy entrance.  It retains the v1
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
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    (finalize . projectAssociatedLengthSpinePairRankingWith id)
    forceLengthSpinePairRankingOwnedResult policies openingPolicy
    execution evaluation contract id candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Occurrence-associated scoped/checkpointed pair sibling.  Checkpointing
-- never projects or forces caller-owned occurrence handles beyond their
-- established weak-head boundary.
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
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    finalize forceAssociatedLengthSpinePairRankingOwnedResult policies
    openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy


-- | Additive occurrence-associated pair filter entrance using one
-- caller-owned nominal counterexample bank.  No established ranking entrance
-- calls this function; their raw four-vector seed bank remains literal.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
  :: CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
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
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndLiveSessionOpening
    context inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpeningAndCursor
    (LengthSpinePairCommandLocalCounterexampleBank context) policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy


-- | Budgeted sibling of the pair counterexample-bank filter entrance.  Like
-- the bank-free budgeted runner, admission stays outside the shared owner and
-- all preparation, live work, and the caller's final transform run beneath
-- the one captured usable-work deadline, but counterexample replay and
-- recording go through the supplied command-local bank instead of the
-- batch-local seed bank.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
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
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndUsableWorkBudget
    finalize budget context inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy openingPolicy execution evaluation
    contract candidates =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudgetAndCursor
    (LengthSpinePairCommandLocalCounterexampleBank context) budget finalize
    forceAssociatedLengthSpinePairRankingOwnedResult policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy


-- | Scoped/checkpointed sibling of the pair counterexample-bank filter
-- entrance.  It selects the same-thread scoped owner with explicit
-- bounded-phase checkpoints while replaying and recording counterexamples
-- through the supplied command-local bank instead of the batch-local seed
-- bank.
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
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
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndCounterexampleBankContextAndScopedUsableWorkBudget
    finalize budget context inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy openingPolicy execution evaluation
    contract candidates =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudgetAndCursor
    (LengthSpinePairCommandLocalCounterexampleBank context) budget finalize
    forceAssociatedLengthSpinePairRankingOwnedResult policies openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates
 where
  policies = LengthSpinePairRankingPolicies
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy


data LengthSpinePairUsableWorkSnapshot association =
  LengthSpinePairUsableWorkSnapshot
    ![PreparedLengthSpinePairCandidate association]
    !Bool

type role LengthSpinePairUsableWorkSnapshot nominal

rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget finish
    forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudgetAndCursor
    (LengthSpinePairBatchLocalCounterexampleBank []) budget finish forceResult
    policies openingPolicy execution evaluation contract verifiedFor associations

rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudgetAndCursor
  :: LengthSpinePairCounterexampleBankCursor command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudgetAndCursor cursor
    budget finish forceResult policies openingPolicy execution evaluation
    contract verifiedFor associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveUsableWorkDeadline budget $ \deadline -> do
        let prepared = prepareLengthSpinePairCandidates
              contract verifiedFor admitted
            snapshot = LengthSpinePairUsableWorkSnapshot prepared False
        _ <- evaluate $ forcePreparedLengthSpinePairCandidates prepared
        snapshot `seq` writeIORef snapshotRef (Just snapshot)
        ranking <- runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline
          deadline execution evaluation policies openingPolicy cursor prepared
        let cleanupIncomplete =
              associatedLengthSpinePairRankingCleanupIncomplete ranking
            completedSnapshot = LengthSpinePairUsableWorkSnapshot
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
                Just (LengthSpinePairUsableWorkSnapshot _ incomplete) ->
                  incomplete
              failure = ownerLengthSpinePairRankingFailure
                cleanupIncomplete ownerFailure
              ranking = case snapshot of
                Nothing -> unpreparedUnassessedLengthSpinePairRanking
                  admitted failure
                Just (LengthSpinePairUsableWorkSnapshot prepared _) ->
                  unassessedLengthSpinePairRanking prepared failure
              result = finish ranking
          _ <- evaluate $ forceResult result
          pure $ Right result

rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    finish forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudgetAndCursor
    (LengthSpinePairBatchLocalCounterexampleBank []) budget finish forceResult
    policies openingPolicy execution evaluation contract verifiedFor associations

rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudgetAndCursor
  :: LengthSpinePairCounterexampleBankCursor command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudgetAndCursor
    cursor budget finish forceResult policies openingPolicy execution evaluation
    contract verifiedFor associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveScopedUsableWorkDeadline budget
        $ \deadline -> do
          initial <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
          case initial of
            Left failure -> pure $ Left failure
            Right () -> do
              let prepared = prepareLengthSpinePairCandidates
                    contract verifiedFor admitted
                  snapshot =
                    LengthSpinePairUsableWorkSnapshot prepared False
              _ <- evaluate $ forcePreparedLengthSpinePairCandidates prepared
              snapshot `seq` writeIORef snapshotRef (Just snapshot)
              afterPreparation <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              case afterPreparation of
                Left failure -> pure $ Left failure
                Right () -> do
                  ranked <-
                    runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline
                      deadline execution evaluation policies openingPolicy
                      cursor prepared
                  case ranked of
                    Left failure -> pure $ Left failure
                    Right ranking -> do
                      let cleanupIncomplete =
                            associatedLengthSpinePairRankingCleanupIncomplete
                              ranking
                          completedSnapshot =
                            LengthSpinePairUsableWorkSnapshot
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
          Just (LengthSpinePairUsableWorkSnapshot _ incomplete) -> incomplete
        rankingFailure = ownerLengthSpinePairRankingFailure
          cleanupIncomplete failure
        ranking = case snapshot of
          Nothing -> unpreparedUnassessedLengthSpinePairRanking
            admitted rankingFailure
          Just (LengthSpinePairUsableWorkSnapshot prepared _) ->
            unassessedLengthSpinePairRanking prepared rankingFailure
        result = finish ranking
    _ <- evaluate $ forceResult result
    pure $ Right result

runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline deadline execution
    evaluation policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ AssociatedLengthSpinePairRanking [] Nothing
  _ | not (hasEligibleLengthSpinePairCandidate prepared) -> pure
        $ AssociatedLengthSpinePairRanking
            (map preparedLengthSpinePairCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
            $ \session -> runPreparedLengthSpinePairCandidates evaluation
                policies cursor session prepared
          pure $ case scoped of
            Left failure -> unassessedLengthSpinePairRanking prepared
              $ lengthSpinePairSessionRankingFailure failure
            Right (Left failure) ->
              unassessedLengthSpinePairRanking prepared failure
            Right (Right assessed) -> AssociatedLengthSpinePairRanking
              (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
            deadline execution evaluation policies cursor prepared

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
    deadline execution evaluation policies cursor prepared = do
  beforeLive <- runPreparedLengthSpinePairCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy cursor prepared
  case beforeLive of
    PreparedLengthSpinePairCandidatesCompleted assessed -> pure
      $ AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
    PreparedLengthSpinePairCandidatesFailed failure -> pure
      $ unassessedLengthSpinePairRanking prepared failure
    PreparedLengthSpinePairCandidatesNeedLive reversed nextCursor index
        association query rest -> do
      scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
        $ \session -> do
          observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Left
              $ lengthSpinePairQueryRankingFailure index failure
            Right observation -> case
                assessLengthSpinePairCandidateWithCounterexampleOrigin evaluation
                  inputBoxPolicy simplificationPolicy index association query
                  observation of
              Left failure -> pure $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceLengthSpinePairCounterexampleBankCursor
                  evaluation index query
                  (LengthSpinePairCounterexampleFresh origin) assessed nextCursor
                case advanced of
                  Left failure -> pure $ Left failure
                  Right advancedCursor ->
                    runPreparedLengthSpinePairCandidatesFrom evaluation policies
                      advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedLengthSpinePairRanking prepared
          $ lengthSpinePairSessionRankingFailure failure
        Right (Left failure) ->
          unassessedLengthSpinePairRanking prepared failure
        Right (Right assessed) -> AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthSpinePairRanking association))
runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline deadline
    execution evaluation policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ Right $ AssociatedLengthSpinePairRanking [] Nothing
  _ | not (hasEligibleLengthSpinePairCandidate prepared) -> pure $ Right
        $ AssociatedLengthSpinePairRanking
            (map preparedLengthSpinePairCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
            deadline execution $ \session ->
              runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
                deadline evaluation policies cursor session [] prepared
          pure $ case scoped of
            Left failure -> Right $ unassessedLengthSpinePairRanking prepared
              $ lengthSpinePairSessionRankingFailure failure
            Right (Left failure) -> Left failure
            Right (Right (Left failure)) -> Right
              $ unassessedLengthSpinePairRanking prepared failure
            Right (Right (Right assessed)) -> Right
              $ AssociatedLengthSpinePairRanking
                  (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
            deadline execution evaluation policies cursor prepared

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthSpinePairRanking association))
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
    deadline execution evaluation policies cursor prepared = do
  beforeLive <-
    runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
      deadline evaluation applicableDomainPolicy originProbePolicy
      simplificationPolicy cursor prepared
  case beforeLive of
    Left failure -> pure $ Left failure
    Right (PreparedLengthSpinePairCandidatesCompleted assessed) -> pure $ Right
      $ AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
    Right (PreparedLengthSpinePairCandidatesFailed failure) -> pure $ Right
      $ unassessedLengthSpinePairRanking prepared failure
    Right (PreparedLengthSpinePairCandidatesNeedLive reversed nextCursor index
        association query rest) -> do
      scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
        deadline execution $ \session -> do
          observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Right $ Left
              $ lengthSpinePairQueryRankingFailure index failure
            Right observation -> case
                assessLengthSpinePairCandidateWithCounterexampleOrigin evaluation
                  inputBoxPolicy simplificationPolicy index association query
                  observation of
              Left failure -> pure $ Right $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceLengthSpinePairCounterexampleBankCursor
                  evaluation index query
                  (LengthSpinePairCounterexampleFresh origin) assessed nextCursor
                case advanced of
                  Left failure -> pure $ Right $ Left failure
                  Right advancedCursor -> do
                    checkpoint <-
                      checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
                    case checkpoint of
                      Left failure -> pure $ Left failure
                      Right () ->
                        runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
                          deadline evaluation policies advancedCursor session
                          (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> Right $ unassessedLengthSpinePairRanking prepared
          $ lengthSpinePairSessionRankingFailure failure
        Right (Left failure) -> Left failure
        Right (Right (Left failure)) -> Right
          $ unassessedLengthSpinePairRanking prepared failure
        Right (Right (Right assessed)) -> Right
          $ AssociatedLengthSpinePairRanking
              (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


-- | Check after each complete pure candidate chain.  The individual MRU,
-- applicable-domain, origin, and simplification operations are independently
-- bounded and deliberately remain one indivisible checkpoint quantum.
runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (PreparedLengthSpinePairCandidatesBeforeLive command association))
runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
    deadline evaluation applicableDomainPolicy originProbePolicy
    simplificationPolicy initialCursor = go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ Right
      $ PreparedLengthSpinePairCandidatesCompleted $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      continue
        (AssociatedRankedLengthSpinePairCandidate index association
          (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthSpinePairCandidateEligible index association query : rest -> do
      replayed <- replayLengthSpinePairCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Right
          $ PreparedLengthSpinePairCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyLengthSpinePairCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure $ Right
              $ PreparedLengthSpinePairCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
            association query of
          Left failure -> pure $ Right
            $ PreparedLengthSpinePairCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            lengthSpinePairSolverIndependentAcquisition rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Right $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    (LengthSpinePairRankingOriginProbeEvaluationFailed failure)
                    index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Right $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> pure $ Right
                $ PreparedLengthSpinePairCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                lengthSpinePairSolverIndependentAcquisition rest assessed
            Right Nothing -> do
              checkpoint <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              pure $ case checkpoint of
                Left failure -> Left failure
                Right () -> Right $ PreparedLengthSpinePairCandidatesNeedLive
                  reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthSpinePairCounterexampleBankCursor evaluation index
      query acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right
        $ PreparedLengthSpinePairCandidatesFailed failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go reversed cursor rest

-- | Live sibling which checks after every completed candidate before any
-- following candidate can demand pure replay or another live transaction.
runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthSpinePairCandidate association]
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (Either LengthSpinePairRankingFailure
          [AssociatedRankedLengthSpinePairCandidate association]))
runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline deadline
    evaluation policies initialCursor session = go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ Right $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      continue
        (AssociatedRankedLengthSpinePairCandidate index association
          (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthSpinePairCandidateEligible index association query : rest -> do
      replayed <- replayLengthSpinePairCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Right $ Left failure
        Right (Just (receipt, acquisition)) ->
          case simplifyLengthSpinePairCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure $ Right $ Left failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
            association query of
          Left failure -> pure $ Right $ Left failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            lengthSpinePairSolverIndependentAcquisition rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Right $ Left $ localLengthSpinePairRankingFailure
                (LengthSpinePairRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Right $ Left $ localLengthSpinePairRankingFailure
                LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> pure $ Right $ Left failure
              Right assessed -> continueAssessed reversed cursor index query
                lengthSpinePairSolverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLengthSpinePairSMTLibLiveQuery
                evaluation session query
              case observed of
                Left failure -> pure $ Right $ Left
                  $ lengthSpinePairQueryRankingFailure index failure
                Right observation -> case
                    assessLengthSpinePairCandidateWithCounterexampleOrigin
                      evaluation inputBoxPolicy simplificationPolicy index
                      association query observation of
                  Left failure -> pure $ Right $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (LengthSpinePairCounterexampleFresh origin) rest
                    assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthSpinePairCounterexampleBankCursor evaluation index
      query acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right $ Left failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go cursor reversed rest

rankAssociatedLengthSpinePairCandidates
  :: LengthSpinePairRankingPolicies
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidates policies execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening policies
    LengthLiveSessionOpeningEager execution evaluation contract verifiedFor
    associations

rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening
  :: LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening policies
    openingPolicy
    execution evaluation contract verifiedFor associations =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpeningAndCursor
    (LengthSpinePairBatchLocalCounterexampleBank []) policies openingPolicy
    execution evaluation contract verifiedFor associations

rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpeningAndCursor
  :: LengthSpinePairCounterexampleBankCursor command
  -> LengthSpinePairRankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpeningAndCursor cursor
    policies openingPolicy execution evaluation contract verifiedFor
    associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> case
        prepareLengthSpinePairCandidates contract verifiedFor admitted of
      [] -> pure $ Right $ AssociatedLengthSpinePairRanking [] Nothing
      prepared
        | not $ hasEligibleLengthSpinePairCandidate prepared -> pure $ Right
            $ AssociatedLengthSpinePairRanking
                (map preparedLengthSpinePairCandidateUnassessed prepared)
                Nothing
        | otherwise -> case openingPolicy of
            LengthLiveSessionOpeningEager -> do
              scoped <- withLengthSMTLibLiveSession execution $ \session ->
                runPreparedLengthSpinePairCandidates evaluation policies
                  cursor session prepared
              pure $ Right $ case scoped of
                Left failure -> unassessedLengthSpinePairRanking prepared
                  $ lengthSpinePairSessionRankingFailure failure
                Right (Left failure) ->
                  unassessedLengthSpinePairRanking prepared failure
                Right (Right assessed) -> AssociatedLengthSpinePairRanking
                  (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
            LengthLiveSessionOpeningDeferredUntilLiveQuery -> Right <$>
              runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening
                execution evaluation policies cursor prepared

admitLengthSpinePairCandidates
  :: Natural
  -> [candidate]
  -> Either LengthRankingInputError [candidate]
admitLengthSpinePairCandidates maximumCandidates = go 0 []
 where
  go observed reversed remaining
    | observed >= maximumCandidates = case remaining of
        [] -> Right $ reverse reversed
        _ : _ -> Left $ LengthRankingInputLimitExceeded
          maximumCandidates (maximumCandidates + 1)
    | otherwise = case remaining of
        [] -> Right $ reverse reversed
        candidate : rest -> go (observed + 1) (candidate : reversed) rest

prepareLengthSpinePairCandidates
  :: LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> [PreparedLengthSpinePairCandidate association]
prepareLengthSpinePairCandidates contract verifiedFor = go 0 []
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let prepared = prepareCandidate index association
    in prepared `seq` go (index + 1) (prepared : reversed) rest

  prepareCandidate index association =
    let verified = verifiedFor association
    in case prepareCheckedLengthSpinePairQuery contract verified of
      Left refusal -> PreparedLengthSpinePairCandidateUnassessed
        index association
          $ lengthSpinePairHandoffPreparationRefusalClass refusal
      Right (Left refusal) -> PreparedLengthSpinePairCandidateUnassessed
        index association
          $ lengthSpinePairQueryPreparationRefusalClass refusal
      Right (Right query) -> PreparedLengthSpinePairCandidateEligible
        index association query

hasEligibleLengthSpinePairCandidate
  :: [PreparedLengthSpinePairCandidate association]
  -> Bool
hasEligibleLengthSpinePairCandidate = any isEligible
 where
  isEligible prepared = case prepared of
    PreparedLengthSpinePairCandidateUnassessed {} -> False
    PreparedLengthSpinePairCandidateEligible {} -> True

preparedLengthSpinePairCandidateUnassessed
  :: PreparedLengthSpinePairCandidate association
  -> AssociatedRankedLengthSpinePairCandidate association
preparedLengthSpinePairCandidateUnassessed prepared = case prepared of
  PreparedLengthSpinePairCandidateUnassessed index association refusal ->
    AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidatePreparationRefused refusal
  PreparedLengthSpinePairCandidateEligible index association _ ->
    AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed LengthSpinePairUnassessed Nothing

data PreparedLengthSpinePairCandidatesBeforeLive command association
  = PreparedLengthSpinePairCandidatesCompleted
      ![AssociatedRankedLengthSpinePairCandidate association]
  | PreparedLengthSpinePairCandidatesFailed
      !LengthSpinePairRankingFailure
  | PreparedLengthSpinePairCandidatesNeedLive
      ![AssociatedRankedLengthSpinePairCandidate association]
      !(LengthSpinePairCounterexampleBankCursor command)
      !Natural
      !association
      !CheckedLengthSpinePairQuery
      ![PreparedLengthSpinePairCandidate association]

type role PreparedLengthSpinePairCandidatesBeforeLive nominal nominal

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening execution
    evaluation policies cursor prepared = do
  beforeLive <- runPreparedLengthSpinePairCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy cursor prepared
  case beforeLive of
    PreparedLengthSpinePairCandidatesCompleted assessed -> pure
      $ AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
    PreparedLengthSpinePairCandidatesFailed failure -> pure
      $ unassessedLengthSpinePairRanking prepared failure
    PreparedLengthSpinePairCandidatesNeedLive reversed nextCursor index
        association query rest -> do
      scoped <- withLengthSMTLibLiveSession execution $ \session -> do
        observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
        case observed of
          Left failure -> pure $ Left
            $ lengthSpinePairQueryRankingFailure index failure
          Right observation -> case
              assessLengthSpinePairCandidateWithCounterexampleOrigin evaluation
                inputBoxPolicy simplificationPolicy index association query
                observation of
            Left failure -> pure $ Left failure
            Right (assessed, origin) -> do
              advanced <- advanceLengthSpinePairCounterexampleBankCursor
                evaluation index query (LengthSpinePairCounterexampleFresh origin)
                assessed nextCursor
              case advanced of
                Left failure -> pure $ Left failure
                Right advancedCursor ->
                  runPreparedLengthSpinePairCandidatesFrom evaluation policies
                    advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedLengthSpinePairRanking prepared
          $ lengthSpinePairSessionRankingFailure failure
        Right (Left failure) ->
          unassessedLengthSpinePairRanking prepared failure
        Right (Right assessed) -> AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies


runPreparedLengthSpinePairCandidatesBeforeLive
  :: LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSpinePairCounterexampleBankCursor command
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (PreparedLengthSpinePairCandidatesBeforeLive command association)
runPreparedLengthSpinePairCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy initialCursor =
  go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ PreparedLengthSpinePairCandidatesCompleted $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      go (AssociatedRankedLengthSpinePairCandidate index association
            (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedLengthSpinePairCandidateEligible index association query : rest -> do
      replayed <- replayLengthSpinePairCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ PreparedLengthSpinePairCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyLengthSpinePairCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure
              $ PreparedLengthSpinePairCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
              association query of
          Left failure -> pure $ PreparedLengthSpinePairCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            lengthSpinePairSolverIndependentAcquisition rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    (LengthSpinePairRankingOriginProbeEvaluationFailed failure)
                    index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> pure
                $ PreparedLengthSpinePairCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                lengthSpinePairSolverIndependentAcquisition rest assessed
            Right Nothing -> pure $ PreparedLengthSpinePairCandidatesNeedLive
              reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthSpinePairCounterexampleBankCursor evaluation index
      query acquisition assessed cursor
    case advanced of
      Left failure -> pure $ PreparedLengthSpinePairCandidatesFailed failure
      Right nextCursor -> go (assessed : reversed) nextCursor rest

runPreparedLengthSpinePairCandidates
  :: LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSpinePairRankingFailure
        [AssociatedRankedLengthSpinePairCandidate association])
runPreparedLengthSpinePairCandidates evaluation policies cursor session =
  runPreparedLengthSpinePairCandidatesFrom evaluation policies cursor session []

runPreparedLengthSpinePairCandidatesFrom
  :: LengthEvaluationLimits
  -> LengthSpinePairRankingPolicies
  -> LengthSpinePairCounterexampleBankCursor command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthSpinePairCandidate association]
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSpinePairRankingFailure
        [AssociatedRankedLengthSpinePairCandidate association])
runPreparedLengthSpinePairCandidatesFrom evaluation policies initialCursor
    session = go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      go cursor
        (AssociatedRankedLengthSpinePairCandidate index association
          (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        rest
    PreparedLengthSpinePairCandidateEligible index association query : rest -> do
      replayed <- replayLengthSpinePairCounterexampleBankCursor
        evaluation index query cursor
      case replayed of
        Left failure -> pure $ Left failure
        Right (Just (receipt, acquisition)) ->
          case simplifyLengthSpinePairCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure $ Left failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
              association query of
          Left failure -> pure $ Left failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            lengthSpinePairSolverIndependentAcquisition rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Left $ localLengthSpinePairRankingFailure
                (LengthSpinePairRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Left $ localLengthSpinePairRankingFailure
                LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) ->
              case simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
                Left failure -> pure $ Left failure
                Right assessed -> continueAssessed reversed cursor index query
                  lengthSpinePairSolverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLengthSpinePairSMTLibLiveQuery
                evaluation session query
              case observed of
                Left failure -> pure $ Left
                  $ lengthSpinePairQueryRankingFailure index failure
                Right observation -> case
                    assessLengthSpinePairCandidateWithCounterexampleOrigin
                      evaluation inputBoxPolicy simplificationPolicy index
                      association query observation of
                  Left failure -> pure $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (LengthSpinePairCounterexampleFresh origin) rest
                    assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceLengthSpinePairCounterexampleBankCursor evaluation index
      query acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Left failure
      Right nextCursor -> go nextCursor (assessed : reversed) rest

-- | Attempt the current complete applicable-domain traversal. Inapplicability
-- under that algorithm and failures which prevent bounded traversal admission
-- are ordinary misses. Once admission succeeds,
-- evaluation/internal failures or an evidence association mismatch atomically
-- fail the indexed batch.
assessLengthSpinePairApplicableDomainCandidate
  :: LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> Either LengthSpinePairRankingFailure
      (Maybe (AssociatedRankedLengthSpinePairCandidate association))
assessLengthSpinePairApplicableDomainCandidate evaluation policy
    simplificationPolicy index association query = case policy of
  LengthSpinePairApplicableDomainRankingDisabled -> Right Nothing
  LengthSpinePairApplicableDomainRankingEnabled
      inputBoxLimits unionLimits -> case
      validateLengthSpinePairSMTLibQueryApplicableDomain
        evaluation inputBoxLimits unionLimits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected failure)
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairApplicableDomainEstablished receipt) Nothing

lengthSpinePairApplicableDomainAdmissionFailure
  :: LengthSpinePairApplicableDomainValidationError
  -> Bool
lengthSpinePairApplicableDomainAdmissionFailure failure = case failure of
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

probeLengthSpinePairOriginCounterexample
  :: LengthEvaluationLimits
  -> LengthSpinePairOriginProbeRankingPolicy
  -> CheckedLengthSpinePairQuery
  -> Either LengthSpinePairSMTLibInputReplayError
      (Maybe ValidatedLengthSpinePairCounterexample)
probeLengthSpinePairOriginCounterexample evaluation policy query = case policy of
  LengthSpinePairOriginProbeRankingDisabled -> Right Nothing
  LengthSpinePairOriginProbeRankingEnabled ->
    probeLengthSpinePairSMTLibCounterexampleAtOrigin evaluation query

lengthSpinePairSolverIndependentAcquisition
  :: LengthSpinePairCounterexampleAcquisition command
lengthSpinePairSolverIndependentAcquisition =
  LengthSpinePairCounterexampleFresh
    CounterexampleBank.BankReceiptFromSolverIndependentReplay

replayLengthSpinePairCounterexampleBankCursor
  :: LengthEvaluationLimits
  -> Natural
  -> CheckedLengthSpinePairQuery
  -> LengthSpinePairCounterexampleBankCursor command
  -> IO
      (Either LengthSpinePairRankingFailure
        (Maybe
          ( ValidatedLengthSpinePairCounterexample
          , LengthSpinePairCounterexampleAcquisition command
          )))
replayLengthSpinePairCounterexampleBankCursor evaluation index query cursor =
  case cursor of
    LengthSpinePairBatchLocalCounterexampleBank seedBank -> pure $ Right $ case
        replayLengthSpinePairCounterexampleSeeds evaluation query seedBank of
      Nothing -> Nothing
      Just (inputs, receipt) -> inputs `seq` Just
        (receipt, LengthSpinePairCounterexampleFromBatchReplay inputs)
    LengthSpinePairCommandLocalCounterexampleBank context -> do
      replayed <-
        CounterexampleBank.replayLengthSpinePairCounterexampleBankInContext
          evaluation query context
      pure $ case replayed of
        Left _ -> Left $ localLengthSpinePairRankingFailure
          LengthSpinePairRankingEvidenceReplayMismatch index
        Right outcome -> Right $ case outcome of
          CounterexampleBank.BankReplayMiss
              _ -> Nothing
          CounterexampleBank.BankReplayAttemptUnavailable
              _ _ -> Nothing
          CounterexampleBank.BankReplayHit
              _ hit -> Just
            ( CounterexampleBank.lengthSpinePairCounterexampleBankContextReplayHitCounterexample
                hit
            , LengthSpinePairCounterexampleFromCommandReplay hit
            )

advanceLengthSpinePairCounterexampleBankCursor
  :: LengthEvaluationLimits
  -> Natural
  -> CheckedLengthSpinePairQuery
  -> LengthSpinePairCounterexampleAcquisition command
  -> AssociatedRankedLengthSpinePairCandidate association
  -> LengthSpinePairCounterexampleBankCursor command
  -> IO
      (Either LengthSpinePairRankingFailure
        (LengthSpinePairCounterexampleBankCursor command))
advanceLengthSpinePairCounterexampleBankCursor evaluation index query
    acquisition assessed cursor = case assessed of
  AssociatedRankedLengthSpinePairCandidate _ _ state -> case state of
    LengthSpinePairCandidatePreparationRefused _ -> pure $ Right cursor
    LengthSpinePairCandidateAssessed assessment simplification -> case
        assessment of
      LengthSpinePairCounterexample receipt ->
        advanceCounterexample receipt simplification
      _ -> pure $ Right cursor
 where
  advanceCounterexample receipt simplification = case cursor of
    LengthSpinePairBatchLocalCounterexampleBank seedBank -> case acquisition of
      LengthSpinePairCounterexampleFromCommandReplay _ -> mismatch
      LengthSpinePairCounterexampleFromBatchReplay _ ->
        promoteBatch seedBank receipt
      LengthSpinePairCounterexampleFresh _ -> promoteBatch seedBank receipt
    LengthSpinePairCommandLocalCounterexampleBank context ->
      case (acquisition, simplification) of
        (LengthSpinePairCounterexampleFromBatchReplay _, _) -> mismatch
        (LengthSpinePairCounterexampleFromCommandReplay hit, Nothing) -> do
          promoted <-
            CounterexampleBank.promoteLengthSpinePairCounterexampleBankReplayHitInContext
              hit context
          pure $ case promoted of
            Left _ -> Left $ localLengthSpinePairRankingFailure
              LengthSpinePairRankingEvidenceReplayMismatch index
            Right () -> Right cursor
        _ -> do
          recorded <-
            CounterexampleBank.recordLengthSpinePairCounterexampleBankReceiptInContext
              evaluation query (receiptOrigin simplification) receipt context
          pure $ case recorded of
            Left _ -> Left $ localLengthSpinePairRankingFailure
              LengthSpinePairRankingEvidenceReplayMismatch index
            Right _ -> Right cursor

  promoteBatch seedBank receipt =
    let promoted = promoteLengthSpinePairCounterexampleSeed
          (validatedLengthSpinePairCounterexampleInputs receipt) seedBank
    in promoted `seq` pure (Right
        $ LengthSpinePairBatchLocalCounterexampleBank promoted)

  mismatch = pure $ Left $ localLengthSpinePairRankingFailure
    LengthSpinePairRankingEvidenceReplayMismatch index

  receiptOrigin simplification = case simplification of
    Just _ ->
      CounterexampleBank.BankReceiptFromSimplificationReplay
    Nothing -> case acquisition of
      LengthSpinePairCounterexampleFresh origin -> origin
      LengthSpinePairCounterexampleFromBatchReplay _ ->
        CounterexampleBank.BankReceiptFromSolverIndependentReplay
      LengthSpinePairCounterexampleFromCommandReplay _ ->
        CounterexampleBank.BankReceiptFromSolverIndependentReplay

-- | Replay the batch-local seed bank against one checked pair query, MRU
-- first, returning the first vector that independently yields a
-- counterexample.  A seed is only an input vector from an exact receipt; the
-- checked query evaluates it against its own retained problem, so no earlier
-- verdict, receipt, or solver observation crosses this edge.  Every rejection
-- and ordinary non-counterexample is a miss, so an older vector can still be
-- attempted.
replayLengthSpinePairCounterexampleSeeds
  :: LengthEvaluationLimits
  -> CheckedLengthSpinePairQuery
  -> [[Natural]]
  -> Maybe ([Natural], ValidatedLengthSpinePairCounterexample)
replayLengthSpinePairCounterexampleSeeds evaluation query =
  go lengthSpinePairCounterexampleSeedBankMaximumEntries
 where
  go remaining seedBank
    | remaining <= 0 = Nothing
    | otherwise = case seedBank of
        [] -> Nothing
        inputs : rest -> case
            replayLengthSpinePairSMTLibCounterexampleInputs
              evaluation query inputs of
          Right (Just receipt) -> Just (inputs, receipt)
          Left (LengthSpinePairSMTLibInputReplayEvaluationRejected _) ->
            go (remaining - 1) rest
          Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
            go (remaining - 1) rest
          Right Nothing -> go (remaining - 1) rest

lengthSpinePairCounterexampleSeedBankMaximumEntries :: Int
lengthSpinePairCounterexampleSeedBankMaximumEntries = 4

-- | Promote one pair counterexample input vector to the front of the
-- batch-local seed bank: insert at the MRU end, remove every exact duplicate,
-- retain at most the four newest distinct vectors, and force that bounded
-- value before it is retained across another candidate.  The bank never
-- contains receipts or query metadata.
promoteLengthSpinePairCounterexampleSeed
  :: [Natural]
  -> [[Natural]]
  -> [[Natural]]
promoteLengthSpinePairCounterexampleSeed inputs seedBank = force $
  inputs : take (lengthSpinePairCounterexampleSeedBankMaximumEntries - 1)
    (filter (/= inputs) seedBank)

assessedLengthSpinePairCounterexample
  :: Natural
  -> association
  -> ValidatedLengthSpinePairCounterexample
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
  -> AssociatedRankedLengthSpinePairCandidate association
assessedLengthSpinePairCounterexample index association receipt simplification =
  AssociatedRankedLengthSpinePairCandidate index association
    $ LengthSpinePairCandidateAssessed
        (LengthSpinePairCounterexample receipt) simplification

simplifyLengthSpinePairCounterexampleAssessment
  :: LengthEvaluationLimits
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> ValidatedLengthSpinePairCounterexample
  -> Either LengthSpinePairRankingFailure
      (AssociatedRankedLengthSpinePairCandidate association)
simplifyLengthSpinePairCounterexampleAssessment evaluation policy index
    association query receipt = case policy of
  LengthSpinePairCounterexampleSimplificationRankingDisabled -> Right
    $ assessedLengthSpinePairCounterexample
        index association receipt Nothing
  LengthSpinePairCounterexampleSimplificationRankingEnabled limits -> case
      simplifyLengthSpinePairSMTLibQueryCounterexample
        evaluation limits query receipt of
    Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected
        (LengthSpinePairCounterexampleSimplificationInputBoxValidationRejected
          LengthSpinePairInputBoxAssignmentEvaluationRejected {})) -> Right
      $ assessedLengthSpinePairCounterexample
          index association receipt Nothing
    Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected failure) ->
      Left $ localLengthSpinePairRankingFailure
        (LengthSpinePairRankingCounterexampleSimplificationFailed failure) index
    Left
        (LengthSpinePairSMTLibCounterexampleSimplificationAssociationRejected
          _) -> Left $ localLengthSpinePairRankingFailure
          LengthSpinePairRankingEvidenceReplayMismatch index
    Right Nothing -> Right $ assessedLengthSpinePairCounterexample
      index association receipt Nothing
    Right (Just simplification) -> Right
      $ assessedLengthSpinePairCounterexample index association
          (validatedLengthSpinePairCounterexampleSimplificationCounterexample
            simplification)
          (Just simplification)

assessLengthSpinePairCandidateWithCounterexampleOrigin
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> LengthSpinePairSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthSpinePairRankingFailure
      ( AssociatedRankedLengthSpinePairCandidate association
      , CounterexampleBank.BankReceiptOrigin
      )
assessLengthSpinePairCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
    simplificationPolicy index association query observation = do
  (assessment, origin) <- case
      replayLengthSpinePairSMTLibLiveQueryObservation query observation of
    Left LengthSpinePairSMTLibLiveObservationQueryFingerprintMismatch ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingQueryAssociationMismatch index
    Left LengthSpinePairSMTLibLiveObservationEvidenceProblemMismatch {} ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Right Nothing -> assessStatus
      $ lengthSpinePairSMTLibLiveQueryObservationSolverStatus observation
    Right (Just receipt) -> Right
      ( LengthSpinePairCounterexample receipt
      , CounterexampleBank.BankReceiptFromLiveModel
      )
  case assessment of
    LengthSpinePairCounterexample receipt -> do
      assessed <- simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
      pure (assessed, origin)
    _ -> pure
      ( AssociatedRankedLengthSpinePairCandidate index association
          $ LengthSpinePairCandidateAssessed assessment Nothing
      , origin
      )
 where
  assessStatus status = case (status, inputBoxPolicy) of
    (SolverUnsatisfiable,
        LengthSpinePairInputBoxRankingEnabled limits maximums) ->
      case validateLengthSpinePairSMTLibQueryInputBox
          evaluation limits query maximums of
        Left (LengthSpinePairSMTLibInputBoxValidationRejected failure) ->
          Left $ localLengthSpinePairRankingFailure
            (LengthSpinePairRankingInputBoxValidationFailed failure) index
        Left
            (LengthSpinePairSMTLibInputBoxValidationAssociationRejected _) ->
          Left $ localLengthSpinePairRankingFailure
            LengthSpinePairRankingEvidenceReplayMismatch index
        Right (LengthInputBoxCounterexample receipt) -> Right
          ( LengthSpinePairCounterexample receipt
          , CounterexampleBank.BankReceiptFromSolverIndependentReplay
          )
        Right (LengthInputBoxValidated receipt) -> Right
          ( LengthSpinePairBoundedPositive receipt
          , CounterexampleBank.BankReceiptFromSolverIndependentReplay
          )
    _ -> Right
      ( LengthSpinePairHeuristic status
      , CounterexampleBank.BankReceiptFromLiveModel
      )

stableLengthSpinePairCounterexampleDemotion
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
stableLengthSpinePairCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    case spinePairCandidateAssessment state of
      LengthSpinePairCounterexample _ -> True
      LengthSpinePairBoundedPositive _ -> False
      _ -> False

-- | Additive evidence-ordering opt-in for an association-free successful
-- product ranking.  Only a finite-box receipt with at least one applicable
-- assignment enters the preferred partition.  Vacuous receipts stay neutral,
-- counterexamples stay last, and every partition remains stable.
preferNonVacuousBoundedPositiveLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousBoundedPositiveLengthSpinePairRanking ranking = case ranking of
  LengthSpinePairRanking _ (Just _) -> ranking
  LengthSpinePairRanking candidates Nothing -> LengthSpinePairRanking
    (preferNonVacuousBoundedPositiveLengthSpinePairCandidates candidates)
    Nothing

-- | Occurrence-associated product sibling applied before the generative
-- permutation seal.  No candidate/evidence association is projected or
-- reconstructed while the stable trichotomy is selected.
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking ranking =
  case ranking of
    AssociatedLengthSpinePairRanking _ (Just _) -> ranking
    AssociatedLengthSpinePairRanking candidates Nothing ->
      AssociatedLengthSpinePairRanking
        (preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates
          candidates)
        Nothing

preferNonVacuousBoundedPositiveLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
preferNonVacuousBoundedPositiveLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableRankedLengthSpinePairCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive
      (RankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairBoundedPositive
      $ spinePairCandidateAssessment state

preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableLengthSpinePairCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairBoundedPositive
      $ spinePairCandidateAssessment state

stableRankedLengthSpinePairCounterexampleDemotion
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
stableRankedLengthSpinePairCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample (RankedLengthSpinePairCandidate _ _ state) = case
      spinePairCandidateAssessment state of
    LengthSpinePairCounterexample _ -> True
    _ -> False

isNonVacuousLengthSpinePairBoundedPositive
  :: LengthSpinePairRankingAssessment
  -> Bool
isNonVacuousLengthSpinePairBoundedPositive assessment = case assessment of
  LengthSpinePairBoundedPositive receipt ->
    validatedLengthSpinePairInputBoxApplicableAssignmentCount receipt > 0
  _ -> False

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousApplicableDomainLengthSpinePairRanking ranking = case ranking of
  LengthSpinePairRanking _ (Just _) -> ranking
  LengthSpinePairRanking candidates Nothing -> LengthSpinePairRanking
    (preferNonVacuousApplicableDomainLengthSpinePairCandidates candidates)
    Nothing

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking ranking = case
    ranking of
  AssociatedLengthSpinePairRanking _ (Just _) -> ranking
  AssociatedLengthSpinePairRanking candidates Nothing ->
    AssociatedLengthSpinePairRanking
      (preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates
        candidates)
      Nothing

preferNonVacuousApplicableDomainLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
preferNonVacuousApplicableDomainLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableRankedLengthSpinePairCounterexampleDemotion retained
 where
  hasApplicableDomain (RankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairApplicableDomain
      $ spinePairCandidateAssessment state

preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableLengthSpinePairCounterexampleDemotion retained
 where
  hasApplicableDomain
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairApplicableDomain
      $ spinePairCandidateAssessment state

isNonVacuousLengthSpinePairApplicableDomain
  :: LengthSpinePairRankingAssessment
  -> Bool
isNonVacuousLengthSpinePairApplicableDomain assessment = case assessment of
  LengthSpinePairApplicableDomainEstablished receipt ->
    validatedLengthSpinePairApplicableDomainApplicableAssignmentCount receipt > 0
  _ -> False

unassessedLengthSpinePairRanking
  :: [PreparedLengthSpinePairCandidate association]
  -> LengthSpinePairRankingFailure
  -> AssociatedLengthSpinePairRanking association
unassessedLengthSpinePairRanking prepared failure =
  AssociatedLengthSpinePairRanking
    (sanitizePreparedLengthSpinePairCandidates prepared)
    (Just failure)

sanitizePreparedLengthSpinePairCandidates
  :: [PreparedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
sanitizePreparedLengthSpinePairCandidates = go []
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    candidate : rest ->
      let sanitized = preparedLengthSpinePairCandidateUnassessed candidate
      in sanitized `seq` go (sanitized : reversed) rest

unpreparedUnassessedLengthSpinePairRanking
  :: [association]
  -> LengthSpinePairRankingFailure
  -> AssociatedLengthSpinePairRanking association
unpreparedUnassessedLengthSpinePairRanking associations failure =
  AssociatedLengthSpinePairRanking (go 0 [] associations) (Just failure)
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let candidate = AssociatedRankedLengthSpinePairCandidate index association
          $ LengthSpinePairCandidateAssessed
              LengthSpinePairUnassessed Nothing
    in candidate `seq` go (index + 1) (candidate : reversed) rest

associatedLengthSpinePairRankingCleanupIncomplete
  :: AssociatedLengthSpinePairRanking association
  -> Bool
associatedLengthSpinePairRankingCleanupIncomplete
    (AssociatedLengthSpinePairRanking _ Nothing) = False
associatedLengthSpinePairRankingCleanupIncomplete
    (AssociatedLengthSpinePairRanking _ (Just failure)) =
  lengthSpinePairRankingFailureCleanupIncomplete failure

ownerLengthSpinePairRankingFailure
  :: Bool
  -> LengthSMTLibLiveSessionError
  -> LengthSpinePairRankingFailure
ownerLengthSpinePairRankingFailure nestedCleanup ownerFailure =
  case lengthSpinePairSessionRankingFailure ownerFailure of
    LengthSpinePairRankingFailure failure cleanup _ ->
      LengthSpinePairRankingFailure failure
        (cleanup || nestedCleanup) Nothing

forceLengthSpinePairRankingOwnedResult :: LengthSpinePairRanking -> ()
forceLengthSpinePairRankingOwnedResult
    (LengthSpinePairRanking candidates failure) =
  forceRankedLengthSpinePairCandidates candidates `seq`
    forceLengthSpinePairRankingFailure failure

forceAssociatedLengthSpinePairRankingOwnedResult
  :: AssociatedLengthSpinePairRanking association
  -> ()
forceAssociatedLengthSpinePairRankingOwnedResult
    (AssociatedLengthSpinePairRanking candidates failure) =
  forceAssociatedRankedLengthSpinePairCandidates candidates `seq`
    forceLengthSpinePairRankingFailure failure

forceRankedLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> ()
forceRankedLengthSpinePairCandidates candidates = case candidates of
  [] -> ()
  RankedLengthSpinePairCandidate index verified state : rest ->
    index `seq` verified `seq`
      forceLengthSpinePairCandidateAssessment state `seq`
      forceRankedLengthSpinePairCandidates rest

forceAssociatedRankedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> ()
forceAssociatedRankedLengthSpinePairCandidates candidates = case candidates of
  [] -> ()
  AssociatedRankedLengthSpinePairCandidate index association state : rest ->
    index `seq` association `seq`
      forceLengthSpinePairCandidateAssessment state `seq`
      forceAssociatedRankedLengthSpinePairCandidates rest

forceLengthSpinePairCandidateAssessment
  :: LengthSpinePairCandidateAssessment
  -> ()
forceLengthSpinePairCandidateAssessment state = case state of
  LengthSpinePairCandidatePreparationRefused refusal -> refusal `seq` ()
  LengthSpinePairCandidateAssessed assessment simplification ->
    forceLengthSpinePairRankingAssessment assessment `seq`
      maybe () rnf simplification

forceLengthSpinePairRankingAssessment
  :: LengthSpinePairRankingAssessment
  -> ()
forceLengthSpinePairRankingAssessment assessment = case assessment of
  LengthSpinePairUnassessed -> ()
  LengthSpinePairHeuristic status -> status `seq` ()
  LengthSpinePairCounterexample receipt -> rnf receipt
  LengthSpinePairBoundedPositive receipt -> rnf receipt
  LengthSpinePairApplicableDomainEstablished receipt -> rnf receipt

forceLengthSpinePairRankingFailure
  :: Maybe LengthSpinePairRankingFailure
  -> ()
forceLengthSpinePairRankingFailure failure = case failure of
  Nothing -> ()
  Just (LengthSpinePairRankingFailure failureClass cleanup index) ->
    forceLengthSpinePairRankingFailureClass failureClass `seq`
      cleanup `seq` forceLengthSpinePairRankingFailureIndex index

forceLengthSpinePairRankingFailureIndex :: Maybe Natural -> ()
forceLengthSpinePairRankingFailureIndex index = case index of
  Nothing -> ()
  Just retained -> retained `seq` ()

forceLengthSpinePairRankingFailureClass
  :: LengthSpinePairRankingFailureClass
  -> ()
forceLengthSpinePairRankingFailureClass failure = case failure of
  LengthSpinePairRankingLiveSessionFailed nested -> rnf nested
  LengthSpinePairRankingLiveQueryFailed nested -> rnf nested
  LengthSpinePairRankingQueryAssociationMismatch -> ()
  LengthSpinePairRankingEvidenceReplayMismatch -> ()
  LengthSpinePairRankingOriginProbeEvaluationFailed nested -> rnf nested
  LengthSpinePairRankingInputBoxValidationFailed nested -> rnf nested
  LengthSpinePairRankingApplicableDomainValidationFailed nested -> rnf nested
  LengthSpinePairRankingCounterexampleSimplificationFailed nested -> rnf nested

forcePreparedLengthSpinePairCandidates
  :: [PreparedLengthSpinePairCandidate association]
  -> ()
forcePreparedLengthSpinePairCandidates prepared = case prepared of
  [] -> ()
  PreparedLengthSpinePairCandidateUnassessed
      index association refusal : rest ->
    index `seq` association `seq` refusal `seq`
      forcePreparedLengthSpinePairCandidates rest
  PreparedLengthSpinePairCandidateEligible index association query : rest ->
    index `seq` association `seq` query `seq`
      forcePreparedLengthSpinePairCandidates rest

-- | Reduce a binary-product handoff refusal to its stable payload-free phase.
-- Shared scalar refusals nested in 'LengthSpinePairHandoffSharedRefusal' are
-- classified by 'lengthHandoffPreparationRefusalClass'; every payload
-- wildcard is intentional so no raw refusal payload is evaluated or retained.
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

-- | Reduce a canonical pair-query construction refusal to its payload-free
-- phase.  Every constructor maps to
-- 'LengthPreparationQueryConstructionRejected'; no field is inspected.
lengthSpinePairQueryPreparationRefusalClass
  :: LengthSpinePairSMTLibQueryError
  -> LengthPreparationRefusalClass
lengthSpinePairQueryPreparationRefusalClass refusal = case refusal of
  LengthSpinePairSMTLibUnexpectedResultVariable -> rejected
  LengthSpinePairSMTLibInputVariableOutOfRange _ _ -> rejected
  LengthSpinePairSMTLibQuotientDivisorZero -> rejected
  LengthSpinePairSMTLibModuloDivisorZero -> rejected
  LengthSpinePairSMTLibNumeralBitLimitExceeded {} -> rejected
  LengthSpinePairSMTLibCommandByteLimitExceeded {} -> rejected
  LengthSpinePairSMTLibFingerprintByteLimitExceeded _ _ -> rejected
 where
  rejected = LengthPreparationQueryConstructionRejected

localLengthSpinePairRankingFailure
  :: LengthSpinePairRankingFailureClass
  -> Natural
  -> LengthSpinePairRankingFailure
localLengthSpinePairRankingFailure failure index =
  LengthSpinePairRankingFailure failure False $ Just index

lengthSpinePairSessionRankingFailure
  :: LengthSMTLibLiveSessionError
  -> LengthSpinePairRankingFailure
lengthSpinePairSessionRankingFailure failure =
  LengthSpinePairRankingFailure
    (LengthSpinePairRankingLiveSessionFailed
      $ lengthSMTLibLiveSessionPrimaryFailure failure)
    (lengthSMTLibLiveSessionCleanupIncomplete failure)
    Nothing

lengthSpinePairQueryRankingFailure
  :: Natural
  -> LengthSpinePairSMTLibLiveQueryError
  -> LengthSpinePairRankingFailure
lengthSpinePairQueryRankingFailure index failure =
  LengthSpinePairRankingFailure
    (LengthSpinePairRankingLiveQueryFailed
      $ lengthSpinePairSMTLibLiveQueryPrimaryFailure failure)
    (lengthSpinePairSMTLibLiveQueryCleanupIncomplete failure)
    (Just index)
