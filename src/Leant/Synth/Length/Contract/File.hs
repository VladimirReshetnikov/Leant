{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded contract-only grammar for one synthesis request.
--
-- This document contains no executable, solver, replay, activation, or
-- process policy.  Its nested contract object is decoded by the same entrance
-- as the version-1 compatibility configuration, so the two file formats
-- cannot drift in name, provider-role, syntax, or resource-limit semantics.
module Leant.Synth.Length.Contract.File
  ( lengthContractFileFormat
  , lengthContractFileVersion
  , lengthContractFileJsonLimits
  , LengthContractFileField (..)
  , LengthContractFileValueType (..)
  , LengthContractFileError (..)
  , decodeLengthContractFile
  ) where

import Data.ByteString (ByteString)
import Data.List (find)
import Data.Text (Text)
import Numeric.Natural (Natural)

import Leant.Json.Bounded
  ( BoundedJsonError
  , BoundedJsonLimits
  , BoundedJsonValue (..)
  , parseBoundedJson
  )
import Leant.Synth.Length.Configuration.File
  ( LengthRankingConfigurationFileError
  , decodeLeanLengthContractValue
  , lengthRankingConfigurationFileJsonLimits
  )
import Leant.Synth.Length.Contract (LeanLengthContract)

lengthContractFileFormat :: Text
lengthContractFileFormat = "leant-finite-list-spine-length-contract"

lengthContractFileVersion :: Natural
lengthContractFileVersion = 1

-- | The contract-only format deliberately uses the compatibility grammar's
-- complete parser ceiling.  More specific contract limits still win at their
-- established maximum-plus-one observations.
lengthContractFileJsonLimits :: BoundedJsonLimits
lengthContractFileJsonLimits = lengthRankingConfigurationFileJsonLimits

data LengthContractFileField
  = LengthContractFileFormatField
  | LengthContractFileVersionField
  | LengthContractFileContractField
  deriving (Bounded, Enum, Eq, Ord, Show)

data LengthContractFileValueType
  = LengthContractFileObjectValue
  | LengthContractFileStringValue
  | LengthContractFileIntegerValue
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Sanitized contract-document rejection.  Unknown keys, source names,
-- syntax tags, paths, and input bytes are not retained.  Nested failures use
-- the existing closed contract grammar's payload-free taxonomy.
data LengthContractFileError
  = LengthContractFileJsonRejected !BoundedJsonError
  | LengthContractFileExpectedRootObject
  | LengthContractFileUnexpectedRootField
  | LengthContractFileMissingRootField !LengthContractFileField
  | LengthContractFileFieldTypeMismatch
      !LengthContractFileField !LengthContractFileValueType
  | LengthContractFileUnsupportedFormat
  | LengthContractFileUnsupportedVersion
  | LengthContractFileContractRejected
      !LengthRankingConfigurationFileError
  deriving (Eq, Ord, Show)

decodeLengthContractFile
  :: ByteString
  -> Either LengthContractFileError LeanLengthContract
decodeLengthContractFile bytes = do
  document <- either (Left . LengthContractFileJsonRejected) Right
    $ parseBoundedJson lengthContractFileJsonLimits bytes
  root <- case document of
    BoundedJsonObject fields -> Right fields
    _ -> Left LengthContractFileExpectedRootObject
  formatValue <- requiredField LengthContractFileFormatField "format" root
  format <- case formatValue of
    BoundedJsonString value -> Right value
    _ -> Left $ LengthContractFileFieldTypeMismatch
      LengthContractFileFormatField LengthContractFileStringValue
  if format == lengthContractFileFormat
    then pure ()
    else Left LengthContractFileUnsupportedFormat
  versionValue <- requiredField LengthContractFileVersionField "version" root
  version <- case versionValue of
    BoundedJsonInteger value -> Right value
    _ -> Left $ LengthContractFileFieldTypeMismatch
      LengthContractFileVersionField LengthContractFileIntegerValue
  if version == toInteger lengthContractFileVersion
    then pure ()
    else Left LengthContractFileUnsupportedVersion
  case find (not . permitted . fst) root of
    Nothing -> pure ()
    Just _ -> Left LengthContractFileUnexpectedRootField
  contractValue <- requiredField
    LengthContractFileContractField "contract" root
  case contractValue of
    BoundedJsonObject _ -> pure ()
    _ -> Left $ LengthContractFileFieldTypeMismatch
      LengthContractFileContractField LengthContractFileObjectValue
  either (Left . LengthContractFileContractRejected) Right
    $ decodeLeanLengthContractValue contractValue
 where
  permitted name = name `elem` ["format", "version", "contract"]

requiredField
  :: LengthContractFileField
  -> Text
  -> [(Text, BoundedJsonValue)]
  -> Either LengthContractFileError BoundedJsonValue
requiredField field name values = case lookup name values of
  Just value -> Right value
  Nothing -> Left $ LengthContractFileMissingRootField field
