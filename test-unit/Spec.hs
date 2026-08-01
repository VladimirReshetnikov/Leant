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
          in if any ("f _ _ _ _ x y z w" `isInfixOf`) candidates
              then pure ()
              else assertFailure $
                "expected a fully applied four-binder candidate, got: "
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
