-- | Stable observations owned by Leant's rendering and verification layers.
--
-- Djex supplies the exact counter representation.  Leant adds only the
-- frontend-specific vocabulary here, keeping backend verification failures
-- mutually exclusive and suitable for deterministic benchmark output.
module Leant.Synth.Observability
  ( VerificationFailureClass (..)
  , verificationFailureClassCode
  , LeantSynthesisMetric (..)
  , LeantObservations
  , leantSynthesisMetricCode
  , leantObservationCodeEntries
  ) where

import Control.DeepSeq (NFData (rnf))
import Language.Haskell.Synthesis.Observability
  ( ObservationCounts
  , observationEntries
  )
import Numeric.Natural (Natural)

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
-- Rendering-route observations are defined now so typed candidate rendering
-- can adopt the same stable vocabulary later.  They are intentionally not
-- recorded by the legacy pipeline until that route is made explicit.
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
