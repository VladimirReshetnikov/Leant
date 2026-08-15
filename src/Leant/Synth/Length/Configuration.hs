-- | Explicit ownership of live Length ranking policy.
--
-- Construction is pure and performs only Djex's bounded policy validation.
-- 'LengthRankingPolicy' owns reusable execution and replay policy plus
-- independent optional origin-probe, finite input-box, and non-vacuous
-- positive-ordering policies, while a 'LeanLengthContract' is supplied
-- separately for each ranking request.  The
-- versioned configuration-file grammar retains its fixed startup contract
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
  , enableLengthRankingOriginProbe
  , enableLengthRankingInputBoxValidation
  , enableLengthRankingNonVacuousInputBoxPreference
  , lengthRankingPolicyExecutableDigestExpectation
  , LengthRankingConfigurationError (..)
  , assessVerifiedLengthCandidatesWithPolicy
  , rankVerifiedLengthCandidatesWithPolicy
  , assessVerifiedLengthSpinePairCandidatesWithPolicy
  , rankVerifiedLengthSpinePairCandidatesWithPolicy
  ) where

import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthEvaluationLimitError
  , LengthEvaluationLimitSource
  , LengthEvaluationLimits
  , LengthInputBoxLimits
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
import Leant.Synth.Length.Contract
  ( LeanLengthContract
  , LeanLengthSpinePairContract
  )
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingInputError
  , rankVerifiedLengthCandidates
  , rankVerifiedLengthCandidatesWithInputBoxValidation
  )
import Leant.Synth.Length.Ranking.Internal
  ( AssociatedLengthRanking
  , preferNonVacuousBoundedPositiveAssociatedLengthRanking
  , preferNonVacuousBoundedPositiveLengthRanking
  , rankPostVerificationLengthCandidates
  , rankPostVerificationLengthCandidatesWithOriginProbe
  , rankPostVerificationLengthCandidatesWithInputBoxValidation
  , rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
  , rankVerifiedLengthCandidatesWithOriginProbe
  , rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
  )
import Leant.Synth.Length.PostVerification.Internal
  ( LengthPostVerificationResult
  , assessVerifiedLengthCandidatesWith
  )
import Leant.Synth.Length.SpinePair.PostVerification.Internal
  ( LengthSpinePairPostVerificationResult
  , assessVerifiedLengthSpinePairCandidatesWith
  )
import Leant.Synth.Length.SpinePair.Ranking
  ( LengthSpinePairRanking
  , rankVerifiedLengthSpinePairCandidates
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
  )
import Leant.Synth.Length.SpinePair.Ranking.Internal
  ( AssociatedLengthSpinePairRanking
  , preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
  , preferNonVacuousBoundedPositiveLengthSpinePairRanking
  , rankPostVerificationLengthSpinePairCandidates
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
  , rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
  , rankVerifiedLengthSpinePairCandidatesWithOriginProbe
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

-- | Validated reusable policy with no process, worker, contract, or behavioral
-- verdict authority.  The constructor and all execution/validation material
-- remain private.
data LengthRankingPolicy = LengthRankingPolicy
  !LengthSMTLibExecutionConfig
  !LengthEvaluationLimits
  !LengthRankingInputBoxValidation
  !LengthRankingOriginProbe
  !LengthRankingNonVacuousInputBoxPreference

-- | Private optional orchestration policy.  It contains no solver status,
-- query, receipt, or verdict; each enabled use must still pass Djex's exact
-- query-owned finite-box validation after a live @unsat@ trigger.
data LengthRankingInputBoxValidation
  = LengthRankingInputBoxValidationDisabled
  | LengthRankingInputBoxValidationEnabled !LengthInputBoxLimits [Natural]

-- | Private permission to run Djex's query-owned canonical origin replay
-- after the MRU bank misses and before a live query.  This retains no input
-- vector, arity, query, receipt, status, or behavioral verdict.
data LengthRankingOriginProbe
  = LengthRankingOriginProbeDisabled
  | LengthRankingOriginProbeEnabled

-- | Private ranking-only authority.  It neither enables finite-box
-- validation nor changes which evidence is acquired.  The enabled branch may
-- only prefer a completed bounded-positive receipt whose applicable-assignment
-- count is nonzero; vacuous receipts remain neutral and counterexamples remain
-- last.
data LengthRankingNonVacuousInputBoxPreference
  = LengthRankingNonVacuousInputBoxPreferenceDisabled
  | LengthRankingNonVacuousInputBoxPreferenceEnabled

-- | Pure validation failure in fixed execution-before-evaluation order.
data LengthRankingConfigurationError
  = LengthRankingExecutionConfigurationRejected
      !LengthSMTLibExecutionConfigError
  | LengthRankingEvaluationLimitsRejected
      !LengthEvaluationLimitError
  deriving (Eq, Ord, Show)

-- | Validate execution before replay limits without performing IO.  This
-- established constructor leaves the origin probe and finite-box validation
-- disabled; callers must derive either opt-in value explicitly.
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
    LengthRankingInputBoxValidationDisabled LengthRankingOriginProbeDisabled
    LengthRankingNonVacuousInputBoxPreferenceDisabled

-- | Assemble one reusable policy from already validated Djex execution and
-- replay authorities with the origin probe and finite-box validation disabled.
-- No validation is repeated and no IO is performed.
-- This bridge is used by the closed compatibility-file decoder after it has
-- preserved the same execution-before-evaluation validation precedence.
lengthRankingPolicyFromValidatedComponents
  :: LengthSMTLibExecutionConfig
  -> LengthEvaluationLimits
  -> LengthRankingPolicy
lengthRankingPolicyFromValidatedComponents execution evaluation =
  LengthRankingPolicy execution evaluation
    LengthRankingInputBoxValidationDisabled LengthRankingOriginProbeDisabled
    LengthRankingNonVacuousInputBoxPreferenceDisabled

-- | Derive an origin-probing sibling without changing the validated
-- execution/evaluation authorities or any independently selected finite box.
-- The probe itself remains query-owned and is attempted only after all four
-- batch-local MRU vectors miss.  Its ordinary non-counterexample result is not
-- positive evidence and cannot suppress the subsequent live query.
enableLengthRankingOriginProbe
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingOriginProbe
    (LengthRankingPolicy execution evaluation inputBoxValidation _ preference) =
  LengthRankingPolicy execution evaluation inputBoxValidation
    LengthRankingOriginProbeEnabled preference

-- | Derive an explicitly enabled finite-box policy without changing the
-- already validated execution/evaluation authorities or the reusable base
-- value.  The inclusive maxima remain caller-owned data until the exact query
-- independently validates width, values, Cartesian size, and every assignment.
-- A cyclic or mismatched vector therefore fails productively only if an
-- @unsat@ observation reaches that exact candidate; it is never treated as a
-- solver verdict or cached evidence.
enableLengthRankingInputBoxValidation
  :: LengthInputBoxLimits
  -> [Natural]
  -> LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingInputBoxValidation limits maximums
    (LengthRankingPolicy execution evaluation _ originProbe preference) =
  LengthRankingPolicy execution evaluation
    (LengthRankingInputBoxValidationEnabled limits maximums) originProbe
    preference

-- | Derive an explicit evidence-ordering sibling without enabling or changing
-- finite-box validation, origin probing, execution, evaluation, or contract
-- authority.  The derivation is compositional with the other two policy
-- builders.  If no non-vacuous bounded-positive receipt is acquired, it is an
-- ordering identity.
enableLengthRankingNonVacuousInputBoxPreference
  :: LengthRankingPolicy
  -> LengthRankingPolicy
enableLengthRankingNonVacuousInputBoxPreference
    (LengthRankingPolicy execution evaluation inputBoxValidation originProbe
      _) =
  LengthRankingPolicy execution evaluation inputBoxValidation originProbe
    LengthRankingNonVacuousInputBoxPreferenceEnabled

-- | Classify only whether the sealed execution policy contains an executable
-- digest expectation.  This reveals neither the digest bytes nor the path and
-- does not claim that a later live executable matches the expectation.  The
-- separately retained request-owned contract is not inspected.
lengthRankingPolicyExecutableDigestExpectation
  :: LengthRankingPolicy
  -> LengthSMTLibExecutableDigestExpectation
lengthRankingPolicyExecutableDigestExpectation
    (LengthRankingPolicy execution _ _ _ _) =
  lengthSMTLibExecutionExecutableDigestExpectation execution

-- Apply the ranking-only preference after all behavioral acquisition has
-- completed.  The disabled branch returns the original action literally;
-- existing policies therefore retain their exact runner and demand behavior.
applyLengthRankingNonVacuousInputBoxPreference
  :: LengthRankingNonVacuousInputBoxPreference
  -> (ranking -> ranking)
  -> IO (Either failure ranking)
  -> IO (Either failure ranking)
applyLengthRankingNonVacuousInputBoxPreference preference prefer action =
  case preference of
    LengthRankingNonVacuousInputBoxPreferenceDisabled -> action
    LengthRankingNonVacuousInputBoxPreferenceEnabled ->
      fmap (fmap prefer) action

-- | Run a verified batch under one reusable policy and one explicitly supplied
-- request contract.  Every eligible call still owns a fresh lexical worker.
rankVerifiedLengthCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthRanking)
rankVerifiedLengthCandidatesWithPolicy
    (LengthRankingPolicy execution evaluation inputBoxValidation
      originProbe preference) contract candidates =
  applyLengthRankingNonVacuousInputBoxPreference preference
    preferNonVacuousBoundedPositiveLengthRanking
    $ case (inputBoxValidation, originProbe) of
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeDisabled) ->
          rankVerifiedLengthCandidates execution evaluation contract candidates
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeEnabled) ->
          rankVerifiedLengthCandidatesWithOriginProbe
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeDisabled) ->
          rankVerifiedLengthCandidatesWithInputBoxValidation
            execution evaluation limits maximums contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeEnabled) ->
          rankVerifiedLengthCandidatesWithInputBoxValidationAndOriginProbe
            execution evaluation limits maximums contract candidates

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
    (LengthRankingPolicy execution evaluation inputBoxValidation
      originProbe preference) contract candidates =
  applyLengthRankingNonVacuousInputBoxPreference preference
    preferNonVacuousBoundedPositiveAssociatedLengthRanking
    $ case (inputBoxValidation, originProbe) of
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeDisabled) ->
          rankPostVerificationLengthCandidates
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeEnabled) ->
          rankPostVerificationLengthCandidatesWithOriginProbe
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeDisabled) ->
          rankPostVerificationLengthCandidatesWithInputBoxValidation
            execution evaluation limits maximums contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeEnabled) ->
          rankPostVerificationLengthCandidatesWithInputBoxValidationAndOriginProbe
            execution evaluation limits maximums contract candidates

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

-- | Run the nominal binary-product sibling under the same process/evaluation
-- policy.  The policy contains no scalar contract, query, or evidence
-- authority; all four branches enter pair-specific runners and receipts.
rankVerifiedLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> [Verified DetailedVerificationVariant]
  -> IO (Either LengthRankingInputError LengthSpinePairRanking)
rankVerifiedLengthSpinePairCandidatesWithPolicy
    (LengthRankingPolicy execution evaluation inputBoxValidation
      originProbe preference) contract candidates =
  applyLengthRankingNonVacuousInputBoxPreference preference
    preferNonVacuousBoundedPositiveLengthSpinePairRanking
    $ case (inputBoxValidation, originProbe) of
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeDisabled) ->
          rankVerifiedLengthSpinePairCandidates
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeEnabled) ->
          rankVerifiedLengthSpinePairCandidatesWithOriginProbe
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeDisabled) ->
          rankVerifiedLengthSpinePairCandidatesWithInputBoxValidation
            execution evaluation limits maximums contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeEnabled) ->
          rankVerifiedLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
            execution evaluation limits maximums contract candidates

rankPostVerificationLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> [PostVerificationCandidate epoch DetailedVerificationVariant]
  -> IO
      (Either LengthRankingInputError
        (AssociatedLengthSpinePairRanking
          (PostVerificationCandidate epoch DetailedVerificationVariant)))
rankPostVerificationLengthSpinePairCandidatesWithPolicy
    (LengthRankingPolicy execution evaluation inputBoxValidation
      originProbe preference) contract candidates =
  applyLengthRankingNonVacuousInputBoxPreference preference
    preferNonVacuousBoundedPositiveAssociatedLengthSpinePairRanking
    $ case (inputBoxValidation, originProbe) of
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeDisabled) ->
          rankPostVerificationLengthSpinePairCandidates
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationDisabled,
            LengthRankingOriginProbeEnabled) ->
          rankPostVerificationLengthSpinePairCandidatesWithOriginProbe
            execution evaluation contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeDisabled) ->
          rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidation
            execution evaluation limits maximums contract candidates
        (LengthRankingInputBoxValidationEnabled limits maximums,
            LengthRankingOriginProbeEnabled) ->
          rankPostVerificationLengthSpinePairCandidatesWithInputBoxValidationAndOriginProbe
            execution evaluation limits maximums contract candidates

-- | Assess one callback batch through the pair-specific occurrence seal.
assessVerifiedLengthSpinePairCandidatesWithPolicy
  :: LengthRankingPolicy
  -> LeanLengthSpinePairContract
  -> VerificationBatch DetailedVerificationVariant
  -> IO LengthSpinePairPostVerificationResult
assessVerifiedLengthSpinePairCandidatesWithPolicy policy contract =
  assessVerifiedLengthSpinePairCandidatesWith
    $ rankPostVerificationLengthSpinePairCandidatesWithPolicy policy contract
