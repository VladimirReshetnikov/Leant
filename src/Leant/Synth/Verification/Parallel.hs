-- | Private scoped concurrency for independent candidate-group verification.
--
-- Inputs are admitted in waves.  A wave is never wider than either the
-- worker limit or the number of successes still required.  Since one input
-- can contribute at most one success, every admitted input is at or before
-- the success-quota cutoff of the corresponding serial traversal.
module Leant.Synth.Verification.Parallel
  ( runOrderedSuccessQuota
  ) where

import Control.Concurrent.Async (wait, withAsync)
import Control.DeepSeq (NFData, force)
import Control.Exception (evaluate)

-- | Run rejection-or-success tasks concurrently while retaining serial
-- observation order.
--
-- A 'Left' result is a rejection and does not consume the quota; a 'Right'
-- result is one success.  Every result is forced to normal form in its worker
-- before that worker publishes it.  Workers in a wave all start before any
-- result is observed, but are waited in input order.  Consequently a later
-- exception cannot overtake an earlier result or exception.  The nested
-- 'withAsync' scopes cancel and join every active worker if observation or
-- the caller raises an exception.
--
-- A non-positive success quota performs no work and does not inspect the
-- input.  A positive quota requires a positive worker limit.  A worker limit
-- of one takes a literal in-caller serial route.
runOrderedSuccessQuota
  :: (NFData rejection, NFData success)
  => Int
  -> Int
  -> (input -> IO (Either rejection success))
  -> [input]
  -> IO [Either rejection success]
runOrderedSuccessQuota workerLimit successQuota runTask inputs
  | successQuota <= 0 = pure []
  | workerLimit <= 0 = ioError $ userError
      "runOrderedSuccessQuota: worker limit must be positive"
  | workerLimit == 1 = runSerialStrict successQuota runTask inputs
  | otherwise = go successQuota inputs
 where
  go remaining currentInputs =
    case admitWave (min workerLimit remaining) currentInputs of
      ([], _) -> pure []
      (waveInputs, followingInputs) -> do
        waveResults <- runWaveStrict runTask waveInputs
        let followingQuota = remaining - countSuccesses waveResults
        if followingQuota <= 0
          then pure waveResults
          else do
            followingResults <- go followingQuota followingInputs
            pure $ waveResults ++ followingResults

-- Do not inspect the tail after the final admitted cons cell.  In particular,
-- the second component remains a thunk when the requested width is reached.
admitWave :: Int -> [value] -> ([value], [value])
admitWave width values
  | width <= 0 = ([], values)
  | otherwise = case values of
      [] -> ([], [])
      value : remaining ->
        let (admitted, following) = admitWave (width - 1) remaining
        in (value : admitted, following)

runWaveStrict
  :: (NFData rejection, NFData success)
  => (input -> IO (Either rejection success))
  -> [input]
  -> IO [Either rejection success]
runWaveStrict runTask = spawn []
 where
  spawn workers waveInputs = case waveInputs of
    [] -> mapM wait $ reverse workers
    input : remaining ->
      withAsync (runTaskStrict runTask input) $ \worker ->
        spawn (worker : workers) remaining

runSerialStrict
  :: (NFData rejection, NFData success)
  => Int
  -> (input -> IO (Either rejection success))
  -> [input]
  -> IO [Either rejection success]
runSerialStrict remaining runTask inputs
  | remaining <= 0 = pure []
  | otherwise = case inputs of
      [] -> pure []
      input : following -> do
        result <- runTaskStrict runTask input
        followingResults <- runSerialStrict
          (case result of Left _ -> remaining; Right _ -> remaining - 1)
          runTask following
        pure $ result : followingResults

runTaskStrict
  :: (NFData rejection, NFData success)
  => (input -> IO (Either rejection success))
  -> input
  -> IO (Either rejection success)
runTaskStrict runTask input = do
  result <- runTask input
  evaluate $ force result

countSuccesses :: [Either rejection success] -> Int
countSuccesses = foldl' count 0
 where
  count total result = case result of
    Left _ -> total
    Right _ -> total + 1
