{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Package-private construction surface for the behavioral-selection seal.
--
-- The public facade deliberately withholds the two decision builders. A
-- domain adapter may classify one exact callback-verified occurrence only
-- after it has established the domain-specific authority carried by the
-- retention or rejection payload.
module Leant.Synth.BehavioralSelection.Internal
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
  , retainBehavioralSelectionCandidate
  , rejectBehavioralSelectionCandidate
  , behaviorallySelectedVerified
  , behaviorallySelectedRetention
  , behaviorallyRejectedVerified
  , behaviorallyRejectedReason
  , behavioralSelectionBatchSelected
  , behavioralSelectionBatchRejected
  , sealBehavioralSelectionBatch
  ) where

import Data.List (sortOn)
import qualified Data.Set as Set
import Numeric.Natural (Natural)

import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

-- | Which of the two bounded lists a collection limit refusal names: the
-- exact callback candidates or an adapter's proposed decisions.
data BehavioralSelectionCollection
  = BehavioralSelectionCandidates
  | BehavioralSelectionDecisions
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Why a proposed partition was not sealed, in check order: a collection
-- exceeded the caller's maximum (maximum and observed count capped at
-- maximum plus one), the decision count differs from the candidate count
-- (candidate count, decision count), a decision's index is out of range
-- (candidate count, index), or an index was decided twice.
data BehavioralSelectionError
  = BehavioralSelectionCollectionLimitExceeded
      !BehavioralSelectionCollection !Natural !Natural
  | BehavioralSelectionDecisionLengthMismatch !Natural !Natural
  | BehavioralSelectionDecisionIndexOutOfRange !Natural !Natural
  | BehavioralSelectionDecisionDuplicateIndex !Natural
  deriving (Eq, Ord, Show)

-- | One exact verified occurrence under a fresh generative epoch. Equal
-- candidate payloads remain different occurrences because the private index,
-- rather than payload equality, is the selection identity.
data BehavioralSelectionCandidate epoch candidate =
  BehavioralSelectionCandidate !Natural !(Verified candidate)

type role BehavioralSelectionCandidate nominal nominal

-- | One callback batch scoped by a fresh abstract epoch.
data BehavioralSelectionInput epoch candidate = BehavioralSelectionInput
  [BehavioralSelectionCandidate epoch candidate]

type role BehavioralSelectionInput nominal nominal

data BehavioralSelectionChoice retained rejection
  = BehavioralSelectionRetain retained
  | BehavioralSelectionReject rejection

type role BehavioralSelectionChoice nominal nominal

-- | One total classification proposal for one exact occurrence. The
-- constructor and the two builders remain package-private.
data BehavioralSelectionDecision epoch candidate retained rejection =
  BehavioralSelectionDecision
    !(BehavioralSelectionCandidate epoch candidate)
    (BehavioralSelectionChoice retained rejection)

type role BehavioralSelectionDecision nominal nominal nominal nominal

-- | One retained callback-verified occurrence and its domain retention
-- explanation. This receipt attests only selection association, not behavior.
data BehaviorallySelected candidate retained = BehaviorallySelected
  !(Verified candidate) retained

type role BehaviorallySelected nominal nominal

-- | One rejected callback-verified occurrence and its domain rejection
-- evidence. This generic wrapper does not itself validate that evidence.
data BehaviorallyRejected candidate rejection = BehaviorallyRejected
  !(Verified candidate) rejection

type role BehaviorallyRejected nominal nominal

-- | A bounded total partition of one callback batch. Both partitions are in
-- original callback order, independent of proposal order.
data BehavioralSelectionBatch candidate retained rejection =
  BehavioralSelectionBatch
    [BehaviorallySelected candidate retained]
    [BehaviorallyRejected candidate rejection]

type role BehavioralSelectionBatch nominal nominal nominal

-- | Introduce one fresh batch scope.  The rank-2 epoch prevents handles from
-- another invocation from being supplied to this input's seal without an
-- explicit unsafe operation.
withBehavioralSelectionInput
  :: VerificationBatch candidate
  -> (forall epoch. BehavioralSelectionInput epoch candidate -> result)
  -> result
withBehavioralSelectionInput verification action =
  action $ BehavioralSelectionInput
    $ zipWith BehavioralSelectionCandidate [0 ..]
    $ verifiedCandidateReceipts verification

-- | The batch's occurrence handles in original callback order; the only
-- source of handles an adapter may classify for
-- 'sealBehavioralSelectionBatch'.
behavioralSelectionInputCandidates
  :: BehavioralSelectionInput epoch candidate
  -> [BehavioralSelectionCandidate epoch candidate]
behavioralSelectionInputCandidates (BehavioralSelectionInput candidates) =
  candidates

-- | The opaque verified receipt behind one occurrence handle.
behavioralSelectionCandidateVerified
  :: BehavioralSelectionCandidate epoch candidate
  -> Verified candidate
behavioralSelectionCandidateVerified
    (BehavioralSelectionCandidate _ verified) = verified

-- | Propose that one exact occurrence be retained with the supplied domain
-- retention explanation.  Package-private: the payload's authority is the
-- adapter's responsibility, not this builder's.
retainBehavioralSelectionCandidate
  :: BehavioralSelectionCandidate epoch candidate
  -> retained
  -> BehavioralSelectionDecision epoch candidate retained rejection
retainBehavioralSelectionCandidate candidate retained =
  BehavioralSelectionDecision candidate $ BehavioralSelectionRetain retained

-- | Propose that one exact occurrence be rejected with the supplied domain
-- rejection evidence.  Package-private: the payload's authority is the
-- adapter's responsibility, not this builder's.
rejectBehavioralSelectionCandidate
  :: BehavioralSelectionCandidate epoch candidate
  -> rejection
  -> BehavioralSelectionDecision epoch candidate retained rejection
rejectBehavioralSelectionCandidate candidate rejection =
  BehavioralSelectionDecision candidate $ BehavioralSelectionReject rejection

-- | The opaque verified receipt of one selected occurrence.
behaviorallySelectedVerified
  :: BehaviorallySelected candidate retained
  -> Verified candidate
behaviorallySelectedVerified (BehaviorallySelected verified _) = verified

-- | The domain retention explanation attached to one selected occurrence.
behaviorallySelectedRetention
  :: BehaviorallySelected candidate retained
  -> retained
behaviorallySelectedRetention (BehaviorallySelected _ retained) = retained

-- | The opaque verified receipt of one rejected occurrence.
behaviorallyRejectedVerified
  :: BehaviorallyRejected candidate rejection
  -> Verified candidate
behaviorallyRejectedVerified (BehaviorallyRejected verified _) = verified

-- | The domain rejection evidence attached to one rejected occurrence.
behaviorallyRejectedReason
  :: BehaviorallyRejected candidate rejection
  -> rejection
behaviorallyRejectedReason (BehaviorallyRejected _ rejection) = rejection

-- | The sealed selected partition in original callback order.
behavioralSelectionBatchSelected
  :: BehavioralSelectionBatch candidate retained rejection
  -> [BehaviorallySelected candidate retained]
behavioralSelectionBatchSelected
    (BehavioralSelectionBatch selected _) = selected

-- | The sealed rejected partition in original callback order.
behavioralSelectionBatchRejected
  :: BehavioralSelectionBatch candidate retained rejection
  -> [BehaviorallyRejected candidate rejection]
behavioralSelectionBatchRejected
    (BehavioralSelectionBatch _ rejected) = rejected

-- | Seal one bounded total partition of the supplied callback receipts.
--
-- Candidate admission precedes decision admission. Length equality precedes
-- index validation; each decision index is checked for range and duplication.
-- Only after those spine/index checks does the seal associate payloads with
-- the original verified receipts and canonicalize both partitions by original
-- callback index. Counts stop at the caller's maximum plus one, including a
-- cyclic decision spine.
sealBehavioralSelectionBatch
  :: Natural
  -> BehavioralSelectionInput epoch candidate
  -> [BehavioralSelectionDecision epoch candidate retained rejection]
  -> Either
      BehavioralSelectionError
      (BehavioralSelectionBatch candidate retained rejection)
sealBehavioralSelectionBatch maximumCandidates input decisions = do
  candidates <- admitCollection BehavioralSelectionCandidates
    maximumCandidates $ behavioralSelectionInputCandidates input
  admittedDecisions <- admitCollection BehavioralSelectionDecisions
    maximumCandidates decisions
  let candidateCount = count candidates
      decisionCount = count admittedDecisions
  if decisionCount == candidateCount
    then pure ()
    else Left $ BehavioralSelectionDecisionLengthMismatch
      candidateCount decisionCount
  indexed <- validateDecisions candidateCount Set.empty [] admittedDecisions
  materialize candidates [] [] $ sortOn fst indexed

admitCollection
  :: BehavioralSelectionCollection
  -> Natural
  -> [value]
  -> Either BehavioralSelectionError [value]
admitCollection collection maximumValues = go 0 []
 where
  go !observed reversed remaining
    | observed >= maximumValues = case remaining of
        [] -> Right $ reverse reversed
        _ : _ -> Left $ BehavioralSelectionCollectionLimitExceeded
          collection maximumValues (maximumValues + 1)
    | otherwise = case remaining of
        [] -> Right $ reverse reversed
        value : rest -> go (observed + 1) (value : reversed) rest

validateDecisions
  :: Natural
  -> Set.Set Natural
  -> [(Natural, BehavioralSelectionChoice retained rejection)]
  -> [BehavioralSelectionDecision epoch candidate retained rejection]
  -> Either
      BehavioralSelectionError
      [(Natural, BehavioralSelectionChoice retained rejection)]
validateDecisions candidateCount = go
 where
  go _ reversed [] = Right $ reverse reversed
  go seen reversed
      ( BehavioralSelectionDecision
          (BehavioralSelectionCandidate index _) choice
        : remaining
      )
    | index >= candidateCount = Left
        $ BehavioralSelectionDecisionIndexOutOfRange candidateCount index
    | Set.member index seen = Left
        $ BehavioralSelectionDecisionDuplicateIndex index
    | otherwise = go (Set.insert index seen)
        ((index, choice) : reversed) remaining

materialize
  :: [BehavioralSelectionCandidate epoch candidate]
  -> [BehaviorallySelected candidate retained]
  -> [BehaviorallyRejected candidate rejection]
  -> [(Natural, BehavioralSelectionChoice retained rejection)]
  -> Either
      BehavioralSelectionError
      (BehavioralSelectionBatch candidate retained rejection)
materialize candidates = go
 where
  go selected rejected [] = Right $ BehavioralSelectionBatch
    (reverse selected) (reverse rejected)
  go selected rejected ((index, choice) : remaining) = do
    expected <- selectCandidate candidates index
    let verified = behavioralSelectionCandidateVerified expected
    case choice of
      BehavioralSelectionRetain retained ->
        go (BehaviorallySelected verified retained : selected)
          rejected remaining
      BehavioralSelectionReject rejection ->
        go selected (BehaviorallyRejected verified rejection : rejected)
          remaining

selectCandidate
  :: [BehavioralSelectionCandidate epoch candidate]
  -> Natural
  -> Either
      BehavioralSelectionError
      (BehavioralSelectionCandidate epoch candidate)
selectCandidate candidates requested = go 0 candidates
 where
  go _ [] = Left $ BehavioralSelectionDecisionIndexOutOfRange
    (count candidates) requested
  go !index (candidate : remaining)
    | index == requested = Right candidate
    | otherwise = go (index + 1) remaining

count :: [value] -> Natural
count = go 0
 where
  go !result [] = result
  go !result (_ : remaining) = go (result + 1) remaining
