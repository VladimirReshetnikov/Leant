{-# LANGUAGE RoleAnnotations #-}

-- | Conservative live Length ranking for callback-verified candidates.
--
-- This module is the only Leant layer which opens Djex's public live Length
-- session.  It first productively bounds the complete input, then seals every
-- checked handoff and canonical query before launching a worker.  Eligible
-- queries run serially in original order inside one rank-N scope.
--
-- A solver status is heuristic only.  An optional counterexample is retained
-- only after the public live result has the exact query fingerprint and its
-- evidence replays again against the handoff's exact checked problem.  Even
-- that receipt is finite-spine and model-relative: it is neither a proof nor a
-- claim about the source-level realization of a Lean term.  Ranking therefore
-- never prunes.  It stably moves candidates with replayed counterexamples after
-- every other candidate and preserves source order within both partitions.
--
-- The private opener/finalizer budgets and the execution policy's per-query
-- host budget remain separate; this function promises no batch-wide hard
-- wall-clock deadline.  Synchronous and asynchronous exceptions are not
-- caught here and retain the live facade's durable-cleanup behavior.
module Leant.Synth.Length.Ranking
  ( LengthRankingInputError (..)
  , LengthRankingAssessment (..)
  , RankedLengthCandidate
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidateVerified
  , rankedLengthCandidateAssessment
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
  , projectAssociatedLengthRanking
  , rankPostVerificationLengthCandidates
  , rankVerifiedLengthCandidates
  ) where

import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthEvaluationLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveQueryError
  , LengthSMTLibLiveQueryFailure
  , LengthSMTLibLiveQueryObservation
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , SolverStatus
  , ValidatedLengthCounterexample
  , checkedLengthProblemBehavioralProblem
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveQueryCleanupIncomplete
  , lengthSMTLibLiveQueryObservationCounterexampleEvidence
  , lengthSMTLibLiveQueryObservationQueryFingerprint
  , lengthSMTLibLiveQueryObservationSolverStatus
  , lengthSMTLibLiveQueryPrimaryFailure
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
  , lengthSMTLibQueryFingerprint
  , replayBehavioralEvidence
  , runLengthSMTLibLiveQuery
  , withLengthSMTLibLiveSession
  )

import Leant.Synth.Engine
  ( CheckedLengthHandoff
  , DetailedVerificationVariant
  , checkedLengthHandoffProblem
  , checkedLengthHandoffVerifiedVariant
  , prepareCheckedLengthHandoff
  )
import Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareLengthQueryFromHandoff
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.PostVerification
  ( PostVerificationCandidate
  , postVerificationCandidateVerified
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

-- | One callback receipt and the assessment made for that exact candidate.
-- The constructor stays private so receipts cannot be detached and paired
-- with another candidate's assessment.
data RankedLengthCandidate = RankedLengthCandidate
  !Natural
  !(Verified DetailedVerificationVariant)
  !LengthRankingAssessment

rankedLengthCandidateOriginalIndex :: RankedLengthCandidate -> Natural
rankedLengthCandidateOriginalIndex (RankedLengthCandidate index _ _) = index

rankedLengthCandidateVerified
  :: RankedLengthCandidate
  -> Verified DetailedVerificationVariant
rankedLengthCandidateVerified (RankedLengthCandidate _ verified _) = verified

rankedLengthCandidateAssessment
  :: RankedLengthCandidate
  -> LengthRankingAssessment
rankedLengthCandidateAssessment (RankedLengthCandidate _ _ assessment) =
  assessment

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
-- inseparable from the verified receipt and assessment derived from it.
data AssociatedRankedLengthCandidate association =
  AssociatedRankedLengthCandidate
    !Natural
    !association
    !(Verified DetailedVerificationVariant)
    !LengthRankingAssessment

type role AssociatedRankedLengthCandidate nominal

associatedRankedLengthCandidateAssociation
  :: AssociatedRankedLengthCandidate association
  -> association
associatedRankedLengthCandidateAssociation
    (AssociatedRankedLengthCandidate _ association _ _) = association

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

-- | Project an association-free compatibility report.  A batch-scoped adapter
-- must validate its occurrence order before calling this; the legacy direct
-- runner uses the verified receipt itself as its association and therefore
-- needs no separate post-verification handle seal.
projectAssociatedLengthRanking
  :: AssociatedLengthRanking association
  -> LengthRanking
projectAssociatedLengthRanking (AssociatedLengthRanking candidates failure) =
  LengthRanking (map projectCandidate candidates) failure
 where
  projectCandidate (AssociatedRankedLengthCandidate
      index _ verified assessment) =
    RankedLengthCandidate index verified assessment

data PreparedLengthCandidate association
  = PreparedLengthCandidateUnassessed
      !Natural
      !association
      !(Verified DetailedVerificationVariant)
  | PreparedLengthCandidateEligible
      !Natural
      !association
      !CheckedLengthHandoff
      !CheckedLengthQuery

-- | Rank one already Lean-callback-verified batch under an explicit behavioral
-- contract and explicit live/evaluation policies.
--
-- Input admission precedes all handoff work.  An empty admitted batch opens no
-- worker.  Every nonempty eligible batch uses exactly one live session and
-- executes its pre-sealed queries serially in original order.
rankVerifiedLengthCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidates execution evaluation contract candidates = fmap
  (fmap projectAssociatedLengthRanking)
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
              Left failure -> unassessedRanking admitted verifiedFor
                $ sessionRankingFailure failure
              Right (Left failure) ->
                unassessedRanking admitted verifiedFor failure
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
    in case prepareCheckedLengthHandoff contract verified of
      Left _ -> PreparedLengthCandidateUnassessed
        index association verified
      Right handoff -> case prepareLengthQueryFromHandoff handoff of
        Left _ -> PreparedLengthCandidateUnassessed
          index association verified
        Right query -> PreparedLengthCandidateEligible
          index association handoff query

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
  PreparedLengthCandidateUnassessed index association verified ->
    AssociatedRankedLengthCandidate
      index association verified Unassessed
  PreparedLengthCandidateEligible index association handoff _ ->
    AssociatedRankedLengthCandidate index association
      (checkedLengthHandoffVerifiedVariant handoff) Unassessed

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
    PreparedLengthCandidateUnassessed index association verified : rest ->
      go (AssociatedRankedLengthCandidate
        index association verified Unassessed : reversed) rest
    PreparedLengthCandidateEligible index association handoff query : rest -> do
      observed <- runLengthSMTLibLiveQuery evaluation session query
      case observed of
        Left failure -> pure $ Left $ queryRankingFailure index failure
        Right observation -> case
            assessCandidate index association handoff query observation of
          Left failure -> pure $ Left failure
          Right assessed -> go (assessed : reversed) rest

assessCandidate
  :: Natural
  -> association
  -> CheckedLengthHandoff
  -> CheckedLengthQuery
  -> LengthSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthRankingFailure
      (AssociatedRankedLengthCandidate association)
assessCandidate index association handoff query observation
  | lengthSMTLibLiveQueryObservationQueryFingerprint observation /=
      lengthSMTLibQueryFingerprint query =
        Left $ localRankingFailure
          LengthRankingQueryAssociationMismatch index
  | otherwise = do
      assessment <- case
          lengthSMTLibLiveQueryObservationCounterexampleEvidence observation of
        Nothing -> Right $ Heuristic
          $ lengthSMTLibLiveQueryObservationSolverStatus observation
        Just evidence -> case replayBehavioralEvidence
            (checkedLengthProblemBehavioralProblem
              $ checkedLengthHandoffProblem handoff)
            evidence of
          Left _ -> Left $ localRankingFailure
            LengthRankingEvidenceReplayMismatch index
          Right receipt -> Right $ Counterexample receipt
      pure $ AssociatedRankedLengthCandidate index association
        (checkedLengthHandoffVerifiedVariant handoff) assessment

stableCounterexampleDemotion
  :: [AssociatedRankedLengthCandidate association]
  -> [AssociatedRankedLengthCandidate association]
stableCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
 in retained ++ counterexamples
 where
  hasCounterexample (AssociatedRankedLengthCandidate _ _ _ assessment) =
    case assessment of
      Counterexample _ -> True
      _ -> False

unassessedRanking
  :: [association]
  -> (association -> Verified DetailedVerificationVariant)
  -> LengthRankingFailure
  -> AssociatedLengthRanking association
unassessedRanking associations verifiedFor failure = AssociatedLengthRanking
  (zipWith
    (\index association -> AssociatedRankedLengthCandidate
      index association (verifiedFor association) Unassessed)
    [0 ..]
    associations)
  (Just failure)

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
