{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live binary-product
-- finite-spine Length ranking.  This is a nominal sibling of the scalar
-- ranking implementation: it shares only domain-neutral policy, admission,
-- and diagnostic vocabulary.  Its additive post-assessment preference keeps
-- pair receipts and occurrence handles nominal throughout the stable
-- non-vacuous-positive/neutral/counterexample trichotomy.
module Leant.Synth.Length.SpinePair.Ranking.Internal
  ( LengthSpinePairRankingAssessment (..)
  , lengthSpinePairHandoffPreparationRefusalClass
  , lengthSpinePairQueryPreparationRefusalClass
  , RankedLengthSpinePairCandidate
  , rankedLengthSpinePairCandidateOriginalIndex
  , rankedLengthSpinePairCandidateVerified
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidatePreparationRefusal
  , LengthSpinePairRankingFailureClass (..)
  , LengthSpinePairRankingFailure
  , lengthSpinePairRankingFailureClass
  , lengthSpinePairRankingFailureCleanupIncomplete
  , lengthSpinePairRankingFailureOriginalIndex
  , LengthSpinePairRanking
  , lengthSpinePairRankingCandidates
  , lengthSpinePairRankingFailure
  , preferNonVacuousBoundedPositiveLengthSpinePairRanking
  , AssociatedRankedLengthSpinePairCandidate
  , associatedRankedLengthSpinePairCandidateAssociation
  , AssociatedLengthSpinePairRanking
  , associatedLengthSpinePairRankingCandidates
  , preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  , PostVerificationLengthSpinePairRanking
  , sealPostVerificationLengthSpinePairRanking
  , postVerificationLengthSpinePairRankingBatch
  , postVerificationLengthSpinePairRankingFailure
  , materializePostVerificationLengthSpinePairRanking
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankPostVerificationLengthSpinePairCandidates
  , rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , promoteLengthSpinePairCounterexampleSeed
  , replayLengthSpinePairCounterexampleSeeds
  ) where

import Control.DeepSeq (force)
import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , LengthSpinePairEvaluationError
  , LengthSpinePairInputBoxValidationError
  , LengthSpinePairSMTLibInputBoxValidationError (..)
  , LengthSpinePairSMTLibInputReplayError (..)
  , LengthSpinePairSMTLibLiveObservationReplayError (..)
  , LengthSpinePairSMTLibLiveQueryError
  , LengthSpinePairSMTLibLiveQueryFailure
  , LengthSpinePairSMTLibLiveQueryObservation
  , LengthSpinePairSMTLibQueryError (..)
  , SolverStatus (..)
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairInputBox
  , defaultLengthSMTLibLiveSessionMaximumQueries
  , lengthSMTLibLiveSessionCleanupIncomplete
  , lengthSMTLibLiveSessionPrimaryFailure
  , lengthSpinePairSMTLibLiveQueryCleanupIncomplete
  , lengthSpinePairSMTLibLiveQueryObservationSolverStatus
  , lengthSpinePairSMTLibLiveQueryPrimaryFailure
  , probeLengthSpinePairSMTLibCounterexampleAtOrigin
  , replayLengthSpinePairSMTLibCounterexampleInputs
  , replayLengthSpinePairSMTLibLiveQueryObservation
  , runLengthSpinePairSMTLibLiveQuery
  , validateLengthSpinePairSMTLibQueryInputBox
  , validatedLengthSpinePairCounterexampleInputs
  , validatedLengthSpinePairInputBoxApplicableAssignmentCount
  , withLengthSMTLibLiveSession
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Adapter
  ( CheckedLengthSpinePairQuery
  , prepareCheckedLengthSpinePairQuery
  )
import Leant.Synth.Length.Contract (LeanLengthSpinePairContract)
import Leant.Synth.Length.Handoff
  ( LengthSpinePairHandoffRefusal (..))
import Leant.Synth.Length.Ranking.Internal
  ( LengthPreparationRefusalClass (..)
  , LengthRankingInputError (..)
  , lengthHandoffPreparationRefusalClass
  )
import Leant.Synth.PostVerification
  ( PostVerificationBatch
  , PostVerificationCandidate
  , PostVerificationError
  , PostVerificationInput
  , postVerificationBatchCandidates
  , postVerificationCandidateVerified
  , sealPostVerificationBatch
  )
import Leant.Synth.Verification (Verified)

-- | Pair-domain assessment strengths.  Only independently replayed
-- counterexamples affect ordering.
data LengthSpinePairRankingAssessment
  = LengthSpinePairUnassessed
  | LengthSpinePairHeuristic !SolverStatus
  | LengthSpinePairCounterexample
      !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairBoundedPositive !ValidatedLengthSpinePairInputBox
  deriving (Eq, Show)

data LengthSpinePairCandidateAssessment
  = LengthSpinePairCandidatePreparationRefused
      !LengthPreparationRefusalClass
  | LengthSpinePairCandidateAssessed !LengthSpinePairRankingAssessment

data RankedLengthSpinePairCandidate = RankedLengthSpinePairCandidate
  !Natural
  !(Verified DetailedVerificationVariant)
  !LengthSpinePairCandidateAssessment

rankedLengthSpinePairCandidateOriginalIndex
  :: RankedLengthSpinePairCandidate
  -> Natural
rankedLengthSpinePairCandidateOriginalIndex
    (RankedLengthSpinePairCandidate index _ _) = index

rankedLengthSpinePairCandidateVerified
  :: RankedLengthSpinePairCandidate
  -> Verified DetailedVerificationVariant
rankedLengthSpinePairCandidateVerified
    (RankedLengthSpinePairCandidate _ verified _) = verified

rankedLengthSpinePairCandidateAssessment
  :: RankedLengthSpinePairCandidate
  -> LengthSpinePairRankingAssessment
rankedLengthSpinePairCandidateAssessment
    (RankedLengthSpinePairCandidate _ _ state) =
  spinePairCandidateAssessment state

rankedLengthSpinePairCandidatePreparationRefusal
  :: RankedLengthSpinePairCandidate
  -> Maybe LengthPreparationRefusalClass
rankedLengthSpinePairCandidatePreparationRefusal
    (RankedLengthSpinePairCandidate _ _ state) =
  spinePairCandidatePreparationRefusal state

spinePairCandidateAssessment
  :: LengthSpinePairCandidateAssessment
  -> LengthSpinePairRankingAssessment
spinePairCandidateAssessment state = case state of
  LengthSpinePairCandidatePreparationRefused _ ->
    LengthSpinePairUnassessed
  LengthSpinePairCandidateAssessed assessment -> assessment

spinePairCandidatePreparationRefusal
  :: LengthSpinePairCandidateAssessment
  -> Maybe LengthPreparationRefusalClass
spinePairCandidatePreparationRefusal state = case state of
  LengthSpinePairCandidatePreparationRefused refusal -> Just refusal
  LengthSpinePairCandidateAssessed _ -> Nothing

data LengthSpinePairRankingFailureClass
  = LengthSpinePairRankingLiveSessionFailed
      !LengthSMTLibLiveSessionFailure
  | LengthSpinePairRankingLiveQueryFailed
      !LengthSpinePairSMTLibLiveQueryFailure
  | LengthSpinePairRankingQueryAssociationMismatch
  | LengthSpinePairRankingEvidenceReplayMismatch
  | LengthSpinePairRankingOriginProbeEvaluationFailed
      !LengthSpinePairEvaluationError
  | LengthSpinePairRankingInputBoxValidationFailed
      !LengthSpinePairInputBoxValidationError
  deriving (Eq, Ord, Show)

data LengthSpinePairRankingFailure = LengthSpinePairRankingFailure
  !LengthSpinePairRankingFailureClass
  !Bool
  !(Maybe Natural)
  deriving (Eq, Ord, Show)

lengthSpinePairRankingFailureClass
  :: LengthSpinePairRankingFailure
  -> LengthSpinePairRankingFailureClass
lengthSpinePairRankingFailureClass
    (LengthSpinePairRankingFailure failure _ _) = failure

lengthSpinePairRankingFailureCleanupIncomplete
  :: LengthSpinePairRankingFailure
  -> Bool
lengthSpinePairRankingFailureCleanupIncomplete
    (LengthSpinePairRankingFailure _ incomplete _) = incomplete

lengthSpinePairRankingFailureOriginalIndex
  :: LengthSpinePairRankingFailure
  -> Maybe Natural
lengthSpinePairRankingFailureOriginalIndex
    (LengthSpinePairRankingFailure _ _ index) = index

data LengthSpinePairRanking = LengthSpinePairRanking
  ![RankedLengthSpinePairCandidate]
  !(Maybe LengthSpinePairRankingFailure)

lengthSpinePairRankingCandidates
  :: LengthSpinePairRanking
  -> [RankedLengthSpinePairCandidate]
lengthSpinePairRankingCandidates
    (LengthSpinePairRanking candidates _) = candidates

lengthSpinePairRankingFailure
  :: LengthSpinePairRanking
  -> Maybe LengthSpinePairRankingFailure
lengthSpinePairRankingFailure
    (LengthSpinePairRanking _ failure) = failure

data AssociatedRankedLengthSpinePairCandidate association =
  AssociatedRankedLengthSpinePairCandidate
    !Natural
    !association
    !LengthSpinePairCandidateAssessment

type role AssociatedRankedLengthSpinePairCandidate nominal

associatedRankedLengthSpinePairCandidateAssociation
  :: AssociatedRankedLengthSpinePairCandidate association
  -> association
associatedRankedLengthSpinePairCandidateAssociation
    (AssociatedRankedLengthSpinePairCandidate _ association _) = association

data AssociatedLengthSpinePairRanking association =
  AssociatedLengthSpinePairRanking
    ![AssociatedRankedLengthSpinePairCandidate association]
    !(Maybe LengthSpinePairRankingFailure)

type role AssociatedLengthSpinePairRanking nominal

associatedLengthSpinePairRankingCandidates
  :: AssociatedLengthSpinePairRanking association
  -> [AssociatedRankedLengthSpinePairCandidate association]
associatedLengthSpinePairRankingCandidates
    (AssociatedLengthSpinePairRanking candidates _) = candidates

projectAssociatedLengthSpinePairRankingWith
  :: (association -> Verified DetailedVerificationVariant)
  -> AssociatedLengthSpinePairRanking association
  -> LengthSpinePairRanking
projectAssociatedLengthSpinePairRankingWith verifiedFor
    (AssociatedLengthSpinePairRanking candidates failure) =
  LengthSpinePairRanking (go [] candidates) failure
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthSpinePairCandidate index association state : rest ->
      let projected = RankedLengthSpinePairCandidate
            index (verifiedFor association) state
      in projected `seq` go (projected : reversed) rest

data PostVerificationLengthSpinePairRanking =
  PostVerificationLengthSpinePairRanking
    !(PostVerificationBatch DetailedVerificationVariant)
    ![PostVerificationLengthSpinePairCandidateSummary]
    !(Maybe LengthSpinePairRankingFailure)

data PostVerificationLengthSpinePairCandidateSummary =
  PostVerificationLengthSpinePairCandidateSummary
    !Natural
    !LengthSpinePairCandidateAssessment

sealPostVerificationLengthSpinePairRanking
  :: Natural
  -> PostVerificationInput epoch DetailedVerificationVariant
  -> AssociatedLengthSpinePairRanking
      (PostVerificationCandidate epoch DetailedVerificationVariant)
  -> Either PostVerificationError PostVerificationLengthSpinePairRanking
sealPostVerificationLengthSpinePairRanking maximumCandidates input associated =
    do
  batch <- sealPostVerificationBatch maximumCandidates input
    $ map associatedRankedLengthSpinePairCandidateAssociation
    $ associatedLengthSpinePairRankingCandidates associated
  pure $ retain batch associated
 where
  retain batch
      (AssociatedLengthSpinePairRanking candidates failure) =
    PostVerificationLengthSpinePairRanking batch
      (projectCandidates [] candidates) failure

  projectCandidates reversed remaining = case remaining of
    [] -> reverse reversed
    AssociatedRankedLengthSpinePairCandidate
        index association state : rest ->
      let verified = postVerificationCandidateVerified association
          projected = PostVerificationLengthSpinePairCandidateSummary
            index state
      in verified `seq` projected `seq`
          projectCandidates (projected : reversed) rest

postVerificationLengthSpinePairRankingBatch
  :: PostVerificationLengthSpinePairRanking
  -> PostVerificationBatch DetailedVerificationVariant
postVerificationLengthSpinePairRankingBatch
    (PostVerificationLengthSpinePairRanking batch _ _) = batch

postVerificationLengthSpinePairRankingFailure
  :: PostVerificationLengthSpinePairRanking
  -> Maybe LengthSpinePairRankingFailure
postVerificationLengthSpinePairRankingFailure
    (PostVerificationLengthSpinePairRanking _ _ failure) = failure

materializePostVerificationLengthSpinePairRanking
  :: PostVerificationLengthSpinePairRanking
  -> LengthSpinePairRanking
materializePostVerificationLengthSpinePairRanking
    (PostVerificationLengthSpinePairRanking batch summaries failure) =
  LengthSpinePairRanking
    (materialize [] (postVerificationBatchCandidates batch) summaries)
    failure
 where
  materialize reversed verifiedRemaining summaryRemaining =
    case (verifiedRemaining, summaryRemaining) of
      ([], []) -> reverse reversed
      (verified : verifiedRest,
          PostVerificationLengthSpinePairCandidateSummary
            index state : summaryRest) ->
        let projected = RankedLengthSpinePairCandidate index verified state
        in projected `seq` materialize
            (projected : reversed) verifiedRest summaryRest
      _ -> error
        "sealed product post-verification ranking summary cardinality changed"

data PreparedLengthSpinePairCandidate association
  = PreparedLengthSpinePairCandidateUnassessed
      !Natural
      !association
      !LengthPreparationRefusalClass
  | PreparedLengthSpinePairCandidateEligible
      !Natural
      !association
      !CheckedLengthSpinePairQuery

data LengthSpinePairInputBoxRankingPolicy
  = LengthSpinePairInputBoxRankingDisabled
  | LengthSpinePairInputBoxRankingEnabled
      !LengthInputBoxLimits [Natural]

data LengthSpinePairOriginProbeRankingPolicy
  = LengthSpinePairOriginProbeRankingDisabled
  | LengthSpinePairOriginProbeRankingEnabled

rankVerifiedLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidates execution evaluation contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        execution evaluation contract id candidates

rankVerifiedLengthSpinePairCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithOriginProbe
    execution evaluation contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        LengthSpinePairInputBoxRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        execution evaluation contract id candidates

rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
    execution evaluation limits maximums contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairOriginProbeRankingDisabled
        execution evaluation contract id candidates

rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums contract candidates =
  fmap (fmap $ projectAssociatedLengthSpinePairRankingWith id)
    $ rankAssociatedLengthSpinePairCandidates
        (LengthSpinePairInputBoxRankingEnabled limits maximums)
        LengthSpinePairOriginProbeRankingEnabled
        execution evaluation contract id candidates

rankPostVerificationLengthSpinePairCandidates
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidates execution evaluation contract =
  rankAssociatedLengthSpinePairCandidates
    LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairOriginProbeRankingDisabled
    execution evaluation contract postVerificationCandidateVerified

rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
    execution evaluation contract =
  rankAssociatedLengthSpinePairCandidates
    LengthSpinePairInputBoxRankingDisabled
    LengthSpinePairOriginProbeRankingEnabled
    execution evaluation contract postVerificationCandidateVerified

rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
    execution evaluation limits maximums contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairOriginProbeRankingDisabled
    execution evaluation contract postVerificationCandidateVerified

rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthInputBoxLimits
  -> [Natural]
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
    execution evaluation limits maximums contract =
  rankAssociatedLengthSpinePairCandidates
    (LengthSpinePairInputBoxRankingEnabled limits maximums)
    LengthSpinePairOriginProbeRankingEnabled
    execution evaluation contract postVerificationCandidateVerified

rankAssociatedLengthSpinePairCandidates
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidates inputBoxPolicy originProbePolicy
    execution evaluation contract verifiedFor associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> case
        prepareLengthSpinePairCandidates contract verifiedFor admitted of
      [] -> pure $ Right $ AssociatedLengthSpinePairRanking [] Nothing
      prepared
        | not $ hasEligibleLengthSpinePairCandidate prepared -> pure $ Right
            $ AssociatedLengthSpinePairRanking
                (map preparedLengthSpinePairCandidateUnassessed prepared)
                Nothing
        | otherwise -> do
            scoped <- withLengthSMTLibLiveSession execution $ \session ->
              runPreparedLengthSpinePairCandidates evaluation inputBoxPolicy
                originProbePolicy session prepared
            pure $ Right $ case scoped of
              Left failure -> unassessedLengthSpinePairRanking prepared
                $ lengthSpinePairSessionRankingFailure failure
              Right (Left failure) ->
                unassessedLengthSpinePairRanking prepared failure
              Right (Right assessed) -> AssociatedLengthSpinePairRanking
                (stableLengthSpinePairCounterexampleDemotion assessed) Nothing

admitLengthSpinePairCandidates
  :: Natural
  -> [candidate]
  -> Either LengthRankingInputError [candidate]
admitLengthSpinePairCandidates maximumCandidates = go 0 []
 where
  go observed reversed remaining
    | observed >= maximumCandidates = case remaining of
        [] -> Right $ reverse reversed
        _ : _ -> Left $ LengthRankingInputLimitExceeded
          maximumCandidates (maximumCandidates + 1)
    | otherwise = case remaining of
        [] -> Right $ reverse reversed
        candidate : rest -> go (observed + 1) (candidate : reversed) rest

prepareLengthSpinePairCandidates
  :: LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> [PreparedLengthSpinePairCandidate association]
prepareLengthSpinePairCandidates contract verifiedFor = go 0 []
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let prepared = prepareCandidate index association
    in prepared `seq` go (index + 1) (prepared : reversed) rest

  prepareCandidate index association =
    let verified = verifiedFor association
    in case prepareCheckedLengthSpinePairQuery contract verified of
      Left refusal -> PreparedLengthSpinePairCandidateUnassessed
        index association
          $ lengthSpinePairHandoffPreparationRefusalClass refusal
      Right (Left refusal) -> PreparedLengthSpinePairCandidateUnassessed
        index association
          $ lengthSpinePairQueryPreparationRefusalClass refusal
      Right (Right query) -> PreparedLengthSpinePairCandidateEligible
        index association query

hasEligibleLengthSpinePairCandidate
  :: [PreparedLengthSpinePairCandidate association]
  -> Bool
hasEligibleLengthSpinePairCandidate = any isEligible
 where
  isEligible prepared = case prepared of
    PreparedLengthSpinePairCandidateUnassessed {} -> False
    PreparedLengthSpinePairCandidateEligible {} -> True

preparedLengthSpinePairCandidateUnassessed
  :: PreparedLengthSpinePairCandidate association
  -> AssociatedRankedLengthSpinePairCandidate association
preparedLengthSpinePairCandidateUnassessed prepared = case prepared of
  PreparedLengthSpinePairCandidateUnassessed index association refusal ->
    AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidatePreparationRefused refusal
  PreparedLengthSpinePairCandidateEligible index association _ ->
    AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed LengthSpinePairUnassessed

runPreparedLengthSpinePairCandidates
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSpinePairRankingFailure
        [AssociatedRankedLengthSpinePairCandidate association])
runPreparedLengthSpinePairCandidates evaluation inputBoxPolicy
    originProbePolicy session = go [] []
 where
  go reversed seedBank remaining = case remaining of
    [] -> pure $ Right $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      go (AssociatedRankedLengthSpinePairCandidate index association
            (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        seedBank rest
    PreparedLengthSpinePairCandidateEligible index association query : rest ->
      case replayLengthSpinePairCounterexampleSeeds
          evaluation query seedBank of
        Just (inputs, receipt) ->
          let promoted = promoteLengthSpinePairCounterexampleSeed inputs seedBank
          in promoted `seq` go
              (assessedLengthSpinePairCounterexample
                index association receipt : reversed)
              promoted rest
        Nothing -> case probeLengthSpinePairOriginCounterexample
            evaluation originProbePolicy query of
          Left (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
            pure $ Left $ localLengthSpinePairRankingFailure
              (LengthSpinePairRankingOriginProbeEvaluationFailed failure) index
          Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
            pure $ Left $ localLengthSpinePairRankingFailure
              LengthSpinePairRankingEvidenceReplayMismatch index
          Right (Just receipt) ->
            let inputs = validatedLengthSpinePairCounterexampleInputs receipt
                promoted = promoteLengthSpinePairCounterexampleSeed
                  inputs seedBank
            in promoted `seq` go
                (assessedLengthSpinePairCounterexample
                  index association receipt : reversed)
                promoted rest
          Right Nothing -> do
            observed <- runLengthSpinePairSMTLibLiveQuery
              evaluation session query
            case observed of
              Left failure -> pure $ Left
                $ lengthSpinePairQueryRankingFailure index failure
              Right observation -> case assessLengthSpinePairCandidate
                  evaluation inputBoxPolicy index association query observation of
                Left failure -> pure $ Left failure
                Right assessed ->
                  let nextSeedBank = case
                        lengthSpinePairCounterexampleSeed assessed of
                        Nothing -> seedBank
                        Just retained ->
                          promoteLengthSpinePairCounterexampleSeed
                            retained seedBank
                  in nextSeedBank `seq`
                      go (assessed : reversed) nextSeedBank rest

probeLengthSpinePairOriginCounterexample
  :: LengthEvaluationLimits
  -> LengthSpinePairOriginProbeRankingPolicy
  -> CheckedLengthSpinePairQuery
  -> Either LengthSpinePairSMTLibInputReplayError
      (Maybe ValidatedLengthSpinePairCounterexample)
probeLengthSpinePairOriginCounterexample evaluation policy query = case policy of
  LengthSpinePairOriginProbeRankingDisabled -> Right Nothing
  LengthSpinePairOriginProbeRankingEnabled ->
    probeLengthSpinePairSMTLibCounterexampleAtOrigin evaluation query

replayLengthSpinePairCounterexampleSeeds
  :: LengthEvaluationLimits
  -> CheckedLengthSpinePairQuery
  -> [[Natural]]
  -> Maybe ([Natural], ValidatedLengthSpinePairCounterexample)
replayLengthSpinePairCounterexampleSeeds evaluation query =
  go lengthSpinePairCounterexampleSeedBankMaximumEntries
 where
  go remaining seedBank
    | remaining <= 0 = Nothing
    | otherwise = case seedBank of
        [] -> Nothing
        inputs : rest -> case
            replayLengthSpinePairSMTLibCounterexampleInputs
              evaluation query inputs of
          Right (Just receipt) -> Just (inputs, receipt)
          Left (LengthSpinePairSMTLibInputReplayEvaluationRejected _) ->
            go (remaining - 1) rest
          Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
            go (remaining - 1) rest
          Right Nothing -> go (remaining - 1) rest

lengthSpinePairCounterexampleSeedBankMaximumEntries :: Int
lengthSpinePairCounterexampleSeedBankMaximumEntries = 4

promoteLengthSpinePairCounterexampleSeed
  :: [Natural]
  -> [[Natural]]
  -> [[Natural]]
promoteLengthSpinePairCounterexampleSeed inputs seedBank = force $
  inputs : take (lengthSpinePairCounterexampleSeedBankMaximumEntries - 1)
    (filter (/= inputs) seedBank)

assessedLengthSpinePairCounterexample
  :: Natural
  -> association
  -> ValidatedLengthSpinePairCounterexample
  -> AssociatedRankedLengthSpinePairCandidate association
assessedLengthSpinePairCounterexample index association receipt =
  AssociatedRankedLengthSpinePairCandidate index association
    $ LengthSpinePairCandidateAssessed
    $ LengthSpinePairCounterexample receipt

lengthSpinePairCounterexampleSeed
  :: AssociatedRankedLengthSpinePairCandidate association
  -> Maybe [Natural]
lengthSpinePairCounterexampleSeed
    (AssociatedRankedLengthSpinePairCandidate _ _ state) = case state of
  LengthSpinePairCandidateAssessed
      (LengthSpinePairCounterexample receipt) ->
    Just $ validatedLengthSpinePairCounterexampleInputs receipt
  _ -> Nothing

assessLengthSpinePairCandidate
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> LengthSpinePairSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthSpinePairRankingFailure
      (AssociatedRankedLengthSpinePairCandidate association)
assessLengthSpinePairCandidate evaluation inputBoxPolicy index association
    query observation = do
  assessment <- case
      replayLengthSpinePairSMTLibLiveQueryObservation query observation of
    Left LengthSpinePairSMTLibLiveObservationQueryFingerprintMismatch ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingQueryAssociationMismatch index
    Left LengthSpinePairSMTLibLiveObservationEvidenceProblemMismatch {} ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Right Nothing -> assessStatus
      $ lengthSpinePairSMTLibLiveQueryObservationSolverStatus observation
    Right (Just receipt) -> Right
      $ LengthSpinePairCounterexample receipt
  pure $ AssociatedRankedLengthSpinePairCandidate index association
    $ LengthSpinePairCandidateAssessed assessment
 where
  assessStatus status = case (status, inputBoxPolicy) of
    (SolverUnsatisfiable,
        LengthSpinePairInputBoxRankingEnabled limits maximums) ->
      case validateLengthSpinePairSMTLibQueryInputBox
          evaluation limits query maximums of
        Left (LengthSpinePairSMTLibInputBoxValidationRejected failure) ->
          Left $ localLengthSpinePairRankingFailure
            (LengthSpinePairRankingInputBoxValidationFailed failure) index
        Left
            (LengthSpinePairSMTLibInputBoxValidationAssociationRejected _) ->
          Left $ localLengthSpinePairRankingFailure
            LengthSpinePairRankingEvidenceReplayMismatch index
        Right (LengthInputBoxCounterexample receipt) -> Right
          $ LengthSpinePairCounterexample receipt
        Right (LengthInputBoxValidated receipt) -> Right
          $ LengthSpinePairBoundedPositive receipt
    _ -> Right $ LengthSpinePairHeuristic status

stableLengthSpinePairCounterexampleDemotion
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
stableLengthSpinePairCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    case spinePairCandidateAssessment state of
      LengthSpinePairCounterexample _ -> True
      LengthSpinePairBoundedPositive _ -> False
      _ -> False

-- | Additive evidence-ordering opt-in for an association-free successful
-- product ranking.  Only a finite-box receipt with at least one applicable
-- assignment enters the preferred partition.  Vacuous receipts stay neutral,
-- counterexamples stay last, and every partition remains stable.
preferNonVacuousBoundedPositiveLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousBoundedPositiveLengthSpinePairRanking ranking = case ranking of
  LengthSpinePairRanking _ (Just _) -> ranking
  LengthSpinePairRanking candidates Nothing -> LengthSpinePairRanking
    (preferNonVacuousBoundedPositiveLengthSpinePairCandidates candidates)
    Nothing

-- | Occurrence-associated product sibling applied before the generative
-- permutation seal.  No candidate/evidence association is projected or
-- reconstructed while the stable trichotomy is selected.
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking ranking =
  case ranking of
    AssociatedLengthSpinePairRanking _ (Just _) -> ranking
    AssociatedLengthSpinePairRanking candidates Nothing ->
      AssociatedLengthSpinePairRanking
        (preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates
          candidates)
        Nothing

preferNonVacuousBoundedPositiveLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
preferNonVacuousBoundedPositiveLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableRankedLengthSpinePairCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive
      (RankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairBoundedPositive
      $ spinePairCandidateAssessment state

preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
preferNonVacuousBoundedPositiveAssociatedLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasNonVacuousBoundedPositive candidates
  in positive ++ stableLengthSpinePairCounterexampleDemotion retained
 where
  hasNonVacuousBoundedPositive
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairBoundedPositive
      $ spinePairCandidateAssessment state

stableRankedLengthSpinePairCounterexampleDemotion
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
stableRankedLengthSpinePairCounterexampleDemotion candidates =
  let (counterexamples, retained) = partition hasCounterexample candidates
  in retained ++ counterexamples
 where
  hasCounterexample (RankedLengthSpinePairCandidate _ _ state) = case
      spinePairCandidateAssessment state of
    LengthSpinePairCounterexample _ -> True
    _ -> False

isNonVacuousLengthSpinePairBoundedPositive
  :: LengthSpinePairRankingAssessment
  -> Bool
isNonVacuousLengthSpinePairBoundedPositive assessment = case assessment of
  LengthSpinePairBoundedPositive receipt ->
    validatedLengthSpinePairInputBoxApplicableAssignmentCount receipt > 0
  _ -> False

unassessedLengthSpinePairRanking
  :: [PreparedLengthSpinePairCandidate association]
  -> LengthSpinePairRankingFailure
  -> AssociatedLengthSpinePairRanking association
unassessedLengthSpinePairRanking prepared failure =
  AssociatedLengthSpinePairRanking
    (sanitizePreparedLengthSpinePairCandidates prepared)
    (Just failure)

sanitizePreparedLengthSpinePairCandidates
  :: [PreparedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
sanitizePreparedLengthSpinePairCandidates = go []
 where
  go reversed remaining = case remaining of
    [] -> reverse reversed
    candidate : rest ->
      let sanitized = preparedLengthSpinePairCandidateUnassessed candidate
      in sanitized `seq` go (sanitized : reversed) rest

lengthSpinePairHandoffPreparationRefusalClass
  :: LengthSpinePairHandoffRefusal
  -> LengthPreparationRefusalClass
lengthSpinePairHandoffPreparationRefusalClass refusal = case refusal of
  LengthSpinePairHandoffSharedRefusal shared ->
    lengthHandoffPreparationRefusalClass shared
  LengthSpinePairHandoffResultNotCanonicalLeanProd ->
    LengthPreparationCandidateAssociationRejected
  LengthSpinePairHandoffComponentNotConfiguredSpine _ _ ->
    LengthPreparationSpineBindingUnavailable
  LengthSpinePairHandoffContractRejected _ ->
    LengthPreparationContractRejected
  LengthSpinePairHandoffProblemRejected _ ->
    LengthPreparationCandidateSemanticsRejected

lengthSpinePairQueryPreparationRefusalClass
  :: LengthSpinePairSMTLibQueryError
  -> LengthPreparationRefusalClass
lengthSpinePairQueryPreparationRefusalClass refusal = case refusal of
  LengthSpinePairSMTLibUnexpectedResultVariable -> rejected
  LengthSpinePairSMTLibInputVariableOutOfRange _ _ -> rejected
  LengthSpinePairSMTLibQuotientDivisorZero -> rejected
  LengthSpinePairSMTLibModuloDivisorZero -> rejected
  LengthSpinePairSMTLibNumeralBitLimitExceeded _ _ _ -> rejected
  LengthSpinePairSMTLibCommandByteLimitExceeded _ _ _ -> rejected
  LengthSpinePairSMTLibFingerprintByteLimitExceeded _ _ -> rejected
 where
  rejected = LengthPreparationQueryConstructionRejected

localLengthSpinePairRankingFailure
  :: LengthSpinePairRankingFailureClass
  -> Natural
  -> LengthSpinePairRankingFailure
localLengthSpinePairRankingFailure failure index =
  LengthSpinePairRankingFailure failure False $ Just index

lengthSpinePairSessionRankingFailure
  :: LengthSMTLibLiveSessionError
  -> LengthSpinePairRankingFailure
lengthSpinePairSessionRankingFailure failure =
  LengthSpinePairRankingFailure
    (LengthSpinePairRankingLiveSessionFailed
      $ lengthSMTLibLiveSessionPrimaryFailure failure)
    (lengthSMTLibLiveSessionCleanupIncomplete failure)
    Nothing

lengthSpinePairQueryRankingFailure
  :: Natural
  -> LengthSpinePairSMTLibLiveQueryError
  -> LengthSpinePairRankingFailure
lengthSpinePairQueryRankingFailure index failure =
  LengthSpinePairRankingFailure
    (LengthSpinePairRankingLiveQueryFailed
      $ lengthSpinePairSMTLibLiveQueryPrimaryFailure failure)
    (lengthSpinePairSMTLibLiveQueryCleanupIncomplete failure)
    (Just index)
