{-# LANGUAGE BangPatterns #-}

-- | Strict, resource-bounded JSON for authority-bearing configuration.
--
-- The older 'Leant.Json' module intentionally remains the small permissive
-- codec used by the Lean REPL protocol.  This module is a separate trust
-- boundary: it accepts strict UTF-8, implements the exact JSON number and
-- string grammars, rejects duplicate object keys, and never retains source
-- snippets in errors.
module Leant.Json.Bounded
  ( BoundedJsonLimits (..)
  , BoundedJsonLimit (..)
  , BoundedJsonErrorKind (..)
  , BoundedJsonError (..)
  , BoundedJsonValue (..)
  , parseBoundedJson
  ) where

import qualified Data.ByteString as BS
import Data.ByteString (ByteString)
import Data.Char (chr, ord)
import qualified Data.Set as Set
import qualified Data.Text as Text
import Data.Text (Text)
import qualified Data.Text.Encoding as Text
import Data.Word (Word8)
import Numeric.Natural (Natural)

-- | Independent hard limits for one complete JSON document.
--
-- Every collection limit is per collection; the node limit is cumulative.
-- Object keys have their own byte limit because schema dispatch must retain
-- them before it can decide whether they are known.
data BoundedJsonLimits = BoundedJsonLimits
  { boundedJsonMaximumTotalBytes :: Natural
  , boundedJsonMaximumNestingDepth :: Natural
  , boundedJsonMaximumNodes :: Natural
  , boundedJsonMaximumObjectMembers :: Natural
  , boundedJsonMaximumArrayElements :: Natural
  , boundedJsonMaximumObjectKeyUtf8Bytes :: Natural
  , boundedJsonMaximumStringUtf8Bytes :: Natural
  , boundedJsonMaximumStringUnicodeScalars :: Natural
  , boundedJsonMaximumNumberBytes :: Natural
  }
  deriving (Eq, Ord, Show)

-- | Which 'BoundedJsonLimits' bound a document exceeded.
data BoundedJsonLimit
  = BoundedJsonTotalBytes
  | BoundedJsonNestingDepth
  | BoundedJsonNodes
  | BoundedJsonObjectMembers
  | BoundedJsonArrayElements
  | BoundedJsonObjectKeyUtf8Bytes
  | BoundedJsonStringUtf8Bytes
  | BoundedJsonStringUnicodeScalars
  | BoundedJsonNumberBytes
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed syntax classifications.  No constructor retains child-controlled
-- text, object keys, numbers, or source bytes.
data BoundedJsonErrorKind
  = BoundedJsonUTF8BOM
  | BoundedJsonInvalidUTF8
  | BoundedJsonUnexpectedEnd
  | BoundedJsonUnexpectedToken
  | BoundedJsonTrailingContent
  | BoundedJsonExpectedObjectKey
  | BoundedJsonExpectedColon
  | BoundedJsonExpectedObjectDelimiter
  | BoundedJsonExpectedArrayDelimiter
  | BoundedJsonUnterminatedString
  | BoundedJsonRawControlCharacter
  | BoundedJsonInvalidEscape
  | BoundedJsonInvalidUnicodeEscape
  | BoundedJsonLoneSurrogate
  | BoundedJsonInvalidNumber
  | BoundedJsonDuplicateObjectKey
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Sanitized parse rejection.  A limit refusal carries the limit, its
-- maximum, the observed count saturated at maximum plus one, and the byte
-- offset reached; a syntax refusal carries its closed kind and byte offset.
-- No document text is retained.
data BoundedJsonError
  = BoundedJsonLimitExceeded
      !BoundedJsonLimit !Natural !Natural !Natural
  | BoundedJsonSyntaxRejected
      !BoundedJsonErrorKind !Natural
  deriving (Eq, Ord, Show)

-- | Exact bounded tree.  Integral numbers retain their arbitrary-precision
-- value.  Non-integral JSON numbers retain the exact bounded lexical spelling
-- rather than being rounded through 'Double'.
data BoundedJsonValue
  = BoundedJsonNull
  | BoundedJsonBool !Bool
  | BoundedJsonInteger !Integer
  | BoundedJsonNonInteger !Text
  | BoundedJsonString !Text
  | BoundedJsonArray [BoundedJsonValue]
  | BoundedJsonObject [(Text, BoundedJsonValue)]
  deriving (Eq, Ord, Show)

data ParserState = ParserState
  { parserRemaining :: String
  , parserByteOffset :: !Natural
  , parserNodeCount :: !Natural
  }

type Parser value =
  ParserState -> Either BoundedJsonError (value, ParserState)

-- | Parse one complete strict UTF-8 JSON document within all supplied limits.
--
-- The strict 'ByteString' has already been acquired by the caller.  This
-- function bounds all decoding and retention but deliberately makes no claim
-- about how a future file loader acquires those bytes.
parseBoundedJson
  :: BoundedJsonLimits
  -> ByteString
  -> Either BoundedJsonError BoundedJsonValue
parseBoundedJson limits bytes = do
  admitTotalBytes
  case validateUtf8 bytes of
    Left offset -> Left $ syntaxError BoundedJsonInvalidUTF8 offset
    Right () -> Right ()
  decoded <- case Text.decodeUtf8' bytes of
    Left _ -> Left $ syntaxError BoundedJsonInvalidUTF8 0
    Right text -> Right text
  case Text.uncons decoded of
    Just ('\xfeff', _) -> Left $ syntaxError BoundedJsonUTF8BOM 0
    _ -> Right ()
  let initial = ParserState (Text.unpack decoded) 0 0
  (result, afterValue) <- parseValue limits 0 $ skipWhitespace initial
  let terminal = skipWhitespace afterValue
  case parserRemaining terminal of
    [] -> Right result
    _ -> Left $ syntaxAt BoundedJsonTrailingContent terminal
 where
  admitTotalBytes =
    let maximumBytes = boundedJsonMaximumTotalBytes limits
        actualBytes = fromIntegral $ BS.length bytes
    in if actualBytes <= maximumBytes
        then Right ()
        else Left $ limitError BoundedJsonTotalBytes maximumBytes maximumBytes

parseValue :: BoundedJsonLimits -> Natural -> Parser BoundedJsonValue
parseValue limits depth state = case parserRemaining state of
  [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
  character : _ | not (startsJsonValue character) ->
    Left $ syntaxAt BoundedJsonUnexpectedToken state
  '{' : _ -> do
    nested <- admitDepth limits (depth + 1) state
    charged <- chargeNode limits nested
    parseObject limits (depth + 1) charged
  '[' : _ -> do
    nested <- admitDepth limits (depth + 1) state
    charged <- chargeNode limits nested
    parseArray limits (depth + 1) charged
  '"' : _ -> do
    charged <- chargeNode limits state
    (value, afterString) <- parseString limits StringValue charged
    Right (BoundedJsonString value, afterString)
  't' : _ -> chargeNode limits state >>=
    parseKeyword "true" (BoundedJsonBool True)
  'f' : _ -> chargeNode limits state >>=
    parseKeyword "false" (BoundedJsonBool False)
  'n' : _ -> chargeNode limits state >>=
    parseKeyword "null" BoundedJsonNull
  _ -> chargeNode limits state >>= parseNumber limits

parseObject :: BoundedJsonLimits -> Natural -> Parser BoundedJsonValue
parseObject limits depth state0 = do
  state1 <- consumeExpected '{' state0
  let state = skipWhitespace state1
  case parserRemaining state of
    '}' : _ -> do
      after <- consumeExpected '}' state
      Right (BoundedJsonObject [], after)
    _ -> members 0 Set.empty [] state
 where
  members !count !seen !reversed state
    | count >= boundedJsonMaximumObjectMembers limits =
        Left $ limitError BoundedJsonObjectMembers
          (boundedJsonMaximumObjectMembers limits)
          (parserByteOffset state)
    | otherwise = case parserRemaining state of
        '"' : _ -> do
          (key, afterKey) <- parseString limits ObjectKey state
          if Set.member key seen
            then Left $ syntaxAt BoundedJsonDuplicateObjectKey afterKey
            else do
              afterColon <- case parserRemaining $ skipWhitespace afterKey of
                ':' : _ -> consumeExpected ':' $ skipWhitespace afterKey
                [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd
                  $ skipWhitespace afterKey
                _ -> Left $ syntaxAt BoundedJsonExpectedColon
                  $ skipWhitespace afterKey
              (value, afterValue) <- parseValue limits depth
                $ skipWhitespace afterColon
              let after = skipWhitespace afterValue
                  retained = (key, value) : reversed
                  nextCount = count + 1
                  nextSeen = Set.insert key seen
              case parserRemaining after of
                ',' : _ -> do
                  next <- consumeExpected ',' after
                  let ready = skipWhitespace next
                  case parserRemaining ready of
                    [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd ready
                    '}' : _ -> Left $ syntaxAt
                      BoundedJsonExpectedObjectKey ready
                    _ -> members nextCount nextSeen retained ready
                '}' : _ -> do
                  terminal <- consumeExpected '}' after
                  Right (BoundedJsonObject $ reverse retained, terminal)
                [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd after
                _ -> Left $ syntaxAt BoundedJsonExpectedObjectDelimiter after
        [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
        _ -> Left $ syntaxAt BoundedJsonExpectedObjectKey state

parseArray :: BoundedJsonLimits -> Natural -> Parser BoundedJsonValue
parseArray limits depth state0 = do
  state1 <- consumeExpected '[' state0
  let state = skipWhitespace state1
  case parserRemaining state of
    ']' : _ -> do
      after <- consumeExpected ']' state
      Right (BoundedJsonArray [], after)
    _ -> elements 0 [] state
 where
  elements !count !reversed state
    | count >= boundedJsonMaximumArrayElements limits =
        Left $ limitError BoundedJsonArrayElements
          (boundedJsonMaximumArrayElements limits)
          (parserByteOffset state)
    | otherwise = do
        (value, afterValue) <- parseValue limits depth state
        let after = skipWhitespace afterValue
            retained = value : reversed
            nextCount = count + 1
        case parserRemaining after of
          ',' : _ -> do
            next <- consumeExpected ',' after
            let ready = skipWhitespace next
            case parserRemaining ready of
              [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd ready
              ']' : _ -> Left $ syntaxAt BoundedJsonUnexpectedToken ready
              _ -> elements nextCount retained ready
          ']' : _ -> do
            terminal <- consumeExpected ']' after
            Right (BoundedJsonArray $ reverse retained, terminal)
          [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd after
          _ -> Left $ syntaxAt BoundedJsonExpectedArrayDelimiter after

data StringSite = ObjectKey | StringValue

parseString :: BoundedJsonLimits -> StringSite -> Parser Text
parseString limits site state0 = do
  state <- consumeExpected '"' state0
  characters [] 0 0 state
 where
  characters reversed !scalarCount !byteCount state =
    case parserRemaining state of
      [] -> Left $ syntaxAt BoundedJsonUnterminatedString state
      '"' : _ -> do
        terminal <- consumeExpected '"' state
        Right (Text.pack $ reverse reversed, terminal)
      '\\' : _ -> do
        afterSlash <- consumeExpected '\\' state
        (character, afterEscape) <- escapedCharacter afterSlash
        retain character reversed scalarCount byteCount
          (parserByteOffset state) afterEscape
      character : _
        | ord character < 0x20 ->
            Left $ syntaxAt BoundedJsonRawControlCharacter state
        | isSurrogate character ->
            Left $ syntaxAt BoundedJsonLoneSurrogate state
        | otherwise -> do
            after <- consumeCharacter state
            retain character reversed scalarCount byteCount
              (parserByteOffset state) after

  retain character reversed scalarCount byteCount errorOffset state =
    let nextScalars = scalarCount + 1
        nextBytes = byteCount + utf8CharacterBytes character
        maximumScalars = boundedJsonMaximumStringUnicodeScalars limits
        (byteLimit, maximumBytes) = case site of
          ObjectKey ->
            ( BoundedJsonObjectKeyUtf8Bytes
            , boundedJsonMaximumObjectKeyUtf8Bytes limits
            )
          StringValue ->
            ( BoundedJsonStringUtf8Bytes
            , boundedJsonMaximumStringUtf8Bytes limits
            )
        scalarLimitApplies = case site of
          ObjectKey -> False
          StringValue -> True
    in if scalarLimitApplies && nextScalars > maximumScalars
        then Left $ limitError BoundedJsonStringUnicodeScalars maximumScalars
          errorOffset
        else if nextBytes > maximumBytes
          then Left $ limitError byteLimit maximumBytes
            errorOffset
          else characters (character : reversed) nextScalars nextBytes state

  escapedCharacter state = case parserRemaining state of
    [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
    '"' : _ -> escapedSimple '"' state
    '\\' : _ -> escapedSimple '\\' state
    '/' : _ -> escapedSimple '/' state
    'b' : _ -> escapedSimple '\b' state
    'f' : _ -> escapedSimple '\f' state
    'n' : _ -> escapedSimple '\n' state
    'r' : _ -> escapedSimple '\r' state
    't' : _ -> escapedSimple '\t' state
    'u' : _ -> do
      afterU <- consumeExpected 'u' state
      (firstCode, afterFirst) <- unicodeEscape afterU
      if isHighSurrogateCode firstCode
        then do
          afterSlash <- case parserRemaining afterFirst of
            '\\' : _ -> consumeExpected '\\' afterFirst
            _ -> Left $ syntaxAt BoundedJsonLoneSurrogate afterFirst
          afterSecondU <- case parserRemaining afterSlash of
            'u' : _ -> consumeExpected 'u' afterSlash
            _ -> Left $ syntaxAt BoundedJsonLoneSurrogate afterSlash
          (secondCode, afterSecond) <- unicodeEscape afterSecondU
          if isLowSurrogateCode secondCode
            then let codePoint = 0x10000
                      + ((firstCode - 0xd800) * 0x400)
                      + (secondCode - 0xdc00)
              in Right (chr codePoint, afterSecond)
            else Left $ syntaxAt BoundedJsonLoneSurrogate afterSecond
        else if isLowSurrogateCode firstCode
          then Left $ syntaxAt BoundedJsonLoneSurrogate afterFirst
          else Right (chr firstCode, afterFirst)
    _ -> Left $ syntaxAt BoundedJsonInvalidEscape state

  escapedSimple character state = do
    after <- consumeCharacter state
    Right (character, after)

  unicodeEscape
    :: ParserState
    -> Either BoundedJsonError (Int, ParserState)
  unicodeEscape = digits 4 0
   where
    digits
      :: Int
      -> Int
      -> ParserState
      -> Either BoundedJsonError (Int, ParserState)
    digits 0 !value state = Right (value, state)
    digits remaining !value state = case parserRemaining state of
      character : _ -> case hexDigit character of
        Nothing -> Left $ syntaxAt BoundedJsonInvalidUnicodeEscape state
        Just digit -> do
          after <- consumeCharacter state
          digits (remaining - 1) (value * 16 + digit) after
      [] -> Left $ syntaxAt BoundedJsonInvalidUnicodeEscape state

parseNumber :: BoundedJsonLimits -> Parser BoundedJsonValue
parseNumber limits state0 = do
  (token, after) <- numberToken [] 0 state0
  case classifyNumber token of
    Nothing -> Left $ syntaxAt BoundedJsonInvalidNumber state0
    Just IntegralNumber -> case reads token :: [(Integer, String)] of
      [(integer, "")] -> Right (BoundedJsonInteger integer, after)
      _ -> Left $ syntaxAt BoundedJsonInvalidNumber state0
    Just NonIntegralNumber ->
      Right (BoundedJsonNonInteger $ Text.pack token, after)
 where
  maximumBytes = boundedJsonMaximumNumberBytes limits

  numberToken reversed !count state = case parserRemaining state of
    character : _ | isNumberCharacter character ->
      let nextCount = count + 1
      in if nextCount > maximumBytes
          then Left $ limitError BoundedJsonNumberBytes maximumBytes
            $ parserByteOffset state
          else do
            after <- consumeCharacter state
            numberToken (character : reversed) nextCount after
    _ -> Right (reverse reversed, state)

data NumberClass = IntegralNumber | NonIntegralNumber

classifyNumber :: String -> Maybe NumberClass
classifyNumber source = do
  (fractional, remaining) <- integerPart source
  (hasFraction, afterFraction) <- fractionPart remaining
  (hasExponent, terminal) <- exponentPart afterFraction
  if null terminal
    then Just $ if fractional || hasFraction || hasExponent
      then NonIntegralNumber
      else IntegralNumber
    else Nothing
 where
  -- The first component is retained for clarity: JSON's leading minus does
  -- not itself make a number non-integral.
  integerPart characters =
    let unsigned = case characters of
          '-' : rest -> rest
          _ -> characters
    in case unsigned of
      '0' : rest -> Just (False, rest)
      digit : rest | digit >= '1' && digit <= '9' ->
        Just (False, dropWhile isAsciiDigit rest)
      _ -> Nothing

  fractionPart ('.' : rest) = case span isAsciiDigit rest of
    ([], _) -> Nothing
    (_, remaining) -> Just (True, remaining)
  fractionPart remaining = Just (False, remaining)

  exponentPart (marker : rest) | marker == 'e' || marker == 'E' =
    let unsigned = case rest of
          '+' : following -> following
          '-' : following -> following
          _ -> rest
    in case span isAsciiDigit unsigned of
      ([], _) -> Nothing
      (_, remaining) -> Just (True, remaining)
  exponentPart remaining = Just (False, remaining)

parseKeyword :: String -> BoundedJsonValue -> Parser BoundedJsonValue
parseKeyword keyword result = go keyword
 where
  go [] state = Right (result, state)
  go (expected : remaining) state = case parserRemaining state of
    actual : _ | actual == expected ->
      consumeCharacter state >>= go remaining
    [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
    _ -> Left $ syntaxAt BoundedJsonUnexpectedToken state

admitDepth
  :: BoundedJsonLimits
  -> Natural
  -> ParserState
  -> Either BoundedJsonError ParserState
admitDepth limits depth state
  | depth <= boundedJsonMaximumNestingDepth limits = Right state
  | otherwise = Left $ limitError BoundedJsonNestingDepth
      (boundedJsonMaximumNestingDepth limits)
      (parserByteOffset state)

chargeNode
  :: BoundedJsonLimits
  -> ParserState
  -> Either BoundedJsonError ParserState
chargeNode limits state
  | parserNodeCount state < boundedJsonMaximumNodes limits =
      Right state { parserNodeCount = parserNodeCount state + 1 }
  | otherwise = Left $ limitError BoundedJsonNodes
      (boundedJsonMaximumNodes limits)
      (parserByteOffset state)

skipWhitespace :: ParserState -> ParserState
skipWhitespace state = case parserRemaining state of
  character : _ | isJsonWhitespace character ->
    skipWhitespace $ consumeCharacterPure state
  _ -> state

consumeExpected
  :: Char
  -> ParserState
  -> Either BoundedJsonError ParserState
consumeExpected expected state = case parserRemaining state of
  actual : _ | actual == expected -> Right $ consumeCharacterPure state
  [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
  _ -> Left $ syntaxAt BoundedJsonUnexpectedToken state

consumeCharacter
  :: ParserState
  -> Either BoundedJsonError ParserState
consumeCharacter state = case parserRemaining state of
  [] -> Left $ syntaxAt BoundedJsonUnexpectedEnd state
  _ -> Right $ consumeCharacterPure state

consumeCharacterPure :: ParserState -> ParserState
consumeCharacterPure state = case parserRemaining state of
  character : remaining -> state
    { parserRemaining = remaining
    , parserByteOffset = parserByteOffset state
        + utf8CharacterBytes character
    }
  [] -> state

syntaxError :: BoundedJsonErrorKind -> Natural -> BoundedJsonError
syntaxError = BoundedJsonSyntaxRejected

syntaxAt :: BoundedJsonErrorKind -> ParserState -> BoundedJsonError
syntaxAt kind = syntaxError kind . parserByteOffset

limitError
  :: BoundedJsonLimit
  -> Natural
  -> Natural
  -> BoundedJsonError
limitError limit maximumValue offset = BoundedJsonLimitExceeded
  limit maximumValue (saturatedSuccessor maximumValue) offset

saturatedSuccessor :: Natural -> Natural
saturatedSuccessor value = value + 1

isJsonWhitespace :: Char -> Bool
isJsonWhitespace character = character == ' '
  || character == '\t'
  || character == '\n'
  || character == '\r'

isAsciiDigit :: Char -> Bool
isAsciiDigit character = character >= '0' && character <= '9'

startsJsonValue :: Char -> Bool
startsJsonValue character = character == '{'
  || character == '['
  || character == '"'
  || character == 't'
  || character == 'f'
  || character == 'n'
  || character == '-'
  || isAsciiDigit character

isNumberCharacter :: Char -> Bool
isNumberCharacter character = isAsciiDigit character
  || character == '-'
  || character == '+'
  || character == '.'
  || character == 'e'
  || character == 'E'

hexDigit :: Char -> Maybe Int
hexDigit character
  | character >= '0' && character <= '9' =
      Just $ ord character - ord '0'
  | character >= 'a' && character <= 'f' =
      Just $ ord character - ord 'a' + 10
  | character >= 'A' && character <= 'F' =
      Just $ ord character - ord 'A' + 10
  | otherwise = Nothing

isSurrogate :: Char -> Bool
isSurrogate character =
  let codePoint = ord character
  in isHighSurrogateCode codePoint || isLowSurrogateCode codePoint

isHighSurrogateCode, isLowSurrogateCode :: Int -> Bool
isHighSurrogateCode codePoint = codePoint >= 0xd800 && codePoint <= 0xdbff
isLowSurrogateCode codePoint = codePoint >= 0xdc00 && codePoint <= 0xdfff

utf8CharacterBytes :: Char -> Natural
utf8CharacterBytes character
  | codePoint <= 0x7f = 1
  | codePoint <= 0x7ff = 2
  | codePoint <= 0xffff = 3
  | otherwise = 4
 where
 codePoint = ord character

-- | Validate strict RFC 3629 UTF-8 and return the first offending byte.
-- Overlong encodings, encoded surrogates, code points above U+10FFFF, and
-- truncated sequences are rejected before 'Text' allocation.  A truncated
-- sequence is attributed to its leading byte; a malformed continuation is
-- attributed to that continuation byte.
validateUtf8 :: ByteString -> Either Natural ()
validateUtf8 bytes = go 0
 where
  size = BS.length bytes

  go !index
    | index >= size = Right ()
    | otherwise = case BS.index bytes index of
        first
          | first <= 0x7f -> go (index + 1)
          | first >= 0xc2 && first <= 0xdf ->
              two index first 0x80 0xbf
          | first == 0xe0 -> three index first 0xa0 0xbf
          | first >= 0xe1 && first <= 0xec ->
              three index first 0x80 0xbf
          | first == 0xed -> three index first 0x80 0x9f
          | first >= 0xee && first <= 0xef ->
              three index first 0x80 0xbf
          | first == 0xf0 -> four index first 0x90 0xbf
          | first >= 0xf1 && first <= 0xf3 ->
              four index first 0x80 0xbf
          | first == 0xf4 -> four index first 0x80 0x8f
          | otherwise -> invalid index

  two index _ lower upper = do
    continuation index (index + 1) lower upper
    go $ index + 2

  three index _ lower upper = do
    continuation index (index + 1) lower upper
    continuation index (index + 2) 0x80 0xbf
    go $ index + 3

  four index _ lower upper = do
    continuation index (index + 1) lower upper
    continuation index (index + 2) 0x80 0xbf
    continuation index (index + 3) 0x80 0xbf
    go $ index + 4

  continuation lead index lower upper
    | index >= size = invalid lead
    | otherwise =
        let byte = BS.index bytes index
        in if within lower upper byte
            then Right ()
            else invalid index

  within :: Word8 -> Word8 -> Word8 -> Bool
  within lower upper byte = byte >= lower && byte <= upper

  invalid = Left . fromIntegral
