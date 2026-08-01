module Main (main) where

import Control.Exception (finally)
import qualified Data.ByteString.Char8 as BS
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import System.Directory (getTemporaryDirectory, removeFile)
import System.FilePath ((</>), normalise)
import System.IO (hClose, openBinaryTempFile)
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
  , synthesizeWith
  , synthesizeWithProviders
  )
import Leant.Synth.Fragment
  ( AppHead (..)
  , Frag (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , ProviderFrag (..)
  , ProviderQuery (..)
  , candidateVerificationProgram
  , fragHasDepth
  , fragProviderMayOpen
  , fragRefusal
  , fragUnsafeAtoms
  , glivenkoSplit
  , parseGoalSexp
  , parseProviderSexp
  , providerProgram
  , propAtoms
  , synthPrelude
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
import Leant.Session.Replay (itCounterAfterHistory, replayHistoryWith)
import Leant.Session.Snapshot
  ( SnapshotCompanion (..)
  , SnapshotFingerprint (..)
  , SnapshotMetadata (..)
  , decodeSnapshotMetadata
  , encodeSnapshotMetadata
  , fingerprintSnapshot
  , resolveSnapshotPath
  , snapshotCompanionPath
  , snapshotMetadataPath
  )

main :: IO ()
main = defaultMain $ testGroup "Leant synthesis boundary"
  [ snapshotMetadataTests
  , sessionReplayTests
  , providerCacheTests
  , replayPlanTests
  , providerProgramTests
  , candidateVerificationTests
  , providerParserTests
  , providerEngineTests
  , typeApplicationTests
  , parametricFamilyFragmentTests
  , parametricFamilyEngineTests
  , rankNFrontierTests
  , visibleTypeApplicationTests
  ]

sessionReplayTests :: TestTree
sessionReplayTests = testGroup "transactional session replay"
  [ testCase "reconstruct the newest-first undo chain" $ do
      replayed <- replayHistoryWith step (0 :: Int) ["one", "two"]
      replayed @?= Right (2, [1, 0])
  , testCase "report the failing command without a partial result" $ do
      replayed <- replayHistoryWith step (0 :: Int) ["one", "bad", "two"]
      replayed @?= Left "bad"
  , testCase "restore generated-result numbering above a snapshot base" $ do
      itCounterAfterHistory 37
        ["def user := 1", "def \171it!38\187 := (2)", "def \171it!41\187 := (3)"]
        @?= 41
      itCounterAfterHistory 37
        [ "set_option autoImplicit true in def \171it!38\187 : Nat := 2"
        , "set_option autoImplicit true in noncomputable def \171it!40\187"
        ] @?= 40
      itCounterAfterHistory 37 ["def user := 1"] @?= 37
  ]
 where
  step environment command = pure $ case command of
    "one" -> Just (environment + 1)
    "two" -> Just (environment + 1)
    _ -> Nothing

snapshotMetadataTests :: TestTree
snapshotMetadataTests = testGroup "environment snapshot metadata"
  [ testCase "derive stable sibling paths" $ do
      temporary <- getTemporaryDirectory
      let workingDirectory = normalise (temporary </> "project-root")
      snapshotCompanionPath "state.olean"
        @?= "state.leant-synth.olean"
      snapshotMetadataPath "state.olean" @?= "state.leant.json"
      snapshotCompanionPath "state" @?= "state.leant-synth.olean"
      resolveSnapshotPath workingDirectory ("snapshots" </> "state.olean")
        @?= normalise
          (workingDirectory </> "snapshots" </> "state.olean")
  , testCase "round-trip fingerprints, counter, and companion identity" $ do
      let mainFingerprint = SnapshotFingerprint 123 "0123456789abcdef"
          companionFingerprint = SnapshotFingerprint 456 "fedcba9876543210"
          metadata = SnapshotMetadata
            { snapshotItCounter = 37
            , snapshotMainFingerprint = mainFingerprint
            , snapshotSynthesisCompanion = Just SnapshotCompanion
                { snapshotCompanionFile = "state.leant-synth.olean"
                , snapshotCompanionFingerprint = companionFingerprint
                , snapshotCompanionABI = "leant-synth-fnv1a64-abc"
                }
            }
      decodeSnapshotMetadata (encodeSnapshotMetadata metadata)
        @?= Right metadata
      decodeSnapshotMetadata
          (encodeSnapshotMetadata SnapshotMetadata
            { snapshotItCounter = 0
            , snapshotMainFingerprint = mainFingerprint
            , snapshotSynthesisCompanion = Nothing
            })
        @?= Right SnapshotMetadata
          { snapshotItCounter = 0
          , snapshotMainFingerprint = mainFingerprint
          , snapshotSynthesisCompanion = Nothing
          }
  , testCase "fingerprint snapshot contents without loading them whole" $ do
      temporary <- getTemporaryDirectory
      (path, handle) <- openBinaryTempFile temporary "leant-fingerprint.olean"
      BS.hPut handle (BS.pack "hello")
      hClose handle
      fingerprint <- fingerprintSnapshot path `finally` removeFile path
      fingerprint @?= SnapshotFingerprint 5 "a430d84680aabd0b"
  , testCase "reject incompatible or invalid sidecars" $ do
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":2,"
            ++ "\"itCounter\":0,\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "unsupported snapshot metadata version 2"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1,"
            ++ "\"itCounter\":-1,\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "snapshot it-counter is out of range"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1,"
            ++ "\"itCounter\":0,\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":{\"file\":\"../stale.olean\","
            ++ "\"fingerprint\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"abi\":\"leant-synth-fnv1a64-abc\"}}")
        @?= Left "snapshot companion path must be a sibling filename"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1.4,"
            ++ "\"itCounter\":0,\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "missing or invalid snapshot metadata field `version`"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1,"
            ++ "\"itCounter\":0.4,\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "missing or invalid snapshot metadata field `itCounter`"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1,"
            ++ "\"itCounter\":0,\"main\":{\"bytes\":1e2,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "missing or invalid snapshot metadata field `bytes`"
      decodeSnapshotMetadata
          ("{\"format\":\"leant-snapshot\",\"version\":1,"
            ++ "\"itCounter\":" ++ show (maxBound :: Int) ++ ","
            ++ "\"main\":{\"bytes\":0,"
            ++ "\"fnv1a64\":\"cbf29ce484222325\"},"
            ++ "\"synthesisCompanion\":null}")
        @?= Left "snapshot it-counter is out of range"
  ]

providerProgramTests :: TestTree
providerProgramTests = testGroup "provider discovery program"
  [ testCase "demote implementation workers but trust session declarations" $ do
      let program = providerProgram ["Demo.listImpl"]
            (ProviderQuery ["Demo"] (Just "List"))
          classifier = unlines
            [ "    let implementationWorker (n : Name) : Bool :="
            , "      match n with"
            , "      | .str _ s =>"
            , "        s == \"go\" || s == \"loop\""
            , "          || s.endsWith \"TR\" || s.endsWith \"Impl\""
            , "          || s.endsWith \"Aux\""
            , "      | _ => false"
            ]
          sessionOverride = unlines
            [ "          if session then"
            , "            if exactHead then"
            , "              sessionPreferred := sessionPreferred.push n"
            , "            else"
            , "              sessionFallback := sessionFallback.push n"
            , "          else if implementationWorker n then"
            ]
          tierOrder = unlines
            [ "    let chosen := (sessionPreferred.toList ++ preferred.toList"
            , "      ++ sessionFallback.toList ++ fallback.toList"
            , "      ++ workerPreferred.toList ++ workerFallback.toList).take 80"
            ]
      classifier `isInfixOf` program @?= True
      sessionOverride `isInfixOf` program @?= True
      tierOrder `isInfixOf` program @?= True
  , testCase "exclude type constructors without excluding polymorphic values" $ do
      let program = providerProgram []
            (ProviderQuery ["Widget"] (Just "Widget"))
      "partial def resultIsSort (e : Expr) : MetaM Bool := do"
        `isInfixOf` synthPrelude @?= True
      "        let typeLevel \8592 LeantSynth.resultIsSort info.type\n        if typeLevel then pure () else"
        `isInfixOf` program @?= True
  , testCase "retain only proper-type applications and constructor kinds" $ do
      "partial def isTypeKind (e : Expr) : MetaM Bool := do"
        `isInfixOf` synthPrelude @?= True
      "        if \8592 isTypeKind t then"
        `isInfixOf` synthPrelude @?= True
      "        if !argType.isSort then return none"
        `isInfixOf` synthPrelude @?= True
      "  if !resultType.isSort || args.isEmpty then pure none"
        `isInfixOf` synthPrelude @?= True
      "              match \8592 appOf fuel depth blocked e with"
        `isInfixOf` synthPrelude @?= True
  ]

candidateVerificationTests :: TestTree
candidateVerificationTests = testGroup "candidate verification programs"
  [ testCase "retry valid opaque inhabitants as noncomputable" $
      candidateVerificationProgram "Widget" "Widget.saved" @?=
        "set_option autoImplicit true in noncomputable example : (Widget) := (Widget.saved)"
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
  , testCase "retain nominal application arity and argument order" $
      parseProviderSexp
          "(providers (provider \"Demo.bi\" \
          \(app unsafe \"Demo.Bi \945 \946\" (app-nominal \"Demo.Bi\") \
          \(var \"\945\") (var \"\946\"))))"
        @?= Right
          [ ProviderFrag "Demo.bi"
              (FApp False "Demo.Bi \945 \946" (AppNominal "Demo.Bi")
                [FVar "\945", FVar "\946"])
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

typeApplicationTests :: TestTree
typeApplicationTests = testGroup "retained type applications"
  [ testCase "parse variable and nominal application heads" $ do
      parseGoalSexp
          "(goal type (query (roots \"Demo\") (head \"Demo.Wrap\")) \
          \(-> (all \"a\" (app safe \"F a\" \
          \(app-variable \"F\") (var \"a\"))) \
          \(app unsafe \"Demo.Wrap ((b : Type) \8594 b \8594 b)\" \
          \(app-nominal \"Demo.Wrap\") \
          \(all \"b\" (-> (var \"b\") (var \"b\"))))))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["Demo"] (Just "Demo.Wrap"))
          (FArr
            (FAll True "a"
              (FApp True "F a" (AppVariable "F") [FVar "a"]))
            (FApp False "Demo.Wrap ((b : Type) \8594 b \8594 b)"
              (AppNominal "Demo.Wrap")
              [FAll True "b" (FArr (FVar "b") (FVar "b"))])))
  , testCase "reject an application without proper-type arguments" $
      parseProviderSexp
          "(providers (provider \"Demo.bad\" \
          \(app unsafe \"Demo.Wrap\" (app-nominal \"Demo.Wrap\"))))"
        @?= Left "type application has no arguments"
  , testCase "instantiate through a rigid nominal family with Djinn" $
      expectTerm "x _" (synthesizeWithProviders EngineDjinn 0 [] nominalGoal)
  , testCase "instantiate through a rigid nominal family with Exference" $
      expectTerm "x _"
        (synthesizeWithProviders EngineExference 1024 [] nominalGoal)
  , testCase "instantiate a foreign polymorphic family provider" $
      expectTerm "Demo.polyWrap"
        (synthesizeWithProviders EngineExference 1024
          [ProviderFrag "Demo.polyWrap" nominalHypothesis]
          (wrap "Demo.Wrap ((b : Type) \8594 b \8594 b)" polytype))
  , testCase "retain higher-kinded bound-variable applications" $ do
      let goal = FAll True "F" (FArr variableHypothesis
            (variableApp "F ((b : Type) \8594 b \8594 b)" "F" polytype))
      expectTerm "x _" (synthesizeWithProviders EngineDjinn 0 [] goal)
      expectTerm "x _"
        (synthesizeWithProviders EngineExference 1024 [] goal)
  , testCase "instantiate two proper-type arguments in source order" $ do
      let bi key a b = FApp False key (AppNominal "Demo.Bi") [a, b]
          hypothesis = FAll True "a" (FAll True "b"
            (bi "Demo.Bi a b" (FVar "a") (FVar "b")))
          goal = FArr hypothesis
            (bi "Demo.Bi poly poly" polytype polytype)
      expectTerm "x _ _" (synthesizeWithProviders EngineDjinn 0 [] goal)
      expectTerm "x _ _"
        (synthesizeWithProviders EngineExference 1024 [] goal)
  , testCase "keep distinct Lean family heads rigid" $ do
      let sameKeyHypothesis = FAll True "a"
            (FApp False "same display key"
              (AppNominal "Demo.Wrap") [FVar "a"])
          goal = FArr sameKeyHypothesis
            (FApp False "same display key"
              (AppNominal "Demo.Other") [polytype])
      case synthesizeWithProviders EngineDjinn 0 [] goal of
        Right SynthCandidates{} ->
          assertFailure "distinct nominal heads produced a candidate"
        Right _ -> pure ()
        Left err -> assertFailure err
  , testCase "preserve application argument order" $ do
      let app a b = FApp True "same display key"
            (AppVariable "F") [a, b]
          goal = FAll True "F" (FAll True "a" (FAll True "b"
            (FArr (app (FVar "a") (FVar "b"))
              (app (FVar "b") (FVar "a")))))
      case synthesizeWithProviders EngineDjinn 0 [] goal of
        Right (SynthRefuted True) -> pure ()
        Right other -> assertFailure $
          "expected ordered applications to be distinct, got: "
            ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "keep application arguments atomic for classical splitting" $ do
      let applied = variableApp "F poly" "F" polytype
      glivenkoSplit applied @?= Just ([], applied)
      propAtoms applied @?= [applied]
  , testCase "find depth markers inside retained applications" $
      let truncated =
            FApp True "F a ?" (AppVariable "F") [FVar "a", FDepth]
      in do
        fragHasDepth truncated @?= True
        fragProviderMayOpen truncated @?= False
        fragRefusal truncated
          @?= Just "the goal exceeds the translator's depth bound"
  , testCase "distinguish safe and unsafe negative evidence" $ do
      let safeApp = variableApp "F a" "F" (FVar "a")
          safeImpossible = FAll True "F" (FAll True "a"
            (FArr safeApp FBot))
          unsafeImpossible = FAll True "a"
            (FArr (wrap "Demo.Wrap a" (FVar "a")) FBot)
      fragUnsafeAtoms safeImpossible @?= []
      fragUnsafeAtoms unsafeImpossible @?= ["Demo.Wrap a"]
      fragRefusal safeApp @?= Nothing
      fragProviderMayOpen safeApp @?= True
      fragUnsafeAtoms
          (FApp True "outer" (AppVariable "F") [FAtom False "Nat"])
        @?= ["Nat"]
      case synthesizeWithProviders EngineDjinn 0 [] safeImpossible of
        Right (SynthRefuted True) -> pure ()
        Right other -> assertFailure $
          "expected a sound variable-application refutation, got: "
            ++ outcomeTag other
        Left err -> assertFailure err
      case synthesizeWithProviders EngineDjinn 0 [] unsafeImpossible of
        Right (SynthRefuted False) -> pure ()
        Right other -> assertFailure $
          "expected an unsafe nominal refutation, got: " ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "poison refutations with the complete nominal application" $ do
      let target = wrap "Demo.Wrap ((b : Type) \8594 b \8594 b)" polytype
      fragRefusal target @?= Just
        ("the goal is a single opaque type application \
         \`Demo.Wrap ((b : Type) \8594 b \8594 b)` \8212 :synth can transport \
         \and instantiate retained type applications, but cannot construct \
         \an unknown Lean family")
      fragUnsafeAtoms target
        @?= ["Demo.Wrap ((b : Type) \8594 b \8594 b)"]
      case synthesizeWithProviders EngineDjinn 0 [] target of
        Right (SynthRefuted True) ->
          assertFailure "unsafe nominal application produced a sound refutation"
        Right SynthCandidates{} ->
          assertFailure "bare abstract nominal application produced a candidate"
        Right _ -> pure ()
        Left err -> assertFailure err
  ]
 where
  polytype = FAll True "b" (FArr (FVar "b") (FVar "b"))
  wrap key argument =
    FApp False key (AppNominal "Demo.Wrap") [argument]
  nominalHypothesis = FAll True "a" (wrap "Demo.Wrap a" (FVar "a"))
  nominalGoal = FArr nominalHypothesis
    (wrap "Demo.Wrap ((b : Type) \8594 b \8594 b)" polytype)
  variableApp key headName argument =
    FApp True key (AppVariable headName) [argument]
  variableHypothesis = FAll True "a"
    (variableApp "F a" "F" (FVar "a"))
  expectTerm needle outcome = case outcome of
    Right (SynthCandidates groups _) ->
      if any (needle `isInfixOf`) (concat groups)
        then pure ()
        else assertFailure $
          "expected a candidate containing " ++ show needle
            ++ ", got: " ++ show groups
    Right other -> assertFailure $
      "unexpected synthesis outcome: " ++ outcomeTag other
    Left err -> assertFailure err

parametricFamilyFragmentTests :: TestTree
parametricFamilyFragmentTests = testGroup "parametric family fragments"
  [ testCase "parse and debug an exact-head non-recursive family" $ do
      let family = FParamInd "Demo.Box" "Demo.Box a" [FVar "a"]
            [("Demo.Box.mk", [FVar "a"])]
          parsed = ParsedGoal GoalType
            (ProviderQuery ["Demo"] (Just "Demo.Box")) family
      parseGoalSexp
          "(goal type (query (roots \"Demo\") (head \"Demo.Box\")) \
          \(param-ind \"Demo.Box\" \"Demo.Box a\" (params (var \"a\")) \
          \(ctor \"Demo.Box.mk\" (var \"a\"))))"
        @?= Right parsed
      "FParamInd \"Demo.Box\" \"Demo.Box a\""
        `isInfixOf` show family @?= True
  , testCase "parse an exact-head complete recursive family" $
      parseProviderSexp
          "(providers (provider \"Demo.list\" \
          \(param-rec complete \"List\" \"List a\" \
          \(params (var \"a\")) (ctor \"List.nil\") \
          \(ctor \"List.cons\" (var \"a\") \
          \(atom unsafe \"List a\")))))"
        @?= Right
          [ ProviderFrag "Demo.list"
              (FParamRec True "List" "List a" [FVar "a"]
                [ ("List.nil", [])
                , ("List.cons", [FVar "a", FAtom False "List a"])
                ])
          ]
  , testCase "retain occurrence-local recursion for a term parameter" $
      parseGoalSexp
          "(goal type (query (roots \"Demo\") (head \"Demo.R\")) \
          \(rec complete \"Demo.R (Demo.termByType Unit)\" \
          \(params (atom unsafe \"Demo.termByType Unit\")) \
          \(ctor \"Demo.R.next\" \
          \(atom unsafe \"Demo.R (Demo.termByType Unit)\"))))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["Demo"] (Just "Demo.R"))
          (FRec True "Demo.R (Demo.termByType Unit)"
            [FAtom False "Demo.termByType Unit"]
            [("Demo.R.next",
              [FAtom False "Demo.R (Demo.termByType Unit)"])]))
  , testCase "retain occurrence-local finite data for a term parameter" $
      parseGoalSexp
          "(goal type (query (roots \"Demo\") (head \"Demo.Tag\")) \
          \(ind \"Demo.Tag (Demo.termByType Unit)\" \
          \(ctor \"Demo.Tag.mk\")))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["Demo"] (Just "Demo.Tag"))
          (FInd "Demo.Tag (Demo.termByType Unit)"
            [("Demo.Tag.mk", [])]))
  , testCase "gate family sharing on universe-inhabiting parameters" $ do
      "def allProperTypeParams (args : Array Expr) : MetaM Bool := do"
        `isInfixOf` synthPrelude @?= True
      unlines
          [ "    let argType \8592 whnfR (\8592 inferType arg)"
          , "    if !argType.isSort then return false"
          ]
        `isInfixOf` synthPrelude @?= True
      "        if \8592 allProperTypeParams args then do"
        `isInfixOf` synthPrelude @?= True
      "          let properParams \8592 allProperTypeParams args"
        `isInfixOf` synthPrelude @?= True
      "          else if properParams then"
        `isInfixOf` synthPrelude @?= True
  , testCase "reject depth hidden in a family parameter" $ do
      let truncated = FParamInd "Demo.Phantom" "Demo.Phantom ?"
            [FDepth] [("Demo.Phantom.base", [])]
      fragHasDepth truncated @?= True
      fragProviderMayOpen truncated @?= False
      fragRefusal truncated
        @?= Just "the goal exceeds the translator's depth bound"
  , testCase "traverse family parameters for unsafe evidence" $ do
      let parameter = FAtom False "Demo.Hidden"
          field = FAtom False "Demo.Field"
          finite = FParamInd "Demo.Box" "Demo.Box Demo.Hidden"
            [parameter] [("Demo.Box.mk", [field])]
          recursive = FParamRec True "Demo.Tree" "Demo.Tree Demo.Hidden"
            [parameter] [("Demo.Tree.node", [field])]
      fragUnsafeAtoms finite @?= ["Demo.Hidden", "Demo.Field"]
      fragUnsafeAtoms recursive @?=
        ["Demo.Tree Demo.Hidden", "Demo.Hidden", "Demo.Field"]
      fragProviderMayOpen finite @?= False
      fragProviderMayOpen recursive @?= False
  , testCase "keep parameters nominal in the classical projection" $ do
      let hiddenQuantifier = FAll True "a" (FVar "a")
          field = FVar "p"
          finite = FParamInd "Demo.Phantom" "Demo.Phantom poly"
            [hiddenQuantifier] [("Demo.Phantom.mk", [field])]
          exposed = FParamInd "Demo.Box" "Demo.Box poly"
            [hiddenQuantifier] [("Demo.Box.mk", [hiddenQuantifier])]
          recursive = FParamRec True "Demo.Tree" "Demo.Tree poly"
            [hiddenQuantifier] [("Demo.Tree.nil", [])]
      glivenkoSplit finite @?= Just ([], finite)
      propAtoms finite @?= [field]
      glivenkoSplit exposed @?= Nothing
      glivenkoSplit recursive @?= Nothing
      propAtoms recursive @?= []
  ]

parametricFamilyEngineTests :: TestTree
parametricFamilyEngineTests = testGroup "parametric family engine projection"
  [ testCase "transport an Option-like rank-N family with Djinn" $
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineDjinn 0 [] optionRankNGoal)
  , testCase "transport an Option-like rank-N family with Exference" $
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineExference 1024 [] optionRankNGoal)
  , testCase "share fixed opaque constructor fields without free variables" $
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineExference 1024 [] guardRankNGoal)
  , testCase "preserve constructor introduction and case elimination" $ do
      let parameter = FVar "a"
          box = unaryFamily "Demo.Box" "Demo.Box.mk" "Demo.Box a" parameter
          introduction = FAll True "a" (FArr parameter box)
          elimination = FAll True "a" (FArr box parameter)
          introduced = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [] introduction)
          eliminated = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [] elimination)
      if any (\term -> "Demo.Box.mk" `isInfixOf` term
              || "\10216" `isInfixOf` term) introduced
        then pure ()
        else assertFailure $ "missing shared-family constructor: "
          ++ show introduced
      if any ("match" `isInfixOf`) eliminated
        then pure ()
        else assertFailure $ "missing shared-family case: "
          ++ show eliminated
  , testCase "specialize constructor fitting at a rank-N occurrence" $ do
      let box = unaryFamily "Demo.Box" "Demo.Box.mk" "Demo.Box poly"
            polytype
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 []
              (FArr box polytype))
      if any (\term -> "| .mk f => f" `isInfixOf` term
              || "| Demo.Box.mk f => f" `isInfixOf` term) candidates
        then pure ()
        else assertFailure $ "rank-N constructor fields were not fitted: "
          ++ show candidates
  , testCase "pre-scan a nested provider for the compatible schema" $ do
      let result = FVar "r"
          repeated = binaryFamily "Demo.Pairish r r" result result
            [result]
          left = FVar "p"
          right = FVar "q"
          generic = binaryFamily "Demo.Pairish p q" left right [left]
          provider = ProviderFrag "Demo.blockedPairish"
            (FAll False "p" (FAll False "q"
              (FArr (FAtom False "Demo.Blocker") generic)))
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [provider]
              (FArr repeated result))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "provider template was not shared: "
          ++ show candidates
  , testCase "exclude a depth-limited provider from family planning" $ do
      let parameter = FVar "a"
          box = unaryFamily "Demo.Box" "Demo.Box.mk" "Demo.Box a" parameter
          incompatible = FParamInd "Demo.Box" "Demo.Box hidden"
            [FAtom False "Demo.Hidden"] [("Demo.Box.mk", [])]
          provider = ProviderFrag "Demo.tooDeep"
            (FArr FDepth incompatible)
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [provider]
              (FArr box parameter))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "a rejected provider poisoned family planning: "
          ++ show candidates
  , testCase "never soundly refute through an unsafe caller premise" $ do
      let result = FVar "r"
          premise = FArr (FAtom False "Fin 1") result
      case synthesizeWith EngineDjinn 0 [("Demo.fromFin", premise)]
          result result of
        Right (SynthRefuted True) -> assertFailure
          "opaque structure in a caller premise produced a sound refutation"
        Right _ -> pure ()
        Left err -> assertFailure err
  , testCase "pre-scan a nested caller premise for the compatible schema" $ do
      let result = FVar "r"
          repeated = binaryFamily "Demo.Pairish r r" result result
            [result]
          left = FVar "p"
          right = FVar "q"
          generic = binaryFamily "Demo.Pairish p q" left right [left]
          premise = FAll False "p" (FAll False "q"
            (FArr (FAtom False "Demo.Blocker") generic))
          goal = FArr repeated result
          candidates = allFamilyCandidates
            (synthesizeWith EngineDjinn 0 [("Demo.blockedPairish", premise)]
              goal goal)
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "caller-premise template was not shared: "
          ++ show candidates
  , testCase "ignore occurrence display keys in nested exact fields" $ do
      let left = FVar "p"
          right = FVar "q"
          inner key parameter = FApp False key
            (AppNominal "Demo.Inner") [parameter]
          outer key innerKey parameter = FParamInd "Demo.Outer" key
            [parameter] [("Demo.Outer.mk", [inner innerKey parameter])]
          leftOuter = outer "Demo.Outer p" "Demo.Inner p" left
          rightOuter = outer "Demo.Outer q" "Demo.Inner q" right
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr leftOuter
                (FArr rightOuter (inner "Demo.Inner p" left))))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "nested display keys split one schema: "
          ++ show candidates
  , testCase "compare fixed rank-N fields modulo binder names" $ do
      let identity binder = FAll True binder
            (FArr (FVar binder) (FVar binder))
          leftIdentity = identity "x"
          rightIdentity = identity "y"
          family key parameter field = FParamInd "Demo.PolyField" key
            [parameter] [("Demo.PolyField.mk", [field])]
          left = family "Demo.PolyField p" (FVar "p") leftIdentity
          right = family "Demo.PolyField q" (FVar "q") rightIdentity
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr left (FArr right leftIdentity)))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "alpha-renamed fixed fields split one schema: "
          ++ show candidates
  , testCase "do not capture shadowing binders while genericizing" $ do
      let identity binder = FAll True binder
            (FArr (FVar binder) (FVar binder))
          family parameter = FParamInd "Demo.PolyField" "same display key"
            [FVar parameter]
            [("Demo.PolyField.mk", [identity parameter])]
          left = family "a"
          right = family "b"
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr left (FArr right (identity "result"))))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "local forall binders were captured: "
          ++ show candidates
  , testCase "avoid capture while specializing actual parameters" $ do
      let field parameter binder = FAll True binder
            (FArr (FVar parameter) (FVar binder))
          family parameter binder = FParamInd
            "Demo.DepField" "same display key" [FVar parameter]
            [("Demo.DepField.mk", [field parameter binder])]
          left = family "a" "b"
          right = family "b" "a"
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr right (FArr left (field "a" "b"))))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "actual family parameter was captured: "
          ++ show candidates
  , testCase "treat duplicate exact parameters as ambiguous despite metadata" $
      let parameter = FVar "p"
          inner fields = FParamInd "Demo.Inner" "Demo.Inner p" [parameter]
            [("Demo.Inner.mk", fields)]
          leftInner = inner [parameter]
          rightInner = inner []
          outer = FParamInd "Demo.Outer" "Demo.Outer inner inner"
            [leftInner, rightInner]
            [("Demo.Outer.mk", [leftInner])]
      in expectIncompleteNoFamilyTerm
          (synthesizeWithProviders EngineDjinn 0 []
            (FArr outer leftInner))
  , testCase "ignore nested exact-family metadata in outer schemas" $ do
      let inner key parameter fields = FParamInd
            "Demo.Inner" key [parameter] [("Demo.Inner.mk", fields)]
          outer key parameter field = FParamInd
            "Demo.Outer" key [parameter] [("Demo.Outer.mk", [field])]
          leftParameter = FVar "p"
          rightParameter = FVar "q"
          leftInner = inner "Demo.Inner p" leftParameter [leftParameter]
          rightInner = inner "Demo.Inner q" rightParameter []
          leftOuter = outer "Demo.Outer p" leftParameter leftInner
          rightOuter = outer "Demo.Outer q" rightParameter rightInner
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr rightOuter (FArr leftOuter leftInner)))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "nested metadata poisoned the outer schema: "
          ++ show candidates
  , testCase "keep inner-only metadata out of an outer declaration" $ do
      let parameter = FVar "p"
          inner = FParamInd "Demo.Inner" "Demo.Inner p" [parameter]
            [("Demo.Inner.mk",
              [FVar "innerClosedOver", FAtom False "Demo.InnerOnly"])]
          outer = FParamInd "Demo.Outer" "Demo.Outer p" [parameter]
            [("Demo.Outer.mk", [inner])]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 [] (FArr outer inner))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "inner-only metadata poisoned outer data: "
          ++ show candidates
  , testCase "choose a later unambiguous repeated-parameter template" $ do
      let result = FVar "r"
          repeated = binaryFamily "Demo.Pairish r r" result result
            [result]
          left = FVar "p"
          right = FVar "q"
          generic = binaryFamily "Demo.Pairish p q" left right [left]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr repeated (FArr generic result)))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "later family template was not selected: "
          ++ show candidates
  , testCase "keep an all-ambiguous repeated family abstract" $ do
      let result = FVar "r"
          repeated = binaryFamily "Demo.Pairish r r" result result
            [result]
      expectIncompleteNoFamilyTerm
        (synthesizeWithProviders EngineDjinn 0 [] (FArr repeated result))
  , testCase "fall back query-wide when constructor schemas disagree" $ do
      let result = FVar "r"
          other = FVar "s"
          extractable = unaryFamily "Demo.Box" "Demo.Box.mk"
            "Demo.Box r" result
          incompatible = FParamInd "Demo.Box" "Demo.Box s" [other]
            [("Demo.Box.mk", [])]
      expectIncompleteNoFamilyTerm
        (synthesizeWithProviders EngineDjinn 0 []
          (FArr extractable (FArr incompatible result)))
  , testCase "make nominal and structural uses one abstract family" $ do
      let source = FAll True "a"
            (unaryFamily "Demo.Box" "Demo.Box.mk" "Demo.Box a"
              (FVar "a"))
          target = FApp False "Demo.Box poly"
            (AppNominal "Demo.Box") [polytype]
          goal = FArr source target
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineDjinn 0 [] goal)
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineExference 1024 [] goal)
  , testCase "never transport between distinct exact family heads" $ do
      let parameter = FVar "a"
          source = unaryFamily "Demo.LeftBox" "Demo.LeftBox.mk"
            "same display key" parameter
          target = unaryFamily "Demo.RightBox" "Demo.RightBox.mk"
            "same display key" parameter
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FAll True "a" (FArr source target)))
      if any (== "fun _ x => x") candidates
        then assertFailure $ "distinct heads transported directly: "
          ++ show candidates
        else if null candidates
          then assertFailure "distinct structural heads lost all conversions"
          else pure ()
  , testCase "retain the established recursive fallback for FParamRec" $ do
      let result = FVar "r"
          natural = FParamRec True "Nat" "Nat" []
            [ ("Nat.zero", [])
            , ("Nat.succ", [FAtom False "Nat"])
            ]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 []
              (FArr result
                (FArr (FArr natural result) (FArr natural result))))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "FParamRec lost FRec elimination: "
          ++ show candidates
  , testCase "scope an opaque recursive field inside shared finite data" $ do
      let element = FVar "a"
          listKey = "List a"
          list = FParamRec True "List" listKey [element]
            [ ("List.nil", [])
            , ("List.cons", [element, FAtom False listKey])
            ]
          wrapper = FParamInd "Demo.ListBox" "Demo.ListBox a" [element]
            [("Demo.ListBox.mk", [list])]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr wrapper list))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "recursive field escaped its data declaration: "
          ++ show candidates
  , testCase "scope a fixed opaque field in zero-parameter recursive data" $ do
      let string = FAtom False "String"
          format = FParamRec True "Std.Format" "Format" []
            [ ("Std.Format.nil", [])
            , ("Std.Format.text", [string])
            , ("Std.Format.append",
                [FAtom False "Format", FAtom False "Format"])
            ]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 512 []
              (FArr string format))
      if any ("text x" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "an earlier fixed field did not construct recursive data: "
            ++ show candidates
  ]
 where
  polytype = FAll True "b" (FArr (FVar "b") (FVar "b"))
  option key parameter = FParamInd "Option" key [parameter]
    [ ("Option.none", [])
    , ("Option.some", [parameter])
    ]
  optionRankNGoal = FArr
    (FAll True "a" (option "Option a" (FVar "a")))
    (option "Option poly" polytype)
  guard key parameter = FParamInd "Demo.Guard" key [parameter]
    [("Demo.Guard.mk", [FAtom False "Demo.Secret", parameter])]
  guardRankNGoal = FArr
    (FAll True "a" (guard "Demo.Guard a" (FVar "a")))
    (guard "Demo.Guard poly" polytype)
  unaryFamily headName constructor key parameter =
    FParamInd headName key [parameter] [(constructor, [parameter])]
  binaryFamily key left right fields =
    FParamInd "Demo.Pairish" key [left, right]
      [("Demo.Pairish.mk", fields)]
  expectExactFamilyTerm expected outcome =
    let candidates = allFamilyCandidates outcome
    in if expected `elem` candidates
        then pure ()
        else assertFailure $ "expected exact family candidate "
          ++ show expected ++ ", got: " ++ show candidates
  expectIncompleteNoFamilyTerm outcome = case outcome of
    Right (SynthCandidates groups _) -> assertFailure $
      "abstract family unexpectedly exposed constructors: " ++ show groups
    Right (SynthRefuted True) ->
      assertFailure "abstract family produced a sound refutation"
    Right _ -> pure ()
    Left err -> assertFailure err
  allFamilyCandidates outcome = case outcome of
    Right (SynthCandidates groups _) -> concat groups
    Right _ -> []
    Left err -> error err

rankNFrontierTests :: TestTree
rankNFrontierTests = testGroup "Djinn rank-N frontiers"
  [ testCase "render four-binder hypothesis instantiation for Lean" $ do
      let variable = FVar
          forall4 a b c d resultFrag =
            FAll True a
              (FAll True b (FAll True c (FAll True d resultFrag)))
          hypothesis = forall4 "a" "b" "c" "d"
            (FArr (variable "a")
              (FArr (variable "b")
                (FArr (variable "c")
                  (FArr (variable "d") (variable "R")))))
          body = FArr hypothesis
            (FArr (variable "A")
              (FArr (variable "B")
                (FArr (variable "C")
                  (FArr (variable "D") (variable "R")))))
          goal = FAll True "A" (FAll True "B" (FAll True "C"
            (FAll True "D" (FAll True "R" body))))
      case synthesizeWithProviders EngineDjinn 0 [] goal of
        Right (SynthCandidates groups _) ->
          let candidates = concat groups
              -- Djex de-duplicates candidates by their eta-normal meaning
              -- while retaining the first checked spelling.  The compact
              -- partially applied spelling and the explicitly eta-expanded
              -- one therefore witness the same four type instantiations.
              instantiated candidate =
                "f _ _ _ _ x y z w" `isInfixOf` candidate
                  || "=> f _ _ _ _" `isInfixOf` candidate
          in if any instantiated candidates
              then pure ()
              else assertFailure $
                "expected a four-binder instantiation candidate, got: "
                  ++ show candidates
        Right other -> assertFailure $
          "unexpected four-binder synthesis outcome: " ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "render a balanced four-site pairwise plan for Lean" $ do
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
  , testCase "render a balanced six-site triple plan for Lean" $ do
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
          q = variable "q"
          r = variable "r"
          goal = FArr
            (wide "a" "b" "c" "d")
            (FArr
              (consumer q "s" "t" "u" "v")
              (FArr
                (consumer r "i" "j" "k" "l")
                (FProd
                  (wide "w" "x" "y" "z")
                  (FProd
                    (consumer q "m" "n" "o" "p")
                    (FProd
                      (consumer r "h" "i1" "j1" "k1")
                      (FProd (identity "e")
                        (FProd (identity "f") (identity "g"))))))))
          candidates = firstGroup
            (synthesizeWithProviders EngineDjinn 0 [] goal)
      if any (\candidate ->
          "fun " `isInfixOf` candidate
            && "\10216" `isInfixOf` candidate
            && "fun _" `isInfixOf` candidate) candidates
        then pure ()
        else assertFailure $
          "expected a rendered triple rank-N candidate, got: "
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
          (Map.singleton "leantProvider0" "Demo.identity") Map.empty
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
          (Map.singleton "leantProvider0" "Demo.identity") Map.empty
          [] (FAtom False "Nat") expression
        @?= Right ["@Demo.identity (Option (Int → Bool))"]
  , testCase "restore every nominal argument with explicit Lean syntax" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      privateName <- expectRight $ mkIdentifier "LeantType0"
      integerName <- expectRight $ mkIdentifier "Int"
      let wrapped = TypeApplication
            (TypeConstructor privateName) (TypeConstructor integerName)
              :: Type String
      argument <- expectRight $ specifiedVisibleTypeArgument wrapped
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0" "Demo.identity")
          (Map.singleton "LeantType0" "Demo.Wrap")
        [] (FAtom False "Nat") expression
        @?= Right ["@Demo.identity (@Demo.Wrap Int)"]
  , testCase "restore a rigid opaque field as one parenthesized type" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      privateName <- expectRight $ mkIdentifier "LeantAtom0"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor privateName :: Type String)
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0" "Demo.identity")
          (Map.singleton "LeantAtom0" "(Nat × Nat)")
          [] (FAtom False "Nat") expression
        @?= Right ["@Demo.identity @(Nat × Nat)"]
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
