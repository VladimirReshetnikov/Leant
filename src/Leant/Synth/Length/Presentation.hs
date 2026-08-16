-- | Association-safe terminal presentation of finite-spine Length evidence.
--
-- Candidate text and its optional semantic note enter one opaque value from
-- the same ranked or selected receipt.  Rejected candidates use a separate
-- opaque presentation projected directly from their sealed wrappers.  Main
-- never zips detached candidates and evidence.
module Leant.Synth.Length.Presentation
  ( LengthCandidatePresentation
  , LengthCandidateRejectionPresentation
  , presentLengthAssessment
  , presentLengthAssessmentRejections
  , presentLengthPostVerificationResult
  , presentLengthSpinePairPostVerificationResult
  , presentLengthSelectionResult
  , presentLengthSpinePairSelectionResult
  , lengthCandidatePresentationText
  , lengthCandidatePresentationNote
  , lengthCandidateRejectionPresentationText
  , lengthCandidateRejectionPresentationNote
  , renderLengthSelectionRejectionNote
  , renderLengthSpinePairSelectionRejectionNote
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
import Leant.Synth.BehavioralSelection
  ( BehaviorallyRejected
  , BehaviorallySelected
  , behaviorallyRejectedReason
  , behaviorallyRejectedVerified
  , behaviorallySelectedRetention
  , behaviorallySelectedVerified
  )
import Leant.Synth.Length.Integration
  ( LengthAssessmentResult
  , lengthAssessmentCandidates
  , lengthAssessmentRanking
  , lengthAssessmentSelectionResult
  , lengthAssessmentSpinePairRanking
  , lengthAssessmentSpinePairSelectionResult
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
import Leant.Synth.Length.Selection
  ( LengthSelectionRejection
  , LengthSelectionResult
  , LengthSelectionRetention
  , LengthSelectionRetentionClass (..)
  , lengthSelectionCandidates
  , lengthSelectionRejected
  , lengthSelectionRejectionCounterexample
  , lengthSelectionRejectionCounterexampleSimplification
  , lengthSelectionRetentionApplicableDomain
  , lengthSelectionRetentionClass
  , lengthSelectionRetentionInputBox
  , lengthSelectionSelected
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
import Leant.Synth.Length.SpinePair.Selection
  ( LengthSpinePairSelectionRejection
  , LengthSpinePairSelectionResult
  , LengthSpinePairSelectionRetention
  , LengthSpinePairSelectionRetentionClass (..)
  , lengthSpinePairSelectionCandidates
  , lengthSpinePairSelectionRejected
  , lengthSpinePairSelectionRejectionCounterexample
  , lengthSpinePairSelectionRejectionCounterexampleSimplification
  , lengthSpinePairSelectionRetentionApplicableDomain
  , lengthSpinePairSelectionRetentionClass
  , lengthSpinePairSelectionRetentionInputBox
  , lengthSpinePairSelectionSelected
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

-- | One omitted candidate and the exact independently replayed evidence
-- retained by that same sealed rejection occurrence.
data LengthCandidateRejectionPresentation =
  LengthCandidateRejectionPresentation String String

lengthCandidatePresentationText
  :: LengthCandidatePresentation
  -> String
lengthCandidatePresentationText (LengthCandidatePresentation text _) = text

lengthCandidatePresentationNote
  :: LengthCandidatePresentation
  -> Maybe String
lengthCandidatePresentationNote (LengthCandidatePresentation _ note) = note

lengthCandidateRejectionPresentationText
  :: LengthCandidateRejectionPresentation
  -> String
lengthCandidateRejectionPresentationText
    (LengthCandidateRejectionPresentation text _) = text

lengthCandidateRejectionPresentationNote
  :: LengthCandidateRejectionPresentation
  -> String
lengthCandidateRejectionPresentationNote
    (LengthCandidateRejectionPresentation _ note) = note

-- | Choose exactly one survivor presentation source.  Accepted rankings and
-- filters are traversed through opaque candidate/evidence associations;
-- disabled or preserve-all assessment uses the effective candidate projection
-- with no semantic note.
presentLengthAssessment
  :: LengthAssessmentResult
  -> [LengthCandidatePresentation]
presentLengthAssessment assessment = case
    lengthAssessmentSelectionResult assessment of
  Just selected -> presentLengthSelectionResult selected
  Nothing -> case lengthAssessmentSpinePairSelectionResult assessment of
    Just selected -> presentLengthSpinePairSelectionResult selected
    Nothing -> case lengthAssessmentRanking assessment of
      Just ranking -> presentLengthRanking ranking
      Nothing -> case lengthAssessmentSpinePairRanking assessment of
        Just ranking -> presentLengthSpinePairRanking ranking
        Nothing -> map presentUnassessedCandidate
          $ lengthAssessmentCandidates assessment

-- | Present omitted occurrences separately from survivors.  Ranking,
-- disabled assessment, and preserve-all filter failures have no rejections.
-- Accepted filters traverse only the sealed associated rejection wrappers.
presentLengthAssessmentRejections
  :: LengthAssessmentResult
  -> [LengthCandidateRejectionPresentation]
presentLengthAssessmentRejections assessment = case
    lengthAssessmentSelectionResult assessment of
  Just selected -> presentLengthSelectionRejections selected
  Nothing -> case lengthAssessmentSpinePairSelectionResult assessment of
    Just selected -> presentLengthSpinePairSelectionRejections selected
    Nothing -> []

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

-- | Present scalar filter survivors through their associated retention
-- wrappers.  Preserve-all failure remains an unannotated original batch.
presentLengthSelectionResult
  :: LengthSelectionResult
  -> [LengthCandidatePresentation]
presentLengthSelectionResult result = case lengthSelectionSelected result of
  Nothing -> map presentUnassessedCandidate $ lengthSelectionCandidates result
  Just selected -> map presentLengthSelectionCandidate selected

-- | Present pair-domain filter survivors without detaching retention evidence
-- from the candidate occurrence which owns it.
presentLengthSpinePairSelectionResult
  :: LengthSpinePairSelectionResult
  -> [LengthCandidatePresentation]
presentLengthSpinePairSelectionResult result = case
    lengthSpinePairSelectionSelected result of
  Nothing -> map presentUnassessedCandidate
    $ lengthSpinePairSelectionCandidates result
  Just selected -> map presentLengthSpinePairSelectionCandidate selected

presentLengthSelectionCandidate
  :: BehaviorallySelected
      DetailedVerificationVariant LengthSelectionRetention
  -> LengthCandidatePresentation
presentLengthSelectionCandidate selected = LengthCandidatePresentation
  (verifiedText $ behaviorallySelectedVerified selected)
  $ presentLengthSelectionRetention
  $ behaviorallySelectedRetention selected

presentLengthSelectionRetention
  :: LengthSelectionRetention
  -> Maybe String
presentLengthSelectionRetention retention = case
    lengthSelectionRetentionClass retention of
  LengthSelectionBoundedPositive -> renderLengthInputBoxValidationNote
    <$> lengthSelectionRetentionInputBox retention
  LengthSelectionApplicableDomainEstablished ->
    renderLengthApplicableDomainValidationNote
      <$> lengthSelectionRetentionApplicableDomain retention
  LengthSelectionPreparationRefused -> Nothing
  LengthSelectionUnassessed -> Nothing
  LengthSelectionHeuristic -> Nothing

presentLengthSpinePairSelectionCandidate
  :: BehaviorallySelected
      DetailedVerificationVariant LengthSpinePairSelectionRetention
  -> LengthCandidatePresentation
presentLengthSpinePairSelectionCandidate selected = LengthCandidatePresentation
  (verifiedText $ behaviorallySelectedVerified selected)
  $ presentLengthSpinePairSelectionRetention
  $ behaviorallySelectedRetention selected

presentLengthSpinePairSelectionRetention
  :: LengthSpinePairSelectionRetention
  -> Maybe String
presentLengthSpinePairSelectionRetention retention = case
    lengthSpinePairSelectionRetentionClass retention of
  LengthSpinePairSelectionBoundedPositive ->
    renderLengthSpinePairInputBoxValidationNote
      <$> lengthSpinePairSelectionRetentionInputBox retention
  LengthSpinePairSelectionApplicableDomainEstablished ->
    renderLengthSpinePairApplicableDomainValidationNote
      <$> lengthSpinePairSelectionRetentionApplicableDomain retention
  LengthSpinePairSelectionPreparationRefused -> Nothing
  LengthSpinePairSelectionUnassessed -> Nothing
  LengthSpinePairSelectionHeuristic -> Nothing

presentLengthSelectionRejections
  :: LengthSelectionResult
  -> [LengthCandidateRejectionPresentation]
presentLengthSelectionRejections result = case lengthSelectionRejected result of
  Nothing -> []
  Just rejected -> map presentLengthSelectionRejection rejected

presentLengthSelectionRejection
  :: BehaviorallyRejected
      DetailedVerificationVariant LengthSelectionRejection
  -> LengthCandidateRejectionPresentation
presentLengthSelectionRejection rejected =
  LengthCandidateRejectionPresentation
    (verifiedText $ behaviorallyRejectedVerified rejected)
    (renderLengthSelectionRejectionNote
      $ behaviorallyRejectedReason rejected)

presentLengthSpinePairSelectionRejections
  :: LengthSpinePairSelectionResult
  -> [LengthCandidateRejectionPresentation]
presentLengthSpinePairSelectionRejections result = case
    lengthSpinePairSelectionRejected result of
  Nothing -> []
  Just rejected -> map presentLengthSpinePairSelectionRejection rejected

presentLengthSpinePairSelectionRejection
  :: BehaviorallyRejected
      DetailedVerificationVariant LengthSpinePairSelectionRejection
  -> LengthCandidateRejectionPresentation
presentLengthSpinePairSelectionRejection rejected =
  LengthCandidateRejectionPresentation
    (verifiedText $ behaviorallyRejectedVerified rejected)
    (renderLengthSpinePairSelectionRejectionNote
      $ behaviorallyRejectedReason rejected)

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

-- | Render the exact scalar replay evidence which authorized omission.  The
-- optional independently replayed reduction is preferred when available;
-- the ordinary replay receipt remains mandatory in the opaque rejection.
renderLengthSelectionRejectionNote
  :: LengthSelectionRejection
  -> String
renderLengthSelectionRejectionNote rejection = case
    lengthSelectionRejectionCounterexampleSimplification rejection of
  Just simplification ->
    renderLengthCounterexampleSimplificationNote simplification
  Nothing -> renderLengthCounterexampleNote
    $ lengthSelectionRejectionCounterexample rejection

-- | Nominal binary-product sibling of the scalar rejection renderer.
renderLengthSpinePairSelectionRejectionNote
  :: LengthSpinePairSelectionRejection
  -> String
renderLengthSpinePairSelectionRejectionNote rejection = case
    lengthSpinePairSelectionRejectionCounterexampleSimplification rejection of
  Just simplification ->
    renderLengthSpinePairCounterexampleSimplificationNote simplification
  Nothing -> renderLengthSpinePairCounterexampleNote
    $ lengthSpinePairSelectionRejectionCounterexample rejection

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

-- | Render the current recursive piecewise-affine applicable domain
-- without collapsing its canonical box antichain.  The inherited count order
-- remains visible before the bounded maxima prefix.
renderLengthApplicableDomainValidationNote
  :: ValidatedLengthApplicableDomain
  -> String
renderLengthApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete finite-spine Length Boolean finite-union atomic-branching "
    ++ "recursive piecewise-affine domain under strict relational positive-affine "
    ++ "quotient/root-extrema/monus coverage within admitted bounds "
    ++ "(model/provider-relative; "
    ++ renderBasis (validatedLengthApplicableDomainBasis receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural (validatedLengthApplicableDomainBoxCount receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthApplicableDomainAssignmentVisitCount receipt)
    ++ "; unique = "
    ++ renderNatural (validatedLengthApplicableDomainAssignmentCount receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthApplicableDomainApplicableAssignmentCount receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthApplicableDomainInclusiveMaximumBoxes receipt)
 where
  vacuity
    | validatedLengthApplicableDomainApplicableAssignmentCount receipt == 0 =
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

-- | Render the current recursive piecewise-affine product domain
-- without collapsing its canonical box antichain.  The inherited count order
-- remains visible before the bounded maxima prefix.
renderLengthSpinePairApplicableDomainValidationNote
  :: ValidatedLengthSpinePairApplicableDomain
  -> String
renderLengthSpinePairApplicableDomainValidationNote receipt =
  take maximumLengthCounterexampleNoteCharacters $
  "complete binary-product finite-spine Length Boolean finite-union "
    ++ "atomic-branching recursive piecewise-affine domain under strict "
    ++ "relational positive-affine quotient/root-extrema/monus coverage "
    ++ "within admitted bounds (model/provider-relative; "
    ++ renderBasis (validatedLengthSpinePairApplicableDomainBasis receipt)
    ++ "; no global proof or solver authority): boxes = "
    ++ renderNatural (validatedLengthSpinePairApplicableDomainBoxCount receipt)
    ++ "; visits = "
    ++ renderNatural
        (validatedLengthSpinePairApplicableDomainAssignmentVisitCount receipt)
    ++ "; unique = "
    ++ renderNatural
        (validatedLengthSpinePairApplicableDomainAssignmentCount receipt)
    ++ "; applicable = "
    ++ renderNatural
        (validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
          receipt)
    ++ vacuity
    ++ "; maxima = "
    ++ renderBooleanFiniteUnionMaximumBoxes
        (validatedLengthSpinePairApplicableDomainInclusiveMaximumBoxes receipt)
 where
  vacuity
    | validatedLengthSpinePairApplicableDomainApplicableAssignmentCount
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
