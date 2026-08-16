-- | Package-private hard-selection adapter for scalar Length behavior.
--
-- The existing post-verification ranking pipeline remains the only producer
-- of behavioral assessments.  This layer gives exactly one assessment back
-- to the matching occurrence of a fresh behavioral-selection epoch by using
-- the ranking report's original index.  Only an independently replayed
-- counterexample becomes a rejection; every other assessment is retained
-- with an explicit reason.
module Leant.Synth.Length.Selection.Internal
  ( LengthSelectionRetentionClass (..)
  , LengthSelectionRetention
  , lengthSelectionRetentionClass
  , lengthSelectionRetentionPreparationRefusal
  , lengthSelectionRetentionSolverStatus
  , lengthSelectionRetentionInputBox
  , lengthSelectionRetentionApplicableDomain
  , LengthSelectionRejection
  , lengthSelectionRejectionCounterexample
  , lengthSelectionRejectionCounterexampleSimplification
  , LengthSelectionFailure (..)
  , LengthSelectionResult
  , lengthSelectionCandidates
  , lengthSelectionSelected
  , lengthSelectionRejected
  , lengthSelectionFailure
  , selectVerifiedLengthCandidatesWithPolicy
  , selectVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , SolverStatus
  , ValidatedLengthApplicableDomain
  , ValidatedLengthCounterexample
  , ValidatedLengthCounterexampleSimplification
  , ValidatedLengthInputBox
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
  , assessVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import qualified Leant.Synth.Length.CounterexampleBank.Internal
  as CounterexampleBank
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure
  , LengthPostVerificationResult
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  )
import Leant.Synth.Length.Ranking
  ( LengthPreparationRefusalClass
  , LengthRankingAssessment (..)
  , LengthRankingFailure
  , RankedLengthCandidate
  , lengthRankingCandidates
  , rankedLengthCandidateAssessment
  , rankedLengthCandidateCounterexampleSimplification
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidatePreparationRefusal
  )
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

-- | Closed reason class for a candidate which the hard filter retained.
-- None of these cases is negative behavioral evidence.
data LengthSelectionRetentionClass
  = LengthSelectionPreparationRefused
  | LengthSelectionUnassessed
  | LengthSelectionHeuristic
  | LengthSelectionBoundedPositive
  | LengthSelectionApplicableDomainEstablished
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Domain-specific retention explanation.  Its constructor stays private so
-- an explanation cannot be forged and attached through the private decision
-- builders.  The projections below expose the exact diagnostic or positive
-- receipt carried by the corresponding closed class.
data LengthSelectionRetention
  = LengthSelectionRetainedPreparationRefusal
      !LengthPreparationRefusalClass
  | LengthSelectionRetainedUnassessed
  | LengthSelectionRetainedHeuristic !SolverStatus
  | LengthSelectionRetainedBoundedPositive !ValidatedLengthInputBox
  | LengthSelectionRetainedApplicableDomainEstablished
      !ValidatedLengthApplicableDomain
  deriving (Eq, Show)

-- | The closed reason class of a retention explanation.  At most one of the
-- payload projections below returns 'Just' for a given explanation, and none
-- does for 'LengthSelectionUnassessed'.
lengthSelectionRetentionClass
  :: LengthSelectionRetention
  -> LengthSelectionRetentionClass
lengthSelectionRetentionClass retention = case retention of
  LengthSelectionRetainedPreparationRefusal _ ->
    LengthSelectionPreparationRefused
  LengthSelectionRetainedUnassessed -> LengthSelectionUnassessed
  LengthSelectionRetainedHeuristic _ -> LengthSelectionHeuristic
  LengthSelectionRetainedBoundedPositive _ -> LengthSelectionBoundedPositive
  LengthSelectionRetainedApplicableDomainEstablished _ ->
    LengthSelectionApplicableDomainEstablished

-- | The preparation refusal diagnostic of a
-- 'LengthSelectionPreparationRefused' retention; 'Nothing' for every other
-- class.
lengthSelectionRetentionPreparationRefusal
  :: LengthSelectionRetention
  -> Maybe LengthPreparationRefusalClass
lengthSelectionRetentionPreparationRefusal retention = case retention of
  LengthSelectionRetainedPreparationRefusal refusal -> Just refusal
  _ -> Nothing

-- | The raw solver status of a 'LengthSelectionHeuristic' retention;
-- 'Nothing' for every other class.  A status is a diagnostic, never negative
-- behavioral evidence.
lengthSelectionRetentionSolverStatus
  :: LengthSelectionRetention
  -> Maybe SolverStatus
lengthSelectionRetentionSolverStatus retention = case retention of
  LengthSelectionRetainedHeuristic status -> Just status
  _ -> Nothing

-- | The finite input-box receipt of a 'LengthSelectionBoundedPositive'
-- retention; 'Nothing' for every other class.
lengthSelectionRetentionInputBox
  :: LengthSelectionRetention
  -> Maybe ValidatedLengthInputBox
lengthSelectionRetentionInputBox retention = case retention of
  LengthSelectionRetainedBoundedPositive receipt -> Just receipt
  _ -> Nothing

-- | The applicable-domain receipt of a
-- 'LengthSelectionApplicableDomainEstablished' retention; 'Nothing' for every
-- other class.
lengthSelectionRetentionApplicableDomain
  :: LengthSelectionRetention
  -> Maybe ValidatedLengthApplicableDomain
lengthSelectionRetentionApplicableDomain retention = case retention of
  LengthSelectionRetainedApplicableDomainEstablished receipt -> Just receipt
  _ -> Nothing

-- | Exact scalar replay authority for one rejected occurrence.  The nominal
-- scalar type and private constructor prevent confusion with binary-product
-- receipts.  Simplification is optional metadata; the ordinary receipt is
-- always the final independently replayed counterexample.
data LengthSelectionRejection = LengthSelectionRejection
  !ValidatedLengthCounterexample
  !(Maybe ValidatedLengthCounterexampleSimplification)
  deriving (Eq, Show)

-- | The independently replayed scalar counterexample which rejected the
-- occurrence; the ordinary receipt regardless of any simplification.
lengthSelectionRejectionCounterexample
  :: LengthSelectionRejection
  -> ValidatedLengthCounterexample
lengthSelectionRejectionCounterexample
    (LengthSelectionRejection receipt _) = receipt

-- | The optional simplification metadata carried by the same ranked
-- candidate as the rejecting counterexample.
lengthSelectionRejectionCounterexampleSimplification
  :: LengthSelectionRejection
  -> Maybe ValidatedLengthCounterexampleSimplification
lengthSelectionRejectionCounterexampleSimplification
    (LengthSelectionRejection _ simplification) = simplification

-- | Fail-closed reasons which preserve the complete original verification
-- batch.  The index failure is an internal association inconsistency: a
-- ranking report named an occurrence outside the fresh selection input.
data LengthSelectionFailure
  = LengthSelectionPostVerificationFailed
      !LengthPostVerificationFailure
  | LengthSelectionRankingFailed !LengthRankingFailure
  | LengthSelectionRankingUnavailable
  | LengthSelectionCandidateIndexOutOfRange !Natural !Natural
  | LengthSelectionSealFailed !BehavioralSelectionError
  deriving (Eq, Ord, Show)

-- | Either the untouched callback batch plus a sanitized failure, or one
-- sealed total partition.  The constructors stay private so a caller cannot
-- present an unsealed partition as accepted selection authority.
data LengthSelectionResult
  = LengthSelectionPreserved
      (VerificationBatch DetailedVerificationVariant)
      !LengthSelectionFailure
  | LengthSelectionAccepted
      !(BehavioralSelectionBatch
          DetailedVerificationVariant
          LengthSelectionRetention
          LengthSelectionRejection)

-- | Effective candidates after selection.  On every failure this is exactly
-- the original callback batch in original order; on success it is exactly the
-- selected partition in original callback order.
lengthSelectionCandidates
  :: LengthSelectionResult
  -> [Verified DetailedVerificationVariant]
lengthSelectionCandidates result = case result of
  LengthSelectionPreserved verification _ ->
    verifiedCandidateReceipts verification
  LengthSelectionAccepted batch ->
    map behaviorallySelectedVerified $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated selected occurrences, available only after the
-- total partition seal succeeded.
lengthSelectionSelected
  :: LengthSelectionResult
  -> Maybe
      [BehaviorallySelected
        DetailedVerificationVariant LengthSelectionRetention]
lengthSelectionSelected result = case result of
  LengthSelectionPreserved {} -> Nothing
  LengthSelectionAccepted batch -> Just
    $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated rejected occurrences, available only after the
-- total partition seal succeeded.
lengthSelectionRejected
  :: LengthSelectionResult
  -> Maybe
      [BehaviorallyRejected
        DetailedVerificationVariant LengthSelectionRejection]
lengthSelectionRejected result = case result of
  LengthSelectionPreserved {} -> Nothing
  LengthSelectionAccepted batch -> Just
    $ behavioralSelectionBatchRejected batch

-- | The sanitized failure which preserved the original batch, or 'Nothing'
-- when the total partition was sealed.
lengthSelectionFailure
  :: LengthSelectionResult
  -> Maybe LengthSelectionFailure
lengthSelectionFailure result = case result of
  LengthSelectionPreserved _ failure -> Just failure
  LengthSelectionAccepted {} -> Nothing

-- | Run the complete current live-capable scalar assessment pipeline, then
-- reject only candidates carrying independently replayed counterexamples.
-- A raw solver status, including @sat@, @unsat@ or @unknown@, never rejects.
-- Any operational or association failure atomically preserves the supplied
-- verification batch.
selectVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSelectionResult
selectVerifiedLengthCandidatesWithPolicy policy contract verification = do
  selectVerifiedLengthCandidatesWithAssessment
    (assessVerifiedLengthCandidatesWithPolicy policy contract) verification

-- | 'selectVerifiedLengthCandidatesWithPolicy' whose assessment pipeline
-- replays and records counterexamples through the supplied command-owned
-- scalar bank context instead of a batch-local bank.  Selection semantics
-- are otherwise identical: only an independently replayed counterexample
-- rejects, and every failure preserves the supplied batch.
selectVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  :: LengthRankingPolicy
  -> CounterexampleBank.LengthCounterexampleBankContext
      command ExferenceLocal
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSelectionResult
selectVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
    policy context contract =
  selectVerifiedLengthCandidatesWithAssessment
    $ assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
        policy context contract

selectVerifiedLengthCandidatesWithAssessment
  :: (VerificationBatch DetailedVerificationVariant
      -> IO LengthPostVerificationResult)
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSelectionResult
selectVerifiedLengthCandidatesWithAssessment assess verification = do
  assessed <- assess verification
  pure $ case lengthPostVerificationAdapterFailure assessed of
    Just failure -> preserve
      $ LengthSelectionPostVerificationFailed failure
    Nothing -> case lengthPostVerificationRankingFailure assessed of
      Just failure -> preserve $ LengthSelectionRankingFailed failure
      Nothing -> case lengthPostVerificationRanking assessed of
        Nothing -> preserve LengthSelectionRankingUnavailable
        Just ranking -> withBehavioralSelectionInput verification $ \input ->
          let candidates = behavioralSelectionInputCandidates input
              candidateCount = count candidates
          in case buildDecisions candidateCount candidates
              $ lengthRankingCandidates ranking of
            Left failure -> preserve failure
            Right decisions -> case sealBehavioralSelectionBatch
                defaultLengthSMTLibLiveSessionMaximumQueries
                input decisions of
              Left failure -> preserve $ LengthSelectionSealFailed failure
              Right batch -> LengthSelectionAccepted batch
 where
  preserve = LengthSelectionPreserved verification

buildDecisions
  :: Natural
  -> [BehavioralSelectionCandidate
        epoch DetailedVerificationVariant]
  -> [RankedLengthCandidate]
  -> Either
      LengthSelectionFailure
      [BehavioralSelectionDecision
        epoch
        DetailedVerificationVariant
        LengthSelectionRetention
        LengthSelectionRejection]
buildDecisions candidateCount candidates = go []
 where
  go reversed remaining = case remaining of
    [] -> Right $ reverse reversed
    ranked : rest -> do
      candidate <- selectCandidate candidateCount candidates
        $ rankedLengthCandidateOriginalIndex ranked
      let decision = classifyCandidate candidate ranked
      decision `seq` go (decision : reversed) rest

classifyCandidate
  :: BehavioralSelectionCandidate epoch DetailedVerificationVariant
  -> RankedLengthCandidate
  -> BehavioralSelectionDecision
      epoch
      DetailedVerificationVariant
      LengthSelectionRetention
      LengthSelectionRejection
classifyCandidate candidate ranked =
  case rankedLengthCandidatePreparationRefusal ranked of
    Just refusal -> retainBehavioralSelectionCandidate candidate
      $ LengthSelectionRetainedPreparationRefusal refusal
    Nothing -> case rankedLengthCandidateAssessment ranked of
      Unassessed -> retainBehavioralSelectionCandidate candidate
        LengthSelectionRetainedUnassessed
      Heuristic status -> retainBehavioralSelectionCandidate candidate
        $ LengthSelectionRetainedHeuristic status
      Counterexample receipt -> rejectBehavioralSelectionCandidate candidate
        $ LengthSelectionRejection receipt
        $ rankedLengthCandidateCounterexampleSimplification ranked
      BoundedPositive receipt -> retainBehavioralSelectionCandidate candidate
        $ LengthSelectionRetainedBoundedPositive receipt
      ApplicableDomainEstablished receipt ->
        retainBehavioralSelectionCandidate candidate
          $ LengthSelectionRetainedApplicableDomainEstablished receipt

selectCandidate
  :: Natural
  -> [BehavioralSelectionCandidate
        epoch DetailedVerificationVariant]
  -> Natural
  -> Either
      LengthSelectionFailure
      (BehavioralSelectionCandidate epoch DetailedVerificationVariant)
selectCandidate candidateCount = go 0
 where
  go _ [] requested = Left $ LengthSelectionCandidateIndexOutOfRange
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
