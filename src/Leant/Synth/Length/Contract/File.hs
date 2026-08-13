{-# LANGUAGE OverloadedStrings #-}

-- | Closed, bounded contract-only grammar for one synthesis request.
--
-- This document contains no executable, solver, replay, activation, or
-- process policy. Version 1 reuses the exact compatibility grammar; version 2
-- adds positive-literal Natural modulo; version 3 additionally requires an
-- exact source-ordered target-role vector; version 4 requires an explicit
-- candidate-case policy. Names, provider roles, target roles, case semantics,
-- and resource limits therefore cannot drift.
module Leant.Synth.Length.Contract.File
  ( lengthContractFileFormat
  , lengthContractFileVersion
  , lengthContractFileModuloVersion
  , lengthContractFileTargetRolesVersion
  , lengthContractFileExactCaseVersion
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
  , decodeLeanLengthContractValueV2
  , decodeLeanLengthContractValueV3
  , decodeLeanLengthContractValueV4
  , lengthRankingConfigurationFileJsonLimits
  )
import Leant.Synth.Length.Contract (LeanLengthContract)

lengthContractFileFormat :: Text
lengthContractFileFormat = "leant-finite-list-spine-length-contract"

-- | The preserved base version, identical to the startup compatibility
-- contract grammar.
lengthContractFileVersion :: Natural
lengthContractFileVersion = 1

-- | Contract-only version 2 adds positive-literal Natural modulo while the
-- startup compatibility configuration remains fixed at version 1.
lengthContractFileModuloVersion :: Natural
lengthContractFileModuloVersion = 2

-- | Contract-only version 3 retains the version-2 expression grammar and
-- requires explicit observed-spine/unobserved-target roles for every physical
-- target argument. The startup compatibility configuration remains version 1.
lengthContractFileTargetRolesVersion :: Natural
lengthContractFileTargetRolesVersion = 3

-- | Contract-only version 4 retains the version-3 grammar and requires one
-- explicit closed candidate-case policy. This is the only file version which
-- can authorize the exact recursive zero/step spine case.
lengthContractFileExactCaseVersion :: Natural
lengthContractFileExactCaseVersion = 4

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
  decoder <- if version == toInteger lengthContractFileVersion
    then Right decodeLeanLengthContractValue
    else if version == toInteger lengthContractFileModuloVersion
      then Right decodeLeanLengthContractValueV2
      else if version == toInteger lengthContractFileTargetRolesVersion
        then Right decodeLeanLengthContractValueV3
        else if version == toInteger lengthContractFileExactCaseVersion
          then Right decodeLeanLengthContractValueV4
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
    $ decoder contractValue
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
