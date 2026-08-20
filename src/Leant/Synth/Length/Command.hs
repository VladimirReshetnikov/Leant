-- | Pure parsing for the request-scoped @:synth@ Length behavior options.
--
-- Ordinary goals remain opaque, delimiter-free text.  Once an exact current
-- option token is recognized, the standalone @--@ delimiter is mandatory.
-- The established parser keeps its fixed behavior-mode/contract order.  The
-- additive inline parser is deliberately separate and passive until Main has
-- authorized and resolved the request in a later checkpoint.
module Leant.Synth.Length.Command
  ( LengthBehaviorMode (..)
  , LengthSynthCommand (..)
  , LengthSynthCommandError (..)
  , parseLengthSynthCommand
  , LengthSynthInlineCommand
  , LengthSynthInlineCommandError (..)
  , lengthSynthInlineCommandWherePlan
  , lengthSynthInlineCommandGoal
  , parseLengthSynthInlineCommand
  ) where

import Data.Char (isSpace)
import Data.List (stripPrefix)
import Numeric.Natural (Natural)

import Leant.Synth.Length.Where
  ( LeanLengthWhereInputSourceError (..)
  , LeanLengthWhereModel (..)
  , LeanLengthWherePlan
  , mkLeanLengthWherePlan
  , parseLeanLengthWhereInputSource
  )

-- | Closed behavior-changing authority understood by the current Length
-- integration.  Ranking retains every verified candidate; filtering may
-- remove only candidates carrying adapter-authorized replay evidence.
data LengthBehaviorMode
  = LengthBehaviorRank
  | LengthBehaviorFilter
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One parsed @:synth@ argument line: the behavior mode (ranking unless
-- @--behavior-mode filter@ was given), the optional request-scoped Length
-- contract path, and the remaining goal text.  Path and goal are already
-- trimmed of surrounding whitespace.
data LengthSynthCommand = LengthSynthCommand
  { lengthSynthCommandBehaviorMode :: !LengthBehaviorMode
  , lengthSynthCommandContractPath :: Maybe FilePath
    -- ^ present exactly when the line named @--length-contract@
  , lengthSynthCommandGoal :: String
    -- ^ opaque Lean goal text; never inspected by this module
  }
  deriving (Eq, Show)

-- | Why a line beginning with @--behavior-mode@ or @--length-contract@ was
-- refused.  A line without either option never fails.
data LengthSynthCommandError
  = LengthSynthCommandBehaviorModeMissing
    -- ^ @--behavior-mode@ was not followed by a mode word
  | LengthSynthCommandBehaviorModeInvalid
    -- ^ the mode word was neither @rank@ nor @filter@
  | LengthSynthCommandDelimiterMissing
    -- ^ an option was recognized but no standalone @--@ delimiter followed
  | LengthSynthCommandContractPathMissing
    -- ^ the @--@ delimiter was found but no path text preceded it
  | LengthSynthCommandBehaviorModeMustPrecedeContract
    -- ^ @--behavior-mode@ appeared after @--length-contract@
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One lexically complete inline request.  The private constructor prevents
-- callers from bypassing the model/input parser, and the type deliberately has
-- no 'Show' instance which could echo the retained clause.
data LengthSynthInlineCommand = LengthSynthInlineCommand
  LeanLengthWherePlan
  String

-- | Closed command-layer failures.  These diagnose only option structure and
-- the bounded physical-input token; the clause itself is parsed later, after
-- command-local policy authorization.
data LengthSynthInlineCommandError
  = LengthSynthCommandInlineRequiresExplicitFilter
  | LengthSynthCommandLengthModelMissing
  | LengthSynthCommandLengthModelInvalid
  | LengthSynthCommandLengthInputsMissing
  | LengthSynthCommandLengthInputsMalformed
  | LengthSynthCommandLengthInputsNotStrictlyIncreasing
  | LengthSynthCommandLengthInputLimitExceeded !Natural !Natural
  | LengthSynthCommandWhereMissing
  | LengthSynthCommandContractSourcesMutuallyExclusive
  | LengthSynthCommandOptionOrderInvalid
  | LengthSynthCommandInlineDelimiterMissing
  deriving (Eq, Ord, Show)

-- | Split one @:synth@ argument line.  A trimmed line that starts with an
-- exact @--behavior-mode@ token names @rank@ or @filter@ next; a line that
-- starts with (or continues with) an exact @--length-contract@ token supplies
-- a path up to the first standalone @--@ token; the text after that
-- delimiter is the goal.  Either option makes the delimiter mandatory, the
-- mode must precede the contract, and a line naming neither option is
-- entirely the goal under the ranking mode.
parseLengthSynthCommand
  :: String
  -> Either LengthSynthCommandError LengthSynthCommand
parseLengthSynthCommand source = case exactOptionTail behaviorModeOption trimmed of
  Just rest -> parseBehaviorMode rest
  Nothing -> case exactOptionTail lengthContractOption trimmed of
    Just rest -> parseContract LengthBehaviorRank rest
    Nothing -> Right $ command LengthBehaviorRank Nothing trimmed
 where
  trimmed = trim source

  parseBehaviorMode rest = case takeToken rest of
    Nothing -> Left LengthSynthCommandBehaviorModeMissing
    Just ("--", _) -> Left LengthSynthCommandBehaviorModeMissing
    Just (modeSource, afterMode) -> case modeSource of
      "rank" -> parseAfterMode LengthBehaviorRank afterMode
      "filter" -> parseAfterMode LengthBehaviorFilter afterMode
      _ -> Left LengthSynthCommandBehaviorModeInvalid

  parseAfterMode mode rest = case exactOptionTail lengthContractOption rest of
    Just afterContract -> parseContract mode afterContract
    Nothing -> case consumeDelimiter rest of
      Just goal -> Right $ command mode Nothing goal
      Nothing -> Left LengthSynthCommandDelimiterMissing

  parseContract mode rest = case splitDelimiter rest of
    Nothing -> Left LengthSynthCommandDelimiterMissing
    Just (pathSource, goal) ->
      let path = trim pathSource
          (pathWords, laterWords) = break (== behaviorModeOption) $ words path
      in if null path
        then Left LengthSynthCommandContractPathMissing
        else case laterWords of
          _ : _
            | null pathWords -> Left LengthSynthCommandContractPathMissing
            | otherwise ->
                Left LengthSynthCommandBehaviorModeMustPrecedeContract
          [] -> Right $ command mode (Just path) goal

  command mode path goal = LengthSynthCommand
    { lengthSynthCommandBehaviorMode = mode
    , lengthSynthCommandContractPath = path
    , lengthSynthCommandGoal = trim goal
    }

-- | Project the passive inline plan without exposing its constructor or raw
-- clause.  Runtime code must first obtain command-local policy authority before
-- passing this value to @parseLeanLengthWhereSource@.
lengthSynthInlineCommandWherePlan
  :: LengthSynthInlineCommand
  -> LeanLengthWherePlan
lengthSynthInlineCommandWherePlan (LengthSynthInlineCommand plan _) = plan

-- | The trimmed goal text following the inline clause's delimiter.
lengthSynthInlineCommandGoal :: LengthSynthInlineCommand -> String
lengthSynthInlineCommandGoal (LengthSynthInlineCommand _ goal) = goal

-- | Recognize only the new fixed-order inline form.  'Nothing' means the
-- command belongs to the established parser, which remains unchanged and is
-- still the sole parser called by Main in this passive checkpoint.
--
-- Structural order, repetition, and file/inline exclusion are checked before
-- model and input token contents.  The clause is merely sliced here; its Djex
-- grammar and byte limits are intentionally not duplicated in Leant.
parseLengthSynthInlineCommand
  :: String
  -> Either
      LengthSynthInlineCommandError
      (Maybe LengthSynthInlineCommand)
parseLengthSynthInlineCommand source =
  case exactOptionTail behaviorModeOption trimmed of
    Just afterBehavior -> case takeToken afterBehavior of
      Just ("filter", afterMode)
        | hasInlineOption optionPrefix -> do
            validateInlineStructure optionPrefix
            Just <$> parseAfterFilter afterMode
        | otherwise -> Right Nothing
      Just ("rank", _)
        | hasInlineOption optionPrefix -> do
            validateInlineStructure optionPrefix
            Left LengthSynthCommandInlineRequiresExplicitFilter
        | otherwise -> Right Nothing
      _ -> Right Nothing
    Nothing
      | startsInlineOption trimmed -> do
          validateInlineStructure optionPrefix
          Left LengthSynthCommandInlineRequiresExplicitFilter
      | startsContractOption trimmed && hasInlineOption optionPrefix -> do
          validateInlineStructure optionPrefix
          Left LengthSynthCommandContractSourcesMutuallyExclusive
      | otherwise -> Right Nothing
 where
  trimmed = trim source
  optionPrefix = commandPrefix trimmed

  parseAfterFilter afterMode = case exactOptionTail lengthModelOption afterMode of
    Nothing -> Left LengthSynthCommandLengthModelMissing
    Just afterModel -> do
      (model, afterModelToken) <- parseModel afterModel
      afterInputsOption <- case exactOptionTail lengthInputsOption
          afterModelToken of
        Just value -> Right value
        Nothing -> Left LengthSynthCommandLengthInputsMissing
      (inputToken, afterInputToken) <- case takeToken afterInputsOption of
        Just (token, rest)
          | not (isOwnedOption token) -> Right (token, rest)
        _ -> Left LengthSynthCommandLengthInputsMissing
      inputs <- case parseLeanLengthWhereInputSource inputToken of
        Left LeanLengthWhereInputMalformed ->
          Left LengthSynthCommandLengthInputsMalformed
        Left LeanLengthWhereInputsNotStrictlyIncreasing ->
          Left LengthSynthCommandLengthInputsNotStrictlyIncreasing
        Left (LeanLengthWhereInputLimitExceeded maximumIndex observed) ->
          Left $ LengthSynthCommandLengthInputLimitExceeded
            maximumIndex observed
        Right value -> Right value
      afterWhere <- case exactOptionTail lengthWhereOption afterInputToken of
        Just value -> Right value
        Nothing -> Left LengthSynthCommandWhereMissing
      case splitDelimiter afterWhere of
        Nothing
          | null afterWhere -> Left LengthSynthCommandWhereMissing
          | otherwise -> Left LengthSynthCommandInlineDelimiterMissing
        Just (clause, goal)
          | null clause -> Left LengthSynthCommandWhereMissing
          | otherwise -> Right $ LengthSynthInlineCommand
              (mkLeanLengthWherePlan model inputs clause) (trim goal)

  parseModel sourceAfterOption = case takeToken sourceAfterOption of
    Nothing -> Left LengthSynthCommandLengthModelMissing
    Just (token, _)
      | isOwnedOption token -> Left LengthSynthCommandLengthModelMissing
    Just (token, rest) -> case token of
      "list-scalar-exact-cases" ->
        Right (LeanListScalarExactCases, rest)
      "list-binary-product-exact-cases" ->
        Right (LeanListBinaryProductExactCases, rest)
      _ -> Left LengthSynthCommandLengthModelInvalid

behaviorModeOption :: String
behaviorModeOption = "--behavior-mode"

lengthContractOption :: String
lengthContractOption = "--length-contract"

lengthModelOption, lengthInputsOption, lengthWhereOption :: String
lengthModelOption = "--length-model"
lengthInputsOption = "--length-inputs"
lengthWhereOption = "--where"

inlineOptions :: [String]
inlineOptions = [lengthModelOption, lengthInputsOption, lengthWhereOption]

allOwnedOptions :: [String]
allOwnedOptions = behaviorModeOption : lengthContractOption : inlineOptions

startsInlineOption :: String -> Bool
startsInlineOption source = any hasTail inlineOptions
 where
  hasTail option = case exactOptionTail option source of
    Just _ -> True
    Nothing -> False

startsContractOption :: String -> Bool
startsContractOption source = case exactOptionTail lengthContractOption source of
  Just _ -> True
  Nothing -> False

hasInlineOption :: String -> Bool
hasInlineOption source = any (`elem` inlineOptions) $ words source

isOwnedOption :: String -> Bool
isOwnedOption token = token `elem` allOwnedOptions || token == "--"

-- | Validate only structural properties whose precedence is earlier than
-- model/input contents.  Missing options are left to the precise field parser.
validateInlineStructure
  :: String
  -> Either LengthSynthInlineCommandError ()
validateInlineStructure source
  | lengthContractOption `elem` tokens =
      Left LengthSynthCommandContractSourcesMutuallyExclusive
  | any repeated allInlineOptions =
      Left LengthSynthCommandOptionOrderInvalid
  | not $ increasing presentPositions =
      Left LengthSynthCommandOptionOrderInvalid
  | otherwise = Right ()
 where
  tokens = words source
  allInlineOptions = behaviorModeOption : inlineOptions
  repeated option = count option tokens > 1
  presentPositions =
    [ position
    | option <- allInlineOptions
    , Just position <- [firstPosition option tokens]
    ]

count :: Eq value => value -> [value] -> Int
count sought = length . filter (== sought)

firstPosition :: Eq value => value -> [value] -> Maybe Int
firstPosition sought = go 0
 where
  go _ [] = Nothing
  go index (value : rest)
    | value == sought = Just index
    | otherwise = go (index + 1) rest

increasing :: Ord value => [value] -> Bool
increasing values = case values of
  [] -> True
  first : rest -> go first rest
 where
  go _ [] = True
  go previous (current : remaining) =
    previous < current && go current remaining

-- | Text before the first standalone delimiter.  Option-like words in the
-- opaque Lean goal therefore never participate in command ownership.
commandPrefix :: String -> String
commandPrefix source = case splitDelimiter source of
  Just (prefix, _) -> prefix
  Nothing -> source

-- | Match one exact option token and trim the separating whitespace.  Longer
-- lookalike prefixes remain ordinary goal text.
exactOptionTail :: String -> String -> Maybe String
exactOptionTail option source = case stripPrefix option source of
  Just [] -> Just []
  Just rest@(character : _)
    | isSpace character -> Just $ dropWhile isSpace rest
  _ -> Nothing

takeToken :: String -> Maybe (String, String)
takeToken source = case dropWhile isSpace source of
  [] -> Nothing
  remaining ->
    let (token, rest) = break isSpace remaining
    in Just (token, dropWhile isSpace rest)

consumeDelimiter :: String -> Maybe String
consumeDelimiter source = case dropWhile isSpace source of
  '-' : '-' : after
    | delimiterEnd after -> Just $ dropWhile isSpace after
  _ -> Nothing

splitDelimiter :: String -> Maybe (String, String)
splitDelimiter source = case source of
  '-' : '-' : after
    | delimiterEnd after ->
        Just ("", dropWhile isSpace after)
  _ -> go [] source
 where
  go _ [] = Nothing
  go reversed remaining@(character : rest)
    | isSpace character =
        let (spaces, following) = span isSpace remaining
        in case following of
          '-' : '-' : after
            | delimiterEnd after ->
                Just (reverse reversed, dropWhile isSpace after)
          _ -> go (reverse spaces ++ reversed) following
    | otherwise = go (character : reversed) rest

delimiterEnd :: String -> Bool
delimiterEnd [] = True
delimiterEnd (character : _) = isSpace character

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse
