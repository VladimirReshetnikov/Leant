-- | Opt-in hard filtering for canonical binary-product finite-spine Length
-- behavior.  This is a nominal sibling of scalar Length selection: only a
-- freshly replayed pair counterexample can reject a verified occurrence, and
-- every failure preserves the complete original callback batch.
module Leant.Synth.Length.SpinePair.Selection
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
  ) where

import Leant.Synth.Length.SpinePair.Selection.Internal
  ( LengthSpinePairSelectionFailure (..)
  , LengthSpinePairSelectionRejection
  , LengthSpinePairSelectionResult
  , LengthSpinePairSelectionRetention
  , LengthSpinePairSelectionRetentionClass (..)
  , lengthSpinePairSelectionCandidates
  , lengthSpinePairSelectionFailure
  , lengthSpinePairSelectionRejected
  , lengthSpinePairSelectionRejectionCounterexample
  , lengthSpinePairSelectionRejectionCounterexampleSimplification
  , lengthSpinePairSelectionRetentionApplicableDomain
  , lengthSpinePairSelectionRetentionClass
  , lengthSpinePairSelectionRetentionInputBox
  , lengthSpinePairSelectionRetentionPreparationRefusal
  , lengthSpinePairSelectionRetentionSolverStatus
  , lengthSpinePairSelectionSelected
  , selectVerifiedLengthSpinePairCandidatesWithPolicy
  )
