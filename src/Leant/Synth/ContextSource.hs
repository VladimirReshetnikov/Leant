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
  , contextNominalIdentity, contextValueIdentity
  , PreparedContextSource, prepareContextSource, prepareContextSourceProviders
  , renderPreparedContextGraph
  , ContextCandidateRejection (..), ContextProjectionFailure (..)
  , renderContextCandidateRejection, checkPreparedContextGraph
  ) where

import Control.Monad (foldM, unless, when)
import qualified Data.Bifunctor as Bifunctor
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name (Boxity (..), Name)
import qualified Language.Haskell.Synthesis.Type as T
import qualified Language.Haskell.Synthesis.TypeAtom as A
import qualified Language.Haskell.Synthesis.TypedGenerated as Q
import Leant.Synth.ContextUniverse
import Leant.Synth.ContextRender

data ContextSourceVisibility = ContextExplicit | ContextImplicit | ContextStrictImplicit
  deriving (Eq, Show)

-- Legacy forall nodes and nominal/class parameters have the exact domain
-- Type 0. A nominal/class declaration must itself end in Type 0.
-- The exact nominal form also retains universe-zero constant instantiations.
-- Exact forall domains additionally retain Type universes. Nominal/class
-- parameter domains and constant selections remain independently checked.
data ContextSourceType
  = ContextVariable String
  | ContextNominal [String] Int [ContextSourceType]
  | ContextNominalAt [String] Int [LeanLevel] [ContextSourceType]
  | ContextNominalExact [String] ContextUniverseSelection [ContextSourceType]
  | ContextArrow ContextSourceType ContextSourceType
  | ContextForall ContextSourceVisibility String ContextSourceType
  | ContextForallAt ContextSourceVisibility String LeanLevel ContextSourceType
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
    let owner = contextValueIdentity parts packet
    when (Set.member owner owners || not (null $ contextSourceConstructors packet)) $
      Left "context-source: duplicate or nested constructor inventory"
    family <- case resultType $ contextSourceType packet of
      ContextNominal name _ _ -> Right $ contextSourceName name
      ContextNominalAt name _ _ _ -> Right $ contextSourceName name
      ContextNominalExact name selected _ -> Right $ contextNominalIdentity name selected
      _ -> Left "context-source: constructor result is not nominal"
    unless (Set.member family reachable) $
      Left "context-source: constructor family is not reachable from the goal"
    pure (Set.insert owner owners, Set.union reachable $ nominalNames $ contextSourceType packet)
  resultType (ContextForall _ _ body) = resultType body
  resultType (ContextForallAt _ _ _ body) = resultType body
  resultType (ContextArrow _ body) = resultType body
  resultType body = body
  nominalNames current = case current of
    ContextVariable{} -> Set.empty
    ContextNominal name _ args -> Set.insert (contextSourceName name) $ Set.unions $ map nominalNames args
    ContextNominalAt name _ _ args -> Set.insert (contextSourceName name) $ Set.unions $ map nominalNames args
    ContextNominalExact name selected args -> Set.insert (contextNominalIdentity name selected) $
      Set.unions $ map nominalNames args
    ContextArrow a b -> Set.union (nominalNames a) (nominalNames b)
    ContextForall _ _ body -> nominalNames body
    ContextForallAt _ _ _ body -> nominalNames body
    ContextGiven _ _ args body -> Set.unions $ map nominalNames (body : args)

contextSourceName :: [String] -> String
contextSourceName = intercalate "."

contextNominalIdentity :: [String] -> ContextUniverseSelection -> String
contextNominalIdentity parts = selectionIdentity (contextSourceName parts)

contextValueIdentity :: [String] -> ContextSource -> String
contextValueIdentity parts = universeIdentity (contextSourceName parts) . contextSourceValueLevels

contextSourceHasGiven :: ContextSourceType -> Bool
contextSourceHasGiven source = case source of
  ContextGiven{} -> True
  ContextArrow a b -> contextSourceHasGiven a || contextSourceHasGiven b
  ContextForall _ _ body -> contextSourceHasGiven body
  ContextForallAt _ _ _ body -> contextSourceHasGiven body
  ContextNominal _ _ arguments -> any contextSourceHasGiven arguments
  ContextNominalAt _ _ _ arguments -> any contextSourceHasGiven arguments
  ContextNominalExact _ _ arguments -> any contextSourceHasGiven arguments
  ContextVariable{} -> False

mkContextSource :: ContextSourceType -> Either String ContextSource
mkContextSource = validateContextSource True

-- A provider may be context-free, but still needs a closed, complete source
-- scheme. The goal entrance continues to require an actual lexical Given.
mkContextProviderSource :: ContextSourceType -> Either String ContextSource
mkContextProviderSource = validateContextSource False

mkContextProviderSourceAt :: [LeanLevel] -> ContextSourceType -> Either String ContextSource
mkContextProviderSourceAt levels source = do
  unless (length levels <= 64) $ Left "context-source: constant universe vector exceeds limit"
  normalized <- traverse normalizeUniverse levels
  packet <- mkContextProviderSource source
  pure packet { contextSourceValueLevels = normalized }

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
  _ <- sourceNominalUniverses source
  pure $ ContextSource source [] []
 where
  inspect fuel _ _ _ _ | fuel <= (0 :: Int) = Left "context-source: source exceeds node limit"
  inspect fuel scope classes nominals current = case current of
    ContextVariable variable -> do
      unless (Set.member variable scope) $ Left "context-source: unbound type variable"
      pure (fuel - 1, classes, nominals)
    ContextForall visibility variable body ->
      inspect fuel scope classes nominals $ ContextForallAt visibility variable typeZeroSort body
    ContextForallAt _ variable level body -> do
      _ <- typeUniverse level
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
    ContextNominalExact name selected arguments -> do
      let arity = length $ selectionArgumentSorts selected
      when (Map.member (contextSourceName name) classes) $
        Left "context-source: a class identity also occurs as an ordinary nominal type"
      updated <- insertNameWithIdentity (contextNominalIdentity name selected) name arity arguments
        (arity, selectionLevels selected) nominals
      inspectArguments (fuel - 1) scope classes updated arguments
    ContextGiven name arity arguments body -> do
      updated <- insertName name arity arguments arity classes
      (remaining, afterClasses, afterNominals) <- inspectArguments (fuel - 1) scope updated nominals arguments
      inspect remaining scope afterClasses afterNominals body
  inspectArguments fuel scope classes nominals = foldM
    (\(remaining, cs, ns) -> inspect remaining scope cs ns) (fuel, classes, nominals)
  insertName parts = insertNameWithIdentity (contextSourceName parts) parts
  insertNameWithIdentity name parts arity arguments metadata names = do
    _ <- either (Left . show) Right $ mkLeanName parts
    unless (arity >= 0 && arity <= 64 && length arguments == arity) $
      Left "context-source: unsaturated or unsupported nominal/class arity"
    case Map.lookup name names of
      Just previous | previous /= metadata -> Left "context-source: inconsistent source arity or universe arguments"
      _ -> pure $ Map.insert name metadata names

typeZeroSort :: LeanLevel
typeZeroSort = LeanLevelSuccessor LeanLevelZero

-- Every variable carries the domain of its own lexical opening. A higher
-- universe variable cannot silently enter a still-Type-0 nominal or class.
sourceUniverse :: ContextSourceType -> Either String LeanLevel
sourceUniverse = go Map.empty
 where
  go scope source = case source of
    ContextVariable variable -> maybe (Left "context-source: unbound universe owner") Right $ Map.lookup variable scope
    ContextArrow domain result -> do
      a <- go scope domain
      b <- go scope result
      normalizeUniverse $ LeanLevelMax a b
    ContextForall visibility variable body -> go scope $ ContextForallAt visibility variable typeZeroSort body
    ContextForallAt _ variable level body -> do
      domain <- typeUniverse level
      result <- go (Map.insert variable domain scope) body
      normalizeUniverse $ LeanLevelMax (LeanLevelSuccessor domain) result
    ContextNominal _ _ arguments -> checkArguments scope arguments >> pure LeanLevelZero
    ContextNominalAt _ _ _ arguments -> checkArguments scope arguments >> pure LeanLevelZero
    ContextNominalExact _ selected arguments -> do
      actual <- traverse (go scope) arguments
      expected <- traverse typeUniverse $ selectionArgumentSorts selected
      unless (actual == expected) $
        Left "context-source: nominal argument differs from its selected declaration universe"
      typeUniverse $ selectionResultSort selected
    ContextGiven _ _ arguments body -> checkArguments scope arguments >> go scope body
  checkArguments scope arguments = do
    levels <- traverse (go scope) arguments
    unless (all (== LeanLevelZero) levels) $
      Left "context-source: higher-universe argument supplied to a Type-0 nominal or class"

sourceUniverseParameters :: ContextSourceType -> Set.Set LeanName
sourceUniverseParameters source = case source of
  ContextVariable{} -> Set.empty
  ContextNominal _ _ arguments -> children arguments
  ContextNominalAt _ _ levels arguments -> Set.union (Set.unions $ map parameters levels) $ children arguments
  ContextNominalExact _ selected arguments -> Set.union
    (Set.unions $ map parameters $ selectionLevels selected) $ children arguments
  ContextArrow domain result -> children [domain, result]
  ContextForall _ _ body -> sourceUniverseParameters body
  ContextForallAt _ _ level body -> Set.union (parameters level) $ sourceUniverseParameters body
  ContextGiven _ _ arguments body -> children (body : arguments)
 where
  children = Set.unions . map sourceUniverseParameters
  parameters LeanLevelZero = Set.empty
  parameters (LeanLevelParameter name) = Set.singleton name
  parameters (LeanLevelSuccessor level) = parameters level
  parameters (LeanLevelMax a b) = Set.union (parameters a) (parameters b)

type NominalUniverse = ([LeanLevel], LeanLevel)

-- Selected instances have separate private keys, but all selections of one
-- declaration must agree on its closed, alpha-normalized universe template.
sourceNominalUniverses
  :: ContextSourceType
  -> Either String (Map.Map String NominalUniverse, Map.Map [String] ContextUniverseSignature)
sourceNominalUniverses source = do
  (instances, declarations, nominals, classes) <- walk
    (Map.empty, Map.empty, Set.empty, Set.empty) source
  unless (Set.null $ Set.intersection nominals classes) $
    Left "context-source: a class identity also occurs as an ordinary nominal type"
  pure (instances, declarations)
 where
  walk state current = case current of
    ContextVariable{} -> pure state
    ContextArrow a b -> foldM walk state [a, b]
    ContextForall _ _ body -> walk state body
    ContextForallAt _ _ _ body -> walk state body
    ContextGiven parts _ arguments body ->
      let (instances, declarations, nominals, classes) = state
      in foldM walk (instances, declarations, nominals, Set.insert parts classes) (body : arguments)
    ContextNominal parts arity arguments ->
      walk state $ ContextNominalAt parts arity [] arguments
    ContextNominalAt parts arity _ arguments ->
      add state parts (contextSourceName parts) (replicate arity typeZeroSort, typeZeroSort)
        Nothing arguments
    ContextNominalExact parts selected arguments ->
      add state parts (contextNominalIdentity parts selected)
        (selectionArgumentSorts selected, selectionResultSort selected)
        (Just $ selectionSignature selected) arguments
  add (instances, declarations, nominals, classes) parts key sorts template arguments = do
    updated <- insert "selected nominal universe signature" key sorts instances
    declared <- maybe (pure declarations)
      (\signature -> insert "declaration universe template" parts signature declarations) template
    foldM walk (updated, declared, Set.insert parts nominals, classes) arguments
  insert label key value entries = case Map.lookup key entries of
    Just old | old /= value -> Left $ "context-source: inconsistent " ++ label
    _ -> pure $ Map.insert key value entries

data PreparedContextSource = PreparedContextSource
  { preparedContextRoot :: LeanType String
  , preparedContextClasses :: Map.Map Name LeanClassInfo
  , preparedContextNominals :: Map.Map Name LeanNominalInfo
  , preparedContextProviders :: Map.Map Name (LeanProviderInfo String)
  , preparedContextUniverses :: Set.Set LeanName
  , preparedContextNominalUniverses :: Map.Map Name NominalUniverse
  , preparedContextNominalDeclarations :: Map.Map [String] ContextUniverseSignature
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
  (sourceUniverses, declarations) <- sourceNominalUniverses source
  universeEntries <- traverse (\(key, sorts) -> do
    (private, _) <- maybe (Left "context-source: nominal universe lacks its private identity") Right $
      Map.lookup key nominals
    pure (private, sorts)) $ Map.toList sourceUniverses
  pure $ PreparedContextSource aligned (Map.fromList classEntries) (Map.fromList nominalEntries) Map.empty
    (sourceUniverseParameters source) (Map.fromList universeEntries) declarations
 where
  project current = case current of
    ContextVariable variable -> pure (LeanVariable variable, [], [])
    ContextArrow domain result -> do
      (a, ac, an) <- project domain
      (b, bc, bn) <- project result
      pure (LeanArrow a b, ac ++ bc, an ++ bn)
    ContextNominal parts arity arguments -> project $ ContextNominalAt parts arity [] arguments
    ContextNominalAt parts arity levels arguments -> do
      projectNominal (contextSourceName parts) parts arity levels arguments
    ContextNominalExact parts selected arguments ->
      projectNominal (contextNominalIdentity parts selected) parts
        (length $ selectionArgumentSorts selected) (selectionLevels selected) arguments
    ContextForall{} -> projectForall current
    ContextForallAt{} -> projectForall current
    ContextGiven parts arity arguments body -> do
      (constraint, cs, ns) <- projectConstraint (parts, arity, arguments)
      (result, bc, bn) <- project body
      pure (LeanForall [] [constraint] result, cs ++ bc, ns ++ bn)
  projectNominal key parts arity levels arguments = do
      (private, actualArity) <- maybe (Left "context-source: nominal has no source-owned translation") Right $
        Map.lookup key nominals
      unless (arity == actualArity) $ Left "context-source: translated nominal kind changed"
      name <- either (Left . show) Right $ mkLeanName parts
      projected <- traverse project arguments
      pure (foldl LeanApplication (LeanNominal private) $ map first projected,
        concatMap second projected,
        (private, LeanNominalInfo name arity levels) : concatMap third projected)
  projectForall current = do
      let (binders, afterBinders) = allSpine current
          (contexts, body) = givenSpine afterBinders
      projectedContexts <- traverse projectConstraint contexts
      (result, bodyClasses, bodyNominals) <- project body
      exactBinders <- traverse (\(visibility, variable, level) -> do
        normalized <- normalizeUniverse level
        pure (variable, binder visibility normalized)) binders
      pure (LeanForall exactBinders
          (map first projectedContexts) result,
        concatMap second projectedContexts ++ bodyClasses,
        concatMap third projectedContexts ++ bodyNominals)
  projectConstraint (parts, arity, arguments) = do
    (private, kinds) <- maybe (Left "context-source: class has no source-owned translation") Right $
      Map.lookup (contextSourceName parts) classes
    unless (kinds == replicate arity 0) $ Left "context-source: translated class parameter kinds changed"
    name <- either (Left . show) Right $ mkLeanName parts
    projected <- traverse project arguments
    pure (Constraint private $ map first projected,
      (private, LeanClassInfo name kinds) : concatMap second projected,
      concatMap third projected)
  binder visibility level = LeanBinder
    (case visibility of
       ContextExplicit -> LeanExplicit
       ContextImplicit -> LeanImplicit
       ContextStrictImplicit -> LeanStrictImplicit)
    (LeanSortDomain level)
  allSpine (ContextForall visibility variable body) =
    allSpine $ ContextForallAt visibility variable typeZeroSort body
  allSpine (ContextForallAt visibility variable level body) =
    let (rest, result) = allSpine body in ((visibility, variable, level) : rest, result)
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
        || any (\provider -> contextProviderLeanName provider == foreignName &&
              contextProviderConstantLevels provider == contextSourceValueLevels source)
          (Map.elems $ preparedContextProviders prepared)) $
      Left "context-source: duplicate global provider owner"
    provider <- prepareContextSource classes nominals scheme source
    unless (Set.null $ T.freeVariables scheme) $
      Left "context-source: global provider scheme is open"
    combinedClasses <- merge (preparedContextClasses prepared) (preparedContextClasses provider)
    combinedNominals <- merge (preparedContextNominals prepared) (preparedContextNominals provider)
    combinedNominalUniverses <- merge (preparedContextNominalUniverses prepared) (preparedContextNominalUniverses provider)
    combinedDeclarations <- merge (preparedContextNominalDeclarations prepared) (preparedContextNominalDeclarations provider)
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
      , preparedContextUniverses = Set.union (preparedContextUniverses prepared) (preparedContextUniverses provider)
      , preparedContextNominalUniverses = combinedNominalUniverses
      , preparedContextNominalDeclarations = combinedDeclarations
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
  (LeanTuple boxity fields, T.TupleType actualBoxity actualFields)
    | boxity == actualBoxity && length fields == length actualFields ->
      LeanTuple boxity <$> sequence (zipWith (alignProjection scope) fields actualFields)
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

-- The engine checks an erased type language. A well-formed candidate can
-- therefore choose an instantiation that this exact Lean source cannot admit.
-- These refusals consume their raw candidate slot but are not corrupt graphs.
data ContextCandidateRejection
  = ContextSelectedUniverseMismatch LeanLevel LeanLevel
  | ContextNominalArgumentUniverseMismatch
  | ContextUnsupportedSelectedPolytype
  | ContextUnsupportedSelectedTuple
  | ContextUnsupportedSelectedKind
  deriving (Eq, Ord, Show)

data ContextProjectionFailure
  = ContextProjectionIntegrityFailure String
  | ContextProjectionCandidateRejected ContextCandidateRejection
  deriving (Eq, Show)

renderContextCandidateRejection :: ContextCandidateRejection -> String
renderContextCandidateRejection reason = "context-source: " ++ case reason of
  ContextSelectedUniverseMismatch expected actual ->
    "selected type universe differs from its source binder domain (expected "
      ++ show expected ++ ", selected " ++ show actual ++ ")"
  ContextNominalArgumentUniverseMismatch -> "selected nominal argument differs from its declaration universe"
  ContextUnsupportedSelectedPolytype -> "impredicative selected types need unsupported universe evidence"
  ContextUnsupportedSelectedTuple -> "selected tuple type is unsupported"
  ContextUnsupportedSelectedKind -> "selected type is not a proper type"

integrity :: Either String value -> Either ContextProjectionFailure value
integrity = Bifunctor.first ContextProjectionIntegrityFailure

newtype Project variable value = Project
  { runProject :: ProjectionState variable
      -> Either (ContextProjectionFailure, ProjectionState variable) (value, ProjectionState variable) }

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
checked = checkedProjection . integrity

checkedProjection :: Either ContextProjectionFailure value -> Project variable value
checkedProjection result = Project $ \state ->
  Bifunctor.bimap (\failure -> (failure, state)) (\value -> (value, state)) result

chargeProjection :: Project variable ()
chargeProjection = Project $ \state@(ProjectionState remaining nodes selections) ->
  if remaining <= 0
    then Left (ContextProjectionIntegrityFailure "context-source: rooted projection walk exceeds limit", state)
    else Right ((), ProjectionState (remaining - 1) nodes selections)

remember :: Eq variable => Q.TermNodeId -> LeanType variable -> Project variable ()
remember owner metadata = Project $ \state@(ProjectionState remaining nodes selections) ->
  case Map.lookup owner nodes of
    Just previous | previous /= metadata -> Left
      (ContextProjectionIntegrityFailure "context-source: a shared graph node acquired conflicting lexical metadata", state)
    _ -> Right ((), ProjectionState remaining (Map.insert owner metadata nodes) selections)

select :: Q.TermNodeId -> LeanType variable -> Project variable ()
select owner metadata = Project $ \(ProjectionState remaining nodes selections) ->
  Right ((), ProjectionState remaining nodes (Map.insert owner metadata selections))

-- Retry only an evidence deficit. Roll back provisional metadata, but preserve
-- every unit of work consumed by the failed branch. A malformed graph or an
-- established universe mismatch is never a fallback.
withSelectionEvidence :: Project variable value -> Project variable value -> Project variable value
withSelectionEvidence first alternative = Project $ \state@(ProjectionState _ nodes selections) -> case runProject first state of
  Left (ContextProjectionCandidateRejected ContextUnsupportedSelectedPolytype, ProjectionState remaining _ _) ->
    runProject alternative $ ProjectionState remaining nodes selections
  result -> result

renderPreparedContextGraph
  :: (Ord variable, Ord local)
  => PreparedContextSource -> Q.TermGraph (T.Type variable) local
  -> Either String [String]
renderPreparedContextGraph prepared graph = Bifunctor.first diagnostic $ checkPreparedContextGraph prepared graph
 where
  diagnostic (ContextProjectionIntegrityFailure failure) = failure
  diagnostic (ContextProjectionCandidateRejected reason) = renderContextCandidateRejection reason

-- Paths identify source-owned positions; a dictionary telescope is distinct
-- from an ordinary function arrow even though its evidence is erased in search.
data ProjectionStep = ProjectionArrowDomain | ProjectionArrowResult | ProjectionContextBody

checkPreparedContextGraph
  :: (Ord variable, Ord local)
  => PreparedContextSource -> Q.TermGraph (T.Type variable) local
  -> Either ContextProjectionFailure [String]
checkPreparedContextGraph prepared graph = do
  root <- integrity $ node $ Q.termGraphRoot graph
  projection <- integrity $ alignProjection Map.empty (preparedContextRoot prepared) $ Q.termNodeType root
  (_, ProjectionState _ nodes selections) <- Bifunctor.first fst $ runProject
    (check Map.empty Map.empty (Q.termGraphRoot graph) projection)
    (ProjectionState 65536 Map.empty Map.empty)
  providers <- integrity $ fmap Map.fromList $ mapM
    (\(name, metadata) -> do
      source <- maybe (Left "context-source: global provider lacks a complete source packet") Right $
        Map.lookup name $ preparedContextProviders prepared
      pure (name, LeanProviderInfo (contextProviderLeanName source) (contextProviderConstantLevels source) metadata))
    [ (name, metadata)
    | (owner, metadata) <- Map.toList nodes
    , Just current <- [Q.lookupTermNode owner graph]
    , Q.TypedGlobal _ name <- [Q.termNodeForm current]
    ]
  rendered <- integrity $ either (Left . ("context-render: " ++) . show) Right $
    renderLeanContextGraph ContextRenderEnvironment
      { contextRenderClasses = preparedContextClasses prepared
      , contextRenderNominals = preparedContextNominals prepared
      , contextRenderProviders = providers
      , contextRenderNodeTypes = nodes
      , contextRenderSelectedTypes = selections
      , contextRenderUniverseParameters = preparedContextUniverses prepared
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
    chargeProjection
    (metadata, form) <- retain owner expected
    case form of
      Q.TypedLambda patterns body -> do
        (nested, result) <- checked $ foldM lambda (locals, metadata) patterns
        check scope nested body result
      Q.TypedTuple elements -> case metadata of
        LeanTuple Boxed fields | length fields == length elements && length fields /= 1 ->
          sequence_ $ zipWith (check scope locals) elements fields
        _ -> checked $ Left "context-source: tuple construction lost its exact field types"
      Q.TypedForallIntroduction _ body witness -> case Q.forallIntroductionVariable witness of
        T.TypeVariable variable -> do
          when (Map.member variable scope) $ checked $ Left "context-source: forall opening reused a scoped identity"
          universe <- checked $ forallUniverse metadata
          result <- checked $ instantiate metadata $ LeanVariable variable
          check (Map.insert variable universe scope) locals body result
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
        inferred <- inferWith scope locals owner [([], metadata)]
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

  infer scope locals owner = inferWith scope locals owner []

  -- A hint has an exact structural address in this node's type. Steps follow
  -- an arrow domain/result or a discharged context body. No unrelated alpha-matching
  -- source type is allowed to donate a selected forall's binder metadata.
  inferWith scope locals owner hints = do
    chargeProjection
    current <- checked $ node owner
    inferred <- case Q.termNodeForm current of
      Q.TypedLocal _ variable -> checked $ maybe
        (Left "context-source: local has no source-owned binder metadata") Right $ Map.lookup variable locals
      Q.TypedGlobal _ name -> checked $ do
        provider <- maybe (Left "context-source: global provider lacks a complete source packet") Right $
          Map.lookup name $ preparedContextProviders prepared
        alignProjection Map.empty (contextProviderSourceType provider) $ Q.termNodeType current
      Q.TypedTuple elements -> LeanTuple Boxed <$> traverse (infer scope locals) elements
      Q.TypedApply function argument _ -> do
        let resultHints = [(ProjectionArrowResult : path, value) | (path, value) <- hints]
        functionType <- inferWith scope locals function resultHints `withSelectionEvidence` do
          argumentType <- infer scope locals argument
          inferWith scope locals function (([ProjectionArrowDomain], argumentType) : resultHints)
        case functionType of
          LeanArrow domain result -> check scope locals argument domain >> pure result
          _ -> checked $ Left "context-source: term application did not retain an arrow"
      Q.TypedVisibleTypeApplication{} -> applyTypes scope locals owner hints
      Q.TypedImplicitTypeApplication{} -> applyTypes scope locals owner hints
      Q.TypedContextApplication _ function _ -> do
        functionType <- inferWith scope locals function
          [(ProjectionContextBody : path, value) | (path, value) <- hints]
        case functionType of
          LeanForall [] (_ : _) result -> pure result
          _ -> checked $ Left "context-source: dictionary application did not retain its context"
      _ -> checked $ Left "context-source: unsupported unanchored graph construction"
    (actual, _) <- retain owner inferred
    checked $ mapM_ (\(path, expected) -> do
      observed <- projectionAt path actual
      aligned <- align expected $ eraseLeanType observed
      unless (aligned == observed) $ Left "context-source: application evidence conflicts with exact source metadata") hints
    pure actual

  -- Collect consecutive type applications before recovering any erased binder
  -- metadata. The final expected type constrains every selected variable in
  -- the original telescope, including a polytype chosen before another binder.
  applyTypes scope locals owner hints = do
    (function, applications) <- typeApplications owner []
    functionType <- infer scope locals function
    (variables, residual) <- checked $ selectionTelescope (length applications) functionType
    foldM (applyOne variables residual) functionType $ zip variables applications
   where
    applyOne variables residual functionType (variable, (application, selected)) = do
      checked $ unless (T.freeVariables selected `Set.isSubsetOf` Map.keysSet scope) $
        Left "context-source: selected variable has no actual source opening"
      argument <- checkedProjection $ case monotype scope selected of
        Left (ContextProjectionCandidateRejected ContextUnsupportedSelectedPolytype) ->
          recoverSelection (Set.fromList variables) residual variable selected hints
        result -> result
      checkedProjection $ unless (properMonotype argument == Just 0) $
        Left $ ContextProjectionCandidateRejected ContextUnsupportedSelectedKind
      expectedUniverse <- checked $ forallUniverse functionType
      actualUniverse <- checkedProjection $ projectionUniverse scope argument
      checkedProjection $ unless (actualUniverse == expectedUniverse) $
        Left $ ContextProjectionCandidateRejected $ ContextSelectedUniverseMismatch expectedUniverse actualUniverse
      select application argument
      instantiated <- checked $ instantiate functionType argument
      fst <$> retain application instantiated

  typeApplications owner applications = do
    chargeProjection
    current <- checked $ node owner
    case Q.termNodeForm current of
      Q.TypedVisibleTypeApplication _ function _ witness ->
        typeApplications function ((owner, Q.typeApplicationSelected witness) : applications)
      Q.TypedImplicitTypeApplication _ function witness ->
        typeApplications function ((owner, Q.implicitTypeApplicationSelected witness) : applications)
      _ -> pure (owner, applications)

  selectionTelescope 0 source = Right ([], source)
  selectionTelescope count (LeanForall ((variable, _) : rest) constraints body) = do
    let residual = if null rest && null constraints then body else LeanForall rest constraints body
    (variables, result) <- selectionTelescope (count - 1) residual
    pure (variable : variables, result)
  selectionTelescope _ _ = Left "context-source: type application spine does not match its source telescope"

  projectionAt [] projection = Right projection
  projectionAt (ProjectionArrowDomain : rest) (LeanArrow domain _) = projectionAt rest domain
  projectionAt (ProjectionArrowResult : rest) (LeanArrow _ result) = projectionAt rest result
  projectionAt (ProjectionContextBody : rest) (LeanForall [] (_ : _) body) = projectionAt rest body
  projectionAt _ _ = Left "context-source: application evidence has no matching source position"

  recoverSelection variables residual variable selected hints = do
    pieces <- integrity $ fmap concat $ traverse (\(path, expected) -> do
      template <- projectionAt path residual
      matchSelection variables Map.empty template expected) hints
    aligned <- integrity $ traverse (\piece -> alignProjection
      (Map.fromSet id $ T.freeVariables selected) piece selected)
      [piece | (owner, piece) <- pieces, owner == variable]
    case aligned of
      [] -> Left $ ContextProjectionCandidateRejected ContextUnsupportedSelectedPolytype
      first : others -> do
        integrity $ unless (all (== first) others) $
          Left "context-source: selected type has conflicting source evidence"
        pure first

  -- Match a source-owned residual telescope against the corresponding expected
  -- subtree. Bound variables have lexical owners; a selection cannot refer to
  -- a binder introduced below that position or borrow its visibility/domain.
  matchSelection selectedVariables bound template expected = case (template, expected) of
    (LeanVariable variable, _)
      | Set.member variable selectedVariables && Map.notMember variable bound -> do
          unless (Set.null $ Set.intersection (T.freeVariables $ eraseLeanType expected)
            (Set.fromList $ Map.elems bound)) $
            Left "context-source: selected evidence escapes a nested source binder"
          pure [(variable, expected)]
    (LeanVariable variable, LeanVariable actual)
      | Map.findWithDefault variable variable bound == actual -> pure []
    (LeanNominal name, LeanNominal actual) | name == actual -> pure []
    (LeanApplication a b, LeanApplication x y) -> both a x b y
    (LeanArrow a b, LeanArrow x y) -> both a x b y
    (LeanTuple boxity fields, LeanTuple actualBoxity actualFields)
      | boxity == actualBoxity && length fields == length actualFields ->
          concat <$> sequence (zipWith descend fields actualFields)
    (LeanForall binders constraints body, LeanForall actualBinders actualConstraints actualBody)
      | map snd binders == map snd actualBinders && length constraints == length actualConstraints -> do
          let nested = Map.union (Map.fromList $ zip (map fst binders) (map fst actualBinders)) bound
              recur = matchSelection selectedVariables nested
          fields <- fmap concat $ sequence
            [ if name == actualName && length args == length actualArgs
                then concat <$> sequence (zipWith recur args actualArgs)
                else Left "context-source: selected evidence changed a class predicate"
            | (Constraint name args, Constraint actualName actualArgs) <- zip constraints actualConstraints ]
          (fields ++) <$> recur body actualBody
    _ -> Left "context-source: selected evidence does not match its source position"
   where
    descend = matchSelection selectedVariables bound
    both a x b y = (++) <$> descend a x <*> descend b y

  monotype scope selected = case selected of
    T.TypeVariable variable
      | Map.member variable scope -> pure $ LeanVariable variable
      | otherwise -> integrity $ Left "context-source: selected variable has no actual source opening"
    T.TypeConstructor name
      | Map.member name (preparedContextNominals prepared) -> pure $ LeanNominal name
      | otherwise -> integrity $ Left "context-source: selected nominal has no exact source metadata"
    T.TypeApplication a b -> LeanApplication <$> monotype scope a <*> monotype scope b
    T.FunctionType a b -> LeanArrow <$> monotype scope a <*> monotype scope b
    T.ForallType{} -> Left $ ContextProjectionCandidateRejected ContextUnsupportedSelectedPolytype
    T.TupleType Boxed fields | length fields /= 1 -> LeanTuple Boxed <$> traverse (monotype scope) fields
    T.TupleType{} -> Left $ ContextProjectionCandidateRejected ContextUnsupportedSelectedTuple

  properMonotype projection = case projection of
    LeanVariable{} -> Just 0
    LeanNominal name -> contextNominalKindArity <$> Map.lookup name (preparedContextNominals prepared)
    LeanApplication a b -> case (properMonotype a, properMonotype b) of
      (Just arity, Just 0) | arity > 0 -> Just (arity - 1)
      _ -> Nothing
    LeanArrow a b | properMonotype a == Just 0 && properMonotype b == Just 0 -> Just 0
    LeanTuple Boxed fields | length fields /= 1 && all ((== Just 0) . properMonotype) fields -> Just 0
    LeanForall binders constraints body
      | all properBinder binders && properMonotype body == Just 0
      , all (all ((== Just 0) . properMonotype)) constraints -> Just 0
    _ -> Nothing
   where
    properBinder (_, LeanBinder _ (LeanSortDomain level)) = either (const False) (const True) $ typeUniverse level
    properBinder _ = False

  forallUniverse (LeanForall ((_, LeanBinder _ (LeanSortDomain level)) : _) _ _) = typeUniverse level
  forallUniverse _ = Left "context-source: type application has no exact Type binder domain"

  projectionUniverse scope projection = case projection of
    LeanVariable variable -> integrity $ maybe (Left "context-source: selected variable lost its universe owner") Right $
      Map.lookup variable scope
    LeanNominal name
      | Just metadata <- Map.lookup name (preparedContextNominals prepared)
      , contextNominalKindArity metadata == 0 -> nominalUniverse scope name []
    LeanApplication{} -> do
      let (headType, arguments) = applicationSpine projection
      case headType of
        LeanNominal name
          | Just metadata <- Map.lookup name (preparedContextNominals prepared)
          , contextNominalKindArity metadata == length arguments -> nominalUniverse scope name arguments
        _ -> integrity $ Left "context-source: selected application has no exact universe signature"
    LeanArrow domain result -> do
      a <- projectionUniverse scope domain
      b <- projectionUniverse scope result
      integrity $ normalizeUniverse $ LeanLevelMax a b
    LeanTuple Boxed fields | length fields /= 1 -> do
      levels <- traverse (projectionUniverse scope) fields
      integrity $ foldM (\a b -> normalizeUniverse $ LeanLevelMax a b) LeanLevelZero levels
    LeanForall binders constraints body -> do
      domains <- integrity $ traverse (\(variable, LeanBinder _ domain) -> case domain of
        LeanSortDomain level -> (,) variable <$> typeUniverse level
        _ -> Left "context-source: selected forall has an unsupported kind domain") binders
      let nested = Map.union (Map.fromList domains) scope
      -- This source route currently admits Type-0 classes only. Keep their
      -- argument checks after substitution; a dictionary is not erased here.
      mapM_ (\(Constraint name arguments) -> do
        metadata <- integrity $ maybe (Left "context-source: selected class has no source metadata") Right $
          Map.lookup name $ preparedContextClasses prepared
        levels <- traverse (projectionUniverse nested) arguments
        integrity $ unless (length levels == length (contextClassParameterKindArities metadata)
            && all (== LeanLevelZero) levels) $
          Left "context-source: selected class argument differs from its declaration universe") constraints
      result <- projectionUniverse nested body
      integrity $ foldM (\level (_, domain) -> normalizeUniverse $
        LeanLevelMax (LeanLevelSuccessor domain) level) result domains
    _ -> integrity $ Left "context-source: selected type has no exact universe signature"

  nominalUniverse scope name arguments = do
    (domains, result) <- integrity $ maybe
      (Left "context-source: selected nominal has no declaration universe signature") Right $
      Map.lookup name $ preparedContextNominalUniverses prepared
    expected <- integrity $ traverse typeUniverse domains
    actual <- traverse (projectionUniverse scope) arguments
    unless (actual == expected) $
      Left $ ContextProjectionCandidateRejected ContextNominalArgumentUniverseMismatch
    integrity $ typeUniverse result

  applicationSpine = go []
   where
    go arguments (LeanApplication function argument) = go (argument : arguments) function
    go arguments headType = (headType, arguments)

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
