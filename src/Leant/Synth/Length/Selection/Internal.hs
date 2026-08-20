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
  )

import Leant.Synth.BehavioralSelection.Internal
  ( BehavioralSelectionError
  , BehaviorallyRejected
  , BehaviorallySelected
  )
import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , assessVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthCandidatesWithPolicyAndCounterexampleBankContext
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import qualified Leant.Synth.Length.Selection.Generic as Generic
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
import Leant.Synth.Verification (VerificationBatch, Verified)

-- | Closed reason class for a candidate which the hard filter retained.
-- None of these cases is negative behavioral evidence.
data LengthSelectionRetentionClass
  = LengthSelectionPreparationRefused
  | LengthSelectionUnassessed
  | LengthSelectionHeuristic
  | LengthSelectionBoundedPositive
  | LengthSelectionApplicableDomainEstablished
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Domain-specific retention explanation.  It is the shared explanation at
-- the scalar receipts, so it cannot be confused with a binary-product one,
-- and its constructors stay private to this module and its facade.
type LengthSelectionRetention =
  Generic.SelectionRetention
    ValidatedLengthInputBox
    ValidatedLengthApplicableDomain

-- | The closed reason class of a retention explanation.  At most one of the
-- payload projections below returns 'Just' for a given explanation, and none
-- does for 'LengthSelectionUnassessed'.
lengthSelectionRetentionClass
  :: LengthSelectionRetention
  -> LengthSelectionRetentionClass
lengthSelectionRetentionClass retention = case retention of
  Generic.RetainedPreparationRefusal _ ->
    LengthSelectionPreparationRefused
  Generic.RetainedUnassessed -> LengthSelectionUnassessed
  Generic.RetainedHeuristic _ -> LengthSelectionHeuristic
  Generic.RetainedBoundedPositive _ -> LengthSelectionBoundedPositive
  Generic.RetainedApplicableDomainEstablished _ ->
    LengthSelectionApplicableDomainEstablished

-- | The diagnostic of a 'LengthSelectionPreparationRefused' retention.
lengthSelectionRetentionPreparationRefusal
  :: LengthSelectionRetention
  -> Maybe LengthPreparationRefusalClass
lengthSelectionRetentionPreparationRefusal =
  Generic.selectionRetentionPreparationRefusal

-- | The raw status of a 'LengthSelectionHeuristic' retention, which is a
-- diagnostic and never negative behavioral evidence.
lengthSelectionRetentionSolverStatus
  :: LengthSelectionRetention
  -> Maybe SolverStatus
lengthSelectionRetentionSolverStatus =
  Generic.selectionRetentionSolverStatus

-- | The receipt of a 'LengthSelectionBoundedPositive' retention.
lengthSelectionRetentionInputBox
  :: LengthSelectionRetention
  -> Maybe ValidatedLengthInputBox
lengthSelectionRetentionInputBox = Generic.selectionRetentionInputBox

-- | The receipt of a 'LengthSelectionApplicableDomainEstablished' retention.
lengthSelectionRetentionApplicableDomain
  :: LengthSelectionRetention
  -> Maybe ValidatedLengthApplicableDomain
lengthSelectionRetentionApplicableDomain =
  Generic.selectionRetentionApplicableDomain

-- | Exact scalar replay authority for one rejected occurrence.  The shared
-- rejection at the scalar receipts is a distinct type from the
-- binary-product one, so the two cannot be confused.  Simplification is
-- optional metadata; the ordinary receipt is always the final independently
-- replayed counterexample.
type LengthSelectionRejection =
  Generic.SelectionRejection
    ValidatedLengthCounterexample
    ValidatedLengthCounterexampleSimplification

-- | The scalar counterexample which rejected the occurrence.
lengthSelectionRejectionCounterexample
  :: LengthSelectionRejection
  -> ValidatedLengthCounterexample
lengthSelectionRejectionCounterexample =
  Generic.selectionRejectionCounterexample

-- | The optional simplification carried by the rejecting candidate.
lengthSelectionRejectionCounterexampleSimplification
  :: LengthSelectionRejection
  -> Maybe ValidatedLengthCounterexampleSimplification
lengthSelectionRejectionCounterexampleSimplification =
  Generic.selectionRejectionSimplification

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
-- sealed total partition.  The shared result at this domain's explanation and
-- rejection types; its constructors stay private, so a caller cannot present
-- an unsealed partition as accepted selection authority.
type LengthSelectionResult =
  Generic.SelectionResult
    LengthSelectionFailure
    LengthSelectionRetention
    LengthSelectionRejection

-- | Effective candidates after selection: the original batch on failure, the
-- selected partition on success, both in original callback order.
lengthSelectionCandidates
  :: LengthSelectionResult
  -> [Verified DetailedVerificationVariant]
lengthSelectionCandidates = Generic.selectionCandidates

-- | Selected occurrences, available only after the partition seal succeeded.
lengthSelectionSelected
  :: LengthSelectionResult
  -> Maybe
      [BehaviorallySelected
        DetailedVerificationVariant LengthSelectionRetention]
lengthSelectionSelected = Generic.selectionSelected

-- | Rejected occurrences, available only after the partition seal succeeded.
lengthSelectionRejected
  :: LengthSelectionResult
  -> Maybe
      [BehaviorallyRejected
        DetailedVerificationVariant LengthSelectionRejection]
lengthSelectionRejected = Generic.selectionRejected

-- | The sanitized failure which preserved the original batch.
lengthSelectionFailure
  :: LengthSelectionResult
  -> Maybe LengthSelectionFailure
lengthSelectionFailure = Generic.selectionFailure

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
selectVerifiedLengthCandidatesWithAssessment =
  Generic.runSelectionWithAssessment scalarSelectionDomain

-- | What the scalar domain contributes to the shared selection pipeline: how
-- to read its assessed batch, how it names each fail-closed reason, and which
-- assessment rejects.  Only an independently replayed counterexample does.
scalarSelectionDomain
  :: Generic.SelectionDomain
      LengthPostVerificationResult
      RankedLengthCandidate
      LengthSelectionFailure
      LengthSelectionRetention
      LengthSelectionRejection
scalarSelectionDomain = Generic.SelectionDomain
  { Generic.selectionAdapterFailure = fmap LengthSelectionPostVerificationFailed
      . lengthPostVerificationAdapterFailure
  , Generic.selectionRankingFailure = fmap LengthSelectionRankingFailed
      . lengthPostVerificationRankingFailure
  , Generic.selectionRanking =
      fmap lengthRankingCandidates . lengthPostVerificationRanking
  , Generic.selectionRankingUnavailable = LengthSelectionRankingUnavailable
  , Generic.selectionIndexOutOfRange = LengthSelectionCandidateIndexOutOfRange
  , Generic.selectionSealFailed = LengthSelectionSealFailed
  , Generic.selectionOriginalIndex = rankedLengthCandidateOriginalIndex
  , Generic.selectionClassify = classifyCandidate
  }

-- | The scalar reading of one ranked report: 'Left' only for an exact
-- independently replayed counterexample, 'Right' with the explanation for
-- every other assessment.
classifyCandidate
  :: RankedLengthCandidate
  -> Either LengthSelectionRejection LengthSelectionRetention
classifyCandidate ranked =
  case rankedLengthCandidatePreparationRefusal ranked of
    Just refusal -> Right $ Generic.RetainedPreparationRefusal refusal
    Nothing -> case rankedLengthCandidateAssessment ranked of
      Unassessed -> Right Generic.RetainedUnassessed
      Heuristic status -> Right $ Generic.RetainedHeuristic status
      Counterexample receipt -> Left
        $ Generic.SelectionRejection receipt
        $ rankedLengthCandidateCounterexampleSimplification ranked
      BoundedPositive receipt ->
        Right $ Generic.RetainedBoundedPositive receipt
      ApplicableDomainEstablished receipt ->
        Right $ Generic.RetainedApplicableDomainEstablished receipt
