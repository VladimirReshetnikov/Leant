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
  , renderLengthInputBoxValidationNote
  , renderLengthSpinePairCounterexampleNote
  , renderLengthSpinePairInputBoxValidationNote
  , maximumLengthCounterexampleNoteCharacters
  ) where

import Data.List (intercalate)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthCounterexampleBasis (..)
  , LengthSpinePair
  , ValidatedLengthCounterexample
  , ValidatedLengthInputBox
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairInputBox
  , lengthSpinePairFirst
  , lengthSpinePairSecond
  , validatedLengthCounterexampleBasis
  , validatedLengthCounterexampleInputs
  , validatedLengthCounterexampleResult
  , validatedLengthInputBoxApplicableAssignmentCount
  , validatedLengthInputBoxAssignmentCount
  , validatedLengthInputBoxBasis
  , validatedLengthInputBoxInclusiveMaximums
  , validatedLengthSpinePairCounterexampleBasis
  , validatedLengthSpinePairCounterexampleInputs
  , validatedLengthSpinePairCounterexampleResult
  , validatedLengthSpinePairInputBoxApplicableAssignmentCount
  , validatedLengthSpinePairInputBoxAssignmentCount
  , validatedLengthSpinePairInputBoxBasis
  , validatedLengthSpinePairInputBoxInclusiveMaximums
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
      Counterexample receipt -> Just $ renderLengthCounterexampleNote receipt
      BoundedPositive receipt -> Just
        $ renderLengthInputBoxValidationNote receipt
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
        $ renderLengthSpinePairCounterexampleNote receipt
      LengthSpinePairBoundedPositive receipt -> Just
        $ renderLengthSpinePairInputBoxValidationNote receipt
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
