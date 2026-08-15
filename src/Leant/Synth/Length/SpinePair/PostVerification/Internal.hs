{-# LANGUAGE RankNTypes #-}

-- | Package-private occurrence seal for binary-product Length ranking.
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

data LengthSpinePairPostVerificationFailure
  = LengthSpinePairPostVerificationInputRejected !LengthRankingInputError
  | LengthSpinePairPostVerificationProposalRejected !PostVerificationError
  deriving (Eq, Ord, Show)

data LengthSpinePairPostVerificationResult
  = LengthSpinePairPostVerificationRejected
      !(VerificationBatch DetailedVerificationVariant)
      !LengthSpinePairPostVerificationFailure
  | LengthSpinePairPostVerificationAccepted
      !PostVerificationLengthSpinePairRanking

lengthSpinePairPostVerificationCandidates
  :: LengthSpinePairPostVerificationResult
  -> [Verified DetailedVerificationVariant]
lengthSpinePairPostVerificationCandidates result = case result of
  LengthSpinePairPostVerificationRejected verification _ ->
    verifiedCandidateReceipts verification
  LengthSpinePairPostVerificationAccepted retained ->
    postVerificationBatchCandidates
      $ postVerificationLengthSpinePairRankingBatch retained

lengthSpinePairPostVerificationSealedBatch
  :: LengthSpinePairPostVerificationResult
  -> Maybe (PostVerificationBatch DetailedVerificationVariant)
lengthSpinePairPostVerificationSealedBatch result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained -> Just
    $ postVerificationLengthSpinePairRankingBatch retained

lengthSpinePairPostVerificationAdapterFailure
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairPostVerificationFailure
lengthSpinePairPostVerificationAdapterFailure result = case result of
  LengthSpinePairPostVerificationRejected _ failure -> Just failure
  LengthSpinePairPostVerificationAccepted {} -> Nothing

lengthSpinePairPostVerificationRanking
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairRanking
lengthSpinePairPostVerificationRanking result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained ->
    let ranking = materializePostVerificationLengthSpinePairRanking retained
    in ranking `seq` Just ranking

lengthSpinePairPostVerificationRankingFailure
  :: LengthSpinePairPostVerificationResult
  -> Maybe LengthSpinePairRankingFailure
lengthSpinePairPostVerificationRankingFailure result = case result of
  LengthSpinePairPostVerificationRejected {} -> Nothing
  LengthSpinePairPostVerificationAccepted retained ->
    postVerificationLengthSpinePairRankingFailure retained

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
