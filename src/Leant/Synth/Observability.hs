-- | Stable observations owned by Leant's rendering and verification layers.
--
-- Djex supplies the exact counter representation.  Leant adds only the
-- frontend-specific vocabulary here, keeping backend verification failures
-- mutually exclusive and suitable for deterministic benchmark output.
module Leant.Synth.Observability
  ( CandidateRenderingRoute (..)
  , candidateRenderingRouteMetric
  , candidateRenderingRouteObservations
  , VerificationFailureClass (..)
  , verificationFailureClassCode
  , LeantSynthesisMetric (..)
  , LeantObservations
  , leantSynthesisMetricCode
  , leantObservationCodeEntries
  ) where

import Control.DeepSeq (NFData (rnf))
import Language.Haskell.Synthesis.Observability
  ( ObservationCounts
  , noObservations
  , observationEntries
  , recordObservation
  )
import Numeric.Natural (Natural)

-- | How one semantic candidate group reached Leant's renderer.
--
-- Djinn does not yet expose the shared typed-candidate lane.  Its groups are
-- deliberately 'RouteUnobserved': treating them as legacy fallbacks would
-- conflate an engine without a typed route with an explicit checked
-- Exference graph absence, and would make later Djinn adoption incomparable.
data CandidateRenderingRoute
  = RouteUnobserved
  | RouteLegacyCandidateFallback
  | RouteTypedCandidate
  deriving (Bounded, Enum, Eq, Ord, Show)

instance NFData CandidateRenderingRoute where
  rnf route = route `seq` ()

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
-- Exference records whether each bounded rendered group came from its checked
-- typed graph or from an explicit graph-absence fallback.  Djinn remains
-- deliberately unobserved until it exposes the same typed-candidate lane.
data LeantSynthesisMetric
  = LegacyCandidateFallback
  | TypedCandidateRendered
  | LeanVariantAttempted
  | LeanVerificationFailure VerificationFailureClass
  | LeanCandidateVerified
  deriving (Eq, Ord, Show)

instance NFData LeantSynthesisMetric where
  rnf metric = case metric of
    LeanVerificationFailure failure -> rnf failure
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

-- | Count each observed Exference semantic group exactly once.
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

-- | Stable machine-readable spelling of a Leant synthesis observation.
leantSynthesisMetricCode :: LeantSynthesisMetric -> String
leantSynthesisMetricCode metric = case metric of
  LegacyCandidateFallback -> "legacy-candidate-fallback"
  TypedCandidateRendered -> "typed-candidate-rendered"
  LeanVariantAttempted -> "lean-variant-attempted"
  LeanVerificationFailure failure ->
    "lean-verification-failure." ++ verificationFailureClassCode failure
  LeanCandidateVerified -> "lean-candidate-verified"

-- | Enumerate stable codes and exact positive counts in metric order.
--
-- 'ObservationCounts' already guarantees ascending keys and omits zero
-- entries, so this projection is deterministic without exposing its map.
leantObservationCodeEntries :: LeantObservations -> [(String, Natural)]
leantObservationCodeEntries observations =
  [ (leantSynthesisMetricCode metric, count)
  | (metric, count) <- observationEntries observations
  ]
