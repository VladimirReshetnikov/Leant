-- | Solver-neutral source vocabulary for finite-spine Length contracts.
--
-- These values are passive assertions supplied by an integration layer.  They
-- do not retain an engine session, a verified candidate, a solver policy, or
-- any authority to run Z3. "Leant.Synth.Length.Handoff" checks the exact names
-- against retained translation provenance when it prepares a
-- candidate-specific problem. Modules which need only the source vocabulary
-- can therefore avoid depending on the complete synthesis engine
-- implementation.
module Leant.Synth.Length.Contract
  ( LeanLengthSpineIdentity (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthCandidateCasePolicy (..)
  , LeanLengthContract (..)
  ) where

import Language.Haskell.Djex
  ( LengthContractSource
  , LengthExpression
  , LengthProviderArgumentRole
  , LengthProviderVariable
  , LengthTargetArgumentRole
  )

-- | Exact Lean names supplied by an external Length contract for the unary
-- finite spine it describes.  These names are matched only against provenance
-- retained from structural declarations; their spelling is never translated
-- into a private Djex identity by convention.
data LeanLengthSpineIdentity = LeanLengthSpineIdentity
  { leanLengthSpineFamilyName :: String
  , leanLengthSpineZeroConstructorName :: String
  , leanLengthSpineStepConstructorName :: String
  }
  deriving (Eq, Show)

-- | One explicitly assumed behavioral law for an exact Lean provider.
--
-- The provider's closed scheme and private Djex name come from its retained
-- translation binding.  Callers supply only the semantic roles and transfer
-- they intend to assume; Leant does not derive either from a provider name or
-- implementation.
data LeanLengthProviderLaw = LeanLengthProviderLaw
  { leanLengthProviderLawName :: String
  , leanLengthProviderLawArgumentRoles :: [LengthProviderArgumentRole]
  , leanLengthProviderLawTransfer ::
      LengthExpression LengthProviderVariable
  }
  deriving (Eq, Show)

-- | Closed candidate-case authority carried by one passive contract.
--
-- Ordinary startup and contract-only versions 1--3 retain the rejecting
-- policy. Contract-only version 4 must spell the exact zero/step policy
-- explicitly; Handoff never infers it from a graph or a failed sealer.
data LeanLengthCandidateCasePolicy
  = LeanLengthCasesRejected
  | LeanLengthExactSpineZeroStepV1
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Explicit finite-spine contract to bind to one accepted typed candidate.
--
-- The contract remains an assertion supplied by the integration layer.  A
-- successful handoff proves that its exact identities, target, renderer
-- correspondence, session, and candidate were checked together; it does not
-- infer a behavioral specification from Lean declarations.
data LeanLengthContract = LeanLengthContract
  { leanLengthContractSpine :: LeanLengthSpineIdentity
  -- | 'Nothing' is the exact legacy all-observed compatibility policy used
  -- by the startup v1 file and contract-only v1/v2.  'Just' retains the exact
  -- source-ordered role vector required by contract-only v3/v4; no roles are
  -- inferred from the target type or provider declarations.
  , leanLengthContractTargetArgumentRoles ::
      Maybe [LengthTargetArgumentRole]
  -- | Explicit candidate-case authority. Versions 1--3 and startup v1 use
  -- 'LeanLengthCasesRejected'; contract-only v4 alone can retain the exact
  -- zero/step policy beside its required role vector.
  , leanLengthContractCandidateCasePolicy :: LeanLengthCandidateCasePolicy
  , leanLengthContractSource :: LengthContractSource
  , leanLengthContractProviderLaws :: [LeanLengthProviderLaw]
  }
  deriving (Eq, Show)
