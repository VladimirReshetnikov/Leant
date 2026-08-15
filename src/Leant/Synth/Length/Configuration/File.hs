{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded versioned file grammar for explicit live Length ranking
-- policy.
--
-- Version 1 remains the exact compatibility grammar.  Version 2 adds one
-- required, explicit finite input-box validation policy.  Version 3 retains
-- that exact box and additionally requires a closed query-owned origin-probe
-- selection.  Version 4 is the nominal binary-product sibling.  Generalized-
-- only versions 5 and 6 add a required non-vacuous bounded-positive ordering
-- grant for the scalar and product domains respectively.  Generalized-only
-- versions 7 and 8 add positive-affine applicable-domain validation, its
-- independent ordering grant, bounded counterexample simplification, and
-- deferred live-session opening.  Versions 9 and 10 retain those exact scalar
-- and product policies and add one required shared usable-work budget.
-- Versions 11 and 12 return to the exact version-7/version-8 root shape while
-- selecting relational positive-affine applicable-domain validation.  Older
-- decoders and grammars remain literal.
-- Decoding performs no discovery, path normalization, environment lookup, or
-- IO.  Every field is required.  A successful decode returns a deliberately
-- disabled opaque value: callers
-- must separately choose whether an absent executable digest pin is
-- acceptable before they can obtain the validated policy and this file's
-- fixed compatibility contract.
module Leant.Synth.Length.Configuration.File
  ( lengthRankingConfigurationFileFormat
  , lengthRankingConfigurationFileVersion
  , lengthRankingConfigurationFileInputBoxVersion
  , lengthRankingConfigurationFileOriginProbeVersion
  , lengthRankingConfigurationFileSpinePairVersion
  , lengthRankingConfigurationFilePositiveOrderingVersion
  , lengthRankingConfigurationFileSpinePairPositiveOrderingVersion
  , lengthRankingConfigurationFilePositiveAffineVersion
  , lengthRankingConfigurationFileSpinePairPositiveAffineVersion
  , lengthRankingConfigurationFileUsableWorkBudgetVersion
  , lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion
  , lengthRankingConfigurationFileRelationalPositiveAffineVersion
  , lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion
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
  , DisabledLengthAssessmentConfiguration
  , LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationActivationError (..)
  , decodeLengthRankingConfigurationFile
  , decodeLengthAssessmentConfigurationFile
  , decodeLeanLengthContractValue
  , decodeLeanLengthContractValueV2
  , decodeLeanLengthContractValueV3
  , decodeLeanLengthContractValueV4
  , decodeLeanLengthContractValueV5
  , decodeLeanLengthSpinePairContractValueV5
  , disableLengthRankingConfiguration
  , activateLengthRankingConfiguration
  , activateLengthAssessmentConfiguration
  ) where

import Data.ByteString (ByteString)
import Data.Char (ord)
import Data.List (find)
import qualified Data.Text as Text
import Data.Text (Text)
import Data.Word (Word8)
import Numeric.Natural (Natural)

import Language.Haskell.Djex
  ( LengthContractSource (..)
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
  , mkLengthInputBoxLimits
  , mkLengthSMTLibExecutionConfig
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
  , enableLengthRankingCounterexampleSimplification
  , enableLengthRankingDeferredLiveSessionOpening
  , enableLengthRankingNonVacuousApplicableDomainPreference
  , enableLengthRankingNonVacuousInputBoxPreference
  , enableLengthRankingOriginProbe
  , enableLengthRankingInputBoxValidation
  , enableLengthRankingPositiveAffineApplicableDomainValidation
  , enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
  , enableLengthRankingUsableWorkBudget
  , lengthRankingPolicyExecutableDigestExpectation
  , lengthRankingPolicyFromValidatedComponents
  )

lengthRankingConfigurationFileFormat :: Text
lengthRankingConfigurationFileFormat =
  "leant-live-length-ranking-configuration"

lengthRankingConfigurationFileVersion :: Natural
lengthRankingConfigurationFileVersion = 1

-- | Opt-in configuration grammar which adds exact finite input-box policy.
-- The established version-1 constant above deliberately remains unchanged.
lengthRankingConfigurationFileInputBoxVersion :: Natural
lengthRankingConfigurationFileInputBoxVersion = 2

-- | Opt-in grammar which retains version 2's exact finite box and adds one
-- explicit query-owned origin probe before live execution.
lengthRankingConfigurationFileOriginProbeVersion :: Natural
lengthRankingConfigurationFileOriginProbeVersion = 3

-- | Additive startup grammar for canonical binary-product finite-spine
-- results.  Versions 1--3 retain their literal scalar-only decoder.
lengthRankingConfigurationFileSpinePairVersion :: Natural
lengthRankingConfigurationFileSpinePairVersion = 4

-- | Additive scalar startup grammar which retains the complete v3
-- orchestration, selects non-vacuous finite-box evidence preference, and uses
-- the already established scalar contract-v5 grammar.
lengthRankingConfigurationFilePositiveOrderingVersion :: Natural
lengthRankingConfigurationFilePositiveOrderingVersion = 5

-- | Nominal binary-product sibling of the scalar positive-ordering grammar.
lengthRankingConfigurationFileSpinePairPositiveOrderingVersion :: Natural
lengthRankingConfigurationFileSpinePairPositiveOrderingVersion = 6

-- | Advanced scalar policy bundle with positive-affine domain extraction,
-- strict counterexample simplification, and deferred worker opening.
lengthRankingConfigurationFilePositiveAffineVersion :: Natural
lengthRankingConfigurationFilePositiveAffineVersion = 7

-- | Nominal binary-product sibling of the advanced scalar policy bundle.
lengthRankingConfigurationFileSpinePairPositiveAffineVersion :: Natural
lengthRankingConfigurationFileSpinePairPositiveAffineVersion = 8

lengthRankingConfigurationFileUsableWorkBudgetVersion :: Natural
lengthRankingConfigurationFileUsableWorkBudgetVersion = 9

lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion :: Natural
lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion = 10

-- | Scalar sibling of version 7 which selects relational positive-affine
-- applicable-domain closure and deliberately carries no usable-work budget.
lengthRankingConfigurationFileRelationalPositiveAffineVersion :: Natural
lengthRankingConfigurationFileRelationalPositiveAffineVersion = 11

-- | Nominal binary-product sibling of the relational scalar grammar.
lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion
  :: Natural
lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion = 12

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
  | LengthRankingConfigurationInputBoxValidationObject
  | LengthRankingConfigurationApplicableDomainValidationObject
  | LengthRankingConfigurationCounterexampleSimplificationObject
  | LengthRankingConfigurationUsableWorkBudgetObject
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
  | LengthRankingConfigurationInputBoxValidationField
  | LengthRankingConfigurationCounterexampleProbeField
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
  | LengthRankingConfigurationResultShapeField
  | LengthRankingConfigurationBoundedPositiveOrderingField
  | LengthRankingConfigurationApplicableDomainValidationField
  | LengthRankingConfigurationApplicableDomainStrategyField
  | LengthRankingConfigurationApplicableDomainMaximumInputsField
  | LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
  | LengthRankingConfigurationApplicableDomainOrderingField
  | LengthRankingConfigurationCounterexampleSimplificationField
  | LengthRankingConfigurationCounterexampleSimplificationStrategyField
  | LengthRankingConfigurationCounterexampleSimplificationMaximumInputsField
  | LengthRankingConfigurationCounterexampleSimplificationMaximumAssignmentsField
  | LengthRankingConfigurationLiveSessionOpeningField
  | LengthRankingConfigurationUsableWorkBudgetField
  | LengthRankingConfigurationUsableWorkBudgetStrategyField
  | LengthRankingConfigurationUsableWorkBudgetMillisecondsField
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
  | LengthRankingConfigurationInputBoxLimitsRejected
      !LengthInputBoxLimitError
  | LengthRankingConfigurationUsableWorkBudgetRejected
      !LengthSMTLibLiveUsableWorkBudgetError
  | LengthRankingConfigurationSyntaxRejected
      !LengthRankingConfigurationSyntaxPhase
      !LengthRankingConfigurationSyntaxError
  deriving (Eq, Ord, Show)

-- | A fully decoded and sealed policy which still grants no permission to run.
-- Its opaque execution policy is the sole owner of any executable digest
-- expectation; no second source-derived activation flag is retained.
-- The strict field preserves the existing disabled wrapper's demand on the
-- already-sealed policy without forcing its deliberately lazy contract.
data DisabledLengthRankingConfiguration =
  DisabledLengthRankingConfiguration
    !LengthRankingPolicy
    LeanLengthContract

-- | Additive disabled startup selection.  The scalar branch retains the
-- established opaque value wholesale; the pair branch has the same strict
-- validated-policy and lazy passive-contract boundary.
data DisabledLengthAssessmentConfiguration
  = DisabledLengthScalarAssessmentConfiguration
      !DisabledLengthRankingConfiguration
  | DisabledLengthSpinePairAssessmentConfiguration
      !LengthRankingPolicy
      LeanLengthSpinePairContract

-- | Retain an already validated policy beside one passive contract assertion
-- without granting permission to execute it.  The strict policy and lazy
-- contract fields match the compatibility-file decoder's demand boundary.
-- This package-private bridge performs no validation or IO.
disableLengthRankingConfiguration
  :: LengthRankingPolicy
  -> LeanLengthContract
  -> DisabledLengthRankingConfiguration
disableLengthRankingConfiguration = DisabledLengthRankingConfiguration

data LengthRankingConfigurationActivationPolicy
  = RequirePinnedExecutable
  | PermitUnpinnedExecutable
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthRankingConfigurationActivationError
  = LengthRankingConfigurationExecutablePinRequired
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Explicitly activate a decoded policy.  Requiring a pin fails closed when
-- the sealed execution policy classifies its digest expectation as absent;
-- permitting an unpinned executable is a distinct, visible caller decision
-- rather than a decoder default.  Neither branch inspects the retained lazy
-- contract or performs IO.
activateLengthRankingConfiguration
  :: LengthRankingConfigurationActivationPolicy
  -> DisabledLengthRankingConfiguration
  -> Either
      LengthRankingConfigurationActivationError
      (LengthRankingPolicy, LeanLengthContract)
activateLengthRankingConfiguration policy
    (DisabledLengthRankingConfiguration rankingPolicy contract) = case policy of
  RequirePinnedExecutable ->
    case lengthRankingPolicyExecutableDigestExpectation rankingPolicy of
      LengthSMTLibExecutableDigestExpectationAbsent ->
        Left LengthRankingConfigurationExecutablePinRequired
      LengthSMTLibExecutableDigestExpectationPresent ->
        Right (rankingPolicy, contract)
  PermitUnpinnedExecutable -> Right (rankingPolicy, contract)

-- | Activate either supported startup domain under the same explicit digest
-- decision.  Scalar activation delegates to the established function.
activateLengthAssessmentConfiguration
  :: LengthRankingConfigurationActivationPolicy
  -> DisabledLengthAssessmentConfiguration
  -> Either
      LengthRankingConfigurationActivationError
      (LengthRankingPolicy, LeanLengthContractSelection)
activateLengthAssessmentConfiguration policy disabled = case disabled of
  DisabledLengthScalarAssessmentConfiguration scalar -> do
    (rankingPolicy, contract) <-
      activateLengthRankingConfiguration policy scalar
    pure (rankingPolicy, LeanLengthScalarContractSelection contract)
  DisabledLengthSpinePairAssessmentConfiguration rankingPolicy contract ->
    case policy of
      RequirePinnedExecutable ->
        case lengthRankingPolicyExecutableDigestExpectation rankingPolicy of
          LengthSMTLibExecutableDigestExpectationAbsent ->
            Left LengthRankingConfigurationExecutablePinRequired
          LengthSMTLibExecutableDigestExpectationPresent ->
            Right
              ( rankingPolicy
              , LeanLengthSpinePairContractSelection contract
              )
      PermitUnpinnedExecutable -> Right
        (rankingPolicy, LeanLengthSpinePairContractSelection contract)

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
    then decodeLengthRankingConfigurationFileV1 root
    else if version ==
        toInteger lengthRankingConfigurationFileInputBoxVersion
      then decodeLengthRankingConfigurationFileInputBoxV2 root
      else if version ==
          toInteger lengthRankingConfigurationFileOriginProbeVersion
        then decodeLengthRankingConfigurationFileOriginProbeV3 root
        else Left LengthRankingConfigurationUnsupportedVersion

-- | Decode the additive domain-selecting startup grammar.  Every established
-- scalar success and every scalar diagnostic except the closed unsupported-
-- version sentinel is returned by the old decoder itself.  Only that sentinel
-- permits the literal version-4 parse and, only after its own unsupported-
-- version sentinel, the additive version-5/version-6 parse.  The advanced
-- version-7/version-8 parser is reached only after that parser returns the
-- same closed sentinel.  Relational versions are considered only after the
-- version-9/version-10 decoder also returns that sentinel.
decodeLengthAssessmentConfigurationFile
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFile bytes =
  case decodeLengthRankingConfigurationFile bytes of
    Right scalar -> Right
      $ DisabledLengthScalarAssessmentConfiguration scalar
    Left LengthRankingConfigurationUnsupportedVersion -> case
        decodeLengthAssessmentConfigurationFileSpinePairV4 bytes of
      Right pair -> Right pair
      Left LengthRankingConfigurationUnsupportedVersion ->
        case decodeLengthAssessmentConfigurationFilePositiveOrdering bytes of
          Right positiveOrdering -> Right positiveOrdering
          Left LengthRankingConfigurationUnsupportedVersion -> case
              decodeLengthAssessmentConfigurationFilePositiveAffine bytes of
            Right positiveAffine -> Right positiveAffine
            Left LengthRankingConfigurationUnsupportedVersion -> case
                decodeLengthAssessmentConfigurationFileUsableWorkBudget bytes of
              Right usableWorkBudget -> Right usableWorkBudget
              Left LengthRankingConfigurationUnsupportedVersion ->
                decodeLengthAssessmentConfigurationFileRelationalPositiveAffine
                  bytes
              Left failure -> Left failure
            Left failure -> Left failure
          Left failure -> Left failure
      Left failure -> Left failure
    Left failure -> Left failure

decodeLengthAssessmentConfigurationFileSpinePairV4
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFileSpinePairV4 bytes = do
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
  if version == toInteger lengthRankingConfigurationFileSpinePairVersion
    then decodeLengthRankingConfigurationFileSpinePairV4 root
    else Left LengthRankingConfigurationUnsupportedVersion

-- | Decode only the two additive positive-ordering versions after both the
-- scalar v1--v3 decoder and the literal pair-v4 decoder have returned their
-- closed unsupported-version sentinel.  This preserves every established
-- success and diagnostic at those older entrances.
decodeLengthAssessmentConfigurationFilePositiveOrdering
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFilePositiveOrdering bytes = do
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
  if version ==
      toInteger lengthRankingConfigurationFilePositiveOrderingVersion
    then decodeLengthRankingConfigurationFilePositiveOrderingV5 root
    else if version == toInteger
        lengthRankingConfigurationFileSpinePairPositiveOrderingVersion
      then decodeLengthRankingConfigurationFileSpinePairPositiveOrderingV6 root
      else Left LengthRankingConfigurationUnsupportedVersion

-- | Decode only the advanced scalar and product bundles, after every older
-- generalized entrance has returned its unsupported-version sentinel.
decodeLengthAssessmentConfigurationFilePositiveAffine
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFilePositiveAffine bytes = do
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
  if version == toInteger lengthRankingConfigurationFilePositiveAffineVersion
    then decodeLengthRankingConfigurationFilePositiveAffineV7 root
    else if version == toInteger
        lengthRankingConfigurationFileSpinePairPositiveAffineVersion
      then decodeLengthRankingConfigurationFileSpinePairPositiveAffineV8 root
      else Left LengthRankingConfigurationUnsupportedVersion

decodeLengthAssessmentConfigurationFileUsableWorkBudget
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFileUsableWorkBudget bytes = do
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
  if version ==
      toInteger lengthRankingConfigurationFileUsableWorkBudgetVersion
    then decodeLengthRankingConfigurationFileUsableWorkBudgetV9 root
    else if version == toInteger
        lengthRankingConfigurationFileSpinePairUsableWorkBudgetVersion
      then decodeLengthRankingConfigurationFileSpinePairUsableWorkBudgetV10 root
      else Left LengthRankingConfigurationUnsupportedVersion

-- | Decode only the scalar/product relational positive-affine siblings after
-- every version-1--version-10 entrance has returned its unsupported-version
-- sentinel.  The accepted root remains byte-for-byte the version-7/version-8
-- field set and therefore has no usable-work-budget member.
decodeLengthAssessmentConfigurationFileRelationalPositiveAffine
  :: ByteString
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthAssessmentConfigurationFileRelationalPositiveAffine bytes = do
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
  if version == toInteger
      lengthRankingConfigurationFileRelationalPositiveAffineVersion
    then decodeLengthRankingConfigurationFileRelationalPositiveAffineV11 root
    else if version == toInteger
        lengthRankingConfigurationFileSpinePairRelationalPositiveAffineVersion
      then
        decodeLengthRankingConfigurationFileSpinePairRelationalPositiveAffineV12
          root
      else Left LengthRankingConfigurationUnsupportedVersion

-- Keep the established version-1 path literal: its exact root, validation
-- order, embedded contract grammar, and disabled policy construction do not
-- pass through any version-2 input-box branch.
decodeLengthRankingConfigurationFileV1
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthRankingConfiguration
decodeLengthRankingConfigurationFileV1 root = do
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValue contractValue
  let policy = lengthRankingPolicyFromValidatedComponents execution evaluation
  pure $ disableLengthRankingConfiguration policy contract

decodeLengthRankingConfigurationFileInputBoxV2
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthRankingConfiguration
decodeLengthRankingConfigurationFileInputBoxV2 root = do
  exactFields LengthRankingConfigurationRootObject rootFieldsInputBoxV2 root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValue contractValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      policy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
  pure $ disableLengthRankingConfiguration policy contract

-- Keep version 2's path literal above.  Version 3 repeats its fixed decode
-- precedence, then validates the new closed root selection before demanding
-- the embedded compatibility contract.
decodeLengthRankingConfigurationFileOriginProbeV3
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthRankingConfiguration
decodeLengthRankingConfigurationFileOriginProbeV3 root = do
  exactFields LengthRankingConfigurationRootObject rootFieldsOriginProbeV3 root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValue contractValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      policy = enableLengthRankingOriginProbe inputBoxPolicy
  pure $ disableLengthRankingConfiguration policy contract

-- Version 4 intentionally repeats version 3's operational precedence and
-- validates the nominal product contract only after the origin-probe choice.
decodeLengthRankingConfigurationFileSpinePairV4
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileSpinePairV4 root = do
  exactFields LengthRankingConfigurationRootObject rootFieldsOriginProbeV3 root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthSpinePairContractValueV5 contractValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      policy = enableLengthRankingOriginProbe inputBoxPolicy
  pure $ DisabledLengthSpinePairAssessmentConfiguration policy contract

-- Version 5 is generalized-only and scalar.  It repeats version 3's complete
-- operational precedence, requires the new ordering grant, then decodes the
-- established full scalar contract-v5 grammar.  No older decoder reaches this
-- function.
decodeLengthRankingConfigurationFilePositiveOrderingV5
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFilePositiveOrderingV5 root = do
  exactFields LengthRankingConfigurationRootObject
    rootFieldsPositiveOrdering root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  boundedPositiveOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationBoundedPositiveOrderingField
    "boundedPositiveOrdering"
    root
  decodeBoundedPositiveOrdering boundedPositiveOrderingValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValueV5 contractValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      originProbePolicy = enableLengthRankingOriginProbe inputBoxPolicy
      policy = enableLengthRankingNonVacuousInputBoxPreference
        originProbePolicy
  pure $ DisabledLengthScalarAssessmentConfiguration
    $ disableLengthRankingConfiguration policy contract

-- Version 6 is the nominal pair sibling.  Its operational and ordering fields
-- have the same fixed precedence as version 5, while the passive contract is
-- decoded only by the pair-specific v5 grammar used by startup version 4.
decodeLengthRankingConfigurationFileSpinePairPositiveOrderingV6
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileSpinePairPositiveOrderingV6 root = do
  exactFields LengthRankingConfigurationRootObject
    rootFieldsPositiveOrdering root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  boundedPositiveOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationBoundedPositiveOrderingField
    "boundedPositiveOrdering"
    root
  decodeBoundedPositiveOrdering boundedPositiveOrderingValue
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthSpinePairContractValueV5 contractValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      originProbePolicy = enableLengthRankingOriginProbe inputBoxPolicy
      policy = enableLengthRankingNonVacuousInputBoxPreference
        originProbePolicy
  pure $ DisabledLengthSpinePairAssessmentConfiguration policy contract

-- Versions 7 and 8 share one exact advanced policy prefix.  Their only
-- distinction remains the nominal scalar/product contract decoded last.
decodeLengthRankingConfigurationFilePositiveAffineV7
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFilePositiveAffineV7 root = do
  policy <- decodeLengthRankingConfigurationFilePositiveAffinePolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValueV5 contractValue
  pure $ DisabledLengthScalarAssessmentConfiguration
    $ disableLengthRankingConfiguration policy contract

decodeLengthRankingConfigurationFileSpinePairPositiveAffineV8
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileSpinePairPositiveAffineV8 root = do
  policy <- decodeLengthRankingConfigurationFilePositiveAffinePolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthSpinePairContractValueV5 contractValue
  pure $ DisabledLengthSpinePairAssessmentConfiguration policy contract

decodeLengthRankingConfigurationFileUsableWorkBudgetV9
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileUsableWorkBudgetV9 root = do
  policy <- decodeLengthRankingConfigurationFileUsableWorkBudgetPolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValueV5 contractValue
  pure $ DisabledLengthScalarAssessmentConfiguration
    $ disableLengthRankingConfiguration policy contract

decodeLengthRankingConfigurationFileSpinePairUsableWorkBudgetV10
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileSpinePairUsableWorkBudgetV10 root = do
  policy <- decodeLengthRankingConfigurationFileUsableWorkBudgetPolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthSpinePairContractValueV5 contractValue
  pure $ DisabledLengthSpinePairAssessmentConfiguration policy contract

decodeLengthRankingConfigurationFileRelationalPositiveAffineV11
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileRelationalPositiveAffineV11 root = do
  policy <-
    decodeLengthRankingConfigurationFileRelationalPositiveAffinePolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthContractValueV5 contractValue
  pure $ DisabledLengthScalarAssessmentConfiguration
    $ disableLengthRankingConfiguration policy contract

decodeLengthRankingConfigurationFileSpinePairRelationalPositiveAffineV12
  :: ObjectFields
  -> Either
      LengthRankingConfigurationFileError
      DisabledLengthAssessmentConfiguration
decodeLengthRankingConfigurationFileSpinePairRelationalPositiveAffineV12
    root = do
  policy <-
    decodeLengthRankingConfigurationFileRelationalPositiveAffinePolicy root
  contractValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationContractField
    "contract"
    root
  contract <- decodeLeanLengthSpinePairContractValueV5 contractValue
  pure $ DisabledLengthSpinePairAssessmentConfiguration policy contract

decodeLengthRankingConfigurationFileUsableWorkBudgetPolicy
  :: ObjectFields
  -> Either LengthRankingConfigurationFileError LengthRankingPolicy
decodeLengthRankingConfigurationFileUsableWorkBudgetPolicy root = do
  exactFields LengthRankingConfigurationRootObject
    rootFieldsUsableWorkBudget root
  let inheritedRoot = filter ((/= "usableWorkBudget") . fst) root
  advancedPolicy <-
    decodeLengthRankingConfigurationFilePositiveAffinePolicy inheritedRoot
  budgetValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationUsableWorkBudgetField
    "usableWorkBudget"
    root
  budget <- decodeUsableWorkBudget budgetValue
  pure $ enableLengthRankingUsableWorkBudget budget advancedPolicy

-- Decode the advanced policy in its frozen diagnostic order.  The two bounded
-- objects are decoded independently and retain distinct validated limits.
decodeLengthRankingConfigurationFilePositiveAffinePolicy
  :: ObjectFields
  -> Either LengthRankingConfigurationFileError LengthRankingPolicy
decodeLengthRankingConfigurationFilePositiveAffinePolicy root = do
  exactFields LengthRankingConfigurationRootObject
    rootFieldsPositiveAffine root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  boundedPositiveOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationBoundedPositiveOrderingField
    "boundedPositiveOrdering"
    root
  decodeBoundedPositiveOrdering boundedPositiveOrderingValue
  applicableDomainValidationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationApplicableDomainValidationField
    "applicableDomainValidation"
    root
  applicableDomainLimits <- decodeApplicableDomainValidation
    applicableDomainValidationValue
  applicableDomainOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationApplicableDomainOrderingField
    "applicableDomainOrdering"
    root
  decodeApplicableDomainOrdering applicableDomainOrderingValue
  counterexampleSimplificationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleSimplificationField
    "counterexampleSimplification"
    root
  counterexampleSimplificationLimits <- decodeCounterexampleSimplification
    counterexampleSimplificationValue
  liveSessionOpeningValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationLiveSessionOpeningField
    "liveSessionOpening"
    root
  decodeLiveSessionOpening liveSessionOpeningValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      originProbePolicy = enableLengthRankingOriginProbe inputBoxPolicy
      inputBoxPreferencePolicy =
        enableLengthRankingNonVacuousInputBoxPreference originProbePolicy
      applicableDomainPolicy =
        enableLengthRankingPositiveAffineApplicableDomainValidation
          applicableDomainLimits inputBoxPreferencePolicy
      applicableDomainPreferencePolicy =
        enableLengthRankingNonVacuousApplicableDomainPreference
          applicableDomainPolicy
      simplificationPolicy = enableLengthRankingCounterexampleSimplification
        counterexampleSimplificationLimits applicableDomainPreferencePolicy
  pure $ enableLengthRankingDeferredLiveSessionOpening simplificationPolicy

-- Versions 11 and 12 intentionally duplicate version 7/8's policy demand
-- order while replacing only the applicable-domain strategy.  Keeping this
-- entrance separate prevents later changes from altering versions 1--10.
decodeLengthRankingConfigurationFileRelationalPositiveAffinePolicy
  :: ObjectFields
  -> Either LengthRankingConfigurationFileError LengthRankingPolicy
decodeLengthRankingConfigurationFileRelationalPositiveAffinePolicy root = do
  exactFields LengthRankingConfigurationRootObject
    rootFieldsPositiveAffine root
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
  execution <- decodeExecution executionLimits executionValue
  evaluationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationEvaluationField
    "evaluation"
    root
  evaluation <- decodeEvaluation evaluationValue
  inputBoxValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationInputBoxValidationField
    "inputBoxValidation"
    root
  (inputBoxLimits, inclusiveMaximums) <-
    decodeInputBoxValidation inputBoxValue
  counterexampleProbeValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleProbeField
    "counterexampleProbe"
    root
  decodeCounterexampleProbe counterexampleProbeValue
  boundedPositiveOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationBoundedPositiveOrderingField
    "boundedPositiveOrdering"
    root
  decodeBoundedPositiveOrdering boundedPositiveOrderingValue
  applicableDomainValidationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationApplicableDomainValidationField
    "applicableDomainValidation"
    root
  applicableDomainLimits <-
    decodeRelationalPositiveAffineApplicableDomainValidation
      applicableDomainValidationValue
  applicableDomainOrderingValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationApplicableDomainOrderingField
    "applicableDomainOrdering"
    root
  decodeApplicableDomainOrdering applicableDomainOrderingValue
  counterexampleSimplificationValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationCounterexampleSimplificationField
    "counterexampleSimplification"
    root
  counterexampleSimplificationLimits <- decodeCounterexampleSimplification
    counterexampleSimplificationValue
  liveSessionOpeningValue <- requiredField
    LengthRankingConfigurationRootObject
    LengthRankingConfigurationLiveSessionOpeningField
    "liveSessionOpening"
    root
  decodeLiveSessionOpening liveSessionOpeningValue
  let basePolicy =
        lengthRankingPolicyFromValidatedComponents execution evaluation
      inputBoxPolicy = enableLengthRankingInputBoxValidation
        inputBoxLimits inclusiveMaximums basePolicy
      originProbePolicy = enableLengthRankingOriginProbe inputBoxPolicy
      inputBoxPreferencePolicy =
        enableLengthRankingNonVacuousInputBoxPreference originProbePolicy
      applicableDomainPolicy =
        enableLengthRankingRelationalPositiveAffineApplicableDomainValidation
          applicableDomainLimits inputBoxPreferencePolicy
      applicableDomainPreferencePolicy =
        enableLengthRankingNonVacuousApplicableDomainPreference
          applicableDomainPolicy
      simplificationPolicy = enableLengthRankingCounterexampleSimplification
        counterexampleSimplificationLimits applicableDomainPreferencePolicy
  pure $ enableLengthRankingDeferredLiveSessionOpening simplificationPolicy

rootFields :: [(Text, LengthRankingConfigurationFileField)]
rootFields =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ("contract", LengthRankingConfigurationContractField)
  ]

rootFieldsInputBoxV2 :: [(Text, LengthRankingConfigurationFileField)]
rootFieldsInputBoxV2 =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ("contract", LengthRankingConfigurationContractField)
  ]

rootFieldsOriginProbeV3
  :: [(Text, LengthRankingConfigurationFileField)]
rootFieldsOriginProbeV3 =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ( "counterexampleProbe"
    , LengthRankingConfigurationCounterexampleProbeField
    )
  , ("contract", LengthRankingConfigurationContractField)
  ]

rootFieldsPositiveOrdering
  :: [(Text, LengthRankingConfigurationFileField)]
rootFieldsPositiveOrdering =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ( "counterexampleProbe"
    , LengthRankingConfigurationCounterexampleProbeField
    )
  , ( "boundedPositiveOrdering"
    , LengthRankingConfigurationBoundedPositiveOrderingField
    )
  , ("contract", LengthRankingConfigurationContractField)
  ]

rootFieldsPositiveAffine
  :: [(Text, LengthRankingConfigurationFileField)]
rootFieldsPositiveAffine =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ( "counterexampleProbe"
    , LengthRankingConfigurationCounterexampleProbeField
    )
  , ( "boundedPositiveOrdering"
    , LengthRankingConfigurationBoundedPositiveOrderingField
    )
  , ( "applicableDomainValidation"
    , LengthRankingConfigurationApplicableDomainValidationField
    )
  , ( "applicableDomainOrdering"
    , LengthRankingConfigurationApplicableDomainOrderingField
    )
  , ( "counterexampleSimplification"
    , LengthRankingConfigurationCounterexampleSimplificationField
    )
  , ( "liveSessionOpening"
    , LengthRankingConfigurationLiveSessionOpeningField
    )
  , ("contract", LengthRankingConfigurationContractField)
  ]

rootFieldsUsableWorkBudget
  :: [(Text, LengthRankingConfigurationFileField)]
rootFieldsUsableWorkBudget =
  [ ("format", LengthRankingConfigurationFormatField)
  , ("version", LengthRankingConfigurationVersionField)
  , ("executionAdmission", LengthRankingConfigurationExecutionAdmissionField)
  , ("execution", LengthRankingConfigurationExecutionField)
  , ("evaluation", LengthRankingConfigurationEvaluationField)
  , ( "inputBoxValidation"
    , LengthRankingConfigurationInputBoxValidationField
    )
  , ( "counterexampleProbe"
    , LengthRankingConfigurationCounterexampleProbeField
    )
  , ( "boundedPositiveOrdering"
    , LengthRankingConfigurationBoundedPositiveOrderingField
    )
  , ( "applicableDomainValidation"
    , LengthRankingConfigurationApplicableDomainValidationField
    )
  , ( "applicableDomainOrdering"
    , LengthRankingConfigurationApplicableDomainOrderingField
    )
  , ( "counterexampleSimplification"
    , LengthRankingConfigurationCounterexampleSimplificationField
    )
  , ( "liveSessionOpening"
    , LengthRankingConfigurationLiveSessionOpeningField
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
  case mkLengthSMTLibExecutionConfig limits source of
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

-- | Decode version 3's only origin-probe mode.  The closed literal grants
-- permission to ask each exact query for its canonical all-zero replay after
-- the MRU bank misses; it contains no caller-supplied arity or input vector.
decodeCounterexampleProbe
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ()
decodeCounterexampleProbe value = do
  mode <- stringField LengthRankingConfigurationCounterexampleProbeField value
  case mode of
    "origin-before-live" -> Right ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationCounterexampleProbeField

-- | Decode the sole additive evidence-ordering grant.  The literal does not
-- enable finite-box traversal or assert that any applicable assignment will
-- exist; it only permits an independently acquired non-vacuous receipt to
-- enter the preferred stable partition.
decodeBoundedPositiveOrdering
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ()
decodeBoundedPositiveOrdering value = do
  mode <- stringField
    LengthRankingConfigurationBoundedPositiveOrderingField value
  case mode of
    "prefer-non-vacuous" -> Right ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationBoundedPositiveOrderingField

-- | Decode the independent positive-affine applicable-domain authority.  The
-- strategy is closed before either bounded limit is admitted.
decodeApplicableDomainValidation
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LengthInputBoxLimits
decodeApplicableDomainValidation value = do
  object <- exactObject
    LengthRankingConfigurationApplicableDomainValidationObject
    applicableDomainValidationFields value
  strategyValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainStrategyField
    "strategy"
    object
  strategy <- stringField
    LengthRankingConfigurationApplicableDomainStrategyField
    strategyValue
  case strategy of
    "positive-affine-v1" -> pure ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationApplicableDomainStrategyField
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
  checkedInputBoxLimits maximumInputs maximumAssignments

-- | Decode the relational positive-affine sibling using the established
-- applicable-domain object and bounded-limit diagnostics.  Only the closed
-- strategy literal differs from versions 7 and 8.
decodeRelationalPositiveAffineApplicableDomainValidation
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LengthInputBoxLimits
decodeRelationalPositiveAffineApplicableDomainValidation value = do
  object <- exactObject
    LengthRankingConfigurationApplicableDomainValidationObject
    applicableDomainValidationFields value
  strategyValue <- requiredField
    LengthRankingConfigurationApplicableDomainValidationObject
    LengthRankingConfigurationApplicableDomainStrategyField
    "strategy"
    object
  strategy <- stringField
    LengthRankingConfigurationApplicableDomainStrategyField
    strategyValue
  case strategy of
    "relational-positive-affine-v1" -> pure ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationApplicableDomainStrategyField
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
  checkedInputBoxLimits maximumInputs maximumAssignments

applicableDomainValidationFields
  :: [(Text, LengthRankingConfigurationFileField)]
applicableDomainValidationFields =
  [ ( "strategy"
    , LengthRankingConfigurationApplicableDomainStrategyField
    )
  , ( "maximumInputs"
    , LengthRankingConfigurationApplicableDomainMaximumInputsField
    )
  , ( "maximumAssignments"
    , LengthRankingConfigurationApplicableDomainMaximumAssignmentsField
    )
  ]

decodeApplicableDomainOrdering
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ()
decodeApplicableDomainOrdering value = do
  mode <- stringField
    LengthRankingConfigurationApplicableDomainOrderingField value
  case mode of
    "prefer-non-vacuous" -> Right ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationApplicableDomainOrderingField

-- | Decode a second, independent bounded authority for strict
-- componentwise-lexicographic counterexample simplification.
decodeCounterexampleSimplification
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LengthInputBoxLimits
decodeCounterexampleSimplification value = do
  object <- exactObject
    LengthRankingConfigurationCounterexampleSimplificationObject
    counterexampleSimplificationFields value
  strategyValue <- requiredField
    LengthRankingConfigurationCounterexampleSimplificationObject
    LengthRankingConfigurationCounterexampleSimplificationStrategyField
    "strategy"
    object
  strategy <- stringField
    LengthRankingConfigurationCounterexampleSimplificationStrategyField
    strategyValue
  case strategy of
    "componentwise-lexicographic-v1" -> pure ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationCounterexampleSimplificationStrategyField
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
  [ ( "strategy"
    , LengthRankingConfigurationCounterexampleSimplificationStrategyField
    )
  , ( "maximumInputs"
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

decodeLiveSessionOpening
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError ()
decodeLiveSessionOpening value = do
  mode <- stringField LengthRankingConfigurationLiveSessionOpeningField value
  case mode of
    "defer-until-live-query" -> Right ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationLiveSessionOpeningField

decodeUsableWorkBudget
  :: BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LengthSMTLibLiveUsableWorkBudget
decodeUsableWorkBudget value = do
  object <- exactObject LengthRankingConfigurationUsableWorkBudgetObject
    usableWorkBudgetFields value
  strategyValue <- requiredField
    LengthRankingConfigurationUsableWorkBudgetObject
    LengthRankingConfigurationUsableWorkBudgetStrategyField
    "strategy"
    object
  strategy <- stringField
    LengthRankingConfigurationUsableWorkBudgetStrategyField strategyValue
  case strategy of
    "shared-usable-work-deadline-v1" -> pure ()
    _ -> Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationUsableWorkBudgetStrategyField
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

usableWorkBudgetFields
  :: [(Text, LengthRankingConfigurationFileField)]
usableWorkBudgetFields =
  [ ( "strategy"
    , LengthRankingConfigurationUsableWorkBudgetStrategyField
    )
  , ( "milliseconds"
    , LengthRankingConfigurationUsableWorkBudgetMillisecondsField
    )
  ]

-- | Decode version 2's explicit source-ordered inclusive input box.  Width is
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

-- | Decode exactly the contract object embedded by the compatibility file.
-- Contract-only version 1 reuses this entrance. Later contract-only versions
-- select the sibling entrances below; all delegate to one owner for names,
-- target and provider roles, case policy, recursive syntax, and hard limits.
decodeLeanLengthContractValue
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValue = decodeLeanLengthContractValueWithGrammar
  LengthContractGrammarV1

-- | Decode the contract-only version-2 grammar.  This is the version-1
-- grammar plus positive-literal Natural modulo; the startup compatibility
-- file deliberately continues to call the version-1 entrance above.
decodeLeanLengthContractValueV2
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValueV2 = decodeLeanLengthContractValueWithGrammar
  LengthContractGrammarV2

-- | Decode the contract-only version-3 grammar. This retains modulo from
-- version 2 and requires one explicit role for every physical target
-- argument. Startup configuration and older contract-only versions never
-- call this entrance and reject the new field as unexpected.
decodeLeanLengthContractValueV3
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValueV3 = decodeLeanLengthContractValueWithGrammar
  LengthContractGrammarV3

-- | Decode the contract-only version-4 grammar. This retains modulo and the
-- required target-role vector from version 3, and additionally requires an
-- explicit closed candidate-case policy. Startup configuration and older
-- contract-only versions reject the new field as unexpected.
decodeLeanLengthContractValueV4
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValueV4 = decodeLeanLengthContractValueWithGrammar
  LengthContractGrammarV4

-- | Decode the contract-only version-5 grammar. This retains modulo, required
-- target roles, and an explicit case policy, and additionally admits
-- positive-literal Natural quotient. Unlike version 4, version 5 accepts an
-- explicit case-rejecting policy so new arithmetic does not itself grant case
-- authority.
decodeLeanLengthContractValueV5
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValueV5 = decodeLeanLengthContractValueWithGrammar
  LengthContractGrammarV5

-- | Decode the nominal binary-product contract used by startup version 4 and
-- contract-only version 6.  It shares version 5's closed arithmetic and
-- provider-law grammar while retaining a distinct result-shape marker,
-- variable type, and passive source value.
decodeLeanLengthSpinePairContractValueV5
  :: BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthSpinePairContract
decodeLeanLengthSpinePairContractValueV5 value = do
  object <- exactObject LengthRankingConfigurationContractObject
    spinePairContractFields value
  resultShapeValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationResultShapeField
    "resultShape"
    object
  resultShape <- stringField LengthRankingConfigurationResultShapeField
    resultShapeValue
  if resultShape == "binary-prod-spines-v1"
    then pure ()
    else Left $ LengthRankingConfigurationFieldValueRejected
      LengthRankingConfigurationResultShapeField
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
  casePolicy <- decodeCandidateCasePolicy LengthContractGrammarV5 policyValue
  preconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPreconditionField
    "precondition"
    object
  (precondition, afterPrecondition) <- parseLengthFormula
    LengthContractGrammarV5
    LengthRankingConfigurationPreconditionSyntax
    spinePairContractVariable
    1
    emptySyntaxUsage
    preconditionValue
  postconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPostconditionField
    "postcondition"
    object
  (postcondition, _) <- parseLengthFormula
    LengthContractGrammarV5
    LengthRankingConfigurationPostconditionSyntax
    spinePairContractVariable
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
  providerLaws <- decodeProviderLaws LengthContractGrammarV5
    0 emptySyntaxUsage lawValues
  pure LeanLengthSpinePairContract
    { leanLengthSpinePairContractSpine = spine
    , leanLengthSpinePairContractTargetArgumentRoles = Just targetRoles
    , leanLengthSpinePairContractCandidateCasePolicy = casePolicy
    , leanLengthSpinePairContractSource = LengthSpinePairContractSource
        { lengthSpinePairContractPrecondition = precondition
        , lengthSpinePairContractPostcondition = postcondition
        }
    , leanLengthSpinePairContractProviderLaws = providerLaws
    }

spinePairContractFields
  :: [(Text, LengthRankingConfigurationFileField)]
spinePairContractFields =
  [ ("resultShape", LengthRankingConfigurationResultShapeField)
  , ("spine", LengthRankingConfigurationSpineField)
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

data LengthContractGrammar
  = LengthContractGrammarV1
  | LengthContractGrammarV2
  | LengthContractGrammarV3
  | LengthContractGrammarV4
  | LengthContractGrammarV5
  deriving (Eq)

decodeLeanLengthContractValueWithGrammar
  :: LengthContractGrammar
  -> BoundedJsonValue
  -> Either LengthRankingConfigurationFileError LeanLengthContract
decodeLeanLengthContractValueWithGrammar grammar value = do
  object <- exactObject LengthRankingConfigurationContractObject
    (contractFields grammar) value
  spineValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationSpineField
    "spine"
    object
  spine <- decodeSpine spineValue
  targetRoles <- case grammar of
    LengthContractGrammarV1 -> Right Nothing
    LengthContractGrammarV2 -> Right Nothing
    LengthContractGrammarV3 -> do
      rolesValue <- requiredField
        LengthRankingConfigurationContractObject
        LengthRankingConfigurationTargetArgumentRolesField
        "targetArgumentRoles"
        object
      Just <$> decodeTargetRoles rolesValue
    LengthContractGrammarV4 -> do
      rolesValue <- requiredField
        LengthRankingConfigurationContractObject
        LengthRankingConfigurationTargetArgumentRolesField
        "targetArgumentRoles"
        object
      Just <$> decodeTargetRoles rolesValue
    LengthContractGrammarV5 -> do
      rolesValue <- requiredField
        LengthRankingConfigurationContractObject
        LengthRankingConfigurationTargetArgumentRolesField
        "targetArgumentRoles"
        object
      Just <$> decodeTargetRoles rolesValue
  casePolicy <- case grammar of
    LengthContractGrammarV4 -> do
      policyValue <- requiredField
        LengthRankingConfigurationContractObject
        LengthRankingConfigurationCandidateCasePolicyField
        "candidateCasePolicy"
        object
      decodeCandidateCasePolicy grammar policyValue
    LengthContractGrammarV5 -> do
      policyValue <- requiredField
        LengthRankingConfigurationContractObject
        LengthRankingConfigurationCandidateCasePolicyField
        "candidateCasePolicy"
        object
      decodeCandidateCasePolicy grammar policyValue
    _ -> Right LeanLengthCasesRejected
  preconditionValue <- requiredField
    LengthRankingConfigurationContractObject
    LengthRankingConfigurationPreconditionField
    "precondition"
    object
  (precondition, afterPrecondition) <- parseLengthFormula grammar
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
  (postcondition, _) <- parseLengthFormula grammar
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
  providerLaws <- decodeProviderLaws grammar 0 emptySyntaxUsage lawValues
  pure LeanLengthContract
    { leanLengthContractSpine = spine
    , leanLengthContractTargetArgumentRoles = targetRoles
    , leanLengthContractCandidateCasePolicy = casePolicy
    , leanLengthContractSource = LengthContractSource
        { lengthContractPrecondition = precondition
        , lengthContractPostcondition = postcondition
        }
    , leanLengthContractProviderLaws = providerLaws
    }

contractFields
  :: LengthContractGrammar
  -> [(Text, LengthRankingConfigurationFileField)]
contractFields grammar =
  [ ("spine", LengthRankingConfigurationSpineField)
  ] ++ targetRoleFields ++ casePolicyFields ++
  [ ("precondition", LengthRankingConfigurationPreconditionField)
  , ("postcondition", LengthRankingConfigurationPostconditionField)
  , ("providerLaws", LengthRankingConfigurationProviderLawsField)
  ]
 where
  targetRoleFields = case grammar of
    LengthContractGrammarV1 -> []
    LengthContractGrammarV2 -> []
    LengthContractGrammarV3 ->
      [ ( "targetArgumentRoles"
        , LengthRankingConfigurationTargetArgumentRolesField
        )
      ]
    LengthContractGrammarV4 ->
      [ ( "targetArgumentRoles"
        , LengthRankingConfigurationTargetArgumentRolesField
        )
      ]
    LengthContractGrammarV5 ->
      [ ( "targetArgumentRoles"
        , LengthRankingConfigurationTargetArgumentRolesField
        )
      ]
  casePolicyFields = case grammar of
    LengthContractGrammarV4 ->
      [ ( "candidateCasePolicy"
        , LengthRankingConfigurationCandidateCasePolicyField
        )
      ]
    LengthContractGrammarV5 ->
      [ ( "candidateCasePolicy"
        , LengthRankingConfigurationCandidateCasePolicyField
        )
      ]
    _ -> []

decodeCandidateCasePolicy
  :: LengthContractGrammar
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      LeanLengthCandidateCasePolicy
decodeCandidateCasePolicy grammar value = do
  let field = LengthRankingConfigurationCandidateCasePolicyField
  policy <- stringField field value
  case policy of
    "exact-spine-zero-step-v1" -> Right LeanLengthExactSpineZeroStepV1
    "cases-rejected"
      | grammar == LengthContractGrammarV5 -> Right LeanLengthCasesRejected
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
  :: LengthContractGrammar
  -> Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either LengthRankingConfigurationFileError [LeanLengthProviderLaw]
decodeProviderLaws _ _ _ [] = Right []
decodeProviderLaws grammar index usage (value : remaining) = do
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
  (transfer, afterTransfer) <- parseLengthExpression grammar
    (LengthRankingConfigurationProviderTransferSyntax index)
    (providerVariable $ fromIntegral $ length roles)
    1
    usage
    transferValue
  following <- decodeProviderLaws grammar (index + 1) afterTransfer remaining
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
  :: LengthContractGrammar
  -> LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthExpression variable, SyntaxUsage)
parseLengthExpression grammar phase decodeVariable depth usage value = do
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
        (parsed, afterTerms) <- parseExpressions grammar phase decodeVariable
          (depth + 1) afterNode terms
        Right (LengthSum parsed, afterTerms)
      "scale" -> do
        (factorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        factor <- boundedLiteral phase factorValue
        (expression, afterExpression) <- parseLengthExpression grammar
          phase decodeVariable (depth + 1) afterNode expressionValue
        Right (LengthScale factor expression, afterExpression)
      "modulo" | grammarSupportsModulo grammar -> do
        (divisorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        divisor <- boundedLiteral phase divisorValue
        if divisor == 0
          then syntax phase $ Left LengthRankingConfigurationModuloDivisorZero
          else do
            (expression, afterExpression) <- parseLengthExpression grammar
              phase decodeVariable (depth + 1) afterNode expressionValue
            Right (LengthModulo divisor expression, afterExpression)
      "quotient" | grammarSupportsQuotient grammar -> do
        (divisorValue, expressionValue) <- syntax phase
          $ twoArguments arguments
        divisor <- boundedLiteral phase divisorValue
        if divisor == 0
          then syntax phase $ Left LengthRankingConfigurationQuotientDivisorZero
          else do
            (expression, afterExpression) <- parseLengthExpression grammar
              phase decodeVariable (depth + 1) afterNode expressionValue
            Right (LengthQuotient divisor expression, afterExpression)
      "monus" -> parseBinaryExpression arguments afterNode LengthMonus
      "minimum" -> parseBinaryExpression arguments afterNode LengthMinimum
      "maximum" -> parseBinaryExpression arguments afterNode LengthMaximum
      "if" -> do
        (conditionValue, trueValue, falseValue) <- syntax phase
          $ threeArguments arguments
        (condition, afterCondition) <- parseLengthFormula grammar
          phase decodeVariable (depth + 1) afterNode conditionValue
        (trueBranch, afterTrue) <- parseLengthExpression grammar
          phase decodeVariable (depth + 1) afterCondition trueValue
        (falseBranch, afterFalse) <- parseLengthExpression grammar
          phase decodeVariable (depth + 1) afterTrue falseValue
        Right (LengthIf condition trueBranch falseBranch, afterFalse)
      _ -> syntax phase $ Left LengthRankingConfigurationUnknownTag
 where
  parseBinaryExpression arguments afterNode constructor = do
    (leftValue, rightValue) <- syntax phase $ twoArguments arguments
    (left, afterLeft) <- parseLengthExpression grammar
      phase decodeVariable (depth + 1) afterNode leftValue
    (right, afterRight) <- parseLengthExpression grammar
      phase decodeVariable (depth + 1) afterLeft rightValue
    Right (constructor left right, afterRight)

grammarSupportsModulo :: LengthContractGrammar -> Bool
grammarSupportsModulo grammar = case grammar of
  LengthContractGrammarV1 -> False
  LengthContractGrammarV2 -> True
  LengthContractGrammarV3 -> True
  LengthContractGrammarV4 -> True
  LengthContractGrammarV5 -> True

grammarSupportsQuotient :: LengthContractGrammar -> Bool
grammarSupportsQuotient grammar = case grammar of
  LengthContractGrammarV1 -> False
  LengthContractGrammarV2 -> False
  LengthContractGrammarV3 -> False
  LengthContractGrammarV4 -> False
  LengthContractGrammarV5 -> True

parseExpressions
  :: LengthContractGrammar
  -> LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either
      LengthRankingConfigurationFileError
      ([LengthExpression variable], SyntaxUsage)
parseExpressions _ _ _ _ usage [] = Right ([], usage)
parseExpressions grammar phase decodeVariable depth usage (value : remaining) = do
  (expression, afterExpression) <- parseLengthExpression grammar
    phase decodeVariable depth usage value
  (following, afterFollowing) <- parseExpressions grammar
    phase decodeVariable depth afterExpression remaining
  Right (expression : following, afterFollowing)

parseLengthFormula
  :: LengthContractGrammar
  -> LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> BoundedJsonValue
  -> Either
      LengthRankingConfigurationFileError
      (LengthFormula variable, SyntaxUsage)
parseLengthFormula grammar phase decodeVariable depth usage value = do
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
      (formula, afterFormula) <- parseLengthFormula grammar
        phase decodeVariable (depth + 1) afterNode argument
      Right (LengthNot formula, afterFormula)
    "all" -> do
      argument <- syntax phase $ onlyArgument arguments
      formulas <- syntax phase $ syntaxArray argument
      syntaxCollection phase LengthRankingConfigurationAllClauses
        maximumSyntaxCollection formulas
      (parsed, afterFormulas) <- parseFormulas grammar phase decodeVariable
        (depth + 1) afterNode formulas
      Right (LengthAll parsed, afterFormulas)
    _ -> syntax phase $ Left LengthRankingConfigurationUnknownTag
 where
  parseComparison arguments afterNode constructor = do
    (leftValue, rightValue) <- syntax phase $ twoArguments arguments
    afterClause <- consumeClause phase afterNode
    (left, afterLeft) <- parseLengthExpression grammar
      phase decodeVariable (depth + 1) afterClause leftValue
    (right, afterRight) <- parseLengthExpression grammar
      phase decodeVariable (depth + 1) afterLeft rightValue
    Right (constructor left right, afterRight)

parseFormulas
  :: LengthContractGrammar
  -> LengthRankingConfigurationSyntaxPhase
  -> VariableDecoder variable
  -> Natural
  -> SyntaxUsage
  -> [BoundedJsonValue]
  -> Either
      LengthRankingConfigurationFileError
      ([LengthFormula variable], SyntaxUsage)
parseFormulas _ _ _ _ usage [] = Right ([], usage)
parseFormulas grammar phase decodeVariable depth usage (value : remaining) = do
  (formula, afterFormula) <- parseLengthFormula grammar
    phase decodeVariable depth usage value
  (following, afterFollowing) <- parseFormulas grammar
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
