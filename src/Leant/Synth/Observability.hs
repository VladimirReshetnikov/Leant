-- | Stable observations owned by Leant's rendering and verification layers.
--
-- Djex supplies the exact counter representation.  Leant adds only the
-- frontend-specific vocabulary here, keeping backend verification failures
-- mutually exclusive and suitable for deterministic benchmark output.
module Leant.Synth.Observability
  ( CandidateRenderingRoute (..)
  , candidateRenderingRouteMetric
  , candidateRenderingRouteObservations
  , CandidateGraphObservation (..)
  , SourceGraphAbsenceReason (..)
  , candidateGraphObservation
  , candidateGraphObservations
  , djinnSourceGraphAbsenceReason
  , exferenceSourceGraphAbsenceReason
  , VerificationFailureClass (..)
  , verificationFailureClassCode
  , LeantSynthesisMetric (..)
  , LeantObservations
  , leantSynthesisMetricCode
  , leantObservationCodeEntries
  ) where

import Control.DeepSeq (NFData (rnf))
import Language.Haskell.Djex
  ( DjinnTermGraphAbsence (..)
  , ExferenceTermGraphAbsence (..)
  )
import Language.Haskell.Synthesis.Observability
  ( ObservationCounts
  , noObservations
  , observationEntries
  , recordObservation
  )
import Numeric.Natural (Natural)

-- | How one semantic candidate group reached Leant's renderer.
--
-- Either engine's own checked graph uses 'RouteTypedCandidate'. Djinn's
-- explicit graph absence preserves its historical 'RouteUnobserved' route;
-- Exference's explicit graph absence uses 'RouteLegacyCandidateFallback'.
-- Target-only reconstruction also remains unobserved and carries no graph
-- authority for the changed expression.
data CandidateRenderingRoute
  = RouteUnobserved
  | RouteLegacyCandidateFallback
  | RouteTypedCandidate
  deriving (Bounded, Enum, Eq, Ord, Show)

instance NFData CandidateRenderingRoute where
  rnf route = route `seq` ()

-- | Stable backend-owned absence categories. Diagnostic strings, source
-- types, and graph coordinates are deliberately not inspected or retained.
data SourceGraphAbsenceReason
  = DjinnSourceContextUnavailable
  | DjinnSourceTypingFailed
  | ExferenceImplicitLocalSpecialization
  | ExferenceSubsumedLocalSpecialization
  | ExferenceNestedForallIntroduction
  | ExferenceNominalConstructorPattern
  | ExferenceUnsupportedStructuralConstructorPattern
  | ExferenceUnsupportedContextualVisibleApplication
  | ExferenceUnsupportedContextEvidence
  | ExferenceUnsupportedContextualCertificateGraph
  | ExferenceEvidenceMismatch
  | ExferenceConstructionLimit
  | ExferenceSealingFailure
  | ExferenceCertificateAssociationFailure
  | ExferenceProjectionMismatch
  deriving (Bounded, Enum, Eq, Ord, Show)

instance NFData SourceGraphAbsenceReason where
  rnf reason = reason `seq` ()

-- | Additional facts about the displayed group's source route. Absence and
-- target-only reconstruction can both occur, so neither fact hides the other.
-- This observation is diagnostic only and never confers typed authority.
data CandidateGraphObservation = CandidateGraphObservation
  (Maybe SourceGraphAbsenceReason)
  Bool
  deriving (Eq, Ord, Show)

-- | Inspect only graph availability and the renderer's existing reconstruction
-- decision. A present graph's payload and an absence's diagnostic payload stay
-- lazy; the backend classifier reads only the absence constructor.
candidateGraphObservation
  :: (absence -> SourceGraphAbsenceReason)
  -> Either absence graph
  -> Bool
  -> Maybe CandidateGraphObservation
candidateGraphObservation classify availability reconstructed = case availability of
  Left absence -> Just $ CandidateGraphObservation (Just $ classify absence) reconstructed
  Right _ | reconstructed -> Just $ CandidateGraphObservation Nothing True
          | otherwise -> Nothing

djinnSourceGraphAbsenceReason :: DjinnTermGraphAbsence -> SourceGraphAbsenceReason
djinnSourceGraphAbsenceReason absence = case absence of
  DjinnTermGraphSourceTypingContextUnavailable -> DjinnSourceContextUnavailable
  DjinnTermGraphSourceTypingFailure _ -> DjinnSourceTypingFailed

exferenceSourceGraphAbsenceReason :: ExferenceTermGraphAbsence -> SourceGraphAbsenceReason
exferenceSourceGraphAbsenceReason absence = case absence of
  ImplicitLocalSpecialization{} -> ExferenceImplicitLocalSpecialization
  SubsumedLocalSpecialization{} -> ExferenceSubsumedLocalSpecialization
  NestedForallIntroduction{} -> ExferenceNestedForallIntroduction
  NominalConstructorPattern{} -> ExferenceNominalConstructorPattern
  UnsupportedStructuralConstructorPattern{} -> ExferenceUnsupportedStructuralConstructorPattern
  UnsupportedContextualVisibleApplication{} -> ExferenceUnsupportedContextualVisibleApplication
  UnsupportedContextEvidence{} -> ExferenceUnsupportedContextEvidence
  UnsupportedContextualCertificateGraph -> ExferenceUnsupportedContextualCertificateGraph
  TermGraphEvidenceMismatch -> ExferenceEvidenceMismatch
  TermGraphConstructionLimit{} -> ExferenceConstructionLimit
  TermGraphSealingFailure{} -> ExferenceSealingFailure
  TermGraphCertificateAssociationFailure{} -> ExferenceCertificateAssociationFailure
  TermGraphProjectionMismatch -> ExferenceProjectionMismatch

-- | The first reason, in protocol precedence order, that Lean rejected one
-- rendered candidate variant.
data VerificationFailureClass
  = BackendRequestFailure
  | BackendFatalResponse
  | LeanErrorDiagnostic
  | LeanContainsSorry
  deriving (Bounded, Enum, Eq, Ord, Show)

instance NFData VerificationFailureClass where
  rnf failure = failure `seq` ()

-- | Stable machine-readable spelling of one verification failure class.
verificationFailureClassCode :: VerificationFailureClass -> String
verificationFailureClassCode failure = case failure of
  BackendRequestFailure -> "backend-request"
  BackendFatalResponse -> "backend-fatal-response"
  LeanErrorDiagnostic -> "error-diagnostic"
  LeanContainsSorry -> "contains-sorry"

-- | Leant-local synthesis observations.
--
-- Each bounded group rendered from its originating checked graph is counted.
-- The existing engine-specific graph-absence route conventions remain stable.
data LeantSynthesisMetric
  = LegacyCandidateFallback
  | TypedCandidateRendered
  | LeanVariantAttempted
  | LeanVerificationFailure VerificationFailureClass
  | LeanCandidateVerified
  | SourceGraphAbsent SourceGraphAbsenceReason
  | TargetOnlyReconstructed
  deriving (Eq, Ord, Show)

instance NFData LeantSynthesisMetric where
  rnf metric = case metric of
    LeanVerificationFailure failure -> rnf failure
    SourceGraphAbsent reason -> rnf reason
    _ -> metric `seq` ()

-- | Exact Leant-local observations using Djex's shared counter carrier.
type LeantObservations = ObservationCounts LeantSynthesisMetric

-- | The one observation, if any, owned by a rendering route.
candidateRenderingRouteMetric
  :: CandidateRenderingRoute
  -> Maybe LeantSynthesisMetric
candidateRenderingRouteMetric route = case route of
  RouteUnobserved -> Nothing
  RouteLegacyCandidateFallback -> Just LegacyCandidateFallback
  RouteTypedCandidate -> Just TypedCandidateRendered

-- | Count each observed semantic group exactly once.
--
-- This sidecar is independent of Lean variant attempts and verdicts.  The
-- caller chooses the bounded semantic-group prefix before applying it, so
-- verifier success quotas cannot silently change route counts.
candidateRenderingRouteObservations
  :: Foldable collection
  => collection CandidateRenderingRoute
  -> LeantObservations
candidateRenderingRouteObservations = foldr record noObservations
 where
  record route observations = case candidateRenderingRouteMetric route of
    Nothing -> observations
    Just metric -> recordObservation metric observations

-- | Count only the selected groups' additional graph facts. The historical
-- route counters remain independent, including Exference's legacy fallback.
candidateGraphObservations
  :: Foldable collection
  => collection CandidateGraphObservation
  -> LeantObservations
candidateGraphObservations = foldr record noObservations
 where
  record (CandidateGraphObservation absence reconstructed) observations =
    let withAbsence = maybe observations
          (\reason -> recordObservation (SourceGraphAbsent reason) observations) absence
    in if reconstructed then recordObservation TargetOnlyReconstructed withAbsence
      else withAbsence

-- | Stable machine-readable spelling of a Leant synthesis observation.
leantSynthesisMetricCode :: LeantSynthesisMetric -> String
leantSynthesisMetricCode metric = case metric of
  LegacyCandidateFallback -> "legacy-candidate-fallback"
  TypedCandidateRendered -> "typed-candidate-rendered"
  LeanVariantAttempted -> "lean-variant-attempted"
  LeanVerificationFailure failure ->
    "lean-verification-failure." ++ verificationFailureClassCode failure
  LeanCandidateVerified -> "lean-candidate-verified"
  SourceGraphAbsent reason -> "source-graph-absent." ++ case reason of
    DjinnSourceContextUnavailable -> "djinn.source-context-unavailable"
    DjinnSourceTypingFailed -> "djinn.source-typing-failure"
    ExferenceImplicitLocalSpecialization -> "exference.implicit-local-specialization"
    ExferenceSubsumedLocalSpecialization -> "exference.subsumed-local-specialization"
    ExferenceNestedForallIntroduction -> "exference.nested-forall-introduction"
    ExferenceNominalConstructorPattern -> "exference.nominal-constructor-pattern"
    ExferenceUnsupportedStructuralConstructorPattern -> "exference.unsupported-structural-constructor-pattern"
    ExferenceUnsupportedContextualVisibleApplication -> "exference.unsupported-contextual-visible-application"
    ExferenceUnsupportedContextEvidence -> "exference.unsupported-context-evidence"
    ExferenceUnsupportedContextualCertificateGraph -> "exference.unsupported-contextual-certificate-graph"
    ExferenceEvidenceMismatch -> "exference.evidence-mismatch"
    ExferenceConstructionLimit -> "exference.construction-limit"
    ExferenceSealingFailure -> "exference.sealing-failure"
    ExferenceCertificateAssociationFailure -> "exference.certificate-association-failure"
    ExferenceProjectionMismatch -> "exference.projection-mismatch"
  TargetOnlyReconstructed -> "target-only-reconstructed"

-- | Enumerate stable codes and exact positive counts in metric order.
--
-- 'ObservationCounts' already guarantees ascending keys and omits zero
-- entries, so this projection is deterministic without exposing its map.
leantObservationCodeEntries :: LeantObservations -> [(String, Natural)]
leantObservationCodeEntries observations =
  [ (leantSynthesisMetricCode metric, count)
  | (metric, count) <- observationEntries observations
  ]
