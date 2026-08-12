{-# LANGUAGE RankNTypes #-}

-- | Safe post-verification adapter for live Length ranking.
--
-- The adapter retains the complete 'LengthRanking' report while sealing its
-- reordered batch-scoped occurrence handles before erasing them. Pure input
-- or proposal failure preserves the original verification batch and exposes
-- no suspect ranking; synchronous and asynchronous IO exceptions retain the
-- ranking layer's existing propagation behavior.
module Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationSealedBatch
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationRanking
  , assessVerifiedLengthCandidatesConfigured
  , assessVerifiedLengthCandidatesWithPolicy
  ) where

import Language.Haskell.Djex
  ( defaultLengthSMTLibLiveSessionMaximumQueries )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Configuration
  ( LengthRankingConfiguration
  , LengthRankingPolicy
  , rankPostVerificationLengthCandidatesConfigured
  , rankPostVerificationLengthCandidatesWithPolicy
  )
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.Ranking
  ( AssociatedLengthRanking
  , LengthRanking
  , LengthRankingInputError
  , associatedLengthRankingCandidates
  , associatedRankedLengthCandidateAssociation
  , projectAssociatedLengthRanking
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

assessVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesWithPolicy policy contract =
  assessVerifiedLengthCandidatesWith
    $ rankPostVerificationLengthCandidatesWithPolicy policy contract

-- | Run the compatibility policy-plus-contract bundle through the same
-- batch-scoped occurrence seal as the separate policy/request-contract path.
-- This is the only configured entry point suitable for candidate
-- presentation: the association-free configured ranking runner does not mint
-- or validate post-verification occurrence handles.
assessVerifiedLengthCandidatesConfigured
  :: LengthRankingConfiguration
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesConfigured configuration =
  assessVerifiedLengthCandidatesWith
    $ rankPostVerificationLengthCandidatesConfigured configuration

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
          $ projectAssociatedLengthRanking associated
