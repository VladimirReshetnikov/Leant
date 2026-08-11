-- | Rendering Djex candidate terms as Lean 4 syntax (the \"out of the
-- engine\" direction of SYNTHESIS_PROPOSAL.md \'s translator).
--
-- The rendering is deliberately universe-agnostic: anonymous constructors
-- (@\10216a, b\10217@, @\10216\10217@), leading-dot injections (@.inl@\/@.inr@), @match@,
-- and @nomatch@ all elaborate against both the @Prop@ spellings
-- (@And@\/@Or@\/@Iff@\/@False@\/@True@) and the @Type@ spellings
-- (@Prod@\/@Sum@\/@Empty@\/@Unit@), because every candidate is elaborated by
-- the Lean backend against the fully known goal type before display.
--
-- Djinn's Haskell model differs from Lean in two ways this module has to
-- bridge structurally, by fitting the candidate to the goal fragment:
--
--   * quantifiers are implicit for Djinn, so its terms never bind them;
--     'fit' weaves an anonymous binder for every explicit quantifier the
--     goal reaches while the candidate is still binding (including inside
--     tuple components, injections, and match alternatives), and
--     eta-expands cores left under an explicit quantifier - always for
--     introduction forms, and as an extra variant for elimination forms
--     (which may instead be transported whole);
--   * instantiating a quantified hypothesis is silent for Djinn, while
--     Lean's explicit binders need @_@ placeholders.  An /applied/
--     hypothesis is unambiguous: placeholders are woven into the argument
--     list wherever the hypothesis type's spine has an explicit
--     quantifier (@h a q@ over @A \8594 \8704 b, b \8594 C@ renders @h a _ q@).  A
--     use whose /trailing/ quantifiers may or may not be instantiated
--     (a bare occurrence, or an application consuming only the arrows
--     before them) is genuinely ambiguous, so such occurrence sites are
--     enumerated into textual variants (each site kept or instantiated)
--     and the caller's backend verification keeps the first variant that
--     elaborates.
--
-- The engine is never trusted (design rule 2): a rendering failure just
-- drops the candidate, and everything shown has been verified.
module Leant.Synth.Render
  ( CtorInfo (..)
  , CtorMap
  , ProviderAssignmentInfo (..)
  , ProviderInfo (..)
  , ProviderMap
  , TypeMap
  , providerInfo
  , renderLeanTerm
  , renderLeanTermGraphProjection
  ) where

import Control.Monad (foldM)
import Data.Char (isControl)
import Data.List (intercalate, nub, sortOn, subsequences)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set

import Language.Haskell.Djex
  ( maximumProviderInstantiationAssignments
  )
import Language.Haskell.Synthesis.Generated
  ( ApplicationArgument (..)
  , ClosedVisibleTypeVariable
  , Expression (..)
  , Pattern (..)
  , VisibleTypeArgument
  , applyExpressionArguments
  , closedVisibleTypeVariableSpelling
  , discardUnusedPatternBindingsBy
  , expressionFullApplicationSpine
  , isInferredVisibleTypeArgument
  , visibleTypeArgumentClosedType
  )
import Language.Haskell.Synthesis.TypedGenerated
  ( TermGraph
  , eraseTermGraph
  )
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name
  ( Boxity (..)
  , Name
  , SpecialName (..)
  , mkIdentifier
  , nameSpecial
  , nameSpelling
  , renderCanonical
  )
import qualified Language.Haskell.Synthesis.Type as SharedType

import Leant.Synth.Fragment
  ( AppHead (..)
  , ExactContextArgument (..)
  , Frag (..)
  , ProviderForallDomain (..)
  , ProviderInstantiationArgument (..)
  , Slot (..)
  , exactContextArgumentPayloadFragments
  , mapExactContextArgumentFragments
  , fragVisibleForallVisibilities
  , fragSpine
  , leadingTypeArgs
  , maximumProviderExactForallDomains
  )

-- | One constructor of a datatype 'Leant.Synth.Engine' declared to
-- represent an expanded inductive occurrence (phase 2).
data CtorInfo = CtorInfo
  { ciLean :: String    -- ^ full Lean constructor name
  , ciFields :: [Frag]  -- ^ field fragments
  , ciSole :: Bool      -- ^ the inductive's only constructor
  , ciParametric :: Maybe (String, [String])
    -- ^ exact family head and private fragment formals when 'ciFields' is a
    -- generic family schema rather than an occurrence-specialized inventory
  }
  deriving (Eq, Show)

-- | Engine-side constructor spellings of the declared datatypes.
type CtorMap = Map.Map String CtorInfo

-- | One retained provider-instantiation vector.  The visible arguments are
-- the canonical syntax emitted by Djex, while the source arguments preserve
-- Lean's exact fragment explicitness and higher-kinded payload.  Keeping both
-- sides lets result fitting recover information which Djex's intentionally
-- language-neutral type representation cannot express.
data ProviderAssignmentInfo = ProviderAssignmentInfo
  { paiVisibleArguments :: [VisibleTypeArgument]
  , paiSourceArguments :: [ProviderInstantiationArgument]
  }
  deriving (Eq, Show)

-- | Exact rendering metadata for one collision-free engine provider.
data ProviderInfo = ProviderInfo
  { piLeanName :: String
  , piBinderNames :: Maybe [String]
  , piFrag :: Frag
  , piAssignments :: [ProviderAssignmentInfo]
  }
  deriving (Eq, Show)

-- | Collision-free engine provider spelling to its exact Lean metadata.
-- Besides restoring names, the renderer needs the source fragment as an
-- expected type when an engine constructs a higher-rank argument directly
-- under a provider application; unlike stripped premise lambdas, such a
-- global has no local-domain entry from which fitting could recover it.
type ProviderMap = Map.Map String ProviderInfo

-- | Provider metadata without retained instantiation evidence.  This is the
-- normal shape for providers which were not discovered with exact assignment
-- vectors and keeps direct renderer fixtures concise.
providerInfo :: String -> Maybe [String] -> Frag -> ProviderInfo
providerInfo leanName binderNames frag = ProviderInfo
  { piLeanName = leanName
  , piBinderNames = binderNames
  , piFrag = frag
  , piAssignments = []
  }

-- | Collision-free engine type spelling to its exact Lean type or type-family
-- spelling.  Family heads are restored with their full explicit argument
-- vector; rigid opaque field types have no engine-visible arguments.
type TypeMap = Map.Map String String

-- | Initial checked-graph rendering seam.
--
-- Today this narrow projection deliberately reuses the established renderer
-- through the graph's checked one-way erasure.  Keeping the graph at this
-- module boundary lets a later direct typed walk replace only this helper,
-- without teaching the engine orchestrator about rendering structure.
renderLeanTermGraphProjection
  :: (local -> String)
  -> CtorMap -> ProviderMap -> TypeMap
  -> ([(String, Frag)], Int, [(String, Frag)]) -> Frag
  -> TermGraph ty local
  -> Either String [String]
renderLeanTermGraphProjection localName cm providers typeNames premises goalFrag =
  renderLeanTerm cm providers typeNames premises goalFrag
    . fmap localName
    . eraseTermGraph

-- | Render one candidate expression against the goal fragment.  The
-- candidate proves the premise-extended goal (see
-- 'Leant.Synth.Engine': conservative constructor premises are antecedents
-- before the engine goal's arrow binders, caller-supplied premises after
-- them), so both premise binder blocks around the kept goal-arrow lambdas are
-- stripped and their uses replaced by the actual Lean names.  Returns a
-- nonempty group of textual variants, best guess first; the caller verifies
-- them in order and keeps the first that elaborates.
renderLeanTerm
  :: CtorMap -> ProviderMap -> TypeMap
  -> ([(String, Frag)], Int, [(String, Frag)]) -> Frag
  -> Expression String
  -> Either String [String]
renderLeanTerm cm providers typeNames (outerPrems, skip, innerPrems)
    goalFrag expr0 = do
  stripped <- stripPremises (map fst outerPrems) skip
    (map fst innerPrems) (normalizeExpr 0 expr0)
  -- Exference's relaxed fallback retains candidates with intentionally
  -- ignored inputs.  Turn those unused binders into real pattern wildcards
  -- before assigning Lean-facing names; this keeps recursive projections
  -- finite and renders the omission explicitly as @.mk value _@.
  base <- uniquify $ discardUnusedPatternBindingsBy id stripped
  -- premises participate in domain fitting under their marked names,
  -- so case splits on them reveal their branch binders' domains
  let premises = outerPrems ++ innerPrems
      seed = [(premiseMark ++ name, frag) | (name, frag) <- premises]
  (occurrenceProviders, occurrenceBase) <-
    aliasProviderOccurrences cm providers base
  let providerVariants = providerRenderingAlternatives occurrenceProviders
      fittedCohorts =
        [ nub
            [ (providerVariant,
                fit cm providerVariant force goalFrag occurrenceBase 0 seed)
            | providerVariant <- providerVariants
            ]
        | force <- [False, True]
        ]
  -- Keep the aggregate provider-assignment budget independently in each
  -- universe-domain lane. This preserves every bounded exact-metadata choice
  -- before the verifier while keeping the final group bounded at three times
  -- that limit. Named, monomorphic, and otherwise domain-insensitive spellings
  -- collapse back to the old size in the final 'nub'.
  lanes <- mapM
    (\visibleBinderDomain -> do
      cohorts <- mapM
        (mapM (uncurry (variantsFor visibleBinderDomain))) fittedCohorts
      pure $ take visibleBinderDomainVariantLimit $
        nub (concatMap roundRobin cohorts))
    visibleBinderDomains
  case nub $ concat lanes of
    [] -> Left "no renderable variant"
    group -> Right group
 where
  variantsFor visibleBinderDomain selectedProviders fitted = do
    let (expr, domPairs) = roleRename fitted
        doms = Map.fromList domPairs
        sites = countSites doms expr
        sets
          | sites == 0 = [[]]
          | sites <= 3 = siteSubsets sites
          | otherwise = [[], [0 .. sites - 1]]
        -- within one instantiation choice, offer the idiomatic
        -- constructor spellings (anonymous ⟨...⟩ for a sole
        -- constructor, leading-dot otherwise) before the fully
        -- qualified fallback; verification keeps the first that
        -- elaborates
        styles = [Idiomatic, Explicit]
    concat <$> mapM
      (\set -> mapM
        (\style ->
          render cm selectedProviders typeNames style visibleBinderDomain
            doms 0 (markSites doms set expr))
        styles)
      sets

  roundRobin rows = case [(item, rest) | item : rest <- rows] of
    [] -> []
    headsAndTails ->
      map fst headsAndTails ++ roundRobin (map snd headsAndTails)

-- Give each provider occurrence whose complete visible vector matches retained
-- evidence a private renderer key. Djex intentionally merges Lean metadata
-- which has one canonical visible type, but two uses of that canonical vector
-- may need different source visibility/domain alternatives. Aliasing before
-- fitting lets the existing bounded provider-map scheduler select those
-- alternatives independently, while every alias still renders the exact
-- original Lean global through its copied 'ProviderInfo'.
aliasProviderOccurrences
  :: CtorMap -> ProviderMap -> Expression local
  -> Either String (ProviderMap, Expression local)
aliasProviderOccurrences constructors providers expression = do
  (expression', aliases, _) <- go (0 :: Int) expression
  let originalsWithoutAssignments = Map.map
        (\info -> info { piAssignments = [] }) providers
  pure
    ( Map.union (Map.fromList aliases) originalsWithoutAssignments
    , expression'
    )
 where
  occupiedGlobalSpellings = expressionGlobalSpellings expression

  go next expression'
    | Just (providerName, arguments) <- providerVisibleSpine expression' []
    , Just info <- declaredProvider providers providerName
    , let retained =
            [ assignment
            | assignment <- piAssignments info
            , paiVisibleArguments assignment == arguments
            ]
    , not (null retained) = do
        (aliasName, aliasKey, next') <- freshAlias next
        let aliasedInfo = info { piAssignments = retained }
            aliasedExpression = foldl VisibleTypeApplication
              (Global aliasName) arguments
        pure (aliasedExpression, [(aliasKey, aliasedInfo)], next')
  go next expression' = case expression' of
    Local{} -> pure (expression', [], next)
    Global{} -> pure (expression', [], next)
    Hole{} -> pure (expression', [], next)
    Lambda patterns body -> do
      (body', aliases, final) <- go next body
      pure (Lambda patterns body', aliases, final)
    Apply function argument -> do
      (function', functionAliases, afterFunction) <- go next function
      (argument', argumentAliases, final) <- go afterFunction argument
      pure
        ( Apply function' argument'
        , functionAliases ++ argumentAliases
        , final
        )
    VisibleTypeApplication function argument -> do
      (function', aliases, final) <- go next function
      pure (VisibleTypeApplication function' argument, aliases, final)
    Tuple elements -> do
      (elements', aliases, final) <- goMany next elements
      pure (Tuple elements', aliases, final)
    Let pattern rhs body -> do
      (rhs', rhsAliases, afterRhs) <- go next rhs
      (body', bodyAliases, final) <- go afterRhs body
      pure (Let pattern rhs' body', rhsAliases ++ bodyAliases, final)
    Case scrutinee alternatives -> do
      (scrutinee', scrutineeAliases, afterScrutinee) <- go next scrutinee
      (alternatives', alternativeAliases, final) <-
        goAlternatives afterScrutinee alternatives
      pure
        ( Case scrutinee' alternatives'
        , scrutineeAliases ++ alternativeAliases
        , final
        )

  goMany next [] = pure ([], [], next)
  goMany next (element : elements) = do
    (element', elementAliases, afterElement) <- go next element
    (elements', remainingAliases, final) <- goMany afterElement elements
    pure
      ( element' : elements'
      , elementAliases ++ remainingAliases
      , final
      )

  goAlternatives next [] = pure ([], [], next)
  goAlternatives next ((pattern, body) : alternatives) = do
    (body', bodyAliases, afterBody) <- go next body
    (alternatives', remainingAliases, final) <-
      goAlternatives afterBody alternatives
    pure
      ( (pattern, body') : alternatives'
      , bodyAliases ++ remainingAliases
      , final
      )

  freshAlias next =
    let digits = show next
        sourceOrdered = replicate (20 - length digits) '0' ++ digits
        aliasKey = "leantMetadataProviderOccurrence" ++ sourceOrdered
    in if Map.member aliasKey providers
        || Map.member aliasKey constructors
        || Set.member aliasKey occupiedGlobalSpellings
      then freshAlias (next + 1)
      else case mkIdentifier aliasKey of
        Left _ -> Left "internal: invalid provider metadata occurrence name"
        Right aliasName -> Right (aliasName, aliasKey, next + 1)

  expressionGlobalSpellings expression' = case expression' of
    Local{} -> Set.empty
    Global name -> maybe Set.empty Set.singleton (nameSpelling name)
    Hole{} -> Set.empty
    Lambda _ body -> expressionGlobalSpellings body
    Apply function argument -> Set.union
      (expressionGlobalSpellings function)
      (expressionGlobalSpellings argument)
    VisibleTypeApplication function _ -> expressionGlobalSpellings function
    Tuple elements -> Set.unions $ map expressionGlobalSpellings elements
    Let _ rhs body -> Set.union
      (expressionGlobalSpellings rhs)
      (expressionGlobalSpellings body)
    Case scrutinee alternatives -> Set.unions $
      expressionGlobalSpellings scrutinee :
        [ expressionGlobalSpellings body | (_, body) <- alternatives ]

providerVisibleSpine
  :: Expression local -> [VisibleTypeArgument]
  -> Maybe (Name, [VisibleTypeArgument])
providerVisibleSpine expression arguments = case expression of
  VisibleTypeApplication function argument ->
    providerVisibleSpine function (argument : arguments)
  Global name -> Just (name, arguments)
  _ -> Nothing

-- Exact domain vectors which collapse to one Djex visible type must remain
-- render alternatives: Lean verification can reject the first (for example a
-- Prop-domain spelling) and accept the next Type-domain spelling. Build a
-- bounded Cartesian product keyed by provider and canonical visible vector.
-- The prefix keeps the base plus individual retained alternatives in provider
-- key order. A source provider contributes at most 32 assignments, but
-- occurrence-local aliases can repeat those alternatives more than 32 times;
-- the same global bound therefore retains the earliest source occurrences and
-- leaves later ones at their base selection. Remaining capacity admits the
-- Cartesian combinations, including for staged callers which may supply more
-- alternatives than the live producer's per-provider limit.
providerRenderingAlternatives :: ProviderMap -> [ProviderMap]
providerRenderingAlternatives providers =
  map applySelections $
    take maximumProviderInstantiationAssignments $ nub (prefix ++ cartesian)
 where
  groups =
    [ ( providerKey
      , visibleArguments
      , min maximumProviderInstantiationAssignments count
      )
    | (providerKey, info) <- Map.toAscList providers
    , visibleArguments <- nub (map paiVisibleArguments (piAssignments info))
    , let count = length
            [ ()
            | candidate <- piAssignments info
            , paiVisibleArguments candidate == visibleArguments
            ]
    , count > 1
    ]
  prefix = [] :
    [ [(providerKey, visibleArguments, alternative)]
    | (providerKey, visibleArguments, count) <- groups
    , alternative <- [1 .. count - 1]
    ]
  cartesian =
    [ [ (providerKey, visibleArguments, alternative)
      | ((providerKey, visibleArguments, _), alternative) <- zip groups choices
      , alternative /= 0
      ]
    | choices <- sequence
        [ [0 .. count - 1] | (_, _, count) <- groups ]
    ]

  applySelections = foldl applySelection providers

  applySelection selectedProviders
      (providerKey, visibleArguments, alternative) =
    Map.adjust
      (\info -> info
        { piAssignments = moveMatchingAssignment alternative visibleArguments
            (piAssignments info)
        })
      providerKey selectedProviders

  moveMatchingAssignment selected visibleArguments assignments =
    case pick selected 0 [] assignments of
      Nothing -> assignments
      Just (chosen, remaining) -> chosen : remaining
   where
    pick _ _ _ [] = Nothing
    pick target seen previous (assignment : rest)
      | paiVisibleArguments assignment == visibleArguments =
          if seen == target
            then Just (assignment, reverse previous ++ rest)
            else pick target (seen + 1) (assignment : previous) rest
      | otherwise = pick target seen (assignment : previous) rest

-- | Instantiation subsets, transport-first: no site instantiated, all
-- sites, then the mixed subsets by size.
siteSubsets :: Int -> [[Int]]
siteSubsets k = [] : full : sortOn (\s -> (length s, s)) middle
 where
  full = [0 .. k - 1]
  middle =
    [ s | s <- subsequences full, not (null s), length s /= k ]

-- Premise stripping ----------------------------------------------------------
--
-- The engine's candidate binds one lambda per premise: the constructor
-- premises before the lambdas of the engine goal's own arrow spine,
-- the caller-supplied premises after them.  Both premise blocks are
-- removed and every use of one is replaced by a reserved-marker local
-- carrying the Lean name; the marker survives uniquification untouched
-- and prints as the bare name.

premiseMark :: String
premiseMark = "\3"

marked :: String -> Bool
marked = (premiseMark ==) . take 1

stripPremises
  :: [String] -> Int -> [String] -> Expression String
  -> Either String (Expression String)
stripPremises [] _ [] expr = Right expr
stripPremises outerNames skip innerNames expr = do
  let (pats, core) = spine expr
  if length pats < length outerNames + skip + length innerNames
    then Left "candidate does not bind the constructor premises"
    else do
      let (outerPats, afterOuter) = splitAt (length outerNames) pats
          (goalPats, afterGoal) = splitAt skip afterOuter
          (innerPats, rest) = splitAt (length innerNames) afterGoal
      subst <- foldM bindPat Map.empty
        (zip outerPats outerNames ++ zip innerPats innerNames)
      let kept = goalPats ++ rest
      Right (substLocals subst
        (if null kept then core else Lambda kept core))
 where
  spine (Lambda ps b) = let (more, c) = spine b in (ps ++ more, c)
  spine e = ([], e)
  bindPat m (Bind x, name) = Right (Map.insert x name m)
  bindPat m (Wildcard, _) = Right m
  bindPat _ _ = Left "unexpected premise binder pattern"

-- | Capture-aware substitution of premise binders by marked names: a
-- binder that rebinds a substituted name shadows it.
substLocals
  :: Map.Map String String -> Expression String -> Expression String
substLocals sub expr
  | Map.null sub = expr
  | otherwise = case expr of
      Local x -> case Map.lookup x sub of
        Just leanName -> Local (premiseMark ++ leanName)
        Nothing -> expr
      Global _ -> expr
      Hole _ -> expr
      Apply f a -> Apply (substLocals sub f) (substLocals sub a)
      VisibleTypeApplication f a ->
        VisibleTypeApplication (substLocals sub f) a
      Tuple es -> Tuple (map (substLocals sub) es)
      Lambda pats body ->
        Lambda pats (substLocals (removeBound pats sub) body)
      Let pat rhs body -> Let pat (substLocals sub rhs)
        (substLocals (removeBound [pat] sub) body)
      Case scrut alts -> Case (substLocals sub scrut)
        [ (pat, substLocals (removeBound [pat] sub) body)
        | (pat, body) <- alts
        ]
 where
  removeBound pats m = foldr Map.delete m (concatMap patternNames pats)

-- | Every name bound by a pattern.
patternNames :: Pattern String -> [String]
patternNames pat = case pat of
  Bind x -> [x]
  Wildcard -> []
  As x p -> x : patternNames p
  TuplePattern ps -> concatMap patternNames ps
  Constructor _ ps -> concatMap patternNames ps

-- Role-based naming ----------------------------------------------------------
--
-- After fitting, binders whose domain fragment the goal determines are
-- named by role: continuations\/negations (domain ending in \8869) draw
-- from the @k@ pool, other functions from @f g h@, values from
-- @x y z w@, and binders the goal says nothing about from @a b c@.
-- Placeholders are globally unique, so one global substitution is
-- capture-safe; pools are mutually disjoint (including overflow
-- spellings) and avoid the @z0, z1, ...@ names 'fit' gives eta binders.

data Role = RoleNeg | RoleFun | RoleVal

roleRename
  :: (Expression String, Int, [(String, Frag)])
  -> (Expression String, [(String, Frag)])
roleRename (expr, _, domPairs) =
  ( mapExprNames renamed expr
  , [(renamed key, frag) | (key, frag) <- domPairs]
  )
 where
  doms = Map.fromList domPairs
  assignment = Map.fromList
    (assign (filter isPlaceholder (binderOrder expr)) (0, 0, 0, 0))
  renamed name = Map.findWithDefault name name assignment

  assign [] _ = []
  assign (name : rest) (nk, nf, nx, na) =
    case classify <$> Map.lookup name doms of
      Just RoleNeg ->
        (name, pool "k" ["k"] nk) : assign rest (nk + 1, nf, nx, na)
      Just RoleFun ->
        (name, pool "f" ["f", "g", "h"] nf)
          : assign rest (nk, nf + 1, nx, na)
      Just RoleVal ->
        (name, pool "x" ["x", "y", "z", "w"] nx)
          : assign rest (nk, nf, nx + 1, na)
      Nothing ->
        (name, pool "a" ["a", "b", "c", "d", "e"] na)
          : assign rest (nk, nf, nx, na + 1)

  pool stem names i
    | i < length names = names !! i
    | otherwise = stem ++ show (i - length names + 1)

  classify frag = case peel frag of
    FArr _ rest
      | endsBot rest -> RoleNeg
      | otherwise -> RoleFun
    _ -> RoleVal
   where
    endsBot f = case peel f of
      FBot -> True
      FArr _ r -> endsBot r
      _ -> False
  peel (FAll _ _ b) = peel b
  peel (FInst _ b) = peel b
  peel (FExactContext _ _ b) = peel b
  peel f = f

-- | Bound placeholder names in binding order.
binderOrder :: Expression String -> [String]
binderOrder e = case e of
  Local _ -> []
  Global _ -> []
  Hole _ -> []
  Apply f a -> binderOrder f ++ binderOrder a
  VisibleTypeApplication f _ -> binderOrder f
  Tuple es -> concatMap binderOrder es
  Lambda pats b -> concatMap patternNames pats ++ binderOrder b
  Let pat rhs b ->
    binderOrder rhs ++ patternNames pat ++ binderOrder b
  Case scrut alts -> binderOrder scrut
    ++ concatMap (\(p, b) -> patternNames p ++ binderOrder b) alts

-- | Rename every local name - binding and use sites alike.  Sound only
-- for globally injective renamings of globally unique names.
mapExprNames :: (String -> String) -> Expression String -> Expression String
mapExprNames f = go
 where
  go e = case e of
    Local x -> Local (f x)
    Global g -> Global g
    Hole h -> Hole h
    Apply a b -> Apply (go a) (go b)
    VisibleTypeApplication a t -> VisibleTypeApplication (go a) t
    Tuple es -> Tuple (map go es)
    Lambda pats b -> Lambda (map goPat pats) (go b)
    Let pat rhs b -> Let (goPat pat) (go rhs) (go b)
    Case scrut alts ->
      Case (go scrut) [(goPat p, go b) | (p, b) <- alts]
  goPat pat = case pat of
    Bind x -> Bind (f x)
    Wildcard -> Wildcard
    As x p -> As (f x) (goPat p)
    TuplePattern ps -> TuplePattern (map goPat ps)
    Constructor c ps -> Constructor c (map goPat ps)

-- Globals -------------------------------------------------------------------

data GlobalKind = GInl | GInr | GUnit | GCtor CtorInfo

globalKind :: CtorMap -> Name -> Either String GlobalKind
globalKind cm name
  | nameSpelling name == Just "Left" = Right GInl
  | nameSpelling name == Just "Right" = Right GInr
  | nameSpecial name == Just (TupleConstructor Boxed 0) = Right GUnit
  | Just info <- declaredCtor cm name = Right (GCtor info)
  | otherwise = Left ("unexpected global in candidate: " ++ show name)

-- | A constructor of one of the engine-declared datatypes, looked up by
-- its engine spelling.
declaredCtor :: CtorMap -> Name -> Maybe CtorInfo
declaredCtor cm name = nameSpelling name >>= (`Map.lookup` cm)

-- | A caller-owned foreign value, looked up through its private engine
-- spelling.  The mapped text and binder metadata come directly from Lean
-- environment introspection, so no Haskell-name rendering or qualification
-- heuristic is applied to them.
declaredProvider
  :: ProviderMap -> Name -> Maybe ProviderInfo
declaredProvider providers name =
  nameSpelling name >>= (`Map.lookup` providers)

-- | Recover the source assignment corresponding to the complete leading
-- specified visible-argument vector of this provider application.  Djinn and
-- Exference both retain the first canonical vector, so source order here is
-- semantically significant.  Inferred, partial, and term-first spines carry no
-- exact recoverable source assignment and deliberately fail closed.
providerAssignmentAt
  :: ProviderInfo
  -> [ApplicationArgument local]
  -> Maybe [ProviderInstantiationArgument]
providerAssignmentAt info arguments = do
  let visiblePrefix = takeVisiblePrefix arguments
  if null visiblePrefix || any isInferredVisibleTypeArgument visiblePrefix
    then Nothing
    else do
      sourceArguments <- lookup visiblePrefix
        [ (paiVisibleArguments assignment, paiSourceArguments assignment)
        | assignment <- piAssignments info
        ]
      if length sourceArguments == length visiblePrefix
        then Just sourceArguments
        else Nothing
 where
  takeVisiblePrefix applicationArguments = case applicationArguments of
    VisibleTypeArgumentArgument argument : remaining ->
      argument : takeVisiblePrefix remaining
    _ -> []

-- | A proper-kinded direct fragment can participate in the renderer's
-- existing first-order substitution.  Higher-kinded and nominal arguments
-- retain their evidence for future support but cannot safely masquerade as a
-- plain fragment today.
properProviderArgument :: ProviderInstantiationArgument -> Maybe Frag
properProviderArgument argument = case argument of
  ProviderInstantiationArgument 0 frag
    | Just _ <- providerArgumentForallVisibilities argument -> Just frag
  ProviderInstantiationExactArgument 0 frag domains
    | length domains <= maximumProviderExactForallDomains
    , Just visibilities <- providerArgumentForallVisibilities argument
    , length domains == length visibilities -> Just frag
  _ -> Nothing

-- Djex intentionally erases Lean's explicit/implicit forall distinction from
-- its neutral visible-type syntax.  Exact provider evidence retains the source
-- fragment beside that canonical syntax, so collect its forall visibility in
-- the same preorder used by the shared type translation.  Free variables,
-- instance binders, and depth markers cannot be reconstructed exactly and
-- therefore fail closed.  Constructor inventories are metadata of nominal
-- occurrences rather than part of the visible type expression, so only
-- occurrence parameters recurse.
providerArgumentForallVisibilities
  :: ProviderInstantiationArgument -> Maybe [Bool]
providerArgumentForallVisibilities argument = case argument of
  ProviderInstantiationArgument _ frag -> fragVisibleForallVisibilities frag
  ProviderInstantiationExactArgument _ frag _ ->
    fragVisibleForallVisibilities frag
  ProviderInstantiationNominalArgument _ _ supplied ->
    concat <$> mapM fragVisibleForallVisibilities supplied

providerArgumentVariableNames
  :: ProviderInstantiationArgument -> Set.Set String
providerArgumentVariableNames argument = case argument of
  ProviderInstantiationArgument _ frag -> fragVariableNames frag
  ProviderInstantiationExactArgument _ frag _ -> fragVariableNames frag
  ProviderInstantiationNominalArgument _ _ supplied ->
    Set.unions (map fragVariableNames supplied)

-- Pattern normalization ------------------------------------------------------
--
-- Lean 4 has no as-patterns and its @fun@\/@let@ binder patterns must be
-- irrefutable, so before rendering:
--   * Exference's intrinsic boxed-pair constructor patterns become the shared
--     'TuplePattern' form emitted by Djinn, retaining irrefutable @fun@\/@let@
--     destructuring and one fragment-fitting path for both engines;
--   * every @As x p@ becomes a plain binding of @x@ plus an inner
--     @match x with | p => ...@ around the body;
--   * a constructor pattern in @fun@\/@let@ position becomes a fresh
--     binder plus an inner @match@.
-- Fresh binders use reserved spellings (@\"$synth0\"@, ...) that the later
-- uniquification pass renames along with everything else.

splitAs :: Pattern String -> (Pattern String, [(String, Pattern String)])
splitAs pat = case pat of
  As x p -> (Bind x, [(x, p)])
  Constructor n ps
    | nameSpecial n == Just (TupleConstructor Boxed 2)
    , length ps == 2 ->
        let (ps', obs) = unzip (map splitAs ps)
        in (TuplePattern ps', concat obs)
  Constructor n ps ->
    let (ps', obs) = unzip (map splitAs ps)
    in (Constructor n ps', concat obs)
  TuplePattern ps ->
    let (ps', obs) = unzip (map splitAs ps)
    in (TuplePattern ps', concat obs)
  other -> (other, [])

-- irrefutable and therefore usable directly as a fun/let binder pattern
binderSimple :: Pattern String -> Bool
binderSimple pat = case pat of
  Bind _ -> True
  Wildcard -> True
  TuplePattern ps -> all binderSimple ps
  _ -> False

wrapObligations :: [(String, Pattern String)] -> Expression String
                -> Expression String
wrapObligations obs body =
  foldr (\(x, p) b -> Case (Local x) [(p, b)]) body obs

normalizeExpr :: Int -> Expression String -> Expression String
normalizeExpr fresh expr = case expr of
  Local _ -> expr
  Global _ -> expr
  Hole _ -> expr
  Apply f a -> Apply (normalizeExpr fresh f) (normalizeExpr fresh a)
  VisibleTypeApplication f a ->
    VisibleTypeApplication (normalizeExpr fresh f) a
  Tuple es -> Tuple (map (normalizeExpr fresh) es)
  Lambda pats body ->
    let step (i, done, wrap) pat =
          let (pat', obs) = splitAs pat
          in if binderSimple pat'
               then (i, done ++ [pat'], wrap . wrapObligations obs)
               else
                 let v = freshName i
                 in ( i + 1
                    , done ++ [Bind v]
                    , wrap . wrapObligations ((v, pat') : obs)
                    )
        (fresh', pats', wrapAll) = foldl step (fresh, [], id) pats
    in Lambda pats' (normalizeExpr fresh' (wrapAll body))
  Let pat rhs body ->
    let (pat', obs) = splitAs pat
        rhs' = normalizeExpr fresh rhs
    in if binderSimple pat'
         then Let pat' rhs' (normalizeExpr fresh (wrapObligations obs body))
         else
           let v = freshName fresh
           in Let (Bind v) rhs'
                (normalizeExpr (fresh + 1)
                  (wrapObligations ((v, pat') : obs) body))
  Case scrut alts ->
    let alt (pat, body) =
          let (pat', obs) = splitAs pat
          in (pat', normalizeExpr fresh (wrapObligations obs body))
    in Case (normalizeExpr fresh scrut) (map alt alts)
 where
  freshName i = "$synth" ++ show i

-- Uniquification -------------------------------------------------------------
--
-- Djinn's binder identities are strings of its own choosing; rename every
-- binding site to a reserved, globally unique placeholder (scoped, so
-- shadowing in the source term stays correct).  The final Lean-safe
-- names are chosen later by 'roleRename', once the fitting pass has
-- paired binders with their goal-determined domain fragments.

placeholder :: Int -> String
placeholder n = "$u" ++ show n

isPlaceholder :: String -> Bool
isPlaceholder = ("$u" ==) . take 2

type Ren = Map.Map String String

uniquify :: Expression String -> Either String (Expression String)
uniquify expr0 = fst <$> go Map.empty 0 expr0
 where
  go :: Ren -> Int -> Expression String
     -> Either String (Expression String, Int)
  go env n expr = case expr of
    Local x
      | marked x -> Right (expr, n)
      | otherwise -> case Map.lookup x env of
          Just x' -> Right (Local x', n)
          Nothing -> Left ("unbound local in candidate: " ++ x)
    Global _ -> Right (expr, n)
    Hole _ -> Left "candidate contains an unfilled hole"
    Apply f a -> do
      (f', n1) <- go env n f
      (a', n2) <- go env n1 a
      Right (Apply f' a', n2)
    VisibleTypeApplication f a -> do
      (f', n1) <- go env n f
      Right (VisibleTypeApplication f' a, n1)
    Tuple es -> do
      (es', n') <- goList env n es
      Right (Tuple es', n')
    Lambda pats body -> do
      (pats', env', n1) <- goPats env n pats
      (body', n2) <- go env' n1 body
      Right (Lambda pats' body', n2)
    Let pat rhs body -> do
      (rhs', n1) <- go env n rhs
      (pats', env', n2) <- goPats env n1 [pat]
      (body', n3) <- go env' n2 body
      case pats' of
        [pat'] -> Right (Let pat' rhs' body', n3)
        _ -> Left "internal: let pattern arity"
    Case scrut alts -> do
      (scrut', n1) <- go env n scrut
      (alts', n2) <- goAlts env n1 alts
      Right (Case scrut' alts', n2)

  goAlts _ n [] = Right ([], n)
  goAlts env n ((pat, body) : rest) = do
    (pats', env', n1) <- goPats env n [pat]
    (body', n2) <- go env' n1 body
    (rest', n3) <- goAlts env n2 rest
    case pats' of
      [pat'] -> Right ((pat', body') : rest', n3)
      _ -> Left "internal: alt pattern arity"

  goList _ n [] = Right ([], n)
  goList env n (x : xs) = do
    (x', n1) <- go env n x
    (xs', n2) <- goList env n1 xs
    Right (x' : xs', n2)

  goPats env n [] = Right ([], env, n)
  goPats env n (p : ps) = do
    (p', env1, n1) <- goPat env n p
    (ps', env2, n2) <- goPats env1 n1 ps
    Right (p' : ps', env2, n2)

  goPat env n pat = case pat of
    Wildcard -> Right (Wildcard, env, n)
    Bind x ->
      let name = placeholder n
      in Right (Bind name, Map.insert x name env, n + 1)
    TuplePattern ps -> do
      (ps', env', n') <- goPats env n ps
      Right (TuplePattern ps', env', n')
    Constructor c ps -> do
      (ps', env', n') <- goPats env n ps
      Right (Constructor c ps', env', n')
    As _ _ -> Left "internal: as-pattern survived normalization"

-- Fitting the candidate to the goal fragment ---------------------------------
--
-- 'fit' walks the goal fragment and the candidate together, threading a
-- counter for fresh eta binders and an accumulator of (binder, domain
-- fragment) pairs for every binder whose domain the goal determines.
-- With @force@, cores left under an explicit quantifier are eta-expanded
-- even when they are elimination forms (the non-forced fit transports
-- those whole; both variants are offered to verification).

fit :: CtorMap -> ProviderMap -> Bool -> Frag -> Expression String -> Int
    -> [(String, Frag)] -> (Expression String, Int, [(String, Frag)])
fit cm providers force frag expr n doms =
  let (pats, core) = lambdaSpine expr
      (pats', remaining, doms1, exhausted) = walk frag pats doms
      (etaPats, core1, coreFrag, n1)
        | exhausted && (force || introCore core)
            && spineNeedsBinder remaining =
            etaExpand remaining core n
        | otherwise = ([], core, remaining, n)
      (core2, n2, doms2) =
        fitCore cm providers force coreFrag core1 n1 doms1
      allPats = pats' ++ etaPats
  in (if null allPats then core2 else Lambda allPats core2, n2, doms2)
 where
  lambdaSpine (Lambda ps b) =
    let (more, coreExpr) = lambdaSpine b in (ps ++ more, coreExpr)
  lambdaSpine e = ([], e)

  -- an implicit quantifier costs no binder, so peel it even after the
  -- candidate's binders run out - otherwise the fragment handed on is
  -- the quantifier rather than the connective underneath it, and the
  -- body never gets fitted at all
  walk (FAll False _ rest) ps ds = walk rest ps ds
  walk f [] ds = ([], f, ds, True)
  walk (FArr dom rest) (p : ps) ds =
    let (ps', f', ds', ex) = walk rest ps (bindDomainPairs p dom ++ ds)
    in (p : ps', f', ds', ex)
  walk (FAll True _ rest) ps ds =
    let (ps', f', ds', ex) = walk rest ps ds
    in (Wildcard : ps', f', ds', ex)
  walk (FInst _ rest) ps ds =
    let (ps', f', ds', ex) = walk rest ps ds
    in (Wildcard : ps', f', ds', ex)
  walk (FExactContext _ _ rest) ps ds =
    let (ps', f', ds', ex) = walk rest ps ds
    in (Wildcard : ps', f', ds', ex)
  walk f ps ds = (ps, f, ds, False)

  introCore e = case e of
    Tuple _ -> True
    Global _ -> True
    Apply h _ -> introCore h
    VisibleTypeApplication h _ -> introCore h
    _ -> False

  spineNeedsBinder f =
    SlotAll True `elem` fragSpine f || SlotInst `elem` fragSpine f

  etaExpand f core k = case f of
    FArr _ rest ->
      let name = "z" ++ show k
          (ps, core', f', k') =
            etaExpand rest (Apply core (Local name)) (k + 1)
      in (Bind name : ps, core', f', k')
    FAll True _ rest ->
      let (ps, core', f', k') = etaExpand rest core k
      in (Wildcard : ps, core', f', k')
    FAll False _ rest -> etaExpand rest core k
    FInst _ rest ->
      let (ps, core', f', k') = etaExpand rest core k
      in (Wildcard : ps, core', f', k')
    FExactContext _ _ rest ->
      let (ps, core', f', k') = etaExpand rest core k
      in (Wildcard : ps, core', f', k')
    _ -> ([], core, f, k)

-- | Recurse through introduction forms whose component types the goal
-- fragment determines, through elimination inputs far enough to fit
-- applications whose heads have known source fragments, and through match
-- alternatives (branches produce the scrutinized position's type;
-- sum\/product eliminations also reveal the branch binders' domains when the
-- scrutinee has a known local or provider fragment, whose quantifiers -
-- instantiated silently by the engine before the case split - are peeled
-- first).
fitCore :: CtorMap -> ProviderMap -> Bool -> Frag -> Expression String -> Int
        -> [(String, Frag)] -> (Expression String, Int, [(String, Frag)])
fitCore cm providers force cf ce n ds = case (cf, ce) of
  (FProd a b, Tuple [x, y]) ->
    let (x', n1, ds1) = fit cm providers force a x n ds
        (y', n2, ds2) = fit cm providers force b y n1 ds1
    in (Tuple [x', y'], n2, ds2)
  (FSum a _, Apply h@(Global g) x) | isKind GInl g ->
    let (x', n1, ds1) = fit cm providers force a x n ds
    in (Apply h x', n1, ds1)
  (FSum _ b, Apply h@(Global g) x) | isKind GInr g ->
    let (x', n1, ds1) = fit cm providers force b x n ds
    in (Apply h x', n1, ds1)
  -- a fully applied declared constructor: fit each argument against
  -- the corresponding field fragment
  (resultFrag, _)
    | isDeclaredData resultFrag
    , (Global g, args@(_ : _)) <- appSpine ce
    , Just info <- declaredCtor cm g
    , Just fields <- constructorFieldsAt resultFrag info
    , length args == length fields ->
        let step (done, k, dss) (field, arg) =
              let (arg', k', dss') =
                    fit cm providers force field arg k dss
              in (done ++ [arg'], k', dss')
            (args', n1, ds1) = foldl step ([], n, ds) (zip fields args)
        in (foldl Apply (Global g) args', n1, ds1)
  -- an eliminated absurdity whose expected type is itself ⊥ needs no
  -- elimination at all
  (FBot, Case scrut []) ->
    fitCore cm providers force FBot scrut n ds
  -- An application of a known local hypothesis or discovered global provider:
  -- fit each term argument against the successive explicit-arrow domains of
  -- its type, so binders inside those arguments are named and fitted too.
  -- Provider globals retain their source fragment in 'ProviderMap'; without
  -- it a constructed @forall@ argument would lose Lean's explicit type-binder
  -- wildcard and be rejected only at backend verification.
  (_, _)
    | Just fitted <- fitKnownApplication ce n ds -> fitted
  (_, VisibleTypeApplication function argument) ->
    let (function', n1, ds1) =
          fitCore cm providers force cf function n ds
    in (VisibleTypeApplication function' argument, n1, ds1)
  (_, Case scrut alts) ->
    let (scrut', n0, ds0) = fitEliminationInput scrut n ds
        scrutFrag = knownExpressionFrag ds0 scrut'
        goAlt (done, k, dss) (pat, body) =
          let branchDoms = eliminationPatternDomains scrutFrag pat
              (body', k', dss') =
                fit cm providers force cf body k (branchDoms ++ dss)
          in (done ++ [(pat, body')], k', dss')
        (alts', n1, ds1) = foldl goAlt ([], n0, ds0) alts
    in (Case scrut' alts', n1, ds1)
  (_, Let pat rhs body) ->
    let (rhs', n0, ds0) = fitEliminationInput rhs n ds
        aliasDoms = maybe [] (bindDomainPairs pat)
          (knownExpressionFrag ds0 rhs')
        (body', n1, ds1) =
          fit cm providers force cf body n0 (aliasDoms ++ ds0)
    in (Let pat rhs' body', n1, ds1)
  _ -> (ce, n, ds)
 where
  isKind k g = case (globalKind cm g, k) of
    (Right GInl, GInl) -> True
    (Right GInr, GInr) -> True
    _ -> False
  -- Complete exact recursive families are declared nominally for both engines
  -- just like expanded non-recursive inductives.  Their constructor arguments
  -- and Exference match binders therefore need the same fragment-directed
  -- fitting.  The constructor-map guard above keeps opaque/partial recursive
  -- occurrences out even when their fragment constructor is present here.
  isDeclaredData FParamInd{} = True
  isDeclaredData FInd{} = True
  isDeclaredData FParamRec{} = True
  isDeclaredData FRec{} = True
  isDeclaredData _ = False
  appSpine expr = spineAcc expr []
  spineAcc (Apply f a) acc = spineAcc f (a : acc)
  spineAcc f acc = (f, acc)
  applicationHeadFrag dss headExpr = case headExpr of
    Local local -> lookup local dss
    Global global -> case declaredProvider providers global of
      Just info -> Just (piFrag info)
      Nothing -> Nothing
    VisibleTypeApplication function _ -> applicationHeadFrag dss function
    _ -> Nothing
  -- Recover the result fragment of a local/provider expression after its full
  -- application spine has been consumed.  This is deliberately shared by case
  -- and let fitting: a provider can expose a structured value directly or
  -- return one from an application, and either elimination must retain the
  -- domains of the fields it binds.  Djex's generated tree intentionally does
  -- not annotate ordinary inferred applications, but an argument which is a
  -- known local or provider still has an exact Lean-side fragment here. Match
  -- that fragment against the corresponding arrow domain and specialize the
  -- provider result capture-avoidably. Opened binders receive collision-free
  -- private identities, so an unresolved binder can safely remain opaque in
  -- a known result envelope; conflicting evidence still fails closed.
  knownExpressionFrag dss expression = do
    (_, _, _, resultFrag) <-
      analyzeKnownApplication Set.empty dss expression
    pure resultFrag
  knownArgumentFrag avoiding dss expression =
    case expressionFullApplicationSpine expression of
      (Local local, []) -> lookup local dss
      (Global global, []) ->
        piFrag
          <$> declaredProvider providers global
      _ -> do
        (_, _, _, resultFrag) <-
          analyzeExactApplication avoiding dss expression
        pure resultFrag
  -- Analyze once for both elimination-result recovery and argument fitting.
  -- Each returned term domain includes every replacement learned at that
  -- argument, while the complete mixed spine is retained for reconstruction.
  analyzeKnownApplication = analyzeApplication False
  analyzeExactApplication = analyzeApplication True
  analyzeApplication preserveTrailing avoiding dss expression = do
    let (headExpr, arguments) = expressionFullApplicationSpine expression
    headFrag <- applicationHeadFrag dss headExpr
    let exactArguments = case headExpr of
          Global global ->
            declaredProvider providers global >>= (`providerAssignmentAt` arguments)
          _ -> Nothing
        retainedArguments = maybe [] id exactArguments
        reserved = Set.unions $
          [ avoiding
          , fragVariableNames headFrag
          ]
          ++ map providerArgumentVariableNames retainedArguments
          ++ map (fragVariableNames . snd) dss
    (termDomains, resultFrag) <-
      consumeApplication preserveTrailing dss reserved retainedArguments
        arguments headFrag
    pure (headExpr, arguments, termDomains, resultFrag)
  consumeApplication preserveTrailing dss reserved = go Set.empty [] []
   where
    go consumed replacements termDomains exactArguments arguments sourceFrag =
      let frag = specializeFrag replacements sourceFrag
      in case frag of
        FAll _ binder rest
          -- An exact term argument retains an unapplied trailing binder.
          -- Elimination analysis instead keeps the historical silent opening
          -- needed to expose a provider's structural result to case or let.
          | preserveTrailing && null arguments ->
              finish replacements termDomains arguments frag
          | otherwise ->
              let replacementNames = Set.unions
                    [ Set.insert formal (fragVariableNames replacement)
                    | (formal, replacement) <- replacements
                    ]
                  fresh = freshFragBinder $ Set.unions
                    [ reserved
                    , consumed
                    , replacementNames
                    , fragVariableNames rest
                    ]
                  opened = renameFragBinder binder fresh rest
                  (replacements', remainingExact, remaining) = case arguments of
                    VisibleTypeArgumentArgument _ : tailArguments ->
                      case exactArguments of
                        exact : tailExact ->
                          ( maybe replacements
                              (\replacement ->
                                replacements ++ [(fresh, replacement)])
                              (properProviderArgument exact)
                          , tailExact
                          , tailArguments
                          )
                        [] -> (replacements, [], tailArguments)
                    _ -> (replacements, exactArguments, arguments)
              in go (Set.insert fresh consumed) replacements'
                termDomains remainingExact remaining opened
        FInst _ rest
          | preserveTrailing && null arguments ->
              finish replacements termDomains arguments frag
          | otherwise ->
              go consumed replacements termDomains exactArguments arguments rest
        FExactContext _ _ rest
          | preserveTrailing && null arguments ->
              finish replacements termDomains arguments frag
          | otherwise ->
              go consumed replacements termDomains exactArguments arguments rest
        FArr domain rest -> case arguments of
          TermArgument argument : remaining -> do
            let replacementNames = Set.unions
                  [ Set.insert formal (fragVariableNames replacement)
                  | (formal, replacement) <- replacements
                  ]
                argumentAvoiding = Set.unions
                  [reserved, consumed, replacementNames]
            replacements' <- case
                knownArgumentFrag argumentAvoiding dss argument of
              Nothing -> Just replacements
              Just actual ->
                inferFragReplacements consumed replacements domain actual
            let fittedDomain = specializeFrag replacements' domain
            go consumed replacements' (fittedDomain : termDomains)
              exactArguments remaining rest
          _ -> finish replacements termDomains arguments frag
        _ -> finish replacements termDomains arguments frag

    finish replacements termDomains arguments frag
      | not (null arguments) = Nothing
      | otherwise = Just
          (reverse termDomains, specializeFrag replacements frag)
  eliminationPatternDomains scrutineeFrag pat =
    case (scrutineeFrag, pat) of
      (Just (FSum a _), Constructor g [p])
        | Right GInl <- globalKind cm g -> bindDomainPairs p a
      (Just (FSum _ b), Constructor g [p])
        | Right GInr <- globalKind cm g -> bindDomainPairs p b
      (Just frag, Constructor g ps)
        | isDeclaredData frag
        , Just info <- declaredCtor cm g
        , Just fields <- constructorFieldsAt frag info
        , length ps == length fields ->
            concat (zipWith bindDomainPairs ps fields)
      (Just frag, TuplePattern _) -> bindDomainPairs pat frag
      (Just frag, Bind x) -> [(x, frag)]
      _ -> []
  fitKnownApplication expression k dss = do
    (headExpr, arguments, termDomains, _) <-
      analyzeKnownApplication Set.empty dss expression
    if null termDomains
      then Nothing
      else
        let step (fittedArguments, j, env, domains) applicationArgument =
              case (applicationArgument, domains) of
                (VisibleTypeArgumentArgument argument, _) ->
                  ( VisibleTypeArgumentArgument argument : fittedArguments
                  , j
                  , env
                  , domains
                  )
                (TermArgument argument, domain : remaining) ->
                  let exactArgument = knownArgumentFrag
                        (fragVariableNames domain) env argument
                      (argument', j', env') = case exactArgument of
                        Just actual
                          | equivalentFrag domain actual ->
                              fitEliminationInput argument j env
                        _ -> fit cm providers force domain argument j env
                  in (TermArgument argument' : fittedArguments, j', env', remaining)
                -- 'analyzeKnownApplication' accepts a term argument only by
                -- consuming one arrow, so this branch is defensive.
                (TermArgument argument, []) ->
                  (TermArgument argument : fittedArguments, j, env, [])
            (reversedArguments, k', dss', _) =
              foldl step ([], k, dss, termDomains) arguments
            fitted = applyExpressionArguments headExpr
              (reverse reversedArguments)
        in Just (fitted, k', dss')
  -- A case scrutinee or let RHS has its own result type, which the enclosing
  -- goal fragment does not describe.  Traverse that input structurally and
  -- invoke fragment-directed fitting only at an application whose local or
  -- provider head has an exact source fragment.  This preserves every
  -- unrelated node and reaches known applications beneath lambdas, tuples,
  -- unknown applications, and nested eliminations without guessing the
  -- input's result fragment.
  fitEliminationInput expression k dss =
    case fitKnownApplication expression k dss of
      Just fitted -> fitted
      Nothing -> case expression of
        Apply function argument ->
          let (function', k1, dss1) =
                fitEliminationInput function k dss
              (argument', k2, dss2) =
                fitEliminationInput argument k1 dss1
          in (Apply function' argument', k2, dss2)
        VisibleTypeApplication function argument ->
          let (function', k1, dss1) =
                fitEliminationInput function k dss
          in (VisibleTypeApplication function' argument, k1, dss1)
        Lambda patterns body ->
          let (body', k1, dss1) = fitEliminationInput body k dss
          in (Lambda patterns body', k1, dss1)
        Tuple elements ->
          let step (done, j, env) element =
                let (element', j', env') =
                      fitEliminationInput element j env
                in (done ++ [element'], j', env')
              (elements', k1, dss1) = foldl step ([], k, dss) elements
          in (Tuple elements', k1, dss1)
        Let pat rhs body ->
          let (rhs', k1, dss1) = fitEliminationInput rhs k dss
              aliasDoms = maybe [] (bindDomainPairs pat)
                (knownExpressionFrag dss1 rhs')
              (body', k2, dss2) =
                fitEliminationInput body k1 (aliasDoms ++ dss1)
          in (Let pat rhs' body', k2, dss2)
        Case scrut alts ->
          let (scrut', k1, dss1) = fitEliminationInput scrut k dss
              scrutFrag = knownExpressionFrag dss1 scrut'
              step (done, j, env) (pat, body) =
                let branchDoms = eliminationPatternDomains scrutFrag pat
                    (body', j', env') =
                      fitEliminationInput body j (branchDoms ++ env)
                in (done ++ [(pat, body')], j', env')
              (alts', k2, dss2) = foldl step ([], k1, dss1) alts
          in (Case scrut' alts', k2, dss2)
        Local _ -> (expression, k, dss)
        Global _ -> (expression, k, dss)
        Hole _ -> (expression, k, dss)
-- | Recover the constructor's field fragments at the exact result or
-- scrutinee occurrence being fitted.  Legacy occurrence-local declarations
-- already carry specialized fields.  Shared parametric declarations instead
-- substitute their private schema formals with this occurrence's ordered Lean
-- parameters, so constructor arguments and pattern binders receive the right
-- rank-N domains even when the declaration template came from a provider.
constructorFieldsAt :: Frag -> CtorInfo -> Maybe [Frag]
constructorFieldsAt occurrence info = case ciParametric info of
  Nothing -> Just (ciFields info)
  Just (familyHead, formals) -> do
    (parameters, occurrenceFields) <- case occurrence of
      FParamInd occurrenceHead _ occurrenceParameters constructors
        | occurrenceHead == familyHead ->
            Just (occurrenceParameters, lookup (ciLean info) constructors)
      FParamRec _ occurrenceHead _ occurrenceParameters constructors
        | occurrenceHead == familyHead ->
            Just (occurrenceParameters, lookup (ciLean info) constructors)
      _ -> Nothing
    if length parameters == length formals
      -- The family planner already validated this occurrence against the
      -- shared template.  Prefer its own fields: besides avoiding needless
      -- reconstruction, this preserves alpha-renaming chosen by the Lean
      -- serializer when an actual parameter name would otherwise be captured
      -- by a constructor-local forall.  The generic specialization remains a
      -- defensive fallback for a fitting fragment without constructor data.
      then Just $ case occurrenceFields of
        Just fields -> fields
        Nothing -> map
          (specializeFrag (zip formals parameters)) (ciFields info)
      else Nothing

-- | Infer exact replacements for variables opened by the known expression's
-- leading forall spine. Matching follows only structural positions which can
-- contain those variables; unrelated display keys and refutation flags are
-- deliberately ignored. A repeated variable must receive the identical exact
-- fragment, while higher-kinded variables in application-head position remain
-- unsupported and therefore fail closed.
inferFragReplacements
  :: Set.Set String -> [(String, Frag)] -> Frag -> Frag
  -> Maybe [(String, Frag)]
inferFragReplacements targets = go Set.empty
 where
  go bound replacements (FVar variable) actual
    | variable `Set.member` targets
    , variable `Set.notMember` bound = case lookup variable replacements of
        Nothing -> Just (replacements ++ [(variable, actual)])
        Just previous
          | equivalentFrag previous actual -> Just replacements
          | otherwise -> Nothing
  go _ replacements (FVar variable) (FVar variable')
    | variable == variable' = Just replacements
  go bound replacements (FArr left right) (FArr left' right') = do
    replacements' <- go bound replacements left left'
    go bound replacements' right right'
  go bound replacements (FProd left right) (FProd left' right') = do
    replacements' <- go bound replacements left left'
    go bound replacements' right right'
  go bound replacements (FSum left right) (FSum left' right') = do
    replacements' <- go bound replacements left left'
    go bound replacements' right right'
  go bound replacements (FAll explicit binder body)
      (FAll explicit' binder' body')
    | explicit == explicit' =
        let reserved = Set.unions
              [ targets
              , bound
              , fragVariableNames body
              , fragVariableNames body'
              , Set.unions
                  [ Set.insert formal (fragVariableNames replacement)
                  | (formal, replacement) <- replacements
                  ]
              ]
            fresh = freshFragBinder reserved
            expected' = renameFragBinder binder fresh body
            actual' = renameFragBinder binder' fresh body'
        in go (Set.insert fresh bound) replacements expected' actual'
  go bound replacements (FInst key body) (FInst key' body')
    | key == key' = go bound replacements body body'
  go bound replacements
      (FExactContext className arguments body)
      (FExactContext className' arguments' body')
    | className == className'
    , length arguments == length arguments' = do
        replacements' <- foldM (matchContextArgument bound)
          replacements (zip arguments arguments')
        go bound replacements' body body'
  go bound replacements (FApp _ _ head' arguments)
      (FApp _ _ head'' arguments')
    | head' == head''
    , not (targetApplicationHead head')
    , length arguments == length arguments' =
        matchMany bound replacements (zip arguments arguments')
  go bound replacements
      (FParamInd headName _ parameters _)
      (FParamInd headName' _ parameters' _)
    | headName == headName'
    , length parameters == length parameters' =
        matchMany bound replacements (zip parameters parameters')
  go _ replacements (FInd key _) (FInd key' _)
    | key == key' = Just replacements
  go bound replacements
      (FParamRec _ headName _ parameters _)
      (FParamRec _ headName' _ parameters' _)
    | headName == headName'
    , length parameters == length parameters' =
        matchMany bound replacements (zip parameters parameters')
  go bound replacements (FRec complete key parameters _)
      (FRec complete' key' parameters' _)
    | complete == complete'
    , key == key'
    , length parameters == length parameters' =
        matchMany bound replacements (zip parameters parameters')
  go _ replacements (FAtom _ key) (FAtom _ key')
    | key == key' = Just replacements
  go _ replacements FTop FTop = Just replacements
  go _ replacements FBot FBot = Just replacements
  go _ replacements FDepth FDepth = Just replacements
  go _ _ _ _ = Nothing

  matchMany bound = foldM
    (\replacements (expected, actual) ->
      go bound replacements expected actual)

  matchContextArgument bound replacements (expected, actual) =
    case (contextNominalUse expected, contextNominalUse actual) of
      ( Just (expectedArity, expectedHead, expectedSupplied)
        , Just (actualArity, actualHead, actualSupplied)
        )
        | expectedArity == actualArity
        , expectedHead == actualHead
        , length expectedSupplied == length actualSupplied ->
            matchMany bound replacements
              (zip expectedSupplied actualSupplied)
      (Nothing, Nothing) -> case (expected, actual) of
        ( ExactContextFragmentArgument expectedArity expectedFrag
          , ExactContextFragmentArgument actualArity actualFrag
          )
          | expectedArity == 0
          , actualArity == 0 ->
              go bound replacements expectedFrag actualFrag
        _ -> Nothing
      _ -> Nothing

  contextNominalUse argument = case argument of
    ExactContextNominalArgument remaining spelling supplied
      | remaining > 0
      , not (null spelling)
      , canonicalHeadSupported spelling (length supplied + remaining) ->
          Just (length supplied + remaining, spelling, supplied)
    ExactContextFragmentArgument remaining child
      | remaining > 0 -> case child of
          FAtom _ spelling
            | legacyHeadSupported spelling ->
                Just (remaining, spelling, [])
          FApp _ _ (AppNominal spelling) supplied
            | legacyHeadSupported spelling ->
                Just (length supplied + remaining, spelling, supplied)
          _ -> Nothing
    _ -> Nothing

  canonicalHeadSupported spelling totalArity
    | elem spelling ["Prod", "Sum"] = totalArity == 2
    | otherwise = legacyHeadSupported spelling
  legacyHeadSupported spelling =
    not (null spelling)
      && not (elem spelling
        ["And", "Prod", "PProd", "Or", "Sum", "PSum", "Iff", "Not"])

  targetApplicationHead head' = case head' of
    AppVariable variable -> variable `Set.member` targets
    AppNominal _ -> False


-- | Alpha-aware equality for exact first-order fragments, deliberately using
-- the same metadata-insensitive structural relation as replacement inference.
equivalentFrag :: Frag -> Frag -> Bool
equivalentFrag left right = case
    inferFragReplacements Set.empty [] left right of
  Just _ -> True
  Nothing -> False

-- | Capture-avoiding substitution shared by known-application result fitting
-- and the defensive generic-field fallback. Family formals use private
-- spellings, but exact argument fragments may reuse a result-local binder
-- name, so conflicting binders are renamed before an actual is inserted.
specializeFrag :: [(String, Frag)] -> Frag -> Frag
specializeFrag replacements = go Set.empty
 where
  replacementFree = Set.unions
    [ freeFragVariables Set.empty replacement
    | (_, replacement) <- replacements
    ]
  replacementNames = Set.unions
    [ Set.insert formal (fragVariableNames replacement)
    | (formal, replacement) <- replacements
    ]

  go bound frag = case frag of
    FVar variable
      | variable `Set.notMember` bound
      , Just replacement <- lookup variable replacements -> replacement
      | otherwise -> frag
    FArr parameter result -> FArr (recur parameter) (recur result)
    FProd left right -> FProd (recur left) (recur right)
    FSum left right -> FSum (recur left) (recur right)
    FAll explicit binder body
      | binder `Set.member` replacementFree ->
          let fresh = freshFragBinder
                (bound `Set.union` replacementNames
                  `Set.union` fragVariableNames body)
              renamed = renameFragBinder binder fresh body
          in FAll explicit fresh (go (Set.insert fresh bound) renamed)
      | otherwise ->
          FAll explicit binder (go (Set.insert binder bound) body)
    FInst key body -> FInst key (recur body)
    FExactContext className arguments body ->
      FExactContext className
        (map (mapExactContextArgumentFragments recur) arguments)
        (recur body)
    FApp safe key head' arguments ->
      FApp safe key head' (map recur arguments)
    FParamInd headName key parameters constructors ->
      FParamInd headName key (map recur parameters)
        (mapCtorFields bound constructors)
    FInd key constructors -> FInd key (mapCtorFields bound constructors)
    FParamRec complete headName key parameters constructors ->
      FParamRec complete headName key (map recur parameters)
        (mapCtorFields bound constructors)
    FRec complete key parameters constructors ->
      FRec complete key (map recur parameters)
        (mapCtorFields bound constructors)
    other -> other
   where
    recur = go bound

  mapCtorFields bound = map
    (\(name, fields) -> (name, map (go bound) fields))

freeFragVariables :: Set.Set String -> Frag -> Set.Set String
freeFragVariables bound frag = case frag of
  FArr parameter result -> descend [parameter, result]
  FProd left right -> descend [left, right]
  FSum left right -> descend [left, right]
  FAll _ binder body -> freeFragVariables (Set.insert binder bound) body
  FInst _ body -> freeFragVariables bound body
  FExactContext _ arguments body ->
    descend
      (concatMap exactContextArgumentPayloadFragments arguments ++ [body])
  FVar variable
    | variable `Set.member` bound -> Set.empty
    | otherwise -> Set.singleton variable
  FApp _ _ head' arguments ->
    let headVariables = case head' of
          AppVariable variable
            | variable `Set.member` bound -> Set.empty
            | otherwise -> Set.singleton variable
          AppNominal _ -> Set.empty
    in headVariables `Set.union` descend arguments
  FParamInd _ _ parameters _ -> descend parameters
  FInd _ constructors -> descend (concatMap snd constructors)
  FParamRec _ _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  FRec _ _ parameters constructors ->
    descend (parameters ++ concatMap snd constructors)
  _ -> Set.empty
 where
  descend = Set.unions . map (freeFragVariables bound)

fragVariableNames :: Frag -> Set.Set String
fragVariableNames frag = case frag of
  FArr parameter result -> descend [parameter, result]
  FProd left right -> descend [left, right]
  FSum left right -> descend [left, right]
  FAll _ binder body -> Set.insert binder (fragVariableNames body)
  FInst _ body -> fragVariableNames body
  FExactContext _ arguments body ->
    descend
      (concatMap exactContextArgumentPayloadFragments arguments ++ [body])
  FVar variable -> Set.singleton variable
  FApp _ _ head' arguments ->
    let headNames = case head' of
          AppVariable variable -> Set.singleton variable
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
  descend = Set.unions . map fragVariableNames

freshFragBinder :: Set.Set String -> String
freshFragBinder reserved = choose (0 :: Int)
 where
  choose index =
    let candidate = "\0leant-render-bound:" ++ show index
    in if candidate `Set.member` reserved
        then choose (index + 1)
        else candidate

renameFragBinder :: String -> String -> Frag -> Frag
renameFragBinder old new frag = case frag of
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
  FVar variable
    | variable == old -> FVar new
    | otherwise -> frag
  FApp safe key head' arguments ->
    let renamedHead = case head' of
          AppVariable variable
            | variable == old -> AppVariable new
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
  go = renameFragBinder old new
  mapCtorFields = map (\(name, fields) -> (name, map go fields))

-- | Binders whose domain type the goal fragment determines, recursing
-- through tuple destructuring.
bindDomainPairs :: Pattern String -> Frag -> [(String, Frag)]
bindDomainPairs (Bind x) dom = [(x, dom)]
bindDomainPairs (TuplePattern [p, q]) (FProd a b) =
  bindDomainPairs p a ++ bindDomainPairs q b
bindDomainPairs _ _ = []

-- Ambiguous instantiation sites ----------------------------------------------
--
-- A use of a quantified hypothesis whose type still has leading explicit
-- quantifiers after the supplied term arguments may be a transport of
-- the remaining pi type or an instantiation at a type the elaborator
-- must infer.  Such sites are numbered (in one fixed traversal order)
-- and 'markSites' tags a chosen subset for instantiation; the tag is a
-- reserved character no binder name can contain.

instTag :: String
instTag = "\1"

tagged :: String -> Bool
tagged = (instTag ==) . take 1

stripTag :: String -> String
stripTag x = if tagged x then drop 1 x else x

stripMark :: String -> String
stripMark x = if marked x then drop 1 x else x

-- | Trailing explicit quantifiers of @frag@ once @k@ term arguments have
-- been consumed (with @k = 0@ this is 'leadingTypeArgs').
trailingAlls :: Frag -> Int -> Int
trailingAlls frag 0 = leadingTypeArgs frag
trailingAlls (FAll _ _ rest) k = trailingAlls rest k
trailingAlls (FInst _ rest) k = trailingAlls rest k
trailingAlls (FExactContext _ _ rest) k = trailingAlls rest k
trailingAlls (FArr _ rest) k = trailingAlls rest (k - 1)
trailingAlls _ _ = 0

countSites :: Map.Map String Frag -> Expression String -> Int
countSites doms expr = snd (markOrCount doms [] expr 0)

markSites :: Map.Map String Frag -> [Int] -> Expression String
          -> Expression String
markSites doms set expr = fst (markOrCount doms set expr 0)

-- | One traversal serving both passes: numbers each ambiguous site and
-- rewrites the chosen ones to tagged names.
markOrCount :: Map.Map String Frag -> [Int] -> Expression String -> Int
            -> (Expression String, Int)
markOrCount doms set = go
 where
  go expr i = case expr of
    Local x -> site x [] i (\x' -> Local x')
    Apply _ _ ->
      let (headExpr, args) = spine expr []
          goArgs [] j = ([], j)
          goArgs (a : as) j =
            let (a', j1) = go a j
                (as', j2) = goArgs as j1
            in (a' : as', j2)
      in case headExpr of
        Local x ->
          let (args', i1) = goArgs args i
          in site x args' i1 (\x' -> foldl Apply (Local x') args')
        _ ->
          let (h', i1) = go headExpr i
              (args', i2) = goArgs args i1
          in (foldl Apply h' args', i2)
    VisibleTypeApplication function argument ->
      let (function', i') = visibleFunction function i
      in (VisibleTypeApplication function' argument, i')
    Tuple es ->
      let (es', i') = goMany es i in (Tuple es', i')
    Lambda pats body ->
      let (body', i') = go body i in (Lambda pats body', i')
    Let pat rhs body ->
      let (rhs', i1) = go rhs i
          (body', i2) = go body i1
      in (Let pat rhs' body', i2)
    Case scrut alts ->
      let (scrut', i1) = go scrut i
          goAlt (pat, body) j =
            let (body', j') = go body j in ((pat, body'), j')
          (alts', i2) = foldl
            (\(done, j) alt -> let (alt', j') = goAlt alt j
                               in (done ++ [alt'], j'))
            ([], i1) alts
      in (Case scrut' alts', i2)
    Global _ -> (expr, i)
    Hole _ -> (expr, i)

  -- A visible application is already an intentional instantiation site.
  -- Exference emits the complete leading binder prefix, so do not also tag
  -- its local head for the older inferred-placeholder variants.  Term
  -- arguments inside the function are still ordinary expression uses and
  -- must participate in the traversal.
  visibleFunction expr i = case expr of
    Local _ -> (expr, i)
    Apply _ _ ->
      let (headExpr, args) = spine expr []
          (headExpr', i1) = visibleFunction headExpr i
          (args', i2) = goMany args i1
      in (foldl Apply headExpr' args', i2)
    VisibleTypeApplication function argument ->
      let (function', i') = visibleFunction function i
      in (VisibleTypeApplication function' argument, i')
    _ -> go expr i

  goMany [] i = ([], i)
  goMany (e : es) i =
    let (e', i1) = go e i
        (es', i2) = goMany es i1
    in (e' : es', i2)

  site x args i rebuild = case Map.lookup x doms of
    Just frag | trailingAlls frag (length args) > 0 ->
      ( rebuild (if i `elem` set then instTag ++ x else x)
      , i + 1
      )
    _ -> (rebuild x, i)

  spine (Apply f a) acc = spine f (a : acc)
  spine f acc = (f, acc)

-- Rendering ------------------------------------------------------------------
--
-- Precedence levels: 0 = open (fun/match/let/nomatch), 1 = application,
-- 2 = atom.  A subterm rendered in a position requiring a higher level is
-- parenthesized.  @doms@ maps quantified-hypothesis binders to their
-- domain fragments: applications weave @_@ placeholders through the
-- argument list wherever the type's spine has an explicit quantifier,
-- and tagged occurrences additionally instantiate their trailing
-- quantifiers.

-- | Constructor-spelling preference for one rendering pass.
data Style = Idiomatic | Explicit
  deriving (Eq)

-- A positional local application provides too little expected-type
-- information for Lean to solve some impredicative binder universes from @_@
-- alone. Keep that historical best guess first, then offer bounded Type- and
-- Prop-directed variants for backend verification. Named global arguments do
-- not need this fallback because their binder type supplies the direction.
data VisibleBinderDomain
  = InferredVisibleBinderDomain
  | TypeVisibleBinderDomain
  | PropVisibleBinderDomain
  | SortVisibleBinderDomain
  deriving (Eq)

visibleBinderDomains :: [VisibleBinderDomain]
visibleBinderDomains =
  [ InferredVisibleBinderDomain
  , TypeVisibleBinderDomain
  , PropVisibleBinderDomain
  ]

-- Applied separately to the three bounded domain lanes in 'renderLeanTerm'.
-- Thirty-two preserves the complete source-selection prefix above before
-- style/site fallbacks; the final candidate group remains bounded at 96.
visibleBinderDomainVariantLimit :: Int
visibleBinderDomainVariantLimit = maximumProviderInstantiationAssignments

render
  :: CtorMap -> ProviderMap -> TypeMap -> Style -> VisibleBinderDomain
  -> Map.Map String Frag
  -> Int -> Expression String -> Either String String
render cm providers typeNames style visibleBinderDomain doms = go
 where
  go :: Int -> Expression String -> Either String String
  go req expr = case expr of
    Local x -> renderUse req x []
    Global name -> case declaredProvider providers name of
      Just info -> Right (at req 2 (piLeanName info))
      Nothing -> do
        kind <- globalKind cm name
        case kind of
          GUnit -> Right (at req 2 "\10216\10217")
          GInl -> Right (at req 0 ".inl")
          GInr -> Right (at req 0 ".inr")
          GCtor info -> case style of
            Idiomatic
              | ciSole info && null (ciFields info) ->
                  Right (at req 2 "\10216\10217")
              | otherwise -> Right (at req 0 (shortDot (ciLean info)))
            Explicit -> Right (at req 2 (ciLean info))
    Apply _ _ -> do
      let (headExpr, args) = spine expr []
      case headExpr of
        Local x -> do
          argTxts <- mapM (go 2) args
          renderUse req x argTxts
        Global g
          | Just info <- declaredProvider providers g -> do
              argTxts <- mapM (go 2) args
              Right (at req 1
                (unwords (piLeanName info : weaveArgs (piFrag info) argTxts)))
        Global g
          | Right (GCtor info) <- globalKind cm g
          , style == Idiomatic
          , ciSole info
          , length args == length (ciFields info) -> do
              argTxts <- mapM (go 0) args
              Right (at req 2
                ("\10216" ++ intercalate ", " argTxts ++ "\10217"))
        _ -> do
          headTxt <- renderHead headExpr
          argTxts <- mapM (go 2) args
          Right (at req 1 (unwords (headTxt : argTxts)))
    VisibleTypeApplication function argument ->
      case namedProviderApplication expr of
        Left failure -> Left failure
        Right (Just (leanName, assignments)) -> do
          rendered <- mapM
            (\(binder, value, source) -> do
              valueTxt <- case source of
                Nothing -> renderNamedVisibleTypeArgument typeNames value
                Just exact -> renderExactNamedVisibleTypeArgument
                  visibleBinderDomain typeNames exact value
              pure (" (" ++ binder ++ " := " ++ valueTxt ++ ")"))
            assignments
          Right (at req 1 (leanName ++ concat rendered))
        Right Nothing -> do
          functionTxt <- visibleFunctionText function
          argumentTxt <-
            if localVisibleHead function
              then renderVisibleTypeArgumentWith
                visibleBinderDomain True typeNames argument
              else renderVisibleTypeArgument typeNames argument
          Right (at req 1 (functionTxt ++ " " ++ argumentTxt))
    Lambda [] body -> go req body
    Lambda pats body -> do
      binders <- mapM (renderPattern cm style True) pats
      bodyTxt <- go 0 body
      Right (at req 0 ("fun " ++ unwords binders ++ " => " ++ bodyTxt))
    Tuple es -> do
      txts <- mapM (go 0) es
      Right (at req 2 ("\10216" ++ intercalate ", " txts ++ "\10217"))
    Let pat rhs body -> do
      patTxt <- renderPattern cm style True pat
      rhsTxt <- go 0 rhs
      bodyTxt <- go 0 body
      Right (at req 0
        ("let " ++ patTxt ++ " := " ++ rhsTxt ++ "; " ++ bodyTxt))
    Case scrut []
      -- a one-argument negation applied and eliminated is `absurd`
      -- in idiomatic Lean; the explicit style keeps `nomatch` for
      -- the cases where `absurd`'s Prop-only hypothesis fails
      | Idiomatic <- style
      , Apply (Local kx) argE <- scrut
      , Just frag <- Map.lookup (stripTag kx) doms
      , isUnaryNeg frag -> do
          argTxt <- go 2 argE
          Right (at req 1
            ("absurd " ++ argTxt ++ " " ++ stripMark (stripTag kx)))
    Case scrut [] -> do
      scrutTxt <- go 2 scrut
      Right (at req 0 ("nomatch " ++ scrutTxt))
    Case scrut alts -> do
      scrutTxt <- go 1 scrut
      altTxts <- mapM renderAlt alts
      Right (at req 0 ("match " ++ scrutTxt ++ " with " ++ unwords altTxts))
    Hole _ -> Left "candidate contains an unfilled hole"

  -- one use of a (possibly tagged) local with already-rendered term
  -- arguments: weave mid-spine placeholders, and instantiate the
  -- trailing quantifiers when the site is tagged
  renderUse req x argTxts =
    let name = stripMark (stripTag x)
        -- domain lookups keep the premise mark (premise entries are
        -- seeded under their marked names); only the display strips it
        key = stripTag x
        instantiate = tagged x
        -- a binder the goal fragment does not describe (bound inside an
        -- argument, say) simply takes its arguments as written
        woven = case Map.lookup key doms of
          Nothing -> argTxts
          Just frag -> weaveArgs frag argTxts
        trailing = case Map.lookup key doms of
          Just frag | instantiate -> trailingAlls frag (length argTxts)
          _ -> 0
        parts = name : woven ++ replicate trailing "_"
    in case parts of
      [only] -> Right (at req 2 only)
      _ -> Right (at req 1 (unwords parts))

  weaveArgs _ [] = []
  weaveArgs (FAll True _ rest) as = "_" : weaveArgs rest as
  weaveArgs (FAll False _ rest) as = weaveArgs rest as
  weaveArgs (FInst _ rest) as = weaveArgs rest as
  weaveArgs (FExactContext _ _ rest) as = weaveArgs rest as
  weaveArgs (FArr _ rest) (a : as) = a : weaveArgs rest as
  weaveArgs _ as = as

  isUnaryNeg frag = case peelA frag of
    FArr _ rest -> case peelA rest of
      FBot -> True
      _ -> False
    _ -> False
  peelA (FAll _ _ b) = peelA b
  peelA (FInst _ b) = peelA b
  peelA (FExactContext _ _ b) = peelA b
  peelA f = f

  at req level text = if level >= req then text else "(" ++ text ++ ")"

  spine (Apply f a) args = spine f (a : args)
  spine f args = (f, args)

  renderHead (Global name) = case declaredProvider providers name of
    Just info -> Right (piLeanName info)
    Nothing -> do
      kind <- globalKind cm name
      case kind of
        GInl -> Right ".inl"
        GInr -> Right ".inr"
        GUnit -> Right "\10216\10217"
        GCtor info -> Right $ case style of
          Idiomatic -> shortDot (ciLean info)
          Explicit -> ciLean info
  renderHead other = go 1 other

  -- Djex's visible type application is Haskell's @f \@T@.  Lean exposes an
  -- implicit binder position by prefixing the head with @\@@; this is also
  -- valid for an already-explicit binder.  Prefix only the first nominal/local
  -- node in a VTA chain.  Higher-rank results reached through an ordinary term
  -- application have no general positional Lean spelling, so they retain the
  -- conservative ordinary-application fallback and verification decides.
  visibleFunctionText function = case function of
    VisibleTypeApplication{} -> go 1 function
    Local{} -> ("@" ++) <$> go 2 function
    Global name -> case declaredProvider providers name of
      Just info -> Right ("@" ++ piLeanName info)
      Nothing -> do
        kind <- globalKind cm name
        Right $ "@" ++ case kind of
          GInl -> "Sum.inl"
          GInr -> "Sum.inr"
          GUnit -> "Unit.unit"
          GCtor info -> ciLean info
    _ -> go 1 function

  localVisibleHead function = case function of
    VisibleTypeApplication inner _ -> localVisibleHead inner
    Local{} -> True
    _ -> False

  -- A positional Lean @ application exposes every intervening implicit and
  -- instance binder. For a discovered global, use the source binder names
  -- retained by the provider serializer instead: class evidence between type
  -- binders remains implicit and Lean's instance search reconstructs it.
  namedProviderApplication expression =
    case providerVisibleSpine expression [] of
      Nothing -> Right Nothing
      Just (providerName, arguments) ->
        case declaredProvider providers providerName of
          Just info
            | Just binderNames <- piBinderNames info ->
            let leanName = piLeanName info
                selected = take (length arguments) binderNames
            in if length selected /= length arguments
              then Left $ "cannot align visible type arguments for Lean provider "
                ++ leanName
              else case traverse renderProviderBinder selected of
                Nothing -> Left $ "cannot address a type binder of Lean provider "
                  ++ leanName
                Just renderedNames
                  | nub renderedNames /= renderedNames ->
                      Left $ "cannot align duplicate type binders for Lean provider "
                        ++ leanName
                  | otherwise -> do
                      let exactSources = lookup arguments
                            [ ( paiVisibleArguments assignment
                              , paiSourceArguments assignment
                              )
                            | assignment <- piAssignments info
                            ]
                      sources <- case exactSources of
                        Just retained
                          | length retained == length arguments ->
                              Right (map Just retained)
                          | otherwise -> Left $
                              "cannot align exact provider type-argument "
                                ++ "source vector for Lean provider "
                                ++ leanName
                        Nothing -> Right $
                          replicate (length arguments) Nothing
                      Right $ Just
                        (leanName, zip3 renderedNames arguments sources)
          _ -> Right Nothing

  -- Quoted identifiers remain valid even when the source binder is a Lean
  -- keyword. Name.toString already quotes some exotic spellings and leaves
  -- ordinary or keyword spellings bare, so preserve a valid existing quote
  -- and quote every other safe spelling. Known live metadata never falls back
  -- positionally: doing so would expose erased instance binders.
  renderProviderBinder name
    | null name || name == "_" = Nothing
    | otherwise = case quotedBody name of
        Just body
          | not (null body) && all safeBinderCharacter body -> Just name
          | otherwise -> Nothing
        Nothing
          | all safeBinderCharacter name -> Just ("«" ++ name ++ "»")
          | otherwise -> Nothing

  quotedBody ('«' : rest) = case reverse rest of
    '»' : reversedBody -> Just (reverse reversedBody)
    _ -> Nothing
  quotedBody _ = Nothing

  safeBinderCharacter character =
    not (isControl character) && character /= '«' && character /= '»'

  -- non-final match-alternative bodies must not swallow following
  -- alternatives, so open bodies are parenthesized uniformly
  renderAlt (pat, body) = do
    patTxt <- renderPattern cm style False pat
    bodyTxt <- go 1 body
    Right ("| " ++ patTxt ++ " => " ++ bodyTxt)

-- | Render Djex's bounded visible type argument as an ordinary Lean
-- application argument. Specified arguments are lexically closed and
-- alpha-normalized by Djex, so quantified binders can be restored without
-- consulting the enclosing term or source-variable scope.
renderVisibleTypeArgument
  :: TypeMap -> VisibleTypeArgument -> Either String String
renderVisibleTypeArgument =
  renderVisibleTypeArgumentWith InferredVisibleBinderDomain True

-- A named Lean argument such as @(a := Nat)@ already identifies the source
-- binder without switching the provider head into fully explicit mode. Keep
-- restored nullary types ordinary, while an applied restored head still uses
-- @\@@ because its recorded argument vector includes Lean's implicit slots.
renderNamedVisibleTypeArgument
  :: TypeMap -> VisibleTypeArgument -> Either String String
renderNamedVisibleTypeArgument =
  renderVisibleTypeArgumentWith InferredVisibleBinderDomain False

-- | Render a matched provider assignment with the canonical Djex type as the
-- structural and nominal authority. Exact live evidence contributes only a
-- bounded vector of semantic forall-domain classes. The source fragment
-- supplies explicitness, and both metadata vectors must align exactly with
-- the canonical visible type before any Lean text is emitted.
renderExactNamedVisibleTypeArgument
  :: VisibleBinderDomain -> TypeMap -> ProviderInstantiationArgument
  -> VisibleTypeArgument
  -> Either String String
renderExactNamedVisibleTypeArgument visibleBinderDomain typeNames source
    argument = do
  visibilities <- maybe
    (Left "cannot render exact Lean provider type-argument evidence")
    Right
    (providerArgumentForallVisibilities source)
  binderMetadata <- case source of
    ProviderInstantiationExactArgument 0 _ domains
      | length domains > maximumProviderExactForallDomains -> Left
          "exact Lean provider forall-domain vector is too long"
      | length domains /= length visibilities -> Left
          "exact Lean provider forall-domain vector does not align with its source fragment"
      | otherwise -> Right
          (zip visibilities (map exactVisibleBinderDomain domains))
    ProviderInstantiationExactArgument _ _ _ -> Left
      "exact Lean provider forall-domain vector is not proper-kinded"
    _ -> Right
      (zip visibilities (repeat visibleBinderDomain))
  renderVisibleTypeArgumentWithForallMetadata
    visibleBinderDomain False typeNames (Just binderMetadata) argument
 where
  exactVisibleBinderDomain domain = case domain of
    ProviderForallDomainProp -> PropVisibleBinderDomain
    ProviderForallDomainType -> TypeVisibleBinderDomain
    ProviderForallDomainSort -> SortVisibleBinderDomain

renderVisibleTypeArgumentWith
  :: VisibleBinderDomain -> Bool -> TypeMap -> VisibleTypeArgument
  -> Either String String
renderVisibleTypeArgumentWith visibleBinderDomain explicitStandalone typeNames =
  renderVisibleTypeArgumentWithForallMetadata
    visibleBinderDomain explicitStandalone typeNames Nothing

renderVisibleTypeArgumentWithForallMetadata
  :: VisibleBinderDomain -> Bool -> TypeMap
  -> Maybe [(Bool, VisibleBinderDomain)]
  -> VisibleTypeArgument -> Either String String
renderVisibleTypeArgumentWithForallMetadata visibleBinderDomain
    explicitStandalone typeNames exactBinders argument =
  case ( isInferredVisibleTypeArgument argument
       , visibleTypeArgumentClosedType argument) of
    (True, Nothing) -> Right "_"
    (False, Just typeExpression) -> do
      (rendered, remaining) <- renderType False 2
        (maybe (repeat (True, visibleBinderDomain)) id exactBinders)
        typeExpression
      case exactBinders of
        Just _
          | not (null remaining) -> Left
              "exact Lean provider type-argument visibility exceeds its canonical type"
        _ -> Right rendered
    (True, Just _) -> Left
      "internal: inferred visible type argument has a closed representation"
    (False, Nothing) -> Left
      "internal: specified visible type argument has no closed representation"
 where
  -- 0 = forall/arrow/product, 1 = type application, 2 = atom.
  renderType
    :: Bool
    -> Int
    -> [(Bool, VisibleBinderDomain)]
    -> SharedType.Type ClosedVisibleTypeVariable
    -> Either String (String, [(Bool, VisibleBinderDomain)])
  renderType applicationHead req visibilities typeExpression = case typeExpression of
    SharedType.TypeVariable variable -> Right
      ( at req 2 $ closedVisibleTypeVariableSpelling variable
      , visibilities
      )
    SharedType.TypeConstructor name -> do
      rendered <- renderTypeName (explicitStandalone || applicationHead) name
      Right (at req 2 rendered, visibilities)
    SharedType.TypeApplication function argumentType -> do
      (functionTxt, afterFunction) <-
        renderType True 1 visibilities function
      (argumentTxt, remaining) <-
        renderType False 2 afterFunction argumentType
      Right (at req 1 (functionTxt ++ " " ++ argumentTxt), remaining)
    SharedType.FunctionType parameter result -> do
      (parameterTxt, afterParameter) <-
        renderType False 1 visibilities parameter
      (resultTxt, remaining) <- renderType False 0 afterParameter result
      Right (at req 0 (parameterTxt ++ " → " ++ resultTxt), remaining)
    SharedType.TupleType Boxed [] -> Right (at req 2 "Unit", visibilities)
    SharedType.TupleType Boxed elements -> do
      (elementTxts, remaining) <- renderTypes visibilities elements
      Right (at req 0 (intercalate " × " elementTxts), remaining)
    SharedType.TupleType Unboxed _ ->
      Left "cannot render an unboxed tuple as a Lean type argument"
    SharedType.ForallType variables constraints body -> do
      let (binderMetadata, afterBinders) =
            splitAt (length variables) visibilities
      if length binderMetadata /= length variables
        then Left
          "exact Lean provider forall metadata is shorter than its canonical type"
        else do
          (constraintTxts, afterConstraints) <-
            renderConstraints afterBinders constraints
          (bodyTxt, remaining) <- renderType False 0 afterConstraints body
          let binderTxt (variable, (explicit, domain)) =
                (if explicit then "(" else "{")
                  ++ closedVisibleTypeVariableSpelling variable ++ " : "
                  ++ visibleBinderDomainText domain
                  ++ (if explicit then ")" else "}")
              contextualBody = intercalate " \8594 "
                (constraintTxts ++ [bodyTxt])
              rendered
                | null variables = contextualBody
                | otherwise =
                    "\8704 " ++ unwords
                      (map binderTxt (zip variables binderMetadata))
                      ++ ", " ++ contextualBody
          Right (at req 0 rendered, remaining)

  renderTypes visibilities types = case types of
    [] -> Right ([], visibilities)
    typeExpression : remainingTypes -> do
      (rendered, afterType) <-
        renderType False 1 visibilities typeExpression
      (rest, remaining) <- renderTypes afterType remainingTypes
      Right (rendered : rest, remaining)

  renderConstraints visibilities constraints = case constraints of
    [] -> Right ([], visibilities)
    Constraint className arguments : remainingConstraints -> do
      classTxt <- renderTypeName (not $ null arguments) className
      (argumentTxts, afterArguments) <-
        renderConstraintArguments visibilities arguments
      let rendered = "[" ++ unwords (classTxt : argumentTxts) ++ "]"
      (rest, remaining) <-
        renderConstraints afterArguments remainingConstraints
      Right (rendered : rest, remaining)

  renderConstraintArguments visibilities arguments = case arguments of
    [] -> Right ([], visibilities)
    nextArgument : remainingArguments -> do
      (rendered, afterArgument) <-
        renderType False 2 visibilities nextArgument
      (rest, remaining) <-
        renderConstraintArguments afterArgument remainingArguments
      Right (rendered : rest, remaining)

  visibleBinderDomainText domain = case domain of
    InferredVisibleBinderDomain -> "_"
    TypeVisibleBinderDomain -> "Type _"
    PropVisibleBinderDomain -> "Prop"
    SortVisibleBinderDomain -> "Sort _"

  -- The engine's structural encodings use their Haskell names.  Lean's
  -- corresponding nominal constructors differ only in these cases; all other
  -- validated identifiers retain their canonical (possibly qualified) name.
  renderTypeName :: Bool -> Name -> Either String String
  renderTypeName explicit name =
    case nameSpelling name >>= (`Map.lookup` typeNames) of
      -- The serializer records every elaborated application argument,
      -- including implicit and instance parameters. Prefix an applied
      -- restored nominal head with @ so Lean consumes that complete explicit
      -- vector; @ is also valid when every source binder was already explicit.
      Just leanName -> Right ((if explicit then "@" else "") ++ leanName)
      Nothing -> case nameSpecial name of
        Just ListConstructor -> Right "List"
        Just FunctionConstructor ->
          Left "cannot render an unsaturated function type constructor in Lean"
        Just (TupleConstructor Boxed 0) -> Right "Unit"
        Just (TupleConstructor Boxed 2) ->
          Right ((if explicit then "@" else "") ++ "Prod")
        Just (TupleConstructor Boxed _) ->
          Left "cannot render an unsaturated tuple type constructor in Lean"
        Just (TupleConstructor Unboxed _) ->
          Left "cannot render an unboxed tuple type constructor in Lean"
        Just ConsConstructor ->
          Left "cannot render a list value constructor as a Lean type"
        Nothing -> Right $ case nameSpelling name of
          Just "Either" -> "Sum"
          Just "Maybe" -> "Option"
          Just "Void" -> "Empty"
          _ -> renderCanonical name

  at :: Int -> Int -> String -> String
  at req level text = if level >= req then text else "(" ++ text ++ ")"

-- | @binder@ selects the irrefutable subset used after @fun@\/@let@;
-- match alternatives additionally allow constructor patterns.  The
-- top-level pattern needs no parentheses; nested constructor patterns do.
renderPattern
  :: CtorMap -> Style -> Bool -> Pattern String -> Either String String
renderPattern cm style = go False
 where
  go _ _ Wildcard = Right "_"
  go _ _ (Bind x) = Right x
  go _ binder (TuplePattern ps) = do
    txts <- mapM (go True binder) ps
    Right ("\10216" ++ intercalate ", " txts ++ "\10217")
  go atomic binder (Constructor c ps)
    | binder = Left "internal: constructor pattern survived normalization"
    | otherwise = do
        kind <- globalKind cm c
        case (kind, ps) of
          (GUnit, []) -> Right "_"
          (GInl, [p]) -> wrapped atomic ".inl" p
          (GInr, [p]) -> wrapped atomic ".inr" p
          (GCtor info, _)
            | Idiomatic <- style, ciSole info -> do
                subs <- mapM (go True binder) ps
                Right ("\10216" ++ intercalate ", " subs ++ "\10217")
          (GCtor info, []) -> Right (spelled info)
          (GCtor info, _) -> do
            subs <- mapM (go True binder) ps
            let text = unwords (spelled info : subs)
            Right (if atomic then "(" ++ text ++ ")" else text)
          _ -> Left "unexpected constructor pattern shape"
   where
    wrapped needParens ctor p = do
      sub <- go False binder p
      let text = ctor ++ " " ++ sub
      Right (if needParens then "(" ++ text ++ ")" else text)
  go _ _ (As _ _) = Left "internal: as-pattern survived normalization"

  spelled info = case style of
    Idiomatic -> shortDot (ciLean info)
    Explicit -> ciLean info

-- | The leading-dot spelling of a constructor name (@.some@ for
-- @Option.some@) - resolved by Lean against the expected type, which
-- verification confirms is known at the use site.
shortDot :: String -> String
shortDot leanName = '.' : reverse (takeWhile (/= '.') (reverse leanName))
