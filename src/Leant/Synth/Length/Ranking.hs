-- | Conservative live Length ranking for callback-verified candidates.
--
-- This facade exposes complete association-free reports only.  The
-- occurrence-associated plan used by the post-verification permutation seal
-- is package-private, so ordinary ranking consumers cannot erase a
-- batch-scoped handle before that seal succeeds.  Within one batch, a later
-- checked problem may independently try up to four validated input vectors
-- from a fixed newest-first MRU bank before opening another live query; no
-- earlier verdict or evidence receipt is reused.
module Leant.Synth.Length.Ranking
  ( LengthRankingInputError (..)
  , LengthRankingAssessment (..)
  , LengthPreparationRefusalClass (..)
  , lengthPreparationRefusalClassCode
  , lengthHandoffPreparationRefusalClass
  , lengthQueryPreparationRefusalClass
  , RankedLengthCandidate
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidateVerified
  , rankedLengthCandidateAssessment
  , rankedLengthCandidatePreparationRefusal
  , LengthRankingFailureClass (..)
  , LengthRankingFailure
  , lengthRankingFailureClass
  , lengthRankingFailureCleanupIncomplete
  , lengthRankingFailureOriginalIndex
  , LengthRanking
  , lengthRankingCandidates
  , lengthRankingFailure
  , rankVerifiedLengthCandidates
  ) where

import Leant.Synth.Length.Ranking.Internal
  ( LengthPreparationRefusalClass (..)
  , LengthRanking
  , LengthRankingAssessment (..)
  , LengthRankingFailure
  , LengthRankingFailureClass (..)
  , LengthRankingInputError (..)
  , RankedLengthCandidate
  , lengthHandoffPreparationRefusalClass
  , lengthPreparationRefusalClassCode
  , lengthQueryPreparationRefusalClass
  , lengthRankingCandidates
  , lengthRankingFailure
  , lengthRankingFailureClass
  , lengthRankingFailureCleanupIncomplete
  , lengthRankingFailureOriginalIndex
  , rankVerifiedLengthCandidates
  , rankedLengthCandidateAssessment
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidatePreparationRefusal
  , rankedLengthCandidateVerified
  )
