-- These tests target the vendored Djex lexical-context graph API. The Lean
-- replay source below is independently executable; the registered test module
-- never launches Lean or a compiler. test-context/run_replay.py owns replay.
module ContextRenderSpec (tests, contextReplaySource) where

import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name (Name, parseName)
import qualified Language.Haskell.Synthesis.Type as T
import qualified Language.Haskell.Synthesis.TypedGenerated as Q
import Leant.Synth.ContextRender
import Numeric.Natural (Natural)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, testCase, (@?=))

type Variable = T.Variable String
type Ty = T.Type Variable
type Source = Q.TermGraphSource Ty Int
type Graph = Q.TermGraph Ty Int
type Environment = ContextRenderEnvironment Variable

tests :: TestTree
tests = testGroup "direct Lean lexical context rendering"
  [ testCase "select distinct equal-predicate dictionary slots with equal erasures" $ do
      first <- rendered $ duplicateFixture 0
      second <- rendered $ duplicateFixture 1
      contextRenderedType first @?= contextRenderedType second
      assertBool "different chosen dictionaries collapsed into the same Lean term" $
        contextRenderedExpression first /= contextRenderedExpression second
      contains "; @leantHead2 leantGiven0x0)" $ contextRenderedExpression first
      contains "; @leantHead2 leantGiven0x1)" $ contextRenderedExpression second
      contains "[leantGiven0x0 :" $ contextRenderedExpression first
      contains "[leantGiven0x1 :" $ contextRenderedExpression first
      Q.eraseTermGraph (snd $ duplicateFixture 0) @?=
        Q.eraseTermGraph (snd $ duplicateFixture 1)
      noEvidenceHoles first
      noEvidenceHoles second
  , testCase "select an outer dictionary under an equal inner introduction" $ do
      value <- rendered shadowFixture
      contains "[leantGiven0x0 :" $ contextRenderedExpression value
      contains "[leantGiven1x0 :" $ contextRenderedExpression value
      contains "; @leantHead3 leantGiven0x0)" $ contextRenderedExpression value
      noEvidenceHoles value
  , testCase "retain exact type selection and scoped dictionaries for a rank-N callback" $ do
      value <- rendered rankNFixture
      contains "(fun (leantType0 : Type)" $ contextRenderedExpression value
      contains "{leantBound0x0 : Type}" $ contextRenderedExpression value
      contains "; @leantHead5 (leantType0))" $ contextRenderedExpression value
      contains "; @leantHead4 leantGiven1x0)" $ contextRenderedExpression value
      contains "leantLocal3" $ contextRenderedExpression value
      noEvidenceHoles value
  , testCase "retain an outer dictionary across nested implicit forall and context introductions" $ do
      value <- rendered nestedFixture
      contains "(fun (leantType0 : Type)" $ contextRenderedExpression value
      contains "(fun {leantType2 : Type}" $ contextRenderedExpression value
      contains "[leantGiven3x0 :" $ contextRenderedExpression value
      contains "; @leantHead5 leantGiven1x0)" $ contextRenderedExpression value
      noEvidenceHoles value
  , testCase "avoid capturing an outer type variable in a polymorphic class argument" $ do
      value <- rendered classArgumentFixture
      contains "(leantBound0x0x : Type)" $ contextRenderedType value
      contains "(leantBound0x0 → leantBound0x0x)" $ contextRenderedType value
      noEvidenceHoles value
  , testCase "retain a global provider's complete constrained implicit scheme" $ do
      value <- rendered providerFixture
      contains "@_root_.«ContextFixture».«observe»" $ contextRenderedExpression value
      contains "∀ {leantBound0x0 : Type}" $ contextRenderedExpression value
      contains "; @leantHead3 (leantType0))" $ contextRenderedExpression value
      contains "; @leantHead2 leantGiven1x0)" $ contextRenderedExpression value
      noEvidenceHoles value
  , testCase "carry a constrained local through an ordinary typed let" $ do
      value <- rendered letFixture
      contains "let leantLocal2 :" $ contextRenderedExpression value
      contains "; @leantHead4 leantGiven0x0)" $ contextRenderedExpression value
      noEvidenceHoles value
  , testCase "keep duplicate unused context binders in a dictionary-independent implementation" $ do
      value <- rendered independentFixture
      contains "[leantGiven0x0 :" $ contextRenderedExpression value
      contains "[leantGiven0x1 :" $ contextRenderedExpression value
      contains "(fun (leantLocal1 : @" $ contextRenderedExpression value
      contains "=> @leantLocal1)" $ contextRenderedExpression value
      noEvidenceHoles value
      let residual = arrow nat $ arrow nat nat
          sourceType = qualified [classC nat] residual
          source = Q.TermGraphSource (nid 0)
            [ (nid 0, node sourceType $ intro 0 1 sourceType)
            , (nid 1, node residual $ Q.TypedLambda
                [Q.TypedPattern (oid 1) nat Q.TypedWildcard, bind 2 0 nat] (nid 2))
            , (nid 2, node nat $ Q.TypedLocal (oid 3) 0)
            ]
      wildcard <- rendered $ fixture Map.empty [] [] source
      contains "[leantGiven0x0 :" $ contextRenderedExpression wildcard
      contains "(leantLocal1 :" $ contextRenderedExpression wildcard
      contains "(leantLocal2 :" $ contextRenderedExpression wildcard
      contains "=> @leantLocal2)" $ contextRenderedExpression wildcard
      noEvidenceHoles wildcard
  , testCase "missing class authority fails before a poisoned provider map is forced" $ do
      let (environment, graph) = duplicateFixture 0
      renderLeanContextGraph environment
          { contextRenderClasses = Map.empty
          , contextRenderProviders = error "missing class forced irrelevant providers"
          } graph @?= Left (MissingClassMetadata className)
  , testCase "a nominal spelling cannot donate class authority" $ do
      let (environment, graph) = duplicateFixture 0
      renderLeanContextGraph environment
          { contextRenderClasses = Map.empty
          , contextRenderNominals = Map.insert className
              (LeanNominalInfo (lean ["ContextFixture", "C"]) 1)
              (contextRenderNominals environment)
          } graph @?= Left (MissingClassMetadata className)
  , testCase "reject a class kind-arity claim inconsistent with the selected source type" $ do
      let (environment, graph) = duplicateFixture 0
      renderLeanContextGraph environment
          { contextRenderClasses = Map.singleton className $
              LeanClassInfo (lean ["ContextFixture", "C"]) [1]
          } graph @?= Left (ClassArgumentKindMismatch className)
  , testCase "require the exact complete provider scheme, including binder visibility" $ do
      let (environment, graph) = providerFixture
          changed = project (Map.singleton boundA explicitType) providerType
      renderLeanContextGraph environment
          { contextRenderProviders = Map.singleton providerName $
              LeanProviderInfo (lean ["ContextFixture", "observe"]) changed
          } graph @?= Left (ProviderTypeMetadataMismatch providerName)
  , testCase "missing selected-type metadata is not an elaborator placeholder" $ do
      let (environment, graph) = rankNFixture
      renderLeanContextGraph environment
          { contextRenderSelectedTypes = Map.empty }
          graph @?= Left (MissingSelectedTypeMetadata $ nid 5)
  , testCase "retain the selected impredicative type's own binder metadata after substitution" $ do
      let (environment, graph) = impredicativeFixture
          wrongSelection = project (Map.singleton boundB implicitType) polyIdentity
      renderLeanContextGraph environment
          { contextRenderSelectedTypes = Map.singleton (nid 1) wrongSelection }
          graph @?= Left (ContextWitnessMetadataMismatch $ nid 1)
  , testCase "missing node projection is an explicit error" $ do
      let (environment, graph) = duplicateFixture 0
      renderLeanContextGraph environment
          { contextRenderNodeTypes = Map.delete (nid 3) $ contextRenderNodeTypes environment }
          graph @?= Left (MissingNodeTypeMetadata $ nid 3)
  , testCase "refuse nonempty premise layouts without forcing the graph or source maps" $ do
      let (environment, _) = duplicateFixture 0
      renderLeanContextGraph environment
          { contextRenderPremiseCounts = (1, 0)
          , contextRenderClasses = error "unsupported premises forced the class map"
          } (error "unsupported premises forced the graph" :: Graph)
        @?= Left UnsupportedContextPremiseLayout
  , testCase "refuse unsupported patterns before reaching their body" $ do
      let source = Q.TermGraphSource (nid 0)
            [ (nid 0, node (arrow nat nat) $ Q.TypedLambda
                [Q.TypedPattern (oid 0) nat $ Q.TypedAs 0 $
                  Q.TypedPattern (oid 2) nat Q.TypedWildcard] (nid 1))
            , (nid 1, node nat $ Q.TypedGlobal (oid 1) providerName)
            ]
          (environment, graph) = fixture Map.empty [] [] source
      renderLeanContextGraph environment
          { contextRenderProviders = error "unsupported pattern forced the provider" }
          graph @?= Left UnsupportedContextPattern
  , testCase "require declared universe parameters instead of inventing a domain" $ do
      let (environment, graph) = providerFixture
          universe = lean ["u"]
          changed = project (Map.singleton boundA $ LeanBinder LeanExplicit $
              LeanSortDomain $ LeanLevelSuccessor $ LeanLevelParameter universe) rootProviderType
      renderLeanContextGraph environment
          { contextRenderNodeTypes = Map.insert (nid 0) changed $ contextRenderNodeTypes environment }
          graph @?= Left (MissingUniverseParameter universe)
  , testCase "bound metadata domain trees before structural equality" $ do
      let (environment, graph) = providerFixture
          tooDeep = iterate LeanLevelSuccessor LeanLevelZero !! 300
          changed = project (Map.singleton boundA $ LeanBinder LeanExplicit $
              LeanSortDomain tooDeep) rootProviderType
      renderLeanContextGraph environment
          { contextRenderNodeTypes = Map.insert (nid 0) changed $ contextRenderNodeTypes environment }
          graph @?= Left ContextProjectionLimitExceeded
  , testCase "reject foreign name snippets at the structured name boundary" $ do
      mkLeanName ["ContextFixture", "C) := by sorry"] @?= Left InvalidLeanName
      mkLeanName ["C\n#check Nat"] @?= Left InvalidLeanName
  , testCase "prepare independent complete-signature payload replay and wrong-result controls" $ do
      source <- either (fail . show) pure contextReplaySource
      contains "contextChooseFirst : [ContextFixture.C Nat]" source
      contains "contextChooseSecond : [ContextFixture.C Nat]" source
      contains "= 11 := by rfl" source
      contains "= 29 := by rfl" source
      contains "≠ 29 := by decide" source
      contains "≠ 11 := by decide" source
      contains "#print axioms contextFirstPayload" source
      assertBool "replay source introduced a proof escape" $ not $ "sorry" `isInfixOf` source
  ]

-- | A standalone Lean source artifact assembled from actual renderer output.
-- Full declaration signatures and observations are written independently of
-- contextRenderedType. Execute this only under the parent's serialized Lean
-- token and retain actual #print axioms results; constructing this String is
-- not kernel/execution evidence.
contextReplaySource :: Either ContextRenderError String
contextReplaySource = do
  first <- renderFixture $ duplicateFixture 0
  second <- renderFixture $ duplicateFixture 1
  shadow <- renderFixture shadowFixture
  rankN <- renderFixture rankNFixture
  nested <- renderFixture nestedFixture
  provider <- renderFixture providerFixture
  alias <- renderFixture letFixture
  pure $ unlines
    [ "set_option autoImplicit false"
    , "namespace ContextFixture"
    , "class C (α : Type) where"
    , "  payload : Nat"
    , "def first : C Nat := ⟨11⟩"
    , "def second : C Nat := ⟨29⟩"
    , "def boolSecond : C Bool := ⟨43⟩"
    , "def observe {α : Type} [c : C α] : Nat := c.payload"
    , "def observeValue {α : Type} [c : C α] (_value : α) : Nat := c.payload"
    , "end ContextFixture"
    , definition "contextChooseFirst"
        "[ContextFixture.C Nat] → [ContextFixture.C Nat] → ([ContextFixture.C Nat] → Nat) → Nat" first
    , definition "contextChooseSecond"
        "[ContextFixture.C Nat] → [ContextFixture.C Nat] → ([ContextFixture.C Nat] → Nat) → Nat" second
    , definition "contextChooseOuter"
        "[ContextFixture.C Nat] → [ContextFixture.C Nat] → ([ContextFixture.C Nat] → Nat) → Nat" shadow
    , definition "contextRankN"
        "(A : Type) → [ContextFixture.C A] → (∀ {b : Type}, [ContextFixture.C b] → b → Nat) → A → Nat" rankN
    , definition "contextNested"
        "(A : Type) → [ContextFixture.C A] → {B : Type} → [ContextFixture.C B] → ([ContextFixture.C A] → Nat) → Nat" nested
    , definition "contextProvider"
        "(A : Type) → [ContextFixture.C A] → Nat" provider
    , definition "contextAlias"
        "[ContextFixture.C Nat] → ([ContextFixture.C Nat] → Nat) → Nat" alias
    , "theorem contextFirstPayload : @contextChooseFirst ContextFixture.first ContextFixture.second (@ContextFixture.observe Nat) = 11 := by rfl"
    , "theorem contextSecondPayload : @contextChooseSecond ContextFixture.first ContextFixture.second (@ContextFixture.observe Nat) = 29 := by rfl"
    , "theorem contextOuterPayload : @contextChooseOuter ContextFixture.first ContextFixture.second (@ContextFixture.observe Nat) = 11 := by rfl"
    , "theorem contextRankNPayload : @contextRankN Nat ContextFixture.second (@ContextFixture.observeValue) 7 = 29 := by rfl"
    , "theorem contextNestedPayload : @contextNested Nat ContextFixture.first Bool ContextFixture.boolSecond (@ContextFixture.observe Nat) = 11 := by rfl"
    , "theorem contextProviderPayload : @contextProvider Nat ContextFixture.first = 11 := by rfl"
    , "theorem contextAliasPayload : @contextAlias ContextFixture.second (@ContextFixture.observe Nat) = 29 := by rfl"
    , "theorem contextFirstWrong : @contextChooseFirst ContextFixture.first ContextFixture.second (@ContextFixture.observe Nat) ≠ 29 := by decide"
    , "theorem contextSecondWrong : @contextChooseSecond ContextFixture.first ContextFixture.second (@ContextFixture.observe Nat) ≠ 11 := by decide"
    , "#print axioms contextFirstPayload"
    , "#print axioms contextSecondPayload"
    , "#print axioms contextOuterPayload"
    , "#print axioms contextRankNPayload"
    , "#print axioms contextNestedPayload"
    , "#print axioms contextProviderPayload"
    , "#print axioms contextAliasPayload"
    , "#print axioms contextFirstWrong"
    , "#print axioms contextSecondWrong"
    ]
 where
  definition name signature value = "def " ++ name ++ " : " ++ signature
    ++ " :=\n  " ++ contextRenderedExpression value

duplicateFixture :: Natural -> (Environment, Graph)
duplicateFixture selected = fixture Map.empty [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ intro 0 1 source)
  , (nid 1, node body $ Q.TypedLambda [bind 1 0 offered] (nid 2))
  , (nid 2, node nat $ discharge 2 3 offered [given 0 selected])
  , (nid 3, node offered $ Q.TypedLocal (oid 3) 0)
  ]
 where
  offered = qualified [classC nat] nat
  body = arrow offered nat
  source = qualified [classC nat, classC nat] body

shadowFixture :: (Environment, Graph)
shadowFixture = fixture Map.empty [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ intro 0 1 source)
  , (nid 1, node inner $ intro 1 2 inner)
  , (nid 2, node body $ Q.TypedLambda [bind 2 0 offered] (nid 3))
  , (nid 3, node nat $ discharge 3 4 offered [given 0 0])
  , (nid 4, node offered $ Q.TypedLocal (oid 4) 0)
  ]
 where
  offered = qualified [classC nat] nat
  body = arrow offered nat
  inner = qualified [classC nat] body
  source = qualified [classC nat] inner

rankNFixture :: (Environment, Graph)
rankNFixture = fixture binders [] [(nid 5, T.TypeVariable rigidA)] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ Q.TypedForallIntroduction (oid 0) (nid 1) $
      Q.ForallIntroductionWitness source (T.TypeVariable rigidA) opened)
  , (nid 1, node opened $ intro 1 2 opened)
  , (nid 2, node body $ Q.TypedLambda [bind 2 0 callback, bind 3 1 a] (nid 3))
  , (nid 3, node nat $ Q.TypedApply (nid 4) (nid 7) $ Q.ApplicationWitness a nat)
  , (nid 4, node (arrow a nat) $ discharge 4 5 chosen [given 1 0])
  , (nid 5, node chosen $ Q.TypedImplicitTypeApplication (oid 5) (nid 6) $
      Q.ImplicitTypeApplicationWitness callback a chosen)
  , (nid 6, node callback $ Q.TypedLocal (oid 6) 0)
  , (nid 7, node a $ Q.TypedLocal (oid 7) 1)
  ]
 where
  binders = Map.fromList [(boundA, explicitType), (boundB, implicitType)]
  a = T.TypeVariable rigidA
  b = T.TypeVariable boundB
  callback = T.ForallType [boundB] [classC b] $ arrow b nat
  chosen = qualified [classC a] $ arrow a nat
  body = arrow callback $ arrow a nat
  opened = qualified [classC a] body
  source = T.ForallType [boundA] [classC $ T.TypeVariable boundA] $
    arrow callback $ arrow (T.TypeVariable boundA) nat

providerFixture :: (Environment, Graph)
providerFixture =
  let source = Q.TermGraphSource (nid 0)
        [ (nid 0, node rootProviderType $ Q.TypedForallIntroduction (oid 0) (nid 1) $
            Q.ForallIntroductionWitness rootProviderType a opened)
        , (nid 1, node opened $ intro 1 2 opened)
        , (nid 2, node nat $ discharge 2 3 opened [given 1 0])
        , (nid 3, node opened $ Q.TypedImplicitTypeApplication (oid 3) (nid 4) $
            Q.ImplicitTypeApplicationWitness providerType a opened)
        , (nid 4, node providerType $ Q.TypedGlobal (oid 4) providerName)
        ]
      (environment, graph) = fixture (Map.singleton boundA explicitType)
        [] [(nid 3, a)] source
      providerProjection = project (Map.singleton boundA implicitType) providerType
  in (environment
      { contextRenderNodeTypes = Map.insert (nid 4) providerProjection $ contextRenderNodeTypes environment
      , contextRenderProviders = Map.singleton providerName $
          LeanProviderInfo (lean ["ContextFixture", "observe"]) providerProjection
      }, graph)
 where
  a = T.TypeVariable rigidA
  opened = qualified [classC a] nat

nestedFixture :: (Environment, Graph)
nestedFixture = fixture binders [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ Q.TypedForallIntroduction (oid 0) (nid 1) $
      Q.ForallIntroductionWitness source a openedA)
  , (nid 1, node openedA $ intro 1 2 openedA)
  , (nid 2, node inner $ Q.TypedForallIntroduction (oid 2) (nid 3) $
      Q.ForallIntroductionWitness inner b openedB)
  , (nid 3, node openedB $ intro 3 4 openedB)
  , (nid 4, node body $ Q.TypedLambda [bind 4 0 offered] (nid 5))
  , (nid 5, node nat $ discharge 5 6 offered [given 1 0])
  , (nid 6, node offered $ Q.TypedLocal (oid 6) 0)
  ]
 where
  binders = Map.fromList [(boundA, explicitType), (boundB, implicitType)]
  a = T.TypeVariable rigidA
  b = T.TypeVariable rigidB
  offered = qualified [classC a] nat
  body = arrow offered nat
  openedB = qualified [classC b] body
  inner = T.ForallType [boundB] [classC $ T.TypeVariable boundB] body
  openedA = qualified [classC a] inner
  source = T.ForallType [boundA] [classC $ T.TypeVariable boundA] $
    T.ForallType [boundB] [classC $ T.TypeVariable boundB] $
      arrow (qualified [classC $ T.TypeVariable boundA] nat) nat

classArgumentFixture :: (Environment, Graph)
classArgumentFixture = fixture binders [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ Q.TypedForallIntroduction (oid 0) (nid 1) $
      Q.ForallIntroductionWitness source (T.TypeVariable rigidA) opened)
  , (nid 1, node opened $ intro 1 2 opened)
  , (nid 2, node (arrow nat nat) $ Q.TypedLambda [bind 2 0 nat] (nid 3))
  , (nid 3, node nat $ Q.TypedLocal (oid 3) 0)
  ]
 where
  binders = Map.fromList [(boundA, explicitType), (boundB, explicitType)]
  argument a = T.ForallType [boundB] [] $ arrow a $ T.TypeVariable boundB
  opened = qualified [classC $ argument $ T.TypeVariable rigidA] $ arrow nat nat
  source = T.ForallType [boundA] [classC $ argument $ T.TypeVariable boundA] $ arrow nat nat

rootProviderType, providerType :: Ty
rootProviderType = T.ForallType [boundA] [classC $ T.TypeVariable boundA] nat
providerType = rootProviderType

letFixture :: (Environment, Graph)
letFixture = fixture Map.empty [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ intro 0 1 source)
  , (nid 1, node body $ Q.TypedLambda [bind 1 0 offered] (nid 2))
  , (nid 2, node nat $ Q.TypedLet (bind 2 1 offered) (nid 3) (nid 4))
  , (nid 3, node offered $ Q.TypedLocal (oid 3) 0)
  , (nid 4, node nat $ discharge 4 5 offered [given 0 0])
  , (nid 5, node offered $ Q.TypedLocal (oid 5) 1)
  ]
 where
  offered = qualified [classC nat] nat
  body = arrow offered nat
  source = qualified [classC nat] body

independentFixture :: (Environment, Graph)
independentFixture = fixture Map.empty [] [] $ Q.TermGraphSource (nid 0)
  [ (nid 0, node source $ intro 0 1 source)
  , (nid 1, node (arrow nat nat) $ Q.TypedLambda [bind 1 0 nat] (nid 2))
  , (nid 2, node nat $ Q.TypedLocal (oid 2) 0)
  ]
 where source = qualified [classC nat, classC nat] $ arrow nat nat

impredicativeFixture :: (Environment, Graph)
impredicativeFixture = fixture binders [(providerName, provider)] [(nid 1, polyIdentity)] $
  Q.TermGraphSource (nid 0)
    [ (nid 0, node source $ intro 0 1 source)
    , (nid 1, node result $ Q.TypedImplicitTypeApplication (oid 1) (nid 2) $
        Q.ImplicitTypeApplicationWitness provider polyIdentity result)
    , (nid 2, node provider $ Q.TypedGlobal (oid 2) providerName)
    ]
 where
  binders = Map.fromList [(boundA, explicitType), (boundB, explicitType)]
  provider = T.ForallType [boundA] [] $ arrow (T.TypeVariable boundA) $ T.TypeVariable boundA
  result = arrow polyIdentity polyIdentity
  source = qualified [classC nat] result

polyIdentity :: Ty
polyIdentity = T.ForallType [boundB] [] $ arrow (T.TypeVariable boundB) $ T.TypeVariable boundB

fixture :: Map.Map Variable LeanBinder -> [(Name, Ty)] -> [(Q.TermNodeId, Ty)]
  -> Source -> (Environment, Graph)
fixture binders providers selections source =
  ( ContextRenderEnvironment
      { contextRenderClasses = Map.singleton className $
          LeanClassInfo (lean ["ContextFixture", "C"]) [0]
      , contextRenderNominals = Map.singleton natName $ LeanNominalInfo (lean ["Nat"]) 0
      , contextRenderProviders = Map.fromList
          [(name, LeanProviderInfo (lean ["ContextFixture", "observe"]) $ project binders ty)
          | (name, ty) <- providers]
      , contextRenderNodeTypes = Map.fromList
          [(key, project binders $ Q.termNodeType current) | (key, current) <- Q.termGraphSourceNodes source]
      , contextRenderSelectedTypes = Map.fromList [(key, project binders ty) | (key, ty) <- selections]
      , contextRenderUniverseParameters = Set.empty
      , contextRenderPremiseCounts = (0, 0)
      }
  , right $ Q.sealTermGraphWithContext Q.sharedContextTypeStructure structure Q.defaultTermGraphLimits source
  )

-- Test source declarations explicitly supply every forall binder's domain and
-- visibility. A missing fixture entry is a test construction error, not a
-- production default or metadata reconstruction rule.
project :: Map.Map Variable LeanBinder -> Ty -> LeanType Variable
project binders ty = case ty of
  T.TypeVariable variable -> LeanVariable variable
  T.TypeConstructor name -> LeanNominal name
  T.TypeApplication function argument -> LeanApplication (go function) (go argument)
  T.FunctionType domain result -> LeanArrow (go domain) (go result)
  T.TupleType boxity fields -> LeanTuple boxity $ map go fields
  T.ForallType variables constraints body -> LeanForall
    [(variable, required $ Map.lookup variable binders) | variable <- variables]
    (map (fmap go) constraints) (go body)
 where go = project binders

renderFixture :: (Environment, Graph) -> Either ContextRenderError ContextRenderedTerm
renderFixture (environment, graph) = renderLeanContextGraph environment graph

rendered :: (Environment, Graph) -> IO ContextRenderedTerm
rendered = either (fail . show) pure . renderFixture

noEvidenceHoles :: ContextRenderedTerm -> Assertion
noEvidenceHoles result = mapM_ absent ["inferInstance", "by assumption", "by exact?", " _", "[_", "sorry"]
 where
  absent forbidden = assertBool ("rendered implicit evidence substitute " ++ show forbidden) $
    not $ forbidden `isInfixOf` (contextRenderedType result ++ contextRenderedExpression result)

contains :: String -> String -> Assertion
contains expected actual = assertBool ("missing " ++ show expected ++ " in " ++ actual) $
  expected `isInfixOf` actual

right :: Show error => Either error value -> value
right = either (error . show) id

required :: Maybe value -> value
required = maybe (error "incomplete context renderer test fixture") id

lean :: [String] -> LeanName
lean = right . mkLeanName

structure :: Q.TypeStructure Ty
structure = Q.sharedTypeStructure { Q.forallTypeStructure = Just Q.sharedContextualForallTypeStructure }

explicitType, implicitType :: LeanBinder
explicitType = LeanBinder LeanExplicit $ LeanSortDomain $ LeanLevelSuccessor LeanLevelZero
implicitType = LeanBinder LeanImplicit $ LeanSortDomain $ LeanLevelSuccessor LeanLevelZero

boundA, boundB, rigidA, rigidB :: Variable
boundA = T.FlexibleVariable "a"
boundB = T.FlexibleVariable "b"
rigidA = T.RigidVariable "openedA"
rigidB = T.RigidVariable "openedB"

className, natName, providerName :: Name
className = right $ parseName "Private.Context"
natName = right $ parseName "Private.Natural"
providerName = right $ parseName "Private.provider"

nat :: Ty
nat = T.TypeConstructor natName

arrow :: Ty -> Ty -> Ty
arrow = T.FunctionType

qualified :: [Constraint Ty] -> Ty -> Ty
qualified = T.ForallType []

classC :: Ty -> Constraint Ty
classC ty = Constraint className [ty]

nid :: Natural -> Q.TermNodeId
nid = Q.termNodeId

oid :: Natural -> Q.OccurrenceId
oid = Q.occurrenceId

node :: Ty -> Q.TermNodeForm Ty Int -> Q.TermNode Ty Int
node = Q.TermNode

bind :: Natural -> Int -> Ty -> Q.TypedPattern Ty Int
bind occurrence local ty = Q.TypedPattern (oid occurrence) ty $ Q.TypedBind local

given :: Natural -> Natural -> Q.ContextEvidence
given occurrence = Q.givenContextEvidence $ oid occurrence

intro :: Natural -> Natural -> Ty -> Q.TermNodeForm Ty Int
intro occurrence child source = Q.TypedContextIntroduction (oid occurrence) (nid child) $
  required $ Q.contextIntroductionWitness Q.sharedContextTypeStructure source

discharge :: Natural -> Natural -> Ty -> [Q.ContextEvidence] -> Q.TermNodeForm Ty Int
discharge occurrence child source evidence = Q.TypedContextApplication (oid occurrence) (nid child) $
  required $ Q.contextApplicationWitness Q.sharedContextTypeStructure source evidence
