-- | Solver-neutral source vocabulary for finite-spine Length contracts.
--
-- These values are passive assertions supplied by an integration layer.  They
-- do not retain an engine session, a verified candidate, a solver policy, or
-- any authority to run Z3.  'Leant.Synth.Engine' checks the exact names against
-- retained translation provenance when it prepares a candidate-specific
-- handoff.  Modules which need only the source vocabulary can therefore avoid
-- depending on the complete synthesis engine implementation; current ranking
-- code still imports that engine separately for candidate-specific handoffs.
module Leant.Synth.Length.Contract
  ( LeanLengthSpineIdentity (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthContract (..)
  ) where

import Language.Haskell.Djex
  ( LengthContractSource
  , LengthExpression
  , LengthProviderArgumentRole
  , LengthProviderVariable
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

-- | Explicit finite-spine contract to bind to one accepted typed candidate.
--
-- The contract remains an assertion supplied by the integration layer.  A
-- successful handoff proves that its exact identities, target, renderer
-- correspondence, session, and candidate were checked together; it does not
-- infer a behavioral specification from Lean declarations.
data LeanLengthContract = LeanLengthContract
  { leanLengthContractSpine :: LeanLengthSpineIdentity
  , leanLengthContractSource :: LengthContractSource
  , leanLengthContractProviderLaws :: [LeanLengthProviderLaw]
  }
  deriving (Eq, Show)
