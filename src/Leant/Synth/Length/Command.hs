-- | Pure parsing for the request-scoped @:synth@ Length behavior options.
--
-- Ordinary goals remain opaque, delimiter-free text.  Once either exact
-- option token is recognized, the standalone @--@ delimiter is mandatory.
-- The order is fixed: behavior mode, then contract.  A contract without an
-- explicit mode keeps the established ranking operation.
module Leant.Synth.Length.Command
  ( LengthBehaviorMode (..)
  , LengthSynthCommand (..)
  , LengthSynthCommandError (..)
  , parseLengthSynthCommand
  ) where

import Data.Char (isSpace)
import Data.List (stripPrefix)

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

behaviorModeOption :: String
behaviorModeOption = "--behavior-mode"

lengthContractOption :: String
lengthContractOption = "--length-contract"

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
