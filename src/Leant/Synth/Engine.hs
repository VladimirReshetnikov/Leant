-- | The narrow engine boundary for @:synth@ (design rule 4 of
-- SYNTHESIS_PROPOSAL.md): fragment goal in, candidate batch out.  This is
-- the module that owns Djex translation and search; the engine behind the
-- boundary (today: Djinn's LJT search, in-process) is swappable without
-- touching the REPL layer. "Leant.Synth.Length.Handoff" separately consumes
-- the retained provenance to seal a checked domain problem; the engine itself
-- owns no behavioral contract or domain sealer.
--
-- Verdicts follow Djex's evidence\/progress split, extended by the
-- two-axis honesty rule of the proposal: a refutation is reported as
-- sound only when Djex itself claims 'ProvedUninhabitable' (its
-- projection was complete) /and/ the Leant-side translation introduced no
-- atom that hides concrete structure ('fragUnsafeAtoms').
--
-- Phase 2: expanded inductive occurrences become Djinn @data@ declarations --
-- constructors as right-rules, case analysis as left-rules, exactly how Djinn
-- admits Haskell datatypes.  Exact-head 'FParamInd' and 'FParamRec' occurrences
-- are pre-scanned across the whole query and share one validated parameterized
-- declaration.  Djinn uses bounded positive recursive introduction while
-- recursive elimination remains restricted to Exference;
-- legacy 'FInd' occurrences remain keyed by their alpha-normalized display
-- spelling.  Engine-side type and constructor names are fresh, and mappings
-- back to their exact Lean spellings ride along to the renderer.
--
-- Caller-supplied premises (library functions over the goal's recursive
-- inductives, excluded-middle instances of the classical fallback)
-- enter through 'synthesizeWith'\/'synthesizeTuned' and become goal
-- antecedents under the leading quantifier prefix, so premise types may
-- mention the goal's bound variables.
module Leant.Synth.Engine
  ( SynthEngine (..)
  , SynthOutcome (..)
  , DetailedCandidateGroup
  , DetailedVerificationVariant
  , ExactTypedVariantOrigin
  , ExactTypedVariantRenderingFailure (..)
  , TypedCandidateSemanticSidecar
  , detailedCandidateGroup
  , detailedCandidateGroupRoute
  , detailedCandidateGroupVariants
  , detailedCandidateGroupVerificationVariants
  , detailedCandidateGroupSemanticSidecar
  , detailedVerificationVariantText
  , detailedVerificationVariantOrdinal
  , detailedVerificationVariantRoute
  , detailedVerificationVariantSemanticSidecar
  , detailedVerificationVariantExactTypedOrigin
  , exactTypedVariantOriginOrdinal
  , exactTypedVariantOriginSidecar
  , renderExactTypedVariantOrigin
  , typedCandidateSemanticCandidate
  , typedCandidateSemanticInventory
  , typedCandidateSemanticAuthorityInspection
  , mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
  , DetailedSynthOutcome (..)
  , projectDetailedSynthOutcome
  , parseSynthEngine
  , synthEngineName
  , providerStages
  , mergeCandidateGroups
  , mergeDetailedCandidateGroups
  , mergeOutcomes
  , mergeOutcomesSkipping
  , mergeDetailedOutcomesSkipping
  , withoutCheckedCandidates
  , withoutCheckedDetailedCandidates
  , synthesize
  , synthesizeWithProviders
  , synthesizeWithProvidersSkipping
  , synthesizeWithProvidersSkippingDetailed
  , synthesizeWith
  , synthesizeTuned
  , synthesizeTunedDetailed
  , forceOutcome
  , forceDetailedOutcome
  , synthMaxShown
  , synthMaxTried
  , synthVerificationWindow
  , candidateWindow
  , takeDistinct
  , takeDistinctOn
  , renderCandidateByAvailability
  , TranslatedPremise (..)
  , ProviderBindingInspection (..)
  , SemanticFamilyBindingInspection (..)
  , PreparedSynthesisInspection (..)
  , ExferenceRunAuthorityInspection (..)
  , inspectExferencePreparation
  ) where

import Data.Foldable (toList)
import Data.List (intercalate, isPrefixOf, nub, nubBy, sortOn)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Void (Void)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( Constraint (..)
  , QueryEvidence (..)
  , QueryOptions (..)
  , QueryRequest (..)
  , Boxity (Boxed)
  , Completion (..)
  , DataConstructor (..)
  , Declaration
      ( AbstractTypeDeclaration
      , ClassDeclaration
      , DataTypeDeclaration
      , ValueDeclaration
      )
  , Diagnostic
  , ExferenceInventory
  , ExferenceLocal
  , ExferenceOptions (..)
  , ExferenceRequest
  , ExferenceSession
  , ExferenceSessionPolicy (..)
  , ExferenceTermGraphAbsence
  , ExferenceTypedCandidate
  , ExferenceType
  , ExferenceTypeVariable
  , Expression
  , GroundKind
  , Name
  , Kind (FunctionKind, ProperTypeKind)
  , Penalty (..)
  , Progress (..)
  , KindedProviderInstantiationAssignment (..)
  , Selection (..)
  , SelectionMode (SelectAll)
  , TruncationReason (..)
  , Type (..)
  , TypeParameter (..)
  , ValueSignature (..)
  , Variable (FlexibleVariable)
  , applyTypeArguments
  , batchCandidates
  , batchProgress
  , candidateOutput
  , declarationTypeVariables
  , defaultExferenceOptions
  , defaultExferenceSessionPolicy
  , defaultQueryOptions
  , djinnSessionEnvironment
  , environmentDeclarations
  , expressionSize
  , functionClauseExpression
  , mapDeclarationTypeVariables
  , maximumProviderInstantiationAssignments
  , maximumProviderInstantiationArguments
  , mkDefinitionName
  , mkDjinnRequest
  , mkDjinnSession
  , mkEnvironment
  , mkExferenceRequest
  , mkExferenceSessionWithPolicy
  , mkIdentifier
  , nameSpelling
  , renderDiagnostic
  , resultEvidence
  , resultSearch
  , runDjinnQueryWithKindedInstantiationAssignments
  , runExferenceTypedQueryWithKindedInstantiationAssignments
  , selectQueryResults
  , specifiedVisibleTypeArgument
  , standardDjinnSession
  , tupleName
  , valueName
  , typedCandidateCompatibility
  , typedCandidateTermGraph
  , TermGraph
  , exferenceSessionInventory
  , exferenceRequestQuery
  )

import Leant.Synth.Observability
  ( CandidateRenderingRoute
      ( RouteLegacyCandidateFallback
      , RouteTypedCandidate
      , RouteUnobserved
      )
  )

import Leant.Synth.Fragment
  ( AppHead (..)
  , ExactContextArgument (..)
  , Frag (..)
  , ProviderFrag (..)
  , ProviderInstantiationArgument (..)
  , Slot (..)
  , fragHasDepth
  , fragHasInstanceBinder
  , fragHasUnsupportedInstanceBinder
  , fragSpine
  , fragUnsafeAtoms
  , fragVisibleForallVisibilities
  , exactContextArgumentKindArity
  , exactContextArgumentPayloadFragments
  , mapExactContextArgumentFragments
  , maximumProviderArgumentKindArity
  , maximumProviderExactForallDomains
  )
import Leant.Synth.Render
  ( CtorInfo (..)
  , CtorMap
  , ProviderAssignmentInfo (..)
  , ProviderInfo (..)
  , ProviderMap
  , TypeMap
  , providerInfo
  , renderLeanTerm
  , renderLeanTermGraphProjection
  )

-- | What the engine established for one goal.  Candidate terms are a lazy
-- ranked list of rendered variant groups (one group per engine candidate;
-- within a group, textual variants of the same term); the caller verifies
-- them against the backend before showing anything.
data SynthOutcome
  = SynthCandidates [[String]] [String]
    -- ^ rendered candidate groups (best first), operational notes
  | SynthRefuted Bool
    -- ^ no inhabitant; 'True' means the verdict is sound (complete
    -- translation, no structure-hiding atoms)
  | SynthNoTerm [String]
    -- ^ no candidate and no logical claim, with notes
  deriving (Eq, Show)

-- | Exact checked inputs shared by every typed candidate from one Exference
-- lane.  The session remains opaque, while the policy, request, provider
-- assignments, variable identity, and pure Leant preparation stay attached so
-- a later semantic checker never has to reconstruct authority from rendered
-- text or private-name conventions.
data ExferenceRunAuthority = ExferenceRunAuthority
  { exferenceAuthorityPreparation :: PreparedSemanticOrigin
  , exferenceAuthorityNameTable :: Map.Map String ExferenceLocal
  , exferenceAuthorityConvertedSourceGoal :: ExferenceType
  , exferenceAuthorityPolicy :: ExferenceSessionPolicy
  , exferenceAuthoritySession :: ExferenceSession
  , exferenceAuthorityRequest :: ExferenceRequest
  , exferenceAuthorityProviderAssignments ::
      [KindedProviderInstantiationAssignment ExferenceTypeVariable]
  }

-- | Checked Exference identity retained with one originating rendered group.
--
-- The opaque typed candidate keeps its compatibility projection inseparable
-- from the exact graph which produced the group and the full checked run which
-- admitted it.  The graph remains owned only by that checked candidate, and
-- Djex fingerprints it only while sealing an actual behavioral problem; rendering
-- retains no parallel fallible graph-key cache.
data TypedCandidateSemanticSidecar = TypedCandidateSemanticSidecar
  ExferenceTypedCandidate
  ExferenceRunAuthority

-- Comparing the checked candidate and every observable run input is
-- sufficient and keeps equality from forcing opaque session internals.
instance Eq TypedCandidateSemanticSidecar where
  TypedCandidateSemanticSidecar leftCandidate leftAuthority
      == TypedCandidateSemanticSidecar rightCandidate rightAuthority =
    leftCandidate == rightCandidate
      && exferenceSessionInventory
          (exferenceAuthoritySession leftAuthority)
        == exferenceSessionInventory
          (exferenceAuthoritySession rightAuthority)
      && exferenceAuthorityPreparation leftAuthority
        == exferenceAuthorityPreparation rightAuthority
      && exferenceAuthorityNameTable leftAuthority
        == exferenceAuthorityNameTable rightAuthority
      && exferenceAuthorityConvertedSourceGoal leftAuthority
        == exferenceAuthorityConvertedSourceGoal rightAuthority
      && exferenceAuthorityPolicy leftAuthority
        == exferenceAuthorityPolicy rightAuthority
      && exferenceAuthorityRequest leftAuthority
        == exferenceAuthorityRequest rightAuthority
      && exferenceAuthorityProviderAssignments leftAuthority
        == exferenceAuthorityProviderAssignments rightAuthority

-- | Recover the checked candidate without detaching its graph association.
typedCandidateSemanticCandidate
  :: TypedCandidateSemanticSidecar
  -> ExferenceTypedCandidate
typedCandidateSemanticCandidate
    (TypedCandidateSemanticSidecar candidate _) = candidate

-- | Recover the exact checked inventory from the candidate's Exference run.
typedCandidateSemanticInventory
  :: TypedCandidateSemanticSidecar
  -> ExferenceInventory
typedCandidateSemanticInventory
    (TypedCandidateSemanticSidecar _ authority) =
  exferenceSessionInventory (exferenceAuthoritySession authority)

-- | Comparable view of the exact checked lane authority. The actual session
-- remains retained privately by the sidecar for later checked operations.
typedCandidateSemanticAuthorityInspection
  :: TypedCandidateSemanticSidecar
  -> ExferenceRunAuthorityInspection
typedCandidateSemanticAuthorityInspection
    (TypedCandidateSemanticSidecar _ authority) =
  inspectExferenceRunAuthority authority

-- | Exact typed origin for one spelling.  It can be the direct Exference
-- display owner or an Exference origin retained after a later duplicate was
-- collapsed.  This is deliberately variant-scoped: in the latter case the
-- sidecar still belongs to that Exference candidate and its original renderer
-- ordinal, never to the Djinn group which displayed the same text first.
data ExactTypedVariantOrigin = ExactTypedVariantOrigin
  !Natural
  !String
  !TypedCandidateSemanticSidecar

instance Eq ExactTypedVariantOrigin where
  ExactTypedVariantOrigin leftOrdinal leftText leftSidecar
      == ExactTypedVariantOrigin rightOrdinal rightText rightSidecar =
    leftOrdinal == rightOrdinal
      && leftText == rightText
      && leftSidecar == rightSidecar

-- | One renderer-produced spelling and its original zero-based ordinal.
-- Filtering preserves this identity instead of silently renumbering the
-- spellings which survive an earlier verification lane.  A merge may retain
-- a separate exact typed origin for this spelling without changing its
-- display owner, route, ordinal, or group membership.
data DetailedCandidateVariant = DetailedCandidateVariant
  Natural
  String
  (Maybe ExactTypedVariantOrigin)

-- The recovered typed origin is a merge-time assessment witness, not part of
-- the displayed candidate identity.  In particular, group equality and
-- compatibility projections remain exactly as they were before the witness
-- existed.
instance Eq DetailedCandidateVariant where
  DetailedCandidateVariant leftOrdinal leftText _
      == DetailedCandidateVariant rightOrdinal rightText _ =
    leftOrdinal == rightOrdinal && leftText == rightText

instance Show DetailedCandidateVariant where
  showsPrec precedence (DetailedCandidateVariant ordinal text _) =
    showsDetailedCandidateVariant precedence ordinal text

showsDetailedCandidateVariant :: Int -> Natural -> String -> ShowS
showsDetailedCandidateVariant precedence ordinal text =
  showParen (precedence > 10) $
    showString "DetailedCandidateVariant "
      . showsPrec 11 ordinal
      . showChar ' '
      . showsPrec 11 text

-- | One semantic candidate and the route that supplied the expression handed
-- to Leant's renderer.  Every deduplication boundary names the textual-variant
-- key explicitly.  A sidecar belongs to the originating engine candidate, not
-- to an arbitrary spelling which happens to compare equal.
data DetailedCandidateGroup = DetailedCandidateGroup
  CandidateRenderingRoute
  [DetailedCandidateVariant]
  (Maybe TypedCandidateSemanticSidecar)

-- Compare the observable checked-candidate and run authority.  The custom
-- 'Show' instance keeps routine diagnostics independent of the retained
-- session authority.
instance Eq DetailedCandidateGroup where
  DetailedCandidateGroup leftRoute leftVariants leftSidecar
      == DetailedCandidateGroup rightRoute rightVariants rightSidecar =
    leftRoute == rightRoute
      && leftVariants == rightVariants
      && leftSidecar == rightSidecar

instance Show DetailedCandidateGroup where
  showsPrec precedence (DetailedCandidateGroup route variants _) =
    showParen (precedence > 10) $
      showString "DetailedCandidateGroup "
        . showsPrec 11 route
        . showChar ' '
        . showsPrec 11 (map detailedCandidateVariantText variants)

-- | Construct one internal semantic group.  This is exported only to the
-- executable's focused boundary tests; Leant has no public library surface.
detailedCandidateGroup
  :: CandidateRenderingRoute
  -> [String]
  -> DetailedCandidateGroup
detailedCandidateGroup route variants =
  DetailedCandidateGroup route (indexDetailedCandidateVariants variants) Nothing

-- | Rendering-route sidecar for one semantic group.
detailedCandidateGroupRoute
  :: DetailedCandidateGroup
  -> CandidateRenderingRoute
detailedCandidateGroupRoute (DetailedCandidateGroup route _ _) = route

-- | Ordered textual variants of one semantic group.
detailedCandidateGroupVariants :: DetailedCandidateGroup -> [String]
detailedCandidateGroupVariants (DetailedCandidateGroup _ variants _) =
  map detailedCandidateVariantText variants

-- | Verification-facing candidates retain the displayed spelling, its
-- display owner's renderer ordinal and route, and one exact typed assessment
-- origin for that spelling.  The latter may come from a duplicate later
-- Exference group, so it is intentionally independent of display provenance.
-- Scheduling's 'DetailedCandidateVariant' is flattened at this boundary: an
-- accepted receipt therefore keeps neither that intermediate record nor a
-- parallel copy of its recovered origin.  The verifier stays generic; only
-- the Lean callback projects the text it must elaborate.
data DetailedVerificationVariant = DetailedVerificationVariant
  CandidateRenderingRoute
  Natural
  String
  (Maybe ExactTypedVariantOrigin)

instance Eq DetailedVerificationVariant where
  DetailedVerificationVariant leftRoute leftOrdinal leftText leftOrigin
      == DetailedVerificationVariant
          rightRoute rightOrdinal rightText rightOrigin =
    leftRoute == rightRoute
      && leftOrdinal == rightOrdinal
      && leftText == rightText
      && leftOrigin == rightOrigin

instance Show DetailedVerificationVariant where
  showsPrec precedence
      (DetailedVerificationVariant route ordinal text _) =
    showParen (precedence > 10) $
      showString "DetailedVerificationVariant "
        . showsPrec 11 route
        . showChar ' '
        . showsDetailedCandidateVariant 11 ordinal text

-- | Preserve group provenance while presenting its spellings to verification.
detailedCandidateGroupVerificationVariants
  :: DetailedCandidateGroup
  -> [DetailedVerificationVariant]
detailedCandidateGroupVerificationVariants
    (DetailedCandidateGroup route variants sidecar) =
  map (verificationVariant route sidecar) variants

verificationVariant
  :: CandidateRenderingRoute
  -> Maybe TypedCandidateSemanticSidecar
  -> DetailedCandidateVariant
  -> DetailedVerificationVariant
verificationVariant route retained
    (DetailedCandidateVariant ordinal text recoveredOrigin) =
  DetailedVerificationVariant route ordinal text $ case retained of
    Just semantic -> Just $ ExactTypedVariantOrigin
      ordinal text semantic
    Nothing -> recoveredOrigin

-- | Exact Lean spelling passed to the backend verifier.
detailedVerificationVariantText :: DetailedVerificationVariant -> String
detailedVerificationVariantText
    (DetailedVerificationVariant _ _ text _) = text

-- | Original zero-based renderer ordinal, stable through filtering and merge.
detailedVerificationVariantOrdinal
  :: DetailedVerificationVariant
  -> Natural
detailedVerificationVariantOrdinal
    (DetailedVerificationVariant _ ordinal _ _) = ordinal

-- | Rendering path of the group which owns this displayed occurrence.  A
-- recovered typed assessment origin does not rewrite this observation.
detailedVerificationVariantRoute
  :: DetailedVerificationVariant
  -> CandidateRenderingRoute
detailedVerificationVariantRoute
    (DetailedVerificationVariant route _ _ _) = route

-- | Checked Exference origin, when the accepted spelling still denotes an
-- unwrapped typed candidate.  This can be the displayed group itself or the
-- exact same spelling from a later Exference group; it never applies to a
-- merely neighboring variant.
detailedVerificationVariantSemanticSidecar
  :: DetailedVerificationVariant
  -> Maybe TypedCandidateSemanticSidecar
detailedVerificationVariantSemanticSidecar variant =
  exactTypedVariantOriginSidecar
    <$> detailedVerificationVariantExactTypedOrigin variant

-- | Exact candidate identity, when this group came from a retained checked
-- Exference graph and has not subsequently been wrapped as another term.
detailedCandidateGroupSemanticSidecar
  :: DetailedCandidateGroup
  -> Maybe TypedCandidateSemanticSidecar
detailedCandidateGroupSemanticSidecar
    (DetailedCandidateGroup _ _ sidecar) = sidecar

-- | Apply an arbitrary textual wrapper. Such a wrapper denotes a new term and
-- possibly a new target (notably @Classical.byContradiction@), so retaining the
-- originating graph identity would associate semantics with the wrong term.
mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
  :: (String -> String)
  -> DetailedCandidateGroup
  -> DetailedCandidateGroup
mapDetailedCandidateGroupVariantsDroppingSemanticSidecar transform group =
  DetailedCandidateGroup
    (detailedCandidateGroupRoute group)
    (map mapVariant $ detailedCandidateGroupVariantRecords group)
    Nothing
 where
  mapVariant (DetailedCandidateVariant ordinal text _) =
    DetailedCandidateVariant ordinal (transform text) Nothing

-- | Replace a group by a stable subset of its spellings without changing the
-- originating engine candidate. Used only by filtering and scheduling paths
-- which never synthesize a new textual term.
retainDetailedCandidateGroupVariants
  :: [DetailedCandidateVariant]
  -> DetailedCandidateGroup
  -> DetailedCandidateGroup
retainDetailedCandidateGroupVariants variants group = DetailedCandidateGroup
  (detailedCandidateGroupRoute group)
  variants
  (detailedCandidateGroupSemanticSidecar group)

detailedCandidateGroupVariantRecords
  :: DetailedCandidateGroup
  -> [DetailedCandidateVariant]
detailedCandidateGroupVariantRecords
    (DetailedCandidateGroup _ variants _) = variants

detailedCandidateVariantOrdinal :: DetailedCandidateVariant -> Natural
detailedCandidateVariantOrdinal
    (DetailedCandidateVariant ordinal _ _) = ordinal

detailedCandidateVariantText :: DetailedCandidateVariant -> String
detailedCandidateVariantText (DetailedCandidateVariant _ text _) = text

detailedCandidateVariantExactTypedOrigin
  :: DetailedCandidateVariant
  -> Maybe ExactTypedVariantOrigin
detailedCandidateVariantExactTypedOrigin
    (DetailedCandidateVariant _ _ exactOrigin) = exactOrigin

detailedVerificationVariantExactTypedOrigin
  :: DetailedVerificationVariant
  -> Maybe ExactTypedVariantOrigin
detailedVerificationVariantExactTypedOrigin
    (DetailedVerificationVariant _ _ text exactOrigin) = case exactOrigin of
  Just retained
    | exactTypedVariantOriginText retained == text -> Just retained
  _ -> Nothing

exactTypedVariantOriginOrdinal :: ExactTypedVariantOrigin -> Natural
exactTypedVariantOriginOrdinal
    (ExactTypedVariantOrigin ordinal _ _) = ordinal

exactTypedVariantOriginText :: ExactTypedVariantOrigin -> String
exactTypedVariantOriginText (ExactTypedVariantOrigin _ text _) = text

exactTypedVariantOriginSidecar
  :: ExactTypedVariantOrigin
  -> TypedCandidateSemanticSidecar
exactTypedVariantOriginSidecar
    (ExactTypedVariantOrigin _ _ sidecar) = sidecar

-- | Closed failure phases of re-rendering the exact checked graph retained by
-- one typed verification origin. The graph remains owned by its opaque Djex
-- candidate; this classification exposes neither the graph nor the renderer's
-- input maps or premise layout.
data ExactTypedVariantRenderingFailure
  = ExactTypedVariantGraphUnavailable ExferenceTermGraphAbsence
  | ExactTypedVariantRendererRejected String
  deriving (Eq, Show)

-- | Re-run the exact renderer from the origin's retained Engine provenance.
--
-- Keeping this operation beside 'PremiseLayout' makes the positional renderer
-- ABI single-owner. Domain handoffs may impose their own cardinality, ordinal,
-- and accepted-text rules over the returned alternatives; this operation keeps
-- current handoffs from rebuilding constructor, provider, type, or
-- premise-layout inputs independently.
renderExactTypedVariantOrigin
  :: ExactTypedVariantOrigin
  -> Either ExactTypedVariantRenderingFailure [String]
renderExactTypedVariantOrigin
    (ExactTypedVariantOrigin _ _
      (TypedCandidateSemanticSidecar candidate authority)) = do
  graph <- case typedCandidateTermGraph candidate of
    Left absence -> Left $ ExactTypedVariantGraphUnavailable absence
    Right retained -> Right retained
  let origin = exferenceAuthorityPreparation authority
  either (Left . ExactTypedVariantRendererRejected) Right
    $ renderLeanTermGraphProjection
        (("x" ++) . show)
        (semanticOriginConstructorMap origin)
        (semanticOriginProviderMap origin)
        (semanticOriginTypeMap origin)
        (premiseLayoutForRenderer $ semanticOriginPremiseLayout origin)
        (semanticOriginFitFragment origin)
        graph

indexDetailedCandidateVariants :: [String] -> [DetailedCandidateVariant]
indexDetailedCandidateVariants = zipWith
  (\ordinal text -> DetailedCandidateVariant ordinal text Nothing)
  [0 ..]

-- | Internal outcome retaining rendering provenance until the bounded group
-- prefix is observed.  Compatibility APIs project this type immediately.
data DetailedSynthOutcome
  = DetailedSynthCandidates [DetailedCandidateGroup] [String]
  | DetailedSynthRefuted Bool
  | DetailedSynthNoTerm [String]
  deriving (Eq, Show)

-- | Forget rendering provenance without changing any historical result.
projectDetailedSynthOutcome :: DetailedSynthOutcome -> SynthOutcome
projectDetailedSynthOutcome outcome = case outcome of
  DetailedSynthCandidates groups notes ->
    SynthCandidates (map detailedCandidateGroupVariants groups) notes
  DetailedSynthRefuted sound -> SynthRefuted sound
  DetailedSynthNoTerm notes -> SynthNoTerm notes

-- | Product-wide verification limits.  Combined-engine scheduling keeps
-- Exference's first fresh group inside the displayed frontier while the
-- caller applies the larger tried frontier to backend work.
synthMaxShown, synthMaxTried :: Int
synthMaxShown = 5
synthMaxTried = 12

-- | How many fresh candidate groups an ordinary lane may send to Lean.
-- A combined lane receives the existing per-engine budget for /both/ engines;
-- selecting @both@ therefore cannot hide a candidate that either engine would
-- have reached on its own.
synthVerificationWindow :: SynthEngine -> Int
synthVerificationWindow engine = case engine of
  EngineBoth -> 2 * synthMaxTried
  EngineDjinn -> synthMaxTried
  EngineExference -> synthMaxTried

-- | How many engine candidates are collected and take part in the size
-- ranking.  Djinn's sorted mode computes the whole collection before
-- returning, so this bounds real work; the default of 200 buys nothing
-- when at most a handful are ever displayed.  Reaching it truncates the
-- batch, which carries no negative evidence, so refutations - which
-- come from an exhausted search rather than a full collection - stay
-- sound.
candidateWindow :: Int
candidateWindow = 60

-- | Retain the first bounded set of distinct values. Deduplication deliberately
-- precedes the bound so repeated backend derivations cannot consume slots that
-- belong to later semantic candidates.
takeDistinct :: Eq value => Int -> [value] -> [value]
takeDistinct = takeDistinctOn id

-- | Retain the first bounded set of distinct values under an explicit
-- semantic key.  Sidecar metadata therefore cannot accidentally redefine
-- candidate identity at a future call site.
takeDistinctOn :: Eq key => (value -> key) -> Int -> [value] -> [value]
takeDistinctOn key limit =
  take limit . nubBy (\left right -> key left == key right)

-- | Drive an outcome's evaluation far enough that the whole search has
-- run: the verdict itself, plus the first @n@ candidate groups.  The
-- caller runs this under a wall-clock guard - the engine is pure and
-- lazy, so without forcing, the search would instead happen later,
-- outside the guard.
forceOutcome :: Int -> Either String SynthOutcome -> Int
forceOutcome n outcome = case outcome of
  Left err -> length err
  Right (SynthCandidates groups notes) ->
    sum (map (sum . map length) (take n groups)) + noteSize notes
  Right (SynthRefuted sound) -> if sound then 1 else 0
  Right (SynthNoTerm notes) -> noteSize notes
 where
  noteSize = sum . map length

-- | 'forceOutcome' for the internal route-preserving stream.  Forcing the
-- route alongside each bounded group keeps search and observation provenance
-- under the same caller-owned deadline without inspecting the tail.  Exact
-- duplicate origins stay deliberately lazy: opt-in behavioral preparation
-- pays their locally 'candidateWindow'-bounded lookup instead of widening
-- Main's established synthesis work.
forceDetailedOutcome :: Int -> Either String DetailedSynthOutcome -> Int
forceDetailedOutcome n outcome = case outcome of
  Left err -> length err
  Right (DetailedSynthCandidates groups notes) ->
    sum (map groupSize (take n groups)) + noteSize notes
  Right (DetailedSynthRefuted sound) -> if sound then 1 else 0
  Right (DetailedSynthNoTerm notes) -> noteSize notes
 where
  groupSize (DetailedCandidateGroup route variants _) =
    route `seq` sum (map (length . detailedCandidateVariantText) variants)
  noteSize = sum . map length

-- | Select and render the typed expression when present; only an explicit
-- absence may consult the compatibility projection.  A typed rendering
-- failure is returned unchanged and never retried through the fallback.
-- Keeping this policy in one small helper makes its laziness independently
-- testable: the compatibility payload and projector are not forced on a
-- typed route.
renderCandidateByAvailability
  :: (typed -> Either renderError [String])
  -> (legacy -> Either renderError [String])
  -> Either absence typed
  -> compatibility
  -> (compatibility -> legacy)
  -> (CandidateRenderingRoute, Either renderError [String])
renderCandidateByAvailability
    renderTyped renderLegacy availability compatibility fallback =
  case availability of
    Right typed -> (RouteTypedCandidate, renderTyped typed)
    Left _ ->
      ( RouteLegacyCandidateFallback
      , renderLegacy (fallback compatibility)
      )

-- | Which synthesis engine(s) a query runs (proposal F of
-- SYNTHESIS_PROPOSAL.md \167 7).  Djinn is the complete, terminating LJT
-- search with refutation verdicts; Exference is a ranked heuristic
-- search under explicit budgets, with no negative evidence.
data SynthEngine = EngineDjinn | EngineExference | EngineBoth
  deriving (Eq, Show)

parseSynthEngine :: String -> Maybe SynthEngine
parseSynthEngine value = case value of
  "djinn" -> Just EngineDjinn
  "exference" -> Just EngineExference
  "both" -> Just EngineBoth
  _ -> Nothing

synthEngineName :: SynthEngine -> String
synthEngineName engine = case engine of
  EngineDjinn -> "djinn"
  EngineExference -> "exference"
  EngineBoth -> "both"

-- | Bounded live-provider widening in discovery order.  Djinn's fixed
-- candidate window can be crowded by a large environment even when a short
-- prefix contains every declaration needed for a composition.  Give it sparse
-- geometric prefixes before the complete bounded inventory: at most four
-- searches for the current eighty-provider discovery cap.  Exference keeps
-- its rated full-inventory lane.  Combined mode preserves its existing
-- singleton run and complete final run; intermediate prefixes are Djinn-only
-- so widening does not repeatedly spend Exference's step budget.
providerStages :: SynthEngine -> [a] -> [(SynthEngine, [a])]
providerStages _ [] = []
providerStages EngineExference providers =
  [(EngineExference, providers)]
providerStages engine providers =
  [ (stageEngine size, take size providers)
  | size <- filter (< providerCount) [1, 4, 16] ++ [providerCount]
  ]
 where
  providerCount = length providers
  stageEngine size = case engine of
    EngineDjinn -> EngineDjinn
    _
      | size == 1 || size == providerCount -> EngineBoth
      | otherwise -> EngineDjinn

-- | Run the selected in-process search on a translated goal.  The
-- step budget applies to Exference only (Djinn's complete search needs
-- no budget beyond the candidate window).
synthesize :: SynthEngine -> Int -> Frag -> Either String SynthOutcome
synthesize engine steps = synthesizeWithProviders engine steps []

-- | Run synthesis with a bounded caller-owned inventory of foreign values.
-- Both engines may reuse the supplied environment, and Lean subsequently
-- verifies every rendered use.  Foreign names never enter Djex's nominal
-- namespace directly; each receives a collision-free private engine name
-- carried back through the renderer map.
synthesizeWithProviders
  :: SynthEngine -> Int -> [ProviderFrag] -> Frag
  -> Either String SynthOutcome
synthesizeWithProviders engine steps providers frag =
  synthesizeWithProvidersSkipping engine steps Set.empty providers frag

-- | 'synthesizeWithProviders' while omitting exact rendered spellings already
-- checked by an earlier REPL lane.  Filtering happens on each engine's own
-- ranked stream before a combined merge, so Djinn and Exference each retain
-- their full fresh-group quota.
synthesizeWithProvidersSkipping
  :: SynthEngine -> Int -> Set.Set String -> [ProviderFrag] -> Frag
  -> Either String SynthOutcome
synthesizeWithProvidersSkipping engine steps checked providers frag =
  fmap projectDetailedSynthOutcome $
    synthesizeWithProvidersSkippingDetailed
      engine steps checked providers frag

-- | Route-preserving counterpart used by the REPL until its bounded
-- verification frontier has recorded rendering observations.
synthesizeWithProvidersSkippingDetailed
  :: SynthEngine -> Int -> Set.Set String -> [ProviderFrag] -> Frag
  -> Either String DetailedSynthOutcome
synthesizeWithProvidersSkippingDetailed engine steps checked providers frag =
  synthesizeTunedWithProvidersDetailed engine steps
    (candidateWindow, Nothing) checked providers [] frag frag

-- | 'synthesize' with caller-supplied premises (name, fragment) - used
-- by the classical fallback to hand the engine excluded-middle
-- assumptions spelled @Classical.em _@ - and a separate fitting
-- fragment: the engine searches @engineFrag@ (with all premises
-- prepended as antecedents), while candidates are fitted and verified
-- against @fitFrag@.  The two differ when @engineFrag@ carries the
-- fitting goal's bound variables as free opaque variables instead.
synthesizeWith
  :: SynthEngine -> Int -> [(String, Frag)] -> Frag -> Frag
  -> Either String SynthOutcome
synthesizeWith engine steps =
  synthesizeTuned engine steps (candidateWindow, Nothing)

-- | 'synthesizeWith' with explicit Djinn limits: the candidate cutoff
-- and an optional choice-point budget.  A budget forfeits completeness
-- (and with it refutation soundness), which is why only searches whose
-- negative verdicts are discarded anyway - the classical fallback's -
-- should pass one; it is what keeps a premise-heavy search's memory
-- bounded.
synthesizeTuned
  :: SynthEngine -> Int -> (Int, Maybe Integer) -> [(String, Frag)]
  -> Frag -> Frag -> Either String SynthOutcome
synthesizeTuned engine steps limits extras engineFrag fitFrag =
  fmap projectDetailedSynthOutcome $
    synthesizeTunedDetailed engine steps limits extras engineFrag fitFrag

-- | Route-preserving tuned search for the REPL's library and classical lanes.
synthesizeTunedDetailed
  :: SynthEngine -> Int -> (Int, Maybe Integer) -> [(String, Frag)]
  -> Frag -> Frag -> Either String DetailedSynthOutcome
synthesizeTunedDetailed engine steps limits extras engineFrag fitFrag =
  synthesizeTunedWithProvidersDetailed engine steps limits Set.empty [] extras
    engineFrag fitFrag

synthesizeTunedWithProvidersDetailed
  :: SynthEngine -> Int -> (Int, Maybe Integer) -> Set.Set String
  -> [ProviderFrag] -> [(String, Frag)] -> Frag -> Frag
  -> Either String DetailedSynthOutcome
synthesizeTunedWithProvidersDetailed engine steps limits checked providers extras
    engineFrag fitFrag = case engine of
  EngineDjinn -> do
    prepared <- prepareSynthesis djinnRecursiveProjection
      providers extras engineFrag fitFrag
    outcome <- djinnRun limits fitFrag
      (preparedProjectionCompleteness prepared)
      (preparedRenderExpression prepared)
      (preparedSearchGoal prepared)
      (preparedDeclarations prepared)
      (preparedProviderAssignments prepared)
    pure
      (withoutCheckedDetailedCandidates checked
        (detailUnobservedOutcome outcome))
  EngineExference -> do
    prepared <- prepareSynthesis exferenceRecursiveProjection
      providers extras engineFrag fitFrag
    outcome <- exferenceRun steps prepared
    pure (withoutCheckedDetailedCandidates checked outcome)
  EngineBoth -> do
    djinnPrepared <- prepareSynthesis djinnRecursiveProjection
      providers extras engineFrag fitFrag
    djinnCompatibility <- djinnRun limits fitFrag
      (preparedProjectionCompleteness djinnPrepared)
      (preparedRenderExpression djinnPrepared)
      (preparedSearchGoal djinnPrepared)
      (preparedDeclarations djinnPrepared)
      (preparedProviderAssignments djinnPrepared)
    let djinn = detailUnobservedOutcome djinnCompatibility
    exferencePrepared <- prepareSynthesis exferenceRecursiveProjection
      providers extras engineFrag fitFrag
    exference <- exferenceRun steps exferencePrepared
    pure (mergeDetailedOutcomesSkipping checked djinn exference)

-- | Prepare one engine-specific translation without erasing which goal came
-- from the source fragment and which goal search actually receives. Premise
-- insertion and rendering share the same named layout, while provider and
-- type maps remain attached to the declarations that introduced their private
-- names. This is the stable seam for later semantic interpretation.
prepareSynthesis
  :: RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Frag
  -> Either String PreparedSynthesis
prepareSynthesis recursiveProjection activeProviders extras engineFrag fitFrag = do
  translation <-
    fragToDjinn recursiveProjection activeProviders extras engineFrag
  let sourceGoal = translationSourceGoal translation
      callerPremises = translationCallerPremises translation
      constructorPremises = translationConstructorPremises translation
      premiseLayout = PremiseLayout
        { premiseLayoutConstructorPremises = constructorPremises
        , premiseLayoutSourceArrowCount =
            length [() | SlotArrow _ <- fragSpine engineFrag]
        , premiseLayoutCallerPremises = callerPremises
        }
      -- Premises enter under the quantifier prefix, where their occurrences of
      -- the goal's bound variables remain connected. The two premise kinds sit
      -- on opposite sides of the goal's own arrows. Caller-supplied premises
      -- go innermost; conservative constructor premises remain outside.
      antecedents premises body =
        foldr (FunctionType . translatedPremiseType) body premises
      insertInner ty = case ty of
        FunctionType domain body -> FunctionType domain (insertInner body)
        body -> antecedents callerPremises body
      insertOuter ty = case ty of
        ForallType variables constraints body ->
          ForallType variables constraints (insertOuter body)
        body -> antecedents constructorPremises (insertInner body)
      searchGoal = insertOuter sourceGoal
      renderPremiseLayout = premiseLayoutForRenderer premiseLayout
      render expr =
        renderLeanTerm
          (translationConstructorMap translation)
          (translationProviderMap translation)
          (translationTypeMap translation)
          renderPremiseLayout fitFrag expr
      renderGraph
        :: TermGraph ExferenceType ExferenceLocal
        -> Either String [String]
      renderGraph graph =
        renderLeanTermGraphProjection (("x" ++) . show)
          (translationConstructorMap translation)
          (translationProviderMap translation)
          (translationTypeMap translation)
          renderPremiseLayout fitFrag graph
  pure PreparedSynthesis
    { preparedEngineFragment = engineFrag
    , preparedFitFragment = fitFrag
    , preparedSourceGoal = sourceGoal
    , preparedSearchGoal = searchGoal
    , preparedDeclarations =
        translationDeclarations translation
          ++ translationProviderDeclarations translation
    , preparedProviderBindings = translationProviderBindings translation
    , preparedSemanticFamilyBindings =
        translationSemanticFamilyBindings translation
    , preparedProviderAssignments =
        translationProviderAssignments translation
    , preparedConstructorMap = translationConstructorMap translation
    , preparedProviderMap = translationProviderMap translation
    , preparedTypeMap = translationTypeMap translation
    , preparedPremiseLayout = premiseLayout
    , preparedProjectionCompleteness =
        translationProjectionCompleteness translation
    , preparedRenderExpression = render
    , preparedRenderTermGraph = renderGraph
    }

-- | The complete LJT search: candidates, or a refutation whose
-- soundness depends on the translation having hidden nothing.
djinnRun
  :: (Int, Maybe Integer)
  -> Frag
  -> ProjectionCompleteness
  -> (Expression String -> Either String [String])
  -> Type String
  -> [DjinnDecl]
  -> [KindedProviderInstantiationAssignment String]
  -> Either String SynthOutcome
djinnRun (cutoff, budget) frag projection render goal decls instantiations = do
  standard <- viaDiagnostic standardDjinnSession
  targetName <- viaShow (mkIdentifier "leantSynth")
  target <- viaShow (mkDefinitionName targetName)
  session <-
    if null decls
      then Right standard
      else do
        environment <- viaShow $ mkEnvironment
          (environmentDeclarations (djinnSessionEnvironment standard)
           ++ decls)
        viaDiagnostic (mkDjinnSession environment)
  let query = QueryRequest
        { requestTarget = target
        , requestGoal = goal
        , requestContexts = []
        , requestOptions = defaultQueryOptions
            { optionAlternatives = True
            , optionCutoff = cutoff
            , optionBudget = budget
            }
        }
  request <- viaDiagnostic (mkDjinnRequest query)
  result <- viaDiagnostic
    (runDjinnQueryWithKindedInstantiationAssignments
      session instantiations request)
  let batch = resultSearch result
      notes = progressNotes (batchProgress batch)
      -- Djinn ranks by unused-binder fraction, which happily puts a
      -- redundantly re-cased monster ahead of the obvious term.  Prefer
      -- smaller terms, keeping the engine's order as the tie-break, over
      -- a bounded prefix (the batch is terminal but can be long).
      rendered =
        [ (expressionSize expr, group)
        | candidate <- take cutoff (batchCandidates batch)
        , let expr = functionClauseExpression (candidateOutput candidate)
        , Right group <- [render expr]
        ]
      terms = map snd (sortOn fst rendered)
  pure $ case resultEvidence result of
    ValidatedCandidates -> SynthCandidates terms notes
    ProvedUninhabitable
      | not (projectionFamiliesComplete projection) -> SynthNoTerm
          ("an exact Lean family stayed opaque because its constructor schema \
           \was ambiguous or incompatible" : notes)
      | otherwise ->
          SynthRefuted
            ( budget == Nothing
              && projectionFragmentsComplete projection
              && fragmentProjectionComplete frag
            )
    RequiresTargetReference -> SynthNoTerm
      ("only a recursive reference to the definition itself would inhabit \
       \this type" : notes)
    NoEvidence -> SynthNoTerm notes

-- | The ranked heuristic search: the same shared environment and goal,
-- converted to Exference's integer variable domain.  Candidates keep
-- Exference's own ranking; there is never negative evidence.
exferenceRun
  :: Int
  -> PreparedSynthesis
  -> Either String DetailedSynthOutcome
exferenceRun steps prepared = do
  standard <- viaDiagnostic standardDjinnSession
  let render = preparedRenderExpression prepared
      renderGraph = preparedRenderTermGraph prepared
      goal = preparedSearchGoal prepared
      decls = preparedDeclarations prepared
      instantiations = preparedProviderAssignments prepared
      allDecls =
        environmentDeclarations (djinnSessionEnvironment standard)
          ++ decls
      names = nub
        ( concatMap declarationTypeVariables allDecls
          ++ toList goal
          ++ concatMap
            (concatMap (toList . snd)
              . kindedProviderInstantiationAssignmentArguments)
            instantiations
        )
      table = Map.fromList (zip names [0 :: Int ..])
      convert v = FlexibleVariable (table Map.! v)
  let convertedDecls = map (mapDeclarationTypeVariables convert) allDecls
      convertedInstantiations =
        [ KindedProviderInstantiationAssignment
            { kindedProviderInstantiationAssignmentProvider = provider
            , kindedProviderInstantiationAssignmentArguments =
                [ (kind, fmap convert argument)
                | (kind, argument) <- arguments
                ]
            }
        | KindedProviderInstantiationAssignment
            { kindedProviderInstantiationAssignmentProvider = provider
            , kindedProviderInstantiationAssignmentArguments = arguments
            } <- instantiations
        ]
      providerNames =
        [ valueName signature
        | ValueDeclaration signature <- convertedDecls
        , Just spelling <- [nameSpelling (valueName signature)]
        , "leantProvider" `isPrefixOf` spelling
        ]
      -- A foreign inventory is intentionally ordered by Lean-side relevance.
      -- Increasing penalties retain more fallback providers without allowing
      -- them to drown the first exact/short provider in combinatorial terms.
      providerRatings = Map.fromList
        (zip providerNames
          [Penalty (fromIntegral rank * 20) | rank <- [0 :: Int ..]])
      policy = defaultExferenceSessionPolicy
        { exferenceRatingOverrides = providerRatings }
      convertedSourceGoal = fmap convert $ preparedSourceGoal prepared
      semanticOrigin = preparedSemanticOrigin prepared
  environment <- viaShow (mkEnvironment convertedDecls)
  session <- viaDiagnostic
    (mkExferenceSessionWithPolicy policy environment)
  targetName <- viaShow (mkIdentifier "leantSynth")
  target <- viaShow (mkDefinitionName targetName)
  let runLane allowUnused = do
        let query = QueryRequest
              { requestTarget = target
              , requestGoal = fmap convert goal
              , requestContexts = []
              , requestOptions = defaultExferenceOptions
                  { exferenceAllowUnused = allowUnused
                  , exferenceMaximumSteps = steps
                  , exferenceMultiConstructorPatterns = True
                    -- the queue is the memory hog; a modest bound keeps the
                    -- search interactive on small machines, reported honestly
                    -- as pruning
                  , exferenceMaximumQueueSize = Just 1024
                  }
              }
        request <- viaDiagnostic (mkExferenceRequest query)
        let authority = ExferenceRunAuthority
              { exferenceAuthorityPreparation = semanticOrigin
              , exferenceAuthorityNameTable = table
              , exferenceAuthorityConvertedSourceGoal = convertedSourceGoal
              , exferenceAuthorityPolicy = policy
              , exferenceAuthoritySession = session
              , exferenceAuthorityRequest = request
              , exferenceAuthorityProviderAssignments =
                  convertedInstantiations
              }
        results <- viaDiagnostic
          (runExferenceTypedQueryWithKindedInstantiationAssignments session
            convertedInstantiations request)
        let selection =
              selectQueryResults SelectAll (const (0 :: Int))
                (const True) results
            -- Deduplicate before applying the public result window. Backend
            -- search histories may converge on the same rendered term, and
            -- repetitions must not crowd later distinct candidates out of a
            -- bounded interactive response.
            groups = takeDistinctOn detailedCandidateGroupVariants
              candidateWindow
              [ DetailedCandidateGroup route
                  (indexDetailedCandidateVariants group) sidecar
              | candidate <- selectionCandidates selection
              , let availability = typedCandidateTermGraph candidate
                    compatibility = typedCandidateCompatibility candidate
                    fallback = fmap (("x" ++) . show)
                      . functionClauseExpression . candidateOutput
                    (route, rendered) = renderCandidateByAvailability
                      renderGraph render availability compatibility fallback
                    sidecar = case availability of
                      Right _ -> Just $ TypedCandidateSemanticSidecar
                        candidate authority
                      Left _ -> Nothing
              , Right group <- [rendered]
              ]
            notes = maybe [] progressNotes (selectionProgress selection)
        pure (groups, notes)
  (strictGroups, strictNotes) <- runLane False
  if not (null strictGroups)
    then pure $ DetailedSynthCandidates strictGroups strictNotes
    else do
      -- Exference normally prefers terms which use every introduced binder.
      -- Lean accepts intentional omission, however, and recursive projection
      -- often needs it: after matching @Headed a@, the recursive tail must stay
      -- unopened while the @a@ field is returned.  Retry only after the strict
      -- lane has produced no term, preserving its established candidate order
      -- and provider preference for every existing successful query.
      (relaxedGroups, relaxedNotes) <- runLane True
      pure $ if null relaxedGroups
        then DetailedSynthNoTerm (nub $ strictNotes ++ relaxedNotes)
        else DetailedSynthCandidates relaxedGroups relaxedNotes

-- | Merge two ranked group streams without letting either engine's bounded
-- tail suppress a candidate from the other.  Djinn owns the first four fresh
-- groups (its small-term order is the primary ranking), Exference then gets
-- its full twelve-group lane budget, and Djinn fills the remaining eight
-- groups of its own budget.  Thus the first 24 fresh groups contain everything
-- either engine could have sent through a standalone twelve-group frontier,
-- while Exference's first distinct group remains fifth.  Tails alternate
-- after that combined frontier.
--
-- A group is one ranked candidate with textual Lean variants.  Exact
-- spellings are retained at their first scheduled occurrence, variants keep
-- their order, and a group emptied by stable deduplication does not spend a
-- scheduling turn.  In particular, an early Exference spelling beats an
-- otherwise identical /later/ Djinn spelling.
mergeCandidateGroups :: [[String]] -> [[String]] -> [[String]]
mergeCandidateGroups left right =
  map detailedCandidateGroupVariants $
    mergeDetailedCandidateGroups
      (map (detailedCandidateGroup RouteUnobserved) left)
      (map (detailedCandidateGroup RouteUnobserved) right)

-- | Route-preserving form of 'mergeCandidateGroups'.  Dedupe looks only at
-- rendered spellings and keeps the route of the first group with a surviving
-- spelling.  When that first group is compatibility-only, an exact duplicate
-- from the Exference lane remains attached solely as that spelling's typed
-- assessment origin.  This neither transfers the sidecar to the Djinn group
-- nor gives any distinct spelling the later candidate's authority.
mergeDetailedCandidateGroups
  :: [DetailedCandidateGroup]
  -> [DetailedCandidateGroup]
  -> [DetailedCandidateGroup]
mergeDetailedCandidateGroups djinnGroups exferenceGroups =
  djinnHead (synthMaxShown - 1) Set.empty
    (map (retainExactExferenceVariantOrigins exferenceGroups) djinnGroups)
    exferenceGroups
 where
  djinnHead remaining seen djinn exference
    | remaining <= 0 =
        exferenceFront synthMaxTried seen djinn exference
    | otherwise = case nextFresh seen djinn of
        Just (group, seen', djinn') ->
          group : djinnHead (remaining - 1) seen' djinn' exference
        Nothing -> drain seen exference

  exferenceFront remaining seen djinn exference
    | remaining <= 0 = djinnFront
        (synthMaxTried - (synthMaxShown - 1)) seen djinn exference
    | otherwise = case nextFresh seen exference of
        Just (group, seen', exference') ->
          group : exferenceFront (remaining - 1) seen' djinn exference'
        Nothing -> drain seen djinn

  djinnFront remaining seen djinn exference
    | remaining <= 0 = alternateExference seen djinn exference
    | otherwise = case nextFresh seen djinn of
        Just (group, seen', djinn') ->
          group : djinnFront (remaining - 1) seen' djinn' exference
        Nothing -> drain seen exference

  alternateExference seen djinn exference =
    case nextFresh seen exference of
      Just (group, seen', exference') ->
        group : alternateDjinn seen' djinn exference'
      Nothing -> drain seen djinn

  alternateDjinn seen djinn exference = case nextFresh seen djinn of
    Just (group, seen', djinn') ->
      group : alternateExference seen' djinn' exference
    Nothing -> drain seen exference

  drain seen groups = case nextFresh seen groups of
    Just (group, seen', groups') -> group : drain seen' groups'
    Nothing -> []

  nextFresh _ [] = Nothing
  nextFresh seen (group : groups) =
    let (fresh, seen') =
          retainFresh seen (detailedCandidateGroupVariantRecords group)
    in if null fresh
      then nextFresh seen' groups
      else Just
        ( retainDetailedCandidateGroupVariants fresh group
        , seen'
        , groups
        )

  retainFresh seen = go seen
   where
    go retained [] = ([], retained)
    go retained (variant : variants)
      | spelling `Set.member` retained = go retained variants
      | otherwise =
          let (fresh, retained') =
                go (Set.insert spelling retained) variants
          in (variant : fresh, retained')
     where
      spelling = detailedCandidateVariantText variant

-- | Retain a later Exference origin only on the byte-for-byte identical
-- spelling of an earlier compatibility group.  The lookup is deliberately
-- stored as a lazy variant field: ordinary display projection and bounded
-- scheduling do not force the other engine's tail.  Recovery itself is capped
-- at the production Exference lane's established 'candidateWindow'; a wider
-- synthetic stream therefore fails closed instead of widening work.
retainExactExferenceVariantOrigins
  :: [DetailedCandidateGroup]
  -> DetailedCandidateGroup
  -> DetailedCandidateGroup
retainExactExferenceVariantOrigins exference group
  | detailedCandidateGroupRoute group == RouteTypedCandidate = group
  | Just _ <- detailedCandidateGroupSemanticSidecar group = group
  | otherwise = DetailedCandidateGroup
      (detailedCandidateGroupRoute group)
      (map retainOrigin $ detailedCandidateGroupVariantRecords group)
      Nothing
 where
  retainOrigin variant = DetailedCandidateVariant
    (detailedCandidateVariantOrdinal variant)
    (detailedCandidateVariantText variant)
    (case detailedCandidateVariantExactTypedOrigin variant of
      Just retained -> Just retained
      Nothing -> findExactTypedVariantOrigin
        (detailedCandidateVariantText variant) exference)

findExactTypedVariantOrigin
  :: String
  -> [DetailedCandidateGroup]
  -> Maybe ExactTypedVariantOrigin
findExactTypedVariantOrigin spelling = go candidateWindow
 where
  go remaining _ | remaining <= 0 = Nothing
  go _ [] = Nothing
  go remaining (group : groups)
    | detailedCandidateGroupRoute group /= RouteTypedCandidate =
        go (remaining - 1) groups
    | otherwise = case detailedCandidateGroupSemanticSidecar group of
        Nothing -> go (remaining - 1) groups
        Just sidecar -> case matchingVariant
            (detailedCandidateGroupVariantRecords group) of
          Nothing -> go (remaining - 1) groups
          Just variant -> Just $ ExactTypedVariantOrigin
            (detailedCandidateVariantOrdinal variant)
            spelling
            sidecar

  matchingVariant [] = Nothing
  matchingVariant (variant : variants)
    | detailedCandidateVariantText variant == spelling = Just variant
    | otherwise = matchingVariant variants

-- | Both engines on one goal: merge their real candidates through the fair
-- frontier above, and return negative evidence only when neither engine
-- produced a candidate.  A refutation remains Djinn's alone; Exference
-- completion without candidates is not negative evidence.
mergeOutcomes :: SynthOutcome -> SynthOutcome -> SynthOutcome
mergeOutcomes = mergeOutcomesSkipping Set.empty

-- | 'mergeOutcomes' after removing already-checked spellings from each source
-- stream independently.  Source-local filtering is essential: removing them
-- from an already scheduled combined stream could spend one engine's reserved
-- quota on empty groups from the other.
mergeOutcomesSkipping
  :: Set.Set String -> SynthOutcome -> SynthOutcome -> SynthOutcome
mergeOutcomesSkipping checked djinn exference =
  projectDetailedSynthOutcome $
    mergeDetailedOutcomesSkipping checked
      (detailUnobservedOutcome djinn)
      (detailUnobservedOutcome exference)

-- | Remove spellings already sent to Lean by an earlier structural/provider
-- lane.  Empty groups do not consume the next lane's verification budget, and
-- the transformation stays lazy so 'forceOutcome' can pull the first bounded
-- /fresh/ prefix while it is still under the command deadline.
withoutCheckedCandidates :: Set.Set String -> SynthOutcome -> SynthOutcome
withoutCheckedCandidates checked =
  projectDetailedSynthOutcome
    . withoutCheckedDetailedCandidates checked
    . detailUnobservedOutcome

-- | Attach no rendering observation to today's Djinn compatibility stream.
-- The mapping is lazy in the candidate tail and does not alter its ordering.
detailUnobservedOutcome :: SynthOutcome -> DetailedSynthOutcome
detailUnobservedOutcome outcome = case outcome of
  SynthCandidates groups notes -> DetailedSynthCandidates
    (map (detailedCandidateGroup RouteUnobserved) groups) notes
  SynthRefuted sound -> DetailedSynthRefuted sound
  SynthNoTerm notes -> DetailedSynthNoTerm notes

-- | Route-preserving combined-engine merge.  As in the compatibility merge,
-- filtering happens in each source before scheduling so an emptied group does
-- not consume the other engine's reserved frontier.
mergeDetailedOutcomesSkipping
  :: Set.Set String
  -> DetailedSynthOutcome
  -> DetailedSynthOutcome
  -> DetailedSynthOutcome
mergeDetailedOutcomesSkipping checked djinn0 exference0 =
  case (djinn, exference) of
    (DetailedSynthCandidates a na, DetailedSynthCandidates b nb) ->
      DetailedSynthCandidates
        (mergeDetailedCandidateGroups a b) (na ++ tag nb)
    (DetailedSynthCandidates a na, other) ->
      DetailedSynthCandidates a (na ++ tag (notesOf other))
    (other, DetailedSynthCandidates b nb) ->
      DetailedSynthCandidates b (notesOf other ++ tag nb)
    (DetailedSynthRefuted sound, _) -> DetailedSynthRefuted sound
    (DetailedSynthNoTerm na, other) ->
      DetailedSynthNoTerm (na ++ tag (notesOf other))
 where
  djinn = normalize (withoutCheckedDetailedCandidates checked djinn0)
  exference = normalize
    (withoutCheckedDetailedCandidates checked exference0)

  tag = map ("exference: " ++)

  candidatesOr fallback groups notes
    | null groups = fallback
    | otherwise = DetailedSynthCandidates groups notes

  normalize outcome = case outcome of
    DetailedSynthCandidates groups notes ->
      candidatesOr (DetailedSynthNoTerm notes)
        (mergeDetailedCandidateGroups groups []) notes
    other -> other

  notesOf outcome = case outcome of
    DetailedSynthCandidates _ notes -> notes
    DetailedSynthNoTerm notes -> notes
    DetailedSynthRefuted _ -> []

-- | Filter exact previously checked spellings while retaining the route of a
-- semantic group with at least one surviving textual variant.
withoutCheckedDetailedCandidates
  :: Set.Set String
  -> DetailedSynthOutcome
  -> DetailedSynthOutcome
withoutCheckedDetailedCandidates checked outcome = case outcome of
  DetailedSynthCandidates groups notes -> case freshGroups groups of
    [] -> DetailedSynthNoTerm notes
    fresh -> DetailedSynthCandidates fresh notes
  other -> other
 where
  freshGroups = filter (not . null . detailedCandidateGroupVariants)
    . map retainFresh
  retainFresh group = retainDetailedCandidateGroupVariants
    (filter
      ((`Set.notMember` checked) . detailedCandidateVariantText)
      (detailedCandidateGroupVariantRecords group))
    group

viaDiagnostic :: Either Diagnostic a -> Either String a
viaDiagnostic = either (Left . renderDiagnostic) Right

viaShow :: Show e => Either e a -> Either String a
viaShow = either (Left . show) Right

progressNotes :: Progress -> [String]
progressNotes progress = case progress of
  Completed Finished -> []
  Completed (Truncated reasons) ->
    [ "search truncated: "
      ++ intercalate ", " (map reasonText (nub (toList reasons))) ]
  Continuing -> ["search reported more batches to come"]
 where
  reasonText reason = case reason of
    StepLimitReached -> "step limit reached"
    ChoicePointLimitReached -> "choice-point limit reached"
    CandidateLimitReached ->
      "candidate limit reached (" ++ show candidateWindow ++ ")"
    IdentifierSpaceExhausted -> "identifier space exhausted"
    QueueLimitPruned n -> "queue limit pruned " ++ show n
    DepthLimitPruned n -> "depth limit pruned " ++ show n

-- Fragment -> Djinn type ----------------------------------------------------
--
-- Opaque variables and ordinary atoms become Djinn type variables; atoms are
-- keyed by their pretty-printed spelling so alpha-equal occurrences share
-- one variable (transportable, never analyzed).  A fixed opaque constructor
-- field in a shared data schema instead receives one private rigid proper
-- type, because it is not a parameter of the Lean family.  Nested quantifiers
-- are passed structurally as 'ForallType'; Djex carries them as alpha-aware
-- atoms and applies its bounded rank-N rules.  Retained first-order type-kind
-- applications become real 'TypeApplication' nodes: bound heads remain
-- higher-kinded variables, while exact Lean constant heads receive shared
-- private abstract declarations and a renderer map back to Lean.  Expanded
-- exact-head inductive families become shared parameterized @data@
-- declarations after query-wide schema validation.  Occurrence-local legacy
-- inductives still become fresh declarations per display key.  Declarations
-- are collected in dependency order (fields are translated before the
-- declaration that contains them).

-- | The neutral declaration shape sealed into a 'DjinnSession' (the
-- @Environment String Void ()@ element type of 'DjinnEnvironment').
type DjinnDecl = Declaration String Void ()

-- | One source premise after translation into the exact query type
-- vocabulary. Keeping all three views named prevents later goal preparation
-- from swapping a Lean spelling, fitting fragment, or engine type.
data TranslatedPremise = TranslatedPremise
  { translatedPremiseName :: String
  , translatedPremiseFragment :: Frag
  , translatedPremiseType :: Type String
  }
  deriving (Eq, Show)

-- | One usable Lean provider bound to its collision-free engine identity.
--
-- The source fragment remains attached to the exact private 'Name', translated
-- scheme, renderer metadata, and provider-local instantiation assignments.
-- No behavioral law is inferred here; this record is only the source identity
-- seam a later checked semantic layer can consume.
data ProviderBinding = ProviderBinding
  { providerBindingSource :: ProviderFrag
  , providerBindingPrivateName :: Name
  , providerBindingPrivateSpelling :: String
  , providerBindingScheme :: Type String
  , providerBindingRenderInfo :: ProviderInfo
  , providerBindingAssignments ::
      [KindedProviderInstantiationAssignment String]
  }
  deriving (Eq, Show)

-- | Exact source identity for one structurally declared Lean family.
--
-- Both the type and constructor identities come from the declarations and
-- exact renderer maps emitted by this translation. No private spelling is
-- interpreted as a Lean name. If any part of that association is absent or
-- inconsistent, the family has no binding.
data SemanticFamilyBinding = SemanticFamilyBinding
  { semanticFamilyLeanName :: String
  , semanticFamilyPrivateTypeName :: Name
  , semanticFamilyConstructors :: Map.Map String Name
  }
  deriving (Eq, Show)

semanticFamilyBindings
  :: [DjinnDecl]
  -> CtorMap
  -> TypeMap
  -> [SemanticFamilyBinding]
semanticFamilyBindings declarations constructorMap typeMap =
  [ binding
  | binding <- candidates
  , Map.lookup (semanticFamilyLeanName binding) familyCounts == Just 1
  ]
 where
  candidates =
    [ binding
    | declaration <- declarations
    , Just binding <-
        [semanticFamilyBinding declaration constructorMap typeMap]
    ]
  -- Count every data declaration with an exact type-map association, even if
  -- its constructor association is incomplete.  One valid declaration cannot
  -- thereby hide an ambiguous sibling which failed later validation.
  familyCounts = Map.fromListWith (+)
    [ (leanFamilyName, 1 :: Int)
    | DataTypeDeclaration _ privateTypeName _ _ <- declarations
    , Just privateTypeSpelling <- [nameSpelling privateTypeName]
    , Just leanFamilyName <- [Map.lookup privateTypeSpelling typeMap]
    ]

semanticFamilyBinding
  :: DjinnDecl
  -> CtorMap
  -> TypeMap
  -> Maybe SemanticFamilyBinding
semanticFamilyBinding declaration constructorMap typeMap = case declaration of
  DataTypeDeclaration _ privateTypeName parameters declaredConstructors -> do
    privateTypeSpelling <- nameSpelling privateTypeName
    leanFamilyName <- Map.lookup privateTypeSpelling typeMap
    constructorBindings <- mapM
      (exactConstructorBinding leanFamilyName $ length parameters)
      declaredConstructors
    let constructors = Map.fromList constructorBindings
    if Map.size constructors /= length constructorBindings
      then Nothing
      else Just SemanticFamilyBinding
        { semanticFamilyLeanName = leanFamilyName
        , semanticFamilyPrivateTypeName = privateTypeName
        , semanticFamilyConstructors = constructors
        }
  _ -> Nothing
 where
  exactConstructorBinding leanFamilyName parameterCount constructor = do
    privateConstructorSpelling <- nameSpelling $ constructorName constructor
    constructorInfo <- Map.lookup privateConstructorSpelling constructorMap
    case ciParametric constructorInfo of
      Just (constructorFamilyName, formals)
        | constructorFamilyName == leanFamilyName
        , length formals == parameterCount ->
            Just (ciLean constructorInfo, constructorName constructor)
      _ -> Nothing

providerBindingDeclaration :: ProviderBinding -> DjinnDecl
providerBindingDeclaration binding = ValueDeclaration
  (ValueSignature ()
    (providerBindingPrivateName binding)
    (providerBindingScheme binding))

-- | Complete pure output of fragment translation, before search-only premises
-- are inserted around the source goal. Provider bindings are retained beside
-- their historical declaration, assignment, and renderer-map projections so
-- future consumers do not have to recover source identity from a private
-- spelling.
data SynthesisTranslation = SynthesisTranslation
  { translationSourceGoal :: Type String
  , translationDeclarations :: [DjinnDecl]
  , translationProviderDeclarations :: [DjinnDecl]
  , translationProviderBindings :: [ProviderBinding]
  , translationSemanticFamilyBindings :: [SemanticFamilyBinding]
  , translationProviderAssignments ::
      [KindedProviderInstantiationAssignment String]
  , translationConstructorMap :: CtorMap
  , translationProviderMap :: ProviderMap
  , translationTypeMap :: TypeMap
  , translationCallerPremises :: [TranslatedPremise]
  , translationConstructorPremises :: [TranslatedPremise]
  , translationProjectionCompleteness :: ProjectionCompleteness
  }

-- | Values produced inside the translation state before its declaration and
-- renderer indexes are projected into 'SynthesisTranslation'.
data TranslationProduct = TranslationProduct
  { translationProductCallerPremises :: [TranslatedPremise]
  , translationProductSourceGoal :: Type String
  , translationProductProviderBindings :: [ProviderBinding]
  }

-- | Exact premise ordering shared by search-goal construction and rendering.
-- Constructor fallbacks surround the source arrows; caller premises are
-- inserted at the innermost arrow result.
data PremiseLayout = PremiseLayout
  { premiseLayoutConstructorPremises :: [TranslatedPremise]
  , premiseLayoutSourceArrowCount :: Int
  , premiseLayoutCallerPremises :: [TranslatedPremise]
  }
  deriving (Eq, Show)

premiseLayoutForRenderer
  :: PremiseLayout
  -> ([(String, Frag)], Int, [(String, Frag)])
premiseLayoutForRenderer layout =
  ( map premisePair $ premiseLayoutConstructorPremises layout
  , premiseLayoutSourceArrowCount layout
  , map premisePair $ premiseLayoutCallerPremises layout
  )
 where
  premisePair premise =
    (translatedPremiseName premise, translatedPremiseFragment premise)

-- | One prepared lane. The source and premise-extended search goals remain
-- separate, and every declaration/map/premise projection used by either
-- backend is retained under a named field instead of tuple position.
data PreparedSynthesis = PreparedSynthesis
  { preparedEngineFragment :: Frag
  , preparedFitFragment :: Frag
  , preparedSourceGoal :: Type String
  , preparedSearchGoal :: Type String
  , preparedDeclarations :: [DjinnDecl]
  , preparedProviderBindings :: [ProviderBinding]
  , preparedSemanticFamilyBindings :: [SemanticFamilyBinding]
  , preparedProviderAssignments ::
      [KindedProviderInstantiationAssignment String]
  , preparedConstructorMap :: CtorMap
  , preparedProviderMap :: ProviderMap
  , preparedTypeMap :: TypeMap
  , preparedPremiseLayout :: PremiseLayout
  , preparedProjectionCompleteness :: ProjectionCompleteness
  , preparedRenderExpression ::
      Expression String -> Either String [String]
  , preparedRenderTermGraph ::
      TermGraph ExferenceType ExferenceLocal -> Either String [String]
  }

-- | Pure, comparable preparation authority retained after renderer functions
-- have served their output-only role. Both source fragments remain explicit:
-- equality of engine and fitting targets is a future semantic precondition,
-- never something reconstructed from their translated goals.
data PreparedSemanticOrigin = PreparedSemanticOrigin
  { semanticOriginEngineFragment :: Frag
  , semanticOriginFitFragment :: Frag
  , semanticOriginSourceGoal :: Type String
  , semanticOriginSearchGoal :: Type String
  , semanticOriginDeclarations :: [DjinnDecl]
  , semanticOriginProviderBindings :: [ProviderBinding]
  , semanticOriginSemanticFamilyBindings :: [SemanticFamilyBinding]
  , semanticOriginProviderAssignments ::
      [KindedProviderInstantiationAssignment String]
  , semanticOriginConstructorMap :: CtorMap
  , semanticOriginProviderMap :: ProviderMap
  , semanticOriginTypeMap :: TypeMap
  , semanticOriginPremiseLayout :: PremiseLayout
  , semanticOriginProjectionCompleteness :: ProjectionCompleteness
  }
  deriving (Eq, Show)

preparedSemanticOrigin :: PreparedSynthesis -> PreparedSemanticOrigin
preparedSemanticOrigin prepared = PreparedSemanticOrigin
  { semanticOriginEngineFragment = preparedEngineFragment prepared
  , semanticOriginFitFragment = preparedFitFragment prepared
  , semanticOriginSourceGoal = preparedSourceGoal prepared
  , semanticOriginSearchGoal = preparedSearchGoal prepared
  , semanticOriginDeclarations = preparedDeclarations prepared
  , semanticOriginProviderBindings = preparedProviderBindings prepared
  , semanticOriginSemanticFamilyBindings =
      preparedSemanticFamilyBindings prepared
  , semanticOriginProviderAssignments = preparedProviderAssignments prepared
  , semanticOriginConstructorMap = preparedConstructorMap prepared
  , semanticOriginProviderMap = preparedProviderMap prepared
  , semanticOriginTypeMap = preparedTypeMap prepared
  , semanticOriginPremiseLayout = preparedPremiseLayout prepared
  , semanticOriginProjectionCompleteness =
      preparedProjectionCompleteness prepared
  }

-- | Exact package-private provider-binding view consumed by the checked
-- Length handoff and focused boundary tests. It deliberately contains no
-- semantic summary or independent trust claim.
data ProviderBindingInspection = ProviderBindingInspection
  { inspectedProviderSourceName :: String
  , inspectedProviderPrivateName :: Name
  , inspectedProviderPrivateSpelling :: String
  , inspectedProviderScheme :: Type String
  , inspectedProviderAssignments ::
      [KindedProviderInstantiationAssignment String]
  }
  deriving (Eq, Show)

-- | Public comparable projection of one exact structural-family binding.
-- Constructor keys are exact Lean names and values are their private Djex
-- identities; neither side is reconstructed from the other.
data SemanticFamilyBindingInspection = SemanticFamilyBindingInspection
  { inspectedSemanticFamilyLeanName :: String
  , inspectedSemanticFamilyPrivateTypeName :: Name
  , inspectedSemanticFamilyConstructors :: Map.Map String Name
  }
  deriving (Eq, Show)

inspectSemanticFamilyBinding
  :: SemanticFamilyBinding
  -> SemanticFamilyBindingInspection
inspectSemanticFamilyBinding binding = SemanticFamilyBindingInspection
  { inspectedSemanticFamilyLeanName = semanticFamilyLeanName binding
  , inspectedSemanticFamilyPrivateTypeName =
      semanticFamilyPrivateTypeName binding
  , inspectedSemanticFamilyConstructors =
      semanticFamilyConstructors binding
  }

-- | Exact package-private view of the preparation fields consumed by the
-- checked Length handoff and inspected by focused boundary tests. The record
-- is descriptive rather than independent authority: the handoff derives it
-- only from the opaque exact-origin sidecar.
data PreparedSynthesisInspection = PreparedSynthesisInspection
  { inspectedEngineFragment :: Frag
  , inspectedFitFragment :: Frag
  , inspectedSourceGoal :: Type String
  , inspectedSearchGoal :: Type String
  , inspectedDeclarations :: [DjinnDecl]
  , inspectedProviderBindings :: [ProviderBindingInspection]
  , inspectedSemanticFamilyBindings :: [SemanticFamilyBindingInspection]
  , inspectedAllProviderAssignments ::
      [KindedProviderInstantiationAssignment String]
  , inspectedConstructorMap :: CtorMap
  , inspectedConstructorPrivateNames :: [String]
  , inspectedProviderMap :: ProviderMap
  , inspectedTypeMap :: TypeMap
  , inspectedConstructorPremises :: [TranslatedPremise]
  , inspectedSourceArrowCount :: Int
  , inspectedCallerPremises :: [TranslatedPremise]
  , inspectedFamiliesComplete :: Bool
  , inspectedFragmentsComplete :: Bool
  }
  deriving (Eq, Show)

-- | Exact package-private view of one Exference lane. The opaque session is
-- intentionally absent; its checked inventory is projected explicitly while
-- the session remains owned by the sidecar. The Length handoff derives this
-- record internally and never accepts one from a caller.
data ExferenceRunAuthorityInspection = ExferenceRunAuthorityInspection
  { inspectedAuthorityPreparation :: PreparedSynthesisInspection
  , inspectedAuthorityNameTable :: Map.Map String ExferenceLocal
  , inspectedAuthorityConvertedSourceGoal :: ExferenceType
  , inspectedAuthorityPolicy :: ExferenceSessionPolicy
  , inspectedAuthorityRequest ::
      QueryRequest ExferenceType ExferenceOptions
  , inspectedAuthorityProviderAssignments ::
      [KindedProviderInstantiationAssignment ExferenceTypeVariable]
  , inspectedAuthorityInventory :: ExferenceInventory
  }
  deriving (Eq, Show)

-- | Prepare the Exference projection and expose only the comparable boundary
-- view above. This keeps tests on the exact same record path used by synthesis.
inspectExferencePreparation
  :: [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Frag
  -> Either String PreparedSynthesisInspection
inspectExferencePreparation providers extras engineFrag fitFrag = do
  prepared <- prepareSynthesis exferenceRecursiveProjection
    providers extras engineFrag fitFrag
  pure $ inspectPreparedSemanticOrigin $ preparedSemanticOrigin prepared

inspectExferenceRunAuthority
  :: ExferenceRunAuthority
  -> ExferenceRunAuthorityInspection
inspectExferenceRunAuthority authority = ExferenceRunAuthorityInspection
  { inspectedAuthorityPreparation = inspectPreparedSemanticOrigin
      $ exferenceAuthorityPreparation authority
  , inspectedAuthorityNameTable = exferenceAuthorityNameTable authority
  , inspectedAuthorityConvertedSourceGoal =
      exferenceAuthorityConvertedSourceGoal authority
  , inspectedAuthorityPolicy = exferenceAuthorityPolicy authority
  , inspectedAuthorityRequest = exferenceRequestQuery
      $ exferenceAuthorityRequest authority
  , inspectedAuthorityProviderAssignments =
      exferenceAuthorityProviderAssignments authority
  , inspectedAuthorityInventory = exferenceSessionInventory
      $ exferenceAuthoritySession authority
  }

inspectPreparedSemanticOrigin
  :: PreparedSemanticOrigin
  -> PreparedSynthesisInspection
inspectPreparedSemanticOrigin origin = PreparedSynthesisInspection
  { inspectedEngineFragment = semanticOriginEngineFragment origin
  , inspectedFitFragment = semanticOriginFitFragment origin
  , inspectedSourceGoal = semanticOriginSourceGoal origin
  , inspectedSearchGoal = semanticOriginSearchGoal origin
  , inspectedDeclarations = semanticOriginDeclarations origin
  , inspectedProviderBindings = map inspectBinding
      $ semanticOriginProviderBindings origin
  , inspectedSemanticFamilyBindings = map inspectSemanticFamilyBinding
      $ semanticOriginSemanticFamilyBindings origin
  , inspectedAllProviderAssignments =
      semanticOriginProviderAssignments origin
  , inspectedConstructorMap = semanticOriginConstructorMap origin
  , inspectedConstructorPrivateNames = Map.keys
      $ semanticOriginConstructorMap origin
  , inspectedProviderMap = semanticOriginProviderMap origin
  , inspectedTypeMap = semanticOriginTypeMap origin
  , inspectedConstructorPremises = premiseLayoutConstructorPremises layout
  , inspectedSourceArrowCount = premiseLayoutSourceArrowCount layout
  , inspectedCallerPremises = premiseLayoutCallerPremises layout
  , inspectedFamiliesComplete = projectionFamiliesComplete projection
  , inspectedFragmentsComplete = projectionFragmentsComplete projection
  }
 where
  layout = semanticOriginPremiseLayout origin
  projection = semanticOriginProjectionCompleteness origin
  inspectBinding binding = ProviderBindingInspection
    { inspectedProviderSourceName = providerLeanName
        $ providerBindingSource binding
    , inspectedProviderPrivateName = providerBindingPrivateName binding
    , inspectedProviderPrivateSpelling =
        providerBindingPrivateSpelling binding
    , inspectedProviderScheme = providerBindingScheme binding
    , inspectedProviderAssignments = providerBindingAssignments binding
    }

data TransState = TransState
  { tsTable :: Map.Map String String
    -- ^ goal variable\/atom key -> engine type variable
  , tsNext :: Int
  , tsInds :: Map.Map String (Type String)
    -- ^ inductive display key -> its occurrence type
  , tsDecls :: [DjinnDecl]
    -- ^ new data declarations, dependency order
  , tsIndNext :: Int
  , tsCtorMap :: CtorMap
    -- ^ engine constructor spelling -> (Lean name, field fragments)
  , tsRecs :: Map.Map String ()
    -- ^ recursive-inductive keys whose constructor premises are
    -- already registered
  , tsRecFamilies :: Map.Map String RecInfo
    -- ^ nominal recursive datatype family -> private type constructor and
    -- inferred parameter arity (Exference's structural projection only)
  , tsPrems :: [TranslatedPremise]
    -- ^ constructor premises, retaining their Lean name, renderer fragment,
    -- and translated engine type together and in order
  , tsAppFamilies :: Map.Map String AppFamily
    -- ^ exact Lean family head -> its one query-wide private engine
    -- constructor, whether structurally declared or abstract
  , tsFamilyPlans :: Map.Map String ExactFamilyPlan
    -- ^ query-wide choice of one structural schema or one opaque fallback
    -- for every exact Lean head visible anywhere in the query
  , tsAppNext :: Int
  , tsRigidAtoms :: Set.Set String
    -- ^ opaque proper types used as fixed fields in a shared data schema;
    -- these must be rigid constructors, not undeclared datatype variables
  , tsAtomFamilies :: Map.Map String Name
  , tsAtomNext :: Int
  , tsContextClasses :: Map.Map String (Name, [Int])
    -- ^ exact Lean class head -> private checked class and parameter kinds
  , tsContextNext :: Int
  , tsTypeMap :: TypeMap
    -- ^ private engine type spelling -> exact Lean type or family head
  }

data RecInfo = RecInfo
  { recTypeName :: Name
  , recTypeArity :: Int
  }

data AppFamily = AppFamily
  { appTypeName :: Name
  , appTypeArity :: Int
  }

-- | One exact-head use found before translation starts.  The pre-scan is what
-- makes the representation independent of traversal order: a provider can
-- contribute the only unambiguous constructor template, while a nominal
-- fallback anywhere in the query conservatively makes the whole family
-- abstract.
data ExactFamilyUse
  = ParametricUse [Frag] [(String, [Frag])]
  | RecursiveUse Bool Bool String [Frag] [(String, [Frag])]
    -- ^ completeness, whether constructor premises are consumed, occurrence
    -- display key, parameters, and constructors
  | NominalUse Int
  | EvidenceUse Int
    -- ^ Exact higher-kinded assignment head and total arity. Unlike a
    -- saturated nominal occurrence, this does not hide a constructor schema.
  deriving (Eq, Show)

structuralHigherKindHeads :: [String]
structuralHigherKindHeads =
  ["And", "Prod", "PProd", "Or", "Sum", "PSum", "Iff", "Not"]

-- | Decompose a supported higher-kinded exact-context argument into its
-- canonical nominal head, total constructor arity, and already supplied
-- proper-type arguments.  The residual kind arity is metadata on the context
-- edge rather than part of the ordinary fragment, so every query-wide family
-- scan must use this view instead of treating the fragment as saturated.
exactContextNominalUse
  :: ExactContextArgument
  -> Maybe (String, Int, [Frag])
exactContextNominalUse source = case source of
  ExactContextNominalArgument remaining spelling supplied
    | remaining > 0
    , remaining <= maximumProviderArgumentKindArity
    , not (null spelling)
    , canonicalHeadSupported spelling (length supplied + remaining) ->
        Just (spelling, length supplied + remaining, supplied)
  ExactContextFragmentArgument remaining argument
    | remaining > 0
    , remaining <= maximumProviderArgumentKindArity -> case argument of
        FAtom _ spelling
          | legacyHeadSupported spelling ->
              Just (spelling, remaining, [])
        FApp _ _ (AppNominal spelling) supplied ->
          if legacyHeadSupported spelling
            then Just (spelling, length supplied + remaining, supplied)
            else Nothing
        _ -> Nothing
  _ -> Nothing
 where
  canonicalHeadSupported spelling totalArity
    | elem spelling ["Prod", "Sum"] = totalArity == 2
    | otherwise = not (elem spelling structuralHigherKindHeads)
  legacyHeadSupported spelling =
    not (null spelling)
      && not (elem spelling structuralHigherKindHeads)

-- | Fragments below a higher-kinded exact nominal head that remain ordinary
-- proper-type planning/rigidity roots.  The head itself is represented by an
-- 'EvidenceUse' and must never be closed as a proper rigid atom.
exactContextArgumentFragments :: ExactContextArgument -> [Frag]
exactContextArgumentFragments source =
  case exactContextNominalUse source of
    Just (_, _, supplied) -> supplied
    Nothing -> exactContextArgumentPayloadFragments source

-- | Exact family and class-kind identities claimed by one untrusted provider
-- assignment.  These claims are inspected before any fragment reaches the
-- query-wide family planner or translator, so a malformed assignment remains
-- local to its source instead of aborting an otherwise usable provider lane.
data ExactEvidenceClaims = ExactEvidenceClaims
  { claimedContextKinds :: Map.Map String (Set.Set [Int])
  , claimedFamilyArities :: Map.Map String (Set.Set Int)
  , claimsMalformed :: Bool
  }

emptyExactEvidenceClaims :: ExactEvidenceClaims
emptyExactEvidenceClaims = ExactEvidenceClaims Map.empty Map.empty False

mergeExactEvidenceClaims
  :: ExactEvidenceClaims
  -> ExactEvidenceClaims
  -> ExactEvidenceClaims
mergeExactEvidenceClaims left right = ExactEvidenceClaims
  { claimedContextKinds = Map.unionWith Set.union
      (claimedContextKinds left) (claimedContextKinds right)
  , claimedFamilyArities = Map.unionWith Set.union
      (claimedFamilyArities left) (claimedFamilyArities right)
  , claimsMalformed = claimsMalformed left || claimsMalformed right
  }

malformedExactEvidenceClaims :: ExactEvidenceClaims
malformedExactEvidenceClaims =
  emptyExactEvidenceClaims { claimsMalformed = True }

claimContextKinds :: String -> [Int] -> ExactEvidenceClaims
claimContextKinds spelling kinds
  | null spelling = malformedExactEvidenceClaims
  | otherwise = emptyExactEvidenceClaims
      { claimedContextKinds = Map.singleton spelling (Set.singleton kinds) }

claimFamilyArity :: String -> Int -> ExactEvidenceClaims
claimFamilyArity spelling arity
  | null spelling || arity < 0 = malformedExactEvidenceClaims
  | otherwise = emptyExactEvidenceClaims
      { claimedFamilyArities = Map.singleton spelling (Set.singleton arity) }

-- | Conservatively collect every exact identity stored in a fragment.  Live
-- serializer output is globally consistent; traversing constructor metadata as
-- well as the occurrence surface therefore makes hand-written snapshots fail
-- closed without changing valid discovery output.
fragExactEvidenceClaims :: Frag -> ExactEvidenceClaims
fragExactEvidenceClaims frag = case frag of
  FArr parameter result -> descend [parameter, result]
  FProd left right -> descend [left, right]
  FSum left right -> descend [left, right]
  FAll _ _ body -> fragExactEvidenceClaims body
  FInst _ body -> fragExactEvidenceClaims body
  FExactContext className arguments body ->
    foldl mergeExactEvidenceClaims
      (mergeExactEvidenceClaims
        (claimContextKinds className
          (map exactContextArgumentKindArity arguments))
        (fragExactEvidenceClaims body))
      (map exactContextClaim arguments)
  FApp _ _ head' arguments ->
    mergeExactEvidenceClaims
      (case head' of
        AppVariable _ -> emptyExactEvidenceClaims
        AppNominal spelling -> claimFamilyArity spelling (length arguments))
      (descend arguments)
  FParamInd spelling _ parameters constructors ->
    mergeExactEvidenceClaims
      (claimFamilyArity spelling (length parameters))
      (descend (parameters ++ concatMap snd constructors))
  FInd _ constructors -> descend (concatMap snd constructors)
  FParamRec _ spelling _ parameters constructors ->
    mergeExactEvidenceClaims
      (claimFamilyArity spelling (length parameters))
      (descend (parameters ++ concatMap snd constructors))
  FRec _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  FDepth -> malformedExactEvidenceClaims
  _ -> emptyExactEvidenceClaims
 where
  descend = foldl
    (\claims child -> mergeExactEvidenceClaims claims
      (fragExactEvidenceClaims child))
    emptyExactEvidenceClaims

  exactContextClaim source
    | remaining < 0 = malformedExactEvidenceClaims
    | remaining == 0 = case source of
        ExactContextFragmentArgument _ argument ->
          fragExactEvidenceClaims argument
        ExactContextNominalArgument{} -> malformedExactEvidenceClaims
    | otherwise = case exactContextNominalUse source of
        Just (spelling, totalArity, supplied) ->
          mergeExactEvidenceClaims
            (claimFamilyArity spelling totalArity)
            (descend supplied)
        Nothing -> malformedExactEvidenceClaims
   where
    remaining = exactContextArgumentKindArity source

providerArgumentExactEvidenceClaims
  :: ProviderInstantiationArgument
  -> ExactEvidenceClaims
providerArgumentExactEvidenceClaims argument = case argument of
  ProviderInstantiationNominalArgument remaining spelling supplied
    | remaining < 0 -> malformedExactEvidenceClaims
    | otherwise -> mergeExactEvidenceClaims
        (claimFamilyArity spelling (length supplied + remaining))
        (descend supplied)
  ProviderInstantiationExactArgument remaining frag _
    | remaining == 0 -> fragExactEvidenceClaims frag
    | otherwise -> malformedExactEvidenceClaims
  ProviderInstantiationArgument remaining frag
    | remaining < 0 -> malformedExactEvidenceClaims
    | remaining == 0 -> fragExactEvidenceClaims frag
    | otherwise -> case exactContextNominalUse
        (ExactContextFragmentArgument remaining frag) of
        Just (spelling, totalArity, supplied) ->
          mergeExactEvidenceClaims
            (claimFamilyArity spelling totalArity)
            (descend supplied)
        Nothing -> malformedExactEvidenceClaims
 where
  descend = foldl
    (\claims child -> mergeExactEvidenceClaims claims
      (fragExactEvidenceClaims child))
    emptyExactEvidenceClaims

providerAssignmentExactEvidenceClaims
  :: [ProviderInstantiationArgument]
  -> ExactEvidenceClaims
providerAssignmentExactEvidenceClaims = foldl
  (\claims argument -> mergeExactEvidenceClaims claims
    (providerArgumentExactEvidenceClaims argument))
  emptyExactEvidenceClaims

exactEvidenceClaimsConsistent :: ExactEvidenceClaims -> Bool
exactEvidenceClaimsConsistent claims =
  not (claimsMalformed claims)
    && all ((<= 1) . Set.size) (Map.elems (claimedContextKinds claims))
    && all ((<= 1) . Set.size) (Map.elems (claimedFamilyArities claims))

conflictingClaimNames :: Map.Map String (Set.Set a) -> Set.Set String
conflictingClaimNames = Map.keysSet . Map.filter ((> 1) . Set.size)

claimsTouchConflicts
  :: Set.Set String
  -> Set.Set String
  -> ExactEvidenceClaims
  -> Bool
claimsTouchConflicts contextConflicts familyConflicts claims =
  not (Set.null (Set.intersection contextConflicts
    (Map.keysSet (claimedContextKinds claims))))
  || not (Set.null (Set.intersection familyConflicts
    (Map.keysSet (claimedFamilyArities claims))))

data ParametricTemplate = ParametricTemplate
  { templateArity :: Int
  , templateFormals :: [String]
  , templateConstructors :: [(String, [Frag])]
  }
  deriving (Eq, Show)

data ExactFamilyPlan
  = StructuralFamily ParametricTemplate
  | RecursiveStructuralFamily ParametricTemplate
    -- ^ Both engines retain exact recursive data natively; Djinn exposes
    -- bounded positive introduction and Exference one-layer elimination.
  | AbstractFamily Int Bool
    -- ^ arity and whether this fallback hid an exposed inductive schema (and
    -- must therefore forfeit Djinn refutation completeness)
  | InvalidFamilyArities [Int]
  deriving (Eq, Show)

-- | Which recursive inventories may become native data declarations.  Exact
-- heads have query-wide identity and schema validation, so both engines can
-- use them.  Legacy 'FRec' inventories have only a constructor-namespace
-- heuristic; retain that positive, Lean-verified projection for Exference but
-- keep Djinn on its conservative introduction-premise fallback.
data RecursiveProjection = RecursiveProjection
  { exactRecursiveData :: Bool
  , legacyRecursiveData :: Bool
  }

djinnRecursiveProjection :: RecursiveProjection
djinnRecursiveProjection = RecursiveProjection
  { exactRecursiveData = True
  , legacyRecursiveData = False
  }

exferenceRecursiveProjection :: RecursiveProjection
exferenceRecursiveProjection = RecursiveProjection
  { exactRecursiveData = True
  , legacyRecursiveData = True
  }

data ProjectionCompleteness = ProjectionCompleteness
  { projectionFamiliesComplete :: Bool
    -- ^ no structural exact family was forced to stay opaque
  , projectionFragmentsComplete :: Bool
    -- ^ engine goal and caller premises contain neither unsafe atoms nor
    -- depth truncation; the fitting fragment is checked separately at verdict
  }
  deriving (Eq, Show)

newtype Trans a = Trans
  { runTrans :: TransState -> Either String (a, TransState) }

instance Functor Trans where
  fmap f (Trans g) = Trans $ \s -> do
    (a, s') <- g s
    Right (f a, s')

instance Applicative Trans where
  pure a = Trans (\s -> Right (a, s))
  Trans f <*> Trans g = Trans $ \s -> do
    (h, s1) <- f s
    (a, s2) <- g s1
    Right (h a, s2)

instance Monad Trans where
  Trans g >>= k = Trans $ \s -> do
    (a, s1) <- g s
    runTrans (k a) s1

failT :: String -> Trans a
failT msg = Trans (\_ -> Left msg)

getsT :: (TransState -> a) -> Trans a
getsT f = Trans (\s -> Right (f s, s))

modifyT :: (TransState -> TransState) -> Trans ()
modifyT f = Trans (\s -> Right ((), f s))

nameT :: String -> Trans Name
nameT spelling = Trans $ \s ->
  case mkIdentifier spelling of
    Left err -> Left (show err)
    Right name -> Right (name, s)

variable :: String -> Trans String
variable key = do
  table <- getsT tsTable
  case Map.lookup key table of
    Just v -> pure v
    Nothing -> do
      n <- getsT tsNext
      let v = "v" ++ show n
      modifyT (\s -> s { tsTable = Map.insert key v (tsTable s)
                       , tsNext = n + 1 })
      pure v

fragToDjinn
  :: RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Either String SynthesisTranslation
fragToDjinn recursiveProjection providers extras frag0 = do
  eitherC <- viaShow (mkIdentifier "Either")
  voidC <- viaShow (mkIdentifier "Void")
  unitC <- viaShow (tupleName Boxed 0)
  pairC <- viaShow (tupleName Boxed 2)
  let usableProviders = filter usableProvider providers
      -- Bound the provider-indexed assignment list before any argument
      -- fragment participates in family planning, rigidity, or translation.
      -- Keeping the index beside each complete vector preserves exact provider
      -- locality and source argument order while leaving later providers and
      -- their declarations intact.
      rawBoundedProviderAssignments =
        take maximumProviderInstantiationAssignments
          [ (index, assignment)
          | (index, provider) <- zip [0 :: Int ..] usableProviders
          , assignment <- usableProviderAssignments provider
          ]
      baselineEvidenceClaims = foldl
        (\claims source -> mergeExactEvidenceClaims claims
          (fragExactEvidenceClaims source))
        emptyExactEvidenceClaims
        (map snd extras ++ [frag0] ++ map providerTypeFrag usableProviders)
      internallyConsistentProviderAssignments =
        [ (index, assignment, claims)
        | (index, assignment) <- rawBoundedProviderAssignments
        , let claims = providerAssignmentExactEvidenceClaims assignment
        , exactEvidenceClaimsConsistent claims
        ]
      combinedEvidenceClaims = foldl
        (\claims (_, _, assignmentClaims) ->
          mergeExactEvidenceClaims claims assignmentClaims)
        baselineEvidenceClaims internallyConsistentProviderAssignments
      conflictingContextNames =
        conflictingClaimNames (claimedContextKinds combinedEvidenceClaims)
      conflictingFamilyNames =
        conflictingClaimNames (claimedFamilyArities combinedEvidenceClaims)
      -- A conflict may span two individually well-formed assignment vectors or
      -- one vector and the query baseline. Drop every vector that touches that
      -- identity; unrelated vectors from the same provider remain eligible.
      boundedProviderAssignments =
        [ (index, assignment)
        | (index, assignment, claims) <-
            internallyConsistentProviderAssignments
        , not (claimsTouchConflicts conflictingContextNames
            conflictingFamilyNames claims)
        ]
      providerArguments = concatMap snd boundedProviderAssignments
      providerAssignmentFragments =
        concatMap providerArgumentFragments providerArguments
      -- Residual higher-kinded nominal applications contribute a neutral
      -- exact-head arity fact while only their already supplied arguments are
      -- ordinary planning roots. This lets @Pair Nat@ share @Pair@ at arity
      -- two without forcing a saturated structural occurrence opaque.
      providerAssignmentPlanningFragments =
        concatMap providerArgumentPlanningFragments providerArguments
      providerAssignmentFamilyUses =
        foldl collectProviderArgumentFamilyUse Map.empty providerArguments
      queryFragments =
        map snd extras ++ [frag0] ++ map providerTypeFrag usableProviders
          ++ providerAssignmentFragments
      planningRoots =
        [ (True, frag) | frag <- map snd extras ++ [frag0] ]
          ++ [ (False, providerTypeFrag provider)
             | provider <- usableProviders
             ]
          ++ [ (False, argument)
             | argument <- providerAssignmentPlanningFragments
             ]
      plans = exactFamilyPlans recursiveProjection
        providerAssignmentFamilyUses planningRoots
      structuralTemplateFragments =
        [ field
        | plan <- Map.elems plans
        , template <- case plan of
            StructuralFamily selected -> [selected]
            RecursiveStructuralFamily selected
              | exactRecursiveData recursiveProjection -> [selected]
            _ -> []
        , (_, fields) <- templateConstructors template
        , field <- fields
        ]
      (recursiveSelfKeys, recursiveFieldAtoms) =
        recursiveStructuralAtoms recursiveProjection plans
          (queryFragments ++ structuralTemplateFragments)
      providerAtoms = foldl
        (\atoms provider -> collectProviderSurfaceAtoms atoms $
            providerTypeFrag provider)
        Set.empty usableProviders
      providerAndEvidenceAtoms = foldl collectProviderSurfaceAtoms
        providerAtoms providerAssignmentFragments
      rigidAtoms = Set.difference
        (Set.unions
          [ structuralAtomKeys recursiveProjection plans
          , recursiveFieldAtoms
          , providerAndEvidenceAtoms
          ])
        recursiveSelfKeys
      projection = ProjectionCompleteness
        { projectionFamiliesComplete =
            exactFamilyProjectionComplete recursiveProjection plans
        , projectionFragmentsComplete =
            all fragmentProjectionComplete (frag0 : map snd extras)
        }
      providerArgumentType argument = case argument of
        ProviderInstantiationNominalArgument remaining spelling supplied ->
          nominalArgumentType remaining spelling supplied
        ProviderInstantiationExactArgument 0 frag _ -> go False frag
        ProviderInstantiationExactArgument _ _ _ -> failT
          "exact Lean provider argument is not proper-kinded"
        ProviderInstantiationArgument 0 frag -> go False frag
        ProviderInstantiationArgument remaining frag -> case frag of
          -- Compatibility for snapshots written by the first kinded wire
          -- format. New live discovery always uses the canonical nominal
          -- payload above rather than trusting a pretty-printed atom.
          FAtom _ spelling -> exactFamilyHead spelling remaining
          FApp _ _ (AppNominal spelling) supplied ->
            nominalArgumentType remaining spelling supplied
          _ -> failT
            "higher-kinded provider argument did not retain a closed \
            \nominal Lean head"

      nominalArgumentType remaining spelling supplied = do
        translated <- mapM (go False) supplied
        headType <- canonicalExactFamilyHead spelling
          (length supplied + remaining)
        pure (applyTypeArguments headType translated)

      go premisesEnabled frag = case frag of
        FArr a b -> FunctionType
          <$> go premisesEnabled a <*> go premisesEnabled b
        FProd a b -> (\x y -> TupleType Boxed [x, y])
          <$> go premisesEnabled a <*> go premisesEnabled b
        FSum a b ->
          (\x y -> TypeApplication
            (TypeApplication (TypeConstructor eitherC) x) y)
          <$> go premisesEnabled a <*> go premisesEnabled b
        FTop -> pure (TypeConstructor unitC)
        FBot -> pure (TypeConstructor voidC)
        FVar v -> TypeVariable <$> variable ("v:" ++ v)
        FAtom _ key -> do
          occurrence <- getsT (Map.lookup key . tsInds)
          case occurrence of
            Just known -> pure known
            Nothing -> do
              rigid <- getsT (Set.member key . tsRigidAtoms)
              if rigid
                then rigidAtom key
                else TypeVariable <$> variable ("a:" ++ key)
        FApp _ _ head' arguments ->
          appOccurrence premisesEnabled head' arguments
        FAll{} -> do
          let (binders, afterBinders) = adjacentForallSpine frag
              (contextSources, body) = adjacentExactContextSpine afterBinders
          variables <- mapM (variable . ("v:" ++)) binders
          contexts <- mapM exactContextConstraint contextSources
          body' <- go premisesEnabled body
          pure (ForallType variables contexts body')
        -- Lean reconstructs instance evidence at applications.  Keep it out
        -- of both engine type systems; Render retains the introduction slot.
        FInst _ body -> go premisesEnabled body
        -- Exact provider-assignment contexts carry semantic class identity and
        -- structured arguments. They occur only in the exact evidence wire;
        -- unlike legacy render-only FInst markers, retain them for Djex's
        -- closed contextual assignment checker.
        FExactContext className arguments body -> do
          context <- exactContextConstraint (className, arguments)
          body' <- go premisesEnabled body
          pure (ForallType [] [context] body')
        FParamInd headName _ parameters _ ->
          parametricIndOccurrence premisesEnabled headName parameters
        FInd key ctors -> indOccurrence premisesEnabled key ctors
        FParamRec _ spelling key parameters ctors
          | exactRecursiveData recursiveProjection
          , Just (RecursiveStructuralFamily template) <-
              Map.lookup spelling plans ->
              exactRecDataOccurrence premisesEnabled spelling key parameters
                template
          | otherwise ->
              exactRecOccurrence premisesEnabled spelling key parameters ctors
        FRec complete key parameters ctors
          | legacyRecursiveData recursiveProjection
          , complete
          , Just parameterKeys <- distinctPlainParameters parameters ->
              recDataOccurrence key parameterKeys ctors
          | otherwise -> recOccurrence premisesEnabled key ctors
        FDepth -> failT "internal: depth marker survived refusal check"

      -- One Lean binder group is serialized as adjacent FAll nodes because
      -- rendering retains each explicitness slot independently. Djex instead
      -- models one source scheme with a binder list. Coalescing only the
      -- uninterrupted spine preserves scope and rendering while preventing a
      -- bounded multi-binder scheme from becoming independent occurrence sites.
      adjacentForallSpine = collect []
        where
          collect binders (FAll _ binder body) =
            collect (binder : binders) body
          collect binders body = (reverse binders, body)

      -- Preserve an exact instance telescope at its source position. A later
      -- FAll starts a nested scheme rather than being floated ahead of the
      -- context, so rendering consumes forall-domain metadata in the same
      -- preorder that the Lean serializer recorded.
      adjacentExactContextSpine = collect []
        where
          collect contexts (FExactContext className arguments body) =
            collect ((className, arguments) : contexts) body
          collect contexts body = (reverse contexts, body)

      exactContextConstraint (leanClassName, arguments) = do
        translatedArguments <- mapM exactContextArgument arguments
        classes <- getsT tsContextClasses
        className <- case Map.lookup leanClassName classes of
          Just (known, knownKinds)
            | knownKinds
                == map exactContextArgumentKindArity arguments -> pure known
            | otherwise -> failT $
                "exact Lean context class " ++ show leanClassName
                  ++ " has inconsistent parameter kinds"
          Nothing -> do
            index <- getsT tsContextNext
            let privateSpelling = "LeantContext" ++ show index
                parameterKinds =
                  map exactContextArgumentKindArity arguments
                parameters =
                  [ TypeParameter
                      ("leantContextParameter" ++ show index ++ "_" ++ show j)
                      (Just $ foldr FunctionKind ProperTypeKind
                        (replicate arity ProperTypeKind))
                  | (j, arity) <- zip [0 :: Int ..] parameterKinds
                  ]
            privateName <- nameT privateSpelling
            modifyT (\s -> s
              { tsContextClasses = Map.insert leanClassName
                  (privateName, parameterKinds) (tsContextClasses s)
              , tsContextNext = index + 1
              , tsTypeMap = Map.insert privateSpelling leanClassName
                  (tsTypeMap s)
              , tsDecls = tsDecls s ++
                  [ClassDeclaration () privateName parameters [] []]
              })
            pure privateName
        pure (Constraint className translatedArguments)

      exactContextArgument source
        | remaining < 0 || remaining > maximumProviderArgumentKindArity =
            failT "exact Lean context argument has an unsupported kind"
        | remaining == 0 = case source of
            ExactContextFragmentArgument _ argument -> go False argument
            ExactContextNominalArgument{} -> failT
              "proper-kinded exact Lean context argument was nominal"
        | otherwise = case source of
            ExactContextNominalArgument _ spelling supplied -> do
              translated <- mapM (go False) supplied
              headType <- canonicalExactFamilyHead spelling
                (length supplied + remaining)
              pure (applyTypeArguments headType translated)
            ExactContextFragmentArgument _ argument -> case argument of
              FAtom _ spelling -> exactFamilyHead spelling remaining
              FApp _ _ (AppNominal spelling) supplied -> do
                translated <- mapM (go False) supplied
                headType <- exactFamilyHead spelling
                  (length supplied + remaining)
                pure (applyTypeArguments headType translated)
              _ -> failT
                "higher-kinded exact Lean context argument did not retain a nominal head"
       where
        remaining = exactContextArgumentKindArity source

      -- Retained type applications are the bridge to Djex's guarded
      -- impredicative instantiation.  A bound higher-kinded head shares the
      -- enclosing forall variable.  A Lean constant becomes one private,
      -- rigid abstract constructor shared by goal and provider occurrences;
      -- its hidden semantics still poison negative verdicts on the fragment
      -- side, and Lean verifies every positive candidate.
      appOccurrence premisesEnabled head' arguments = do
        translated <- mapM (go premisesEnabled) arguments
        case head' of
          AppVariable spelling -> do
            headType <- TypeVariable <$> variable ("v:" ++ spelling)
            pure (applyTypeArguments headType translated)
          AppNominal spelling -> do
            headType <- exactFamilyHead spelling (length arguments)
            pure (applyTypeArguments headType translated)

      parametricIndOccurrence premisesEnabled spelling parameters = do
        translated <- mapM (go premisesEnabled) parameters
        headType <- exactFamilyHead spelling (length parameters)
        pure (applyTypeArguments headType translated)

      -- Every exact Lean head has exactly one engine-side constructor for the
      -- whole query.  The pre-scan decides whether that constructor can carry
      -- a validated data schema or must remain abstract.  Installing the
      -- family before translating structural fields also keeps nested family
      -- declarations dependency ordered without risking duplicate heads.
      exactFamilyHead spelling arity = do
        families <- getsT tsAppFamilies
        case Map.lookup spelling families of
          Just family
            | appTypeArity family == arity ->
                pure (TypeConstructor (appTypeName family))
            | otherwise -> failT
                ("internal: exact Lean family " ++ show spelling
                  ++ " appeared at arities " ++ show (appTypeArity family)
                  ++ " and " ++ show arity)
          Nothing -> do
            familyPlans <- getsT tsFamilyPlans
            case Map.lookup spelling familyPlans of
              Just (StructuralFamily template)
                | templateArity template == arity ->
                    declareParametricFamily spelling template
                | otherwise -> arityFailure spelling arity
                    [templateArity template]
              Just (RecursiveStructuralFamily template)
                | templateArity template == arity ->
                    if exactRecursiveData recursiveProjection
                      then failT
                        ("internal: structural recursive family "
                          ++ show spelling
                          ++ " reached its head before installing its knot")
                      else declareAbstractFamily spelling arity
                | otherwise -> arityFailure spelling arity
                    [templateArity template]
              Just (AbstractFamily plannedArity _)
                | plannedArity == arity ->
                    declareAbstractFamily spelling arity
                | otherwise -> arityFailure spelling arity [plannedArity]
              Just (InvalidFamilyArities arities) ->
                arityFailure spelling arity arities
              Nothing ->
                -- This is only reachable for a fragment introduced while a
                -- generic constructor schema is translated.  It still gets a
                -- single conservative nominal declaration.
                declareAbstractFamily spelling arity

      -- Canonical Prod and Sum evidence is the same structural identity used
      -- for saturated fragment products and sums.  This matters when a
      -- provider body applies its assigned constructor: substituting a fresh
      -- abstract family would no longer match an ordinary FProd/FSum goal.
      canonicalExactFamilyHead spelling arity
        | spelling == "Prod" =
            if arity == 2
              then pure (TypeConstructor pairC)
              else arityFailure spelling arity [2]
        | spelling == "Sum" =
            if arity == 2
              then pure (TypeConstructor eitherC)
              else arityFailure spelling arity [2]
        | otherwise = exactFamilyHead spelling arity

      arityFailure spelling arity arities = failT
        ("internal: exact Lean family " ++ show spelling
          ++ " has incompatible proper-type arities "
          ++ show (nub (arity : arities)))

      declareAbstractFamily spelling arity = do
        (_, _, typeName) <- freshExactFamily spelling arity
        let kind = foldr FunctionKind ProperTypeKind
              (replicate arity ProperTypeKind)
            declaration = AbstractTypeDeclaration () typeName kind
        modifyT (\s -> s { tsDecls = tsDecls s ++ [declaration] })
        pure (TypeConstructor typeName)

      declareParametricFamily spelling template = do
        (index, _, typeName) <-
          freshExactFamily spelling (templateArity template)
        parameterVariables <- mapM
          (variable . ("v:" ++)) (templateFormals template)
        let sole = length (templateConstructors template) == 1
        constructors <- mapM
          (\(j, (leanName, fields)) -> do
            fieldTypes <- mapM (go True) fields
            let constructorSpelling =
                  "LeantFamilyC" ++ show index ++ "_" ++ show j
            cname <- nameT constructorSpelling
            modifyT (\s -> s { tsCtorMap = Map.insert constructorSpelling
                (CtorInfo leanName fields sole
                  (Just (spelling, templateFormals template)))
                (tsCtorMap s) })
            pure (DataConstructor () cname fieldTypes))
          (zip [0 :: Int ..] (templateConstructors template))
        let declaration = DataTypeDeclaration () typeName
              [ TypeParameter parameter Nothing
              | parameter <- parameterVariables
              ] constructors
        modifyT (\s -> s { tsDecls = tsDecls s ++ [declaration] })
        pure (TypeConstructor typeName)

      freshExactFamily spelling arity = do
        index <- getsT tsAppNext
        let privateSpelling = "LeantType" ++ show index
        typeName <- nameT privateSpelling
        let family = AppFamily typeName arity
        modifyT (\s -> s
          { tsAppFamilies = Map.insert spelling family (tsAppFamilies s)
          , tsAppNext = index + 1
          , tsTypeMap = Map.insert privateSpelling spelling (tsTypeMap s)
          })
        pure (index, privateSpelling, typeName)

      -- A fixed opaque field such as @Secret@ is not one of the Lean
      -- inductive's parameters.  Modeling it as an engine type variable would
      -- make the generated data declaration ill scoped, so give every such
      -- exact field one shared private proper-type declaration.  Other atoms
      -- retain the established flexible transport representation.
      rigidAtom key = do
        atoms <- getsT tsAtomFamilies
        case Map.lookup key atoms of
          Just typeName -> pure (TypeConstructor typeName)
          Nothing -> do
            index <- getsT tsAtomNext
            let privateSpelling = "LeantAtom" ++ show index
            typeName <- nameT privateSpelling
            let declaration =
                  AbstractTypeDeclaration () typeName ProperTypeKind
            modifyT (\s -> s
              { tsAtomFamilies = Map.insert key typeName (tsAtomFamilies s)
              , tsAtomNext = index + 1
              -- Parenthesize the full pretty-printed type: the renderer adds
              -- Lean's @ prefix, and keys may themselves be applications or
              -- arrows rather than a single identifier.
              , tsTypeMap = Map.insert privateSpelling ("(" ++ key ++ ")")
                  (tsTypeMap s)
              , tsDecls = tsDecls s ++ [declaration]
              })
            pure (TypeConstructor typeName)

      -- One declaration per display key: translate the fields first
      -- (declaring any nested inductives before this one), parameterize
      -- over the type variables the translated fields mention, cache the
      -- applied occurrence.
      indOccurrence premisesEnabled key ctors = do
        existing <- getsT (Map.lookup key . tsInds)
        case existing of
          Just occurrence -> pure occurrence
          Nothing -> do
            translated <- mapM
              (\(leanName, fields) -> do
                fieldTypes <- mapM (go premisesEnabled) fields
                pure (leanName, fields, fieldTypes))
              ctors
            index <- getsT tsIndNext
            modifyT (\s -> s { tsIndNext = index + 1 })
            typeName <- nameT ("LeantData" ++ show index)
            let params = nub
                  [ v
                  | (_, _, fieldTypes) <- translated
                  , fieldType <- fieldTypes
                  , v <- toList fieldType
                  ]
            let sole = length translated == 1
            constructors <- mapM
              (\(j, (leanName, fields, fieldTypes)) -> do
                let spelling = "LeantC" ++ show index ++ "_" ++ show j
                cname <- nameT spelling
                modifyT (\s -> s { tsCtorMap = Map.insert spelling
                    (CtorInfo leanName fields sole Nothing) (tsCtorMap s) })
                pure (DataConstructor () cname fieldTypes))
              (zip [0 :: Int ..] translated)
            -- kinds stay implicit: Djinn's lowering rejects explicit
            -- parameter kinds and infers @*@ itself
            let decl = DataTypeDeclaration () typeName
                  [ TypeParameter p Nothing | p <- params ]
                  constructors
                occurrence = applyTypeArguments (TypeConstructor typeName)
                  (map TypeVariable params)
            modifyT (\s -> s { tsInds = Map.insert key occurrence (tsInds s)
                             , tsDecls = tsDecls s ++ [decl] })
            pure occurrence

      -- Both engines retain validated exact recursive data natively.
      -- 'FParamRec' occurrences use their serialized Lean head as the family
      -- identity.  One complete distinct-plain-variable occurrence supplies
      -- the generic declaration, and the query-wide plan proves that every use
      -- is a complete specialization.  Djex then owns the backend asymmetry:
      -- bounded positive introduction in Djinn and one-layer elimination in
      -- Exference.
      exactRecDataOccurrence premisesEnabled spelling key occurrenceParameters
          template = do
        translated <- mapM (go premisesEnabled) occurrenceParameters
        families <- getsT tsAppFamilies
        case Map.lookup spelling families of
          Just family
            | appTypeArity family == length translated -> do
                let occurrence = applyTypeArguments
                      (TypeConstructor (appTypeName family))
                      translated
                -- Display keys remain useful only for resolving the blocked
                -- self atoms within this occurrence's constructor fields.
                modifyT (\s -> s
                  { tsInds = Map.insert key occurrence (tsInds s) })
                pure occurrence
            | otherwise -> arityFailure spelling (length translated)
                [appTypeArity family]
          Nothing -> do
            (index, _, typeName) <-
              freshExactFamily spelling (length translated)
            let occurrence = applyTypeArguments
                  (TypeConstructor typeName) translated
            -- Install the knot before translating blocked recursive fields.
            modifyT (\s -> s
              { tsInds = Map.insert key occurrence (tsInds s) })
            formalVariables <- mapM
              (variable . ("v:" ++)) (templateFormals template)
            let sole = length (templateConstructors template) == 1
            constructors <- mapM
              (\(j, (leanName, fields)) -> do
                fieldTypes <- mapM (go True) fields
                let constructorSpelling =
                      "LeantRecC" ++ show index ++ "_" ++ show j
                cname <- nameT constructorSpelling
                modifyT (\s -> s
                  { tsCtorMap = Map.insert constructorSpelling
                      (CtorInfo leanName fields sole
                        (Just (spelling, templateFormals template)))
                      (tsCtorMap s) })
                pure (DataConstructor () cname fieldTypes))
              (zip [0 :: Int ..] (templateConstructors template))
            let declaration = DataTypeDeclaration () typeName
                  [ TypeParameter parameter Nothing
                  | parameter <- formalVariables
                  ] constructors
            modifyT (\s -> s
              { tsDecls = tsDecls s ++ [declaration] })
            pure occurrence

      -- Every non-structural FParamRec occurrence still shares one exact
      -- abstract family across the query.  Constructor premises preserve
      -- introduction without granting recursive elimination.
      exactRecOccurrence premisesEnabled spelling key parameters ctors = do
        translated <- mapM (go premisesEnabled) parameters
        headType <- exactFamilyHead spelling (length parameters)
        let occurrence = applyTypeArguments headType translated
        modifyT (\s -> s
          { tsInds = Map.insert key occurrence (tsInds s) })
        registerRecPremises premisesEnabled
          ("exact:" ++ spelling ++ ":" ++ key) key occurrence ctors
        pure occurrence

      -- Legacy FRec has no exact serialized head.  Retain its established
      -- constructor-namespace heuristic for Exference only.
      -- Requiring distinct plain variables avoids conflating structured or
      -- repeated applications while still preserving phantom parameters.
      -- This is what lets a live polymorphic provider such as
      -- @List.map@ line up with a goal mentioning @List \945@ even though Lean's
      -- two serializer runs chose different local binder spellings.
      recDataOccurrence key parameterKeys ctors = do
        existing <- getsT (Map.lookup key . tsInds)
        case existing of
          Just occurrence -> pure occurrence
          Nothing -> do
            let family = recursiveFamily key ctors
            parameters <- mapM (variable . ("v:" ++)) parameterKeys
            families <- getsT tsRecFamilies
            case Map.lookup family families of
              Just info
                | recTypeArity info == length parameters -> do
                    let occurrence = applyTypeArguments
                          (TypeConstructor (recTypeName info))
                          (map TypeVariable parameters)
                    modifyT (\s -> s
                      { tsInds = Map.insert key occurrence (tsInds s) })
                    pure occurrence
                | otherwise -> do
                    -- A family whose serialized parameter arity changes is
                    -- not safe to identify nominally.  Keep this occurrence
                    -- opaque instead of conflating the two applications;
                    -- Lean verification remains the final authority.
                    occurrence <- TypeVariable <$> variable ("a:" ++ key)
                    modifyT (\s -> s
                      { tsInds = Map.insert key occurrence (tsInds s) })
                    pure occurrence
              Nothing -> do
                index <- getsT tsIndNext
                modifyT (\s -> s { tsIndNext = index + 1 })
                typeName <- nameT ("LeantRec" ++ show index)
                let occurrence = applyTypeArguments
                      (TypeConstructor typeName) (map TypeVariable parameters)
                -- Install the occurrence before translating fields: blocked
                -- recursive fields arrive as FAtom with this exact key.
                modifyT (\s -> s
                  { tsInds = Map.insert key occurrence (tsInds s)
                  , tsRecFamilies = Map.insert family
                      (RecInfo typeName (length parameters))
                      (tsRecFamilies s)
                  })
                let sole = length ctors == 1
                constructors <- mapM
                  (\(j, (leanName, fields)) -> do
                    fieldTypes <- mapM (go True) fields
                    let spelling = "LeantC" ++ show index ++ "_" ++ show j
                    cname <- nameT spelling
                    modifyT (\s -> s
                      { tsCtorMap = Map.insert spelling
                          (CtorInfo leanName fields sole Nothing)
                          (tsCtorMap s) })
                    pure (DataConstructor () cname fieldTypes))
                  (zip [0 :: Int ..] ctors)
                let decl = DataTypeDeclaration () typeName
                      [ TypeParameter p Nothing | p <- parameters ]
                      constructors
                modifyT (\s -> s { tsDecls = tsDecls s ++ [decl] })
                pure occurrence

      -- A recursive inductive stays an opaque atom (sharing the
      -- variable any blocked field occurrence produced), but its
      -- constructors become premise types the caller prepends to the
      -- goal as antecedents - introduction rules without elimination.
      recOccurrence premisesEnabled key ctors = do
        rigid <- getsT (Set.member key . tsRigidAtoms)
        occurrence <- if rigid
          then rigidAtom key
          else TypeVariable <$> variable ("a:" ++ key)
        registerRecPremises premisesEnabled key key occurrence ctors
        pure occurrence

      registerRecPremises premisesEnabled registrationKey key occurrence
          ctors = do
        registered <- getsT (Map.member registrationKey . tsRecs)
        if registered || not premisesEnabled
          then pure ()
          else do
            modifyT (\s -> s
              { tsRecs = Map.insert registrationKey () (tsRecs s) })
            mapM_
              (\(leanName, fields) -> do
                fieldTypes <- mapM (go premisesEnabled) fields
                let premise = foldr FunctionType occurrence fieldTypes
                    premFrag = foldr FArr (FAtom False key) fields
                modifyT (\s -> s
                  { tsPrems = tsPrems s ++
                      [ TranslatedPremise
                          { translatedPremiseName = leanName
                          , translatedPremiseFragment = premFrag
                          , translatedPremiseType = premise
                          }
                      ] }))
              ctors
            pure ()

  let translate = do
        -- caller-supplied premises share the goal's variable table and
        -- come first, so their binders are the candidate's first
        extrasT <- mapM
          (\(name, prem) -> do
            premType <- go True prem
            pure TranslatedPremise
              { translatedPremiseName = name
              , translatedPremiseFragment = prem
              , translatedPremiseType = premType
              })
          extras
        goal <- go True frag0
        translatedProviders <- mapM
          (\(index, provider) -> do
            let leanName = providerLeanName provider
                providerFrag = providerTypeFrag provider
                binderNames = case provider of
                  ProviderFrag{} -> Nothing
                  ProviderFragWithBinders
                      { providerTypeBinderNames = names } -> Just names
                  ProviderFragWithEvidence
                      { providerTypeBinderNames = names } -> Just names
            privateName <- nameT ("leantProvider" ++ show index)
            providerType <- go False providerFrag
            translatedAssignments <- mapM
              (\arguments -> do
                translatedArguments <- mapM
                  (\argument -> do
                    argumentType <- providerArgumentType argument
                    visibleArgument <- case
                        specifiedVisibleTypeArgument argumentType of
                      Left failure -> failT $ show failure
                      Right visible -> pure visible
                    pure
                      ( (providerArgumentKind argument, argumentType)
                      , visibleArgument
                      ))
                  arguments
                pure
                  ( KindedProviderInstantiationAssignment
                      { kindedProviderInstantiationAssignmentProvider =
                          privateName
                      , kindedProviderInstantiationAssignmentArguments =
                          map fst translatedArguments
                      }
                  , ProviderAssignmentInfo
                      { paiVisibleArguments = map snd translatedArguments
                      , paiSourceArguments = arguments
                      }
                  ))
              [ assignment
              | (providerIndex, assignment) <- boundedProviderAssignments
              , providerIndex == index
              ]
            -- Domain metadata can distinguish two Lean renderings which Djex
            -- intentionally collapses to the same canonical assignment. Keep
            -- every bounded rendering below, but search each canonical vector
            -- only once.
            let instantiations = nub (map fst translatedAssignments)
                info = (providerInfo leanName binderNames providerFrag)
                  { piAssignments = map snd translatedAssignments }
            pure ProviderBinding
              { providerBindingSource = provider
              , providerBindingPrivateName = privateName
              , providerBindingPrivateSpelling =
                  "leantProvider" ++ show index
              , providerBindingScheme = providerType
              , providerBindingRenderInfo = info
              , providerBindingAssignments = instantiations
              })
          (zip [0 :: Int ..] usableProviders)
        pure TranslationProduct
          { translationProductCallerPremises = extrasT
          , translationProductSourceGoal = goal
          , translationProductProviderBindings = translatedProviders
          }
  (translatedProduct, finalState) <-
    runTrans translate TransState
    { tsTable = Map.empty
    , tsNext = 0
    , tsInds = Map.empty
    , tsDecls = []
    , tsIndNext = 0
    , tsCtorMap = Map.empty
    , tsRecs = Map.empty
    , tsRecFamilies = Map.empty
    , tsPrems = []
    , tsAppFamilies = Map.empty
    , tsFamilyPlans = plans
    , tsAppNext = 0
    , tsRigidAtoms = rigidAtoms
    , tsAtomFamilies = Map.empty
    , tsAtomNext = 0
    , tsContextClasses = Map.empty
    , tsContextNext = 0
    , tsTypeMap = Map.empty
    }
  let providerBindings = translationProductProviderBindings translatedProduct
      providerDecls = map providerBindingDeclaration providerBindings
      providerMap = Map.fromList
        [ ( providerBindingPrivateSpelling binding
          , providerBindingRenderInfo binding
          )
        | binding <- providerBindings
        ]
      instantiations = concatMap providerBindingAssignments providerBindings
      constructorPremises = tsPrems finalState
      familyBindings = semanticFamilyBindings
        (tsDecls finalState)
        (tsCtorMap finalState)
        (tsTypeMap finalState)
  Right SynthesisTranslation
    { translationSourceGoal = translationProductSourceGoal translatedProduct
    , translationDeclarations = tsDecls finalState
    , translationProviderDeclarations = providerDecls
    , translationProviderBindings = providerBindings
    , translationSemanticFamilyBindings = familyBindings
    , translationProviderAssignments = instantiations
    , translationConstructorMap = tsCtorMap finalState
    , translationProviderMap = providerMap
    , translationTypeMap = tsTypeMap finalState
    , translationCallerPremises =
        translationProductCallerPremises translatedProduct
    , translationConstructorPremises = constructorPremises
    , translationProjectionCompleteness = projection
    }
 where
  usableProvider = not . fragHasDepth . providerTypeFrag

  usableProviderAssignments provider = case provider of
    ProviderFragWithEvidence
        { providerInstantiationAssignments = assignments } ->
      let arity = providerInstantiationArity (providerTypeFrag provider)
      in
      filter
        (\assignment ->
          not (null assignment)
            && length assignment == arity
            && length assignment <= maximumProviderInstantiationArguments
            && all usableProviderArgument assignment)
        assignments
    _ -> []

  usableProviderArgument argument =
    providerInstantiationArgumentKindArity argument >= 0
      && providerInstantiationArgumentKindArity argument
        <= maximumProviderArgumentKindArity
      && supportedProviderArgumentHead argument
      && usableExactDomains argument
      && contextualEvidenceIsExact argument
      && all
        (\frag -> not
          (fragHasDepth frag || fragHasUnsupportedInstanceBinder frag))
        (providerArgumentFragments argument)

  -- The structured contextual node is semantic metadata owned by the exact
  -- argument wire. Historical structural and nominal payloads must not gain a
  -- second, metadata-free route merely because they share the Frag parser.
  contextualEvidenceIsExact argument = case argument of
    ProviderInstantiationExactArgument{} -> True
    _ -> all (not . fragHasInstanceBinder)
      (providerArgumentFragments argument)

  usableExactDomains argument = case argument of
    ProviderInstantiationExactArgument remaining frag domains ->
      remaining == 0
        && length domains <= maximumProviderExactForallDomains
        && maybe False ((length domains ==) . length)
          (fragVisibleForallVisibilities frag)
    _ -> True

  providerArgumentKind :: ProviderInstantiationArgument -> GroundKind
  providerArgumentKind argument =
    foldr FunctionKind ProperTypeKind
      (replicate
        (providerInstantiationArgumentKindArity argument)
        ProperTypeKind)

  -- Canonical Prod/Sum payloads have exact structural engine identities.
  -- Prop-valued and sort-polymorphic structural heads remain fail-closed
  -- because the ground-kind wire does not retain enough sort information.
  supportedProviderArgumentHead argument = case argument of
    ProviderInstantiationNominalArgument remaining spelling supplied
      | elem spelling ["Prod", "Sum"] ->
          length supplied + remaining == 2
      | otherwise ->
          remaining == 0 || not (elem spelling structuralHigherKindHeads)
    ProviderInstantiationExactArgument remaining _ _ -> remaining == 0
    ProviderInstantiationArgument remaining frag
      | remaining > 0 -> case frag of
          FAtom _ spelling -> spelling `notElem` structuralHigherKindHeads
          FApp _ _ (AppNominal spelling) _ ->
            spelling `notElem` structuralHigherKindHeads
          _ -> True
      | otherwise -> True
  providerArgumentFragments argument = case argument of
    ProviderInstantiationArgument _ frag -> [frag]
    ProviderInstantiationExactArgument _ frag _ -> [frag]
    ProviderInstantiationNominalArgument _ _ supplied -> supplied

  providerArgumentPlanningFragments argument = case argument of
    ProviderInstantiationNominalArgument _ _ supplied -> supplied
    ProviderInstantiationExactArgument _ frag _ -> [frag]
    ProviderInstantiationArgument remaining frag
      | remaining > 0 -> case frag of
          FAtom{} -> []
          FApp _ _ (AppNominal _) supplied -> supplied
          _ -> [frag]
      | otherwise -> [frag]

  collectProviderArgumentFamilyUse uses argument = case argument of
    ProviderInstantiationNominalArgument remaining spelling supplied ->
      insertEvidenceUse spelling (length supplied + remaining) uses
    ProviderInstantiationExactArgument _ _ _ -> uses
    ProviderInstantiationArgument remaining frag
      | remaining > 0 -> case frag of
          FAtom _ spelling -> insertEvidenceUse spelling remaining uses
          FApp _ _ (AppNominal spelling) supplied ->
            insertEvidenceUse spelling (length supplied + remaining) uses
          _ -> uses
      | otherwise -> uses
   where
    insertEvidenceUse spelling arity = Map.alter append spelling
     where
      evidence = EvidenceUse arity
      append Nothing = Just [evidence]
      append (Just previous)
        | evidence `elem` previous = Just previous
        | otherwise = Just (previous ++ [evidence])

  providerInstantiationArity provider = case provider of
    FAll _ _ body -> 1 + providerInstantiationArity body
    FInst _ body -> providerInstantiationArity body
    FExactContext _ _ body -> providerInstantiationArity body
    _ -> 0

  recursiveFamily key ctors = case ctors of
    (leanName, _) : _ ->
      let prefix = reverse (drop 1 (dropWhile (/= '.') (reverse leanName)))
      in if null prefix then key else prefix
    [] -> key

  distinctPlainParameters parameters = do
    keys <- mapM plainParameter parameters
    if nub keys == keys then Just keys else Nothing

  plainParameter parameter = case parameter of
    FVar key -> Just key
    _ -> Nothing

  -- Fixed opaque fields consumed by native structural recursive declarations
  -- must be rigid before any fragment is translated.  Otherwise
  -- traversal order can give an earlier goal occurrence (say @String@ in
  -- @String -> Std.Format@) a flexible identity before @Format.text@ closes
  -- the same field as a private proper type.  Consume only query-wide selected
  -- recursive templates, then remove every structural recursive occurrence key
  -- itself: self fields must still resolve through the shared structural knot
  -- rather than becoming unrelated rigid atoms.  Legacy FRec inventories keep
  -- their established occurrence-local scan below.
  recursiveStructuralAtoms projectionPolicy plans =
    foldl collect (Set.empty, Set.empty)
   where
    collect accum frag = case frag of
      FArr parameter result -> descend accum [parameter, result]
      FProd left right -> descend accum [left, right]
      FSum left right -> descend accum [left, right]
      FAll _ _ body -> collect accum body
      FInst _ body -> collect accum body
      FExactContext _ arguments body ->
        descend accum
          (concatMap exactContextArgumentFragments arguments ++ [body])
      FApp _ _ _ arguments -> descend accum arguments
      -- Translating an exact nonrecursive occurrence consumes only its
      -- parameter vector.  Its query-wide structural template fields are
      -- supplied separately above; an abstract plan's occurrence inventory
      -- must not rigidify otherwise unused metadata.
      FParamInd _ _ parameters _ -> descend accum parameters
      FInd _ constructors -> descend accum (concatMap snd constructors)
      FParamRec _ spelling key parameters _ ->
        let structural = case Map.lookup spelling plans of
              Just RecursiveStructuralFamily{} ->
                exactRecursiveData projectionPolicy
              _ -> False
            accum'
              | structural = (Set.insert key (fst accum), snd accum)
              | otherwise = accum
        -- The selected generic template fields are supplied separately above;
        -- occurrence-local inventories do not participate in the declaration.
        in descend accum' parameters
      FRec complete key parameters constructors ->
        recursive accum
          (legacyRecursiveData projectionPolicy
            && complete && hasDistinctPlainParameters parameters)
          key parameters constructors
      _ -> accum

    descend = foldl collect

    recursive accum@(selfKeys, fieldAtoms)
        eligible key parameters constructors =
      let fields = concatMap snd constructors
          accum'
            | eligible =
                ( Set.insert key selfKeys
                , foldl collectFragAtoms fieldAtoms fields
                )
            | otherwise = accum
      in descend accum' (parameters ++ fields)

fragmentProjectionComplete :: Frag -> Bool
fragmentProjectionComplete frag =
  not (fragHasDepth frag) && null (fragUnsafeAtoms frag)

-- | Decide each exact-head family representation from the complete query,
-- before translation order can bias the choice.  A nominal use means Lean did
-- not expose a constructor schema at that occurrence, so every use of that
-- head becomes one shared abstract family.  Otherwise a structural template
-- is accepted only when one unique schema can be recovered and specializing
-- it reproduces every serialized occurrence exactly.
exactFamilyPlans
  :: RecursiveProjection
  -> Map.Map String [ExactFamilyUse]
  -> [(Bool, Frag)]
  -> Map.Map String ExactFamilyPlan
exactFamilyPlans recursiveProjection evidenceUses roots = settle initialUses
 where
  initialUses = foldl
    (\uses (premisesEnabled, frag) ->
      collectExactFamilyUses recursiveProjection premisesEnabled uses frag)
    evidenceUses roots

  -- Constructor inventories are metadata until translation commits to using
  -- them.  Grow the reachable-use set only through selected data templates and
  -- through recursive constructor premises that the active engine lowering
  -- actually registers.  The use set grows monotonically and is deduplicated,
  -- so nested exact families reach a finite fixed point without traversal-order
  -- bias.  If a newly reached occurrence makes an earlier plan abstract, its
  -- already inspected fields remain a conservative part of the scan.
  settle uses =
    let plans = Map.mapWithKey choosePlan uses
        fields = structuralFields plans ++ recursivePremiseFields plans uses
        uses' = foldl
          (collectExactFamilyUses recursiveProjection True) uses fields
    in if uses' == uses then plans else settle uses'

  structuralFields plans =
    [ field
    | plan <- Map.elems plans
    , template <- case plan of
        StructuralFamily selected -> [selected]
        RecursiveStructuralFamily selected
          | exactRecursiveData recursiveProjection -> [selected]
        _ -> []
    , (_, fields) <- templateConstructors template
    , field <- fields
    ]

  recursivePremiseFields plans uses =
    [ field
    | (spelling, familyUses) <- Map.toList uses
    , use@RecursiveUse{} <- familyUses
    , recursiveUsePremises use
    , recursiveUsesPremises plans spelling
    , (_, fields) <- recursiveUseConstructors use
    , field <- fields
    ]

  recursiveUsesPremises plans spelling =
    not (exactRecursiveData recursiveProjection) ||
      case Map.lookup spelling plans of
        Just RecursiveStructuralFamily{} -> False
        _ -> True

  recursiveUsePremises use = case use of
    RecursiveUse _ premisesEnabled _ _ _ -> premisesEnabled
    _ -> False

  recursiveUseConstructors use = case use of
    RecursiveUse _ _ _ _ constructors -> constructors
    _ -> []

structuralAtomKeys
  :: RecursiveProjection
  -> Map.Map String ExactFamilyPlan
  -> Set.Set String
structuralAtomKeys recursiveProjection = Map.foldl' collectPlan Set.empty
 where
  collectPlan keys plan = case plan of
    StructuralFamily template -> foldl collectConstructor keys
      (templateConstructors template)
    RecursiveStructuralFamily template
      | exactRecursiveData recursiveProjection -> foldl collectConstructor keys
          (templateConstructors template)
    _ -> keys
  collectConstructor keys (_, fields) = foldl collectFragAtoms keys fields

collectFragAtoms :: Set.Set String -> Frag -> Set.Set String
collectFragAtoms atoms frag = case frag of
  FArr parameter result -> descend atoms [parameter, result]
  FProd left right -> descend atoms [left, right]
  FSum left right -> descend atoms [left, right]
  FAll _ _ body -> collectFragAtoms atoms body
  FInst _ body -> collectFragAtoms atoms body
  FExactContext _ arguments body ->
    descend atoms
      (concatMap exactContextArgumentFragments arguments ++ [body])
  FAtom _ key -> Set.insert key atoms
  FApp _ _ _ arguments -> descend atoms arguments
  -- An exact nested family's inventory belongs to its independent query-wide
  -- plan.  Translating this field consumes only the head and parameter vector,
  -- so inventory-only atoms must not become rigid on the outer declaration's
  -- behalf.
  FParamInd _ _ parameters _ -> descend atoms parameters
  FInd _ constructors -> descend atoms (concatMap snd constructors)
  -- Exact recursive inventories are likewise owned by their independent plan.
  -- A selected recursive template contributes its atoms through
  -- 'structuralAtomKeys'; an abstract inventory must not leak metadata into an
  -- enclosing declaration.
  FParamRec _ _ _ parameters _ -> descend atoms parameters
  FRec _ key parameters constructors ->
    descend (Set.insert key atoms) (parameters ++ concatMap snd constructors)
  _ -> atoms
 where
  descend = foldl collectFragAtoms

-- A live provider's surface atoms denote exact Lean types, not caller-owned
-- type variables. Close them as private nominal types in the provider-enriched
-- lane so a scheme such as @forall a. Demo.Token@ does not acquire an extra
-- implicitly generalized Djex binder before @a@. Constructor inventories are
-- metadata rather than part of the occurrence type; their fixed fields keep
-- using the query-wide structural planning rules above.
collectProviderSurfaceAtoms :: Set.Set String -> Frag -> Set.Set String
collectProviderSurfaceAtoms atoms frag = case frag of
  FArr parameter result -> descend atoms [parameter, result]
  FProd left right -> descend atoms [left, right]
  FSum left right -> descend atoms [left, right]
  FAll _ _ body -> collectProviderSurfaceAtoms atoms body
  FInst _ body -> collectProviderSurfaceAtoms atoms body
  FExactContext _ arguments body ->
    descend atoms
      (concatMap exactContextArgumentFragments arguments ++ [body])
  FAtom _ key -> Set.insert key atoms
  FApp _ _ _ arguments -> descend atoms arguments
  FParamInd _ _ parameters _ -> descend atoms parameters
  FParamRec _ _ _ parameters _ -> descend atoms parameters
  FRec _ _ parameters _ -> descend atoms parameters
  _ -> atoms
 where
  descend = foldl collectProviderSurfaceAtoms

collectExactFamilyUses
  :: RecursiveProjection
  -> Bool
  -> Map.Map String [ExactFamilyUse]
  -> Frag
  -> Map.Map String [ExactFamilyUse]
collectExactFamilyUses recursiveProjection premisesEnabled uses frag =
  case frag of
  FArr parameter result -> descend uses [parameter, result]
  FProd left right -> descend uses [left, right]
  FSum left right -> descend uses [left, right]
  FAll _ _ body -> collect uses body
  FInst _ body -> collect uses body
  FExactContext _ arguments body ->
    collect (foldl collectContextArgument uses arguments) body
  FApp _ key head' arguments ->
    let withUse = case head' of
          AppVariable _ -> uses
          AppNominal spelling
            -- A normalized recursive self application describes the knot in
            -- its declaration; it is not a separate nominal occurrence.
            | "\0leant-rec-self:" `isPrefixOf` key -> uses
            | otherwise -> insertUse spelling
                (NominalUse (length arguments)) uses
    in descend withUse arguments
  FParamInd spelling _ parameters constructors ->
    descend (insertUse spelling
      (ParametricUse parameters constructors) uses) parameters
  FInd _ constructors -> descend uses (concatMap snd constructors)
  FParamRec complete spelling key parameters constructors ->
    descend (insertUse spelling
      (RecursiveUse complete premisesEnabled key parameters constructors) uses)
      parameters
  FRec complete _ parameters constructors ->
    let fields
          | premisesEnabled
              || (legacyRecursiveData recursiveProjection && complete
                && hasDistinctPlainParameters parameters) =
              concatMap snd constructors
          | otherwise = []
    in descend uses (parameters ++ fields)
  _ -> uses
 where
  collect = collectExactFamilyUses recursiveProjection premisesEnabled
  descend = foldl collect
  collectContextArgument current source =
    case exactContextNominalUse source of
      Just (spelling, totalArity, supplied) ->
        descend
          (insertUse spelling (EvidenceUse totalArity) current)
          supplied
      Nothing -> descend current
        (exactContextArgumentPayloadFragments source)
  insertUse spelling use = Map.alter append spelling
   where
    append Nothing = Just [use]
    append (Just previous)
      | use `elem` previous = Just previous
      | otherwise = Just (previous ++ [use])

choosePlan :: String -> [ExactFamilyUse] -> ExactFamilyPlan
choosePlan spelling uses = case nub (map useArity uses) of
  [arity]
    | null substantiveUses -> AbstractFamily arity False
    | length occurrences == length substantiveUses ->
        case compatibleTemplates of
        template : rest
          | all (templatesEquivalent template) rest ->
              StructuralFamily template
        _ -> AbstractFamily arity True
    | length recursiveOccurrences == length substantiveUses ->
        case compatibleRecursiveTemplates of
          template : rest
            | all (templatesEquivalent template) rest ->
                RecursiveStructuralFamily template
          _ -> AbstractFamily arity True
    | otherwise -> AbstractFamily arity (any hidesStructure uses)
  arities -> InvalidFamilyArities arities
 where
  substantiveUses = [use | use <- uses, substantive use]
  substantive EvidenceUse{} = False
  substantive _ = True
  occurrences =
    [ (parameters, constructors)
    | ParametricUse parameters constructors <- uses
    ]
  recursiveOccurrences =
    [ (complete, key, parameters, constructors)
    | RecursiveUse complete _ key parameters constructors <- uses
    ]
  compatibleTemplates =
    [ template
    | occurrence@(parameters, _) <- occurrences
    , pairwiseDistinct parameters
    , let template = genericTemplate spelling occurrence
    , templateClosed template
    , all (templateFits template) occurrences
    ]
  compatibleRecursiveTemplates =
    [ template
    | (complete, key, parameters, constructors) <-
        recursiveOccurrences
    , complete
    -- Exact query-wide family identity lets a whole structured proper type
    -- contribute a positive schema candidate.  Serialized occurrences do not
    -- yet distinguish declaration-parameter fields from coincidentally equal
    -- fixed fields, so this is deliberately speculative: genericization
    -- matches the complete fragment before descending, closes the template,
    -- and must specialize back to every occurrence.  A second occurrence can
    -- therefore disambiguate fixed fields; repeated or alpha-equal parameter
    -- vectors stay abstract, and every emitted term is still checked by Lean.
    , pairwiseDistinct parameters
    , let template = recursiveTemplate spelling key parameters constructors
    , templateClosed template
    , all (recursiveTemplateFits spelling template) recursiveOccurrences
    ]

  useArity use = case use of
    ParametricUse parameters _ -> length parameters
    RecursiveUse _ _ _ parameters _ -> length parameters
    NominalUse arity -> arity
    EvidenceUse arity -> arity
  hidesStructure use = case use of
    ParametricUse{} -> True
    RecursiveUse{} -> True
    NominalUse{} -> False
    EvidenceUse{} -> False

hasDistinctPlainParameters :: [Frag] -> Bool
hasDistinctPlainParameters parameters = case mapM plain parameters of
  Just names -> nub names == names
  Nothing -> False
 where
  plain parameter = case parameter of
    FVar name -> Just name
    _ -> Nothing

-- | Normalize the blocked display-key atom used for a recursive self field,
-- then genericize the proper-type parameters.  This compares schemas by exact
-- family head rather than by occurrence spelling or constructor namespace.
recursiveTemplate
  :: String
  -> String
  -> [Frag]
  -> [(String, [Frag])]
  -> ParametricTemplate
recursiveTemplate spelling key parameters constructors =
  genericTemplate spelling
    (normalizedRecursiveOccurrence spelling key parameters constructors)

recursiveTemplateFits
  :: String
  -> ParametricTemplate
  -> (Bool, String, [Frag], [(String, [Frag])])
  -> Bool
recursiveTemplateFits spelling template
    (complete, key, parameters, constructors) =
  complete && templateFits template
    (normalizedRecursiveOccurrence spelling key parameters constructors)

normalizedRecursiveOccurrence
  :: String
  -> String
  -> [Frag]
  -> [(String, [Frag])]
  -> ([Frag], [(String, [Frag])])
normalizedRecursiveOccurrence spelling key parameters constructors =
  ( parameters
  , replaceConstructorFields
      [ ( FAtom False key
        , FApp True ("\0leant-rec-self:" ++ spelling)
            (AppNominal spelling) parameters
        )
      ]
      constructors
  )

exactFamilyProjectionComplete
  :: RecursiveProjection
  -> Map.Map String ExactFamilyPlan
  -> Bool
exactFamilyProjectionComplete recursiveProjection = all complete . Map.elems
 where
  complete plan = case plan of
    AbstractFamily _ hidesStructure -> not hidesStructure
    InvalidFamilyArities{} -> False
    StructuralFamily{} -> True
    RecursiveStructuralFamily{} -> exactRecursiveData recursiveProjection

pairwiseDistinct :: [Frag] -> Bool
pairwiseDistinct [] = True
pairwiseDistinct (parameter : rest) =
  not (any (schemaEquivalent parameter) rest) && pairwiseDistinct rest

genericTemplate
  :: String
  -> ([Frag], [(String, [Frag])])
  -> ParametricTemplate
genericTemplate spelling (parameters, constructors) = ParametricTemplate
  { templateArity = length parameters
  , templateFormals = formals
  , templateConstructors = replaceConstructorFields replacements constructors
  }
 where
  formals =
    [ "\0leant-family:" ++ spelling ++ ":" ++ show index
    | index <- [0 :: Int .. length parameters - 1]
    ]
  replacements = zip parameters (map FVar formals)

-- A shared declaration may mention only its fresh family parameters and
-- variables bound by a field-local forall.  Fixed opaque atoms are closed
-- separately as private rigid declarations; an unexpected free FVar or
-- higher-kinded variable head makes the family abstract instead of producing
-- an ill-scoped Djex data declaration.
templateClosed :: ParametricTemplate -> Bool
templateClosed template = all
  (Set.null . freeSchemaVariables (Set.fromList (templateFormals template)))
  [ field
  | (_, fields) <- templateConstructors template
  , field <- fields
  ]

freeSchemaVariables :: Set.Set String -> Frag -> Set.Set String
freeSchemaVariables bound frag = case frag of
  FArr parameter result -> descend [parameter, result]
  FProd left right -> descend [left, right]
  FSum left right -> descend [left, right]
  FAll _ binder body -> freeSchemaVariables (Set.insert binder bound) body
  FInst _ body -> freeSchemaVariables bound body
  FExactContext _ arguments body ->
    descend
      (concatMap exactContextArgumentPayloadFragments arguments ++ [body])
  FVar variableName
    | variableName `Set.member` bound -> Set.empty
    | otherwise -> Set.singleton variableName
  FApp _ _ head' arguments ->
    let headVariables = case head' of
          AppVariable variableName
            | variableName `Set.member` bound -> Set.empty
            | otherwise -> Set.singleton variableName
          AppNominal _ -> Set.empty
    in headVariables `Set.union` descend arguments
  -- As in 'collectFragAtoms', the nested exact family's constructors are
  -- validated by its own plan and do not occur in this field's engine type.
  FParamInd _ _ parameters _ -> descend parameters
  FInd _ constructors -> descend (concatMap snd constructors)
  FParamRec _ _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  FRec _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  _ -> Set.empty
 where
  descend = Set.unions . map (freeSchemaVariables bound)

templateFits
  :: ParametricTemplate
  -> ([Frag], [(String, [Frag])])
  -> Bool
templateFits template (parameters, constructors) =
  length parameters == templateArity template
    && constructorsEquivalent
      (replaceConstructorFields
        (zip (map FVar (templateFormals template)) parameters)
        (templateConstructors template))
      constructors

templatesEquivalent :: ParametricTemplate -> ParametricTemplate -> Bool
templatesEquivalent left right =
  templateArity left == templateArity right
    && templateFormals left == templateFormals right
    && constructorsEquivalent
      (templateConstructors left) (templateConstructors right)

constructorsEquivalent
  :: [(String, [Frag])]
  -> [(String, [Frag])]
  -> Bool
constructorsEquivalent left right =
  length left == length right
    && and (zipWith constructorEquivalent left right)
 where
  constructorEquivalent (leftName, leftFields) (rightName, rightFields) =
    leftName == rightName
      && length leftFields == length rightFields
      && and (zipWith schemaEquivalent leftFields rightFields)

-- Display keys, safety flags, completeness, and nested constructor inventories
-- are occurrence metadata, not part of a field type's identity.  An exact node
-- is identified by its head and parameter vector; a legacy occurrence-local
-- node by its display key.  The surrounding family's top-level constructor
-- inventory is still checked separately by 'constructorsEquivalent'.
schemaEquivalent :: Frag -> Frag -> Bool
schemaEquivalent = go []
 where
  go binders left right = case (left, right) of
    (FArr a b, FArr c d) -> both binders a c b d
    (FProd a b, FProd c d) -> both binders a c b d
    (FSum a b, FSum c d) -> both binders a c b d
    (FTop, FTop) -> True
    (FBot, FBot) -> True
    (FAll leftExplicit leftBinder leftBody,
        FAll rightExplicit rightBinder rightBody) ->
      leftExplicit == rightExplicit
        && go ((leftBinder, rightBinder) : binders) leftBody rightBody
    -- Instance evidence is erased before either engine sees a schema.  Pretty
    -- keys retain only diagnostics and must not split alpha-equivalent family
    -- templates whose enclosing binder spellings differ.
    (FInst _ leftBody, FInst _ rightBody) ->
      go binders leftBody rightBody
    (FExactContext leftClass leftArguments leftBody,
        FExactContext rightClass rightArguments rightBody) ->
      leftClass == rightClass
        && length leftArguments == length rightArguments
        && and (zipWith (equivalentContextArgument binders)
          leftArguments rightArguments)
        && go binders leftBody rightBody
    (FVar a, FVar b) -> equivalentName binders a b
    (FAtom _ a, FAtom _ b) -> a == b
    (FApp _ _ leftHead leftArguments,
        FApp _ _ rightHead rightArguments) ->
      equivalentHead binders leftHead rightHead
        && equivalentLists binders leftArguments rightArguments
    (FParamInd leftHead _ leftParameters _,
        FParamInd rightHead _ rightParameters _) ->
      leftHead == rightHead
        && equivalentLists binders leftParameters rightParameters
    (FInd leftKey _, FInd rightKey _) -> leftKey == rightKey
    (FParamRec _ leftHead _ leftParameters _,
        FParamRec _ rightHead _ rightParameters _) ->
      leftHead == rightHead
        && equivalentLists binders leftParameters rightParameters
    (FRec _ leftKey _ _, FRec _ rightKey _ _) -> leftKey == rightKey
    (FDepth, FDepth) -> True
    _ -> False

  both binders a c b d = go binders a c && go binders b d
  equivalentLists binders xs ys = length xs == length ys
    && and (zipWith (go binders) xs ys)
  equivalentContextArgument binders left right =
    case (exactContextNominalUse left, exactContextNominalUse right) of
      ( Just (leftHead, leftArity, leftSupplied)
        , Just (rightHead, rightArity, rightSupplied)
        ) ->
          leftArity == rightArity
            && leftHead == rightHead
            && equivalentLists binders leftSupplied rightSupplied
      (Nothing, Nothing) -> case (left, right) of
        ( ExactContextFragmentArgument leftArity leftFrag
          , ExactContextFragmentArgument rightArity rightFrag
          ) ->
            leftArity == 0
              && rightArity == 0
              && go binders leftFrag rightFrag
        _ -> False
      _ -> False
  equivalentHead binders leftHead rightHead = case (leftHead, rightHead) of
    (AppVariable leftName, AppVariable rightName) ->
      equivalentName binders leftName rightName
    (AppNominal leftName, AppNominal rightName) -> leftName == rightName
    _ -> False
  equivalentName binders leftName rightName = case lookup leftName binders of
    Just expected -> expected == rightName
    Nothing -> case lookup rightName [(right, left) | (left, right) <- binders] of
      Just _ -> False
      Nothing -> leftName == rightName

replaceConstructorFields
  :: [(Frag, Frag)]
  -> [(String, [Frag])]
  -> [(String, [Frag])]
replaceConstructorFields replacements = map
  (\(name, fields) -> (name, map (replaceFrag replacements) fields))

-- | Exact whole-fragment replacement, followed by structural descent only
-- when no parameter matches the current node.  Matching the whole node first
-- is important for higher-kinded or otherwise structured parameters: their
-- internal variables are not declaration parameters in their own right.
replaceFrag :: [(Frag, Frag)] -> Frag -> Frag
replaceFrag replacements = go Set.empty
 where
  replacementFreeVariables = Set.unions
    [ freeSchemaVariables Set.empty replacement
    | (_, replacement) <- replacements
    ]
  reservedNames = Set.unions
    [ schemaNames parameter `Set.union` schemaNames replacement
    | (parameter, replacement) <- replacements
    ]

  go shadowed frag = case
      [ replacement
      | (parameter, replacement) <- replacements
      -- A constructor-local forall may reuse an outer family parameter's
      -- spelling.  The occurrence below that binder denotes the local
      -- variable, not the family argument, so it must not be genericized.
      , Set.null
          (freeSchemaVariables Set.empty parameter `Set.intersection` shadowed)
      -- Every binder that could capture a replacement is alpha-renamed on
      -- entry below.  Retain this guard at the replacement site as a
      -- defensive invariant for fragments introduced by future constructors.
      , Set.null
          (freeSchemaVariables Set.empty replacement
            `Set.intersection` shadowed)
      , schemaEquivalent parameter frag
      ] of
    replacement : _ -> replacement
    [] -> case frag of
      FArr parameter result ->
        FArr (recur parameter) (recur result)
      FProd left right -> FProd (recur left) (recur right)
      FSum left right -> FSum (recur left) (recur right)
      FAll explicit binder body
        | binder `Set.member` replacementFreeVariables ->
            let fresh = freshBinderName
                  (reservedNames `Set.union` schemaNames body
                    `Set.union` shadowed)
                renamed = renameBoundVariable binder fresh body
            in FAll explicit fresh
                (go (Set.insert fresh shadowed) renamed)
        | otherwise ->
            FAll explicit binder (go (Set.insert binder shadowed) body)
      FInst key body -> FInst key (recur body)
      FExactContext className arguments body ->
        FExactContext className
          (map (mapExactContextArgumentFragments recur) arguments)
          (recur body)
      FApp safe key head' arguments ->
        FApp safe key head' (map recur arguments)
      FParamInd headName key parameters constructors ->
        FParamInd headName key (map recur parameters)
          (mapCtorFields shadowed constructors)
      FInd key constructors ->
        FInd key (mapCtorFields shadowed constructors)
      FParamRec complete headName key parameters constructors ->
        FParamRec complete headName key (map recur parameters)
          (mapCtorFields shadowed constructors)
      FRec complete key parameters constructors ->
        FRec complete key (map recur parameters)
          (mapCtorFields shadowed constructors)
      other -> other
   where
    recur = go shadowed

  mapCtorFields shadowed = map
    (\(name, fields) -> (name, map (go shadowed) fields))

  freshBinderName reserved = choose (0 :: Int)
   where
    choose index =
      let candidate = "\0leant-bound:" ++ show index
      in if candidate `Set.member` reserved
          then choose (index + 1)
          else candidate

-- | Every syntactic variable and binder name in a schema.  Exact nominal
-- heads and display keys live in a separate namespace and need not constrain
-- alpha-renaming.
schemaNames :: Frag -> Set.Set String
schemaNames frag = case frag of
  FArr parameter result -> descend [parameter, result]
  FProd left right -> descend [left, right]
  FSum left right -> descend [left, right]
  FAll _ binder body -> Set.insert binder (schemaNames body)
  FInst _ body -> schemaNames body
  FExactContext _ arguments body ->
    descend
      (concatMap exactContextArgumentPayloadFragments arguments ++ [body])
  FVar variableName -> Set.singleton variableName
  FApp _ _ head' arguments ->
    let headNames = case head' of
          AppVariable variableName -> Set.singleton variableName
          AppNominal _ -> Set.empty
    in headNames `Set.union` descend arguments
  FParamInd _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  FInd _ constructors -> descend (concatMap snd constructors)
  FParamRec _ _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  FRec _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  _ -> Set.empty
 where
  descend = Set.unions . map schemaNames

-- | Rename the occurrences bound by one surrounding 'FAll'.  A nested binder
-- with the same spelling shadows it and therefore stops the descent.
renameBoundVariable :: String -> String -> Frag -> Frag
renameBoundVariable old new frag = case frag of
  FArr parameter result -> FArr (go parameter) (go result)
  FProd left right -> FProd (go left) (go right)
  FSum left right -> FSum (go left) (go right)
  FAll explicit binder body
    | binder == old -> frag
    | otherwise -> FAll explicit binder (go body)
  FInst key body -> FInst key (go body)
  FExactContext className arguments body ->
    FExactContext className
      (map (mapExactContextArgumentFragments go) arguments)
      (go body)
  FVar variableName
    | variableName == old -> FVar new
    | otherwise -> frag
  FApp safe key head' arguments ->
    let renamedHead = case head' of
          AppVariable variableName
            | variableName == old -> AppVariable new
          _ -> head'
    in FApp safe key renamedHead (map go arguments)
  FParamInd headName key parameters constructors ->
    FParamInd headName key (map go parameters) (mapCtorFields constructors)
  FInd key constructors -> FInd key (mapCtorFields constructors)
  FParamRec complete headName key parameters constructors ->
    FParamRec complete headName key (map go parameters)
      (mapCtorFields constructors)
  FRec complete key parameters constructors ->
    FRec complete key (map go parameters) (mapCtorFields constructors)
  _ -> frag
 where
  go = renameBoundVariable old new
  mapCtorFields = map (\(name, fields) -> (name, map go fields))
