{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live Length ranking.
--
-- This module is the only Leant layer which opens Djex's public live Length
-- session.  It first productively bounds the complete input, then prepares
-- every checked problem and canonical query before launching a worker.
-- Eligible candidates are processed serially in original order inside one
-- rank-N scope.  Before a later live call, at most four exact counterexample
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
-- The private opener/finalizer budgets and the execution policy's per-query
-- host budget remain separate; this function promises no batch-wide hard
-- wall-clock deadline.  Synchronous and asynchronous exceptions are not
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
  , AssociatedRankedLengthCandidate
  , associatedRankedLengthCandidateAssociation
  , AssociatedLengthRanking
  , associatedLengthRankingCandidates
  , preferNonVacuousBoundedPositiveAssociatedLengthRanking
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
  , promoteCounterexampleSeed
  , replayCounterexampleSeeds
  ) where

import Control.DeepSeq (force)
import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthEvaluationError
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthInputBoxValidationError
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
  , SolverStatus (..)
  , ValidatedLengthCounterexample
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
  , validateLengthSMTLibQueryInputBox
  , validatedLengthCounterexampleInputs
  , validatedLengthInputBoxApplicableAssignmentCount
  , withLengthSMTLibLiveSession
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareCheckedLengthQuery
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
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

-- | The four public assessment strengths.  A heuristic status and an
-- independently validated finite-box success are deliberately neutral for
-- ordering; only a replayed counterexample is stably demoted.
data LengthRankingAssessment
  = Unassessed
  | Heuristic !SolverStatus
  | Counterexample !ValidatedLengthCounterexample
  | BoundedPositive !ValidatedLengthInputBox
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
  | LengthCandidateAssessed !LengthRankingAssessment

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
  LengthCandidateAssessed assessment -> assessment

candidatePreparationRefusal
  :: LengthCandidateAssessment
  -> Maybe LengthPreparationRefusalClass
candidatePreparationRefusal state = case state of
  LengthCandidatePreparationRefused refusal -> Just refusal
  LengthCandidateAssessed _ -> Nothing

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

postVerificationLengthRankingBatch
  :: PostVerificationLengthRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthRankingBatch
    (PostVerificationLengthRanking batch _ _) = batch

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

-- | Private query-owned pre-live probe policy.  The enabled constructor is
-- only permission to run Djex's canonical origin replay after every MRU miss;
-- it carries no arity, input vector, query, receipt, or verdict.
data LengthOriginProbeRankingPolicy
  = LengthOriginProbeRankingDisabled
  | LengthOriginProbeRankingEnabled

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
  $ rankAssociatedLengthCandidates LengthInputBoxRankingDisabled
      LengthOriginProbeRankingDisabled
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
  $ rankAssociatedLengthCandidates LengthInputBoxRankingDisabled
      LengthOriginProbeRankingEnabled
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
      (LengthInputBoxRankingEnabled limits maximums)
      LengthOriginProbeRankingDisabled
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
      (LengthInputBoxRankingEnabled limits maximums)
      LengthOriginProbeRankingEnabled
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
  rankAssociatedLengthCandidates LengthInputBoxRankingDisabled
    LengthOriginProbeRankingDisabled
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
  rankAssociatedLengthCandidates LengthInputBoxRankingDisabled
    LengthOriginProbeRankingEnabled
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
    (LengthInputBoxRankingEnabled limits maximums)
    LengthOriginProbeRankingDisabled
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
    (LengthInputBoxRankingEnabled limits maximums)
    LengthOriginProbeRankingEnabled
    execution evaluation contract postVerificationCandidateVerified

-- | Rank caller-owned occurrences while retaining each occurrence handle
-- through preparation, live assessment, stable partitioning, and atomic
-- fallback.  The projection is not touched until complete input admission has
-- succeeded.
rankAssociatedLengthCandidates
  :: LengthInputBoxRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking association))
rankAssociatedLengthCandidates inputBoxPolicy originProbePolicy execution
    evaluation contract verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> case prepareCandidates contract verifiedFor admitted of
      [] -> pure $ Right $ AssociatedLengthRanking [] Nothing
      prepared
        | not (hasEligibleCandidate prepared) -> pure $ Right
            $ AssociatedLengthRanking
                (map preparedCandidateUnassessed prepared) Nothing
        | otherwise -> do
            scoped <- withLengthSMTLibLiveSession execution
              $ \session -> runPreparedCandidates
                  evaluation inputBoxPolicy originProbePolicy session prepared
            pure $ Right $ case scoped of
              Left failure -> unassessedRanking prepared
                $ sessionRankingFailure failure
              Right (Left failure) ->
                unassessedRanking prepared failure
              Right (Right assessed) -> AssociatedLengthRanking
                (stableCounterexampleDemotion assessed) Nothing

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
      $ LengthCandidateAssessed Unassessed

runPreparedCandidates
  :: LengthEvaluationLimits
  -> LengthInputBoxRankingPolicy
  -> LengthOriginProbeRankingPolicy
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthRankingFailure
        [AssociatedRankedLengthCandidate association])
runPreparedCandidates evaluation inputBoxPolicy originProbePolicy session =
  go [] []
 where
  go reversed seedBank remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthCandidateUnassessed
        index association refusal : rest ->
      go (AssociatedRankedLengthCandidate
        index association (LengthCandidatePreparationRefused refusal) : reversed)
        seedBank rest
    PreparedLengthCandidateEligible
        index association query : rest -> case
          replayCounterexampleSeeds evaluation query seedBank of
      Just (inputs, receipt) ->
        let promoted = promoteCounterexampleSeed inputs seedBank
        in promoted `seq` go
            (assessedCounterexample index association receipt : reversed)
            promoted rest
      Nothing -> case probeOriginCounterexample evaluation originProbePolicy
          query of
        Left (LengthSMTLibInputReplayEvaluationRejected failure) -> pure
          $ Left $ localRankingFailure
              (LengthRankingOriginProbeEvaluationFailed failure) index
        Left (LengthSMTLibInputReplayAssociationRejected _) -> pure
          $ Left $ localRankingFailure
              LengthRankingEvidenceReplayMismatch index
        Right (Just receipt) ->
          let inputs = validatedLengthCounterexampleInputs receipt
              promoted = promoteCounterexampleSeed inputs seedBank
          in promoted `seq` go
              (assessedCounterexample index association receipt : reversed)
              promoted rest
        Right Nothing -> do
          observed <- runLengthSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Left $ queryRankingFailure index failure
            Right observation -> case
                assessCandidate evaluation inputBoxPolicy
                  index association query observation of
              Left failure -> pure $ Left failure
              Right assessed ->
                let nextSeedBank = case counterexampleSeed assessed of
                      Nothing -> seedBank
                      Just retained ->
                        promoteCounterexampleSeed retained seedBank
                in nextSeedBank `seq`
                    go (assessed : reversed) nextSeedBank rest

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
  -> AssociatedRankedLengthCandidate association
assessedCounterexample index association receipt =
  AssociatedRankedLengthCandidate index association
    $ LengthCandidateAssessed $ Counterexample receipt

counterexampleSeed
  :: AssociatedRankedLengthCandidate association
  -> Maybe [Natural]
counterexampleSeed (AssociatedRankedLengthCandidate _ _ state) = case
    state of
  LengthCandidateAssessed (Counterexample receipt) ->
    Just $ validatedLengthCounterexampleInputs receipt
  _ -> Nothing

assessCandidate
  :: LengthEvaluationLimits
  -> LengthInputBoxRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthQuery
  -> LengthSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthRankingFailure
      (AssociatedRankedLengthCandidate association)
assessCandidate evaluation inputBoxPolicy index association query observation =
    do
  assessment <- case
      replayLengthSMTLibLiveQueryObservation query observation of
    Left LengthSMTLibLiveObservationQueryFingerprintMismatch ->
      Left $ localRankingFailure LengthRankingQueryAssociationMismatch index
    Left LengthSMTLibLiveObservationEvidenceProblemMismatch{} ->
      Left $ localRankingFailure LengthRankingEvidenceReplayMismatch index
    Right Nothing -> assessStatus
      $ lengthSMTLibLiveQueryObservationSolverStatus observation
    Right (Just receipt) -> Right $ Counterexample receipt
  pure $ AssociatedRankedLengthCandidate index association
    $ LengthCandidateAssessed assessment
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
          Right $ Counterexample receipt
        Right (LengthInputBoxValidated receipt) ->
          Right $ BoundedPositive receipt
    _ -> Right $ Heuristic status

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
  LengthHandoffExactCasePolicyRequiresTargetRoles ->
    LengthPreparationContractRejected
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
