-- | Source metadata for the bounded production lexical-Given route. The Lean
-- serializer owns foreign names and domains; preparation owns their private
-- translations. Graph metadata is then propagated from those roots through
-- actual introduction/application witnesses, never recovered from erasure.
module Leant.Synth.ContextSource
  ( ContextSource, ContextSourceType (..), ContextSourceVisibility (..)
  , mkContextSource, mkContextSourceWithConstructors, mkContextProviderSource
  , mkContextProviderSourceAt, contextSourceConstructors, contextSourceWithoutConstructors
  , contextSourceType, contextSourceHasGiven
  , contextSourceName
  , PreparedContextSource, prepareContextSource, prepareContextSourceProviders
  , renderPreparedContextGraph
  ) where

import Control.Monad (foldM, unless, when)
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name (Name)
import qualified Language.Haskell.Synthesis.Type as T
import qualified Language.Haskell.Synthesis.TypeAtom as A
import qualified Language.Haskell.Synthesis.TypedGenerated as Q
import Leant.Synth.ContextRender

data ContextSourceVisibility = ContextExplicit | ContextImplicit | ContextStrictImplicit
  deriving (Eq, Show)

-- Every type binder and nominal/class parameter in version 1 has the exact
-- domain Type 0. A nominal/class declaration must itself end in Type 0.
-- The exact nominal form also retains universe-zero constant instantiations.
-- Higher sorts, Prop domains and dependent term
-- arrows remain refused; constant selections must not be inferred or erased.
data ContextSourceType
  = ContextVariable String
  | ContextNominal [String] Int [ContextSourceType]
  | ContextNominalAt [String] Int [LeanLevel] [ContextSourceType]
  | ContextArrow ContextSourceType ContextSourceType
  | ContextForall ContextSourceVisibility String ContextSourceType
  | ContextGiven [String] Int [ContextSourceType] ContextSourceType
  deriving (Eq, Show)

data ContextSource = ContextSource
  { contextSourceType :: ContextSourceType
  , contextSourceValueLevels :: [LeanLevel]
  , contextSourceConstructors :: [([String], ContextSource)]
  } deriving (Eq, Show)

contextSourceWithoutConstructors :: ContextSource -> ContextSource
contextSourceWithoutConstructors source = source { contextSourceConstructors = [] }

-- Constructor packets originate in the actual inductive declaration inventory.
-- They are closed source-owned values; they never authorize case completeness.
mkContextSourceWithConstructors
  :: ContextSourceType -> [([String], ContextSource)] -> Either String ContextSource
mkContextSourceWithConstructors source constructors = do
  root <- mkContextSource source
  when (length constructors > 64) $ Left "context-source: constructor inventory exceeds limit"
  _ <- foldM add (Set.empty, nominalNames source) constructors
  pure root { contextSourceConstructors = constructors }
 where
  add (owners, reachable) (parts, packet) = do
    _ <- either (Left . show) Right $ mkLeanName parts
    when (Set.member parts owners || not (null $ contextSourceConstructors packet)) $
      Left "context-source: duplicate or nested constructor inventory"
    family <- case resultType $ contextSourceType packet of
      ContextNominal name _ _ -> Right name
      ContextNominalAt name _ _ _ -> Right name
      _ -> Left "context-source: constructor result is not nominal"
    unless (Set.member family reachable) $
      Left "context-source: constructor family is not reachable from the goal"
    pure (Set.insert parts owners, Set.union reachable $ nominalNames $ contextSourceType packet)
  resultType (ContextForall _ _ body) = resultType body
  resultType (ContextArrow _ body) = resultType body
  resultType body = body
  nominalNames current = case current of
    ContextVariable{} -> Set.empty
    ContextNominal name _ args -> Set.insert name $ Set.unions $ map nominalNames args
    ContextNominalAt name _ _ args -> Set.insert name $ Set.unions $ map nominalNames args
    ContextArrow a b -> Set.union (nominalNames a) (nominalNames b)
    ContextForall _ _ body -> nominalNames body
    ContextGiven _ _ args body -> Set.unions $ map nominalNames (body : args)

contextSourceName :: [String] -> String
contextSourceName = intercalate "."

contextSourceHasGiven :: ContextSourceType -> Bool
contextSourceHasGiven source = case source of
  ContextGiven{} -> True
  ContextArrow a b -> contextSourceHasGiven a || contextSourceHasGiven b
  ContextForall _ _ body -> contextSourceHasGiven body
  ContextNominal _ _ arguments -> any contextSourceHasGiven arguments
  ContextNominalAt _ _ _ arguments -> any contextSourceHasGiven arguments
  ContextVariable{} -> False

mkContextSource :: ContextSourceType -> Either String ContextSource
mkContextSource = validateContextSource True

-- A provider may be context-free, but still needs a closed, complete source
-- scheme. The goal entrance continues to require an actual lexical Given.
mkContextProviderSource :: ContextSourceType -> Either String ContextSource
mkContextProviderSource = validateContextSource False

mkContextProviderSourceAt :: [LeanLevel] -> ContextSourceType -> Either String ContextSource
mkContextProviderSourceAt levels source = do
  validateConstantLevels levels
  packet <- mkContextProviderSource source
  pure packet { contextSourceValueLevels = levels }

validateConstantLevels :: [LeanLevel] -> Either String ()
validateConstantLevels levels =
  unless (length levels <= 64 && all (== LeanLevelZero) levels) $
    Left "context-source: constant levels require explicit universe-zero instantiations"

validateContextSource :: Bool -> ContextSourceType -> Either String ContextSource
validateContextSource requireGiven source = do
  (_, classes, nominals) <- inspect 4096 Set.empty Map.empty Map.empty source
  unless (Map.null $ Map.intersection classes nominals) $
    Left "context-source: a class identity also occurs as an ordinary nominal type"
  when (requireGiven && not (contextSourceHasGiven source)) $
    Left "context-source: packet has no lexical Given context"
  _ <- sourceUniverse source
  pure $ ContextSource source [] []
 where
  inspect fuel _ _ _ _ | fuel <= (0 :: Int) = Left "context-source: source exceeds node limit"
  inspect fuel scope classes nominals current = case current of
    ContextVariable variable -> do
      unless (Set.member variable scope) $ Left "context-source: unbound type variable"
      pure (fuel - 1, classes, nominals)
    ContextForall _ variable body -> do
      when (null variable || length variable > 256) $ Left "context-source: invalid binder identity"
      when (Set.member variable scope) $ Left "context-source: a binder reused an active source identity"
      inspect (fuel - 1) (Set.insert variable scope) classes nominals body
    ContextArrow domain result -> do
      (remaining, afterClasses, afterNominals) <- inspect (fuel - 1) scope classes nominals domain
      inspect remaining scope afterClasses afterNominals result
    ContextNominal name arity arguments -> do
      inspect fuel scope classes nominals $ ContextNominalAt name arity [] arguments
    ContextNominalAt name arity levels arguments -> do
      validateConstantLevels levels
      updated <- insertName name arity arguments (arity, levels) nominals
      inspectArguments (fuel - 1) scope classes updated arguments
    ContextGiven name arity arguments body -> do
      updated <- insertName name arity arguments arity classes
      (remaining, afterClasses, afterNominals) <- inspectArguments (fuel - 1) scope updated nominals arguments
      inspect remaining scope afterClasses afterNominals body
  inspectArguments fuel scope classes nominals = foldM
    (\(remaining, cs, ns) -> inspect remaining scope cs ns) (fuel, classes, nominals)
  insertName parts arity arguments metadata names = do
    _ <- either (Left . show) Right $ mkLeanName parts
    unless (arity >= 0 && arity <= 64 && length arguments == arity) $
      Left "context-source: unsaturated or unsupported nominal/class arity"
    let name = contextSourceName parts
    case Map.lookup name names of
      Just previous | previous /= metadata -> Left "context-source: inconsistent source arity or universe arguments"
      _ -> pure $ Map.insert name metadata names

-- Version 1's source domains suffice to compute this restricted universe
-- fragment. A forall over Type 0 may itself live in Type 1; it cannot silently
-- become an argument of a nominal/class parameter whose domain is Type 0.
sourceUniverse :: ContextSourceType -> Either String Int
sourceUniverse source = case source of
  ContextVariable{} -> Right 0
  ContextArrow domain result -> max <$> sourceUniverse domain <*> sourceUniverse result
  ContextForall _ _ body -> max 1 <$> sourceUniverse body
  ContextNominal _ _ arguments -> checkArguments arguments >> pure 0
  ContextNominalAt _ _ _ arguments -> checkArguments arguments >> pure 0
  ContextGiven _ _ arguments body -> checkArguments arguments >> sourceUniverse body
 where
  checkArguments arguments = do
    levels <- traverse sourceUniverse arguments
    unless (all (== 0) levels) $
      Left "context-source: higher-universe argument supplied to a Type-0 nominal or class"

data PreparedContextSource = PreparedContextSource
  { preparedContextRoot :: LeanType String
  , preparedContextClasses :: Map.Map Name LeanClassInfo
  , preparedContextNominals :: Map.Map Name LeanNominalInfo
  , preparedContextProviders :: Map.Map Name (LeanProviderInfo String)
  } deriving (Eq, Show)

-- The two maps come directly from the same completed translation state as
-- the source goal. No pretty-type map or provider-name inference is accepted.
prepareContextSource
  :: Map.Map String (Name, [Int])
  -> Map.Map String (Name, Int)
  -> T.Type String
  -> ContextSource
  -> Either String PreparedContextSource
prepareContextSource classes nominals goal packet = do
  let source = contextSourceType packet
  (projection, classEntries, nominalEntries) <- project source
  aligned <- alignProjection Map.empty projection goal
  pure $ PreparedContextSource aligned (Map.fromList classEntries) (Map.fromList nominalEntries) Map.empty
 where
  project current = case current of
    ContextVariable variable -> pure (LeanVariable variable, [], [])
    ContextArrow domain result -> do
      (a, ac, an) <- project domain
      (b, bc, bn) <- project result
      pure (LeanArrow a b, ac ++ bc, an ++ bn)
    ContextNominal parts arity arguments -> project $ ContextNominalAt parts arity [] arguments
    ContextNominalAt parts arity levels arguments -> do
      (private, actualArity) <- maybe (Left "context-source: nominal has no source-owned translation") Right $
        Map.lookup (contextSourceName parts) nominals
      unless (arity == actualArity) $ Left "context-source: translated nominal kind changed"
      name <- either (Left . show) Right $ mkLeanName parts
      projected <- traverse project arguments
      pure (foldl LeanApplication (LeanNominal private) $ map first projected,
        concatMap second projected,
        (private, LeanNominalInfo name arity levels) : concatMap third projected)
    ContextForall{} -> do
      let (binders, afterBinders) = allSpine current
          (contexts, body) = givenSpine afterBinders
      projectedContexts <- traverse projectConstraint contexts
      (result, bodyClasses, bodyNominals) <- project body
      pure (LeanForall [(variable, binder visibility) | (visibility, variable) <- binders]
          (map first projectedContexts) result,
        concatMap second projectedContexts ++ bodyClasses,
        concatMap third projectedContexts ++ bodyNominals)
    ContextGiven parts arity arguments body -> do
      (constraint, cs, ns) <- projectConstraint (parts, arity, arguments)
      (result, bc, bn) <- project body
      pure (LeanForall [] [constraint] result, cs ++ bc, ns ++ bn)
  projectConstraint (parts, arity, arguments) = do
    (private, kinds) <- maybe (Left "context-source: class has no source-owned translation") Right $
      Map.lookup (contextSourceName parts) classes
    unless (kinds == replicate arity 0) $ Left "context-source: translated class parameter kinds changed"
    name <- either (Left . show) Right $ mkLeanName parts
    projected <- traverse project arguments
    pure (Constraint private $ map first projected,
      (private, LeanClassInfo name kinds) : concatMap second projected,
      concatMap third projected)
  binder visibility = LeanBinder
    (case visibility of
       ContextExplicit -> LeanExplicit
       ContextImplicit -> LeanImplicit
       ContextStrictImplicit -> LeanStrictImplicit)
    (LeanSortDomain $ LeanLevelSuccessor LeanLevelZero)
  allSpine (ContextForall visibility variable body) =
    let (rest, result) = allSpine body in ((visibility, variable) : rest, result)
  allSpine body = ([], body)
  givenSpine (ContextGiven parts arity arguments body) =
    let (rest, result) = givenSpine body in ((parts, arity, arguments) : rest, result)
  givenSpine body = ([], body)
  first (value, _, _) = value
  second (_, value, _) = value
  third (_, _, value) = value

-- All entries are the actual value bindings of one completed translation.
-- A source packet is never recovered from a generated application or its
-- neighbor. Duplicate private or foreign provider owners are refused.
prepareContextSourceProviders
  :: Map.Map String (Name, [Int])
  -> Map.Map String (Name, Int)
  -> [(Name, [String], T.Type String, ContextSource)]
  -> PreparedContextSource
  -> Either String PreparedContextSource
prepareContextSourceProviders classes nominals bindings initial =
  foldM add initial bindings
 where
  add prepared (private, parts, scheme, source) = do
    foreignName <- either (Left . show) Right $ mkLeanName parts
    when (Map.member private (preparedContextProviders prepared)
        || any ((== foreignName) . contextProviderLeanName)
          (Map.elems $ preparedContextProviders prepared)) $
      Left "context-source: duplicate global provider owner"
    provider <- prepareContextSource classes nominals scheme source
    unless (Set.null $ T.freeVariables scheme) $
      Left "context-source: global provider scheme is open"
    combinedClasses <- merge (preparedContextClasses prepared) (preparedContextClasses provider)
    combinedNominals <- merge (preparedContextNominals prepared) (preparedContextNominals provider)
    when (any (\classInfo -> any
        ((== contextClassLeanName classInfo) . contextNominalLeanName)
        (Map.elems combinedNominals)) (Map.elems combinedClasses)) $
      Left "context-source: class identity also occurs as an ordinary nominal type"
    pure prepared
      { preparedContextClasses = combinedClasses
      , preparedContextNominals = combinedNominals
      , preparedContextProviders = Map.insert private
          (LeanProviderInfo foreignName (contextSourceValueLevels source) $ preparedContextRoot provider)
          (preparedContextProviders prepared)
      }
  merge left right = do
    unless (and $ Map.elems $ Map.intersectionWith (==) left right) $
      Left "context-source: conflicting provider source declarations"
    pure $ Map.union left right

-- Alignment renames only lexical binders. Free identities must already be
-- present in the caller's actual graph scope; no alpha-key pool grants them.
alignProjection
  :: (Ord source, Eq target)
  => Map.Map source target -> LeanType source -> T.Type target
  -> Either String (LeanType target)
alignProjection scope projection actual = case (projection, actual) of
  (LeanVariable variable, T.TypeVariable target)
    | Map.lookup variable scope == Just target -> pure $ LeanVariable target
  (LeanNominal name, T.TypeConstructor target) | name == target -> pure $ LeanNominal target
  (LeanApplication a b, T.TypeApplication x y) ->
    LeanApplication <$> alignProjection scope a x <*> alignProjection scope b y
  (LeanArrow a b, T.FunctionType x y) ->
    LeanArrow <$> alignProjection scope a x <*> alignProjection scope b y
  (LeanForall binders constraints body, T.ForallType variables actualConstraints actualBody)
    | length binders == length variables && length constraints == length actualConstraints -> do
      let nested = Map.union (Map.fromList $ zip (map fst binders) variables) scope
      contexts <- traverse (alignConstraint nested) $ zip constraints actualConstraints
      result <- alignProjection nested body actualBody
      pure $ LeanForall (zip variables $ map snd binders) contexts result
  _ -> Left "context-source: complete source metadata does not match the actual type"
 where
  alignConstraint nested (Constraint name arguments, Constraint actualName actualArguments) = do
    unless (name == actualName && length arguments == length actualArguments) $
      Left "context-source: class identity or arity changed in the actual type"
    Constraint name <$> sequence (zipWith (alignProjection nested) arguments actualArguments)

data ProjectionState variable = ProjectionState
  Int (Map.Map Q.TermNodeId (LeanType variable)) (Map.Map Q.TermNodeId (LeanType variable))

newtype Project variable value = Project
  { runProject :: ProjectionState variable -> Either String (value, ProjectionState variable) }

instance Functor (Project variable) where
  fmap f (Project action) = Project $ \state -> do
    (value, next) <- action state
    pure (f value, next)
instance Applicative (Project variable) where
  pure value = Project $ \state -> Right (value, state)
  Project function <*> Project argument = Project $ \state -> do
    (f, next) <- function state
    (value, final) <- argument next
    pure (f value, final)
instance Monad (Project variable) where
  Project action >>= continuation = Project $ \state -> do
    (value, next) <- action state
    runProject (continuation value) next

checked :: Either String value -> Project variable value
checked result = Project $ \state -> (\value -> (value, state)) <$> result

remember :: Eq variable => Q.TermNodeId -> LeanType variable -> Project variable ()
remember owner metadata = Project $ \(ProjectionState remaining nodes selections) -> do
  when (remaining <= 0) $ Left "context-source: rooted projection walk exceeds limit"
  case Map.lookup owner nodes of
    Just previous -> unless (previous == metadata) $
      Left "context-source: a shared graph node acquired conflicting lexical metadata"
    Nothing -> pure ()
  pure ((), ProjectionState (remaining - 1) (Map.insert owner metadata nodes) selections)

select :: Q.TermNodeId -> LeanType variable -> Project variable ()
select owner metadata = Project $ \(ProjectionState remaining nodes selections) ->
  Right ((), ProjectionState remaining nodes (Map.insert owner metadata selections))

renderPreparedContextGraph
  :: (Ord variable, Ord local)
  => PreparedContextSource -> Q.TermGraph (T.Type variable) local
  -> Either String [String]
renderPreparedContextGraph prepared graph = do
  root <- node $ Q.termGraphRoot graph
  projection <- alignProjection Map.empty (preparedContextRoot prepared) $ Q.termNodeType root
  (_, ProjectionState _ nodes selections) <- runProject
    (check Set.empty Map.empty (Q.termGraphRoot graph) projection)
    (ProjectionState 65536 Map.empty Map.empty)
  providers <- fmap Map.fromList $ mapM
    (\(name, metadata) -> do
      source <- maybe (Left "context-source: global provider lacks a complete source packet") Right $
        Map.lookup name $ preparedContextProviders prepared
      pure (name, LeanProviderInfo (contextProviderLeanName source) (contextProviderConstantLevels source) metadata))
    [ (name, metadata)
    | (owner, metadata) <- Map.toList nodes
    , Just current <- [Q.lookupTermNode owner graph]
    , Q.TypedGlobal _ name <- [Q.termNodeForm current]
    ]
  rendered <- either (Left . ("context-render: " ++) . show) Right $
    renderLeanContextGraph ContextRenderEnvironment
      { contextRenderClasses = preparedContextClasses prepared
      , contextRenderNominals = preparedContextNominals prepared
      , contextRenderProviders = providers
      , contextRenderNodeTypes = nodes
      , contextRenderSelectedTypes = selections
      , contextRenderUniverseParameters = Set.empty
      , contextRenderPremiseCounts = (0, 0)
      } graph
  pure [contextRenderedExpression rendered]
 where
  node owner = maybe (Left "context-source: graph references a missing node") Right $
    Q.lookupTermNode owner graph
  align expected actual = alignProjection
    (Map.fromSet id $ T.freeVariables $ eraseLeanType expected) expected actual
  retain owner expected = do
    current <- checked $ node owner
    actual <- checked $ align expected $ Q.termNodeType current
    remember owner actual
    pure (actual, Q.termNodeForm current)

  check scope locals owner expected = do
    (metadata, form) <- retain owner expected
    case form of
      Q.TypedLambda patterns body -> do
        (nested, result) <- checked $ foldM lambda (locals, metadata) patterns
        check scope nested body result
      Q.TypedForallIntroduction _ body witness -> case Q.forallIntroductionVariable witness of
        T.TypeVariable variable -> do
          when (Set.member variable scope) $ checked $ Left "context-source: forall opening reused a scoped identity"
          result <- checked $ instantiate metadata $ LeanVariable variable
          check (Set.insert variable scope) locals body result
        _ -> checked $ Left "context-source: forall introduction has no variable opening"
      Q.TypedContextIntroduction _ body _ -> case metadata of
        LeanForall [] (_ : _) result -> check scope locals body result
        _ -> checked $ Left "context-source: unexpected context introduction telescope"
      Q.TypedLet pattern binding body -> case Q.typedPatternNode pattern of
        Q.TypedBind variable -> do
          bindingType <- infer scope locals binding
          checked $ unless (A.alphaEquivalentTypes (eraseLeanType bindingType) $ Q.typedPatternType pattern) $
            Left "context-source: let binder type changed"
          check scope (Map.insert variable bindingType locals) body metadata
        _ -> checked $ Left "context-source: unsupported let pattern"
      _ -> do
        inferred <- infer scope locals owner
        _ <- checked $ align metadata $ eraseLeanType inferred
        pure ()

  lambda (locals, residual) pattern = case (residual, Q.typedPatternNode pattern) of
    (LeanArrow domain result, Q.TypedBind variable) -> do
      unless (A.alphaEquivalentTypes (eraseLeanType domain) $ Q.typedPatternType pattern) $
        Left "context-source: lambda binder type changed"
      pure (Map.insert variable domain locals, result)
    (LeanArrow domain result, Q.TypedWildcard) -> do
      unless (A.alphaEquivalentTypes (eraseLeanType domain) $ Q.typedPatternType pattern) $
        Left "context-source: wildcard binder type changed"
      pure (locals, result)
    _ -> Left "context-source: unsupported lambda pattern or source arrow"

  infer scope locals owner = do
    current <- checked $ node owner
    inferred <- case Q.termNodeForm current of
      Q.TypedLocal _ variable -> checked $ maybe
        (Left "context-source: local has no source-owned binder metadata") Right $ Map.lookup variable locals
      Q.TypedGlobal _ name -> checked $ do
        provider <- maybe (Left "context-source: global provider lacks a complete source packet") Right $
          Map.lookup name $ preparedContextProviders prepared
        alignProjection Map.empty (contextProviderSourceType provider) $ Q.termNodeType current
      Q.TypedApply function argument _ -> do
        functionType <- infer scope locals function
        case functionType of
          LeanArrow domain result -> check scope locals argument domain >> pure result
          _ -> checked $ Left "context-source: term application did not retain an arrow"
      Q.TypedVisibleTypeApplication _ function _ witness ->
        applyType scope locals owner function $ Q.typeApplicationSelected witness
      Q.TypedImplicitTypeApplication _ function witness ->
        applyType scope locals owner function $ Q.implicitTypeApplicationSelected witness
      Q.TypedContextApplication _ function _ -> do
        functionType <- infer scope locals function
        case functionType of
          LeanForall [] (_ : _) result -> pure result
          _ -> checked $ Left "context-source: dictionary application did not retain its context"
      _ -> checked $ Left "context-source: unsupported unanchored graph construction"
    (actual, _) <- retain owner inferred
    pure actual

  applyType scope locals owner function selected = do
    functionType <- infer scope locals function
    argument <- checked $ monotype scope selected
    checked $ unless (properMonotype argument == Just 0) $
      Left "context-source: selected type is not a Type-0 proper type"
    select owner argument
    checked $ instantiate functionType argument

  monotype scope selected = case selected of
    T.TypeVariable variable
      | Set.member variable scope -> pure $ LeanVariable variable
      | otherwise -> Left "context-source: selected variable has no actual source opening"
    T.TypeConstructor name
      | Map.member name (preparedContextNominals prepared) -> pure $ LeanNominal name
      | otherwise -> Left "context-source: selected nominal has no exact source metadata"
    T.TypeApplication a b -> LeanApplication <$> monotype scope a <*> monotype scope b
    T.FunctionType a b -> LeanArrow <$> monotype scope a <*> monotype scope b
    T.ForallType{} -> Left "context-source: impredicative selected types need unsupported universe evidence"
    T.TupleType{} -> Left "context-source: selected tuple type is unsupported"

  properMonotype projection = case projection of
    LeanVariable{} -> Just 0
    LeanNominal name -> contextNominalKindArity <$> Map.lookup name (preparedContextNominals prepared)
    LeanApplication a b -> case (properMonotype a, properMonotype b) of
      (Just arity, Just 0) | arity > 0 -> Just (arity - 1)
      _ -> Nothing
    LeanArrow a b | properMonotype a == Just 0 && properMonotype b == Just 0 -> Just 0
    _ -> Nothing

-- Selected monotypes contain only actual opened variables; graph sealing
-- keeps those rigid identities distinct from every quantified source binder.
instantiate :: Ord variable => LeanType variable -> LeanType variable -> Either String (LeanType variable)
instantiate (LeanForall ((variable, _) : rest) constraints body) selected = do
  let residual = if null rest && null constraints then body else LeanForall rest constraints body
  unless (Set.null $ Set.intersection (T.freeVariables $ eraseLeanType selected)
      (boundProjectionVariables residual)) $
    Left "context-source: selected type would capture a source binder"
  pure $ substitute variable selected residual
instantiate _ _ = Left "context-source: type application has no retained forall binder"

boundProjectionVariables :: Ord variable => LeanType variable -> Set.Set variable
boundProjectionVariables source = case source of
  LeanVariable{} -> Set.empty
  LeanNominal{} -> Set.empty
  LeanApplication a b -> descend a `Set.union` descend b
  LeanArrow a b -> descend a `Set.union` descend b
  LeanTuple _ fields -> Set.unions $ map descend fields
  LeanForall binders constraints body -> Set.unions $
    Set.fromList (map fst binders) : descend body :
      [descend argument | Constraint _ arguments <- constraints, argument <- arguments]
 where descend = boundProjectionVariables

substitute :: Eq variable => variable -> LeanType variable -> LeanType variable -> LeanType variable
substitute variable replacement source = case source of
  LeanVariable current | current == variable -> replacement
                       | otherwise -> source
  LeanNominal{} -> source
  LeanApplication a b -> LeanApplication (go a) (go b)
  LeanArrow a b -> LeanArrow (go a) (go b)
  LeanTuple boxity fields -> LeanTuple boxity $ map go fields
  LeanForall binders constraints body
    | variable `elem` map fst binders -> source
    | otherwise -> LeanForall binders (map (fmap go) constraints) (go body)
 where go = substitute variable replacement
