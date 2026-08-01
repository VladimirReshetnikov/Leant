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
  , ProviderFrag (..)
  , parseProviderSexp
  )
import Leant.Synth.Render (renderLeanTerm)

main :: IO ()
main = defaultMain $ testGroup "Leant synthesis boundary"
  [ providerParserTests
  , providerEngineTests
  , visibleTypeApplicationTests
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
