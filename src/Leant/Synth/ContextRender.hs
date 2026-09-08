-- | Direct projection of a checked lexical-Given graph. Preparation owns all
-- foreign identities and source binder metadata supplied here. This module
-- neither discovers instances nor grants a graph source/certificate authority.
-- It deliberately does not import the compatibility expression renderer.
module Leant.Synth.ContextRender
  ( LeanName, mkLeanName
  , LeanLevel (..), LeanBinderDomain (..), LeanVisibility (..)
  , LeanBinder (..), LeanType (..), eraseLeanType
  , LeanClassInfo (..), LeanNominalInfo (..), LeanProviderInfo (..)
  , ContextRenderEnvironment (..), ContextRenderedTerm (..)
  , ContextRenderError (..), renderLeanContextGraph
  ) where

import Control.Monad (foldM, unless, when)
import Data.Char (isAlphaNum)
import Data.List (intercalate, mapAccumL)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Language.Haskell.Synthesis.Collection (observedListLength)
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name (Boxity, Name)
import qualified Language.Haskell.Synthesis.Type as T
import qualified Language.Haskell.Synthesis.TypeAtom as A
import qualified Language.Haskell.Synthesis.TypedGenerated as Q

-- | Structured names, never executable snippets. Each component is quoted and
-- global references are rooted, so generated locals cannot capture them.
newtype LeanName = LeanName [String] deriving (Eq, Ord, Show)

mkLeanName :: [String] -> Either ContextRenderError LeanName
mkLeanName parts
  | null parts || observedListLength 64 parts > 64 = Left InvalidLeanName
  | all valid parts = Right (LeanName parts)
  | otherwise = Left InvalidLeanName
 where
  valid part = not (null part) && observedListLength 256 part <= 256
    && all (\c -> isAlphaNum c || c == '_' || c == '\'') part

data LeanLevel
  = LeanLevelZero
  | LeanLevelParameter LeanName
  | LeanLevelSuccessor LeanLevel
  | LeanLevelMax LeanLevel LeanLevel
  deriving (Eq, Ord, Show)

-- | An exact first-order type-kind domain. There is no inferred-domain case.
-- For example, @Type u -> Type v@ has one arrow with two explicit sort levels.
data LeanBinderDomain
  = LeanSortDomain LeanLevel
  | LeanKindArrow LeanBinderDomain LeanBinderDomain
  deriving (Eq, Ord, Show)

data LeanVisibility = LeanExplicit | LeanImplicit deriving (Eq, Ord, Show)
data LeanBinder = LeanBinder LeanVisibility LeanBinderDomain
  deriving (Eq, Ord, Show)

-- | Source metadata follows the complete type tree, including class arguments
-- and nested foralls. It is checked against the graph before rendering. Keeping
-- metadata on the tree lets substitution retain the selected polytype's own
-- binder domains and visibility instead of guessing a preorder alignment.
data LeanType variable
  = LeanVariable variable
  | LeanNominal Name
  | LeanApplication (LeanType variable) (LeanType variable)
  | LeanArrow (LeanType variable) (LeanType variable)
  | LeanTuple Boxity [LeanType variable]
  | LeanForall [(variable, LeanBinder)] [Constraint (LeanType variable)]
      (LeanType variable)
  deriving (Eq, Show)

eraseLeanType :: LeanType variable -> T.Type variable
eraseLeanType projection = case projection of
  LeanVariable variable -> T.TypeVariable variable
  LeanNominal name -> T.TypeConstructor name
  LeanApplication function argument -> T.TypeApplication
    (eraseLeanType function) (eraseLeanType argument)
  LeanArrow domain result -> T.FunctionType (eraseLeanType domain) (eraseLeanType result)
  LeanTuple boxity fields -> T.TupleType boxity (map eraseLeanType fields)
  LeanForall binders constraints body -> T.ForallType (map fst binders)
    (map (fmap eraseLeanType) constraints) (eraseLeanType body)

data LeanClassInfo = LeanClassInfo
  { contextClassLeanName :: LeanName
  , contextClassParameterKindArities :: [Int]
  } deriving (Eq, Show)

data LeanNominalInfo = LeanNominalInfo
  { contextNominalLeanName :: LeanName
  , contextNominalKindArity :: Int
  } deriving (Eq, Show)

data LeanProviderInfo variable = LeanProviderInfo
  { contextProviderLeanName :: LeanName
  , contextProviderSourceType :: LeanType variable
  } deriving (Eq, Show)

-- | These are preparation projections, not caller assertions promoted to
-- search evidence. A production caller must derive them from the same source
-- inventory and translation as its checked candidate. Node keys identify the
-- exact graph; selected-type keys identify visible/implicit application nodes.
-- Only the empty search-premise layout is supported in this increment.
data ContextRenderEnvironment variable = ContextRenderEnvironment
  { contextRenderClasses :: Map.Map Name LeanClassInfo
  , contextRenderNominals :: Map.Map Name LeanNominalInfo
  , contextRenderProviders :: Map.Map Name (LeanProviderInfo variable)
  , contextRenderNodeTypes :: Map.Map Q.TermNodeId (LeanType variable)
  , contextRenderSelectedTypes :: Map.Map Q.TermNodeId (LeanType variable)
  , contextRenderUniverseParameters :: Set.Set LeanName
  , contextRenderPremiseCounts :: (Int, Int)
  } deriving (Eq, Show)

data ContextRenderedTerm = ContextRenderedTerm
  { contextRenderedType :: String
  , contextRenderedExpression :: String
  } deriving (Eq, Show)

data ContextRenderError
  = InvalidLeanName
  | MissingContextNode Q.TermNodeId
  | MissingNodeTypeMetadata Q.TermNodeId
  | NodeTypeMetadataMismatch Q.TermNodeId
  | MissingSelectedTypeMetadata Q.TermNodeId
  | SelectedTypeMetadataMismatch Q.TermNodeId
  | MissingClassMetadata Name
  | MissingNominalMetadata Name
  | MissingProviderMetadata Name
  | ProviderTypeMetadataMismatch Name
  | ConflictingClassNominalIdentity Name
  | InvalidClassKindMetadata Name
  | InvalidNominalKindMetadata Name
  | ClassArgumentKindMismatch Name
  | UnboundProjectionTypeVariable
  | UnsupportedBinderDomain
  | MissingUniverseParameter LeanName
  | InvalidUniverseParameter LeanName
  | InvalidProjectionKind
  | InvalidTypeProjection
  | OpenContextGraphRoot
  | UnsupportedContextPremiseLayout
  | UnsupportedContextPattern
  | UnsupportedContextNode Q.TermNodeId
  | UnboundContextLocal
  | ContextLocalMetadataMismatch
  | ContextWitnessMetadataMismatch Q.TermNodeId
  | ContextGivenUnavailable Q.EvidenceBinderId
  | ContextGivenPredicateMismatch Q.EvidenceBinderId
  | ContextProjectionLimitExceeded
  deriving (Eq, Show)

type TypeScope variable = Map.Map variable (String, LeanBinderDomain)

-- A command-local walk budget also bounds repeated visits to a shared DAG.
-- It is separate from graph sealing's syntax/type/projection capacities.
newtype RenderM a = RenderM { runRenderM :: Int -> Either ContextRenderError (a, Int) }
instance Functor RenderM where
  fmap f (RenderM action) = RenderM $ \budget -> do
    (value, rest) <- action budget
    pure (f value, rest)
instance Applicative RenderM where
  pure value = RenderM $ \budget -> Right (value, budget)
  RenderM function <*> RenderM argument = RenderM $ \budget -> do
    (f, afterFunction) <- function budget
    (value, rest) <- argument afterFunction
    pure (f value, rest)
instance Monad RenderM where
  RenderM action >>= next = RenderM $ \budget -> do
    (value, rest) <- action budget
    runRenderM (next value) rest

checked :: Either ContextRenderError a -> RenderM a
checked result = RenderM $ \budget -> do
  value <- result
  pure (value, budget)

spend :: RenderM ()
spend = RenderM $ \budget -> if budget <= 0
  then Left ContextProjectionLimitExceeded else Right ((), budget - 1)

renderLeanContextGraph
  :: (Ord variable, Ord local)
  => ContextRenderEnvironment variable
  -> Q.TermGraph (T.Type variable) local
  -> Either ContextRenderError ContextRenderedTerm
renderLeanContextGraph environment graph = do
  unless (contextRenderPremiseCounts environment == (0, 0)) $
    Left UnsupportedContextPremiseLayout
  root <- projection $ Q.termGraphRoot graph
  unless (Set.null $ T.freeVariables $ eraseLeanType root) $ Left OpenContextGraphRoot
  signature <- properType Map.empty root
  (expression, _) <- runRenderM
    (render Map.empty Map.empty Map.empty $ Q.termGraphRoot graph) 65536
  annotated <- boundedText $ annotate expression signature
  pure $ ContextRenderedTerm signature annotated
 where
  node key = maybe (Left $ MissingContextNode key) Right $ Q.lookupTermNode key graph

  projection key = do
    current <- node key
    metadata <- maybe (Left $ MissingNodeTypeMetadata key) Right $
      Map.lookup key $ contextRenderNodeTypes environment
    observeProjection metadata
    unless (A.alphaEquivalentTypes (Q.termNodeType current) $ eraseLeanType metadata) $
      Left $ NodeTypeMetadataMismatch key
    -- Free type variables are source identities. Alpha equivalence above only
    -- renames bound ones; all opening maps below are installed lexically.
    pure metadata

  properType scope metadata = do
    (text, arity) <- typeText environment scope metadata
    unless (arity == 0) $ Left InvalidProjectionKind
    boundedText text

  render scope locals givens key = do
    spend
    current <- checked $ node key
    metadata <- checked $ projection key
    _ <- checked $ properType scope metadata
    rendered <- case Q.termNodeForm current of
      Q.TypedLocal _ variable -> do
        (name, expected) <- checked $ maybe (Left UnboundContextLocal) Right $
          Map.lookup variable locals
        checked $ unless (sameProjection metadata expected) $ Left ContextLocalMetadataMismatch
        pure $ "@" ++ name
      Q.TypedGlobal _ name -> do
        provider <- checked $ maybe (Left $ MissingProviderMetadata name) Right $
          Map.lookup name $ contextRenderProviders environment
        checked $ observeProjection $ contextProviderSourceType provider
        checked $ unless
          (Set.null (T.freeVariables $ eraseLeanType $ contextProviderSourceType provider)
            && sameProjection metadata (contextProviderSourceType provider)) $
          Left $ ProviderTypeMetadataMismatch name
        pure $ "@" ++ globalName (contextProviderLeanName provider)
      Q.TypedLambda patterns body -> do
        checked $ when (null patterns) $ Left UnsupportedContextPattern
        (parameters, nested, residual) <- checked $
          foldM (lambdaBinder scope) ([], locals, metadata) patterns
        result <- checked $ projection body
        checked $ requireProjection key residual result
        bodyText <- render scope nested givens body
        pure $ "(fun " ++ unwords parameters ++ " => " ++ bodyText ++ ")"
      Q.TypedLet pattern value body -> case Q.typedPatternNode pattern of
        Q.TypedBind variable -> do
          valueType <- checked $ projection value
          checked $ unless (A.alphaEquivalentTypes (Q.typedPatternType pattern) $
              eraseLeanType valueType) $ Left ContextLocalMetadataMismatch
          signature <- checked $ properType scope valueType
          valueText <- render scope locals givens value
          result <- checked $ projection body
          checked $ requireProjection key metadata result
          let name = localName pattern
          bodyText <- render scope (Map.insert variable (name, valueType) locals) givens body
          pure $ "@(let " ++ name ++ " : " ++ signature ++ " := " ++ valueText
            ++ "; " ++ bodyText ++ ")"
        _ -> checked $ Left UnsupportedContextPattern
      Q.TypedForallIntroduction _ body witness ->
        case (metadata, Q.forallIntroductionVariable witness) of
          (LeanForall ((_, LeanBinder visibility domain) : _) _ _,
              T.TypeVariable variable) -> do
            let name = "leantType" ++ show (Q.termNodeIdValue key)
                nested = Map.insert variable (name, domain) scope
            opened <- checked $ projection body
            checked $ requireInstantiation key metadata (LeanVariable variable) opened
            domainText <- checked $ binderDomainText environment domain
            bodyText <- render nested locals givens body
            let parameter = binderText visibility name domainText
            pure ("(fun " ++ parameter ++ " => " ++ bodyText ++ ")")
          _ -> checked $ Left $ ContextWitnessMetadataMismatch key
      Q.TypedContextIntroduction occurrence body witness -> case metadata of
        LeanForall [] constraints@(_ : _) result -> do
          opened <- checked $ projection body
          checked $ requireProjection key result opened
          checked $ requireContexts key constraints $ Q.contextIntroductionConstraints witness
          introduced <- checked $ mapM
            (\(slot, constraint) -> do
              predicate <- constraintText environment scope constraint
              let identity = Q.contextEvidenceBinder $ Q.givenContextEvidence occurrence slot
                  name = givenName identity
              pure ("[" ++ name ++ " : " ++ predicate ++ "]",
                (identity, (name, constraint))))
            (zip [0 ..] constraints)
          bodyText <- render scope locals
            (Map.union (Map.fromList $ map snd introduced) givens) body
          pure $ "(fun " ++ unwords (map fst introduced) ++ " => " ++ bodyText ++ ")"
        _ -> checked $ Left $ ContextWitnessMetadataMismatch key
      Q.TypedApply function argument witness -> do
        functionType <- checked $ projection function
        argumentType <- checked $ projection argument
        case functionType of
          LeanArrow domain result -> do
            checked $ requireProjection key domain argumentType
            checked $ requireProjection key result metadata
            checked $ unless (A.alphaEquivalentTypes (eraseLeanType domain) $
                Q.applicationDomain witness) $ Left $ ContextWitnessMetadataMismatch key
            argumentSignature <- checked $ properType scope domain
            argumentText <- render scope locals givens argument
            applyHead scope locals givens key function functionType
              [annotate argumentText argumentSignature]
          _ -> checked $ Left $ ContextWitnessMetadataMismatch key
      Q.TypedVisibleTypeApplication _ function _ witness ->
        typeApplication scope locals givens key function metadata $
          Q.typeApplicationSelected witness
      Q.TypedImplicitTypeApplication _ function witness ->
        typeApplication scope locals givens key function metadata $
          Q.implicitTypeApplicationSelected witness
      Q.TypedContextApplication _ function witness -> do
        functionType <- checked $ projection function
        case functionType of
          LeanForall [] constraints@(_ : _) result -> do
            checked $ requireProjection key result metadata
            checked $ requireContexts key constraints $ Q.contextApplicationConstraints witness
            let evidence = Q.contextApplicationEvidence witness
            checked $ unless (length constraints == length evidence) $
              Left $ ContextWitnessMetadataMismatch key
            arguments <- checked $ mapM (chosenGiven givens) $ zip constraints evidence
            applyHead scope locals givens key function functionType arguments
          _ -> checked $ Left $ ContextWitnessMetadataMismatch key
      Q.TypedTuple{} -> checked $ Left $ UnsupportedContextNode key
      Q.TypedCase{} -> checked $ Left $ UnsupportedContextNode key
      Q.TypedHole{} -> checked $ Left $ UnsupportedContextNode key
    checked $ boundedText rendered

  lambdaBinder scope (parameters, locals, residual) pattern =
    case (residual, Q.typedPatternNode pattern) of
      (LeanArrow domain result, Q.TypedBind variable) -> do
        unless (A.alphaEquivalentTypes (Q.typedPatternType pattern) $ eraseLeanType domain) $
          Left ContextLocalMetadataMismatch
        signature <- properType scope domain
        let name = localName pattern
        pure (parameters ++ ["(" ++ name ++ " : " ++ signature ++ ")"],
          Map.insert variable (name, domain) locals, result)
      (LeanArrow domain result, Q.TypedWildcard) -> do
        unless (A.alphaEquivalentTypes (Q.typedPatternType pattern) $ eraseLeanType domain) $
          Left ContextLocalMetadataMismatch
        signature <- properType scope domain
        pure (parameters ++ ["(" ++ localName pattern ++ " : " ++ signature ++ ")"],
          locals, result)
      _ -> Left UnsupportedContextPattern

  -- Explicit application is always headed by a fresh local with the complete
  -- source type. This works for local/global/compound heads alike and exposes
  -- precisely the checked type, dictionary or ordinary argument slots.
  -- The compound term itself must also be explicit: without the outer @,
  -- Lean can introduce an expected residual implicit/context binder before
  -- elaborating the let body, changing the type expected of this partial use.
  applyHead scope locals givens owner function source arguments = do
    signature <- checked $ properType scope source
    functionText <- render scope locals givens function
    let name = "leantHead" ++ show (Q.termNodeIdValue owner)
    pure $ "@(let " ++ name ++ " : " ++ signature ++ " := " ++ functionText
      ++ "; @" ++ name ++ " " ++ unwords arguments ++ ")"

  typeApplication scope locals givens owner function result selected = do
    source <- checked $ projection function
    argument <- checked $ maybe (Left $ MissingSelectedTypeMetadata owner) Right $
      Map.lookup owner $ contextRenderSelectedTypes environment
    checked $ observeProjection argument
    checked $ unless (A.alphaEquivalentTypes selected $ eraseLeanType argument) $
      Left $ SelectedTypeMetadataMismatch owner
    checked $ requireInstantiation owner source argument result
    (argumentText, argumentKind) <- checked $ typeText environment scope argument
    case source of
      LeanForall ((_, LeanBinder _ domain) : _) _ _ -> do
        expectedKind <- checked $ domainArity domain
        checked $ unless (argumentKind == expectedKind) $ Left InvalidProjectionKind
      _ -> checked $ Left $ ContextWitnessMetadataMismatch owner
    applyHead scope locals givens owner function source [parens argumentText]

  chosenGiven givens (predicate, evidence) = do
    let identity = Q.contextEvidenceBinder evidence
    (name, actual) <- maybe (Left $ ContextGivenUnavailable identity) Right $
      Map.lookup identity givens
    unless (sameConstraint predicate actual) $ Left $ ContextGivenPredicateMismatch identity
    pure name

  requireContexts key projections constraints = unless
    (length projections == length constraints
      && and (zipWith sameErasedConstraint projections constraints)) $
        Left $ ContextWitnessMetadataMismatch key

  requireProjection key expected actual = unless (sameProjection expected actual) $
    Left $ ContextWitnessMetadataMismatch key

  requireInstantiation key source selected result = case instantiateProjection source selected of
    Just instantiated -> do
      observeProjection instantiated
      unless (sameProjection instantiated $ mapProjection Right result) $
        Left $ ContextWitnessMetadataMismatch key
    _ -> Left $ ContextWitnessMetadataMismatch key

sameErasedConstraint :: Ord variable
  => Constraint (LeanType variable) -> Constraint (T.Type variable) -> Bool
sameErasedConstraint (Constraint leftName left) (Constraint rightName right) =
  leftName == rightName && length left == length right
    && and (zipWith (\a b -> A.alphaEquivalentTypes (eraseLeanType a) b) left right)

sameConstraint :: Ord variable
  => Constraint (LeanType variable) -> Constraint (LeanType variable) -> Bool
sameConstraint (Constraint leftName left) (Constraint rightName right) =
  leftName == rightName && length left == length right && and (zipWith sameProjection left right)

sameProjection :: Ord variable => LeanType variable -> LeanType variable -> Bool
sameProjection left right =
  A.alphaEquivalentTypes (eraseLeanType left) (eraseLeanType right)
    && binderMetadata left == binderMetadata right

binderMetadata :: LeanType variable -> [LeanBinder]
binderMetadata projection = case projection of
  LeanForall binders constraints body -> map snd binders
    ++ concatMap (concatMap binderMetadata . constraintArguments) constraints ++ binderMetadata body
  _ -> concatMap binderMetadata $ projectionChildren projection

mapProjection :: (a -> b) -> LeanType a -> LeanType b
mapProjection f projection = case projection of
  LeanVariable variable -> LeanVariable $ f variable
  LeanNominal name -> LeanNominal name
  LeanApplication function argument -> LeanApplication (mapProjection f function) (mapProjection f argument)
  LeanArrow domain result -> LeanArrow (mapProjection f domain) (mapProjection f result)
  LeanTuple boxity fields -> LeanTuple boxity $ map (mapProjection f) fields
  LeanForall binders constraints body -> LeanForall
    [(f variable, metadata) | (variable, metadata) <- binders]
    (map (fmap $ mapProjection f) constraints) (mapProjection f body)

-- Fresh tagged variables make substitution capture-free even when a selected
-- type's free variable has the spelling of a nested source binder. The result
-- is compared alpha-equivalently with metadata, never converted to an inferred
-- Lean type. Source and selected binders use disjoint fresh supplies.
instantiateProjection :: Ord variable
  => LeanType variable -> LeanType variable -> Maybe (LeanType (Either Int variable))
instantiateProjection source selected = case freshen 0 Map.empty source of
  (next, LeanForall ((variable, _) : rest) constraints body) ->
    let (_, selected') = freshen next Map.empty selected
        residual = if null rest && null constraints then body else LeanForall rest constraints body
    in Just $ substitute variable selected' residual
  _ -> Nothing
 where
  substitute variable replacement projection = case projection of
    LeanVariable current | current == variable -> replacement
                         | otherwise -> projection
    LeanNominal{} -> projection
    LeanApplication function argument -> LeanApplication (go function) (go argument)
    LeanArrow domain result -> LeanArrow (go domain) (go result)
    LeanTuple boxity fields -> LeanTuple boxity $ map go fields
    LeanForall binders constraints body
      | variable `elem` map fst binders -> projection
      | otherwise -> LeanForall binders (map (fmap go) constraints) (go body)
   where go = substitute variable replacement

freshen :: Ord variable => Int -> Map.Map variable (Either Int variable)
  -> LeanType variable -> (Int, LeanType (Either Int variable))
freshen next scope projection = case projection of
  LeanVariable variable -> (next, LeanVariable $ Map.findWithDefault (Right variable) variable scope)
  LeanNominal name -> (next, LeanNominal name)
  LeanApplication function argument -> binary LeanApplication function argument
  LeanArrow domain result -> binary LeanArrow domain result
  LeanTuple boxity fields -> let (after, fields') = mapAccumL (\n -> freshen n scope) next fields
    in (after, LeanTuple boxity fields')
  LeanForall binders constraints body ->
    let introduced = zip (map fst binders) $ map Left [next .. next + length binders - 1]
        nested = Map.union (Map.fromList introduced) scope
        renamed = zip (map snd introduced) (map snd binders)
        (afterConstraints, constraints') = mapAccumL
          (\n (Constraint name arguments) ->
            let (rest, arguments') = mapAccumL (\i -> freshen i nested) n arguments
            in (rest, Constraint name arguments')) (next + length binders) constraints
        (after, body') = freshen afterConstraints nested body
    in (after, LeanForall renamed constraints' body')
 where
  binary constructor left right =
    let (afterLeft, left') = freshen next scope left
        (afterRight, right') = freshen afterLeft scope right
    in (afterRight, constructor left' right')

-- Projection inputs are checked before alpha comparison or substitution.
observeProjection :: Ord variable => LeanType variable -> Either ContextRenderError ()
observeProjection projection = do
  _ <- walk (4096 :: Int) projection
  either (const $ Left InvalidTypeProjection) Right $ T.validateType $ eraseLeanType projection
 where
  walk fuel current = do
    when (fuel <= 0) $ Left ContextProjectionLimitExceeded
    case current of
      LeanForall binders constraints _ -> do
        width binders
        width constraints
        mapM_ (observeDomain . (\(LeanBinder _ domain) -> domain) . snd) binders
        mapM_ (width . constraintArguments) constraints
      LeanTuple _ fields -> width fields
      _ -> Right ()
    foldM walk (fuel - 1) $ projectionChildren current
  width values = when (observedListLength 256 values > 256) $ Left ContextProjectionLimitExceeded

  observeDomain domain = do
    _ <- domainArity domain
    () <$ walkDomain (256 :: Int) domain
  walkDomain fuel _ | fuel <= 0 = Left ContextProjectionLimitExceeded
  walkDomain fuel (LeanSortDomain level) = walkLevel (fuel - 1) level
  walkDomain fuel (LeanKindArrow parameter result) = do
    rest <- walkDomain (fuel - 1) parameter
    walkDomain rest result
  walkLevel fuel _ | fuel <= 0 = Left ContextProjectionLimitExceeded
  walkLevel fuel LeanLevelZero = Right (fuel - 1)
  walkLevel fuel (LeanLevelParameter _) = Right (fuel - 1)
  walkLevel fuel (LeanLevelSuccessor level) = walkLevel (fuel - 1) level
  walkLevel fuel (LeanLevelMax left right) = do
    rest <- walkLevel (fuel - 1) left
    walkLevel rest right

projectionChildren :: LeanType variable -> [LeanType variable]
projectionChildren projection = case projection of
  LeanApplication function argument -> [function, argument]
  LeanArrow domain result -> [domain, result]
  LeanTuple _ fields -> fields
  LeanForall _ constraints body -> concatMap constraintArguments constraints ++ [body]
  _ -> []

domainArity :: LeanBinderDomain -> Either ContextRenderError Int
domainArity = go (64 :: Int)
 where
  go _ (LeanSortDomain _) = Right 0
  go fuel (LeanKindArrow (LeanSortDomain _) result)
    | fuel > 0 = (1 +) <$> go (fuel - 1) result
  go _ _ = Left UnsupportedBinderDomain

typeText :: Ord variable => ContextRenderEnvironment variable -> TypeScope variable
  -> LeanType variable -> Either ContextRenderError (String, Int)
typeText environment = go (0 :: Int)
 where
  go depth scope projection = case projection of
    LeanVariable variable -> do
      (name, domain) <- maybe (Left UnboundProjectionTypeVariable) Right $ Map.lookup variable scope
      arity <- domainArity domain
      pure (name, arity)
    LeanNominal name -> do
      when (Map.member name $ contextRenderClasses environment) $ Left $ ConflictingClassNominalIdentity name
      info <- maybe (Left $ MissingNominalMetadata name) Right $ Map.lookup name $ contextRenderNominals environment
      let arity = contextNominalKindArity info
      when (arity < 0 || arity > 64) $ Left $ InvalidNominalKindMetadata name
      pure ("@" ++ globalName (contextNominalLeanName info), arity)
    LeanApplication function argument -> do
      (functionText, functionKind) <- go depth scope function
      (argumentText, argumentKind) <- go depth scope argument
      unless (functionKind > 0 && argumentKind == 0) $ Left InvalidProjectionKind
      pure (parens $ functionText ++ " " ++ parens argumentText, functionKind - 1)
    LeanArrow domain result -> do
      left <- proper depth scope domain
      right <- proper depth scope result
      pure (parens $ left ++ " → " ++ right, 0)
    LeanTuple{} -> Left UnsupportedBinderDomain
    LeanForall binders constraints body -> do
      let occupied = Set.fromList $ map fst $ Map.elems scope
          names = [freshName occupied $ "leantBound" ++ show depth ++ "x" ++ show index
                  | index <- [0 :: Int .. length binders - 1]]
          nested = Map.union (Map.fromList
            [(variable, (name, domain)) | ((variable, LeanBinder _ domain), name) <- zip binders names]) scope
      parameters <- mapM
        (\((_, LeanBinder visibility domain), name) ->
          binderText visibility name <$> binderDomainText environment domain) (zip binders names)
      predicates <- mapM (constraintText environment nested) constraints
      result <- proper (depth + 1) nested body
      let prefix = parameters ++ ["[" ++ predicate ++ "]" | predicate <- predicates]
      pure (if null prefix then result else parens $ "∀ " ++ unwords prefix ++ ", " ++ result, 0)

  proper depth scope projection = do
    (text, kind) <- go depth scope projection
    unless (kind == 0) $ Left InvalidProjectionKind
    pure text

  freshName occupied name
    | Set.member name occupied = freshName occupied $ name ++ "x"
    | otherwise = name

constraintText :: Ord variable => ContextRenderEnvironment variable -> TypeScope variable
  -> Constraint (LeanType variable) -> Either ContextRenderError String
constraintText environment scope (Constraint name arguments) = do
  info <- maybe (Left $ MissingClassMetadata name) Right $ Map.lookup name $ contextRenderClasses environment
  when (Map.member name $ contextRenderNominals environment) $ Left $ ConflictingClassNominalIdentity name
  let kinds = contextClassParameterKindArities info
  when (observedListLength 256 kinds > 256 || any (\kind -> kind < 0 || kind > 64) kinds) $
    Left $ InvalidClassKindMetadata name
  unless (length arguments == length kinds) $ Left $ ClassArgumentKindMismatch name
  rendered <- mapM (typeText environment scope) arguments
  unless (map snd rendered == kinds) $ Left $ ClassArgumentKindMismatch name
  pure $ "@" ++ globalName (contextClassLeanName info)
    ++ concatMap ((" " ++) . parens . fst) rendered

binderDomainText :: ContextRenderEnvironment variable -> LeanBinderDomain
  -> Either ContextRenderError String
binderDomainText environment domain = do
  _ <- domainArity domain
  render domain
 where
  render (LeanSortDomain LeanLevelZero) = Right "Prop"
  render (LeanSortDomain (LeanLevelSuccessor LeanLevelZero)) = Right "Type"
  render (LeanSortDomain (LeanLevelSuccessor level)) = ("Type " ++) <$> levelText 128 level
  render (LeanSortDomain level) = ("Sort " ++) <$> levelText 128 level
  render (LeanKindArrow parameter result) = do
    left <- render parameter
    right <- render result
    pure $ parens $ left ++ " → " ++ right
  levelText :: Int -> LeanLevel -> Either ContextRenderError String
  levelText fuel _ | fuel <= 0 = Left ContextProjectionLimitExceeded
  levelText _ LeanLevelZero = Right "0"
  levelText _ (LeanLevelParameter name@(LeanName parts)) = do
    unless (length parts == 1) $ Left $ InvalidUniverseParameter name
    unless (Set.member name $ contextRenderUniverseParameters environment) $
      Left $ MissingUniverseParameter name
    pure $ relativeName name
  levelText fuel (LeanLevelSuccessor level) = do
    text <- levelText (fuel - 1) level
    pure $ parens $ text ++ " + 1"
  levelText fuel (LeanLevelMax left right) = do
    a <- levelText (fuel - 1) left
    b <- levelText (fuel - 1) right
    pure $ parens $ "max " ++ a ++ " " ++ b

givenName :: Q.EvidenceBinderId -> String
givenName identity = "leantGiven" ++ show (Q.occurrenceIdValue $ Q.evidenceBinderIntroduction identity)
  ++ "x" ++ show (Q.evidenceBinderSlot identity)

localName :: Q.TypedPattern ty local -> String
localName pattern = "leantLocal" ++ show (Q.occurrenceIdValue $ Q.typedPatternOccurrence pattern)

binderText :: LeanVisibility -> String -> String -> String
binderText visibility name domain = case visibility of
  LeanExplicit -> "(" ++ name ++ " : " ++ domain ++ ")"
  LeanImplicit -> "{" ++ name ++ " : " ++ domain ++ "}"

relativeName :: LeanName -> String
relativeName (LeanName parts) = intercalate "." $ map (\part -> "«" ++ part ++ "»") parts

globalName :: LeanName -> String
globalName name = "_root_." ++ relativeName name

parens :: String -> String
parens text = "(" ++ text ++ ")"

annotate :: String -> String -> String
annotate expression signature = parens $ expression ++ " : " ++ signature

boundedText :: String -> Either ContextRenderError String
boundedText text
  | observedListLength 1048576 text > 1048576 = Left ContextProjectionLimitExceeded
  | otherwise = Right text
