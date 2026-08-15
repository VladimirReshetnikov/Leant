-- | Association-safe terminal presentation of finite-spine Length evidence.
--
-- Candidate text and its optional semantic note enter one opaque value from
-- the same ranked receipt.  Main can therefore bind and display a reordered
-- candidate without ever zipping it to a separately projected evidence list.
module Leant.Synth.Length.Presentation
  ( LengthCandidatePresentation
  , presentLengthAssessment
  , presentLengthPostVerificationResult
  , presentLengthSpinePairPostVerificationResult
  , lengthCandidatePresentationText
  , lengthCandidatePresentationNote
  , renderLengthCounterexampleNote
  , renderLengthCounterexampleSimplificationNote
  , renderLengthInputBoxValidationNote
  , renderLengthApplicableDomainValidationNote
  , renderLengthPositiveAffineApplicableDomainValidationNote
  , renderLengthRelationalPositiveAffineApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
  , renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
  , renderLengthSpinePairCounterexampleNote
  , renderLengthSpinePairCounterexampleSimplificationNote
  , renderLengthSpinePairInputBoxValidationNote
  , renderLengthSpinePairApplicableDomainValidationNote
  , renderLengthSpinePairPositiveAffineApplicableDomainValidationNote
  , renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
  , renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
  , maximumLengthCounterexampleNoteCharacters
  ) where

import Data.List (intercalate)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthCounterexampleBasis (..)
  , LengthSpinePair
  , ValidatedLengthApplicableDomain
  , ValidatedLengthCounterexample
  , ValidatedLengthCounterexampleSimplification
  , ValidatedLengthInputBox
  , ValidatedLengthPositiveAffineApplicableDomain
  , ValidatedLengthRelationalPositiveAffineApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  , ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomain
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairInputBox
  , ValidatedLengthSpinePairPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairRelationalPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  , ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomain
  , lengthSpinePairFirst
  , lengthSpinePairSecond
  , validatedLengthCounterexampleBasis
  , validatedLengthCounterexampleInputs
  , validatedLengthCounterexampleResult
  , validatedLengthCounterexampleSimplificationBasis
  , validatedLengthCounterexampleSimplificationInputs
  , validatedLengthCounterexampleSimplificationInspectedAssignmentCount
  , validatedLengthCounterexampleSimplificationOriginalInputs
  , validatedLengthCounterexampleSimplificationResult
  , validatedLengthApplicableDomainApplicableAssignmentCount
  , validatedLengthApplicableDomainAssignmentCount
  , validatedLengthApplicableDomainBasis
  , validatedLengthApplicableDomainInclusiveMaximums
  , validatedLengthInputBoxApplicableAssignmentCount
  , validatedLengthInputBoxAssignmentCount
  , validatedLengthInputBoxBasis
  , validatedLengthInputBoxInclusiveMaximums
  , validatedLengthPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthPositiveAffineApplicableDomainBasis
  , validatedLengthPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthRelationalPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthRelationalPositiveAffineApplicableDomainBasis
  , validatedLengthRelationalPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainInclusiveMaximums
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainInclusiveMaximums
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainInclusiveMaximums
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentVisitCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBoxCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainInclusiveMaximumBoxes
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentVisitCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBoxCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainInclusiveMaximumBoxes
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentVisitCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBasis
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBoxCount
  , validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainInclusiveMaximumBoxes
  , validatedLengthSpinePairCounterexampleBasis
  , validatedLengthSpinePairCounterexampleInputs
  , validatedLengthSpinePairCounterexampleResult
  , validatedLengthSpinePairCounterexampleSimplificationBasis
  , validatedLengthSpinePairCounterexampleSimplificationInputs
  , validatedLengthSpinePairCounterexampleSimplificationInspectedAssignmentCount
  , validatedLengthSpinePairCounterexampleSimplificationOriginalInputs
  , validatedLengthSpinePairCounterexampleSimplificationResult
  , validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairApplicableDomainAssignmentCount
  , validatedLengthSpinePairApplicableDomainBasis
  , validatedLengthSpinePairApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairInputBoxApplicableAssignmentCount
  , validatedLengthSpinePairInputBoxAssignmentCount
  , validatedLengthSpinePairInputBoxBasis
  , validatedLengthSpinePairInputBoxInclusiveMaximums
  , validatedLengthSpinePairPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthSpinePairPositiveAffineApplicableDomainBasis
  , validatedLengthSpinePairPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairRelationalPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthSpinePairRelationalPositiveAffineApplicableDomainBasis
  , validatedLengthSpinePairRelationalPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainInclusiveMaximums
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentVisitCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBoxCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainInclusiveMaximumBoxes
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentVisitCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBoxCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainInclusiveMaximumBoxes
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentVisitCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBasis
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBoxCount
  , validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainInclusiveMaximumBoxes
  )

import Leant.Synth.Engine
  ( DetailedVerificationVariant
  , detailedVerificationVariantText
  )
import Leant.Synth.Length.Integration
  ( LengthAssessmentResult
  , lengthAssessmentCandidates
  , lengthAssessmentRanking
  , lengthAssessmentSpinePairRanking
  )
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationResult
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  )
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingAssessment (..)
  , RankedLengthCandidate
  , lengthRankingCandidates
  , rankedLengthCandidateAssessment
  , rankedLengthCandidateCounterexampleSimplification
  , rankedLengthCandidateVerified
  )
import Leant.Synth.Length.SpinePair.PostVerification
  ( LengthSpinePairPostVerificationResult
  , lengthSpinePairPostVerificationCandidates
  , lengthSpinePairPostVerificationRanking
  )
import Leant.Synth.Length.SpinePair.Ranking
  ( LengthSpinePairRanking
  , LengthSpinePairRankingAssessment (..)
  , RankedLengthSpinePairCandidate
  , lengthSpinePairRankingCandidates
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidateCounterexampleSimplification
  , rankedLengthSpinePairCandidateVerified
  )
import Leant.Synth.Verification
  ( Verified
  , verifiedCandidate
  )

-- | One displayed candidate and the only semantic note authorized for that
-- exact callback receipt.  Both fields stay lazy so merely checking whether a
-- result is empty preserves the established candidate-payload demand.
data LengthCandidatePresentation = LengthCandidatePresentation
  String
  (Maybe String)

lengthCandidatePresentationText
  :: LengthCandidatePresentation
  -> String
lengthCandidatePresentationText (LengthCandidatePresentation text _) = text

lengthCandidatePresentationNote
  :: LengthCandidatePresentation
  -> Maybe String
lengthCandidatePresentationNote (LengthCandidatePresentation _ note) = note

-- | Choose exactly one presentation source.  An accepted ranking is traversed
-- through its opaque candidate/evidence association; disabled or rejected
-- assessment uses the established candidate projection with no semantic note.
presentLengthAssessment
  :: LengthAssessmentResult
  -> [LengthCandidatePresentation]
presentLengthAssessment assessment = case lengthAssessmentRanking assessment of
  Just ranking -> presentLengthRanking ranking
  Nothing -> case lengthAssessmentSpinePairRanking assessment of
    Just ranking -> presentLengthSpinePairRanking ranking
    Nothing -> map presentUnassessedCandidate
      $ lengthAssessmentCandidates assessment

-- | Present one completed occurrence-sealed adapter result. Rejection has no
-- ranking and therefore no semantic note; accepted output traverses the same
-- materialized whole ranked receipts as the Main integration path.
presentLengthPostVerificationResult
  :: LengthPostVerificationResult
  -> [LengthCandidatePresentation]
presentLengthPostVerificationResult result = case
    lengthPostVerificationRanking result of
  Just ranking -> presentLengthRanking ranking
  Nothing -> map presentUnassessedCandidate
    $ lengthPostVerificationCandidates result

-- | Present one occurrence-sealed binary-product result without detaching a
-- pair receipt from the candidate which produced it.
presentLengthSpinePairPostVerificationResult
  :: LengthSpinePairPostVerificationResult
  -> [LengthCandidatePresentation]
presentLengthSpinePairPostVerificationResult result = case
    lengthSpinePairPostVerificationRanking result of
  Just ranking -> presentLengthSpinePairRanking ranking
  Nothing -> map presentUnassessedCandidate
    $ lengthSpinePairPostVerificationCandidates result

-- | Present a complete association-free ranking without separating any
-- candidate from the assessment retained by its opaque ranked receipt.
presentLengthRanking
  :: LengthRanking
  -> [LengthCandidatePresentation]
presentLengthRanking = map presentRankedCandidate . lengthRankingCandidates

presentRankedCandidate
  :: RankedLengthCandidate
  -> LengthCandidatePresentation
presentRankedCandidate ranked = LengthCandidatePresentation
  (verifiedText $ rankedLengthCandidateVerified ranked)
  $ case rankedLengthCandidateAssessment ranked of
      Counterexample receipt -> Just $ case
          rankedLengthCandidateCounterexampleSimplification ranked of
        Nothing -> renderLengthCounterexampleNote receipt
        Just simplification ->
          renderLengthCounterexampleSimplificationNote simplification
      BoundedPositive receipt -> Just
        $ renderLengthInputBoxValidationNote receipt
      ApplicableDomainEstablished receipt -> Just
        $ renderLengthApplicableDomainValidationNote receipt
      PositiveAffineApplicableDomainEstablished receipt -> Just
        $ renderLengthPositiveAffineApplicableDomainValidationNote receipt
      RelationalPositiveAffineApplicableDomainEstablished receipt -> Just
        $ renderLengthRelationalPositiveAffineApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineApplicableDomainEstablished receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
            receipt
      StrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished
          receipt -> Just
        $ renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
            receipt
      Heuristic _ -> Nothing
      Unassessed -> Nothing

presentLengthSpinePairRanking
  :: LengthSpinePairRanking
  -> [LengthCandidatePresentation]
presentLengthSpinePairRanking = map presentRankedLengthSpinePairCandidate
  . lengthSpinePairRankingCandidates

presentRankedLengthSpinePairCandidate
  :: RankedLengthSpinePairCandidate
  -> LengthCandidatePresentation
presentRankedLengthSpinePairCandidate ranked = LengthCandidatePresentation
  (verifiedText $ rankedLengthSpinePairCandidateVerified ranked)
  $ case rankedLengthSpinePairCandidateAssessment ranked of
      LengthSpinePairCounterexample receipt -> Just
        $ case rankedLengthSpinePairCandidateCounterexampleSimplification
            ranked of
          Nothing -> renderLengthSpinePairCounterexampleNote receipt
          Just simplification ->
            renderLengthSpinePairCounterexampleSimplificationNote
              simplification
      LengthSpinePairBoundedPositive receipt -> Just
        $ renderLengthSpinePairInputBoxValidationNote receipt
      LengthSpinePairApplicableDomainEstablished receipt -> Just
        $ renderLengthSpinePairApplicableDomainValidationNote receipt
      LengthSpinePairPositiveAffineApplicableDomainEstablished receipt -> Just
        $ renderLengthSpinePairPositiveAffineApplicableDomainValidationNote
            receipt
      LengthSpinePairRelationalPositiveAffineApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
            receipt
      LengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainEstablished
          receipt -> Just
        $ renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
            receipt
      LengthSpinePairHeuristic _ -> Nothing
      LengthSpinePairUnassessed -> Nothing

presentUnassessedCandidate
  :: Verified DetailedVerificationVariant
  -> LengthCandidatePresentation
presentUnassessedCandidate receipt =
  LengthCandidatePresentation (verifiedText receipt) Nothing

verifiedText
  :: Verified DetailedVerificationVariant
  -> String
verifiedText = detailedVerificationVariantText . verifiedCandidate

-- | Render one sanitized, bounded user-facing claim.  The counterexample is a
-- finite-spine model result, not automatically a realized Lean counterexample.
-- Provider names are deliberately reduced to a count, and only a bounded
-- prefix of bounded-width natural values reaches the terminal.
renderLengthCounterexampleNote
  :: ValidatedLengthCounterexample
  -> String
renderLengthCounterexampleNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "replayed finite-list-spine Length counterexample (model-relative; "
    ++ renderBasis (validatedLengthCounterexampleBasis receipt)
    ++ "): observed input spine lengths = "
    ++ renderInputs (validatedLengthCounterexampleInputs receipt)
    ++ "; result spine length = "
    ++ renderNatural (validatedLengthCounterexampleResult receipt)

-- | Render only a strict, independently replayed reduction.  This describes
-- the componentwise-bounded lexicographic search which Djex actually ran; it
-- deliberately makes no global-minimality or source-language claim.
renderLengthCounterexampleSimplificationNote
  :: ValidatedLengthCounterexampleSimplification
  -> String
renderLengthCounterexampleSimplificationNote simplification =
  take maximumLengthCounterexampleNoteCharacters $
  "replayed bounded query-owned componentwise-lexicographic "
    ++ "finite-list-spine Length counterexample (model-relative; "
    ++ renderBasis
        (validatedLengthCounterexampleSimplificationBasis simplification)
    ++ "): inspected lower-box assignments = "
    ++ renderNatural
        (validatedLengthCounterexampleSimplificationInspectedAssignmentCount
          simplification)
    ++ "; input spine lengths reduced from "
    ++ renderInputs
        (validatedLengthCounterexampleSimplificationOriginalInputs
          simplification)
    ++ " to "
    ++ renderInputs
        (validatedLengthCounterexampleSimplificationInputs simplification)
    ++ "; result spine length = "
    ++ renderNatural
        (validatedLengthCounterexampleSimplificationResult simplification)

-- | Render one sanitized positive bounded claim.  The note names the exact
-- finite box and checked/applicable counts while retaining the same explicit
-- model/provider basis as replayed counterexamples.  It intentionally says
-- nothing about the external status which merely triggered validation.
renderLengthInputBoxValidationNote
  :: ValidatedLengthInputBox
  -> String
renderLengthInputBoxValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "independently checked finite-list-spine Length input box "
    ++ "(bounded/model-relative; "
    ++ renderBasis (validatedLengthInputBoxBasis receipt)
    ++ "): inclusive input maxima = "
    ++ renderInputs (validatedLengthInputBoxInclusiveMaximums receipt)
    ++ "; checked assignments = "
    ++ renderNatural (validatedLengthInputBoxAssignmentCount receipt)
    ++ "; applicable assignments = "
    ++ renderNatural (validatedLengthInputBoxApplicableAssignmentCount receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthInputBoxApplicableAssignmentCount receipt == 0 =
        "; vacuous within this box (no assignment met the precondition)"
    | otherwise = ""

-- | Render a complete query-owned applicable-domain traversal.  Direct
-- precondition bounds establish that the finite maxima cover every applicable
-- assignment; the claim remains explicitly model-relative.
renderLengthApplicableDomainValidationNote
  :: ValidatedLengthApplicableDomain
  -> String
renderLengthApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "independently established the complete precondition-applicable "
    ++ "finite-list-spine Length domain (model-relative; "
    ++ renderBasis (validatedLengthApplicableDomainBasis receipt)
    ++ "): inclusive input maxima = "
    ++ renderInputs (validatedLengthApplicableDomainInclusiveMaximums receipt)
    ++ "; checked assignments = "
    ++ renderNatural (validatedLengthApplicableDomainAssignmentCount receipt)
    ++ "; applicable assignments = "
    ++ renderNatural
        (validatedLengthApplicableDomainApplicableAssignmentCount receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthApplicableDomainApplicableAssignmentCount receipt == 0 =
        "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the additive positive-affine coverage receipt without promoting it
-- to solver or source-language proof authority.  All values remain bounded by
-- the same terminal ceiling and provider-name redaction as existing notes.
renderLengthPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthPositiveAffineApplicableDomain
  -> String
renderLengthPositiveAffineApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under positive-affine "
    ++ "precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthPositiveAffineApplicableDomainBasis receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthPositiveAffineApplicableDomainInclusiveMaximums receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthPositiveAffineApplicableDomainAssignmentCount receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the additive relational positive-affine coverage receipt without
-- promoting its finite, model-relative closure to solver or source-language
-- proof authority.
renderLengthRelationalPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthRelationalPositiveAffineApplicableDomain
  -> String
renderLengthRelationalPositiveAffineApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under relational positive-affine "
    ++ "precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthRelationalPositiveAffineApplicableDomainBasis receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthRelationalPositiveAffineApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthRelationalPositiveAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the additive strict relational positive-affine coverage receipt.
-- The rule adds one narrowly scoped negated-at-most extraction without
-- promoting finite, model-relative closure to solver or source-language proof
-- authority.
renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under strict relational "
    ++ "positive-affine precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthStrictRelationalPositiveAffineApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the additive root-quotient-consequence coverage receipt without
-- implying authority over embedded quotient syntax, source execution, or the
-- external solver.
renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under strict relational "
    ++ "positive-affine quotient-consequence precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the cumulative root-extrema coverage receipt without implying
-- authority over nested extrema syntax, source execution, or the external
-- solver.
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under strict relational "
    ++ "positive-affine quotient/root-extrema precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the cumulative root-monus coverage receipt without implying
-- authority over embedded monus syntax, source execution, or the external
-- solver.
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length domain under strict relational "
    ++ "positive-affine quotient/root-extrema/monus precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the bounded Boolean finite-union successor without collapsing its
-- canonical antichain to one rectangular hull.  Counts precede the bounded
-- box prefix so the terminal ceiling cannot hide replay cardinalities.
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length Boolean finite-union domain under strict "
    ++ "relational positive-affine quotient/root-extrema/monus coverage "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the nominal atomic-branching successor without collapsing its
-- canonical box antichain.  Counts retain the predecessor order and remain
-- visible before the bounded maxima prefix.
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length Boolean finite-union atomic-branching domain "
    ++ "under strict relational positive-affine quotient/root-extrema/monus "
    ++ "coverage within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render the nominal recursive piecewise-affine successor without
-- collapsing its canonical box antichain.  The inherited count order remains
-- visible before the bounded maxima prefix.
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
  :: ValidatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomain
  -> String
renderLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length Boolean finite-union atomic-branching "
    ++ "recursive piecewise-affine domain under strict relational positive-affine "
    ++ "quotient/root-extrema/monus coverage within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Render both source-ordered result components of one independently replayed
-- product-domain counterexample.  The note remains model-relative and bounded.
renderLengthSpinePairCounterexampleNote
  :: ValidatedLengthSpinePairCounterexample
  -> String
renderLengthSpinePairCounterexampleNote receipt =
  let result :: LengthSpinePair Natural
      result = validatedLengthSpinePairCounterexampleResult receipt
  in take maximumLengthCounterexampleNoteCharacters $
    "replayed binary-product finite-spine Length counterexample "
      ++ "(model-relative; "
      ++ renderBasis (validatedLengthSpinePairCounterexampleBasis receipt)
      ++ "): observed input spine lengths = "
      ++ renderInputs (validatedLengthSpinePairCounterexampleInputs receipt)
      ++ "; first result spine length = "
      ++ renderNatural (lengthSpinePairFirst result)
      ++ "; second result spine length = "
      ++ renderNatural (lengthSpinePairSecond result)

-- | Nominal product-domain presentation of one strict bounded reduction.
renderLengthSpinePairCounterexampleSimplificationNote
  :: ValidatedLengthSpinePairCounterexampleSimplification
  -> String
renderLengthSpinePairCounterexampleSimplificationNote simplification =
  let result :: LengthSpinePair Natural
      result = validatedLengthSpinePairCounterexampleSimplificationResult
        simplification
  in take maximumLengthCounterexampleNoteCharacters $
    "replayed bounded query-owned componentwise-lexicographic "
      ++ "binary-product finite-spine Length counterexample (model-relative; "
      ++ renderBasis
          (validatedLengthSpinePairCounterexampleSimplificationBasis
            simplification)
      ++ "): inspected lower-box assignments = "
      ++ renderNatural
          (validatedLengthSpinePairCounterexampleSimplificationInspectedAssignmentCount
            simplification)
      ++ "; input spine lengths reduced from "
      ++ renderInputs
          (validatedLengthSpinePairCounterexampleSimplificationOriginalInputs
            simplification)
      ++ " to "
      ++ renderInputs
          (validatedLengthSpinePairCounterexampleSimplificationInputs
            simplification)
      ++ "; result spine lengths = ["
      ++ renderNatural (lengthSpinePairFirst result)
      ++ ", "
      ++ renderNatural (lengthSpinePairSecond result)
      ++ "]"

-- | Render one independently checked finite box for the product domain.
renderLengthSpinePairInputBoxValidationNote
  :: ValidatedLengthSpinePairInputBox
  -> String
renderLengthSpinePairInputBoxValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "independently checked binary-product finite-spine Length input box "
    ++ "(bounded/model-relative; "
    ++ renderBasis (validatedLengthSpinePairInputBoxBasis receipt)
    ++ "): inclusive input maxima = "
    ++ renderInputs
        (validatedLengthSpinePairInputBoxInclusiveMaximums receipt)
    ++ "; checked assignments = "
    ++ renderNatural
        (validatedLengthSpinePairInputBoxAssignmentCount receipt)
    ++ "; applicable assignments = "
    ++ renderNatural
        (validatedLengthSpinePairInputBoxApplicableAssignmentCount receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairInputBoxApplicableAssignmentCount receipt == 0 =
        "; vacuous within this box (no assignment met the precondition)"
    | otherwise = ""

-- | Product-domain sibling of the complete applicable-domain note.
renderLengthSpinePairApplicableDomainValidationNote
  :: ValidatedLengthSpinePairApplicableDomain
  -> String
renderLengthSpinePairApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "independently established the complete precondition-applicable "
    ++ "binary-product finite-spine Length domain (model-relative; "
    ++ renderBasis (validatedLengthSpinePairApplicableDomainBasis receipt)
    ++ "): inclusive input maxima = "
    ++ renderInputs
        (validatedLengthSpinePairApplicableDomainInclusiveMaximums receipt)
    ++ "; checked assignments = "
    ++ renderNatural
        (validatedLengthSpinePairApplicableDomainAssignmentCount receipt)
    ++ "; applicable assignments = "
    ++ renderNatural
        (validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the positive-affine coverage note.
renderLengthSpinePairPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthSpinePairPositiveAffineApplicableDomain
  -> String
renderLengthSpinePairPositiveAffineApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under "
    ++ "positive-affine precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairPositiveAffineApplicableDomainBasis receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairPositiveAffineApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairPositiveAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the relational positive-affine
-- coverage note.
renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthSpinePairRelationalPositiveAffineApplicableDomain
  -> String
renderLengthSpinePairRelationalPositiveAffineApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under relational "
    ++ "positive-affine precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairRelationalPositiveAffineApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairRelationalPositiveAffineApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairRelationalPositiveAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the strict relational positive-affine
-- coverage note.
renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under strict relational "
    ++ "positive-affine precondition coverage rule within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the root-quotient-consequence coverage
-- note.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under strict relational "
    ++ "positive-affine quotient-consequence precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the cumulative root-extrema coverage
-- note.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under strict relational "
    ++ "positive-affine quotient/root-extrema precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product sibling of the cumulative root-monus coverage
-- note.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length domain under strict relational "
    ++ "positive-affine quotient/root-extrema/monus precondition coverage rule "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): derived maxima = "
    ++ renderPositiveAffineMaximums
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainInclusiveMaximums
          receipt)
    ++ "; checked = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product presentation of the bounded Boolean finite union.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length Boolean finite-union domain "
    ++ "under strict relational positive-affine quotient/root-extrema/monus "
    ++ "coverage within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal product presentation of the atomic-branching finite union.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length Boolean finite-union "
    ++ "atomic-branching domain under strict relational positive-affine "
    ++ "quotient/root-extrema/monus coverage within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Nominal binary-product presentation of the recursive piecewise-affine
-- atomic-branching finite union.
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
  :: ValidatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomain
  -> String
renderLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainValidationNote
    receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length Boolean finite-union "
    ++ "atomic-branching recursive piecewise-affine domain under strict "
    ++ "relational positive-affine quotient/root-extrema/monus coverage "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBasis
          receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainBoxCount
          receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentVisitCount
          receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainAssignmentCount
          receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainInclusiveMaximumBoxes
          receipt)
 where
  vacuity
    | validatedLengthSpinePairStrictRelationalPositiveAffineQuotientRootExtremaMonusBooleanFiniteUnionAtomicBranchingRecursivePiecewiseAffineApplicableDomainApplicableAssignmentCount
        receipt == 0 =
          "; vacuous (no assignment met the precondition)"
    | otherwise = ""

-- | Hard terminal-output ceiling.  The supported file-format caps make a
-- valid Main-path note fit below this limit; the final projection also keeps
-- custom lower-level receipts from expanding terminal output past it.
maximumLengthCounterexampleNoteCharacters :: Int
maximumLengthCounterexampleNoteCharacters = 384

renderBasis :: LengthCounterexampleBasis -> String
renderBasis basis = case basis of
  ProviderIndependentFiniteSpineModel -> "provider-independent"
  FiniteSpineModelUnderAssumedProviderLaws names ->
    "conditional on " ++ show (length names) ++ " assumed provider "
      ++ (if hasExactlyOne names then "law" else "laws")
      ++ " used by this candidate"

hasExactlyOne :: [value] -> Bool
hasExactlyOne values = case values of
  [_] -> True
  _ -> False

maximumPresentedInputs :: Int
maximumPresentedInputs = 8

renderInputs :: [Natural] -> String
renderInputs values =
  let (prefix, remaining) = splitAt maximumPresentedInputs values
      suffix = case remaining of
        [] -> []
        _ : _ -> ["..."]
  in "[" ++ intercalate ", " (map renderNatural prefix ++ suffix) ++ "]"

-- Positive-affine notes carry more authority qualifiers and counts than the
-- older notes.  Showing one source-ordered maximum plus an explicit ellipsis
-- keeps even the configured eight-input, 4,096-bit, vacuous product case below
-- the shared 384-character terminal ceiling without dropping the count tail.
renderPositiveAffineMaximums :: [Natural] -> String
renderPositiveAffineMaximums values = case values of
  [] -> "[]"
  value : remaining -> "[" ++ renderNatural value ++ suffix remaining ++ "]"
 where
  suffix remaining = case remaining of
    [] -> ""
    _ : _ -> ", ..."

renderBooleanFiniteUnionMaximumBoxes :: [[Natural]] -> String
renderBooleanFiniteUnionMaximumBoxes boxes =
  let (prefix, remaining) = splitAt 2 boxes
      suffix = case remaining of
        [] -> []
        _ : _ -> ["..."]
  in "[" ++ intercalate ", "
      (map renderBooleanFiniteUnionMaximumBox prefix ++ suffix) ++ "]"

renderBooleanFiniteUnionMaximumBox :: [Natural] -> String
renderBooleanFiniteUnionMaximumBox maximums =
  let (prefix, remaining) = splitAt 2 maximums
      suffix = case remaining of
        [] -> []
        _ : _ -> ["..."]
  in "[" ++ intercalate ", " (map renderNatural prefix ++ suffix) ++ "]"

-- Twenty-four decimal digits are enough to identify ordinary examples while
-- preventing the configured 4,096-bit ceiling from producing kilobyte lines.
maximumExactNatural :: Natural
maximumExactNatural = 999999999999999999999999

renderNatural :: Natural -> String
renderNatural value
  | value <= maximumExactNatural = show value
  | otherwise = "<" ++ show (naturalBitLength value) ++ "-bit natural>"

naturalBitLength :: Natural -> Natural
naturalBitLength = go 0
 where
  go bits value
    | value == 0 = bits
    | otherwise =
        let next = bits + 1
        in next `seq` go next (value `quot` 2)
