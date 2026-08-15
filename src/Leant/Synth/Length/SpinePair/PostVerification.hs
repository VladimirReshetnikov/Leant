-- | Safe post-verification facade for binary-product Length ranking.
module Leant.Synth.Length.SpinePair.PostVerification
  ( LengthSpinePairPostVerificationFailure (..)
  , LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationCandidates
  , lengthSpinePairPostVerificationSealedBatch
  , lengthSpinePairPostVerificationAdapterFailure
  , lengthSpinePairPostVerificationRanking
  , lengthSpinePairPostVerificationRankingFailure
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  ) where

import Leant.Synth.Length.Configuration
  ( assessVerifiedLengthSpinePairCandidatesWithPolicy )
import Leant.Synth.Length.SpinePair.PostVerification.Internal
  ( LengthSpinePairPostVerificationFailure (..)
  , LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationAdapterFailure
  , lengthSpinePairPostVerificationCandidates
  , lengthSpinePairPostVerificationRanking
  , lengthSpinePairPostVerificationRankingFailure
  , lengthSpinePairPostVerificationSealedBatch
  )
