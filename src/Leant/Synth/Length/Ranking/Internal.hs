{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live Length ranking.
--
-- This module is the only Leant layer which opens Djex's public live Length
-- session.  It first productively bounds the complete input, then prepares
-- every checked problem and canonical query before launching a worker.
-- Eligible queries run serially in original order inside one rank-N scope.
--
-- A solver status is heuristic only.  An optional counterexample is retained
-- only after Djex's public live replay gate checks the exact query fingerprint
-- and replays its evidence against the behavioral problem retained by that
-- query.  Even that receipt is finite-spine and model-relative: it is neither a
-- proof nor a claim about the source-level realization of a Lean term.
-- Ranking therefore never prunes.  It stably moves candidates with replayed
-- counterexamples after every other candidate and preserves source order
-- within both partitions.
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
  , AssociatedRankedLengthCandidate
  , associatedRankedLengthCandidateAssociation
  , AssociatedLengthRanking
  , associatedLengthRankingCandidates
  , PostVerificationLengthRanking
  , sealPostVerificationLengthRanking
  , postVerificationLengthRankingBatch
  , postVerificationLengthRankingFailure
  , materializePostVerificationLengthRanking
  , rankPostVerificationLengthCandidates
  , rankVerifiedLengthCandidates
  ) where

import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthEvaluationLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibQueryError (..)
  , LengthSMTLibLiveObservationReplayError (..)
  , LengthSMTLibLiveQueryError
  , LengthSMTLibLiveQueryFailure
  , LengthSMTLibLiveQueryObservation
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , SolverStatus
  , ValidatedLengthCounterexample
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveQueryCleanupIncomplete
  , lengthSMTLibLiveQueryObservationSolverStatus
  , lengthSMTLibLiveQueryPrimaryFailure
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
  , replayLengthSMTLibLiveQueryObservation
  , runLengthSMTLibLiveQuery
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

-- | The only three public assessment strengths.  A heuristic status is
-- deliberately neutral for ordering; only a replayed counterexample is
-- stably demoted.
data LengthRankingAssessment
  = Unassessed
  | Heuristic !SolverStatus
  | Counterexample !ValidatedLengthCounterexample
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

rankedLengthCandidateOriginalIndex :: RankedLengthCandidate -> Natural
rankedLengthCandidateOriginalIndex (RankedLengthCandidate index _ _) = index

rankedLengthCandidateVerified
  :: RankedLengthCandidate
  -> Verified DetailedVerificationVariant
rankedLengthCandidateVerified (RankedLengthCandidate _ verified _) = verified

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

-- | Payload-free failure classes.  Nested live failures are already sanitized
-- by Djex; association and replay failures deliberately discard their richer
-- internal diagnostics here.  Pure handoff/query-sealing refusals are ordinary
-- per-candidate absence of assessment rather than batch failures.
data LengthRankingFailureClass
  = LengthRankingLiveSessionFailed !LengthSMTLibLiveSessionFailure
  | LengthRankingLiveQueryFailed !LengthSMTLibLiveQueryFailure
  | LengthRankingQueryAssociationMismatch
  | LengthRankingEvidenceReplayMismatch
  deriving (Eq, Ord, Show)

-- | One fail-closed ranking failure.  The optional index is the safe,
-- zero-based position in the caller's admitted input, never a solver ordinal.
-- The Boolean copies only Djex's sanitized incomplete-cleanup observation.
data LengthRankingFailure = LengthRankingFailure
  !LengthRankingFailureClass
  !Bool
  !(Maybe Natural)
  deriving (Eq, Ord, Show)

lengthRankingFailureClass
  :: LengthRankingFailure
  -> LengthRankingFailureClass
lengthRankingFailureClass (LengthRankingFailure failure _ _) = failure

lengthRankingFailureCleanupIncomplete :: LengthRankingFailure -> Bool
lengthRankingFailureCleanupIncomplete
    (LengthRankingFailure _ incomplete _) = incomplete

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

lengthRankingCandidates :: LengthRanking -> [RankedLengthCandidate]
lengthRankingCandidates (LengthRanking candidates _) = candidates

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

-- | Rank one already Lean-callback-verified batch under an explicit behavioral
-- contract and explicit live/evaluation policies.
--
-- Input admission precedes all behavioral-preparation work. A successfully
-- checked problem is transient until query sealing; prepared state retains
-- only the caller-owned receipt association and query. An empty admitted batch
-- opens no worker. Every nonempty eligible batch uses exactly one live session
-- and executes its pre-sealed queries serially in original order.
rankVerifiedLengthCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidates execution evaluation contract candidates = fmap
  (fmap $ projectAssociatedLengthRankingWith id)
  $ rankAssociatedLengthCandidates execution evaluation contract id candidates

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
  rankAssociatedLengthCandidates execution evaluation contract
    postVerificationCandidateVerified

-- | Rank caller-owned occurrences while retaining each occurrence handle
-- through preparation, live assessment, stable partitioning, and atomic
-- fallback.  The projection is not touched until complete input admission has
-- succeeded.
rankAssociatedLengthCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking association))
rankAssociatedLengthCandidates execution evaluation contract
    verifiedFor associations =
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
              $ \session -> runPreparedCandidates evaluation session prepared
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
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthCandidate association]
  -> IO
      (Either LengthRankingFailure
        [AssociatedRankedLengthCandidate association])
runPreparedCandidates evaluation session = go []
 where
  go reversed remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthCandidateUnassessed
        index association refusal : rest ->
      go (AssociatedRankedLengthCandidate
        index association
          (LengthCandidatePreparationRefused refusal) : reversed) rest
    PreparedLengthCandidateEligible
        index association query : rest -> do
      observed <- runLengthSMTLibLiveQuery evaluation session query
      case observed of
        Left failure -> pure $ Left $ queryRankingFailure index failure
        Right observation -> case
            assessCandidate index association query observation of
          Left failure -> pure $ Left failure
          Right assessed -> go (assessed : reversed) rest

assessCandidate
  :: Natural
  -> association
  -> CheckedLengthQuery
  -> LengthSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthRankingFailure
      (AssociatedRankedLengthCandidate association)
assessCandidate index association query observation = do
  assessment <- case
      replayLengthSMTLibLiveQueryObservation query observation of
    Left LengthSMTLibLiveObservationQueryFingerprintMismatch ->
      Left $ localRankingFailure LengthRankingQueryAssociationMismatch index
    Left LengthSMTLibLiveObservationEvidenceProblemMismatch{} ->
      Left $ localRankingFailure LengthRankingEvidenceReplayMismatch index
    Right Nothing -> Right $ Heuristic
      $ lengthSMTLibLiveQueryObservationSolverStatus observation
    Right (Just receipt) -> Right $ Counterexample receipt
  pure $ AssociatedRankedLengthCandidate index association
    $ LengthCandidateAssessed assessment

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
