{-# LANGUAGE RankNTypes #-}

-- | Package-private sealing core for live Length ranking.
--
-- The adapter retains the sealed batch as the sole owner of verified receipts
-- beside an eager receipt-free ranking summary.  It materializes the complete
-- compatibility 'LengthRanking' view only on projection.  Pure input or
-- proposal failure preserves the original verification batch and exposes no
-- suspect ranking; synchronous and asynchronous IO exceptions retain the
-- ranking layer's existing propagation behavior.
module Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationSealedBatch
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , lengthPostVerificationRankingFailure
  , assessVerifiedLengthCandidatesWith
  ) where

import Language.Haskell.Djex
  ( defaultLengthSMTLibLiveSessionMaximumQueries )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Ranking.Internal
  ( AssociatedLengthRanking
  , LengthRanking
  , LengthRankingFailure
  , LengthRankingInputError
  , PostVerificationLengthRanking
  , materializePostVerificationLengthRanking
  , postVerificationLengthRankingBatch
  , postVerificationLengthRankingFailure
  , sealPostVerificationLengthRanking
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

data LengthPostVerificationFailure
  = LengthPostVerificationInputRejected !LengthRankingInputError
  | LengthPostVerificationProposalRejected !PostVerificationError
  deriving (Eq, Ord, Show)

-- | A rejected proposal preserves the exact opaque verification input and
-- exposes no ranking whose associations failed validation.  An accepted
-- result retains one sealed batch as its sole verified-receipt owner beside
-- the eager receipt-free state needed to project its compatibility report.
data LengthPostVerificationResult
  = LengthPostVerificationRejected
      !(VerificationBatch DetailedVerificationVariant)
      !LengthPostVerificationFailure
  | LengthPostVerificationAccepted
      !PostVerificationLengthRanking

lengthPostVerificationCandidates
  :: LengthPostVerificationResult
  -> [Verified DetailedVerificationVariant]
lengthPostVerificationCandidates result = case result of
  LengthPostVerificationRejected verification _ ->
    verifiedCandidateReceipts verification
  LengthPostVerificationAccepted retained ->
    postVerificationBatchCandidates
      $ postVerificationLengthRankingBatch retained

-- | Present exactly when output ordering passed the bounded permutation seal.
lengthPostVerificationSealedBatch
  :: LengthPostVerificationResult
  -> Maybe (PostVerificationBatch DetailedVerificationVariant)
lengthPostVerificationSealedBatch result = case result of
  LengthPostVerificationRejected {} -> Nothing
  LengthPostVerificationAccepted retained -> Just
    $ postVerificationLengthRankingBatch retained

lengthPostVerificationAdapterFailure
  :: LengthPostVerificationResult
  -> Maybe LengthPostVerificationFailure
lengthPostVerificationAdapterFailure result = case result of
  LengthPostVerificationRejected _ failure -> Just failure
  LengthPostVerificationAccepted {} -> Nothing

lengthPostVerificationRanking
  :: LengthPostVerificationResult
  -> Maybe LengthRanking
lengthPostVerificationRanking result = case result of
  LengthPostVerificationRejected {} -> Nothing
  LengthPostVerificationAccepted retained ->
    let ranking = materializePostVerificationLengthRanking retained
    in ranking `seq` Just ranking

-- | Batch-wide ranking failure without materializing the receipt-bearing
-- compatibility report.
lengthPostVerificationRankingFailure
  :: LengthPostVerificationResult
  -> Maybe LengthRankingFailure
lengthPostVerificationRankingFailure result = case result of
  LengthPostVerificationRejected {} -> Nothing
  LengthPostVerificationAccepted retained ->
    postVerificationLengthRankingFailure retained

-- | Seal the complete permutation returned by one trusted associated ranker
-- before erasing its batch-scoped occurrence handles.  This helper stays in
-- the package-private module so presentation facades can expose only the two
-- concrete Length entry points.
assessVerifiedLengthCandidatesWith
  :: (forall epoch.
      [PostVerificationCandidate epoch DetailedVerificationVariant]
      -> IO
          (Either LengthRankingInputError
            (AssociatedLengthRanking
              (PostVerificationCandidate
                epoch DetailedVerificationVariant))))
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesWith rankCandidates verification = do
  withPostVerificationInput verification $ \input -> do
    ranked <- rankCandidates
      $ postVerificationInputCandidates input
    pure $ case ranked of
      Left failure -> LengthPostVerificationRejected verification
        $ LengthPostVerificationInputRejected failure
      Right associated -> case sealPostVerificationLengthRanking
          defaultLengthSMTLibLiveSessionMaximumQueries input associated of
        Left failure -> LengthPostVerificationRejected verification
          $ LengthPostVerificationProposalRejected failure
        Right retained -> LengthPostVerificationAccepted retained
