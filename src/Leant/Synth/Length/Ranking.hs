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
  , LeanLengthContract
  , checkedLengthHandoffProblem
  , checkedLengthHandoffVerifiedVariant
  , prepareCheckedLengthHandoff
  )
import Leant.Synth.Length.Adapter
  ( CheckedLengthQuery
  , prepareLengthQueryFromHandoff
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
  !(Verified DetailedVerificationVariant)
  !LengthRankingAssessment

rankedLengthCandidateVerified
  :: RankedLengthCandidate
  -> Verified DetailedVerificationVariant
rankedLengthCandidateVerified (RankedLengthCandidate verified _) = verified

rankedLengthCandidateAssessment
  :: RankedLengthCandidate
  -> LengthRankingAssessment
rankedLengthCandidateAssessment (RankedLengthCandidate _ assessment) = assessment

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

data PreparedLengthCandidate
  = PreparedLengthCandidateUnassessed
      !(Verified DetailedVerificationVariant)
  | PreparedLengthCandidateEligible
      !Natural
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
rankVerifiedLengthCandidates execution evaluation contract candidates =
  case admitCandidates defaultLengthSMTLibLiveSessionMaximumQueries candidates of
    Left failure -> pure $ Left failure
    Right admitted -> case prepareCandidates contract admitted of
      [] -> pure $ Right $ LengthRanking [] Nothing
      prepared
        | not (hasEligibleCandidate prepared) -> pure $ Right $ LengthRanking
            (map preparedCandidateUnassessed prepared) Nothing
        | otherwise -> do
            scoped <- withLengthSMTLibLiveSession execution
              $ \session -> runPreparedCandidates evaluation session prepared
            pure $ Right $ case scoped of
              Left failure -> unassessedRanking admitted
                $ sessionRankingFailure failure
              Right (Left failure) -> unassessedRanking admitted failure
              Right (Right assessed) -> LengthRanking
                (stableCounterexampleDemotion assessed) Nothing

admitCandidates
  :: Natural
  -> [Verified DetailedVerificationVariant]
  -> Either
      LengthRankingInputError
      [Verified DetailedVerificationVariant]
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
  -> [Verified DetailedVerificationVariant]
  -> [PreparedLengthCandidate]
prepareCandidates contract = go 0 []
 where
  go _ reversed [] = reverse reversed
  go index reversed (verified : rest) =
    let prepared = prepareCandidate index verified
    in prepared `seq` go (index + 1) (prepared : reversed) rest

  prepareCandidate index verified = case
      prepareCheckedLengthHandoff contract verified of
    Left _ -> PreparedLengthCandidateUnassessed verified
    Right handoff -> case prepareLengthQueryFromHandoff handoff of
      Left _ -> PreparedLengthCandidateUnassessed verified
      Right query -> PreparedLengthCandidateEligible index handoff query

hasEligibleCandidate :: [PreparedLengthCandidate] -> Bool
hasEligibleCandidate = any isEligible
 where
  isEligible prepared = case prepared of
    PreparedLengthCandidateUnassessed {} -> False
    PreparedLengthCandidateEligible {} -> True

preparedCandidateUnassessed
  :: PreparedLengthCandidate
  -> RankedLengthCandidate
preparedCandidateUnassessed prepared = case prepared of
  PreparedLengthCandidateUnassessed verified ->
    RankedLengthCandidate verified Unassessed
  PreparedLengthCandidateEligible _ handoff _ -> RankedLengthCandidate
    (checkedLengthHandoffVerifiedVariant handoff) Unassessed

runPreparedCandidates
  :: LengthEvaluationLimits
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthCandidate]
  -> IO (Either LengthRankingFailure [RankedLengthCandidate])
runPreparedCandidates evaluation session = go []
 where
  go reversed remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthCandidateUnassessed verified : rest ->
      go (RankedLengthCandidate verified Unassessed : reversed) rest
    PreparedLengthCandidateEligible index handoff query : rest -> do
      observed <- runLengthSMTLibLiveQuery evaluation session query
      case observed of
        Left failure -> pure $ Left $ queryRankingFailure index failure
        Right observation -> case
            assessCandidate index handoff query observation of
          Left failure -> pure $ Left failure
          Right assessed -> go (assessed : reversed) rest

assessCandidate
  :: Natural
  -> CheckedLengthHandoff
  -> CheckedLengthQuery
  -> LengthSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthRankingFailure RankedLengthCandidate
assessCandidate index handoff query observation
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
      pure $ RankedLengthCandidate
        (checkedLengthHandoffVerifiedVariant handoff) assessment

stableCounterexampleDemotion
  :: [RankedLengthCandidate]
  -> [RankedLengthCandidate]
stableCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample candidate = case rankedLengthCandidateAssessment candidate of
    Counterexample _ -> True
    _ -> False

unassessedRanking
  :: [Verified DetailedVerificationVariant]
  -> LengthRankingFailure
  -> LengthRanking
unassessedRanking candidates failure = LengthRanking
  (map (`RankedLengthCandidate` Unassessed) candidates)
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
