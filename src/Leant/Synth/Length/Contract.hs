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
  , LeanLengthSpinePairContract (..)
  , LeanLengthContractSelection (..)
  ) where

import Language.Haskell.Djex
  ( LengthContractSource
  , LengthExpression
  , LengthProviderArgumentRole
  , LengthProviderVariable
  , LengthSpinePairContractSource
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
-- Both current file entrances spell this choice explicitly. Handoff never
-- infers it from a graph or a failed sealer.
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
  -- | Exact source-ordered role vector. No roles are inferred from the target
  -- type or provider declarations.
  , leanLengthContractTargetArgumentRoles :: ![LengthTargetArgumentRole]
  -- | Explicit candidate-case authority selected by either current file
  -- entrance.
  , leanLengthContractCandidateCasePolicy :: LeanLengthCandidateCasePolicy
  , leanLengthContractSource :: LengthContractSource
  , leanLengthContractProviderLaws :: [LeanLengthProviderLaw]
  }
  deriving (Eq, Show)

-- | Explicit finite-spine contract for a result whose normalized root is
-- canonical Lean @Prod@ and whose two source-ordered fields are applications
-- of the same configured spine.
--
-- The current @rankingDomain = binary-product@ startup and contract-only
-- entrances decode this additive source value.
-- Like 'LeanLengthContract', it remains a passive assertion until the exact
-- accepted typed origin, family/provider provenance, contract, and candidate
-- are sealed together by the product handoff.
data LeanLengthSpinePairContract = LeanLengthSpinePairContract
  { leanLengthSpinePairContractSpine :: LeanLengthSpineIdentity
  , leanLengthSpinePairContractTargetArgumentRoles ::
      ![LengthTargetArgumentRole]
  , leanLengthSpinePairContractCandidateCasePolicy ::
      LeanLengthCandidateCasePolicy
  , leanLengthSpinePairContractSource :: LengthSpinePairContractSource
  , leanLengthSpinePairContractProviderLaws :: [LeanLengthProviderLaw]
  }
  deriving (Eq, Show)

-- | Passive domain selection decoded by the additive configuration and
-- contract-file entrances.  Neither branch carries execution authority, and
-- both payloads remain lazy so domain dispatch does not inspect a contract
-- before the established activation and request-admission boundaries.
data LeanLengthContractSelection
  = LeanLengthScalarContractSelection LeanLengthContract
  | LeanLengthSpinePairContractSelection LeanLengthSpinePairContract
  deriving (Eq, Show)
