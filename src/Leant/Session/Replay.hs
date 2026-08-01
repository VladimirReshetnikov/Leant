-- | Transactional reconstruction of a chronological command history.
module Leant.Session.Replay
  ( generatedItBinding
  , itCounterAfterHistory
  , replayHistoryWith
  ) where

import Data.Char (isDigit, isSpace)
import Data.List (isPrefixOf, stripPrefix)

-- | Replay commands without exposing partial progress.  On success the
-- newest undo environment is first; on failure the failing command is
-- returned and the caller's original logical history remains untouched.
replayHistoryWith
  :: Monad m
  => (environment -> command -> m (Maybe environment))
  -> environment
  -> [command]
  -> m (Either command (environment, [environment]))
replayHistoryWith step = go []
 where
  go stack current [] = pure (Right (current, stack))
  go stack current (command : rest) = do
    next <- step current command
    case next of
      Nothing -> pure (Left command)
      Just environment -> go (current : stack) environment rest

-- | Recognize Leant's hidden GHCi-style result declaration.
generatedItBinding :: String -> Maybe Int
generatedItBinding entry = do
  rest <- firstMatch generatedPrefixes (dropWhile isSpace entry)
  let (digits, suffix) = span isDigit rest
  if null digits || not ("\187" `isPrefixOf` suffix)
    then Nothing
    else case reads digits of
      [(counter, "")] -> Just counter
      _ -> Nothing
 where
  generatedPrefixes =
    [ "def \171it!"
    , "set_option autoImplicit true in def \171it!"
    , "set_option autoImplicit true in noncomputable def \171it!"
    ]

  firstMatch [] _ = Nothing
  firstMatch (prefix : prefixes) value = case stripPrefix prefix value of
    Just rest -> Just rest
    Nothing -> firstMatch prefixes value

-- | Restore bare-@it@ numbering after undo, never crossing below the
-- counter embedded in a snapshot base.
itCounterAfterHistory :: Int -> [String] -> Int
itCounterAfterHistory base history = maximum
  (base : [counter | entry <- history, Just counter <- [generatedItBinding entry]])
