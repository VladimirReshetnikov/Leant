{-# LANGUAGE ScopedTypeVariables #-}

-- | Command-scoped ownership for the optional parallel-verification
-- artifact.  This module contains no Lean session state: callers supply the
-- static eligibility decision and the effectful artifact operations, which
-- keeps admission, cancellation, and cleanup independently testable.
module Leant.Synth.Verification.Runtime
  ( VerificationArtifactRuntime
  , ParallelFailureDisposition (..)
  , withVerificationArtifactRuntime
  , ensureVerificationArtifactWith
  , disableVerificationArtifactRuntime
  , runVerificationBatchWith
  , parallelVerificationFailureAllowsSerialFallback
  ) where

import Control.Exception
  ( Exception
  , IOException
  , SomeException
  , SomeAsyncException
  , fromException
  , mask
  , throwIO
  , try
  )
import Data.IORef

import Leant.Backend.Isolated
  ( IsolatedBackendFailure (..)
  , IsolatedBackendTransportFailure (..)
  )

data VerificationArtifactRuntime artifact = VerificationArtifactRuntime
  { verificationArtifactState :: IORef (VerificationArtifactState artifact)
  , verificationArtifactCleanup :: artifact -> IO ()
  }

data VerificationArtifactState artifact
  = VerificationArtifactUnprobed
  | VerificationArtifactDisabled (Maybe artifact)
  | VerificationArtifactReady artifact

-- | Decide whether a completed, cleanly closed parallel attempt can be
-- replayed through the serial oracle or must terminate the command.
data ParallelFailureDisposition fatal
  = FallbackSerial
  | AbortParallel fatal

-- | Own one optional artifact for a complete command.
--
-- Cleanup runs after both normal and exceptional callbacks.  The callback's
-- exception remains primary; after a normal callback, a cleanup exception is
-- surfaced.  An artifact retained by a failed preparation is deliberately
-- retried here.
withVerificationArtifactRuntime
  :: (artifact -> IO ())
  -> (VerificationArtifactRuntime artifact -> IO value)
  -> IO value
withVerificationArtifactRuntime cleanup action = mask $ \restore -> do
  stateReference <- newIORef VerificationArtifactUnprobed
  let runtime = VerificationArtifactRuntime
        { verificationArtifactState = stateReference
        , verificationArtifactCleanup = cleanup
        }
  outcome <- tryAny $ restore $ action runtime
  cleanupOutcome <- tryAny $ cleanupVerificationArtifactRuntime runtime
  case outcome of
    Left primary -> throwIO primary
    Right value -> case cleanupOutcome of
      Left cleanupFailure -> throwIO cleanupFailure
      Right () -> pure value

-- | Lazily prepare or reuse the command's artifact.
--
-- The effectful static gate is observed before capabilities.  Acquisition may
-- perform prerequisite work but must return an artifact name which is still
-- absent; ownership is recorded, while masked, before the interruptible
-- preparation action may create it.  Normal unavailability is sticky.  A
-- failed or interrupted preparation gets one best-effort early cleanup.  A
-- successful cleanup clears ownership immediately; a failed cleanup retains
-- ownership so command-final cleanup can retry.
ensureVerificationArtifactWith
  :: VerificationArtifactRuntime artifact
  -> IO Bool
  -> IO Int
  -> IO (Maybe (artifact, seed))
  -> (artifact -> seed -> IO Bool)
  -> IO (Maybe artifact)
ensureVerificationArtifactWith runtime readStaticEligibility
    readCapabilities acquire prepare = do
  state <- readIORef $ verificationArtifactState runtime
  case state of
    VerificationArtifactReady artifact -> pure $ Just artifact
    VerificationArtifactDisabled _ -> pure Nothing
    VerificationArtifactUnprobed -> mask $ \restore -> do
      staticallyEligible <- restore readStaticEligibility
      if not staticallyEligible
        then disabled
        else do
          capabilities <- restore readCapabilities
          if capabilities < 2
            then disabled
            else do
              acquired <- restore acquire
              case acquired of
                Nothing -> disabled
                Just (artifact, seed) -> do
                  -- The acquisition contract leaves the path absent.  From
                  -- this write onward, every exit retains a cleanup owner.
                  writeIORef (verificationArtifactState runtime)
                    $ VerificationArtifactDisabled $ Just artifact
                  prepared <- tryAny $ restore $ prepare artifact seed
                  case prepared of
                    Left primary -> do
                      cleanupIgnoringFailure runtime artifact
                      throwIO primary
                    Right False -> do
                      cleanupAfterNormalFailure runtime artifact
                      pure Nothing
                    Right True -> do
                      writeIORef (verificationArtifactState runtime)
                        $ VerificationArtifactReady artifact
                      pure $ Just artifact
 where
  disabled = do
    disableVerificationArtifactRuntime runtime
    pure Nothing

-- | Permanently select serial verification for later batches while retaining
-- any already-owned artifact for command cleanup.
disableVerificationArtifactRuntime
  :: VerificationArtifactRuntime artifact
  -> IO ()
disableVerificationArtifactRuntime runtime =
  atomicModifyIORef' (verificationArtifactState runtime) $ \state ->
    ( VerificationArtifactDisabled $ case state of
        VerificationArtifactUnprobed -> Nothing
        VerificationArtifactDisabled artifact -> artifact
        VerificationArtifactReady artifact -> Just artifact
    , ()
    )

-- | Select one batch route without exposing runtime state.
--
-- Ineligible batches call the serial oracle literally and do not evaluate the
-- artifact action.  A replayable parallel failure disables later batches
-- before replaying this exact batch.  Async/programmer exceptions and pair
-- cleanup exceptions must remain exceptions in @runParallel@; this boundary
-- converts only its explicit failure value.
runVerificationBatchWith
  :: Exception fatal
  => VerificationArtifactRuntime artifact
  -> Bool
  -> IO (Maybe artifact)
  -> IO result
  -> (artifact -> IO (Either failure result))
  -> (failure -> ParallelFailureDisposition fatal)
  -> IO result
runVerificationBatchWith runtime batchEligible ensureArtifact runSerial
    runParallel classifyFailure
  | not batchEligible = runSerial
  | otherwise = do
      artifact <- ensureArtifact
      case artifact of
        Nothing -> runSerial
        Just available -> do
          attempted <- runParallel available
          case attempted of
            Right result -> pure result
            Left failure -> case classifyFailure failure of
              FallbackSerial -> do
                disableVerificationArtifactRuntime runtime
                runSerial
              AbortParallel fatal -> throwIO fatal

-- | Only cleanup-free operational unavailability is replayable through the
-- historical serial verifier.  Cleanup failures may leave an unowned process
-- tree; closed/retired lease states are invariant violations in the scoped
-- production route.  This exhaustive match forces review of future failure
-- constructors.
parallelVerificationFailureAllowsSerialFallback
  :: IsolatedBackendFailure
  -> Bool
parallelVerificationFailureAllowsSerialFallback failure = case failure of
  IsolatedBackendSpawnFailure {} -> True
  IsolatedBackendSetupTransportFailure _ cause ->
    transportAllowsSerialFallback cause
  IsolatedBackendSetupFatal {} -> True
  IsolatedBackendSetupErrors {} -> True
  IsolatedBackendSetupMissingEnvironment {} -> True
  IsolatedBackendRequestFailure cause ->
    transportAllowsSerialFallback cause
  IsolatedBackendPairPoisoned cause ->
    transportAllowsSerialFallback cause
  IsolatedBackendCleanupFailure {} -> False
  IsolatedBackendLeaseClosed -> False
  IsolatedBackendLeaseRetired {} -> False
  IsolatedBackendPairClosed -> False
  IsolatedBackendPreparationClaimed -> False
 where
  -- An interruption is cancellation/lifecycle evidence, never ordinary
  -- speculative unavailability.  Replaying serially would swallow it.
  transportAllowsSerialFallback cause = case cause of
    IsolatedBackendRequestInterrupted -> False
    IsolatedBackendRequestTimeout -> True
    IsolatedBackendServerClosed {} -> True
    IsolatedBackendBadResponse {} -> True

cleanupVerificationArtifactRuntime
  :: VerificationArtifactRuntime artifact
  -> IO ()
cleanupVerificationArtifactRuntime runtime = do
  state <- readIORef $ verificationArtifactState runtime
  case state of
    VerificationArtifactUnprobed -> pure ()
    VerificationArtifactDisabled Nothing -> pure ()
    VerificationArtifactDisabled (Just artifact) -> cleanup artifact
    VerificationArtifactReady artifact -> cleanup artifact
 where
  cleanup = verificationArtifactCleanup runtime

cleanupIgnoringFailure
  :: VerificationArtifactRuntime artifact
  -> artifact
  -> IO ()
cleanupIgnoringFailure runtime artifact = do
  cleaned <- tryAny $ verificationArtifactCleanup runtime artifact
  case cleaned of
    Left _ -> pure ()
    Right () -> clearArtifactOwnership runtime

cleanupAfterNormalFailure
  :: VerificationArtifactRuntime artifact
  -> artifact
  -> IO ()
cleanupAfterNormalFailure runtime artifact = do
  cleaned <- tryAny $ verificationArtifactCleanup runtime artifact
  case cleaned of
    Left failure
      | Just (_ :: SomeAsyncException) <- fromException failure ->
          throwIO failure
      | Just (_ :: IOException) <- fromException failure -> pure ()
      | otherwise -> throwIO failure
    Right () -> clearArtifactOwnership runtime

-- Early cleanup has removed the absent-path reservation completely.  Do not
-- retain that name for command-final cleanup: another process could create a
-- new file there before the command ends, and the stale owner would then
-- delete a foreign artifact.  Failed/interrupted cleanup deliberately leaves
-- the existing owner in place for a later retry.
clearArtifactOwnership
  :: VerificationArtifactRuntime artifact
  -> IO ()
clearArtifactOwnership runtime =
  writeIORef (verificationArtifactState runtime)
    $ VerificationArtifactDisabled Nothing

tryAny :: IO value -> IO (Either SomeException value)
tryAny = try
