-- | Lazy, quota-aware verification of rendered candidate groups.
--
-- A group contains textual variants of one semantic candidate.  Variants are
-- tried in order, the first accepted variant represents its group, and only
-- accepted groups consume the success quota.  The result records exact
-- attempt and outcome observations without changing synthesis-engine output.
module Leant.Synth.Verification
  ( VariantVerdict (..)
  , VerificationBatch
  , verifiedCandidates
  , failedCandidateGroups
  , verificationObservations
  , verifyCandidateGroups
  ) where

import Language.Haskell.Synthesis.Observability
  ( noObservations
  , recordObservation
  )
import Numeric.Natural (Natural)

import Leant.Synth.Observability
  ( LeantObservations
  , LeantSynthesisMetric (..)
  , VerificationFailureClass
  )

-- | The mutually exclusive result of attempting one rendered variant.
data VariantVerdict
  = VariantAccepted
  | VariantRejected VerificationFailureClass
  deriving (Eq, Ord, Show)

-- | The verified representatives and observations from one bounded pass.
--
-- Fields stay private so attempt and outcome counts cannot drift apart.
data VerificationBatch candidate = VerificationBatch
  [candidate]
  Natural
  LeantObservations
  deriving (Eq, Show)

-- | Accepted group representatives, in input order.
verifiedCandidates :: VerificationBatch candidate -> [candidate]
verifiedCandidates (VerificationBatch candidates _ _) = candidates

-- | Number of groups for which no variant was accepted.
--
-- An empty group is failed but records no variant attempt.
failedCandidateGroups :: VerificationBatch candidate -> Natural
failedCandidateGroups (VerificationBatch _ failed _) = failed

-- | Exact attempt and verdict observations accumulated by this pass.
verificationObservations
  :: VerificationBatch candidate
  -> LeantObservations
verificationObservations (VerificationBatch _ _ observations) = observations

-- | Verify candidate groups until the success quota is met or input ends.
--
-- The quota guard deliberately precedes inspection of the group list.  This
-- makes a zero quota total even for a partial input and avoids forcing the
-- tail after the final accepted group.  Failed and empty groups do not consume
-- quota; accepted variants stop their group before its remaining variants are
-- inspected.
verifyCandidateGroups
  :: Monad m
  => Int
  -> (candidate -> m VariantVerdict)
  -> [[candidate]]
  -> m (VerificationBatch candidate)
verifyCandidateGroups quota verifyVariant = go quota 0
 where
  go remaining failed groups
    | remaining <= 0 =
        pure (VerificationBatch [] failed noObservations)
    | otherwise = case groups of
        [] -> pure (VerificationBatch [] failed noObservations)
        group : rest -> do
          groupResult <- verifyGroup group
          case groupResult of
            GroupAccepted candidate observations -> do
              following <- go (remaining - 1) failed rest
              pure $ prependCandidate candidate observations following
            GroupRejected observations -> do
              following <- go remaining (failed + 1) rest
              pure $ prependObservations observations following

  verifyGroup variants = case variants of
    [] -> pure (GroupRejected noObservations)
    candidate : remaining -> do
      verdict <- verifyVariant candidate
      let attempted = recordObservation LeanVariantAttempted noObservations
      case verdict of
        VariantAccepted -> pure $ GroupAccepted candidate
          (recordObservation LeanCandidateVerified attempted)
        VariantRejected failure -> do
          following <- verifyGroup remaining
          pure $ addGroupObservations
            (recordObservation (LeanVerificationFailure failure) attempted)
            following

data GroupResult candidate
  = GroupAccepted candidate LeantObservations
  | GroupRejected LeantObservations

addGroupObservations
  :: LeantObservations
  -> GroupResult candidate
  -> GroupResult candidate
addGroupObservations observations result = case result of
  GroupAccepted candidate following ->
    GroupAccepted candidate (observations <> following)
  GroupRejected following -> GroupRejected (observations <> following)

prependCandidate
  :: candidate
  -> LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependCandidate candidate observations
    (VerificationBatch candidates failed following) =
  VerificationBatch
    (candidate : candidates)
    failed
    (observations <> following)

prependObservations
  :: LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependObservations observations
    (VerificationBatch candidates failed following) =
  VerificationBatch candidates failed (observations <> following)
