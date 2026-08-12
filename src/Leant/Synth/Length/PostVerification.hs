-- | Safe post-verification facade for live Length ranking.
--
-- Both entry points retain opaque batch-scoped occurrence handles through
-- ranking and expose an association-free report only after the complete
-- permutation seal succeeds.  The lower-level associated plan and projector
-- are confined to package-private modules.
module Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationSealedBatch
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  , assessVerifiedLengthCandidatesConfigured
  , assessVerifiedLengthCandidatesWithPolicy
  ) where

import Leant.Synth.Length.Configuration
  ( assessVerifiedLengthCandidatesConfigured
  , assessVerifiedLengthCandidatesWithPolicy
  )
import Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  , lengthPostVerificationSealedBatch
  )
