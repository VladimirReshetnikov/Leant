module Main (main) where

import Control.Exception (evaluate, finally)
import qualified Data.ByteString.Char8 as BS
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (isInfixOf)
import Data.Maybe (isNothing)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import System.Directory
  ( canonicalizePath
  , createDirectory
  , createDirectoryIfMissing
  , createFileLink
  , getTemporaryDirectory
  , removeFile
  , removePathForcibly
  )
import System.FilePath ((</>), normalise, takeDirectory)
import System.IO (hClose, openBinaryTempFile)
import System.Info (os)
import System.Timeout (timeout)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, assertFailure, testCase)

import Language.Haskell.Djex
  ( Boxity (Boxed)
  , Constraint (..)
  , ExferenceOptions (..)
  , ExferenceSessionPolicy (..)
  , Expression
      ( Apply, Case, Global, Lambda, Let, Local, Tuple
      , VisibleTypeApplication
      )
  , Pattern (Bind, Constructor, TuplePattern, Wildcard)
  , KindedProviderInstantiationAssignment (..)
  , LengthContractSource (..)
  , LengthContractVariable (..)
  , LengthExpression (..)
  , LengthFormula (..)
  , LengthProviderArgumentRole (..)
  , LengthProviderInventoryError (..)
  , LengthProviderSummaryError (..)
  , LengthSessionError (..)
  , QueryRequest (..)
  , Type (..)
  , Variable (FlexibleVariable)
  , inferredVisibleTypeArgument
  , checkedLengthCandidateResult
  , checkedLengthCandidateUsedProviders
  , checkedLengthProblemCandidate
  , maximumProviderInstantiationArguments
  , maximumProviderInstantiationKindNodes
  , mkIdentifier
  , noObservations
  , observationCount
  , specifiedVisibleTypeArgument
  , typedCandidateTermGraph
  , tupleName
  , behavioralProblemFingerprint
  , checkedLengthProblemBehavioralProblem
  , defaultLengthEvaluationLimits
  , fingerprintCanonicalBytes
  , lengthSMTLibQueryBehavioralProblem
  , lengthSMTLibQueryFingerprint
  , lengthSMTLibQueryInputSymbols
  , lengthSMTLibQueryInputValueRequestBytes
  , lengthSMTLibQueryLogic
  , lengthSMTLibQuerySchemaTag
  , validateLengthSMTLibCounterexample
  )

import Leant.Backend (findBackendProject)
import Leant.Synth.Engine
  ( DetailedSynthOutcome (..)
  , ExferenceRunAuthorityInspection (..)
  , LeanLengthContract (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthSpineIdentity (..)
  , LengthHandoffRefusal (..)
  , PreparedSynthesisInspection (..)
  , ProviderBindingInspection (..)
  , SynthEngine (..)
  , SynthOutcome (..)
  , TranslatedPremise (..)
  , detailedCandidateGroup
  , detailedCandidateGroupRoute
  , detailedCandidateGroupSemanticSidecar
  , detailedCandidateGroupVariants
  , detailedCandidateGroupVerificationVariants
  , detailedVerificationVariantOrdinal
  , detailedVerificationVariantRoute
  , detailedVerificationVariantSemanticSidecar
  , detailedVerificationVariantText
  , forceDetailedOutcome
  , inspectExferencePreparation
  , mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
  , mergeCandidateGroups
  , mergeDetailedCandidateGroups
  , mergeDetailedOutcomesSkipping
  , mergeOutcomes
  , mergeOutcomesSkipping
  , providerStages
  , synthEngineName
  , candidateWindow
  , checkedLengthHandoffFamilyInspection
  , checkedLengthHandoffProblem
  , synthMaxShown
  , synthMaxTried
  , synthVerificationWindow
  , synthesizeWith
  , synthesizeWithProviders
  , synthesizeWithProvidersSkippingDetailed
  , synthesizeTunedDetailed
  , projectDetailedSynthOutcome
  , prepareCheckedLengthHandoff
  , renderCandidateByAvailability
  , takeDistinct
  , takeDistinctOn
  , typedCandidateSemanticCandidate
  , typedCandidateSemanticAuthorityInspection
  , typedCandidateSemanticFingerprint
  , typedCandidateSemanticInventory
  , withoutCheckedCandidates
  , withoutCheckedDetailedCandidates
  )
import Leant.Synth.Fragment
  ( AppHead (..)
  , ExactContextArgument (..)
  , Frag (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , ProviderFrag (..)
  , ProviderForallDomain (..)
  , ProviderInstantiationArgument (..)
  , ProviderQuery (..)
  , candidateVerificationProgram
  , fragHasDepth
  , fragHasInstanceBinder
  , fragHasUnsupportedInstanceBinder
  , fragProviderMayOpen
  , fragRefusal
  , fragUnsafeAtoms
  , glivenkoSplit
  , maximumProviderArgumentKindArity
  , maximumProviderExactForallDomains
  , parseGoalSexp
  , parseProviderSexp
  , providerProgram
  , propAtoms
  , serializerProgram
  , synthPrelude
  )
import Leant.Synth.Length.Adapter
  ( prepareLengthQueryFromHandoff )
import Leant.Synth.Observability
  ( CandidateRenderingRoute (..)
  , LeantSynthesisMetric (..)
  , VerificationFailureClass (..)
  , candidateRenderingRouteMetric
  , candidateRenderingRouteObservations
  , leantObservationCodeEntries
  , leantSynthesisMetricCode
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
import Leant.Synth.Render
  ( CtorInfo (..)
  , ProviderAssignmentInfo (..)
  , ProviderInfo (..)
  , providerInfo
  , renderLeanTerm
  )
import Leant.Synth.Verification
  ( VariantVerdict (..)
  , failedCandidateGroups
  , verificationObservations
  , verifiedCandidate
  , verifiedCandidateReceipts
  , verifiedCandidates
  , verifyCandidateGroups
  )
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
  [ backendDiscoveryTests
  , snapshotMetadataTests
  , sessionReplayTests
  , providerCacheTests
  , translationPreparationTests
  , providerScheduleTests
  , combinedEngineMergeTests
  , typedCandidateRoutingTests
  , replayPlanTests
  , providerProgramTests
  , candidateVerificationTests
  , verificationObservabilityTests
  , providerParserTests
  , instanceImplicitTests
  , providerEngineTests
  , typeApplicationTests
  , parametricFamilyFragmentTests
  , parametricFamilyEngineTests
  , rankNFrontierTests
  , visibleTypeApplicationTests
  ]

backendDiscoveryTests :: TestTree
backendDiscoveryTests = testGroup "Lean backend discovery"
  [ testCase "find the Lake project above a cached REPL executable" $
      withTemporaryDirectory "leant-backend-project" $ \root -> do
        let project = root </> "cache" </> "owner" </> "repl" </> "revision"
            executable = project </> ".lake" </> "build" </> "bin" </> "repl"
        createDirectoryIfMissing True $ takeDirectory executable
        writeFile (project </> "lakefile.toml") "name = \"repl\"\n"
        writeFile executable ""
        expected <- canonicalizePath project
        found <- findBackendProject executable
        found @?= Just expected
  , testCase "follow a backend symlink to its real Lake project" $
      if os == "mingw32" then pure () else
        withTemporaryDirectory "leant-backend-link" $ \root -> do
          let project = root </> "cache" </> "repl" </> "revision"
              executable = project </> ".lake" </> "build" </> "bin" </> "repl"
              linked = root </> "convenience" </> "repl"
          createDirectoryIfMissing True $ takeDirectory executable
          createDirectoryIfMissing True $ takeDirectory linked
          writeFile (project </> "lakefile.lean") "package repl\n"
          writeFile executable ""
          createFileLink executable linked
          expected <- canonicalizePath project
          found <- findBackendProject linked
          found @?= Just expected
  , testCase "reject a backend executable without an enclosing Lake project" $
      withTemporaryDirectory "leant-backend-orphan" $ \root -> do
        let executable = root </> "bin" </> "repl"
        createDirectoryIfMissing True $ takeDirectory executable
        writeFile executable ""
        found <- findBackendProject executable
        found @?= Nothing
  ]

withTemporaryDirectory :: String -> (FilePath -> IO a) -> IO a
withTemporaryDirectory template action = do
  temporary <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile temporary template
  hClose handle
  removeFile path
  createDirectory path
  action path `finally` removePathForcibly path

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
        `isInfixOf` synthPrelude [] @?= True
      "        let typeLevel \8592 LeantSynth.resultIsSort info.type\n        if typeLevel then pure () else"
        `isInfixOf` program @?= True
  , testCase "retain proper applications and bounded constructor kinds" $ do
      "partial def isTypeKind (e : Expr) : MetaM Bool := do"
        `isInfixOf` synthPrelude [] @?= True
      "partial def typeKindArity? (remaining : Nat) (e : Expr)"
        `isInfixOf` synthPrelude [] @?= True
      "        if \8592 isTypeKind t then"
        `isInfixOf` synthPrelude [] @?= True
      "        if !argType.isSort then return none"
        `isInfixOf` synthPrelude [] @?= True
      "  if !resultType.isSort || args.isEmpty then pure none"
        `isInfixOf` synthPrelude [] @?= True
      "              match \8592 appOf providerMode exactAssignmentMode fuel depth blocked e with"
        `isInfixOf` synthPrelude [] @?= True
  , testCase "separate ordinary and exact-assignment instance serialization" $ do
      let instanceHandling = unlines
            [ "      else if bi.isInstImplicit then"
            , "        -- Typeclass evidence is reconstructed by Lean when a value is"
            , "        -- applied, so Djex never consumes it as a term premise. Providers"
            , "        -- erase the binder completely. Exact assignment mode preserves a"
            , "        -- bounded, semantic class application; ordinary goal mode retains"
            , "        -- only the legacy render marker for backward compatibility."
            , "        if providerMode then"
            , "          go providerMode exactAssignmentMode fuel depth blocked b"
            , "        else if exactAssignmentMode then do"
            , "          let legacy : MetaM String := do"
            ]
          exactContextHandling = unlines
            [ "          match \8592 Meta.isClass? classType with"
            , "          | none => legacy"
            , "          | some className => do"
            , "            let arguments := classType.getAppArgs"
            ]
          implicitScheme = unlines
            [ "      else do"
            , "        let typeKind \8592 isTypeKind t"
            , "        if providerMode && !typeKind then atomOf e"
            , "        else do"
            , "          -- An unused ordinary implicit type parameter still needs a"
            , "          -- scheme binder so Djex can choose a visible instantiation."
            ]
      instanceHandling `isInfixOf` synthPrelude [] @?= True
      exactContextHandling `isInfixOf` synthPrelude [] @?= True
      "pure (\"(exact-context \" ++ esc className.toString"
        `isInfixOf` synthPrelude [] @?= True
      "def exactContextArgumentKindArity? (fuel : Nat) (argument : Expr)"
        `isInfixOf` synthPrelude [] @?= True
      "partial def exactContextArgumentFragment? (fuel depth : Nat)"
        `isInfixOf` synthPrelude [] @?= True
      isInfixOf "pure (some (arity, \"(nominal \" ++ esc name.toString"
        (synthPrelude []) @?= True
      "++ toString arity ++ \" \" ++ fragment ++ \")\""
        `isInfixOf` synthPrelude [] @?= True
      "if exactAssignmentMode && bi.isInstImplicit then pure \"(depth)\""
        `isInfixOf` synthPrelude [] @?= True
      "let r \8592 go providerMode false fuel depth blocked b"
        `isInfixOf` synthPrelude [] @?= True
      implicitScheme `isInfixOf` synthPrelude [] @?= True
      "let s \8592 LeantSynth.go false false 100 0 [] tgt"
        `isInfixOf` serializerProgram "Demo.Token" @?= True
      "let frag \8592 LeantSynth.go true false 80 0 [] info.type"
        `isInfixOf` providerProgram []
          (ProviderQuery ["Demo"] (Just "Demo.Token")) @?= True
      "partial def leadingTypeBinderNames (fuel : Nat) (e : Expr)"
        `isInfixOf` synthPrelude [] @?= True
      "let binders \8592 LeantSynth.leadingTypeBinderNames 80 info.type"
        `isInfixOf` providerProgram []
          (ProviderQuery ["Demo"] (Just "Demo.Token")) @?= True
  , testCase "bound complete active instance-head assignments per provider" $ do
      let prelude = synthPrelude []
          program = providerProgram []
            (ProviderQuery ["Gap"] (Just "Gap.Token"))
      ("providerEvidenceSpine fuel "
          ++ show maximumProviderInstantiationArguments ++ " source")
        `isInfixOf` prelude @?= True
      "if inspected < 32 && assignments.size < 16"
        `isInfixOf` prelude @?= True
      "for inst in instances.toList.reverse do"
        `isInfixOf` prelude @?= True
      "Lean.withoutModifyingState do" `isInfixOf` prelude @?= True
      "partial def closeProviderConstraints (fuel : Nat) (pending : List Expr)"
        `isInfixOf` prelude @?= True
      "closeProviderConstraints fuel (subgoals ++ rest)"
        `isInfixOf` prelude @?= True
      "let mut pending := subgoals" `isInfixOf` prelude @?= True
      "let otherGoal ← mkFreshExprMVar otherConstraint"
        `isInfixOf` prelude @?= True
      "pending := pending ++ [otherGoal]"
        `isInfixOf` prelude @?= True
      "if binderInfo.isInstImplicit then do"
        `isInfixOf` prelude @?= True
      unlines
          [ "      if binderInfo.isInstImplicit then do"
          , "        -- A dictionary-dependent result is not an ordinary Haskell class"
          , "        -- context and must not fall back to one opaque pretty-printed atom."
          , "        if body.hasLooseBVars then pure none"
          ]
        `isInfixOf` prelude @?= True
      ("if arguments.size > "
          ++ show maximumProviderInstantiationArguments ++ " then return none")
        `isInfixOf` prelude @?= True
      "match \8592 Meta.isClass? classType with"
        `isInfixOf` prelude @?= True
      "| some closedMCtx => withMCtx closedMCtx do"
        `isInfixOf` prelude @?= True
      "if complete && arguments.size == typeArgs.size then"
        `isInfixOf` prelude @?= True
      "match ← typeKindArity? fuel kind with"
        `isInfixOf` prelude @?= True
      "if arity > 64 then" `isInfixOf` prelude @?= True
      "providerNominalCandidateFragment? fuel candidate"
        `isInfixOf` prelude @?= True
      "let mut assignments : Array (Array ProviderCandidateFragment) := #[]"
        `isInfixOf` prelude @?= True
      "candidate : Expr"
        `isInfixOf` prelude @?= True
      "domains : Array String"
        `isInfixOf` prelude @?= True
      "providerForallDomains? fuel 0 candidate"
        `isInfixOf` prelude @?= True
      "let fragment \8592 go false true fuel 0 [] candidate"
        `isInfixOf` prelude @?= True
      "payload := \"(exact (domains\""
        `isInfixOf` prelude @?= True
      "providerCandidateAssignmentsDefEq"
        `isInfixOf` prelude @?= True
      "firstLeft.domains != firstRight.domains"
        `isInfixOf` prelude @?= True
      "Lean.withoutModifyingState do"
        `isInfixOf` prelude @?= True
      "isDefEq firstLeft.candidate firstRight.candidate"
        `isInfixOf` prelude @?= True
      "LeantSynth.providerInstantiationAssignments 80 info.type"
        `isInfixOf` program @?= True
      "\" (kinded \" ++ toString argument.kindArity ++ \" \""
        `isInfixOf` program @?= True
      "\" (instantiations\" ++ assignmentText ++ \")\""
        `isInfixOf` program @?= True
  ]

candidateVerificationTests :: TestTree
candidateVerificationTests = testGroup "candidate verification programs"
  [ testCase "retry valid opaque inhabitants as noncomputable" $
      candidateVerificationProgram "Widget" "Widget.saved" @?=
        "set_option autoImplicit true in noncomputable example : (Widget) := (Widget.saved)"
  ]

verificationObservabilityTests :: TestTree
verificationObservabilityTests = testGroup "verification observability"
  [ testCase "assign unique stable codes to every metric" $ do
      let failures = [minBound .. maxBound]
          metrics =
            [ LegacyCandidateFallback
            , TypedCandidateRendered
            , LeanVariantAttempted
            ]
            ++ map LeanVerificationFailure failures
            ++ [LeanCandidateVerified]
          codes = map leantSynthesisMetricCode metrics
      codes @?=
        [ "legacy-candidate-fallback"
        , "typed-candidate-rendered"
        , "lean-variant-attempted"
        , "lean-verification-failure.backend-request"
        , "lean-verification-failure.backend-fatal-response"
        , "lean-verification-failure.error-diagnostic"
        , "lean-verification-failure.contains-sorry"
        , "lean-candidate-verified"
        ]
      Set.size (Set.fromList codes) @?= length codes
  , testCase "classify rejections exactly once before a success" $ do
      let verdict candidate = pure $ case candidate of
            "request" -> VariantRejected BackendRequestFailure
            "fatal" -> VariantRejected BackendFatalResponse
            "diagnostic" -> VariantRejected LeanErrorDiagnostic
            "sorry" -> VariantRejected LeanContainsSorry
            _ -> VariantAccepted
      batch <- verifyCandidateGroups 1 verdict
        [["request", "fatal", "diagnostic", "sorry", "accepted"]]
      verifiedCandidates batch @?= ["accepted"]
      case verifiedCandidateReceipts batch of
        [receipt] -> verifiedCandidate receipt @?= "accepted"
        receipts -> assertFailure $
          "unexpected verification receipts: " ++ show receipts
      failedCandidateGroups batch @?= 0
      let observations = verificationObservations batch
          failures = sum
            [ observationCount (LeanVerificationFailure failure) observations
            | failure <- [minBound .. maxBound]
            ]
          attempts = observationCount LeanVariantAttempted observations
          verified = observationCount LeanCandidateVerified observations
      attempts @?= 5
      failures @?= 4
      verified @?= 1
      attempts @?= failures + verified
  , testCase "failed groups do not consume the success quota" $ do
      attemptsRef <- newIORef ([] :: [String])
      let verdict candidate = do
            modifyIORef' attemptsRef (++ [candidate])
            pure $ if candidate == "accepted"
              then VariantAccepted
              else VariantRejected LeanErrorDiagnostic
      batch <- verifyCandidateGroups 1 verdict
        [["rejected-1", "rejected-2"], ["accepted"], ["unreached"]]
      attempted <- readIORef attemptsRef
      attempted @?= ["rejected-1", "rejected-2", "accepted"]
      verifiedCandidates batch @?= ["accepted"]
      failedCandidateGroups batch @?= 1
      observationCount LeanVariantAttempted
        (verificationObservations batch) @?= 3
  , testCase "empty groups fail without recording a variant attempt" $ do
      batch <- verifyCandidateGroups 1 (const (pure VariantAccepted))
        [[], ["accepted"]]
      verifiedCandidates batch @?= ["accepted"]
      failedCandidateGroups batch @?= 1
      leantObservationCodeEntries (verificationObservations batch) @?=
        [ ("lean-variant-attempted", 1)
        , ("lean-candidate-verified", 1)
        ]
  , testCase "quota and acceptance leave partial tails untouched" $ do
      zero <- verifyCandidateGroups 0
        (const (assertFailure "zero quota attempted a variant"
          >> pure VariantAccepted))
        (error "zero quota forced the group list")
      verifiedCandidates zero @?= ([] :: [String])
      verificationObservations zero @?= noObservations
      one <- verifyCandidateGroups 1 (const (pure VariantAccepted))
        (("accepted" : error "accepted group forced its variant tail")
          : error "success quota forced the group tail")
      verifiedCandidates one @?= ["accepted"]
      observationCount LeanVariantAttempted
        (verificationObservations one) @?= 1
  , testCase "keep indexed verification provenance lazy at both quotas" $ do
      zero <- verifyCandidateGroups 0
        (\_ -> assertFailure "zero quota attempted an indexed variant"
          >> pure VariantAccepted)
        (map detailedCandidateGroupVerificationVariants
          (error "zero quota forced the detailed group list"))
      verifiedCandidates zero @?= []
      verificationObservations zero @?= noObservations
      let group = detailedCandidateGroup RouteTypedCandidate
            ("accepted" : error "accepted group forced its spelling tail")
          variants = detailedCandidateGroupVerificationVariants group
      one <- verifyCandidateGroups 1
        (\variant -> pure $
          if detailedVerificationVariantText variant == "accepted"
            then VariantAccepted
            else VariantRejected LeanErrorDiagnostic)
        (variants : error "success quota forced the detailed group tail")
      case verifiedCandidates one of
        [accepted] -> do
          detailedVerificationVariantText accepted @?= "accepted"
          detailedVerificationVariantOrdinal accepted @?= 0
          detailedVerificationVariantRoute accepted @?= RouteTypedCandidate
          assertBool "a synthetic group acquired semantic authority"
            (isNothing
              $ detailedVerificationVariantSemanticSidecar accepted)
        accepted -> assertFailure $
          "unexpected indexed verification result: " ++ show accepted
      observationCount LeanVariantAttempted
        (verificationObservations one) @?= 1
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
          (FArr (FVar "a") (FVar "a")) [])
  , testCase "retain an explicitly headless provider query" $
      parseGoalSexp
          "(goal prop (query (roots) (head)) (var \"p\"))"
        @?= Right (ParsedGoal GoalProp
          (ProviderQuery [] Nothing) (FVar "p") [])
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

translationPreparationTests :: TestTree
translationPreparationTests = testGroup "prepared synthesis translation"
  [ testCase "retain the source goal before inserting caller premises" $ do
      let token = FAtom False "Demo.Token"
      prepared <- expectRight $ inspectExferencePreparation
        [] [("Demo.seed", token)] token token
      inspectedEngineFragment prepared @?= token
      inspectedFitFragment prepared @?= token
      let sourceGoal = inspectedSourceGoal prepared
      inspectedSearchGoal prepared @?=
        FunctionType sourceGoal sourceGoal
      map translatedPremiseName (inspectedCallerPremises prepared)
        @?= ["Demo.seed"]
      map translatedPremiseType (inspectedCallerPremises prepared)
        @?= [sourceGoal]
      inspectedConstructorPremises prepared @?= []
      inspectedSourceArrowCount prepared @?= 0
      inspectedProviderBindings prepared @?= []
      inspectedAllProviderAssignments prepared @?= []
  , testCase "retain a distinct fitting target outside renderer closures" $ do
      let engine = FAtom False "Demo.EngineTarget"
          fit = FAll True "a" (FArr (FVar "a") (FVar "a"))
      prepared <- expectRight $ inspectExferencePreparation
        [] [] engine fit
      inspectedEngineFragment prepared @?= engine
      inspectedFitFragment prepared @?= fit
      assertBool "engine and fitting targets collapsed"
        (inspectedEngineFragment prepared /= inspectedFitFragment prepared)
  , testCase "bind private providers, assignments, and exact family maps" $ do
      privateProvider <- expectRight $ mkIdentifier "leantProvider0"
      privateType <- expectRight $ mkIdentifier "LeantType0"
      let natural = FAtom False "Nat"
          box key argument =
            FApp False key (AppNominal "Demo.Box") [argument]
          provider = ProviderFragWithEvidence "Demo.chooseBox"
            (FAll False "a" (box "Demo.Box a" (FVar "a")))
            ["a"] [[ProviderInstantiationArgument 0 natural]]
          goal = box "Demo.Box Nat" natural
      prepared <- expectRight $ inspectExferencePreparation
        [provider] [] goal goal
      inspectedSourceGoal prepared @?= inspectedSearchGoal prepared
      case inspectedProviderBindings prepared of
        [binding] -> do
          inspectedProviderSourceName binding @?= "Demo.chooseBox"
          inspectedProviderPrivateName binding @?= privateProvider
          inspectedProviderPrivateSpelling binding @?= "leantProvider0"
          case inspectedProviderScheme binding of
            ForallType [binder] []
                (TypeApplication (TypeConstructor family)
                  (TypeVariable occurrence)) -> do
              family @?= privateType
              occurrence @?= binder
            scheme -> assertFailure $
              "expected the exact private provider scheme, got: "
                ++ show scheme
          case inspectedProviderAssignments binding of
            [assignment] -> do
              kindedProviderInstantiationAssignmentProvider assignment
                @?= privateProvider
              length
                  (kindedProviderInstantiationAssignmentArguments assignment)
                @?= 1
              inspectedAllProviderAssignments prepared @?= [assignment]
            assignments -> assertFailure $
              "expected one exact provider assignment, got: "
                ++ show assignments
        bindings -> assertFailure $
          "expected one private provider binding, got: " ++ show bindings
      fmap piLeanName (Map.lookup "leantProvider0"
          $ inspectedProviderMap prepared)
        @?= Just "Demo.chooseBox"
      Map.lookup "LeantType0" (inspectedTypeMap prepared)
        @?= Just "Demo.Box"
  , testCase "retain constructor and type maps from one structural family" $ do
      let flag = FParamInd "Demo.Flag" "Demo.Flag" []
            [("Demo.Flag.mk", [])]
      prepared <- expectRight $ inspectExferencePreparation
        [] [] flag flag
      inspectedConstructorPrivateNames prepared @?=
        ["LeantFamilyC0_0"]
      Map.lookup "LeantType0" (inspectedTypeMap prepared)
        @?= Just "Demo.Flag"
      inspectedFamiliesComplete prepared @?= True
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
  , testCase "retain original Lean names for provider type binders" $
      parseProviderSexp
          "(providers (provider \"Demo.global\" (binders \"a\") \
          \(alli \"s0\" (atom unsafe \"Demo.Token\"))))"
        @?= Right
          [ ProviderFragWithBinders "Demo.global"
              (FAll False "s0" (FAtom False "Demo.Token")) ["a"]
          ]
  , testCase "distinguish live empty binder metadata from legacy input" $
      parseProviderSexp
          "(providers (provider \"Demo.token\" (binders) \
          \(atom unsafe \"Demo.Token\")))"
        @?= Right
          [ ProviderFragWithBinders "Demo.token"
              (FAtom False "Demo.Token") []
          ]
  , testCase "read legacy provider candidates as unary assignments" $
      parseProviderSexp
          "(providers (provider \"Gap.global\" (binders \"a\") \
          \(candidates \
          \(all \"s0\" (-> (var \"s0\") (var \"s0\"))) \
          \(atom unsafe \"Nat\")) \
          \(alli \"i0\" (atom unsafe \"Gap.Token\"))))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.global"
              (FAll False "i0" (FAtom False "Gap.Token"))
              ["a"]
              [ [ ProviderInstantiationArgument 0
                    (FAll True "s0" (FArr (FVar "s0") (FVar "s0")))
                ]
              , [ProviderInstantiationArgument 0 (FAtom False "Nat")]
              ]
          ]
  , testCase "retain exact ordered provider instantiations" $
      parseProviderSexp
          "(providers (provider \"Gap.global\" (binders \"a\" \"b\") \
          \(instantiations \
          \(args (all \"s0\" (-> (var \"s0\") (var \"s0\"))) \
          \(all \"s1\" (-> (var \"s1\") \
          \(-> (var \"s1\") (var \"s1\"))))) \
          \(args (atom unsafe \"Nat\") (atom unsafe \"Bool\"))) \
          \(alli \"a\" (alli \"b\" (atom unsafe \"Gap.Token\")))))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.global"
              (FAll False "a"
                (FAll False "b" (FAtom False "Gap.Token")))
              ["a", "b"]
              [ [ ProviderInstantiationArgument 0
                    (FAll True "s0" (FArr (FVar "s0") (FVar "s0")))
                , ProviderInstantiationArgument 0
                    (FAll True "s1"
                      (FArr (FVar "s1")
                        (FArr (FVar "s1") (FVar "s1"))))
                ]
              , [ ProviderInstantiationArgument 0 (FAtom False "Nat")
                , ProviderInstantiationArgument 0 (FAtom False "Bool")
                ]
              ]
          ]
  , testCase "retain explicit provider argument kinds" $
      parseProviderSexp
          "(providers (provider \"Gap.global\" (binders \"F\" \"a\") \
          \(instantiations (args \
          \(kinded 1 (atom unsafe \"Gap.Wrap\")) \
          \(kinded 0 (atom unsafe \"Nat\")))) \
          \(alli \"F\" (alli \"a\" (-> \
          \(app unsafe \"F a\" (app-variable \"F\") (var \"a\")) \
          \(atom unsafe \"Gap.Token\"))))))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.global"
              (FAll False "F" (FAll False "a"
                (FArr
                  (FApp False "F a" (AppVariable "F") [FVar "a"])
                  (FAtom False "Gap.Token"))))
              ["F", "a"]
              [ [ ProviderInstantiationArgument 1
                    (FAtom False "Gap.Wrap")
                , ProviderInstantiationArgument 0 (FAtom False "Nat")
                ]
              ]
          ]
  , testCase "retain bounded exact Lean provider forall domains" $
      parseProviderSexp
          ("(providers (provider \"Gap.global\" (binders \"a\") "
            ++ "(instantiations (args (kinded 0 (exact "
            ++ "(domains prop type) "
            ++ "(alli \"P\" (all \"A\" (-> (var \"P\") "
            ++ "(var \"A\")))))))) (alli \"a\" "
            ++ "(atom unsafe \"Gap.Token\"))))")
        @?= Right
          [ ProviderFragWithEvidence "Gap.global"
              (FAll False "a" (FAtom False "Gap.Token"))
              ["a"]
              [ [ ProviderInstantiationExactArgument 0
                    (FAll False "P" $ FAll True "A" $
                      FArr (FVar "P") (FVar "A"))
                    [ProviderForallDomainProp, ProviderForallDomainType]
                ]
              ]
          ]
  , testCase "retain structured contextual exact provider assignments" $
      let contextual = FAll False "A" $
            FExactContext "Inhabited"
              [ExactContextFragmentArgument 0 (FVar "A")] $
              FArr (FVar "A") (FVar "A")
          higherContextual =
            FExactContext "Functor"
              [ExactContextFragmentArgument 1 (FAtom False "List")] $
              FArr (FAtom False "Nat") (FAtom False "Nat")
      in do
        parseProviderSexp
            ("(providers (provider \"ContextualOnly.chosen\" "
              ++ "(binders \"a\") (instantiations (args (kinded 0 "
              ++ "(exact (domains type) (alli \"A\" "
              ++ "(exact-context \"Inhabited\" (arguments "
              ++ "(kinded 0 (var \"A\"))) "
              ++ "(-> (var \"A\") (var \"A\")))))))) "
              ++ "(alli \"a\" "
              ++ "(atom unsafe \"ContextualOnly.Token\"))))")
          @?= Right
            [ ProviderFragWithEvidence "ContextualOnly.chosen"
                (FAll False "a" (FAtom False "ContextualOnly.Token"))
                ["a"]
                [ [ ProviderInstantiationExactArgument 0 contextual
                      [ProviderForallDomainType]
                  ]
                ]
            ]
        fragHasInstanceBinder contextual @?= True
        fragHasUnsupportedInstanceBinder contextual @?= False
        parseProviderSexp
            ("(providers (provider \"HigherContext.chosen\" "
              ++ "(binders \"a\") (instantiations (args (kinded 0 "
              ++ "(exact (domains) "
              ++ "(exact-context \"Functor\" (arguments "
              ++ "(kinded 1 (atom unsafe \"List\"))) "
              ++ "(-> (atom unsafe \"Nat\") "
              ++ "(atom unsafe \"Nat\"))))))) "
              ++ "(alli \"a\" "
              ++ "(atom unsafe \"HigherContext.Token\"))))")
          @?= Right
            [ ProviderFragWithEvidence "HigherContext.chosen"
                (FAll False "a" (FAtom False "HigherContext.Token"))
                ["a"]
                [ [ ProviderInstantiationExactArgument 0 higherContextual []
                  ]
                ]
            ]
        fragHasUnsupportedInstanceBinder higherContextual @?= False
  , testCase "retain canonical structural higher-kinded context arguments" $
      let natural = FAtom False "Nat"
          contextual = FExactContext "Structural.Context"
            [ ExactContextNominalArgument 2 "Prod" []
            , ExactContextNominalArgument 1 "Sum" [natural]
            ]
            (FArr natural natural)
      in do
        parseProviderSexp
            ("(providers (provider \"Structural.chosen\" "
              ++ "(binders \"selected\") "
              ++ "(instantiations (args (kinded 0 "
              ++ "(exact (domains) "
              ++ "(exact-context \"Structural.Context\" (arguments "
              ++ "(kinded 2 (nominal \"Prod\")) "
              ++ "(kinded 1 (nominal \"Sum\" "
              ++ "(atom unsafe \"Nat\")))) "
              ++ "(-> (atom unsafe \"Nat\") "
              ++ "(atom unsafe \"Nat\"))))))) "
              ++ "(alli \"selected\" "
              ++ "(atom unsafe \"Structural.Token\"))))")
          @?= Right
            [ ProviderFragWithEvidence "Structural.chosen"
                (FAll False "selected" (FAtom False "Structural.Token"))
                ["selected"]
                [ [ ProviderInstantiationExactArgument 0 contextual []
                  ]
                ]
            ]
        fragHasUnsupportedInstanceBinder contextual @?= False
  , testCase "reject structured contexts outside exact assignments" $ do
      let contextual =
            "(exact-context \"Gap.C\" (arguments) "
              ++ "(atom unsafe \"Gap.Token\"))"
          expected = Left
            "exact-context is only valid in an exact provider argument"
      parseGoalSexp
          ("(goal type (query (roots \"Gap\") (head)) "
            ++ contextual ++ ")")
        @?= expected
      parseProviderSexp
          ("(providers (provider \"Gap.bad\" " ++ contextual ++ "))")
        @?= expected
      parseProviderSexp
          ("(providers (provider \"Gap.global\" (binders \"a\") "
            ++ "(instantiations (args (kinded 0 " ++ contextual ++ "))) "
            ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))")
        @?= expected
      parseProviderSexp
          ("(providers (provider \"Gap.global\" (binders \"a\") "
            ++ "(instantiations (args (kinded 0 (nominal \"Gap.Wrap\" "
            ++ contextual ++ ")))) "
            ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))")
        @?= expected
  , testCase "retain a general Sort provider forall domain" $
      parseProviderSexp
          ("(providers (provider \"Gap.sort\" (binders \"a\") "
            ++ "(instantiations (args (kinded 0 (exact (domains sort) "
            ++ "(alli \"A\" (var \"A\")))))) "
            ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))")
        @?= Right
          [ ProviderFragWithEvidence "Gap.sort"
              (FAll False "a" (FAtom False "Gap.Token"))
              ["a"]
              [ [ ProviderInstantiationExactArgument 0
                    (FAll False "A" (FVar "A"))
                    [ProviderForallDomainSort]
                ]
              ]
          ]
  , testCase "reject invalid exact Lean provider forall domains" $ do
      let inventory domains =
            "(providers (provider \"Gap.global\" (binders \"a\") "
              ++ "(instantiations (args (kinded 0 (exact (domains "
              ++ domains
              ++ ") (atom unsafe \"Nat\"))))) "
              ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))"
      parseProviderSexp (inventory "effect") @?=
        Left "unknown exact Lean provider forall-domain tag"
      parseProviderSexp (inventory "prop") @?=
        Left "exact Lean provider forall-domain vector does not align with its fragment"
      parseProviderSexp
          ("(providers (provider \"Gap.global\" (binders \"a\") "
            ++ "(instantiations (args (kinded 0 (exact (domains \"prop\") "
            ++ "(atom unsafe \"Nat\"))))) "
            ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))") @?=
        Left "malformed exact Lean provider forall-domain vector"
      parseProviderSexp
          (inventory $ unwords $
            replicate (maximumProviderExactForallDomains + 1) "prop")
        @?= Left "exact Lean provider forall-domain vector is too long"
  , testCase "bound structured exact-context class arguments" $ do
      let inventory arguments =
            "(providers (provider \"Gap.global\" (binders \"a\") "
              ++ "(instantiations (args (kinded 0 (exact (domains) "
              ++ "(exact-context \"Gap.C\" (arguments " ++ arguments
              ++ ") (atom unsafe \"Nat\")))))) "
              ++ "(alli \"a\" (atom unsafe \"Gap.Token\"))))"
          proper = "(kinded 0 (atom unsafe \"Nat\"))"
      parseProviderSexp (inventory
          "(kinded 65 (atom unsafe \"Nat\"))")
        @?= Left "invalid exact-context class argument kind arity"
      parseProviderSexp (inventory $ unwords $
          replicate (maximumProviderInstantiationArguments + 1) proper)
        @?= Left "too many exact-context class arguments"
  , testCase "retain canonical nominal provider arguments" $
      parseProviderSexp
          "(providers (provider \"Gap.partial\" (binders \"F\") \
          \(instantiations (args \
          \(kinded 1 (nominal \"Gap.Pair\" \
          \(atom unsafe \"Nat\"))))) \
          \(alli \"F\" (-> \
          \(app unsafe \"F Bool\" (app-variable \"F\") \
          \(atom unsafe \"Bool\")) \
          \(atom unsafe \"Gap.Token\")))))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.partial"
              (FAll False "F"
                (FArr
                  (FApp False "F Bool" (AppVariable "F")
                    [FAtom False "Bool"])
                  (FAtom False "Gap.Token")))
              ["F"]
              [ [ ProviderInstantiationNominalArgument 1 "Gap.Pair"
                    [FAtom False "Nat"]
                ]
              ]
          ]
  , testCase "retain residual binary provider argument kinds" $
      parseProviderSexp
          "(providers (provider \"Gap.vacuous\" (binders \"F\") \
          \(instantiations (args \
          \(kinded 2 (nominal \"Gap.Triple\" \
          \(atom unsafe \"Nat\"))))) \
          \(alli \"F\" (atom unsafe \"Gap.Token\"))))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.vacuous"
              (FAll False "F" (FAtom False "Gap.Token"))
              ["F"]
              [ [ ProviderInstantiationNominalArgument 2 "Gap.Triple"
                    [FAtom False "Nat"]
                ]
              ]
          ]
  , testCase "reject invalid provider argument kinds" $ do
      let inventory arity =
            "(providers (provider \"Gap.global\" (binders \"F\") "
              ++ "(instantiations (args (kinded " ++ arity
              ++ " (atom unsafe \"Gap.Wrap\")))) "
              ++ "(alli \"F\" (atom unsafe \"Gap.Token\"))))"
          rejected arity = case parseProviderSexp (inventory arity) of
            Left "invalid provider instantiation argument kind arity" ->
              pure ()
            other -> assertFailure $
              "accepted invalid provider kind " ++ arity ++ ": " ++ show other
          accepted arity = case parseProviderSexp (inventory arity) of
            Right _ -> pure ()
            other -> assertFailure $
              "rejected valid provider kind " ++ arity ++ ": " ++ show other
      maximumProviderArgumentKindArity @?= 64
      maximumProviderArgumentKindArity @?=
        (maximumProviderInstantiationKindNodes - 1) `div` 2
      accepted "64"
      mapM_ rejected ["-1", "65", "not-a-kind"]
  , testCase "distinguish an explicit empty evidence block" $
      parseProviderSexp
          "(providers (provider \"Gap.token\" (binders) (candidates) \
          \(atom unsafe \"Gap.Token\")))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.token"
              (FAtom False "Gap.Token") [] []
          ]
  , testCase "accept an explicit empty exact-instantiation block" $
      parseProviderSexp
          "(providers (provider \"Gap.token\" (binders) (instantiations) \
          \(atom unsafe \"Gap.Token\")))"
        @?= Right
          [ ProviderFragWithEvidence "Gap.token"
              (FAtom False "Gap.Token") [] []
          ]
  , testCase "reject an empty exact argument vector" $
      parseProviderSexp
          "(providers (provider \"Gap.bad\" (binders \"a\") \
          \(instantiations (args)) \
          \(alli \"a\" (atom unsafe \"Gap.Token\"))))"
        @?= Left "provider instantiation assignment has no arguments"
  , testCase "retain legacy contextual evidence for fail-closed filtering" $
      let contextual = FAll False "a"
            (FInst "Inhabited a" (FVar "a"))
      in do
        parseProviderSexp
            "(providers (provider \"Gap.global\" (binders \"a\") \
            \(candidates (alli \"a\" \
            \(inst \"Inhabited a\" (var \"a\")))) \
            \(alli \"a\" (atom unsafe \"Gap.Token\"))))"
          @?= Right
            [ ProviderFragWithEvidence "Gap.global"
                (FAll False "a" (FAtom False "Gap.Token"))
                ["a"] [[ProviderInstantiationArgument 0 contextual]]
            ]
        fragHasInstanceBinder contextual @?= True
        fragHasUnsupportedInstanceBinder contextual @?= True
        fragHasInstanceBinder
          (FAll True "a" (FArr (FVar "a") (FVar "a"))) @?= False
  , testCase "rejects trailing inventory data" $
      parseProviderSexp "(providers) extra" @?=
        Left "trailing tokens in provider translation"
  ]

instanceImplicitTests :: TestTree
instanceImplicitTests = testGroup "instance-implicit synthesis"
  [ testCase "parse a render-only instance binder distinctly" $ do
      let body = FAll True "A"
            (FInst "Gap.C A" (FArr (FVar "A") (FVar "A")))
      parseGoalSexp
          "(goal type (query (roots \"Gap\") (head)) \
          \(all \"A\" (inst \"Gap.C A\" (-> (var \"A\") (var \"A\")))))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["Gap"] Nothing) body [])
      fragUnsafeAtoms body @?= ["Gap.C A"]
  , testCase "bind an erased instance before ordinary term arguments" $ do
      let goal = FAll True "A"
            (FInst "Gap.C A" (FArr (FVar "A") (FVar "A")))
          check engine =
            expectInstanceTerm "fun _ _ x => x"
              (synthesizeWithProviders engine 4096 [] goal)
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "reconstruct evidence for a constrained rank-N hypothesis" $ do
      let goal = FAll True "A" (FAll True "R"
            (FInst "Gap.C A"
              (FArr
                (FAll True "a"
                  (FInst "Gap.C a" (FArr (FVar "a") (FVar "R"))))
                (FArr (FVar "A") (FVar "R")))))
          check engine =
            expectInstanceTerm "fun _ _ _ f => f _"
              (synthesizeWithProviders engine 4096 [] goal)
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "withhold a refutation after erasing dictionary evidence" $ do
      let impossible = FAll True "A" (FInst "Gap.C A" FBot)
      case synthesizeWithProviders EngineDjinn 0 [] impossible of
        Right (SynthRefuted False) -> pure ()
        Right other -> assertFailure $
          "erased instance evidence produced the wrong verdict: "
            ++ outcomeTag other
        Left err -> assertFailure err
  ]
 where
  expectInstanceTerm expected outcome = case outcome of
    Right (SynthCandidates groups _) ->
      if any (== expected) (concat groups)
        then pure ()
        else assertFailure $
          "expected instance-aware candidate " ++ show expected
            ++ ", got: " ++ show groups
    Right other -> assertFailure $
      "unexpected instance-aware outcome: " ++ outcomeTag other
    Left err -> assertFailure err

providerScheduleTests :: TestTree
providerScheduleTests = testGroup "live provider widening"
  [ testCase "keep Exference on one rated full-inventory lane" $
      providerStages EngineExference ([1 .. 80] :: [Int]) @?=
        [(EngineExference, [1 .. 80])]
  , testCase "widen Djinn through sparse discovery-order prefixes" $
      providerStages EngineDjinn ([1 .. 80] :: [Int]) @?=
        [ (EngineDjinn, [1])
        , (EngineDjinn, [1 .. 4])
        , (EngineDjinn, [1 .. 16])
        , (EngineDjinn, [1 .. 80])
        ]
  , testCase "run only intermediate combined prefixes through Djinn" $
      providerStages EngineBoth ([1 .. 17] :: [Int]) @?=
        [ (EngineBoth, [1])
        , (EngineDjinn, [1 .. 4])
        , (EngineDjinn, [1 .. 16])
        , (EngineBoth, [1 .. 17])
        ]
  , testCase "deduplicate milestones at short inventory boundaries" $ do
      let inventory size = [1 .. size] :: [Int]
      providerStages EngineDjinn (inventory 0) @?= []
      providerStages EngineDjinn (inventory 1) @?= [(EngineDjinn, [1])]
      providerStages EngineDjinn (inventory 2) @?=
        [(EngineDjinn, [1]), (EngineDjinn, [1, 2])]
      providerStages EngineDjinn (inventory 4) @?=
        [(EngineDjinn, [1]), (EngineDjinn, [1 .. 4])]
      providerStages EngineBoth (inventory 1) @?=
        [(EngineBoth, [1])]
      providerStages EngineBoth (inventory 2) @?=
        [(EngineBoth, [1]), (EngineBoth, [1, 2])]
      providerStages EngineBoth (inventory 5) @?=
        [ (EngineBoth, [1])
        , (EngineDjinn, [1 .. 4])
        , (EngineBoth, [1 .. 5])
        ]
  ]

combinedEngineMergeTests :: TestTree
combinedEngineMergeTests = testGroup "combined-engine verification frontier"
  [ testCase "deduplicate before spending the candidate window" $
      takeDistinct 3
          (replicate 60 "same" ++ ["later", "last", "outside"])
        @?= ["same", "later", "last"]
  , testCase "reserve a bounded frontier for fresh Exference groups" $ do
      let groups prefix = [[prefix ++ show i] | i <- [1 :: Int .. 20]]
          merged = mergeCandidateGroups (groups "d") (groups "e")
      synthVerificationWindow EngineDjinn @?= synthMaxTried
      synthVerificationWindow EngineExference @?= synthMaxTried
      synthVerificationWindow EngineBoth @?= 2 * synthMaxTried
      take (synthVerificationWindow EngineBoth) merged @?=
        map (\i -> ["d" ++ show i]) [1 :: Int .. 4]
          ++ map (\i -> ["e" ++ show i]) [1 :: Int .. 12]
          ++ map (\i -> ["d" ++ show i]) [5 :: Int .. 12]
      take synthMaxShown merged @?=
        [["d1"], ["d2"], ["d3"], ["d4"], ["e1"]]
      merged !! (synthMaxTried - 1) @?= ["e8"]
      take 4 (drop (synthVerificationWindow EngineBoth) merged) @?=
        [["e13"], ["d13"], ["e14"], ["d14"]]
  , testCase "surface an oldest-first constrained choice in the shown frontier" $ do
      let token = FAtom False "Demo.Token"
          finite name = FParamInd name name [] [(name ++ ".mk", [])]
          inputs =
            [finite ("Demo.A" ++ show i) | i <- [1 :: Int .. 7]]
              ++ [finite "Demo.Good"]
          goal = foldr FArr token inputs
          provider = ProviderFragWithBinders "Demo.global"
            (FAll False "a" token) ["a"]
          isGood = any (isInfixOf "Demo.global (\171a\187 := Demo.Good)")
      case synthesizeWithProviders EngineBoth 1 [provider] goal of
        Right (SynthCandidates groups _) -> do
          any isGood (take (synthMaxShown - 1) groups) @?= False
          any isGood (take synthMaxShown groups) @?= True
        Right other -> assertFailure $
          "expected combined candidates, got: " ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "drain either ranked lane without losing its order" $ do
      mergeCandidateGroups [["d1"], ["d2"]]
          [["e1"], ["e2"], ["e3"]]
        @?= [["d1"], ["d2"], ["e1"], ["e2"], ["e3"]]
      mergeCandidateGroups [] [["e1"], ["e2"]]
        @?= [["e1"], ["e2"]]
      mergeCandidateGroups [["d1"], ["d2"]] []
        @?= [["d1"], ["d2"]]
  , testCase "deduplicate variants in final scheduled order" $ do
      mergeCandidateGroups
          [ ["d1", "d1", "d1-alt"]
          , []
          , ["d1-alt"]
          , ["d2"]
          , ["shared"]
          ]
          [["shared", "e1-alt"], ["d2", "e2"]]
        @?=
          [ ["d1", "d1-alt"]
          , ["d2"]
          , ["shared"]
          , ["e1-alt"]
          , ["e2"]
          ]
  , testCase "let early Exference spellings outrank late Djinn duplicates" $
      mergeCandidateGroups
          ( [ ["d1"], ["d2"], ["d3"], ["d4"] ]
          ++ [ ["d" ++ show i] | i <- [5 :: Int .. 12] ]
          ++ [ ["shared", "d-alt"] ]
          )
          [["shared", "e-alt"]]
        @?=
          ( [ ["d1"], ["d2"], ["d3"], ["d4"]
            , ["shared", "e-alt"]
            ]
          ++ [ ["d" ++ show i] | i <- [5 :: Int .. 12] ]
          ++ [["d-alt"]]
          )
  , testCase "remove checked spellings before spending a fresh lane quota" $ do
      let checked = Set.fromList ["old" ++ show i | i <- [1 :: Int .. 20]]
          groups = [["old" ++ show i] | i <- [1 :: Int .. 20]]
            ++ [["fresh", "old1"], ["later"]]
      withoutCheckedCandidates checked (SynthCandidates groups ["ranked"])
        @?= SynthCandidates [["fresh"], ["later"]] ["ranked"]
      withoutCheckedCandidates (Set.singleton "only")
          (SynthCandidates [["only"], []] ["empty"])
        @?= SynthNoTerm ["empty"]
  , testCase "reserve source-local quotas after checked-lane filtering" $ do
      let groups prefix count =
            [[prefix ++ show i] | i <- [1 :: Int .. count]]
          checked = Set.fromList ["e" ++ show i | i <- [1 :: Int .. 12]]
          merged = mergeOutcomesSkipping checked
            (SynthCandidates (groups "d" 30) [])
            (SynthCandidates (groups "e" 24) [])
      case merged of
        SynthCandidates candidateGroups _ ->
          take (synthVerificationWindow EngineBoth) candidateGroups @?=
            groups "d" 4
              ++ [["e" ++ show i] | i <- [13 :: Int .. 24]]
              ++ [["d" ++ show i] | i <- [5 :: Int .. 12]]
        other -> assertFailure $
          "expected filtered combined candidates, got: " ++ outcomeTag other
  , testCase "normalize empty rendered candidates without inventing evidence" $ do
      mergeOutcomes
          (SynthCandidates [[], []] ["djinn empty"])
          (SynthNoTerm ["exference empty"])
        @?= SynthNoTerm
          ["djinn empty", "exference: exference empty"]
      mergeOutcomes
          (SynthCandidates [] ["djinn empty"])
          (SynthCandidates [["e1"]] ["ranked"])
        @?= SynthCandidates [["e1"]]
          ["djinn empty", "exference: ranked"]
  , testCase "preserve Djinn refutations unless a real candidate wins" $ do
      mergeOutcomes (SynthRefuted True)
          (SynthCandidates [[]] ["empty"])
        @?= SynthRefuted True
      mergeOutcomes (SynthRefuted False) (SynthNoTerm ["none"])
        @?= SynthRefuted False
      mergeOutcomes (SynthRefuted True)
          (SynthCandidates [["e1"]] ["ranked"])
        @?= SynthCandidates [["e1"]] ["exference: ranked"]
  , testCase "retain note provenance for every candidate-bearing merge" $ do
      mergeOutcomes
          (SynthCandidates [["d1"]] ["smallest"])
          (SynthCandidates [["e1"]] ["rated"])
        @?= SynthCandidates [["d1"], ["e1"]]
          ["smallest", "exference: rated"]
      mergeOutcomes
          (SynthCandidates [["d1"]] ["smallest"])
          (SynthNoTerm ["finished"])
        @?= SynthCandidates [["d1"]]
          ["smallest", "exference: finished"]
      mergeOutcomes
          (SynthNoTerm ["bounded"])
          (SynthCandidates [["e1"]] ["rated"])
        @?= SynthCandidates [["e1"]]
          ["bounded", "exference: rated"]
  ]

typedCandidateRoutingTests :: TestTree
typedCandidateRoutingTests = testGroup "typed candidate rendering routes"
  [ testCase "render a supported Exference graph and preserve projection" $ do
      let token = FAtom False "Demo.TypedToken"
          goal = FArr token token
          detailed = synthesizeWithProvidersSkippingDetailed
            EngineExference 128 Set.empty [] goal
          compatibility = synthesizeWithProviders
            EngineExference 128 [] goal
      fmap projectDetailedSynthOutcome detailed @?= compatibility
      case detailed of
        Right (DetailedSynthCandidates (group : _) _) -> do
          detailedCandidateGroupRoute group @?= RouteTypedCandidate
          case detailedCandidateGroupSemanticSidecar group of
            Nothing -> assertFailure
              "typed graph rendering lost its semantic sidecar"
            Just semantic -> do
              case typedCandidateTermGraph
                  (typedCandidateSemanticCandidate semantic) of
                Left absence -> assertFailure $
                  "typed semantic candidate lost its graph: " ++ show absence
                Right _ -> pure ()
              case typedCandidateSemanticFingerprint semantic of
                Left fingerprintError -> assertFailure $
                  "typed graph fingerprint failed: " ++ show fingerprintError
                Right _ -> pure ()
        Right other -> assertFailure $
          "expected a typed Exference identity candidate, got: "
            ++ show other
        Left err -> assertFailure err
  , testCase "refuse callback acceptance without a semantic sidecar" $ do
      let synthetic = detailedCandidateGroup RouteTypedCandidate ["synthetic"]
          unreachableContract = LeanLengthContract
            { leanLengthContractSpine = LeanLengthSpineIdentity
                { leanLengthSpineFamilyName = "Demo.Unreachable"
                , leanLengthSpineZeroConstructorName =
                    "Demo.Unreachable.zero"
                , leanLengthSpineStepConstructorName =
                    "Demo.Unreachable.step"
                }
            , leanLengthContractSource = LengthContractSource
                { lengthContractPrecondition = LengthTruth True
                , lengthContractPostcondition = LengthTruth True
                }
            , leanLengthContractProviderLaws = []
            }
      batch <- verifyCandidateGroups 1
        (const $ pure VariantAccepted)
        [detailedCandidateGroupVerificationVariants synthetic]
      case verifiedCandidateReceipts batch of
        [verified] -> case prepareCheckedLengthHandoff
            unreachableContract verified of
          Left LengthHandoffMissingSemanticSidecar -> pure ()
          Left refusal -> assertFailure $
            "unexpected missing-sidecar refusal: " ++ show refusal
          Right _ -> assertFailure
            "callback acceptance invented a semantic sidecar"
        receipts -> assertFailure $
          "unexpected synthetic verification receipts: " ++ show receipts
  , testCase
      "seal one verified direct List provider into an exact Length problem" $
      do
        let element = FAtom False "Nat"
            listKey = "List Nat"
            list = FParamRec True "List" listKey [element]
              [ ("List.nil", [])
              , ("List.cons", [element, FAtom False listKey])
              ]
            provider = ProviderFrag "Demo.emptyList" list
            goal = list
            spine = LeanLengthSpineIdentity
              { leanLengthSpineFamilyName = "List"
              , leanLengthSpineZeroConstructorName = "List.nil"
              , leanLengthSpineStepConstructorName = "List.cons"
              }
            providerLaw = LeanLengthProviderLaw
              { leanLengthProviderLawName = "Demo.emptyList"
              , leanLengthProviderLawArgumentRoles = []
              , leanLengthProviderLawTransfer = LengthLiteral 0
              }
            contract = LeanLengthContract
              { leanLengthContractSpine = spine
              , leanLengthContractSource = LengthContractSource
                  { lengthContractPrecondition = LengthTruth True
                  , lengthContractPostcondition = LengthEqual
                      (LengthVariable LengthResult)
                      (LengthLiteral 0)
                  }
              , leanLengthContractProviderLaws = [providerLaw]
              }
        expected <- expectRight $ inspectExferencePreparation
          [provider] [] goal goal
        detailed <- expectRight $
          synthesizeWithProvidersSkippingDetailed
            EngineExference 256 Set.empty [provider] goal
        case detailed of
          DetailedSynthCandidates groups _ -> case
              [ group
              | group <- groups
              , detailedCandidateGroupVariants group == ["Demo.emptyList"]
              , not $ isNothing $ detailedCandidateGroupSemanticSidecar group
              ] of
            origin : _ -> do
              batch <- verifyCandidateGroups 1
                (const $ pure VariantAccepted)
                [detailedCandidateGroupVerificationVariants origin]
              case verifiedCandidateReceipts batch of
                [verified] -> do
                  handoff <- expectRight $
                    prepareCheckedLengthHandoff contract verified
                  case inspectedSemanticFamilyBindings expected of
                    [expectedFamily] ->
                      checkedLengthHandoffFamilyInspection handoff
                        @?= expectedFamily
                    families -> assertFailure $
                      "expected one exact List family binding, got: "
                        ++ show families
                  let candidate = checkedLengthProblemCandidate
                        $ checkedLengthHandoffProblem handoff
                  checkedLengthCandidateResult candidate @?=
                    LengthLiteral 0
                  query <- expectRight $
                    prepareLengthQueryFromHandoff handoff
                  lengthSMTLibQuerySchemaTag @?=
                    map (fromIntegral . fromEnum)
                      ("djex-length-z3-qf-lia-smtlib2/v1" :: String)
                  lengthSMTLibQueryLogic @?=
                    map (fromIntegral . fromEnum) ("QF_LIA" :: String)
                  lengthSMTLibQueryInputSymbols query @?= []
                  lengthSMTLibQueryInputValueRequestBytes query @?= Nothing
                  assertBool "the checked query retained no identity" $
                    not $ null $ fingerprintCanonicalBytes
                      $ lengthSMTLibQueryFingerprint query
                  behavioralProblemFingerprint
                      (lengthSMTLibQueryBehavioralProblem query) @?=
                    behavioralProblemFingerprint
                      (checkedLengthProblemBehavioralProblem
                        $ checkedLengthHandoffProblem handoff)
                  case validateLengthSMTLibCounterexample
                      defaultLengthEvaluationLimits query [] of
                    Right Nothing -> pure ()
                    Right Just{} -> assertFailure
                      "a false zero-input bad state produced evidence"
                    Left failure -> assertFailure $
                      "zero-input query replay failed: " ++ show failure
                  case inspectedProviderBindings expected of
                    [binding] ->
                      checkedLengthCandidateUsedProviders candidate @?=
                        [inspectedProviderPrivateName binding]
                    bindings -> assertFailure $
                      "expected one exact provider binding, got: "
                        ++ show bindings
                  case prepareCheckedLengthHandoff
                      (contract
                        { leanLengthContractProviderLaws =
                            [ providerLaw
                                { leanLengthProviderLawName =
                                    "Demo.missingProvider"
                                }
                            ]
                        })
                      verified of
                    Left (LengthHandoffProviderUnavailable providerName) ->
                      providerName @?= "Demo.missingProvider"
                    Left refusal -> assertFailure $
                      "unexpected missing-provider refusal: " ++ show refusal
                    Right _ -> assertFailure
                      "an unbound provider law entered Length sealing"
                  case prepareCheckedLengthHandoff
                      (contract
                        { leanLengthContractProviderLaws =
                            [ providerLaw
                                { leanLengthProviderLawArgumentRoles =
                                    [LengthSpineArgument]
                                }
                            ]
                        })
                      verified of
                    Left (LengthHandoffSessionRejected
                        (LengthSessionProviderInventoryRejected
                          (LengthProviderSummaryRejected 0 _
                            (LengthProviderRoleArityMismatch 0 1)))) ->
                      pure ()
                    Left refusal -> assertFailure $
                      "unexpected provider-role refusal: " ++ show refusal
                    Right _ -> assertFailure
                      "a provider law with the wrong role arity was sealed"
                  let cyclicProviderLaws =
                        providerLaw : cyclicProviderLaws
                  productive <- timeout 5000000 $ evaluate $
                    case prepareCheckedLengthHandoff
                        (contract
                          { leanLengthContractProviderLaws =
                              cyclicProviderLaws
                          })
                        verified of
                      Left (LengthHandoffSessionRejected
                          (LengthSessionProviderInventoryRejected
                            (LengthProviderSummaryLimitExceeded
                              maximumSummaries observedSummaries))) ->
                        observedSummaries == maximumSummaries + 1
                      _ -> False
                  productive @?= Just True
                  case prepareCheckedLengthHandoff
                      (contract
                        { leanLengthContractSpine = spine
                            { leanLengthSpineFamilyName =
                                "Demo.NotTheListFamily"
                            }
                        })
                      verified of
                    Left (LengthHandoffFamilyUnavailable family) ->
                      family @?= "Demo.NotTheListFamily"
                    Left refusal -> assertFailure $
                      "unexpected missing-family refusal: " ++ show refusal
                    Right _ -> assertFailure
                      "an unbound Lean family entered Length sealing"
                  case prepareCheckedLengthHandoff
                      (contract
                        { leanLengthContractSpine = spine
                            { leanLengthSpineZeroConstructorName =
                                "List.notNil"
                            }
                        })
                      verified of
                    Left (LengthHandoffConstructorUnavailable family ctor) ->
                      (family, ctor) @?= ("List", "List.notNil")
                    Left refusal -> assertFailure $
                      "unexpected missing-constructor refusal: "
                        ++ show refusal
                    Right _ -> assertFailure
                      "an unbound Lean constructor entered Length sealing"
                receipts -> assertFailure $
                  "unexpected direct-graph verification receipts: "
                    ++ show receipts
            _ -> assertFailure $
              "expected a unique direct List provider group, got: "
                ++ show groups
          other -> assertFailure $
            "expected direct List provider candidates, got: " ++ show other
  , testCase
      "resolve one polymorphic List provider scheme into Length sealing" $ do
      let parameter = FVar "a"
          natural = FAtom False "Nat"
          list key element = FParamRec True "List" key [element]
            [ ("List.nil", [])
            , ("List.cons", [element, FAtom False key])
            ]
          genericList = list "List a" parameter
          concreteList = list "List Nat" natural
          provider = ProviderFragWithEvidence "Demo.emptyPolyList"
            (FAll False "a" genericList)
            ["a"]
            [[ProviderInstantiationArgument 0 natural]]
          goal = concreteList
          contract = LeanLengthContract
            { leanLengthContractSpine = LeanLengthSpineIdentity
                { leanLengthSpineFamilyName = "List"
                , leanLengthSpineZeroConstructorName = "List.nil"
                , leanLengthSpineStepConstructorName = "List.cons"
                }
            , leanLengthContractSource = LengthContractSource
                { lengthContractPrecondition = LengthTruth True
                , lengthContractPostcondition = LengthEqual
                    (LengthVariable LengthResult)
                    (LengthLiteral 0)
                }
            , leanLengthContractProviderLaws =
                [ LeanLengthProviderLaw
                    { leanLengthProviderLawName = "Demo.emptyPolyList"
                    , leanLengthProviderLawArgumentRoles = []
                    , leanLengthProviderLawTransfer = LengthLiteral 0
                    }
                ]
            }
      expected <- expectRight $ inspectExferencePreparation
        [provider] [] goal goal
      case inspectedProviderBindings expected of
        [binding] -> case inspectedProviderScheme binding of
          ForallType [_] [] _ -> pure ()
          scheme -> assertFailure $
            "the retained provider scheme was not polymorphic: " ++ show scheme
        bindings -> assertFailure $
          "expected one polymorphic provider binding, got: " ++ show bindings
      detailed <- expectRight $
        synthesizeWithProvidersSkippingDetailed
          EngineExference 512 Set.empty [provider] goal
      case detailed of
        DetailedSynthCandidates groups _ -> case
            [ group
            | group <- groups
            , [variant] <- [detailedCandidateGroupVariants group]
            , "Demo.emptyPolyList" `isInfixOf` variant
            , not $ isNothing $ detailedCandidateGroupSemanticSidecar group
            ] of
          origin : _ -> do
            batch <- verifyCandidateGroups 1
              (const $ pure VariantAccepted)
              [detailedCandidateGroupVerificationVariants origin]
            case verifiedCandidateReceipts batch of
              [verified] -> do
                handoff <- expectRight $
                  prepareCheckedLengthHandoff contract verified
                let candidate = checkedLengthProblemCandidate
                      $ checkedLengthHandoffProblem handoff
                checkedLengthCandidateResult candidate @?=
                  LengthLiteral 0
                case inspectedProviderBindings expected of
                  [binding] ->
                    checkedLengthCandidateUsedProviders candidate @?=
                      [inspectedProviderPrivateName binding]
                  bindings -> assertFailure $
                    "expected one resolved provider binding, got: "
                      ++ show bindings
              receipts -> assertFailure $
                "unexpected polymorphic verification receipts: "
                  ++ show receipts
          _ -> assertFailure $
            "expected one direct polymorphic provider group, got: "
              ++ show groups
        other -> assertFailure $
          "expected polymorphic provider candidates, got: " ++ show other
  , testCase
      "retain exact preparation and strict request authority in the sidecar" $
      do
        let token = FAtom False "Demo.AuthorityToken"
            extras = [("Demo.seed", token)]
        expected <- expectRight $ inspectExferencePreparation
          [] extras token token
        detailed <- expectRight $ synthesizeTunedDetailed
          EngineExference 128 (candidateWindow, Nothing)
          extras token token
        case detailed of
          DetailedSynthCandidates groups _ ->
            case
              [ (group, semantic)
              | group <- groups
              , Just semantic <-
                  [detailedCandidateGroupSemanticSidecar group]
              ] of
              (origin, semantic) : _ -> do
                let authority =
                      typedCandidateSemanticAuthorityInspection semantic
                    table = inspectedAuthorityNameTable authority
                    convert variable = FlexibleVariable (table Map.! variable)
                    request = inspectedAuthorityRequest authority
                    options = requestOptions request
                inspectedAuthorityPreparation authority @?= expected
                inspectedAuthorityInventory authority @?=
                  typedCandidateSemanticInventory semantic
                inspectedAuthorityConvertedSourceGoal authority @?=
                  fmap convert (inspectedSourceGoal expected)
                requestGoal request @?=
                  fmap convert (inspectedSearchGoal expected)
                assertBool
                  "the premise-extended request collapsed to the source goal"
                  (requestGoal request
                    /= inspectedAuthorityConvertedSourceGoal authority)
                requestContexts request @?= []
                exferenceAllowUnused options @?= False
                exferenceMaximumSteps options @?= 128
                exferenceMultiConstructorPatterns options @?= True
                exferenceMaximumQueueSize options @?= Just 1024
                inspectedAuthorityProviderAssignments authority @?= []
                batch <- verifyCandidateGroups 1
                  (const $ pure VariantAccepted)
                  [detailedCandidateGroupVerificationVariants origin]
                let unreachableContract = LeanLengthContract
                      { leanLengthContractSpine = LeanLengthSpineIdentity
                          { leanLengthSpineFamilyName = "Demo.Unreachable"
                          , leanLengthSpineZeroConstructorName =
                              "Demo.Unreachable.zero"
                          , leanLengthSpineStepConstructorName =
                              "Demo.Unreachable.step"
                          }
                      , leanLengthContractSource = LengthContractSource
                          { lengthContractPrecondition = LengthTruth True
                          , lengthContractPostcondition = LengthTruth True
                          }
                      , leanLengthContractProviderLaws = []
                      }
                case verifiedCandidateReceipts batch of
                  [verified] -> case prepareCheckedLengthHandoff
                      unreachableContract verified of
                    Left LengthHandoffPremisesPresent -> pure ()
                    Left refusal -> assertFailure $
                      "unexpected premise-backed refusal: " ++ show refusal
                    Right _ -> assertFailure
                      "a premise-retargeted candidate entered Length sealing"
                  receipts -> assertFailure $
                    "unexpected premise verification receipts: "
                      ++ show receipts
              [] -> assertFailure $
                "expected a typed sidecar for the premise-backed candidate: "
                  ++ show groups
          other -> assertFailure $
            "expected premise-backed candidates, got: " ++ show other
  , testCase
      "retain provider authority and the accepted original spelling ordinal" $
      do
        privateProvider <- expectRight $ mkIdentifier "leantProvider0"
        let void = FParamInd "Demo.Void" "Demo.Void" [] []
            polytype = FAll True "p" (FArr (FVar "p") (FVar "p"))
            provider = ProviderFragWithEvidence "Demo.impossible"
              (FAll False "a" void) ["a"]
                [[ProviderInstantiationArgument 0 polytype]]
        expected <- expectRight $ inspectExferencePreparation
          [provider] [] void void
        detailed <- expectRight $
          synthesizeWithProvidersSkippingDetailed
            EngineExference 128 Set.empty [provider] void
        case detailed of
          DetailedSynthCandidates groups _ ->
            case
              [ (group, semantic)
              | group <- groups
              , length (detailedCandidateGroupVariants group) >= 2
              , Just semantic <-
                  [detailedCandidateGroupSemanticSidecar group]
              ] of
              (origin, semantic) : _ -> do
                let authority =
                      typedCandidateSemanticAuthorityInspection semantic
                inspectedAuthorityPreparation authority @?= expected
                case inspectedProviderBindings expected of
                  [binding] -> do
                    inspectedProviderSourceName binding @?= "Demo.impossible"
                    inspectedProviderPrivateName binding @?= privateProvider
                    length (inspectedProviderAssignments binding) @?= 1
                  bindings -> assertFailure $
                    "expected one retained provider binding, got: "
                      ++ show bindings
                case inspectedAuthorityProviderAssignments authority of
                  [assignment] -> do
                    kindedProviderInstantiationAssignmentProvider assignment
                      @?= privateProvider
                    length
                        (kindedProviderInstantiationAssignmentArguments
                          assignment)
                      @?= 1
                  assignments -> assertFailure $
                    "expected one converted provider assignment, got: "
                      ++ show assignments
                Map.keys
                    (exferenceRatingOverrides
                      $ inspectedAuthorityPolicy authority)
                  @?= [privateProvider]
                let variants =
                      detailedCandidateGroupVerificationVariants origin
                    verdict variant = pure $ case
                        detailedVerificationVariantOrdinal variant of
                      0 -> VariantRejected LeanErrorDiagnostic
                      1 -> VariantAccepted
                      ordinal -> error $
                        "verification forced later renderer ordinal "
                          ++ show ordinal
                batch <- verifyCandidateGroups 1 verdict [variants]
                failedCandidateGroups batch @?= 0
                observationCount LeanVariantAttempted
                  (verificationObservations batch) @?= 2
                case verifiedCandidates batch of
                  [accepted] -> do
                    detailedVerificationVariantOrdinal accepted @?= 1
                    detailedVerificationVariantText accepted @?=
                      detailedCandidateGroupVariants origin !! 1
                    detailedVerificationVariantRoute accepted @?=
                      RouteTypedCandidate
                    case detailedVerificationVariantSemanticSidecar
                        accepted of
                      Just acceptedSemantic -> do
                        typedCandidateSemanticCandidate acceptedSemantic @?=
                          typedCandidateSemanticCandidate semantic
                        typedCandidateSemanticInventory acceptedSemantic @?=
                          typedCandidateSemanticInventory semantic
                        typedCandidateSemanticAuthorityInspection
                            acceptedSemantic
                          @?= authority
                      Nothing -> assertFailure
                        "accepted renderer variant lost its typed sidecar"
                    assertBool
                      "verification display exposed opaque run authority"
                      (not $ "ExferenceRunAuthority" `isInfixOf` show accepted)
                  accepted -> assertFailure $
                    "unexpected accepted renderer variants: "
                      ++ show accepted
                let unreachableContract = LeanLengthContract
                      { leanLengthContractSpine = LeanLengthSpineIdentity
                          { leanLengthSpineFamilyName = "Demo.unreachable"
                          , leanLengthSpineZeroConstructorName =
                              "Demo.unreachable.zero"
                          , leanLengthSpineStepConstructorName =
                              "Demo.unreachable.step"
                          }
                      , leanLengthContractSource = LengthContractSource
                          { lengthContractPrecondition = LengthTruth True
                          , lengthContractPostcondition = LengthTruth True
                          }
                      , leanLengthContractProviderLaws = []
                      }
                case verifiedCandidateReceipts batch of
                  [verified] -> case prepareCheckedLengthHandoff
                      unreachableContract verified of
                    Left (LengthHandoffRendererNotUnique alternatives) ->
                      assertBool
                        "a multi-spelling renderer reported one alternative"
                        (alternatives >= 2)
                    Left refusal -> assertFailure $
                      "renderer ambiguity reached a later authority phase: "
                        ++ show refusal
                    Right _ -> assertFailure
                      "an ordinal alone certified an ambiguous rendering"
                  receipts -> assertFailure $
                    "unexpected multi-spelling verification receipts: "
                      ++ show receipts
              [] -> assertFailure $
                "expected a multi-spelling typed provider group, got: "
                  ++ show groups
          other -> assertFailure $
            "expected provider-backed candidates, got: " ++ show other
  , testCase "use compatibility only for explicit typed graph absence" $ do
      let outer = FAtom False "Demo.Outer"
          goal = FArr outer
            (FAll True "a" (FArr (FVar "a") (FVar "a")))
          detailed = synthesizeWithProvidersSkippingDetailed
            EngineExference 256 Set.empty [] goal
          compatibility = synthesizeWithProviders
            EngineExference 256 [] goal
      fmap projectDetailedSynthOutcome detailed @?= compatibility
      case detailed of
        Right (DetailedSynthCandidates groups _) -> do
          assertBool
            ("expected an explicit nested-forall fallback, got: "
              ++ show groups)
            (any
              ((== RouteLegacyCandidateFallback)
                . detailedCandidateGroupRoute)
              groups)
          assertBool
            "a compatibility-only rendering retained typed graph semantics"
            (all
              (isNothing . detailedCandidateGroupSemanticSidecar)
              (filter
                ((== RouteLegacyCandidateFallback)
                  . detailedCandidateGroupRoute)
                groups))
        Right other -> assertFailure $
          "expected a fallback Exference candidate, got: " ++ show other
        Left err -> assertFailure err
  , testCase "keep relaxed unused-binder candidates fail-closed" $ do
      let left = FAtom False "Demo.RelaxedLeft"
          right = FAtom False "Demo.RelaxedRight"
          goal = FArr left (FArr right left)
      case synthesizeWithProvidersSkippingDetailed
          EngineExference 128 Set.empty [] goal of
        Right (DetailedSynthCandidates groups _) -> do
          assertBool
            ("expected a relaxed wildcard rendering, got: " ++ show groups)
            (any
              (any ("_" `isInfixOf`) . detailedCandidateGroupVariants)
              groups)
          assertBool
            "a relaxed compatibility projection claimed typed authority"
            (all
              (isNothing . detailedCandidateGroupSemanticSidecar)
              groups)
          assertBool
            "a relaxed compatibility projection claimed the typed route"
            (all
              ((== RouteLegacyCandidateFallback)
                . detailedCandidateGroupRoute)
              groups)
        Right other -> assertFailure $
          "expected a relaxed candidate, got: " ++ show other
        Left err -> assertFailure err
  , testCase "never retry a failed typed rendering through compatibility" $ do
      let rendered = renderCandidateByAvailability
            (\typed -> Left ("typed render rejected: " ++ typed))
            (\_ -> error "legacy renderer was retried")
            (Right "typed-expression" :: Either () String)
            (error "compatibility candidate was forced" :: String)
            id
      rendered @?=
        ( RouteTypedCandidate
        , Left "typed render rejected: typed-expression"
        )
  , testCase "consult compatibility on an explicit absence only" $ do
      let rendered
            :: (CandidateRenderingRoute, Either String [String])
          rendered = renderCandidateByAvailability
            (\_ -> error "typed renderer was forced")
            (\legacy -> Right ["rendered " ++ legacy])
            (Left () :: Either () String)
            "legacy-expression"
            id
      rendered @?=
        (RouteLegacyCandidateFallback, Right ["rendered legacy-expression"])
  , testCase "count each bounded Exference group independently of Lean" $ do
      candidateRenderingRouteMetric RouteUnobserved @?= Nothing
      candidateRenderingRouteMetric RouteLegacyCandidateFallback
        @?= Just LegacyCandidateFallback
      candidateRenderingRouteMetric RouteTypedCandidate
        @?= Just TypedCandidateRendered
      let observations = candidateRenderingRouteObservations
            [ RouteTypedCandidate
            , RouteUnobserved
            , RouteLegacyCandidateFallback
            , RouteTypedCandidate
            ]
      observationCount TypedCandidateRendered observations @?= 2
      observationCount LegacyCandidateFallback observations @?= 1
      observationCount LeanVariantAttempted observations @?= 0
  , testCase "keep route counts orthogonal to verifier invariants" $ do
      batch <- verifyCandidateGroups 1
        (\candidate -> pure $ if candidate == "accepted"
          then VariantAccepted
          else VariantRejected LeanErrorDiagnostic)
        [["rejected", "accepted"]]
      let combined = candidateRenderingRouteObservations
            [RouteTypedCandidate, RouteLegacyCandidateFallback]
            <> verificationObservations batch
          attempted = observationCount LeanVariantAttempted combined
          failed = sum
            [ observationCount (LeanVerificationFailure failure) combined
            | failure <- [minBound .. maxBound]
            ]
          verified = observationCount LeanCandidateVerified combined
      attempted @?= failed + verified
      attempted @?= 2
      observationCount TypedCandidateRendered combined @?= 1
      observationCount LegacyCandidateFallback combined @?= 1
  , testCase "deduplicate on variants and retain the first surviving route" $ do
      let typed = detailedCandidateGroup RouteTypedCandidate ["shared"]
          fallback = detailedCandidateGroup
            RouteLegacyCandidateFallback ["shared", "fallback-alt"]
          merged = mergeDetailedCandidateGroups [typed] [fallback]
      map detailedCandidateGroupVariants merged
        @?= mergeCandidateGroups [["shared"]]
          [["shared", "fallback-alt"]]
      map detailedCandidateGroupRoute merged @?=
        [RouteTypedCandidate, RouteLegacyCandidateFallback]
      map
          (map detailedVerificationVariantOrdinal
            . detailedCandidateGroupVerificationVariants)
          merged
        @?= [[0], [1]]
      takeDistinctOn detailedCandidateGroupVariants 2
          [ fallback
          , detailedCandidateGroup RouteTypedCandidate ["shared", "fallback-alt"]
          , typed
          ]
        @?= [fallback, typed]
  , testCase
      "preserve only the originating typed sidecar through filtering and merge" $
      do
        let token = FAtom False "Demo.SemanticToken"
            goal = FArr token token
        case synthesizeWithProvidersSkippingDetailed
            EngineExference 128 Set.empty [] goal of
          Right (DetailedSynthCandidates (origin : _) _) ->
            case detailedCandidateGroupSemanticSidecar origin of
              Nothing -> assertFailure
                "expected an originating typed semantic sidecar"
              Just originalSemantic -> do
                let filtered = withoutCheckedDetailedCandidates
                      (Set.singleton "not-this-candidate")
                      (DetailedSynthCandidates [origin] [])
                case filtered of
                  DetailedSynthCandidates [survivor] _ ->
                    case detailedCandidateGroupSemanticSidecar survivor of
                      Nothing -> assertFailure
                        "filtering discarded the originating semantic sidecar"
                      Just survivorSemantic -> do
                        typedCandidateSemanticCandidate survivorSemantic
                          @?= typedCandidateSemanticCandidate originalSemantic
                        typedCandidateSemanticInventory survivorSemantic
                          @?= typedCandidateSemanticInventory originalSemantic
                        typedCandidateSemanticFingerprint survivorSemantic
                          @?= typedCandidateSemanticFingerprint originalSemantic
                  other -> assertFailure $
                    "unexpected filtered typed outcome: " ++ show other
                let earlier = detailedCandidateGroup RouteUnobserved
                      (detailedCandidateGroupVariants origin)
                    merged = mergeDetailedCandidateGroups [earlier] [origin]
                assertBool
                  "observable semantic ownership was absent from equality"
                  (origin /= earlier)
                merged @?= [earlier]
                assertBool
                  "a later duplicate transferred its sidecar to earlier text"
                  (all
                    (isNothing . detailedCandidateGroupSemanticSidecar)
                    merged)
          Right other -> assertFailure $
            "expected a typed semantic candidate, got: " ++ show other
          Left err -> assertFailure err
  , testCase "drop typed semantics when wrapping a candidate as a new term" $ do
      let token = FAtom False "Demo.WrappedToken"
          goal = FArr token token
      case synthesizeWithProvidersSkippingDetailed
          EngineExference 128 Set.empty [] goal of
        Right (DetailedSynthCandidates (origin : _) _) -> do
          assertBool
            "expected an originating typed semantic sidecar"
            (not $ isNothing $ detailedCandidateGroupSemanticSidecar origin)
          let wrap term = "Classical.byContradiction (" ++ term ++ ")"
              wrapped =
                mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
                  wrap origin
          detailedCandidateGroupRoute wrapped
            @?= detailedCandidateGroupRoute origin
          detailedCandidateGroupVariants wrapped
            @?= map wrap (detailedCandidateGroupVariants origin)
          map detailedVerificationVariantOrdinal
              (detailedCandidateGroupVerificationVariants wrapped)
            @?= map detailedVerificationVariantOrdinal
              (detailedCandidateGroupVerificationVariants origin)
          assertBool
            "Classical.byContradiction retained stale typed semantics"
            (isNothing $ detailedCandidateGroupSemanticSidecar wrapped)
        Right other -> assertFailure $
          "expected a typed candidate to wrap, got: " ++ show other
        Left err -> assertFailure err
  , testCase "filter routes as sidecars and preserve old merge projection" $ do
      let checked = Set.singleton "old"
          typed = detailedCandidateGroup RouteTypedCandidate
            ["old", "fresh", "later"]
          fallback = detailedCandidateGroup
            RouteLegacyCandidateFallback ["fallback"]
          filtered = withoutCheckedDetailedCandidates checked
            (DetailedSynthCandidates [typed] ["ranked"])
      projectDetailedSynthOutcome filtered @?=
        withoutCheckedCandidates checked
          (SynthCandidates [["old", "fresh", "later"]] ["ranked"])
      case filtered of
        DetailedSynthCandidates [survivor] notes -> do
          detailedCandidateGroupVariants survivor @?= ["fresh", "later"]
          map detailedVerificationVariantOrdinal
              (detailedCandidateGroupVerificationVariants survivor)
            @?= [1, 2]
          notes @?= ["ranked"]
        other -> assertFailure $
          "unexpected filtered ordinal outcome: " ++ show other
      let detailedMerged = mergeDetailedOutcomesSkipping checked
            (DetailedSynthCandidates [typed] ["smallest"])
            (DetailedSynthCandidates [fallback] ["rated"])
          compatibilityMerged = mergeOutcomesSkipping checked
            (SynthCandidates [["old", "fresh", "later"]] ["smallest"])
            (SynthCandidates [["fallback"]] ["rated"])
      projectDetailedSynthOutcome detailedMerged @?= compatibilityMerged
      case detailedMerged of
        DetailedSynthCandidates groups _ ->
          map detailedCandidateGroupRoute groups @?=
            [RouteTypedCandidate, RouteLegacyCandidateFallback]
        other -> assertFailure $ "unexpected detailed merge: " ++ show other
  , testCase "keep bounded detailed projections lazy in poison tails" $ do
      let first = detailedCandidateGroup RouteTypedCandidate ["first"]
          poison = error "entered detailed candidate tail"
          groups = first : poison
          outcome = Right (DetailedSynthCandidates groups [])
      forceDetailedOutcome 1 outcome @?= length "first"
      let routeObservations = candidateRenderingRouteObservations
            (map detailedCandidateGroupRoute (take 1 groups))
      observationCount TypedCandidateRendered routeObservations @?= 1
      observationCount LegacyCandidateFallback routeObservations @?= 0
      case projectDetailedSynthOutcome
          (DetailedSynthCandidates groups []) of
        SynthCandidates projected _ -> take 1 projected @?= [["first"]]
        other -> assertFailure $ "unexpected projection: " ++ show other
      take 1 (mergeDetailedCandidateGroups groups poison) @?= [first]
  ]

providerEngineTests :: TestTree
providerEngineTests = testGroup "foreign providers"
  [ testCase "override a provider-free refutation with a real provider" $ do
      let provider = ProviderFrag "Demo.falseProof" FBot
          check engine = case
              synthesizeWithProviders engine 128 [provider] FBot of
            Right (SynthCandidates groups _) ->
              assertBool
                ("the provider did not override the provider-free refutation \
                 \in " ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== "Demo.falseProof") (concat groups))
            Right other -> assertFailure $
              "unexpected provider-refutation outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "override an empty-family refutation with exact rank-N evidence" $ do
      let void = FParamInd "Demo.Void" "Demo.Void" [] []
          polytype = FAll True "p" (FArr (FVar "p") (FVar "p"))
          provider = ProviderFragWithEvidence "Demo.impossible"
            (FAll False "a" void) ["a"]
              [[ProviderInstantiationArgument 0 polytype]]
          exact = (==
            "Demo.impossible («a» := (∀ (a0_0 : _), a0_0 → a0_0))")
          check engine = case
              synthesizeWithProviders engine 128 [provider] void of
            Right (SynthCandidates groups _) ->
              assertBool
                ("the exact provider did not override the empty-family \
                 \refutation in " ++ synthEngineName engine ++ ": "
                   ++ show groups)
                (any exact (concat groups))
            Right other -> assertFailure $
              "unexpected exact provider-refutation outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain a refutation when providers cannot inhabit the goal" $ do
      let provider = ProviderFrag "Demo.falseEndomorphism" (FArr FBot FBot)
      case synthesizeWithProviders EngineDjinn 128 [provider] FBot of
        Right (SynthRefuted True) -> pure ()
        Right other -> assertFailure $
          "an unusable provider replaced the sound refutation: "
            ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "render an exact qualified provider through Exference" $ do
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
  , testCase "render an exact qualified provider through Djinn" $ do
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          provider = ProviderFrag "Demo.toBool" (FArr natural boolean)
      firstGroup
          (synthesizeWithProviders EngineDjinn 256 [provider]
            (FArr natural boolean))
        @?= ["Demo.toBool"]
  , testCase "keep distinct same-typed arguments in the Djinn frontier" $ do
      let value = FAtom False "Demo.Value"
          combine = FArr value (FArr value value)
          distractor = FArr value value
          goal = FArr value (FArr value value)
          extras =
            [ ("Demo.combine", combine)
            , ("Demo.first", distractor)
            , ("Demo.second", distractor)
            ]
      case synthesizeWith EngineDjinn 0 extras goal goal of
        Right (SynthCandidates groups _) ->
          assertBool "the verification frontier omitted Demo.combine x y" $
            any (elem "fun x y => Demo.combine x y")
              (take synthMaxTried groups)
        Right other -> assertFailure $
          "unexpected repeated-domain synthesis outcome: " ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "reuse a provider through both engines" $ do
      let natural = FAtom False "Nat"
          provider = ProviderFrag "Demo.zero" natural
      firstGroup
          (synthesizeWithProviders EngineBoth 128 [provider] natural)
        @?= ["Demo.zero"]
  , testCase "compose two polymorphic providers through Djinn" $ do
      let natural = FAtom False "Nat"
          parameter = FVar "a"
          family headName key argument =
            FApp False key (AppNominal headName) [argument]
          input argument = family "Demo.Input" "Demo.Input a" argument
          middle argument = family "Demo.Middle" "Demo.Middle a" argument
          output argument = family "Demo.Output" "Demo.Output a" argument
          providers =
            [ ProviderFrag "Demo.consume" (FAll False "a"
                (FArr (middle parameter) (output parameter)))
            , ProviderFrag "Demo.produce" (FAll False "a"
                (FArr (input parameter) (middle parameter)))
            ]
          goal = FArr
            (family "Demo.Input" "Demo.Input Nat" natural)
            (family "Demo.Output" "Demo.Output Nat" natural)
          candidates = firstGroup
            (synthesizeWithProviders EngineDjinn 256 providers goal)
      if any (\candidate ->
          "Demo.consume" `isInfixOf` candidate
            && "Demo.produce" `isInfixOf` candidate) candidates
        then pure ()
        else assertFailure $
          "expected a composed Djinn provider candidate, got: "
            ++ show candidates
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
              [FAll True "b" (FArr (FVar "b") (FVar "b"))]))
          [])
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
  , testCase "instantiate a local scheme at a closed query type" $ do
      let mono = FAtom False "QueryClosed.Mono"
          token = FAtom False "QueryClosed.Token"
          indexed key argument = FApp False key
            (AppNominal "QueryClosed.Indexed") [argument]
          variable = FVar "a"
          hypothesis = FAll True "a"
            (FArr (FArr variable token)
              (FArr variable (indexed "QueryClosed.Indexed a" variable)))
          goal = FArr hypothesis
            (FArr (FArr mono token)
              (FArr mono
                (indexed "QueryClosed.Indexed QueryClosed.Mono" mono)))
          check engine = expectTerm "f _"
            (synthesizeWithProviders engine 128 [] goal)
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "instantiate a foreign polymorphic family provider" $
      let provider = ProviderFrag "Demo.polyWrap" nominalHypothesis
          goal = wrap "Demo.Wrap ((b : Type) \8594 b \8594 b)" polytype
          check engine = expectTerm "Demo.polyWrap"
            (synthesizeWithProviders engine 1024 [provider] goal)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "apply a foreign polymorphic provider at rank N" $
      let argument = FVar "a"
          provider = ProviderFrag "Demo.sealedBox"
            (FAll False "a" (FArr argument
              (wrap "Demo.Wrap a" argument)))
          goal = FArr polytype
            (wrap "Demo.Wrap ((b : Type) \8594 b \8594 b)" polytype)
          check engine = expectTerm "Demo.sealedBox"
            (synthesizeWithProviders engine 1024 [provider] goal)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain structured rank-N provider elimination across engines" $ do
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          provider = ProviderFrag "Demo.source" $
            FProd
              (FAll True "A" (FArr (FVar "A") result))
              FTop
          goal = FArr source result
          check engine = case
              synthesizeWithProviders engine 1024 [provider] goal of
            Right (SynthCandidates groups _) ->
              let candidates = concat groups
                  fitted term =
                    "Demo.source" `isInfixOf` term
                      && case engine of
                        EngineDjinn ->
                          "match Demo.source with" `isInfixOf` term
                        EngineExference -> "f _ x" `isInfixOf` term
                        EngineBoth -> "f _ x" `isInfixOf` term
              in assertBool
                ("structured provider field was not instantiated in "
                  ++ synthEngineName engine ++ ": " ++ show candidates)
                (any fitted candidates)
            Right other -> assertFailure $
              "unexpected structured-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "specialize provider results from impredicative arguments" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" $
            FArr (FVar "A") (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.box" Nothing providerFrag)
          expression = Lambda [Bind "polymorphic", Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (Apply (Global providerName) (Local "polymorphic"))
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr identity (FArr natural natural)) expression
        @?= Right
          [ "fun f x => let ⟨g, _⟩ := Demo.box f; g _ x"
          , "fun f x => let ⟨g, _⟩ := Demo.box (f _); g _ x"
          ]
  , testCase "specialize provider results from specified type arguments" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      visibleIdentity <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["B"] []
          (FunctionType (TypeVariable "B") (TypeVariable "B"))
          :: Type String)
      let -- Deliberately collide with the renderer's private fresh prefix;
          -- retained source evidence must be reserved before opening A.
          identity = FAll True "\0leant-render-bound:0"
            (FArr
              (FVar "\0leant-render-bound:0")
              (FVar "\0leant-render-bound:0"))
          implicitIdentity = FAll False "C"
            (FArr (FVar "C") (FVar "C"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.box" (Just ["A"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleIdentity]
                      , paiSourceArguments =
                          [ProviderInstantiationArgument 0 identity]
                      }
                  , ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleIdentity]
                      , paiSourceArguments =
                          [ProviderInstantiationArgument 0 implicitIdentity]
                      }
                  ]
              }
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (VisibleTypeApplication (Global providerName) visibleIdentity)
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural natural) expression
        @?= Right
          [ "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ (a0_0 : _), a0_0 → a0_0)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : _}, a0_0 → a0_0)); f x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ (a0_0 : Type _), a0_0 → a0_0)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Type _}, a0_0 → a0_0)); f x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ (a0_0 : Prop), a0_0 → a0_0)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Prop}, a0_0 → a0_0)); f x"
          ]
  , testCase "restore implicit specified arguments exactly" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      visibleIdentity <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["B"] []
          (FunctionType (TypeVariable "B") (TypeVariable "B"))
          :: Type String)
      let implicitIdentity = FAll False "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.box" (Just ["A"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleIdentity]
                      , paiSourceArguments =
                          [ProviderInstantiationArgument 0 implicitIdentity]
                      }
                  ]
              }
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (VisibleTypeApplication (Global providerName) visibleIdentity)
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural natural) expression
        @?= Right
          [ "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : _}, a0_0 → a0_0)); f x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Type _}, a0_0 → a0_0)); f x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Prop}, a0_0 → a0_0)); f x"
          ]
  , testCase "restore mixed forall visibility in specified results" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      visibleMixed <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["B", "C"] []
          (FunctionType (TypeVariable "C") (TypeVariable "C"))
          :: Type String)
      let mixed = FAll False "B" $ FAll True "C"
            (FArr (FVar "C") (FVar "C"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.box" (Just ["A"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleMixed]
                      , paiSourceArguments =
                          [ProviderInstantiationArgument 0 mixed]
                      }
                  ]
              }
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (VisibleTypeApplication (Global providerName) visibleMixed)
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural natural) expression
        @?= Right
          [ "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : _} (a0_1 : _), "
              ++ "a0_1 → a0_1)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Type _} (a0_1 : Type _), "
              ++ "a0_1 → a0_1)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«A» := (∀ {a0_0 : Prop} (a0_1 : Prop), "
              ++ "a0_1 → a0_1)); f _ x"
          ]
  , testCase "render exact mixed forall-domain alternatives" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      resultName <- expectRight $ mkIdentifier "Result"
      visibleMixed <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["P", "A"] []
          (FunctionType (TypeVariable "P")
            (FunctionType (TypeVariable "A") (TypeConstructor resultName)))
          :: Type String)
      let mixed = FAll False "P" $ FAll True "A" $
            FArr (FVar "P") $
              FArr (FVar "A") (FAtom False "Result")
          token = FAtom False "Demo.Token"
          providerFrag = FAll False "X" token
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["X"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleMixed]
                      , paiSourceArguments =
                          [ ProviderInstantiationExactArgument
                              0 mixed
                              [ ProviderForallDomainProp
                              , ProviderForallDomainType
                              ]
                          ]
                      }
                  , ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleMixed]
                      , paiSourceArguments =
                          [ ProviderInstantiationExactArgument 0 mixed
                              [ ProviderForallDomainType
                              , ProviderForallDomainProp
                              ]
                          ]
                      }
                  ]
              }
          expression = VisibleTypeApplication
            (Global providerName) visibleMixed
      renderLeanTerm Map.empty providers Map.empty ([], 0, []) token expression
        @?= Right
          [ "Demo.value («X» := (∀ {a0_0 : Prop} (a0_1 : Type _), "
              ++ "a0_0 → a0_1 → Result))"
          , "Demo.value («X» := (∀ {a0_0 : Type _} (a0_1 : Prop), "
              ++ "a0_0 → a0_1 → Result))"
          ]
  , testCase "couple exact metadata to occurrence-local result fitting" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      visibleIdentity <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["A"] []
          (FunctionType (TypeVariable "A") (TypeVariable "A"))
          :: Type String)
      let natural = FAtom False "Nat"
          implicitIdentity = FAll False "A" $
            FArr (FVar "A") (FVar "A")
          explicitIdentity = FAll True "A" $
            FArr (FVar "A") (FVar "A")
          assignment source = ProviderAssignmentInfo
            { paiVisibleArguments = [visibleIdentity]
            , paiSourceArguments =
                [ ProviderInstantiationExactArgument 0 source
                    [ProviderForallDomainType]
                ]
            }
          providerFrag = FAll False "F" (FProd (FVar "F") FTop)
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.box" (Just ["F"]) providerFrag)
              { piAssignments =
                  [ assignment implicitIdentity
                  , assignment explicitIdentity
                  ]
              }
          providerApplication = VisibleTypeApplication
            (Global providerName) visibleIdentity
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "implicitFunction", Wildcard])
              providerApplication $
              Let (TuplePattern [Bind "explicitFunction", Wildcard])
                providerApplication $
                Tuple
                  [ Apply (Local "implicitFunction") (Local "value")
                  , Apply (Local "explicitFunction") (Local "value")
                  ]
          goal = FArr natural (FProd natural natural)
          occurrenceLocalChoice =
            "fun x => let ⟨f, _⟩ := Demo.box "
              ++ "(«F» := (∀ {a0_0 : Type _}, a0_0 → a0_0)); "
              ++ "let ⟨g, _⟩ := Demo.box "
              ++ "(«F» := (∀ (a0_0 : Type _), a0_0 → a0_0)); "
              ++ "⟨f x, g _ x⟩"
      rendered <- expectRight $
        renderLeanTerm Map.empty providers Map.empty ([], 0, []) goal expression
      assertBool
        ("no rendering kept each occurrence's metadata coupled to fitting: "
          ++ show rendered)
        (occurrenceLocalChoice `elem` rendered)
  , testCase "reserve occurrence identities against candidate globals" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      collisionName <- expectRight $ mkIdentifier
        "leantMetadataProviderOccurrence00000000000000000000"
      naturalName <- expectRight $ mkIdentifier "Nat"
      visibleNatural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      let natural = FAtom False "Nat"
          token = FAtom False "Demo.Token"
          collision = FAtom False "Demo.Collision"
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["A"])
              (FAll False "A" token))
                { piAssignments =
                    [ ProviderAssignmentInfo
                        { paiVisibleArguments = [visibleNatural]
                        , paiSourceArguments =
                            [ProviderInstantiationArgument 0 natural]
                        }
                    ]
                }
          constructors = Map.singleton
            "leantMetadataProviderOccurrence00000000000000000000"
            CtorInfo
              { ciLean = "Demo.Collision.mk"
              , ciFields = []
              , ciSole = False
              , ciParametric = Nothing
              }
          expression = Tuple
            [ VisibleTypeApplication (Global providerName) visibleNatural
            , Global collisionName
            ]
      rendered <- expectRight $
        renderLeanTerm constructors providers Map.empty ([], 0, [])
          (FProd token collision) expression
      assertBool
        ("an occurrence identity shadowed an existing candidate global: "
          ++ show rendered)
        (any (isInfixOf "Demo.Collision.mk") rendered)
  , testCase "retain staged exact-domain alternatives beyond the live cap" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      resultName <- expectRight $ mkIdentifier "Result"
      visibleMixed <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["A", "B", "C"] []
          (FunctionType (TypeVariable "A") $
            FunctionType (TypeVariable "B") $
              FunctionType (TypeVariable "C") (TypeConstructor resultName))
          :: Type String)
      let mixed = FAll True "A" $ FAll True "B" $ FAll True "C" $
            FArr (FVar "A") $ FArr (FVar "B") $
              FArr (FVar "C") (FAtom False "Result")
          domains = take 17 $ sequence $ replicate 3
            [ ProviderForallDomainProp
            , ProviderForallDomainType
            , ProviderForallDomainSort
            ]
          token = FAtom False "Demo.Token"
          providerFrag = FAll False "X" token
          assignment exactDomains = ProviderAssignmentInfo
            { paiVisibleArguments = [visibleMixed]
            , paiSourceArguments =
                [ProviderInstantiationExactArgument 0 mixed exactDomains]
            }
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["X"]) providerFrag)
              { piAssignments = map assignment domains }
          expression = VisibleTypeApplication
            (Global providerName) visibleMixed
          seventeenth =
            "Demo.value («X» := (∀ (a0_0 : Type _) (a0_1 : Sort _) "
              ++ "(a0_2 : Type _), a0_0 → a0_1 → a0_2 → Result))"
      rendered <- expectRight $
        renderLeanTerm Map.empty providers Map.empty ([], 0, []) token expression
      length rendered @?= 17
      assertBool "the seventeenth staged exact-domain rendering was dropped"
        $ seventeenth `elem` rendered
  , testCase "reject exact domains misaligned with the source fragment" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      visibleNatural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      let natural = FAtom False "Nat"
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["X"])
              (FAll False "X" (FAtom False "Demo.Token")))
                { piAssignments =
                    [ ProviderAssignmentInfo
                        { paiVisibleArguments = [visibleNatural]
                        , paiSourceArguments =
                            [ ProviderInstantiationExactArgument
                                0 natural [ProviderForallDomainProp]
                            ]
                        }
                    ]
                }
          expression = VisibleTypeApplication
            (Global providerName) visibleNatural
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FAtom False "Demo.Token") expression
        @?= Left
          "exact Lean provider forall-domain vector does not align with its source fragment"
  , testCase "reject mismatched exact forall visibility" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      visibleIdentity <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["B"] []
          (FunctionType (TypeVariable "B") (TypeVariable "B"))
          :: Type String)
      let providerFrag = FAll False "A" (FVar "A")
          mismatched = FAll False "B" $ FAll True "C"
            (FArr (FVar "C") (FVar "C"))
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["A"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleIdentity]
                      , paiSourceArguments =
                          [ProviderInstantiationArgument 0 mismatched]
                      }
                  ]
              }
          expression = VisibleTypeApplication
            (Global providerName) visibleIdentity
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FAll True "B" (FArr (FVar "B") (FVar "B"))) expression
        @?= Left
          "exact Lean provider type-argument visibility exceeds its canonical type"
  , testCase "reject mismatched exact provider assignment vectors" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      visibleNatural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      let natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FVar "A")
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.value" (Just ["A"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments = [visibleNatural]
                      , paiSourceArguments = []
                      }
                  ]
              }
          expression = VisibleTypeApplication
            (Global providerName) visibleNatural
      renderLeanTerm Map.empty providers Map.empty ([], 0, []) natural expression
        @?= Left
          "cannot align exact provider type-argument source vector for Lean provider Demo.value"
  , testCase "correlate complete type vectors across erased instances" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      visibleNatural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      visibleIdentity <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["B"] []
          (FunctionType (TypeVariable "B") (TypeVariable "B"))
          :: Type String)
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" $ FInst "Demo.inst" $
            FAll False "B" (FProd (FVar "B") FTop)
          providers = Map.singleton "leantProvider0" $
            (providerInfo "Demo.box" (Just ["A", "B"]) providerFrag)
              { piAssignments =
                  [ ProviderAssignmentInfo
                      { paiVisibleArguments =
                          [visibleNatural, visibleIdentity]
                      , paiSourceArguments =
                          [ ProviderInstantiationArgument 0 natural
                          , ProviderInstantiationArgument 0 identity
                          ]
                      }
                  ]
              }
          eliminate providerApplication = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              providerApplication
              (Apply (Local "function") (Local "value"))
          completeApplication = VisibleTypeApplication
            (VisibleTypeApplication (Global providerName) visibleNatural)
            visibleIdentity
          partialApplication =
            VisibleTypeApplication (Global providerName) visibleNatural
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural natural) (eliminate completeApplication)
        @?= Right
          [ "fun x => let ⟨f, _⟩ := Demo.box («A» := Nat) "
              ++ "(«B» := (∀ (a0_0 : _), a0_0 → a0_0)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box («A» := Nat) "
              ++ "(«B» := (∀ (a0_0 : Type _), a0_0 → a0_0)); f _ x"
          , "fun x => let ⟨f, _⟩ := Demo.box («A» := Nat) "
              ++ "(«B» := (∀ (a0_0 : Prop), a0_0 → a0_0)); f _ x"
          ]
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural natural) (eliminate partialApplication)
        @?= Right
          ["fun x => let ⟨y, _⟩ := Demo.box («A» := Nat); y x"]
  , testCase "fit later provider arguments at an inferred rank-N type" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          token = FAtom False "Demo.Token"
          holder key argument =
            FApp False key (AppNominal "Demo.Holder") [argument]
          providerFrag = FAll False "A" $
            FArr
              (holder "Demo.Holder A" (FVar "A"))
              (FArr (FVar "A") token)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.consume" Nothing providerFrag)
          expression = Lambda [Bind "wrapped"] $
            Apply
              (Apply (Global providerName) (Local "wrapped"))
              (Lambda [Bind "identity"] (Local "identity"))
          goal = FArr
            (holder "Demo.Holder identity" identity)
            token
      renderLeanTerm Map.empty providers Map.empty ([], 0, []) goal expression
        @?= Right
          ["fun x => Demo.consume x (fun _ y => y)"]
  , testCase "continue through an inferred function-shaped result" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          token = FAtom False "Demo.Token"
          consumer = FArr identity token
          providerFrag = FAll False "A"
            (FArr (FVar "A") (FVar "A"))
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.choose" Nothing providerFrag)
          expression = Lambda [Bind "consumer"] $
            Apply
              (Apply (Global providerName) (Local "consumer"))
              (Lambda [Bind "identity"] (Local "identity"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr consumer token) expression
        @?= Right
          ["fun f => Demo.choose f (fun _ x => x)"]
  , testCase "fit nested exact provider applications recursively" $ do
      consumeName <- expectRight $ mkIdentifier "leantProvider0"
      transportName <- expectRight $ mkIdentifier "leantProvider1"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          token = FAtom False "Demo.Token"
          providers = Map.fromList
            [ ( "leantProvider0"
              , providerInfo "Demo.consume" Nothing (FArr identity token)
              )
            , ( "leantProvider1"
              , providerInfo "Demo.transport" Nothing (FArr identity identity)
              )
            ]
          expression = Apply (Global consumeName) $
            Apply
              (Global transportName)
              (Lambda [Bind "identity"] (Local "identity"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          token expression
        @?= Right
          ["Demo.consume (Demo.transport (fun _ x => x))"]
  , testCase "open a trailing forall for structural elimination" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FArr FTop $
            FAll False "A" (FProd identity FTop)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.make" Nothing providerFrag)
          expression = Lambda [Bind "unit", Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (Apply (Global providerName) (Local "unit"))
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr FTop (FArr natural natural)) expression
        @?= Right
          ["fun x y => let ⟨f, _⟩ := Demo.make x; f _ y"]
  , testCase "retain inferred provider-result envelopes" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          providerFrag = FAll False "A" $
            FProd
              (FAll True "B" (FArr (FVar "B") (FVar "A")))
              FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.unknown" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (VisibleTypeApplication
                (Global providerName) inferredVisibleTypeArgument)
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr natural boolean) expression
        @?= Right
          ["fun x => let ⟨f, _⟩ := @Demo.unknown _; f _ x"]
  , testCase "match repeated impredicative arguments alpha-equivalently" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity binder = FAll True binder
            (FArr (FVar binder) (FVar binder))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" $
            FArr
              (FProd (FVar "A") (FVar "A"))
              (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.boxRepeated" Nothing providerFrag)
          expression = Lambda [Bind "pair", Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (Apply (Global providerName) (Local "pair"))
              (Apply (Local "function") (Local "value"))
          goal = FArr
            (FProd (identity "B") (identity "C"))
            (FArr natural natural)
      renderLeanTerm Map.empty providers Map.empty ([], 0, []) goal expression
        @?= Right
          ["fun x y => let ⟨f, _⟩ := Demo.boxRepeated x; f _ y"]
  , testCase "reject conflicting provider-result specializations" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" $
            FArr
              (FProd (FVar "A") (FVar "A"))
              (FProd (FVar "A") FTop)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.boxRepeated" Nothing providerFrag)
          expression = Lambda [Bind "pair", Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (Apply (Global providerName) (Local "pair"))
              (Apply (Local "function") (Local "value"))
          goal = FArr
            (FProd identity natural)
            (FArr natural natural)
      renderLeanTerm Map.empty providers Map.empty ([], 0, []) goal expression
        @?= Right
          ["fun x y => let ⟨a, _⟩ := Demo.boxRepeated x; a y"]
  , testCase "specialize impredicative provider results across engines" $ do
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          holder key argument =
            FApp False key (AppNominal "Demo.Holder") [argument]
          provider = ProviderFrag "Demo.unpack" $
            FAll False "A" $
              FArr
                (holder "Demo.Holder A" (FVar "A"))
                (FProd (FVar "A") FTop)
          goal = FArr
            (holder "Demo.Holder identity" identity)
            (FArr natural natural)
          check engine = case
              synthesizeWithProviders engine 1024 [provider] goal of
            Right (SynthCandidates groups _) ->
              let candidates = concat groups
                  fitted term =
                    "Demo.unpack" `isInfixOf` term
                      && "f _ y" `isInfixOf` term
              in assertBool
                ("impredicative provider result was not specialized in "
                  ++ synthEngineName engine ++ ": " ++ show candidates)
                (any fitted candidates)
            Right other -> assertFailure $
              "unexpected impredicative-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "specialize evidence-selected provider results" $ do
      let identity = FAll True "B"
            (FArr (FVar "B") (FVar "B"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FProd (FVar "A") FTop)
          provider = ProviderFragWithEvidence
            "Demo.box" providerFrag ["A"]
            [[ProviderInstantiationArgument 0 identity]]
          goal = FArr natural natural
          check engine = case
              synthesizeWithProviders engine 1024 [provider] goal of
            Right (SynthCandidates groups _) ->
              let candidates = concat groups
                  fitted term =
                    "Demo.box («A» := (∀" `isInfixOf` term
                      && "f _ x" `isInfixOf` term
              in assertBool
                ("specified provider result was not specialized in "
                  ++ synthEngineName engine ++ ": " ++ show candidates)
                (any fitted candidates)
            Right other -> assertFailure $
              "unexpected specified-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      -- The direct renderer assertion above covers the engine-neutral fitting
      -- path exactly. Exference supplies the stable evidence-selected
      -- elimination candidate; combined mode verifies that merging preserves
      -- it even when Djinn's direct identity candidates fill its own frontier.
      mapM_ check [EngineExference, EngineBoth]
  , testCase "specialize implicit evidence-selected provider results" $ do
      let mixed = FAll False "B" $ FAll True "C"
            (FArr (FVar "C") (FVar "C"))
          natural = FAtom False "Nat"
          providerFrag = FAll False "A" (FProd (FVar "A") FTop)
          provider = ProviderFragWithEvidence
            "Demo.box" providerFrag ["A"]
            [[ProviderInstantiationArgument 0 mixed]]
          goal = FArr natural natural
          check engine = case
              synthesizeWithProviders engine 1024 [provider] goal of
            Right (SynthCandidates groups _) ->
              let candidates = concat groups
                  fitted term =
                    "Demo.box («A» := (∀ {" `isInfixOf` term
                      && "} (a0_1 : _), a0_1 → a0_1)" `isInfixOf` term
                      && "f _ x" `isInfixOf` term
              in assertBool
                ("implicit specified provider result was not specialized in "
                  ++ synthEngineName engine ++ ": " ++ show candidates)
                (any fitted candidates)
            Right other -> assertFailure $
              "unexpected implicit specified-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineExference, EngineBoth]
  , testCase "fit explicit forall arguments of foreign providers" $ do
      let token = FAtom False "Demo.Token"
          provider = ProviderFrag "Demo.consumeExplicit"
            (FArr polytype token)
          check engine = expectTerm "Demo.consumeExplicit (fun _"
            (synthesizeWithProviders engine 4096 [provider] token)
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "keep implicit forall provider arguments binder-free" $ do
      let token = FAtom False "Demo.Token"
          implicitIdentity = FAll False "a"
            (FArr (FVar "a") (FVar "a"))
          provider = ProviderFrag "Demo.consumeImplicit"
            (FArr implicitIdentity token)
          check engine = case
              synthesizeWithProviders engine 4096 [provider] token of
            Right (SynthCandidates groups _) ->
              let candidates = concat groups
                  fitted candidate =
                    "Demo.consumeImplicit (fun " `isInfixOf` candidate
                      && not
                        ("Demo.consumeImplicit (fun _" `isInfixOf` candidate)
              in assertBool
                ("implicit provider argument gained a type binder in "
                  ++ synthEngineName engine ++ ": " ++ show candidates)
                (any fitted candidates)
            Right other -> assertFailure $
              "unexpected implicit-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "weave explicit forall slots into applied foreign providers" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FAll True "A"
            (FArr (FVar "A") result)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Apply (Global providerName) (Local "value")
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right ["fun x => Demo.source _ x"]
  , testCase "leave implicit forall slots hidden on applied providers" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FAll False "A"
            (FArr (FVar "A") result)
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Apply (Global providerName) (Local "value")
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right ["fun x => Demo.source x"]
  , testCase "fit rank-N fields eliminated from structured providers" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FProd
            (FAll True "A" (FArr (FVar "A") result))
            FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Case (Global providerName)
              [ ( TuplePattern [Bind "function", Wildcard]
                , Apply (Local "function") (Local "value")
                )
              ]
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right
          ["fun x => match Demo.source with | ⟨f, _⟩ => f _ x"]
  , testCase "normalize Exference intrinsic product eliminations" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      pairName <- expectRight $ tupleName Boxed 2
      unitName <- expectRight $ tupleName Boxed 0
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FProd
            (FAll True "A" (FArr (FVar "A") result))
            FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Let (Constructor pairName [Bind "function", Bind "unit"])
              (Global providerName)
              (Let (Constructor unitName []) (Local "unit")
                (Apply (Local "function") (Local "value")))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right
          [ "fun x => let ⟨f, y⟩ := Demo.source; let z := y; "
              ++ "match z with | _ => f _ x"
          ]
  , testCase "fit rank-N fields from applied structured providers" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let token = FAtom False "Demo.Token"
          source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FArr token $
            FProd
              (FAll True "A" (FArr (FVar "A") result))
              FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.makeSource" Nothing providerFrag)
          expression = Lambda [Bind "token", Bind "value"] $
            Case
              (Apply (Global providerName) (Local "token"))
              [ ( TuplePattern [Bind "function", Wildcard]
                , Apply (Local "function") (Local "value")
                )
              ]
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr token (FArr source result)) expression
        @?= Right
          ["fun x y => match Demo.makeSource x with | ⟨f, _⟩ => f _ y"]
  , testCase "fit rank-N fields let-bound from structured providers" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FProd
            (FAll True "A" (FArr (FVar "A") result))
            FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Let (TuplePattern [Bind "function", Wildcard])
              (Global providerName)
              (Apply (Local "function") (Local "value"))
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right
          ["fun x => let ⟨f, _⟩ := Demo.source; f _ x"]
  , testCase "leave implicit rank-N fields hidden after elimination" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FProd
            (FAll False "A" (FArr (FVar "A") result))
            FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Case (Global providerName)
              [ ( TuplePattern [Bind "function", Wildcard]
                , Apply (Local "function") (Local "value")
                )
              ]
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right
          ["fun x => match Demo.source with | ⟨f, _⟩ => f x"]
  , testCase "fit rank-N fields inside nested elimination inputs" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source = FAtom False "Demo.Source"
          result = FAtom False "Demo.Result"
          providerFrag = FProd
            (FAll True "A" (FArr (FVar "A") result))
            FTop
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.source" Nothing providerFrag)
          expression = Lambda [Bind "value"] $
            Let (Bind "answer")
              (Case (Global providerName)
                [ ( TuplePattern [Bind "function", Wildcard]
                  , Apply (Local "function") (Local "value")
                  )
                ])
              (Local "answer")
      renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr source result) expression
        @?= Right
          [ "fun x => let a := match Demo.source with | "
              ++ "⟨f, _⟩ => f _ x; a"
          ]
  , testCase "fit explicit forall provider arguments in case scrutinees" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let token = FAtom False "Demo.Token"
          providerFrag = FArr polytype token
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.consumeExplicit" Nothing providerFrag)
          providerApplication = Apply (Global providerName)
            (Lambda [Bind "identity"] (Local "identity"))
          expression = Case providerApplication
            [(Bind "result", Local "result")]
      case renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          token expression of
        Left err -> assertFailure err
        Right candidates -> assertBool
          ("case scrutinee lost its explicit forall binder: "
            ++ show candidates)
          (not (null candidates)
            && all
              ("Demo.consumeExplicit (fun _" `isInfixOf`)
              candidates)
  , testCase "fit explicit forall provider arguments in let right-hand sides" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let token = FAtom False "Demo.Token"
          providerFrag = FArr polytype token
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.consumeExplicit" Nothing providerFrag)
          providerApplication = Apply (Global providerName)
            (Lambda [Bind "identity"] (Local "identity"))
          expression = Let (Bind "result") providerApplication
            (Local "result")
      case renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          token expression of
        Left err -> assertFailure err
        Right candidates -> assertBool
          ("let right-hand side lost its explicit forall binder: "
            ++ show candidates)
          (not (null candidates)
            && all
              ("Demo.consumeExplicit (fun _" `isInfixOf`)
              candidates)
  , testCase "fit provider arguments recursively below elimination inputs" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let token = FAtom False "Demo.Token"
          providerFrag = FArr polytype token
          providers = Map.singleton "leantProvider0"
            (providerInfo "Demo.consumeExplicit" Nothing providerFrag)
          providerApplication = Apply (Global providerName)
            (Lambda [Bind "identity"] (Local "identity"))
          nestedRhs = Lambda [Bind "ignored"] providerApplication
          expression = Let (Bind "result") nestedRhs (Local "result")
      case renderLeanTerm Map.empty providers Map.empty ([], 0, [])
          (FArr token token) expression of
        Left err -> assertFailure err
        Right candidates -> assertBool
          ("nested elimination input lost its explicit forall binder: "
            ++ show candidates)
          (not (null candidates)
            && all
              ("Demo.consumeExplicit (fun _" `isInfixOf`)
              candidates)
  , testCase "make a constrained vacuous provider choice visible" $
      let natural = FParamRec True "Nat" "Nat" []
            [ ("Nat.zero", [])
            , ("Nat.succ", [FAtom False "Nat"])
            ]
          token = FAtom False "Demo.Token"
          provider = ProviderFragWithBinders "Demo.global"
            (FAll False "a" token) ["a"]
          goal = FArr natural token
          check engine = expectTerm "Demo.global («a» := Nat)"
            (synthesizeWithProviders engine 1024 [provider] goal)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "instantiate a provider-only constrained rank-N choice" $
      let token = FAtom False "Gap.Token"
          provider = ProviderFragWithEvidence "Gap.global"
            (FAll False "a" token) ["a"] [[properArgument polytype]]
          check engine = expectTerm "Gap.global («a» := (∀"
            (synthesizeWithProviders engine 1024 [provider] token)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "instantiate a structured contextual rank-N provider choice" $
      let token = FAtom False "ContextualOnly.Token"
          contextual = FAll False "A" $
            FExactContext "Inhabited"
              [ExactContextFragmentArgument 0 (FVar "A")] $
              FArr (FVar "A") (FVar "A")
          provider = ProviderFragWithEvidence "ContextualOnly.chosen"
            (FAll False "a" token) ["a"]
            [ [ ProviderInstantiationExactArgument 0 contextual
                  [ProviderForallDomainType]
              ]
            ]
          expected =
            "ContextualOnly.chosen («a» := (∀ {a0_0 : Type _}, "
              ++ "[@Inhabited a0_0] → a0_0 → a0_0))"
          check engine = expectTerm expected
            (synthesizeWithProviders engine 2048 [provider] token)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "instantiate a higher-kinded structured contextual choice" $
      let token = FAtom False "HigherContext.Token"
          contextual = FExactContext "Functor"
            [ExactContextFragmentArgument 1 (FAtom False "List")] $
              FArr (FAtom False "Nat") (FAtom False "Nat")
          provider = ProviderFragWithEvidence "HigherContext.chosen"
            (FAll False "a" token) ["a"]
            [ [ProviderInstantiationExactArgument 0 contextual []]
            ]
          expected =
            "HigherContext.chosen («a» := "
              ++ "([@Functor List] → (Nat) → (Nat)))"
          check engine = expectTerm expected
            (synthesizeWithProviders engine 2048 [provider] token)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "plan a partial contextual family at its total arity" $
      let token = FAtom False "HigherContext.Token"
          partial = FApp False "Except String"
            (AppNominal "Except") [FAtom False "String"]
          contextual = FExactContext "Bifunctor"
            [ExactContextFragmentArgument 1 partial] $
              FArr (FAtom False "Nat") (FAtom False "Nat")
          provider = ProviderFragWithEvidence "HigherContext.partial"
            (FAll False "a" token) ["a"]
            [ [ProviderInstantiationExactArgument 0 contextual []]
            ]
          check engine = expectTerm
            "[@Bifunctor (@Except (String))]"
            (synthesizeWithProviders engine 2048 [provider] token)
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "consume canonical structural provider assignments" $
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          token = FAtom False "Structural.Token"
          fApplied = FApp True "F Nat Bool"
            (AppVariable "F") [natural, boolean]
          gApplied = FApp True "G Bool"
            (AppVariable "G") [boolean]
          provider = ProviderFragWithEvidence "Structural.consume"
            (FAll False "F" $ FAll False "G" $
              FArr fApplied (FArr gApplied token))
            ["F", "G"]
            [ [ ProviderInstantiationNominalArgument 2 "Prod" []
              , ProviderInstantiationNominalArgument 1 "Sum" [natural]
              ]
            , [ ProviderInstantiationNominalArgument 2 "Sum" []
              , ProviderInstantiationNominalArgument 1 "Prod" [natural]
              ]
            ]
          assignments =
            [ ( "bare Prod and partial Sum"
              , FArr (FProd natural boolean)
                  (FArr (FSum natural boolean) token)
              , "«F» := Prod"
              , "«G» := (Sum (Nat))"
              )
            , ( "bare Sum and partial Prod"
              , FArr (FSum natural boolean)
                  (FArr (FProd natural boolean) token)
              , "«F» := Sum"
              , "«G» := (@Prod (Nat))"
              )
            ]
          check (label, goal, expectedF, expectedG) engine = case
              synthesizeWithProviders engine 4096 [provider] goal of
            Right (SynthCandidates groups _) ->
              let terms = concat groups
              in assertBool
                  (label ++ " assignment was lost in "
                    ++ synthEngineName engine ++ ": " ++ show terms)
                  (any (\term ->
                    isInfixOf "Structural.consume" term
                      && isInfixOf expectedF term
                      && isInfixOf expectedG term)
                    terms)
            Right other -> assertFailure $
              "unexpected " ++ label ++ " provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      in mapM_ (\assignment ->
          mapM_ (check assignment)
            [EngineDjinn, EngineExference, EngineBoth])
        assignments
  , testCase "consume a structural contextual rank-N assignment" $
      let natural = FAtom False "Nat"
          token = FAtom False "Structural.ContextToken"
          contextual = FAll False "A" $
            FExactContext "Structural.Context"
              [ ExactContextNominalArgument 2 "Prod" []
              , ExactContextNominalArgument 1 "Sum" [natural]
              ] $
              FArr (FVar "A") (FVar "A")
          provider = ProviderFragWithEvidence "Structural.choose"
            (FAll False "selected" $
              FArr (FVar "selected") token)
            ["selected"]
            [ [ ProviderInstantiationExactArgument 0 contextual
                  [ProviderForallDomainType]
              ]
            ]
          goal = FArr contextual token
          check engine = case
              synthesizeWithProviders engine 4096 [provider] goal of
            Right (SynthCandidates groups _) ->
              let terms = concat groups
              in assertBool
                  ("structural contextual rank-N assignment was lost in "
                    ++ synthEngineName engine ++ ": " ++ show terms)
                  (any (\term ->
                    isInfixOf "Structural.choose" term
                      && isInfixOf
                        "[@Structural.Context Prod (Sum (Nat))]" term)
                    terms)
            Right other -> assertFailure $
              "unexpected structural contextual outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      in mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "keep structured contexts exact-only and nominally kinded" $
      let token = FAtom False "ContextualOnly.Token"
          contextual arity = FAll False "A" $
            FExactContext "Inhabited"
              [ExactContextFragmentArgument arity (FVar "A")] $
              FArr (FVar "A") (FVar "A")
          nominal = FExactContext "Functor"
            [ExactContextFragmentArgument 1 (FAtom False "List")] token
          partialNominal = FExactContext "Bifunctor"
            [ ExactContextFragmentArgument 1
                (FApp False "Except String"
                  (AppNominal "Except") [FAtom False "String"])
            ] token
          reserved = FExactContext "Functor"
            [ExactContextFragmentArgument 1 (FAtom False "Prod")] token
          canonicalProduct = FExactContext "Functor"
            [ExactContextNominalArgument 2 "Prod" []] token
          canonicalPartialSum = FExactContext "Functor"
            [ ExactContextNominalArgument 1 "Sum"
                [FAtom False "Nat"]
            ] token
          wrongStructuralArity = FExactContext "Functor"
            [ExactContextNominalArgument 1 "Prod" []] token
          unsupportedStructural = FExactContext "Functor"
            [ExactContextNominalArgument 2 "PProd" []] token
          overBound = FExactContext "Functor"
            [ ExactContextFragmentArgument
                (maximumProviderArgumentKindArity + 1)
                (FAtom False "List")
            ]
            token
          provider argument = ProviderFragWithEvidence
            "ContextualOnly.chosen" (FAll False "a" token) ["a"]
            [[argument]]
          structural = provider $
            ProviderInstantiationArgument 0 (contextual 0)
          wrongKind = provider $
            ProviderInstantiationExactArgument 0 (contextual 1)
              [ProviderForallDomainType]
          check provider' engine = case
              synthesizeWithProviders engine 512 [provider'] token of
            Right (SynthCandidates groups _)
              | any (anyContextMarker `isInfixOf`) (concat groups) ->
                  assertFailure $ "unsupported contextual assignment reached "
                    ++ show engine ++ ": " ++ show groups
            Right _ -> pure ()
            Left err -> assertFailure $ "unsupported contextual assignment "
              ++ "failed the whole " ++ show engine ++ " query: " ++ err
          anyContextMarker = "[@Inhabited"
      in do
        fragHasUnsupportedInstanceBinder (contextual 0) @?= False
        fragHasUnsupportedInstanceBinder (contextual 1) @?= True
        fragHasUnsupportedInstanceBinder nominal @?= False
        fragHasUnsupportedInstanceBinder partialNominal @?= False
        fragHasUnsupportedInstanceBinder reserved @?= True
        fragHasUnsupportedInstanceBinder canonicalProduct @?= False
        fragHasUnsupportedInstanceBinder canonicalPartialSum @?= False
        fragHasUnsupportedInstanceBinder wrongStructuralArity @?= True
        fragHasUnsupportedInstanceBinder unsupportedStructural @?= True
        fragHasUnsupportedInstanceBinder overBound @?= True
        mapM_ (check structural) [EngineDjinn, EngineExference, EngineBoth]
        mapM_ (check wrongKind) [EngineDjinn, EngineExference, EngineBoth]
  , testCase "discard inconsistent exact evidence without losing siblings" $
      let token = FAtom False "ContextualOnly.Token"
          natural = FAtom False "Nat"
          good = natural
          familyAtOne = FExactContext "Audit.C1"
            [ExactContextFragmentArgument 1 (FAtom False "Audit.H")] token
          familyAtTwo = FExactContext "Audit.C2"
            [ ExactContextFragmentArgument 1
                (FApp False "Audit.H Nat" (AppNominal "Audit.H")
                  [natural])
            ] token
          internallyInconsistentFamily = FExactContext "Audit.C1"
            [ExactContextFragmentArgument 1 (FAtom False "Audit.H")] $
              FExactContext "Audit.C2"
                [ ExactContextFragmentArgument 1
                    (FApp False "Audit.H Nat" (AppNominal "Audit.H")
                      [natural])
                ] token
          classAtProper = FExactContext "Audit.Class"
            [ExactContextFragmentArgument 0 natural] token
          classAtHigher = FExactContext "Audit.Class"
            [ExactContextFragmentArgument 1 (FAtom False "List")] token
          emptyNominal = FExactContext "Audit.Empty"
            [ExactContextFragmentArgument 1 (FAtom False "")] token
          provider assignments = ProviderFragWithEvidence
            "ContextualOnly.chosen" (FAll False "a" token) ["a"]
            [ [ProviderInstantiationExactArgument 0 assignment []]
            | assignment <- assignments
            ]
          expected = "ContextualOnly.chosen («a» := (Nat))"
          malformedBatches =
            [ ("one internally inconsistent family",
                [internallyInconsistentFamily, good])
            , ("two conflicting family vectors",
                [familyAtOne, familyAtTwo, good])
            , ("two conflicting class-kind vectors",
                [classAtProper, classAtHigher, good])
            , ("an empty nominal head", [emptyNominal, good])
            ]
          check (label, assignments) engine = case
              synthesizeWithProviders engine 1024
                [provider assignments] token of
            Right (SynthCandidates groups _) ->
              assertBool
                (label ++ " removed an unrelated valid assignment from "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (expected `elem` concat groups)
            Right other -> assertFailure $
              label ++ " produced an unexpected " ++ synthEngineName engine
                ++ " outcome: " ++ outcomeTag other
            Left err -> assertFailure $
              label ++ " poisoned the whole " ++ synthEngineName engine
                ++ " query: " ++ err
      in do
        fragHasUnsupportedInstanceBinder internallyInconsistentFamily @?= False
        fragHasUnsupportedInstanceBinder familyAtOne @?= False
        fragHasUnsupportedInstanceBinder familyAtTwo @?= False
        fragHasUnsupportedInstanceBinder classAtProper @?= False
        fragHasUnsupportedInstanceBinder classAtHigher @?= False
        fragHasUnsupportedInstanceBinder emptyNominal @?= True
        mapM_
          (\batch -> mapM_ (check batch)
            [EngineDjinn, EngineExference, EngineBoth])
          malformedBatches
  , testCase "search one canonical assignment but retain domain alternatives" $ do
      let mixed = FAll False "P" $ FAll True "A" $
            FArr (FVar "P") $ FArr (FVar "A") (FVar "A")
          token = FAtom False "Gap.Token"
          provider = ProviderFragWithEvidence "Gap.global"
            (FAll False "X" token) ["X"]
            [ [ ProviderInstantiationExactArgument 0 mixed
                  [ ProviderForallDomainProp
                  , ProviderForallDomainType
                  ]
              ]
            , [ ProviderInstantiationExactArgument 0 mixed
                  [ ProviderForallDomainType
                  , ProviderForallDomainProp
                  ]
              ]
            ]
          expected =
            [ "Gap.global («X» := (∀ {a0_0 : Prop} (a0_1 : Type _), "
                ++ "a0_0 → a0_1 → a0_1))"
            , "Gap.global («X» := (∀ {a0_0 : Type _} (a0_1 : Prop), "
                ++ "a0_0 → a0_1 → a0_1))"
            ]
      case synthesizeWithProviders EngineDjinn 1024 [provider] token of
        Right (SynthCandidates groups _) -> do
          let exactGroups =
                [ variants
                | variants <- groups
                , any (`elem` variants) expected
                ]
          case exactGroups of
            [variants] -> mapM_ (\term -> assertBool
                ("domain alternative missing from the sole exact Djinn group: "
                  ++ show variants)
                (term `elem` variants))
              expected
            _ -> assertFailure $
              "canonical domain collision did not coalesce into one exact "
                ++ "Djinn group: " ++ show groups
        Right other -> assertFailure $
          "unexpected canonical-domain collision outcome: " ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "retain mixed higher-kinded and rank-N provider arguments" $ do
      let natural = FAtom False "Nat"
          token = FAtom False "Higher.Token"
          applied = FApp False "Higher.Wrap Nat"
            (AppNominal "Higher.Wrap") [natural]
          provider = ProviderFragWithEvidence "Higher.global"
            (FAll False "F" (FAll False "a" (FAll False "hidden"
              (FArr
                (FApp True "F a" (AppVariable "F") [FVar "a"])
                token))))
            ["F", "a", "hidden"]
            [ [ ProviderInstantiationNominalArgument 1 "Higher.Wrap" []
              , properArgument natural
              , properArgument polytype
              ]
            ]
          expected =
            "Higher.global («F» := Higher.Wrap) («a» := (Nat)) "
              ++ "(«hidden» := (∀ (a0_0 : _), a0_0 → a0_0))"
          check engine = case
              synthesizeWithProviders engine 2048 [provider]
                (FArr applied token) of
            Right (SynthCandidates groups _) ->
              assertBool
                ("mixed higher-kinded assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== expected) (concat groups))
            Right other -> assertFailure $
              "unexpected mixed higher-kinded assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "share a partially applied higher-kinded provider argument" $ do
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          token = FAtom False "Higher.Token"
          saturated = FApp False "Higher.Pair Nat Bool"
            (AppNominal "Higher.Pair") [natural, boolean]
          provider = ProviderFragWithEvidence "Higher.partial"
            (FAll False "F"
              (FArr
                (FApp True "F Bool" (AppVariable "F") [boolean])
                token))
            ["F"]
            [[ProviderInstantiationNominalArgument 1 "Higher.Pair" [natural]]]
          expected = "Higher.partial («F» := (@Higher.Pair (Nat)))"
          check engine = case
              synthesizeWithProviders engine 2048 [provider]
                (FArr saturated token) of
            Right (SynthCandidates groups _) ->
              assertBool
                ("partial higher-kinded assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== expected) (concat groups))
            Right other -> assertFailure $
              "unexpected partial higher-kinded assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain a vacuous higher-kinded provider assignment" $ do
      let token = FAtom False "Higher.Token"
          provider = ProviderFragWithEvidence "Higher.vacuous"
            (FAll False "F" token) ["F"]
            [[ProviderInstantiationNominalArgument 1 "Higher.Wrap" []]]
          expected = "Higher.vacuous («F» := Higher.Wrap)"
          check engine = case
              synthesizeWithProviders engine 512 [provider] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("vacuous higher-kinded assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== expected) (concat groups))
            Right other -> assertFailure $
              "unexpected vacuous higher-kinded assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "drop an over-limit provider kind without losing later evidence" $ do
      let token = FAtom False "Higher.Token"
          overLimit = ProviderFragWithEvidence "Higher.overLimit"
            (FAll False "F" token) ["F"]
            [ [ ProviderInstantiationNominalArgument 65 "Higher.TooWide" []
              ]
            ]
          valid = ProviderFragWithEvidence "Higher.vacuous"
            (FAll False "F" token) ["F"]
            [[ProviderInstantiationNominalArgument 1 "Higher.Wrap" []]]
          expected = "Higher.vacuous («F» := Higher.Wrap)"
          check engine = case
              synthesizeWithProviders engine 512 [overLimit, valid] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("later provider evidence was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== expected) (concat groups))
            Right other -> assertFailure $
              "unexpected over-limit provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain heterogeneous multi-vacuous provider kinds" $ do
      let natural = FAtom False "Nat"
          token = FAtom False "Higher.MultiVacuousToken"
          provider = ProviderFragWithEvidence "Higher.multiVacuous"
            (FAll False "F" (FAll False "G" token)) ["F", "G"]
            [ [ ProviderInstantiationNominalArgument 1 "Higher.Wrap" []
              , ProviderInstantiationNominalArgument 2 "Higher.Triple"
                  [natural]
              ]
            ]
          expected =
            "Higher.multiVacuous («F» := Higher.Wrap) "
              ++ "(«G» := (@Higher.Triple (Nat)))"
          check engine = case
              synthesizeWithProviders engine 1024 [provider] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("multi-vacuous heterogeneous assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any (== expected) (concat groups))
            Right other -> assertFailure $
              "unexpected multi-vacuous assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain distinct same-provider assignment vectors" $ do
      let natural = FAtom False "Nat"
          token = FAtom False "Higher.AlternativeToken"
          provider = ProviderFragWithEvidence "Higher.alternative"
            (FAll False "F" token) ["F"]
            [ [ProviderInstantiationNominalArgument 1 "Higher.Wrap" []]
            , [ ProviderInstantiationNominalArgument 1 "Higher.Pair"
                  [natural]
              ]
            , [ProviderInstantiationNominalArgument 1 "Higher.Wrap" []]
            ]
          expected =
            [ "Higher.alternative («F» := Higher.Wrap)"
            , "Higher.alternative («F» := (@Higher.Pair (Nat)))"
            ]
          check engine = case
              synthesizeWithProviders engine 1024 [provider] token of
            Right (SynthCandidates groups _) ->
              let terms = concat groups
              in mapM_ (\term ->
                  assertBool
                    ("a distinct same-provider vector was lost or duplicated "
                      ++ "in " ++ synthEngineName engine ++ ": " ++ show terms)
                    (length (filter (== term) terms) == 1))
                  expected
            Right other -> assertFailure $
              "unexpected same-provider assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain four ordered quantified provider arguments" $ do
      let token = FAtom False "Gap.Token"
          quantified binder arity =
            let variable = FVar binder
            in FAll True binder
                (foldr FArr variable (replicate arity variable))
          assignment = map properArgument
            [ quantified "p1" 1
            , quantified "p2" 2
            , quantified "p3" 3
            , quantified "p4" 4
            ]
          provider = ProviderFragWithEvidence "Gap.four"
            (FAll False "a" (FAll False "b"
              (FAll False "c" (FAll False "d" token))))
            ["a", "b", "c", "d"] [assignment]
          expected =
            [ "Gap.four"
            , "«a» := (∀ (a0_0 : _), a0_0 → a0_0)"
            , "«b» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0)"
            , "«c» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0)"
            , "«d» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            ]
          exact term = all (\needle -> needle `isInfixOf` term) expected
          check engine = case
              synthesizeWithProviders engine 2048 [provider] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("ordered four-argument assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any exact (concat groups))
            Right other -> assertFailure $
              "unexpected ordered-assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain five ordered quantified provider arguments" $ do
      let token = FAtom False "Gap.FiveToken"
          quantified binder arity =
            let variable = FVar binder
            in FAll True binder
                (foldr FArr variable (replicate arity variable))
          assignment = map properArgument
            [ quantified "p1" 1
            , quantified "p2" 2
            , quantified "p3" 3
            , quantified "p4" 4
            , quantified "p5" 5
            ]
          provider = ProviderFragWithEvidence "Gap.five"
            (FAll False "a" (FAll False "b"
              (FAll False "c" (FAll False "d"
                (FAll False "e" token)))))
            ["a", "b", "c", "d", "e"] [assignment]
          expected =
            [ "Gap.five"
            , "«a» := (∀ (a0_0 : _), a0_0 → a0_0)"
            , "«b» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0)"
            , "«c» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0)"
            , "«d» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            , "«e» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            ]
          exact term = all (\needle -> needle `isInfixOf` term) expected
          check engine = case
              synthesizeWithProviders engine 2048 [provider] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("ordered five-argument assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any exact (concat groups))
            Right other -> assertFailure $
              "unexpected five-argument assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "retain six ordered quantified provider arguments" $ do
      let token = FAtom False "Gap.SixToken"
          quantified binder arity =
            let variable = FVar binder
            in FAll True binder
                (foldr FArr variable (replicate arity variable))
          assignment = map properArgument
            [ quantified "p1" 1
            , quantified "p2" 2
            , quantified "p3" 3
            , quantified "p4" 4
            , quantified "p5" 5
            , quantified "p6" 6
            ]
          provider = ProviderFragWithEvidence "Gap.six"
            (FAll False "a" (FAll False "b"
              (FAll False "c" (FAll False "d"
                (FAll False "e" (FAll False "f" token))))))
            ["a", "b", "c", "d", "e", "f"] [assignment]
          expected =
            [ "Gap.six"
            , "«a» := (∀ (a0_0 : _), a0_0 → a0_0)"
            , "«b» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0)"
            , "«c» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0)"
            , "«d» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            , "«e» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            , "«f» := (∀ (a0_0 : _), a0_0 → a0_0 → a0_0 → a0_0 → a0_0 → a0_0 → a0_0)"
            ]
          exact term = all (\needle -> needle `isInfixOf` term) expected
          check engine = case
              synthesizeWithProviders engine 4096 [provider] token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("ordered six-argument assignment was lost in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (any exact (concat groups))
            Right other -> assertFailure $
              "unexpected six-argument assignment outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "do not enter a seven-argument provider assignment" $ do
      let token = FAtom False "Gap.SevenBoundaryToken"
          binderNames =
            ["p" ++ show index
            | index <- [1 .. maximumProviderInstantiationArguments + 1]
            ]
          providerType = foldr (FAll False) token binderNames
          inertArguments = replicate maximumProviderInstantiationArguments
            (properArgument polytype)
          assignment = inertArguments ++
            [error "entered an over-wide provider assignment argument"]
          provider = ProviderFragWithEvidence "Gap.sevenBoundary"
            providerType binderNames [assignment]
          check engine = case
              synthesizeWithProviders engine 128 [provider] token of
            Left err -> assertFailure $
              "over-wide assignment failed the whole "
                ++ synthEngineName engine ++ " query: " ++ err
            Right (SynthCandidates groups _) -> assertBool
              ("over-wide assignment became visible in "
                ++ synthEngineName engine ++ ": " ++ show groups)
              (all (not . isInfixOf "«p1» :=") (concat groups))
            Right _ -> pure ()
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "do not enter provider evidence beyond the aggregate bound" $
      let token = FAtom False "Gap.Token"
          provider name result assignments = ProviderFragWithEvidence name
            (FAll False "a" result) ["a"] assignments
          providers =
            [ provider "Gap.first" token
                (replicate 16 [properArgument polytype])
            , provider "Gap.second" (FAtom False "Gap.Other")
                (replicate 16 [properArgument polytype])
            , provider "Gap.third" (FAtom False "Gap.Last")
                [error "entered the 33rd provider instantiation assignment"]
            ]
      in expectTerm "Gap.first («a» := (∀"
          (synthesizeWithProviders EngineDjinn 1024 providers token)
  , testCase "do not donate evidence between provider lanes" $ do
      let token = FAtom False "Gap.Token"
          providers =
            [ ProviderFragWithBinders "Gap.first"
                (FAll False "a" token) ["a"]
            , ProviderFragWithEvidence "Gap.unrelated"
                (FAll False "a" (FAtom False "Gap.Other")) ["a"]
                [[properArgument polytype]]
            ]
          donated = isInfixOf "Gap.first («a» := (∀"
          check engine = case
              synthesizeWithProviders engine 1024 providers token of
            Right (SynthCandidates groups _) ->
              assertBool
                ("a later provider donated rank-N evidence to Gap.first in "
                  ++ synthEngineName engine ++ ": " ++ show groups)
                (not (any donated (concat groups)))
            Right _ -> pure ()
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "apply a scoped vacuous provider at a query polytype" $ do
      let token = FAtom False "Demo.Token"
          provider = FAll False "hidden" token
          goal = FArr polytype $ FArr provider token
          quantifiedTypeVariant term =
            '@' `elem` term
              && "(∀ (a0_0 : Type _), a0_0 → a0_0)" `isInfixOf` term
          check engine = case
              synthesizeWithProviders engine 1024 [] goal of
            Right (SynthCandidates groups _) ->
              assertBool
                ("scoped quantified application fell outside the first "
                  ++ show synthMaxTried ++ " " ++ synthEngineName engine
                  ++ " groups: " ++ show (take synthMaxTried groups))
                $ any quantifiedTypeVariant
                $ concat $ take synthMaxTried groups
            Right other -> assertFailure $
              "unexpected scoped-provider outcome from "
                ++ synthEngineName engine ++ ": " ++ outcomeTag other
            Left err -> assertFailure err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
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
  properArgument = ProviderInstantiationArgument 0
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
            (ProviderQuery ["Demo"] (Just "Demo.Box")) family []
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
              [FAtom False "Demo.R (Demo.termByType Unit)"])])
          [])
  , testCase "retain occurrence-local finite data for a term parameter" $
      parseGoalSexp
          "(goal type (query (roots \"Demo\") (head \"Demo.Tag\")) \
          \(ind \"Demo.Tag (Demo.termByType Unit)\" \
          \(ctor \"Demo.Tag.mk\")))"
        @?= Right (ParsedGoal GoalType
          (ProviderQuery ["Demo"] (Just "Demo.Tag"))
          (FInd "Demo.Tag (Demo.termByType Unit)"
            [("Demo.Tag.mk", [])])
          [])
  , testCase "gate family sharing on universe-inhabiting parameters" $ do
      "def allProperTypeParams (args : Array Expr) : MetaM Bool := do"
        `isInfixOf` synthPrelude [] @?= True
      unlines
          [ "    let argType \8592 whnfR (\8592 inferType arg)"
          , "    if !argType.isSort then return false"
          ]
        `isInfixOf` synthPrelude [] @?= True
      "        if \8592 allProperTypeParams args then do"
        `isInfixOf` synthPrelude [] @?= True
      "          let properParams \8592 allProperTypeParams args"
        `isInfixOf` synthPrelude [] @?= True
      "          else if properParams then"
        `isInfixOf` synthPrelude [] @?= True
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
  , testCase "transport a recursive List rank-N family with Djinn" $
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineDjinn 0 [] listRankNGoal)
  , testCase "transport a recursive List rank-N family with Exference" $
      expectExactFamilyTerm "fun x => x _"
        (synthesizeWithProviders EngineExference 1024 [] listRankNGoal)
  , testCase "keep structural families with partial nominal evidence" $ do
      let natural = FAtom False "Nat"
          boolean = FAtom False "Bool"
          other = FAtom False "Higher.Other"
          pair = FParamInd "Higher.Pair" "Higher.Pair Nat Bool"
            [natural, boolean]
            [("Higher.Pair.mk", [natural, boolean])]
          provider = ProviderFragWithEvidence "Higher.unrelated"
            (FAll False "F"
              (FArr
                (FApp True "F Bool" (AppVariable "F") [boolean])
                other))
            ["F"]
            [[ProviderInstantiationNominalArgument 1 "Higher.Pair" [natural]]]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [provider]
              (FArr pair natural))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "partial evidence forced a structural family opaque: "
            ++ show candidates
  , testCase "construct a polymorphic recursive family natively with Djinn" $
      do
        let parameter = FVar "p"
            recursive = nativeRecursive "Demo.NativeRec p" parameter
            goal = FAll True "p" (FArr parameter recursive)
            candidates = allFamilyCandidates
              (synthesizeWithProviders EngineDjinn 0 [] goal)
        if any ("=> .done" `isInfixOf`) candidates
          then pure ()
          else assertFailure $
            "native recursive constructor did not specialize under forall: "
              ++ show candidates
  , testCase "compose independent native recursive components in Djinn" $ do
      let parameter = FVar "p"
          innerKey = "Demo.NativeInner p"
          inner = nativeInner innerKey parameter
          outerKey = "Demo.NativeOuter p"
          outer = nativeOuter outerKey parameter inner
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FAll True "p" (FArr parameter outer)))
      if any (\term -> ".wrap" `isInfixOf` term
              && ".done" `isInfixOf` term) candidates
        then pure ()
        else assertFailure $
          "independent native recursive components did not compose: "
            ++ show candidates
  , testCase "bound native Djinn recursion to one constructor layer" $ do
      let parameter = FVar "p"
          recursive = nativeRecursive "Demo.NativeRec p" parameter
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr parameter recursive))
      if not (any ("done" `isInfixOf`) candidates)
        then assertFailure $ "native recursive base constructor was lost: "
          ++ show candidates
        else if any ("again" `isInfixOf`) candidates
          then assertFailure $ "Djinn reopened native recursion below its "
            ++ "first constructor layer: " ++ show candidates
          else pure ()
  , testCase "withhold evidence after native recursive atomization" $ do
      let parameter = FVar "p"
          recursive = nativeRecursive "Demo.NativeRec p" parameter
      case synthesizeWithProviders EngineDjinn 0 []
          (FArr recursive parameter) of
        Right (SynthNoTerm _) -> pure ()
        Right other -> assertFailure $
          "native recursive elimination returned unexpected evidence: "
            ++ outcomeTag other
        Left err -> assertFailure err
  , testCase "reuse a recursive provider schema independent of order" $ do
      let target = recursiveBox True "Demo.RecBox consumer" consumerType
          inhabitant = ProviderFrag "Demo.anyRecBox"
            (FAll False "source"
              (recursiveBox True "Demo.RecBox source" (FVar "source")))
          schemaOnly = ProviderFrag "Demo.blockedRecBox"
            (FAll False "renamed" (FArr FBot
              (recursiveBox True "Demo.RecBox renamed" (FVar "renamed"))))
          check providers =
            let candidates = allFamilyCandidates
                  (synthesizeWithProviders EngineExference 1024 providers target)
            in if any ("Demo.anyRecBox" `isInfixOf`) candidates
                then pure ()
                else assertFailure $ "recursive provider source was lost in "
                  ++ show (map providerLeanName providers) ++ ": "
                  ++ show candidates
      mapM_ check [[inhabitant, schemaOnly], [schemaOnly, inhabitant]]
  , testCase "fit recursive rank-N fields at a structured occurrence" $ do
      let result = FAtom False "Demo.Result"
          consumer = FAll True "b" (FArr (FVar "b") result)
          target = recursiveCell "Demo.RecCell consumer" consumer
          schemaOnly = ProviderFrag "Demo.blockedRecCell"
            (FAll False "renamed" (FArr FBot
              (recursiveCell "Demo.RecCell renamed" (FVar "renamed"))))
          goal = FAll True "c"
            (FArr target (FArr (FVar "c") result))
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 2048 [schemaOnly] goal)
      if any (\term -> "match" `isInfixOf` term
              && " _ " `isInfixOf` term) candidates
        then pure ()
        else assertFailure $ "recursive rank-N fields were not fitted: "
          ++ show candidates
  , testCase "project a parameter through one recursive layer" $ do
      let parameter = FVar "p"
          headed = recursiveHeaded "Demo.Headed p" parameter
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 []
              (FAll True "p" (FArr headed parameter)))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "one-layer recursive projection produced no candidate: "
            ++ show candidates
  , testCase "project an impredicative parameter through one recursive layer" $ do
      let headed = recursiveHeaded "Demo.Headed poly" polytype
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 []
              (FArr headed polytype))
      if any (\term -> "match" `isInfixOf` term
              && "_ =>" `isInfixOf` term) candidates
        then pure ()
        else assertFailure $
          "impredicative recursive projection produced no candidate: "
            ++ show candidates
  , testCase "disambiguate a fixed field from a structured recursive parameter" $ do
      let natural = FAtom False "Nat"
          fixed = FProd natural natural
          boolean = FAtom False "Bool"
          family key parameter = FParamRec True "Demo.FixedRec" key
            [parameter]
            [("Demo.FixedRec.mk", [fixed, FAtom False key])]
          target = family "Demo.FixedRec (Nat × Nat)" fixed
          schemaOnly = ProviderFrag "Demo.blockedFixedRec"
            (FArr FBot (family "Demo.FixedRec Bool" boolean))
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [schemaOnly]
              (FArr target fixed))
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $
          "a second recursive occurrence did not preserve its fixed field: "
            ++ show candidates
  , testCase "keep structured recursive Djinn construction natively bounded" $ do
      let structured = FParamRec True "Demo.StructuredRec"
            "Demo.StructuredRec poly" [polytype]
            [ ("Demo.StructuredRec.done", [polytype])
            , ("Demo.StructuredRec.again",
                [FAtom False "Demo.StructuredRec poly"])
            ]
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineDjinn 0 []
              (FArr polytype structured))
      if not (any (".done" `isInfixOf`) candidates)
        then assertFailure $ "structured native constructor was lost: "
          ++ show candidates
        else if any (".again" `isInfixOf`) candidates
          then assertFailure $ "structured recursive family fell back to "
            ++ "reopenable constructor premises: " ++ show candidates
          else pure ()
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
  , testCase "ignore alpha-varying instance keys in family schemas" $ do
      let result = FAtom False "Demo.Result"
          family parameter key instanceKey =
            FParamInd "Demo.Constrained" key [parameter]
              [("Demo.Constrained.mk", [FInst instanceKey result])]
          left = family (FVar "a") "Demo.Constrained a" "Demo.C a"
          right = family (FVar "b") "Demo.Constrained b" "Demo.C b"
          goal = FAll True "a" (FAll True "b"
            (FInst "Demo.C b" (FArr left (FArr right result))))
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [] goal)
      if any (isInfixOf "match") candidates
        then pure ()
        else assertFailure $
          "diagnostic instance keys split one erased family schema: "
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
  , testCase "never conflate recursive heads sharing keys and constructors" $
      let parameter = FVar "a"
          family headName = FParamRec True headName "same display key"
            [parameter]
            [ ("Shared.nil", [])
            , ("Shared.cons",
                [parameter, FAtom False "same display key"])
            ]
          goal = FAll True "a"
            (FArr (family "Demo.LeftList") (family "Demo.RightList"))
          direct term = term == "fun _ x => x"
            || term == "fun _ => fun x => x"
          check engine =
            let candidates = allFamilyCandidates
                  (synthesizeWithProviders engine 1024 [] goal)
            in if any direct candidates
                then assertFailure $ "distinct recursive heads shared an "
                  ++ "identity in " ++ show engine ++ ": " ++ show candidates
                else pure ()
      in mapM_ check [EngineDjinn, EngineExference]
  , testCase "normalize recursive knots and ignore unused outer metadata" $ do
      let result = FVar "r"
          natural complete key = FParamRec complete "Nat" key []
            [ ("Nat.zero", [])
            , ("Nat.succ", [FAtom False key])
            ]
          left = natural True "Nat left"
          right = natural True "Nat right"
          hiddenPartial = natural False "Nat hidden"
          parameter = FVar "p"
          ambiguousOuter = FParamInd "Demo.Outer" "Demo.Outer p p"
            [parameter, parameter]
            [("Demo.Outer.mk", [hiddenPartial])]
          unusedOuter = ProviderFrag "Demo.unusedOuter"
            (FArr FBot ambiguousOuter)
          goal = FArr result (FArr (FArr right result) (FArr left result))
          candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [unusedOuter] goal)
      if any ("match" `isInfixOf`) candidates
        then pure ()
        else assertFailure $ "unused outer metadata hid recursive matches: "
          ++ show candidates
  , testCase "reject recursive exact-head arity disagreements" $ do
      let one = FParamRec True "Demo.ArityRec" "Demo.ArityRec a"
            [FVar "a"] [("Demo.ArityRec.one", [])]
          two = FParamRec True "Demo.ArityRec" "Demo.ArityRec a b"
            [FVar "a", FVar "b"] [("Demo.ArityRec.two", [])]
          goal = FAll True "a" (FAll True "b" (FArr one two))
          check engine = case
              synthesizeWithProviders engine 1024 [] goal of
            Left err
              | "incompatible proper-type arities" `isInfixOf` err -> pure ()
              | otherwise -> assertFailure $ "unexpected arity error in "
                  ++ show engine ++ ": " ++ err
            Right outcome -> assertFailure $ "recursive arity mismatch was "
              ++ "accepted in " ++ show engine ++ ": " ++ outcomeTag outcome
      mapM_ check [EngineDjinn, EngineExference]
  , testCase "keep partial and repeated recursive uses abstract" $ do
      let parameter = FVar "p"
          partial = recursiveList False "List p" parameter
          repeatedKey = "Demo.PairRec p p"
          repeated = FParamRec True "Demo.PairRec" repeatedKey
            [parameter, parameter]
            [ ("Demo.PairRec.more",
                [parameter, FAtom False repeatedKey])
            ]
      mapM_ (\engine -> do
          expectIncompleteNoFamilyTerm
            (synthesizeWithProviders engine 512 []
              (FArr partial parameter))
          expectIncompleteNoFamilyTerm
            (synthesizeWithProviders engine 512 []
              (FArr repeated parameter)))
        [EngineDjinn, EngineExference]
  , testCase "keep complete and partial recursive uses abstract with intro" $ do
      let parameter = FVar "p"
          partial = recursiveTree False "Demo.Tree partial" parameter
          complete = recursiveTree True "Demo.Tree complete" parameter
          check engine =
            let candidates = allFamilyCandidates
                  (synthesizeWithProviders engine 1024 []
                    (FArr partial (FArr parameter complete)))
            in if any treeElimination candidates
                then assertFailure $ "mixed completeness exposed elimination "
                  ++ "in " ++ show engine ++ ": " ++ show candidates
                else if any ("Demo.Tree.leaf" `isInfixOf`) candidates
                  then pure ()
                  else assertFailure $ "abstract recursive fallback lost "
                    ++ "introduction in " ++ show engine ++ ": "
                    ++ show candidates
          treeElimination term =
            "| .leaf" `isInfixOf` term
              || "| Demo.Tree.leaf" `isInfixOf` term
      mapM_ check [EngineDjinn, EngineExference]
  , testCase "share recursive and nominal uses through an abstract head" $ do
      let source = recursiveBox True "Demo.RecBox poly" polytype
          target = FApp False "Demo.RecBox poly"
            (AppNominal "Demo.RecBox") [polytype]
          goal = FArr source target
          recBoxElimination term =
            "| ⟨" `isInfixOf` term
              || "| Demo.RecBox.step" `isInfixOf` term
      expectExactFamilyTerm "fun x => x"
        (synthesizeWithProviders EngineDjinn 0 [] goal)
      let candidates = allFamilyCandidates
            (synthesizeWithProviders EngineExference 1024 [] goal)
      if null candidates
        then assertFailure "recursive/nominal fallback lost all conversions"
        else if any recBoxElimination candidates
          then assertFailure $ "recursive/nominal fallback exposed a match: "
            ++ show candidates
          else if any ("fun x =>" `isInfixOf`) candidates
            then pure ()
            else assertFailure $ "abstract conversions ignored their source: "
              ++ show candidates
  , testCase "keep incompatible recursive schemas abstract query-wide" $ do
      let result = FVar "r"
          other = FVar "s"
          leftKey = "Demo.Chain r"
          rightKey = "Demo.Chain s"
          left = FParamRec True "Demo.Chain" leftKey [result]
            [ ("Demo.Chain.link", [result, FAtom False leftKey]) ]
          right = FParamRec True "Demo.Chain" rightKey [other]
            [ ("Demo.Chain.link", [FAtom False rightKey]) ]
      expectIncompleteNoFamilyTerm
        (synthesizeWithProviders EngineExference 512 []
          (FArr left (FArr right result)))
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
  recursiveList complete key parameter = FParamRec complete "List" key
    [parameter]
    [ ("List.nil", [])
    , ("List.cons", [parameter, FAtom False key])
    ]
  listRankNGoal = FArr
    (FAll True "a" (recursiveList True "List a" (FVar "a")))
    (recursiveList True "List poly" polytype)
  recursiveBox complete key parameter = FParamRec complete "Demo.RecBox" key
    [parameter]
    [("Demo.RecBox.step", [parameter, FAtom False key])]
  recursiveCell key parameter = FParamRec True "Demo.RecCell" key
    [parameter] [("Demo.RecCell.mk", [parameter])]
  recursiveHeaded key parameter = FParamRec True "Demo.Headed" key
    [parameter]
    [("Demo.Headed.mk", [parameter, FAtom False key])]
  nativeRecursive key parameter = FParamRec True "Demo.NativeRec" key
    [parameter]
    [ ("Demo.NativeRec.done", [parameter])
    , ("Demo.NativeRec.again", [FAtom False key])
    ]
  nativeInner key parameter = FParamRec True "Demo.NativeInner" key
    [parameter]
    [ ("Demo.NativeInner.done", [parameter])
    , ("Demo.NativeInner.again", [FAtom False key])
    ]
  nativeOuter key parameter inner = FParamRec True "Demo.NativeOuter" key
    [parameter]
    [ ("Demo.NativeOuter.wrap", [inner])
    , ("Demo.NativeOuter.again", [FAtom False key])
    ]
  recursiveTree complete key parameter = FParamRec complete "Demo.Tree" key
    [parameter]
    [ ("Demo.Tree.leaf", [parameter])
    , ("Demo.Tree.branch", [FAtom False key, FAtom False key])
    ]
  consumerType = FAll True "b" (FArr (FVar "b") (FVar "b"))
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
          ++ "; outcome: " ++ familyOutcomeSummary outcome
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
  familyOutcomeSummary outcome = case outcome of
    Left err -> "error " ++ show err
    Right (SynthCandidates groups notes) ->
      "candidates " ++ show groups ++ ", notes " ++ show notes
    Right (SynthRefuted sound) -> "refuted " ++ show sound
    Right (SynthNoTerm notes) -> "no term, notes " ++ show notes

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
  , testCase "render five-binder hypothesis instantiation for Lean" $ do
      let variable = FVar
          forall5 a b c d e resultFrag =
            FAll True a
              (FAll True b
                (FAll True c (FAll True d (FAll True e resultFrag))))
          hypothesis = forall5 "a" "b" "c" "d" "e"
            (FArr (variable "a")
              (FArr (variable "b")
                (FArr (variable "c")
                  (FArr (variable "d")
                    (FArr (variable "e") (variable "R"))))))
          body = FArr hypothesis
            (FArr (variable "A")
              (FArr (variable "B")
                (FArr (variable "C")
                  (FArr (variable "D")
                    (FArr (variable "E") (variable "R"))))))
          goal = FAll True "A" (FAll True "B" (FAll True "C"
            (FAll True "D" (FAll True "E" (FAll True "R" body)))))
          check engine =
            case synthesizeWithProviders engine 128 [] goal of
              Right (SynthCandidates groups _) ->
                let candidates = concat groups
                    -- Eta-equivalent candidates can keep either the compact
                    -- or expanded spelling. Both spellings expose the five
                    -- retained type applications that this boundary tests.
                    instantiated candidate =
                      "f _ _ _ _ _ " `isInfixOf` candidate
                        || "=> f _ _ _ _ _" `isInfixOf` candidate
                in if any instantiated candidates
                    then pure ()
                    else assertFailure $
                      "expected a five-binder instantiation candidate from "
                        ++ synthEngineName engine ++ ", got: "
                        ++ show candidates
              Right other -> assertFailure $
                "unexpected five-binder synthesis outcome from "
                  ++ synthEngineName engine ++ ": " ++ outcomeTag other
              Left err -> assertFailure $
                "five-binder synthesis failed in "
                  ++ synthEngineName engine ++ ": " ++ err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
  , testCase "render six-binder hypothesis instantiation for Lean" $ do
      let variable = FVar
          forall6 a b c d e f resultFrag =
            FAll True a
              (FAll True b
                (FAll True c
                  (FAll True d (FAll True e (FAll True f resultFrag)))))
          hypothesis = forall6 "a" "b" "c" "d" "e" "f"
            (FArr (variable "a")
              (FArr (variable "b")
                (FArr (variable "c")
                  (FArr (variable "d")
                    (FArr (variable "e")
                      (FArr (variable "f") (variable "R")))))))
          body = FArr hypothesis
            (FArr (variable "A")
              (FArr (variable "B")
                (FArr (variable "C")
                  (FArr (variable "D")
                    (FArr (variable "E")
                      (FArr (variable "F") (variable "R")))))))
          goal = FAll True "A" (FAll True "B" (FAll True "C"
            (FAll True "D" (FAll True "E" (FAll True "F"
              (FAll True "R" body))))))
          check engine =
            case synthesizeWithProviders engine 256 [] goal of
              Right (SynthCandidates groups _) ->
                let candidates = concat groups
                    instantiated candidate =
                      "f _ _ _ _ _ _ " `isInfixOf` candidate
                        || "=> f _ _ _ _ _ _" `isInfixOf` candidate
                in if any instantiated candidates
                    then pure ()
                    else assertFailure $
                      "expected a six-binder instantiation candidate from "
                        ++ synthEngineName engine ++ ", got: "
                        ++ show candidates
              Right other -> assertFailure $
                "unexpected six-binder synthesis outcome from "
                  ++ synthEngineName engine ++ ": " ++ outcomeTag other
              Left err -> assertFailure $
                "six-binder synthesis failed in "
                  ++ synthEngineName engine ++ ": " ++ err
      mapM_ check [EngineDjinn, EngineExference, EngineBoth]
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
  , testCase "render a balanced eight-site quartic plan for Lean" $ do
      let variable = FVar
          -- Match the serializer exactly. The four result variables occur in
          -- the body and therefore cross as explicit FAlls. Each vacuous
          -- @forall A B C D E : Type, Q@ instead crosses as five ordinary
          -- arrows from the same opaque @Type@ atom. Sibling dependent
          -- identities reuse the serializer's depth-local @s4@ spelling.
          universe = FAtom False "Type"
          scheme codomain = foldr FArr codomain (replicate 5 universe)
          identity = FAll True "s4"
            (FArr (variable "s4") (variable "s4"))
          q = variable "s0"
          r = variable "s1"
          z = variable "s2"
          m = variable "s3"
          result = foldr1 FProd
            [ scheme q, scheme r, scheme z, scheme m
            , identity, identity, identity, identity
            ]
          body = foldr FArr result [scheme q, scheme r, scheme z, scheme m]
          goal = FAll True "s0"
            (FAll True "s1" (FAll True "s2" (FAll True "s3" body)))
          direct =
            "fun _ _ _ _ f g h f1 => "
              ++ "⟨f, ⟨g, ⟨h, ⟨f1, ⟨fun _ x => x, "
              ++ "⟨fun _ y => y, ⟨fun _ z => z, "
              ++ "fun _ w => w⟩⟩⟩⟩⟩⟩⟩"
          checkEngine engine = case
              synthesizeWithProviders engine 4096 [] goal of
            Right (SynthCandidates groups _) -> do
              let candidates = concat
                    $ take (synthVerificationWindow engine) groups
              assertBool
                ("expected direct quartic rank-N candidate from "
                  ++ synthEngineName engine ++ ", got: " ++ show candidates)
                (direct `elem` candidates)
            Right other -> assertFailure
              ("unexpected quartic outcome from " ++ synthEngineName engine
                ++ ": " ++ outcomeTag other)
            Left err -> assertFailure
              ("quartic synthesis failed in " ++ synthEngineName engine
                ++ ": " ++ err)
      mapM_ checkEngine [EngineDjinn, EngineExference, EngineBoth]
  , testCase "coalesce seven-binder sentinels for quintic Djinn planning" $ do
      let variable = FVar
          product7 names = foldr1 FProd $ map variable names
          wide names = foldr (FAll True) (product7 names) names
          identity name = FAll True name
            (FArr (variable name) (variable name))
          input = wide ["a", "b", "c", "d", "e", "f", "f0"]
          result = foldr1 FProd
            [ wide ["g", "h", "i", "j", "k", "l", "l0"]
            , wide ["m", "n", "o", "p", "q", "r", "r0"]
            , wide ["s", "t", "u", "v", "w", "x", "x0"]
            , wide ["y", "z", "a0", "b0", "c0", "d0", "e0"]
            , identity "i0"
            , identity "i1"
            , identity "i2"
            , identity "i3"
            , identity "i4"
            , wide ["z0", "z1", "z2", "z3", "z4", "z5", "z6"]
            ]
          goal = FArr input result
          direct =
            "fun x => ⟨x, ⟨x, ⟨x, ⟨x, ⟨fun _ y => y, "
              ++ "⟨fun _ z => z, ⟨fun _ w => w, "
              ++ "⟨fun _ x1 => x1, ⟨fun _ x2 => x2, x⟩⟩⟩⟩⟩⟩⟩⟩⟩"
      case synthesizeWithProviders EngineDjinn 0 [] goal of
        Right (SynthCandidates groups _) -> assertBool
          ("expected the direct quintic rank-N candidate, got: "
            ++ show groups)
          (direct `elem` concat groups)
        Right other -> assertFailure $
          "unexpected quintic synthesis outcome: " ++ outcomeTag other
        Left err -> assertFailure $
          "quintic synthesis failed after forall coalescing: " ++ err
  , testCase "render the eleven-site dual quintic plan for Lean" $ do
      let variable = FVar
          product7 names = foldr1 FProd $ map variable names
          wide names = foldr (FAll True) (product7 names) names
          identity name = FAll True name
            (FArr (variable name) (variable name))
          input = wide
            [ "source0", "source1", "source2", "source3"
            , "source4", "source5", "source6"
            ]
          result = foldr1 FProd
            [ identity "i0"
            , identity "i1"
            , identity "i2"
            , identity "i3"
            , wide ["a", "b", "c", "d", "e", "f", "f0"]
            , wide ["g", "h", "i", "j", "k", "l", "l0"]
            , wide ["m", "n", "o", "p", "q", "r", "r0"]
            , wide ["s", "t", "u", "v", "w", "x", "x0"]
            , wide ["y", "z", "a0", "b0", "c0", "d0", "e0"]
            , wide ["z0", "z1", "z2", "z3", "z4", "z5", "z6"]
            , identity "i4"
            ]
          goal = FArr input result
          direct =
            "fun x => ⟨fun _ y => y, ⟨fun _ z => z, "
              ++ "⟨fun _ w => w, ⟨fun _ x1 => x1, "
              ++ "⟨x, ⟨x, ⟨x, ⟨x, ⟨x, ⟨x, "
              ++ "fun _ x2 => x2⟩⟩⟩⟩⟩⟩⟩⟩⟩⟩"
      case synthesizeWithProviders EngineDjinn 0 [] goal of
        Right (SynthCandidates groups _) -> assertBool
          ("expected the direct dual-quintic rank-N candidate, got: "
            ++ show groups)
          (direct `elem` concat groups)
        Right other -> assertFailure $
          "unexpected dual-quintic synthesis outcome: " ++ outcomeTag other
        Left err -> assertFailure $
          "dual-quintic synthesis failed after forall coalescing: " ++ err
  ]

testProviderInfo :: String -> Maybe [String]
  -> ProviderInfo
testProviderInfo leanName binders =
  providerInfo leanName binders (FAtom False "test provider")

visibleTypeApplicationTests :: TestTree
visibleTypeApplicationTests = testGroup "Lean visible type applications"
  [ testCase "activate implicit provider arguments with Lean @ syntax" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      integerName <- expectRight $ mkIdentifier "Int"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor integerName :: Type String)
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing)) Map.empty
          ([], 0, []) (FAtom False "Nat") expression
        @?= Right ["@Demo.identity Int"]
  , testCase "keep provider dictionaries implicit with a named type argument" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a"])) Map.empty
          ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right ["Demo.global («a» := Nat)"]
  , testCase "preserve named provider type-argument order" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      booleanName <- expectRight $ mkIdentifier "Bool"
      natural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      boolean <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor booleanName :: Type String)
      let expression = VisibleTypeApplication
            (VisibleTypeApplication (Global providerName) natural) boolean
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a", "b"]))
          Map.empty ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right ["Demo.global («a» := Nat) («b» := Bool)"]
  , testCase "quote keyword and exotic provider binder names" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      booleanName <- expectRight $ mkIdentifier "Bool"
      natural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      boolean <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor booleanName :: Type String)
      let expression = VisibleTypeApplication
            (VisibleTypeApplication (Global providerName) natural) boolean
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["match", "«x-y»"]))
          Map.empty ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right ["Demo.global («match» := Nat) («x-y» := Bool)"]
  , testCase "reject misaligned live provider binder metadata" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      naturalName <- expectRight $ mkIdentifier "Nat"
      booleanName <- expectRight $ mkIdentifier "Bool"
      natural <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor naturalName :: Type String)
      boolean <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor booleanName :: Type String)
      let expression = VisibleTypeApplication
            (VisibleTypeApplication (Global providerName) natural) boolean
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a"]))
          Map.empty ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Left "cannot align visible type arguments for Lean provider Demo.global"
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
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing)) Map.empty
          ([], 0, []) (FAtom False "Nat") expression
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
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing))
          (Map.singleton "LeantType0" "Demo.Wrap")
        ([], 0, []) (FAtom False "Nat") expression
        @?= Right ["@Demo.identity (@Demo.Wrap Int)"]
  , testCase "restore a rigid opaque field as one parenthesized type" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      privateName <- expectRight $ mkIdentifier "LeantAtom0"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (TypeConstructor privateName :: Type String)
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing))
          (Map.singleton "LeantAtom0" "(Nat × Nat)")
          ([], 0, []) (FAtom False "Nat") expression
        @?= Right ["@Demo.identity @(Nat × Nat)"]
  , testCase "keep inferred visible type arguments distinct from foralls" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let expression = VisibleTypeApplication
            (Global providerName) inferredVisibleTypeArgument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing)) Map.empty
          ([], 0, []) (FAtom False "Nat") expression
        @?= Right ["@Demo.identity _"]
  , testCase "render a closed quantified named provider argument" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["source"] []
          (FunctionType (TypeVariable "source") (TypeVariable "source")))
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a"])) Map.empty
          ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right
          ["Demo.global («a» := (∀ (a0_0 : _), a0_0 → a0_0))"]
  , testCase "parenthesize a positional quantified type argument" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      argument <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["a"] []
          (FunctionType (TypeVariable "a") (TypeVariable "a")))
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.identity" Nothing)) Map.empty
          ([], 0, []) (FAtom False "Nat") expression
        @?= Right ["@Demo.identity (∀ (a0_0 : _), a0_0 → a0_0)"]
  , testCase "offer kind-directed local quantified arguments" $ do
      argument <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["a"] []
          (FunctionType (TypeVariable "a") (TypeVariable "a")))
      let token = FAtom False "Demo.Token"
          expression = Lambda [Bind "provider"] $
            VisibleTypeApplication (Local "provider") argument
          rendered = renderLeanTerm Map.empty Map.empty Map.empty ([], 0, [])
            (FArr (FAll False "hidden" token) token) expression
      case rendered of
        Left err -> assertFailure err
        Right variants -> do
          assertBool ("missing inferred-sort local variant: " ++ show variants)
            $ any ("(a0_0 : _)" `isInfixOf`) variants
          assertBool ("missing Type-directed local variant: " ++ show variants)
            $ any ("(a0_0 : Type _)" `isInfixOf`) variants
          assertBool ("missing Prop-directed local variant: " ++ show variants)
            $ any ("(a0_0 : Prop)" `isInfixOf`) variants
  , testCase "retain mixed local instantiations in each kind-hint lane" $ do
      argument <- expectRight $ specifiedVisibleTypeArgument
        (ForallType ["a"] []
          (FunctionType (TypeVariable "a") (TypeVariable "a")))
      let token = FAtom False "Demo.Token"
          provider = FAll False "hidden" token
          ambiguousFunction binder =
            FAll True binder (FArr token token)
          first = ambiguousFunction "firstType"
          second = ambiguousFunction "secondType"
          third = ambiguousFunction "thirdType"
          goal = FArr provider $ FArr first $ FArr second $ FArr third $
            FProd token (FProd first (FProd second third))
          expression = Lambda
            [Bind "provider", Bind "first", Bind "second", Bind "third"] $
            Tuple
              [ VisibleTypeApplication (Local "provider") argument
              , Tuple [Local "first", Tuple [Local "second", Local "third"]]
              ]
          expected binderDomain =
            "fun x f g h => \10216@x "
              ++ "(\8704 (a0_0 : " ++ binderDomain ++ "), a0_0 \8594 a0_0), "
              ++ "\10216f, \10216g, h _\10217\10217\10217"
          rendered = renderLeanTerm Map.empty Map.empty Map.empty ([], 0, [])
            goal expression
      case rendered of
        Left err -> assertFailure err
        Right variants -> do
          assertBool ("renderer exceeded its three 12-variant lanes: "
              ++ show variants)
            (length variants <= 36)
          mapM_
            (\binderDomain -> assertBool
              (binderDomain ++ " lane lost its third-site-only variant: "
                ++ show variants)
              (expected binderDomain `elem` variants))
            ["_", "Type _", "Prop"]
  , testCase "render alpha-renamed quantified arguments identically" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let source variable = ForallType [variable] []
            (FunctionType (TypeVariable variable) (TypeVariable variable))
              :: Type String
      leftArgument <- expectRight $ specifiedVisibleTypeArgument (source "a")
      rightArgument <- expectRight $ specifiedVisibleTypeArgument (source "renamed")
      let renderArgument argument = renderLeanTerm Map.empty
            (Map.singleton "leantProvider0"
              (testProviderInfo "Demo.global" $ Just ["a"]))
            Map.empty ([], 0, []) (FAtom False "Demo.Token")
            (VisibleTypeApplication (Global providerName) argument)
      renderArgument leftArgument @?= renderArgument rightArgument
  , testCase "preserve nested quantified shadowing with distinct names" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      let quantified = ForallType ["x"] []
            (FunctionType (TypeVariable "x")
              (ForallType ["x"] []
                (FunctionType (TypeVariable "x") (TypeVariable "x"))))
              :: Type String
      argument <- expectRight $ specifiedVisibleTypeArgument quantified
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a"])) Map.empty
          ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right
          [ "Demo.global («a» := (∀ (a0_0 : _), a0_0 → "
              ++ "∀ (a1_0 : _), a1_0 → a1_0))"
          ]
  , testCase "render constrained quantified Lean type arguments" $ do
      providerName <- expectRight $ mkIdentifier "leantProvider0"
      className <- expectRight $ mkIdentifier "C"
      let constrained = ForallType ["a"]
            [Constraint className [TypeVariable "a"]]
            (TypeVariable "a") :: Type String
      argument <- expectRight $ specifiedVisibleTypeArgument constrained
      let expression = VisibleTypeApplication (Global providerName) argument
      renderLeanTerm Map.empty
          (Map.singleton "leantProvider0"
            (testProviderInfo "Demo.global" $ Just ["a"])) Map.empty
          ([], 0, []) (FAtom False "Demo.Token") expression
        @?= Right
          [ "Demo.global («a» := (∀ (a0_0 : _), "
              ++ "[C a0_0] → a0_0))"
          ]
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
