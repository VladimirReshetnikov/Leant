{-# LANGUAGE BangPatterns #-}

-- | Durable metadata and managed paths for REPL environment snapshots.
--
-- The upstream backend pickles Lean's command environment.  Leant can also
-- pickle a sibling synthesis-ready environment; the versioned sidecar binds
-- both artifacts to their content so an older companion is never paired with
-- a newly replaced user snapshot.
module Leant.Session.Snapshot
  ( SnapshotBase (..)
  , SnapshotCompanion (..)
  , SnapshotFingerprint (..)
  , SnapshotMetadata (..)
  , snapshotCompanionPath
  , snapshotMetadataPath
  , resolveSnapshotPath
  , fingerprintSnapshot
  , synthesisToolingABI
  , encodeSnapshotMetadata
  , decodeSnapshotMetadata
  ) where

import Data.Bits (xor)
import qualified Data.ByteString as BS
import Data.Char (isHexDigit, ord, toLower)
import qualified Data.List as List
import Data.Word (Word64)
import Numeric (showHex)
import System.FilePath ((</>), isAbsolute, normalise, takeFileName)
import System.IO (IOMode (ReadMode), withBinaryFile)

import Leant.Json
  ( JValue (..)
  , encodeJson
  , jLookup
  , jString
  , parseJson
  )

-- | A session-owned copy of an unpickled base.  Backend environment ids die
-- with the process; these files are the durable restart source for the life
-- of the Leant process.  The source path is retained only for diagnostics.
data SnapshotBase = SnapshotBase
  { snapshotSourcePath :: FilePath
  , snapshotEnvironmentPath :: FilePath
  , snapshotToolingPath :: Maybe FilePath
  , snapshotBaseItCounter :: Int
  }
  deriving (Eq, Show)

-- | A cheap content identity for an opaque backend artifact.  FNV-1a is not
-- used as a security primitive; it prevents accidental pairing with a stale
-- sibling while keeping the snapshot layer dependency-light and streaming.
data SnapshotFingerprint = SnapshotFingerprint
  { snapshotByteCount :: Integer
  , snapshotFNV1a64 :: String
  }
  deriving (Eq, Show)

-- | The synthesis-ready sibling pickled beside a main snapshot, bound to
-- its content fingerprint and to the tooling ABI that produced it.
data SnapshotCompanion = SnapshotCompanion
  { snapshotCompanionFile :: FilePath
  , snapshotCompanionFingerprint :: SnapshotFingerprint
  , snapshotCompanionABI :: String
  }
  deriving (Eq, Show)

-- | The JSON sidecar written beside a main snapshot: the @it@ counter to
-- restore, the main artifact's fingerprint, and the optional synthesis
-- companion.
data SnapshotMetadata = SnapshotMetadata
  { snapshotItCounter :: Int
  , snapshotMainFingerprint :: SnapshotFingerprint
  , snapshotSynthesisCompanion :: Maybe SnapshotCompanion
  }
  deriving (Eq, Show)

-- | Path of the synthesis companion snapshot beside a main @.olean@.
snapshotCompanionPath :: FilePath -> FilePath
snapshotCompanionPath path = snapshotStem path ++ ".leant-synth.olean"

-- | Path of the JSON metadata sidecar beside a main @.olean@.
snapshotMetadataPath :: FilePath -> FilePath
snapshotMetadataPath path = snapshotStem path ++ ".leant.json"

-- | The backend runs in the Lake project rather than necessarily in Leant's
-- own process directory.  Resolve once and use the same absolute spelling for
-- backend requests and Haskell-side metadata I/O.
resolveSnapshotPath :: FilePath -> FilePath -> FilePath
resolveSnapshotPath workingDirectory path = normalise $
  if isAbsolute path then path else workingDirectory </> path

snapshotStem :: FilePath -> FilePath
snapshotStem path
  | length path >= length extension
  , drop (length path - length extension) path == extension =
      take (length path - length extension) path
  | otherwise = path
 where
  extension = ".olean"

-- | Stream a snapshot file once, producing its byte count and FNV-1a hash.
fingerprintSnapshot :: FilePath -> IO SnapshotFingerprint
fingerprintSnapshot path = withBinaryFile path ReadMode (go fnvOffset 0)
 where
  go !hash !count handle = do
    chunk <- BS.hGetSome handle (64 * 1024)
    if BS.null chunk
      then pure SnapshotFingerprint
        { snapshotByteCount = count
        , snapshotFNV1a64 = word64Hex hash
        }
      else go (BS.foldl' fnvStep hash chunk)
        (count + toInteger (BS.length chunk)) handle

  fnvStep hash byte = (hash `xor` fromIntegral byte) * fnvPrime

fnvOffset, fnvPrime :: Word64
fnvOffset = 14695981039346656037
fnvPrime = 1099511628211

word64Hex :: Word64 -> String
word64Hex value = replicate (16 - length rendered) '0' ++ rendered
 where
  rendered = showHex value ""

-- | Cache identity for the exact serializer source understood by this Leant
-- build.  It is not a security hash; any source change invalidates an older
-- synthesis companion and falls back to rebuilding tooling over the main
-- snapshot.
synthesisToolingABI :: String -> String
synthesisToolingABI source = "leant-synth-fnv1a64-"
  ++ word64Hex (List.foldl' step fnvOffset source)
 where
  step hash character =
    (hash `xor` fromIntegral (ord character)) * fnvPrime

-- | Render the versioned sidecar document written next to a pickled
-- snapshot.  'decodeSnapshotMetadata' reads exactly this format back.
encodeSnapshotMetadata :: SnapshotMetadata -> String
encodeSnapshotMetadata metadata = encodeJson $ JObj
  [ ("format", JStr "leant-snapshot")
  , ("version", JInt 1)
  , ("itCounter", JInt (toInteger (snapshotItCounter metadata)))
  , ("main", encodeFingerprint (snapshotMainFingerprint metadata))
  , ("synthesisCompanion", maybe JNull encodeCompanion
      (snapshotSynthesisCompanion metadata))
  ]
 where
  encodeCompanion companion = JObj
    [ ("file", JStr (snapshotCompanionFile companion))
    , ("fingerprint", encodeFingerprint
        (snapshotCompanionFingerprint companion))
    , ("abi", JStr (snapshotCompanionABI companion))
    ]

  encodeFingerprint fingerprint = JObj
    [ ("bytes", JInt (snapshotByteCount fingerprint))
    , ("fnv1a64", JStr (snapshotFNV1a64 fingerprint))
    ]

-- | Parse and validate a sidecar document, rejecting unknown formats,
-- versions, and out-of-range counters with a short error description.
decodeSnapshotMetadata :: String -> Either String SnapshotMetadata
decodeSnapshotMetadata text = do
  value <- parseJson text
  format <- required "format" jString value
  version <- required "version" exactInteger value
  counter <- required "itCounter" exactInteger value
  mainValue <- requiredValue "main" value
  mainFingerprint <- decodeFingerprint "main" mainValue
  companion <- case jLookup "synthesisCompanion" value of
    Just JNull -> Right Nothing
    Just companionValue -> Just <$> decodeCompanion companionValue
    Nothing -> Left
      "missing or invalid snapshot metadata field `synthesisCompanion`"
  if format /= "leant-snapshot"
    then Left "unknown snapshot metadata format"
    else if version /= 1
      then Left ("unsupported snapshot metadata version " ++ show version)
      else if counter < 0 || counter >= toInteger (maxBound :: Int)
        then Left "snapshot it-counter is out of range"
        else Right SnapshotMetadata
          { snapshotItCounter = fromInteger counter
          , snapshotMainFingerprint = mainFingerprint
          , snapshotSynthesisCompanion = companion
          }
 where
  decodeCompanion object = do
    file <- required "file" jString object
    fingerprintValue <- requiredValue "fingerprint" object
    fingerprint <- decodeFingerprint
      "synthesisCompanion.fingerprint" fingerprintValue
    abi <- required "abi" jString object
    if null file || takeFileName file /= file || file `elem` [".", ".."]
      then Left "snapshot companion path must be a sibling filename"
      else if null abi
        then Left "snapshot companion ABI must not be empty"
      else Right SnapshotCompanion
        { snapshotCompanionFile = file
        , snapshotCompanionFingerprint = fingerprint
        , snapshotCompanionABI = abi
        }

  decodeFingerprint label object = do
    bytes <- required "bytes" exactInteger object
    hash <- required "fnv1a64" jString object
    if bytes < 0
      then Left (label ++ " byte count is out of range")
      else if length hash /= 16 || not (all isHexDigit hash)
        then Left (label ++ " FNV-1a fingerprint is invalid")
        else Right SnapshotFingerprint
          { snapshotByteCount = bytes
          , snapshotFNV1a64 = map toLower hash
          }

  required name project object = case jLookup name object >>= project of
    Just result -> Right result
    Nothing -> Left ("missing or invalid snapshot metadata field `"
      ++ name ++ "`")

  requiredValue name object = case jLookup name object of
    Just result -> Right result
    Nothing -> Left ("missing or invalid snapshot metadata field `"
      ++ name ++ "`")

  exactInteger (JInt value) = Just value
  exactInteger _ = Nothing
