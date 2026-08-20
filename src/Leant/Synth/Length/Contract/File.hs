{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded contract-only grammar for one synthesis request.
--
-- The versionless document contains no executable, solver, replay,
-- activation, or process policy. Its required @rankingDomain@ field selects
-- the current nominal scalar or canonical binary-product contract grammar.
-- Superseded shapes live only in Git history.
module Leant.Synth.Length.Contract.File
  ( lengthContractFileFormat
  , lengthContractFileJsonLimits
  , LengthContractFileField (..)
  , LengthContractFileValueType (..)
  , LengthContractFileError (..)
  , decodeLengthContractFile
  ) where

import Data.ByteString (ByteString)
import Data.List (find)
import Data.Text (Text)

import Leant.Json.Bounded
  ( BoundedJsonError
  , BoundedJsonLimits
  , BoundedJsonValue (..)
  , parseBoundedJson
  )
import Leant.Synth.Length.Configuration.File
  ( LengthRankingConfigurationFileError
  , decodeLeanLengthContractValue
  , decodeLeanLengthSpinePairContractValue
  , lengthRankingConfigurationFileJsonLimits
  )
import Leant.Synth.Length.Contract
  ( LeanLengthContractSelection (..)
  )

-- | The exact @format@ string a contract-only document must carry.
lengthContractFileFormat :: Text
lengthContractFileFormat = "leant-finite-list-spine-length-contract"

-- | The contract-only format uses the complete current grammar's parser
-- ceiling. More specific contract limits still win at their established
-- maximum-plus-one observations.
lengthContractFileJsonLimits :: BoundedJsonLimits
lengthContractFileJsonLimits = lengthRankingConfigurationFileJsonLimits

-- | Which root field of the contract-only grammar a refusal names.
data LengthContractFileField
  = LengthContractFileFormatField
  | LengthContractFileRankingDomainField
  | LengthContractFileContractField
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | The JSON value shape a root field required when a type mismatch is
-- reported.
data LengthContractFileValueType
  = LengthContractFileObjectValue
  | LengthContractFileStringValue
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Sanitized contract-document rejection. Unknown keys, source names,
-- syntax tags, paths, and input bytes are not retained. Nested failures use
-- the shared current contract grammar's payload-free taxonomy.
data LengthContractFileError
  = LengthContractFileJsonRejected !BoundedJsonError
  | LengthContractFileExpectedRootObject
  | LengthContractFileUnexpectedRootField
  | LengthContractFileMissingRootField !LengthContractFileField
  | LengthContractFileFieldTypeMismatch
      !LengthContractFileField !LengthContractFileValueType
  | LengthContractFileFieldValueRejected !LengthContractFileField
  | LengthContractFileUnsupportedFormat
  | LengthContractFileContractRejected
      !LengthRankingConfigurationFileError
  deriving (Eq, Ord, Show)

data LengthContractFileRankingDomain
  = LengthContractFileScalarDomain
  | LengthContractFileBinaryProductDomain

-- | Decode the current passive nominal contract selection. Domain selection
-- is explicit and occurs after format admission but before the exact-root
-- check, so historical roots receive ordinary current-schema diagnostics.
-- The bounded JSON input is parsed exactly once and no fallback route exists.
decodeLengthContractFile
  :: ByteString
  -> Either LengthContractFileError LeanLengthContractSelection
decodeLengthContractFile bytes = do
  document <- either (Left . LengthContractFileJsonRejected) Right
    $ parseBoundedJson lengthContractFileJsonLimits bytes
  root <- case document of
    BoundedJsonObject fields -> Right fields
    _ -> Left LengthContractFileExpectedRootObject
  formatValue <- requiredField LengthContractFileFormatField "format" root
  format <- stringField LengthContractFileFormatField formatValue
  if format == lengthContractFileFormat
    then pure ()
    else Left LengthContractFileUnsupportedFormat
  domainValue <- requiredField
    LengthContractFileRankingDomainField "rankingDomain" root
  domainText <- stringField
    LengthContractFileRankingDomainField domainValue
  domain <- case domainText of
    "scalar" -> Right LengthContractFileScalarDomain
    "binary-product" -> Right LengthContractFileBinaryProductDomain
    _ -> Left $ LengthContractFileFieldValueRejected
      LengthContractFileRankingDomainField
  exactRoot root
  contractValue <- requiredField
    LengthContractFileContractField "contract" root
  case contractValue of
    BoundedJsonObject _ -> pure ()
    _ -> Left $ LengthContractFileFieldTypeMismatch
      LengthContractFileContractField LengthContractFileObjectValue
  either (Left . LengthContractFileContractRejected) Right
    $ case domain of
      LengthContractFileScalarDomain ->
        LeanLengthScalarContractSelection
          <$> decodeLeanLengthContractValue contractValue
      LengthContractFileBinaryProductDomain ->
        LeanLengthSpinePairContractSelection
          <$> decodeLeanLengthSpinePairContractValue contractValue

exactRoot
  :: [(Text, BoundedJsonValue)]
  -> Either LengthContractFileError ()
exactRoot fields = case find unexpected fields of
  Just _ -> Left LengthContractFileUnexpectedRootField
  Nothing -> case find missing rootFields of
    Just (_, field) -> Left $ LengthContractFileMissingRootField field
    Nothing -> Right ()
 where
  unexpected (name, _) = name `notElem` map fst rootFields
  missing (name, _) = name `notElem` map fst fields

rootFields :: [(Text, LengthContractFileField)]
rootFields =
  [ ("format", LengthContractFileFormatField)
  , ("rankingDomain", LengthContractFileRankingDomainField)
  , ("contract", LengthContractFileContractField)
  ]

requiredField
  :: LengthContractFileField
  -> Text
  -> [(Text, BoundedJsonValue)]
  -> Either LengthContractFileError BoundedJsonValue
requiredField field name values = case lookup name values of
  Just value -> Right value
  Nothing -> Left $ LengthContractFileMissingRootField field

stringField
  :: LengthContractFileField
  -> BoundedJsonValue
  -> Either LengthContractFileError Text
stringField field value = case value of
  BoundedJsonString textValue -> Right textValue
  _ -> Left $ LengthContractFileFieldTypeMismatch
    field LengthContractFileStringValue
