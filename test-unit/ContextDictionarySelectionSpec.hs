-- Source-evidence recovery after type selection and dictionary discharge.
module ContextDictionarySelectionSpec (tests) where

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
import Test.Tasty.HUnit ((@?=), testCase)

tests :: TestTree
tests = testGroup "Polymorphic selection through dictionary application"
  [ testCase "expected result crosses the dictionary application" $ do
      _ <- right $ fixture True typeOne
      pure ()
  , testCase "actual argument evidence crosses the dictionary application" $ do
      _ <- right $ fixture False typeOne
      pure ()
  , testCase "recovered evidence still enforces the selected universe" $
      fixture False typeZero @?= Left (ContextProjectionCandidateRejected $
        ContextSelectedUniverseMismatch zero (LeanLevelSuccessor zero))
  ]

-- The given belongs to the outer context introduction. The graph applies it
-- after the polymorphic type selection and before the payload application:
-- consumeWithGate @P [given] payload. Graph sealing checks this exact ordering
-- and dictionary ownership independently of the source-metadata projector.
fixture :: Bool -> LeanLevel -> Either ContextProjectionFailure [String]
fixture boxed providerDomain = do
  selected <- prep $ selectContextUniverses
    (ContextUniverseSignature [] [typeOne] typeOne) []
  let nominal = ContextNominalExact ["Box"] selected
      natSource = ContextNominal ["Nat"] 0 []
      polySource = ContextForall ContextExplicit "b" $
        ContextArrow (ContextVariable "b") natSource
      outputSource = if boxed then nominal [polySource] else natSource
      source = ContextGiven ["Gate"] 0 [] $ ContextArrow polySource outputSource
      providerSource = ContextForallAt ContextImplicit "a" providerDomain $
        ContextGiven ["Gate"] 0 [] $ ContextArrow (ContextVariable "a") $
          if boxed then nominal [ContextVariable "a"] else natSource
      classes = Map.singleton "Gate" (gateName, [])
      nominals = Map.fromList [("Box", (boxName, 1)), ("Nat", (natName, 0))]
      p = T.ForallType ["b"] [] $ T.FunctionType (T.TypeVariable "b") nat
      result = if boxed then T.TypeApplication (T.TypeConstructor boxName) p else nat
      body = T.FunctionType p result
      root = T.ForallType [] [Constraint gateName []] body
      providerTy = T.ForallType ["a"] [Constraint gateName []] $
        T.FunctionType (T.TypeVariable "a") $
          if boxed then T.TypeApplication (T.TypeConstructor boxName) (T.TypeVariable "a") else nat
      selectedTy = T.ForallType [] [Constraint gateName []] body
      graphTy = fmap T.FlexibleVariable
      pattern' = Q.TypedPattern (oid 1) (graphTy p) $ Q.TypedBind (0 :: Int)
      graphSource = Q.TermGraphSource (nid 0)
        [ (nid 0, Q.TermNode (graphTy root) $ Q.TypedContextIntroduction (oid 0) (nid 1) $
            require $ Q.contextIntroductionWitness Q.sharedContextTypeStructure $ graphTy root)
        , (nid 1, Q.TermNode (graphTy body) $ Q.TypedLambda [pattern'] (nid 2))
        , (nid 2, Q.TermNode (graphTy result) $ Q.TypedApply (nid 3) (nid 5) $
            Q.ApplicationWitness (graphTy p) (graphTy result))
        , (nid 3, Q.TermNode (graphTy body) $ Q.TypedContextApplication (oid 3) (nid 6) $
            require $ Q.contextApplicationWitness Q.sharedContextTypeStructure (graphTy selectedTy)
              [Q.givenContextEvidence (oid 0) 0])
        , (nid 4, Q.TermNode (graphTy providerTy) $ Q.TypedGlobal (oid 4) providerName)
        , (nid 5, Q.TermNode (graphTy p) $ Q.TypedLocal (oid 5) 0)
        , (nid 6, Q.TermNode (graphTy selectedTy) $ Q.TypedImplicitTypeApplication (oid 6) (nid 4) $
            Q.ImplicitTypeApplicationWitness (graphTy providerTy) (graphTy p) (graphTy selectedTy))
        ]
      structure = Q.sharedTypeStructure { Q.forallTypeStructure = Just Q.sharedContextualForallTypeStructure }
  packet <- prep $ mkContextSource source
  provider <- prep $ mkContextProviderSource providerSource
  prepared <- prep $ prepareContextSource classes nominals root packet
  withProvider <- prep $ prepareContextSourceProviders classes nominals
    [(providerName, ["consumeWithGate"], providerTy, provider)] prepared
  graph <- either (Left . ContextProjectionIntegrityFailure . show) Right $
    Q.sealTermGraphWithContext Q.sharedContextTypeStructure structure Q.defaultTermGraphLimits graphSource
  checkPreparedContextGraph withProvider graph
 where
  prep = either (Left . ContextProjectionIntegrityFailure) Right

right :: Show failure => Either failure value -> IO value
right = either (fail . show) pure

require :: Maybe value -> value
require = maybe (error "invalid independent dictionary-selection graph fixture") id

zero, typeZero, typeOne :: LeanLevel
zero = LeanLevelZero
typeZero = LeanLevelSuccessor zero
typeOne = LeanLevelSuccessor typeZero

gateName, boxName, natName, providerName :: Name
gateName = name "Private.Gate"
boxName = name "Private.Box"
natName = name "Private.Nat"
providerName = name "privateQualifiedProvider"

name :: String -> Name
name = either (error . show) id . parseName

nat :: T.Type String
nat = T.TypeConstructor natName

nid :: Natural -> Q.TermNodeId
nid = Q.termNodeId

oid :: Natural -> Q.OccurrenceId
oid = Q.occurrenceId
