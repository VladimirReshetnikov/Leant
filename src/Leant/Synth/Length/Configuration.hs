-- | Explicit ownership of live Length ranking policy.
--
-- Construction is pure and performs only Djex's bounded policy validation.
-- 'LengthRankingPolicy' owns reusable execution and replay policy, while a
-- 'LeanLengthContract' is supplied separately for each ranking request.  The
-- older 'LengthRankingConfiguration' remains the opaque compatibility bundle
-- decoded by the versioned configuration-file grammar.
--
-- A successful value does not establish that the configured path resolves to
-- a usable executable, that a later pre-spawn executable-file snapshot matches
-- an optional SHA-256 expectation, or that the child has the required Z3
-- capability; those observations belong to the lexical live session opened by
-- each ranking run.  A caller-supplied contract likewise remains an assertion
-- until checked with each exact callback-verified candidate.
--
-- There is deliberately no default source, executable discovery, path
-- normalization, environment lookup, or projection from the opaque sealed
-- value.  Callers must provide the complete execution and replay policy plus
-- each contract explicitly.  Neither runner retains a worker: every eligible
-- batch delegates to the rank-N live scope owned by
-- 'rankVerifiedLengthCandidates'.
module Leant.Synth.Length.Configuration
  ( LengthRankingPolicySource (..)
  , LengthRankingPolicy
  , mkLengthRankingPolicy
  , rankPostVerificationLengthCandidatesWithPolicy
  , rankVerifiedLengthCandidatesWithPolicy
  , LengthRankingConfigurationSource (..)
  , LengthRankingConfiguration
  , LengthRankingConfigurationError (..)
  , mkLengthRankingConfiguration
  , rankPostVerificationLengthCandidatesConfigured
  , rankVerifiedLengthCandidatesConfigured
  ) where

import Language.Haskell.Djex
  ( LengthEvaluationLimitError
  , LengthEvaluationLimitSource
  , LengthEvaluationLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibExecutionConfigError
  , LengthSMTLibExecutionConfigSource
  , LengthSMTLibExecutionLimits
  , mkLengthEvaluationLimits
  , mkLengthSMTLibExecutionConfig
  )

import Leant.Synth.Engine (DetailedVerificationVariant)
import Leant.Synth.Length.Contract (LeanLengthContract)
import Leant.Synth.Length.Ranking
  ( AssociatedLengthRanking
  , LengthRanking
  , LengthRankingInputError
  , rankPostVerificationLengthCandidates
  , rankVerifiedLengthCandidates
  )
import Leant.Synth.PostVerification (PostVerificationCandidate)
import Leant.Synth.Verification (Verified)

-- | Reusable source policy for live solver ownership and independent replay.
--
-- This contains no behavioral contract.  One admitted policy may therefore be
-- paired explicitly with different request-owned contracts without treating a
-- goal assertion as process configuration.
data LengthRankingPolicySource = LengthRankingPolicySource
  { lengthRankingPolicyExecutionLimits :: LengthSMTLibExecutionLimits
  , lengthRankingPolicyExecutionSource :: LengthSMTLibExecutionConfigSource
  , lengthRankingPolicyEvaluationSource :: LengthEvaluationLimitSource
  }

-- | Validated reusable policy with no process, worker, or contract authority.
-- The constructor and all execution material remain private.
data LengthRankingPolicy = LengthRankingPolicy
  !LengthSMTLibExecutionConfig
  !LengthEvaluationLimits

-- | Compatibility source which bundles one policy and one contract.
--
-- The execution source includes the absolute executable path, optional exact
-- SHA-256 pre-spawn snapshot expectation, finite solver and host budgets,
-- artifact policy, and bounded response policy.  Execution admission limits
-- and replay limits are separate and equally explicit.  No field is inferred
-- from the host or current goal.
data LengthRankingConfigurationSource = LengthRankingConfigurationSource
  { lengthRankingConfigurationExecutionLimits
      :: LengthSMTLibExecutionLimits
  , lengthRankingConfigurationExecutionSource
      :: LengthSMTLibExecutionConfigSource
  , lengthRankingConfigurationEvaluationSource
      :: LengthEvaluationLimitSource
  , lengthRankingConfigurationContract :: LeanLengthContract
  }

-- | Compatibility value retaining one validated policy and contract assertion.
--
-- In particular, this value exposes neither the executable path nor digest
-- material and cannot retain a live session or process owner.  The contract
-- field is deliberately lazy so productive candidate admission can reject a
-- maximum-plus-one batch before inspecting request-owned behavioral syntax,
-- matching the separate policy/request-contract entry point.
data LengthRankingConfiguration = LengthRankingConfiguration
  !LengthRankingPolicy
  LeanLengthContract

-- | Pure validation failure in fixed execution-before-evaluation order.
data LengthRankingConfigurationError
  = LengthRankingExecutionConfigurationRejected
      !LengthSMTLibExecutionConfigError
  | LengthRankingEvaluationLimitsRejected
      !LengthEvaluationLimitError
  deriving (Eq, Ord, Show)

-- | Validate execution before replay limits without performing IO.
mkLengthRankingPolicy
  :: LengthRankingPolicySource
  -> Either LengthRankingConfigurationError LengthRankingPolicy
mkLengthRankingPolicy source = do
  execution <- case mkLengthSMTLibExecutionConfig
      (lengthRankingPolicyExecutionLimits source)
      (lengthRankingPolicyExecutionSource source) of
    Left failure -> Left $ LengthRankingExecutionConfigurationRejected failure
    Right validated -> Right validated
  evaluation <- case mkLengthEvaluationLimits
      (lengthRankingPolicyEvaluationSource source) of
    Left failure -> Left $ LengthRankingEvaluationLimitsRejected failure
    Right validated -> Right validated
  pure $ LengthRankingPolicy execution evaluation

-- | Validate a reusable policy, then retain the explicit compatibility-file
-- contract assertion without forcing it or performing IO.
mkLengthRankingConfiguration
  :: LengthRankingConfigurationSource
  -> Either LengthRankingConfigurationError LengthRankingConfiguration
mkLengthRankingConfiguration source = do
  policy <- mkLengthRankingPolicy LengthRankingPolicySource
    { lengthRankingPolicyExecutionLimits =
        lengthRankingConfigurationExecutionLimits source
    , lengthRankingPolicyExecutionSource =
        lengthRankingConfigurationExecutionSource source
    , lengthRankingPolicyEvaluationSource =
        lengthRankingConfigurationEvaluationSource source
    }
  pure $ LengthRankingConfiguration policy
    $ lengthRankingConfigurationContract source

-- | Run a verified batch under one reusable policy and one explicitly supplied
-- request contract.  Every eligible call still owns a fresh lexical worker.
rankVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithPolicy
    (LengthRankingPolicy execution evaluation) =
  rankVerifiedLengthCandidates execution evaluation

-- | Associated variant used by a batch-scoped post-verification adapter.
-- Caller-owned occurrence handles remain attached until that adapter validates
-- the final permutation and deliberately erases them.
rankPostVerificationLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesWithPolicy
    (LengthRankingPolicy execution evaluation) =
  rankPostVerificationLengthCandidates execution evaluation

-- | Preserve batch-scoped occurrence handles while running the compatible
-- policy-plus-contract bundle.  This is the configured counterpart of
-- 'rankPostVerificationLengthCandidatesWithPolicy'; a post-verification
-- adapter must still validate the returned handle permutation before erasing
-- those associations.
rankPostVerificationLengthCandidatesConfigured
  :: LengthRankingConfiguration
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthCandidatesConfigured
    (LengthRankingConfiguration policy contract) =
  rankPostVerificationLengthCandidatesWithPolicy policy contract

-- | Run one complete candidate batch under the retained policy.
--
-- Eligible queries use one fresh lexical live session and execute serially;
-- the configuration retains no worker between calls.  Input-limit results and
-- the ranking layer's atomic operational fallback are preserved unchanged,
-- while synchronous and asynchronous exceptions continue to propagate.
rankVerifiedLengthCandidatesConfigured
  :: LengthRankingConfiguration
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesConfigured
    (LengthRankingConfiguration policy contract) =
  rankVerifiedLengthCandidatesWithPolicy policy contract
