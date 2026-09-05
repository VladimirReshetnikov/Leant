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
  , DetailedCandidateBatch
  , detailedCandidateBatchGroups
  , detailedCandidateBatchNotes
  , DetailedSynthCursor
  , DetailedSynthCursorError (..)
  , DetailedSynthCursorStep (..)
  , startDetailedSynthCursor
  , advanceDetailedSynthCursor
  , forceDetailedSynthCursorStep
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
  , synthesizeWithProvidersSkippingDetailedWithMultiConstructorPatterns
  , synthesizeWith
  , synthesizeTuned
  , synthesizeTunedDetailed
  , forceDetailedOutcome
  , synthMaxShown
  , synthMaxTried
  , synthVerificationWindow
  , candidateWindow
  , SynthLimits (..)
  , defaultSynthLimits
  , synthVerificationWindowWith
  , synthesizeTunedDetailedWith
  , synthesizeWithProvidersSkippingDetailedWith
  , advanceDetailedSynthCursorWith
  , takeDistinct
  , takeDistinctOn
  , renderCandidateByAvailability
  , candidateQualityExpressionByAvailability
  , TranslatedPremise (..)
  , ProviderBindingInspection (..)
  , SemanticFamilyBindingInspection (..)
  , PreparedSynthesisInspection (..)
  , ExferenceRunAuthorityInspection (..)
  , inspectExferencePreparation
  , retainRequiredPrelude
  , leanNonStrictConstructorArities
  ) where

import Data.Foldable (toList)
import Data.List (intercalate, isPrefixOf, nub, nubBy, sortOn)
import Data.Bifunctor (first, second)
import Data.Maybe (catMaybes, isNothing)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Void (Void)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( CandidateRankingPolicy (..)
  , Constraint (..)
  , QueryEvidence (..)
  , QueryOptions (..)
  , QueryRequest (..)
  , Boxity (Boxed)
  , Completion (..)
  , DataConstructor (..)
  , Declaration
      ( AbstractTypeDeclaration
      , TypeSynonymDeclaration
      , ClassDeclaration
      , DataTypeDeclaration
      , InstanceDeclaration
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
  , canonicalizeType
  , candidateOutput
  , containsForall
  , declarationTypeVariables
  , declarationSubjectName
  , defaultCandidateRankingPolicy
  , defaultCandidateProviderCost
  , defaultExferenceOptions
  , defaultExferenceSessionPolicy
  , defaultQueryOptions
  , djinnSessionEnvironment
  , environmentDeclarations
  , eraseTermGraph
  , expressionSize
  , freeVariables
  , functionClauseExpression
  , mapDeclarationTypeVariables
  , maximumProviderInstantiationAssignments
  , observedListLength
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
  , selectQualityQueryResults
  , specifiedVisibleTypeArgument
  , splitLeadingForalls
  , standardDjinnSession
  , substituteTypeVariablesBatch
  , tupleName
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
  , fragChildren
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
  , fragVariableNames
  , freeFragVariables
  , freshFragBinderFrom
  , mapExactContextArgumentFragments
  , maximumProviderArgumentKindArity
  , maximumProviderExactForallDomains
  , renameFragBinder
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
-- bindings, variable identity, and pure Leant preparation stay attached so a
-- later semantic checker never has to reconstruct authority from rendered text
-- or private-name conventions. Converted provider assignments are projected
-- from those bindings and the exact name table at their run or inspection edge.
data ExferenceRunAuthority = ExferenceRunAuthority
  { exferenceAuthorityPreparation :: PreparedSemanticOrigin
  , exferenceAuthorityNameTable :: Map.Map String ExferenceLocal
  , exferenceAuthorityPolicy :: ExferenceSessionPolicy
  , exferenceAuthoritySession :: ExferenceSession
  , exferenceAuthorityRequest :: ExferenceRequest
  }

-- | Checked Exference identity retained with one originating rendered group.
--
-- The opaque typed candidate keeps its compatibility projection inseparable
-- from the exact graph and any checked certificate association which produced
-- the group, together with the full checked run which admitted it.  Rendering
-- may inspect the public bare-graph projection, but a stamped projection has
-- discarded association authority and cannot be fingerprinted independently.
-- Behavioral sealing instead consumes the whole candidate; rendering retains
-- no parallel fallible graph-key cache.
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
      && exferenceAuthorityPolicy leftAuthority
        == exferenceAuthorityPolicy rightAuthority
      && exferenceAuthorityRequest leftAuthority
        == exferenceAuthorityRequest rightAuthority

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

-- | The exact typed origin whose recorded spelling is still this variant's
-- accepted text.  A retained origin whose recorded text differs from the
-- accepted spelling is answered with 'Nothing', so a caller never associates
-- semantics with a different term.
detailedVerificationVariantExactTypedOrigin
  :: DetailedVerificationVariant
  -> Maybe ExactTypedVariantOrigin
detailedVerificationVariantExactTypedOrigin
    (DetailedVerificationVariant _ _ text exactOrigin) = case exactOrigin of
  Just retained
    | exactTypedVariantOriginText retained == text -> Just retained
  _ -> Nothing

-- | Zero-based ordinal of the origin's spelling within the Exference
-- renderer's alternative list, recorded before verification.  Handoffs use
-- it to select the same alternative when the exact renderer is re-run.
exactTypedVariantOriginOrdinal :: ExactTypedVariantOrigin -> Natural
exactTypedVariantOriginOrdinal
    (ExactTypedVariantOrigin ordinal _ _) = ordinal

exactTypedVariantOriginText :: ExactTypedVariantOrigin -> String
exactTypedVariantOriginText (ExactTypedVariantOrigin _ text _) = text

-- | The checked Exference candidate and run authority retained by the
-- origin.  This is the sidecar of the Exference candidate which produced the
-- spelling, even when a Djinn group displayed the same text first.
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
      providerMap = providerMapFromBindings
        $ semanticOriginProviderBindings origin
  either (Left . ExactTypedVariantRendererRejected) Right
    $ renderLeanTermGraphProjection
        (("x" ++) . show)
        (semanticOriginConstructorMap origin)
        providerMap
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

-- | One nonempty, ordered slice of a detailed candidate stream.  The
-- constructor stays hidden so callers cannot manufacture an empty batch or
-- detach a slice from the run-level notes produced alongside it.  Both fields
-- deliberately remain lazy: advancing a cursor chooses the slice, while the
-- caller's deadline owns forcing its search and rendering work.
data DetailedCandidateBatch = DetailedCandidateBatch
  [DetailedCandidateGroup]
  [String]

-- | Candidate groups in their original engine order.
detailedCandidateBatchGroups
  :: DetailedCandidateBatch
  -> [DetailedCandidateGroup]
detailedCandidateBatchGroups (DetailedCandidateBatch groups _) = groups

-- | Original run-level notes, unchanged for every slice of the run.
detailedCandidateBatchNotes :: DetailedCandidateBatch -> [String]
detailedCandidateBatchNotes (DetailedCandidateBatch _ notes) = notes

-- | Opaque continuation over one detailed engine outcome.  The consumed
-- count and payload are intentionally lazy.  In particular,
-- 'startDetailedSynthCursor' does not start the engine, and the successor in a
-- 'DetailedSynthCursorCandidateBatch' does not inspect the unselected stream
-- tail.
data DetailedSynthCursor = DetailedSynthCursor
  Int
  (Either String DetailedSynthOutcome)

-- | Invalid per-step batch requests.  The limit error records the maximum
-- first and the observed request second.
data DetailedSynthCursorError
  = DetailedSynthCursorBatchSizeNotPositive Int
  | DetailedSynthCursorBatchSizeLimitExceeded Int Int
  deriving (Eq, Show)

-- | One observable cursor step.  Candidate batches always contain at least
-- one group.  Exhaustion is distinguished from consuming the product-wide
-- hard cap because only the former observes an empty engine tail.
data DetailedSynthCursorStep
  = DetailedSynthCursorCandidateBatch
      DetailedCandidateBatch
      DetailedSynthCursor
  | DetailedSynthCursorNaturallyExhausted [String]
  | DetailedSynthCursorHardCapReached [String]
  | DetailedSynthCursorEngineFailed String
  | DetailedSynthCursorRefuted Bool
  | DetailedSynthCursorNoTerm [String]

-- | Wrap a detailed result without evaluating either its verdict or search.
startDetailedSynthCursor
  :: Either String DetailedSynthOutcome
  -> DetailedSynthCursor
startDetailedSynthCursor = DetailedSynthCursor 0

-- | Select the next bounded, nonempty candidate slice.  Request admission is
-- independent of the cursor: invalid sizes are rejected before even the
-- cursor constructor is demanded.  A valid request returns its outer 'Right'
-- without demanding the cursor or engine outcome; forcing the step payload
-- performs that work.
advanceDetailedSynthCursor
  :: Int
  -> DetailedSynthCursor
  -> Either DetailedSynthCursorError DetailedSynthCursorStep
advanceDetailedSynthCursor = advanceDetailedSynthCursorWith candidateWindow

-- | 'advanceDetailedSynthCursor' under a retuned hard cap on the total
-- number of candidate groups the cursor may hand out ('synthLimitWindow');
-- the cap is checked before the cursor is demanded, exactly as the default.
advanceDetailedSynthCursorWith
  :: Int
  -> Int
  -> DetailedSynthCursor
  -> Either DetailedSynthCursorError DetailedSynthCursorStep
advanceDetailedSynthCursorWith window requested cursor
  | requested <= 0 =
      Left $ DetailedSynthCursorBatchSizeNotPositive requested
  | requested > window =
      Left $ DetailedSynthCursorBatchSizeLimitExceeded
        window requested
  | otherwise = Right $ advanceValidDetailedSynthCursor window requested cursor

advanceValidDetailedSynthCursor
  :: Int
  -> Int
  -> DetailedSynthCursor
  -> DetailedSynthCursorStep
advanceValidDetailedSynthCursor window requested
    (DetailedSynthCursor consumed outcome)
  | consumed >= window = hardCapStep outcome
  | otherwise = case outcome of
      Left err -> DetailedSynthCursorEngineFailed err
      Right (DetailedSynthRefuted sound) ->
        DetailedSynthCursorRefuted sound
      Right (DetailedSynthNoTerm notes) -> DetailedSynthCursorNoTerm notes
      Right (DetailedSynthCandidates groups notes) -> case batch of
        [] -> DetailedSynthCursorNaturallyExhausted notes
        _ : _ -> DetailedSynthCursorCandidateBatch
          (DetailedCandidateBatch batch notes)
          (DetailedSynthCursor
            (consumed + length batch)
            (Right $ DetailedSynthCandidates rest notes))
       where
        (batch, rest) = splitAt remainingRequest groups
        remainingRequest = min requested (window - consumed)

-- The only reachable capped cursor follows at least one candidate batch, so
-- its payload is a locally reconstructed candidate outcome.  Keeping the
-- cases total makes the invariant robust without inspecting the candidate
-- tail in the ordinary case.
hardCapStep :: Either String DetailedSynthOutcome -> DetailedSynthCursorStep
hardCapStep outcome = case outcome of
  Right (DetailedSynthCandidates _ notes) ->
    DetailedSynthCursorHardCapReached notes
  Left err -> DetailedSynthCursorEngineFailed err
  Right (DetailedSynthRefuted sound) -> DetailedSynthCursorRefuted sound
  Right (DetailedSynthNoTerm notes) -> DetailedSynthCursorNoTerm notes

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

-- | Per-command search bounds and candidate ranking. The resource defaults
-- retain the established allowances; the ordinary lanes take their Djinn
-- candidate cutoff and choice-point budget from here, while the library and
-- classical lanes keep their own fixed budgets. Ranking changes selection
-- within those allowances, independently of verification and Length ranking.
data SynthLimits = SynthLimits
  { synthLimitShown :: !Int
    -- ^ accepted candidate groups shown and bound ('synthMaxShown')
  , synthLimitTried :: !Int
    -- ^ fresh groups verified per lane; the @both@ engine doubles it
    -- ('synthMaxTried')
  , synthLimitWindow :: !Int
    -- ^ candidate groups one lane may observe before "candidate limit
    -- reached" ('candidateWindow'); also the cursor's hard cap
  , synthLimitBudget :: !(Maybe Integer)
    -- ^ Djinn choice-point budget of the ordinary and provider lanes;
    -- 'Nothing' is unbounded
  , synthLimitQueue :: !Int
    -- ^ Exference queue bound
  , synthLimitRanking :: !CandidateRankingPolicy
    -- ^ Target-neutral candidate ordering within the same search bounds.
  }
  deriving (Eq, Show)

-- | The historical bounds: 5 shown, 12 tried, a 60-group window, no Djinn
-- budget, and an Exference queue of 1024, with balanced candidate ranking.
defaultSynthLimits :: SynthLimits
defaultSynthLimits = SynthLimits
  { synthLimitShown = synthMaxShown
  , synthLimitTried = synthMaxTried
  , synthLimitWindow = candidateWindow
  , synthLimitBudget = Nothing
  , synthLimitQueue = 1024
  , synthLimitRanking = defaultCandidateRankingPolicy
  }

-- | 'synthVerificationWindow' under retuned limits.
synthVerificationWindowWith :: SynthLimits -> SynthEngine -> Int
synthVerificationWindowWith limits engine = case engine of
  EngineBoth -> 2 * synthLimitTried limits
  EngineDjinn -> synthLimitTried limits
  EngineExference -> synthLimitTried limits

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
-- outside the guard.  Forcing the route alongside each bounded group keeps
-- search and observation provenance under the same caller-owned deadline
-- without inspecting the tail.  Exact duplicate origins stay deliberately
-- lazy: opt-in behavioral preparation pays their locally
-- 'candidateWindow'-bounded lookup instead of widening Main's established
-- synthesis work.
forceDetailedOutcome :: Int -> Either String DetailedSynthOutcome -> Int
forceDetailedOutcome n outcome = case outcome of
  Left err -> length err
  Right (DetailedSynthCandidates groups notes) ->
    detailedGroupSize (take n groups) + detailedNoteSize notes
  Right (DetailedSynthRefuted sound) -> if sound then 1 else 0
  Right (DetailedSynthNoTerm notes) -> detailedNoteSize notes

-- | Force exactly the work owned by the current cursor step.  For a
-- candidate step this is the whole selected batch and the original notes,
-- matching 'forceDetailedOutcome' while leaving semantic sidecars, the
-- successor cursor, and the unselected stream tail untouched.  Terminal
-- payloads use that same historical forcing boundary.
forceDetailedSynthCursorStep :: DetailedSynthCursorStep -> Int
forceDetailedSynthCursorStep step = case step of
  DetailedSynthCursorCandidateBatch
      (DetailedCandidateBatch groups notes) _ ->
    detailedGroupSize groups + detailedNoteSize notes
  DetailedSynthCursorNaturallyExhausted notes -> detailedNoteSize notes
  DetailedSynthCursorHardCapReached notes -> detailedNoteSize notes
  DetailedSynthCursorEngineFailed err -> length err
  DetailedSynthCursorRefuted sound -> if sound then 1 else 0
  DetailedSynthCursorNoTerm notes -> detailedNoteSize notes

detailedGroupSize :: [DetailedCandidateGroup] -> Int
detailedGroupSize = sum . map groupSize
 where
  groupSize (DetailedCandidateGroup route variants _) =
    route `seq` sum (map (length . detailedCandidateVariantText) variants)

detailedNoteSize :: [String] -> Int
detailedNoteSize = sum . map length

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

-- | Score the same source form selected for rendering. A present typed graph
-- owns this projection; its compatibility payload remains deliberately lazy.
-- The candidate handle and its authority are never reconstructed from the
-- projected expression. Exported only for focused boundary tests.
candidateQualityExpressionByAvailability
  :: (typed -> Expression local)
  -> Either absence typed
  -> compatibility
  -> (compatibility -> Expression local)
  -> Expression local
candidateQualityExpressionByAvailability erase availability compatibility fallback =
  case availability of
    Right graph -> erase graph
    Left _ -> fallback compatibility

-- | Which synthesis engine(s) a query runs (proposal F of
-- SYNTHESIS_PROPOSAL.md \167 7).  Djinn is the complete, terminating LJT
-- search with refutation verdicts; Exference is a ranked heuristic
-- search under explicit budgets, with no negative evidence.
data SynthEngine = EngineDjinn | EngineExference | EngineBoth
  deriving (Eq, Show)

-- | Parse the user-facing engine name accepted by @:set synth-engine@:
-- exactly @djinn@, @exference@, or @both@ (case-sensitive, untrimmed);
-- anything else is 'Nothing'.  Inverse of 'synthEngineName'.
parseSynthEngine :: String -> Maybe SynthEngine
parseSynthEngine value = case value of
  "djinn" -> Just EngineDjinn
  "exference" -> Just EngineExference
  "both" -> Just EngineBoth
  _ -> Nothing

-- | The user-facing engine name shown by @:set synth-engine@ with no
-- argument; 'parseSynthEngine' accepts exactly these spellings.
synthEngineName :: SynthEngine -> String
synthEngineName engine = case engine of
  EngineDjinn -> "djinn"
  EngineExference -> "exference"
  EngineBoth -> "both"

-- | Bounded live-provider widening in discovery order.  Djinn's fixed
-- candidate window can be crowded by a large environment even when a short
-- prefix contains every declaration needed for a composition.  Give it sparse
-- geometric prefixes before the complete bounded inventory: at most four
-- searches for the default eighty-provider discovery cap.  Exference keeps
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
synthesizeWithProvidersSkippingDetailed =
  synthesizeWithProvidersSkippingDetailedWith defaultSynthLimits

-- | 'synthesizeWithProvidersSkippingDetailed' under retuned limits: the
-- Djinn cutoff and choice-point budget come from the limits, as do the
-- Exference queue and candidate window.
synthesizeWithProvidersSkippingDetailedWith
  :: SynthLimits
  -> SynthEngine -> Int -> Set.Set String -> [ProviderFrag] -> Frag
  -> Either String DetailedSynthOutcome
synthesizeWithProvidersSkippingDetailedWith limits engine steps checked
    providers frag =
  runTunedSynthesis limits True engine steps
    (synthLimitWindow limits, synthLimitBudget limits)
    checked providers [] frag frag

-- | Package-private tuned counterpart used by focused boundary tests which
-- need to retain a simple checked provider graph without changing the REPL's
-- established multi-constructor search policy. Production callers use
-- 'synthesizeWithProvidersSkippingDetailed', whose policy remains enabled.
synthesizeWithProvidersSkippingDetailedWithMultiConstructorPatterns
  :: Bool
  -> SynthEngine -> Int -> Set.Set String -> [ProviderFrag] -> Frag
  -> Either String DetailedSynthOutcome
synthesizeWithProvidersSkippingDetailedWithMultiConstructorPatterns
    multiConstructorPatterns engine steps checked providers frag =
  runTunedSynthesis defaultSynthLimits
    multiConstructorPatterns engine steps (candidateWindow, Nothing)
    checked providers [] frag frag

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
synthesizeTunedDetailed = synthesizeTunedDetailedWith defaultSynthLimits

-- | 'synthesizeTunedDetailed' whose Exference queue, candidate window, and
-- @both@-mode interleave come from retuned limits; the explicit Djinn
-- cutoff/budget pair still belongs to the calling lane.
synthesizeTunedDetailedWith
  :: SynthLimits
  -> SynthEngine -> Int -> (Int, Maybe Integer) -> [(String, Frag)]
  -> Frag -> Frag -> Either String DetailedSynthOutcome
synthesizeTunedDetailedWith limits engine steps djinnLimits extras engineFrag
    fitFrag =
  runTunedSynthesis limits True engine steps djinnLimits Set.empty [] extras
    engineFrag fitFrag

-- | The one tuned search: Djinn under the lane's cutoff/budget pair,
-- Exference under the limits' step, queue, and window bounds, or both merged
-- under the limits' shown/tried interleave.
runTunedSynthesis
  :: SynthLimits
  -> Bool
  -> SynthEngine -> Int -> (Int, Maybe Integer) -> Set.Set String
  -> [ProviderFrag] -> [(String, Frag)] -> Frag -> Frag
  -> Either String DetailedSynthOutcome
runTunedSynthesis limits
    multiConstructorPatterns engine steps djinnLimits checked providers extras
    engineFrag fitFrag = case engine of
  EngineDjinn -> do
    prepared <- prepareSynthesis djinnRecursiveProjection
      providers extras engineFrag fitFrag
    let origin = preparedSemanticOrigin prepared
    outcome <- djinnRun (synthLimitRanking limits)
      Map.empty
      (synthLimitWindow limits) djinnLimits fitFrag
      (semanticOriginProjectionCompleteness origin)
      (preparedRenderExpression prepared)
      (semanticOriginSearchGoal origin)
      (semanticOriginDeclarations origin)
      (semanticOriginProviderAssignments origin)
    pure
      (withoutCheckedDetailedCandidates checked
        (detailUnobservedOutcome outcome))
  EngineExference -> do
    prepared <- prepareSynthesis exferenceRecursiveProjection
      providers extras engineFrag fitFrag
    outcome <- exferenceRun limits multiConstructorPatterns steps prepared
    pure (withoutCheckedDetailedCandidates checked outcome)
  EngineBoth -> do
    djinnPrepared <- prepareSynthesis djinnRecursiveProjection
      providers extras engineFrag fitFrag
    let djinnOrigin = preparedSemanticOrigin djinnPrepared
    djinnCompatibility <- djinnRun (synthLimitRanking limits)
      Map.empty
      (synthLimitWindow limits) djinnLimits fitFrag
      (semanticOriginProjectionCompleteness djinnOrigin)
      (preparedRenderExpression djinnPrepared)
      (semanticOriginSearchGoal djinnOrigin)
      (semanticOriginDeclarations djinnOrigin)
      (semanticOriginProviderAssignments djinnOrigin)
    let djinn = detailUnobservedOutcome djinnCompatibility
    exferencePrepared <- prepareSynthesis exferenceRecursiveProjection
      providers extras engineFrag fitFrag
    exference <- exferenceRun limits multiConstructorPatterns steps
      exferencePrepared
    pure (mergeDetailedOutcomesSkippingWith limits checked djinn exference)

-- | Prepare one engine-specific translation without erasing which goal came
-- from the source fragment and which goal search actually receives. Premise
-- insertion and rendering share the same named layout. Provider renderer
-- metadata remains attached to the binding which introduced its private name;
-- constructor and type maps remain attached to their declarations. This is
-- the stable seam for later semantic interpretation.
prepareSynthesis
  :: RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Frag
  -> Either String PreparedSynthesis
prepareSynthesis recursiveProjection activeProviders extras engineFrag fitFrag = do
  translation <- prepareProviderGroundFactTranslation
    recursiveProjection activeProviders extras engineFrag
  let sourceGoal = translationSourceGoal translation
      draftProviderBindings = translationProviderBindings translation
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
  (providerBindings, providerDeclarations) <-
    providerDeclarationsFromBindings
      (translationDeclarations translation) draftProviderBindings
  let declarations =
        translationDeclarations translation ++ providerDeclarations
      providerMap = providerMapFromBindings providerBindings
      semanticOrigin = PreparedSemanticOrigin
        { semanticOriginEngineFragment = engineFrag
        , semanticOriginFitFragment = fitFrag
        , semanticOriginSourceGoal = sourceGoal
        , semanticOriginSearchGoal = searchGoal
        , semanticOriginDeclarations = declarations
        , semanticOriginProviderBindings = providerBindings
        , semanticOriginSemanticFamilyBindings =
            translationSemanticFamilyBindings translation
        , semanticOriginConstructorMap = translationConstructorMap translation
        , semanticOriginTypeMap = translationTypeMap translation
        , semanticOriginPremiseLayout = premiseLayout
        , semanticOriginProjectionCompleteness =
            translationProjectionCompleteness translation
        }
      renderPremiseLayout = premiseLayoutForRenderer
        $ semanticOriginPremiseLayout semanticOrigin
      render expr =
        renderLeanTerm
          (semanticOriginConstructorMap semanticOrigin)
          providerMap
          (semanticOriginTypeMap semanticOrigin)
          renderPremiseLayout
          (semanticOriginFitFragment semanticOrigin) expr
      renderGraph
        :: TermGraph ExferenceType ExferenceLocal
        -> Either String [String]
      renderGraph graph =
        renderLeanTermGraphProjection (("x" ++) . show)
          (semanticOriginConstructorMap semanticOrigin)
          providerMap
          (semanticOriginTypeMap semanticOrigin)
          renderPremiseLayout
          (semanticOriginFitFragment semanticOrigin) graph
  pure PreparedSynthesis
    { preparedSemanticOrigin = semanticOrigin
    , preparedRenderExpression = render
    , preparedRenderTermGraph = renderGraph
    }

-- | Resolve exact contextual provider fact groups as a replayed source-order
-- subsequence. The discovery pass commits no assignment-local state. Every trial
-- reruns the complete translation with only the previously accepted groups
-- plus the candidate, and the final pass reruns once more with exactly the
-- accepted set. Thus a rejected vector cannot leak declarations, names, maps,
-- or planning state, while an all-rejected provider recovers every
-- successfully translatable vector from its bounded, filtered historical
-- context-erased assignment lane.
prepareProviderGroundFactTranslation
  :: RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Either String SynthesisTranslation
prepareProviderGroundFactTranslation recursiveProjection providers extras
    engineFrag
  | not discoveryRequired = fragToDjinn
      (SelectProviderGroundFacts Set.empty)
      recursiveProjection providers extras engineFrag
  | otherwise = do
      discovery <- fragToDjinn DiscoverProviderGroundFacts
        recursiveProjection providers extras engineFrag
      selected <- choose Set.empty $ providerGroundFactKeys discovery
      fragToDjinn (SelectProviderGroundFacts selected)
        recursiveProjection providers extras engineFrag
 where
  discoveryRequired = case providerContextProjection recursiveProjection of
    EraseProviderContexts -> False
    RetainProviderContexts -> any exactContextualEvidenceProvider
      providers

  exactContextualEvidenceProvider provider = case provider of
    ProviderFragWithEvidence{} ->
      providerFragmentContainsExactContext $ providerTypeFrag provider
    _ -> False

  choose selected [] = Right selected
  choose selected (key : remaining) =
    let candidate = Set.insert key selected
    in case fragToDjinn (SelectProviderGroundFacts candidate)
        recursiveProjection providers extras engineFrag of
      Left _ -> choose selected remaining
      Right replay -> do
        accepted <- trialProviderGroundFactSelection candidate replay
        choose (if accepted then candidate else selected) remaining

-- | LJT search with bounded higher-rank extensions: candidates, or a
-- refutation whose soundness depends on the translation having hidden nothing.
djinnRun
  :: CandidateRankingPolicy
  -> Map.Map Name Natural
  -> Int
  -> (Int, Maybe Integer)
  -> Frag
  -> ProjectionCompleteness
  -> (Expression String -> Either String [String])
  -> Type String
  -> [DjinnDecl]
  -> [KindedProviderInstantiationAssignment String]
  -> Either String SynthOutcome
djinnRun ranking providerCosts window (cutoff, budget) frag projection render goal decls
    instantiations = do
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
            , optionRanking = ranking
            , optionProviderCosts = providerCosts
            }
        }
  request <- viaDiagnostic (mkDjinnRequest query)
  result <- viaDiagnostic
    (runDjinnQueryWithKindedInstantiationAssignments
      session instantiations request)
  let batch = resultSearch result
      notes = progressNotesWith window (batchProgress batch)
      -- Preserve Leant's historical size tie-break only in legacy mode.
      -- Structural policies already selected and ordered the checked Djex
      -- candidates before the result cutoff; sorting again here would erase
      -- their elimination, provider-cost, and diversity preferences.
      rendered =
        [ (expressionSize expr, group)
        | candidate <- take cutoff (batchCandidates batch)
        , let expr = functionClauseExpression (candidateOutput candidate)
        , Right group <- [render expr]
        ]
      terms = map snd $ case ranking of
        LegacyCandidateRanking -> sortOn fst rendered
        StructuralCandidateRanking _ -> rendered
  pure $ case resultEvidence result of
    ValidatedCandidates -> SynthCandidates terms notes
    ProvedUninhabitable
      | not (projectionFamiliesComplete projection) -> SynthNoTerm
          ("an exact Lean family stayed opaque because its constructor schema \
           \was ambiguous or incompatible" : notes)
      | otherwise ->
          SynthRefuted
            ( isNothing budget
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
  :: SynthLimits
  -> Bool
  -> Int
  -> PreparedSynthesis
  -> Either String DetailedSynthOutcome
exferenceRun limits multiConstructorPatterns steps prepared = do
  standard <- viaDiagnostic standardDjinnSession
  let semanticOrigin = preparedSemanticOrigin prepared
      render = preparedRenderExpression prepared
      renderGraph = preparedRenderTermGraph prepared
      goal = semanticOriginSearchGoal semanticOrigin
      decls = semanticOriginDeclarations semanticOrigin
      instantiations = semanticOriginProviderAssignments semanticOrigin
      standardDecls = environmentDeclarations (djinnSessionEnvironment standard)
      allDecls = standardDecls ++ decls
      requiredTypes = goal :
        [ argument
        | assignment <- instantiations
        , (_, argument) <- kindedProviderInstantiationAssignmentArguments assignment
        ]
      focusedDecls = retainRequiredPrelude standardDecls decls requiredTypes ++ decls
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
  let convertedInstantiations = convertProviderAssignments table instantiations
      -- A foreign inventory is intentionally ordered by Lean-side relevance.
      -- Increasing penalties retain more fallback providers without allowing
      -- them to drown the first exact/short provider in combinatorial terms.
      -- These positional search ratings are separate from structural prices:
      -- charging them again for each provider occurrence would count the
      -- existing relevance penalty twice and disfavor necessary repeated use.
      providerRatings = semanticOriginProviderRatings semanticOrigin
      policy = defaultExferenceSessionPolicy
        { exferenceRatingOverrides = providerRatings }
      prepareSession activeDeclarations = do
        constructorArities <- leanNonStrictConstructorArities
          (semanticOriginConstructorMap semanticOrigin) activeDeclarations
        let activePolicy = policy
              { exferenceNonStrictConstructors = constructorArities }
        environment <- viaShow $ mkEnvironment
          (map (mapDeclarationTypeVariables convert) activeDeclarations)
        activeSession <- viaDiagnostic
          (mkExferenceSessionWithPolicy activePolicy environment)
        pure (activePolicy, activeSession)
  session <- prepareSession allDecls
  targetName <- viaShow (mkIdentifier "leantSynth")
  target <- viaShow (mkDefinitionName targetName)
  let runLane (activePolicy, activeSession) useMultiConstructorPatterns allowUnused = do
        let query = QueryRequest
              { requestTarget = target
              , requestGoal = fmap convert goal
              , requestContexts = []
              , requestOptions = defaultExferenceOptions
                  { exferenceAllowUnused = allowUnused
                  , exferenceMaximumSteps = steps
                  , exferenceCandidateRanking = synthLimitRanking limits
                  , exferenceProviderCosts = Map.empty
                  , exferenceMultiConstructorPatterns =
                      useMultiConstructorPatterns
                    -- the queue is the memory hog; a modest bound keeps the
                    -- search interactive on small machines, reported honestly
                    -- as pruning
                  , exferenceMaximumQueueSize = Just (synthLimitQueue limits)
                  }
              }
        request <- viaDiagnostic (mkExferenceRequest query)
        let authority = ExferenceRunAuthority
              { exferenceAuthorityPreparation = semanticOrigin
              , exferenceAuthorityNameTable = table
              , exferenceAuthorityPolicy = activePolicy
              , exferenceAuthoritySession = activeSession
              , exferenceAuthorityRequest = request
              }
        results <- viaDiagnostic
          (runExferenceTypedQueryWithKindedInstantiationAssignments activeSession
            convertedInstantiations request)
        let selection = case synthLimitRanking limits of
              LegacyCandidateRanking ->
                selectQueryResults SelectAll (const (0 :: Int))
                  (const True) results
              ranking@StructuralCandidateRanking{} ->
                selectQualityQueryResults (synthLimitWindow limits) ranking
                  defaultCandidateProviderCost
                  (\candidate -> candidateQualityExpressionByAvailability
                    eraseTermGraph (typedCandidateTermGraph candidate)
                    (typedCandidateCompatibility candidate)
                    (functionClauseExpression . candidateOutput))
                  (const True) results
            -- Quality selection has already charged every raw observation,
            -- including failures and normalized duplicates, before ranking
            -- its finite pool. Rendering and textual deduplication can only
            -- shrink that pool. Legacy mode retains its historical distinct
            -- rendered-group window without changing its search prefix.
            groups = takeDistinctOn detailedCandidateGroupVariants
              (synthLimitWindow limits)
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
            notes = maybe [] (progressNotesWith (synthLimitWindow limits))
              (selectionProgress selection)
        pure (groups, notes)
      runPatternLanes activeSession useMultiConstructorPatterns = do
        (strictGroups, strictNotes) <- runLane activeSession useMultiConstructorPatterns False
        if not (null strictGroups)
          then pure $ DetailedSynthCandidates strictGroups strictNotes
          else do
            -- Exference normally prefers terms which use every introduced
            -- binder. Retry without that preference only when the strict lane
            -- produced no term, retaining established successful prefixes.
            (relaxedGroups, relaxedNotes) <- runLane activeSession useMultiConstructorPatterns True
            pure $ if null relaxedGroups
              then DetailedSynthNoTerm (nub $ strictNotes ++ relaxedNotes)
              else DetailedSynthCandidates relaxedGroups relaxedNotes
      runSession activeSession = do
        primary <- runPatternLanes activeSession multiConstructorPatterns
        case primary of
          DetailedSynthNoTerm primaryNotes | multiConstructorPatterns -> do
            -- Splitting every available sum can consume the queue before a
            -- simple polymorphic result is introduced. Retain the same checked
            -- environment while omitting those optional eliminations.
            fallback <- runPatternLanes activeSession False
            pure $ case fallback of
              DetailedSynthNoTerm fallbackNotes ->
                DetailedSynthNoTerm (nub $ primaryNotes ++ fallbackNotes)
              _ -> fallback
          _ -> pure primary
  primary <- runSession session
  case primary of
    DetailedSynthNoTerm primaryNotes
      | length focusedDecls < length allDecls -> do
          -- Even an unrelated stock datatype such as Maybe competes with
          -- constructing a polymorphic argument under successive forall
          -- layers. Preserve every successful historical prefix; only an
          -- exhausted search retries with the prelude dependencies actually
          -- mentioned by the goal, exact assignments, and retained providers.
          -- Keep the original variable table and ratings, and seal this
          -- smaller checked inventory into the fallback candidate authority.
          focusedSession <- prepareSession focusedDecls
          fallback <- runSession focusedSession
          pure $ case fallback of
            DetailedSynthNoTerm fallbackNotes ->
              DetailedSynthNoTerm (nub $ primaryNotes ++ fallbackNotes)
            _ -> fallback
    _ -> pure primary

-- | Exact constructor reduction authority for this Lean target. A private
-- datatype contributes only constructors present in the translation's own
-- renderer map with the same field arity. Lean constructor fields are total;
-- this target fact is explicit policy rather than an inference about Haskell
-- strictness from a neutral declaration. The receiving Exference session
-- checks every name and arity again against its prepared datatype inventory.
--
-- Canonical sums use the translator's intrinsic Either identity instead of
-- private renderer entries. Their real declaration must have the complete
-- binary-sum shape; the constructor names come from that declaration. Boxed
-- tuples already carry intrinsic arity authority in the shared normalizer.
-- Recompute this view for a pruned session so removed prelude constructors
-- never remain authorized. Exported only for focused boundary tests.
leanNonStrictConstructorArities
  :: CtorMap -> [DjinnDecl] -> Either String (Map.Map Name Natural)
leanNonStrictConstructorArities constructorMap declarations = do
  sumType <- leanSumTypeName
  entries <- concat <$> mapM (declarationEntries sumType) declarations
  let arities = Map.fromList entries
  if Map.size arities == length entries
    then Right arities
    else Left "duplicate constructor in Lean reduction authority"
 where
  declarationEntries sumType declaration = case declaration of
    DataTypeDeclaration _ typeName parameters constructors
      | typeName == sumType -> case (parameters, constructors) of
          ([TypeParameter left _, TypeParameter right _], [inLeft, inRight])
            | left /= right
            , constructorFields inLeft == [TypeVariable left]
            , constructorFields inRight == [TypeVariable right] ->
                Right [(constructorName inLeft, 1), (constructorName inRight, 1)]
          _ -> Left "canonical Lean sum declaration has an incompatible constructor shape"
      | otherwise -> catMaybes <$> mapM mappedConstructor constructors
    _ -> Right []

  mappedConstructor constructor = case exactRendererInfo of
    Nothing -> Right Nothing
    Just info
      | length (ciFields info) == length (constructorFields constructor) ->
          Right $ Just (constructorName constructor,
            fromIntegral $ length $ constructorFields constructor)
      | otherwise -> Left "Lean constructor reduction authority disagrees with its renderer"
   where
    -- Renderer keys are generated unqualified identifiers. nameSpelling alone
    -- drops a module qualifier, which must never let an unrelated constructor
    -- borrow a private constructor's target-language authority.
    exactRendererInfo = do
      spelling <- nameSpelling (constructorName constructor)
      case mkIdentifier spelling of
        Right privateName | privateName == constructorName constructor ->
          Map.lookup spelling constructorMap
        _ -> Nothing

-- The intrinsic family identity used by both fragment translation and its
-- constructor-reduction authority. No constructor spelling is inferred here.
leanSumTypeName :: Either String Name
leanSumTypeName = viaShow (mkIdentifier "Either")

-- Retain a transitive dependency closure of the historical prelude. Foreign
-- declarations are all kept: this fallback never drops a discovered provider,
-- caller premise, exact class/instance, or constructor family from Lean.
-- Exported only for the executable's focused dependency-boundary tests.
retainRequiredPrelude
  :: [Declaration variable kind annotation]
  -> [Declaration variable kind annotation]
  -> [Type variable]
  -> [Declaration variable kind annotation]
retainRequiredPrelude prelude foreignDeclarations requiredTypes =
  close $ Set.unions
    (map typeReferences requiredTypes ++ map declarationReferences foreignDeclarations)
 where
  close required =
    let retained = filter ((`Set.member` required) . declarationSubjectName) prelude
        expanded = required `Set.union` Set.unions (map declarationReferences retained)
    in if expanded == required then retained else close expanded
  declarationReferences declaration = case declaration of
    TypeSynonymDeclaration _ _ _ body -> typeReferences body
    DataTypeDeclaration _ _ _ constructors -> Set.unions
      [ typeReferences field
      | constructor <- constructors
      , field <- constructorFields constructor
      ]
    AbstractTypeDeclaration{} -> Set.empty
    ValueDeclaration signature -> typeReferences (valueType signature)
    ClassDeclaration _ _ _ contexts methods -> Set.unions
      (map contextReferences contexts ++ map (typeReferences . valueType) methods)
    InstanceDeclaration _ _ contexts headContext ->
      Set.unions (map contextReferences (headContext : contexts))
  contextReferences (Constraint className arguments) =
    Set.insert className (Set.unions (map typeReferences arguments))
  typeReferences source = case source of
    TypeVariable{} -> Set.empty
    TypeConstructor name -> Set.singleton name
    TypeApplication function argument ->
      typeReferences function `Set.union` typeReferences argument
    FunctionType domain result ->
      typeReferences domain `Set.union` typeReferences result
    TupleType boxity elements ->
      let elementNames = Set.unions (map typeReferences elements)
      in case tupleName boxity (length elements) of
          Right tuple -> Set.insert tuple elementNames
          Left _ -> elementNames
    ForallType _ contexts body -> Set.unions
      (typeReferences body : map contextReferences contexts)

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
mergeDetailedCandidateGroups = mergeDetailedCandidateGroupsWith defaultSynthLimits

-- | 'mergeDetailedCandidateGroups' interleaving under retuned shown/tried
-- bounds.
mergeDetailedCandidateGroupsWith
  :: SynthLimits
  -> [DetailedCandidateGroup]
  -> [DetailedCandidateGroup]
  -> [DetailedCandidateGroup]
mergeDetailedCandidateGroupsWith limits djinnGroups exferenceGroups =
  djinnHead (synthLimitShown limits - 1) Set.empty
    (map (retainExactExferenceVariantOrigins exferenceGroups) djinnGroups)
    exferenceGroups
 where
  djinnHead remaining seen djinn exference
    | remaining <= 0 =
        exferenceFront (synthLimitTried limits) seen djinn exference
    | otherwise = case nextFresh seen djinn of
        Just (group, seen', djinn') ->
          group : djinnHead (remaining - 1) seen' djinn' exference
        Nothing -> drain seen exference

  exferenceFront remaining seen djinn exference
    | remaining <= 0 = djinnFront
        (synthLimitTried limits - (synthLimitShown limits - 1)) seen djinn
        exference
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
-- the transformation stays lazy so 'forceDetailedOutcome' can pull the first bounded
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
mergeDetailedOutcomesSkipping = mergeDetailedOutcomesSkippingWith defaultSynthLimits

-- | 'mergeDetailedOutcomesSkipping' under retuned shown/tried bounds.
mergeDetailedOutcomesSkippingWith
  :: SynthLimits
  -> Set.Set String
  -> DetailedSynthOutcome
  -> DetailedSynthOutcome
  -> DetailedSynthOutcome
mergeDetailedOutcomesSkippingWith limits checked djinn0 exference0 =
  case (djinn, exference) of
    (DetailedSynthCandidates a na, DetailedSynthCandidates b nb) ->
      DetailedSynthCandidates
        (mergeDetailedCandidateGroupsWith limits a b) (na ++ tag nb)
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
        (mergeDetailedCandidateGroupsWith limits groups []) notes
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

-- | Human-readable notes for one engine progress report, naming the
-- candidate window in its cap note.
progressNotesWith :: Int -> Progress -> [String]
progressNotesWith window progress = case progress of
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
      "candidate limit reached (" ++ show window ++ ")"
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
    -- ^ Context-free specialization hints passed to Djex's historical
    -- provider-assignment adapter. Contextual Exference providers with an
    -- accepted fact group keep this empty. With no accepted group, an exact-
    -- evidence provider instead retains its successfully translated bounded
    -- fallback vectors here under a context-erased scheme.
  , providerBindingTranslatedAssignmentKeys :: [(Int, Int)]
    -- ^ Source keys of exact contextual vectors whose complete assignment
    -- translation succeeded in this pass. This internal replay witness keeps
    -- later clean passes from allowing a failed vector to affect claims,
    -- family planning, rigidity, or final renderer metadata.
  , providerBindingGroundConstraintGroups ::
      [ProviderGroundConstraintGroup]
    -- ^ Resolver-ground facts projected only from exact active-instance-
    -- closure vectors. They remain provider-local here solely to preserve
    -- source order before the complete inventory projection deduplicates them.
  }
  deriving (Eq, Show)

-- | One successfully translated exact vector, before deciding whether its
-- leading contextual obligations are resolver facts or historical assignment
-- hints. Translation failures never construct this value.
data ProviderTranslatedAssignment = ProviderTranslatedAssignment
  { providerTranslatedInstantiation ::
      KindedProviderInstantiationAssignment String
  , providerTranslatedRenderInfo :: ProviderAssignmentInfo
  }
  deriving (Eq, Show)

-- | One structurally resolver-eligible vector and its all-or-none ground fact
-- group. Keeping the translated assignment beside the group lets the final
-- inventory seal retain rendering authority for exactly the vectors it
-- accepted, including duplicate groups with distinct Lean-domain metadata.
data ProviderGroundConstraintGroup = ProviderGroundConstraintGroup
  { providerGroundConstraintKey :: (Int, Int)
  , providerGroundConstraintAssignment :: ProviderTranslatedAssignment
  , providerGroundConstraints :: [Constraint (Type String)]
  }
  deriving (Eq, Show)

-- | Whether one complete translation is discovering structurally eligible
-- fact groups or retaining an already trial-sealed subset. Discovery never
-- commits assignment-local translation state. Selection reruns the complete
-- translation so rejected vectors cannot leave declarations or renderer maps
-- behind, while an exact-evidence provider with no selected group takes its
-- exact historical context-erased assignment path.
data ProviderGroundFactMode
  = DiscoverProviderGroundFacts
  | SelectProviderGroundFacts (Set.Set (Int, Int))

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

-- | Derive the declaration projection in binding order. Provider bindings are
-- the sole prepared owner of the private identity and translated scheme.
-- Provider values retain their historical contiguous source order. Exact
-- ground instance facts follow in first provider/vector/constraint order and
-- are stably deduplicated. Once installed, those facts intentionally belong to
-- the whole top-level Exference inventory: Lean discovered them in the global
-- environment, so a fact first witnessed through one provider may discharge
-- the same ground obligation on another provider in this bounded snapshot.
providerDeclarationsFromBindings
  :: [DjinnDecl]
  -> [ProviderBinding]
  -> Either String ([ProviderBinding], [DjinnDecl])
providerDeclarationsFromBindings baseDeclarations bindings = do
  standard <- case constraintGroups of
    [] -> Right Nothing
    _ -> Just <$> viaDiagnostic standardDjinnSession
  let fixedDeclarations = maybe []
        (environmentDeclarations . djinnSessionEnvironment) standard
        ++ baseDeclarations ++ valueDeclarations
      initiallySeen = Set.fromList
        [ constraint
        | InstanceDeclaration _ _ _ constraint <- fixedDeclarations
        ]
      acceptedConstraints = stableNovel initiallySeen
        $ concatMap snd constraintGroups
  pure (bindings, valueDeclarations
    ++ [ InstanceDeclaration () [] [] constraint
       | constraint <- acceptedConstraints
       ])
 where
  valueDeclarations = map providerBindingDeclaration bindings
  constraintGroups =
    [ (providerGroundConstraintKey group, providerGroundConstraints group)
    | binding <- bindings
    , group <- providerBindingGroundConstraintGroups binding
    ]

  stableNovel = go
   where
    go _ [] = []
    go seen (constraint : remaining)
      | constraint `Set.member` seen = go seen remaining
      | otherwise = constraint
          : go (Set.insert constraint seen) remaining

providerGroundFactKeys :: SynthesisTranslation -> [(Int, Int)]
providerGroundFactKeys translation =
  [ providerGroundConstraintKey group
  | binding <- translationProviderBindings translation
  , group <- providerBindingGroundConstraintGroups binding
  ]

-- | Exact contextual vector keys which survived complete assignment
-- translation in one pass. Ground eligibility is deliberately independent:
-- a successful non-ground vector still belongs to the historical fallback
-- lane if this provider ultimately has no accepted fact group.
providerSuccessfulExactContextualAssignmentKeys
  :: SynthesisTranslation
  -> Set.Set (Int, Int)
providerSuccessfulExactContextualAssignmentKeys translation = Set.fromList
  [ key
  | binding <- translationProviderBindings translation
  , exactContextualEvidenceSource $ providerBindingSource binding
  , key <- providerBindingTranslatedAssignmentKeys binding
  ]
 where
  exactContextualEvidenceSource provider = case provider of
    ProviderFragWithEvidence{} ->
      providerFragmentContainsExactContext $ providerTypeFrag provider
    _ -> False

-- | Check one replayed source-order subsequence selection through the exact
-- Exference environment/session boundary. A selected vector must still be
-- present after the clean replay; otherwise the trial fails closed. Ordinary
-- environment or session rejection drops only the candidate group, while a
-- failure to construct the package's standard session remains a preparation
-- error as before.
trialProviderGroundFactSelection
  :: Set.Set (Int, Int)
  -> SynthesisTranslation
  -> Either String Bool
trialProviderGroundFactSelection selected translation
  | not (selected `Set.isSubsetOf` retainedKeys) = Right False
  | otherwise = do
      standard <- viaDiagnostic standardDjinnSession
      (_, providerDeclarations) <- providerDeclarationsFromBindings
        (translationDeclarations translation)
        (translationProviderBindings translation)
      let allDeclarations =
            environmentDeclarations (djinnSessionEnvironment standard)
              ++ translationDeclarations translation
              ++ providerDeclarations
          variables = nub
            $ concatMap declarationTypeVariables allDeclarations
          table = Map.fromList $ zip variables [0 :: Int ..]
          convert sourceVariable = FlexibleVariable $ table Map.! sourceVariable
          convertedDeclarations = map
            (mapDeclarationTypeVariables convert) allDeclarations
      pure $ case mkEnvironment convertedDeclarations of
        Left _ -> False
        Right environment -> case mkExferenceSessionWithPolicy
            defaultExferenceSessionPolicy environment of
          Left _ -> False
          Right _ -> True
 where
  retainedKeys = Set.fromList $ providerGroundFactKeys translation


-- | Derive the exact renderer index from its retained provider bindings.
-- 'Map.fromList' preserves the historical ascending-key index and last-wins
-- behavior for any repeated private spelling while forcing each mapped
-- 'ProviderInfo' to the same weak-head-normal-form boundary as before.
providerMapFromBindings :: [ProviderBinding] -> ProviderMap
providerMapFromBindings bindings = Map.fromList
  [ ( providerBindingPrivateSpelling binding
    , providerBindingRenderInfo binding
    )
  | binding <- bindings
  ]

-- | Complete pure output of fragment translation, before search-only premises
-- are inserted around the source goal. Provider bindings are the sole owner
-- of their ordered canonical source-domain instantiation assignments and
-- of the declaration and renderer metadata projected from them, so future
-- consumers do not have to recover source identity from a private spelling.
data SynthesisTranslation = SynthesisTranslation
  { translationSourceGoal :: Type String
  , translationDeclarations :: [DjinnDecl]
  , translationProviderBindings :: [ProviderBinding]
  , translationSemanticFamilyBindings :: [SemanticFamilyBinding]
  , translationConstructorMap :: CtorMap
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

-- | One prepared lane. A single comparable semantic origin owns every pure
-- preparation field consumed by search, rendering, and later exact-origin
-- handoff. Only the two output renderer closures live beside that authority.
data PreparedSynthesis = PreparedSynthesis
  { preparedSemanticOrigin :: PreparedSemanticOrigin
  , preparedRenderExpression ::
      Expression String -> Either String [String]
  , preparedRenderTermGraph ::
      TermGraph ExferenceType ExferenceLocal -> Either String [String]
  }

-- | Pure, comparable preparation authority shared by search and rendering,
-- then retained after the renderer functions have served their output-only
-- role. Both source fragments remain explicit: equality of engine and fitting
-- targets is a future semantic precondition, never something reconstructed
-- from their translated goals. Provider bindings remain the sole owner of
-- private declaration inputs and renderer metadata; their historical
-- declaration and map views are derived only at the edges which consume them.
data PreparedSemanticOrigin = PreparedSemanticOrigin
  { semanticOriginEngineFragment :: Frag
  , semanticOriginFitFragment :: Frag
  , semanticOriginSourceGoal :: Type String
  , semanticOriginSearchGoal :: Type String
  , semanticOriginDeclarations :: [DjinnDecl]
  , semanticOriginProviderBindings :: [ProviderBinding]
  , semanticOriginSemanticFamilyBindings :: [SemanticFamilyBinding]
  , semanticOriginConstructorMap :: CtorMap
  , semanticOriginTypeMap :: TypeMap
  , semanticOriginPremiseLayout :: PremiseLayout
  , semanticOriginProjectionCompleteness :: ProjectionCompleteness
  }
  deriving (Eq, Show)

-- | Exact search-order projection of source-domain canonical assignments from
-- their sole prepared owner. Provider order and each provider-local assignment
-- order are retained verbatim; the aggregate list is never cached beside the
-- bindings. The Exference-domain view is likewise derived instead of retained.
semanticOriginProviderAssignments
  :: PreparedSemanticOrigin
  -> [KindedProviderInstantiationAssignment String]
semanticOriginProviderAssignments =
  concatMap providerBindingAssignments . semanticOriginProviderBindings

-- | Exference's established positional search ratings, keyed by the same
-- private identities which own declarations and assignment evidence. These
-- are source priorities, not structural provider prices. Both engines use
-- the shared default structural prices (named values one, constructors zero),
-- while provider encounter order and this Exference rating remain unchanged.
semanticOriginProviderRatings
  :: PreparedSemanticOrigin -> Map.Map Name Penalty
semanticOriginProviderRatings origin = Map.fromList $ zip
  (map providerBindingPrivateName $ semanticOriginProviderBindings origin)
  (map (Penalty . fromIntegral) [0 :: Natural, 20 ..])

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
  -- Compatibility view derived lazily from the retained preparation and
  -- name table; the run authority keeps no parallel converted source goal.
  , inspectedAuthorityConvertedSourceGoal :: ExferenceType
  , inspectedAuthorityPolicy :: ExferenceSessionPolicy
  , inspectedAuthorityRequest ::
      QueryRequest ExferenceType ExferenceOptions
  -- Compatibility view derived lazily from the retained provider bindings and
  -- exact name table; the run authority keeps no parallel converted list.
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
      convertedSourceGoalFromAuthority authority
  , inspectedAuthorityPolicy = exferenceAuthorityPolicy authority
  , inspectedAuthorityRequest = exferenceRequestQuery
      $ exferenceAuthorityRequest authority
  , inspectedAuthorityProviderAssignments =
      convertedProviderAssignmentsFromAuthority authority
  , inspectedAuthorityInventory = exferenceSessionInventory
      $ exferenceAuthoritySession authority
  }

convertedSourceGoalFromAuthority
  :: ExferenceRunAuthority
  -> ExferenceType
convertedSourceGoalFromAuthority authority = fmap convert
  $ semanticOriginSourceGoal $ exferenceAuthorityPreparation authority
 where
  convert sourceVariable = FlexibleVariable
    $ exferenceAuthorityNameTable authority Map.! sourceVariable

convertedProviderAssignmentsFromAuthority
  :: ExferenceRunAuthority
  -> [KindedProviderInstantiationAssignment ExferenceTypeVariable]
convertedProviderAssignmentsFromAuthority authority =
  convertProviderAssignments
    (exferenceAuthorityNameTable authority)
    (semanticOriginProviderAssignments
      $ exferenceAuthorityPreparation authority)

-- | Convert one exact source-domain assignment projection through the table
-- built from every declaration, goal, and provider-assignment variable in this
-- lane. Mapping remains lazy in the assignment spine and argument types, and
-- is total under that complete-table construction invariant. The private
-- partial lookup deliberately retains the historical variable-demand behavior
-- if an internal caller ever violates the invariant.
convertProviderAssignments
  :: Map.Map String ExferenceLocal
  -> [KindedProviderInstantiationAssignment String]
  -> [KindedProviderInstantiationAssignment ExferenceTypeVariable]
convertProviderAssignments table assignments =
  [ KindedProviderInstantiationAssignment
      { kindedProviderInstantiationAssignmentProvider = provider
      , kindedProviderInstantiationAssignmentArguments =
          [ (kind, fmap convertVariable argument)
          | (kind, argument) <- arguments
          ]
      }
  | KindedProviderInstantiationAssignment
      { kindedProviderInstantiationAssignmentProvider = provider
      , kindedProviderInstantiationAssignmentArguments = arguments
      } <- assignments
  ]
 where
  convertVariable sourceVariable = FlexibleVariable
    $ table Map.! sourceVariable

inspectPreparedSemanticOrigin
  :: PreparedSemanticOrigin
  -> PreparedSynthesisInspection
inspectPreparedSemanticOrigin origin = PreparedSynthesisInspection
  { inspectedEngineFragment = semanticOriginEngineFragment origin
  , inspectedFitFragment = semanticOriginFitFragment origin
  , inspectedSourceGoal = semanticOriginSourceGoal origin
  , inspectedSearchGoal = semanticOriginSearchGoal origin
  , inspectedDeclarations = semanticOriginDeclarations origin
  , inspectedProviderBindings = map inspectBinding providerBindings
  , inspectedSemanticFamilyBindings = map inspectSemanticFamilyBinding
      $ semanticOriginSemanticFamilyBindings origin
  , inspectedAllProviderAssignments =
      semanticOriginProviderAssignments origin
  , inspectedConstructorMap = semanticOriginConstructorMap origin
  , inspectedConstructorPrivateNames = Map.keys
      $ semanticOriginConstructorMap origin
  , inspectedProviderMap = providerMapFromBindings providerBindings
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
  providerBindings = semanticOriginProviderBindings origin
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
    | otherwise = spelling `notElem` structuralHigherKindHeads
  legacyHeadSupported spelling =
    not (null spelling)
      && spelling `notElem` structuralHigherKindHeads

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
fragExactEvidenceClaims = go Set.empty
 where
  go bound frag = case frag of
    FArr parameter result -> descend bound [parameter, result]
    FProd left right -> descend bound [left, right]
    FLeanProd left right -> descend bound [left, right]
    FSum left right -> descend bound [left, right]
    FAll _ binder body -> go (Set.insert binder bound) body
    FInst _ body -> go bound body
    FExactContext className arguments body ->
      foldl mergeExactEvidenceClaims
        (mergeExactEvidenceClaims
          (claimContextKinds className
            (map exactContextArgumentKindArity arguments))
          (go bound body))
        (map (exactContextClaim bound) arguments)
    FApp _ _ head' arguments ->
      mergeExactEvidenceClaims
        (case head' of
          AppVariable _ -> emptyExactEvidenceClaims
          AppNominal spelling -> claimFamilyArity spelling (length arguments))
        (descend bound arguments)
    FParamInd spelling _ parameters constructors ->
      mergeExactEvidenceClaims
        (claimFamilyArity spelling (length parameters))
        (descend bound (parameters ++ concatMap snd constructors))
    FInd _ constructors -> descend bound (concatMap snd constructors)
    FParamRec _ spelling _ parameters constructors ->
      mergeExactEvidenceClaims
        (claimFamilyArity spelling (length parameters))
        (descend bound (parameters ++ concatMap snd constructors))
    FRec _ _ parameters constructors ->
      descend bound (parameters ++ concatMap snd constructors)
    FDepth -> malformedExactEvidenceClaims
    _ -> emptyExactEvidenceClaims

  descend bound = foldl
    (\claims child -> mergeExactEvidenceClaims claims
      (go bound child))
    emptyExactEvidenceClaims

  exactContextClaim bound source
    | remaining < 0 = malformedExactEvidenceClaims
    | remaining == 0 = case source of
        ExactContextFragmentArgument _ argument ->
          go bound argument
        ExactContextNominalArgument{} -> malformedExactEvidenceClaims
    | otherwise = case exactContextNominalUse source of
        Just (spelling, totalArity, supplied) ->
          mergeExactEvidenceClaims
            (claimFamilyArity spelling totalArity)
            (descend bound supplied)
        Nothing -> case source of
          ExactContextFragmentArgument _ argument ->
            case boundVariableSuppliedArguments bound argument of
              Just supplied -> descend bound supplied
              Nothing -> malformedExactEvidenceClaims
          ExactContextNominalArgument{} -> malformedExactEvidenceClaims
   where
    remaining = exactContextArgumentKindArity source

  -- A scoped type-function variable is not a nominal family identity. Its
  -- already supplied proper arguments can still carry exact claims of their
  -- own, while a free or malformed variable-headed application fails closed.
  boundVariableSuppliedArguments bound argument = case argument of
    FVar variableName
      | variableName `Set.member` bound -> Just []
    FApp _ _ (AppVariable variableName) supplied
      | not (null supplied)
      , variableName `Set.member` bound -> Just supplied
    _ -> Nothing

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
  , providerContextProjection :: ProviderContextProjection
  }

-- | Engine-specific treatment of the exact provider-scheme context wire.
-- Djinn keeps its historical dictionary-erased provider schemes and assignment
-- search. Exference retains exact contexts so its checked instance inventory
-- can resolve them; legacy candidate snapshots are erased independently below
-- because their provenance never authorizes a conditional scheme.
data ProviderContextProjection
  = EraseProviderContexts
  | RetainProviderContexts

providerFragmentContainsExactContext :: Frag -> Bool
providerFragmentContainsExactContext source = case source of
  FExactContext{} -> True
  _ -> any providerFragmentContainsExactContext (fragChildren source)

djinnRecursiveProjection :: RecursiveProjection
djinnRecursiveProjection = RecursiveProjection
  { exactRecursiveData = True
  , legacyRecursiveData = False
  , providerContextProjection = EraseProviderContexts
  }

exferenceRecursiveProjection :: RecursiveProjection
exferenceRecursiveProjection = RecursiveProjection
  { exactRecursiveData = True
  , legacyRecursiveData = True
  , providerContextProjection = RetainProviderContexts
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

-- | Inspect one vector translation without committing any declarations,
-- names, or variable-table entries it introduced.  Contextual providers use
-- this only in discovery; every selected/fallback path is reconstructed by a
-- later complete translation replay.
probeMaybeT :: Trans a -> Trans (Maybe a)
probeMaybeT (Trans action) = Trans $ \state -> case action state of
  Left _ -> Right (Nothing, state)
  Right (value, _) -> Right (Just value, state)

-- | Retain one successful historical fallback vector, but restore the exact
-- incoming state if its translation fails. This is deliberately narrower than
-- discovery: a successful fallback must commit the declarations and renderer
-- identities needed by the context-erased assignment it returns.
transactionT :: Trans a -> Trans (Maybe a)
transactionT (Trans action) = Trans $ \state -> case action state of
  Left _ -> Right (Nothing, state)
  Right (value, finalState) -> Right (Just value, finalState)

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
  :: ProviderGroundFactMode
  -> RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Either String SynthesisTranslation
fragToDjinn groundFactMode recursiveProjection providers extras frag0
  | not successfulKeyReplayRequired = fragToDjinnPass Nothing
      groundFactMode recursiveProjection providers extras frag0
  | otherwise = do
      provisional <- fragToDjinnPass Nothing
        groundFactMode recursiveProjection providers extras frag0
      stabilize $ providerSuccessfulExactContextualAssignmentKeys provisional
 where
  -- Only exact-contextual Exference evidence needs this extra replay. Djinn,
  -- legacy candidates, and every context-free provider retain their historical
  -- single-pass translation and demand behavior.
  successfulKeyReplayRequired = case
      providerContextProjection recursiveProjection of
    EraseProviderContexts -> False
    RetainProviderContexts -> any exactContextualEvidenceProvider
      $ filter (not . fragHasDepth . providerTypeFrag) providers

  exactContextualEvidenceProvider provider = case provider of
    ProviderFragWithEvidence{} ->
      providerFragmentContainsExactContext $ providerTypeFrag provider
    _ -> False

  -- The whitelist can only shrink: every clean pass filters exact contextual
  -- vectors before evidence claims and family planning, then reports the keys
  -- whose complete assignment translation still succeeded. The fixed point is
  -- therefore bounded by the already capped source vector set.
  stabilize retained = do
    replay <- fragToDjinnPass (Just retained)
      groundFactMode recursiveProjection providers extras frag0
    let surviving = providerSuccessfulExactContextualAssignmentKeys replay
    if surviving == retained
      then Right replay
      else stabilize surviving

fragToDjinnPass
  :: Maybe (Set.Set (Int, Int))
  -> ProviderGroundFactMode
  -> RecursiveProjection
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Either String SynthesisTranslation
fragToDjinnPass successfulKeyFilter groundFactMode recursiveProjection
    providers extras frag0 = do
  eitherC <- leanSumTypeName
  voidC <- viaShow (mkIdentifier "Void")
  unitC <- viaShow (tupleName Boxed 0)
  pairC <- viaShow (tupleName Boxed 2)
  (translatedProduct, finalState) <- runTrans
    (translateSession eitherC voidC unitC pairC)
    TransState
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
      constructorPremises = tsPrems finalState
      familyBindings = semanticFamilyBindings
        (tsDecls finalState)
        (tsCtorMap finalState)
        (tsTypeMap finalState)
  Right SynthesisTranslation
    { translationSourceGoal = translationProductSourceGoal translatedProduct
    , translationDeclarations = tsDecls finalState
    , translationProviderBindings = providerBindings
    , translationSemanticFamilyBindings = familyBindings
    , translationConstructorMap = tsCtorMap finalState
    , translationTypeMap = tsTypeMap finalState
    , translationCallerPremises =
        translationProductCallerPremises translatedProduct
    , translationConstructorPremises = constructorPremises
    , translationProjectionCompleteness = projection
    }
 where
  -- The pure pre-translation pipeline: bound and filter provider
  -- assignment vectors, merge exact evidence claims, select query-wide
  -- family plans, and fix the rigid-atom and completeness facts that
  -- seed the translation state.
  usableProviders = filter usableProvider providers

  indexedProviders = zip [0 :: Int ..] usableProviders

  exactContextualProviderIndices = Set.fromList
    [ index
    | (index, provider) <- indexedProviders
    , exactContextualProvider provider
    ]

  assignmentRetainedForPass providerIndex vectorIndex
    | providerIndex `Set.notMember` exactContextualProviderIndices = True
    | Just successfulKeys <- successfulKeyFilter
    , (providerIndex, vectorIndex) `Set.notMember` successfulKeys = False
    | otherwise = case groundFactMode of
        DiscoverProviderGroundFacts -> True
        SelectProviderGroundFacts selected
          | selectedProviderHasGroundFacts providerIndex selected ->
              (providerIndex, vectorIndex) `Set.member` selected
          | otherwise -> True

  projectedProviderFrags =
    [ projectedProviderFrag index provider
    | (index, provider) <- indexedProviders
    ]
  -- Bound the provider-indexed assignment list before any argument
  -- fragment participates in family planning, rigidity, or translation.
  -- Keeping the index beside each complete vector preserves exact provider
  -- locality and source argument order while leaving later providers and
  -- their declarations intact.
  rawBoundedProviderAssignments =
    take maximumProviderInstantiationAssignments
      [ (providerIndex, vectorIndex, assignment)
      | (providerIndex, provider) <- indexedProviders
      , (vectorIndex, assignment) <- zip [0 :: Int ..]
          $ usableProviderAssignments provider
      ]

  passProviderAssignments =
    [ retained
    | retained@(providerIndex, vectorIndex, _) <-
        rawBoundedProviderAssignments
    , assignmentRetainedForPass providerIndex vectorIndex
    ]

  baselineEvidenceClaims = foldl
    (\claims source -> mergeExactEvidenceClaims claims
      (fragExactEvidenceClaims source))
    emptyExactEvidenceClaims
    (map snd extras ++ [frag0] ++ projectedProviderFrags)

  internallyConsistentProviderAssignments =
    [ (providerIndex, vectorIndex, assignment, claims)
    | (providerIndex, vectorIndex, assignment) <- passProviderAssignments
    , let claims = providerAssignmentExactEvidenceClaims assignment
    , exactEvidenceClaimsConsistent claims
    ]

  combinedEvidenceClaims = foldl
    (\claims (_, _, _, assignmentClaims) ->
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
    [ (providerIndex, vectorIndex, assignment)
    | (providerIndex, vectorIndex, assignment, claims) <-
        internallyConsistentProviderAssignments
    , not (claimsTouchConflicts conflictingContextNames
        conflictingFamilyNames claims)
    ]

  providerArguments = concatMap
    (\(_, _, arguments) -> arguments)
    boundedProviderAssignments

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
    map snd extras ++ [frag0] ++ projectedProviderFrags
      ++ providerAssignmentFragments

  planningRoots =
    [ (True, frag) | frag <- map snd extras ++ [frag0] ]
      ++ [ (False, providerFrag)
         | providerFrag <- projectedProviderFrags
         ]
      ++ [ (False, argument)
         | argument <- providerAssignmentPlanningFragments
         ]

  plans = exactFamilyPlans recursiveProjection
    providerAssignmentFamilyUses planningRoots

  structuralTemplateFragments =
    structuralPlanFields recursiveProjection plans

  (recursiveSelfKeys, recursiveFieldAtoms) =
    recursiveStructuralAtoms recursiveProjection plans
      (queryFragments ++ structuralTemplateFragments)

  providerAtoms = foldl collectProviderSurfaceAtoms
    Set.empty projectedProviderFrags

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

  -- The complete monadic translation session.  The four engine-side
  -- constants are threaded in because they are extracted in the Either
  -- monad before the session starts; everything else the workers need
  -- is a function argument or a sibling binding above.
  translateSession eitherC voidC unitC pairC = translate
   where
      providerArgumentType argument = case argument of
        ProviderInstantiationNominalArgument remaining spelling supplied ->
          nominalArgumentType remaining spelling supplied
        ProviderInstantiationExactArgument 0 frag _ -> go False frag
        ProviderInstantiationExactArgument {} -> failT
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
        FLeanProd a b -> (\x y -> TupleType Boxed [x, y])
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
        -- Exact provider contexts carry semantic class identity and structured
        -- arguments. They occur in supported provider-source schemes and exact
        -- assignment payloads; unlike legacy render-only FInst markers, retain
        -- them for Djex's closed contextual assignment checker.
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
              FVar spelling ->
                TypeVariable <$> variable ("v:" ++ spelling)
              FAtom _ spelling -> exactFamilyHead spelling remaining
              FApp _ _ (AppVariable spelling) supplied
                | not (null supplied) -> do
                    translated <- mapM (go False) supplied
                    headType <- TypeVariable <$> variable ("v:" ++ spelling)
                    pure (applyTypeArguments headType translated)
              FApp _ _ (AppNominal spelling) supplied -> do
                translated <- mapM (go False) supplied
                headType <- exactFamilyHead spelling
                  (length supplied + remaining)
                pure (applyTypeArguments headType translated)
              _ -> failT
                "higher-kinded exact Lean context argument retained neither \
                \a bound variable nor a nominal head"
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

      translate = do
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
                sourceProviderFrag = providerTypeFrag provider
                providerFrag = projectedProviderFrag index provider
                binderNames = case provider of
                  ProviderFrag{} -> Nothing
                  ProviderFragWithBinders
                      { providerTypeBinderNames = names } -> Just names
                  ProviderFragWithEvidence
                      { providerTypeBinderNames = names } -> Just names
                  ProviderFragWithLegacyCandidates
                      { providerTypeBinderNames = names } -> Just names
                exactContextual = exactContextualProvider provider
                providerHasSelectedFacts = case groundFactMode of
                  DiscoverProviderGroundFacts -> False
                  SelectProviderGroundFacts selected ->
                    selectedProviderHasGroundFacts index selected
            privateName <- nameT ("leantProvider" ++ show index)
            providerType <- go False providerFrag
            let assignmentVectors =
                  [ (vectorIndex, assignment)
                  | (providerIndex, vectorIndex, assignment) <-
                      boundedProviderAssignments
                  , providerIndex == index
                  ]
                translateAssignment arguments = do
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
                    , map (snd . fst) translatedArguments
                    )
            translatedAssignments <- case
                (exactContextual, groundFactMode, providerHasSelectedFacts) of
              (True, DiscoverProviderGroundFacts, _) -> do
                discovered <- mapM
                  (\(vectorIndex, arguments) -> do
                    translated <- probeMaybeT $ translateAssignment arguments
                    pure $ fmap
                      (\retained@(_, _, argumentTypes) ->
                        ( (index, vectorIndex)
                        , retained
                        , groundProviderConstraintGroup
                            sourceProviderFrag providerType argumentTypes
                        ))
                      translated)
                  assignmentVectors
                pure (catMaybes discovered)
              (True, SelectProviderGroundFacts _, True) -> mapM
                (\(vectorIndex, arguments) -> do
                  translated@(_, _, argumentTypes) <-
                    translateAssignment arguments
                  grounded <- case groundProviderConstraintGroup
                      sourceProviderFrag providerType argumentTypes of
                    Just constraints -> pure constraints
                    Nothing -> failT
                      "selected contextual provider fact became unavailable"
                  pure
                    ( (index, vectorIndex)
                    , translated
                    , Just grounded
                    ))
                assignmentVectors
              (True, SelectProviderGroundFacts _, False) -> do
                fallback <- mapM
                  (\(vectorIndex, arguments) -> do
                    translated <- transactionT
                      $ translateAssignment arguments
                    pure $ (\retained ->
                      ((index, vectorIndex), retained, Nothing))
                        <$> translated)
                  assignmentVectors
                pure (catMaybes fallback)
              _ -> mapM
                (\(vectorIndex, arguments) -> do
                  translated <- translateAssignment arguments
                  pure ((index, vectorIndex), translated, Nothing))
                assignmentVectors
            -- Domain metadata can distinguish two Lean renderings which Djex
            -- intentionally collapses to the same canonical assignment. Keep
            -- every bounded rendering below, but search each canonical vector
            -- only once.
            let historicalAssignments =
                  [ ProviderTranslatedAssignment instantiation assignmentInfo
                  | (_, (instantiation, assignmentInfo, _), _) <-
                      translatedAssignments
                  ]
                allInstantiations = nub
                  $ map providerTranslatedInstantiation historicalAssignments
                successfulContextualKeys
                  | exactContextual =
                      [ key | (key, _, _) <- translatedAssignments ]
                  | otherwise = []
                groundConstraintGroups =
                  [ ProviderGroundConstraintGroup key historical grounded
                  | (historical, (key, _, Just grounded)) <-
                      zip historicalAssignments translatedAssignments
                  ]
                retainedAssignments
                  | exactContextual
                  , case groundFactMode of
                      DiscoverProviderGroundFacts -> True
                      SelectProviderGroundFacts _ -> providerHasSelectedFacts
                      = []
                  | otherwise = allInstantiations
                info = (providerInfo leanName binderNames sourceProviderFrag)
                  { piAssignments =
                      map providerTranslatedRenderInfo historicalAssignments
                  }
            pure ProviderBinding
              { providerBindingSource = provider
              , providerBindingPrivateName = privateName
              , providerBindingPrivateSpelling =
                  "leantProvider" ++ show index
              , providerBindingScheme = providerType
              , providerBindingRenderInfo = info
              , providerBindingAssignments = retainedAssignments
              , providerBindingTranslatedAssignmentKeys =
                  successfulContextualKeys
              , providerBindingGroundConstraintGroups =
                  groundConstraintGroups
              })
          (zip [0 :: Int ..] usableProviders)
        pure TranslationProduct
          { translationProductCallerPremises = extrasT
          , translationProductSourceGoal = goal
          , translationProductProviderBindings = translatedProviders
          }

  -- Djinn's compatibility projection erases every exact provider context.
  -- Exference retains the semantic wire for live/plain, binder-only, and
  -- exact-evidence providers. Historical candidate pools are context-erased
  -- in both engines: reshaping a legacy unary hint must never create a
  -- conditional provider declaration.
  projectedProviderFrag index provider = case
      (providerContextProjection recursiveProjection, provider) of
    (RetainProviderContexts, ProviderFragWithLegacyCandidates{}) ->
      eraseProviderExactContexts $ providerTypeFrag provider
    (RetainProviderContexts, _)
      | exactContextualProvider provider -> case groundFactMode of
          DiscoverProviderGroundFacts -> providerTypeFrag provider
          SelectProviderGroundFacts selected
            | selectedProviderHasGroundFacts index selected ->
                providerTypeFrag provider
            | otherwise ->
                eraseProviderExactContexts $ providerTypeFrag provider
    (RetainProviderContexts, _) -> providerTypeFrag provider
    (EraseProviderContexts, _) ->
      eraseProviderExactContexts $ providerTypeFrag provider

  exactContextualProvider provider = case
      (providerContextProjection recursiveProjection, provider) of
    (RetainProviderContexts, ProviderFragWithEvidence{}) ->
      providerFragmentContainsExactContext $ providerTypeFrag provider
    _ -> False

  selectedProviderHasGroundFacts index = any
    ((== index) . fst) . Set.toList

  eraseProviderExactContexts source = case source of
    FArr parameter result -> FArr
      (eraseProviderExactContexts parameter)
      (eraseProviderExactContexts result)
    FProd left right -> FProd
      (eraseProviderExactContexts left)
      (eraseProviderExactContexts right)
    FLeanProd left right -> FLeanProd
      (eraseProviderExactContexts left)
      (eraseProviderExactContexts right)
    FSum left right -> FSum
      (eraseProviderExactContexts left)
      (eraseProviderExactContexts right)
    FAll explicit binder body ->
      FAll explicit binder (eraseProviderExactContexts body)
    FInst key body -> FInst key (eraseProviderExactContexts body)
    FExactContext _ _ body -> eraseProviderExactContexts body
    FApp safe key head' arguments ->
      FApp safe key head' $ map eraseProviderExactContexts arguments
    FParamInd spelling key parameters constructors ->
      FParamInd spelling key
        (map eraseProviderExactContexts parameters)
        [ (name, map eraseProviderExactContexts fields)
        | (name, fields) <- constructors
        ]
    FInd key constructors -> FInd key
      [ (name, map eraseProviderExactContexts fields)
      | (name, fields) <- constructors
      ]
    FParamRec complete spelling key parameters constructors ->
      FParamRec complete spelling key
        (map eraseProviderExactContexts parameters)
        [ (name, map eraseProviderExactContexts fields)
        | (name, fields) <- constructors
        ]
    FRec complete key parameters constructors ->
      FRec complete key
        (map eraseProviderExactContexts parameters)
        [ (name, map eraseProviderExactContexts fields)
        | (name, fields) <- constructors
        ]
    _ -> source

  -- One exact vector authorizes the complete leading constraint group or
  -- nothing. The translated argument vector must be closed and forall-free;
  -- this still admits ground higher-kinded arguments such as @Functor List@.
  -- One capture-safe simultaneous substitution is then applied to the whole
  -- group. The vector proves closure of these provider obligations only: no
  -- original Lean instance head or prerequisite graph is reconstructed.
  -- A later full-inventory trial seal owns nominal kind validation, so this
  -- helper can fail closed without rejecting the provider itself.
  groundProviderConstraintGroup sourceProviderFrag providerScheme
      argumentTypes
    | null binders || null constraints = Nothing
    | length binders /= length argumentTypes = Nothing
    | length (nub binders) /= length binders = Nothing
    | length sourceContexts /= length constraints = Nothing
    | not (all resolverGroundType argumentTypes) = Nothing
    | otherwise = case substituteTypeVariablesBatch noFresh Set.empty
        (Map.fromList $ zip binders argumentTypes)
        (concatMap constraintArguments constraints) of
      Left _ -> Nothing
      Right groundedArguments -> do
        grounded <- rebuildConstraints constraints groundedArguments
        let canonical = map (fmap canonicalizeType) grounded
        if all resolverGroundConstraint canonical
          then Just canonical
          else Nothing
   where
    (binders, constraints, _) = splitLeadingForalls providerScheme
    sourceContexts = leadingSourceContexts sourceProviderFrag
    noFresh _ _ = Nothing
    resolverGroundType typeExpression =
      not (containsForall typeExpression)
        && Set.null (freeVariables typeExpression)
    resolverGroundConstraint = all resolverGroundType . constraintArguments

    leadingSourceContexts source = case source of
      FAll _ _ body -> leadingSourceContexts body
      FExactContext className arguments body ->
        (className, arguments) : leadingSourceContexts body
      _ -> []

    rebuildConstraints [] [] = Just []
    rebuildConstraints [] _ = Nothing
    rebuildConstraints (constraint : remaining) arguments = do
      let width = length $ constraintArguments constraint
          (current, rest) = splitAt width arguments
      if length current /= width
        then Nothing
        else do
          tailConstraints <- rebuildConstraints remaining rest
          pure
            ( Constraint (constraintClass constraint) current
                : tailConstraints
            )

  usableProvider provider =
    not (fragHasDepth source)
      && case providerContextProjection recursiveProjection of
        EraseProviderContexts -> True
        RetainProviderContexts ->
          not (providerFragmentContainsExactContext source
            && fragHasUnsupportedInstanceBinder source)
   where
    source = providerTypeFrag provider

  usableProviderAssignments provider =
    let arity = providerInstantiationArity $ providerTypeFrag provider
        assignments = case provider of
          ProviderFragWithEvidence
              { providerInstantiationAssignments = exact } -> exact
          ProviderFragWithLegacyCandidates
              { providerLegacyInstantiationCandidates = candidates } ->
                [ [ProviderInstantiationArgument 0 candidate]
                | candidate <- candidates
                ]
          _ -> []
    in filter
      (\assignment ->
        not (null assignment)
          && observedListLength arity assignment == arity
          && all usableProviderArgument assignment)
      assignments

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
          remaining == 0 || spelling `notElem` structuralHigherKindHeads
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
    ProviderInstantiationExactArgument {} -> uses
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
  recursiveStructuralAtoms projectionPolicy structuralPlans =
    foldl collect (Set.empty, Set.empty)
   where
    collect accum frag = case frag of
      FArr parameter result -> descend accum [parameter, result]
      FProd left right -> descend accum [left, right]
      FLeanProd left right -> descend accum [left, right]
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
        let structural = case Map.lookup spelling structuralPlans of
              Just RecursiveStructuralFamily{} ->
                exactRecursiveData projectionPolicy
              _ -> False
            accum'
              | structural = first (Set.insert key) accum
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

-- | One Lean binder group is serialized as adjacent FAll nodes because
-- rendering retains each explicitness slot independently. Djex instead
-- models one source scheme with a binder list. Coalescing only the
-- uninterrupted spine preserves scope and rendering while preventing a
-- bounded multi-binder scheme from becoming independent occurrence sites.
adjacentForallSpine :: Frag -> ([String], Frag)
adjacentForallSpine = collect []
  where
    collect binders (FAll _ binder body) =
      collect (binder : binders) body
    collect binders body = (reverse binders, body)

-- | Preserve an exact instance telescope at its source position. A later
-- FAll starts a nested scheme rather than being floated ahead of the
-- context, so rendering consumes forall-domain metadata in the same
-- preorder that the Lean serializer recorded.
adjacentExactContextSpine
  :: Frag -> ([(String, [ExactContextArgument])], Frag)
adjacentExactContextSpine = collect []
  where
    collect contexts (FExactContext className arguments body) =
      collect ((className, arguments) : contexts) body
    collect contexts body = (reverse contexts, body)

-- | Report one exact Lean family observed at incompatible proper-type
-- arities.
arityFailure :: String -> Int -> [Int] -> Trans a
arityFailure spelling arity arities = failT
  ("internal: exact Lean family " ++ show spelling
    ++ " has incompatible proper-type arities "
    ++ show (nub (arity : arities)))

-- | Declare one shared abstract engine constructor for an exact Lean
-- family whose structure stays hidden.
declareAbstractFamily :: String -> Int -> Trans (Type String)
declareAbstractFamily spelling arity = do
  (_, _, typeName) <- freshExactFamily spelling arity
  let kind = foldr FunctionKind ProperTypeKind
        (replicate arity ProperTypeKind)
      declaration = AbstractTypeDeclaration () typeName kind
  modifyT (\s -> s { tsDecls = tsDecls s ++ [declaration] })
  pure (TypeConstructor typeName)

-- | Allocate the next private engine spelling for one exact Lean family
-- and record its name-map entry.
freshExactFamily :: String -> Int -> Trans (Int, String, Name)
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

-- | A fixed opaque field such as @Secret@ is not one of the Lean
-- inductive's parameters.  Modeling it as an engine type variable would
-- make the generated data declaration ill scoped, so give every such
-- exact field one shared private proper-type declaration.  Other atoms
-- retain the established flexible transport representation.
rigidAtom :: String -> Trans (Type String)
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

fragmentProjectionComplete :: Frag -> Bool
fragmentProjectionComplete frag =
  not (fragHasDepth frag) && null (fragUnsafeAtoms frag)

-- | Decide each exact-head family representation from the complete query,
-- before translation order can bias the choice.  A nominal use means Lean did
-- not expose a constructor schema at that occurrence, so every use of that
-- head becomes one shared abstract family.  Otherwise a structural template
-- is accepted only when one unique schema can be recovered and specializing
-- it reproduces every serialized occurrence exactly.
-- | The fields of every selected structural template in a plan map: the
-- fragments a plan selection commits to translating.  The plan-selection rule
-- and the atom scan which must agree with it both read exactly this list, so
-- neither can drift from the other.
structuralPlanFields
  :: RecursiveProjection
  -> Map.Map String ExactFamilyPlan
  -> [Frag]
structuralPlanFields recursiveProjection plans =
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

  structuralFields plans = structuralPlanFields recursiveProjection plans

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
  FLeanProd left right -> descend atoms [left, right]
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
  FLeanProd left right -> descend atoms [left, right]
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
  FLeanProd left right -> descend uses [left, right]
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
  (Set.null . freeFragVariables (Set.fromList (templateFormals template)))
  [ field
  | (_, fields) <- templateConstructors template
  , field <- fields
  ]

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
    (FProd a b, FLeanProd c d) -> both binders a c b d
    (FLeanProd a b, FProd c d) -> both binders a c b d
    (FLeanProd a b, FLeanProd c d) -> both binders a c b d
    (FSum a b, FSum c d) -> both binders a c b d
    (FTop, FTop) -> True
    (FBot, FBot) -> True
    (FAll leftExplicit leftBinder leftBody,
        FAll rightExplicit rightBinder rightBody) ->
      leftExplicit == rightExplicit
        && go ((leftBinder, rightBinder) : binders) leftBody rightBody
    -- Legacy instance evidence is erased before either engine sees a schema.
    -- Pretty keys retain only diagnostics and must not split alpha-equivalent
    -- family templates whose enclosing binder spellings differ.  Semantic
    -- FExactContext nodes are compared by the branch immediately below.
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
            leftArity == rightArity
              && if leftArity == 0
                then go binders leftFrag rightFrag
                else leftArity > 0
                  && leftArity <= maximumProviderArgumentKindArity
                  && scopedVariableArgumentsEquivalent binders
                    leftFrag rightFrag
        _ -> False
      _ -> False
  scopedVariableArgumentsEquivalent binders left right = case (left, right) of
    (FVar leftName, FVar rightName) ->
      leftName `elem` map fst binders
        && rightName `elem` map snd binders
        && go binders left right
    ( FApp _ _ (AppVariable leftName) leftSupplied
      , FApp _ _ (AppVariable rightName) rightSupplied
      ) ->
        not (null leftSupplied)
          && not (null rightSupplied)
          && leftName `elem` map fst binders
          && rightName `elem` map snd binders
          && go binders left right
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
  (second (map (replaceFrag replacements)))

-- | Exact whole-fragment replacement, followed by structural descent only
-- when no parameter matches the current node.  Matching the whole node first
-- is important for higher-kinded or otherwise structured parameters: their
-- internal variables are not declaration parameters in their own right.
replaceFrag :: [(Frag, Frag)] -> Frag -> Frag
replaceFrag replacements = go Set.empty
 where
  replacementFreeVariables = Set.unions
    [ freeFragVariables Set.empty replacement
    | (_, replacement) <- replacements
    ]
  reservedNames = Set.unions
    [ fragVariableNames parameter `Set.union` fragVariableNames replacement
    | (parameter, replacement) <- replacements
    ]

  go shadowed frag = case
      [ replacement
      | (parameter, replacement) <- replacements
      -- A constructor-local forall may reuse an outer family parameter's
      -- spelling.  The occurrence below that binder denotes the local
      -- variable, not the family argument, so it must not be genericized.
      , Set.null
          (freeFragVariables Set.empty parameter `Set.intersection` shadowed)
      -- Every binder that could capture a replacement is alpha-renamed on
      -- entry below.  Retain this guard at the replacement site as a
      -- defensive invariant for fragments introduced by future constructors.
      , Set.null
          (freeFragVariables Set.empty replacement
            `Set.intersection` shadowed)
      , schemaEquivalent parameter frag
      ] of
    replacement : _ -> replacement
    [] -> case frag of
      FArr parameter result ->
        FArr (recur parameter) (recur result)
      FProd left right -> FProd (recur left) (recur right)
      FLeanProd left right -> FLeanProd (recur left) (recur right)
      FSum left right -> FSum (recur left) (recur right)
      FAll explicit binder body
        | binder `Set.member` replacementFreeVariables ->
            let fresh = freshBinderName
                  (reservedNames `Set.union` fragVariableNames body
                    `Set.union` shadowed)
                renamed = renameFragBinder binder fresh body
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
    (second (map (go shadowed)))

  freshBinderName = freshFragBinderFrom "\0leant-bound:"
