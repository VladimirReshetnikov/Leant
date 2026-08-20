-- | Private scoped concurrency for the independent combined-engine lanes.
--
-- Both actions start before either result is observed.  Results are observed
-- left-to-right so Djinn retains its established error precedence.  A normal
-- left failure ends the pair without observing the right result; leaving the
-- nested 'withAsync' scope cancels and joins that worker.  The same scoped
-- cleanup applies when a worker or the caller raises an exception.
module Leant.Synth.Engine.Parallel
  ( runParallelEitherPairOrdered
  ) where

import Control.Concurrent.Async (wait, withAsync)

-- | Run two failure-aware actions concurrently and retain serial left-first
-- result semantics.  Strictness belongs to the supplied actions so callers
-- can choose an application-specific bounded force target.
runParallelEitherPairOrdered
  :: IO (Either err left)
  -> IO (Either err right)
  -> IO (Either err (left, right))
runParallelEitherPairOrdered left right =
  withAsync left $ \leftWorker ->
    withAsync right $ \rightWorker -> do
      leftResult <- wait leftWorker
      case leftResult of
        Left err -> pure (Left err)
        Right leftValue -> do
          rightResult <- wait rightWorker
          pure (fmap (\rightValue -> (leftValue, rightValue)) rightResult)
