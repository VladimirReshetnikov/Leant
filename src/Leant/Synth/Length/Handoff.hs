{-# LANGUAGE RankNTypes #-}

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
  , SourceCheckedLengthProblem (..)
  , prepareSourceCheckedLengthProblem
  , LengthSpinePairHandoffRefusal (..)
  , prepareCheckedLengthSpinePairProblem
  , SourceCheckedLengthSpinePairProblem (..)
  , prepareSourceCheckedLengthSpinePairProblem
  ) where

import qualified Data.Map.Strict as Map
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( CheckedLengthProblem
  , Candidate
  , Inventory
  , Type
  , TypedCandidate
  , CheckedLengthSpinePairProblem
  , ExferenceLocal
  , ExferenceTermGraphAbsence
  , ExferenceTypeVariable
  , LengthContractError
  , LengthProblemError
  , LengthProviderInventoryError (..)
  , LengthProviderSummarySource (..)
  , LengthInterpretationPolicySource (..)
  , LengthSessionError (..)
  , LengthSpinePairComponent (..)
  , LengthSpinePairContractError
  , LengthSpinePairProblemError
  , LengthSpineModelSource (DeclaredListSpine)
  , LengthTargetArgumentRole
  , Name
  , QueryRequest (..)
  , Variable (FlexibleVariable)
  , defaultLengthLimits
  , defaultLengthProblemLimits
  , lengthProviderSummaryLimit
  , sealLengthContractInSession
  , sealLengthSpinePairContractInSession
  , sealLengthSpinePairTypedCandidateProblemInSession
  , sealLengthSessionWithInterpretationPolicy
  , sealLengthTypedCandidateProblemInSession
  , splitLeadingForalls
  )
import Language.Haskell.Djex.Djinn
  ( DjinnTermGraphAbsence
  , djinnSessionSourceInventory
  , djinnTypedCandidateForLength
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
  , exactTypedVariantOriginSourceAuthority
  , foldCandidateSourceAuthority
  , djinnSourceCandidate
  , djinnSourcePreparation
  , djinnSourceRequest
  , djinnSourceSession
  , closeDjinnTransportGoal
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
  , LeanLengthSpinePairContract (..)
  , LeanLengthSpineIdentity (..)
  )
import Leant.Synth.Fragment
  ( AppHead (AppNominal)
  , Frag (..)
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
  | LengthHandoffSessionRejected (LengthSessionError ExferenceLocal)
  | LengthHandoffContractRejected (LengthContractError ExferenceTypeVariable)
  | LengthHandoffProblemRejected
      (LengthProblemError
        ExferenceTermGraphAbsence ExferenceLocal ExferenceLocal)
  | LengthHandoffExferenceProjectionRequired
  | LengthHandoffDjinnTypedGraphLost DjinnTermGraphAbsence
  | LengthHandoffDjinnSessionRejected (LengthSessionError String)
  | LengthHandoffDjinnContractRejected (LengthContractError (Variable String))
  | LengthHandoffDjinnProblemRejected
      (LengthProblemError DjinnTermGraphAbsence String String)
  deriving (Eq, Show)

-- | Fail-closed phases unique to the canonical binary-product entrance.
-- Shared exact-origin and session refusals remain nested so the scalar public
-- type and its constructor order stay unchanged.
data LengthSpinePairHandoffRefusal
  = LengthSpinePairHandoffSharedRefusal LengthHandoffRefusal
  | LengthSpinePairHandoffResultNotCanonicalLeanProd
  | LengthSpinePairHandoffComponentNotConfiguredSpine
      LengthSpinePairComponent String
  | LengthSpinePairHandoffContractRejected
      (LengthSpinePairContractError ExferenceTypeVariable)
  | LengthSpinePairHandoffProblemRejected
      (LengthSpinePairProblemError
        ExferenceTermGraphAbsence ExferenceLocal ExferenceLocal)
  | LengthSpinePairHandoffDjinnContractRejected
      (LengthSpinePairContractError (Variable String))
  | LengthSpinePairHandoffDjinnProblemRejected
      (LengthSpinePairProblemError DjinnTermGraphAbsence String String)
  deriving (Eq, Show)

-- | Whole checked problems keep their engine's nominal source and local
-- identities. Neither branch rekeys a graph or substitutes another engine's
-- inventory, including when Both displays equal spellings.
data SourceCheckedLengthProblem
  = ExferenceCheckedLengthProblem
      (CheckedLengthProblem ExferenceLocal ExferenceLocal)
  | DjinnCheckedLengthProblem (CheckedLengthProblem String String)

data SourceCheckedLengthSpinePairProblem
  = ExferenceCheckedLengthSpinePairProblem
      (CheckedLengthSpinePairProblem ExferenceLocal ExferenceLocal)
  | DjinnCheckedLengthSpinePairProblem
      (CheckedLengthSpinePairProblem String String)

-- These inputs are constructed only by eliminating the retained whole owner.
-- The polymorphic helpers below use the same checked Djex sealers for either
-- nominal identity domain; the compatibility residual adapter is supplied by
-- Djinn itself and does not rebuild or relabel the graph.
data LengthSourceInputs identity local absence details output = LengthSourceInputs
  { sourcePreparation :: PreparedSynthesisInspection
  , sourceInventory :: Inventory (Variable identity) ()
  , sourceTypedCandidate :: TypedCandidate absence (Type (Variable identity)) local
      (Candidate (Type (Variable identity)) details output)
  , sourceVariable :: String -> Either LengthHandoffRefusal (Variable identity)
  , sourceProviderVariable :: String -> String
      -> Either LengthHandoffRefusal (Variable identity)
  , sourceRequestGoal :: Type (Variable identity)
  , sourceCloseGoal :: Type (Variable identity) -> Type (Variable identity)
  , sourceRequestContextCount :: Int
  , sourceSessionRefusal :: LengthSessionError identity -> LengthHandoffRefusal
  , sourceContractRefusal :: LengthContractError (Variable identity)
      -> LengthHandoffRefusal
  , sourceProblemRefusal :: LengthProblemError absence identity local
      -> LengthHandoffRefusal
  , sourcePairContractRefusal :: LengthSpinePairContractError (Variable identity)
      -> LengthSpinePairHandoffRefusal
  , sourcePairProblemRefusal :: LengthSpinePairProblemError absence identity local
      -> LengthSpinePairHandoffRefusal
  }

withLengthSource
  :: ExactTypedVariantOrigin
  -> (forall identity local absence details output. (Ord identity, Ord local)
      => LengthSourceInputs identity local absence details output
      -> (CheckedLengthProblem identity local -> SourceCheckedLengthProblem)
      -> (CheckedLengthSpinePairProblem identity local
          -> SourceCheckedLengthSpinePairProblem)
      -> result)
  -> result
withLengthSource exactOrigin action =
  foldCandidateSourceAuthority fromDjinn fromExference
    $ exactTypedVariantOriginSourceAuthority exactOrigin
 where
  fromExference semantic =
    let authority = typedCandidateSemanticAuthorityInspection semantic
        request = inspectedAuthorityRequest authority
        providerVariable provider variable = case Map.lookup variable
            $ inspectedAuthorityNameTable authority of
          Nothing -> Left $ LengthHandoffProviderVariableMissing provider variable
          Just local -> Right $ FlexibleVariable local
        inputs = LengthSourceInputs
          { sourcePreparation = inspectedAuthorityPreparation authority
          , sourceInventory = typedCandidateSemanticInventory semantic
          , sourceTypedCandidate = typedCandidateSemanticCandidate semantic
          , sourceVariable = convertSourceVariable authority
          , sourceProviderVariable = providerVariable
          , sourceRequestGoal = requestGoal request
          , sourceCloseGoal = id
          , sourceRequestContextCount = length $ requestContexts request
          , sourceSessionRefusal = LengthHandoffSessionRejected
          , sourceContractRefusal = LengthHandoffContractRejected
          , sourceProblemRefusal = LengthHandoffProblemRejected
          , sourcePairContractRefusal = LengthSpinePairHandoffContractRejected
          , sourcePairProblemRefusal = LengthSpinePairHandoffProblemRejected
          }
    in action inputs ExferenceCheckedLengthProblem
        ExferenceCheckedLengthSpinePairProblem
  fromDjinn authority =
    let request = djinnSourceRequest authority
        inputs = LengthSourceInputs
          { sourcePreparation = djinnSourcePreparation authority
          , sourceInventory = djinnSessionSourceInventory $ djinnSourceSession authority
          , sourceTypedCandidate = djinnTypedCandidateForLength $ djinnSourceCandidate authority
          , sourceVariable = Right . FlexibleVariable
          , sourceProviderVariable = \_ -> Right . FlexibleVariable
          , sourceRequestGoal = fmap FlexibleVariable $ requestGoal request
          , sourceCloseGoal = closeDjinnTransportGoal
          , sourceRequestContextCount = length $ requestContexts request
          , sourceSessionRefusal = LengthHandoffDjinnSessionRejected
          , sourceContractRefusal = LengthHandoffDjinnContractRejected
          , sourceProblemRefusal = LengthHandoffDjinnProblemRejected
          , sourcePairContractRefusal = LengthSpinePairHandoffDjinnContractRejected
          , sourcePairProblemRefusal = LengthSpinePairHandoffDjinnProblemRejected
          }
    in action inputs DjinnCheckedLengthProblem DjinnCheckedLengthSpinePairProblem

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
prepareCheckedLengthProblem source verified =
  requireExferenceProjection LengthHandoffExferenceProjectionRequired verified $ do
    problem <- prepareSourceCheckedLengthProblem source verified
    case problem of
      ExferenceCheckedLengthProblem exact -> Right exact
      DjinnCheckedLengthProblem _ -> Left LengthHandoffExferenceProjectionRequired

prepareSourceCheckedLengthProblem
  :: LeanLengthContract
  -> Verified DetailedVerificationVariant
  -> Either LengthHandoffRefusal SourceCheckedLengthProblem
prepareSourceCheckedLengthProblem source verified = do
  let variant = verifiedCandidate verified
      route = detailedVerificationVariantRoute variant
  exactOrigin <- case detailedVerificationVariantExactTypedOrigin variant of
    Just retained -> Right retained
    Nothing
      | route == RouteTypedCandidate ->
          Left LengthHandoffMissingSemanticSidecar
      | otherwise -> Left $ LengthHandoffNotTypedRoute route
  withLengthSource exactOrigin $ \inputs wrapProblem _ ->
    wrapProblem <$> prepareLengthProblemFromSource inputs source exactOrigin variant

prepareLengthProblemFromSource
  :: (Ord identity, Ord local)
  => LengthSourceInputs identity local absence details output
  -> LeanLengthContract
  -> ExactTypedVariantOrigin
  -> DetailedVerificationVariant
  -> Either LengthHandoffRefusal (CheckedLengthProblem identity local)
prepareLengthProblemFromSource inputs source exactOrigin variant = do
  let origin = sourcePreparation inputs
      candidate = sourceTypedCandidate inputs
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
  convertedSource <- fmap (sourceCloseGoal inputs) $ traverse (sourceVariable inputs)
    $ inspectedSourceGoal origin
  if sourceRequestContextCount inputs == 0
    then pure ()
    else Left $ LengthHandoffRequestContextsPresent
      $ sourceRequestContextCount inputs
  if sourceRequestGoal inputs == convertedSource
    then pure ()
    else Left LengthHandoffRequestGoalChanged
  checkDirectRendering
    (leanLengthContractCandidateCasePolicy source) exactOrigin variant
  (family, zeroConstructor, stepConstructor) <- resolveSemanticFamily origin
    $ leanLengthContractSpine source
  providerLaws <- boundedProviderLawPrefix
    $ leanLengthContractProviderLaws source
  providerSources <- mapM (resolveProviderLawBy (sourceProviderVariable inputs) origin) providerLaws
  let inventory = sourceInventory inputs
      spineModel = DeclaredListSpine
        (inspectedSemanticFamilyPrivateTypeName family)
        zeroConstructor
        stepConstructor
      targetRoles = leanLengthContractTargetArgumentRoles source
      casePolicy = leanLengthContractCandidateCasePolicy source
      interpretationPolicy = lengthInterpretationPolicySource
        casePolicy targetRoles
  session <- either (Left . sourceSessionRefusal inputs) Right
    $ sealLengthSessionWithInterpretationPolicy defaultLengthLimits
        interpretationPolicy inventory spineModel providerSources
  contract <- either (Left . sourceContractRefusal inputs) Right
    $ sealLengthContractInSession session convertedSource
        (leanLengthContractSource source)
  either (Left . sourceProblemRefusal inputs) Right
    $ sealLengthTypedCandidateProblemInSession
        defaultLengthProblemLimits session contract candidate

-- | Prepare a product-domain problem only when the accepted goal result has a
-- post-@whnfR@ saturated canonical Lean @Prod@ root and both source-ordered
-- fields are exact unary applications of the configured spine family.
--
-- Synthesis continues to use the ordinary structural pair translation.  The
-- distinct 'FLeanProd' marker is consulted here, before Djex seals its boxed
-- tuple target, so @And@, @PProd@, a scalar spine, and a nested/non-binary
-- product cannot acquire product behavioral authority by sharing that search
-- representation.  The configured spine alone is resolved through retained
-- semantic-family provenance; no binding is invented for Lean's built-in
-- @Prod@.
prepareCheckedLengthSpinePairProblem
  :: LeanLengthSpinePairContract
  -> Verified DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal
      (CheckedLengthSpinePairProblem ExferenceLocal ExferenceLocal)
prepareCheckedLengthSpinePairProblem source verified =
  requireExferenceProjection refusal verified $ do
    problem <- prepareSourceCheckedLengthSpinePairProblem source verified
    case problem of
      ExferenceCheckedLengthSpinePairProblem exact -> Right exact
      DjinnCheckedLengthSpinePairProblem _ -> Left refusal
 where
  refusal = LengthSpinePairHandoffSharedRefusal LengthHandoffExferenceProjectionRequired

-- Preserve the old projection's early refusal, including non-strictness in
-- a contract which is irrelevant to this engine. Missing origins still use
-- the usual route/authority diagnostics in the shared entrance.
requireExferenceProjection
  :: refusal
  -> Verified DetailedVerificationVariant
  -> Either refusal result
  -> Either refusal result
requireExferenceProjection refusal verified action =
  case detailedVerificationVariantExactTypedOrigin $ verifiedCandidate verified of
    Nothing -> action
    Just origin -> foldCandidateSourceAuthority (const $ Left refusal) (const action)
      $ exactTypedVariantOriginSourceAuthority origin

prepareSourceCheckedLengthSpinePairProblem
  :: LeanLengthSpinePairContract
  -> Verified DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal SourceCheckedLengthSpinePairProblem
prepareSourceCheckedLengthSpinePairProblem source verified = do
  let variant = verifiedCandidate verified
      route = detailedVerificationVariantRoute variant
      shared result = either
        (Left . LengthSpinePairHandoffSharedRefusal) Right result
  exactOrigin <- shared $ case detailedVerificationVariantExactTypedOrigin
      variant of
    Just retained -> Right retained
    Nothing
      | route == RouteTypedCandidate ->
          Left LengthHandoffMissingSemanticSidecar
      | otherwise -> Left $ LengthHandoffNotTypedRoute route
  withLengthSource exactOrigin $ \inputs _ wrapProblem ->
    wrapProblem <$> prepareLengthSpinePairProblemFromSource inputs source exactOrigin variant

prepareLengthSpinePairProblemFromSource
  :: (Ord identity, Ord local)
  => LengthSourceInputs identity local absence details output
  -> LeanLengthSpinePairContract
  -> ExactTypedVariantOrigin
  -> DetailedVerificationVariant
  -> Either LengthSpinePairHandoffRefusal
      (CheckedLengthSpinePairProblem identity local)
prepareLengthSpinePairProblemFromSource inputs source exactOrigin variant = do
  let origin = sourcePreparation inputs
      candidate = sourceTypedCandidate inputs
      shared result = either
        (Left . LengthSpinePairHandoffSharedRefusal) Right result
  shared $ if inspectedEngineFragment origin == inspectedFitFragment origin
    then Right ()
    else Left LengthHandoffRetargetedFragments
  shared $ if null (inspectedConstructorPremises origin)
      && null (inspectedCallerPremises origin)
    then Right ()
    else Left LengthHandoffPremisesPresent
  shared $ if inspectedSourceGoal origin == inspectedSearchGoal origin
    then Right ()
    else Left LengthHandoffSearchGoalChanged
  convertedSource <- shared $ fmap (sourceCloseGoal inputs) $ traverse (sourceVariable inputs)
    $ inspectedSourceGoal origin
  shared $ if sourceRequestContextCount inputs == 0
    then Right ()
    else Left $ LengthHandoffRequestContextsPresent
      $ sourceRequestContextCount inputs
  shared $ if sourceRequestGoal inputs == convertedSource
    then Right ()
    else Left LengthHandoffRequestGoalChanged
  shared $ checkDirectRendering
    (leanLengthSpinePairContractCandidateCasePolicy source)
    exactOrigin variant
  let configuredSpine = leanLengthSpinePairContractSpine source
  case lengthResultFragment $ inspectedEngineFragment origin of
    FLeanProd first second -> do
      requireConfiguredSpineApplication
        LengthSpinePairFirst configuredSpine first
      requireConfiguredSpineApplication
        LengthSpinePairSecond configuredSpine second
    _ -> Left LengthSpinePairHandoffResultNotCanonicalLeanProd
  (family, zeroConstructor, stepConstructor) <- shared
    $ resolveSemanticFamily origin configuredSpine
  providerLaws <- shared $ boundedProviderLawPrefix
    $ leanLengthSpinePairContractProviderLaws source
  providerSources <- shared $ mapM
    (resolveProviderLawBy (sourceProviderVariable inputs) origin) providerLaws
  let inventory = sourceInventory inputs
      spineModel = DeclaredListSpine
        (inspectedSemanticFamilyPrivateTypeName family)
        zeroConstructor
        stepConstructor
      targetRoles = leanLengthSpinePairContractTargetArgumentRoles source
      casePolicy = leanLengthSpinePairContractCandidateCasePolicy source
      interpretationPolicy = lengthInterpretationPolicySource
        casePolicy targetRoles
  session <- shared $ either (Left . sourceSessionRefusal inputs) Right
    $ sealLengthSessionWithInterpretationPolicy defaultLengthLimits
        interpretationPolicy inventory spineModel providerSources
  contract <- either
    (Left . sourcePairContractRefusal inputs) Right
    $ sealLengthSpinePairContractInSession session convertedSource
        (leanLengthSpinePairContractSource source)
  either (Left . sourcePairProblemRefusal inputs) Right
    $ sealLengthSpinePairTypedCandidateProblemInSession
        defaultLengthProblemLimits session contract candidate

-- | Peel only the target's introduction spine. A product nested within either
-- component is therefore not mistaken for the binary result root.
lengthResultFragment :: Frag -> Frag
lengthResultFragment fragment = case fragment of
  FArr _ result -> lengthResultFragment result
  FAll _ _ result -> lengthResultFragment result
  FInst _ result -> lengthResultFragment result
  FExactContext _ _ result -> lengthResultFragment result
  result -> result

requireConfiguredSpineApplication
  :: LengthSpinePairComponent
  -> LeanLengthSpineIdentity
  -> Frag
  -> Either LengthSpinePairHandoffRefusal ()
requireConfiguredSpineApplication component configured fragment
  | exactUnaryFamilyApplication expectedFamily fragment = Right ()
  | otherwise = Left $ LengthSpinePairHandoffComponentNotConfiguredSpine
      component expectedFamily
 where
  expectedFamily = leanLengthSpineFamilyName configured

-- Exact parametric-family nodes are emitted from elaborated nominal heads.
-- The generic application case covers a fail-closed abstract exact family;
-- the later Djex contract sealer still requires its translated private type to
-- be the session's structurally checked unary spine.
exactUnaryFamilyApplication :: String -> Frag -> Bool
exactUnaryFamilyApplication expected fragment = case fragment of
  FParamInd family _ [_] _ -> family == expected
  FParamRec _ family _ [_] _ -> family == expected
  FApp _ _ (AppNominal family) [_] -> family == expected
  _ -> False

-- | Convert Leant's two explicit policy axes once, after every exact family
-- and provider identity has been resolved.  The closed Djex source makes the
-- selected case semantics and exact source-ordered roles inseparable past
-- this point.
lengthInterpretationPolicySource
  :: LeanLengthCandidateCasePolicy
  -> [LengthTargetArgumentRole]
  -> LengthInterpretationPolicySource
lengthInterpretationPolicySource casePolicy targetRoles =
  case casePolicy of
    LeanLengthCasesRejected ->
      LengthExplicitTargetRolesCasesRejected targetRoles
    LeanLengthExactSpineZeroStepV1 ->
      LengthExplicitTargetRolesExactZeroStepCases targetRoles

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
convertSourceVariable authority sourceName = case Map.lookup sourceName
    $ inspectedAuthorityNameTable authority of
  Nothing -> Left $ LengthHandoffSourceGoalVariableMissing sourceName
  Just local -> Right $ FlexibleVariable local

resolveProviderLawBy
  :: (String -> String -> Either LengthHandoffRefusal variable)
  -> PreparedSynthesisInspection
  -> LeanLengthProviderLaw
  -> Either
      LengthHandoffRefusal
      (LengthProviderSummarySource variable)
resolveProviderLawBy convertVariable origin law = case
    [ binding
    | binding <- inspectedProviderBindings origin
    , inspectedProviderSourceName binding == leanLengthProviderLawName law
    ] of
  [] -> Left $ LengthHandoffProviderUnavailable
    $ leanLengthProviderLawName law
  [binding] -> do
    scheme <- traverse convertProviderVariable
      $ inspectedProviderScheme binding
    -- The exact inventory scheme is the only trust discriminator. Keeping an
    -- empty leading context on the historical constructor preserves its
    -- provider/session identities, while a retained context merely selects
    -- Djex's conditional law: this handoff neither resolves nor supplies its
    -- dictionary evidence.
    let providerSummary = case splitLeadingForalls scheme of
          (_, [], _) -> AssumedProviderSummary
            { lengthProviderName = inspectedProviderPrivateName binding
            , lengthProviderScheme = scheme
            , lengthProviderArgumentRoles =
                leanLengthProviderLawArgumentRoles law
            , lengthProviderTransfer = leanLengthProviderLawTransfer law
            }
          (_, _ : _, _) -> AssumedConstraintConditionalProviderSummary
            { lengthProviderName = inspectedProviderPrivateName binding
            , lengthProviderScheme = scheme
            , lengthProviderArgumentRoles =
                leanLengthProviderLawArgumentRoles law
            , lengthProviderTransfer = leanLengthProviderLawTransfer law
            }
    Right providerSummary
   where
    convertProviderVariable = convertVariable $ leanLengthProviderLawName law
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
    Left (ExactTypedVariantDjinnGraphUnavailable absence) ->
      Left $ LengthHandoffDjinnTypedGraphLost absence
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
