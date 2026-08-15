{-# LANGUAGE RoleAnnotations #-}

-- | Package-private implementation of conservative live binary-product
-- finite-spine Length ranking.  This is a nominal sibling of the scalar
-- ranking implementation: it shares only domain-neutral policy, admission,
-- and diagnostic vocabulary.  Its additive post-assessment preference keeps
-- pair receipts and occurrence handles nominal throughout the stable
-- non-vacuous-positive/neutral/counterexample trichotomy.
-- Its additive usable-work entrance is the nominal product sibling of the
-- scalar owner: admission precedes capture, preparation and live work share
-- one deadline, and the outer normal-return check observes the completed
-- nested final-readiness/cleanup stages without interrupting them.
module Leant.Synth.Length.SpinePair.Ranking.Internal
  ( LengthSpinePairRankingAssessment (..)
  , lengthSpinePairHandoffPreparationRefusalClass
  , lengthSpinePairQueryPreparationRefusalClass
  , RankedLengthSpinePairCandidate
  , rankedLengthSpinePairCandidateOriginalIndex
  , rankedLengthSpinePairCandidateVerified
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidateCounterexampleSimplification
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
  , preferNonVacuousApplicableDomainLengthSpinePairRanking
  , AssociatedRankedLengthSpinePairCandidate
  , associatedRankedLengthSpinePairCandidateAssociation
  , AssociatedLengthSpinePairRanking
  , associatedLengthSpinePairRankingCandidates
  , preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  , preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
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
  , LengthSpinePairInputBoxRankingPolicy (..)
  , LengthSpinePairApplicableDomainRankingPolicy (..)
  , LengthSpinePairOriginProbeRankingPolicy (..)
  , LengthSpinePairCounterexampleSimplificationRankingPolicy (..)
  , rankVerifiedLengthSpinePairCandidatesWithRankingPolicies
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  , rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  , promoteLengthSpinePairCounterexampleSeed
  , replayLengthSpinePairCounterexampleSeeds
  ) where

import Control.DeepSeq (NFData (rnf), force)
import Control.Exception (evaluate)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (partition)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( ExferenceLocal
  , LengthBooleanFiniteUnionLimits
  , LengthApplicableDomainValidation (..)
  , LengthEvaluationLimits
  , LengthInputBoxLimits
  , LengthInputBoxValidation (..)
  , LengthSMTLibExecutionConfig
  , LengthSMTLibLiveSession
  , LengthSMTLibLiveSessionError
  , LengthSMTLibLiveSessionFailure
  , LengthSMTLibLiveScopedUsableWorkDeadline
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSMTLibLiveUsableWorkDeadline
  , LengthSpinePairEvaluationError
  , LengthSpinePairCounterexampleSimplificationError (..)
  , LengthSpinePairApplicableDomainValidationError (..)
  , LengthSpinePairBooleanFiniteUnionApplicableDomainValidationError (..)
  , LengthSpinePairInputBoxValidationError (..)
  , LengthSpinePairSMTLibApplicableDomainValidationError (..)
  , LengthSpinePairSMTLibBooleanFiniteUnionApplicableDomainValidationError (..)
  , LengthSpinePairSMTLibCounterexampleSimplificationError (..)
  , LengthSpinePairSMTLibInputBoxValidationError (..)
  , LengthSpinePairSMTLibInputReplayError (..)
  , LengthSpinePairSMTLibLiveObservationReplayError (..)
  , LengthSpinePairSMTLibLiveQueryError
  , LengthSpinePairSMTLibLiveQueryFailure
  , LengthSpinePairSMTLibLiveQueryObservation
  , LengthSpinePairSMTLibQueryError (..)
  , SolverStatus (..)
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairInputBox
  , ValidatedLengthSpinePairPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairRelationalPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
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
  , simplifyLengthSpinePairSMTLibQueryCounterexample
  , validateLengthSpinePairSMTLibQueryApplicableDomain
  , validateLengthSpinePairSMTLibQueryPositiveAffineApplicableDomain
  , validateLengthSpinePairSMTLibQueryRelationalPositiveAffineApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  , validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  , validateLengthSpinePairSMTLibQueryInputBox
  , validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairCounterexampleInputs
  , validatedLengthSpinePairCounterexampleSimplificationCounterexample
  , validatedLengthSpinePairInputBoxApplicableAssignmentCount
  , validatedLengthSpinePairPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
  , checkLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveSession
  , withLengthSMTLibLiveSessionUnderScopedDeadline
  , withLengthSMTLibLiveSessionUnderDeadline
  , withLengthSMTLibLiveScopedUsableWorkDeadline
  , withLengthSMTLibLiveUsableWorkDeadline
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
  ( LengthLiveSessionOpeningPolicy (..)
  , LengthPreparationRefusalClass (..)
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

-- | Pair-domain assessment strengths.  Positive receipts affect ordering only
-- through their independent additive preferences; every independently
-- replayed counterexample remains stably demoted.
data LengthSpinePairRankingAssessment
  = LengthSpinePairUnassessed
  | LengthSpinePairHeuristic !SolverStatus
  | LengthSpinePairCounterexample
      !ValidatedLengthSpinePairCounterexample
  | LengthSpinePairBoundedPositive !ValidatedLengthSpinePairInputBox
  | LengthSpinePairApplicableDomainEstablished
      !ValidatedLengthSpinePairApplicableDomain
  | LengthSpinePairPositiveAffineApplicableDomainEstablished
      !ValidatedLengthSpinePairPositiveAffineApplicableDomain
  | LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished
      !ValidatedLengthSpinePairRelationalPositiveAffineApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  | LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
      !ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  deriving (Eq, Show)

data LengthSpinePairCandidateAssessment
  = LengthSpinePairCandidatePreparationRefused
      !LengthPreparationRefusalClass
  | LengthSpinePairCandidateAssessed
      !LengthSpinePairRankingAssessment
      !(Maybe ValidatedLengthSpinePairCounterexampleSimplification)

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
  LengthSpinePairCandidateAssessed assessment _ -> assessment

spinePairCandidatePreparationRefusal
  :: LengthSpinePairCandidateAssessment
  -> Maybe LengthPreparationRefusalClass
spinePairCandidatePreparationRefusal state = case state of
  LengthSpinePairCandidatePreparationRefused refusal -> Just refusal
  LengthSpinePairCandidateAssessed _ _ -> Nothing

rankedLengthSpinePairCandidateCounterexampleSimplification
  :: RankedLengthSpinePairCandidate
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
rankedLengthSpinePairCandidateCounterexampleSimplification
    (RankedLengthSpinePairCandidate _ _ state) = case state of
  LengthSpinePairCandidatePreparationRefused _ -> Nothing
  LengthSpinePairCandidateAssessed _ simplification -> simplification

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
  | LengthSpinePairRankingApplicableDomainValidationFailed
      !LengthSpinePairInputBoxValidationError
  | LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
      !LengthSpinePairBooleanFiniteUnionApplicableDomainValidationError
  | LengthSpinePairRankingCounterexampleSimplificationFailed
      !LengthSpinePairCounterexampleSimplificationError
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

data LengthSpinePairApplicableDomainRankingPolicy
  = LengthSpinePairApplicableDomainRankingDisabled
  | LengthSpinePairApplicableDomainRankingEnabled !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingPositiveAffineEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingRelationalPositiveAffineEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusEnabled
      !LengthInputBoxLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits
  | LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingEnabled
      !LengthInputBoxLimits !LengthBooleanFiniteUnionLimits

data LengthSpinePairOriginProbeRankingPolicy
  = LengthSpinePairOriginProbeRankingDisabled
  | LengthSpinePairOriginProbeRankingEnabled

data LengthSpinePairCounterexampleSimplificationRankingPolicy
  = LengthSpinePairCounterexampleSimplificationRankingDisabled
  | LengthSpinePairCounterexampleSimplificationRankingEnabled
      !LengthInputBoxLimits

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
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled
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
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled
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
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingDisabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled
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
        LengthSpinePairApplicableDomainRankingDisabled
        LengthSpinePairOriginProbeRankingEnabled
        LengthSpinePairCounterexampleSimplificationRankingDisabled
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
    LengthSpinePairApplicableDomainRankingDisabled
    LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled
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
    LengthSpinePairApplicableDomainRankingDisabled
    LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled
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
    LengthSpinePairApplicableDomainRankingDisabled
    LengthSpinePairOriginProbeRankingDisabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled
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
    LengthSpinePairApplicableDomainRankingDisabled
    LengthSpinePairOriginProbeRankingEnabled
    LengthSpinePairCounterexampleSimplificationRankingDisabled
    execution evaluation contract postVerificationCandidateVerified

-- | Package-private complete policy entrance used by the opaque reusable
-- configuration owner.  The established public runners above keep passing
-- the literal disabled applicable-domain policy.
rankVerifiedLengthSpinePairCandidatesWithRankingPolicies
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPolicies inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy execution
    evaluation contract candidates =
  rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy
    LengthLiveSessionOpeningEager execution evaluation contract candidates

rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy
    openingPolicy execution evaluation contract candidates = fmap
      (fmap $ projectAssociatedLengthSpinePairRankingWith id)
  $ rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening inputBoxPolicy
      applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
      execution evaluation contract id candidates

-- | Occurrence-associated sibling of the complete private policy entrance.
rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPolicies inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy execution
    evaluation contract =
  rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy
    LengthLiveSessionOpeningEager execution evaluation contract

rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndLiveSessionOpening
    inputBoxPolicy applicableDomainPolicy originProbePolicy simplificationPolicy
    openingPolicy execution evaluation contract =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
    execution evaluation contract postVerificationCandidateVerified

rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (LengthSpinePairRanking -> LengthSpinePairRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget
    (finalize . projectAssociatedLengthSpinePairRankingWith id)
    forceLengthSpinePairRankingOwnedResult inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
    execution evaluation contract id candidates

rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget finalize
    forceAssociatedLengthSpinePairRankingOwnedResult inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates

rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (LengthSpinePairRanking -> LengthSpinePairRanking)
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    (finalize . projectAssociatedLengthSpinePairRankingWith id)
    forceLengthSpinePairRankingOwnedResult inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
    execution evaluation contract id candidates

rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
  :: (AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant)
      -> AssociatedLengthSpinePairRanking
        (PostVerificationCandidate epoch DetailedVerificationVariant))
  -> LengthSMTLibLiveUsableWorkBudget
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithRankingPoliciesAndScopedUsableWorkBudget
    finalize budget inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    candidates =
  rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    finalize forceAssociatedLengthSpinePairRankingOwnedResult inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
    execution evaluation contract postVerificationCandidateVerified candidates

data LengthSpinePairUsableWorkSnapshot association =
  LengthSpinePairUsableWorkSnapshot
    ![PreparedLengthSpinePairCandidate association]
    !Bool

type role LengthSpinePairUsableWorkSnapshot nominal

rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithUsableWorkBudget budget finish
    forceResult inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    verifiedFor associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveUsableWorkDeadline budget $ \deadline -> do
        let prepared = prepareLengthSpinePairCandidates
              contract verifiedFor admitted
            snapshot = LengthSpinePairUsableWorkSnapshot prepared False
        _ <- evaluate $ forcePreparedLengthSpinePairCandidates prepared
        snapshot `seq` writeIORef snapshotRef (Just snapshot)
        ranking <- runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline
          deadline execution evaluation inputBoxPolicy applicableDomainPolicy
          originProbePolicy simplificationPolicy openingPolicy prepared
        let cleanupIncomplete =
              associatedLengthSpinePairRankingCleanupIncomplete ranking
            completedSnapshot = LengthSpinePairUsableWorkSnapshot
              prepared cleanupIncomplete
            result = finish ranking
        completedSnapshot `seq`
          writeIORef snapshotRef (Just completedSnapshot)
        _ <- evaluate $ forceResult result
        pure result
      case owned of
        Right result -> pure $ Right result
        Left ownerFailure -> do
          snapshot <- readIORef snapshotRef
          let cleanupIncomplete = case snapshot of
                Nothing -> False
                Just (LengthSpinePairUsableWorkSnapshot _ incomplete) ->
                  incomplete
              failure = ownerLengthSpinePairRankingFailure
                cleanupIncomplete ownerFailure
              ranking = case snapshot of
                Nothing -> unpreparedUnassessedLengthSpinePairRanking
                  admitted failure
                Just (LengthSpinePairUsableWorkSnapshot prepared _) ->
                  unassessedLengthSpinePairRanking prepared failure
              result = finish ranking
          _ <- evaluate $ forceResult result
          pure $ Right result

rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget
  :: LengthSMTLibLiveUsableWorkBudget
  -> (AssociatedLengthSpinePairRanking association -> result)
  -> (result -> ())
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO (Either LengthRankingInputError result)
rankAssociatedLengthSpinePairCandidatesWithScopedUsableWorkBudget budget
    finish forceResult inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy execution evaluation contract
    verifiedFor associations =
  case admitLengthSpinePairCandidates
      defaultLengthSMTLibLiveSessionMaximumQueries associations of
    Left failure -> pure $ Left failure
    Right admitted -> do
      snapshotRef <- newIORef Nothing
      owned <- withLengthSMTLibLiveScopedUsableWorkDeadline budget
        $ \deadline -> do
          initial <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
          case initial of
            Left failure -> pure $ Left failure
            Right () -> do
              let prepared = prepareLengthSpinePairCandidates
                    contract verifiedFor admitted
                  snapshot =
                    LengthSpinePairUsableWorkSnapshot prepared False
              _ <- evaluate $ forcePreparedLengthSpinePairCandidates prepared
              snapshot `seq` writeIORef snapshotRef (Just snapshot)
              afterPreparation <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              case afterPreparation of
                Left failure -> pure $ Left failure
                Right () -> do
                  ranked <-
                    runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline
                      deadline execution evaluation inputBoxPolicy
                      applicableDomainPolicy originProbePolicy
                      simplificationPolicy openingPolicy prepared
                  case ranked of
                    Left failure -> pure $ Left failure
                    Right ranking -> do
                      let cleanupIncomplete =
                            associatedLengthSpinePairRankingCleanupIncomplete
                              ranking
                          completedSnapshot =
                            LengthSpinePairUsableWorkSnapshot
                              prepared cleanupIncomplete
                      completedSnapshot `seq`
                        writeIORef snapshotRef (Just completedSnapshot)
                      beforeResult <-
                        checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
                      case beforeResult of
                        Left failure -> pure $ Left failure
                        Right () -> do
                          let result = finish ranking
                          _ <- evaluate $ forceResult result
                          afterResult <-
                            checkLengthSMTLibLiveScopedUsableWorkDeadline
                              deadline
                          case afterResult of
                            Left failure -> pure $ Left failure
                            Right () -> pure $ Right result
      case owned of
        Left ownerFailure -> fallback snapshotRef admitted ownerFailure
        Right (Left checkpointFailure) ->
          fallback snapshotRef admitted checkpointFailure
        Right (Right result) -> pure $ Right result
 where
  fallback snapshotRef admitted failure = do
    snapshot <- readIORef snapshotRef
    let cleanupIncomplete = case snapshot of
          Nothing -> False
          Just (LengthSpinePairUsableWorkSnapshot _ incomplete) -> incomplete
        rankingFailure = ownerLengthSpinePairRankingFailure
          cleanupIncomplete failure
        ranking = case snapshot of
          Nothing -> unpreparedUnassessedLengthSpinePairRanking
            admitted rankingFailure
          Just (LengthSpinePairUsableWorkSnapshot prepared _) ->
            unassessedLengthSpinePairRanking prepared rankingFailure
        result = finish ranking
    _ <- evaluate $ forceResult result
    pure $ Right result

runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesUnderUsableWorkDeadline deadline execution
    evaluation inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy prepared = case prepared of
  [] -> pure $ AssociatedLengthSpinePairRanking [] Nothing
  _ | not (hasEligibleLengthSpinePairCandidate prepared) -> pure
        $ AssociatedLengthSpinePairRanking
            (map preparedLengthSpinePairCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
            $ \session -> runPreparedLengthSpinePairCandidates evaluation
                inputBoxPolicy applicableDomainPolicy originProbePolicy
                simplificationPolicy session prepared
          pure $ case scoped of
            Left failure -> unassessedLengthSpinePairRanking prepared
              $ lengthSpinePairSessionRankingFailure failure
            Right (Left failure) ->
              unassessedLengthSpinePairRanking prepared failure
            Right (Right assessed) -> AssociatedLengthSpinePairRanking
              (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
            deadline execution evaluation inputBoxPolicy applicableDomainPolicy
            originProbePolicy simplificationPolicy prepared

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
  :: LengthSMTLibLiveUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderDeadline
    deadline execution evaluation inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy prepared = case
        runPreparedLengthSpinePairCandidatesBeforeLive evaluation
          applicableDomainPolicy originProbePolicy simplificationPolicy
          prepared of
  PreparedLengthSpinePairCandidatesCompleted assessed -> pure
    $ AssociatedLengthSpinePairRanking
        (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
  PreparedLengthSpinePairCandidatesFailed failure -> pure
    $ unassessedLengthSpinePairRanking prepared failure
  PreparedLengthSpinePairCandidatesNeedLive reversed seedBank index association
      query rest -> do
    scoped <- withLengthSMTLibLiveSessionUnderDeadline deadline execution
      $ \session -> do
        observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
        case observed of
          Left failure -> pure $ Left
            $ lengthSpinePairQueryRankingFailure index failure
          Right observation -> case assessLengthSpinePairCandidate evaluation
              inputBoxPolicy simplificationPolicy index association query
              observation of
            Left failure -> pure $ Left failure
            Right assessed ->
              let nextSeedBank = case
                      lengthSpinePairCounterexampleSeed assessed of
                    Nothing -> seedBank
                    Just retained ->
                      promoteLengthSpinePairCounterexampleSeed retained seedBank
              in nextSeedBank `seq`
                  runPreparedLengthSpinePairCandidatesFrom evaluation
                    inputBoxPolicy applicableDomainPolicy originProbePolicy
                    simplificationPolicy session (assessed : reversed)
                    nextSeedBank rest
    pure $ case scoped of
      Left failure -> unassessedLengthSpinePairRanking prepared
        $ lengthSpinePairSessionRankingFailure failure
      Right (Left failure) ->
        unassessedLengthSpinePairRanking prepared failure
      Right (Right assessed) -> AssociatedLengthSpinePairRanking
        (stableLengthSpinePairCounterexampleDemotion assessed) Nothing

runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthSpinePairRanking association))
runPreparedLengthSpinePairCandidatesUnderScopedUsableWorkDeadline deadline
    execution evaluation inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy openingPolicy prepared = case prepared of
  [] -> pure $ Right $ AssociatedLengthSpinePairRanking [] Nothing
  _ | not (hasEligibleLengthSpinePairCandidate prepared) -> pure $ Right
        $ AssociatedLengthSpinePairRanking
            (map preparedLengthSpinePairCandidateUnassessed prepared) Nothing
    | otherwise -> case openingPolicy of
        LengthLiveSessionOpeningEager -> do
          scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
            deadline execution $ \session ->
              runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
                deadline evaluation inputBoxPolicy applicableDomainPolicy
                originProbePolicy simplificationPolicy session [] [] prepared
          pure $ case scoped of
            Left failure -> Right $ unassessedLengthSpinePairRanking prepared
              $ lengthSpinePairSessionRankingFailure failure
            Right (Left failure) -> Left failure
            Right (Right (Left failure)) -> Right
              $ unassessedLengthSpinePairRanking prepared failure
            Right (Right (Right assessed)) -> Right
              $ AssociatedLengthSpinePairRanking
                  (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
        LengthLiveSessionOpeningDeferredUntilLiveQuery ->
          runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
            deadline execution evaluation inputBoxPolicy applicableDomainPolicy
            originProbePolicy simplificationPolicy prepared

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (AssociatedLengthSpinePairRanking association))
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpeningUnderScopedDeadline
    deadline execution evaluation inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy prepared = do
  beforeLive <-
    runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
      deadline evaluation applicableDomainPolicy originProbePolicy
      simplificationPolicy prepared
  case beforeLive of
    Left failure -> pure $ Left failure
    Right (PreparedLengthSpinePairCandidatesCompleted assessed) -> pure $ Right
      $ AssociatedLengthSpinePairRanking
          (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
    Right (PreparedLengthSpinePairCandidatesFailed failure) -> pure $ Right
      $ unassessedLengthSpinePairRanking prepared failure
    Right (PreparedLengthSpinePairCandidatesNeedLive reversed seedBank index
        association query rest) -> do
      scoped <- withLengthSMTLibLiveSessionUnderScopedDeadline
        deadline execution $ \session -> do
          observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
          case observed of
            Left failure -> pure $ Right $ Left
              $ lengthSpinePairQueryRankingFailure index failure
            Right observation -> case assessLengthSpinePairCandidate evaluation
                inputBoxPolicy simplificationPolicy index association query
                observation of
              Left failure -> pure $ Right $ Left failure
              Right assessed -> do
                let nextSeedBank = case
                        lengthSpinePairCounterexampleSeed assessed of
                      Nothing -> seedBank
                      Just retained ->
                        promoteLengthSpinePairCounterexampleSeed retained seedBank
                nextSeedBank `seq` pure ()
                checkpoint <-
                  checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
                case checkpoint of
                  Left failure -> pure $ Left failure
                  Right () ->
                    runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
                      deadline evaluation inputBoxPolicy applicableDomainPolicy
                      originProbePolicy simplificationPolicy session
                      (assessed : reversed) nextSeedBank rest
      pure $ case scoped of
        Left failure -> Right $ unassessedLengthSpinePairRanking prepared
          $ lengthSpinePairSessionRankingFailure failure
        Right (Left failure) -> Left failure
        Right (Right (Left failure)) -> Right
          $ unassessedLengthSpinePairRanking prepared failure
        Right (Right (Right assessed)) -> Right
          $ AssociatedLengthSpinePairRanking
              (stableLengthSpinePairCounterexampleDemotion assessed) Nothing

-- | Check after each complete pure candidate chain.  The individual MRU,
-- applicable-domain, origin, and simplification operations are independently
-- bounded and deliberately remain one indivisible checkpoint quantum.
runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (PreparedLengthSpinePairCandidatesBeforeLive association))
runPreparedLengthSpinePairCandidatesBeforeLiveUnderScopedUsableWorkDeadline
    deadline evaluation applicableDomainPolicy originProbePolicy
    simplificationPolicy = go [] []
 where
  go reversed seedBank remaining = case remaining of
    [] -> pure $ Right
      $ PreparedLengthSpinePairCandidatesCompleted $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      continue
        (AssociatedRankedLengthSpinePairCandidate index association
          (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        seedBank rest
    PreparedLengthSpinePairCandidateEligible index association query : rest ->
      case replayLengthSpinePairCounterexampleSeeds
          evaluation query seedBank of
        Just (inputs, receipt) ->
          inputs `seq` case simplifyLengthSpinePairCounterexampleAssessment
              evaluation simplificationPolicy index association query receipt of
            Left failure -> pure $ Right
              $ PreparedLengthSpinePairCandidatesFailed failure
            Right assessed ->
              continueAssessed reversed seedBank rest assessed
        Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
            association query of
          Left failure -> pure $ Right
            $ PreparedLengthSpinePairCandidatesFailed failure
          Right (Just assessed) ->
            continueAssessed reversed seedBank rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Right $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    (LengthSpinePairRankingOriginProbeEvaluationFailed failure)
                    index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Right $ PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> pure $ Right
                $ PreparedLengthSpinePairCandidatesFailed failure
              Right assessed ->
                continueAssessed reversed seedBank rest assessed
            Right Nothing -> do
              checkpoint <-
                checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
              pure $ case checkpoint of
                Left failure -> Left failure
                Right () -> Right $ PreparedLengthSpinePairCandidatesNeedLive
                  reversed seedBank index association query rest

  continueAssessed reversed seedBank rest assessed =
    let nextSeedBank = case lengthSpinePairCounterexampleSeed assessed of
          Nothing -> seedBank
          Just retained ->
            promoteLengthSpinePairCounterexampleSeed retained seedBank
    in nextSeedBank `seq`
        continue (assessed : reversed) nextSeedBank rest

  continue reversed seedBank rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go reversed seedBank rest

-- | Live sibling which checks after every completed candidate before any
-- following candidate can demand pure replay or another live transaction.
runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline
  :: LengthSMTLibLiveScopedUsableWorkDeadline budget
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthSpinePairCandidate association]
  -> [[Natural]]
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSMTLibLiveSessionError
        (Either LengthSpinePairRankingFailure
          [AssociatedRankedLengthSpinePairCandidate association]))
runPreparedLengthSpinePairCandidatesFromUnderScopedUsableWorkDeadline deadline
    evaluation inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy session = go
 where
  go reversed seedBank remaining = case remaining of
    [] -> pure $ Right $ Right $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      continue
        (AssociatedRankedLengthSpinePairCandidate index association
          (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        seedBank rest
    PreparedLengthSpinePairCandidateEligible index association query : rest ->
      case replayLengthSpinePairCounterexampleSeeds
          evaluation query seedBank of
        Just (inputs, receipt) ->
          inputs `seq` case simplifyLengthSpinePairCounterexampleAssessment
              evaluation simplificationPolicy index association query receipt of
            Left failure -> pure $ Right $ Left failure
            Right assessed ->
              continueAssessed reversed seedBank rest assessed
        Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
            association query of
          Left failure -> pure $ Right $ Left failure
          Right (Just assessed) ->
            continueAssessed reversed seedBank rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Right $ Left $ localLengthSpinePairRankingFailure
                (LengthSpinePairRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Right $ Left $ localLengthSpinePairRankingFailure
                LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> pure $ Right $ Left failure
              Right assessed ->
                continueAssessed reversed seedBank rest assessed
            Right Nothing -> do
              observed <- runLengthSpinePairSMTLibLiveQuery
                evaluation session query
              case observed of
                Left failure -> pure $ Right $ Left
                  $ lengthSpinePairQueryRankingFailure index failure
                Right observation -> case assessLengthSpinePairCandidate
                    evaluation inputBoxPolicy simplificationPolicy index
                    association query observation of
                  Left failure -> pure $ Right $ Left failure
                  Right assessed ->
                    continueAssessed reversed seedBank rest assessed

  continueAssessed reversed seedBank rest assessed =
    let nextSeedBank = case lengthSpinePairCounterexampleSeed assessed of
          Nothing -> seedBank
          Just retained ->
            promoteLengthSpinePairCounterexampleSeed retained seedBank
    in nextSeedBank `seq`
        continue (assessed : reversed) nextSeedBank rest

  continue reversed seedBank rest = do
    checkpoint <- checkLengthSMTLibLiveScopedUsableWorkDeadline deadline
    case checkpoint of
      Left failure -> pure $ Left failure
      Right () -> go reversed seedBank rest

rankAssociatedLengthSpinePairCandidates
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidates inputBoxPolicy applicableDomainPolicy
    originProbePolicy simplificationPolicy execution evaluation contract
    verifiedFor associations =
  rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy
    LengthLiveSessionOpeningEager execution evaluation contract verifiedFor
    associations

rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening
  :: LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthLiveSessionOpeningPolicy
  -> LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LeanLengthSpinePairContract
  -> (association -> Verified DetailedVerificationVariant)
  -> [association]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking association))
rankAssociatedLengthSpinePairCandidatesWithLiveSessionOpening inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy openingPolicy
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
        | otherwise -> case openingPolicy of
            LengthLiveSessionOpeningEager -> do
              scoped <- withLengthSMTLibLiveSession execution $ \session ->
                runPreparedLengthSpinePairCandidates evaluation inputBoxPolicy
                  applicableDomainPolicy originProbePolicy simplificationPolicy
                  session prepared
              pure $ Right $ case scoped of
                Left failure -> unassessedLengthSpinePairRanking prepared
                  $ lengthSpinePairSessionRankingFailure failure
                Right (Left failure) ->
                  unassessedLengthSpinePairRanking prepared failure
                Right (Right assessed) -> AssociatedLengthSpinePairRanking
                  (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
            LengthLiveSessionOpeningDeferredUntilLiveQuery -> Right <$>
              runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening
                execution evaluation inputBoxPolicy applicableDomainPolicy
                  originProbePolicy simplificationPolicy prepared

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
      $ LengthSpinePairCandidateAssessed LengthSpinePairUnassessed Nothing

data PreparedLengthSpinePairCandidatesBeforeLive association
  = PreparedLengthSpinePairCandidatesCompleted
      ![AssociatedRankedLengthSpinePairCandidate association]
  | PreparedLengthSpinePairCandidatesFailed
      !LengthSpinePairRankingFailure
  | PreparedLengthSpinePairCandidatesNeedLive
      ![AssociatedRankedLengthSpinePairCandidate association]
      ![[Natural]]
      !Natural
      !association
      !CheckedLengthSpinePairQuery
      ![PreparedLengthSpinePairCandidate association]

type role PreparedLengthSpinePairCandidatesBeforeLive nominal

runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> IO (AssociatedLengthSpinePairRanking association)
runPreparedLengthSpinePairCandidatesWithDeferredLiveSessionOpening execution
    evaluation inputBoxPolicy applicableDomainPolicy originProbePolicy
    simplificationPolicy prepared = case
        runPreparedLengthSpinePairCandidatesBeforeLive evaluation
          applicableDomainPolicy originProbePolicy simplificationPolicy prepared of
  PreparedLengthSpinePairCandidatesCompleted assessed -> pure
    $ AssociatedLengthSpinePairRanking
        (stableLengthSpinePairCounterexampleDemotion assessed) Nothing
  PreparedLengthSpinePairCandidatesFailed failure -> pure
    $ unassessedLengthSpinePairRanking prepared failure
  PreparedLengthSpinePairCandidatesNeedLive reversed seedBank index association
      query rest -> do
    scoped <- withLengthSMTLibLiveSession execution $ \session -> do
      observed <- runLengthSpinePairSMTLibLiveQuery evaluation session query
      case observed of
        Left failure -> pure $ Left
          $ lengthSpinePairQueryRankingFailure index failure
        Right observation -> case assessLengthSpinePairCandidate evaluation
            inputBoxPolicy simplificationPolicy index association query
              observation of
          Left failure -> pure $ Left failure
          Right assessed ->
            let nextSeedBank = case
                    lengthSpinePairCounterexampleSeed assessed of
                  Nothing -> seedBank
                  Just retained ->
                    promoteLengthSpinePairCounterexampleSeed retained seedBank
            in nextSeedBank `seq`
                runPreparedLengthSpinePairCandidatesFrom evaluation
                  inputBoxPolicy applicableDomainPolicy originProbePolicy
                  simplificationPolicy session (assessed : reversed)
                  nextSeedBank rest
    pure $ case scoped of
      Left failure -> unassessedLengthSpinePairRanking prepared
        $ lengthSpinePairSessionRankingFailure failure
      Right (Left failure) ->
        unassessedLengthSpinePairRanking prepared failure
      Right (Right assessed) -> AssociatedLengthSpinePairRanking
        (stableLengthSpinePairCounterexampleDemotion assessed) Nothing

runPreparedLengthSpinePairCandidatesBeforeLive
  :: LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> [PreparedLengthSpinePairCandidate association]
  -> PreparedLengthSpinePairCandidatesBeforeLive association
runPreparedLengthSpinePairCandidatesBeforeLive evaluation
    applicableDomainPolicy originProbePolicy simplificationPolicy = go [] []
 where
  go reversed seedBank remaining = case remaining of
    [] -> PreparedLengthSpinePairCandidatesCompleted $ reverse reversed
    PreparedLengthSpinePairCandidateUnassessed
        index association refusal : rest ->
      go (AssociatedRankedLengthSpinePairCandidate index association
            (LengthSpinePairCandidatePreparationRefused refusal) : reversed)
        seedBank rest
    PreparedLengthSpinePairCandidateEligible index association query : rest ->
      case replayLengthSpinePairCounterexampleSeeds
          evaluation query seedBank of
        Just (inputs, receipt) ->
          inputs `seq` case simplifyLengthSpinePairCounterexampleAssessment
              evaluation simplificationPolicy index association query receipt of
            Left failure ->
              PreparedLengthSpinePairCandidatesFailed failure
            Right assessed -> continueAssessed
              reversed seedBank rest assessed
        Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
              association query of
          Left failure -> PreparedLengthSpinePairCandidatesFailed failure
          Right (Just assessed) -> continueAssessed
            reversed seedBank rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left
                (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    (LengthSpinePairRankingOriginProbeEvaluationFailed failure)
                    index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              PreparedLengthSpinePairCandidatesFailed
                $ localLengthSpinePairRankingFailure
                    LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) -> case
                simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
              Left failure -> PreparedLengthSpinePairCandidatesFailed failure
              Right assessed -> continueAssessed
                reversed seedBank rest assessed
            Right Nothing -> PreparedLengthSpinePairCandidatesNeedLive
              reversed seedBank index association query rest

  continueAssessed reversed seedBank rest assessed =
    let nextSeedBank = case lengthSpinePairCounterexampleSeed assessed of
          Nothing -> seedBank
          Just retained ->
            promoteLengthSpinePairCounterexampleSeed retained seedBank
    in nextSeedBank `seq` go (assessed : reversed) nextSeedBank rest

runPreparedLengthSpinePairCandidates
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibLiveSession epoch
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSpinePairRankingFailure
        [AssociatedRankedLengthSpinePairCandidate association])
runPreparedLengthSpinePairCandidates evaluation inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy session =
  runPreparedLengthSpinePairCandidatesFrom evaluation inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy session [] []

runPreparedLengthSpinePairCandidatesFrom
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairOriginProbeRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> LengthSMTLibLiveSession epoch
  -> [AssociatedRankedLengthSpinePairCandidate association]
  -> [[Natural]]
  -> [PreparedLengthSpinePairCandidate association]
  -> IO
      (Either LengthSpinePairRankingFailure
        [AssociatedRankedLengthSpinePairCandidate association])
runPreparedLengthSpinePairCandidatesFrom evaluation inputBoxPolicy
    applicableDomainPolicy originProbePolicy simplificationPolicy session = go
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
          inputs `seq` case simplifyLengthSpinePairCounterexampleAssessment
              evaluation simplificationPolicy index association query receipt of
            Left failure -> pure $ Left failure
            Right assessed -> continueAssessed
              reversed seedBank rest assessed
        Nothing -> case assessLengthSpinePairApplicableDomainCandidate
            evaluation applicableDomainPolicy simplificationPolicy index
              association query of
          Left failure -> pure $ Left failure
          Right (Just assessed) -> continueAssessed
            reversed seedBank rest assessed
          Right Nothing -> case probeLengthSpinePairOriginCounterexample
              evaluation originProbePolicy query of
            Left (LengthSpinePairSMTLibInputReplayEvaluationRejected failure) ->
              pure $ Left $ localLengthSpinePairRankingFailure
                (LengthSpinePairRankingOriginProbeEvaluationFailed failure) index
            Left (LengthSpinePairSMTLibInputReplayAssociationRejected _) ->
              pure $ Left $ localLengthSpinePairRankingFailure
                LengthSpinePairRankingEvidenceReplayMismatch index
            Right (Just receipt) ->
              case simplifyLengthSpinePairCounterexampleAssessment evaluation
                  simplificationPolicy index association query receipt of
                Left failure -> pure $ Left failure
                Right assessed -> continueAssessed
                  reversed seedBank rest assessed
            Right Nothing -> do
              observed <- runLengthSpinePairSMTLibLiveQuery
                evaluation session query
              case observed of
                Left failure -> pure $ Left
                  $ lengthSpinePairQueryRankingFailure index failure
                Right observation -> case assessLengthSpinePairCandidate
                    evaluation inputBoxPolicy simplificationPolicy index
                      association query observation of
                  Left failure -> pure $ Left failure
                  Right assessed -> continueAssessed
                    reversed seedBank rest assessed

  continueAssessed reversed seedBank rest assessed =
    let nextSeedBank = case lengthSpinePairCounterexampleSeed assessed of
          Nothing -> seedBank
          Just retained ->
            promoteLengthSpinePairCounterexampleSeed retained seedBank
    in nextSeedBank `seq` go (assessed : reversed) nextSeedBank rest

-- | Attempt the selected complete applicable-domain traversal.  Inapplicability
-- under that extraction rule and failures which prevent bounded traversal
-- admission are ordinary misses.  Once admission succeeds,
-- evaluation/internal failures or an evidence association mismatch atomically
-- fail the indexed batch.
assessLengthSpinePairApplicableDomainCandidate
  :: LengthEvaluationLimits
  -> LengthSpinePairApplicableDomainRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> Either LengthSpinePairRankingFailure
      (Maybe (AssociatedRankedLengthSpinePairCandidate association))
assessLengthSpinePairApplicableDomainCandidate evaluation policy
    simplificationPolicy index association query = case policy of
  LengthSpinePairApplicableDomainRankingDisabled -> Right Nothing
  LengthSpinePairApplicableDomainRankingEnabled limits -> case
      validateLengthSpinePairSMTLibQueryApplicableDomain
        evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairApplicableDomainEstablished receipt) Nothing
  LengthSpinePairApplicableDomainRankingPositiveAffineEnabled limits -> case
      validateLengthSpinePairSMTLibQueryPositiveAffineApplicableDomain
        evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairPositiveAffineApplicableDomainEstablished receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingRelationalPositiveAffineEnabled
      limits -> case
        validateLengthSpinePairSMTLibQueryRelationalPositiveAffineApplicableDomain
          evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineEnabled
      limits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineApplicableDomain
          evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientEnabled
      limits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientApplicableDomain
          evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaEnabled
      limits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
          evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusEnabled
      limits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
          evaluation limits query of
    Left
        (LengthSpinePairSMTLibApplicableDomainValidationAssociationRejected _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left (LengthSpinePairSMTLibApplicableDomainValidationRejected
        (LengthSpinePairApplicableDomainInputBoxValidationRejected failure))
      | lengthSpinePairApplicableDomainAdmissionFailure failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingApplicableDomainValidationFailed failure) index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionEnabled
      inputBoxLimits unionLimits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
          evaluation inputBoxLimits unionLimits query of
    Left
        (LengthSpinePairSMTLibBooleanFiniteUnionApplicableDomainValidationAssociationRejected
          _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left
        (LengthSpinePairSMTLibBooleanFiniteUnionApplicableDomainValidationRejected
          failure)
      | lengthSpinePairBooleanFiniteUnionApplicableDomainAdmissionFailure
          failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
            failure)
          index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
            receipt)
          Nothing
  LengthSpinePairApplicableDomainRankingStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingEnabled
      inputBoxLimits unionLimits -> case
        validateLengthSpinePairSMTLibQueryStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
          evaluation inputBoxLimits unionLimits query of
    Left
        (LengthSpinePairSMTLibBooleanFiniteUnionApplicableDomainValidationAssociationRejected
          _) ->
      Left $ localLengthSpinePairRankingFailure
        LengthSpinePairRankingEvidenceReplayMismatch index
    Left
        (LengthSpinePairSMTLibBooleanFiniteUnionApplicableDomainValidationRejected
          failure)
      | lengthSpinePairBooleanFiniteUnionApplicableDomainAdmissionFailure
          failure -> Right Nothing
      | otherwise -> Left $ localLengthSpinePairRankingFailure
          (LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
            failure)
          index
    Right (LengthApplicableDomainInapplicable _) -> Right Nothing
    Right (LengthApplicableDomainCounterexample receipt) -> Just <$>
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    Right (LengthApplicableDomainEstablished receipt) -> Right $ Just
      $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed
          (LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
            receipt)
          Nothing

lengthSpinePairApplicableDomainAdmissionFailure
  :: LengthSpinePairInputBoxValidationError
  -> Bool
lengthSpinePairApplicableDomainAdmissionFailure failure = case failure of
  LengthSpinePairInputBoxProblemInputLimitExceeded {} -> True
  LengthSpinePairInputBoxMaximumValueRejected {} -> True
  LengthSpinePairInputBoxAssignmentLimitExceeded {} -> True
  LengthSpinePairInputBoxBoundsArityMismatch {} -> False
  LengthSpinePairInputBoxAssignmentEvaluationRejected {} -> False
  LengthSpinePairInputBoxInternalEnumerationInvariant -> False

lengthSpinePairBooleanFiniteUnionApplicableDomainAdmissionFailure
  :: LengthSpinePairBooleanFiniteUnionApplicableDomainValidationError
  -> Bool
lengthSpinePairBooleanFiniteUnionApplicableDomainAdmissionFailure failure =
  case failure of
    LengthSpinePairBooleanFiniteUnionProblemInputLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionGeneratedBranchLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionRuleLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionClosureInspectionLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionRetainedBoxLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionMaximumValueRejected {} -> True
    LengthSpinePairBooleanFiniteUnionAssignmentVisitLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionAssignmentLimitExceeded {} -> True
    LengthSpinePairBooleanFiniteUnionAssignmentEvaluationRejected {} -> False
    LengthSpinePairBooleanFiniteUnionInternalEnumerationInvariant -> False

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
  -> Maybe ValidatedLengthSpinePairCounterexampleSimplification
  -> AssociatedRankedLengthSpinePairCandidate association
assessedLengthSpinePairCounterexample index association receipt simplification =
  AssociatedRankedLengthSpinePairCandidate index association
    $ LengthSpinePairCandidateAssessed
        (LengthSpinePairCounterexample receipt) simplification

simplifyLengthSpinePairCounterexampleAssessment
  :: LengthEvaluationLimits
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> ValidatedLengthSpinePairCounterexample
  -> Either LengthSpinePairRankingFailure
      (AssociatedRankedLengthSpinePairCandidate association)
simplifyLengthSpinePairCounterexampleAssessment evaluation policy index
    association query receipt = case policy of
  LengthSpinePairCounterexampleSimplificationRankingDisabled -> Right
    $ assessedLengthSpinePairCounterexample
        index association receipt Nothing
  LengthSpinePairCounterexampleSimplificationRankingEnabled limits -> case
      simplifyLengthSpinePairSMTLibQueryCounterexample
        evaluation limits query receipt of
    Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected
        (LengthSpinePairCounterexampleSimplificationInputBoxValidationRejected
          LengthSpinePairInputBoxAssignmentEvaluationRejected {})) -> Right
      $ assessedLengthSpinePairCounterexample
          index association receipt Nothing
    Left (LengthSpinePairSMTLibCounterexampleSimplificationRejected failure) ->
      Left $ localLengthSpinePairRankingFailure
        (LengthSpinePairRankingCounterexampleSimplificationFailed failure) index
    Left
        (LengthSpinePairSMTLibCounterexampleSimplificationAssociationRejected
          _) -> Left $ localLengthSpinePairRankingFailure
          LengthSpinePairRankingEvidenceReplayMismatch index
    Right Nothing -> Right $ assessedLengthSpinePairCounterexample
      index association receipt Nothing
    Right (Just simplification) -> Right
      $ assessedLengthSpinePairCounterexample index association
          (validatedLengthSpinePairCounterexampleSimplificationCounterexample
            simplification)
          (Just simplification)

lengthSpinePairCounterexampleSeed
  :: AssociatedRankedLengthSpinePairCandidate association
  -> Maybe [Natural]
lengthSpinePairCounterexampleSeed
    (AssociatedRankedLengthSpinePairCandidate _ _ state) = case state of
  LengthSpinePairCandidateAssessed
      (LengthSpinePairCounterexample receipt) _ ->
    Just $ validatedLengthSpinePairCounterexampleInputs receipt
  _ -> Nothing

assessLengthSpinePairCandidate
  :: LengthEvaluationLimits
  -> LengthSpinePairInputBoxRankingPolicy
  -> LengthSpinePairCounterexampleSimplificationRankingPolicy
  -> Natural
  -> association
  -> CheckedLengthSpinePairQuery
  -> LengthSpinePairSMTLibLiveQueryObservation
      epoch ExferenceLocal ExferenceLocal
  -> Either LengthSpinePairRankingFailure
      (AssociatedRankedLengthSpinePairCandidate association)
assessLengthSpinePairCandidate evaluation inputBoxPolicy simplificationPolicy
    index association query observation = do
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
  case assessment of
    LengthSpinePairCounterexample receipt ->
      simplifyLengthSpinePairCounterexampleAssessment evaluation
        simplificationPolicy index association query receipt
    _ -> pure $ AssociatedRankedLengthSpinePairCandidate index association
      $ LengthSpinePairCandidateAssessed assessment Nothing
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

-- | Prefer only complete applicable-domain receipts with at least one
-- assignment satisfying the precondition.  This transform is intended to run
-- after the established bounded-box preference, so composing both policies
-- yields domain-positive, box-positive, neutral, then counterexample order.
preferNonVacuousApplicableDomainLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> LengthSpinePairRanking
preferNonVacuousApplicableDomainLengthSpinePairRanking ranking = case ranking of
  LengthSpinePairRanking _ (Just _) -> ranking
  LengthSpinePairRanking candidates Nothing -> LengthSpinePairRanking
    (preferNonVacuousApplicableDomainLengthSpinePairCandidates candidates)
    Nothing

-- | Occurrence-associated sibling of the complete-domain preference.
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking
  :: AssociatedLengthSpinePairRanking association
  -> AssociatedLengthSpinePairRanking association
preferNonVacuousApplicableDomainAssociatedLengthSpinePairRanking ranking = case
    ranking of
  AssociatedLengthSpinePairRanking _ (Just _) -> ranking
  AssociatedLengthSpinePairRanking candidates Nothing ->
    AssociatedLengthSpinePairRanking
      (preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates
        candidates)
      Nothing

preferNonVacuousApplicableDomainLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> [RankedLengthSpinePairCandidate]
preferNonVacuousApplicableDomainLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableRankedLengthSpinePairCounterexampleDemotion retained
 where
  hasApplicableDomain (RankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairApplicableDomain
      $ spinePairCandidateAssessment state

preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> [AssociatedRankedLengthSpinePairCandidate association]
preferNonVacuousApplicableDomainAssociatedLengthSpinePairCandidates candidates =
  let (positive, retained) = partition hasApplicableDomain candidates
  in positive ++ stableLengthSpinePairCounterexampleDemotion retained
 where
  hasApplicableDomain
      (AssociatedRankedLengthSpinePairCandidate _ _ state) =
    isNonVacuousLengthSpinePairApplicableDomain
      $ spinePairCandidateAssessment state

isNonVacuousLengthSpinePairApplicableDomain
  :: LengthSpinePairRankingAssessment
  -> Bool
isNonVacuousLengthSpinePairApplicableDomain assessment = case assessment of
  LengthSpinePairApplicableDomainEstablished receipt ->
    validatedLengthSpinePairApplicableDomainApplicableAssignmentCount receipt > 0
  LengthSpinePairPositiveAffineApplicableDomainEstablished receipt ->
    validatedLengthSpinePairPositiveAffineApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished receipt ->
    validatedLengthSpinePairRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
      receipt > 0
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
      receipt ->
    validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
      receipt > 0
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

unpreparedUnassessedLengthSpinePairRanking
  :: [association]
  -> LengthSpinePairRankingFailure
  -> AssociatedLengthSpinePairRanking association
unpreparedUnassessedLengthSpinePairRanking associations failure =
  AssociatedLengthSpinePairRanking (go 0 [] associations) (Just failure)
 where
  go _ reversed [] = reverse reversed
  go index reversed (association : rest) =
    let candidate = AssociatedRankedLengthSpinePairCandidate index association
          $ LengthSpinePairCandidateAssessed
              LengthSpinePairUnassessed Nothing
    in candidate `seq` go (index + 1) (candidate : reversed) rest

associatedLengthSpinePairRankingCleanupIncomplete
  :: AssociatedLengthSpinePairRanking association
  -> Bool
associatedLengthSpinePairRankingCleanupIncomplete
    (AssociatedLengthSpinePairRanking _ Nothing) = False
associatedLengthSpinePairRankingCleanupIncomplete
    (AssociatedLengthSpinePairRanking _ (Just failure)) =
  lengthSpinePairRankingFailureCleanupIncomplete failure

ownerLengthSpinePairRankingFailure
  :: Bool
  -> LengthSMTLibLiveSessionError
  -> LengthSpinePairRankingFailure
ownerLengthSpinePairRankingFailure nestedCleanup ownerFailure =
  case lengthSpinePairSessionRankingFailure ownerFailure of
    LengthSpinePairRankingFailure failure cleanup _ ->
      LengthSpinePairRankingFailure failure
        (cleanup || nestedCleanup) Nothing

forceLengthSpinePairRankingOwnedResult :: LengthSpinePairRanking -> ()
forceLengthSpinePairRankingOwnedResult
    (LengthSpinePairRanking candidates failure) =
  forceRankedLengthSpinePairCandidates candidates `seq`
    forceLengthSpinePairRankingFailure failure

forceAssociatedLengthSpinePairRankingOwnedResult
  :: AssociatedLengthSpinePairRanking association
  -> ()
forceAssociatedLengthSpinePairRankingOwnedResult
    (AssociatedLengthSpinePairRanking candidates failure) =
  forceAssociatedRankedLengthSpinePairCandidates candidates `seq`
    forceLengthSpinePairRankingFailure failure

forceRankedLengthSpinePairCandidates
  :: [RankedLengthSpinePairCandidate]
  -> ()
forceRankedLengthSpinePairCandidates candidates = case candidates of
  [] -> ()
  RankedLengthSpinePairCandidate index verified state : rest ->
    index `seq` verified `seq`
      forceLengthSpinePairCandidateAssessment state `seq`
      forceRankedLengthSpinePairCandidates rest

forceAssociatedRankedLengthSpinePairCandidates
  :: [AssociatedRankedLengthSpinePairCandidate association]
  -> ()
forceAssociatedRankedLengthSpinePairCandidates candidates = case candidates of
  [] -> ()
  AssociatedRankedLengthSpinePairCandidate index association state : rest ->
    index `seq` association `seq`
      forceLengthSpinePairCandidateAssessment state `seq`
      forceAssociatedRankedLengthSpinePairCandidates rest

forceLengthSpinePairCandidateAssessment
  :: LengthSpinePairCandidateAssessment
  -> ()
forceLengthSpinePairCandidateAssessment state = case state of
  LengthSpinePairCandidatePreparationRefused refusal -> refusal `seq` ()
  LengthSpinePairCandidateAssessed assessment simplification ->
    forceLengthSpinePairRankingAssessment assessment `seq`
      case simplification of
        Nothing -> ()
        Just receipt -> rnf receipt

forceLengthSpinePairRankingAssessment
  :: LengthSpinePairRankingAssessment
  -> ()
forceLengthSpinePairRankingAssessment assessment = case assessment of
  LengthSpinePairUnassessed -> ()
  LengthSpinePairHeuristic status -> status `seq` ()
  LengthSpinePairCounterexample receipt -> rnf receipt
  LengthSpinePairBoundedPositive receipt -> rnf receipt
  LengthSpinePairApplicableDomainEstablished receipt -> rnf receipt
  LengthSpinePairPositiveAffineApplicableDomainEstablished receipt ->
    rnf receipt
  LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished receipt ->
    rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
      receipt -> rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
      receipt -> rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
      receipt -> rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
      receipt -> rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
      receipt -> rnf receipt
  LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
      receipt -> rnf receipt

forceLengthSpinePairRankingFailure
  :: Maybe LengthSpinePairRankingFailure
  -> ()
forceLengthSpinePairRankingFailure failure = case failure of
  Nothing -> ()
  Just (LengthSpinePairRankingFailure failureClass cleanup index) ->
    forceLengthSpinePairRankingFailureClass failureClass `seq`
      cleanup `seq` forceLengthSpinePairRankingFailureIndex index

forceLengthSpinePairRankingFailureIndex :: Maybe Natural -> ()
forceLengthSpinePairRankingFailureIndex index = case index of
  Nothing -> ()
  Just retained -> retained `seq` ()

forceLengthSpinePairRankingFailureClass
  :: LengthSpinePairRankingFailureClass
  -> ()
forceLengthSpinePairRankingFailureClass failure = case failure of
  LengthSpinePairRankingLiveSessionFailed nested -> rnf nested
  LengthSpinePairRankingLiveQueryFailed nested -> rnf nested
  LengthSpinePairRankingQueryAssociationMismatch -> ()
  LengthSpinePairRankingEvidenceReplayMismatch -> ()
  LengthSpinePairRankingOriginProbeEvaluationFailed nested -> rnf nested
  LengthSpinePairRankingInputBoxValidationFailed nested -> rnf nested
  LengthSpinePairRankingApplicableDomainValidationFailed nested -> rnf nested
  LengthSpinePairRankingBooleanFiniteUnionApplicableDomainValidationFailed
      nested -> rnf nested
  LengthSpinePairRankingCounterexampleSimplificationFailed nested -> rnf nested

forcePreparedLengthSpinePairCandidates
  :: [PreparedLengthSpinePairCandidate association]
  -> ()
forcePreparedLengthSpinePairCandidates prepared = case prepared of
  [] -> ()
  PreparedLengthSpinePairCandidateUnassessed
      index association refusal : rest ->
    index `seq` association `seq` refusal `seq`
      forcePreparedLengthSpinePairCandidates rest
  PreparedLengthSpinePairCandidateEligible index association query : rest ->
    index `seq` association `seq` query `seq`
      forcePreparedLengthSpinePairCandidates rest

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
