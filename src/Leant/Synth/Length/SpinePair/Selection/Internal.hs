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
  )

import Leant.Synth.BehavioralSelection.Internal
  ( BehavioralSelectionError
  , BehaviorallyRejected
  , BehaviorallySelected
  )
import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicyAndCounterexampleBankContext
  )
import Leant.Synth.Length.Contract (LeanLengthSpinePairContract)
import qualified Leant.Synth.Length.Selection.Generic as Generic
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
import Leant.Synth.Verification (VerificationBatch, Verified)

-- | Closed pair-domain reason class for a retained candidate.
data LengthSpinePairSelectionRetentionClass
  = LengthSpinePairSelectionPreparationRefused
  | LengthSpinePairSelectionUnassessed
  | LengthSpinePairSelectionHeuristic
  | LengthSpinePairSelectionBoundedPositive
  | LengthSpinePairSelectionApplicableDomainEstablished
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Exact pair-domain retention explanation.  It is the shared explanation
-- at the binary-product receipts, so it cannot be confused with a scalar one,
-- and its constructors stay private to this module and its facade.
type LengthSpinePairSelectionRetention =
  Generic.SelectionRetention
    ValidatedLengthSpinePairInputBox
    ValidatedLengthSpinePairApplicableDomain

-- | The closed reason class of a pair-domain retention explanation.  At most
-- one of the payload projections below returns 'Just' for a given
-- explanation, and none does for 'LengthSpinePairSelectionUnassessed'.
lengthSpinePairSelectionRetentionClass
  :: LengthSpinePairSelectionRetention
  -> LengthSpinePairSelectionRetentionClass
lengthSpinePairSelectionRetentionClass retention = case retention of
  Generic.RetainedPreparationRefusal _ ->
    LengthSpinePairSelectionPreparationRefused
  Generic.RetainedUnassessed -> LengthSpinePairSelectionUnassessed
  Generic.RetainedHeuristic _ -> LengthSpinePairSelectionHeuristic
  Generic.RetainedBoundedPositive _ ->
    LengthSpinePairSelectionBoundedPositive
  Generic.RetainedApplicableDomainEstablished _ ->
    LengthSpinePairSelectionApplicableDomainEstablished

-- | The diagnostic of a 'LengthSpinePairSelectionPreparationRefused'
-- retention.
lengthSpinePairSelectionRetentionPreparationRefusal
  :: LengthSpinePairSelectionRetention
  -> Maybe LengthPreparationRefusalClass
lengthSpinePairSelectionRetentionPreparationRefusal =
  Generic.selectionRetentionPreparationRefusal

-- | The raw status of a 'LengthSpinePairSelectionHeuristic' retention, which
-- is a diagnostic and never negative behavioral evidence.
lengthSpinePairSelectionRetentionSolverStatus
  :: LengthSpinePairSelectionRetention
  -> Maybe SolverStatus
lengthSpinePairSelectionRetentionSolverStatus =
  Generic.selectionRetentionSolverStatus

-- | The receipt of a 'LengthSpinePairSelectionBoundedPositive' retention.
lengthSpinePairSelectionRetentionInputBox
  :: LengthSpinePairSelectionRetention
  -> Maybe ValidatedLengthSpinePairInputBox
lengthSpinePairSelectionRetentionInputBox =
  Generic.selectionRetentionInputBox

-- | The receipt of a
-- 'LengthSpinePairSelectionApplicableDomainEstablished' retention.
lengthSpinePairSelectionRetentionApplicableDomain
  :: LengthSpinePairSelectionRetention
  -> Maybe ValidatedLengthSpinePairApplicableDomain
lengthSpinePairSelectionRetentionApplicableDomain =
  Generic.selectionRetentionApplicableDomain

-- | Exact pair replay authority for one rejected occurrence.  The shared
-- rejection at the binary-product receipts is a distinct type from the
-- scalar one, so the two cannot be confused.  Simplification is optional
-- metadata; the ordinary receipt is always the final independently replayed
-- counterexample.
type LengthSpinePairSelectionRejection =
  Generic.SelectionRejection
    ValidatedLengthSpinePairCounterexample
    ValidatedLengthSpinePairCounterexampleSimplification

-- | The pair counterexample which rejected the occurrence.
lengthSpinePairSelectionRejectionCounterexample
  :: LengthSpinePairSelectionRejection
  -> ValidatedLengthSpinePairCounterexample
lengthSpinePairSelectionRejectionCounterexample =
  Generic.selectionRejectionCounterexample

-- | The optional simplification carried by the rejecting pair candidate.
lengthSpinePairSelectionRejectionCounterexampleSimplification
  :: LengthSpinePairSelectionRejection
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
lengthSpinePairSelectionRejectionCounterexampleSimplification =
  Generic.selectionRejectionSimplification

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

-- | Opaque preserve-all failure or sealed pair-domain partition: the shared
-- result at this domain's explanation and rejection types.
type LengthSpinePairSelectionResult =
  Generic.SelectionResult
    LengthSpinePairSelectionFailure
    LengthSpinePairSelectionRetention
    LengthSpinePairSelectionRejection

-- | Effective candidates in original callback order: the original batch on
-- failure, the selected partition on success.
lengthSpinePairSelectionCandidates
  :: LengthSpinePairSelectionResult
  -> [Verified DetailedVerificationVariant]
lengthSpinePairSelectionCandidates = Generic.selectionCandidates

-- | Selected pair occurrences, available only after the seal succeeded.
lengthSpinePairSelectionSelected
  :: LengthSpinePairSelectionResult
  -> Maybe
      [BehaviorallySelected
        DetailedVerificationVariant LengthSpinePairSelectionRetention]
lengthSpinePairSelectionSelected = Generic.selectionSelected

-- | Rejected pair occurrences, available only after the seal succeeded.
lengthSpinePairSelectionRejected
  :: LengthSpinePairSelectionResult
  -> Maybe
      [BehaviorallyRejected
        DetailedVerificationVariant LengthSpinePairSelectionRejection]
lengthSpinePairSelectionRejected = Generic.selectionRejected

-- | The sanitized failure which preserved the original batch.
lengthSpinePairSelectionFailure
  :: LengthSpinePairSelectionResult
  -> Maybe LengthSpinePairSelectionFailure
lengthSpinePairSelectionFailure = Generic.selectionFailure

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
selectVerifiedLengthSpinePairCandidatesWithAssessment =
  Generic.runSelectionWithAssessment spinePairSelectionDomain

-- | What the binary-product domain contributes to the shared selection
-- pipeline: how to read its assessed batch, how it names each fail-closed
-- reason, and which assessment rejects.  Only an independently replayed pair
-- counterexample does.
spinePairSelectionDomain
  :: Generic.SelectionDomain
      LengthSpinePairPostVerificationResult
      RankedLengthSpinePairCandidate
      LengthSpinePairSelectionFailure
      LengthSpinePairSelectionRetention
      LengthSpinePairSelectionRejection
spinePairSelectionDomain = Generic.SelectionDomain
  { Generic.selectionAdapterFailure =
      fmap LengthSpinePairSelectionPostVerificationFailed
        . lengthSpinePairPostVerificationAdapterFailure
  , Generic.selectionRankingFailure =
      fmap LengthSpinePairSelectionRankingFailed
        . lengthSpinePairPostVerificationRankingFailure
  , Generic.selectionRanking = fmap lengthSpinePairRankingCandidates
      . lengthSpinePairPostVerificationRanking
  , Generic.selectionRankingUnavailable =
      LengthSpinePairSelectionRankingUnavailable
  , Generic.selectionIndexOutOfRange =
      LengthSpinePairSelectionCandidateIndexOutOfRange
  , Generic.selectionSealFailed = LengthSpinePairSelectionSealFailed
  , Generic.selectionOriginalIndex =
      rankedLengthSpinePairCandidateOriginalIndex
  , Generic.selectionClassify = classifyCandidate
  }

-- | The pair reading of one ranked report: 'Left' only for an exact
-- independently replayed pair counterexample, 'Right' with the explanation
-- for every other assessment.
classifyCandidate
  :: RankedLengthSpinePairCandidate
  -> Either
      LengthSpinePairSelectionRejection
      LengthSpinePairSelectionRetention
classifyCandidate ranked =
  case rankedLengthSpinePairCandidatePreparationRefusal ranked of
    Just refusal -> Right $ Generic.RetainedPreparationRefusal refusal
    Nothing -> case rankedLengthSpinePairCandidateAssessment ranked of
      LengthSpinePairUnassessed -> Right Generic.RetainedUnassessed
      LengthSpinePairHeuristic status ->
        Right $ Generic.RetainedHeuristic status
      LengthSpinePairCounterexample receipt -> Left
        $ Generic.SelectionRejection receipt
        $ rankedLengthSpinePairCandidateCounterexampleSimplification ranked
      LengthSpinePairBoundedPositive receipt ->
        Right $ Generic.RetainedBoundedPositive receipt
      LengthSpinePairApplicableDomainEstablished receipt ->
        Right $ Generic.RetainedApplicableDomainEstablished receipt
