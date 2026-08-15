-- | Conservative live ranking for canonical binary-product finite-spine
-- Length behavior.  Only complete association-free reports cross this facade.
module Leant.Synth.Length.SpinePair.Ranking
  ( LengthRankingInputError (..)
  , LengthPreparationRefusalClass (..)
  , lengthPreparationRefusalClassCode
  , lengthSpinePairHandoffPreparationRefusalClass
  , lengthSpinePairQueryPreparationRefusalClass
  , LengthSpinePairRankingAssessment (..)
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
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  ) where

import Leant.Synth.Length.Ranking
  ( LengthPreparationRefusalClass (..)
  , LengthRankingInputError (..)
  , lengthPreparationRefusalClassCode
  )
import Leant.Synth.Length.SpinePair.Ranking.Internal
  ( LengthSpinePairRanking
  , LengthSpinePairRankingAssessment (..)
  , LengthSpinePairRankingFailure
  , LengthSpinePairRankingFailureClass (..)
  , RankedLengthSpinePairCandidate
  , lengthSpinePairHandoffPreparationRefusalClass
  , lengthSpinePairQueryPreparationRefusalClass
  , lengthSpinePairRankingCandidates
  , lengthSpinePairRankingFailure
  , lengthSpinePairRankingFailureClass
  , lengthSpinePairRankingFailureCleanupIncomplete
  , lengthSpinePairRankingFailureOriginalIndex
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  , rankedLengthSpinePairCandidateAssessment
  , rankedLengthSpinePairCandidateCounterexampleSimplification
  , rankedLengthSpinePairCandidateOriginalIndex
  , rankedLengthSpinePairCandidatePreparationRefusal
  , rankedLengthSpinePairCandidateVerified
  )
