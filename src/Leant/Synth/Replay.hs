-- | Pure planning for keeping Leant's synthesis environment in step with
-- the interactive session.
--
-- A cached environment already contains a chronological prefix of the
-- session history.  Appending commands therefore only requires replaying the
-- suffix; undo and replacement histories must restart from the synthesis
-- base.  Keeping the choice pure makes the boundary explicit and testable.
module Leant.Synth.Replay
  ( ReplayPlan (..)
  , planReplay
  ) where

import Data.List (stripPrefix)

data ReplayPlan a
  = Reuse
  | ReplaySuffix [a]
  | ReplayAll [a]
  deriving (Eq, Show)

-- | Compare the history represented by a cached environment with the
-- current session history.
planReplay :: Eq a => [a] -> [a] -> ReplayPlan a
planReplay cached current = case stripPrefix cached current of
  Just [] -> Reuse
  Just suffix -> ReplaySuffix suffix
  Nothing -> ReplayAll current
