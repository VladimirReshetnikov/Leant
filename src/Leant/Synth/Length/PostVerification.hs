-- | Safe post-verification facade for live Length ranking.
--
-- The policy-plus-contract entry point retains opaque batch-scoped occurrence
-- handles through ranking.  It exposes an association-free report only after
-- the complete permutation seal succeeds.  The lower-level associated plan
-- and projector are confined to package-private modules.
module Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationSealedBatch
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  , assessVerifiedLengthCandidatesWithPolicy
  ) where

import Leant.Synth.Length.Configuration
  ( assessVerifiedLengthCandidatesWithPolicy )
import Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  , lengthPostVerificationSealedBatch
  )
