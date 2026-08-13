-- | Explicit ownership of live Length ranking policy.
--
-- Construction is pure and performs only Djex's bounded policy validation.
-- 'LengthRankingPolicy' owns reusable execution and replay policy, while a
-- 'LeanLengthContract' is supplied separately for each ranking request.  The
-- versioned compatibility-file grammar retains its fixed startup contract
-- beside this policy without introducing a second generic aggregate.
--
-- A successful value does not establish that the configured path resolves to
-- a usable executable, that a later pre-spawn executable-file snapshot matches
-- an optional SHA-256 expectation, or that the child has the required Z3
-- capability; those observations belong to the lexical live session opened by
-- each ranking run.  A caller-supplied contract likewise remains an assertion
-- until checked with each exact callback-verified candidate.
--
-- There is deliberately no default source, executable discovery, path
-- normalization, environment lookup, or projection of executable paths or
-- digest bytes from the opaque sealed value.  A closed classifier reports
-- only whether the retained execution policy contains a digest expectation.
-- Callers must provide the complete execution and replay policy plus each
-- contract explicitly.  No runner retains a worker: every eligible batch
-- delegates to the rank-N live scope owned by
-- 'rankVerifiedLengthCandidates'.
module Leant.Synth.Length.Configuration
  ( LengthRankingPolicySource (..)
  , LengthRankingPolicy
  , mkLengthRankingPolicy
  , lengthRankingPolicyFromValidatedComponents
  , lengthRankingPolicyExecutableDigestExpectation
  , LengthRankingConfigurationError (..)
  , assessVerifiedLengthCandidatesWithPolicy
  , rankVerifiedLengthCandidatesWithPolicy
  ) where

import Language.Haskell.Djex
  ( LengthEvaluationLimitError
  , LengthEvaluationLimitSource
  , LengthEvaluationLimits
  , LengthSMTLibExecutionConfig
  , LengthSMTLibExecutionConfigError
  , LengthSMTLibExecutionConfigSource
  , LengthSMTLibExecutionLimits
  , LengthSMTLibExecutableDigestExpectation
  , lengthSMTLibExecutionExecutableDigestExpectation
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
import Leant.Synth.Length.Ranking.Internal
  ( AssociatedLengthRanking
  , rankPostVerificationLengthCandidates
  )
import Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationResult
  , assessVerifiedLengthCandidatesWith
  )
import Leant.Synth.PostVerification (PostVerificationCandidate)
import Leant.Synth.Verification
  ( VerificationBatch
  , Verified
  )

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

-- | Assemble one reusable policy from already validated Djex execution and
-- replay authorities.  No validation is repeated and no IO is performed.
-- This bridge is used by the closed compatibility-file decoder after it has
-- preserved the same execution-before-evaluation validation precedence.
lengthRankingPolicyFromValidatedComponents
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicy
lengthRankingPolicyFromValidatedComponents = LengthRankingPolicy

-- | Classify only whether the sealed execution policy contains an executable
-- digest expectation.  This reveals neither the digest bytes nor the path and
-- does not claim that a later live executable matches the expectation.  The
-- separately retained request-owned contract is not inspected.
lengthRankingPolicyExecutableDigestExpectation
  :: LengthRankingPolicy
  -> LengthSMTLibExecutableDigestExpectation
lengthRankingPolicyExecutableDigestExpectation
    (LengthRankingPolicy execution _) =
  lengthSMTLibExecutionExecutableDigestExpectation execution

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

-- | Assess one exact callback batch with an explicit reusable policy and
-- request-owned contract, then expose a report only through the generative
-- occurrence-permutation seal.
assessVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthPostVerificationResult
assessVerifiedLengthCandidatesWithPolicy policy contract =
  assessVerifiedLengthCandidatesWith
    $ rankPostVerificationLengthCandidatesWithPolicy policy contract
