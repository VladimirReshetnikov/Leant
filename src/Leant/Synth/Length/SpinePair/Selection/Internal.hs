-- | Package-private hard-selection adapter for binary-product Length
-- behavior.
--
-- This is a nominal sibling of scalar Length selection.  It consumes only
-- the existing pair-domain post-verification ranking report, maps every
-- report back to a fresh behavioral-selection handle by its original index,
-- and rejects only an independently replayed pair counterexample.
module Leant.Synth.Length.SpinePair.Selection.Internal
  ( LengthSpinePairSelectionRetentionClass (..)
  , LengthSpinePairSelectionRetention
  , lengthSpinePairSelectionRetentionClass
  , lengthSpinePairSelectionRetentionPreparationRefusal
  , lengthSpinePairSelectionRetentionSolverStatus
  , lengthSpinePairSelectionRetentionInputBox
  , lengthSpinePairSelectionRetentionApplicableDomain
  , LengthSpinePairSelectionRejection
  , lengthSpinePairSelectionRejectionCounterexample
  , lengthSpinePairSelectionRejectionCounterexampleSimplification
  , LengthSpinePairSelectionFailure (..)
  , LengthSpinePairSelectionResult
  , lengthSpinePairSelectionCandidates
  , lengthSpinePairSelectionSelected
  , lengthSpinePairSelectionRejected
  , lengthSpinePairSelectionFailure
  , selectVerifiedLengthSpinePairCandidatesWithPolicy
  , selectVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , SolverStatus
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairInputBox
  , defaultLengthSMTLibLiveSessionMaximumQueries
  )

import Leant.Synth.BehavioralSelection.Internal
  ( BehavioralSelectionBatch
  , BehavioralSelectionCandidate
  , BehavioralSelectionDecision
  , BehavioralSelectionError
  , BehaviorallyRejected
  , BehaviorallySelected
  , behavioralSelectionBatchRejected
  , behavioralSelectionBatchSelected
  , behavioralSelectionInputCandidates
  , behaviorallySelectedVerified
  , rejectBehavioralSelectionCandidate
  , retainBehavioralSelectionCandidate
  , sealBehavioralSelectionBatch
  , withBehavioralSelectionInput
  )
import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  )
import Leant.Synth.Length.Contract (LeanLengthSpinePairContract)
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.Ranking
  ( LengthPreparationRefusalClass )
import Leant.Synth.Length.SpinePair.PostVerification
  ( LengthSpinePairPostVerificationFailure
  , LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationAdapterFailure
  , lengthSpinePairPostVerificationRanking
  , lengthSpinePairPostVerificationRankingFailure
  )
import Leant.Synth.Length.SpinePair.Ranking
  ( LengthSpinePairRankingAssessment (..)
  , LengthSpinePairRankingFailure
  , RankedLengthSpinePairCandidate
  , lengthSpinePairRankingCandidates
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidateCounterexampleSimplification
  , rankedLengthSpinePairCandidateOriginalIndex
  , rankedLengthSpinePairCandidatePreparationRefusal
  )
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

-- | Closed pair-domain reason class for a retained candidate.
data LengthSpinePairSelectionRetentionClass
  = LengthSpinePairSelectionPreparationRefused
  | LengthSpinePairSelectionUnassessed
  | LengthSpinePairSelectionHeuristic
  | LengthSpinePairSelectionBoundedPositive
  | LengthSpinePairSelectionApplicableDomainEstablished
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact pair-domain retention explanation.  The constructor stays private;
-- the closed projections expose the diagnostic or positive receipt without
-- permitting callers to forge a selection decision.
data LengthSpinePairSelectionRetention
  = LengthSpinePairSelectionRetainedPreparationRefusal
      !LengthPreparationRefusalClass
  | LengthSpinePairSelectionRetainedUnassessed
  | LengthSpinePairSelectionRetainedHeuristic !SolverStatus
  | LengthSpinePairSelectionRetainedBoundedPositive
      !ValidatedLengthSpinePairInputBox
  | LengthSpinePairSelectionRetainedApplicableDomainEstablished
      !ValidatedLengthSpinePairApplicableDomain
  deriving (Eq, Show)

-- | The closed reason class of a pair-domain retention explanation.  At most
-- one of the payload projections below returns 'Just' for a given
-- explanation, and none does for 'LengthSpinePairSelectionUnassessed'.
lengthSpinePairSelectionRetentionClass
  :: LengthSpinePairSelectionRetention
  -> LengthSpinePairSelectionRetentionClass
lengthSpinePairSelectionRetentionClass retention = case retention of
  LengthSpinePairSelectionRetainedPreparationRefusal _ ->
    LengthSpinePairSelectionPreparationRefused
  LengthSpinePairSelectionRetainedUnassessed ->
    LengthSpinePairSelectionUnassessed
  LengthSpinePairSelectionRetainedHeuristic _ ->
    LengthSpinePairSelectionHeuristic
  LengthSpinePairSelectionRetainedBoundedPositive _ ->
    LengthSpinePairSelectionBoundedPositive
  LengthSpinePairSelectionRetainedApplicableDomainEstablished _ ->
    LengthSpinePairSelectionApplicableDomainEstablished

-- | The preparation refusal diagnostic of a
-- 'LengthSpinePairSelectionPreparationRefused' retention; 'Nothing' for
-- every other class.
lengthSpinePairSelectionRetentionPreparationRefusal
  :: LengthSpinePairSelectionRetention
  -> Maybe LengthPreparationRefusalClass
lengthSpinePairSelectionRetentionPreparationRefusal retention =
  case retention of
    LengthSpinePairSelectionRetainedPreparationRefusal refusal ->
      Just refusal
    _ -> Nothing

-- | The raw solver status of a 'LengthSpinePairSelectionHeuristic'
-- retention; 'Nothing' for every other class.  A status is a diagnostic,
-- never negative behavioral evidence.
lengthSpinePairSelectionRetentionSolverStatus
  :: LengthSpinePairSelectionRetention
  -> Maybe SolverStatus
lengthSpinePairSelectionRetentionSolverStatus retention = case retention of
  LengthSpinePairSelectionRetainedHeuristic status -> Just status
  _ -> Nothing

-- | The finite pair input-box receipt of a
-- 'LengthSpinePairSelectionBoundedPositive' retention; 'Nothing' for every
-- other class.
lengthSpinePairSelectionRetentionInputBox
  :: LengthSpinePairSelectionRetention
  -> Maybe ValidatedLengthSpinePairInputBox
lengthSpinePairSelectionRetentionInputBox retention = case retention of
  LengthSpinePairSelectionRetainedBoundedPositive receipt -> Just receipt
  _ -> Nothing

-- | The pair applicable-domain receipt of a
-- 'LengthSpinePairSelectionApplicableDomainEstablished' retention; 'Nothing'
-- for every other class.
lengthSpinePairSelectionRetentionApplicableDomain
  :: LengthSpinePairSelectionRetention
  -> Maybe ValidatedLengthSpinePairApplicableDomain
lengthSpinePairSelectionRetentionApplicableDomain retention =
  case retention of
    LengthSpinePairSelectionRetainedApplicableDomainEstablished receipt ->
      Just receipt
    _ -> Nothing

-- | Exact binary-product replay authority for one rejected occurrence.
-- Simplification remains optional metadata owned by that same ranked value.
data LengthSpinePairSelectionRejection =
  LengthSpinePairSelectionRejection
    !ValidatedLengthSpinePairCounterexample
    !(Maybe ValidatedLengthSpinePairCounterexampleSimplification)
  deriving (Eq, Show)

-- | The independently replayed pair counterexample which rejected the
-- occurrence; the ordinary receipt regardless of any simplification.
lengthSpinePairSelectionRejectionCounterexample
  :: LengthSpinePairSelectionRejection
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairSelectionRejectionCounterexample
    (LengthSpinePairSelectionRejection receipt _) = receipt

-- | The optional simplification metadata carried by the same ranked pair
-- candidate as the rejecting counterexample.
lengthSpinePairSelectionRejectionCounterexampleSimplification
  :: LengthSpinePairSelectionRejection
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
lengthSpinePairSelectionRejectionCounterexampleSimplification
    (LengthSpinePairSelectionRejection _ simplification) = simplification

-- | Fail-closed pair-domain reasons which preserve the complete original
-- verification batch.  The index failure is an internal association
-- inconsistency: a ranking report named an occurrence outside the fresh
-- selection input (candidate count, requested index).
data LengthSpinePairSelectionFailure
  = LengthSpinePairSelectionPostVerificationFailed
      !LengthSpinePairPostVerificationFailure
  | LengthSpinePairSelectionRankingFailed
      !LengthSpinePairRankingFailure
  | LengthSpinePairSelectionRankingUnavailable
  | LengthSpinePairSelectionCandidateIndexOutOfRange !Natural !Natural
  | LengthSpinePairSelectionSealFailed !BehavioralSelectionError
  deriving (Eq, Ord, Show)

-- | Opaque preserve-all failure or sealed pair-domain partition.
data LengthSpinePairSelectionResult
  = LengthSpinePairSelectionPreserved
      (VerificationBatch DetailedVerificationVariant)
      !LengthSpinePairSelectionFailure
  | LengthSpinePairSelectionAccepted
      !(BehavioralSelectionBatch
          DetailedVerificationVariant
          LengthSpinePairSelectionRetention
          LengthSpinePairSelectionRejection)

-- | Effective candidates in original callback order.  Failures return the
-- complete original batch; success returns only the selected partition.
lengthSpinePairSelectionCandidates
  :: LengthSpinePairSelectionResult
  -> [Verified DetailedVerificationVariant]
lengthSpinePairSelectionCandidates result = case result of
  LengthSpinePairSelectionPreserved verification _ ->
    verifiedCandidateReceipts verification
  LengthSpinePairSelectionAccepted batch ->
    map behaviorallySelectedVerified $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated selected pair occurrences, available only after
-- the total partition seal succeeded.
lengthSpinePairSelectionSelected
  :: LengthSpinePairSelectionResult
  -> Maybe
      [BehaviorallySelected
        DetailedVerificationVariant LengthSpinePairSelectionRetention]
lengthSpinePairSelectionSelected result = case result of
  LengthSpinePairSelectionPreserved {} -> Nothing
  LengthSpinePairSelectionAccepted batch -> Just
    $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated rejected pair occurrences, available only after
-- the total partition seal succeeded.
lengthSpinePairSelectionRejected
  :: LengthSpinePairSelectionResult
  -> Maybe
      [BehaviorallyRejected
        DetailedVerificationVariant LengthSpinePairSelectionRejection]
lengthSpinePairSelectionRejected result = case result of
  LengthSpinePairSelectionPreserved {} -> Nothing
  LengthSpinePairSelectionAccepted batch -> Just
    $ behavioralSelectionBatchRejected batch

-- | The sanitized failure which preserved the original batch, or 'Nothing'
-- when the total partition was sealed.
lengthSpinePairSelectionFailure
  :: LengthSpinePairSelectionResult
  -> Maybe LengthSpinePairSelectionFailure
lengthSpinePairSelectionFailure result = case result of
  LengthSpinePairSelectionPreserved _ failure -> Just failure
  LengthSpinePairSelectionAccepted {} -> Nothing

-- | Run the complete pair-domain assessment pipeline and reject only exact
-- independently replayed pair counterexamples.  All failures preserve the
-- original verification batch atomically.
selectVerifiedLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairSelectionResult
selectVerifiedLengthSpinePairCandidatesWithPolicy
    policy contract verification = do
  selectVerifiedLengthSpinePairCandidatesWithAssessment
    (assessVerifiedLengthSpinePairCandidatesWithPolicy policy contract)
    verification

-- | 'selectVerifiedLengthSpinePairCandidatesWithPolicy' whose assessment
-- pipeline replays and records pair counterexamples through the supplied
-- command-owned binary-product bank context instead of a batch-local bank.
-- Selection semantics are otherwise identical: only an independently
-- replayed pair counterexample rejects, and every failure preserves the
-- supplied batch.
selectVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthSpinePairCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthSpinePairContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairSelectionResult
selectVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
    policy context contract =
  selectVerifiedLengthSpinePairCandidatesWithAssessment
    $ assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
        policy context contract

selectVerifiedLengthSpinePairCandidatesWithAssessment
  :: (VerificationBatch DetailedVerificationVariant
      -> IO LengthSpinePairPostVerificationResult)
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairSelectionResult
selectVerifiedLengthSpinePairCandidatesWithAssessment assess verification = do
  assessed <- assess verification
  pure $ case lengthSpinePairPostVerificationAdapterFailure assessed of
    Just failure -> preserve
      $ LengthSpinePairSelectionPostVerificationFailed failure
    Nothing -> case lengthSpinePairPostVerificationRankingFailure assessed of
      Just failure -> preserve
        $ LengthSpinePairSelectionRankingFailed failure
      Nothing -> case lengthSpinePairPostVerificationRanking assessed of
        Nothing -> preserve LengthSpinePairSelectionRankingUnavailable
        Just ranking -> withBehavioralSelectionInput verification $ \input ->
          let candidates = behavioralSelectionInputCandidates input
              candidateCount = count candidates
          in case buildDecisions candidateCount candidates
              $ lengthSpinePairRankingCandidates ranking of
            Left failure -> preserve failure
            Right decisions -> case sealBehavioralSelectionBatch
                defaultLengthSMTLibLiveSessionMaximumQueries
                input decisions of
              Left failure -> preserve
                $ LengthSpinePairSelectionSealFailed failure
              Right batch -> LengthSpinePairSelectionAccepted batch
 where
  preserve = LengthSpinePairSelectionPreserved verification

buildDecisions
  :: Natural
  -> [BehavioralSelectionCandidate
        epoch DetailedVerificationVariant]
  -> [RankedLengthSpinePairCandidate]
  -> Either
      LengthSpinePairSelectionFailure
      [BehavioralSelectionDecision
        epoch
        DetailedVerificationVariant
        LengthSpinePairSelectionRetention
        LengthSpinePairSelectionRejection]
buildDecisions candidateCount candidates = go []
 where
  go reversed remaining = case remaining of
    [] -> Right $ reverse reversed
    ranked : rest -> do
      candidate <- selectCandidate candidateCount candidates
        $ rankedLengthSpinePairCandidateOriginalIndex ranked
      let decision = classifyCandidate candidate ranked
      decision `seq` go (decision : reversed) rest

classifyCandidate
  :: BehavioralSelectionCandidate epoch DetailedVerificationVariant
  -> RankedLengthSpinePairCandidate
  -> BehavioralSelectionDecision
      epoch
      DetailedVerificationVariant
      LengthSpinePairSelectionRetention
      LengthSpinePairSelectionRejection
classifyCandidate candidate ranked =
  case rankedLengthSpinePairCandidatePreparationRefusal ranked of
    Just refusal -> retainBehavioralSelectionCandidate candidate
      $ LengthSpinePairSelectionRetainedPreparationRefusal refusal
    Nothing -> case rankedLengthSpinePairCandidateAssessment ranked of
      LengthSpinePairUnassessed ->
        retainBehavioralSelectionCandidate candidate
          LengthSpinePairSelectionRetainedUnassessed
      LengthSpinePairHeuristic status ->
        retainBehavioralSelectionCandidate candidate
          $ LengthSpinePairSelectionRetainedHeuristic status
      LengthSpinePairCounterexample receipt ->
        rejectBehavioralSelectionCandidate candidate
          $ LengthSpinePairSelectionRejection receipt
          $ rankedLengthSpinePairCandidateCounterexampleSimplification ranked
      LengthSpinePairBoundedPositive receipt ->
        retainBehavioralSelectionCandidate candidate
          $ LengthSpinePairSelectionRetainedBoundedPositive receipt
      LengthSpinePairApplicableDomainEstablished receipt ->
        retainBehavioralSelectionCandidate candidate
          $ LengthSpinePairSelectionRetainedApplicableDomainEstablished receipt

selectCandidate
  :: Natural
  -> [BehavioralSelectionCandidate
        epoch DetailedVerificationVariant]
  -> Natural
  -> Either
      LengthSpinePairSelectionFailure
      (BehavioralSelectionCandidate epoch DetailedVerificationVariant)
selectCandidate candidateCount = go 0
 where
  go _ [] requested = Left
    $ LengthSpinePairSelectionCandidateIndexOutOfRange
      candidateCount requested
  go index (candidate : rest) requested
    | index == requested = Right candidate
    | otherwise = go (index + 1) rest requested

count :: [value] -> Natural
count = go 0
 where
  go result remaining = case remaining of
    [] -> result
    _ : rest -> go (result + 1) rest
