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
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( SolverStatus
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
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure
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

lengthSelectionRetentionPreparationRefusal
  :: LengthSelectionRetention
  -> Maybe LengthPreparationRefusalClass
lengthSelectionRetentionPreparationRefusal retention = case retention of
  LengthSelectionRetainedPreparationRefusal refusal -> Just refusal
  _ -> Nothing

lengthSelectionRetentionSolverStatus
  :: LengthSelectionRetention
  -> Maybe SolverStatus
lengthSelectionRetentionSolverStatus retention = case retention of
  LengthSelectionRetainedHeuristic status -> Just status
  _ -> Nothing

lengthSelectionRetentionInputBox
  :: LengthSelectionRetention
  -> Maybe ValidatedLengthInputBox
lengthSelectionRetentionInputBox retention = case retention of
  LengthSelectionRetainedBoundedPositive receipt -> Just receipt
  _ -> Nothing

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

lengthSelectionRejectionCounterexample
  :: LengthSelectionRejection
  -> ValidatedLengthCounterexample
lengthSelectionRejectionCounterexample
    (LengthSelectionRejection receipt _) = receipt

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
  assessed <- assessVerifiedLengthCandidatesWithPolicy
    policy contract verification
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
