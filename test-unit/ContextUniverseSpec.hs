module ContextUniverseSpec (tests) where

import Data.Either (isLeft)
import qualified Data.Set as Set
import Leant.Synth.ContextRender (LeanLevel (..), mkLeanName)
import Leant.Synth.ContextSource
import Leant.Synth.ContextUniverse
import Leant.Synth.Fragment (contextSourceFragment)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

tests :: TestTree
tests = testGroup "Contextual declaration universe selections"
  [ testCase "declaration parameters do not capture equally named caller levels" $ do
      u <- right $ mkLeanName ["u"]
      v <- right $ mkLeanName ["v"]
      selected <- right $ selectContextUniverses
        (ContextUniverseSignature [u] [succLevel $ LeanLevelParameter u] (succLevel $ LeanLevelParameter u))
        [LeanLevelParameter v]
      selectionArgumentSorts selected @?= [succLevel $ LeanLevelParameter v]
      selectionResultSort selected @?= succLevel (LeanLevelParameter v)
      universeParameters (selectionResultSort selected) @?= Set.singleton v
  , testCase "renaming declaration parameters preserves its canonical signature" $ do
      u <- right $ mkLeanName ["u"]
      v <- right $ mkLeanName ["v"]
      a <- right $ selectContextUniverses
        (ContextUniverseSignature [u] [succLevel $ LeanLevelParameter u] (succLevel $ LeanLevelParameter u)) [zero]
      b <- right $ selectContextUniverses
        (ContextUniverseSignature [v] [succLevel $ LeanLevelParameter v] (succLevel $ LeanLevelParameter v)) [zero]
      a @?= b
  , testCase "equivalent maximum selections share an identity; unequal selections do not" $ do
      u <- right $ mkLeanName ["u"]
      let signature = ContextUniverseSignature [u] [succLevel $ LeanLevelParameter u] (succLevel $ LeanLevelParameter u)
      a <- right $ selectContextUniverses signature [LeanLevelParameter u]
      b <- right $ selectContextUniverses signature [LeanLevelMax (LeanLevelParameter u) zero]
      c <- right $ selectContextUniverses signature [succLevel $ LeanLevelParameter u]
      selectionIdentity "Box" a @?= selectionIdentity "Box" b
      assertBool "distinct selections collided" $ selectionIdentity "Box" a /= selectionIdentity "Box" c
  , testCase "malformed template scope and selected arity are rejected" $ do
      u <- right $ mkLeanName ["u"]
      let check signature levels = assertBool "malformed signature accepted" $
            isLeft $ selectContextUniverses signature levels
      check (ContextUniverseSignature [u,u] [] typeZero) [zero,zero]
      check (ContextUniverseSignature [] [LeanLevelParameter u] typeZero) []
      check (ContextUniverseSignature [u] [] typeZero) []
      check (ContextUniverseSignature [] (replicate 65 typeZero) typeZero) []
  , testCase "higher-universe nominal payloads enter the exact source fragment" $ do
      selected <- right $ selectContextUniverses (ContextUniverseSignature [] [typeOne] typeOne) []
      let variable = ContextVariable "b"
          box = ContextNominalExact ["Box"] selected [variable]
          source = context $ ContextForallAt ContextExplicit "b" typeOne $ ContextArrow variable box
      packet <- right $ mkContextSource source
      contextSourceType packet @?= source
      assertBool "higher nominal fragment collapsed to its payload" $
        contextSourceFragment packet /= contextSourceFragment (either error id $ mkContextSource $
          context $ ContextForallAt ContextExplicit "b" typeOne $ ContextArrow variable variable)
  , testCase "nominal parameter universes remain exact" $ do
      selected <- right $ selectContextUniverses (ContextUniverseSignature [] [typeOne] typeOne) []
      assertBool "Type-0 payload entered a Type-1 parameter" $ isLeft $ mkContextSource $
        context $ ContextNominalExact ["Box"] selected [ContextVariable "a"]
  , testCase "two universe selections retain separate source identities" $ do
      u <- right $ mkLeanName ["u"]
      let signature = ContextUniverseSignature [u] [] (succLevel $ LeanLevelParameter u)
      low <- right $ selectContextUniverses signature [zero]
      high <- right $ selectContextUniverses signature [succLevel zero]
      packet <- right $ mkContextSource $ context $ ContextArrow
        (ContextNominalExact ["Token"] low []) (ContextNominalExact ["Token"] high [])
      assertBool "selected identities collided" $
        contextNominalIdentity ["Token"] low /= contextNominalIdentity ["Token"] high
      contextSourceHasGiven (contextSourceType packet) @?= True
  , testCase "different selections cannot donate conflicting declaration templates" $ do
      u <- right $ mkLeanName ["u"]
      low <- right $ selectContextUniverses (ContextUniverseSignature [u] [] typeZero) [zero]
      high <- right $ selectContextUniverses (ContextUniverseSignature [u] [] typeOne) [succLevel zero]
      assertBool "conflicting templates accepted" $ isLeft $ mkContextSource $ context $ ContextArrow
        (ContextNominalExact ["Token"] low []) (ContextNominalExact ["Token"] high [])
  , testCase "a class cannot become a nominal at another universe selection" $ do
      u <- right $ mkLeanName ["u"]
      selected <- right $ selectContextUniverses (ContextUniverseSignature [u] [typeZero] typeOne) [succLevel zero]
      assertBool "universe suffix bypassed class ownership" $ isLeft $ mkContextSource $
        ContextForall ContextExplicit "a" $ ContextArrow
          (ContextNominalExact ["Dictionary"] selected [ContextVariable "a"])
          (ContextGiven ["Dictionary"] 1 [ContextVariable "a"] $ ContextVariable "a")
  ]
 where
  right :: Show failure => Either failure value -> IO value
  right = either (fail . show) pure
  zero = LeanLevelZero
  succLevel = LeanLevelSuccessor
  typeZero = succLevel zero
  typeOne = succLevel typeZero
  context body = ContextForall ContextExplicit "a" $
    ContextGiven ["Dictionary"] 1 [ContextVariable "a"] body
