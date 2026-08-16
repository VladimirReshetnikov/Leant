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
  , renderLengthSpinePairCounterexampleNote
  , renderLengthSpinePairCounterexampleSimplificationNote
  , renderLengthSpinePairInputBoxValidationNote
  , renderLengthSpinePairApplicableDomainValidationNote
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
  , ValidatedLengthSpinePairApplicableDomain
  , ValidatedLengthSpinePairCounterexample
  , ValidatedLengthSpinePairCounterexampleSimplification
  , ValidatedLengthSpinePairInputBox
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
  , validatedLengthApplicableDomainAssignmentVisitCount
  , validatedLengthApplicableDomainBasis
  , validatedLengthApplicableDomainBoxCount
  , validatedLengthApplicableDomainInclusiveMaximumBoxes
  , validatedLengthInputBoxApplicableAssignmentCount
  , validatedLengthInputBoxAssignmentCount
  , validatedLengthInputBoxBasis
  , validatedLengthInputBoxInclusiveMaximums
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
  , validatedLengthSpinePairApplicableDomainAssignmentVisitCount
  , validatedLengthSpinePairApplicableDomainBasis
  , validatedLengthSpinePairApplicableDomainBoxCount
  , validatedLengthSpinePairApplicableDomainInclusiveMaximumBoxes
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
  renderCounterexampleNote scalarFamily
    (validatedLengthCounterexampleBasis receipt)
    (validatedLengthCounterexampleInputs receipt)
    ("; result spine length = "
      ++ renderNatural (validatedLengthCounterexampleResult receipt))

-- | Render only a strict, independently replayed reduction.  This describes
-- the componentwise-bounded lexicographic search which Djex actually ran; it
-- deliberately makes no global-minimality or source-language claim.
renderLengthCounterexampleSimplificationNote
  :: ValidatedLengthCounterexampleSimplification
  -> String
renderLengthCounterexampleSimplificationNote simplification =
  renderSimplificationNote scalarFamily
    (validatedLengthCounterexampleSimplificationBasis simplification)
    (validatedLengthCounterexampleSimplificationInspectedAssignmentCount
      simplification)
    (validatedLengthCounterexampleSimplificationOriginalInputs simplification)
    (validatedLengthCounterexampleSimplificationInputs simplification)
    ("; result spine length = "
      ++ renderNatural
          (validatedLengthCounterexampleSimplificationResult simplification))

-- | Render one sanitized positive bounded claim.  The note names the exact
-- finite box and checked/applicable counts while retaining the same explicit
-- model/provider basis as replayed counterexamples.  It intentionally says
-- nothing about the external status which merely triggered validation.
renderLengthInputBoxValidationNote
  :: ValidatedLengthInputBox
  -> String
renderLengthInputBoxValidationNote receipt =
  renderInputBoxNote scalarFamily
    (validatedLengthInputBoxBasis receipt)
    (validatedLengthInputBoxInclusiveMaximums receipt)
    (validatedLengthInputBoxAssignmentCount receipt)
    (validatedLengthInputBoxApplicableAssignmentCount receipt)

-- | Render the current recursive piecewise-affine applicable domain
-- without collapsing its canonical box antichain.  The inherited count order
-- remains visible before the bounded maxima prefix.
renderLengthApplicableDomainValidationNote
  :: ValidatedLengthApplicableDomain
  -> String
renderLengthApplicableDomainValidationNote receipt =
  renderApplicableDomainNote "finite-spine"
    (validatedLengthApplicableDomainBasis receipt)
    (validatedLengthApplicableDomainBoxCount receipt)
    (validatedLengthApplicableDomainAssignmentVisitCount receipt)
    (validatedLengthApplicableDomainAssignmentCount receipt)
    (validatedLengthApplicableDomainApplicableAssignmentCount receipt)
    (validatedLengthApplicableDomainInclusiveMaximumBoxes receipt)

-- | Render both source-ordered result components of one independently replayed
-- product-domain counterexample.  The note remains model-relative and bounded.
renderLengthSpinePairCounterexampleNote
  :: ValidatedLengthSpinePairCounterexample
  -> String
renderLengthSpinePairCounterexampleNote receipt =
  let result :: LengthSpinePair Natural
      result = validatedLengthSpinePairCounterexampleResult receipt
  in renderCounterexampleNote pairFamily
    (validatedLengthSpinePairCounterexampleBasis receipt)
    (validatedLengthSpinePairCounterexampleInputs receipt)
    ("; first result spine length = "
      ++ renderNatural (lengthSpinePairFirst result)
      ++ "; second result spine length = "
      ++ renderNatural (lengthSpinePairSecond result))

-- | Nominal product-domain presentation of one strict bounded reduction.
renderLengthSpinePairCounterexampleSimplificationNote
  :: ValidatedLengthSpinePairCounterexampleSimplification
  -> String
renderLengthSpinePairCounterexampleSimplificationNote simplification =
  let result :: LengthSpinePair Natural
      result = validatedLengthSpinePairCounterexampleSimplificationResult
        simplification
  in renderSimplificationNote pairFamily
    (validatedLengthSpinePairCounterexampleSimplificationBasis simplification)
    (validatedLengthSpinePairCounterexampleSimplificationInspectedAssignmentCount
      simplification)
    (validatedLengthSpinePairCounterexampleSimplificationOriginalInputs
      simplification)
    (validatedLengthSpinePairCounterexampleSimplificationInputs simplification)
    ("; result spine lengths = ["
      ++ renderNatural (lengthSpinePairFirst result)
      ++ ", "
      ++ renderNatural (lengthSpinePairSecond result)
      ++ "]")

-- | Render one independently checked finite box for the product domain.
renderLengthSpinePairInputBoxValidationNote
  :: ValidatedLengthSpinePairInputBox
  -> String
renderLengthSpinePairInputBoxValidationNote receipt =
  renderInputBoxNote pairFamily
    (validatedLengthSpinePairInputBoxBasis receipt)
    (validatedLengthSpinePairInputBoxInclusiveMaximums receipt)
    (validatedLengthSpinePairInputBoxAssignmentCount receipt)
    (validatedLengthSpinePairInputBoxApplicableAssignmentCount receipt)

-- | Render the current recursive piecewise-affine product domain
-- without collapsing its canonical box antichain.  The inherited count order
-- remains visible before the bounded maxima prefix.
renderLengthSpinePairApplicableDomainValidationNote
  :: ValidatedLengthSpinePairApplicableDomain
  -> String
renderLengthSpinePairApplicableDomainValidationNote receipt =
  renderApplicableDomainNote pairFamily
    (validatedLengthSpinePairApplicableDomainBasis receipt)
    (validatedLengthSpinePairApplicableDomainBoxCount receipt)
    (validatedLengthSpinePairApplicableDomainAssignmentVisitCount receipt)
    (validatedLengthSpinePairApplicableDomainAssignmentCount receipt)
    (validatedLengthSpinePairApplicableDomainApplicableAssignmentCount receipt)
    (validatedLengthSpinePairApplicableDomainInclusiveMaximumBoxes receipt)

-- Shared note renderers -------------------------------------------------------
--
-- The scalar and binary-product receipts are nominally distinct types with
-- distinct accessors, but their notes differ only in the family phrase and,
-- for counterexamples, in how the result component(s) are described.  Each
-- public renderer above projects its receipt's fields and hands them to one
-- of the renderers below, so the wording, field order and the terminal ceiling
-- are stated once.

-- | Family phrase of the scalar domain in counterexample and box notes.
scalarFamily :: String
scalarFamily = "finite-list-spine"

-- | Family phrase of the binary-product domain in every note.
pairFamily :: String
pairFamily = "binary-product finite-spine"

-- The result description begins with its own @"; "@ separator because the
-- scalar and product domains describe one and two components differently.
renderCounterexampleNote
  :: String -> LengthCounterexampleBasis -> [Natural] -> String -> String
renderCounterexampleNote family basis inputs resultDescription =
  take maximumLengthCounterexampleNoteCharacters $
  "replayed " ++ family ++ " Length counterexample (model-relative; "
    ++ renderBasis basis
    ++ "): observed input spine lengths = "
    ++ renderInputs inputs
    ++ resultDescription

renderSimplificationNote
  :: String
  -> LengthCounterexampleBasis
  -> Natural
  -> [Natural]
  -> [Natural]
  -> String
  -> String
renderSimplificationNote family basis inspected original reduced
    resultDescription =
  take maximumLengthCounterexampleNoteCharacters $
  "replayed bounded query-owned componentwise-lexicographic "
    ++ family ++ " Length counterexample (model-relative; "
    ++ renderBasis basis
    ++ "): inspected lower-box assignments = "
    ++ renderNatural inspected
    ++ "; input spine lengths reduced from "
    ++ renderInputs original
    ++ " to "
    ++ renderInputs reduced
    ++ resultDescription

renderInputBoxNote
  :: String -> LengthCounterexampleBasis -> [Natural] -> Natural -> Natural
  -> String
renderInputBoxNote family basis maximums checked applicable =
  take maximumLengthCounterexampleNoteCharacters $
  "independently checked " ++ family ++ " Length input box "
    ++ "(bounded/model-relative; "
    ++ renderBasis basis
    ++ "): inclusive input maxima = "
    ++ renderInputs maximums
    ++ "; checked assignments = "
    ++ renderNatural checked
    ++ "; applicable assignments = "
    ++ renderNatural applicable
    ++ vacuity
 where
  vacuity
    | applicable == 0 =
        "; vacuous within this box (no assignment met the precondition)"
    | otherwise = ""

renderApplicableDomainNote
  :: String
  -> LengthCounterexampleBasis
  -> Natural
  -> Natural
  -> Natural
  -> Natural
  -> [[Natural]]
  -> String
renderApplicableDomainNote family basis boxes visits unique applicable
    maximumBoxes =
  take maximumLengthCounterexampleNoteCharacters $
  "complete " ++ family ++ " Length Boolean finite-union atomic-branching "
    ++ "recursive piecewise-affine domain under strict relational positive-affine "
    ++ "quotient/root-extrema/monus coverage within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis basis
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural boxes
    ++ "; visits = "
    ++ renderNatural visits
    ++ "; unique = "
    ++ renderNatural unique
    ++ "; applicable = "
    ++ renderNatural applicable
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes maximumBoxes
 where
  vacuity
    | applicable == 0 = "; vacuous (no assignment met the precondition)"
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
