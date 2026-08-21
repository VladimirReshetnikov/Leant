{-# LANGUAGE RoleAnnotations #-}

-- | Lazy, quota-aware verification of rendered candidate groups.
--
-- A group contains textual variants of one semantic candidate.  Variants are
-- tried in order, the first accepted variant represents its group, and only
-- accepted groups consume the success quota.  The result records exact
-- attempt and outcome observations without changing synthesis-engine output.
module Leant.Synth.Verification
  ( VariantVerdict (..)
  , GroupVerificationSummary
  , verifyCandidateGroup
  , groupVerificationSummaryAccepted
  , verificationBatchFromGroupSummaries
  , Verified
  , verifiedCandidate
  , VerificationBatch
  , verifiedCandidateReceipts
  , verifiedCandidates
  , failedCandidateGroups
  , verificationObservations
  , verifyCandidateGroups
  ) where

import Control.DeepSeq (NFData (rnf))
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

instance NFData VariantVerdict where
  rnf verdict = case verdict of
    VariantAccepted -> ()
    VariantRejected failure -> rnf failure

-- | Candidate-free result of attempting one complete semantic group.
--
-- The private constructors retain rejection classes in variant order.  An
-- accepted summary ends immediately before the first accepted variant; a
-- rejected summary contains every attempted variant's failure.  Consequently
-- an empty rejected list also represents an empty group.  Keeping candidates
-- out of this value lets a worker force the complete verdict before
-- publication without demanding a retained semantic sidecar.
data GroupVerificationSummary
  = GroupVerificationAccepted ![VerificationFailureClass]
  | GroupVerificationRejected ![VerificationFailureClass]

instance NFData GroupVerificationSummary where
  rnf summary = case summary of
    GroupVerificationAccepted failures -> rnf failures
    GroupVerificationRejected failures -> rnf failures

-- | Verify exactly one group, stopping at its first accepted variant.
--
-- This package-internal scheduler seam deliberately records no candidate.
-- The group and its summary are reunited only after ordered worker results
-- have been observed.
verifyCandidateGroup
  :: Monad m
  => (candidate -> m VariantVerdict)
  -> [candidate]
  -> m GroupVerificationSummary
verifyCandidateGroup verifyVariant = go []
 where
  go reverseFailures variants = case variants of
    [] -> pure $ GroupVerificationRejected $ reverse reverseFailures
    candidate : remaining -> do
      verdict <- verifyVariant candidate
      case verdict of
        VariantAccepted ->
          pure $ GroupVerificationAccepted $ reverse reverseFailures
        VariantRejected failure ->
          go (failure : reverseFailures) remaining

-- | Whether a complete group summary contains an accepted variant.
--
-- This is exposed only so the private parallel scheduler can translate the
-- summary into its rejection-or-success quota protocol.
groupVerificationSummaryAccepted :: GroupVerificationSummary -> Bool
groupVerificationSummaryAccepted summary = case summary of
  GroupVerificationAccepted _ -> True
  GroupVerificationRejected _ -> False

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

-- | Reattach ordered summaries to the exact group prefix that produced them.
--
-- The first component is the historical verification batch.  The second is
-- the flattened logical attempt trace: complete rejected groups and accepted
-- groups through their first accepted variant, all in input order.  Neither
-- component deep-forces candidate payloads.  Inspecting stops with the
-- summary list, so a success-quota tail remains untouched.
--
-- The summaries and groups must come from the same ordered traversal.  The
-- private parallel scheduler and 'verifyCandidateGroups' establish that
-- invariant before calling this package-internal reconstruction boundary.
verificationBatchFromGroupSummaries
  :: [GroupVerificationSummary]
  -> [[candidate]]
  -> (VerificationBatch candidate, [candidate])
verificationBatchFromGroupSummaries = go
 where
  go summaries groups = case summaries of
    [] -> (VerificationBatch [] 0 noObservations, [])
    summary : followingSummaries -> case groups of
      [] -> error $ unwords
        [ "verificationBatchFromGroupSummaries:"
        , "summary/group length mismatch"
        ]
      group : followingGroups ->
        let (followingBatch, followingAttempts) =
              go followingSummaries followingGroups
            attempts = groupAttemptedCandidates summary group
              ++ followingAttempts
            observations = groupVerificationObservations summary
            batch = case summary of
              GroupVerificationAccepted failures ->
                prependCandidate
                  (Verified $ acceptedCandidate failures group)
                  observations
                  followingBatch
              GroupVerificationRejected _ ->
                prependRejectedGroup observations followingBatch
        in (batch, attempts)

-- Select only list spines.  Candidate values, including semantic sidecars,
-- remain thunks in both the receipt batch and the logical attempt trace.
groupAttemptedCandidates
  :: GroupVerificationSummary
  -> [candidate]
  -> [candidate]
groupAttemptedCandidates summary group = case summary of
  GroupVerificationAccepted failures ->
    take (length failures + 1) group
  GroupVerificationRejected failures ->
    take (length failures) group

acceptedCandidate
  :: [VerificationFailureClass]
  -> [candidate]
  -> candidate
acceptedCandidate failures group = case drop (length failures) group of
  candidate : _ -> candidate
  [] -> error $ unwords
    [ "verificationBatchFromGroupSummaries:"
    , "accepted summary lacks its candidate"
    ]

groupVerificationObservations
  :: GroupVerificationSummary
  -> LeantObservations
groupVerificationObservations summary =
  foldr recordFailure terminal failures
 where
  (failures, terminal) = case summary of
    GroupVerificationAccepted rejected ->
      ( rejected
      , recordObservation LeanCandidateVerified
          $ recordObservation LeanVariantAttempted noObservations
      )
    GroupVerificationRejected rejected -> (rejected, noObservations)

  recordFailure failure observations =
    recordObservation (LeanVerificationFailure failure)
      $ recordObservation LeanVariantAttempted observations

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

prependRejectedGroup
  :: LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependRejectedGroup observations
    (VerificationBatch candidates failed following) =
  VerificationBatch candidates (failed + 1) (observations <> following)

prependObservations
  :: LeantObservations
  -> VerificationBatch candidate
  -> VerificationBatch candidate
prependObservations observations
    (VerificationBatch candidates failed following) =
  VerificationBatch candidates failed (observations <> following)
