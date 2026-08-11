-- | Explicit ownership of live Length ranking policy.
--
-- Construction is pure and performs only Djex's bounded policy validation.  A
-- successful value does not establish that the configured path resolves to a
-- usable executable, that a later pre-spawn executable-file snapshot matches
-- an optional SHA-256 expectation, or that the child has the required Z3
-- capability; those observations belong to the lexical live session opened by
-- the ranking run.
-- Likewise, the caller-supplied 'LeanLengthContract' remains an assertion until
-- it is checked together with each exact callback-verified candidate.
--
-- There is deliberately no default source, executable discovery, path
-- normalization, environment lookup, or projection from the opaque sealed
-- value.  Callers must provide the complete execution, replay, and contract
-- policy explicitly.  The configured runner retains no worker: every eligible
-- batch delegates to the rank-N live scope owned by
-- 'rankVerifiedLengthCandidates'.
module Leant.Synth.Length.Configuration
  ( LengthRankingConfigurationSource (..)
  , LengthRankingConfiguration
  , LengthRankingConfigurationError (..)
  , mkLengthRankingConfiguration
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
  ( LengthRanking
  , LengthRankingInputError
  , rankVerifiedLengthCandidates
  )
import Leant.Synth.Verification (Verified)

-- | Complete caller-owned source for one live Length ranking policy.
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

-- | Execution- and replay-validated policy retaining a contract assertion.
--
-- In particular, this value exposes neither the executable path nor digest
-- material and cannot retain a live session or process owner.
data LengthRankingConfiguration = LengthRankingConfiguration
  !LengthSMTLibExecutionConfig
  !LengthEvaluationLimits
  !LeanLengthContract

-- | Pure validation failure in fixed execution-before-evaluation order.
data LengthRankingConfigurationError
  = LengthRankingExecutionConfigurationRejected
      !LengthSMTLibExecutionConfigError
  | LengthRankingEvaluationLimitsRejected
      !LengthEvaluationLimitError
  deriving (Eq, Ord, Show)

-- | Validate execution and replay inputs, then retain the explicit contract
-- assertion without performing IO.
mkLengthRankingConfiguration
  :: LengthRankingConfigurationSource
  -> Either LengthRankingConfigurationError LengthRankingConfiguration
mkLengthRankingConfiguration source = do
  execution <- case mkLengthSMTLibExecutionConfig
      (lengthRankingConfigurationExecutionLimits source)
      (lengthRankingConfigurationExecutionSource source) of
    Left failure -> Left $ LengthRankingExecutionConfigurationRejected failure
    Right validated -> Right validated
  evaluation <- case mkLengthEvaluationLimits
      (lengthRankingConfigurationEvaluationSource source) of
    Left failure -> Left $ LengthRankingEvaluationLimitsRejected failure
    Right validated -> Right validated
  pure $ LengthRankingConfiguration execution evaluation
    $ lengthRankingConfigurationContract source

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
    (LengthRankingConfiguration execution evaluation contract) =
  rankVerifiedLengthCandidates execution evaluation contract
