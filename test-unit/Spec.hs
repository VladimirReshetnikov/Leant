module Main (main) where

import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

import Language.Haskell.Djex
  ( Expression (Global, VisibleTypeApplication)
  , Type (..)
  , mkIdentifier
  , specifiedVisibleTypeArgument
  )

import Leant.Synth.Engine
  ( SynthEngine (..)
  , SynthOutcome (..)
  , synthesizeWithProviders
  )
import Leant.Synth.Fragment
  ( Frag (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , ProviderFrag (..)
  , ProviderQuery (..)
  , parseGoalSexp
  , parseProviderSexp
  )
import Leant.Synth.ProviderCache
  ( advanceProviderWorld
  , canonicalProviderQuery
  , emptyProviderCache
  , historyEntryAffectsProviders
  , initialProviderWorld
  , insertProviderCache
  , lookupProviderCache
  , providerCacheSize
  )
import Leant.Synth.Replay (ReplayPlan (..), planReplay)
import Leant.Synth.Render (renderLeanTerm)

main :: IO ()
main = defaultMain $ testGroup "Leant synthesis boundary"
  [ providerCacheTests
  , replayPlanTests
  , providerParserTests
  , providerEngineTests
  , rankNFrontierTests
  , visibleTypeApplicationTests
  ]

replayPlanTests :: TestTree
replayPlanTests = testGroup "synthesis history replay"
  [ testCase "reuse an exact cached history" $
      planReplay ["def a := 1"] ["def a := 1"] @?= Reuse
  , testCase "replay only an appended suffix" $
      planReplay
          ["def a := 1", "def b := a"]
          ["def a := 1", "def b := a", "def «it!1» := b"]
        @?= ReplaySuffix ["def «it!1» := b"]
  , testCase "rebuild after undo shortens the history" $
      planReplay ["def a := 1", "def b := a"] ["def a := 1"]
        @?= ReplayAll ["def a := 1"]
  , testCase "rebuild after an earlier entry is replaced" $
      planReplay ["def a := 1", "def b := a"]
          ["def a := 2", "def b := a"]
        @?= ReplayAll ["def a := 2", "def b := a"]
  , testCase "respect duplicates at the prefix boundary" $
      planReplay ["a", "b"] ["a", "b", "b", "c"]
        @?= ReplaySuffix ["b", "c"]
  ]

providerCacheTests :: TestTree
providerCacheTests = testGroup "semantic provider cache"
  [ testCase "canonicalize roots independently of traversal order" $
      canonicalProviderQuery
          [" List", "Prod", "List", "", "  Prod  "]
          (Just " List.map ")
        @?= ProviderQuery ["List", "Prod"] (Just "List.map")
  , testCase "remove generated results without erasing normal namespaces" $ do
      canonicalProviderQuery ["it!12", "List", "it!12"] (Just "it!7")
        @?= ProviderQuery ["List"] Nothing
      canonicalProviderQuery ["Foo"] (Just "Foo.it!7")
        @?= ProviderQuery ["Foo"] (Just "Foo.it!7")
  , testCase "parse and canonicalize provider metadata with a goal" $
      parseGoalSexp
          "(goal type (query (roots \"Prod\" \"List\" \"Prod\") \
          \(head \"List\")) (-> (var \"a\") (var \"a\")))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["List", "Prod"] (Just "List"))
          (FArr (FVar "a") (FVar "a")))
  , testCase "retain an explicitly headless provider query" $
      parseGoalSexp
          "(goal prop (query (roots) (head)) (var \"p\"))"
        @?= Right (ParsedGoal GoalProp
          (ProviderQuery [] Nothing) (FVar "p"))
  , testCase "refresh hits and evict the least-recently used entry" $ do
      let world = initialProviderWorld
          query n = ProviderQuery [n] (Just n)
          cache0 = emptyProviderCache 2
          cache1 = insertProviderCache world (query "A") "a" cache0
          cache2 = insertProviderCache world (query "B") "b" cache1
          (hitA, refreshed) =
            lookupProviderCache world (query "A") cache2
          cache3 = insertProviderCache world (query "C") "c" refreshed
          (missB, afterMiss) =
            lookupProviderCache world (query "B") cache3
          (hitAAgain, _) =
            lookupProviderCache world (query "A") afterMiss
      hitA @?= Just "a"
      missB @?= Nothing
      hitAAgain @?= Just "a"
      providerCacheSize cache3 @?= 2
  , testCase "isolate identical queries across provider generations" $ do
      let oldWorld = initialProviderWorld
          newWorld = advanceProviderWorld oldWorld
          query = ProviderQuery ["List"] (Just "List")
          cache = insertProviderCache oldWorld query ([] :: [Int])
            (emptyProviderCache 12)
          (oldHit, cache') = lookupProviderCache oldWorld query cache
          (newMiss, _) = lookupProviderCache newWorld query cache'
      oldHit @?= Just []
      newMiss @?= Nothing
  , testCase "preserve inventories only across generated result bindings" $ do
      map historyEntryAffectsProviders
          [ "def «it!1» := (3)"
          , "set_option autoImplicit true in def «it!2» : Nat := (3)"
          , "set_option autoImplicit true in noncomputable def «it!3» \
            \: Classical.choice _ := (Classical.choice _)"
          ]
        @?= [False, False, False]
      historyEntryAffectsProviders "def userValue : Nat := 3" @?= True
      historyEntryAffectsProviders "set_option pp.universes true" @?= True
  ]

providerParserTests :: TestTree
providerParserTests = testGroup "provider inventory parser"
  [ testCase "retains exact Lean names and structural types" $ do
      parseProviderSexp
          "(providers (provider \"Demo.toBool\" (-> (atom unsafe \"Nat\") \
          \(ind \"Bool\" (ctor \"Bool.false\") (ctor \"Bool.true\")))))"
        @?= Right
          [ ProviderFrag "Demo.toBool"
              (FArr
                (FAtom False "Nat")
                (FInd "Bool" [("Bool.false", []), ("Bool.true", [])]))
          ]
  , testCase "retains recursive inventory status and applied parameters" $ do
      parseProviderSexp
          "(providers (provider \"Demo.step\" (rec partial \"Demo.Phantom α\" \
          \(params (var \"α\")) (ctor \"Demo.Phantom.base\") \
          \(ctor \"Demo.Phantom.next\" \
          \(atom unsafe \"Demo.Phantom α\")))))"
        @?= Right
          [ ProviderFrag "Demo.step"
              (FRec False "Demo.Phantom α" [FVar "α"]
                [ ("Demo.Phantom.base", [])
                , ("Demo.Phantom.next",
                    [FAtom False "Demo.Phantom α"])
                ])
          ]
  , testCase "accepts an empty bounded inventory" $
      parseProviderSexp "(providers)" @?= Right []
  , testCase "rejects trailing inventory data" $
      parseProviderSexp "(providers) extra" @?=
        Left "trailing tokens in provider translation"
  ]

providerEngineTests :: TestTree
providerEngineTests = testGroup "foreign providers"
  [ testCase "render an exact qualified provider through Exference" $ do
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          provider = ProviderFrag "Demo.toBool" (FArr natural boolean)
      firstGroup
          (synthesizeWithProviders EngineExference 256 [provider]
            (FArr natural boolean))
        @?= ["Demo.toBool"]
  , testCase "open an otherwise atomic goal with a provider" $ do
      let natural = FAtom False "Nat"
          provider = ProviderFrag "Demo.zero" natural
      firstGroup
          (synthesizeWithProviders EngineExference 128 [provider] natural)
        @?= ["Demo.zero"]
  , testCase "drop a depth-limited provider without losing later values" $ do
      let natural = FAtom False "Nat"
          providers =
            [ ProviderFrag "Demo.tooDeep" FDepth
            , ProviderFrag "Demo.zero" natural
            ]
      firstGroup
          (synthesizeWithProviders EngineExference 128 providers natural)
        @?= ["Demo.zero"]
  , testCase "keep foreign providers out of deciding Djinn search" $ do
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          provider = ProviderFrag "Demo.toBool" (FArr natural boolean)
      case synthesizeWithProviders EngineDjinn 256 [provider]
          (FArr natural boolean) of
        Right (SynthCandidates groups _) ->
          if any (elem "Demo.toBool") groups
            then assertFailure "Djinn used an Exference-only provider"
            else pure ()
        Right _ -> pure ()
        Left err -> assertFailure err
  , testCase "eliminate one layer of a recursive Nat" $ do
      let result = FVar "r"
          natural = FRec True "Nat" []
            [ ("Nat.zero", [])
            , ("Nat.succ", [FAtom False "Nat"])
            ]
          goal = FArr result
            (FArr (FArr natural result) (FArr natural result))
      firstGroup
          (synthesizeWithProviders EngineExference 1024 [] goal)
        @?=
          [ "fun x f y => match y with | .zero => x | .succ z => f z"
          , "fun x f y => match y with | Nat.zero => x | Nat.succ z => f z"
          ]
  , testCase "keep partial recursive inventories introduction-only" $ do
      let element = FVar "a"
          partial = FRec False "Demo.Partial a" [element]
            [("Demo.Partial.some", [element])]
      case synthesizeWithProviders EngineExference 512 []
          (FArr partial element) of
        Right (SynthNoTerm _) -> pure ()
        Right (SynthCandidates groups _) -> assertFailure $
          "partial inventory was structurally eliminated: " ++ show groups
        Right other -> assertFailure $
          "unexpected partial-inventory outcome: " ++ outcomeTag other
        Left err -> assertFailure err
      let introductions = firstGroup
            (synthesizeWithProviders EngineExference 512 []
              (FArr element partial))
      if any ("Demo.Partial.some" `isInfixOf`) introductions
        then pure ()
        else assertFailure $
          "expected constructor introduction, got: " ++ show introductions
  , testCase "reuse List.map across recursive families with renamed binders" $ do
      let alpha = FVar "α"
          beta = FVar "β"
          source = FVar "s0"
          target = FVar "s1"
          list key element = FRec True key [element]
            [ ("List.nil", [])
            , ("List.cons", [element, FAtom False key])
            ]
          goal = FArr (FArr alpha beta)
            (FArr (list "List α" alpha) (list "List β" beta))
          provider = ProviderFrag "List.map"
            (FAll False "s0" (FAll False "s1"
              (FArr (FArr source target)
                (FArr (list "List s0" source) (list "List s1" target)))))
          candidates = firstGroup
            (synthesizeWithProviders EngineExference 512 [provider] goal)
      if any ("List.map" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "expected a List.map candidate, got: " ++ show candidates
  , testCase "reuse providers across phantom parameters with renamed binders" $ do
      let alpha = FVar "α"
          beta = FVar "β"
          source = FVar "s0"
          target = FVar "s1"
          phantom key parameter = FRec True key [parameter]
            [ ("Demo.Phantom.base", [])
            , ("Demo.Phantom.next", [FAtom False key])
            ]
          goal = FArr
            (phantom "Demo.Phantom α" alpha)
            (phantom "Demo.Phantom β" beta)
          provider = ProviderFrag "Demo.Phantom.cast"
            (FAll False "s0" (FAll False "s1"
              (FArr
                (phantom "Demo.Phantom s0" source)
                (phantom "Demo.Phantom s1" target))))
          candidates = firstGroup
            (synthesizeWithProviders EngineExference 512 [provider] goal)
      if any ("Demo.Phantom.cast" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "expected a phantom-parameter provider, got: " ++ show candidates
  ]

rankNFrontierTests :: TestTree
rankNFrontierTests = testGroup "Djinn rank-N frontiers"
  [ testCase "render a balanced four-site pairwise plan for Lean" $ do
      let variable = FVar
          product4 a b c d = FProd a (FProd b (FProd c d))
          forall4 a b c d body =
            FAll True a (FAll True b (FAll True c (FAll True d body)))
          wide a b c d = forall4 a b c d
            (product4 (variable a) (variable b) (variable c) (variable d))
          consumer codomain a b c d = forall4 a b c d
            (FArr
              (product4 (variable a) (variable b) (variable c) (variable d))
              codomain)
          identity a = FAll True a (FArr (variable a) (variable a))
          result = variable "q"
          goal = FArr
            (wide "a" "b" "c" "d")
            (FArr
              (consumer result "s" "t" "u" "v")
              (FProd
                (wide "w" "x" "y" "z")
                (FProd
                  (consumer result "i" "j" "k" "l")
                  (FProd (identity "e") (identity "f")))))
          candidates = firstGroup
            (synthesizeWithProviders EngineDjinn 0 [] goal)
      if any (\candidate ->
          "fun " `isInfixOf` candidate
            && "\10216" `isInfixOf` candidate
            && "fun _" `isInfixOf` candidate) candidates
        then pure ()
        else assertFailure $
          "expected a rendered pairwise rank-N candidate, got: "
            ++ show candidates
  ]

visibleTypeApplicationTests :: TestTree
visibleTypeApplicationTests = testGroup "Lean visible type applications"
  [ testCase "activate implicit provider arguments with Lean @ syntax" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      integerName <- expectRight $ mkIdentifier "Int"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor integerName :: Type String)
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0" "Demo.identity")
          [] (FAtom False "Nat") expression
        @?= Right ["@Demo.identity Int"]
  , testCase "render compound closed type arguments in Lean syntax" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      maybeName <- expectRight $ mkIdentifier "Maybe"
      integerName <- expectRight $ mkIdentifier "Int"
      booleanName <- expectRight $ mkIdentifier "Bool"
      let compound = TypeApplication (TypeConstructor maybeName)
            (FunctionType
              (TypeConstructor integerName)
              (TypeConstructor booleanName)) :: Type String
      argument <- expectRight $ specifiedVisibleTypeArgument compound
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0" "Demo.identity")
          [] (FAtom False "Nat") expression
        @?= Right ["@Demo.identity (Option (Int → Bool))"]
  ]

firstGroup :: Either String SynthOutcome -> AssertionResult
firstGroup outcome = case outcome of
  Right (SynthCandidates (group : _) _) -> group
  Right (SynthCandidates [] notes) ->
    error $ "no provider candidate: " ++ show notes
  Right other -> error $ "unexpected synthesis outcome: " ++ outcomeTag other
  Left err -> error err

type AssertionResult = [String]

outcomeTag :: SynthOutcome -> String
outcomeTag outcome = case outcome of
  SynthCandidates _ _ -> "candidates"
  SynthRefuted sound -> "refuted (sound=" ++ show sound ++ ")"
  SynthNoTerm notes -> "no term " ++ show notes

expectRight :: Show error => Either error value -> IO value
expectRight result = case result of
  Right value -> pure value
  Left err -> assertFailure (show err) >> error "unreachable"
