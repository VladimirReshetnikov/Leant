module Main (main) where

import Control.Exception (evaluate, finally)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Char8 as BS
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (isInfixOf)
import Data.Maybe (isNothing)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Word (Word8)
import Numeric.Natural (Natural)
import System.Directory
  ( canonicalizePath
  , copyFile
  , createDirectory
  , createDirectoryIfMissing
  , createFileLink
  , doesFileExist
  , findExecutable
  , getPermissions
  , getTemporaryDirectory
  , removeFile
  , removePathForcibly
  , setOwnerExecutable
  , setPermissions
  )
import System.FilePath ((</>), normalise, takeDirectory)
import System.IO (hClose, openBinaryTempFile)
import System.Info (os)
import System.Timeout (timeout)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, assertFailure, testCase)

import qualified Language.Haskell.Djex as Djex
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
import qualified Leant.Json as Json
import Leant.Json.Bounded
  ( BoundedJsonError (..)
  , BoundedJsonErrorKind (..)
  , BoundedJsonLimit (..)
  , BoundedJsonLimits (..)
  , BoundedJsonValue (..)
  , parseBoundedJson
  )
import Leant.Synth.Engine
  ( CheckedLengthHandoff
  , DetailedCandidateGroup
  , DetailedSynthOutcome (..)
  , DetailedVerificationVariant
  , TypedCandidateSemanticSidecar
  , ExferenceRunAuthorityInspection (..)
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
  ( CheckedLengthQuery
  , prepareLengthQueryFromHandoff
  )
import Leant.Synth.Length.Configuration
  ( LengthRankingConfiguration
  , LengthRankingConfigurationError (..)
  , LengthRankingConfigurationSource (..)
  , LengthRankingPolicy
  , LengthRankingPolicySource (..)
  , mkLengthRankingConfiguration
  , mkLengthRankingPolicy
  , rankVerifiedLengthCandidatesConfigured
  , rankVerifiedLengthCandidatesWithPolicy
  )
import Leant.Synth.Length.Configuration.File
  ( DisabledLengthRankingConfiguration
  , LengthRankingConfigurationActivationError (..)
  , LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationFileError (..)
  , LengthRankingConfigurationFileField (..)
  , LengthRankingConfigurationFileObject (..)
  , LengthRankingConfigurationFileTextMeasure (..)
  , LengthRankingConfigurationFileValueType (..)
  , LengthRankingConfigurationSyntaxError (..)
  , LengthRankingConfigurationSyntaxLimit (..)
  , LengthRankingConfigurationSyntaxPhase (..)
  , activateLengthRankingConfiguration
  , decodeLengthRankingConfigurationFile
  , lengthRankingConfigurationFileFormat
  , lengthRankingConfigurationFileJsonLimits
  , lengthRankingConfigurationFileVersion
  )
import Leant.Synth.Length.Configuration.File.Acquire
  ( LengthRankingConfigurationFileAdmissionError (..)
  , LengthRankingConfigurationFileLoadError
  , LengthRankingConfigurationFileLoadErrorClass (..)
  , LengthRankingConfigurationFileRequest
  , LengthRankingConfigurationFileSource (..)
  , lengthRankingConfigurationFileLoadCleanupIncomplete
  , lengthRankingConfigurationFileLoadErrorClass
  , lengthRankingConfigurationFileLoadMaximumBytes
  , lengthRankingConfigurationFileMaximumPathCharacters
  , lengthRankingConfigurationFileMaximumTimeoutMilliseconds
  , loadLengthRankingConfigurationFile
  , mkLengthRankingConfigurationFileRequest
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContract (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthSpineIdentity (..)
  )
import Leant.Synth.Length.PostVerification
  ( LengthPostVerificationFailure (..)
  , LengthPostVerificationResult
  , assessVerifiedLengthCandidatesConfigured
  , assessVerifiedLengthCandidatesWithPolicy
  , lengthPostVerificationAdapterFailure
  , lengthPostVerificationCandidates
  , lengthPostVerificationRanking
  , lengthPostVerificationSealedBatch
  )
import Leant.Synth.Length.Ranking
  ( LengthRanking
  , LengthRankingAssessment (..)
  , LengthRankingFailureClass (..)
  , LengthRankingInputError (..)
  , LengthPreparationRefusalClass (..)
  , lengthHandoffPreparationRefusalClass
  , lengthPreparationRefusalClassCode
  , lengthQueryPreparationRefusalClass
  , lengthRankingCandidates
  , lengthRankingFailure
  , lengthRankingFailureClass
  , lengthRankingFailureCleanupIncomplete
  , lengthRankingFailureOriginalIndex
  , rankVerifiedLengthCandidates
  , rankedLengthCandidateAssessment
  , rankedLengthCandidateOriginalIndex
  , rankedLengthCandidatePreparationRefusal
  , rankedLengthCandidateVerified
  )
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
import Leant.Synth.PostVerification
  ( PostVerificationCollection (..)
  , PostVerificationError (..)
  , postVerificationBatchCandidates
  , postVerificationCandidateVerified
  , postVerificationInputCandidates
  , sealPostVerificationBatch
  , skipPostVerificationAssessment
  , withPostVerificationInput
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
  , VerificationBatch
  , Verified
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
  , boundedJsonTests
  , snapshotMetadataTests
  , sessionReplayTests
  , providerCacheTests
  , translationPreparationTests
  , providerScheduleTests
  , combinedEngineMergeTests
  , typedCandidateRoutingTests
  , lengthRankingTests
  , replayPlanTests
  , providerProgramTests
  , candidateVerificationTests
  , verificationObservabilityTests
  , postVerificationTests
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

boundedJsonTests :: TestTree
boundedJsonTests = testGroup "strict bounded JSON"
  [ testCase "retain exact values, number spellings, and object order"
      assertBoundedJsonValues
  , testCase "decode UTF-8 scalars and every permitted string escape"
      assertBoundedJsonUnicode
  , testCase "recognize the complete closed syntax-error vocabulary"
      assertBoundedJsonSyntaxErrors
  , testCase "enforce exact JSON number grammar without rounding"
      assertBoundedJsonNumbers
  , testCase "reject decoded duplicate keys, including escaped aliases"
      assertBoundedJsonDuplicateKeys
  , testCase "admit every exact resource boundary and stop at maximum plus one"
      assertBoundedJsonLimits
  , testCase "keep source snippets and duplicate keys out of errors"
      assertBoundedJsonErrorSanitization
  ]

assertBoundedJsonValues :: IO ()
assertBoundedJsonValues = do
  parseBoundedJson generousBoundedJsonLimits
      (BS.pack
        "{\"second\":[null,true,false,-12,1.25,1e+2],\"first\":0}")
    @?= Right (BoundedJsonObject
      [ ( Text.pack "second"
        , BoundedJsonArray
            [ BoundedJsonNull
            , BoundedJsonBool True
            , BoundedJsonBool False
            , BoundedJsonInteger (-12)
            , BoundedJsonNonInteger $ Text.pack "1.25"
            , BoundedJsonNonInteger $ Text.pack "1e+2"
            ]
        )
      , (Text.pack "first", BoundedJsonInteger 0)
      ])
  parseBoundedJson generousBoundedJsonLimits
      (BS.pack " { \"first\" : 0, \"second\" : 1 } \r\n")
    @?= Right (BoundedJsonObject
      [ (Text.pack "first", BoundedJsonInteger 0)
      , (Text.pack "second", BoundedJsonInteger 1)
      ])

assertBoundedJsonUnicode :: IO ()
assertBoundedJsonUnicode = do
  let unicode = Text.pack "\233\x1d11e"
      rawDocument = ByteString.concat
        [BS.pack "\"", TextEncoding.encodeUtf8 unicode, BS.pack "\""]
      escapedDocument = BS.pack
        "\"\\\"\\\\\\/\\b\\f\\n\\r\\t\\u0041\\uD834\\uDD1E\""
      escapedValue = Text.pack
        ['"', '\\', '/', '\b', '\f', '\n', '\r', '\t', 'A', '\x1d11e']
  parseBoundedJson generousBoundedJsonLimits rawDocument @?=
    Right (BoundedJsonString unicode)
  parseBoundedJson generousBoundedJsonLimits escapedDocument @?=
    Right (BoundedJsonString escapedValue)

assertBoundedJsonSyntaxErrors :: IO ()
assertBoundedJsonSyntaxErrors = do
  mapM_ assertCase cases
  parseBoundedJson generousBoundedJsonLimits
      (ByteString.pack [0x6e, 0x75, 0x6c, 0x6c, 0x20, 0xe2, 0x28, 0xa1])
    @?= Left (BoundedJsonSyntaxRejected BoundedJsonInvalidUTF8 6)
 where
  assertCase (label, expected, input) =
    assertBoundedJsonSyntax label expected input

  cases =
    [ ("UTF-8 BOM", BoundedJsonUTF8BOM,
        ByteString.pack [0xef, 0xbb, 0xbf] `ByteString.append`
          BS.pack "null")
    , ("invalid UTF-8", BoundedJsonInvalidUTF8,
        ByteString.pack [0xed, 0xa0, 0x80])
    , ("unexpected end", BoundedJsonUnexpectedEnd, BS.empty)
    , ("unexpected token", BoundedJsonUnexpectedToken, BS.pack "?")
    , ("trailing content", BoundedJsonTrailingContent,
        BS.pack "null null")
    , ("object key", BoundedJsonExpectedObjectKey, BS.pack "{0:0}")
    , ("colon", BoundedJsonExpectedColon, BS.pack "{\"a\" 0}")
    , ("object delimiter", BoundedJsonExpectedObjectDelimiter,
        BS.pack "{\"a\":0 \"b\":1}")
    , ("array delimiter", BoundedJsonExpectedArrayDelimiter,
        BS.pack "[0 1]")
    , ("unterminated string", BoundedJsonUnterminatedString,
        BS.pack "\"unterminated")
    , ("raw control", BoundedJsonRawControlCharacter,
        ByteString.pack [0x22, 0x0a, 0x22])
    , ("escape", BoundedJsonInvalidEscape, BS.pack "\"\\x\"")
    , ("Unicode escape", BoundedJsonInvalidUnicodeEscape,
        BS.pack "\"\\u00xz\"")
    , ("lone high surrogate", BoundedJsonLoneSurrogate,
        BS.pack "\"\\uD800\"")
    , ("number", BoundedJsonInvalidNumber, BS.pack "01")
    , ("duplicate key", BoundedJsonDuplicateObjectKey,
        BS.pack "{\"a\":0,\"\\u0061\":1}")
    ]

assertBoundedJsonNumbers :: IO ()
assertBoundedJsonNumbers = do
  mapM_ assertValid valid
  mapM_ assertInvalid invalid
  assertBoundedJsonSyntax "leading plus" BoundedJsonUnexpectedToken
    $ BS.pack "+1"
 where
  assertValid (source, expected) =
    parseBoundedJson generousBoundedJsonLimits (BS.pack source) @?=
      Right expected

  valid =
    [ ("0", BoundedJsonInteger 0)
    , ("-0", BoundedJsonInteger 0)
    , ("123456789", BoundedJsonInteger 123456789)
    , ("-42", BoundedJsonInteger (-42))
    , ("0.0", BoundedJsonNonInteger $ Text.pack "0.0")
    , ("-0.5", BoundedJsonNonInteger $ Text.pack "-0.5")
    , ("1e9", BoundedJsonNonInteger $ Text.pack "1e9")
    , ("1E+9", BoundedJsonNonInteger $ Text.pack "1E+9")
    , ("1e-9", BoundedJsonNonInteger $ Text.pack "1e-9")
    ]

  assertInvalid source = assertBoundedJsonSyntax source
    BoundedJsonInvalidNumber $ BS.pack source

  invalid = ["01", "-01", "1.", "1e", "1e+", "--1", "1-2"]

assertBoundedJsonDuplicateKeys :: IO ()
assertBoundedJsonDuplicateKeys = do
  mapM_ (assertBoundedJsonSyntax "duplicate object key"
      BoundedJsonDuplicateObjectKey . BS.pack)
    [ "{\"a\":0,\"a\":1}"
    , "{\"a\":0,\"b\":1,\"a\":2}"
    , "{\"a\":0,\"\\u0061\":1}"
    , "{\"\\u00e9\":0,\"\\u00E9\":1}"
    ]

assertBoundedJsonLimits :: IO ()
assertBoundedJsonLimits = do
  mapM_ assertCase boundedJsonLimitCases
  let zeroDepth = generousBoundedJsonLimits
        { boundedJsonMaximumNestingDepth = 0 }
      zeroNodes = generousBoundedJsonLimits
        { boundedJsonMaximumNodes = 0 }
      zeroDepthAndNodes = zeroDepth
        { boundedJsonMaximumNodes = 0 }
  parseBoundedJson zeroDepth (BS.pack "0") @?=
    Right (BoundedJsonInteger 0)
  parseBoundedJson zeroDepth (BS.pack "[]") @?=
    Left (BoundedJsonLimitExceeded BoundedJsonNestingDepth 0 1 0)
  parseBoundedJson zeroNodes (BS.pack "0") @?=
    Left (BoundedJsonLimitExceeded BoundedJsonNodes 0 1 0)
  parseBoundedJson zeroDepthAndNodes (BS.pack "[]") @?=
    Left (BoundedJsonLimitExceeded BoundedJsonNestingDepth 0 1 0)
  parseBoundedJson zeroDepthAndNodes (BS.pack "?") @?=
    Left (BoundedJsonSyntaxRejected BoundedJsonUnexpectedToken 0)
 where
  assertCase
      (label, field, maximumValue, offset, limits, exact, excessive) = do
    case parseBoundedJson limits exact of
      Left failure -> assertFailure $ "exact " ++ label ++
        " boundary was rejected: " ++ show failure
      Right _ -> pure ()
    observed <- timeout 1000000 $ evaluate $
      parseBoundedJson limits excessive
    observed @?= Just (Left $ BoundedJsonLimitExceeded
      field maximumValue (maximumValue + 1) offset)

boundedJsonLimitCases
  :: [( String
      , BoundedJsonLimit
      , Natural
      , Natural
      , BoundedJsonLimits
      , ByteString.ByteString
      , ByteString.ByteString
      )]
boundedJsonLimitCases =
  [ ( "total bytes"
    , BoundedJsonTotalBytes
    , 4
    , 4
    , generousBoundedJsonLimits
        { boundedJsonMaximumTotalBytes = 4 }
    , BS.pack "null"
    , BS.pack "null "
    )
  , ( "nesting depth"
    , BoundedJsonNestingDepth
    , 2
    , 2
    , generousBoundedJsonLimits
        { boundedJsonMaximumNestingDepth = 2 }
    , BS.pack "[[0]]"
    , BS.pack "[[[0]]]"
    )
  , ( "nodes"
    , BoundedJsonNodes
    , 2
    , 3
    , generousBoundedJsonLimits
        { boundedJsonMaximumNodes = 2 }
    , BS.pack "[0]"
    , BS.pack "[0,0]"
    )
  , ( "object members"
    , BoundedJsonObjectMembers
    , 2
    , 13
    , generousBoundedJsonLimits
        { boundedJsonMaximumObjectMembers = 2 }
    , BS.pack "{\"a\":0,\"b\":0}"
    , BS.pack "{\"a\":0,\"b\":0,\"c\":0}"
    )
  , ( "array elements"
    , BoundedJsonArrayElements
    , 2
    , 5
    , generousBoundedJsonLimits
        { boundedJsonMaximumArrayElements = 2 }
    , BS.pack "[0,0]"
    , BS.pack "[0,0,0]"
    )
  , ( "object-key UTF-8 bytes"
    , BoundedJsonObjectKeyUtf8Bytes
    , 2
    , 2
    , generousBoundedJsonLimits
        { boundedJsonMaximumObjectKeyUtf8Bytes = 2 }
    , utf8JsonObject "\233"
    , utf8JsonObject "\8364"
    )
  , ( "string UTF-8 bytes"
    , BoundedJsonStringUtf8Bytes
    , 2
    , 1
    , generousBoundedJsonLimits
        { boundedJsonMaximumStringUtf8Bytes = 2 }
    , utf8JsonString "\233"
    , utf8JsonString "\8364"
    )
  , ( "string Unicode scalars"
    , BoundedJsonStringUnicodeScalars
    , 1
    , 5
    , generousBoundedJsonLimits
        { boundedJsonMaximumStringUnicodeScalars = 1 }
    , utf8JsonString "\x1d11e"
    , utf8JsonString "\x1d11e\&a"
    )
  , ( "number bytes"
    , BoundedJsonNumberBytes
    , 2
    , 2
    , generousBoundedJsonLimits
        { boundedJsonMaximumNumberBytes = 2 }
    , BS.pack "-1"
    , BS.pack "-12"
    )
  ]

assertBoundedJsonErrorSanitization :: IO ()
assertBoundedJsonErrorSanitization = do
  first <- expectBoundedJsonFailure $ BS.pack
    "{\"private-a\":0,\"private-a\":1}"
  second <- expectBoundedJsonFailure $ BS.pack
    "{\"private-b\":0,\"private-b\":1}"
  first @?= second
  let rendered = show first
  assertBool "a duplicate object key leaked through the error"
    $ not $ "private-a" `isInfixOf` rendered
  trailing <- expectBoundedJsonFailure
    $ BS.pack "null PRIVATE_DYNAMIC_TRAILING_BYTES"
  assertBool "trailing source bytes leaked through the error"
    $ not $ "PRIVATE_DYNAMIC_TRAILING_BYTES" `isInfixOf` show trailing

assertBoundedJsonSyntax
  :: String
  -> BoundedJsonErrorKind
  -> ByteString.ByteString
  -> IO ()
assertBoundedJsonSyntax label expected input =
  case parseBoundedJson generousBoundedJsonLimits input of
    Left (BoundedJsonSyntaxRejected observed _) -> observed @?= expected
    Left failure -> assertFailure $ label ++
      " produced a limit failure instead of " ++ show expected ++
      ": " ++ show failure
    Right value -> assertFailure $ label ++ " was accepted as " ++ show value

expectBoundedJsonFailure
  :: ByteString.ByteString
  -> IO BoundedJsonError
expectBoundedJsonFailure input =
  case parseBoundedJson generousBoundedJsonLimits input of
    Left failure -> pure failure
    Right value -> assertFailure ("expected bounded JSON rejection, got " ++
      show value) >> error "unreachable"

generousBoundedJsonLimits :: BoundedJsonLimits
generousBoundedJsonLimits = BoundedJsonLimits
  { boundedJsonMaximumTotalBytes = 1048576
  , boundedJsonMaximumNestingDepth = 1024
  , boundedJsonMaximumNodes = 65536
  , boundedJsonMaximumObjectMembers = 1024
  , boundedJsonMaximumArrayElements = 1024
  , boundedJsonMaximumObjectKeyUtf8Bytes = 65536
  , boundedJsonMaximumStringUtf8Bytes = 65536
  , boundedJsonMaximumStringUnicodeScalars = 65536
  , boundedJsonMaximumNumberBytes = 1024
  }

utf8JsonString :: String -> ByteString.ByteString
utf8JsonString value = ByteString.concat
  [ BS.pack "\""
  , TextEncoding.encodeUtf8 $ Text.pack value
  , BS.pack "\""
  ]

utf8JsonObject :: String -> ByteString.ByteString
utf8JsonObject key = ByteString.concat
  [ BS.pack "{\""
  , TextEncoding.encodeUtf8 $ Text.pack key
  , BS.pack "\":null}"
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

postVerificationTests :: TestTree
postVerificationTests = testGroup "post-verification ordering boundary"
  [ testCase "keep the disabled stage exact and non-strict" $ do
      verification <- syntheticPostVerificationBatch
        ["post-verification-first", "post-verification-second"]
      skipPostVerificationAssessment verification @?=
        verifiedCandidateReceipts verification
      let poison :: DetailedVerificationVariant
          poison = error "disabled stage forced a verified candidate"
      lazyVerification <- verifyCandidateGroups 1
        (const $ pure VariantAccepted) [[poison]]
      length (skipPostVerificationAssessment lazyVerification) @?= 1
      withPostVerificationInput lazyVerification $ \input -> case
          postVerificationInputCandidates input of
        [candidate] -> do
          batch <- expectRight $ sealPostVerificationBatch 1 input [candidate]
          length (postVerificationBatchCandidates batch) @?= 1
        candidates -> assertFailure $
          "unexpected lazy handle count: " ++ show (length candidates)
  , testCase "seal only a complete exact permutation" $ do
      verification <- syntheticPostVerificationBatch
        [ "post-verification-first"
        , "post-verification-second"
        , "post-verification-third"
        ]
      withPostVerificationInput verification $ \input -> case
          postVerificationInputCandidates input of
        [first, second, third] -> do
          batch <- expectRight $ sealPostVerificationBatch 3 input
            [third, first, second]
          postVerificationBatchCandidates batch @?=
            map postVerificationCandidateVerified [third, first, second]
          assertPostVerificationError
            (PostVerificationProposalLengthMismatch 3 2)
            $ sealPostVerificationBatch 3 input [first, second]
          assertPostVerificationError
            (PostVerificationProposalDuplicateIndex 0)
            $ sealPostVerificationBatch 3 input [first, first, second]
        candidates -> assertFailure $
          "unexpected post-verification handle count: "
            ++ show (length candidates)
  , testCase "keep equal occurrences distinct and bound proposals productively" $ do
      verification <- syntheticPostVerificationBatch
        [ "post-verification-first"
        , "post-verification-second"
        , "post-verification-third"
        ]
      withPostVerificationInput verification $ \input -> case
          postVerificationInputCandidates input of
        [first, second, third] -> do
          assertPostVerificationError
            (PostVerificationCollectionLimitExceeded
              PostVerificationCandidates 2 3)
            $ sealPostVerificationBatch 2 input
                (error "candidate admission forced the proposals")
          bounded <- timeout 1000000 $ evaluate
            $ sealPostVerificationBatch 3 input
                (cycle [first, second, third])
          case bounded of
            Just result -> assertPostVerificationError
              (PostVerificationCollectionLimitExceeded
                PostVerificationProposals 3 4)
              result
            Nothing -> assertFailure
              "cyclic post-verification proposals were not rejected"
        candidates -> assertFailure $
          "unexpected bounded handle count: " ++ show (length candidates)

      duplicates <- syntheticPostVerificationBatch
        ["post-verification-same", "post-verification-same"]
      withPostVerificationInput duplicates $ \input -> case
          postVerificationInputCandidates input of
        [first, second] -> do
          batch <- expectRight $ sealPostVerificationBatch 2 input
            [second, first]
          postVerificationBatchCandidates batch @?=
            map postVerificationCandidateVerified [second, first]
          assertPostVerificationError
            (PostVerificationProposalDuplicateIndex 0)
            $ sealPostVerificationBatch 2 input [first, first]
        candidates -> assertFailure $
          "unexpected duplicate handle count: " ++ show (length candidates)
  ]

syntheticPostVerificationBatch
  :: [String]
  -> IO (VerificationBatch DetailedVerificationVariant)
syntheticPostVerificationBatch spellings =
  verifyCandidateGroups (length spellings) (const $ pure VariantAccepted)
    [ detailedCandidateGroupVerificationVariants
        $ detailedCandidateGroup RouteTypedCandidate [spelling]
    | spelling <- spellings
    ]

assertPostVerificationError
  :: PostVerificationError
  -> Either PostVerificationError batch
  -> IO ()
assertPostVerificationError expected result = case result of
  Left actual -> actual @?= expected
  Right _ -> assertFailure $
    "post-verification proposal was admitted; expected: " ++ show expected

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

lengthRankingTests :: TestTree
lengthRankingTests = testGroup "checked Length behavioral ranking"
  [ testCase "sanitize every pure preparation refusal without forcing payloads"
      assertLengthPreparationRefusalClasses
  , testCase "admit the exact bound and reject a cyclic maximum-plus-one"
      assertLengthRankingInputBound
  , testCase "leave an all-ineligible batch unassessed without opening"
      assertLengthRankingAllIneligible
  , testCase "keep sat, unsat, and unknown heuristic statuses neutral"
      assertLengthRankingNeutralStatuses
  , testCase
      "stably demote replayed counterexamples without pruning or reassociation"
      assertLengthRankingCounterexampleDemotion
  , testCase
      "reset every candidate in original order after an operational failure"
      assertLengthRankingAtomicFallback
  , testCase
      "adapt ranking only through a validated post-verification permutation"
      assertLengthPostVerificationAdapter
  , lengthRankingConfigurationTests
  ]

lengthRankingConfigurationTests :: TestTree
lengthRankingConfigurationTests = testGroup "explicit ranking configuration"
  [ testCase
      "reject a PATH-resolvable relative executable before later poison"
      assertLengthRankingConfigurationRelativePath
  , testCase "reject a malformed explicit SHA-256 pin"
      assertLengthRankingConfigurationDigest
  , testCase "enforce explicit execution admission limits"
      assertLengthRankingConfigurationExecutionLimits
  , testCase "reject explicit evaluation limits after execution validation"
      assertLengthRankingConfigurationEvaluationLimits
  , testCase
      "match the direct runner for all-ineligible input without discovery"
      assertLengthRankingConfiguredAllIneligible
  , testCase "match the direct runner for healthy and failing live rankings"
      assertLengthRankingConfiguredLiveEquivalence
  , testCase "reuse one sealed solver policy with request-owned contracts"
      assertLengthRankingPolicyContractSeparation
  , lengthRankingConfigurationFileTests
  ]

lengthRankingConfigurationFileTests :: TestTree
lengthRankingConfigurationFileTests = testGroup
  "versioned bounded ranking configuration file"
  [ testCase "decode order-invariant pinned and unpinned v1 files explicitly"
      assertLengthRankingConfigurationFileActivation
  , testCase "apply format, version, schema, decimal, and digest precedence"
      assertLengthRankingConfigurationFileSchemaPrecedence
  , testCase "validate execution before evaluation before contract syntax"
      assertLengthRankingConfigurationFileValidationPrecedence
  , testCase "decode and activate without opening the configured executable"
      assertLengthRankingConfigurationFileNoOpen
  , testCase "reject unknown, missing, and mistyped fields at every object"
      assertLengthRankingConfigurationFileObjectSchema
  , testCase "admit operational caps exactly and reject maximum plus one"
      assertLengthRankingConfigurationFileOperationalCaps
  , testCase "decode every Length syntax constructor and reject bad shapes"
      assertLengthRankingConfigurationFileSyntaxShapes
  , testCase "enforce bounded contract syntax and provider associations"
      assertLengthRankingConfigurationFileSyntaxBounds
  , testCase "match the explicit configured live runner"
      assertLengthRankingConfigurationFileLiveEquivalence
  , testCase "keep paths, digests, fields, tags, and names out of Show errors"
      assertLengthRankingConfigurationFileShowRedaction
  , lengthRankingConfigurationFileAcquisitionTests
  ]

lengthRankingConfigurationFileAcquisitionTests :: TestTree
lengthRankingConfigurationFileAcquisitionTests = testGroup
  "bounded explicit file acquisition"
  [ testCase "admit finite paths and timeouts in a productive fixed order"
      assertLengthRankingConfigurationFileRequestAdmission
  , testCase "load and decode one explicitly admitted regular file"
      assertLengthRankingConfigurationFileAcquisition
  , testCase "reject non-regular and final-component symlink sources"
      assertLengthRankingConfigurationFileSourceTypes
  , testCase "probe the exact byte ceiling and cap the excess observation"
      assertLengthRankingConfigurationFileAcquisitionByteLimit
  , testCase "sanitize acquisition failures without losing their phase"
      assertLengthRankingConfigurationFileAcquisitionRedaction
  ]

assertLengthRankingConfigurationFileRequestAdmission :: IO ()
assertLengthRankingConfigurationFileRequestAdmission =
  withTemporaryDirectory "leant-length-acquisition-admission" $ \root -> do
    lengthRankingConfigurationFileMaximumPathCharacters @?= 4096
    lengthRankingConfigurationFileMaximumTimeoutMilliseconds @?= 60000
    lengthRankingConfigurationFileLoadMaximumBytes @?=
      boundedJsonMaximumTotalBytes lengthRankingConfigurationFileJsonLimits
    let exactPath = root ++ replicate
          (fromIntegral lengthRankingConfigurationFileMaximumPathCharacters
            - length root)
          'a'
        exactSource = LengthRankingConfigurationFileSource exactPath
          lengthRankingConfigurationFileMaximumTimeoutMilliseconds
    case mkLengthRankingConfigurationFileRequest exactSource of
      Left failure -> assertFailure $ "exact request was rejected: "
        ++ show failure
      Right _ -> pure ()

    let cyclicPath = root ++ repeat 'a'
        cyclicSource = LengthRankingConfigurationFileSource cyclicPath
          (error "timeout forced after an oversized path")
    case mkLengthRankingConfigurationFileRequest cyclicSource of
      Left failure -> failure @?=
        LengthRankingConfigurationFilePathCharacterLimitExceeded 4096 4097
      Right _ -> assertFailure "cyclic oversized path was admitted"

    assertAdmissionFailure LengthRankingConfigurationFilePathEmpty
      $ LengthRankingConfigurationFileSource "" 1
    assertAdmissionFailure LengthRankingConfigurationFilePathContainsNul
      $ LengthRankingConfigurationFileSource (root ++ "\0private") 1
    assertAdmissionFailure LengthRankingConfigurationFilePathNotAbsolute
      $ LengthRankingConfigurationFileSource "relative.json" 1
    assertAdmissionFailure LengthRankingConfigurationFileTimeoutNotPositive
      $ LengthRankingConfigurationFileSource root 0
    assertAdmissionFailure
      (LengthRankingConfigurationFileTimeoutLimitExceeded 60000 60001)
      $ LengthRankingConfigurationFileSource root 60001

assertLengthRankingConfigurationFileAcquisition :: IO ()
assertLengthRankingConfigurationFileAcquisition =
  withTemporaryDirectory "leant-length-acquisition-success" $ \root -> do
    let sourcePath = root </> "length-ranking.json"
        executable = root </> "missing-z3"
    ByteString.writeFile sourcePath $ encodeLengthRankingConfigurationFile
      $ lengthRankingConfigurationFileFixture executable Nothing
    request <- expectLengthRankingConfigurationFileRequest sourcePath 1000
    loaded <- loadLengthRankingConfigurationFile request
    if os == "mingw32"
      then expectLengthRankingConfigurationFileLoadFailure
        LengthRankingConfigurationFilePlatformUnsupported loaded
      else case loaded of
        Left failure -> assertFailure $ "regular configuration was rejected: "
          ++ show (lengthRankingConfigurationFileLoadErrorClass failure)
        Right disabled -> do
          _ <- expectLengthRankingConfigurationActivation
            PermitUnpinnedExecutable disabled
          pure ()

assertLengthRankingConfigurationFileSourceTypes :: IO ()
assertLengthRankingConfigurationFileSourceTypes =
  withTemporaryDirectory "leant-length-acquisition-types" $ \root -> do
    directoryRequest <- expectLengthRankingConfigurationFileRequest root 1000
    directoryResult <- loadLengthRankingConfigurationFile directoryRequest
    if os == "mingw32"
      then expectLengthRankingConfigurationFileLoadFailure
        LengthRankingConfigurationFilePlatformUnsupported directoryResult
      else expectLengthRankingConfigurationFileLoadFailure
        LengthRankingConfigurationFileNotRegular directoryResult

    let target = root </> "target.json"
        linked = root </> "linked.json"
    ByteString.writeFile target $ BS.pack "{}"
    if os == "mingw32"
      then pure ()
      else do
        createFileLink target linked
        linkedRequest <- expectLengthRankingConfigurationFileRequest linked 1000
        linkedResult <- loadLengthRankingConfigurationFile linkedRequest
        expectLengthRankingConfigurationFileLoadFailure
          LengthRankingConfigurationFileOpenFailed linkedResult

assertLengthRankingConfigurationFileAcquisitionByteLimit :: IO ()
assertLengthRankingConfigurationFileAcquisitionByteLimit =
  withTemporaryDirectory "leant-length-acquisition-bytes" $ \root -> do
    let exactPath = root </> "exact.json"
        excessivePath = root </> "excessive.json"
        maximumBytes = fromIntegral
          lengthRankingConfigurationFileLoadMaximumBytes
    ByteString.writeFile exactPath $ ByteString.replicate maximumBytes 32
    ByteString.writeFile excessivePath
      $ ByteString.replicate (maximumBytes + 1) 32
    exactRequest <- expectLengthRankingConfigurationFileRequest exactPath 1000
    excessiveRequest <- expectLengthRankingConfigurationFileRequest
      excessivePath 1000
    exactResult <- loadLengthRankingConfigurationFile exactRequest
    excessiveResult <- loadLengthRankingConfigurationFile excessiveRequest
    if os == "mingw32"
      then do
        expectLengthRankingConfigurationFileLoadFailure
          LengthRankingConfigurationFilePlatformUnsupported exactResult
        expectLengthRankingConfigurationFileLoadFailure
          LengthRankingConfigurationFilePlatformUnsupported excessiveResult
      else do
        case exactResult of
          Left failure -> case
              lengthRankingConfigurationFileLoadErrorClass failure of
            LengthRankingConfigurationFileDecodeRejected _ ->
              lengthRankingConfigurationFileLoadCleanupIncomplete failure @?=
                False
            other -> assertFailure $ "exact byte ceiling failed before decode: "
              ++ show other
          Right _ -> assertFailure "all-whitespace document unexpectedly decoded"
        expectLengthRankingConfigurationFileLoadFailure
          (LengthRankingConfigurationFileByteLimitExceeded 262144 262145)
          excessiveResult

assertLengthRankingConfigurationFileAcquisitionRedaction :: IO ()
assertLengthRankingConfigurationFileAcquisitionRedaction =
  withTemporaryDirectory "leant-length-acquisition-redaction" $ \root -> do
    let privateFragment = "private-acquisition-path-fragment"
        missing = root </> privateFragment
    request <- expectLengthRankingConfigurationFileRequest missing 1000
    loaded <- loadLengthRankingConfigurationFile request
    case loaded of
      Right _ -> assertFailure "missing configuration unexpectedly loaded"
      Left failure -> do
        lengthRankingConfigurationFileLoadErrorClass failure @?=
          if os == "mingw32"
            then LengthRankingConfigurationFilePlatformUnsupported
            else LengthRankingConfigurationFileOpenFailed
        lengthRankingConfigurationFileLoadCleanupIncomplete failure @?= False
        assertBool "load failure exposed the private source path"
          $ not $ privateFragment `isInfixOf` show failure

assertAdmissionFailure
  :: LengthRankingConfigurationFileAdmissionError
  -> LengthRankingConfigurationFileSource
  -> IO ()
assertAdmissionFailure expected source =
  case mkLengthRankingConfigurationFileRequest source of
    Left failure -> failure @?= expected
    Right _ -> assertFailure $ "expected request rejection: " ++ show expected

expectLengthRankingConfigurationFileRequest
  :: FilePath
  -> Int
  -> IO LengthRankingConfigurationFileRequest
expectLengthRankingConfigurationFileRequest path timeoutMilliseconds =
  case mkLengthRankingConfigurationFileRequest
      $ LengthRankingConfigurationFileSource path timeoutMilliseconds of
    Left failure -> assertFailure ("request admission failed: " ++ show failure)
      >> error "unreachable"
    Right request -> pure request

expectLengthRankingConfigurationFileLoadFailure
  :: LengthRankingConfigurationFileLoadErrorClass
  -> Either
      LengthRankingConfigurationFileLoadError
      DisabledLengthRankingConfiguration
  -> IO ()
expectLengthRankingConfigurationFileLoadFailure expected result = case result of
  Right _ -> assertFailure $ "expected acquisition failure: " ++ show expected
  Left failure -> do
    lengthRankingConfigurationFileLoadErrorClass failure @?= expected
    lengthRankingConfigurationFileLoadCleanupIncomplete failure @?= False

assertLengthRankingConfigurationFileActivation :: IO ()
assertLengthRankingConfigurationFileActivation =
  withTemporaryDirectory "leant-length-file-activation" $ \root -> do
    let executable = root </> "missing-z3"
        unpinnedDocument = lengthRankingConfigurationFileFixture
          executable Nothing
        pinnedDocument = lengthRankingConfigurationFileFixture executable
          $ Just $ replicate 64 '0'
    lengthRankingConfigurationFileFormat @?=
      Text.pack "leant-live-length-ranking-configuration"
    lengthRankingConfigurationFileVersion @?= 1
    lengthRankingConfigurationFileJsonLimits @?= BoundedJsonLimits
      { boundedJsonMaximumTotalBytes = 262144
      , boundedJsonMaximumNestingDepth = 133
      , boundedJsonMaximumNodes = 32768
      , boundedJsonMaximumObjectMembers = 32
      , boundedJsonMaximumArrayElements = 257
      , boundedJsonMaximumObjectKeyUtf8Bytes = 64
      , boundedJsonMaximumStringUtf8Bytes = 16384
      , boundedJsonMaximumStringUnicodeScalars = 4096
      , boundedJsonMaximumNumberBytes = 80
      }

    unpinned <- expectLengthRankingConfigurationFile unpinnedDocument
    case activateLengthRankingConfiguration
        RequirePinnedExecutable unpinned of
      Left failure -> failure @?=
        LengthRankingConfigurationExecutablePinRequired
      Right _ -> assertFailure
        "an unpinned configuration passed require-pinned activation"
    _ <- expectLengthRankingConfigurationActivation
      PermitUnpinnedExecutable unpinned

    pinned <- expectLengthRankingConfigurationFile pinnedDocument
    _ <- expectLengthRankingConfigurationActivation
      RequirePinnedExecutable pinned
    _ <- expectLengthRankingConfigurationActivation
      PermitUnpinnedExecutable pinned

    reordered <- expectLengthRankingConfigurationFile
      $ reverseJsonObjectFields pinnedDocument
    _ <- expectLengthRankingConfigurationActivation
      RequirePinnedExecutable reordered
    pure ()

assertLengthRankingConfigurationFileSchemaPrecedence :: IO ()
assertLengthRankingConfigurationFileSchemaPrecedence =
  withTemporaryDirectory "leant-length-file-schema" $ \root -> do
    let executable = root </> "missing-z3"
        base = lengthRankingConfigurationFileFixture executable Nothing
        badEnvelope = addJsonField [] ("private-root-field", Json.JNull)
          $ setJsonField ["version"] (Json.JInt 2)
          $ setJsonField ["format"] (Json.JStr "private-format") base
    assertLengthRankingConfigurationFileError
      LengthRankingConfigurationUnsupportedFormat badEnvelope
    assertLengthRankingConfigurationFileError
      LengthRankingConfigurationUnsupportedVersion
      $ setJsonField ["format"]
          (Json.JStr $ Text.unpack lengthRankingConfigurationFileFormat)
          badEnvelope
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationUnexpectedField
        LengthRankingConfigurationRootObject)
      $ deleteJsonField ["executionAdmission"]
      $ addJsonField [] ("private-root-field", Json.JNull) base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationMissingField
        LengthRankingConfigurationRootObject
        LengthRankingConfigurationExecutionField)
      $ deleteJsonField ["contract"]
      $ deleteJsonField ["execution"] base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        LengthRankingConfigurationVersionField
        LengthRankingConfigurationIntegerValue)
      $ setJsonField ["version"] (Json.JNum 1.0) base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        LengthRankingConfigurationExpectedExecutableSha256Field)
      $ setJsonField ["execution", "expectedExecutableSha256"]
          (Json.JStr $ replicate 64 'A') base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        LengthRankingConfigurationExpectedExecutableSha256Field)
      $ setJsonField ["execution", "expectedExecutableSha256"]
          (Json.JStr $ replicate 63 '0') base
    _ <- expectLengthRankingConfigurationFile
      $ setJsonField ["execution", "expectedExecutableSha256"]
          (Json.JStr $ replicate 64 '0') base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        LengthRankingConfigurationExpectedExecutableSha256Field)
      $ setJsonField ["execution", "expectedExecutableSha256"]
          (Json.JStr $ replicate 65 '0') base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        LengthRankingConfigurationExpectedExecutableSha256Field
        LengthRankingConfigurationNullOrStringValue)
      $ setJsonField ["execution", "expectedExecutableSha256"]
          (Json.JBool False) base
    _ <- expectLengthRankingConfigurationFile
      $ setJsonField ["execution", "artifactPolicy"]
          (Json.JStr "input-values-after-satisfiable") base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        LengthRankingConfigurationArtifactPolicyField)
      $ setJsonField ["execution", "artifactPolicy"]
          (Json.JStr "private-artifact-policy") base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        LengthRankingConfigurationArtifactPolicyField
        LengthRankingConfigurationStringValue)
      $ setJsonField ["execution", "artifactPolicy"]
          (Json.JBool False) base

assertLengthRankingConfigurationFileValidationPrecedence :: IO ()
assertLengthRankingConfigurationFileValidationPrecedence =
  withTemporaryDirectory "leant-length-file-precedence" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        badEvaluation = setJsonField
          ["evaluation", "assignmentValueBits"] (Json.JInt (-1))
        badContract = setJsonField ["contract", "precondition"]
          $ Json.JArr [Json.JStr "private-unknown-formula"]
        allBad = setJsonField ["execution", "executablePath"]
          (Json.JStr "djex-fake-z3") $ badEvaluation $ badContract base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationExecutionRejected
        Djex.LengthSMTLibExecutionExecutablePathNotAbsolute)
      allBad
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationEvaluationRejected
        $ Djex.NegativeLengthEvaluationLimit
            Djex.LengthAssignmentValueBits (-1))
      $ badEvaluation $ badContract base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationSyntaxRejected
        LengthRankingConfigurationPreconditionSyntax
        LengthRankingConfigurationUnknownTag)
      $ badContract base

assertLengthRankingConfigurationFileNoOpen :: IO ()
assertLengthRankingConfigurationFileNoOpen =
  withFakeLengthSolver "healthy" $ \executable -> do
    let sidecar = executable ++ ".events"
    doesFileExist sidecar >>= (@?= False)
    disabled <- expectLengthRankingConfigurationFile
      $ lengthRankingConfigurationFileFixture executable Nothing
    doesFileExist sidecar >>= (@?= False)
    _ <- expectLengthRankingConfigurationActivation
      PermitUnpinnedExecutable disabled
    doesFileExist sidecar >>= (@?= False)

assertLengthRankingConfigurationFileObjectSchema :: IO ()
assertLengthRankingConfigurationFileObjectSchema =
  withTemporaryDirectory "leant-length-file-objects" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        law = jsonLengthProviderLaw "Demo.provider" []
          $ jsonLengthLiteral 0
        withLaw = setJsonField ["contract", "providerLaws"]
          (Json.JArr [law]) base
        unexpected object path source =
          ( LengthRankingConfigurationUnexpectedField object
          , addJsonField path ("private-unexpected", Json.JNull) source
          )
        missing object field path source =
          ( LengthRankingConfigurationMissingField object field
          , deleteJsonField path source
          )
        unexpectedLaw = setJsonField ["contract", "providerLaws"]
          (Json.JArr [prependJsonObjectField
            ("private-unexpected", Json.JNull) law]) base
        missingLaw = setJsonField ["contract", "providerLaws"]
          (Json.JArr [deleteJsonObjectField "name" law]) base
        cases =
          [ unexpected LengthRankingConfigurationRootObject [] base
          , unexpected LengthRankingConfigurationExecutionAdmissionObject
              ["executionAdmission"] base
          , unexpected LengthRankingConfigurationExecutionObject
              ["execution"] base
          , unexpected LengthRankingConfigurationResponseLimitsObject
              ["execution", "responseLimits"] base
          , unexpected LengthRankingConfigurationEvaluationObject
              ["evaluation"] base
          , unexpected LengthRankingConfigurationContractObject
              ["contract"] base
          , unexpected LengthRankingConfigurationSpineObject
              ["contract", "spine"] base
          , ( LengthRankingConfigurationUnexpectedField
                $ LengthRankingConfigurationProviderLawObject 0
            , unexpectedLaw
            )
          , missing LengthRankingConfigurationRootObject
              LengthRankingConfigurationExecutionAdmissionField
              ["executionAdmission"] base
          , missing LengthRankingConfigurationExecutionAdmissionObject
              LengthRankingConfigurationExecutablePathCharactersField
              ["executionAdmission", "executablePathCharacters"] base
          , missing LengthRankingConfigurationExecutionObject
              LengthRankingConfigurationExecutablePathField
              ["execution", "executablePath"] base
          , missing LengthRankingConfigurationResponseLimitsObject
              LengthRankingConfigurationResponseBytesField
              ["execution", "responseLimits", "bytes"] base
          , missing LengthRankingConfigurationEvaluationObject
              LengthRankingConfigurationAssignmentValueBitsField
              ["evaluation", "assignmentValueBits"] base
          , missing LengthRankingConfigurationContractObject
              LengthRankingConfigurationSpineField
              ["contract", "spine"] base
          , missing LengthRankingConfigurationSpineObject
              LengthRankingConfigurationSpineFamilyField
              ["contract", "spine", "family"] base
          , ( LengthRankingConfigurationMissingField
                (LengthRankingConfigurationProviderLawObject 0)
                (LengthRankingConfigurationProviderLawNameField 0)
            , missingLaw
            )
          ]
    mapM_ (uncurry assertLengthRankingConfigurationFileError) cases
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationExpectedObject
        LengthRankingConfigurationRootObject)
      Json.JNull
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationExpectedObject
        LengthRankingConfigurationExecutionAdmissionObject)
      $ setJsonField ["executionAdmission"] Json.JNull base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        LengthRankingConfigurationExecutablePathField
        LengthRankingConfigurationStringValue)
      $ setJsonField ["execution", "executablePath"] (Json.JInt 0) base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        LengthRankingConfigurationProviderLawsField
        LengthRankingConfigurationArrayValue)
      $ setJsonField ["contract", "providerLaws"] (Json.JBool False) base
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldTypeMismatch
        (LengthRankingConfigurationProviderLawArgumentRolesField 0)
        LengthRankingConfigurationArrayValue)
      $ setJsonField ["contract", "providerLaws"]
          (Json.JArr [setJsonField ["argumentRoles"]
            (Json.JBool False) law]) withLaw

assertLengthRankingConfigurationFileOperationalCaps :: IO ()
assertLengthRankingConfigurationFileOperationalCaps =
  withTemporaryDirectory "leant-length-file-caps" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        setInteger path value = setJsonField path $ Json.JInt value
        direct path value = setInteger path value base
        timeoutAt value = setInteger
          ["execution", "solverTimeoutMilliseconds"] value
          $ setInteger ["execution", "hostDeadlineMilliseconds"] 65000 base
        cases =
          [ ( LengthRankingConfigurationExecutablePathCharactersField
            , 4096
            , direct ["executionAdmission", "executablePathCharacters"]
            )
          , ( LengthRankingConfigurationPolicyFingerprintBytesField
            , 262144
            , direct ["executionAdmission", "policyFingerprintBytes"]
            )
          , ( LengthRankingConfigurationSolverTimeoutMillisecondsField
            , 60000
            , timeoutAt
            )
          , ( LengthRankingConfigurationSolverResourceLimitField
            , 10000000
            , direct ["execution", "solverResourceLimit"]
            )
          , ( LengthRankingConfigurationHostDeadlineMillisecondsField
            , 65000
            , direct ["execution", "hostDeadlineMilliseconds"]
            )
          , ( LengthRankingConfigurationResponseBytesField
            , 65536
            , direct ["execution", "responseLimits", "bytes"]
            )
          , ( LengthRankingConfigurationResponseNestingDepthField
            , 64
            , direct ["execution", "responseLimits", "nestingDepth"]
            )
          , ( LengthRankingConfigurationResponseNodesField
            , 4096
            , direct ["execution", "responseLimits", "nodes"]
            )
          , ( LengthRankingConfigurationResponseTokenBytesField
            , 4096
            , direct ["execution", "responseLimits", "tokenBytes"]
            )
          , ( LengthRankingConfigurationResponseIntegerBitsField
            , 4096
            , direct ["execution", "responseLimits", "integerBits"]
            )
          , ( LengthRankingConfigurationAssignmentValueBitsField
            , 4096
            , direct ["evaluation", "assignmentValueBits"]
            )
          , ( LengthRankingConfigurationIntermediateValueBitsField
            , 4096
            , direct ["evaluation", "intermediateValueBits"]
            )
          ]
    mapM_ assertCap cases
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        LengthRankingConfigurationExecutablePathCharactersField)
      $ direct ["executionAdmission", "executablePathCharacters"] (-1)
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationResponseLimitsRejected
        $ Djex.NegativeLengthSMTLibResponseLimit
            Djex.LengthSMTLibResponseNestingDepth (-1))
      $ direct ["execution", "responseLimits", "nestingDepth"] (-1)
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationExecutionRejected
        $ Djex.ZeroLengthSMTLibExecutionConfigField
            Djex.LengthSMTLibExecutionSolverTimeoutMilliseconds)
      $ direct ["execution", "solverTimeoutMilliseconds"] 0
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationEvaluationRejected
        $ Djex.NegativeLengthEvaluationLimit
            Djex.LengthAssignmentValueBits (-1))
      $ direct ["evaluation", "assignmentValueBits"] (-1)
 where
  assertCap (field, maximumValue, documentAt) = do
    _ <- expectLengthRankingConfigurationFile $ documentAt maximumValue
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationPolicyLimitExceeded field
        (fromInteger maximumValue) (fromInteger maximumValue + 1))
      $ documentAt $ maximumValue + 1

prependJsonObjectField
  :: (String, Json.JValue)
  -> Json.JValue
  -> Json.JValue
prependJsonObjectField field (Json.JObj fields) = Json.JObj $ field : fields
prependJsonObjectField _ value = value

deleteJsonObjectField :: String -> Json.JValue -> Json.JValue
deleteJsonObjectField field (Json.JObj fields) = Json.JObj
  [(name, value) | (name, value) <- fields, name /= field]
deleteJsonObjectField _ value = value

assertLengthRankingConfigurationFileSyntaxShapes :: IO ()
assertLengthRankingConfigurationFileSyntaxShapes =
  withTemporaryDirectory "leant-length-file-shapes" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        fullExpression = jsonLengthIf
          (jsonLengthNot $ jsonLengthTruth False)
          (jsonLengthMonus
            (jsonLengthMaximum
              (jsonLengthSum
                [ jsonLengthInput 0
                , jsonLengthScale 2 $ jsonLengthLiteral 3
                ])
              (jsonLengthLiteral 4))
            (jsonLengthMinimum (jsonLengthLiteral 5)
              $ jsonLengthLiteral 6))
          (jsonLengthLiteral 7)
        fullContract = jsonLengthContract
          (jsonLengthAll
            [ jsonLengthTruth True
            , jsonLengthEqual fullExpression $ jsonLengthLiteral 0
            , jsonLengthAtMost (jsonLengthLiteral 0) fullExpression
            ])
          (jsonLengthEqual jsonLengthResult $ jsonLengthLiteral 0)
          [ jsonLengthProviderLaw "Demo.provider"
              ["spine", "unobserved"]
              (jsonLengthSum
                [jsonLengthArgument 0, jsonLengthLiteral 1])
          ]
        withFullContract = setJsonField ["contract"] fullContract base
        malformed value expected =
          ( LengthRankingConfigurationSyntaxRejected
              LengthRankingConfigurationPreconditionSyntax expected
          , setJsonField ["contract", "precondition"] value base
          )
        malformedExpression value expected = malformed
          (jsonLengthEqual value $ jsonLengthLiteral 0) expected
        cases =
          [ malformed (Json.JBool True)
              LengthRankingConfigurationExpectedTaggedArray
          , malformed (Json.JArr []) LengthRankingConfigurationExpectedTag
          , malformed (Json.JArr [Json.JStr "private-tag"])
              LengthRankingConfigurationUnknownTag
          , malformedExpression
              (Json.JArr [Json.JStr "result", Json.JInt 0])
              (LengthRankingConfigurationTagArityMismatch 0 1)
          , malformed (Json.JArr [Json.JStr "truth"])
              (LengthRankingConfigurationTagArityMismatch 1 0)
          , malformed
              (Json.JArr [Json.JStr "equal", jsonLengthLiteral 0])
              (LengthRankingConfigurationTagArityMismatch 2 1)
          , malformedExpression
              (Json.JArr
                [ Json.JStr "if"
                , jsonLengthTruth True
                , jsonLengthLiteral 0
                ])
              (LengthRankingConfigurationTagArityMismatch 3 2)
          , malformedExpression
              (Json.JArr [Json.JStr "sum", Json.JBool False])
              LengthRankingConfigurationExpectedSyntaxArray
          , malformed
              (Json.JArr [Json.JStr "truth", Json.JInt 1])
              LengthRankingConfigurationExpectedSyntaxBoolean
          , malformedExpression (jsonLengthLiteral (-1))
              LengthRankingConfigurationExpectedSyntaxNatural
          ]
    _ <- expectLengthRankingConfigurationFile withFullContract
    mapM_ (uncurry assertLengthRankingConfigurationFileError) cases

assertLengthRankingConfigurationFileSyntaxBounds :: IO ()
assertLengthRankingConfigurationFileSyntaxBounds =
  withTemporaryDirectory "leant-length-file-syntax-bounds" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        withContract precondition postcondition laws =
          setJsonField ["contract"]
            (jsonLengthContract precondition postcondition laws) base
        preconditionLimit limit maximumValue =
          LengthRankingConfigurationSyntaxRejected
            LengthRankingConfigurationPreconditionSyntax
            $ LengthRankingConfigurationSyntaxLimitExceeded
                limit maximumValue (maximumValue + 1)
        providerLimit index limit maximumValue observed =
          LengthRankingConfigurationSyntaxRejected
            (LengthRankingConfigurationProviderTransferSyntax index)
            $ LengthRankingConfigurationSyntaxLimitExceeded
                limit maximumValue observed

    _ <- expectLengthRankingConfigurationFile $ withContract
      (nestedLengthNot 63 $ jsonLengthTruth True)
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (preconditionLimit LengthRankingConfigurationSemanticDepth 64)
      $ withContract (nestedLengthNot 64 $ jsonLengthTruth True)
          (jsonLengthTruth True) []

    let exactDepthLaw = jsonLengthProviderLaw "Demo.depth" []
          $ nestedProviderTransfer 64
        excessiveDepthLaw = jsonLengthProviderLaw "Demo.depth" []
          $ nestedProviderTransfer 65
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True) [exactDepthLaw]
    assertLengthRankingConfigurationFileError
      (providerLimit 0 LengthRankingConfigurationSemanticDepth 64 65)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          [excessiveDepthLaw]

    _ <- expectLengthRankingConfigurationFile $ withContract
      (largeLengthFormula 12) (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationSyntaxRejected
        LengthRankingConfigurationPostconditionSyntax
        $ LengthRankingConfigurationSyntaxLimitExceeded
            LengthRankingConfigurationSyntaxNodes 1024 1025)
      $ withContract (largeLengthFormula 13) (jsonLengthTruth True) []

    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthAll $ replicate 31 $ jsonLengthTruth True)
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationSyntaxRejected
        LengthRankingConfigurationPostconditionSyntax
        $ LengthRankingConfigurationSyntaxLimitExceeded
            LengthRankingConfigurationFormulaClauses 32 33)
      $ withContract
          (jsonLengthAll $ replicate 32 $ jsonLengthTruth True)
          (jsonLengthTruth True) []

    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthEqual
        (jsonLengthSum $ replicate 64 $ jsonLengthLiteral 0)
        $ jsonLengthLiteral 0)
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (preconditionLimit LengthRankingConfigurationSumTerms 64)
      $ withContract
          (jsonLengthEqual
            (jsonLengthSum $ replicate 65 $ jsonLengthLiteral 0)
            $ jsonLengthLiteral 0)
          (jsonLengthTruth True) []

    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthAll $ replicate 64 $ jsonLengthAll [])
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (preconditionLimit LengthRankingConfigurationAllClauses 64)
      $ withContract (jsonLengthAll $ replicate 65 $ jsonLengthAll [])
          (jsonLengthTruth True) []

    let maximumLiteral = 2 ^ (256 :: Int) - 1
        excessiveLiteral = maximumLiteral + 1
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthEqual (jsonLengthLiteral maximumLiteral)
        $ jsonLengthLiteral 0)
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (preconditionLimit LengthRankingConfigurationLiteralBits 256)
      $ withContract
          (jsonLengthEqual (jsonLengthLiteral excessiveLiteral)
            $ jsonLengthLiteral 0)
          (jsonLengthTruth True) []

    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthEqual (jsonLengthInput 7) $ jsonLengthLiteral 0)
      (jsonLengthTruth True) []
    assertLengthRankingConfigurationFileError
      (preconditionLimit LengthRankingConfigurationInputIndex 7)
      $ withContract
          (jsonLengthEqual (jsonLengthInput 8) $ jsonLengthLiteral 0)
          (jsonLengthTruth True) []

    let roles16 = replicate 16 "spine"
        exactArgumentLaw = jsonLengthProviderLaw
          "Demo.arguments" roles16 $ jsonLengthArgument 15
        excessiveArgumentLaw = jsonLengthProviderLaw
          "Demo.arguments" roles16 $ jsonLengthArgument 16
        missingRoleLaw = jsonLengthProviderLaw
          "Demo.arguments" ["spine"] $ jsonLengthArgument 1
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True) [exactArgumentLaw]
    assertLengthRankingConfigurationFileError
      (providerLimit 0 LengthRankingConfigurationProviderArgumentIndex
        15 16)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          [excessiveArgumentLaw]
    assertLengthRankingConfigurationFileError
      (providerLimit 0 LengthRankingConfigurationProviderArgumentRoleCount
        1 2)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          [missingRoleLaw]

    let lawWithRoles roles = jsonLengthProviderLaw
          "Demo.roles" roles $ jsonLengthLiteral 0
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True)
      [lawWithRoles roles16]
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationPolicyLimitExceeded
        (LengthRankingConfigurationProviderLawArgumentRolesField 0) 16 17)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          [lawWithRoles $ replicate 17 "spine"]
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationFieldValueRejected
        $ LengthRankingConfigurationProviderLawArgumentRolesField 0)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          [lawWithRoles ["private-role"]]

    let laws count =
          [ jsonLengthProviderLaw ("Demo.provider" ++ show index) []
              $ jsonLengthLiteral 0
          | index <- take count [0 :: Int ..]
          ]
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True) $ laws 256
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationPolicyLimitExceeded
        LengthRankingConfigurationProviderLawsField 256 257)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True) $ laws 257

    let setFamily name = setJsonField
          ["contract", "spine", "family"] (Json.JStr name) base
    _ <- expectLengthRankingConfigurationFile $ setFamily
      $ replicate 256 '\x1f600'
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationTextLimitExceeded
        LengthRankingConfigurationSpineFamilyField
        LengthRankingConfigurationUnicodeScalars 256 257)
      $ setFamily $ replicate 257 'a'
    assertLengthRankingConfigurationFileError
      (LengthRankingConfigurationTextLimitExceeded
        LengthRankingConfigurationSpineFamilyField
        LengthRankingConfigurationUtf8Bytes 1024 1025)
      $ setFamily $ replicate 257 '\x1f600'

    let exactNodeLaws =
          [ jsonLengthProviderLaw "Demo.large" []
              $ largeLengthExpression 14
          , jsonLengthProviderLaw "Demo.last" [] $ jsonLengthLiteral 0
          ]
        excessiveNodeLaws = exactNodeLaws ++
          [jsonLengthProviderLaw "Demo.excessive" [] $ jsonLengthLiteral 0]
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True) exactNodeLaws
    assertLengthRankingConfigurationFileError
      (providerLimit 2 LengthRankingConfigurationSyntaxNodes 1024 1025)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          excessiveNodeLaws

    let clauseLaw :: Int -> Json.JValue
        clauseLaw index = jsonLengthProviderLaw
          ("Demo.clause" ++ show index) []
          $ jsonLengthIf (jsonLengthTruth True)
              (jsonLengthLiteral 0) (jsonLengthLiteral 0)
        exactClauseLaws = map clauseLaw $ take 32 [0 :: Int ..]
        excessiveClauseLaws = exactClauseLaws ++ [clauseLaw 32]
    _ <- expectLengthRankingConfigurationFile $ withContract
      (jsonLengthTruth True) (jsonLengthTruth True) exactClauseLaws
    assertLengthRankingConfigurationFileError
      (providerLimit 32 LengthRankingConfigurationFormulaClauses 32 33)
      $ withContract (jsonLengthTruth True) (jsonLengthTruth True)
          excessiveClauseLaws

nestedLengthNot :: Int -> Json.JValue -> Json.JValue
nestedLengthNot count value
  | count <= 0 = value
  | otherwise = jsonLengthNot $ nestedLengthNot (count - 1) value

nestedProviderTransfer :: Int -> Json.JValue
nestedProviderTransfer depth
  | depth <= 1 = jsonLengthLiteral 0
  | even depth = jsonLengthSum [nestedProviderTransfer $ depth - 1]
  | otherwise = jsonLengthIf (jsonLengthAll [])
      (nestedProviderTransfer $ depth - 1) (jsonLengthLiteral 0)

largeLengthFormula :: Int -> Json.JValue
largeLengthFormula finalTermNodes = jsonLengthEqual
  (largeLengthExpression finalTermNodes)
  $ jsonLengthLiteral 0

largeLengthExpression :: Int -> Json.JValue
largeLengthExpression finalTermNodes = jsonLengthSum
  $ replicate 63 (scaleChain 16)
    ++ [scaleChain finalTermNodes]
 where
  scaleChain :: Int -> Json.JValue
  scaleChain nodes
    | nodes <= 1 = jsonLengthLiteral 0
    | otherwise = jsonLengthScale 1 $ scaleChain $ nodes - 1

assertLengthRankingConfigurationFileLiveEquivalence :: IO ()
assertLengthRankingConfigurationFileLiveEquivalence = do
  fixture <- buildLengthRankingLiveFixture
  neutral <- syntheticLengthRankingCandidate "file-configured-neutral"
  withFakeLengthSolver "healthy" $ \executable -> do
    let zero = lengthRankingFixtureZero fixture
        one = lengthRankingFixtureOne fixture
        candidates = [zero, neutral, one]
        contract = lengthRankingContract 0
        contractValue = jsonLengthContract
          (jsonLengthTruth True)
          (jsonLengthEqual jsonLengthResult $ jsonLengthLiteral 0)
          [ jsonLengthProviderLaw "Demo.zeroList" []
              $ jsonLengthLiteral 0
          , jsonLengthProviderLaw "Demo.oneList" []
              $ jsonLengthLiteral 1
          ]
        document = setJsonField ["contract"] contractValue
          $ lengthRankingConfigurationFileFixture executable Nothing
        executionSource = explicitLengthRankingExecutionSource
          executable Nothing Djex.LengthSMTLibStatusOnly
    disabled <- expectLengthRankingConfigurationFile document
    configuration <- expectLengthRankingConfigurationActivation
      PermitUnpinnedExecutable disabled
    execution <- expectRight $ Djex.mkLengthSMTLibExecutionConfig
      Djex.defaultLengthSMTLibExecutionLimits executionSource
    evaluation <- expectRight $ Djex.mkLengthEvaluationLimits
      Djex.defaultLengthEvaluationLimitSource
    direct <- expectLengthRankingWithin "direct file configuration"
      $ rankVerifiedLengthCandidates execution evaluation contract candidates
    configured <- expectLengthRankingWithin "decoded file configuration"
      $ rankVerifiedLengthCandidatesConfigured configuration candidates
    assertLengthRankingsEquivalent direct configured
    map rankedLengthCandidateAssessment
        (lengthRankingCandidates configured) @?=
      [ Heuristic Djex.SolverSatisfiable
      , Unassessed
      , Heuristic Djex.SolverSatisfiable
      ]
    verification <- verificationBatchFromReceipts candidates
    postVerification <- expectLengthPostVerificationWithin
      "decoded and activated file configuration"
      $ assessVerifiedLengthCandidatesConfigured configuration verification
    assertLengthPostVerificationSealed postVerification
    postVerificationRanking <- expectLengthPostVerificationRanking
      postVerification
    assertLengthRankingsEquivalent configured postVerificationRanking

assertLengthRankingConfigurationFileShowRedaction :: IO ()
assertLengthRankingConfigurationFileShowRedaction =
  withTemporaryDirectory "leant-length-file-redaction" $ \root -> do
    let base = lengthRankingConfigurationFileFixture
          (root </> "missing-z3") Nothing
        privatePath = "private-relative-executable-path"
        privateDigest = take 64 $ cycle "abcdefPRIVATE"
        privateField = "private-unexpected-field"
        privateTag = "private-unknown-tag"
        privateNameFragment = "private-name-fragment"
        privateName = concat $ replicate 30 privateNameFragment
        failures =
          [ ( privatePath
            , setJsonField ["execution", "executablePath"]
                (Json.JStr privatePath) base
            )
          , ( privateDigest
            , setJsonField ["execution", "expectedExecutableSha256"]
                (Json.JStr privateDigest) base
            )
          , ( privateField
            , addJsonField [] (privateField, Json.JNull) base
            )
          , ( privateTag
            , setJsonField ["contract", "precondition"]
                (Json.JArr [Json.JStr privateTag]) base
            )
          , ( privateNameFragment
            , setJsonField ["contract", "spine", "family"]
                (Json.JStr privateName) base
            )
          ]
    mapM_ assertRedacted failures
 where
  assertRedacted (privateText, document) = case
      decodeLengthRankingConfigurationFile
        $ encodeLengthRankingConfigurationFile document of
    Right _ -> assertFailure "redaction fixture unexpectedly decoded"
    Left failure -> assertBool
      ("configuration failure exposed private text: " ++ show failure)
      $ not $ privateText `isInfixOf` show failure

lengthRankingConfigurationFileFixture
  :: FilePath
  -> Maybe String
  -> Json.JValue
lengthRankingConfigurationFileFixture executable digest = Json.JObj
  [ ( "format"
    , Json.JStr $ Text.unpack lengthRankingConfigurationFileFormat
    )
  , ("version", Json.JInt $ toInteger lengthRankingConfigurationFileVersion)
  , ("executionAdmission", Json.JObj
      [ ("executablePathCharacters", Json.JInt 4096)
      , ("policyFingerprintBytes", Json.JInt 262144)
      ])
  , ("execution", Json.JObj
      [ ("executablePath", Json.JStr executable)
      , ( "expectedExecutableSha256"
        , maybe Json.JNull Json.JStr digest
        )
      , ("solverTimeoutMilliseconds", Json.JInt 100)
      , ("solverResourceLimit", Json.JInt 4242)
      , ("hostDeadlineMilliseconds", Json.JInt 1000)
      , ("artifactPolicy", Json.JStr "status-only")
      , ("responseLimits", Json.JObj
          [ ("bytes", Json.JInt 65536)
          , ("nestingDepth", Json.JInt 64)
          , ("nodes", Json.JInt 4096)
          , ("tokenBytes", Json.JInt 4096)
          , ("integerBits", Json.JInt 4096)
          ])
      ])
  , ("evaluation", Json.JObj
      [ ("assignmentValueBits", Json.JInt 4096)
      , ("intermediateValueBits", Json.JInt 4096)
      ])
  , ("contract", Json.JObj
      [ ("spine", Json.JObj
          [ ("family", Json.JStr "List")
          , ("zero", Json.JStr "List.nil")
          , ("step", Json.JStr "List.cons")
          ])
      , ("precondition", jsonLengthTruth True)
      , ("postcondition", jsonLengthTruth True)
      , ("providerLaws", Json.JArr [])
      ])
  ]

jsonLengthTruth :: Bool -> Json.JValue
jsonLengthTruth value = Json.JArr
  [Json.JStr "truth", Json.JBool value]

jsonLengthLiteral :: Integer -> Json.JValue
jsonLengthLiteral value = Json.JArr
  [Json.JStr "literal", Json.JInt value]

jsonLengthInput :: Integer -> Json.JValue
jsonLengthInput index = Json.JArr [Json.JStr "input", Json.JInt index]

jsonLengthResult :: Json.JValue
jsonLengthResult = Json.JArr [Json.JStr "result"]

jsonLengthArgument :: Integer -> Json.JValue
jsonLengthArgument index = Json.JArr
  [Json.JStr "argument", Json.JInt index]

jsonLengthSum :: [Json.JValue] -> Json.JValue
jsonLengthSum terms = Json.JArr
  [Json.JStr "sum", Json.JArr terms]

jsonLengthScale :: Integer -> Json.JValue -> Json.JValue
jsonLengthScale factor expression = Json.JArr
  [Json.JStr "scale", Json.JInt factor, expression]

jsonLengthMonus :: Json.JValue -> Json.JValue -> Json.JValue
jsonLengthMonus left right = Json.JArr
  [Json.JStr "monus", left, right]

jsonLengthMinimum :: Json.JValue -> Json.JValue -> Json.JValue
jsonLengthMinimum left right = Json.JArr
  [Json.JStr "minimum", left, right]

jsonLengthMaximum :: Json.JValue -> Json.JValue -> Json.JValue
jsonLengthMaximum left right = Json.JArr
  [Json.JStr "maximum", left, right]

jsonLengthIf
  :: Json.JValue
  -> Json.JValue
  -> Json.JValue
  -> Json.JValue
jsonLengthIf condition trueBranch falseBranch = Json.JArr
  [Json.JStr "if", condition, trueBranch, falseBranch]

jsonLengthEqual :: Json.JValue -> Json.JValue -> Json.JValue
jsonLengthEqual left right = Json.JArr
  [Json.JStr "equal", left, right]

jsonLengthAtMost :: Json.JValue -> Json.JValue -> Json.JValue
jsonLengthAtMost left right = Json.JArr
  [Json.JStr "at-most", left, right]

jsonLengthNot :: Json.JValue -> Json.JValue
jsonLengthNot formula = Json.JArr [Json.JStr "not", formula]

jsonLengthAll :: [Json.JValue] -> Json.JValue
jsonLengthAll formulas = Json.JArr
  [Json.JStr "all", Json.JArr formulas]

jsonLengthProviderLaw
  :: String
  -> [String]
  -> Json.JValue
  -> Json.JValue
jsonLengthProviderLaw name roles transfer = Json.JObj
  [ ("name", Json.JStr name)
  , ("argumentRoles", Json.JArr $ map Json.JStr roles)
  , ("transfer", transfer)
  ]

jsonLengthContract
  :: Json.JValue
  -> Json.JValue
  -> [Json.JValue]
  -> Json.JValue
jsonLengthContract precondition postcondition laws = Json.JObj
  [ ("spine", Json.JObj
      [ ("family", Json.JStr "List")
      , ("zero", Json.JStr "List.nil")
      , ("step", Json.JStr "List.cons")
      ])
  , ("precondition", precondition)
  , ("postcondition", postcondition)
  , ("providerLaws", Json.JArr laws)
  ]

encodeLengthRankingConfigurationFile
  :: Json.JValue
  -> ByteString.ByteString
encodeLengthRankingConfigurationFile = TextEncoding.encodeUtf8
  . Text.pack
  . Json.encodeJson

expectLengthRankingConfigurationFile
  :: Json.JValue
  -> IO DisabledLengthRankingConfiguration
expectLengthRankingConfigurationFile document =
  case decodeLengthRankingConfigurationFile
      $ encodeLengthRankingConfigurationFile document of
    Left failure -> assertFailure ("configuration file was rejected: " ++
      show failure) >> error "unreachable"
    Right disabled -> pure disabled

expectLengthRankingConfigurationActivation
  :: LengthRankingConfigurationActivationPolicy
  -> DisabledLengthRankingConfiguration
  -> IO LengthRankingConfiguration
expectLengthRankingConfigurationActivation policy disabled =
  case activateLengthRankingConfiguration policy disabled of
    Left failure -> assertFailure ("configuration activation failed: " ++
      show failure) >> error "unreachable"
    Right configuration -> pure configuration

assertLengthRankingConfigurationFileError
  :: LengthRankingConfigurationFileError
  -> Json.JValue
  -> IO ()
assertLengthRankingConfigurationFileError expected document =
  case decodeLengthRankingConfigurationFile
      $ encodeLengthRankingConfigurationFile document of
    Left failure -> failure @?= expected
    Right _ -> assertFailure $ "expected configuration-file failure: " ++
      show expected

setJsonField :: [String] -> Json.JValue -> Json.JValue -> Json.JValue
setJsonField [] _ source = source
setJsonField [field] replacement (Json.JObj fields) = Json.JObj
  [ if name == field then (name, replacement) else (name, value)
  | (name, value) <- fields
  ]
setJsonField (field : remaining) replacement (Json.JObj fields) = Json.JObj
  [ if name == field
      then (name, setJsonField remaining replacement value)
      else (name, value)
  | (name, value) <- fields
  ]
setJsonField _ _ source = source

deleteJsonField :: [String] -> Json.JValue -> Json.JValue
deleteJsonField [] source = source
deleteJsonField [field] (Json.JObj fields) = Json.JObj
  [(name, value) | (name, value) <- fields, name /= field]
deleteJsonField (field : remaining) (Json.JObj fields) = Json.JObj
  [ if name == field
      then (name, deleteJsonField remaining value)
      else (name, value)
  | (name, value) <- fields
  ]
deleteJsonField _ source = source

addJsonField
  :: [String]
  -> (String, Json.JValue)
  -> Json.JValue
  -> Json.JValue
addJsonField [] added (Json.JObj fields) = Json.JObj $ added : fields
addJsonField (field : remaining) added (Json.JObj fields) = Json.JObj
  [ if name == field
      then (name, addJsonField remaining added value)
      else (name, value)
  | (name, value) <- fields
  ]
addJsonField _ _ source = source

reverseJsonObjectFields :: Json.JValue -> Json.JValue
reverseJsonObjectFields value = case value of
  Json.JArr values -> Json.JArr $ map reverseJsonObjectFields values
  Json.JObj fields -> Json.JObj $ reverse
    [ (name, reverseJsonObjectFields child)
    | (name, child) <- fields
    ]
  _ -> value

assertLengthRankingConfigurationRelativePath :: IO ()
assertLengthRankingConfigurationRelativePath = do
  located <- findExecutable "djex-fake-z3"
  assertBool "the fake solver was not PATH-resolvable for the discovery test"
    $ case located of
        Nothing -> False
        Just _ -> True
  let policySource = explicitLengthRankingPolicySource
        Djex.defaultLengthSMTLibExecutionLimits
        (explicitLengthRankingExecutionSource
          "djex-fake-z3" Nothing Djex.LengthSMTLibStatusOnly)
        (error "execution rejection forced the later evaluation source")
      source = explicitLengthRankingConfigurationSource
        Djex.defaultLengthSMTLibExecutionLimits
        (explicitLengthRankingExecutionSource
          "djex-fake-z3" Nothing Djex.LengthSMTLibStatusOnly)
        (error "execution rejection forced the later evaluation source")
        (error "execution rejection forced the later Length contract")
  assertLengthRankingPolicyError
    (LengthRankingExecutionConfigurationRejected
      Djex.LengthSMTLibExecutionExecutablePathNotAbsolute)
    $ mkLengthRankingPolicy policySource
  assertLengthRankingConfigurationError
    (LengthRankingExecutionConfigurationRejected
      Djex.LengthSMTLibExecutionExecutablePathNotAbsolute)
    $ mkLengthRankingConfiguration source

assertLengthRankingConfigurationDigest :: IO ()
assertLengthRankingConfigurationDigest =
  withTemporaryDirectory "leant-length-config-digest" $ \root -> do
    let executable = root </> "explicit-missing-z3"
        source = explicitLengthRankingConfigurationSource
          Djex.defaultLengthSMTLibExecutionLimits
          (explicitLengthRankingExecutionSource executable (Just [0])
            Djex.LengthSMTLibStatusOnly)
          Djex.defaultLengthEvaluationLimitSource
          $ lengthRankingContract 0
    assertLengthRankingConfigurationError
      (LengthRankingExecutionConfigurationRejected
        $ Djex.LengthSMTLibExecutionExpectedExecutableSHA256LengthMismatch
            32 1)
      $ mkLengthRankingConfiguration source

assertLengthRankingConfigurationExecutionLimits :: IO ()
assertLengthRankingConfigurationExecutionLimits =
  withTemporaryDirectory "leant-length-config-execution-limit" $ \root -> do
    let executable = root </> "explicit-missing-z3"
        limits = Djex.mkLengthSMTLibExecutionLimits
          Djex.defaultLengthSMTLibExecutionLimitSource
            { Djex.lengthSMTLibExecutionLimitSourceExecutablePathCharacters = 3
            }
        source = explicitLengthRankingConfigurationSource limits
          (explicitLengthRankingExecutionSource executable Nothing
            Djex.LengthSMTLibStatusOnly)
          Djex.defaultLengthEvaluationLimitSource
          $ lengthRankingContract 0
    assertLengthRankingConfigurationError
      (LengthRankingExecutionConfigurationRejected
        $ Djex.LengthSMTLibExecutionExecutablePathCharacterLimitExceeded 3 4)
      $ mkLengthRankingConfiguration source

assertLengthRankingConfigurationEvaluationLimits :: IO ()
assertLengthRankingConfigurationEvaluationLimits =
  withTemporaryDirectory "leant-length-config-evaluation-limit" $ \root -> do
    let executable = root </> "explicit-missing-z3"
        evaluation = Djex.defaultLengthEvaluationLimitSource
          { Djex.lengthEvaluationLimitSourceAssignmentValueBits = -1
          , Djex.lengthEvaluationLimitSourceIntermediateValueBits = -2
          }
        policySource = explicitLengthRankingPolicySource
          Djex.defaultLengthSMTLibExecutionLimits
          (explicitLengthRankingExecutionSource executable Nothing
            Djex.LengthSMTLibStatusOnly)
          evaluation
        source = explicitLengthRankingConfigurationSource
          Djex.defaultLengthSMTLibExecutionLimits
          (explicitLengthRankingExecutionSource executable Nothing
            Djex.LengthSMTLibStatusOnly)
          evaluation
          $ error "evaluation rejection forced the later Length contract"
    assertLengthRankingPolicyError
      (LengthRankingEvaluationLimitsRejected
        $ Djex.NegativeLengthEvaluationLimit
            Djex.LengthAssignmentValueBits (-1))
      $ mkLengthRankingPolicy policySource
    assertLengthRankingConfigurationError
      (LengthRankingEvaluationLimitsRejected
        $ Djex.NegativeLengthEvaluationLimit
            Djex.LengthAssignmentValueBits (-1))
      $ mkLengthRankingConfiguration source

assertLengthRankingConfiguredAllIneligible :: IO ()
assertLengthRankingConfiguredAllIneligible =
  withTemporaryDirectory "leant-length-config-no-open" $ \root -> do
    first <- syntheticLengthRankingCandidate "configured-ineligible-first"
    second <- syntheticLengthRankingCandidate "configured-ineligible-second"
    let executable = root </> "explicit-missing-z3"
        candidates = [first, second]
        contract = ineligibleLengthRankingContract
        executionSource = explicitLengthRankingExecutionSource
          executable Nothing Djex.LengthSMTLibInputValuesAfterSatisfiable
        configurationSource = explicitLengthRankingConfigurationSource
          Djex.defaultLengthSMTLibExecutionLimits executionSource
          Djex.defaultLengthEvaluationLimitSource contract
    configuration <- expectRight
      $ mkLengthRankingConfiguration configurationSource
    execution <- expectRight $ Djex.mkLengthSMTLibExecutionConfig
      Djex.defaultLengthSMTLibExecutionLimits executionSource
    evaluation <- expectRight $ Djex.mkLengthEvaluationLimits
      Djex.defaultLengthEvaluationLimitSource
    direct <- expectLengthRankingWithin "direct all-ineligible configuration"
      $ rankVerifiedLengthCandidates execution evaluation contract candidates
    configured <- expectLengthRankingWithin
      "opaque all-ineligible configuration"
      $ rankVerifiedLengthCandidatesConfigured configuration candidates
    assertLengthRankingsEquivalent direct configured
    rankedLengthVerifiedCandidates configured @?= candidates
    map rankedLengthCandidateAssessment
        (lengthRankingCandidates configured) @?=
      [Unassessed, Unassessed]
    rankedLengthPreparationRefusals configured @?=
      replicate 2 (Just LengthPreparationTypedAuthorityUnavailable)
    lengthRankingFailure configured @?= Nothing

assertLengthRankingConfiguredLiveEquivalence :: IO ()
assertLengthRankingConfiguredLiveEquivalence = do
  fixture <- buildLengthRankingLiveFixture
  neutral <- syntheticLengthRankingCandidate "configured-neutral"
  trailing <- syntheticLengthRankingCandidate "configured-fallback"
  withFakeLengthSolver "healthy" $ \executable -> do
    let zero = lengthRankingFixtureZero fixture
        one = lengthRankingFixtureOne fixture
    healthy <- assertConfiguredLengthRankingEquivalent executable
      Djex.LengthSMTLibStatusOnly (lengthRankingContract 0)
      [zero, neutral, one]
    case map rankedLengthCandidateAssessment
        $ lengthRankingCandidates healthy of
      [Heuristic first, Unassessed, Heuristic second] ->
        (first, second) @?=
          (Djex.SolverSatisfiable, Djex.SolverSatisfiable)
      assessments -> assertFailure $
        "unexpected configured healthy assessments: " ++ show assessments
    rankedLengthPreparationRefusals healthy @?=
      [Nothing, Just LengthPreparationTypedAuthorityUnavailable, Nothing]

    failed <- assertConfiguredLengthRankingEquivalent executable
      Djex.LengthSMTLibInputValuesAfterSatisfiable
      (lengthRankingContract 0) [one, zero, trailing]
    rankedLengthVerifiedCandidates failed @?= [one, zero, trailing]
    map rankedLengthCandidateAssessment (lengthRankingCandidates failed) @?=
      replicate 3 Unassessed
    rankedLengthPreparationRefusals failed @?=
      [Nothing, Nothing, Just LengthPreparationTypedAuthorityUnavailable]
    failure <- case lengthRankingFailure failed of
      Nothing -> assertFailure "configured live failure was not retained"
      Just value -> pure value
    lengthRankingFailureClass failure @?=
      LengthRankingLiveQueryFailed
        Djex.LengthSMTLibLiveQueryCounterexampleRejected
    lengthRankingFailureCleanupIncomplete failure @?= False
    lengthRankingFailureOriginalIndex failure @?= Just 1

assertLengthRankingPolicyContractSeparation :: IO ()
assertLengthRankingPolicyContractSeparation = do
  fixture <- buildLengthRankingLiveFixture
  withFakeLengthSolver "healthy" $ \executable -> do
    let candidates =
          [ lengthRankingFixtureZero fixture
          , lengthRankingFixtureOne fixture
          ]
        policySource = explicitLengthRankingPolicySource
          Djex.defaultLengthSMTLibExecutionLimits
          (explicitLengthRankingExecutionSource executable Nothing
            Djex.LengthSMTLibStatusOnly)
          Djex.defaultLengthEvaluationLimitSource
    policy <- expectRight $ mkLengthRankingPolicy policySource
    first <- expectLengthRankingWithin "first request-owned contract"
      $ rankVerifiedLengthCandidatesWithPolicy policy
          (lengthRankingContract 0) candidates
    second <- expectLengthRankingWithin "second request-owned contract"
      $ rankVerifiedLengthCandidatesWithPolicy policy
          (lengthRankingContract 1) candidates
    mapM_ (\ranking -> do
        rankedLengthVerifiedCandidates ranking @?= candidates
        case map rankedLengthCandidateAssessment
            $ lengthRankingCandidates ranking of
          [Heuristic firstStatus, Heuristic secondStatus] ->
            (firstStatus, secondStatus) @?=
              (Djex.SolverSatisfiable, Djex.SolverSatisfiable)
          assessments -> assertFailure $ "unexpected policy assessments: "
            ++ show assessments
        rankedLengthPreparationRefusals ranking @?= [Nothing, Nothing]
        lengthRankingFailure ranking @?= Nothing)
      [first, second]

explicitLengthRankingPolicySource
  :: Djex.LengthSMTLibExecutionLimits
  -> Djex.LengthSMTLibExecutionConfigSource
  -> Djex.LengthEvaluationLimitSource
  -> LengthRankingPolicySource
explicitLengthRankingPolicySource executionLimits executionSource
    evaluationSource = LengthRankingPolicySource
  { lengthRankingPolicyExecutionLimits = executionLimits
  , lengthRankingPolicyExecutionSource = executionSource
  , lengthRankingPolicyEvaluationSource = evaluationSource
  }

explicitLengthRankingConfigurationSource
  :: Djex.LengthSMTLibExecutionLimits
  -> Djex.LengthSMTLibExecutionConfigSource
  -> Djex.LengthEvaluationLimitSource
  -> LeanLengthContract
  -> LengthRankingConfigurationSource
explicitLengthRankingConfigurationSource executionLimits executionSource
    evaluationSource contract = LengthRankingConfigurationSource
  { lengthRankingConfigurationExecutionLimits = executionLimits
  , lengthRankingConfigurationExecutionSource = executionSource
  , lengthRankingConfigurationEvaluationSource = evaluationSource
  , lengthRankingConfigurationContract = contract
  }

explicitLengthRankingExecutionSource
  :: FilePath
  -> Maybe [Word8]
  -> Djex.LengthSMTLibArtifactPolicy
  -> Djex.LengthSMTLibExecutionConfigSource
explicitLengthRankingExecutionSource executable digest policy =
  (Djex.defaultLengthSMTLibExecutionConfigSource executable digest)
    { Djex.lengthSMTLibExecutionConfigSourceSolverTimeoutMilliseconds = 100
    , Djex.lengthSMTLibExecutionConfigSourceSolverResourceLimit = 4242
    , Djex.lengthSMTLibExecutionConfigSourceHostDeadlineMilliseconds = 1000
    , Djex.lengthSMTLibExecutionConfigSourceArtifactPolicy = policy
    }

assertLengthRankingConfigurationError
  :: LengthRankingConfigurationError
  -> Either LengthRankingConfigurationError LengthRankingConfiguration
  -> IO ()
assertLengthRankingConfigurationError expected result = case result of
  Left failure -> failure @?= expected
  Right _ -> assertFailure $ "expected ranking configuration failure: " ++
    show expected

assertLengthRankingPolicyError
  :: LengthRankingConfigurationError
  -> Either LengthRankingConfigurationError LengthRankingPolicy
  -> IO ()
assertLengthRankingPolicyError expected result = case result of
  Left failure -> failure @?= expected
  Right _ -> assertFailure $ "expected ranking policy failure: "
    ++ show expected

assertConfiguredLengthRankingEquivalent
  :: FilePath
  -> Djex.LengthSMTLibArtifactPolicy
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO LengthRanking
assertConfiguredLengthRankingEquivalent executable policy contract candidates = do
  let executionSource = explicitLengthRankingExecutionSource
        executable Nothing policy
      configurationSource = explicitLengthRankingConfigurationSource
        Djex.defaultLengthSMTLibExecutionLimits executionSource
        Djex.defaultLengthEvaluationLimitSource contract
  configuration <- expectRight
    $ mkLengthRankingConfiguration configurationSource
  policyConfiguration <- expectRight $ mkLengthRankingPolicy
    $ explicitLengthRankingPolicySource
        Djex.defaultLengthSMTLibExecutionLimits executionSource
        Djex.defaultLengthEvaluationLimitSource
  execution <- expectRight $ Djex.mkLengthSMTLibExecutionConfig
    Djex.defaultLengthSMTLibExecutionLimits executionSource
  evaluation <- expectRight $ Djex.mkLengthEvaluationLimits
    Djex.defaultLengthEvaluationLimitSource
  direct <- expectLengthRankingWithin "direct live configuration"
    $ rankVerifiedLengthCandidates execution evaluation contract candidates
  configured <- expectLengthRankingWithin "opaque live configuration"
    $ rankVerifiedLengthCandidatesConfigured configuration candidates
  policyRanked <- expectLengthRankingWithin "separate policy and contract"
    $ rankVerifiedLengthCandidatesWithPolicy policyConfiguration contract
        candidates
  assertLengthRankingsEquivalent direct configured
  assertLengthRankingsEquivalent direct policyRanked
  pure configured

expectLengthRankingWithin
  :: String
  -> IO (Either LengthRankingInputError LengthRanking)
  -> IO LengthRanking
expectLengthRankingWithin label action = do
  bounded <- timeout 8000000 action
  case bounded of
    Nothing -> assertFailure $ label ++ " exceeded its outer bound"
    Just result -> expectRight result

assertLengthRankingsEquivalent :: LengthRanking -> LengthRanking -> IO ()
assertLengthRankingsEquivalent direct configured = do
  rankedLengthVerifiedCandidates configured @?=
    rankedLengthVerifiedCandidates direct
  map rankedLengthCandidateAssessment
      (lengthRankingCandidates configured) @?=
    map rankedLengthCandidateAssessment (lengthRankingCandidates direct)
  map rankedLengthCandidateOriginalIndex
      (lengthRankingCandidates configured) @?=
    map rankedLengthCandidateOriginalIndex
      (lengthRankingCandidates direct)
  rankedLengthPreparationRefusals configured @?=
    rankedLengthPreparationRefusals direct
  lengthRankingFailure configured @?= lengthRankingFailure direct

data LengthRankingLiveFixture = LengthRankingLiveFixture
  { lengthRankingFixtureZero
      :: Verified DetailedVerificationVariant
  , lengthRankingFixtureOne
      :: Verified DetailedVerificationVariant
  }

assertLengthPreparationRefusalClasses :: IO ()
assertLengthPreparationRefusalClasses = do
  let poison label = error $ "preparation sanitizer forced " ++ label
      handoffRefusals =
        [ LengthHandoffNotTypedRoute $ poison "route"
        , LengthHandoffMissingSemanticSidecar
        , LengthHandoffRetargetedFragments
        , LengthHandoffPremisesPresent
        , LengthHandoffSearchGoalChanged
        , LengthHandoffSourceGoalVariableMissing $ poison "source variable"
        , LengthHandoffSourceGoalConversionChanged
        , LengthHandoffRequestContextsPresent $ poison "request contexts"
        , LengthHandoffRequestGoalChanged
        , LengthHandoffTypedGraphLost $ poison "typed graph"
        , LengthHandoffRendererRejected $ poison "renderer refusal"
        , LengthHandoffRendererNotUnique $ poison "renderer alternatives"
        , LengthHandoffRendererOrdinalChanged $ poison "renderer ordinal"
        , LengthHandoffRendererTextChanged
            (poison "rendered candidate") (poison "accepted candidate")
        , LengthHandoffFamilyUnavailable $ poison "family"
        , LengthHandoffConstructorUnavailable
            (poison "family constructor") (poison "constructor")
        , LengthHandoffProviderUnavailable $ poison "provider"
        , LengthHandoffProviderAmbiguous
            (poison "ambiguous provider") (poison "provider matches")
        , LengthHandoffProviderVariableMissing
            (poison "provider variable") (poison "provider source")
        , LengthHandoffSessionRejected $ poison "session error"
        , LengthHandoffContractRejected $ poison "contract error"
        , LengthHandoffProblemRejected $ poison "problem error"
        ]
      expectedHandoffClasses =
        [ LengthPreparationUnsupportedRoute
        , LengthPreparationTypedAuthorityUnavailable
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationCandidateAssociationRejected
        , LengthPreparationTypedAuthorityUnavailable
        , LengthPreparationRenderingAssociationRejected
        , LengthPreparationRenderingAssociationRejected
        , LengthPreparationRenderingAssociationRejected
        , LengthPreparationRenderingAssociationRejected
        , LengthPreparationSpineBindingUnavailable
        , LengthPreparationSpineBindingUnavailable
        , LengthPreparationProviderBindingUnavailable
        , LengthPreparationProviderBindingUnavailable
        , LengthPreparationProviderBindingUnavailable
        , LengthPreparationSessionRejected
        , LengthPreparationContractRejected
        , LengthPreparationCandidateSemanticsRejected
        ]
      queryRefusals =
        [ Djex.LengthSMTLibUnexpectedResultVariable
        , Djex.LengthSMTLibInputVariableOutOfRange 0 0
        , Djex.LengthSMTLibNumeralBitLimitExceeded
            Djex.LengthSMTLibLiteralNumeral 1 0
        , Djex.LengthSMTLibCommandByteLimitExceeded
            Djex.LengthSMTLibCheckCommand 1 0
        , Djex.LengthSMTLibFingerprintByteLimitExceeded 1 0
        ]
      classes = [minBound .. maxBound]
      expectedCodes =
        [ "unsupported-route"
        , "typed-authority-unavailable"
        , "candidate-association-rejected"
        , "rendering-association-rejected"
        , "spine-binding-unavailable"
        , "provider-binding-unavailable"
        , "session-rejected"
        , "contract-rejected"
        , "candidate-semantics-rejected"
        , "query-construction-rejected"
        ]
  map lengthHandoffPreparationRefusalClass handoffRefusals @?=
    expectedHandoffClasses
  map lengthQueryPreparationRefusalClass queryRefusals @?=
    replicate 5 LengthPreparationQueryConstructionRejected
  map lengthPreparationRefusalClassCode classes @?= expectedCodes
  Set.size (Set.fromList expectedCodes) @?= length expectedCodes
  let sanitized = show $ lengthHandoffPreparationRefusalClass
        $ LengthHandoffRendererTextChanged
            "private-rendered-candidate" "private-accepted-candidate"
  assertBool "preparation sanitizer retained renderer payload text"
    $ not $ "private-" `isInfixOf` sanitized

assertLengthRankingInputBound :: IO ()
assertLengthRankingInputBound = do
  candidate <- syntheticLengthRankingCandidate "synthetic-bound"
  let maximumCandidates =
        Djex.defaultLengthSMTLibLiveSessionMaximumQueries
      exact = replicate (fromIntegral maximumCandidates) candidate
      unopened = error "Length ranking opened a worker during input admission"
  admitted <- rankVerifiedLengthCandidates unopened
    defaultLengthEvaluationLimits ineligibleLengthRankingContract exact
  exactRanking <- expectRight admitted
  length (lengthRankingCandidates exactRanking) @?=
    fromIntegral maximumCandidates
  lengthRankingFailure exactRanking @?= Nothing
  map rankedLengthCandidateAssessment
      (lengthRankingCandidates exactRanking) @?=
    replicate (fromIntegral maximumCandidates) Unassessed
  rankedLengthPreparationRefusals exactRanking @?=
    replicate (fromIntegral maximumCandidates)
      (Just LengthPreparationTypedAuthorityUnavailable)

  bounded <- timeout 1000000 $ rankVerifiedLengthCandidates unopened
    defaultLengthEvaluationLimits ineligibleLengthRankingContract
    $ repeat candidate
  case bounded of
    Just (Left (LengthRankingInputLimitExceeded admittedMaximum observed)) -> do
      admittedMaximum @?= maximumCandidates
      observed @?= maximumCandidates + 1
    Just (Right _) -> assertFailure
      "cyclic maximum-plus-one ranking input was admitted"
    Nothing -> assertFailure
      "cyclic maximum-plus-one ranking input was not rejected productively"

assertLengthRankingAllIneligible :: IO ()
assertLengthRankingAllIneligible = do
  first <- syntheticLengthRankingCandidate "synthetic-first"
  second <- syntheticLengthRankingCandidate "synthetic-second"
  let original = [first, second]
      unopened = error "all-ineligible Length ranking opened a live session"
  result <- rankVerifiedLengthCandidates unopened
    defaultLengthEvaluationLimits ineligibleLengthRankingContract original
  ranking <- expectRight result
  lengthRankingFailure ranking @?= Nothing
  rankedLengthVerifiedCandidates ranking @?= original
  map rankedLengthCandidateAssessment (lengthRankingCandidates ranking) @?=
    [Unassessed, Unassessed]
  rankedLengthPreparationRefusals ranking @?=
    replicate 2 (Just LengthPreparationTypedAuthorityUnavailable)

assertLengthRankingNeutralStatuses :: IO ()
assertLengthRankingNeutralStatuses = do
  fixture <- buildLengthRankingLiveFixture
  ineligible <- syntheticLengthRankingCandidate "neutral-ineligible"
  let zero = lengthRankingFixtureZero fixture
      one = lengthRankingFixtureOne fixture
      original =
        [zero, ineligible, one]
      cases =
        [ ( "healthy"
          , Djex.LengthSMTLibStatusOnly
          , Djex.SolverSatisfiable
          )
        , ( "query-unsat"
          , Djex.LengthSMTLibInputValuesAfterSatisfiable
          , Djex.SolverUnsatisfiable
          )
        , ( "query-unknown"
          , Djex.LengthSMTLibInputValuesAfterSatisfiable
          , Djex.SolverUnknown
          )
        ]
  mapM_ (assertNeutralCase original) cases

assertNeutralCase
  :: [Verified DetailedVerificationVariant]
  -> (String, Djex.LengthSMTLibArtifactPolicy, Djex.SolverStatus)
  -> IO ()
assertNeutralCase original (mode, policy, expectedStatus) = do
  ranking <- runLengthRankingWithFake mode policy
    (lengthRankingContract 0) original
  lengthRankingFailure ranking @?= Nothing
  rankedLengthVerifiedCandidates ranking @?= original
  case map rankedLengthCandidateAssessment
      $ lengthRankingCandidates ranking of
    [Heuristic zero, Unassessed, Heuristic one] ->
      (zero, one) @?= (expectedStatus, expectedStatus)
    assessments -> assertFailure $ "unexpected neutral Length assessments: "
      ++ show assessments
  rankedLengthPreparationRefusals ranking @?=
    [Nothing, Just LengthPreparationTypedAuthorityUnavailable, Nothing]

assertLengthRankingCounterexampleDemotion :: IO ()
assertLengthRankingCounterexampleDemotion = do
  fixture <- buildLengthRankingLiveFixture
  retainedFirst <- syntheticLengthRankingCandidate "retained-first"
  retainedSecond <- syntheticLengthRankingCandidate "retained-second"
  let zero = lengthRankingFixtureZero fixture
      one = lengthRankingFixtureOne fixture
      contract = lengthRankingContract 2
      original = [zero, retainedFirst, one, retainedSecond]
      expected = [retainedFirst, retainedSecond, zero, one]
  zeroHandoff <- expectRight $ prepareCheckedLengthHandoff contract zero
  oneHandoff <- expectRight $ prepareCheckedLengthHandoff contract one
  zeroQuery <- expectRight $ prepareLengthQueryFromHandoff zeroHandoff
  oneQuery <- expectRight $ prepareLengthQueryFromHandoff oneHandoff
  assertBool "distinct checked providers shared a Length query identity"
    $ Djex.lengthSMTLibQueryFingerprint zeroQuery /=
        Djex.lengthSMTLibQueryFingerprint oneQuery
  assertLengthRankingQueryAssociation zeroHandoff zeroQuery
  assertLengthRankingQueryAssociation oneHandoff oneQuery
  ranking <- runLengthRankingWithFake "healthy"
    Djex.LengthSMTLibInputValuesAfterSatisfiable
    contract original
  lengthRankingFailure ranking @?= Nothing
  length (lengthRankingCandidates ranking) @?= length original
  rankedLengthVerifiedCandidates ranking @?= expected
  case map rankedLengthCandidateAssessment
      $ lengthRankingCandidates ranking of
    [Unassessed, Unassessed, Counterexample zeroReceipt,
        Counterexample oneReceipt] -> do
      assertLengthCounterexampleReceipt 0 zeroReceipt
      assertLengthCounterexampleReceipt 1 oneReceipt
    assessments -> assertFailure $
      "unexpected stable counterexample partition: " ++ show assessments
  rankedLengthPreparationRefusals ranking @?=
    [ Just LengthPreparationTypedAuthorityUnavailable
    , Just LengthPreparationTypedAuthorityUnavailable
    , Nothing
    , Nothing
    ]

assertLengthRankingAtomicFallback :: IO ()
assertLengthRankingAtomicFallback = do
  fixture <- buildLengthRankingLiveFixture
  trailing <- syntheticLengthRankingCandidate "fallback-trailing"
  let zero = lengthRankingFixtureZero fixture
      one = lengthRankingFixtureOne fixture
      original = [one, zero, trailing]
  ranking <- runLengthRankingWithFake "healthy"
    Djex.LengthSMTLibInputValuesAfterSatisfiable
    (lengthRankingContract 0) original
  rankedLengthVerifiedCandidates ranking @?= original
  map rankedLengthCandidateAssessment (lengthRankingCandidates ranking) @?=
    replicate 3 Unassessed
  rankedLengthPreparationRefusals ranking @?=
    [Nothing, Nothing, Just LengthPreparationTypedAuthorityUnavailable]
  failure <- case lengthRankingFailure ranking of
    Nothing -> assertFailure
      "a satisfiable non-counterexample did not fail closed"
    Just value -> pure value
  lengthRankingFailureClass failure @?=
    LengthRankingLiveQueryFailed
      Djex.LengthSMTLibLiveQueryCounterexampleRejected
  lengthRankingFailureCleanupIncomplete failure @?= False
  lengthRankingFailureOriginalIndex failure @?= Just 1

assertLengthPostVerificationAdapter :: IO ()
assertLengthPostVerificationAdapter = do
  fixture <- buildLengthRankingLiveFixture
  retainedFirst <- syntheticLengthRankingCandidate
    "post-verification-retained-first"
  retainedSecond <- syntheticLengthRankingCandidate
    "post-verification-retained-second"
  trailing <- syntheticLengthRankingCandidate
    "post-verification-fallback-trailing"
  let zero = lengthRankingFixtureZero fixture
      one = lengthRankingFixtureOne fixture
      rawDemotion = [zero, retainedFirst, one, retainedSecond]
      rawFallback = [one, zero, trailing]
      maximumCandidates =
        Djex.defaultLengthSMTLibLiveSessionMaximumQueries
      oversizedCount = fromIntegral maximumCandidates + 1
  oversizedVerification <- verificationBatchFromReceipts
    $ replicate oversizedCount zero
  demotionVerification <- verificationBatchFromReceipts rawDemotion
  fallbackVerification <- verificationBatchFromReceipts rawFallback
  let demotionInput = verifiedCandidateReceipts demotionVerification
      demotionExpected = case demotionInput of
        [verifiedZero, verifiedRetainedFirst, verifiedOne,
            verifiedRetainedSecond] ->
          [ verifiedRetainedFirst
          , verifiedRetainedSecond
          , verifiedZero
          , verifiedOne
          ]
        _ -> error "post-verification demotion fixture changed cardinality"
      fallbackInput = verifiedCandidateReceipts fallbackVerification
  withFakeLengthSolver "healthy" $ \executable -> do
    let executionSource = explicitLengthRankingExecutionSource
          executable Nothing Djex.LengthSMTLibInputValuesAfterSatisfiable
        policySource = explicitLengthRankingPolicySource
          Djex.defaultLengthSMTLibExecutionLimits
          executionSource
          Djex.defaultLengthEvaluationLimitSource
        configured contract = mkLengthRankingConfiguration
          $ explicitLengthRankingConfigurationSource
              Djex.defaultLengthSMTLibExecutionLimits
              executionSource
              Djex.defaultLengthEvaluationLimitSource
              contract
    policy <- expectRight $ mkLengthRankingPolicy policySource
    demotionConfiguration <- expectRight
      $ configured $ lengthRankingContract 2
    fallbackConfiguration <- expectRight
      $ configured $ lengthRankingContract 0
    poisonContractConfiguration <- expectRight
      $ configured
          $ error "configured input admission forced the Length contract"

    rejected <- expectLengthPostVerificationWithin "bounded input rejection"
      $ assessVerifiedLengthCandidatesWithPolicy policy
          (error "input rejection forced the Length contract")
          oversizedVerification
    lengthPostVerificationAdapterFailure rejected @?= Just
      (LengthPostVerificationInputRejected
        $ LengthRankingInputLimitExceeded maximumCandidates
            (maximumCandidates + 1))
    assertBool "input rejection retained an impossible ranking report"
      $ isNothing $ lengthPostVerificationRanking rejected
    assertBool "rejected input masqueraded as a sealed candidate batch"
      $ isNothing $ lengthPostVerificationSealedBatch rejected
    lengthPostVerificationCandidates rejected @?=
      verifiedCandidateReceipts oversizedVerification

    let poison :: DetailedVerificationVariant
        poison = error
          "configured post-verification input admission forced a candidate"
    poisonedOversizedVerification <- verifyCandidateGroups oversizedCount
      (const $ pure VariantAccepted)
      $ replicate oversizedCount [poison]
    configuredRejected <- expectLengthPostVerificationWithin
      "configured bounded input rejection"
      $ assessVerifiedLengthCandidatesConfigured poisonContractConfiguration
          poisonedOversizedVerification
    lengthPostVerificationAdapterFailure configuredRejected @?= Just
      (LengthPostVerificationInputRejected
        $ LengthRankingInputLimitExceeded maximumCandidates
            (maximumCandidates + 1))
    assertBool "configured input rejection retained an impossible ranking"
      $ isNothing $ lengthPostVerificationRanking configuredRejected
    assertBool "configured input rejection masqueraded as a sealed batch"
      $ isNothing $ lengthPostVerificationSealedBatch configuredRejected
    length (lengthPostVerificationCandidates configuredRejected) @?=
      oversizedCount

    demotion <- expectLengthPostVerificationWithin "counterexample demotion"
      $ assessVerifiedLengthCandidatesWithPolicy policy
          (lengthRankingContract 2) demotionVerification
    lengthPostVerificationAdapterFailure demotion @?= Nothing
    lengthPostVerificationCandidates demotion @?= demotionExpected
    assertLengthPostVerificationSealed demotion
    demotionRanking <- expectLengthPostVerificationRanking demotion
    map rankedLengthCandidateOriginalIndex
        (lengthRankingCandidates demotionRanking) @?=
      [1, 3, 0, 2]
    rankedLengthVerifiedCandidates demotionRanking @?= demotionExpected
    rankedLengthPreparationRefusals demotionRanking @?=
      [ Just LengthPreparationTypedAuthorityUnavailable
      , Just LengthPreparationTypedAuthorityUnavailable
      , Nothing
      , Nothing
      ]
    configuredDemotion <- expectLengthPostVerificationWithin
      "configured counterexample demotion"
      $ assessVerifiedLengthCandidatesConfigured demotionConfiguration
          demotionVerification
    assertLengthPostVerificationResultsEquivalent demotion
      configuredDemotion

    duplicateVerification <- verificationBatchFromReceipts
      [zero, zero, retainedFirst]
    duplicatePolicy <- expectLengthPostVerificationWithin
      "equal-occurrence policy demotion"
      $ assessVerifiedLengthCandidatesWithPolicy policy
          (lengthRankingContract 2) duplicateVerification
    duplicateConfigured <- expectLengthPostVerificationWithin
      "equal-occurrence configured demotion"
      $ assessVerifiedLengthCandidatesConfigured demotionConfiguration
          duplicateVerification
    assertLengthPostVerificationResultsEquivalent duplicatePolicy
      duplicateConfigured
    duplicateRanking <- expectLengthPostVerificationRanking
      duplicateConfigured
    map rankedLengthCandidateOriginalIndex
        (lengthRankingCandidates duplicateRanking) @?=
      [2, 0, 1]
    length (lengthPostVerificationCandidates duplicateConfigured) @?= 3

    fallback <- expectLengthPostVerificationWithin "atomic ranking fallback"
      $ assessVerifiedLengthCandidatesWithPolicy policy
          (lengthRankingContract 0) fallbackVerification
    lengthPostVerificationAdapterFailure fallback @?= Nothing
    lengthPostVerificationCandidates fallback @?= fallbackInput
    assertLengthPostVerificationSealed fallback
    fallbackRanking <- expectLengthPostVerificationRanking fallback
    map rankedLengthCandidateOriginalIndex
        (lengthRankingCandidates fallbackRanking) @?=
      [0, 1, 2]
    rankedLengthVerifiedCandidates fallbackRanking @?= fallbackInput
    rankedLengthPreparationRefusals fallbackRanking @?=
      [Nothing, Nothing, Just LengthPreparationTypedAuthorityUnavailable]
    case lengthRankingFailure fallbackRanking of
      Nothing -> assertFailure
        "post-verification adapter discarded the ranking failure report"
      Just failure -> lengthRankingFailureClass failure @?=
        LengthRankingLiveQueryFailed
          Djex.LengthSMTLibLiveQueryCounterexampleRejected
    configuredFallback <- expectLengthPostVerificationWithin
      "configured atomic ranking fallback"
      $ assessVerifiedLengthCandidatesConfigured fallbackConfiguration
          fallbackVerification
    assertLengthPostVerificationResultsEquivalent fallback
      configuredFallback

assertLengthPostVerificationResultsEquivalent
  :: LengthPostVerificationResult
  -> LengthPostVerificationResult
  -> IO ()
assertLengthPostVerificationResultsEquivalent expected actual = do
  lengthPostVerificationCandidates actual @?=
    lengthPostVerificationCandidates expected
  lengthPostVerificationAdapterFailure actual @?=
    lengthPostVerificationAdapterFailure expected
  case ( lengthPostVerificationSealedBatch expected
       , lengthPostVerificationSealedBatch actual
       ) of
    (Nothing, Nothing) -> pure ()
    (Just expectedBatch, Just actualBatch) ->
      postVerificationBatchCandidates actualBatch @?=
        postVerificationBatchCandidates expectedBatch
    _ -> assertFailure
      "configured post-verification sealing disagreed with the policy path"
  case ( lengthPostVerificationRanking expected
       , lengthPostVerificationRanking actual
       ) of
    (Nothing, Nothing) -> pure ()
    (Just expectedRanking, Just actualRanking) ->
      assertLengthRankingsEquivalent expectedRanking actualRanking
    _ -> assertFailure
      "configured post-verification ranking disagreed with the policy path"

verificationBatchFromReceipts
  :: [Verified DetailedVerificationVariant]
  -> IO (VerificationBatch DetailedVerificationVariant)
verificationBatchFromReceipts receipts =
  verifyCandidateGroups (length receipts) (const $ pure VariantAccepted)
    [[verifiedCandidate receipt] | receipt <- receipts]

expectLengthPostVerificationWithin
  :: String
  -> IO LengthPostVerificationResult
  -> IO LengthPostVerificationResult
expectLengthPostVerificationWithin label action = do
  bounded <- timeout 8000000 action
  case bounded of
    Nothing -> assertFailure $ "Length post-verification " ++ label
      ++ " exceeded its outer bound"
    Just result -> pure result

expectLengthPostVerificationRanking
  :: LengthPostVerificationResult
  -> IO LengthRanking
expectLengthPostVerificationRanking result = case
    lengthPostVerificationRanking result of
  Nothing -> assertFailure
    "Length post-verification result discarded its ranking report"
  Just ranking -> pure ranking

assertLengthPostVerificationSealed
  :: LengthPostVerificationResult
  -> IO ()
assertLengthPostVerificationSealed result = case
    lengthPostVerificationSealedBatch result of
  Nothing -> assertFailure
    "Length post-verification output bypassed its permutation seal"
  Just batch -> postVerificationBatchCandidates batch @?=
    lengthPostVerificationCandidates result

assertLengthCounterexampleReceipt
  :: Natural
  -> Djex.ValidatedLengthCounterexample
  -> IO ()
assertLengthCounterexampleReceipt expectedResult receipt = do
  Djex.validatedLengthCounterexampleInputs receipt @?= []
  Djex.validatedLengthCounterexampleResult receipt @?= expectedResult

assertLengthRankingQueryAssociation
  :: CheckedLengthHandoff
  -> CheckedLengthQuery
  -> IO ()
assertLengthRankingQueryAssociation handoff query = do
  assertBool "the exact checked ranking query retained no identity"
    $ not $ null $ Djex.fingerprintCanonicalBytes
      $ Djex.lengthSMTLibQueryFingerprint query
  Djex.behavioralProblemFingerprint
      (Djex.lengthSMTLibQueryBehavioralProblem query) @?=
    Djex.behavioralProblemFingerprint
      (Djex.checkedLengthProblemBehavioralProblem
        $ checkedLengthHandoffProblem handoff)

rankedLengthVerifiedCandidates
  :: LengthRanking
  -> [Verified DetailedVerificationVariant]
rankedLengthVerifiedCandidates =
  map rankedLengthCandidateVerified . lengthRankingCandidates

rankedLengthPreparationRefusals
  :: LengthRanking
  -> [Maybe LengthPreparationRefusalClass]
rankedLengthPreparationRefusals =
  map rankedLengthCandidatePreparationRefusal . lengthRankingCandidates

syntheticLengthRankingCandidate
  :: String
  -> IO (Verified DetailedVerificationVariant)
syntheticLengthRankingCandidate spelling = do
  let group = detailedCandidateGroup RouteTypedCandidate [spelling]
  batch <- verifyCandidateGroups 1 (const $ pure VariantAccepted)
    [detailedCandidateGroupVerificationVariants group]
  case verifiedCandidateReceipts batch of
    [verified] -> pure verified
    receipts -> assertFailure $ "synthetic verification produced " ++
      show (length receipts) ++ " receipts"

ineligibleLengthRankingContract :: LeanLengthContract
ineligibleLengthRankingContract = LeanLengthContract
  { leanLengthContractSpine = LeanLengthSpineIdentity
      { leanLengthSpineFamilyName = "Unreachable.List"
      , leanLengthSpineZeroConstructorName = "Unreachable.List.nil"
      , leanLengthSpineStepConstructorName = "Unreachable.List.cons"
      }
  , leanLengthContractSource = LengthContractSource
      { lengthContractPrecondition = LengthTruth True
      , lengthContractPostcondition = LengthTruth True
      }
  , leanLengthContractProviderLaws = []
  }

lengthRankingContract :: Natural -> LeanLengthContract
lengthRankingContract expectedResult = LeanLengthContract
  { leanLengthContractSpine = LeanLengthSpineIdentity
      { leanLengthSpineFamilyName = "List"
      , leanLengthSpineZeroConstructorName = "List.nil"
      , leanLengthSpineStepConstructorName = "List.cons"
      }
  , leanLengthContractSource = LengthContractSource
      { lengthContractPrecondition = LengthTruth True
      , lengthContractPostcondition = LengthEqual
          (LengthVariable LengthResult)
          (LengthLiteral expectedResult)
      }
  , leanLengthContractProviderLaws =
      [ LeanLengthProviderLaw
          { leanLengthProviderLawName = "Demo.zeroList"
          , leanLengthProviderLawArgumentRoles = []
          , leanLengthProviderLawTransfer = LengthLiteral 0
          }
      , LeanLengthProviderLaw
          { leanLengthProviderLawName = "Demo.oneList"
          , leanLengthProviderLawArgumentRoles = []
          , leanLengthProviderLawTransfer = LengthLiteral 1
          }
      ]
  }

buildLengthRankingLiveFixture :: IO LengthRankingLiveFixture
buildLengthRankingLiveFixture = do
  let natural = FAtom False "Nat"
      listKey = "List Nat"
      list = FParamRec True "List" listKey [natural]
        [ ("List.nil", [])
        , ("List.cons", [natural, FAtom False listKey])
        ]
      zeroProvider = ProviderFrag "Demo.zeroList" list
      oneProvider = ProviderFrag "Demo.oneList" list
  detailed <- expectRight $ synthesizeWithProvidersSkippingDetailed
    EngineExference 256 Set.empty [zeroProvider, oneProvider] list
  (zeroOrigin, oneOrigin) <- case detailed of
    DetailedSynthCandidates candidates _ -> case
        (directProvider "Demo.zeroList" candidates,
          directProvider "Demo.oneList" candidates) of
      (zero : _, one : _) -> pure (zero, one)
      _ -> assertFailure $ "Length ranking fixture lacked its two direct " ++
        "providers: " ++ show candidates
    other -> assertFailure $ "Length ranking fixture produced: " ++ show other
  zero <- verifySingleLengthRankingGroup zeroOrigin
  one <- verifySingleLengthRankingGroup oneOrigin
  zeroHandoff <- expectRight $ prepareCheckedLengthHandoff
    (lengthRankingContract 0) zero
  oneHandoff <- expectRight $ prepareCheckedLengthHandoff
    (lengthRankingContract 0) one
  checkedLengthCandidateResult
      (checkedLengthProblemCandidate
        $ checkedLengthHandoffProblem zeroHandoff) @?=
    LengthLiteral 0
  checkedLengthCandidateResult
      (checkedLengthProblemCandidate
        $ checkedLengthHandoffProblem oneHandoff) @?=
    LengthLiteral 1
  pure LengthRankingLiveFixture
    { lengthRankingFixtureZero = zero
    , lengthRankingFixtureOne = one
    }
 where
  directProvider spelling = filter $ \group ->
    detailedCandidateGroupVariants group == [spelling]
      && not (isNothing $ detailedCandidateGroupSemanticSidecar group)

verifySingleLengthRankingGroup
  :: DetailedCandidateGroup
  -> IO (Verified DetailedVerificationVariant)
verifySingleLengthRankingGroup group = do
  batch <- verifyCandidateGroups 1 (const $ pure VariantAccepted)
    [detailedCandidateGroupVerificationVariants group]
  case verifiedCandidateReceipts batch of
    [verified] -> pure verified
    receipts -> assertFailure $ "checked Length group produced " ++
      show (length receipts) ++ " verification receipts"

runLengthRankingWithFake
  :: String
  -> Djex.LengthSMTLibArtifactPolicy
  -> LeanLengthContract
  -> [Verified DetailedVerificationVariant]
  -> IO LengthRanking
runLengthRankingWithFake mode policy contract candidates =
  withFakeLengthSolver mode $ \executable -> do
    execution <- expectRight $ Djex.mkLengthSMTLibExecutionConfig
      Djex.defaultLengthSMTLibExecutionLimits
      $ (Djex.defaultLengthSMTLibExecutionConfigSource executable Nothing)
          { Djex.lengthSMTLibExecutionConfigSourceSolverTimeoutMilliseconds =
              100
          , Djex.lengthSMTLibExecutionConfigSourceSolverResourceLimit = 4242
          , Djex.lengthSMTLibExecutionConfigSourceHostDeadlineMilliseconds =
              1000
          , Djex.lengthSMTLibExecutionConfigSourceArtifactPolicy = policy
          }
    bounded <- timeout 8000000 $ rankVerifiedLengthCandidates execution
      defaultLengthEvaluationLimits contract candidates
    case bounded of
      Nothing -> assertFailure $ "Length ranking mode exceeded its bound: " ++
        mode
      Just result -> expectRight result

withFakeLengthSolver :: String -> (FilePath -> IO result) -> IO result
withFakeLengthSolver mode action =
  withTemporaryDirectory "leant-length-ranking" $ \root -> do
    source <- findExecutable "djex-fake-z3" >>= maybe
      (assertFailure "cannot locate the djex-fake-z3 build tool")
      canonicalizePath
    let extension
          | os == "mingw32" = ".exe"
          | otherwise = ""
        target = root </> ("djex-fake-z3-" ++ mode ++ extension)
    copyFile source target
    permissions <- getPermissions source
    setPermissions target $ setOwnerExecutable True permissions
    canonicalizePath target >>= action

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
              let compatibilityGroup = detailedCandidateGroup
                    RouteUnobserved
                    [ "djinn-only"
                    , "Demo.emptyList"
                    , "djinn-tail"
                    ]
                  recoveredGroups = mergeDetailedCandidateGroups
                    [compatibilityGroup] [origin]
              map detailedCandidateGroupVariants recoveredGroups @?=
                mergeCandidateGroups
                  [["djinn-only", "Demo.emptyList", "djinn-tail"]]
                  [["Demo.emptyList"]]
              case recoveredGroups of
                recovered : _ -> do
                  detailedCandidateGroupRoute recovered @?= RouteUnobserved
                  assertBool
                    "the display-owning Djinn group acquired a typed sidecar"
                    (isNothing
                      $ detailedCandidateGroupSemanticSidecar recovered)
                  let recoveredVariants =
                        detailedCandidateGroupVerificationVariants recovered
                  map detailedVerificationVariantOrdinal recoveredVariants
                    @?= [0, 1, 2]
                  map detailedVerificationVariantRoute recoveredVariants
                    @?= replicate 3 RouteUnobserved
                  map
                      (isNothing
                        . detailedVerificationVariantSemanticSidecar)
                      recoveredVariants
                    @?= [True, False, True]
                  recoveredBatch <- verifyCandidateGroups 1
                    (\variant -> pure $
                      if detailedVerificationVariantText variant
                          == "Demo.emptyList"
                        then VariantAccepted
                        else VariantRejected LeanErrorDiagnostic)
                    [recoveredVariants]
                  case verifiedCandidateReceipts recoveredBatch of
                    [recoveredVerified] -> do
                      detailedVerificationVariantOrdinal
                          (verifiedCandidate recoveredVerified) @?= 1
                      recoveredHandoff <- expectRight $
                        prepareCheckedLengthHandoff
                          contract recoveredVerified
                      checkedLengthCandidateResult
                          (checkedLengthProblemCandidate
                            $ checkedLengthHandoffProblem
                              recoveredHandoff)
                        @?= LengthLiteral 0
                    receipts -> assertFailure $
                      "exact duplicate provenance produced unexpected "
                        ++ "verification receipts: " ++ show receipts
                [] -> assertFailure
                  "exact duplicate provenance removed the displayed group"
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
                  query <- expectRight $
                    prepareLengthQueryFromHandoff handoff
                  lengthSMTLibQuerySchemaTag @?=
                    map (fromIntegral . fromEnum)
                      ("djex-length-z3-qf-lia-smtlib2/v2" :: String)
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
                  let responseBytes = map $ fromIntegral . fromEnum
                  Djex.parseLengthSMTLibCheckResponse
                      Djex.defaultLengthSMTLibResponseLimits
                      (responseBytes "unsat") @?=
                    Right Djex.SolverUnsatisfiable
                  Djex.parseLengthSMTLibInputValueResponse
                      Djex.defaultLengthSMTLibResponseLimits query
                      (responseBytes "()") @?=
                    Left Djex.LengthSMTLibInputValueResponseNotExpected
                  case Djex.parseLengthSMTLibCheckResponse
                      Djex.defaultLengthSMTLibResponseLimits
                      (responseBytes "unsat trailing") of
                    Left _ -> pure ()
                    Right status -> assertFailure $
                      "a trailing response became solver authority: "
                        ++ show status
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
      "decode a direct Djex List model before exact evidence replay" $ do
      -- The Leant handoff above is correctly zero-input, so get-value is not
      -- part of its query.  This test-only dependency fixture supplies the
      -- smallest honest one-input boundary: a typed Exference identity over
      -- one declared List spine, sealed through the same public Length APIs.
      responseListName <- expectRight $ Djex.mkIdentifier "ResponseList"
      responseNilName <- expectRight $ Djex.mkIdentifier "ResponseNil"
      responseConsName <- expectRight $ Djex.mkIdentifier "ResponseCons"
      responseTargetName <- expectRight $
        Djex.mkIdentifier "responseIdentity"
      responseTarget <- expectRight $
        Djex.mkDefinitionName responseTargetName
      let parameter = Djex.FlexibleVariable 0
            :: Djex.ExferenceTypeVariable
          payload = Djex.TupleType Djex.Boxed [] :: Djex.ExferenceType
          listOf value = Djex.TypeApplication
            (Djex.TypeConstructor responseListName) value
          recursiveList = listOf $ Djex.TypeVariable parameter
          declaration = Djex.DataTypeDeclaration () responseListName
            [Djex.TypeParameter parameter Nothing]
            [ Djex.DataConstructor () responseNilName []
            , Djex.DataConstructor () responseConsName
                [Djex.TypeVariable parameter, recursiveList]
            ]
          goal = Djex.FunctionType (listOf payload) (listOf payload)
          contract = Djex.LengthContractSource
            { Djex.lengthContractPrecondition = Djex.LengthTruth True
            , Djex.lengthContractPostcondition = Djex.LengthEqual
                (Djex.LengthVariable Djex.LengthResult)
                (Djex.LengthLiteral 0)
            }
          responseBytes = map $ fromIntegral . fromEnum
      environment <- expectRight
        (Djex.mkEnvironment [declaration] :: Either
          (Djex.EnvironmentError Djex.ExferenceTypeVariable)
          Djex.ExferenceEnvironment)
      session <- expectRight $ Djex.mkExferenceSession environment
      request <- expectRight $ Djex.mkExferenceRequest Djex.QueryRequest
        { Djex.requestTarget = responseTarget
        , Djex.requestGoal = goal
        , Djex.requestContexts = []
        , Djex.requestOptions = Djex.defaultExferenceOptions
            { Djex.exferenceMaximumSteps = 8
            , Djex.exferenceMultiConstructorPatterns = False
            }
        }
      results <- expectRight $ Djex.runExferenceTypedQuery session request
      let candidates =
            [ retained
            | result <- results
            , retained <- Djex.batchCandidates $ Djex.resultSearch result
            ]
      lengthSession <- expectRight $ Djex.sealLengthSession
        Djex.defaultLengthLimits
        (Djex.exferenceSessionInventory session)
        (Djex.DeclaredListSpine
          responseListName responseNilName responseConsName)
        []
      checkedContract <- expectRight $ Djex.sealLengthContractInContext
        Djex.defaultLengthLimits
        (Djex.checkedLengthSessionContext lengthSession)
        goal contract
      problem <- case
          [ retained
          | candidate <- candidates
          , Right retained <-
              [ Djex.sealLengthTypedCandidateProblem
                  Djex.defaultLengthProblemLimits
                  lengthSession checkedContract candidate
              ]
          , Djex.checkedLengthCandidateResult
              (Djex.checkedLengthProblemCandidate retained) ==
                Djex.LengthVariable (Djex.LengthInput 0)
          ] of
        retained : _ -> pure retained
        [] -> assertFailure
          "the direct fixture returned no checked identity candidate"
            >> error "unreachable"
      query <- expectRight $ Djex.sealLengthSMTLibQuery
        Djex.defaultLengthSMTLibLimits problem
      Djex.parseLengthSMTLibCheckResponse
          Djex.defaultLengthSMTLibResponseLimits
          (responseBytes "sat") @?=
        Right Djex.SolverSatisfiable
      case Djex.lengthSMTLibQueryInputSymbols query of
        [symbol] -> do
          bindings <- expectRight $
            Djex.parseLengthSMTLibInputValueResponse
              Djex.defaultLengthSMTLibResponseLimits query
              (responseBytes "((" ++ symbol ++ responseBytes " 3))")
          evidence <- case Djex.validateLengthSMTLibCounterexample
              Djex.defaultLengthEvaluationLimits query bindings of
            Left failure -> assertFailure
              ("model replay failed: " ++ show failure) >> error "unreachable"
            Right Nothing -> assertFailure
              "the violating identity model produced no evidence"
                >> error "unreachable"
            Right (Just retained) -> pure retained
          receipt <- expectRight $ Djex.replayBehavioralEvidence
            (Djex.checkedLengthProblemBehavioralProblem problem) evidence
          Djex.validatedLengthCounterexampleInputs receipt @?= [3]
          Djex.validatedLengthCounterexampleResult receipt @?= 3
        symbols -> assertFailure $
          "the direct identity query did not retain one input: "
            ++ show symbols
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
      "preserve the originating typed sidecar through filtering" $
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
                assertBool
                  "observable semantic ownership was absent from equality"
                  (origin /= detailedCandidateGroup RouteUnobserved
                    (detailedCandidateGroupVariants origin))
          Right other -> assertFailure $
            "expected a typed semantic candidate, got: " ++ show other
          Left err -> assertFailure err
  , testCase
      "recover a later exact Exference origin without changing Djinn display" $
      do
        origin <- typedIdentityCandidateGroup "Demo.LaterSemanticToken"
        let variants = detailedCandidateGroupVariants origin
            earlier = detailedCandidateGroup RouteUnobserved variants
            merged = mergeDetailedCandidateGroups [earlier] [origin]
        map detailedCandidateGroupVariants merged @?=
          mergeCandidateGroups [variants] [variants]
        merged @?= [earlier]
        case (detailedCandidateGroupSemanticSidecar origin, merged) of
          (Just originalSemantic, [displayed]) -> do
            detailedCandidateGroupRoute displayed @?= RouteUnobserved
            assertBool
              "a later exact origin became the Djinn group's own sidecar"
              (isNothing
                $ detailedCandidateGroupSemanticSidecar displayed)
            let recovered =
                  detailedCandidateGroupVerificationVariants displayed
            map detailedVerificationVariantText recovered @?= variants
            map detailedVerificationVariantRoute recovered @?=
              replicate (length variants) RouteUnobserved
            map detailedVerificationVariantOrdinal recovered @?=
              take (length variants) [0 ..]
            mapM_ (assertRecovered originalSemantic) recovered
          (Nothing, _) -> assertFailure
            "the later Exference group lacked typed authority"
          (_, groups) -> assertFailure $
            "the duplicate changed the displayed group structure: "
              ++ show groups
  , testCase
      "retain an earlier exact Exference origin over a compatibility duplicate" $
      do
        origin <- typedIdentityCandidateGroup "Demo.EarlierSemanticToken"
        let variants = detailedCandidateGroupVariants origin
            compatibility = detailedCandidateGroup RouteUnobserved variants
            merged = mergeDetailedCandidateGroups [origin] [compatibility]
        map detailedCandidateGroupVariants merged @?=
          mergeCandidateGroups [variants] [variants]
        merged @?= [origin]
        case merged of
          [displayed] -> do
            detailedCandidateGroupRoute displayed @?= RouteTypedCandidate
            assertBool
              "the earlier typed owner lost its group sidecar"
              (not $ isNothing
                $ detailedCandidateGroupSemanticSidecar displayed)
            assertBool
              "the earlier typed owner lost a verification sidecar"
              (all
                (not . isNothing
                  . detailedVerificationVariantSemanticSidecar)
                (detailedCandidateGroupVerificationVariants displayed))
          groups -> assertFailure $
            "the reverse duplicate changed the displayed group structure: "
              ++ show groups
  , testCase
      "scope a recovered typed origin to only the identical spelling" $ do
        origin <- typedIdentityCandidateGroup "Demo.MultiVariantToken"
        case detailedCandidateGroupVariants origin of
          [] -> assertFailure "the typed identity group had no spelling"
          shared : typedTail -> do
            let compatibilityVariants =
                  ["djinn-only", shared, "djinn-tail"]
                compatibility = detailedCandidateGroup
                  RouteUnobserved compatibilityVariants
                merged = mergeDetailedCandidateGroups
                  [compatibility] [origin]
            map detailedCandidateGroupVariants merged @?=
              mergeCandidateGroups [compatibilityVariants]
                [shared : typedTail]
            case merged of
              displayed : _ -> do
                detailedCandidateGroupVariants displayed @?=
                  compatibilityVariants
                detailedCandidateGroupRoute displayed @?= RouteUnobserved
                observationCount TypedCandidateRendered
                    (candidateRenderingRouteObservations
                      [detailedCandidateGroupRoute displayed])
                  @?= 0
                assertBool
                  "variant recovery transferred ownership to the Djinn group"
                  (isNothing
                    $ detailedCandidateGroupSemanticSidecar displayed)
                let recovered =
                      detailedCandidateGroupVerificationVariants displayed
                map detailedVerificationVariantText recovered @?=
                  compatibilityVariants
                map detailedVerificationVariantOrdinal recovered @?=
                  [0, 1, 2]
                map
                    (isNothing
                      . detailedVerificationVariantSemanticSidecar)
                    recovered
                  @?= [True, False, True]
                let wrap term = "wrapped (" ++ term ++ ")"
                    wrapped =
                      mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
                        wrap displayed
                detailedCandidateGroupVariants wrapped @?=
                  map wrap compatibilityVariants
                assertBool
                  "a textual wrapper retained recovered typed authority"
                  (all
                    (isNothing
                      . detailedVerificationVariantSemanticSidecar)
                    (detailedCandidateGroupVerificationVariants wrapped))
              [] -> assertFailure
                "variant-scoped recovery removed the display owner"
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
      let compatibility = detailedCandidateGroup
            RouteUnobserved ["compatibility"]
          lazyMerge = mergeDetailedCandidateGroups [compatibility] poison
      map detailedCandidateGroupVariants (take 1 lazyMerge)
        @?= [["compatibility"]]
      forceDetailedOutcome 1
          (Right $ DetailedSynthCandidates lazyMerge [])
        @?= length "compatibility"
      let twiceMerged = mergeDetailedCandidateGroups lazyMerge poison
      map detailedCandidateGroupVariants (take 1 twiceMerged)
        @?= [["compatibility"]]
      forceDetailedOutcome 1
          (Right $ DetailedSynthCandidates twiceMerged [])
        @?= length "compatibility"
  ]

typedIdentityCandidateGroup :: String -> IO DetailedCandidateGroup
typedIdentityCandidateGroup tokenName = do
  let token = FAtom False tokenName
      goal = FArr token token
  case synthesizeWithProvidersSkippingDetailed
      EngineExference 128 Set.empty [] goal of
    Right (DetailedSynthCandidates (origin : _) _) ->
      case detailedCandidateGroupSemanticSidecar origin of
        Just _ -> pure origin
        Nothing -> assertFailure $
          "typed identity origin lost its sidecar: " ++ show origin
    Right other -> assertFailure $
      "expected a typed identity candidate, got: " ++ show other
    Left err -> assertFailure err

assertRecovered
  :: TypedCandidateSemanticSidecar
  -> DetailedVerificationVariant
  -> IO ()
assertRecovered expected variant = case
    detailedVerificationVariantSemanticSidecar variant of
  Just recovered -> do
    typedCandidateSemanticCandidate recovered @?=
      typedCandidateSemanticCandidate expected
    typedCandidateSemanticInventory recovered @?=
      typedCandidateSemanticInventory expected
    typedCandidateSemanticFingerprint recovered @?=
      typedCandidateSemanticFingerprint expected
  Nothing -> assertFailure $
    "exact duplicate spelling lacked recovered typed authority: "
      ++ detailedVerificationVariantText variant

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
