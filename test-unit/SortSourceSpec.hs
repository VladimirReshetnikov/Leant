module SortSourceSpec (tests) where

import Control.Monad (forM_)
import Data.Either (isLeft)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Language.Haskell.Synthesis.Generated (Expression (..), Pattern (..))
import Language.Haskell.Synthesis.Name (mkIdentifier)
import Leant.Synth.ContextRender
import Leant.Synth.Engine
import Leant.Synth.Fragment
import Leant.Synth.Render
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

tests :: TestTree
tests = testGroup "source sort values"
  [ testCase "parse exact sort levels separately from opaque spellings" $ do
      parsed <- either fail pure $ parseGoalSexp "(goal type (query (roots) (head)) (sort (succ zero)))"
      pgFrag parsed @?= FSort (LeanLevelSuccessor LeanLevelZero)
      assertBool "a sort acquired opaque spelling identity" $
        pgFrag parsed /= FAtom False "Type"
      parameter <- either (fail . show) pure $ mkLeanName ["u"]
      named <- either fail pure $ parseGoalSexp "(goal type (query (roots) (head)) (sort (max (param \"u\") (succ zero))))"
      pgFrag named @?= FSort (LeanLevelMax (LeanLevelParameter parameter) (LeanLevelSuccessor LeanLevelZero))
  , testCase "reject malformed and excessive source universes" $
      forM_ ["(param \"bad.name\")", "(succ)", "(max zero)", "(mvar \"u\")", concat (replicate 130 "(succ ") ++ "zero" ++ replicate 130 ')'] $ \level ->
        assertBool ("accepted malformed universe " ++ level) $
          isLeft $ parseGoalSexp $ "(goal type (query (roots) (head)) (sort " ++ level ++ "))"
  , testCase "introduce sort values through either engine" $
      forM_ [EngineDjinn, EngineExference] $ \engine ->
        forM_ [LeanLevelZero, LeanLevelSuccessor LeanLevelZero] $ \level -> do
          result <- either fail pure $ synthesize engine 4096 $ FSort level
          case result of
            SynthCandidates groups _ -> assertBool "missing source-owned PUnit type witness" $
              any (isInfixOf "_root_.PUnit.{") $ concat groups
            other -> fail $ "sort introduction failed: " ++ show other
  , testCase "a sort witness cannot inhabit an opaque lookalike" $ do
      result <- either fail pure $ synthesize EngineDjinn 4096 $
        FArr (FSort $ LeanLevelSuccessor LeanLevelZero) (FAtom False "Type")
      case result of
        SynthCandidates groups _ -> assertBool "sort and opaque atom identities were conflated" $ null groups
        _ -> pure ()
  , testCase "a universe witness grants no datatype elimination or refutation" $ do
      result <- either fail pure $ synthesize EngineDjinn 4096 $
        FArr (FSort $ LeanLevelSuccessor LeanLevelZero) FBot
      case result of
        SynthCandidates groups _ -> assertBool "fabricated universe elimination" $ null groups
        SynthRefuted True -> fail "opaque sort search claimed a complete refutation"
        _ -> pure ()
  , testCase "supply a closed sort value needed only by a provider" $
      forM_ [EngineDjinn, EngineExference] $ \engine -> do
        let target = FAtom False "Demo.Result"
            provider = ProviderFrag "Demo.consumeType" $
              FArr (FSort $ LeanLevelSuccessor LeanLevelZero) target
        result <- either fail pure $ synthesizeWithProviders engine 4096 [provider] target
        case result of
          SynthCandidates groups _ -> assertBool "provider-only sort argument lacks its canonical witness" $
            any (\term -> "Demo.consumeType" `isInfixOf` term && "_root_.PUnit.{" `isInfixOf` term) $ concat groups
          other -> fail $ "provider-only sort introduction failed for " ++ show engine
            ++ ": " ++ show other ++ "\nPreparation: "
            ++ show (inspectExferencePreparation [provider] [] target target)
  , testCase "restore eta-contracted outer and inner premise arguments without capture" $ do
      private <- either (fail . show) pure $ mkIdentifier "provider"
      let token = FAtom False "Demo.Token"
          sort = FSort $ LeanLevelSuccessor LeanLevelZero
          witness = ("_root_.PUnit.{(0 + 1)}", sort)
          seed = ("Demo.seed", token)
          global = Global private
          render shape goal scheme = renderLeanTerm Map.empty
            (Map.singleton "provider" $ providerInfo "Demo.consume" Nothing scheme)
            Map.empty shape goal
          equivalent shape goal scheme short long = do
            actual <- either fail pure $ render shape goal scheme short
            expected <- either fail pure $ render shape goal scheme long
            assertBool "empty premise rendering" $ not $ null actual
            actual @?= expected
      equivalent ([witness], 0, []) token (FArr sort token)
        global (Lambda [Bind "s"] $ Apply global $ Local "s")
      equivalent ([], 1, [seed]) (FArr token token) (FArr token $ FArr token token)
        global (Lambda [Bind "x", Bind "s"] $ Apply (Apply global $ Local "x") $ Local "s")
      equivalent ([witness], 1, [seed]) (FArr token token)
        (FArr sort $ FArr token $ FArr token token)
        global (Lambda [Bind "u", Bind "x", Bind "s"] $
          Apply (Apply (Apply global $ Local "u") $ Local "x") $ Local "s")
      equivalent ([], 1, [seed]) (FArr token token) (FArr token $ FArr token token)
        (Lambda [Bind "$premise0"] $ Apply global $ Local "$premise0")
        (Lambda [Bind "$premise0", Bind "s"] $ Apply (Apply global $ Local "$premise0") $ Local "s")
  ]
