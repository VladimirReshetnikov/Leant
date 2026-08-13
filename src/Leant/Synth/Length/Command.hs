-- | Pure parsing for the request-scoped @:synth@ Length contract option.
--
-- Goal syntax remains opaque text.  The standalone @--@ delimiter is required
-- so Lean tokens and spaces are never parsed as option fields.  The contract
-- path is the trimmed finite text between the option and delimiter; it may
-- contain spaces, but the delimiter spelling itself is reserved.
module Leant.Synth.Length.Command
  ( LengthSynthCommand (..)
  , LengthSynthCommandError (..)
  , parseLengthSynthCommand
  ) where

import Data.Char (isSpace)
import Data.List (stripPrefix)

data LengthSynthCommand = LengthSynthCommand
  { lengthSynthCommandContractPath :: Maybe FilePath
  , lengthSynthCommandGoal :: String
  }
  deriving (Eq, Show)

data LengthSynthCommandError
  = LengthSynthCommandContractPathMissing
  | LengthSynthCommandDelimiterMissing
  deriving (Bounded, Enum, Eq, Ord, Show)

parseLengthSynthCommand
  :: String
  -> Either LengthSynthCommandError LengthSynthCommand
parseLengthSynthCommand source = case optionTail of
  Just rest -> do
    (pathSource, goal) <- case splitDelimiter rest of
      Nothing -> Left LengthSynthCommandDelimiterMissing
      Just values -> Right values
    let path = trim pathSource
    if null path
      then Left LengthSynthCommandContractPathMissing
      else Right LengthSynthCommand
        { lengthSynthCommandContractPath = Just path
        , lengthSynthCommandGoal = trim goal
        }
  Nothing -> Right LengthSynthCommand
    { lengthSynthCommandContractPath = Nothing
    , lengthSynthCommandGoal = trim source
    }
 where
  trimmed = trim source
  optionTail = case stripPrefix "--length-contract" trimmed of
    Just [] -> Just []
    Just rest@(character : _)
      | isSpace character -> Just $ dropWhile isSpace rest
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
