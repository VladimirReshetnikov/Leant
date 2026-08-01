-- | The narrow engine boundary for @:synth@ (design rule 4 of
-- SYNTHESIS_PROPOSAL.md): fragment goal in, candidate batch out.  This is
-- the only Leant module that imports Djex; the engine behind the boundary
-- (today: Djinn's LJT search, in-process) is swappable without touching
-- the REPL layer.
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
module Leant.Synth.Engine
  ( SynthEngine (..)
  , SynthOutcome (..)
  , parseSynthEngine
  , synthEngineName
  , synthesize
  , synthesizeWithProviders
  , synthesizeWith
  , synthesizeTuned
  , forceOutcome
  , candidateWindow
  ) where

import Data.Foldable (toList)
import Data.List (intercalate, isPrefixOf, nub, sortOn)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Void (Void)

import Language.Haskell.Djex
  ( QueryEvidence (..)
  , QueryOptions (..)
  , QueryRequest (..)
  , Boxity (Boxed)
  , Completion (..)
  , DataConstructor (..)
  , Declaration
      ( AbstractTypeDeclaration
      , DataTypeDeclaration
      , ValueDeclaration
      )
  , Diagnostic
  , ExferenceOptions (..)
  , ExferenceSessionPolicy (..)
  , Expression
  , Name
  , Kind (FunctionKind, ProperTypeKind)
  , Penalty (..)
  , Progress (..)
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
  , runDjinnQuery
  , runExferenceQuery
  , selectQueryResults
  , standardDjinnSession
  , tupleName
  , valueName
  )

import Leant.Synth.Fragment
  ( AppHead (..)
  , Frag (..)
  , ProviderFrag (..)
  , fragHasDepth
  , fragUnsafeAtoms
  )
import Leant.Synth.Render
  ( CtorInfo (..)
  , CtorMap
  , TypeMap
  , renderLeanTerm
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

-- | How many engine candidates are collected and take part in the size
-- ranking.  Djinn's sorted mode computes the whole collection before
-- returning, so this bounds real work; the default of 200 buys nothing
-- when at most a handful are ever displayed.  Reaching it truncates the
-- batch, which carries no negative evidence, so refutations - which
-- come from an exhausted search rather than a full collection - stay
-- sound.
candidateWindow :: Int
candidateWindow = 60

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
  synthesizeTunedWithProviders engine steps
    (candidateWindow, Nothing) providers [] frag frag

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
synthesizeTuned engine steps limits extras engineFrag fitFrag = do
  synthesizeTunedWithProviders engine steps limits [] extras engineFrag fitFrag

synthesizeTunedWithProviders
  :: SynthEngine -> Int -> (Int, Maybe Integer) -> [ProviderFrag]
  -> [(String, Frag)] -> Frag -> Frag -> Either String SynthOutcome
synthesizeTunedWithProviders engine steps limits providers extras
    engineFrag fitFrag = case engine of
  EngineDjinn -> do
    (goal, decls, providerDecls, render, complete) <-
      prepare djinnRecursiveProjection providers
    djinnRun limits fitFrag complete render goal (decls ++ providerDecls)
  EngineExference -> do
    (goal, decls, providerDecls, render, _) <-
      prepare exferenceRecursiveProjection providers
    exferenceRun steps render goal (decls ++ providerDecls)
  EngineBoth -> do
    (djinnGoal, djinnDecls, djinnProviderDecls, djinnRender, djinnComplete) <-
      prepare djinnRecursiveProjection providers
    djinn <- djinnRun limits fitFrag djinnComplete djinnRender
      djinnGoal (djinnDecls ++ djinnProviderDecls)
    (exferenceGoal, exferenceDecls, providerDecls, exferenceRender, _) <-
      prepare exferenceRecursiveProjection providers
    exference <- exferenceRun steps exferenceRender exferenceGoal
      (exferenceDecls ++ providerDecls)
    pure (mergeOutcomes djinn exference)
 where
  prepare recursiveProjection activeProviders = do
    ( goal0, decls, providerDecls, ctorMap, providerMap, typeMap, premises
      , complete) <- fragToDjinn recursiveProjection activeProviders extras
        engineFrag
    -- Caller-supplied assumptions and constructor premises for conservative
    -- recursive fallbacks enter as goal antecedents.  Validated exact
    -- recursive families are native declarations for both engines: Djinn
    -- grants one positive constructor layer, while Exference additionally
    -- uses its bounded one-layer eliminator.
    let goal = foldr (\(_, _, t) acc -> FunctionType t acc) goal0 premises
        premisePairs = [(name, prem) | (name, prem, _) <- premises]
        render expr =
          renderLeanTerm ctorMap providerMap typeMap premisePairs fitFrag expr
    pure (goal, decls, providerDecls, render, complete)

-- | The complete LJT search: candidates, or a refutation whose
-- soundness depends on the translation having hidden nothing.
djinnRun
  :: (Int, Maybe Integer)
  -> Frag
  -> ProjectionCompleteness
  -> (Expression String -> Either String [String])
  -> Type String
  -> [DjinnDecl]
  -> Either String SynthOutcome
djinnRun (cutoff, budget) frag projection render goal decls = do
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
  result <- viaDiagnostic (runDjinnQuery session request)
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
  -> (Expression String -> Either String [String])
  -> Type String
  -> [DjinnDecl]
  -> Either String SynthOutcome
exferenceRun steps render goal decls = do
  standard <- viaDiagnostic standardDjinnSession
  let allDecls =
        environmentDeclarations (djinnSessionEnvironment standard)
          ++ decls
      names = nub
        (concatMap declarationTypeVariables allDecls ++ toList goal)
      table = Map.fromList (zip names [0 :: Int ..])
      convert v = FlexibleVariable (table Map.! v)
  let convertedDecls = map (mapDeclarationTypeVariables convert) allDecls
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
        results <- viaDiagnostic (runExferenceQuery session request)
        let selection =
              selectQueryResults SelectAll (const (0 :: Int))
                (const True) results
            groups = nub
              [ group
              | candidate <- take candidateWindow
                  (selectionCandidates selection)
              , let expr = fmap (("x" ++) . show)
                      (functionClauseExpression (candidateOutput candidate))
              , Right group <- [render expr]
              ]
            notes = maybe [] progressNotes (selectionProgress selection)
        pure (groups, notes)
  (strictGroups, strictNotes) <- runLane False
  if not (null strictGroups)
    then pure $ SynthCandidates strictGroups strictNotes
    else do
      -- Exference normally prefers terms which use every introduced binder.
      -- Lean accepts intentional omission, however, and recursive projection
      -- often needs it: after matching @Headed a@, the recursive tail must stay
      -- unopened while the @a@ field is returned.  Retry only after the strict
      -- lane has produced no term, preserving its established candidate order
      -- and provider preference for every existing successful query.
      (relaxedGroups, relaxedNotes) <- runLane True
      pure $ if null relaxedGroups
        then SynthNoTerm (nub $ strictNotes ++ relaxedNotes)
        else SynthCandidates relaxedGroups relaxedNotes

-- | Both engines on one goal: Djinn's candidates first (they carry the
-- smallest-term ranking), Exference's new ones after, and negative
-- verdicts only when neither engine produced a candidate - a refutation
-- stays Djinn's alone.
mergeOutcomes :: SynthOutcome -> SynthOutcome -> SynthOutcome
mergeOutcomes djinn exference = case (djinn, exference) of
  (SynthCandidates a na, SynthCandidates b nb) ->
    SynthCandidates (a ++ filter (`notElem` a) b) (na ++ tag nb)
  (SynthCandidates a na, other) ->
    SynthCandidates a (na ++ tag (notesOf other))
  (other, SynthCandidates b nb) ->
    SynthCandidates b (notesOf other ++ tag nb)
  (SynthRefuted sound, _) -> SynthRefuted sound
  (SynthNoTerm na, other) -> SynthNoTerm (na ++ tag (notesOf other))
 where
  tag = map ("exference: " ++)
  notesOf outcome = case outcome of
    SynthCandidates _ notes -> notes
    SynthNoTerm notes -> notes
    SynthRefuted _ -> []

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
-- atoms and applies its bounded rank-N rules.  Retained proper-type
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
  , tsPrems :: [(String, Frag, Type String)]
    -- ^ constructor premises (Lean name, fragment for the renderer's
    -- domain fitting, engine type), in order
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
  deriving (Eq, Show)

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
  -> Either String
      ( Type String
      , [DjinnDecl]
      , [DjinnDecl]
      , CtorMap
      , Map.Map String String
      , TypeMap
      , [(String, Frag, Type String)]
      , ProjectionCompleteness
      )
fragToDjinn recursiveProjection providers extras frag0 = do
  eitherC <- viaShow (mkIdentifier "Either")
  voidC <- viaShow (mkIdentifier "Void")
  unitC <- viaShow (tupleName Boxed 0)
  let usableProviders = filter usableProvider providers
      queryFragments =
        map snd extras ++ [frag0] ++ map providerTypeFrag usableProviders
      planningRoots =
        [ (True, frag) | frag <- map snd extras ++ [frag0] ]
          ++ [ (False, providerTypeFrag provider)
             | provider <- usableProviders
             ]
      plans = exactFamilyPlans recursiveProjection planningRoots
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
      rigidAtoms = Set.difference
        (Set.union
          (structuralAtomKeys recursiveProjection plans) recursiveFieldAtoms)
        recursiveSelfKeys
      projection = ProjectionCompleteness
        { projectionFamiliesComplete =
            exactFamilyProjectionComplete recursiveProjection plans
        , projectionFragmentsComplete =
            all fragmentProjectionComplete (frag0 : map snd extras)
        }
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
        FAll _ binder body -> do
          v <- variable ("v:" ++ binder)
          body' <- go premisesEnabled body
          pure (ForallType [v] [] body')
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
                  { tsPrems =
                      tsPrems s ++ [(leanName, premFrag, premise)] }))
              ctors
            pure ()

  let translate = do
        -- caller-supplied premises share the goal's variable table and
        -- come first, so their binders are the candidate's first
        extrasT <- mapM
          (\(name, prem) -> do
            premType <- go True prem
            pure (name, prem, premType))
          extras
        goal <- go True frag0
        translatedProviders <- mapM
          (\(index, ProviderFrag leanName providerFrag) -> do
            privateName <- nameT ("leantProvider" ++ show index)
            providerType <- go False providerFrag
            pure
              ( ValueDeclaration
                  (ValueSignature () privateName providerType)
              , ("leantProvider" ++ show index, leanName)
              ))
          (zip [0 :: Int ..] usableProviders)
        pure (extrasT, goal, translatedProviders)
  ((extrasT, goal, translatedProviders), finalState) <-
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
    , tsTypeMap = Map.empty
    }
  let (providerDecls, providerNames) = unzip translatedProviders
  Right
    ( goal
    , tsDecls finalState
    , providerDecls
    , tsCtorMap finalState
    , Map.fromList providerNames
    , tsTypeMap finalState
    , extrasT ++ tsPrems finalState
    , projection
    )
 where
  usableProvider = not . fragHasDepth . providerTypeFrag

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
  -> [(Bool, Frag)]
  -> Map.Map String ExactFamilyPlan
exactFamilyPlans recursiveProjection roots = settle initialUses
 where
  initialUses = foldl
    (\uses (premisesEnabled, frag) ->
      collectExactFamilyUses recursiveProjection premisesEnabled uses frag)
    Map.empty roots

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
  insertUse spelling use = Map.alter append spelling
   where
    append Nothing = Just [use]
    append (Just previous)
      | use `elem` previous = Just previous
      | otherwise = Just (previous ++ [use])

choosePlan :: String -> [ExactFamilyUse] -> ExactFamilyPlan
choosePlan spelling uses = case nub (map useArity uses) of
  [arity]
    | length occurrences == length uses -> case compatibleTemplates of
        template : rest
          | all (templatesEquivalent template) rest ->
              StructuralFamily template
        _ -> AbstractFamily arity True
    | length recursiveOccurrences == length uses ->
        case compatibleRecursiveTemplates of
          template : rest
            | all (templatesEquivalent template) rest ->
                RecursiveStructuralFamily template
          _ -> AbstractFamily arity True
    | otherwise -> AbstractFamily arity (any hidesStructure uses)
  arities -> InvalidFamilyArities arities
 where
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
  hidesStructure use = case use of
    ParametricUse{} -> True
    RecursiveUse{} -> True
    NominalUse{} -> False

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
