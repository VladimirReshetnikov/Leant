-- | Checked correspondence from one callback-accepted Leant occurrence to a
-- candidate-specific Djex Length problem.
--
-- This is the sole Length-specific consumer of synthesis provenance.  Its
-- public entrance accepts the opaque verification receipt, not a detached
-- candidate, origin, inspection record, or rendered spelling.  The exact
-- typed origin is recovered through "Leant.Synth.Engine" first. Candidate,
-- inventory, and source identities are projected from its one retained
-- sidecar, while Engine rerenders that opaque origin without exposing its
-- private map or premise-layout inputs, before Djex seals the problem.
--
-- Callback acceptance is not a kernel proof, behavioral observation, or
-- solver certificate.  This module establishes only the narrow structural
-- correspondence required by the versioned finite-spine Length adapter.
module Leant.Synth.Length.Handoff
  ( LengthHandoffRefusal (..)
  , prepareCheckedLengthProblem
  ) where

import qualified Data.Map.Strict as Map
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( CheckedLengthProblem
  , ExferenceLocal
  , ExferenceTermGraphAbsence
  , ExferenceTypeVariable
  , LengthContractError
  , LengthProblemError
  , LengthProviderInventoryError (..)
  , LengthProviderSummarySource (..)
  , LengthInterpretationPolicySource (..)
  , LengthSessionError (..)
  , LengthSpineModelSource (DeclaredListSpine)
  , LengthTargetArgumentRole
  , Name
  , QueryRequest (..)
  , Variable (FlexibleVariable)
  , defaultLengthLimits
  , defaultLengthProblemLimits
  , lengthProviderSummaryLimit
  , sealLengthContractInSession
  , sealLengthSessionWithInterpretationPolicy
  , sealLengthTypedCandidateProblemInSession
  )

import Leant.Synth.Engine
  ( DetailedVerificationVariant
  , ExactTypedVariantOrigin
  , ExactTypedVariantRenderingFailure (..)
  , ExferenceRunAuthorityInspection
  , PreparedSynthesisInspection
  , SemanticFamilyBindingInspection
  , detailedVerificationVariantExactTypedOrigin
  , detailedVerificationVariantRoute
  , detailedVerificationVariantText
  , exactTypedVariantOriginOrdinal
  , exactTypedVariantOriginSidecar
  , inspectedAuthorityNameTable
  , inspectedAuthorityPreparation
  , inspectedAuthorityRequest
  , inspectedCallerPremises
  , inspectedConstructorPremises
  , inspectedEngineFragment
  , inspectedFitFragment
  , inspectedProviderBindings
  , inspectedProviderPrivateName
  , inspectedProviderScheme
  , inspectedProviderSourceName
  , inspectedSearchGoal
  , inspectedSemanticFamilyBindings
  , inspectedSemanticFamilyConstructors
  , inspectedSemanticFamilyLeanName
  , inspectedSemanticFamilyPrivateTypeName
  , inspectedSourceGoal
  , renderExactTypedVariantOrigin
  , typedCandidateSemanticAuthorityInspection
  , typedCandidateSemanticCandidate
  , typedCandidateSemanticInventory
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContract (..)
  , LeanLengthCandidateCasePolicy (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthSpineIdentity (..)
  )
import Leant.Synth.Observability
  ( CandidateRenderingRoute (RouteTypedCandidate) )
import Leant.Synth.Verification (Verified, verifiedCandidate)

-- | Stable fail-closed phases of preparing one Length behavioral problem.
-- Djex's structured sealing errors remain nested instead of being flattened
-- into renderer diagnostics or treated as an ordinary absence of evidence.
data LengthHandoffRefusal
  = LengthHandoffNotTypedRoute CandidateRenderingRoute
  | LengthHandoffMissingSemanticSidecar
  | LengthHandoffRetargetedFragments
  | LengthHandoffPremisesPresent
  | LengthHandoffSearchGoalChanged
  | LengthHandoffSourceGoalVariableMissing String
  | LengthHandoffRequestContextsPresent Int
  | LengthHandoffRequestGoalChanged
  | LengthHandoffTypedGraphLost ExferenceTermGraphAbsence
  | LengthHandoffRendererRejected String
  | LengthHandoffRendererNotUnique Int
  | LengthHandoffRendererOrdinalChanged Natural
  | LengthHandoffRendererTextChanged String String
  | LengthHandoffFamilyUnavailable String
  | LengthHandoffConstructorUnavailable String String
  | LengthHandoffProviderUnavailable String
  | LengthHandoffProviderAmbiguous String Int
  | LengthHandoffProviderVariableMissing String String
  | LengthHandoffExactCasePolicyRequiresTargetRoles
  | LengthHandoffSessionRejected (LengthSessionError ExferenceLocal)
  | LengthHandoffContractRejected (LengthContractError ExferenceTypeVariable)
  | LengthHandoffProblemRejected
      (LengthProblemError
        ExferenceTermGraphAbsence ExferenceLocal ExferenceLocal)
  deriving (Eq, Show)

-- | Prepare the only currently supported Leant-to-Djex behavioral problem.
--
-- The exact-origin projection validates that any recovered origin belongs to
-- this accepted spelling before the handoff observes its sidecar.  All later
-- inspection records are derived internally from that opaque sidecar; they
-- are descriptive views, never caller-supplied authority.
--
-- Once correspondence succeeds, exact family/provider bindings are resolved
-- from retained translation provenance. Djex seals the inventory, spine, and
-- provider laws once into an opaque session, revalidates the separately
-- supplied contract through that session, and then seals the whole typed
-- candidate, semantic encoding, and problem identity. The returned problem is
-- the direct Djex authority; no additional Leant handoff wrapper is retained.
prepareCheckedLengthProblem
  :: LeanLengthContract
  -> Verified DetailedVerificationVariant
  -> Either LengthHandoffRefusal
      (CheckedLengthProblem ExferenceLocal ExferenceLocal)
prepareCheckedLengthProblem source verified = do
  let variant = verifiedCandidate verified
      route = detailedVerificationVariantRoute variant
  exactOrigin <- case detailedVerificationVariantExactTypedOrigin variant of
    Just retained -> Right retained
    Nothing
      | route == RouteTypedCandidate ->
          Left LengthHandoffMissingSemanticSidecar
      | otherwise -> Left $ LengthHandoffNotTypedRoute route
  let semantic = exactTypedVariantOriginSidecar exactOrigin
      candidate = typedCandidateSemanticCandidate semantic
      authority = typedCandidateSemanticAuthorityInspection semantic
      origin = inspectedAuthorityPreparation authority
  if inspectedEngineFragment origin == inspectedFitFragment origin
    then pure ()
    else Left LengthHandoffRetargetedFragments
  if null (inspectedConstructorPremises origin)
      && null (inspectedCallerPremises origin)
    then pure ()
    else Left LengthHandoffPremisesPresent
  if inspectedSourceGoal origin == inspectedSearchGoal origin
    then pure ()
    else Left LengthHandoffSearchGoalChanged
  convertedSource <- traverse (convertSourceVariable authority)
    $ inspectedSourceGoal origin
  let request = inspectedAuthorityRequest authority
  if null $ requestContexts request
    then pure ()
    else Left $ LengthHandoffRequestContextsPresent
      $ length $ requestContexts request
  if requestGoal request == convertedSource
    then pure ()
    else Left LengthHandoffRequestGoalChanged
  checkDirectRendering
    (leanLengthContractCandidateCasePolicy source) exactOrigin variant
  (family, zeroConstructor, stepConstructor) <- resolveSemanticFamily origin
    $ leanLengthContractSpine source
  providerLaws <- boundedProviderLawPrefix
    $ leanLengthContractProviderLaws source
  providerSources <- mapM (resolveProviderLaw authority origin) providerLaws
  let inventory = typedCandidateSemanticInventory semantic
      spineModel = DeclaredListSpine
        (inspectedSemanticFamilyPrivateTypeName family)
        zeroConstructor
        stepConstructor
      targetRoles = leanLengthContractTargetArgumentRoles source
      casePolicy = leanLengthContractCandidateCasePolicy source
  interpretationPolicy <- lengthInterpretationPolicySource
    casePolicy targetRoles
  session <- either (Left . LengthHandoffSessionRejected) Right
    $ sealLengthSessionWithInterpretationPolicy defaultLengthLimits
        interpretationPolicy inventory spineModel providerSources
  contract <- either (Left . LengthHandoffContractRejected) Right
    $ sealLengthContractInSession session convertedSource
        (leanLengthContractSource source)
  problem <- either (Left . LengthHandoffProblemRejected) Right
    $ sealLengthTypedCandidateProblemInSession
        defaultLengthProblemLimits session contract candidate
  pure problem

-- | Convert Leant's two decoded policy axes once, after every exact family and
-- provider identity has been resolved.  The closed Djex source makes invalid
-- combinations unrepresentable past this point while retaining the startup
-- and contract-only legacy entrance exactly.
lengthInterpretationPolicySource
  :: LeanLengthCandidateCasePolicy
  -> Maybe [LengthTargetArgumentRole]
  -> Either LengthHandoffRefusal LengthInterpretationPolicySource
lengthInterpretationPolicySource casePolicy targetRoles =
  case (casePolicy, targetRoles) of
    (LeanLengthCasesRejected, Nothing) ->
      Right LengthLegacyCasesRejected
    (LeanLengthCasesRejected, Just roles) ->
      Right $ LengthExplicitTargetRolesCasesRejected roles
    (LeanLengthExactSpineZeroStepV1, Just roles) ->
      Right $ LengthExplicitTargetRolesExactZeroStepCases roles
    (LeanLengthExactSpineZeroStepV1, Nothing) ->
      Left LengthHandoffExactCasePolicyRequiresTargetRoles

resolveSemanticFamily
  :: PreparedSynthesisInspection
  -> LeanLengthSpineIdentity
  -> Either
      LengthHandoffRefusal
      (SemanticFamilyBindingInspection, Name, Name)
resolveSemanticFamily origin spine = case
    [ binding
    | binding <- inspectedSemanticFamilyBindings origin
    , inspectedSemanticFamilyLeanName binding ==
        leanLengthSpineFamilyName spine
    ] of
  [binding] -> do
    zeroConstructor <- checkedSpineConstructor binding
      $ leanLengthSpineZeroConstructorName spine
    stepConstructor <- checkedSpineConstructor binding
      $ leanLengthSpineStepConstructorName spine
    Right (binding, zeroConstructor, stepConstructor)
  _ -> Left $ LengthHandoffFamilyUnavailable
    $ leanLengthSpineFamilyName spine

checkedSpineConstructor
  :: SemanticFamilyBindingInspection
  -> String
  -> Either LengthHandoffRefusal Name
checkedSpineConstructor family leanConstructor =
  case Map.lookup leanConstructor $ inspectedSemanticFamilyConstructors family of
    Just privateConstructor -> Right privateConstructor
    Nothing -> Left $ LengthHandoffConstructorUnavailable
      (inspectedSemanticFamilyLeanName family) leanConstructor

-- | Bound caller-owned law-list traversal before translating any element.
-- Djex applies this same limit while sealing raw summaries, but Leant must
-- resolve exact provider bindings first. Mirroring the sealer's productive
-- width check here preserves its structured rejection for cyclic or oversized
-- source lists instead of doing unbounded work ahead of that boundary.
boundedProviderLawPrefix
  :: [LeanLengthProviderLaw]
  -> Either LengthHandoffRefusal [LeanLengthProviderLaw]
boundedProviderLawPrefix laws = case beyondLimit of
  [] -> Right withinLimit
  _ : _ -> Left $ LengthHandoffSessionRejected
    $ LengthSessionProviderInventoryRejected
    $ LengthProviderSummaryLimitExceeded maximumSummaries
      (maximumSummaries + 1)
 where
  maximumSummaries = lengthProviderSummaryLimit defaultLengthLimits
  (withinLimit, beyondLimit) = splitAt maximumSummaries laws

convertSourceVariable
  :: ExferenceRunAuthorityInspection
  -> String
  -> Either LengthHandoffRefusal ExferenceTypeVariable
convertSourceVariable authority sourceVariable = case Map.lookup sourceVariable
    $ inspectedAuthorityNameTable authority of
  Nothing -> Left $ LengthHandoffSourceGoalVariableMissing sourceVariable
  Just local -> Right $ FlexibleVariable local

resolveProviderLaw
  :: ExferenceRunAuthorityInspection
  -> PreparedSynthesisInspection
  -> LeanLengthProviderLaw
  -> Either
      LengthHandoffRefusal
      (LengthProviderSummarySource ExferenceTypeVariable)
resolveProviderLaw authority origin law = case
    [ binding
    | binding <- inspectedProviderBindings origin
    , inspectedProviderSourceName binding == leanLengthProviderLawName law
    ] of
  [] -> Left $ LengthHandoffProviderUnavailable
    $ leanLengthProviderLawName law
  [binding] -> do
    scheme <- traverse convertProviderVariable
      $ inspectedProviderScheme binding
    Right AssumedProviderSummary
      { lengthProviderName = inspectedProviderPrivateName binding
      , lengthProviderScheme = scheme
      , lengthProviderArgumentRoles =
          leanLengthProviderLawArgumentRoles law
      , lengthProviderTransfer = leanLengthProviderLawTransfer law
      }
   where
    convertProviderVariable providerVariable = case Map.lookup providerVariable
        $ inspectedAuthorityNameTable authority of
      Nothing -> Left $ LengthHandoffProviderVariableMissing
        (leanLengthProviderLawName law) providerVariable
      Just local -> Right $ FlexibleVariable local
  bindings -> Left $ LengthHandoffProviderAmbiguous
    (leanLengthProviderLawName law) (length bindings)

checkDirectRendering
  :: LeanLengthCandidateCasePolicy
  -> ExactTypedVariantOrigin
  -> DetailedVerificationVariant
  -> Either LengthHandoffRefusal ()
checkDirectRendering casePolicy exactOrigin variant = do
  rendered <- case renderExactTypedVariantOrigin exactOrigin of
    Left (ExactTypedVariantGraphUnavailable absence) ->
      Left $ LengthHandoffTypedGraphLost absence
    Left (ExactTypedVariantRendererRejected refusal) ->
      Left $ LengthHandoffRendererRejected refusal
    Right alternatives -> Right alternatives
  exactText <- case casePolicy of
    LeanLengthCasesRejected -> selectLegacyAlternative rendered
    LeanLengthExactSpineZeroStepV1 -> selectOriginatingAlternative
      (exactTypedVariantOriginOrdinal exactOrigin) rendered
  let acceptedText = detailedVerificationVariantText variant
  if acceptedText == exactText
    then Right ()
    else Left $ LengthHandoffRendererTextChanged exactText acceptedText
 where
  -- The case-rejecting policy keeps the original singleton renderer
  -- requirement and ordinal-zero check. The exact case policy associates the
  -- retained ordinal within a multi-alternative rendering. This follows the
  -- decoded semantic policy rather than assuming a particular file version.
  selectLegacyAlternative [text]
    | exactTypedVariantOriginOrdinal exactOrigin == 0 = Right text
    | otherwise = Left $ LengthHandoffRendererOrdinalChanged
        $ exactTypedVariantOriginOrdinal exactOrigin
  selectLegacyAlternative alternatives = Left
    $ LengthHandoffRendererNotUnique $ length alternatives

  -- The origin records the renderer ordinal and exact text before verification.
  -- Re-running the same renderer over the retained graph and authority lets a
  -- later spelling be associated without requiring the graph to have only one
  -- valid Lean presentation. Traversal is bounded by the renderer's already
  -- finite alternative list and avoids converting a caller-visible Natural.
  selectOriginatingAlternative 0 (text : _) = Right text
  selectOriginatingAlternative remaining (_ : alternatives) =
    selectOriginatingAlternative (remaining - 1) alternatives
  selectOriginatingAlternative _ [] = Left
    $ LengthHandoffRendererOrdinalChanged
    $ exactTypedVariantOriginOrdinal exactOrigin
