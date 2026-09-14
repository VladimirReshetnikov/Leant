module ContextSelectionSpec (tests) where

import Data.Either (isLeft)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Language.Haskell.Synthesis.Constraint (Constraint (..))
import Language.Haskell.Synthesis.Name (Name, parseName)
import qualified Language.Haskell.Synthesis.Type as T
import qualified Language.Haskell.Synthesis.TypedGenerated as Q
import Leant.Synth.ContextRender (LeanLevel (..))
import Leant.Synth.ContextSource
import Leant.Synth.ContextUniverse
import Numeric.Natural (Natural)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

tests :: TestTree
tests = testGroup "Source anchored polymorphic selection"
  [ testCase "boxed payload selection follows its expected result" $ do
      terms <- right $ fixture True True ContextExplicit ContextExplicit typeOne
      assertBool "box constructor was lost" $ any ("«Box».«mk»" `isInfixOf`) terms
  , testCase "strict implicit selected binders keep their source visibility" $ do
      terms <- right $ fixture True True ContextStrictImplicit ContextStrictImplicit typeOne
      assertBool "selected strict binder became explicit" $ any ("⦃" `isInfixOf`) terms
  , testCase "expected function type supplies evidence without an argument node" $ do
      _ <- right $ fixture True False ContextExplicit ContextExplicit typeOne
      pure ()
  , testCase "argument supplies evidence when selection is absent from the result" $ do
      _ <- right $ fixture False True ContextExplicit ContextExplicit typeOne
      pure ()
  , testCase "a quantified type cannot enter a Type zero binder" $
      fixture False True ContextExplicit ContextExplicit typeZero @?=
        Left (ContextProjectionCandidateRejected $ ContextSelectedUniverseMismatch zero $ LeanLevelSuccessor zero)
  , testCase "same erasure cannot donate different binder visibility" $
      assertBool "conflicting source visibility was accepted" $ isLeft $
        fixture True True ContextExplicit ContextStrictImplicit typeOne
  , testCase "a polymorphic first selection survives a later type application" $ do
      _ <- right $ fixtureWithChain True True True ContextExplicit ContextExplicit typeOne
      pure ()
  , testCase "a complete type application spine uses the expected function type" $ do
      _ <- right $ fixtureWithChain True True False ContextExplicit ContextExplicit typeOne
      pure ()
  ]

-- A sealed System-F graph of Box.mk @P payload (or consume @P payload).
-- The graph's type erases binder domains/visibility; the independently prepared
-- goal and provider packets must supply those facts. No search ranking or
-- renderer-injected metadata participates in these projection tests.
fixture :: Bool -> Bool -> ContextSourceVisibility -> ContextSourceVisibility -> LeanLevel
  -> Either ContextProjectionFailure [String]
fixture = fixtureWithChain False

fixtureWithChain :: Bool -> Bool -> Bool -> ContextSourceVisibility -> ContextSourceVisibility -> LeanLevel
  -> Either ContextProjectionFailure [String]
fixtureWithChain chained boxed applied inputVisibility outputVisibility providerDomain = do
  selected <- prep $ selectContextUniverses (ContextUniverseSignature [] [typeOne] typeOne) []
  let nominal = ContextNominalExact ["Box"] selected
      natSource = ContextNominal ["Nat"] 0 []
      polySource visibility = ContextForall visibility "b" $ ContextArrow (ContextVariable "b") natSource
      outputSource = if boxed then nominal [polySource outputVisibility] else natSource
      source = ContextGiven ["Gate"] 0 [] $ ContextArrow (polySource inputVisibility) outputSource
      providerSource = ContextForallAt ContextImplicit "a" providerDomain $ extraSourceBinder $
        ContextArrow (ContextVariable "a") $ if boxed then nominal [ContextVariable "a"] else natSource
      extraSourceBinder = if chained then ContextForall ContextImplicit "extra" else id
      classes = Map.singleton "Gate" (gateName, [])
      nominals = Map.fromList [("Box", (boxName,1)), ("Nat", (natName,0))]
      p = T.ForallType ["b"] [] $ T.FunctionType (T.TypeVariable "b") nat
      result = if boxed then T.TypeApplication (T.TypeConstructor boxName) p else nat
      body = T.FunctionType p result
      root = T.ForallType [] [Constraint gateName []] body
      providerTy = T.ForallType (["a"] ++ ["extra" | chained]) [] $ T.FunctionType (T.TypeVariable "a") $
        if boxed then T.TypeApplication (T.TypeConstructor boxName) (T.TypeVariable "a") else nat
      partialTy = T.ForallType ["extra"] [] body
      graphTy = fmap T.FlexibleVariable
      pattern' = Q.TypedPattern (oid 1) (graphTy p) $ Q.TypedBind (0 :: Int)
      typeApplication = if chained
        then Q.TypedImplicitTypeApplication (oid 3) (nid 6) $
          Q.ImplicitTypeApplicationWitness (graphTy partialTy) (graphTy nat) (graphTy body)
        else Q.TypedImplicitTypeApplication (oid 3) (nid 4) $
          Q.ImplicitTypeApplicationWitness (graphTy providerTy) (graphTy p) (graphTy body)
      graphSource = Q.TermGraphSource (nid 0) $
        [ (nid 0, Q.TermNode (graphTy root) $ Q.TypedContextIntroduction (oid 0) (nid 1) $
            require $ Q.contextIntroductionWitness Q.sharedContextTypeStructure $ graphTy root) ] ++
        (if applied then
          [ (nid 1, Q.TermNode (graphTy body) $ Q.TypedLambda [pattern'] (nid 2))
          , (nid 2, Q.TermNode (graphTy result) $ Q.TypedApply (nid 3) (nid 5) $
              Q.ApplicationWitness (graphTy p) (graphTy result))
          , (nid 3, Q.TermNode (graphTy body) typeApplication)
          , (nid 5, Q.TermNode (graphTy p) $ Q.TypedLocal (oid 5) 0)
          ]
         else [(nid 1, Q.TermNode (graphTy body) typeApplication)]) ++
        [(nid 4, Q.TermNode (graphTy providerTy) $ Q.TypedGlobal (oid 4) providerName)] ++
        [ (nid 6, Q.TermNode (graphTy partialTy) $ Q.TypedImplicitTypeApplication (oid 6) (nid 4) $
            Q.ImplicitTypeApplicationWitness (graphTy providerTy) (graphTy p) (graphTy partialTy))
        | chained ]
      structure = Q.sharedTypeStructure { Q.forallTypeStructure = Just Q.sharedContextualForallTypeStructure }
  packet <- prep $ mkContextSource source
  provider <- prep $ mkContextProviderSource providerSource
  prepared <- prep $ prepareContextSource classes nominals root packet
  withProvider <- prep $ prepareContextSourceProviders classes nominals
    [(providerName, if boxed then ["Box","mk"] else ["consume"], providerTy, provider)] prepared
  graph <- either (Left . ContextProjectionIntegrityFailure . show) Right $
    Q.sealTermGraphWithContext Q.sharedContextTypeStructure structure Q.defaultTermGraphLimits graphSource
  checkPreparedContextGraph withProvider graph
 where
  prep = either (Left . ContextProjectionIntegrityFailure) Right

right :: Show failure => Either failure value -> IO value
right = either (fail . show) pure

require :: Maybe value -> value
require = maybe (error "invalid independent graph fixture") id

zero, typeZero, typeOne :: LeanLevel
zero = LeanLevelZero
typeZero = LeanLevelSuccessor zero
typeOne = LeanLevelSuccessor typeZero

gateName, boxName, natName, providerName :: Name
gateName = name "Private.Gate"
boxName = name "Private.Box"
natName = name "Private.Nat"
providerName = name "privateConstructor"

name :: String -> Name
name = either (error . show) id . parseName

nat :: T.Type String
nat = T.TypeConstructor natName

nid :: Natural -> Q.TermNodeId
nid = Q.termNodeId

oid :: Natural -> Q.OccurrenceId
oid = Q.occurrenceId
