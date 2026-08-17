{-# LANGUAGE RoleAnnotations #-}

-- | Domain-generic hard selection over an assessed Length ranking.
--
-- The scalar finite-list-spine domain and the binary-product domain select
-- with exactly the same control flow: run the domain's assessment pipeline,
-- give each ranked report back to the matching occurrence of one fresh
-- behavioral-selection epoch by its original index, retain everything except
-- an independently replayed counterexample, and seal the resulting partition.
-- Every operational or association failure atomically preserves the supplied
-- verification batch.  The two domains differ only in the nominal receipts
-- they validate and in the nominal explanation, failure, and result types
-- each exports.
--
-- This module holds that control flow once.
-- "Leant.Synth.Length.Selection.Internal" and
-- "Leant.Synth.Length.SpinePair.Selection.Internal" instantiate it and keep
-- their established public names, signatures, and nominal types: the shared
-- explanation, rejection, and result types below take the domain's own
-- receipt types as parameters, so a scalar retention and a binary-product
-- retention remain distinct types which no projection can confuse, exactly as
-- when each domain spelled the same five constructors itself.  The
-- projections stay closed because the constructors below are exported to the
-- two instantiating modules only, which re-export the types abstractly.
module Leant.Synth.Length.Selection.Generic
  ( SelectionRetention (..)
  , selectionRetentionPreparationRefusal
  , selectionRetentionSolverStatus
  , selectionRetentionInputBox
  , selectionRetentionApplicableDomain
  , SelectionRejection (..)
  , selectionRejectionCounterexample
  , selectionRejectionSimplification
  , SelectionResult (..)
  , selectionCandidates
  , selectionSelected
  , selectionRejected
  , selectionFailure
  , SelectionDomain (..)
  , runSelectionWithAssessment
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( SolverStatus
  , defaultLengthSMTLibLiveSessionMaximumQueries
  )

import Leant.Synth.BehavioralSelection.Internal
  ( BehavioralSelectionBatch
  , BehavioralSelectionCandidate
  , BehavioralSelectionDecision
  , BehavioralSelectionError
  , BehaviorallyRejected
  , BehaviorallySelected
  , behavioralSelectionBatchRejected
  , behavioralSelectionBatchSelected
  , behavioralSelectionInputCandidates
  , behaviorallySelectedVerified
  , rejectBehavioralSelectionCandidate
  , retainBehavioralSelectionCandidate
  , sealBehavioralSelectionBatch
  , withBehavioralSelectionInput
  )
import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Ranking (LengthPreparationRefusalClass)
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  , verifiedCandidateReceipts
  )

-- | Why the hard filter retained a candidate.  None of these cases is
-- negative behavioral evidence.  The two payload parameters are the domain's
-- own finite input-box and applicable-domain receipts, which is what keeps a
-- scalar retention and a binary-product retention distinct types.
data SelectionRetention box domain
  = RetainedPreparationRefusal !LengthPreparationRefusalClass
  | RetainedUnassessed
  | RetainedHeuristic !SolverStatus
  | RetainedBoundedPositive !box
  | RetainedApplicableDomainEstablished !domain
  deriving (Eq, Show)

type role SelectionRetention nominal nominal

-- | The preparation refusal diagnostic of a refused retention; 'Nothing' for
-- every other class.
selectionRetentionPreparationRefusal
  :: SelectionRetention box domain
  -> Maybe LengthPreparationRefusalClass
selectionRetentionPreparationRefusal retention = case retention of
  RetainedPreparationRefusal refusal -> Just refusal
  _ -> Nothing

-- | The raw solver status of a heuristic retention; 'Nothing' for every other
-- class.  A status is a diagnostic, never negative behavioral evidence.
selectionRetentionSolverStatus
  :: SelectionRetention box domain
  -> Maybe SolverStatus
selectionRetentionSolverStatus retention = case retention of
  RetainedHeuristic status -> Just status
  _ -> Nothing

-- | The finite input-box receipt of a bounded-positive retention; 'Nothing'
-- for every other class.
selectionRetentionInputBox :: SelectionRetention box domain -> Maybe box
selectionRetentionInputBox retention = case retention of
  RetainedBoundedPositive receipt -> Just receipt
  _ -> Nothing

-- | The applicable-domain receipt of an established retention; 'Nothing' for
-- every other class.
selectionRetentionApplicableDomain
  :: SelectionRetention box domain
  -> Maybe domain
selectionRetentionApplicableDomain retention = case retention of
  RetainedApplicableDomainEstablished receipt -> Just receipt
  _ -> Nothing

-- | Exact replay authority for one rejected occurrence.  Simplification is
-- optional metadata; the ordinary receipt is always the final independently
-- replayed counterexample.  The domain's own counterexample types are the
-- parameters, so the two domains' rejections stay distinct.
data SelectionRejection counterexample simplification
  = SelectionRejection !counterexample !(Maybe simplification)
  deriving (Eq, Show)

type role SelectionRejection nominal nominal

-- | The independently replayed counterexample which rejected the occurrence;
-- the ordinary receipt regardless of any simplification.
selectionRejectionCounterexample
  :: SelectionRejection counterexample simplification
  -> counterexample
selectionRejectionCounterexample (SelectionRejection receipt _) = receipt

-- | The optional simplification metadata carried by the same ranked candidate
-- as the rejecting counterexample.
selectionRejectionSimplification
  :: SelectionRejection counterexample simplification
  -> Maybe simplification
selectionRejectionSimplification
  (SelectionRejection _ simplification) = simplification

-- | Either the untouched callback batch plus a sanitized failure, or one
-- sealed total partition.
data SelectionResult failure retention rejection
  = SelectionPreserved
      (VerificationBatch DetailedVerificationVariant)
      !failure
  | SelectionAccepted
      !(BehavioralSelectionBatch
          DetailedVerificationVariant
          retention
          rejection)

type role SelectionResult nominal nominal nominal

-- | Effective candidates after selection.  On every failure this is exactly
-- the original callback batch in original order; on success it is exactly the
-- selected partition in original callback order.
selectionCandidates
  :: SelectionResult failure retention rejection
  -> [Verified DetailedVerificationVariant]
selectionCandidates result = case result of
  SelectionPreserved verification _ -> verifiedCandidateReceipts verification
  SelectionAccepted batch ->
    map behaviorallySelectedVerified $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated selected occurrences, available only after the
-- total partition seal succeeded.
selectionSelected
  :: SelectionResult failure retention rejection
  -> Maybe [BehaviorallySelected DetailedVerificationVariant retention]
selectionSelected result = case result of
  SelectionPreserved {} -> Nothing
  SelectionAccepted batch -> Just $ behavioralSelectionBatchSelected batch

-- | Intrinsically associated rejected occurrences, available only after the
-- total partition seal succeeded.
selectionRejected
  :: SelectionResult failure retention rejection
  -> Maybe [BehaviorallyRejected DetailedVerificationVariant rejection]
selectionRejected result = case result of
  SelectionPreserved {} -> Nothing
  SelectionAccepted batch -> Just $ behavioralSelectionBatchRejected batch

-- | The sanitized failure which preserved the original batch, or 'Nothing'
-- when the total partition was sealed.
selectionFailure
  :: SelectionResult failure retention rejection
  -> Maybe failure
selectionFailure result = case result of
  SelectionPreserved _ failure -> Just failure
  SelectionAccepted {} -> Nothing

-- | Everything one domain contributes to the shared pipeline: how to read its
-- assessed post-verification result, how to name each fail-closed reason in
-- its own failure type, and how to classify one ranked report.  A domain
-- supplies exactly these; the control flow below is the same for both.
data SelectionDomain assessed ranked failure retention rejection =
  SelectionDomain
    { selectionAdapterFailure :: assessed -> Maybe failure
      -- ^ the sanitized adapter failure of an assessed batch, already named
      -- in the domain's failure type
    , selectionRankingFailure :: assessed -> Maybe failure
      -- ^ the sanitized ranking failure, likewise already named
    , selectionRanking :: assessed -> Maybe [ranked]
      -- ^ the ranked reports of a successful assessment
    , selectionRankingUnavailable :: failure
      -- ^ no ranking and no failure: the assessment reported neither
    , selectionIndexOutOfRange :: Natural -> Natural -> failure
      -- ^ a ranking report named an occurrence outside the fresh selection
      -- input; the count comes first, then the requested index
    , selectionSealFailed :: BehavioralSelectionError -> failure
      -- ^ the total partition could not be sealed
    , selectionOriginalIndex :: ranked -> Natural
      -- ^ the original callback index a ranked report belongs to
    , selectionClassify :: ranked -> Either rejection retention
      -- ^ 'Left' only for an independently replayed counterexample
    }

-- | Run one domain's assessment pipeline and reject only the candidates its
-- classifier names, preserving the supplied batch on every failure.
runSelectionWithAssessment
  :: SelectionDomain assessed ranked failure retention rejection
  -> (VerificationBatch DetailedVerificationVariant -> IO assessed)
  -> VerificationBatch DetailedVerificationVariant
  -> IO (SelectionResult failure retention rejection)
runSelectionWithAssessment domain assess verification = do
  assessed <- assess verification
  pure $ case selectionAdapterFailure domain assessed of
    Just failure -> preserve failure
    Nothing -> case selectionRankingFailure domain assessed of
      Just failure -> preserve failure
      Nothing -> case selectionRanking domain assessed of
        Nothing -> preserve $ selectionRankingUnavailable domain
        Just ranking -> withBehavioralSelectionInput verification $ \input ->
          let candidates = behavioralSelectionInputCandidates input
              candidateCount = count candidates
          in case buildDecisions domain candidateCount candidates ranking of
            Left failure -> preserve failure
            Right decisions -> case sealBehavioralSelectionBatch
                defaultLengthSMTLibLiveSessionMaximumQueries
                input decisions of
              Left failure -> preserve $ selectionSealFailed domain failure
              Right batch -> SelectionAccepted batch
 where
  preserve = SelectionPreserved verification

buildDecisions
  :: SelectionDomain assessed ranked failure retention rejection
  -> Natural
  -> [BehavioralSelectionCandidate epoch DetailedVerificationVariant]
  -> [ranked]
  -> Either
      failure
      [BehavioralSelectionDecision
        epoch DetailedVerificationVariant retention rejection]
buildDecisions domain candidateCount candidates = go []
 where
  go reversed remaining = case remaining of
    [] -> Right $ reverse reversed
    ranked : rest -> do
      candidate <- selectCandidate domain candidateCount candidates
        $ selectionOriginalIndex domain ranked
      let decision = case selectionClassify domain ranked of
            Left rejection ->
              rejectBehavioralSelectionCandidate candidate rejection
            Right retention ->
              retainBehavioralSelectionCandidate candidate retention
      decision `seq` go (decision : reversed) rest

selectCandidate
  :: SelectionDomain assessed ranked failure retention rejection
  -> Natural
  -> [BehavioralSelectionCandidate epoch DetailedVerificationVariant]
  -> Natural
  -> Either
      failure
      (BehavioralSelectionCandidate epoch DetailedVerificationVariant)
selectCandidate domain candidateCount = go 0
 where
  go _ [] requested = Left
    $ selectionIndexOutOfRange domain candidateCount requested
  go index (candidate : rest) requested
    | index == requested = Right candidate
    | otherwise = go (index + 1) rest requested

count :: [value] -> Natural
count = go 0
 where
  go result remaining = case remaining of
    [] -> result
    _ : rest -> go (result + 1) rest
