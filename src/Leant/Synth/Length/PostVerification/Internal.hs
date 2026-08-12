{-# LANGUAGE RankNTypes #-}

-- | Package-private sealing core for live Length ranking.
--
-- The adapter retains the complete 'LengthRanking' report while sealing its
-- reordered batch-scoped occurrence handles before erasing them. Pure input
-- or proposal failure preserves the original verification batch and exposes
-- no suspect ranking; synchronous and asynchronous IO exceptions retain the
-- ranking layer's existing propagation behavior.
module Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationSealedBatch
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , assessVerifiedLengthCandidatesWith
  ) where

import Language.Haskell.Djex
  ( defaultLengthSMTLibLiveSessionMaximumQueries )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Ranking.Internal
  ( AssociatedLengthRanking
  , LengthRanking
  , LengthRankingInputError
  , associatedLengthRankingCandidates
  , associatedRankedLengthCandidateAssociation
  , projectPostVerificationLengthRanking
  )
import Leant.Synth.PostVerification
  ( PostVerificationBatch
  , PostVerificationCandidate
  , PostVerificationError
  , postVerificationBatchCandidates
  , postVerificationInputCandidates
  , sealPostVerificationBatch
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
-- result always couples one sealed batch with its complete domain report.
data LengthPostVerificationResult
  = LengthPostVerificationRejected
      !(VerificationBatch DetailedVerificationVariant)
      !LengthPostVerificationFailure
  | LengthPostVerificationAccepted
      !(PostVerificationBatch DetailedVerificationVariant)
      !LengthRanking

lengthPostVerificationCandidates
  :: LengthPostVerificationResult
  -> [Verified DetailedVerificationVariant]
lengthPostVerificationCandidates result = case result of
  LengthPostVerificationRejected verification _ ->
    verifiedCandidateReceipts verification
  LengthPostVerificationAccepted batch _ ->
    postVerificationBatchCandidates batch

-- | Present exactly when output ordering passed the bounded permutation seal.
lengthPostVerificationSealedBatch
  :: LengthPostVerificationResult
  -> Maybe (PostVerificationBatch DetailedVerificationVariant)
lengthPostVerificationSealedBatch result = case result of
  LengthPostVerificationRejected {} -> Nothing
  LengthPostVerificationAccepted batch _ -> Just batch

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
  LengthPostVerificationAccepted _ ranking -> Just ranking

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
      Right associated -> case sealPostVerificationBatch
          defaultLengthSMTLibLiveSessionMaximumQueries input
          (map associatedRankedLengthCandidateAssociation
            $ associatedLengthRankingCandidates associated) of
        Left failure -> LengthPostVerificationRejected verification
          $ LengthPostVerificationProposalRejected failure
        Right batch -> LengthPostVerificationAccepted batch
          $ projectPostVerificationLengthRanking associated
