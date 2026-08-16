{-# LANGUAGE RankNTypes #-}

-- | Package-private occurrence seal for binary-product Length ranking.
--
-- This is the nominal product sibling of
-- "Leant.Synth.Length.PostVerification.Internal".  The adapter retains the
-- sealed batch as the sole owner of verified receipts beside an eager
-- receipt-free ranking summary.  It materializes the complete pair-domain
-- 'LengthSpinePairRanking' view only on projection.  Pure input or proposal
-- failure preserves the original verification batch and exposes no suspect
-- ranking; synchronous and asynchronous IO exceptions retain the ranking
-- layer's existing propagation behavior.
module Leant.Synth.Length.SpinePair.PostVerification.Internal
  ( LengthSpinePairPostVerificationFailure (..)
  , LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationCandidates
  , lengthSpinePairPostVerificationSealedBatch
  , lengthSpinePairPostVerificationAdapterFailure
  , lengthSpinePairPostVerificationRanking
  , lengthSpinePairPostVerificationRankingFailure
  , assessVerifiedLengthSpinePairCandidatesWith
  ) where

import Language.Haskell.Djex
  ( defaultLengthSMTLibLiveSessionMaximumQueries )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Ranking.Internal
  ( LengthRankingInputError )
import Leant.Synth.Length.SpinePair.Ranking.Internal
  ( AssociatedLengthSpinePairRanking
  , LengthSpinePairRanking
  , LengthSpinePairRankingFailure
  , PostVerificationLengthSpinePairRanking
  , materializePostVerificationLengthSpinePairRanking
  , postVerificationLengthSpinePairRankingBatch
  , postVerificationLengthSpinePairRankingFailure
  , sealPostVerificationLengthSpinePairRanking
  )
import Leant.Synth.PostVerification
  ( PostVerificationBatch
  , PostVerificationCandidate
  , PostVerificationError
  , postVerificationBatchCandidates
  , postVerificationInputCandidates
  , withPostVerificationInput
  )
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

-- | Why the pair-domain post-verification adapter rejected a batch: the
-- ranking input itself was refused, or the ranking's proposed permutation
-- failed the bounded seal.
data LengthSpinePairPostVerificationFailure
  = LengthSpinePairPostVerificationInputRejected !LengthRankingInputError
  | LengthSpinePairPostVerificationProposalRejected !PostVerificationError
  deriving (Eq, Ord, Show)

-- | A rejected proposal preserves the exact opaque verification input and
-- exposes no ranking whose associations failed validation.  An accepted
-- result retains one sealed batch as its sole verified-receipt owner beside
-- the eager receipt-free state needed to project its pair-domain report.
data LengthSpinePairPostVerificationResult
  = LengthSpinePairPostVerificationRejected
      !(VerificationBatch DetailedVerificationVariant)
      !LengthSpinePairPostVerificationFailure
  | LengthSpinePairPostVerificationAccepted
      !PostVerificationLengthSpinePairRanking

-- | The verified receipts to present: the untouched callback order for a
-- rejected result, or the sealed post-assessment order for an accepted one.
lengthSpinePairPostVerificationCandidates
  :: LengthSpinePairPostVerificationResult
  -> [Verified DetailedVerificationVariant]
lengthSpinePairPostVerificationCandidates result = case result of
  LengthSpinePairPostVerificationRejected verification _ ->
    verifiedCandidateReceipts verification
  LengthSpinePairPostVerificationAccepted retained ->
    postVerificationBatchCandidates
      $ postVerificationLengthSpinePairRankingBatch retained

-- | Present exactly when output ordering passed the bounded permutation seal.
lengthSpinePairPostVerificationSealedBatch
  :: LengthSpinePairPostVerificationResult
  -> Maybe (PostVerificationBatch DetailedVerificationVariant)
lengthSpinePairPostVerificationSealedBatch result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained -> Just
    $ postVerificationLengthSpinePairRankingBatch retained

-- | The adapter's own rejection, present exactly for a rejected result.
lengthSpinePairPostVerificationAdapterFailure
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairPostVerificationFailure
lengthSpinePairPostVerificationAdapterFailure result = case result of
  LengthSpinePairPostVerificationRejected _ failure -> Just failure
  LengthSpinePairPostVerificationAccepted {} -> Nothing

-- | The receipt-bearing pair-domain ranking of an accepted result,
-- materialized on demand and forced to weak head normal form before it is
-- returned; 'Nothing' for a rejected result.
lengthSpinePairPostVerificationRanking
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairRanking
lengthSpinePairPostVerificationRanking result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained ->
    let ranking = materializePostVerificationLengthSpinePairRanking retained
    in ranking `seq` Just ranking

-- | Batch-wide ranking failure without materializing the receipt-bearing
-- pair-domain report.
lengthSpinePairPostVerificationRankingFailure
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairRankingFailure
lengthSpinePairPostVerificationRankingFailure result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained ->
    postVerificationLengthSpinePairRankingFailure retained

-- | Seal the complete permutation returned by one trusted associated ranker
-- before erasing its batch-scoped occurrence handles.  This helper stays in
-- the package-private module so presentation facades can expose only the
-- concrete pair-domain entry points.
assessVerifiedLengthSpinePairCandidatesWith
  :: (forall epoch.
      [PostVerificationCandidate epoch DetailedVerificationVariant]
      -> IO
          (Either LengthRankingInputError
            (AssociatedLengthSpinePairRanking
              (PostVerificationCandidate
                epoch DetailedVerificationVariant))))
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairPostVerificationResult
assessVerifiedLengthSpinePairCandidatesWith rankCandidates verification =
  withPostVerificationInput verification $ \input -> do
    ranked <- rankCandidates $ postVerificationInputCandidates input
    pure $ case ranked of
      Left failure -> LengthSpinePairPostVerificationRejected verification
        $ LengthSpinePairPostVerificationInputRejected failure
      Right associated -> case sealPostVerificationLengthSpinePairRanking
          defaultLengthSMTLibLiveSessionMaximumQueries input associated of
        Left failure -> LengthSpinePairPostVerificationRejected verification
          $ LengthSpinePairPostVerificationProposalRejected failure
        Right retained -> LengthSpinePairPostVerificationAccepted retained
