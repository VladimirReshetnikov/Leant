-- | Opt-in hard filtering for scalar finite-spine Length behavior.
--
-- Only a counterexample independently replayed by the existing Length
-- assessment pipeline can reject a callback-verified candidate.  All raw
-- solver statuses, positive bounded receipts, applicable-domain receipts,
-- preparation refusals and unassessed candidates are retained explicitly.
-- Every operational or sealing failure preserves the complete original
-- callback batch.
module Leant.Synth.Length.Selection
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

import Leant.Synth.Length.Selection.Internal
  ( LengthSelectionFailure (..)
  , LengthSelectionRejection
  , LengthSelectionResult
  , LengthSelectionRetention
  , LengthSelectionRetentionClass (..)
  , lengthSelectionCandidates
  , lengthSelectionFailure
  , lengthSelectionRejected
  , lengthSelectionRejectionCounterexample
  , lengthSelectionRejectionCounterexampleSimplification
  , lengthSelectionRetentionApplicableDomain
  , lengthSelectionRetentionClass
  , lengthSelectionRetentionInputBox
  , lengthSelectionRetentionPreparationRefusal
  , lengthSelectionRetentionSolverStatus
  , lengthSelectionSelected
  , selectVerifiedLengthCandidatesWithPolicy
  )
