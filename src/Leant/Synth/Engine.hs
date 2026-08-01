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
-- Phase 2: expanded inductive occurrences ('FInd') become Djinn @data@
-- declarations -- constructors as right-rules, case analysis as
-- left-rules, exactly how Djinn admits Haskell datatypes.  Each distinct
-- occurrence key (one per alpha-normalized instantiation) is declared
-- once, parameterized over the goal variables its fields mention, and
-- the goal references the declared constructor applied to those
-- variables.  The engine-side constructor names are fresh; the mapping
-- back to the Lean spellings rides along to the renderer.
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
import Data.Void (Void)

import Language.Haskell.Djex
  ( QueryEvidence (..)
  , QueryOptions (..)
  , QueryRequest (..)
  , Boxity (Boxed)
  , Completion (..)
  , DataConstructor (..)
  , Declaration (DataTypeDeclaration, ValueDeclaration)
  , Diagnostic
  , ExferenceOptions (..)
  , ExferenceSessionPolicy (..)
  , Expression
  , Name
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
  ( Frag (..)
  , ProviderFrag (..)
  , fragUnsafeAtoms
  )
import Leant.Synth.Render (CtorInfo (..), CtorMap, renderLeanTerm)

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
-- Providers affect Exference only: Djinn remains the closed, deciding
-- structural search, while Exference may reuse the supplied environment and
-- Lean subsequently verifies every rendered use.  Foreign names never enter
-- Djex's nominal namespace directly; each receives a collision-free private
-- engine name carried back through the renderer map.
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
    (goal, decls, _, render) <- prepare False []
    djinnRun limits fitFrag render goal decls
  EngineExference -> do
    (goal, decls, providerDecls, render) <- prepare True providers
    exferenceRun steps render goal (decls ++ providerDecls)
  EngineBoth -> do
    (djinnGoal, djinnDecls, _, djinnRender) <- prepare False []
    djinn <- djinnRun limits fitFrag djinnRender djinnGoal djinnDecls
    (exferenceGoal, exferenceDecls, providerDecls, exferenceRender) <-
      prepare True providers
    exference <- exferenceRun steps exferenceRender exferenceGoal
      (exferenceDecls ++ providerDecls)
    pure (mergeOutcomes djinn exference)
 where
  prepare structuralRecursive activeProviders = do
    (goal0, decls, providerDecls, ctorMap, providerMap, premises) <-
      fragToDjinn structuralRecursive activeProviders extras engineFrag
    -- Premises (caller-supplied assumptions, and Djinn's constructor
    -- premises for recursive inductives) enter as goal antecedents.  The
    -- Exference projection instead receives a real recursive declaration and
    -- uses its bounded one-layer eliminator.
    let goal = foldr (\(_, _, t) acc -> FunctionType t acc) goal0 premises
        premisePairs = [(name, prem) | (name, prem, _) <- premises]
        render expr =
          renderLeanTerm ctorMap providerMap premisePairs fitFrag expr
    pure (goal, decls, providerDecls, render)

-- | The complete LJT search: candidates, or a refutation whose
-- soundness depends on the translation having hidden nothing.
djinnRun
  :: (Int, Maybe Integer)
  -> Frag
  -> (Expression String -> Either String [String])
  -> Type String
  -> [DjinnDecl]
  -> Either String SynthOutcome
djinnRun (cutoff, budget) frag render goal decls = do
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
    ProvedUninhabitable ->
      SynthRefuted (budget == Nothing && null (fragUnsafeAtoms frag))
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
  let query = QueryRequest
        { requestTarget = target
        , requestGoal = fmap convert goal
        , requestContexts = []
        , requestOptions = defaultExferenceOptions
            { exferenceMaximumSteps = steps
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
        selectQueryResults SelectAll (const (0 :: Int)) (const True) results
      groups = nub
        [ group
        | candidate <- take candidateWindow (selectionCandidates selection)
        , let expr = fmap (("x" ++) . show)
                (functionClauseExpression (candidateOutput candidate))
        , Right group <- [render expr]
        ]
      notes = maybe [] progressNotes (selectionProgress selection)
  pure $ if null groups
    then SynthNoTerm notes
    else SynthCandidates groups notes

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
-- Opaque variables and atoms both become Djinn type variables; atoms are
-- keyed by their pretty-printed spelling so alpha-equal occurrences share
-- one variable (transportable, never analyzed).  Nested quantifiers are
-- passed structurally as 'ForallType'; Djex carries them as alpha-aware
-- atoms and applies its bounded rank-N rules.  Expanded inductive
-- occurrences become fresh @data@ declarations, one per display key,
-- collected in dependency order (fields are translated before the
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
  }

data RecInfo = RecInfo
  { recTypeName :: Name
  , recTypeArity :: Int
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
  :: Bool
  -> [ProviderFrag]
  -> [(String, Frag)]
  -> Frag
  -> Either String
      ( Type String
      , [DjinnDecl]
      , [DjinnDecl]
      , CtorMap
      , Map.Map String String
      , [(String, Frag, Type String)]
      )
fragToDjinn structuralRecursive providers extras frag0 = do
  eitherC <- viaShow (mkIdentifier "Either")
  voidC <- viaShow (mkIdentifier "Void")
  unitC <- viaShow (tupleName Boxed 0)
  let go premisesEnabled frag = case frag of
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
            Nothing -> TypeVariable <$> variable ("a:" ++ key)
        FAll _ binder body -> do
          v <- variable ("v:" ++ binder)
          body' <- go premisesEnabled body
          pure (ForallType [v] [] body')
        FInd key ctors -> indOccurrence premisesEnabled key ctors
        FRec complete key parameters ctors
          | structuralRecursive
          , complete
          , Just parameterKeys <- distinctPlainParameters parameters ->
              recDataOccurrence key parameterKeys ctors
          | otherwise -> recOccurrence premisesEnabled key ctors
        FDepth -> failT "internal: depth marker survived refusal check"

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
                    (CtorInfo leanName fields sole) (tsCtorMap s) })
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

      -- Exference can safely inspect one layer of recursive data.  Give every
      -- occurrence of the same Lean constructor family one shared nominal
      -- datatype, applied to the occurrence's explicit parameter vector.
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
                          (CtorInfo leanName fields sole) (tsCtorMap s) })
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
        occurrence <- TypeVariable <$> variable ("a:" ++ key)
        registered <- getsT (Map.member key . tsRecs)
        if registered || not premisesEnabled
          then pure occurrence
          else do
            modifyT (\s -> s { tsRecs = Map.insert key () (tsRecs s) })
            mapM_
              (\(leanName, fields) -> do
                fieldTypes <- mapM (go premisesEnabled) fields
                let premise = foldr FunctionType occurrence fieldTypes
                    premFrag = foldr FArr (FAtom False key) fields
                modifyT (\s -> s
                  { tsPrems =
                      tsPrems s ++ [(leanName, premFrag, premise)] }))
              ctors
            pure occurrence

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
          (zip [0 :: Int ..] (filter usableProvider providers))
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
    }
  let (providerDecls, providerNames) = unzip translatedProviders
  Right
    ( goal
    , tsDecls finalState
    , providerDecls
    , tsCtorMap finalState
    , Map.fromList providerNames
    , extrasT ++ tsPrems finalState
    )
 where
  usableProvider = not . hasDepth . providerTypeFrag

  hasDepth frag = case frag of
    FArr a b -> hasDepth a || hasDepth b
    FProd a b -> hasDepth a || hasDepth b
    FSum a b -> hasDepth a || hasDepth b
    FAll _ _ body -> hasDepth body
    FInd _ ctors -> any (any hasDepth . snd) ctors
    FRec _ _ parameters ctors ->
      any hasDepth parameters || any (any hasDepth . snd) ctors
    FDepth -> True
    _ -> False

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
