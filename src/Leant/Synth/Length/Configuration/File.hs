{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded file grammar for the current live Length-ranking policy.
--
-- The startup document is deliberately versionless.  Its required
-- @rankingDomain@ field selects either the scalar or canonical binary-product
-- contract grammar; every other field describes one current policy bundle.
-- Leant is experimental, so superseded startup shapes live in Git history
-- rather than production decoder branches.
--
-- Decoding performs no discovery, path normalization, environment lookup, or
-- IO.  A successful decode returns a deliberately disabled opaque value:
-- callers must separately choose whether an absent executable digest pin is
-- acceptable before they can obtain the validated policy and passive nominal
-- contract selection.
module Leant.Synth.Length.Configuration.File
  ( lengthRankingConfigurationFileFormat
  , lengthRankingConfigurationFileJsonLimits
  , LengthRankingConfigurationFileObject (..)
  , LengthRankingConfigurationFileField (..)
  , LengthRankingConfigurationFileValueType (..)
  , LengthRankingConfigurationFileTextMeasure (..)
  , LengthRankingConfigurationSyntaxPhase (..)
  , LengthRankingConfigurationSyntaxLimit (..)
  , LengthRankingConfigurationSyntaxError (..)
  , LengthRankingConfigurationFileError (..)
  , DisabledLengthAssessmentConfiguration
  , LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationActivationError (..)
  , decodeLengthAssessmentConfigurationFile
  , decodeLeanLengthContractValue
  , decodeLeanLengthSpinePairContractValue
  , activateLengthAssessmentConfiguration
  ) where

import Data.ByteString (ByteString)
import Data.Char (isDigit, ord)
import Data.List (find)
import qualified Data.Text as Text
import Data.Text (Text)
import Data.Word (Word8)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthBooleanFiniteUnionLimitError
  , LengthBooleanFiniteUnionLimitSource (..)
  , LengthBooleanFiniteUnionLimits
  , LengthContractSource (..)
  , LengthContractVariable (..)
  , LengthEvaluationLimitError
  , LengthEvaluationLimitSource (..)
  , LengthEvaluationLimits
  , LengthExpression (..)
  , LengthFormula (..)
  , LengthInputBoxLimitError
  , LengthInputBoxLimitSource (..)
  , LengthInputBoxLimits
  , LengthProviderArgumentRole (..)
  , LengthProviderVariable (..)
  , LengthSpinePairComponent (..)
  , LengthSpinePairContractSource (..)
  , LengthSpinePairContractVariable (..)
  , LengthTargetArgumentRole (..)
  , LengthSMTLibArtifactPolicy (..)
  , LengthSMTLibExecutionConfigError
  , LengthSMTLibExecutionConfig
  , LengthSMTLibExecutionConfigSource (..)
  , LengthSMTLibExecutionLimitSource (..)
  , LengthSMTLibExecutionLimits
  , LengthSMTLibExecutableDigestExpectation (..)
  , LengthSMTLibResponseLimitError
  , LengthSMTLibResponseLimitSource (..)
  , LengthSMTLibResponseLimits
  , LengthSMTLibLiveUsableWorkBudget
  , LengthSMTLibLiveUsableWorkBudgetError
  , LengthSMTLibLiveUsableWorkBudgetSource (..)
  , mkLengthEvaluationLimits
  , mkLengthBooleanFiniteUnionLimits
  , mkLengthInputBoxLimits
  , mkLengthSMTLibDescriptorBoundExecveCheckExecutableAccessExecutionConfig
  , mkLengthSMTLibExecutionLimits
  , mkLengthSMTLibResponseLimits
  , mkLengthSMTLibLiveUsableWorkBudget
  )

import Leant.Json.Bounded
  ( BoundedJsonError
  , BoundedJsonLimits (..)
  , BoundedJsonValue (..)
  , parseBoundedJson
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContract (..)
  , LeanLengthCandidateCasePolicy (..)
  , LeanLengthContractSelection (..)
  , LeanLengthProviderLaw (..)
  , LeanLengthSpineIdentity (..)
  , LeanLengthSpinePairContract (..)
  )
import Leant.Synth.Length.Configuration
  ( LengthRankingPolicy
  , enableLengthRankingApplicableDomainValidation
  , enableLengthRankingCounterexampleSimplification
  , enableLengthRankingDeferredLiveSessionOpening
  , enableLengthRankingNonVacuousApplicableDomainPreference
  , enableLengthRankingNonVacuousInputBoxPreference
  , enableLengthRankingOriginProbe
  , enableLengthRankingInputBoxValidation
  , enableLengthRankingScopedUsableWorkBudget
  , lengthRankingPolicyExecutableDigestExpectation
  , lengthRankingPolicyFromValidatedComponents
  )

-- | The exact @format@ string a startup document must carry.
lengthRankingConfigurationFileFormat :: Text
lengthRankingConfigurationFileFormat =
  "leant-live-length-ranking-configuration"

-- | Fixed admission policy for the startup document.  The array maximum is
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

-- | Which object of the startup grammar a structural refusal names; a
-- provider-law object carries its zero-based index in the @providerLaws@
-- array.
data LengthRankingConfigurationFileObject
  = LengthRankingConfigurationRootObject
  | LengthRankingConfigurationExecutionAdmissionObject
  | LengthRankingConfigurationExecutionObject
  | LengthRankingConfigurationResponseLimitsObject
  | LengthRankingConfigurationEvaluationObject
  | LengthRankingConfigurationInputBoxValidationObject
  | LengthRankingConfigurationApplicableDomainValidationObject
  | LengthRankingConfigurationCounterexampleSimplificationObject
  | LengthRankingConfigurationUsableWorkBudgetObject
  | LengthRankingConfigurationContractObject
  | LengthRankingConfigurationSpineObject
  | LengthRankingConfigurationProviderLawObject !Natural
  deriving (Eq, Ord, Show)

-- | Which field of the startup grammar a refusal names; provider-law fields
-- carry the zero-based index of their law.
data LengthRankingConfigurationFileField
  = LengthRankingConfigurationFormatField
  | LengthRankingConfigurationRankingDomainField
  | LengthRankingConfigurationExecutionAdmissionField
  | LengthRankingConfigurationExecutionField
  | LengthRankingConfigurationEvaluationField
  | LengthRankingConfigurationInputBoxValidationField
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
  | LengthRankingConfigurationInputBoxInclusiveMaximumsField
  | LengthRankingConfigurationInputBoxInclusiveMaximumField !Natural
  | LengthRankingConfigurationInputBoxMaximumAssignmentsField
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
  | LengthRankingConfigurationTargetArgumentRolesField
  | LengthRankingConfigurationCandidateCasePolicyField
  | LengthRankingConfigurationApplicableDomainValidationField
  | LengthRankingConfigurationApplicableDomainMaximumInputsField
  | LengthRankingConfigurationApplicableDomainMaximumGeneratedBranchesField
  | LengthRankingConfigurationApplicableDomainMaximumRulesPerBranchField
  | LengthRankingConfigurationApplicableDomainMaximumClosureInspectionsPerBranchField
  | LengthRankingConfigurationApplicableDomainMaximumRetainedBoxesField
  | LengthRankingConfigurationApplicableDomainMaximumAssignmentVisitsField
  | LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
  | LengthRankingConfigurationCounterexampleSimplificationField
  | LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
  | LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
  | LengthRankingConfigurationUsableWorkBudgetField
  | LengthRankingConfigurationUsableWorkBudgetMillisecondsField
  deriving (Eq, Ord, Show)

-- | The JSON value shape a field required when a type mismatch is reported.
data LengthRankingConfigurationFileValueType
  = LengthRankingConfigurationObjectValue
  | LengthRankingConfigurationArrayValue
  | LengthRankingConfigurationStringValue
  | LengthRankingConfigurationIntegerValue
  | LengthRankingConfigurationBooleanValue
  | LengthRankingConfigurationNullOrStringValue
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Which measure of a text field a text-limit refusal reports: Unicode
-- scalar values or UTF-8 bytes.
data LengthRankingConfigurationFileTextMeasure
  = LengthRankingConfigurationUnicodeScalars
  | LengthRankingConfigurationUtf8Bytes
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Which formula or expression a syntax refusal arose in: the contract's
-- precondition or postcondition, or the transfer expression of the
-- provider law with the given index.
data LengthRankingConfigurationSyntaxPhase
  = LengthRankingConfigurationPreconditionSyntax
  | LengthRankingConfigurationPostconditionSyntax
  | LengthRankingConfigurationProviderTransferSyntax !Natural
  deriving (Eq, Ord, Show)

-- | Which hard limit of the arithmetic grammar a syntax-limit refusal
-- names: nesting depth, total nodes, formula clauses, sum terms, @all@
-- clauses, literal width in bits, contract input index, provider argument
-- index, or provider argument index against the law's declared role count.
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

-- | Sanitized rejection of one tagged-array syntax node.  A tag-arity
-- mismatch carries the expected argument count and the observed count capped
-- at expected plus one; a limit
-- refusal carries the limit, its maximum, and the observed value capped at
-- maximum plus one.  No tag text is retained.
data LengthRankingConfigurationSyntaxError
  = LengthRankingConfigurationExpectedTaggedArray
  | LengthRankingConfigurationExpectedTag
  | LengthRankingConfigurationUnknownTag
  | LengthRankingConfigurationTagArityMismatch !Natural !Natural
  | LengthRankingConfigurationExpectedSyntaxArray
  | LengthRankingConfigurationExpectedSyntaxBoolean
  | LengthRankingConfigurationExpectedSyntaxNatural
  | LengthRankingConfigurationModuloDivisorZero
  | LengthRankingConfigurationQuotientDivisorZero
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
  | LengthRankingConfigurationInputBoxLimitsRejected
      !LengthInputBoxLimitError
  | LengthRankingConfigurationBooleanFiniteUnionLimitsRejected
      !LengthBooleanFiniteUnionLimitError
  | LengthRankingConfigurationUsableWorkBudgetRejected
      !LengthSMTLibLiveUsableWorkBudgetError
  | LengthRankingConfigurationSyntaxRejected
      !LengthRankingConfigurationSyntaxPhase
      !LengthRankingConfigurationSyntaxError
  deriving (Eq, Ord, Show)

data LengthRankingDomain
  = LengthRankingScalarDomain
  | LengthRankingBinaryProductDomain

-- | A fully decoded policy and nominal domain selection which still grants no
-- permission to execute the solver.  The policy is strict so validation is
-- complete at the decoder boundary; the passive contract selection remains
-- lazy across the explicit activation decision.
data DisabledLengthAssessmentConfiguration =
  DisabledLengthAssessmentConfiguration
    !LengthRankingPolicy
    LeanLengthContractSelection

-- | The caller's explicit decision on executables without a SHA-256 pin:
-- refuse them, or permit them.
data LengthRankingConfigurationActivationPolicy
  = RequirePinnedExecutable
  | PermitUnpinnedExecutable
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Activation refused because the policy demanded a pinned executable and
-- the decoded execution policy carries no digest expectation.
data LengthRankingConfigurationActivationError
  = LengthRankingConfigurationExecutablePinRequired
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Activate either supported startup domain under one explicit digest
-- decision.  Neither branch inspects the retained lazy contract selection or
-- performs IO.
activateLengthAssessmentConfiguration
  :: LengthRankingConfigurationActivationPolicy
  -> DisabledLengthAssessmentConfiguration
  -> Either
      LengthRankingConfigurationActivationError
      (LengthRankingPolicy, LeanLengthContractSelection)
activateLengthAssessmentConfiguration policy
    (DisabledLengthAssessmentConfiguration rankingPolicy selection) =
  case policy of
    RequirePinnedExecutable ->
      case lengthRankingPolicyExecutableDigestExpectation rankingPolicy of
        LengthSMTLibExecutableDigestExpectationAbsent ->
          Left LengthRankingConfigurationExecutablePinRequired
        LengthSMTLibExecutableDigestExpectationPresent ->
          Right (rankingPolicy, selection)
    PermitUnpinnedExecutable -> Right (rankingPolicy, selection)

-- | Decode one complete startup document without IO: bounded JSON, then
-- @format@, then @rankingDomain@, then the exact root field set, then each
-- policy section in root order (execution admission, execution,
-- evaluation, input-box validation, applicable-domain validation,
-- counterexample simplification, usable-work budget), then the contract in
-- the selected domain's grammar.  The result enables every optional ranking
-- policy the sections describe but grants no permission to run the solver
-- until 'activateLengthAssessmentConfiguration'.
decodeLengthAssessmentConfigurationFile
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFile bytes = do
  document <- either (Left . LengthRankingConfigurationJsonRejected) Right
    $ parseBoundedJson lengthRankingConfigurationFileJsonLimits bytes
  root <- objectFields LengthRankingConfigurationRootObject document
  formatValue <- rootField LengthRankingConfigurationFormatField "format" root
  format <- stringField LengthRankingConfigurationFormatField formatValue
  if format == lengthRankingConfigurationFileFormat
    then pure ()
    else Left LengthRankingConfigurationUnsupportedFormat
  domainValue <- rootField
    LengthRankingConfigurationRankingDomainField "rankingDomain" root
  domainText <- stringField
    LengthRankingConfigurationRankingDomainField domainValue
  domain <- case domainText of
    "scalar" -> Right LengthRankingScalarDomain
    "binary-product" -> Right LengthRankingBinaryProductDomain
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationRankingDomainField
  exactFields LengthRankingConfigurationRootObject rootFields root

  executionAdmissionValue <- rootField
    LengthRankingConfigurationExecutionAdmissionField
    "executionAdmission" root
  executionLimits <- decodeExecutionAdmission executionAdmissionValue
  executionValue <- rootField
    LengthRankingConfigurationExecutionField "execution" root
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- rootField
    LengthRankingConfigurationEvaluationField "evaluation" root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- rootField
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation" root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  applicableDomainValue <- rootField
    LengthRankingConfigurationApplicableDomainValidationField
    "applicableDomainValidation" root
  (applicableDomainInputBoxLimits, booleanFiniteUnionLimits) <-
    decodeApplicableDomainValidation applicableDomainValue
  simplificationValue <- rootField
    LengthRankingConfigurationCounterexampleSimplificationField
    "counterexampleSimplification" root
  simplificationLimits <-
    decodeCounterexampleSimplification simplificationValue
  budgetValue <- rootField
    LengthRankingConfigurationUsableWorkBudgetField
    "usableWorkBudget" root
  budget <- decodeUsableWorkBudget budgetValue
  contractValue <- rootField
    LengthRankingConfigurationContractField "contract" root
  selection <- case domain of
    LengthRankingScalarDomain ->
      LeanLengthScalarContractSelection
        <$> decodeLeanLengthContractValue contractValue
    LengthRankingBinaryProductDomain ->
      LeanLengthSpinePairContractSelection
        <$> decodeLeanLengthSpinePairContractValue contractValue

  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      originProbePolicy = enableLengthRankingOriginProbe inputBoxPolicy
      inputBoxPreferencePolicy =
        enableLengthRankingNonVacuousInputBoxPreference originProbePolicy
      applicableDomainPolicy =
        enableLengthRankingApplicableDomainValidation
          applicableDomainInputBoxLimits booleanFiniteUnionLimits
          inputBoxPreferencePolicy
      applicableDomainPreferencePolicy =
        enableLengthRankingNonVacuousApplicableDomainPreference
          applicableDomainPolicy
      simplificationPolicy = enableLengthRankingCounterexampleSimplification
        simplificationLimits applicableDomainPreferencePolicy
      deferredPolicy =
        enableLengthRankingDeferredLiveSessionOpening simplificationPolicy
      policy = enableLengthRankingScopedUsableWorkBudget
        budget deferredPolicy
  pure $ DisabledLengthAssessmentConfiguration policy selection

rootFields :: [(Text, LengthRankingConfigurationFileField)]
rootFields =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("rankingDomain", LengthRankingConfigurationRankingDomainField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ( "applicableDomainValidation"
    , LengthRankingConfigurationApplicableDomainValidationField
    )
  , ( "counterexampleSimplification"
    , LengthRankingConfigurationCounterexampleSimplificationField
    )
  , ( "usableWorkBudget"
    , LengthRankingConfigurationUsableWorkBudgetField
    )
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

-- | 'requiredField' at the configuration root, which is where the great
-- majority of required reads happen.
rootField
  :: LengthRankingConfigurationFileField
  -> Text
  -> ObjectFields
  -> Either LengthRankingConfigurationFileError BoundedJsonValue
rootField = requiredField LengthRankingConfigurationRootObject

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
      LengthSMTLibExecutionConfig
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
  case
      mkLengthSMTLibDescriptorBoundExecveCheckExecutableAccessExecutionConfig
        limits source of
    Left failure -> Left $ LengthRankingConfigurationExecutionRejected failure
    Right validated -> Right validated

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

-- The sole current execution shape selects descriptor-bound execve-check
-- executable-access admission in Djex without a redundant strategy field.
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
    isDigit character || ('a' <= character && character <= 'f')

  decodeHexBytes [] = Right []
  decodeHexBytes (high : low : remaining) =
    ((fromIntegral $ hexValue high * 16 + hexValue low) :)
      <$> decodeHexBytes remaining
  decodeHexBytes _ = rejected

  hexValue character
    | isDigit character = ord character - ord '0'
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
      LengthEvaluationLimits
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
    Right validated -> Right validated

evaluationFields :: [(Text, LengthRankingConfigurationFileField)]
evaluationFields =
  [ ( "assignmentValueBits"
    , LengthRankingConfigurationAssignmentValueBitsField
    )
  , ( "intermediateValueBits"
    , LengthRankingConfigurationIntermediateValueBitsField
    )
  ]

-- | Decode the independently bounded inputs, recursive branch closure, and
-- finite-union enumeration limits for the sole current applicable-domain
-- validator.  The policy strategy is fixed by this decoder rather than
-- repeated as a one-value choice in the document.
decodeApplicableDomainValidation
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthInputBoxLimits, LengthBooleanFiniteUnionLimits)
decodeApplicableDomainValidation value = do
  object <- exactObject
    LengthRankingConfigurationApplicableDomainValidationObject
    booleanFiniteUnionApplicableDomainValidationFields value
  maximumInputsValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumInputsField
    "maximumInputs"
    object
  maximumInputs <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumInputsField
    maximumInputsValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumInputsField
      maximumInputBoxInputs
  maximumGeneratedBranchesValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumGeneratedBranchesField
    "maximumGeneratedBranches"
    object
  maximumGeneratedBranches <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumGeneratedBranchesField
    maximumGeneratedBranchesValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumGeneratedBranchesField
      maximumBooleanFiniteUnionGeneratedBranches
  maximumRulesPerBranchValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumRulesPerBranchField
    "maximumRulesPerBranch"
    object
  maximumRulesPerBranch <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumRulesPerBranchField
    maximumRulesPerBranchValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumRulesPerBranchField
      maximumBooleanFiniteUnionRulesPerBranch
  maximumClosureInspectionsPerBranchValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumClosureInspectionsPerBranchField
    "maximumClosureInspectionsPerBranch"
    object
  maximumClosureInspectionsPerBranch <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumClosureInspectionsPerBranchField
    maximumClosureInspectionsPerBranchValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumClosureInspectionsPerBranchField
      maximumBooleanFiniteUnionClosureInspectionsPerBranch
  maximumRetainedBoxesValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumRetainedBoxesField
    "maximumRetainedBoxes"
    object
  maximumRetainedBoxes <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumRetainedBoxesField
    maximumRetainedBoxesValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumRetainedBoxesField
      maximumBooleanFiniteUnionRetainedBoxes
  maximumAssignmentVisitsValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumAssignmentVisitsField
    "maximumAssignmentVisits"
    object
  maximumAssignmentVisits <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumAssignmentVisitsField
    maximumAssignmentVisitsValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumAssignmentVisitsField
      maximumBooleanFiniteUnionAssignmentVisits
  maximumAssignmentsValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
    "maximumAssignments"
    object
  maximumAssignments <- naturalField
    LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
    maximumAssignmentsValue
    >>= capNatural
      LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
      maximumInputBoxAssignments
  inputBoxLimits <- checkedInputBoxLimits maximumInputs maximumAssignments
  booleanFiniteUnionLimits <- checkedBooleanFiniteUnionLimits
    maximumGeneratedBranches
    maximumRulesPerBranch
    maximumClosureInspectionsPerBranch
    maximumRetainedBoxes
    maximumAssignmentVisits
  pure (inputBoxLimits, booleanFiniteUnionLimits)

booleanFiniteUnionApplicableDomainValidationFields
  :: [(Text, LengthRankingConfigurationFileField)]
booleanFiniteUnionApplicableDomainValidationFields =
  [ ( "maximumInputs"
    , LengthRankingConfigurationApplicableDomainMaximumInputsField
    )
  , ( "maximumGeneratedBranches"
    , LengthRankingConfigurationApplicableDomainMaximumGeneratedBranchesField
    )
  , ( "maximumRulesPerBranch"
    , LengthRankingConfigurationApplicableDomainMaximumRulesPerBranchField
    )
  , ( "maximumClosureInspectionsPerBranch"
    , LengthRankingConfigurationApplicableDomainMaximumClosureInspectionsPerBranchField
    )
  , ( "maximumRetainedBoxes"
    , LengthRankingConfigurationApplicableDomainMaximumRetainedBoxesField
    )
  , ( "maximumAssignmentVisits"
    , LengthRankingConfigurationApplicableDomainMaximumAssignmentVisitsField
    )
  , ( "maximumAssignments"
    , LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
    )
  ]

-- | Decode a second, independent bounded authority for strict
-- componentwise-lexicographic counterexample simplification.
decodeCounterexampleSimplification
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LengthInputBoxLimits
decodeCounterexampleSimplification value = do
  object <- exactObject
    LengthRankingConfigurationCounterexampleSimplificationObject
    counterexampleSimplificationFields value
  maximumInputsValue <- requiredField
    LengthRankingConfigurationCounterexampleSimplificationObject
    LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
    "maximumInputs"
    object
  maximumInputs <- naturalField
    LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
    maximumInputsValue
    >>= capNatural
      LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
      maximumInputBoxInputs
  maximumAssignmentsValue <- requiredField
    LengthRankingConfigurationCounterexampleSimplificationObject
    LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
    "maximumAssignments"
    object
  maximumAssignments <- naturalField
    LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
    maximumAssignmentsValue
    >>= capNatural
      LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
      maximumInputBoxAssignments
  checkedInputBoxLimits maximumInputs maximumAssignments

counterexampleSimplificationFields
  :: [(Text, LengthRankingConfigurationFileField)]
counterexampleSimplificationFields =
  [ ( "maximumInputs"
    , LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
    )
  , ( "maximumAssignments"
    , LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
    )
  ]

checkedInputBoxLimits
  :: Natural
  -> Natural
  -> Either LengthRankingConfigurationFileError LengthInputBoxLimits
checkedInputBoxLimits maximumInputs maximumAssignments =
  case mkLengthInputBoxLimits LengthInputBoxLimitSource
      { lengthInputBoxLimitSourceMaximumInputs = fromIntegral maximumInputs
      , lengthInputBoxLimitSourceMaximumAssignments = maximumAssignments
      } of
    Left failure -> Left
      $ LengthRankingConfigurationInputBoxLimitsRejected failure
    Right validated -> Right validated

checkedBooleanFiniteUnionLimits
  :: Natural
  -> Natural
  -> Natural
  -> Natural
  -> Natural
  -> Either
      LengthRankingConfigurationFileError
      LengthBooleanFiniteUnionLimits
checkedBooleanFiniteUnionLimits maximumGeneratedBranches maximumRulesPerBranch
    maximumClosureInspectionsPerBranch maximumRetainedBoxes
    maximumAssignmentVisits =
  case mkLengthBooleanFiniteUnionLimits LengthBooleanFiniteUnionLimitSource
      { lengthBooleanFiniteUnionLimitSourceMaximumGeneratedBranches =
          fromIntegral maximumGeneratedBranches
      , lengthBooleanFiniteUnionLimitSourceMaximumRulesPerBranch =
          fromIntegral maximumRulesPerBranch
      , lengthBooleanFiniteUnionLimitSourceMaximumClosureInspectionsPerBranch =
          fromIntegral maximumClosureInspectionsPerBranch
      , lengthBooleanFiniteUnionLimitSourceMaximumRetainedBoxes =
          fromIntegral maximumRetainedBoxes
      , lengthBooleanFiniteUnionLimitSourceMaximumAssignmentVisits =
          fromIntegral maximumAssignmentVisits
      } of
    Left failure -> Left
      $ LengthRankingConfigurationBooleanFiniteUnionLimitsRejected failure
    Right validated -> Right validated

decodeUsableWorkBudget
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthSMTLibLiveUsableWorkBudget
decodeUsableWorkBudget value = do
  object <- exactObject LengthRankingConfigurationUsableWorkBudgetObject
    usableWorkBudgetFields value
  millisecondsValue <- requiredField
    LengthRankingConfigurationUsableWorkBudgetObject
    LengthRankingConfigurationUsableWorkBudgetMillisecondsField
    "milliseconds"
    object
  milliseconds <- intField
    LengthRankingConfigurationUsableWorkBudgetMillisecondsField
    millisecondsValue
    >>= capIntUpper
      LengthRankingConfigurationUsableWorkBudgetMillisecondsField 65000
  case mkLengthSMTLibLiveUsableWorkBudget
      LengthSMTLibLiveUsableWorkBudgetSource
        { lengthSMTLibLiveUsableWorkBudgetSourceMilliseconds = milliseconds } of
    Left failure -> Left
      $ LengthRankingConfigurationUsableWorkBudgetRejected failure
    Right validated -> Right validated

-- The sole current budget shape selects scoped, checkpointed shared usable
-- work ownership through the policy builder above.
usableWorkBudgetFields
  :: [(Text, LengthRankingConfigurationFileField)]
usableWorkBudgetFields =
  [ ( "milliseconds"
    , LengthRankingConfigurationUsableWorkBudgetMillisecondsField
    )
  ]

-- | Decode the current source-ordered inclusive input box.  Width is
-- bounded before any element is decoded, element values are then decoded
-- left-to-right, and the assignment cap is decoded last.  The vector's exact
-- finite width supplies Djex's independent maximum-input admission limit, so
-- the JSON grammar has no redundant width field which could disagree with the
-- retained box.
decodeInputBoxValidation
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthInputBoxLimits, [Natural])
decodeInputBoxValidation value = do
  object <- exactObject LengthRankingConfigurationInputBoxValidationObject
    inputBoxValidationFields value
  maximumsValue <- requiredField
    LengthRankingConfigurationInputBoxValidationObject
    LengthRankingConfigurationInputBoxInclusiveMaximumsField
    "inclusiveInputMaximums"
    object
  rawMaximums <- arrayField
    LengthRankingConfigurationInputBoxInclusiveMaximumsField maximumsValue
  let observedMaximums = observedListLength
        maximumInputBoxInputs rawMaximums
  if observedMaximums <= maximumInputBoxInputs
    then pure ()
    else Left $ LengthRankingConfigurationPolicyLimitExceeded
      LengthRankingConfigurationInputBoxInclusiveMaximumsField
      maximumInputBoxInputs (maximumInputBoxInputs + 1)
  inclusiveMaximums <- decodeMaximums 0 rawMaximums
  assignmentsValue <- requiredField
    LengthRankingConfigurationInputBoxValidationObject
    LengthRankingConfigurationInputBoxMaximumAssignmentsField
    "maximumAssignments"
    object
  maximumAssignments <- naturalField
    LengthRankingConfigurationInputBoxMaximumAssignmentsField
    assignmentsValue
    >>= capNatural
      LengthRankingConfigurationInputBoxMaximumAssignmentsField
      maximumInputBoxAssignments
  let source = LengthInputBoxLimitSource
        { lengthInputBoxLimitSourceMaximumInputs =
            fromIntegral observedMaximums
        , lengthInputBoxLimitSourceMaximumAssignments = maximumAssignments
        }
  limits <- case mkLengthInputBoxLimits source of
    Left failure -> Left
      $ LengthRankingConfigurationInputBoxLimitsRejected failure
    Right validated -> Right validated
  pure (limits, inclusiveMaximums)
 where
  decodeMaximums _ [] = Right []
  decodeMaximums index (rawMaximum : remaining) = do
    maximumValue <- naturalField
      (LengthRankingConfigurationInputBoxInclusiveMaximumField index)
      rawMaximum
    following <- decodeMaximums (index + 1) remaining
    pure $ maximumValue : following

inputBoxValidationFields
  :: [(Text, LengthRankingConfigurationFileField)]
inputBoxValidationFields =
  [ ( "inclusiveInputMaximums"
    , LengthRankingConfigurationInputBoxInclusiveMaximumsField
    )
  , ( "maximumAssignments"
    , LengthRankingConfigurationInputBoxMaximumAssignmentsField
    )
  ]

maximumInputBoxInputs, maximumInputBoxAssignments :: Natural
maximumInputBoxInputs = 8
maximumInputBoxAssignments = 65536

maximumBooleanFiniteUnionGeneratedBranches,
  maximumBooleanFiniteUnionRulesPerBranch,
  maximumBooleanFiniteUnionClosureInspectionsPerBranch,
  maximumBooleanFiniteUnionRetainedBoxes,
  maximumBooleanFiniteUnionAssignmentVisits :: Natural
maximumBooleanFiniteUnionGeneratedBranches = 256
maximumBooleanFiniteUnionRulesPerBranch = 64
maximumBooleanFiniteUnionClosureInspectionsPerBranch = 4096
maximumBooleanFiniteUnionRetainedBoxes = 256
maximumBooleanFiniteUnionAssignmentVisits = 262144

-- | Decode the current nominal contract grammar shared by startup and
-- contract-only files, once for both domains.  Target roles and case policy
-- are explicit, and the complete current arithmetic grammar and hard limits
-- are always active.  The scalar and binary-product grammars are the same
-- object with the same fields, precedence, and limits; they differ only in
-- the contract variable vocabulary of the two formulas and in the nominal
-- record assembled from the decoded parts, so both are supplied here.
decodeContractValueWith
  :: VariableDecoder variable
  -> (LeanLengthSpineIdentity
      -> [LengthTargetArgumentRole]
      -> LeanLengthCandidateCasePolicy
      -> LengthFormula variable
      -> LengthFormula variable
      -> [LeanLengthProviderLaw]
      -> contract)
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError contract
decodeContractValueWith decodeVariable assemble value = do
  object <- exactObject LengthRankingConfigurationContractObject
    contractFields value
  spineValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationSpineField
    "spine"
    object
  spine <- decodeSpine spineValue
  rolesValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationTargetArgumentRolesField
    "targetArgumentRoles"
    object
  targetRoles <- decodeTargetRoles rolesValue
  policyValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationCandidateCasePolicyField
    "candidateCasePolicy"
    object
  casePolicy <- decodeCandidateCasePolicy policyValue
  preconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPreconditionField
    "precondition"
    object
  (precondition, afterPrecondition) <- parseLengthFormula
    LengthRankingConfigurationPreconditionSyntax
    decodeVariable
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
    decodeVariable
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
  pure $ assemble spine targetRoles casePolicy precondition postcondition
    providerLaws

-- | The current nominal scalar contract grammar.
decodeLeanLengthContractValue
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValue = decodeContractValueWith contractVariable
  $ \spine targetRoles casePolicy precondition postcondition providerLaws ->
    LeanLengthContract
      { leanLengthContractSpine = spine
      , leanLengthContractTargetArgumentRoles = targetRoles
      , leanLengthContractCandidateCasePolicy = casePolicy
      , leanLengthContractSource = LengthContractSource
          { lengthContractPrecondition = precondition
          , lengthContractPostcondition = postcondition
          }
      , leanLengthContractProviderLaws = providerLaws
      }

-- | The current nominal binary-product contract grammar.  The enclosing
-- @rankingDomain@ is the sole domain discriminator; the nested grammar
-- retains a distinct variable and passive source type without a redundant
-- result-shape field.
decodeLeanLengthSpinePairContractValue
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthSpinePairContract
decodeLeanLengthSpinePairContractValue =
  decodeContractValueWith spinePairContractVariable
    $ \spine targetRoles casePolicy precondition postcondition providerLaws ->
      LeanLengthSpinePairContract
        { leanLengthSpinePairContractSpine = spine
        , leanLengthSpinePairContractTargetArgumentRoles = targetRoles
        , leanLengthSpinePairContractCandidateCasePolicy = casePolicy
        , leanLengthSpinePairContractSource = LengthSpinePairContractSource
            { lengthSpinePairContractPrecondition = precondition
            , lengthSpinePairContractPostcondition = postcondition
            }
        , leanLengthSpinePairContractProviderLaws = providerLaws
        }

contractFields :: [(Text, LengthRankingConfigurationFileField)]
contractFields =
  [ ("spine", LengthRankingConfigurationSpineField)
  , ( "targetArgumentRoles"
    , LengthRankingConfigurationTargetArgumentRolesField
    )
  , ( "candidateCasePolicy"
    , LengthRankingConfigurationCandidateCasePolicyField
    )
  , ("precondition", LengthRankingConfigurationPreconditionField)
  , ("postcondition", LengthRankingConfigurationPostconditionField)
  , ("providerLaws", LengthRankingConfigurationProviderLawsField)
  ]

decodeCandidateCasePolicy
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LeanLengthCandidateCasePolicy
decodeCandidateCasePolicy value = do
  let field = LengthRankingConfigurationCandidateCasePolicyField
  policy <- stringField field value
  case policy of
    "exact-spine-zero-step-v1" -> Right LeanLengthExactSpineZeroStepV1
    "cases-rejected" -> Right LeanLengthCasesRejected
    _ -> Left $ LengthRankingConfigurationFieldValueRejected field

decodeTargetRoles
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      [LengthTargetArgumentRole]
decodeTargetRoles value = do
  let field = LengthRankingConfigurationTargetArgumentRolesField
  values <- arrayField field value
  boundedCollection field maximumTargetRoles values
  mapM (decodeRole field) values
 where
  decodeRole field roleValue = do
    role <- stringField field roleValue
    case role of
      "observed-spine" -> Right LengthObservedSpine
      "unobserved-target" -> Right LengthUnobservedTarget
      _ -> Left $ LengthRankingConfigurationFieldValueRejected field

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

maximumProviderLaws, maximumProviderRoles, maximumTargetRoles :: Natural
maximumProviderLaws = 256
maximumProviderRoles = 16
maximumTargetRoles = 8

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

spinePairContractVariable
  :: VariableDecoder LengthSpinePairContractVariable
spinePairContractVariable tag arguments = case tag of
  "input" -> do
    argument <- onlyArgument arguments
    index <- syntaxNatural argument
    if index <= maximumContractInputIndex
      then Right $ Just $ LengthSpinePairInput index
      else Left $ LengthRankingConfigurationSyntaxLimitExceeded
        LengthRankingConfigurationInputIndex
        maximumContractInputIndex (maximumContractInputIndex + 1)
  "result" -> do
    argument <- onlyArgument arguments
    component <- case argument of
      BoundedJsonString "first" -> Right LengthSpinePairFirst
      BoundedJsonString "second" -> Right LengthSpinePairSecond
      BoundedJsonString _ -> Left LengthRankingConfigurationUnknownTag
      _ -> Left LengthRankingConfigurationExpectedTag
    Right $ Just $ LengthSpinePairResult component
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
        (parsed, afterTerms) <- parseSequence
          (parseLengthExpression phase decodeVariable $ depth + 1)
          afterNode terms
        Right (LengthSum parsed, afterTerms)
      "scale" -> do
        (factorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        factor <- boundedLiteral phase factorValue
        (expression, afterExpression) <- parseLengthExpression
          phase decodeVariable (depth + 1) afterNode expressionValue
        Right (LengthScale factor expression, afterExpression)
      "modulo" -> do
        (divisorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        divisor <- boundedLiteral phase divisorValue
        if divisor == 0
          then syntax phase $ Left LengthRankingConfigurationModuloDivisorZero
          else do
            (expression, afterExpression) <- parseLengthExpression
              phase decodeVariable (depth + 1) afterNode expressionValue
            Right (LengthModulo divisor expression, afterExpression)
      "quotient" -> do
        (divisorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        divisor <- boundedLiteral phase divisorValue
        if divisor == 0
          then syntax phase $ Left LengthRankingConfigurationQuotientDivisorZero
          else do
            (expression, afterExpression) <- parseLengthExpression
              phase decodeVariable (depth + 1) afterNode expressionValue
            Right (LengthQuotient divisor expression, afterExpression)
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

-- | Parse one bounded sequence of sibling nodes with the given node parser,
-- threading the syntax usage left to right and stopping at the first
-- rejection.  Sum terms and @all@ clauses both go through here.
parseSequence
  :: (SyntaxUsage
      -> BoundedJsonValue
      -> Either LengthRankingConfigurationFileError (node, SyntaxUsage))
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either LengthRankingConfigurationFileError ([node], SyntaxUsage)
parseSequence _ usage [] = Right ([], usage)
parseSequence parseNode usage (value : remaining) = do
  (node, afterNode) <- parseNode usage value
  (following, afterFollowing) <- parseSequence parseNode afterNode remaining
  Right (node : following, afterFollowing)

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
      (parsed, afterFormulas) <- parseSequence
        (parseLengthFormula phase decodeVariable $ depth + 1)
        afterNode formulas
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
