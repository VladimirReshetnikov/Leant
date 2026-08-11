{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded v1 file grammar for explicit live Length ranking policy.
--
-- Decoding performs no discovery, path normalization, environment lookup, or
-- IO.  Every field is required.  A successful decode returns a deliberately
-- disabled opaque value: callers must separately choose whether an absent
-- executable digest pin is acceptable before they can obtain the runnable
-- 'LengthRankingConfiguration'.
module Leant.Synth.Length.Configuration.File
  ( lengthRankingConfigurationFileFormat
  , lengthRankingConfigurationFileVersion
  , lengthRankingConfigurationFileJsonLimits
  , LengthRankingConfigurationFileObject (..)
  , LengthRankingConfigurationFileField (..)
  , LengthRankingConfigurationFileValueType (..)
  , LengthRankingConfigurationFileTextMeasure (..)
  , LengthRankingConfigurationSyntaxPhase (..)
  , LengthRankingConfigurationSyntaxLimit (..)
  , LengthRankingConfigurationSyntaxError (..)
  , LengthRankingConfigurationFileError (..)
  , DisabledLengthRankingConfiguration
  , LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationActivationError (..)
  , decodeLengthRankingConfigurationFile
  , activateLengthRankingConfiguration
  ) where

import Data.ByteString (ByteString)
import Data.Char (ord)
import Data.List (find)
import Data.Maybe (isJust)
import qualified Data.Text as Text
import Data.Text (Text)
import Data.Word (Word8)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthContractSource (..)
  , LengthContractVariable (..)
  , LengthEvaluationLimitError
  , LengthEvaluationLimitSource (..)
  , LengthExpression (..)
  , LengthFormula (..)
  , LengthProviderArgumentRole (..)
  , LengthProviderVariable (..)
  , LengthSMTLibArtifactPolicy (..)
  , LengthSMTLibExecutionConfigError
  , LengthSMTLibExecutionConfigSource (..)
  , LengthSMTLibExecutionLimitSource (..)
  , LengthSMTLibExecutionLimits
  , LengthSMTLibResponseLimitError
  , LengthSMTLibResponseLimitSource (..)
  , LengthSMTLibResponseLimits
  , mkLengthEvaluationLimits
  , mkLengthSMTLibExecutionConfig
  , mkLengthSMTLibExecutionLimits
  , mkLengthSMTLibResponseLimits
  )

import Leant.Json.Bounded
  ( BoundedJsonError
  , BoundedJsonLimits (..)
  , BoundedJsonValue (..)
  , parseBoundedJson
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContract (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthSpineIdentity (..)
  )
import Leant.Synth.Length.Configuration
  ( LengthRankingConfiguration
  , LengthRankingConfigurationError
  , LengthRankingConfigurationSource (..)
  , mkLengthRankingConfiguration
  )

lengthRankingConfigurationFileFormat :: Text
lengthRankingConfigurationFileFormat =
  "leant-live-length-ranking-configuration"

lengthRankingConfigurationFileVersion :: Natural
lengthRankingConfigurationFileVersion = 1

-- | Fixed admission policy for the v1 document itself.  The array maximum is
-- one greater than the widest typed collection so maximum-plus-one reaches the
-- more specific schema diagnostic.
lengthRankingConfigurationFileJsonLimits :: BoundedJsonLimits
lengthRankingConfigurationFileJsonLimits = BoundedJsonLimits
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

data LengthRankingConfigurationFileObject
  = LengthRankingConfigurationRootObject
  | LengthRankingConfigurationExecutionAdmissionObject
  | LengthRankingConfigurationExecutionObject
  | LengthRankingConfigurationResponseLimitsObject
  | LengthRankingConfigurationEvaluationObject
  | LengthRankingConfigurationContractObject
  | LengthRankingConfigurationSpineObject
  | LengthRankingConfigurationProviderLawObject !Natural
  deriving (Eq, Ord, Show)

data LengthRankingConfigurationFileField
  = LengthRankingConfigurationFormatField
  | LengthRankingConfigurationVersionField
  | LengthRankingConfigurationExecutionAdmissionField
  | LengthRankingConfigurationExecutionField
  | LengthRankingConfigurationEvaluationField
  | LengthRankingConfigurationContractField
  | LengthRankingConfigurationExecutablePathCharactersField
  | LengthRankingConfigurationPolicyFingerprintBytesField
  | LengthRankingConfigurationExecutablePathField
  | LengthRankingConfigurationExpectedExecutableSha256Field
  | LengthRankingConfigurationSolverTimeoutMillisecondsField
  | LengthRankingConfigurationSolverResourceLimitField
  | LengthRankingConfigurationHostDeadlineMillisecondsField
  | LengthRankingConfigurationArtifactPolicyField
  | LengthRankingConfigurationResponseLimitsField
  | LengthRankingConfigurationResponseBytesField
  | LengthRankingConfigurationResponseNestingDepthField
  | LengthRankingConfigurationResponseNodesField
  | LengthRankingConfigurationResponseTokenBytesField
  | LengthRankingConfigurationResponseIntegerBitsField
  | LengthRankingConfigurationAssignmentValueBitsField
  | LengthRankingConfigurationIntermediateValueBitsField
  | LengthRankingConfigurationSpineField
  | LengthRankingConfigurationPreconditionField
  | LengthRankingConfigurationPostconditionField
  | LengthRankingConfigurationProviderLawsField
  | LengthRankingConfigurationSpineFamilyField
  | LengthRankingConfigurationSpineZeroField
  | LengthRankingConfigurationSpineStepField
  | LengthRankingConfigurationProviderLawNameField !Natural
  | LengthRankingConfigurationProviderLawArgumentRolesField !Natural
  | LengthRankingConfigurationProviderLawTransferField !Natural
  deriving (Eq, Ord, Show)

data LengthRankingConfigurationFileValueType
  = LengthRankingConfigurationObjectValue
  | LengthRankingConfigurationArrayValue
  | LengthRankingConfigurationStringValue
  | LengthRankingConfigurationIntegerValue
  | LengthRankingConfigurationBooleanValue
  | LengthRankingConfigurationNullOrStringValue
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthRankingConfigurationFileTextMeasure
  = LengthRankingConfigurationUnicodeScalars
  | LengthRankingConfigurationUtf8Bytes
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthRankingConfigurationSyntaxPhase
  = LengthRankingConfigurationPreconditionSyntax
  | LengthRankingConfigurationPostconditionSyntax
  | LengthRankingConfigurationProviderTransferSyntax !Natural
  deriving (Eq, Ord, Show)

data LengthRankingConfigurationSyntaxLimit
  = LengthRankingConfigurationSemanticDepth
  | LengthRankingConfigurationSyntaxNodes
  | LengthRankingConfigurationFormulaClauses
  | LengthRankingConfigurationSumTerms
  | LengthRankingConfigurationAllClauses
  | LengthRankingConfigurationLiteralBits
  | LengthRankingConfigurationInputIndex
  | LengthRankingConfigurationProviderArgumentIndex
  | LengthRankingConfigurationProviderArgumentRoleCount
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthRankingConfigurationSyntaxError
  = LengthRankingConfigurationExpectedTaggedArray
  | LengthRankingConfigurationExpectedTag
  | LengthRankingConfigurationUnknownTag
  | LengthRankingConfigurationTagArityMismatch !Natural !Natural
  | LengthRankingConfigurationExpectedSyntaxArray
  | LengthRankingConfigurationExpectedSyntaxBoolean
  | LengthRankingConfigurationExpectedSyntaxNatural
  | LengthRankingConfigurationSyntaxLimitExceeded
      !LengthRankingConfigurationSyntaxLimit !Natural !Natural
  deriving (Eq, Ord, Show)

-- | Sanitized file failure.  No unknown key or tag text, path, digest, Lean
-- name, or source snippet is retained.
data LengthRankingConfigurationFileError
  = LengthRankingConfigurationJsonRejected !BoundedJsonError
  | LengthRankingConfigurationExpectedObject
      !LengthRankingConfigurationFileObject
  | LengthRankingConfigurationUnexpectedField
      !LengthRankingConfigurationFileObject
  | LengthRankingConfigurationMissingField
      !LengthRankingConfigurationFileObject
      !LengthRankingConfigurationFileField
  | LengthRankingConfigurationFieldTypeMismatch
      !LengthRankingConfigurationFileField
      !LengthRankingConfigurationFileValueType
  | LengthRankingConfigurationFieldValueRejected
      !LengthRankingConfigurationFileField
  | LengthRankingConfigurationUnsupportedFormat
  | LengthRankingConfigurationUnsupportedVersion
  | LengthRankingConfigurationPolicyLimitExceeded
      !LengthRankingConfigurationFileField !Natural !Natural
  | LengthRankingConfigurationTextLimitExceeded
      !LengthRankingConfigurationFileField
      !LengthRankingConfigurationFileTextMeasure
      !Natural !Natural
  | LengthRankingConfigurationResponseLimitsRejected
      !LengthSMTLibResponseLimitError
  | LengthRankingConfigurationExecutionRejected
      !LengthSMTLibExecutionConfigError
  | LengthRankingConfigurationEvaluationRejected
      !LengthEvaluationLimitError
  | LengthRankingConfigurationSyntaxRejected
      !LengthRankingConfigurationSyntaxPhase
      !LengthRankingConfigurationSyntaxError
  | LengthRankingConfigurationAssemblyRejected
      !LengthRankingConfigurationError
  deriving (Eq, Ord, Show)

-- | A fully decoded and sealed policy which still grants no permission to run.
-- The Boolean records only whether the sealed source supplied an exact digest
-- expectation; the path and digest themselves remain inside the opaque policy.
data DisabledLengthRankingConfiguration =
  DisabledLengthRankingConfiguration !Bool !LengthRankingConfiguration

data LengthRankingConfigurationActivationPolicy
  = RequirePinnedExecutable
  | PermitUnpinnedExecutable
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthRankingConfigurationActivationError
  = LengthRankingConfigurationExecutablePinRequired
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Explicitly activate a decoded policy.  Requiring a pin fails closed when
-- the file supplied @null@; permitting an unpinned executable is a distinct,
-- visible caller decision rather than a decoder default.
activateLengthRankingConfiguration
  :: LengthRankingConfigurationActivationPolicy
  -> DisabledLengthRankingConfiguration
  -> Either
      LengthRankingConfigurationActivationError
      LengthRankingConfiguration
activateLengthRankingConfiguration policy
    (DisabledLengthRankingConfiguration pinned configuration) = case policy of
  RequirePinnedExecutable
    | not pinned -> Left LengthRankingConfigurationExecutablePinRequired
  _ -> Right configuration

decodeLengthRankingConfigurationFile
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthRankingConfiguration
decodeLengthRankingConfigurationFile bytes = do
  document <- either (Left . LengthRankingConfigurationJsonRejected) Right
    $ parseBoundedJson lengthRankingConfigurationFileJsonLimits bytes
  root <- objectFields LengthRankingConfigurationRootObject document
  formatValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationFormatField
    "format"
    root
  format <- stringField LengthRankingConfigurationFormatField formatValue
  if format == lengthRankingConfigurationFileFormat
    then pure ()
    else Left LengthRankingConfigurationUnsupportedFormat
  versionValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationVersionField
    "version"
    root
  version <- integerField LengthRankingConfigurationVersionField versionValue
  if version == toInteger lengthRankingConfigurationFileVersion
    then pure ()
    else Left LengthRankingConfigurationUnsupportedVersion
  exactFields LengthRankingConfigurationRootObject rootFields root
  executionAdmissionValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationExecutionAdmissionField
    "executionAdmission"
    root
  executionLimits <- decodeExecutionAdmission executionAdmissionValue
  executionValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationExecutionField
    "execution"
    root
  (executionSource, pinned) <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluationSource <- decodeEvaluation evaluationValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeContract contractValue
  let source = LengthRankingConfigurationSource
        { lengthRankingConfigurationExecutionLimits = executionLimits
        , lengthRankingConfigurationExecutionSource = executionSource
        , lengthRankingConfigurationEvaluationSource = evaluationSource
        , lengthRankingConfigurationContract = contract
        }
  configuration <- either
    (Left . LengthRankingConfigurationAssemblyRejected) Right
    $ mkLengthRankingConfiguration source
  pure $ DisabledLengthRankingConfiguration pinned configuration

rootFields :: [(Text, LengthRankingConfigurationFileField)]
rootFields =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ("contract", LengthRankingConfigurationContractField)
  ]

type ObjectFields = [(Text, BoundedJsonValue)]

exactObject
  :: LengthRankingConfigurationFileObject
  -> [(Text, LengthRankingConfigurationFileField)]
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ObjectFields
exactObject object expected value = case value of
  BoundedJsonObject fields -> do
    exactFields object expected fields
    Right fields
  _ -> Left $ LengthRankingConfigurationExpectedObject object

objectFields
  :: LengthRankingConfigurationFileObject
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ObjectFields
objectFields object value = case value of
  BoundedJsonObject fields -> Right fields
  _ -> Left $ LengthRankingConfigurationExpectedObject object

exactFields
  :: LengthRankingConfigurationFileObject
  -> [(Text, LengthRankingConfigurationFileField)]
  -> ObjectFields
  -> Either LengthRankingConfigurationFileError ()
exactFields object expected fields = case find unexpected fields of
  Just _ -> Left $ LengthRankingConfigurationUnexpectedField object
  Nothing -> case find missing expected of
    Just (_, field) -> Left $ LengthRankingConfigurationMissingField
      object field
    Nothing -> Right ()
 where
  unexpected (name, _) = name `notElem` map fst expected
  missing (name, _) = name `notElem` map fst fields

requiredField
  :: LengthRankingConfigurationFileObject
  -> LengthRankingConfigurationFileField
  -> Text
  -> ObjectFields
  -> Either LengthRankingConfigurationFileError BoundedJsonValue
requiredField object field name fields = case lookup name fields of
  Just value -> Right value
  Nothing -> Left $ LengthRankingConfigurationMissingField object field

stringField
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError Text
stringField field value = case value of
  BoundedJsonString text -> Right text
  _ -> Left $ LengthRankingConfigurationFieldTypeMismatch field
    LengthRankingConfigurationStringValue

integerField
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError Integer
integerField field value = case value of
  BoundedJsonInteger integer -> Right integer
  _ -> Left $ LengthRankingConfigurationFieldTypeMismatch field
    LengthRankingConfigurationIntegerValue

naturalField
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError Natural
naturalField field value = do
  integer <- integerField field value
  if integer < 0
    then Left $ LengthRankingConfigurationFieldValueRejected field
    else Right $ fromInteger integer

intField
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError Int
intField field value = do
  integer <- integerField field value
  if integer < toInteger (minBound :: Int)
      || integer > toInteger (maxBound :: Int)
    then Left $ LengthRankingConfigurationFieldValueRejected field
    else Right $ fromInteger integer

arrayField
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError [BoundedJsonValue]
arrayField field value = case value of
  BoundedJsonArray values -> Right values
  _ -> Left $ LengthRankingConfigurationFieldTypeMismatch field
    LengthRankingConfigurationArrayValue

capNatural
  :: LengthRankingConfigurationFileField
  -> Natural
  -> Natural
  -> Either LengthRankingConfigurationFileError Natural
capNatural field maximumValue value
  | value <= maximumValue = Right value
  | otherwise = Left $ LengthRankingConfigurationPolicyLimitExceeded
      field maximumValue (maximumValue + 1)

capIntUpper
  :: LengthRankingConfigurationFileField
  -> Int
  -> Int
  -> Either LengthRankingConfigurationFileError Int
capIntUpper field maximumValue value
  | value <= maximumValue = Right value
  | otherwise = Left $ LengthRankingConfigurationPolicyLimitExceeded
      field (fromIntegral maximumValue) (fromIntegral maximumValue + 1)

decodeExecutionAdmission
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthSMTLibExecutionLimits
decodeExecutionAdmission value = do
  object <- exactObject LengthRankingConfigurationExecutionAdmissionObject
    executionAdmissionFields value
  pathCharactersValue <- requiredField
    LengthRankingConfigurationExecutionAdmissionObject
    LengthRankingConfigurationExecutablePathCharactersField
    "executablePathCharacters"
    object
  pathCharacters <- naturalField
    LengthRankingConfigurationExecutablePathCharactersField
    pathCharactersValue
  retainedPathCharacters <- capNatural
    LengthRankingConfigurationExecutablePathCharactersField
    maximumExecutablePathCharacters pathCharacters
  fingerprintBytesValue <- requiredField
    LengthRankingConfigurationExecutionAdmissionObject
    LengthRankingConfigurationPolicyFingerprintBytesField
    "policyFingerprintBytes"
    object
  fingerprintBytes <- naturalField
    LengthRankingConfigurationPolicyFingerprintBytesField
    fingerprintBytesValue
  retainedFingerprintBytes <- capNatural
    LengthRankingConfigurationPolicyFingerprintBytesField
    maximumPolicyFingerprintBytes fingerprintBytes
  pure $ mkLengthSMTLibExecutionLimits LengthSMTLibExecutionLimitSource
    { lengthSMTLibExecutionLimitSourceExecutablePathCharacters =
        retainedPathCharacters
    , lengthSMTLibExecutionLimitSourcePolicyFingerprintBytes =
        retainedFingerprintBytes
    }

executionAdmissionFields :: [(Text, LengthRankingConfigurationFileField)]
executionAdmissionFields =
  [ ( "executablePathCharacters"
    , LengthRankingConfigurationExecutablePathCharactersField
    )
  , ( "policyFingerprintBytes"
    , LengthRankingConfigurationPolicyFingerprintBytesField
    )
  ]

maximumExecutablePathCharacters, maximumPolicyFingerprintBytes :: Natural
maximumExecutablePathCharacters = 4096
maximumPolicyFingerprintBytes = 262144

decodeExecution
  :: LengthSMTLibExecutionLimits
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthSMTLibExecutionConfigSource, Bool)
decodeExecution limits value = do
  object <- exactObject LengthRankingConfigurationExecutionObject
    executionFields value
  responseLimitsValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationResponseLimitsField
    "responseLimits"
    object
  responses <- decodeResponseLimits responseLimitsValue
  executableValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationExecutablePathField
    "executablePath"
    object
  executable <- Text.unpack <$> stringField
    LengthRankingConfigurationExecutablePathField
    executableValue
  expectedDigestValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationExpectedExecutableSha256Field
    "expectedExecutableSha256"
    object
  expectedDigest <- decodeExpectedDigest expectedDigestValue
  timeoutValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationSolverTimeoutMillisecondsField
    "solverTimeoutMilliseconds"
    object
  timeout <- intField
    LengthRankingConfigurationSolverTimeoutMillisecondsField
    timeoutValue
    >>= capIntUpper
      LengthRankingConfigurationSolverTimeoutMillisecondsField 60000
  resourceValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationSolverResourceLimitField
    "solverResourceLimit"
    object
  resource <- intField
    LengthRankingConfigurationSolverResourceLimitField
    resourceValue
    >>= capIntUpper
      LengthRankingConfigurationSolverResourceLimitField 10000000
  deadlineValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationHostDeadlineMillisecondsField
    "hostDeadlineMilliseconds"
    object
  deadline <- intField
    LengthRankingConfigurationHostDeadlineMillisecondsField
    deadlineValue
    >>= capIntUpper
      LengthRankingConfigurationHostDeadlineMillisecondsField 65000
  artifactPolicyValue <- requiredField
    LengthRankingConfigurationExecutionObject
    LengthRankingConfigurationArtifactPolicyField
    "artifactPolicy"
    object
  artifacts <- decodeArtifactPolicy artifactPolicyValue
  let source = LengthSMTLibExecutionConfigSource
        { lengthSMTLibExecutionConfigSourceExecutablePath = executable
        , lengthSMTLibExecutionConfigSourceExpectedExecutableSHA256 =
            expectedDigest
        , lengthSMTLibExecutionConfigSourceSolverTimeoutMilliseconds = timeout
        , lengthSMTLibExecutionConfigSourceSolverResourceLimit = resource
        , lengthSMTLibExecutionConfigSourceHostDeadlineMilliseconds = deadline
        , lengthSMTLibExecutionConfigSourceArtifactPolicy = artifacts
        , lengthSMTLibExecutionConfigSourceResponseLimits = responses
        }
  case mkLengthSMTLibExecutionConfig limits source of
    Left failure -> Left $ LengthRankingConfigurationExecutionRejected failure
    Right _ -> Right (source, isJust expectedDigest)

executionFields :: [(Text, LengthRankingConfigurationFileField)]
executionFields =
  [ ("executablePath", LengthRankingConfigurationExecutablePathField)
  , ( "expectedExecutableSha256"
    , LengthRankingConfigurationExpectedExecutableSha256Field
    )
  , ( "solverTimeoutMilliseconds"
    , LengthRankingConfigurationSolverTimeoutMillisecondsField
    )
  , ( "solverResourceLimit"
    , LengthRankingConfigurationSolverResourceLimitField
    )
  , ( "hostDeadlineMilliseconds"
    , LengthRankingConfigurationHostDeadlineMillisecondsField
    )
  , ("artifactPolicy", LengthRankingConfigurationArtifactPolicyField)
  , ("responseLimits", LengthRankingConfigurationResponseLimitsField)
  ]

decodeResponseLimits
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthSMTLibResponseLimits
decodeResponseLimits value = do
  object <- exactObject LengthRankingConfigurationResponseLimitsObject
    responseLimitFields value
  bytesValue <- requiredField
    LengthRankingConfigurationResponseLimitsObject
    LengthRankingConfigurationResponseBytesField
    "bytes"
    object
  bytes <- naturalField LengthRankingConfigurationResponseBytesField
    bytesValue
    >>= capNatural LengthRankingConfigurationResponseBytesField 65536
  depthValue <- requiredField
    LengthRankingConfigurationResponseLimitsObject
    LengthRankingConfigurationResponseNestingDepthField
    "nestingDepth"
    object
  depth <- intField LengthRankingConfigurationResponseNestingDepthField
    depthValue
    >>= capIntUpper LengthRankingConfigurationResponseNestingDepthField 64
  nodesValue <- requiredField
    LengthRankingConfigurationResponseLimitsObject
    LengthRankingConfigurationResponseNodesField
    "nodes"
    object
  nodes <- naturalField LengthRankingConfigurationResponseNodesField
    nodesValue
    >>= capNatural LengthRankingConfigurationResponseNodesField 4096
  tokenBytesValue <- requiredField
    LengthRankingConfigurationResponseLimitsObject
    LengthRankingConfigurationResponseTokenBytesField
    "tokenBytes"
    object
  tokenBytes <- naturalField LengthRankingConfigurationResponseTokenBytesField
    tokenBytesValue
    >>= capNatural LengthRankingConfigurationResponseTokenBytesField 4096
  integerBitsValue <- requiredField
    LengthRankingConfigurationResponseLimitsObject
    LengthRankingConfigurationResponseIntegerBitsField
    "integerBits"
    object
  integerBits <- intField LengthRankingConfigurationResponseIntegerBitsField
    integerBitsValue
    >>= capIntUpper LengthRankingConfigurationResponseIntegerBitsField 4096
  let source = LengthSMTLibResponseLimitSource
        { lengthSMTLibResponseLimitSourceBytes = bytes
        , lengthSMTLibResponseLimitSourceNestingDepth = depth
        , lengthSMTLibResponseLimitSourceNodes = nodes
        , lengthSMTLibResponseLimitSourceTokenBytes = tokenBytes
        , lengthSMTLibResponseLimitSourceIntegerBits = integerBits
        }
  either (Left . LengthRankingConfigurationResponseLimitsRejected) Right
    $ mkLengthSMTLibResponseLimits source

responseLimitFields :: [(Text, LengthRankingConfigurationFileField)]
responseLimitFields =
  [ ("bytes", LengthRankingConfigurationResponseBytesField)
  , ("nestingDepth", LengthRankingConfigurationResponseNestingDepthField)
  , ("nodes", LengthRankingConfigurationResponseNodesField)
  , ("tokenBytes", LengthRankingConfigurationResponseTokenBytesField)
  , ("integerBits", LengthRankingConfigurationResponseIntegerBitsField)
  ]

decodeExpectedDigest
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError (Maybe [Word8])
decodeExpectedDigest value = case value of
  BoundedJsonNull -> Right Nothing
  BoundedJsonString digest
    | observedTextScalars 64 digest == 64
    , Text.all isLowerHexDigit digest -> Just <$> decodeHexBytes
        (Text.unpack digest)
    | otherwise -> rejected
  _ -> Left $ LengthRankingConfigurationFieldTypeMismatch field
    LengthRankingConfigurationNullOrStringValue
 where
  field = LengthRankingConfigurationExpectedExecutableSha256Field
  rejected = Left $ LengthRankingConfigurationFieldValueRejected field

  isLowerHexDigit character =
    ('0' <= character && character <= '9')
      || ('a' <= character && character <= 'f')

  decodeHexBytes [] = Right []
  decodeHexBytes (high : low : remaining) =
    ((fromIntegral $ hexValue high * 16 + hexValue low) :)
      <$> decodeHexBytes remaining
  decodeHexBytes _ = rejected

  hexValue character
    | '0' <= character && character <= '9' = ord character - ord '0'
    | otherwise = ord character - ord 'a' + 10

decodeArtifactPolicy
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthSMTLibArtifactPolicy
decodeArtifactPolicy value = do
  policy <- stringField LengthRankingConfigurationArtifactPolicyField value
  case policy of
    "status-only" -> Right LengthSMTLibStatusOnly
    "input-values-after-satisfiable" ->
      Right LengthSMTLibInputValuesAfterSatisfiable
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationArtifactPolicyField

decodeEvaluation
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthEvaluationLimitSource
decodeEvaluation value = do
  object <- exactObject LengthRankingConfigurationEvaluationObject
    evaluationFields value
  assignmentsValue <- requiredField
    LengthRankingConfigurationEvaluationObject
    LengthRankingConfigurationAssignmentValueBitsField
    "assignmentValueBits"
    object
  assignments <- intField LengthRankingConfigurationAssignmentValueBitsField
    assignmentsValue
    >>= capIntUpper LengthRankingConfigurationAssignmentValueBitsField 4096
  intermediateValue <- requiredField
    LengthRankingConfigurationEvaluationObject
    LengthRankingConfigurationIntermediateValueBitsField
    "intermediateValueBits"
    object
  intermediate <- intField
    LengthRankingConfigurationIntermediateValueBitsField
    intermediateValue
    >>= capIntUpper LengthRankingConfigurationIntermediateValueBitsField 4096
  let source = LengthEvaluationLimitSource
        { lengthEvaluationLimitSourceAssignmentValueBits = assignments
        , lengthEvaluationLimitSourceIntermediateValueBits = intermediate
        }
  case mkLengthEvaluationLimits source of
    Left failure -> Left $ LengthRankingConfigurationEvaluationRejected failure
    Right _ -> Right source

evaluationFields :: [(Text, LengthRankingConfigurationFileField)]
evaluationFields =
  [ ( "assignmentValueBits"
    , LengthRankingConfigurationAssignmentValueBitsField
    )
  , ( "intermediateValueBits"
    , LengthRankingConfigurationIntermediateValueBitsField
    )
  ]

decodeContract
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeContract value = do
  object <- exactObject LengthRankingConfigurationContractObject
    contractFields value
  spineValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationSpineField
    "spine"
    object
  spine <- decodeSpine spineValue
  preconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPreconditionField
    "precondition"
    object
  (precondition, afterPrecondition) <- parseLengthFormula
    LengthRankingConfigurationPreconditionSyntax
    contractVariable
    1
    emptySyntaxUsage
    preconditionValue
  postconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPostconditionField
    "postcondition"
    object
  (postcondition, _) <- parseLengthFormula
    LengthRankingConfigurationPostconditionSyntax
    contractVariable
    1
    afterPrecondition
    postconditionValue
  providerLawsValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationProviderLawsField
    "providerLaws"
    object
  lawValues <- arrayField LengthRankingConfigurationProviderLawsField
    providerLawsValue
  boundedCollection LengthRankingConfigurationProviderLawsField
    maximumProviderLaws lawValues
  providerLaws <- decodeProviderLaws 0 emptySyntaxUsage lawValues
  pure LeanLengthContract
    { leanLengthContractSpine = spine
    , leanLengthContractSource = LengthContractSource
        { lengthContractPrecondition = precondition
        , lengthContractPostcondition = postcondition
        }
    , leanLengthContractProviderLaws = providerLaws
    }

contractFields :: [(Text, LengthRankingConfigurationFileField)]
contractFields =
  [ ("spine", LengthRankingConfigurationSpineField)
  , ("precondition", LengthRankingConfigurationPreconditionField)
  , ("postcondition", LengthRankingConfigurationPostconditionField)
  , ("providerLaws", LengthRankingConfigurationProviderLawsField)
  ]

decodeSpine
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthSpineIdentity
decodeSpine value = do
  object <- exactObject LengthRankingConfigurationSpineObject
    spineFields value
  familyValue <- requiredField
    LengthRankingConfigurationSpineObject
    LengthRankingConfigurationSpineFamilyField
    "family"
    object
  family <- boundedName LengthRankingConfigurationSpineFamilyField
    familyValue
  zeroValue <- requiredField
    LengthRankingConfigurationSpineObject
    LengthRankingConfigurationSpineZeroField
    "zero"
    object
  zero <- boundedName LengthRankingConfigurationSpineZeroField
    zeroValue
  stepValue <- requiredField
    LengthRankingConfigurationSpineObject
    LengthRankingConfigurationSpineStepField
    "step"
    object
  step <- boundedName LengthRankingConfigurationSpineStepField
    stepValue
  pure LeanLengthSpineIdentity
    { leanLengthSpineFamilyName = family
    , leanLengthSpineZeroConstructorName = zero
    , leanLengthSpineStepConstructorName = step
    }

spineFields :: [(Text, LengthRankingConfigurationFileField)]
spineFields =
  [ ("family", LengthRankingConfigurationSpineFamilyField)
  , ("zero", LengthRankingConfigurationSpineZeroField)
  , ("step", LengthRankingConfigurationSpineStepField)
  ]

decodeProviderLaws
  :: Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either LengthRankingConfigurationFileError [LeanLengthProviderLaw]
decodeProviderLaws _ _ [] = Right []
decodeProviderLaws index usage (value : remaining) = do
  let lawObject = LengthRankingConfigurationProviderLawObject index
  object <- exactObject lawObject
    (providerLawFields index) value
  nameValue <- requiredField
    lawObject
    (LengthRankingConfigurationProviderLawNameField index)
    "name"
    object
  name <- boundedName (LengthRankingConfigurationProviderLawNameField index)
    nameValue
  rolesValue <- requiredField
    lawObject
    (LengthRankingConfigurationProviderLawArgumentRolesField index)
    "argumentRoles"
    object
  roles <- decodeProviderRoles index rolesValue
  transferValue <- requiredField
    lawObject
    (LengthRankingConfigurationProviderLawTransferField index)
    "transfer"
    object
  (transfer, afterTransfer) <- parseLengthExpression
    (LengthRankingConfigurationProviderTransferSyntax index)
    (providerVariable $ fromIntegral $ length roles)
    1
    usage
    transferValue
  following <- decodeProviderLaws (index + 1) afterTransfer remaining
  pure $ LeanLengthProviderLaw
    { leanLengthProviderLawName = name
    , leanLengthProviderLawArgumentRoles = roles
    , leanLengthProviderLawTransfer = transfer
    } : following

providerLawFields
  :: Natural
  -> [(Text, LengthRankingConfigurationFileField)]
providerLawFields index =
  [ ("name", LengthRankingConfigurationProviderLawNameField index)
  , ( "argumentRoles"
    , LengthRankingConfigurationProviderLawArgumentRolesField index
    )
  , ("transfer", LengthRankingConfigurationProviderLawTransferField index)
  ]

decodeProviderRoles
  :: Natural
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      [LengthProviderArgumentRole]
decodeProviderRoles index value = do
  let field = LengthRankingConfigurationProviderLawArgumentRolesField index
  values <- arrayField field value
  boundedCollection field maximumProviderRoles values
  mapM (decodeRole field) values
 where
  decodeRole field roleValue = do
    role <- stringField field roleValue
    case role of
      "spine" -> Right LengthSpineArgument
      "unobserved" -> Right LengthUnobservedArgument
      _ -> Left $ LengthRankingConfigurationFieldValueRejected field

boundedCollection
  :: LengthRankingConfigurationFileField
  -> Natural
  -> [value]
  -> Either LengthRankingConfigurationFileError ()
boundedCollection field maximumValues values =
  let observed = observedListLength maximumValues values
  in if observed <= maximumValues
      then Right ()
      else Left $ LengthRankingConfigurationPolicyLimitExceeded
        field maximumValues (maximumValues + 1)

maximumProviderLaws, maximumProviderRoles :: Natural
maximumProviderLaws = 256
maximumProviderRoles = 16

boundedName
  :: LengthRankingConfigurationFileField
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError String
boundedName field value = do
  name <- stringField field value
  let utf8Bytes = observedTextUtf8Bytes maximumNameUtf8Bytes name
  if utf8Bytes > maximumNameUtf8Bytes
    then Left $ LengthRankingConfigurationTextLimitExceeded
      field LengthRankingConfigurationUtf8Bytes
      maximumNameUtf8Bytes (maximumNameUtf8Bytes + 1)
    else let scalars = observedTextScalars maximumNameScalars name
      in if scalars > maximumNameScalars
      then Left $ LengthRankingConfigurationTextLimitExceeded
        field LengthRankingConfigurationUnicodeScalars
        maximumNameScalars (maximumNameScalars + 1)
      else Right $ Text.unpack name

observedTextScalars :: Natural -> Text -> Natural
observedTextScalars maximumValue = go 0
 where
  go !observed remaining = case Text.uncons remaining of
    Nothing -> observed
    Just (_, following)
      | observed >= maximumValue -> maximumValue + 1
      | otherwise -> go (observed + 1) following

observedTextUtf8Bytes :: Natural -> Text -> Natural
observedTextUtf8Bytes maximumValue = go 0
 where
  go !observed remaining = case Text.uncons remaining of
    Nothing -> observed
    Just (character, following) ->
      let next = observed + utf8CharacterBytes character
      in if next > maximumValue
          then maximumValue + 1
          else go next following

utf8CharacterBytes :: Char -> Natural
utf8CharacterBytes character
  | codePoint <= 0x7f = 1
  | codePoint <= 0x7ff = 2
  | codePoint <= 0xffff = 3
  | otherwise = 4
 where
  codePoint = ord character

maximumNameScalars, maximumNameUtf8Bytes :: Natural
maximumNameScalars = 256
maximumNameUtf8Bytes = 1024

data SyntaxUsage = SyntaxUsage !Natural !Natural

emptySyntaxUsage :: SyntaxUsage
emptySyntaxUsage = SyntaxUsage 0 0

type VariableDecoder variable =
  Text
  -> [BoundedJsonValue]
  -> Either LengthRankingConfigurationSyntaxError (Maybe variable)

contractVariable :: VariableDecoder LengthContractVariable
contractVariable tag arguments = case tag of
  "input" -> do
    argument <- onlyArgument arguments
    index <- syntaxNatural argument
    if index <= maximumContractInputIndex
      then Right $ Just $ LengthInput index
      else Left $ LengthRankingConfigurationSyntaxLimitExceeded
        LengthRankingConfigurationInputIndex
        maximumContractInputIndex (maximumContractInputIndex + 1)
  "result" -> do
    noArguments arguments
    Right $ Just LengthResult
  _ -> Right Nothing

providerVariable
  :: Natural
  -> VariableDecoder LengthProviderVariable
providerVariable roleCount tag arguments = case tag of
  "argument" -> do
    argument <- onlyArgument arguments
    index <- syntaxNatural argument
    if index > maximumProviderArgumentIndex
      then Left $ LengthRankingConfigurationSyntaxLimitExceeded
        LengthRankingConfigurationProviderArgumentIndex
        maximumProviderArgumentIndex (maximumProviderArgumentIndex + 1)
      else if index >= roleCount
        then Left $ LengthRankingConfigurationSyntaxLimitExceeded
          LengthRankingConfigurationProviderArgumentRoleCount
          roleCount (min (roleCount + 1) (index + 1))
        else Right $ Just $ LengthProviderArgument index
  _ -> Right Nothing

maximumContractInputIndex, maximumProviderArgumentIndex :: Natural
maximumContractInputIndex = 7
maximumProviderArgumentIndex = 15

parseLengthExpression
  :: LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthExpression variable, SyntaxUsage)
parseLengthExpression phase decodeVariable depth usage value = do
  (tag, arguments) <- syntax phase $ tagged value
  afterNode <- enterSyntax phase depth usage
  variable <- syntax phase $ decodeVariable tag arguments
  case variable of
    Just retained -> Right (LengthVariable retained, afterNode)
    Nothing -> case tag of
      "literal" -> do
        argument <- syntax phase $ onlyArgument arguments
        literal <- boundedLiteral phase argument
        Right (LengthLiteral literal, afterNode)
      "sum" -> do
        argument <- syntax phase $ onlyArgument arguments
        terms <- syntax phase $ syntaxArray argument
        syntaxCollection phase LengthRankingConfigurationSumTerms
          maximumSyntaxCollection terms
        (parsed, afterTerms) <- parseExpressions phase decodeVariable
          (depth + 1) afterNode terms
        Right (LengthSum parsed, afterTerms)
      "scale" -> do
        (factorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        factor <- boundedLiteral phase factorValue
        (expression, afterExpression) <- parseLengthExpression
          phase decodeVariable (depth + 1) afterNode expressionValue
        Right (LengthScale factor expression, afterExpression)
      "monus" -> parseBinaryExpression arguments afterNode LengthMonus
      "minimum" -> parseBinaryExpression arguments afterNode LengthMinimum
      "maximum" -> parseBinaryExpression arguments afterNode LengthMaximum
      "if" -> do
        (conditionValue, trueValue, falseValue) <- syntax phase
          $ threeArguments arguments
        (condition, afterCondition) <- parseLengthFormula
          phase decodeVariable (depth + 1) afterNode conditionValue
        (trueBranch, afterTrue) <- parseLengthExpression
          phase decodeVariable (depth + 1) afterCondition trueValue
        (falseBranch, afterFalse) <- parseLengthExpression
          phase decodeVariable (depth + 1) afterTrue falseValue
        Right (LengthIf condition trueBranch falseBranch, afterFalse)
      _ -> syntax phase $ Left LengthRankingConfigurationUnknownTag
 where
  parseBinaryExpression arguments afterNode constructor = do
    (leftValue, rightValue) <- syntax phase $ twoArguments arguments
    (left, afterLeft) <- parseLengthExpression
      phase decodeVariable (depth + 1) afterNode leftValue
    (right, afterRight) <- parseLengthExpression
      phase decodeVariable (depth + 1) afterLeft rightValue
    Right (constructor left right, afterRight)

parseExpressions
  :: LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either
      LengthRankingConfigurationFileError
      ([LengthExpression variable], SyntaxUsage)
parseExpressions _ _ _ usage [] = Right ([], usage)
parseExpressions phase decodeVariable depth usage (value : remaining) = do
  (expression, afterExpression) <- parseLengthExpression
    phase decodeVariable depth usage value
  (following, afterFollowing) <- parseExpressions
    phase decodeVariable depth afterExpression remaining
  Right (expression : following, afterFollowing)

parseLengthFormula
  :: LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthFormula variable, SyntaxUsage)
parseLengthFormula phase decodeVariable depth usage value = do
  (tag, arguments) <- syntax phase $ tagged value
  afterNode <- enterSyntax phase depth usage
  case tag of
    "truth" -> do
      argument <- syntax phase $ onlyArgument arguments
      truth <- syntax phase $ syntaxBoolean argument
      afterClause <- consumeClause phase afterNode
      Right (LengthTruth truth, afterClause)
    "equal" -> parseComparison arguments afterNode LengthEqual
    "at-most" -> parseComparison arguments afterNode LengthAtMost
    "not" -> do
      argument <- syntax phase $ onlyArgument arguments
      (formula, afterFormula) <- parseLengthFormula
        phase decodeVariable (depth + 1) afterNode argument
      Right (LengthNot formula, afterFormula)
    "all" -> do
      argument <- syntax phase $ onlyArgument arguments
      formulas <- syntax phase $ syntaxArray argument
      syntaxCollection phase LengthRankingConfigurationAllClauses
        maximumSyntaxCollection formulas
      (parsed, afterFormulas) <- parseFormulas phase decodeVariable
        (depth + 1) afterNode formulas
      Right (LengthAll parsed, afterFormulas)
    _ -> syntax phase $ Left LengthRankingConfigurationUnknownTag
 where
  parseComparison arguments afterNode constructor = do
    (leftValue, rightValue) <- syntax phase $ twoArguments arguments
    afterClause <- consumeClause phase afterNode
    (left, afterLeft) <- parseLengthExpression
      phase decodeVariable (depth + 1) afterClause leftValue
    (right, afterRight) <- parseLengthExpression
      phase decodeVariable (depth + 1) afterLeft rightValue
    Right (constructor left right, afterRight)

parseFormulas
  :: LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either
      LengthRankingConfigurationFileError
      ([LengthFormula variable], SyntaxUsage)
parseFormulas _ _ _ usage [] = Right ([], usage)
parseFormulas phase decodeVariable depth usage (value : remaining) = do
  (formula, afterFormula) <- parseLengthFormula
    phase decodeVariable depth usage value
  (following, afterFollowing) <- parseFormulas
    phase decodeVariable depth afterFormula remaining
  Right (formula : following, afterFollowing)

enterSyntax
  :: LengthRankingConfigurationSyntaxPhase
  -> Natural
  -> SyntaxUsage
  -> Either LengthRankingConfigurationFileError SyntaxUsage
enterSyntax phase depth (SyntaxUsage nodes clauses)
  | depth > maximumSemanticDepth = syntaxLimit phase
      LengthRankingConfigurationSemanticDepth
      maximumSemanticDepth (maximumSemanticDepth + 1)
  | nodes >= maximumSyntaxNodes = syntaxLimit phase
      LengthRankingConfigurationSyntaxNodes
      maximumSyntaxNodes (maximumSyntaxNodes + 1)
  | otherwise = Right $ SyntaxUsage (nodes + 1) clauses

consumeClause
  :: LengthRankingConfigurationSyntaxPhase
  -> SyntaxUsage
  -> Either LengthRankingConfigurationFileError SyntaxUsage
consumeClause phase (SyntaxUsage nodes clauses)
  | clauses >= maximumFormulaClauses = syntaxLimit phase
      LengthRankingConfigurationFormulaClauses
      maximumFormulaClauses (maximumFormulaClauses + 1)
  | otherwise = Right $ SyntaxUsage nodes (clauses + 1)

syntaxCollection
  :: LengthRankingConfigurationSyntaxPhase
  -> LengthRankingConfigurationSyntaxLimit
  -> Natural
  -> [value]
  -> Either LengthRankingConfigurationFileError ()
syntaxCollection phase limit maximumValues values =
  let observed = observedListLength maximumValues values
  in if observed <= maximumValues
      then Right ()
      else syntaxLimit phase limit maximumValues (maximumValues + 1)

boundedLiteral
  :: LengthRankingConfigurationSyntaxPhase
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError Natural
boundedLiteral phase value = do
  literal <- syntax phase $ syntaxNatural value
  let bits = observedNaturalBits maximumLiteralBits literal
  if bits <= maximumLiteralBits
    then Right literal
    else syntaxLimit phase LengthRankingConfigurationLiteralBits
      maximumLiteralBits (maximumLiteralBits + 1)

observedNaturalBits :: Natural -> Natural -> Natural
observedNaturalBits maximumValue = go 0
 where
  go !bits 0 = bits
  go !bits value
    | bits >= maximumValue = maximumValue + 1
    | otherwise = go (bits + 1) $ value `quot` 2

maximumSemanticDepth, maximumSyntaxNodes, maximumFormulaClauses,
  maximumSyntaxCollection, maximumLiteralBits :: Natural
maximumSemanticDepth = 64
maximumSyntaxNodes = 1024
maximumFormulaClauses = 32
maximumSyntaxCollection = 64
maximumLiteralBits = 256

syntaxLimit
  :: LengthRankingConfigurationSyntaxPhase
  -> LengthRankingConfigurationSyntaxLimit
  -> Natural
  -> Natural
  -> Either LengthRankingConfigurationFileError value
syntaxLimit phase limit maximumValue observed = Left
  $ LengthRankingConfigurationSyntaxRejected phase
  $ LengthRankingConfigurationSyntaxLimitExceeded
      limit maximumValue observed

syntax
  :: LengthRankingConfigurationSyntaxPhase
  -> Either LengthRankingConfigurationSyntaxError value
  -> Either LengthRankingConfigurationFileError value
syntax phase = either
  (Left . LengthRankingConfigurationSyntaxRejected phase) Right

tagged
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationSyntaxError
      (Text, [BoundedJsonValue])
tagged value = case value of
  BoundedJsonArray (BoundedJsonString tag : arguments) ->
    Right (tag, arguments)
  BoundedJsonArray _ -> Left LengthRankingConfigurationExpectedTag
  _ -> Left LengthRankingConfigurationExpectedTaggedArray

noArguments
  :: [value]
  -> Either LengthRankingConfigurationSyntaxError ()
noArguments [] = Right ()
noArguments values = Left $ LengthRankingConfigurationTagArityMismatch
  0 $ observedListLength 0 values

onlyArgument
  :: [value]
  -> Either LengthRankingConfigurationSyntaxError value
onlyArgument [value] = Right value
onlyArgument values = Left $ LengthRankingConfigurationTagArityMismatch
  1 $ observedListLength 1 values

twoArguments
  :: [value]
  -> Either LengthRankingConfigurationSyntaxError (value, value)
twoArguments [first, second] = Right (first, second)
twoArguments values = Left $ LengthRankingConfigurationTagArityMismatch
  2 $ observedListLength 2 values

threeArguments
  :: [value]
  -> Either LengthRankingConfigurationSyntaxError (value, value, value)
threeArguments [first, second, third] = Right (first, second, third)
threeArguments values = Left $ LengthRankingConfigurationTagArityMismatch
  3 $ observedListLength 3 values

observedListLength :: Natural -> [value] -> Natural
observedListLength maximumValue = go 0
 where
  go !observed [] = observed
  go !observed (_ : remaining)
    | observed >= maximumValue = maximumValue + 1
    | otherwise = go (observed + 1) remaining

syntaxArray
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationSyntaxError [BoundedJsonValue]
syntaxArray value = case value of
  BoundedJsonArray values -> Right values
  _ -> Left LengthRankingConfigurationExpectedSyntaxArray

syntaxBoolean
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationSyntaxError Bool
syntaxBoolean value = case value of
  BoundedJsonBool boolean -> Right boolean
  _ -> Left LengthRankingConfigurationExpectedSyntaxBoolean

syntaxNatural
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationSyntaxError Natural
syntaxNatural value = case value of
  BoundedJsonInteger integer
    | integer >= 0 -> Right $ fromInteger integer
  _ -> Left LengthRankingConfigurationExpectedSyntaxNatural
