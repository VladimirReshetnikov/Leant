{-# LANGUAGE RoleAnnotations #-}

-- | Lazy, quota-aware verification of rendered candidate groups.
--
-- A group contains textual variants of one semantic candidate.  Variants are
-- tried in order, the first accepted variant represents its group, and only
-- accepted groups consume the success quota.  The result records exact
-- attempt and outcome observations without changing synthesis-engine output.
module Leant.Synth.Verification
  ( VariantVerdict (..)
  , Verified
  , verifiedCandidate
  , VerificationBatch
  , verifiedCandidateReceipts
  , verifiedCandidates
  , failedCandidateGroups
  , verificationObservations
  , verifyCandidateGroups
  , verifyDistinctCandidateGroupsBy
  ) where

import qualified Data.Set as Set
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

-- | Opaque receipt that the supplied verification callback accepted a
-- candidate.
--
-- This records only callback acceptance at this boundary.  In particular, it
-- is not behavioral evidence, a solver certificate, or a kernel proof.  A
-- caller which needs one of those stronger claims must retain and replay that
-- authority separately.
data Verified candidate = Verified candidate
  deriving (Eq, Show)

type role Verified nominal

-- | Recover the exact candidate accepted by the verification callback.
verifiedCandidate :: Verified candidate -> candidate
verifiedCandidate (Verified candidate) = candidate

-- | The callback-accepted representatives and observations from one bounded
-- pass.
--
-- Fields stay private so attempt and outcome counts cannot drift apart.
data VerificationBatch candidate = VerificationBatch
  [Verified candidate]
  Natural
  LeantObservations
  deriving (Eq)

type role VerificationBatch nominal

-- Preserve the historical rendering of the private batch representation.
-- The new receipt layer is observable only through its explicit projection.
instance Show candidate => Show (VerificationBatch candidate) where
  showsPrec precedence (VerificationBatch receipts failed observations) =
    showParen (precedence > 10) $
      showString "VerificationBatch "
        . showsPrec 11 (map verifiedCandidate receipts)
        . showChar ' '
        . showsPrec 11 failed
        . showChar ' '
        . showsPrec 11 observations

-- | Opaque callback-acceptance receipts, in input order.
verifiedCandidateReceipts
  :: VerificationBatch candidate
  -> [Verified candidate]
verifiedCandidateReceipts (VerificationBatch receipts _ _) = receipts

-- | Accepted group representatives, in input order.
--
-- This compatibility projection intentionally discards only the receipt
-- wrapper; it does not alter candidate order or force candidate payloads.
verifiedCandidates :: VerificationBatch candidate -> [candidate]
verifiedCandidates = map verifiedCandidate . verifiedCandidateReceipts

-- | Number of groups for which no variant was accepted.
--
-- An empty group is failed but records no variant attempt.
-- In the keyed verifier, a nonempty group containing only previously accepted
-- keys is skipped, rather than counted as a failed verification.
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
            GroupAccepted receipt observations -> do
              following <- go (remaining - 1) failed rest
              pure $ prependCandidate receipt observations following
            GroupRejected observations -> do
              following <- go remaining (failed + 1) rest
              pure $ prependObservations observations following

  verifyGroup variants = case variants of
    [] -> pure (GroupRejected noObservations)
    candidate : remaining -> do
      verdict <- verifyVariant candidate
      let attempted = recordObservation LeanVariantAttempted noObservations
      case verdict of
        VariantAccepted -> pure $ GroupAccepted (Verified candidate)
          (recordObservation LeanCandidateVerified attempted)
        VariantRejected failure -> do
          following <- verifyGroup remaining
          pure $ addGroupObservations
            (recordObservation (LeanVerificationFailure failure) attempted)
            following

-- | Verify a caller-bounded group stream, accepting each key at most once.
-- Main supplies the exact rendered spelling as the key. Only an actual
-- callback acceptance adds a key: a previously rejected spelling can still
-- be retried, and untried alternatives do not suppress a later group.
--
-- A duplicate is skipped before its callback; fresh alternatives in the same
-- group retain their original candidate payload and renderer identity. No
-- receipt or semantic authority is copied from another occurrence. Skipped
-- duplicates produce neither verification attempts nor synthetic failures.
-- An empty input group retains the generic verifier's failed-group behavior.
--
-- This function does not fetch or refill a synthesis window. The caller must
-- bound the group stream first. The success-quota guard precedes inspection
-- of keys or tails, and acceptance leaves the rest of its group untouched.
verifyDistinctCandidateGroupsBy
  :: (Monad m, Ord key)
  => (candidate -> key)
  -> Int
  -> (candidate -> m VariantVerdict)
  -> [[candidate]]
  -> m (VerificationBatch candidate)
verifyDistinctCandidateGroupsBy key quota verifyVariant = go quota 0 Set.empty
 where
  go remaining failed accepted groups
    | remaining <= 0 = pure (VerificationBatch [] failed noObservations)
    | otherwise = case groups of
        [] -> pure (VerificationBatch [] failed noObservations)
        [] : rest -> go remaining (failed + 1) accepted rest
        group : rest -> do
          result <- verifyGroup accepted group
          case result of
            FreshGroupAccepted acceptedKey receipt observations -> do
              following <- go (remaining - 1) failed
                (Set.insert acceptedKey accepted) rest
              pure $ prependCandidate receipt observations following
            FreshGroupRejected observations -> do
              following <- go remaining (failed + 1) accepted rest
              pure $ prependObservations observations following
            FreshGroupSkipped -> go remaining failed accepted rest

  verifyGroup accepted variants = case variants of
    [] -> pure FreshGroupSkipped
    candidate : remaining ->
      let candidateKey = key candidate
      in if candidateKey `Set.member` accepted
        then verifyGroup accepted remaining
        else do
          verdict <- verifyVariant candidate
          let attempted = recordObservation LeanVariantAttempted noObservations
          case verdict of
            VariantAccepted -> pure $ FreshGroupAccepted candidateKey
              (Verified candidate) (recordObservation LeanCandidateVerified attempted)
            VariantRejected failure -> do
              following <- verifyGroup accepted remaining
              let observations = recordObservation
                    (LeanVerificationFailure failure) attempted
              pure $ case following of
                FreshGroupAccepted followingKey receipt followingObservations ->
                  FreshGroupAccepted followingKey receipt
                    (observations <> followingObservations)
                FreshGroupRejected followingObservations ->
                  FreshGroupRejected (observations <> followingObservations)
                FreshGroupSkipped -> FreshGroupRejected observations
data FreshGroupResult key candidate
  = FreshGroupAccepted key (Verified candidate) LeantObservations
  | FreshGroupRejected LeantObservations
  | FreshGroupSkipped


data GroupResult candidate
  = GroupAccepted (Verified candidate) LeantObservations
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
  :: Verified candidate
  -> LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependCandidate receipt observations
    (VerificationBatch receipts failed following) =
  VerificationBatch
    (receipt : receipts)
    failed
    (observations <> following)

prependObservations
  :: LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependObservations observations
    (VerificationBatch candidates failed following) =
  VerificationBatch candidates failed (observations <> following)
