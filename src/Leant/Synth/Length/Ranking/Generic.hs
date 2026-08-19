{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

-- | Domain-generic implementation of conservative live Length ranking.
--
-- The scalar finite-list-spine domain and the binary-product domain rank
-- candidates with exactly the same control flow, admission bounds, seed bank,
-- error precedence, deadline ownership, and stable partitioning; they differ
-- only in the nominal Djex vocabulary (queries, receipts, validators, live
-- observations) and in the nominal Leant assessment and failure types each
-- domain exports.  This module holds that control flow once, parameterized by
-- the closed 'LengthRankingDomain' class.  "Leant.Synth.Length.Ranking.Internal"
-- and "Leant.Synth.Length.SpinePair.Ranking.Internal" instantiate it and keep
-- their established public names, signatures, and nominal receipt types by
-- wrapping the shared values in domain-specific newtypes.
--
-- The narrative below is the established one for both domains.  This module
-- is the only Leant layer which opens Djex's public live Length session.  It
-- first productively bounds the complete input, then prepares every checked
-- problem and canonical query before launching a worker.  Eligible candidates
-- are processed serially in original order.  The eager programmatic path opens
-- one rank-N scope before the first candidate; the additive deferred path
-- enters that one scope only at the first actual live miss, and an all-pure
-- batch opens none.  Before a later live call, at most four exact
-- counterexample input vectors are independently validated and replayed in
-- newest-first order against that candidate's checked query.  A replay hit
-- avoids one live query and promotes that vector; every all-miss follows the
-- established live path.  An independently enabled origin policy may next
-- probe the canonical all-zero vector owned by that exact query.  A hit enters
-- the same receipt and MRU path, while an ordinary miss proceeds to live
-- execution.  An explicitly enabled policy may use a live @unsat@ only as the
-- trigger for independent, query-owned exhaustive validation of one finite
-- input box.  A validation counterexample enters the same exact receipt/MRU
-- path; complete bounded success stays neutral and a validation failure
-- atomically resets the batch.  The external status itself never becomes
-- positive evidence.
--
-- A solver status is heuristic only.  A live observation can yield a
-- counterexample only after Djex's public query-first gate checks its exact
-- fingerprint and replays its evidence.  A seed hit can yield one only after
-- the later query independently validates the input vector against the
-- checked problem retained by that query and associates the resulting evidence
-- back to its own behavioral problem.  Even that receipt is finite-spine and
-- model-relative: it is neither a proof nor a claim about the source-level
-- realization of a Lean term.  Ranking therefore never prunes.  The
-- established runners stably move candidates with replayed counterexamples
-- after every other candidate.  A separate post-assessment opt-in may first
-- prefer non-vacuous bounded-positive receipts while leaving vacuous receipts
-- neutral and counterexamples last; source order is preserved within every
-- partition.  The seed bank contains only input vectors, not cached verdicts,
-- solver results, receipts, or proofs, and it never crosses a ranking batch.
--
-- Historical entrances retain separate opener/finalizer and per-query host
-- windows.  The additive usable-work entrance instead captures one shared
-- owner after admission and before preparation.  It remains an observed
-- normal-return boundary, not an asynchronous watchdog: nested final readiness
-- and cleanup use fresh private windows, but the outer owner checks only after
-- those stages return and may then reject the batch.  Exceptions are not
-- caught here and retain the live facade's durable-cleanup behavior.
module Leant.Synth.Length.Ranking.Generic
  ( -- * The domain class
    LengthRankingDomain (..)
  , AssessmentView (..)
  , FailureClassView (..)
  , ReplayRejection (..)
  , DomainRejection (..)
  , DomainOutcome (..)
  , BoxRejection (..)
  , BoxOutcome (..)
  , SimplificationRejection (..)
  , ObservationRejection (..)
  , LiveOutcome (..)
  , CounterexampleBankCursor (..)
  , CounterexampleAcquisition (..)
    -- * Domain-neutral vocabulary
  , LengthRankingInputError (..)
  , LengthPreparationRefusalClass (..)
  , lengthPreparationRefusalClassCode
  , LengthLiveSessionOpeningPolicy (..)
    -- * Shared policies
  , InputBoxPolicy (..)
  , ApplicableDomainPolicy (..)
  , OriginProbePolicy (..)
  , SimplificationPolicy (..)
  , RankingPolicies (..)
    -- * Shared structure
  , CandidateAssessment (..)
  , candidateAssessment
  , candidatePreparationRefusal
  , candidateSimplification
  , RankedCandidate (..)
  , Ranking (..)
  , AssociatedRankedCandidate (..)
  , AssociatedRanking (..)
  , projectAssociatedRankingWith
  , PostVerificationRanking (..)
  , sealPostVerificationRanking
  , materializePostVerificationRanking
    -- * Runners
  , rankAssociatedCandidates
  , rankAssociatedCandidatesWithLiveSessionOpening
  , rankAssociatedCandidatesWithLiveSessionOpeningAndCursor
  , rankAssociatedCandidatesWithUsableWorkBudget
  , rankAssociatedCandidatesWithUsableWorkBudgetAndCursor
  , rankAssociatedCandidatesWithScopedUsableWorkBudget
  , rankAssociatedCandidatesWithScopedUsableWorkBudgetAndCursor
  , forceRankingOwnedResult
  , forceAssociatedRankingOwnedResult
    -- * Post-assessment preferences
  , preferNonVacuousBoundedPositiveRanking
  , preferNonVacuousBoundedPositiveAssociatedRanking
  , preferNonVacuousApplicableDomainRanking
  , preferNonVacuousApplicableDomainAssociatedRanking
    -- * Seed bank
  , promoteCounterexampleSeed
  , replayCounterexampleSeeds
  ) where

import Control.DeepSeq (NFData, force)
import Control.Exception (evaluate)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (partition)
import Numeric.Natural (Natural)

import Leant.Synth.Length.CounterexampleBank.Internal
  ( BankBridge
  , BankContext
  , BankContextReplayHit
  , BankPromotionFailure
  , BankRecordFailure
  , BankRecordOutcome (..)
  , BankReceiptOrigin (..)
  , BankReplayOutcome (..)
  , BankSurface
  , bankContextReplayHitCounterexample
  , promoteBankReplayHitInContext
  , recordBankReceiptInContext
  , replayBankInContext
  )

import Language.Haskell.Djex
  ( LengthBooleanFiniteUnionLimits
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveScopedUsableWorkDeadline
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSMTLibLiveUsableWorkDeadline
  , SolverStatus (..)
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
  , checkLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveSession
  , withLengthSMTLibLiveSessionUnderScopedDeadline
  , withLengthSMTLibLiveSessionUnderDeadline
  , withLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveUsableWorkDeadline
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
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

-- Domain-neutral vocabulary ---------------------------------------------------

-- | Productive rejection of maximum-plus-one input candidates.  The observed
-- count is capped at that first excess; an unbounded tail is never traversed.
data LengthRankingInputError = LengthRankingInputLimitExceeded
  { lengthRankingInputMaximumCandidates :: !Natural
  , lengthRankingInputObservedCandidatesAtLeast :: !Natural
  }
  deriving (Eq, Ord, Show)

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

-- | Package-private worker-opening policy shared by the scalar and binary
-- product ranking implementations.  The eager constructor is the literal
-- historical behavior.  Deferred opening still admits and prepares the full
-- batch first, but opens a worker only after the first candidate whose pure
-- MRU/domain/origin prefix misses.
data LengthLiveSessionOpeningPolicy
  = LengthLiveSessionOpeningEager
  | LengthLiveSessionOpeningDeferredUntilLiveQuery
  deriving (Eq, Ord, Show)

-- The domain class ------------------------------------------------------------

-- | Everything that distinguishes one Length ranking domain from the other:
-- the Djex vocabulary it queries and replays, and the nominal Leant
-- assessment and failure types it exports.  Every Djex outcome that the shared
-- control flow inspects is delivered through a small shared view so the flow
-- never names a domain-specific constructor.  Instances are closed: the two
-- ranking modules define one each.
class ( NFData (BankLimits d)
      , NFData (Bank d)
      , Eq (BankSample d)
      ) => LengthRankingDomain d where
  -- Leant-side inputs and outputs.
  type Contract d
  type Query d
  type Assessment d
  type FailureClass d
  type Failure d
  -- Djex receipts.
  type Counterexample d
  type InputBox d
  type ApplicableDomain d
  type Simplification d
  -- Djex live vocabulary and closed public error types.
  type LiveError d
  type LiveFailure d
  type EvaluationError d
  type InputBoxError d
  type DomainError d
  type SimplificationError d
  -- Djex's counterexample-bank vocabulary, as the bank adapter parameterizes
  -- it.  Only the additive command-local cursor branch uses these; the
  -- established batch-local MRU is raw input vectors and needs none of them.
  type BankLimits d
  type Bank d
  type BankScope d
  type BankSample d
  type BankError d

  -- | Check the verified origin and construct the canonical query, reducing
  -- either refusal to its payload-free class.
  prepareQuery
    :: Contract d
    -> Verified DetailedVerificationVariant
    -> Either LengthPreparationRefusalClass (Query d)

  -- | Independently replay one input vector against the exact checked query.
  replayInputs
    :: LengthEvaluationLimits
    -> Query d
    -> [Natural]
    -> Either (ReplayRejection d) (Maybe (Counterexample d))

  -- | Replay the canonical all-zero vector owned by the exact query.
  probeAtOrigin
    :: LengthEvaluationLimits
    -> Query d
    -> Either (ReplayRejection d) (Maybe (Counterexample d))

  -- | The current complete query-owned applicable-domain validation.
  validateApplicableDomain
    :: LengthEvaluationLimits
    -> LengthInputBoxLimits
    -> LengthBooleanFiniteUnionLimits
    -> Query d
    -> Either (DomainRejection d) (DomainOutcome d)

  -- | Whether an applicable-domain rejection is an admission limit (an
  -- ordinary miss) rather than an evaluation or internal failure.
  applicableDomainAdmissionFailure :: DomainError d -> Bool

  -- | Query-owned exhaustive validation of one finite input box.
  validateInputBox
    :: LengthEvaluationLimits
    -> LengthInputBoxLimits
    -> Query d
    -> [Natural]
    -> Either (BoxRejection d) (BoxOutcome d)

  -- | Djex's strictly smaller query-owned sibling of a replayed
  -- counterexample, when one exists.
  simplifyCounterexample
    :: LengthEvaluationLimits
    -> LengthInputBoxLimits
    -> Query d
    -> Counterexample d
    -> Either (SimplificationRejection d) (Maybe (Simplification d))

  simplificationCounterexample :: Simplification d -> Counterexample d
  counterexampleInputs :: Counterexample d -> [Natural]
  inputBoxApplicableAssignmentCount :: InputBox d -> Natural
  applicableDomainApplicableAssignmentCount :: ApplicableDomain d -> Natural

  -- | Execute one canonical query on the shared live session and pass its
  -- observation through Djex's query-first gate (exact fingerprint check and
  -- evidence replay).  The domain's observation type never leaves the
  -- instance; the shared flow sees only the gated outcome.
  runLiveQuery
    :: LengthEvaluationLimits
    -> LengthSMTLibLiveSession epoch
    -> Query d
    -> IO (Either (LiveError d) (LiveOutcome d))

  -- | The domain's query-free bank operations: promotion is exactly these.
  bankSurface
    :: BankSurface (Bank d) (BankScope d) (BankSample d) (BankError d)

  -- | The domain's bank bridges for one checked query.
  bankBridge
    :: LengthEvaluationLimits
    -> Query d
    -> BankBridge (BankLimits d) (Bank d) (BankScope d) (BankSample d)
        (Counterexample d) (BankError d) (EvaluationError d)

  liveErrorPrimaryFailure :: LiveError d -> LiveFailure d
  liveErrorCleanupIncomplete :: LiveError d -> Bool

  -- The nominal Leant leaves.
  buildAssessment :: AssessmentView d -> Assessment d
  viewAssessment :: Assessment d -> AssessmentView d
  buildFailureClass :: FailureClassView d -> FailureClass d
  buildFailure :: FailureClass d -> Bool -> Maybe Natural -> Failure d
  failureCleanupIncomplete :: Failure d -> Bool
  -- | Force exactly the ranking-owned structure of a receipt (deep).
  forceAssessment :: Assessment d -> ()
  forceSimplification :: Simplification d -> ()
  forceFailure :: Failure d -> ()

-- | The five assessment strengths, viewed without naming a domain's
-- constructors.
data AssessmentView d
  = ViewUnassessed
  | ViewHeuristic !SolverStatus
  | ViewCounterexample !(Counterexample d)
  | ViewBoundedPositive !(InputBox d)
  | ViewApplicableDomainEstablished !(ApplicableDomain d)

-- | The sanitized failure classes, viewed without naming a domain's
-- constructors.
data FailureClassView d
  = ViewLiveSessionFailed !LengthSMTLibLiveSessionFailure
  | ViewLiveQueryFailed !(LiveFailure d)
  | ViewQueryAssociationMismatch
  | ViewEvidenceReplayMismatch
  | ViewOriginProbeEvaluationFailed !(EvaluationError d)
  | ViewInputBoxValidationFailed !(InputBoxError d)
  | ViewApplicableDomainValidationFailed !(DomainError d)
  | ViewCounterexampleSimplificationFailed !(SimplificationError d)

-- | Why one input-vector replay (a seed, or the origin probe) yielded no
-- receipt: Djex's bounded evaluation refused, or the evidence could not be
-- associated back to the exact query.  Both are ordinary misses for a seed
-- and indexed failures for the origin probe.
data ReplayRejection d
  = ReplayEvaluationRejected !(EvaluationError d)
  | ReplayAssociationRejected

-- | Why the query-owned applicable-domain validation produced no outcome.
-- An admission-limit rejection (see 'applicableDomainAdmissionFailure') is
-- an ordinary miss; every other rejection fails the indexed batch.
data DomainRejection d
  = DomainValidationRejected !(DomainError d)
  | DomainAssociationRejected

-- | The three answers of a completed applicable-domain validation: the
-- algorithm does not apply, it found a counterexample, or it established the
-- complete domain receipt.
data DomainOutcome d
  = DomainInapplicable
  | DomainCounterexample !(Counterexample d)
  | DomainEstablished !(ApplicableDomain d)

-- | Why the post-@unsat@ finite input-box validation produced no outcome;
-- both cases fail the indexed batch.
data BoxRejection d
  = BoxValidationRejected !(InputBoxError d)
  | BoxAssociationRejected

-- | The two answers of a completed finite input-box validation: an exact
-- counterexample, or the bounded-positive box receipt.
data BoxOutcome d
  = BoxCounterexample !(Counterexample d)
  | BoxValidated !(InputBox d)

-- | A search-assignment evaluation rejection is a conservative failed trial
-- ('SimplificationTrialRejected'); every other admitted rejection is an
-- indexed batch failure.
data SimplificationRejection d
  = SimplificationTrialRejected
  | SimplificationRejected !(SimplificationError d)
  | SimplificationAssociationRejected

-- | Why Djex's query-first gate refused a live observation: its fingerprint
-- is not the executed query's, or its replayed evidence does not belong to
-- that query's behavioral problem.
data ObservationRejection
  = ObservationQueryFingerprintMismatch
  | ObservationEvidenceProblemMismatch

-- | The established batch-local raw-vector MRU or one explicitly supplied
-- command-local nominal bank.  Existing ranking entrances always construct
-- the first branch; only the additive filter runner receives the second.
data CounterexampleBankCursor d command
  = BatchLocalCounterexampleBank ![[Natural]]
  | CommandLocalCounterexampleBank
      !(BankContext command (BankLimits d) (Bank d))

type role CounterexampleBankCursor nominal nominal

-- | Exact source of one candidate-specific counterexample before optional
-- simplification.  A retained-bank hit keeps its command tag until either its
-- exact sample is promoted or its simplified successor is freshly recorded.
data CounterexampleAcquisition d command
  = FromBatchReplay ![Natural]
  | FromCommandReplay
      !(BankContextReplayHit
          command (BankScope d) (BankSample d) (Counterexample d))
  | FreshCounterexample !BankReceiptOrigin

type role CounterexampleAcquisition nominal nominal

-- | One live observation after Djex's query-first gate: the gate refused the
-- association, or replay found no counterexample and only the heuristic
-- solver status remains, or replay yielded an exact receipt.
data LiveOutcome d
  = LiveObservationRejected !ObservationRejection
  | LiveHeuristic !SolverStatus
  | LiveCounterexample !(Counterexample d)

-- Shared policies -------------------------------------------------------------

-- | Orchestration policy.  The disabled constructor is the exact historical
-- path.  The enabled constructor owns only an independently checked traversal
-- limit and caller-supplied finite maxima; it carries no solver observation or
-- behavioral verdict.
data InputBoxPolicy
  = InputBoxDisabled
  | InputBoxEnabled !LengthInputBoxLimits [Natural]

-- | Permission to attempt the current complete query-owned validation of the
-- precondition-applicable input domain after every MRU miss. Admission limits
-- remain an ordinary miss and no solver observation is retained here.
data ApplicableDomainPolicy
  = ApplicableDomainDisabled
  | ApplicableDomainEnabled !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

-- | Query-owned pre-live probe policy.  The enabled constructor is only
-- permission to run Djex's canonical origin replay after every MRU miss; it
-- carries no arity, input vector, query, receipt, or verdict.
data OriginProbePolicy
  = OriginProbeDisabled
  | OriginProbeEnabled

-- | Permission to replace any independently replayed counterexample with
-- Djex's strictly smaller query-owned sibling.  The same bounded policy is
-- applied regardless of whether the starting receipt came from MRU replay,
-- applicable-domain traversal, the origin probe, live replay, or the
-- post-@unsat@ box.  @Nothing@ from Djex retains that exact starting receipt.
data SimplificationPolicy
  = SimplificationDisabled
  | SimplificationEnabled !LengthInputBoxLimits

-- | The four assessment policies that every internal ranking runner threads
-- together unchanged.  The worker opening policy stays separate because the
-- deferred-opening runners omit it.
data RankingPolicies = RankingPolicies
  { inputBoxPolicyOf :: !InputBoxPolicy
  , applicableDomainPolicyOf :: !ApplicableDomainPolicy
  , originProbePolicyOf :: !OriginProbePolicy
  , simplificationPolicyOf :: !SimplificationPolicy
  }

-- Shared structure ------------------------------------------------------------

-- | Invariant separating a pure preparation refusal from the legacy assessment
-- projection.  Operational batch fallback is represented by
-- 'CandidateAssessed' of the unassessed view, with no candidate-local refusal.
data CandidateAssessment d
  = CandidatePreparationRefused !LengthPreparationRefusalClass
  | CandidateAssessed !(Assessment d) !(Maybe (Simplification d))

-- | Legacy assessment projection; a preparation refusal reads as unassessed.
candidateAssessment
  :: forall d. LengthRankingDomain d => CandidateAssessment d -> Assessment d
candidateAssessment state = case state of
  CandidatePreparationRefused _ -> buildAssessment @d ViewUnassessed
  CandidateAssessed assessment _ -> assessment

-- | The candidate-local pure preparation refusal, if one occurred.
candidatePreparationRefusal
  :: CandidateAssessment d -> Maybe LengthPreparationRefusalClass
candidatePreparationRefusal state = case state of
  CandidatePreparationRefused refusal -> Just refusal
  CandidateAssessed _ _ -> Nothing

-- | The optional simplifier's metadata for this candidate's counterexample.
candidateSimplification :: CandidateAssessment d -> Maybe (Simplification d)
candidateSimplification state = case state of
  CandidatePreparationRefused _ -> Nothing
  CandidateAssessed _ simplification -> simplification

-- | One callback receipt and the assessment made for that exact candidate.
data RankedCandidate d = RankedCandidate
  !Natural
  !(Verified DetailedVerificationVariant)
  !(CandidateAssessment d)

-- | Complete all-or-fallback result.  A successful value may be stably
-- reordered.  Any failure contains every original receipt in original order,
-- all unassessed, plus one sanitized failure.
data Ranking d = Ranking ![RankedCandidate d] !(Maybe (Failure d))

-- | Internal ranking result which keeps one caller-owned occurrence handle
-- inseparable from the assessment derived from its receipt.
data AssociatedRankedCandidate d association = AssociatedRankedCandidate
  !Natural
  !association
  !(CandidateAssessment d)

type role AssociatedRankedCandidate nominal nominal

-- | Complete associated plan before its batch-scoped handles are erased.
data AssociatedRanking d association = AssociatedRanking
  ![AssociatedRankedCandidate d association]
  !(Maybe (Failure d))

type role AssociatedRanking nominal nominal

associatedRankedCandidateAssociation
  :: AssociatedRankedCandidate d association -> association
associatedRankedCandidateAssociation
    (AssociatedRankedCandidate _ association _) = association

-- | Project one association-free compatibility report through its fixed
-- receipt-bearing association.  It eagerly materializes the already bounded
-- report spine so an erased epoch handle cannot survive behind a public
-- association-free result thunk.
projectAssociatedRankingWith
  :: (association -> Verified DetailedVerificationVariant)
  -> AssociatedRanking d association
  -> Ranking d
projectAssociatedRankingWith verifiedFor (AssociatedRanking candidates failure) =
  Ranking (projectCandidates [] candidates) failure
 where
  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedCandidate index association state : rest ->
      let projected = RankedCandidate index (verifiedFor association) state
      in projected `seq` projectCandidates (projected : reversed) rest

-- | One exact sealed permutation and its receipt-free compatibility state.
-- The opaque value stores verified receipts only through the sealed batch.
-- Its already bounded summary spine is materialized eagerly so no erased
-- epoch handle can survive behind an accepted post-verification result.
data PostVerificationRanking d = PostVerificationRanking
  !(PostVerificationBatch DetailedVerificationVariant)
  ![PostVerificationRankedCandidateSummary d]
  !(Maybe (Failure d))

data PostVerificationRankedCandidateSummary d =
  PostVerificationRankedCandidateSummary !Natural !(CandidateAssessment d)

-- | Seal one associated proposal and retain its receipt-free compatibility
-- state in the same fixed operation.  Receipt weak-head demand deliberately
-- matches the old complete-report projection even though the values are now
-- retained only by the sealed 'PostVerificationBatch'.
sealPostVerificationRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedRanking d
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError (PostVerificationRanking d)
sealPostVerificationRanking maximumCandidates input associated = do
  batch <- sealPostVerificationBatch maximumCandidates input
    $ map associatedRankedCandidateAssociation
    $ associatedRankingCandidates associated
  pure $ retain batch associated
 where
  associatedRankingCandidates (AssociatedRanking candidates _) = candidates
  retain batch (AssociatedRanking candidates failure) =
    PostVerificationRanking batch (projectCandidates [] candidates) failure
  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedCandidate index association state : rest ->
      let verified = postVerificationCandidateVerified association
          projected = PostVerificationRankedCandidateSummary index state
      in verified `seq` projected `seq`
          projectCandidates (projected : reversed) rest

-- | Materialize the established association-free compatibility report from
-- the sole retained receipt owner and its receipt-free summary.  A cardinality
-- mismatch denotes an internal invariant violation rather than a
-- caller-controlled ranking failure.
materializePostVerificationRanking :: PostVerificationRanking d -> Ranking d
materializePostVerificationRanking
    (PostVerificationRanking batch summaries failure) =
  Ranking
    (materializeCandidates [] (postVerificationBatchCandidates batch) summaries)
    failure
 where
  materializeCandidates reversed verifiedRemaining summaryRemaining =
    case (verifiedRemaining, summaryRemaining) of
      ([], []) -> reverse reversed
      (verified : verifiedRest,
          PostVerificationRankedCandidateSummary index state : summaryRest) ->
        let projected = RankedCandidate index verified state
        in projected `seq` materializeCandidates
            (projected : reversed) verifiedRest summaryRest
      _ -> error
        "sealed post-verification ranking summary cardinality changed"

data PreparedCandidate d association
  = PreparedCandidateUnassessed
      !Natural
      !association
      !LengthPreparationRefusalClass
  | PreparedCandidateEligible
      !Natural
      !association
      !(Query d)

-- Budgeted runners ------------------------------------------------------------

data UsableWorkSnapshot d association = UsableWorkSnapshot
  ![PreparedCandidate d association]
  !Bool

type role UsableWorkSnapshot nominal nominal

-- | Budgeted runner over the established batch-local MRU.
rankAssociatedCandidatesWithUsableWorkBudget
  :: forall d association result. LengthRankingDomain d
  => LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedRanking d association -> result)
  -> (result -> ())
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedCandidatesWithUsableWorkBudget =
  rankAssociatedCandidatesWithUsableWorkBudgetAndCursor
    (BatchLocalCounterexampleBank [])

-- | Budgeted runner over an explicit counterexample-bank cursor.  Admission
-- stays outside the shared owner; preparation, live work, and the caller's
-- final transform run beneath the one captured usable-work deadline.
rankAssociatedCandidatesWithUsableWorkBudgetAndCursor
  :: forall d association result command. LengthRankingDomain d
  => CounterexampleBankCursor d command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedRanking d association -> result)
  -> (result -> ())
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedCandidatesWithUsableWorkBudgetAndCursor cursor budget finish
    forceResult policies openingPolicy execution evaluation contract
    verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveUsableWorkDeadline budget $ \deadline -> do
        let prepared = prepareCandidates @d contract verifiedFor admitted
            snapshot = UsableWorkSnapshot prepared False
        _ <- evaluate $ forcePreparedCandidates prepared
        snapshot `seq` writeIORef snapshotRef (Just snapshot)
        ranking <- runPreparedCandidatesUnderUsableWorkDeadline deadline
          execution evaluation policies openingPolicy cursor prepared
        let cleanupIncomplete = associatedRankingCleanupIncomplete ranking
            completedSnapshot = UsableWorkSnapshot prepared cleanupIncomplete
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
                Just (UsableWorkSnapshot _ incomplete) -> incomplete
              failure = ownerRankingFailure @d cleanupIncomplete ownerFailure
              ranking = case snapshot of
                Nothing -> unpreparedUnassessedRanking admitted failure
                Just (UsableWorkSnapshot prepared _) ->
                  unassessedRanking prepared failure
              result = finish ranking
          _ <- evaluate $ forceResult result
          pure $ Right result

-- | Scoped/checkpointed runner over the established batch-local MRU.
rankAssociatedCandidatesWithScopedUsableWorkBudget
  :: forall d association result. LengthRankingDomain d
  => LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedRanking d association -> result)
  -> (result -> ())
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedCandidatesWithScopedUsableWorkBudget =
  rankAssociatedCandidatesWithScopedUsableWorkBudgetAndCursor
    (BatchLocalCounterexampleBank [])

-- | Scoped/checkpointed runner over an explicit counterexample-bank cursor.
-- It selects the same-thread scoped owner with explicit bounded-phase
-- checkpoints.
rankAssociatedCandidatesWithScopedUsableWorkBudgetAndCursor
  :: forall d association result command. LengthRankingDomain d
  => CounterexampleBankCursor d command
  -> LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedRanking d association -> result)
  -> (result -> ())
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedCandidatesWithScopedUsableWorkBudgetAndCursor cursor budget
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
              let prepared = prepareCandidates @d contract verifiedFor admitted
                  snapshot = UsableWorkSnapshot prepared False
              _ <- evaluate $ forcePreparedCandidates prepared
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
                            associatedRankingCleanupIncomplete ranking
                          completedSnapshot = UsableWorkSnapshot
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
          Just (UsableWorkSnapshot _ incomplete) -> incomplete
        rankingFailure = ownerRankingFailure @d cleanupIncomplete failure
        ranking = case snapshot of
          Nothing -> unpreparedUnassessedRanking admitted rankingFailure
          Just (UsableWorkSnapshot prepared _) ->
            unassessedRanking prepared rankingFailure
        result = finish ranking
    _ <- evaluate $ forceResult result
    pure $ Right result

runPreparedCandidatesUnderUsableWorkDeadline
  :: forall d association budget command. LengthRankingDomain d
  => LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO (AssociatedRanking d association)
runPreparedCandidatesUnderUsableWorkDeadline deadline execution evaluation
    policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ AssociatedRanking [] Nothing
  _ | not (hasEligibleCandidate prepared) -> pure $ AssociatedRanking
        (map preparedCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
            $ \session -> runPreparedCandidates evaluation policies
                cursor session prepared
          pure $ case scoped of
            Left failure -> unassessedRanking prepared
              $ sessionRankingFailure @d failure
            Right (Left failure) -> unassessedRanking prepared failure
            Right (Right assessed) -> AssociatedRanking
              (stableCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline
            deadline execution evaluation policies cursor prepared

runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline
  :: forall d association budget command. LengthRankingDomain d
  => LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO (AssociatedRanking d association)
runPreparedCandidatesWithDeferredLiveSessionOpeningUnderDeadline deadline
    execution evaluation policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLive
    evaluation applicableDomainPolicy originProbePolicy simplificationPolicy
    cursor prepared
  case beforeLive of
    PreparedCandidatesCompleted assessed -> pure
      $ AssociatedRanking (stableCounterexampleDemotion assessed) Nothing
    PreparedCandidatesFailed failure -> pure
      $ unassessedRanking prepared failure
    PreparedCandidatesNeedLive reversed nextCursor index association query
        rest -> do
      scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
        $ \session -> do
          observed <- runLiveQuery @d evaluation session query
          case observed of
            Left failure -> pure $ Left $ queryRankingFailure @d index failure
            Right observation -> case
                assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                  simplificationPolicy index association query observation of
              Left failure -> pure $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceCounterexampleBankCursor @d evaluation index
                  query (FreshCounterexample origin) assessed nextCursor
                case advanced of
                  Left failure -> pure $ Left failure
                  Right advancedCursor -> runPreparedCandidatesFrom evaluation
                    policies advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedRanking prepared
          $ sessionRankingFailure @d failure
        Right (Left failure) -> unassessedRanking prepared failure
        Right (Right assessed) -> AssociatedRanking
          (stableCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies

runPreparedCandidatesUnderScopedUsableWorkDeadline
  :: forall d association budget command. LengthRankingDomain d
  => LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedRanking d association))
runPreparedCandidatesUnderScopedUsableWorkDeadline deadline execution
    evaluation policies openingPolicy cursor prepared = case prepared of
  [] -> pure $ Right $ AssociatedRanking [] Nothing
  _ | not (hasEligibleCandidate prepared) -> pure $ Right
        $ AssociatedRanking (map preparedCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
            deadline execution $ \session ->
              runPreparedCandidatesFromUnderScopedUsableWorkDeadline
                deadline evaluation policies cursor session [] prepared
          pure $ case scoped of
            Left failure -> Right $ unassessedRanking prepared
              $ sessionRankingFailure @d failure
            Right (Left failure) -> Left failure
            Right (Right (Left failure)) -> Right
              $ unassessedRanking prepared failure
            Right (Right (Right assessed)) -> Right
              $ AssociatedRanking (stableCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
            deadline execution evaluation policies cursor prepared

runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
  :: forall d association budget command. LengthRankingDomain d
  => LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedRanking d association))
runPreparedCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
    deadline execution evaluation policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline
    deadline evaluation applicableDomainPolicy originProbePolicy
    simplificationPolicy cursor prepared
  case beforeLive of
    Left failure -> pure $ Left failure
    Right (PreparedCandidatesCompleted assessed) -> pure $ Right
      $ AssociatedRanking (stableCounterexampleDemotion assessed) Nothing
    Right (PreparedCandidatesFailed failure) -> pure $ Right
      $ unassessedRanking prepared failure
    Right (PreparedCandidatesNeedLive reversed nextCursor index
        association query rest) -> do
      scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
        deadline execution $ \session -> do
          observed <- runLiveQuery @d evaluation session query
          case observed of
            Left failure -> pure $ Right $ Left
              $ queryRankingFailure @d index failure
            Right observation -> case
                assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                  simplificationPolicy index association query observation of
              Left failure -> pure $ Right $ Left failure
              Right (assessed, origin) -> do
                advanced <- advanceCounterexampleBankCursor @d evaluation
                  index query (FreshCounterexample origin) assessed
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
          $ sessionRankingFailure @d failure
        Right (Left failure) -> Left failure
        Right (Right (Left failure)) -> Right
          $ unassessedRanking prepared failure
        Right (Right (Right assessed)) -> Right
          $ AssociatedRanking (stableCounterexampleDemotion assessed) Nothing
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies

-- | Check after each complete pure candidate chain.  The individual MRU,
-- applicable-domain, origin, and simplification operations are independently
-- bounded and deliberately remain one indivisible checkpoint quantum.
runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline
  :: forall d association budget command. LengthRankingDomain d
  => LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> ApplicableDomainPolicy
  -> OriginProbePolicy
  -> SimplificationPolicy
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (PreparedCandidatesBeforeLive d command association))
runPreparedCandidatesBeforeLiveUnderScopedUsableWorkDeadline deadline
    evaluation applicableDomainPolicy originProbePolicy simplificationPolicy
    initialCursor = go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ Right $ PreparedCandidatesCompleted $ reverse reversed
    PreparedCandidateUnassessed index association refusal : rest ->
      continue
        (AssociatedRankedCandidate index association
          (CandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedCandidateEligible index association query : rest -> do
      replayed <- replayCounterexampleBankCursor @d evaluation index query
        cursor
      case replayed of
        Left failure -> pure $ Right $ PreparedCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation
              simplificationPolicy index association query receipt of
            Left failure -> pure $ Right $ PreparedCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association
            query of
          Left failure -> pure $ Right $ PreparedCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample @d evaluation
              originProbePolicy query of
            Left (ReplayEvaluationRejected failure) -> pure
              $ Right $ PreparedCandidatesFailed $ localRankingFailure @d
                  (ViewOriginProbeEvaluationFailed failure) index
            Left ReplayAssociationRejected -> pure
              $ Right $ PreparedCandidatesFailed $ localRankingFailure @d
                  ViewEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query
                receipt of
              Left failure -> pure $ Right $ PreparedCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              checkpoint <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              pure $ case checkpoint of
                Left failure -> Left failure
                Right () -> Right $ PreparedCandidatesNeedLive
                  reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceCounterexampleBankCursor @d evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right $ PreparedCandidatesFailed failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go reversed cursor rest

-- | Live sibling which checks after every completed candidate before any
-- following candidate can demand pure replay or another live transaction.
runPreparedCandidatesFromUnderScopedUsableWorkDeadline
  :: forall d association budget command epoch. LengthRankingDomain d
  => LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedCandidate d association]
  -> [PreparedCandidate d association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (Either (Failure d) [AssociatedRankedCandidate d association]))
runPreparedCandidatesFromUnderScopedUsableWorkDeadline deadline evaluation
    policies initialCursor session = go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ Right $ reverse reversed
    PreparedCandidateUnassessed index association refusal : rest ->
      continue
        (AssociatedRankedCandidate index association
          (CandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedCandidateEligible index association query : rest -> do
      replayed <- replayCounterexampleBankCursor @d evaluation index query
        cursor
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
          Right Nothing -> case probeOriginCounterexample @d evaluation
              originProbePolicy query of
            Left (ReplayEvaluationRejected failure) -> pure
              $ Right $ Left $ localRankingFailure @d
                  (ViewOriginProbeEvaluationFailed failure) index
            Left ReplayAssociationRejected -> pure
              $ Right $ Left $ localRankingFailure @d
                  ViewEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ Right $ Left failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLiveQuery @d evaluation session query
              case observed of
                Left failure -> pure $ Right $ Left
                  $ queryRankingFailure @d index failure
                Right observation -> case
                    assessCandidateWithCounterexampleOrigin evaluation
                      inputBoxPolicy simplificationPolicy index association query
                      observation of
                  Left failure -> pure $ Right $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (FreshCounterexample origin) rest assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceCounterexampleBankCursor @d evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Right $ Left failure
      Right nextCursor -> continue (assessed : reversed) nextCursor rest

  continue reversed cursor rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go cursor reversed rest

-- Historical runners ----------------------------------------------------------

-- | Rank caller-owned occurrences while retaining each occurrence handle
-- through preparation, live assessment, stable partitioning, and atomic
-- fallback.  The projection is not touched until complete input admission has
-- succeeded.
rankAssociatedCandidates
  :: forall d association. LengthRankingDomain d
  => RankingPolicies
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError (AssociatedRanking d association))
rankAssociatedCandidates policies =
  rankAssociatedCandidatesWithLiveSessionOpening policies
    LengthLiveSessionOpeningEager

-- | 'rankAssociatedCandidates' under an explicit worker-opening policy.
rankAssociatedCandidatesWithLiveSessionOpening
  :: forall d association. LengthRankingDomain d
  => RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError (AssociatedRanking d association))
rankAssociatedCandidatesWithLiveSessionOpening =
  rankAssociatedCandidatesWithLiveSessionOpeningAndCursor
    (BatchLocalCounterexampleBank [])

-- | The unbudgeted runner over an explicit counterexample-bank cursor.
rankAssociatedCandidatesWithLiveSessionOpeningAndCursor
  :: forall d association command. LengthRankingDomain d
  => CounterexampleBankCursor d command
  -> RankingPolicies
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError (AssociatedRanking d association))
rankAssociatedCandidatesWithLiveSessionOpeningAndCursor cursor policies
    openingPolicy execution evaluation contract verifiedFor associations =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries
      associations of
    Left failure -> pure $ Left failure
    Right admitted -> case prepareCandidates @d contract verifiedFor admitted of
      [] -> pure $ Right $ AssociatedRanking [] Nothing
      prepared
        | not (hasEligibleCandidate prepared) -> pure $ Right
            $ AssociatedRanking (map preparedCandidateUnassessed prepared) Nothing
        | otherwise -> case openingPolicy of
            LengthLiveSessionOpeningEager -> do
              scoped <- withLengthSMTLibLiveSession execution
                $ \session -> runPreparedCandidates
                    evaluation policies cursor session prepared
              pure $ Right $ case scoped of
                Left failure -> unassessedRanking prepared
                  $ sessionRankingFailure @d failure
                Right (Left failure) ->
                  unassessedRanking prepared failure
                Right (Right assessed) -> AssociatedRanking
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
  :: forall d association. LengthRankingDomain d
  => Contract d
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> [PreparedCandidate d association]
prepareCandidates contract verifiedFor = go 0 []
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let prepared = prepareCandidate index association
    in prepared `seq` go (index + 1) (prepared : reversed) rest

  prepareCandidate index association =
    case prepareQuery @d contract (verifiedFor association) of
      Left refusal -> PreparedCandidateUnassessed index association refusal
      Right query -> PreparedCandidateEligible index association query

hasEligibleCandidate :: [PreparedCandidate d association] -> Bool
hasEligibleCandidate = any isEligible
 where
  isEligible prepared = case prepared of
    PreparedCandidateUnassessed {} -> False
    PreparedCandidateEligible {} -> True

preparedCandidateUnassessed
  :: forall d association. LengthRankingDomain d
  => PreparedCandidate d association
  -> AssociatedRankedCandidate d association
preparedCandidateUnassessed prepared = case prepared of
  PreparedCandidateUnassessed index association refusal ->
    AssociatedRankedCandidate index association
      $ CandidatePreparationRefused refusal
  PreparedCandidateEligible index association _ ->
    AssociatedRankedCandidate index association
      $ CandidateAssessed (buildAssessment @d ViewUnassessed) Nothing

-- | Result of evaluating the pure prefix before a deferred worker exists.
-- The continuation is private and retains the exact prepared query only until
-- the single live-session scope is either entered or skipped.
data PreparedCandidatesBeforeLive d command association
  = PreparedCandidatesCompleted ![AssociatedRankedCandidate d association]
  | PreparedCandidatesFailed !(Failure d)
  | PreparedCandidatesNeedLive
      ![AssociatedRankedCandidate d association]
      !(CounterexampleBankCursor d command)
      !Natural
      !association
      !(Query d)
      ![PreparedCandidate d association]

type role PreparedCandidatesBeforeLive nominal nominal nominal

runPreparedCandidatesWithDeferredLiveSessionOpening
  :: forall d association command. LengthRankingDomain d
  => LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO (AssociatedRanking d association)
runPreparedCandidatesWithDeferredLiveSessionOpening execution evaluation
    policies cursor prepared = do
  beforeLive <- runPreparedCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy cursor prepared
  case beforeLive of
    PreparedCandidatesCompleted assessed -> pure
      $ AssociatedRanking (stableCounterexampleDemotion assessed) Nothing
    PreparedCandidatesFailed failure -> pure
      $ unassessedRanking prepared failure
    PreparedCandidatesNeedLive reversed nextCursor index association query
        rest -> do
      scoped <- withLengthSMTLibLiveSession execution $ \session -> do
        observed <- runLiveQuery @d evaluation session query
        case observed of
          Left failure -> pure $ Left $ queryRankingFailure @d index failure
          Right observation -> case
              assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
                simplificationPolicy index association query observation of
            Left failure -> pure $ Left failure
            Right (assessed, origin) -> do
              advanced <- advanceCounterexampleBankCursor @d evaluation index
                query (FreshCounterexample origin) assessed nextCursor
              case advanced of
                Left failure -> pure $ Left failure
                Right advancedCursor -> runPreparedCandidatesFrom evaluation
                  policies advancedCursor session (assessed : reversed) rest
      pure $ case scoped of
        Left failure -> unassessedRanking prepared
          $ sessionRankingFailure @d failure
        Right (Left failure) -> unassessedRanking prepared failure
        Right (Right assessed) -> AssociatedRanking
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
  :: forall d association command. LengthRankingDomain d
  => LengthEvaluationLimits
  -> ApplicableDomainPolicy
  -> OriginProbePolicy
  -> SimplificationPolicy
  -> CounterexampleBankCursor d command
  -> [PreparedCandidate d association]
  -> IO (PreparedCandidatesBeforeLive d command association)
runPreparedCandidatesBeforeLive evaluation applicableDomainPolicy
    originProbePolicy simplificationPolicy initialCursor = go [] initialCursor
 where
  go reversed cursor remaining = case remaining of
    [] -> pure $ PreparedCandidatesCompleted $ reverse reversed
    PreparedCandidateUnassessed index association refusal : rest ->
      go (AssociatedRankedCandidate index association
            (CandidatePreparationRefused refusal) : reversed)
        cursor rest
    PreparedCandidateEligible index association query : rest -> do
      replayed <- replayCounterexampleBankCursor @d evaluation index query
        cursor
      case replayed of
        Left failure -> pure $ PreparedCandidatesFailed failure
        Right (Just (receipt, acquisition)) ->
          case simplifyCounterexampleAssessment evaluation simplificationPolicy
              index association query receipt of
            Left failure -> pure $ PreparedCandidatesFailed failure
            Right assessed -> continueAssessed reversed cursor index query
              acquisition rest assessed
        Right Nothing -> case assessApplicableDomainCandidate evaluation
            applicableDomainPolicy simplificationPolicy index association query of
          Left failure -> pure $ PreparedCandidatesFailed failure
          Right (Just assessed) -> continueAssessed reversed cursor index query
            solverIndependentAcquisition rest assessed
          Right Nothing -> case probeOriginCounterexample @d evaluation
              originProbePolicy query of
            Left (ReplayEvaluationRejected failure) -> pure
              $ PreparedCandidatesFailed $ localRankingFailure @d
                  (ViewOriginProbeEvaluationFailed failure) index
            Left ReplayAssociationRejected -> pure
              $ PreparedCandidatesFailed $ localRankingFailure @d
                  ViewEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ PreparedCandidatesFailed failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> pure $ PreparedCandidatesNeedLive
              reversed cursor index association query rest

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceCounterexampleBankCursor @d evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ PreparedCandidatesFailed failure
      Right nextCursor -> go (assessed : reversed) nextCursor rest

runPreparedCandidates
  :: forall d association command epoch. LengthRankingDomain d
  => LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> LengthSMTLibLiveSession epoch
  -> [PreparedCandidate d association]
  -> IO (Either (Failure d) [AssociatedRankedCandidate d association])
runPreparedCandidates evaluation policies cursor session =
  runPreparedCandidatesFrom evaluation policies cursor session []

runPreparedCandidatesFrom
  :: forall d association command epoch. LengthRankingDomain d
  => LengthEvaluationLimits
  -> RankingPolicies
  -> CounterexampleBankCursor d command
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedCandidate d association]
  -> [PreparedCandidate d association]
  -> IO (Either (Failure d) [AssociatedRankedCandidate d association])
runPreparedCandidatesFrom evaluation policies initialCursor session =
  go initialCursor
 where
  inputBoxPolicy = inputBoxPolicyOf policies
  applicableDomainPolicy = applicableDomainPolicyOf policies
  originProbePolicy = originProbePolicyOf policies
  simplificationPolicy = simplificationPolicyOf policies
  go cursor reversed remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedCandidateUnassessed index association refusal : rest ->
      go cursor
        (AssociatedRankedCandidate index association
          (CandidatePreparationRefused refusal) : reversed)
        rest
    PreparedCandidateEligible index association query : rest -> do
      replayed <- replayCounterexampleBankCursor @d evaluation index query
        cursor
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
          Right Nothing -> case probeOriginCounterexample @d evaluation
              originProbePolicy query of
            Left (ReplayEvaluationRejected failure) -> pure
              $ Left $ localRankingFailure @d
                  (ViewOriginProbeEvaluationFailed failure) index
            Left ReplayAssociationRejected -> pure
              $ Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
            Right (Just receipt) -> case simplifyCounterexampleAssessment
                evaluation simplificationPolicy index association query receipt of
              Left failure -> pure $ Left failure
              Right assessed -> continueAssessed reversed cursor index query
                solverIndependentAcquisition rest assessed
            Right Nothing -> do
              observed <- runLiveQuery @d evaluation session query
              case observed of
                Left failure -> pure $ Left $ queryRankingFailure @d index failure
                Right observation -> case
                    assessCandidateWithCounterexampleOrigin evaluation
                      inputBoxPolicy simplificationPolicy index association query
                      observation of
                  Left failure -> pure $ Left failure
                  Right (assessed, origin) -> continueAssessed reversed cursor
                    index query (FreshCounterexample origin) rest assessed

  continueAssessed reversed cursor index query acquisition rest assessed = do
    advanced <- advanceCounterexampleBankCursor @d evaluation index query
      acquisition assessed cursor
    case advanced of
      Left failure -> pure $ Left failure
      Right nextCursor -> go nextCursor (assessed : reversed) rest

-- Assessment steps ------------------------------------------------------------

-- | Attempt the current complete applicable-domain traversal. Inapplicability
-- under that algorithm and failures which prevent bounded traversal admission
-- are ordinary misses. Once admission succeeds, evaluation/internal failures
-- or an evidence association mismatch atomically fail the indexed batch.
assessApplicableDomainCandidate
  :: forall d association. LengthRankingDomain d
  => LengthEvaluationLimits
  -> ApplicableDomainPolicy
  -> SimplificationPolicy
  -> Natural
  -> association
  -> Query d
  -> Either (Failure d) (Maybe (AssociatedRankedCandidate d association))
assessApplicableDomainCandidate evaluation policy simplificationPolicy index
    association query =
  case policy of
    ApplicableDomainDisabled -> Right Nothing
    ApplicableDomainEnabled inputBoxLimits unionLimits -> case
        validateApplicableDomain @d evaluation inputBoxLimits unionLimits query of
      Left DomainAssociationRejected ->
        Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
      Left (DomainValidationRejected failure)
        | applicableDomainAdmissionFailure @d failure -> Right Nothing
        | otherwise -> Left $ localRankingFailure @d
            (ViewApplicableDomainValidationFailed failure) index
      Right DomainInapplicable -> Right Nothing
      Right (DomainCounterexample receipt) -> Just <$>
        simplifyCounterexampleAssessment evaluation simplificationPolicy
          index association query receipt
      Right (DomainEstablished receipt) -> Right $ Just
        $ AssociatedRankedCandidate index association
        $ CandidateAssessed
            (buildAssessment @d $ ViewApplicableDomainEstablished receipt)
            Nothing

-- | Run no replay at all on the compatibility path.  The enabled path
-- delegates arity and zero construction to the exact sealed query; Leant never
-- fabricates or retains an origin vector before a validated receipt exists.
probeOriginCounterexample
  :: forall d. LengthRankingDomain d
  => LengthEvaluationLimits
  -> OriginProbePolicy
  -> Query d
  -> Either (ReplayRejection d) (Maybe (Counterexample d))
probeOriginCounterexample evaluation policy query = case policy of
  OriginProbeDisabled -> Right Nothing
  OriginProbeEnabled -> probeAtOrigin @d evaluation query

-- | The acquisition of every receipt established by a query-owned,
-- solver-free source: applicable-domain traversal and the origin probe.
solverIndependentAcquisition :: CounterexampleAcquisition d command
solverIndependentAcquisition =
  FreshCounterexample BankReceiptFromSolverIndependentReplay

-- | Replay whichever bank the cursor holds against one checked query.
--
-- The batch-local branch is the established raw-vector MRU.  The
-- command-local branch goes through the owner's serialized transition, whose
-- authoritative successor is installed before the outcome is interpreted; a
-- miss and bounded cache unavailability are both ordinary fallthrough, while
-- an impossible authority mismatch fails the indexed batch closed.
replayCounterexampleBankCursor
  :: forall d command. LengthRankingDomain d
  => LengthEvaluationLimits
  -> Natural
  -> Query d
  -> CounterexampleBankCursor d command
  -> IO
      (Either (Failure d)
        (Maybe (Counterexample d, CounterexampleAcquisition d command)))
replayCounterexampleBankCursor evaluation index query cursor = case cursor of
  BatchLocalCounterexampleBank seedBank -> pure $ Right $ case
      replayCounterexampleSeeds @d evaluation query seedBank of
    Nothing -> Nothing
    Just (inputs, receipt) ->
      inputs `seq` Just (receipt, FromBatchReplay inputs)
  CommandLocalCounterexampleBank context -> do
    replayed <- replayBankInContext (bankBridge @d evaluation query) context
    pure $ case replayed of
      Left _ -> Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
      Right outcome -> Right $ case outcome of
        BankReplayMiss _ -> Nothing
        BankReplayAttemptUnavailable _ _ -> Nothing
        BankReplayHit _ hit -> Just
          (bankContextReplayHitCounterexample hit, FromCommandReplay hit)

-- | Install the authoritative successor of the cache side effect for one
-- completed assessment.  Recording deliberately leaves the assessment's
-- pre-record receipt untouched; the fresh receipt returned by the bank is
-- cache confirmation only.
advanceCounterexampleBankCursor
  :: forall d association command. LengthRankingDomain d
  => LengthEvaluationLimits
  -> Natural
  -> Query d
  -> CounterexampleAcquisition d command
  -> AssociatedRankedCandidate d association
  -> CounterexampleBankCursor d command
  -> IO (Either (Failure d) (CounterexampleBankCursor d command))
advanceCounterexampleBankCursor evaluation index query acquisition assessed
    cursor = case assessed of
  AssociatedRankedCandidate _ _ state -> case state of
    CandidatePreparationRefused _ -> pure $ Right cursor
    CandidateAssessed assessment simplification ->
      case viewAssessment @d assessment of
        ViewCounterexample receipt ->
          advanceCounterexample receipt simplification
        _ -> pure $ Right cursor
 where
  mismatch = Left $ localRankingFailure @d ViewEvidenceReplayMismatch index

  advanceCounterexample receipt simplification = case cursor of
    BatchLocalCounterexampleBank seedBank -> case acquisition of
      FromCommandReplay _ -> pure mismatch
      FromBatchReplay _ -> promoteBatch seedBank receipt
      FreshCounterexample _ -> promoteBatch seedBank receipt
    CommandLocalCounterexampleBank context ->
      case (acquisition, simplification) of
        (FromBatchReplay _, _) -> pure mismatch
        (FromCommandReplay hit, Nothing) -> do
          promoted <- promoteBankReplayHitInContext (bankSurface @d) hit context
          pure $ case promoted of
            Left _ -> mismatch
            Right () -> Right cursor
        _ -> do
          recorded <- recordBankReceiptInContext
            (bankBridge @d evaluation query)
            (receiptOrigin simplification) receipt context
          pure $ case recorded of
            Left _ -> mismatch
            Right _ -> Right cursor

  promoteBatch seedBank receipt =
    let promoted = promoteCounterexampleSeed
          (counterexampleInputs @d receipt) seedBank
    in promoted `seq` pure (Right $ BatchLocalCounterexampleBank promoted)

  receiptOrigin simplification = case simplification of
    Just _ -> BankReceiptFromSimplificationReplay
    Nothing -> case acquisition of
      FreshCounterexample origin -> origin
      FromBatchReplay _ -> BankReceiptFromSolverIndependentReplay
      FromCommandReplay _ -> BankReceiptFromSolverIndependentReplay

-- | A seed is only an input vector from an exact receipt.  The later checked
-- query independently evaluates that vector against its own retained problem
-- and associates the resulting evidence back to that problem; no earlier
-- verdict, receipt, provider basis, query identity, or solver observation
-- crosses this edge.  Every rejection and ordinary non-counterexample is a
-- miss, so an older vector can still be attempted.
replayCounterexampleSeeds
  :: forall d. LengthRankingDomain d
  => LengthEvaluationLimits
  -> Query d
  -> [[Natural]]
  -> Maybe ([Natural], Counterexample d)
replayCounterexampleSeeds evaluation query =
  go counterexampleSeedBankMaximumEntries
 where
  go remaining seedBank
    | remaining <= 0 = Nothing
    | otherwise = case seedBank of
        [] -> Nothing
        inputs : rest -> case replayInputs @d evaluation query inputs of
          Right (Just receipt) -> Just (inputs, receipt)
          Left (ReplayEvaluationRejected _) -> go (remaining - 1) rest
          Left ReplayAssociationRejected -> go (remaining - 1) rest
          Right Nothing -> go (remaining - 1) rest

counterexampleSeedBankMaximumEntries :: Int
counterexampleSeedBankMaximumEntries = 4

-- | Insert at the MRU end, remove every exact duplicate, retain at most the
-- four newest distinct vectors, and force that bounded value before it is
-- retained across another candidate.  The bank never contains receipts or
-- query metadata, and repeated promotions cannot accumulate a lazy history
-- chain.
promoteCounterexampleSeed
  :: [Natural]
  -> [[Natural]]
  -> [[Natural]]
promoteCounterexampleSeed inputs seedBank = force $
  inputs : take (counterexampleSeedBankMaximumEntries - 1)
    (filter (/= inputs) seedBank)

assessedCounterexample
  :: forall d association. LengthRankingDomain d
  => Natural
  -> association
  -> Counterexample d
  -> Maybe (Simplification d)
  -> AssociatedRankedCandidate d association
assessedCounterexample index association receipt simplification =
  AssociatedRankedCandidate index association
    $ CandidateAssessed
        (buildAssessment @d $ ViewCounterexample receipt) simplification

-- | Apply the optional simplifier at the single receipt-to-assessment seam.
-- A search-assignment evaluation rejection is a conservative failed trial and
-- retains the already authoritative starting receipt.  Every other admitted
-- simplification failure is an indexed batch failure.  Djex's successful
-- absence likewise retains the original and carries no metadata.
simplifyCounterexampleAssessment
  :: forall d association. LengthRankingDomain d
  => LengthEvaluationLimits
  -> SimplificationPolicy
  -> Natural
  -> association
  -> Query d
  -> Counterexample d
  -> Either (Failure d) (AssociatedRankedCandidate d association)
simplifyCounterexampleAssessment evaluation policy index association query
    receipt = case policy of
  SimplificationDisabled -> Right
    $ assessedCounterexample index association receipt Nothing
  SimplificationEnabled limits -> case
      simplifyCounterexample @d evaluation limits query receipt of
    Left SimplificationTrialRejected -> Right
      $ assessedCounterexample index association receipt Nothing
    Left (SimplificationRejected failure) ->
      Left $ localRankingFailure @d
        (ViewCounterexampleSimplificationFailed failure) index
    Left SimplificationAssociationRejected ->
      Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
    Right Nothing -> Right
      $ assessedCounterexample index association receipt Nothing
    Right (Just simplification) -> Right
      $ assessedCounterexample index association
          (simplificationCounterexample @d simplification)
          (Just simplification)

-- | Assess one gated live observation and name the coarse bank provenance of
-- any counterexample it yields.  A replayed live model is a live-model
-- receipt; a post-@unsat@ box counterexample is solver-independent.  The
-- provenance is a bank label only and carries no evidence authority.
assessCandidateWithCounterexampleOrigin
  :: forall d association. LengthRankingDomain d
  => LengthEvaluationLimits
  -> InputBoxPolicy
  -> SimplificationPolicy
  -> Natural
  -> association
  -> Query d
  -> LiveOutcome d
  -> Either (Failure d)
      (AssociatedRankedCandidate d association, BankReceiptOrigin)
assessCandidateWithCounterexampleOrigin evaluation inputBoxPolicy
    simplificationPolicy index association query observation = do
  (assessment, origin) <- case observation of
    LiveObservationRejected ObservationQueryFingerprintMismatch ->
      Left $ localRankingFailure @d ViewQueryAssociationMismatch index
    LiveObservationRejected ObservationEvidenceProblemMismatch ->
      Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
    LiveHeuristic status -> assessStatus status
    LiveCounterexample receipt ->
      Right (ViewCounterexample receipt, BankReceiptFromLiveModel)
  case assessment of
    ViewCounterexample receipt -> do
      assessed <- simplifyCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
      pure (assessed, origin)
    _ -> pure
      ( AssociatedRankedCandidate index association
          $ CandidateAssessed (buildAssessment @d assessment) Nothing
      , origin
      )
 where
  assessStatus status = case (status, inputBoxPolicy) of
    (SolverUnsatisfiable, InputBoxEnabled limits maximums) ->
      case validateInputBox @d evaluation limits query maximums of
        Left (BoxValidationRejected failure) ->
          Left $ localRankingFailure @d
            (ViewInputBoxValidationFailed failure) index
        Left BoxAssociationRejected ->
          Left $ localRankingFailure @d ViewEvidenceReplayMismatch index
        Right (BoxCounterexample receipt) ->
          Right
            ( ViewCounterexample receipt
            , BankReceiptFromSolverIndependentReplay
            )
        Right (BoxValidated receipt) ->
          Right
            ( ViewBoundedPositive receipt
            , BankReceiptFromSolverIndependentReplay
            )
    _ -> Right (ViewHeuristic status, BankReceiptFromLiveModel)

-- Stable partitioning ---------------------------------------------------------

isCounterexample
  :: forall d. LengthRankingDomain d => CandidateAssessment d -> Bool
isCounterexample state = case viewAssessment @d (candidateAssessment state) of
  ViewCounterexample _ -> True
  _ -> False

isNonVacuousBoundedPositive
  :: forall d. LengthRankingDomain d => CandidateAssessment d -> Bool
isNonVacuousBoundedPositive state =
  case viewAssessment @d (candidateAssessment state) of
    ViewBoundedPositive receipt ->
      inputBoxApplicableAssignmentCount @d receipt > 0
    _ -> False

isNonVacuousApplicableDomain
  :: forall d. LengthRankingDomain d => CandidateAssessment d -> Bool
isNonVacuousApplicableDomain state =
  case viewAssessment @d (candidateAssessment state) of
    ViewApplicableDomainEstablished receipt ->
      applicableDomainApplicableAssignmentCount @d receipt > 0
    _ -> False

stableCounterexampleDemotion
  :: LengthRankingDomain d
  => [AssociatedRankedCandidate d association]
  -> [AssociatedRankedCandidate d association]
stableCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample (AssociatedRankedCandidate _ _ state) = isCounterexample state

stableRankedCounterexampleDemotion
  :: LengthRankingDomain d => [RankedCandidate d] -> [RankedCandidate d]
stableRankedCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample (RankedCandidate _ _ state) = isCounterexample state

-- | Additive evidence-ordering opt-in for an association-free successful
-- ranking.  A positive finite-box receipt is preferred only when at least one
-- checked assignment satisfied the contract precondition.  Vacuous positive
-- receipts remain in the neutral partition, counterexamples remain last, and
-- relative order is stable within all three partitions.  Operational fallback
-- is returned literally so it cannot be mistaken for a successful preference.
preferNonVacuousBoundedPositiveRanking
  :: LengthRankingDomain d => Ranking d -> Ranking d
preferNonVacuousBoundedPositiveRanking =
  preferRanking isNonVacuousBoundedPositive

-- | Occurrence-associated sibling applied before the post-verification
-- permutation seal.  The exact occurrence handle remains inseparable from its
-- assessment through the stable trichotomy.
preferNonVacuousBoundedPositiveAssociatedRanking
  :: LengthRankingDomain d
  => AssociatedRanking d association -> AssociatedRanking d association
preferNonVacuousBoundedPositiveAssociatedRanking =
  preferAssociatedRanking isNonVacuousBoundedPositive

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainRanking
  :: LengthRankingDomain d => Ranking d -> Ranking d
preferNonVacuousApplicableDomainRanking =
  preferRanking isNonVacuousApplicableDomain

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedRanking
  :: LengthRankingDomain d
  => AssociatedRanking d association -> AssociatedRanking d association
preferNonVacuousApplicableDomainAssociatedRanking =
  preferAssociatedRanking isNonVacuousApplicableDomain

preferRanking
  :: LengthRankingDomain d
  => (CandidateAssessment d -> Bool) -> Ranking d -> Ranking d
preferRanking preferred ranking = case ranking of
  Ranking _ (Just _) -> ranking
  Ranking candidates Nothing ->
    let (positive, retained) = partition hasPreferred candidates
    in Ranking (positive ++ stableRankedCounterexampleDemotion retained) Nothing
 where
  hasPreferred (RankedCandidate _ _ state) = preferred state

preferAssociatedRanking
  :: LengthRankingDomain d
  => (CandidateAssessment d -> Bool)
  -> AssociatedRanking d association
  -> AssociatedRanking d association
preferAssociatedRanking preferred ranking = case ranking of
  AssociatedRanking _ (Just _) -> ranking
  AssociatedRanking candidates Nothing ->
    let (positive, retained) = partition hasPreferred candidates
    in AssociatedRanking (positive ++ stableCounterexampleDemotion retained)
        Nothing
 where
  hasPreferred (AssociatedRankedCandidate _ _ state) = preferred state

-- Fallback and failures -------------------------------------------------------

unassessedRanking
  :: LengthRankingDomain d
  => [PreparedCandidate d association]
  -> Failure d
  -> AssociatedRanking d association
unassessedRanking prepared failure =
  AssociatedRanking (sanitizePreparedCandidates prepared) (Just failure)

-- Force the complete already-bounded fallback spine and each sanitized record
-- before exposing the result.  A lazy 'map' would hide the same public values
-- but could retain sealed queries, their checked problems, and command bytes
-- behind an unevaluated tail after an early live failure.
sanitizePreparedCandidates
  :: LengthRankingDomain d
  => [PreparedCandidate d association]
  -> [AssociatedRankedCandidate d association]
sanitizePreparedCandidates = go []
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    candidate : rest ->
      let sanitized = preparedCandidateUnassessed candidate
      in sanitized `seq` go (sanitized : reversed) rest

unpreparedUnassessedRanking
  :: forall d association. LengthRankingDomain d
  => [association]
  -> Failure d
  -> AssociatedRanking d association
unpreparedUnassessedRanking associations failure =
  AssociatedRanking (go 0 [] associations) (Just failure)
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let candidate = AssociatedRankedCandidate index association
          $ CandidateAssessed (buildAssessment @d ViewUnassessed) Nothing
    in candidate `seq` go (index + 1) (candidate : reversed) rest

associatedRankingCleanupIncomplete
  :: forall d association. LengthRankingDomain d
  => AssociatedRanking d association -> Bool
associatedRankingCleanupIncomplete (AssociatedRanking _ Nothing) = False
associatedRankingCleanupIncomplete (AssociatedRanking _ (Just failure)) =
  failureCleanupIncomplete @d failure

ownerRankingFailure
  :: forall d. LengthRankingDomain d
  => Bool -> LengthSMTLibLiveSessionError -> Failure d
ownerRankingFailure nestedCleanup ownerFailure = buildFailure @d
  (buildFailureClass @d $ ViewLiveSessionFailed
    $ lengthSMTLibLiveSessionPrimaryFailure ownerFailure)
  (lengthSMTLibLiveSessionCleanupIncomplete ownerFailure || nestedCleanup)
  Nothing

localRankingFailure
  :: forall d. LengthRankingDomain d
  => FailureClassView d -> Natural -> Failure d
localRankingFailure failure index =
  buildFailure @d (buildFailureClass @d failure) False $ Just index

sessionRankingFailure
  :: forall d. LengthRankingDomain d
  => LengthSMTLibLiveSessionError -> Failure d
sessionRankingFailure failure = buildFailure @d
  (buildFailureClass @d $ ViewLiveSessionFailed
    $ lengthSMTLibLiveSessionPrimaryFailure failure)
  (lengthSMTLibLiveSessionCleanupIncomplete failure)
  Nothing

queryRankingFailure
  :: forall d. LengthRankingDomain d
  => Natural -> LiveError d -> Failure d
queryRankingFailure index failure = buildFailure @d
  (buildFailureClass @d $ ViewLiveQueryFailed
    $ liveErrorPrimaryFailure @d failure)
  (liveErrorCleanupIncomplete @d failure)
  (Just index)

-- Forcing ---------------------------------------------------------------------

-- | Force only ranking-owned structure.  Caller-owned verified receipts and
-- occurrence associations retain their established WHNF boundary.
forceRankingOwnedResult :: forall d. LengthRankingDomain d => Ranking d -> ()
forceRankingOwnedResult (Ranking candidates failure) =
  forceRankedCandidates candidates `seq` forceMaybeFailure @d failure

-- | 'forceRankingOwnedResult' for the occurrence-associated ranking.
forceAssociatedRankingOwnedResult
  :: forall d association. LengthRankingDomain d
  => AssociatedRanking d association -> ()
forceAssociatedRankingOwnedResult (AssociatedRanking candidates failure) =
  forceAssociatedRankedCandidates candidates `seq` forceMaybeFailure @d failure

forceRankedCandidates
  :: forall d. LengthRankingDomain d => [RankedCandidate d] -> ()
forceRankedCandidates candidates = case candidates of
  [] -> ()
  RankedCandidate index verified state : rest ->
    index `seq` verified `seq` forceCandidateAssessment @d state `seq`
      forceRankedCandidates rest

forceAssociatedRankedCandidates
  :: forall d association. LengthRankingDomain d
  => [AssociatedRankedCandidate d association] -> ()
forceAssociatedRankedCandidates candidates = case candidates of
  [] -> ()
  AssociatedRankedCandidate index association state : rest ->
    index `seq` association `seq` forceCandidateAssessment @d state `seq`
      forceAssociatedRankedCandidates rest

forceCandidateAssessment
  :: forall d. LengthRankingDomain d => CandidateAssessment d -> ()
forceCandidateAssessment state = case state of
  CandidatePreparationRefused refusal -> refusal `seq` ()
  CandidateAssessed assessment simplification ->
    forceAssessment @d assessment `seq` case simplification of
      Nothing -> ()
      Just receipt -> forceSimplification @d receipt

forceMaybeFailure
  :: forall d. LengthRankingDomain d => Maybe (Failure d) -> ()
forceMaybeFailure failure = case failure of
  Nothing -> ()
  Just retained -> forceFailure @d retained

forcePreparedCandidates :: [PreparedCandidate d association] -> ()
forcePreparedCandidates prepared = case prepared of
  [] -> ()
  PreparedCandidateUnassessed index association refusal : rest ->
    index `seq` association `seq` refusal `seq` forcePreparedCandidates rest
  PreparedCandidateEligible index association query : rest ->
    index `seq` association `seq` query `seq` forcePreparedCandidates rest
