-- | Validated hard-selection boundary after callback verification.
--
-- A selection batch is a bounded total partition of the exact opaque
-- 'Verified' receipts supplied to a fresh rank-2 epoch. The seal checks only
-- occurrence membership, totality, and original-order association. It does
-- not establish candidate behavior, trust solver status, or create proof
-- authority. Domain adapters keep the retain/reject builders private and must
-- supply their own evidence policy.
module Leant.Synth.BehavioralSelection
  ( BehavioralSelectionCollection (..)
  , BehavioralSelectionError (..)
  , BehavioralSelectionInput
  , BehavioralSelectionCandidate
  , BehavioralSelectionDecision
  , BehaviorallySelected
  , BehaviorallyRejected
  , BehavioralSelectionBatch
  , withBehavioralSelectionInput
  , behavioralSelectionInputCandidates
  , behavioralSelectionCandidateVerified
  , behaviorallySelectedVerified
  , behaviorallySelectedRetention
  , behaviorallyRejectedVerified
  , behaviorallyRejectedReason
  , behavioralSelectionBatchSelected
  , behavioralSelectionBatchRejected
  , sealBehavioralSelectionBatch
  ) where

import Leant.Synth.BehavioralSelection.Internal
  ( BehavioralSelectionBatch
  , BehavioralSelectionCandidate
  , BehavioralSelectionCollection (..)
  , BehavioralSelectionDecision
  , BehavioralSelectionError (..)
  , BehavioralSelectionInput
  , BehaviorallyRejected
  , BehaviorallySelected
  , behavioralSelectionBatchRejected
  , behavioralSelectionBatchSelected
  , behavioralSelectionCandidateVerified
  , behavioralSelectionInputCandidates
  , behaviorallyRejectedReason
  , behaviorallyRejectedVerified
  , behaviorallySelectedRetention
  , behaviorallySelectedVerified
  , sealBehavioralSelectionBatch
  , withBehavioralSelectionInput
  )
