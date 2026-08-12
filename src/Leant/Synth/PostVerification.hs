{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Validated ordering boundary after callback verification.
--
-- Behavioral assessors may propose only a permutation of the exact opaque
-- 'Verified' receipts supplied to the seal.  This module productively bounds
-- both lists and rejects omission, duplication, or reassociation before
-- sealing the reordered batch.  The disabled path stays a transparent raw
-- list so it cannot masquerade as validated ordering authority.
module Leant.Synth.PostVerification
  ( PostVerificationCollection (..)
  , PostVerificationError (..)
  , PostVerificationInput
  , PostVerificationCandidate
  , withPostVerificationInput
  , postVerificationInputCandidates
  , postVerificationCandidateVerified
  , PostVerificationBatch
  , postVerificationBatchCandidates
  , skipPostVerificationAssessment
  , sealPostVerificationBatch
  ) where

import qualified Data.Set as Set
import Numeric.Natural (Natural)

import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

data PostVerificationCollection
  = PostVerificationCandidates
  | PostVerificationProposals
  deriving (Bounded, Enum, Eq, Ord, Show)

data PostVerificationError
  = PostVerificationCollectionLimitExceeded
      !PostVerificationCollection !Natural !Natural
  | PostVerificationProposalLengthMismatch !Natural !Natural
  | PostVerificationProposalIndexOutOfRange !Natural !Natural
  | PostVerificationProposalDuplicateIndex !Natural
  deriving (Eq, Ord, Show)

-- | One occurrence minted from an opaque callback batch under a generative
-- epoch.  Its constructor and original index stay private; assessors may only
-- retain, reorder, or duplicate handles supplied by
-- 'postVerificationInputCandidates'.
data PostVerificationCandidate epoch candidate = PostVerificationCandidate
  !Natural
  !(Verified candidate)

type role PostVerificationCandidate nominal nominal

-- | One exact callback batch scoped by a fresh abstract epoch.
data PostVerificationInput epoch candidate = PostVerificationInput
  [PostVerificationCandidate epoch candidate]

type role PostVerificationInput nominal nominal

-- | Introduce one fresh batch scope.  The rank-2 epoch prevents handles from
-- another invocation from being supplied to this input's seal without an
-- explicit unsafe operation.
withPostVerificationInput
  :: VerificationBatch candidate
  -> (forall epoch. PostVerificationInput epoch candidate -> result)
  -> result
withPostVerificationInput verification action = action $ PostVerificationInput
  $ zipWith PostVerificationCandidate [0 ..]
  $ verifiedCandidateReceipts verification

postVerificationInputCandidates
  :: PostVerificationInput epoch candidate
  -> [PostVerificationCandidate epoch candidate]
postVerificationInputCandidates (PostVerificationInput candidates) = candidates

postVerificationCandidateVerified
  :: PostVerificationCandidate epoch candidate
  -> Verified candidate
postVerificationCandidateVerified (PostVerificationCandidate _ verified) =
  verified

-- | Exact callback receipts in one admitted post-assessment order.
-- The nominal parameter prevents representation coercion across candidate
-- domains.  Only 'sealPostVerificationBatch' constructs this type.
data PostVerificationBatch candidate = PostVerificationBatch
  [Verified candidate]

type role PostVerificationBatch nominal

postVerificationBatchCandidates
  :: PostVerificationBatch candidate
  -> [Verified candidate]
postVerificationBatchCandidates (PostVerificationBatch candidates) = candidates

-- | The disabled/default stage.  Preserve the verification result as a raw
-- list without traversal, assessment, IO, or any claim that sealing occurred.
skipPostVerificationAssessment
  :: VerificationBatch candidate
  -> [Verified candidate]
skipPostVerificationAssessment = verifiedCandidateReceipts

-- | Seal one bounded exact permutation of the supplied receipts.
--
-- Candidate admission precedes proposal admission.  Length equality precedes
-- index validation; each batch-scoped handle is checked for range and
-- duplication before the original receipt at that occurrence is selected.
-- Counts stop at the caller's maximum plus one, including cyclic inputs.
sealPostVerificationBatch
  :: Natural
  -> PostVerificationInput epoch candidate
  -> [PostVerificationCandidate epoch candidate]
  -> Either PostVerificationError (PostVerificationBatch candidate)
sealPostVerificationBatch maximumCandidates input proposals = do
  admittedCandidates <- admitCollection
    PostVerificationCandidates maximumCandidates
    $ postVerificationInputCandidates input
  admittedProposals <- admitCollection
    PostVerificationProposals maximumCandidates proposals
  let candidateCount = count admittedCandidates
      proposalCount = count admittedProposals
  if proposalCount == candidateCount
    then pure ()
    else Left $ PostVerificationProposalLengthMismatch
      candidateCount proposalCount
  reordered <- validateProposals admittedCandidates candidateCount
    Set.empty [] admittedProposals
  pure $ PostVerificationBatch reordered

admitCollection
  :: PostVerificationCollection
  -> Natural
  -> [value]
  -> Either PostVerificationError [value]
admitCollection collection maximumValues = go 0 []
 where
  go !observed reversed remaining
    | observed >= maximumValues = case remaining of
        [] -> Right $ reverse reversed
        _ : _ -> Left $ PostVerificationCollectionLimitExceeded
          collection maximumValues (maximumValues + 1)
    | otherwise = case remaining of
        [] -> Right $ reverse reversed
        value : rest -> go (observed + 1) (value : reversed) rest

validateProposals
  :: [PostVerificationCandidate epoch candidate]
  -> Natural
  -> Set.Set Natural
  -> [Verified candidate]
  -> [PostVerificationCandidate epoch candidate]
  -> Either PostVerificationError [Verified candidate]
validateProposals candidates candidateCount = go
 where
  go _ reversed [] = Right $ reverse reversed
  go seen reversed (PostVerificationCandidate index _ : rest)
    | index >= candidateCount = Left
        $ PostVerificationProposalIndexOutOfRange candidateCount index
    | Set.member index seen = Left
        $ PostVerificationProposalDuplicateIndex index
    | otherwise = do
        expected <- selectCandidate candidates index
        go (Set.insert index seen)
          (postVerificationCandidateVerified expected : reversed) rest

selectCandidate
  :: [PostVerificationCandidate epoch candidate]
  -> Natural
  -> Either PostVerificationError
      (PostVerificationCandidate epoch candidate)
selectCandidate candidates requested = go 0 candidates
 where
  go _ [] = Left $ PostVerificationProposalIndexOutOfRange
    (count candidates) requested
  go !index (candidate : rest)
    | index == requested = Right candidate
    | otherwise = go (index + 1) rest

count :: [value] -> Natural
count = go 0
 where
  go !result [] = result
  go !result (_ : rest) = go (result + 1) rest
