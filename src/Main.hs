{-# LANGUAGE CPP #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | leant - a GHCi-style interactive REPL for Lean 4.
--
-- The Haskeline loop follows the structure of the Djex REPL driver
-- (interrupt-safe step function, logical multi-line input, command
-- completion).
module Main (main) where

import Control.Concurrent (getNumCapabilities)
import Control.Exception (SomeException, evaluate, finally, try)
import Control.Monad (forM_, unless, void, when)
import Control.Monad.IO.Class (liftIO)
import Data.Char
  (isAlpha, isAlphaNum, isAscii, isDigit, isLower, isSpace, isUpper, toLower)
import Data.IORef
import Data.List
  ( intercalate
  , isInfixOf
  , isPrefixOf
  , isSuffixOf
  , nub
  , nubBy
  , sortOn
  , stripPrefix
  , tails
  )
import Data.Maybe (fromMaybe, isJust, isNothing, listToMaybe, mapMaybe)
import qualified Data.Set as Set
import Data.Time.Clock (UTCTime, addUTCTime, diffUTCTime, getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import Data.Time.LocalTime (getZonedTime)
import Numeric.Natural (Natural)
import System.Console.Haskeline
import System.Directory
  ( copyFile
  , doesDirectoryExist
  , doesFileExist
  , getHomeDirectory
  , getTemporaryDirectory
  , listDirectory
  , makeAbsolute
  , removeFile
  , renameFile
  )
import System.Environment (getArgs, lookupEnv)
import System.Exit (ExitCode (..), exitWith)
import System.FilePath
  ( (</>)
  , (<.>)
  , takeDirectory
  , takeFileName
  )
import System.IO
import System.IO.Error
  ( catchIOError
  , isDoesNotExistError
  , isEOFError
  , tryIOError
  )
import System.Process (callCommand)
import System.Timeout (timeout)

import Language.Haskell.Djex
  ( LengthSMTLibExecutableLaunchStrategy (..)
  )

import Leant.Backend
import Leant.Builtins (builtinInfo)
import Leant.Classify
import Leant.Format (formatInfo, indentDefBody)
import Leant.Json
import Leant.Options
  ( Options (..)
  , lengthAssessmentSetup
  , parseArgs
  )
import Leant.Session.Replay
  ( generatedItBinding
  , itCounterAfterHistory
  , replayHistoryWith
  )
import Leant.Session.Snapshot
  ( SnapshotBase (..)
  , SnapshotCompanion (..)
  , SnapshotFingerprint
  , SnapshotMetadata (..)
  , decodeSnapshotMetadata
  , encodeSnapshotMetadata
  , fingerprintSnapshot
  , resolveSnapshotPath
  , snapshotCompanionPath
  , snapshotMetadataPath
  , synthesisToolingABI
  )
import Leant.Synth.Engine
  ( DetailedCandidateGroup
  , DetailedSynthCursor
  , DetailedSynthCursorError (..)
  , DetailedSynthCursorStep (..)
  , DetailedVerificationVariant
  , DetailedSynthOutcome (..)
  , SynthEngine (..)
  , detailedCandidateBatchGroups
  , detailedCandidateBatchNotes
  , detailedCandidateGroupRoute
  , detailedCandidateGroupVariants
  , detailedCandidateGroupVerificationVariants
  , detailedVerificationVariantText
  , forceDetailedOutcome
  , forceDetailedSynthCursorStep
  , mapDetailedCandidateGroupVariantsDroppingSemanticSidecar
  , mergeDetailedOutcomesSkipping
  , parseSynthEngine
  , providerStages
  , startDetailedSynthCursor
  , advanceDetailedSynthCursorWith
  , synthEngineName
  , synthesizeWithProvidersSkippingDetailedWith
  , synthesizeTunedDetailedWith
  , SynthLimits (..)
  , defaultSynthLimits
  , synthVerificationWindowWith
  )
import Leant.Synth.Engine.Parallel (runParallelEitherPairOrdered)
import Leant.Synth.Fragment
  ( Frag (..)
  , GoalSort (..)
  , ParsedGoal (..)
  , ProviderFrag
  , ProviderQuery
  , Slot (SlotArrow)
  , candidateVerificationProgram
  , fragProviderMayOpen
  , fragSpine
  , fragHasDepth
  , fragRecKeys
  , fragRefusal
  , fragUnsafeAtoms
  , glivenkoSplit
  , parseUniqueGoalTranslation
  , parseProviderSexp
  , propAtoms
  , providerProgramWith
  , defaultProviderCap
  , serializerProgram
  , stripRecCtors
  , synthPrelude
  )
import Leant.Synth.Length.Integration
  ( ExplicitLengthAssessmentPermission
  , LengthAssessmentContext
  , LengthAssessmentMode
  , LengthAssessmentRequest
  , LengthAssessmentResult
  , LengthRankingConfigurationActivationPolicy (..)
  , assessLengthVerificationContext
  , authorizeExplicitLengthAssessmentRequest
  , startupLengthAssessmentRequest
  , disabledLengthAssessmentMode
  , explicitLengthAssessmentRequest
  , lengthAssessmentContextBehaviorMode
  , lengthAssessmentFailure
  , lengthAssessmentModeActivationPolicy
  , lengthAssessmentModeExecutableLaunchStrategy
  , loadLengthAssessmentMode
  , withLengthAssessmentRequestContext
  )
import Leant.Synth.Length.Command
  ( LengthBehaviorMode (..)
  , LengthSynthCommand (..)
  , LengthSynthInlineCommand
  , LengthSynthNativeInlineCommand
  , lengthSynthInlineCommandGoal
  , lengthSynthInlineCommandWherePlan
  , lengthSynthNativeInlineCommandGoal
  , lengthSynthNativeInlineCommandWherePlan
  , parseLengthSynthInlineCommand
  , parseLengthSynthNativeInlineCommand
  , parseLengthSynthCommand
  )
import Leant.Synth.Length.Contract.File.Acquire
  ( LengthContractFileSource (..)
  , lengthContractFileDefaultTimeoutMilliseconds
  , loadLengthContractFile
  , mkLengthContractFileRequest
  )
import Leant.Synth.Length.Presentation
  ( LengthCandidatePresentation
  , LengthCandidateRejectionPresentation
  , lengthCandidatePresentationNote
  , lengthCandidatePresentationText
  , lengthCandidateRejectionPresentationNote
  , lengthCandidateRejectionPresentationText
  , presentLengthAssessment
  , presentLengthAssessmentRejections
  )
import Leant.Synth.Length.Where
  ( LeanLengthWhereSource
  , LeanNativeLengthWhereSource
  , parseLeanLengthWhereSource
  , parseLeanNativeLengthWhereSource
  , resolveLeanLengthWhereSource
  , resolveLeanNativeLengthWhereSource
  )
import Leant.Synth.Observability
  ( LeantObservations
  , VerificationFailureClass (..)
  , candidateRenderingRouteObservations
  , leantObservationCodeEntries
  )
import Leant.Synth.ProviderCache
  ( ProviderCache
  , ProviderWorld
  , advanceProviderWorld
  , clearProviderCache
  , emptyProviderCache
  , historyEntryAffectsProviders
  , initialProviderWorld
  , insertProviderCache
  , lookupProviderCache
  )
import Leant.Synth.Replay (ReplayPlan (..), planReplay)
import Leant.Synth.Verification
  ( VariantVerdict (..)
  , VerificationBatch
  , verificationObservations
  , verifiedCandidateReceipts
  , verifyCandidateGroups
  )

#ifdef mingw32_HOST_OS
import Data.Bits ((.|.))
import Data.Word (Word32)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peek)
import Foreign.C.Types (CInt (..))

foreign import ccall unsafe "GetStdHandle"
  c_GetStdHandle :: Word32 -> IO (Ptr ())
foreign import ccall unsafe "GetConsoleMode"
  c_GetConsoleMode :: Ptr () -> Ptr Word32 -> IO CInt
foreign import ccall unsafe "SetConsoleMode"
  c_SetConsoleMode :: Ptr () -> Word32 -> IO CInt

foreign import ccall unsafe "GetConsoleOutputCP"
  c_GetConsoleOutputCP :: IO Word32
foreign import ccall unsafe "SetConsoleOutputCP"
  c_SetConsoleOutputCP :: Word32 -> IO CInt
foreign import ccall unsafe "GetConsoleCP"
  c_GetConsoleCP :: IO Word32
foreign import ccall unsafe "SetConsoleCP"
  c_SetConsoleCP :: Word32 -> IO CInt

-- The console renders our UTF-8 output bytes in its OEM codepage (CP437:
-- \945 shows as ╬▒) unless the output codepage is UTF-8. Switch both
-- codepages to 65001 and return an action restoring the originals.
setupConsoleUtf8 :: IO (IO ())
setupConsoleUtf8 = do
  result <- try $ do
    oldOut <- c_GetConsoleOutputCP
    oldIn <- c_GetConsoleCP
    _ <- c_SetConsoleOutputCP 65001
    _ <- c_SetConsoleCP 65001
    pure $ do
      _ <- c_SetConsoleOutputCP oldOut
      _ <- c_SetConsoleCP oldIn
      pure ()
  pure (either (\e -> const (pure ()) (e :: SomeException)) id result)

-- Enable virtual-terminal processing so ANSI escapes render in the classic
-- Windows console. Returns False if the console refuses.
enableVT :: IO Bool
enableVT = do
  result <- try $ do
    handle <- c_GetStdHandle 0xFFFFFFF5  -- STD_OUTPUT_HANDLE (-11)
    alloca $ \modePtr -> do
      ok <- c_GetConsoleMode handle modePtr
      if ok == 0
        then pure False
        else do
          mode <- peek modePtr
          ok' <- c_SetConsoleMode handle (mode .|. 0x0004)
          pure (ok' /= 0)
  pure (either (\e -> const False (e :: SomeException)) id result)
#else
setupConsoleUtf8 :: IO (IO ())
setupConsoleUtf8 = pure (pure ())

enableVT :: IO Bool
enableVT = pure True
#endif

-- State ---------------------------------------------------------------------

data ReplState = ReplState
  { rsBackend :: Maybe Backend
  , rsConfig :: BackendConfig
  , rsProjectDir :: Maybe FilePath
  , rsEnv :: Maybe Integer
  , rsBaseEnv :: Maybe Integer
  , rsSnapshotBase :: Maybe SnapshotBase
    -- ^ opaque environment restored by :unpickle, replayed before the
    -- post-snapshot history after backend restart.  A Leant-created sibling
    -- environment carries Lean's synthesis tooling and snapshot declarations.
  , rsEnvStack :: [Maybe Integer]
  , rsImports :: [String]
  , rsHistory :: [String]
  , rsLoadedFile :: Maybe FilePath
  , rsShowTime :: Bool
  , rsTimestamps :: Bool
  , rsTranscript :: Maybe (FilePath, Handle)
  , rsProve :: Maybe ProveState
  , rsProveCounter :: Int
  , rsLastSorry :: Maybe (Integer, String)
  , rsItCounter :: Int
    -- ^ GHCi-style `it`: evaluations bind `def \171it!N\187 := (expr)`; bare
    -- `it` in later input is substituted with the newest binding
  , rsComplCache :: [(String, [String])]
  , rsBrowseEnv :: Maybe Integer
    -- ^ cached environment for :browse - session imports plus
    -- Lean.Elab.Command (so the introspection metaprogram elaborates without
    -- polluting the user's own environment); invalidated on import changes
  , rsSynthBase :: Maybe Integer
    -- ^ cached base environment for :synth goal translation - session
    -- imports plus Lean (for run_tac) plus the compiled serializer
    -- prelude; invalidated on import changes
  , rsSynthEnv :: Maybe (Integer, [String])
    -- ^ the base environment with the session history replayed on top
    -- (so session-local names translate), tagged with the history it
    -- replayed; rebuilt when the history changes
  , rsProviderWorld :: ProviderWorld
    -- ^ generation of imports and user declarations eligible for live
    -- provider discovery; generated it bindings do not advance it
  , rsProviderCache :: ProviderCache [ProviderFrag]
    -- ^ bounded semantic inventories keyed by provider world and the
    -- serializer's canonical target roots/result head
  , rsSynthIts :: [String]
    -- ^ splice texts for `it1`, `it2`, ... - the last :synth batch's
    -- candidates.  In the session these are the mangled names the
    -- candidates were bound under (best candidate bound last, so bare
    -- `it` is `it1`); in prove mode they are the candidate terms
    -- applied to the goal's hypotheses, so `exact it1` closes the goal
  , rsSynthItsProve :: Bool
    -- ^ the current splice texts mention prove-mode hypotheses and are
    -- cleared when prove mode ends
  , rsSynthEngine :: SynthEngine
    -- ^ :set synth-engine djinn|exference|both
  , rsSynthSteps :: Int
    -- ^ :set synth-steps N - Exference's step budget
  , rsSynthClassical :: Bool
    -- ^ :set synth-classical on|off - offer classical candidates for
    -- constructively refuted goals
  , rsSynthLibrary :: Bool
    -- ^ :set synth-library on|off - seed the search with curated
    -- library functions over the goal's recursive inductives
  , rsSynthTimeout :: Int
    -- ^ :set synth-timeout N - wall-clock seconds one :synth command may
    -- search before answering "no answer, not a verdict"; 0 waits
    -- indefinitely.  Seeded from LEANT_SYNTH_TIMEOUT (default 20).
  , rsSynthLimits :: SynthLimits
    -- ^ :set synth-shown / synth-verify / synth-window / synth-budget /
    -- synth-queue - the retunable search bounds; 'defaultSynthLimits'
    -- reproduces the historical constants
  , rsSynthProviders :: Bool
    -- ^ :set synth-providers on|off - discover live providers after the
    -- structural baseline lane
  , rsSynthProviderCap :: Int
    -- ^ :set synth-provider-cap N - providers one discovery run may
    -- serialize (default 80)
  , rsSynthLibraryPremises :: Int
    -- ^ :set synth-library-premises N - rated library offers kept per goal
    -- (default 8)
  , rsSynthDebug :: Bool
    -- ^ :set synth-debug on|off - print fragments, providers, per-lane
    -- outcomes, and metrics; seeded from LEANT_SYNTH_DEBUG
  , rsLengthAssessmentMode :: LengthAssessmentMode
    -- ^ Explicitly disabled by default. Enabled values come only from one
    -- bounded, activated configuration-file setup at process startup. Its
    -- finite-spine domain selection and contract remain fixed for this process.
    -- Eager policies give each eligible batch a fresh lexical solver session;
    -- deferred policies create it only at the first actual live miss.
  , rsRatings :: [(String, Double)]
    -- ^ the library inventory with ratings (lower is better), best
    -- first: the defaults merged with the project's `leant.ratings`
    -- at startup.  Compiled into the synthesis prelude, so a
    -- mid-session edit of the file takes effect next session
  , rsTimeout :: Maybe Int
  , rsColor :: Bool
  , rsInteractive :: Bool
    -- ^ False when stdin is piped: prompts and echo go through emit (so the
    -- output and transcript read like a session) and Haskeline's own
    -- locale-encoded prompt printing is bypassed.
  }

-- | Backend-local identifiers rebuilt from an import or snapshot base plus
-- chronological history.  Reconstruction is accumulated off to the side and
-- installed atomically, so a failed replay cannot truncate history or damage
-- the undo chain of the still-live session.
data ReconstructedSession = ReconstructedSession
  { reconstructedBaseEnv :: Maybe Integer
  , reconstructedCurrentEnv :: Maybe Integer
  , reconstructedEnvStack :: [Maybe Integer]
  }

data SnapshotEnvironmentError
  = SnapshotTransportError String
  | SnapshotRejected String

-- | Move to a provider world whose imported and session declarations may
-- differ.  Old generations cannot hit even before the bounded cache refills;
-- clearing also makes the reclaimed capacity immediately useful.
invalidateProviderWorld :: ReplState -> ReplState
invalidateProviderWorld state = state
  { rsProviderWorld = advanceProviderWorld (rsProviderWorld state)
  , rsProviderCache = clearProviderCache (rsProviderCache state)
  , rsComplCache = []
  }

-- | Environment identifiers are backend-local.  Import changes and backend
-- restarts must discard every derived environment before another command can
-- observe it.
invalidateDerivedEnvironments :: ReplState -> ReplState
invalidateDerivedEnvironments state = state
  { rsBrowseEnv = Nothing
  , rsSynthBase = Nothing
  , rsSynthEnv = Nothing
  , rsComplCache = []
  }

-- | Interactive prove mode: the stack holds (proofState, goals, scriptEntry)
-- newest first; the entry state has no script entry.
data ProveState = ProveState
  { pvStmt :: Maybe String  -- ^ Nothing when resumed from a `sorry`
  , pvStack :: [(Integer, [String], Maybe String)]
  , pvSuggestions :: [(Integer, Maybe String)]
    -- ^ automatic tactic suggestions, cached by proof-state id; caching
    -- failures too keeps :goals/:undo from repeating potentially costly search
  }

type St = IORef ReplState

-- | One bounded synthesis lane after callback verification and optional
-- behavioral assessment.  The two candidate sequences deliberately retain
-- different meanings: the spelling frontier is the complete bounded engine
-- prefix used by the existing provider-dedup scheduler, while the callback
-- trace contains only variants actually attempted by the lazy verifier.  In
-- particular, a successful variant stops its group before any later variant
-- can enter the trace.  Every field stays lazy so an empty lane can remain a
-- total result without inspecting the assessment request.
data SynthLaneOutcome = SynthLaneOutcome
  { synthLaneCheckedFrontierSpellings :: [String]
  , synthLaneCallbackAttemptVariants :: [DetailedVerificationVariant]
  , synthLaneOutcomeObservations :: LeantObservations
  , synthLaneOutcomeNotes :: [String]
  , synthLaneAssessed :: Maybe AssessedSynthLane
  }

-- | The exact callback batch and its one associated behavioral assessment.
-- Keeping both receipts makes this private seam suitable for later scheduler
-- accounting without giving either value new public authority.
data AssessedSynthLane = AssessedSynthLane
  { assessedSynthLaneVerification
      :: VerificationBatch DetailedVerificationVariant
  , assessedSynthLaneLengthAssessment :: LengthAssessmentResult
  }

-- | Command-local lane history in reverse attempt order.  Prepending keeps
-- continuation constant-time without forcing an earlier outcome.  The owner
-- is lexical to one 'synthRun' context and never enters 'ReplState'.
newtype SynthLaneAccumulation =
  SynthLaneAccumulation [SynthLaneOutcome]

emptySynthLaneAccumulation :: SynthLaneAccumulation
emptySynthLaneAccumulation = SynthLaneAccumulation []

accumulateSynthLaneOutcome
  :: SynthLaneOutcome
  -> SynthLaneAccumulation
  -> SynthLaneAccumulation
accumulateSynthLaneOutcome outcome (SynthLaneAccumulation reverseOutcomes) =
  SynthLaneAccumulation (outcome : reverseOutcomes)

-- | Pure scheduling meaning of a lane.  'SynthLaneNoVerified' and successful
-- behavioral all-rejection may enter a later scheduler lane, but remain
-- distinct.  Survivor and preserve-all results are terminal.
data SynthLaneDisposition
  = SynthLaneNoVerified
  | SynthLaneSurvivors
      [LengthCandidatePresentation]
      [LengthCandidateRejectionPresentation]
  | SynthLaneAllBehaviorallyRejected
      [LengthCandidateRejectionPresentation]
  | SynthLaneAssessmentPreserved
      [LengthCandidatePresentation]
      [LengthCandidateRejectionPresentation]

-- | One engine run's private cursor policy.  The batch size is admitted by
-- Engine's opaque cursor.  A filter-enabled ordinary lane may consume the
-- returned successor once; rank, disabled, and excluded-middle lanes stop
-- after their first candidate batch.  Run notes belong to ordinary lanes but
-- remain silent for both classical fallbacks.
data SynthLaneCursorPolicy = SynthLaneCursorPolicy
  { synthLaneCursorBatchSize :: Int
  , synthLaneCursorAllowsFilterSuccessor :: Bool
  , synthLaneCursorRetainsRunNotes :: Bool
  , synthLaneCursorWindow :: Int
    -- ^ the cursor's hard cap on observed candidate groups
    -- (@:set synth-window@)
  , synthLaneCursorShown :: Int
    -- ^ accepted groups a batch may keep (@:set synth-shown@)
  }

-- | Why observation of one lazy engine outcome stopped.  Batch-policy
-- completion is deliberately distinct from natural exhaustion and the
-- product-wide cursor cap: after the admitted one or two candidate batches,
-- Main never probes the successor merely to classify its tail.
data SynthLaneRunEnd
  = SynthLaneRunStoppedByDisposition
  | SynthLaneRunBatchPolicyReached
  | SynthLaneRunNaturallyExhausted
  | SynthLaneRunHardCapReached
  | SynthLaneRunTimedOut
  | SynthLaneRunCursorAdmissionFailed DetailedSynthCursorError
  | SynthLaneRunEngineFailed String
  | SynthLaneRunRefuted Bool
  | SynthLaneRunNoTerm

-- | Complete command-local receipt for one engine outcome.  The accumulated
-- lane outcomes are already in the command's reverse history; the spelling
-- frontier and count cover only this engine run and retain attempt order.
-- Fields stay lazy and the type intentionally has no equality or rendering
-- instance, so it cannot become a persistence or diagnostics protocol.
data SynthLaneRun = SynthLaneRun
  { synthLaneRunAccumulation :: SynthLaneAccumulation
  , synthLaneRunCheckedFrontierSpellings :: [String]
  , synthLaneRunCandidateGroupCount :: Int
  , synthLaneRunNotes :: [String]
  , synthLaneRunEnd :: SynthLaneRunEnd
  }

-- Output (all user-visible text flows through emit so transcripts capture
-- the whole session) --------------------------------------------------------

emit :: St -> String -> IO ()
emit st text = do
  state <- readIORef st
  putStr text
  hFlush stdout
  forM_ (rsTranscript state) $ \(_, h) -> do
    hPutStr h (stripAnsi text)
    hFlush h

emitLn :: St -> String -> IO ()
emitLn st text = emit st (text ++ "\n")

stripAnsi :: String -> String
stripAnsi [] = []
stripAnsi ('\27' : '[' : rest) = stripAnsi (drop 1 (dropWhile (/= 'm') rest))
stripAnsi (c : rest) = c : stripAnsi rest

color :: St -> String -> String -> IO String
color st code text = do
  state <- readIORef st
  pure (if rsColor state then "\27[" ++ code ++ "m" ++ text ++ "\27[0m" else text)

cRed, cYellow, cCyan, cDim, cBold :: St -> String -> IO String
cRed st = color st "31"
cYellow st = color st "33"
cCyan st = color st "36"
cDim st = color st "2"
cBold st = color st "1"

-- Transcript ----------------------------------------------------------------

transcriptStart :: St -> Maybe FilePath -> IO ()
transcriptStart st mpath = do
  state <- readIORef st
  case rsTranscript state of
    Just (p, _) -> emitLn st =<< cDim st ("already recording to " ++ p)
    Nothing -> do
      path <- case mpath of
        Just p -> pure p
        Nothing -> do
          formatTime defaultTimeLocale "leant-%Y%m%d-%H%M%S.log"
            <$> getZonedTime
      result <- try (openFile path AppendMode)
      case (result :: Either SomeException Handle) of
        Left err -> emitLn st =<< cRed st ("cannot open transcript file: " ++ show err)
        Right h -> do
          hSetEncoding h utf8
          now <- getZonedTime
          hPutStrLn h ("-- Leant transcript started "
            ++ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" now)
          hFlush h
          modifyIORef' st (\s -> s { rsTranscript = Just (path, h) })
          stamps <- rsTimestamps <$> readIORef st
          emitLn st =<< cDim st ("recording transcript to " ++ path
            ++ (if stamps then " (with per-command timestamps)" else ""))

transcriptStop :: St -> IO ()
transcriptStop st = do
  state <- readIORef st
  case rsTranscript state of
    Nothing -> emitLn st =<< cDim st "transcript is not active"
    Just (path, h) -> do
      now <- getZonedTime
      hPutStrLn h ("-- Leant transcript ended "
        ++ formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S" now)
      hClose h
      modifyIORef' st (\s -> s { rsTranscript = Nothing })
      emitLn st =<< cDim st ("transcript saved to " ++ path)

-- Record an input line (with its prompt) in the transcript; Haskeline's echo
-- does not pass through emit.
transcriptInput' :: St -> Bool -> String -> String -> IO ()
transcriptInput' st isMain promptText line = do
  state <- readIORef st
  forM_ (rsTranscript state) $ \(_, h) -> do
    when (rsTimestamps state && isMain) $ do
      now <- getZonedTime
      hPutStrLn h (formatTime defaultTimeLocale "[%H:%M:%S]" now)
    hPutStrLn h (promptText ++ line)
    hFlush h

mainPrompt, contPrompt :: String
mainPrompt = "\955> "
contPrompt = "\8230> "

promptOf :: St -> IO String
promptOf st = do
  state <- readIORef st
  pure $ case rsProve state of
    Just pv -> case pvStack pv of
      (_, goals, _) : _ | length goals > 1 ->
        "\8866" ++ show (length goals) ++ "> "
      _ -> "\8866> "
    Nothing -> mainPrompt

-- Backend interaction -------------------------------------------------------

-- Ensure a live backend, respawning and replaying the session after a crash
-- or interrupt (port of AutoLeanServer's restart-and-replay behavior).
ensureBackend :: St -> IO (Either String Backend)
ensureBackend st = do
  processOr <- ensureBackendProcess st
  case processOr of
    Left err -> pure (Left err)
    Right (backend, False) -> pure (Right backend)
    Right (backend, True) -> do
      rebuilt <- rebuildSession st
      if rebuilt then pure (Right backend)
        else do
          -- Do not leave a partially replayed backend installed.  A later
          -- request could otherwise observe ids from an incomplete session.
          backendDied st
          pure (Left "failed to rebuild the session")

-- Start only the process.  Replacement operations (:reset, :load, and
-- :unpickle) deliberately use this lower boundary: if the old session can no
-- longer replay, those commands must still be able to establish a new base.
-- The Bool reports whether this call spawned an unreconstructed backend.
ensureBackendProcess :: St -> IO (Either String (Backend, Bool))
ensureBackendProcess st = do
  state <- readIORef st
  case rsBackend state of
    Just backend -> pure (Right (backend, False))
    Nothing -> do
      emitLn st =<< cDim st "starting Lean backend..."
      result <- try (spawnBackend (rsConfig state))
      case (result :: Either SomeException Backend) of
        Left err -> pure (Left (show err))
        Right backend -> do
          modifyIORef' st (\s -> s { rsBackend = Just backend })
          pure (Right (backend, True))

abandonReplacementBackend :: St -> Bool -> IO ()
abandonReplacementBackend st spawned = when spawned (backendDied st)

backendDied :: St -> IO ()
backendDied st = do
  state <- readIORef st
  forM_ (rsBackend state) killBackend
  -- Proof states and the last-sorry handle are backend-local too. Preserve
  -- the human-readable script, but never submit either token after respawn.
  proveEmergencyExit st "the Lean backend stopped; leaving prove mode"
  modifyIORef' st $ \current ->
    invalidateProviderWorld (invalidateDerivedEnvironments current
      { rsBackend = Nothing, rsLastSorry = Nothing })

-- Run a command in an exact backend-local environment. Nothing env = fresh
-- (imports allowed). Callers targeting the interactive session must use
-- 'runCurrentCmd', which resolves its environment only after a dead backend
-- has been respawned and the session replayed.
runCmd :: St -> Maybe Integer -> String -> IO (Either String JValue)
runCmd st env code = runPayload st (commandPayload env code)

-- | Run against the current interactive environment, resolving the id after
-- 'ensureBackend'.  Environment ids are local to one backend process, so
-- capturing @rsEnv@ before restart/replay can address an unrelated new id.
runCurrentCmd :: St -> String -> IO (Either String JValue)
runCurrentCmd st code = runPayloadAfterBackend st $ \state ->
  commandPayload (rsEnv state) code

commandPayload :: Maybe Integer -> String -> JValue
commandPayload env code = JObj
  (("cmd", JStr code) : [("env", JInt e) | Just e <- [env]])

pickleEnvironmentPayload :: FilePath -> Integer -> JValue
pickleEnvironmentPayload path env = JObj
  [("pickleTo", JStr path), ("env", JInt env)]

unpickleEnvironmentPayload :: FilePath -> JValue
unpickleEnvironmentPayload path = JObj [("unpickleEnvFrom", JStr path)]

restoreEnvironmentArtifact
  :: St -> FilePath -> IO (Either SnapshotEnvironmentError Integer)
restoreEnvironmentArtifact st path = do
  result <- runPayload st (unpickleEnvironmentPayload path)
  pure $ case result of
    Left err -> Left (SnapshotTransportError err)
    Right response
      | Just fatal <- respFatal response ->
          Left (SnapshotRejected (trim fatal))
      | hasErrors response ->
          Left (SnapshotRejected "Lean rejected the snapshot environment")
      | Just env <- respEnv response -> Right env
      | otherwise ->
          Left (SnapshotRejected "snapshot restore returned no environment")

-- Apply one tactic to a proof state.
runTactic :: St -> Integer -> String -> IO (Either String JValue)
runTactic st proofState tactic = runPayload st $ JObj
  [("tactic", JStr tactic), ("proofState", JInt proofState)]

runPayload :: St -> JValue -> IO (Either String JValue)
runPayload st payload = runPayloadAfterBackend st (const payload)

-- | Ensure/rebuild first, then construct the request from the resulting
-- state. This is the common timeout/death boundary for commands and snapshot
-- operations alike.
runPayloadAfterBackend
  :: St
  -> (ReplState -> JValue)
  -> IO (Either String JValue)
runPayloadAfterBackend st makePayload = do
  backendOr <- ensureBackend st
  case backendOr of
    Left err -> pure (Left err)
    Right backend -> do
      state <- readIORef st
      result <- request backend (rsTimeout state) (makePayload state)
      case result of
        Right v -> pure (Right v)
        Left RequestTimeout -> do
          backendDied st
          pure (Left ("timeout after "
            ++ maybe "?" show (rsTimeout state)
            ++ "s - the backend was killed; the session replays on the next command"))
        Left (ServerClosed stderrText) -> do
          backendDied st
          pure (Left ("the Lean server died"
            ++ (if null (trim stderrText) then "" else ":\n" ++ stderrText)
            ++ "\nhint: check that the project is built (lake build) and that "
            ++ "enough memory is available; the session replays on the next command"))
        Left (BadResponse err) -> pure (Left ("bad response: " ++ err))

-- Response accessors --------------------------------------------------------

respEnv :: JValue -> Maybe Integer
respEnv v = jLookup "env" v >>= jInt

respMessages :: JValue -> [(String, String)]  -- (severity, data)
respMessages v = fromMaybe [] $ do
  msgs <- jLookup "messages" v >>= jArray
  pure [ (sev, dat)
       | m <- msgs
       , Just sev <- [jLookup "severity" m >>= jString]
       , Just dat <- [jLookup "data" m >>= jString]
       ]

respSorries :: JValue -> [(Maybe Integer, String)]  -- (proofState, goal)
respSorries v = fromMaybe [] $ do
  sorries <- jLookup "sorries" v >>= jArray
  pure [ (jLookup "proofState" s >>= jInt, goal)
       | s <- sorries
       , Just goal <- [jLookup "goal" s >>= jString]
       ]

respFatal :: JValue -> Maybe String
respFatal v = case jLookup "message" v of
  Just (JStr m) | isNothing (jLookup "env" v) -> Just m
  _ -> Nothing

hasErrors :: JValue -> Bool
hasErrors v = any ((== "error") . fst) (respMessages v)

looksIncomplete :: JValue -> Bool
looksIncomplete v =
  let errs = [d | (s, d) <- respMessages v, s == "error"]
  in not (null errs) && all ("unexpected end of input" `isInfixOf'`) errs
 where
  isInfixOf' needle hay = any (needle `isPrefixOf`) (suffixes hay)
  suffixes s = s : case s of
    _ : rest -> suffixes rest
    [] -> []

-- Print messages/sorries; returns True if there were errors.
printResponse :: St -> Maybe (String -> Maybe String) -> JValue -> IO Bool
printResponse st transform v = case respFatal v of
  Just m -> do
    emitLn st . (++ m) =<< cRed st "REPL error: "
    pure True
  Nothing -> do
    errored <- newIORef False
    forM_ (respMessages v) $ \(severity, rawText) -> do
      let text = trimEnd (applyTransform severity (rewriteIt rawText))
      case severity of
        "error" -> do
          writeIORef errored True
          emitLn st . (++ text) =<< cRed st "error: "
        "warning" ->
          unless ("declaration uses" `isPrefixOf` text) $
            emitLn st . (++ text) =<< cYellow st "warning: "
        _ -> emitLn st text
    forM_ (respSorries v) $ \(proofState, goal) -> do
      forM_ proofState $ \ps -> modifyIORef' st
        (\s -> s { rsLastSorry = Just (ps, goal) })
      tag <- cCyan st "sorry"
      note <- cDim st (" (proof state " ++ maybe "?" show proofState
        ++ " \8212 :prove to work on it)")
      emitLn st (tag ++ note)
      forM_ (lines (trimEnd goal)) $ \l -> emitLn st ("  " ++ l)
    readIORef errored
 where
  applyTransform "info" text = fromMaybe text (transform >>= \f -> f text)
  applyTransform _ text = text
  trimEnd = reverse . dropWhile isSpace . reverse

-- Session (re)construction --------------------------------------------------

restoreSnapshotBase :: St -> SnapshotBase -> IO (Either () (Maybe Integer))
restoreSnapshotBase st snapshot = do
  let path = snapshotEnvironmentPath snapshot
  emitLn st =<< cDim st ("restoring snapshot base: " ++ path ++ " ...")
  result <- runPayload st (unpickleEnvironmentPayload path)
  case result of
    Left err -> do
      emitLn st . (++ err) =<< cRed st "snapshot restore failed: "
      pure (Left ())
    Right response -> do
      errored <- printResponse st Nothing response
      case (errored, respEnv response) of
        (False, Just env) -> pure (Right (Just env))
        (False, Nothing) -> do
          emitLn st =<< cRed st "snapshot restore returned no environment"
          pure (Left ())
        (True, _) -> pure (Left ())

buildImportedBase :: St -> [String] -> IO (Either () (Maybe Integer))
buildImportedBase st imports = case imports of
  [] -> pure (Right Nothing)
  _ -> do
    emitLn st =<< cDim st ("importing: " ++ intercalate ", " imports ++ " ...")
    warnMissingModules st imports
    started <- getCurrentTime
    result <- runCmd st Nothing (unlines (map ("import " ++) imports))
    case result of
      Left err -> do
        emitLn st . (++ err) =<< cRed st "import failed: "
        pure (Left ())
      Right response -> do
        errored <- printResponse st Nothing response
        if errored then pure (Left ()) else do
          -- A failed import can yield a silently empty environment; probe it.
          probe <- runCmd st (respEnv response)
            "example : True := True.intro"
          case probe of
            Right checked | not (hasErrors checked) -> do
              finished <- getCurrentTime
              emitLn st =<< cDim st ("imports ready in "
                ++ show (round (diffUTCTime finished started) :: Integer)
                ++ "s")
              pure (Right (respEnv response))
            _ -> do
              emitLn st =<< cRed st
                "import failed: the resulting environment is unusable"
              pure (Left ())

reconstructSession
  :: St
  -> Maybe SnapshotBase
  -> [String]
  -> [String]
  -> IO (Maybe ReconstructedSession)
reconstructSession st snapshot imports history = do
  baseOr <- case snapshot of
    Just snapshotBase -> restoreSnapshotBase st snapshotBase
    Nothing -> buildImportedBase st imports
  case baseOr of
    Left () -> pure Nothing
    Right base -> do
      replayed <- replayHistoryWith replayOne base history
      case replayed of
        Left code -> do
          emitLn st =<< cRed st ("replay failed at: "
            ++ takeWhile (/= '\n') code)
          pure Nothing
        Right (current, stack) -> pure (Just ReconstructedSession
          { reconstructedBaseEnv = base
          , reconstructedCurrentEnv = current
          , reconstructedEnvStack = stack
          })
 where
  replayOne current code = do
    result <- runCmd st current code
    pure $ case result of
      Right response
        | not (hasErrors response)
        , Nothing <- respFatal response
        , Just next <- respEnv response -> Just (Just next)
      _ -> Nothing

installReconstruction :: St -> ReconstructedSession -> IO ()
installReconstruction st rebuilt = modifyIORef' st
  (applyReconstruction rebuilt)

applyReconstruction :: ReconstructedSession -> ReplState -> ReplState
applyReconstruction rebuilt state =
  invalidateProviderWorld (invalidateDerivedEnvironments state
    { rsBaseEnv = reconstructedBaseEnv rebuilt
    , rsEnv = reconstructedCurrentEnv rebuilt
    , rsEnvStack = reconstructedEnvStack rebuilt
    })

clearSessionTransients :: ReplState -> ReplState
clearSessionTransients state = state
  { rsProve = Nothing
  , rsLastSorry = Nothing
  , rsItCounter = 0
  , rsSynthIts = []
  , rsSynthItsProve = False
  }

-- Build the base environment from imports or an opaque restored snapshot,
-- then replay history recorded after that base (used on startup after a
-- crash, and when the base changes).
rebuildSession :: St -> IO Bool
rebuildSession st = do
  state <- readIORef st
  rebuilt <- reconstructSession st (rsSnapshotBase state)
    (rsImports state) (rsHistory state)
  case rebuilt of
    Nothing -> pure False
    Just session -> do
      installReconstruction st session
      pure True

-- Module availability (the backend silently ignores unresolvable imports).
moduleAvailable :: St -> String -> IO Bool
moduleAvailable st modName = do
  state <- readIORef st
  let root = takeWhile (/= '.') modName
  if root `elem` ["Init", "Std", "Lean"] then pure True else
    case rsProjectDir state of
      Nothing -> pure False
      Just project -> do
        let relative = foldr1 (</>) (splitOn '.' modName) <.> "olean"
            buildLib dir = dir </> ".lake" </> "build" </> "lib" </> "lean"
            packagesDir = project </> ".lake" </> "packages"
        packageDirs <- do
          ok <- doesDirectoryExist packagesDir
          if not ok then pure [] else
            map (packagesDir </>) <$> listDirectory packagesDir
        let roots = buildLib project : map buildLib packageDirs
        results <- mapM (\r -> doesFileExist (r </> relative)) roots
        pure (or results)

warnMissingModules :: St -> [String] -> IO ()
warnMissingModules st mods = forM_ mods $ \m -> do
  ok <- moduleAvailable st m
  unless ok $ do
    state <- readIORef st
    let hint = case rsProjectDir state of
          Just p -> "run `lake build` in " ++ p
          Nothing -> "plain mode has no project modules"
    warning <- cYellow st "warning: "
    emitLn st (warning ++ "module " ++ m
      ++ " not found in the build tree - the backend will silently ignore it ("
      ++ hint ++ ")")

splitOn :: Char -> String -> [String]
splitOn sep s = case break (== sep) s of
  (chunk, []) -> [chunk]
  (chunk, _ : rest) -> chunk : splitOn sep rest

-- Evaluation ----------------------------------------------------------------

data EvalOutcome = EvalDone | EvalIncomplete

-- GHCi-style `it` ------------------------------------------------------------

itName :: Int -> String
itName n = "\171it!" ++ show n ++ "\187"

-- Replace bare `it` (outside strings and comments, at identifier
-- boundaries) with the mangled name of the newest bound result, and
-- `it1`, `it2`, ... with the last :synth batch's candidate splices.
substIt :: Int -> [String] -> String -> String
substIt counter its text
  | counter == 0 && null its = text
  | otherwise = go Nothing text
 where
  target = itName counter
  go _ [] = []
  go _ ('"' : rest) =
    let (lit, rest') = takeStringLit rest in '"' : lit ++ go (Just '"') rest'
  go _ ('-' : '-' : rest) =
    let (c, r) = break (== '\n') rest in "--" ++ c ++ go (Just ' ') r
  go _ ('/' : '-' : rest) =
    let (c, r) = takeBlockComment (1 :: Int) rest
    in "/-" ++ c ++ go (Just ' ') r
  go prev ('i' : 't' : rest)
    | boundaryBefore prev
    , (digits@(_ : _), rest') <- span isDigit rest
    , boundaryAfter rest'
    , index <- read digits
    , index >= 1 && index <= length its =
        its !! (index - 1) ++ go (Just '\187') rest'
    | boundaryBefore prev, boundaryAfter rest, counter > 0 =
        target ++ go (Just '\187') rest
    | otherwise = 'i' : go (Just 'i') ('t' : rest)
  go _ (c : rest) = c : go (Just c) rest

  boundaryBefore Nothing = True
  boundaryBefore (Just c) = not (isIdentChar c) && c /= '.'
  boundaryAfter [] = True
  boundaryAfter (c : _) = not (isIdentChar c)  -- '.' allowed: it.succ
  isIdentChar c = isAlphaNum c || c `elem` "_'!?\171\187"

  takeStringLit ('\\' : c : rest) =
    let (a, b) = takeStringLit rest in ('\\' : c : a, b)
  takeStringLit ('"' : rest) = ("\"", rest)
  takeStringLit (c : rest) = let (a, b) = takeStringLit rest in (c : a, b)
  takeStringLit [] = ("", "")

  takeBlockComment _ [] = ("", "")
  takeBlockComment depth ('/' : '-' : rest) =
    let (a, b) = takeBlockComment (depth + 1) rest in ("/-" ++ a, b)
  takeBlockComment depth ('-' : '/' : rest)
    | depth <= 1 = ("-/", rest)
    | otherwise = let (a, b) = takeBlockComment (depth - 1) rest
                  in ("-/" ++ a, b)
  takeBlockComment depth (c : rest) =
    let (a, b) = takeBlockComment depth rest in (c : a, b)

-- Cosmetic: mangled it-names in backend output display as plain `it`.
rewriteIt :: String -> String
rewriteIt [] = []
rewriteIt s@(c : rest) = case stripItName s of
  Just remainder -> "it" ++ rewriteIt remainder
  Nothing -> c : rewriteIt rest
 where
  stripItName input = do
    afterMark <- stripPrefix "\171it!" input `orElse'`
      (stripPrefix "it!" input >>= ensureBare)
    let (digits, rest') = span (`elem` "0123456789") afterMark
    if null digits then Nothing else
      pure (fromMaybe rest' (stripPrefix "\187" rest'))
  -- for the guillemet-less spelling, digits must follow directly
  ensureBare r@(d : _) | d `elem` "0123456789" = Just r
  ensureBare _ = Nothing
  orElse' (Just x) _ = Just x
  orElse' Nothing y = y

bindIt :: St -> String -> IO ()
bindIt st expr = do
  state <- readIORef st
  candidate <- firstUnusedItCounter st (rsItCounter state + 1) 10000
  forM_ candidate $ \n -> do
    let code = "def " ++ itName n ++ " := (" ++ expr ++ ")"
    result <- runCurrentCmd st code
    case result of
      Right v | not (hasErrors v), Nothing <- respFatal v -> do
        modifyIORef' st (\s -> s { rsItCounter = n })
        advanceEnv st (respEnv v) code
      _ -> pure ()

-- External snapshots do not necessarily have Leant metadata.  Probe forward
-- before binding so an existing generated name cannot make every subsequent
-- evaluation silently fail to update bare `it`.
firstUnusedItCounter :: St -> Int -> Int -> IO (Maybe Int)
firstUnusedItCounter _ _ 0 = pure Nothing
firstUnusedItCounter _ candidate _
  | candidate >= maxBound = pure Nothing
firstUnusedItCounter st candidate attempts = do
  result <- runCurrentCmd st ("#check " ++ itName candidate)
  case result of
    Right response
      | not (hasErrors response), Nothing <- respFatal response ->
          firstUnusedItCounter st (candidate + 1) (attempts - 1)
    _ -> pure (Just candidate)

itCounterForHistory :: ReplState -> [String] -> Int
itCounterForHistory state history =
  itCounterAfterHistory baseCounter history
 where
  baseCounter = maybe 0 snapshotBaseItCounter (rsSnapshotBase state)

advanceEnv :: St -> Maybe Integer -> String -> IO ()
advanceEnv st newEnv code = modifyIORef' st $ \state ->
  let advanced = state
        { rsEnvStack = rsEnv state : rsEnvStack state
        , rsEnv = newEnv
        , rsHistory = rsHistory state ++ [code]
        }
  in if historyEntryAffectsProviders code
       then invalidateProviderWorld advanced
       else advanced

evalInput :: St -> Bool -> String -> IO EvalOutcome
evalInput st allowIncomplete rawText = do
  state0 <- readIORef st
  let text = substIt (rsItCounter state0) (rsSynthIts state0)
        (trim rawText)
  if null text then pure EvalDone else do
    started <- getCurrentTime
    outcome <-
      if firstToken text == "import"
        then do
          let mods = [ trim (drop 7 (trim l))
                     | l <- lines text, "import " `isPrefixOf` trim l ]
          cmdImport st mods
          pure EvalDone
        else if isDeclaration text
          then do
            result <- runCurrentCmd st text
            case result of
              Left err -> do
                emitLn st =<< cRed st err
                pure EvalDone
              Right v
                | allowIncomplete && looksIncomplete v -> pure EvalIncomplete
                | otherwise -> do
                    errored <- printResponse st Nothing v
                    unless errored (advanceEnv st (respEnv v) text)
                    pure EvalDone
          else do
            evalExpression st text
            pure EvalDone
    showTimeFlag <- rsShowTime <$> readIORef st
    when showTimeFlag $ do
      finished <- getCurrentTime
      emitLn st =<< cDim st ("(" ++ show (diffUTCTime finished started) ++ ")")
    pure outcome

-- GHCi-style: try #eval, fall back to #check, then raw, then built-in help.
evalExpression :: St -> String -> IO ()
evalExpression st text = do
  evalResult <- runCurrentCmd st ("#eval (" ++ text ++ ")")
  case evalResult of
    Right v | not (hasErrors v), Nothing <- respFatal v -> do
      _ <- printResponse st Nothing v
      bindIt st text
    Left err -> emitLn st =<< cRed st err
    _ -> do
      checkResult <- runCurrentCmd st ("#check (" ++ text ++ ")")
      case checkResult of
        Right v | not (hasErrors v), Nothing <- respFatal v ->
          void (printResponse st Nothing v)
        _ -> do
          rawResult <- runCurrentCmd st text
          case rawResult of
            Right v | not (hasErrors v), Nothing <- respFatal v -> do
              _ <- printResponse st Nothing v
              advanceEnv st (respEnv v) text
            _ -> do
              printed <- printBuiltinInfo st text
              unless printed $ case evalResult of
                Right v -> void (printResponse st Nothing v)

printBuiltinInfo :: St -> String -> IO Bool
printBuiltinInfo st token = case builtinInfo token of
  Nothing -> pure False
  Just text -> do
    emitLn st =<< cCyan st ("built-in: " ++ trim token)
    forM_ (lines text) $ \l -> emitLn st ("  " ++ l)
    pure True

-- Commands ------------------------------------------------------------------

helpText :: String
helpText = unlines
  [ ""
  , "Enter Lean declarations (def, theorem, ...) or expressions (evaluated with"
  , "#eval, falling back to #check). Multi-line input starts when a line is"
  , "syntactically incomplete; an empty line submits it. :{ and :} delimit an"
  , "explicit block."
  , ""
  , "Commands (GHCi-style):"
  , "  :help, :h, :?            show this help"
  , "  :quit, :q                exit the REPL"
  , "  :type EXPR, :t EXPR      show the type of EXPR       (#check)"
  , "  :info NAME, :i NAME      show the definition of NAME (#print)"
  , "  :load FILE, :l FILE      reset the session and load a .lean file"
  , "  :reload, :r              reload the last loaded file"
  , "  :import MOD              add an import (rebuilds; not over a snapshot)"
  , "  :imports                 list active or post-reset imports"
  , "  :browse [NAMESPACE]      list declarations in a namespace or the session"
  , "  :browse! NAMESPACE       ...including compiler-generated auxiliaries"
  , "  :prove [PROP]            interactively prove PROP tactic by tactic"
  , "                           (no argument: resume the last `sorry`)"
  , "                           suggests a verified next tactic automatically"
  , "  :doc NAME                show the documentation string of NAME"
  , "  :search TEXT             search declaration names (case-insensitive)"
  , "  :search? TYPE            proof search: what proves TYPE? (via exact?)"
  , "  :synth TYPE              synthesize verified terms of TYPE (LJT engine)"
  , "  :synth --behavior-mode filter -- TYPE"
  , "                           filter with the activated startup contract"
  , "  :synth --where List.length result = List.length arg0 -- TYPE"
  , "                           infer the fixed List profile and filter"
  , "  :synth [--behavior-mode rank|filter]"
  , "         --length-contract ABSOLUTE-PATH -- TYPE"
  , "                           use one contract file for this command only"
  , "  :synth --behavior-mode filter"
  , "         --length-model list-scalar-exact-cases"
  , "         --length-inputs arg0[,argN...] --where CLAUSE -- TYPE"
  , "                           use one inline Length constraint"
  , "                           candidates are bound as it1 (= it), it2, ..."
  , "  :set synth-engine E      djinn (default) | exference | both"
  , "  :set synth-steps N       Exference step budget (default 4096)"
  , "  :set synth-classical B   classical candidates for refuted goals"
  , "                           (on|off, default on)"
  , "  :set synth-library B     library premises for recursive inductives"
  , "                           (on|off, default on)"
  , "  :set synth-timeout N     seconds a :synth may search before answering"
  , "                           \"no answer\" (0 waits indefinitely; default"
  , "                           20, or LEANT_SYNTH_TIMEOUT at startup)"
  , "  :set synth-shown N       accepted candidates shown and bound (default 5)"
  , "  :set synth-verify N      fresh candidate groups Lean checks per lane"
  , "                           (default 12; the both engine sends twice that)"
  , "  :set synth-window N      candidate groups a lane may observe (default 60)"
  , "  :set synth-budget N|off  Djinn choice-point budget of the ordinary and"
  , "                           provider lanes (default off = unbounded)"
  , "  :set synth-queue N       Exference queue bound (default 1024)"
  , "  :set synth-providers B   discover live providers after the structural"
  , "                           lane (on|off, default on)"
  , "  :set synth-provider-cap N"
  , "                           providers one discovery may serialize (80)"
  , "  :set synth-library-premises N"
  , "                           rated library offers kept per goal (default 8)"
  , "  :set synth-ratings       list the rated library functions"
  , "  :set synth-debug B       print fragments, providers, lane outcomes, and"
  , "                           metrics (on|off; LEANT_SYNTH_DEBUG at startup)"
  , "  :set backend-timeout N   seconds per Lean request (default 300, or"
  , "                           --timeout at startup; 0 = none)"
  , "  :set                     show every synth setting"
  , "  :set OPT VAL             set_option OPT VAL (persists in the session)"
  , "  :undo                    revert the last state-changing command"
  , "  :reset                   clear definitions/snapshot (keeps imports)"
  , "  :history                 show commands after the current base"
  , "  :env                     show the current environment id"
  , "  :time                    toggle per-command timing"
  , "  :transcript [FILE|on|off] record a full transcript of the session"
  , "  :timestamps [on|off]     timestamp each command in the transcript"
  , "  :pickle FILE             save environment + synthesis companion"
  , "  :unpickle FILE           restore as a new undo/history base"
  , "  :! CMD                   run a shell command"
  , "Any #-prefixed Lean command (#eval, #check, #print axioms) works directly."
  ]

commandNames :: [String]
commandNames =
  [ ":help", ":quit", ":type", ":info", ":load", ":reload", ":import"
  , ":imports", ":browse", ":browse!", ":doc", ":prove", ":search", ":search?"
  , ":set", ":synth", ":undo", ":reset", ":history", ":env", ":time"
  , ":transcript", ":timestamps", ":pickle", ":unpickle", ":goals"
  , ":script", ":suggest", ":auto", ":qed", ":abort"
  ]

-- Returns False when the REPL should exit.
dispatchCommand :: St -> String -> IO Bool
dispatchCommand st line = do
  let (word, rest) = break isSpace (drop 1 (trim line))
      arg = trim rest
  case word of
    w | w `elem` ["q", "quit", "exit"] -> pure False
    w | w `elem` ["h", "help", "?"] -> True <$ emit st helpText
    w | w `elem` ["t", "type"] -> True <$ cmdType st arg
    w | w `elem` ["i", "info"] -> True <$ cmdInfo st arg
    w | w `elem` ["l", "load"] -> True <$ cmdLoad st arg
    w | w `elem` ["r", "reload"] -> do
      loaded <- rsLoadedFile <$> readIORef st
      case loaded of
        Just path -> cmdLoad st path
        Nothing -> emitLn st =<< cRed st "no file has been loaded"
      pure True
    "browse" -> True <$ cmdBrowse st False arg
    "browse!" -> True <$ cmdBrowse st True arg
    "prove" -> True <$ cmdProve st arg
    "doc" -> True <$ cmdDoc st arg
    "search" -> True <$ cmdSearch st False arg
    "search?" -> True <$ cmdSearch st True arg
    "synth" -> True <$ cmdSynth st arg
    "import" -> True <$ cmdImport st (words (map decomma arg))
    "imports" -> do
      state <- readIORef st
      let imports = rsImports state
      forM_ (rsSnapshotBase state) $ \snapshot ->
        emitLn st =<< cDim st ("snapshot base active: "
          ++ snapshotSourcePath snapshot
          ++ " (listed imports take effect after :reset)")
      if null imports
        then emitLn st =<< cDim st "(no configured imports)"
        else forM_ imports (\m -> emitLn st ("import " ++ m))
      pure True
    "set" -> do
      -- :synth's own options are intercepted here; anything else is a
      -- Lean set_option forwarded to the backend
      case words arg of
        ["synth-engine", value] -> case parseSynthEngine value of
          Just engine -> do
            modifyIORef' st (\s -> s { rsSynthEngine = engine })
            emitLn st =<< cDim st ("synth engine: " ++ value)
          Nothing -> emitLn st =<< cRed st
            "usage: :set synth-engine djinn|exference|both"
        ["synth-engine"] -> do
          engine <- rsSynthEngine <$> readIORef st
          emitLn st =<< cDim st
            ("synth engine: " ++ synthEngineName engine)
        ["synth-steps", value]
          | [(n, "")] <- reads value, n > (0 :: Int) -> do
              modifyIORef' st (\s -> s { rsSynthSteps = n })
              emitLn st =<< cDim st ("synth steps: " ++ show n)
          | otherwise -> emitLn st =<< cRed st
              "usage: :set synth-steps N   (a positive step budget)"
        ["synth-steps"] -> do
          steps <- rsSynthSteps <$> readIORef st
          emitLn st =<< cDim st ("synth steps: " ++ show steps)
        ["synth-classical", value] -> setSynthFlag st "synth-classical" value
          (\enabled s -> s { rsSynthClassical = enabled })
        ["synth-classical"] -> showSynthFlag st "synth-classical"
          rsSynthClassical
        ["synth-library", value] -> setSynthFlag st "synth-library" value
          (\enabled s -> s { rsSynthLibrary = enabled })
        ["synth-library"] -> showSynthFlag st "synth-library" rsSynthLibrary
        ["synth-timeout", value] -> setSynthTimeoutLimit st "synth-timeout"
          value "0 waits indefinitely" (\n s -> s { rsSynthTimeout = n })
        ["synth-timeout"] -> showSynthTimeoutLimit st "synth-timeout"
          rsSynthTimeout
        ["synth-shown", value] -> setSynthLimit st "synth-shown" value
          (\n l -> l { synthLimitShown = n })
        ["synth-shown"] -> showSynthLimit st "synth-shown" synthLimitShown
        ["synth-verify", value] -> do
          setSynthLimit st "synth-verify" value
            (\n l -> l { synthLimitTried = n })
          noteFrontierClamp st
        ["synth-verify"] -> showSynthLimit st "synth-verify" synthLimitTried
        ["synth-window", value] -> do
          setSynthLimit st "synth-window" value
            (\n l -> l { synthLimitWindow = n })
          noteFrontierClamp st
        ["synth-window"] -> showSynthLimit st "synth-window" synthLimitWindow
        ["synth-queue", value] -> setSynthLimit st "synth-queue" value
          (\n l -> l { synthLimitQueue = n })
        ["synth-queue"] -> showSynthLimit st "synth-queue" synthLimitQueue
        ["synth-budget", value]
          | value `elem` ["off", "none", "unbounded"] -> do
              modifyIORef' st (\s -> s { rsSynthLimits =
                (rsSynthLimits s) { synthLimitBudget = Nothing } })
              emitLn st =<< cDim st "synth budget: off (unbounded)"
          | [(n, "")] <- reads value, n > (0 :: Integer) -> do
              modifyIORef' st (\s -> s { rsSynthLimits =
                (rsSynthLimits s) { synthLimitBudget = Just n } })
              emitLn st =<< cDim st ("synth budget: " ++ show n)
          | otherwise -> emitLn st =<< cRed st
              "usage: :set synth-budget N|off   (Djinn choice points)"
        ["synth-budget"] -> do
          budget <- synthLimitBudget <$> synthLimitsOf st
          emitLn st =<< cDim st ("synth budget: " ++ showSynthBudget budget)
        ["synth-providers", value] -> setSynthFlag st "synth-providers" value
          (\enabled s -> s { rsSynthProviders = enabled })
        ["synth-providers"] -> showSynthFlag st "synth-providers"
          rsSynthProviders
        ["synth-provider-cap", value]
          | [(n, "")] <- reads value, n > (0 :: Int) -> do
              -- The inventory cache is keyed by provider world and query, so
              -- a cached answer would outlive the cap that produced it.
              modifyIORef' st (\s -> s
                { rsSynthProviderCap = n
                , rsProviderCache = clearProviderCache (rsProviderCache s)
                })
              emitLn st =<< cDim st ("synth provider cap: " ++ show n)
          | otherwise -> emitLn st =<< cRed st
              "usage: :set synth-provider-cap N   (a positive count)"
        ["synth-provider-cap"] -> do
          n <- rsSynthProviderCap <$> readIORef st
          emitLn st =<< cDim st ("synth provider cap: " ++ show n)
        ["synth-library-premises", value]
          | [(n, "")] <- reads value, n >= (0 :: Int) -> do
              modifyIORef' st (\s -> s { rsSynthLibraryPremises = n })
              emitLn st =<< cDim st ("synth library premises: " ++ show n)
          | otherwise -> emitLn st =<< cRed st
              "usage: :set synth-library-premises N   (offers kept per goal)"
        ["synth-library-premises"] -> do
          n <- rsSynthLibraryPremises <$> readIORef st
          emitLn st =<< cDim st ("synth library premises: " ++ show n)
        ["synth-ratings"] -> do
          ratings <- rsRatings <$> readIORef st
          if null ratings
            then emitLn st =<< cDim st "(no rated library functions)"
            else forM_ ratings $ \(name, rating) ->
              emitLn st =<< cDim st (name ++ "  " ++ show rating)
        ["synth-debug", value] -> setSynthFlag st "synth-debug" value
          (\enabled s -> s { rsSynthDebug = enabled })
        ["synth-debug"] -> showSynthFlag st "synth-debug" rsSynthDebug
        ["backend-timeout", value] -> setSynthTimeoutLimit st "backend-timeout"
          value "0 removes the limit"
          (\n s -> s { rsTimeout = if n <= 0 then Nothing else Just n })
        ["backend-timeout"] -> showSynthTimeoutLimit st "backend-timeout"
          (fromMaybe 0 . rsTimeout)
        [] -> showSynthSettings st
        _ -> do
          result <- runCurrentCmd st ("set_option " ++ arg)
          case result of
            Left err -> emitLn st =<< cRed st err
            Right v -> do
              errored <- printResponse st Nothing v
              unless errored
                (advanceEnv st (respEnv v) ("set_option " ++ arg))
      pure True
    "undo" -> do
      state <- readIORef st
      case rsEnvStack state of
        [] -> emitLn st =<< cRed st "nothing to undo"
        prev : stack -> do
          let (dropped, history) = case reverse (rsHistory state) of
                h : hs -> (Just h, reverse hs)
                [] -> (Nothing, [])
              restored = state
                { rsEnv = prev
                , rsEnvStack = stack
                , rsHistory = history
                , rsItCounter = itCounterForHistory state history
                , rsSynthIts = []
                , rsSynthItsProve = False
                , rsLastSorry = Nothing
                , rsComplCache = []
                }
              updated = case dropped of
                Just entry | historyEntryAffectsProviders entry ->
                  invalidateProviderWorld restored
                _ -> restored
          writeIORef st updated
          forM_ dropped $ \d ->
            emitLn st =<< cDim st ("undid: " ++ takeWhile (/= '\n') d)
      pure True
    "reset" -> do
      state <- readIORef st
      backendOr <- ensureBackendProcess st
      case backendOr of
        Left err -> emitLn st =<< cRed st err
        Right (_, spawned) -> do
          rebuilt <- reconstructSession st Nothing (rsImports state) []
          case rebuilt of
            Nothing -> do
              abandonReplacementBackend st spawned
              emitLn st =<< cRed st "reset failed; session unchanged"
            Just session -> do
              modifyIORef' st $ \current -> clearSessionTransients
                (applyReconstruction session current
                  { rsSnapshotBase = Nothing, rsHistory = [] })
              forM_ (rsSnapshotBase state) cleanupSnapshotBase
              emitLn st =<< cDim st
                ("session reset"
                  ++ (if null (rsImports state)
                        then "" else " (imports kept)")
                  ++ if isJust (rsSnapshotBase state)
                       then "; snapshot base cleared" else "")
      pure True
    "history" -> do
      state <- readIORef st
      forM_ (rsSnapshotBase state) $ \snapshot ->
        emitLn st =<< cDim st ("(history starts after snapshot base "
          ++ snapshotSourcePath snapshot ++ ")")
      let history = filter (isNothing . generatedItBinding)
            (rsHistory state)
      if null history
        then emitLn st =<< cDim st "(empty)"
        else forM_ (zip [1 :: Int ..] history) $ \(i, h) ->
          emitLn st (pad i ++ "  " ++ takeWhile (/= '\n') h
            ++ (if '\n' `elem` h then " \8230" else ""))
      pure True
    "env" -> do
      env <- rsEnv <$> readIORef st
      emitLn st ("environment id: " ++ maybe "(none)" show env)
      pure True
    "time" -> do
      modifyIORef' st (\s -> s { rsShowTime = not (rsShowTime s) })
      enabled <- rsShowTime <$> readIORef st
      emitLn st =<< cDim st ("timing " ++ if enabled then "on" else "off")
      pure True
    "transcript" -> do
      case arg of
        "" -> do
          state <- readIORef st
          case rsTranscript state of
            Just (p, _) -> emitLn st ("recording to " ++ p
              ++ if rsTimestamps state then " (with timestamps)" else "")
            Nothing -> emitLn st =<< cDim st
              "transcript is off  (:transcript on|FILE to start)"
        "off" -> transcriptStop st
        "on" -> transcriptStart st Nothing
        path -> transcriptStart st (Just path)
      pure True
    "timestamps" -> do
      case arg of
        a | a `elem` ["on", "true", "1", "yes"] ->
          modifyIORef' st (\s -> s { rsTimestamps = True })
        a | a `elem` ["off", "false", "0", "no"] ->
          modifyIORef' st (\s -> s { rsTimestamps = False })
        "" -> modifyIORef' st (\s -> s { rsTimestamps = not (rsTimestamps s) })
        _ -> emitLn st =<< cRed st "usage: :timestamps [on|off]"
      enabled <- rsTimestamps <$> readIORef st
      emitLn st =<< cDim st
        ("per-command timestamps " ++ if enabled then "on" else "off")
      pure True
    "pickle" -> True <$ cmdPickle st arg
    "unpickle" -> True <$ cmdUnpickle st arg
    "!" -> do
      result <- try (callCommand arg)
      case (result :: Either SomeException ()) of
        Left err -> emitLn st =<< cRed st (show err)
        Right () -> pure ()
      pure True
    _ -> do
      emitLn st =<< cRed st ("unknown command :" ++ word ++ "  (:help for help)")
      pure True
 where
  decomma c = if c == ',' then ' ' else c
  pad i = let s = show i in replicate (3 - length s) ' ' ++ s

cmdType :: St -> String -> IO ()
cmdType st rawArg
  | null rawArg = emitLn st =<< cRed st "usage: :type EXPR"
  | otherwise = do
      state <- readIORef st
      let arg = substIt (rsItCounter state) (rsSynthIts state) rawArg
      result <- runCurrentCmd st ("#check (" ++ arg ++ ")")
      case result of
        Left err -> emitLn st =<< cRed st err
        Right v
          | hasErrors v || isJust (respFatal v) -> do
              printed <- printBuiltinInfo st arg
              unless printed (void (printResponse st Nothing v))
          | otherwise -> void (printResponse st Nothing v)

cmdInfo :: St -> String -> IO ()
cmdInfo st arg
  | null arg = emitLn st =<< cRed st "usage: :info NAME"
  | otherwise = do
      printResult <- runCurrentCmd st ("#print " ++ arg)
      case printResult of
        Left err -> emitLn st =<< cRed st err
        Right v
          | hasErrors v || isJust (respFatal v) -> do
              checkResult <- runCurrentCmd st ("#check (" ++ arg ++ ")")
              case checkResult of
                Right cv | not (hasErrors cv), Nothing <- respFatal cv ->
                  void (printResponse st Nothing cv)
                _ -> do
                  printed <- printBuiltinInfo st arg
                  unless printed (void (printResponse st Nothing v))
          | otherwise -> void (printResponse st
              (Just (\t -> formatInfo t `orElse` indentDefBody t)) v)
 where
  orElse (Just x) _ = Just x
  orElse Nothing y = y

cmdImport :: St -> [String] -> IO ()
cmdImport st mods
  | null mods = emitLn st =<< cRed st "usage: :import MODULE"
  | otherwise = do
      state <- readIORef st
      case rsSnapshotBase state of
        Just _ -> emitLn st =<< cRed st
          "cannot add imports to an opaque snapshot; use :reset or :load first"
        Nothing -> do
          fresh <- newModules st (rsImports state) mods
          if null fresh
            then emitLn st =<< cDim st "no new modules to import"
            else do
              let imports = rsImports state ++ fresh
              emitLn st =<< cDim st
                "rebuilding session with new imports (this re-elaborates history)..."
              rebuilt <- reconstructSession st Nothing imports (rsHistory state)
              case rebuilt of
                Nothing -> emitLn st =<< cRed st
                  "import failed; session unchanged"
                Just session -> do
                  modifyIORef' st $ \current ->
                    applyReconstruction session current { rsImports = imports }
                  emitLn st =<< cDim st "imports added"

newModules :: St -> [String] -> [String] -> IO [String]
newModules st existing mods = go (nub mods) []
 where
  go [] acc = pure (reverse acc)
  go (m : rest) acc
    | m `elem` existing = go rest acc
    | otherwise = do
        ok <- moduleAvailable st m
        if ok then go rest (m : acc) else do
          warnMissingModules st [m]
          go rest acc

cmdLoad :: St -> String -> IO ()
cmdLoad st arg
  | null arg = emitLn st =<< cRed st "usage: :load FILE"
  | otherwise = do
      let path0 = arg
      exists0 <- doesFileExist path0
      let path = if exists0 || '.' `elem` takeFileName path0
            then path0 else path0 <.> "lean"
      exists <- doesFileExist path
      if not exists
        then emitLn st =<< cRed st ("file not found: " ++ path)
        else do
          contents <- readFileUtf8 path
          let (fileImports, body) = splitHeader contents
          state <- readIORef st
          fresh <- newModules st (rsImports state) fileImports
          let imports = rsImports state ++ fresh
          emitLn st =<< cDim st ("loading " ++ path ++ " ...")
          started <- getCurrentTime
          backendOr <- ensureBackendProcess st
          case backendOr of
            Left err -> emitLn st =<< cRed st err
            Right (_, spawned) -> do
              baseSession <- reconstructSession st Nothing imports []
              case baseSession of
                Nothing -> do
                  abandonReplacementBackend st spawned
                  emitLn st =<< cRed st
                    "failed to elaborate imports; session unchanged"
                Just imported -> do
                  loaded <- if null (trim body)
                    then pure (Just imported)
                    else do
                      result <- runCmd st (reconstructedBaseEnv imported) body
                      case result of
                        Left err -> do
                          emitLn st =<< cRed st err
                          pure Nothing
                        Right response -> do
                          errored <- printResponse st Nothing response
                          case (errored, respEnv response) of
                            (False, Just env) -> pure (Just imported
                              { reconstructedCurrentEnv = Just env
                              , reconstructedEnvStack =
                                  [reconstructedBaseEnv imported]
                              })
                            (False, Nothing) -> do
                              emitLn st =<< cRed st
                                "file elaboration returned no environment"
                              pure Nothing
                            (True, _) -> pure Nothing
                  case loaded of
                    Nothing -> do
                      abandonReplacementBackend st spawned
                      emitLn st =<< cRed st "load failed; session unchanged"
                    Just session -> do
                      modifyIORef' st $ \current -> clearSessionTransients
                        (applyReconstruction session current
                          { rsSnapshotBase = Nothing
                          , rsImports = imports
                          , rsHistory = [body | not (null (trim body))]
                          , rsLoadedFile = Just path
                          })
                      forM_ (rsSnapshotBase state) cleanupSnapshotBase
                      finished <- getCurrentTime
                      emitLn st =<< cDim st ("loaded " ++ takeFileName path
                        ++ " (" ++ show (length (lines body)) ++ " lines) in "
                        ++ show (round (diffUTCTime finished started) :: Integer)
                        ++ "s")
 where
  splitHeader contents = go (lines contents) []
   where
    go [] imports = (reverse imports, "")
    go (l : rest) imports
      | "import " `isPrefixOf` trim l =
          go rest (trim (drop 7 (trim l)) : imports)
      | null (trim l) || "--" `isPrefixOf` trim l = go rest imports
      | otherwise = (reverse imports, intercalate "\n" (l : rest))

-- :browse -------------------------------------------------------------------

-- The introspection metaprogram run inside the browse environment. One
-- logInfo with all matches keeps the response to a single message.
-- The namespace is spliced as string literals (not a backquoted name
-- literal), so arbitrary component spellings cannot break the parser.
browseProgram :: Bool -> [String] -> String
browseProgram showAll nameComponents = unlines $
  [ "open Lean in run_cmd do"
  , "  let env \8592 getEnv"
  , "  let pre : Name := ["
      ++ intercalate ", " (map leanStringLit nameComponents)
      ++ "].foldl (fun a s => Name.str a s) Name.anonymous"
  ]
  ++ (if showAll then
  [ "  let keep (n : Name) : Bool := !n.isInternal" ]
  else generatedFilterLines)
  ++
  [ "  let names := env.constants.fold (init := #[]) fun a n _ =>"
  , "    if pre.isPrefixOf n && keep n then a.push n else a"
  , "  if names.isEmpty then"
  , "    logInfo \"(no declarations found)\""
  , "  else"
  , "    let sorted := names.qsort (\183.toString < \183.toString)"
  , "    logInfo (String.intercalate \"\\n\" (sorted.toList.map toString))"
  ]

-- Build (or reuse) an environment containing the session's imports plus the
-- Lean metaprogramming API, without touching the user's environment.
ensureBrowseEnv :: St -> IO (Either String Integer)
ensureBrowseEnv = ensureBrowseEnv' False

ensureBrowseEnv' :: Bool -> St -> IO (Either String Integer)
ensureBrowseEnv' quiet st = do
  state <- readIORef st
  case rsBrowseEnv state of
    Just env -> pure (Right env)
    Nothing -> case rsSnapshotBase state of
      -- The synthesis base is also a Lean-tooling environment and, unlike a
      -- fresh import environment, retains declarations hidden in the opaque
      -- snapshot.
      Just _ -> do
        envOr <- ensureSynthBase st
        case envOr of
          Left err -> pure (Left err)
          Right env -> do
            modifyIORef' st (\s -> s { rsBrowseEnv = Just env })
            pure (Right env)
      Nothing -> do
        unless quiet $
          emitLn st =<< cDim st
            "preparing browse environment (session imports + Lean)..."
        let imports = nub (rsImports state ++ ["Lean.Elab.Command"])
        result <- runCmd st Nothing (unlines (map ("import " ++) imports))
        case result of
          Left err -> pure (Left err)
          Right response
            | hasErrors response || isJust (respFatal response) -> do
                _ <- printResponse st Nothing response
                pure (Left "failed to build the browse environment")
            | Just env <- respEnv response -> do
                modifyIORef' st (\s -> s { rsBrowseEnv = Just env })
                pure (Right env)
            | otherwise -> pure (Left "browse environment has no id")

leanStringLit :: String -> String
leanStringLit s = '"' : concatMap escape s ++ "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape c = [c]

-- shared filter for compiler-generated auxiliary names
generatedFilterLines :: [String]
generatedFilterLines =
  [ "  let aux : List String :="
  , "    [\"rec\", \"recOn\", \"casesOn\", \"brecOn\", \"binductionOn\","
  , "     \"below\", \"ibelow\", \"noConfusion\", \"noConfusionType\","
  , "     \"ctorElim\", \"ctorElimType\", \"ctorIdx\", \"sizeOf_spec\","
  , "     \"injEq\", \"inj\", \"eq_def\", \"decEq\"]"
  , "  let keep (n : Name) : Bool :="
  , "    !n.isInternalDetail &&"
  , "    !n.components.any fun c => match c with"
  , "      | .str _ s => aux.contains s"
  , "      | _ => false"
  ]

validDottedName :: String -> Maybe [String]
validDottedName arg =
  let comps = splitOn '.' arg
  in if any isSpace arg || any null comps then Nothing else Just comps

cmdDoc :: St -> String -> IO ()
cmdDoc st rawArg = do
  let arg = dropWhile (== '@') (trim rawArg)
  case (arg, validDottedName arg) of
    ("", _) -> emitLn st =<< cRed st "usage: :doc NAME"
    (_, Nothing) -> emitLn st =<< cRed st ("invalid name `" ++ arg ++ "`")
    (_, Just comps) -> do
      envOr <- ensureBrowseEnv st
      case envOr of
        Left err -> emitLn st =<< cRed st err
        Right env -> do
          let program = unlines
                [ "open Lean in run_cmd do"
                , "  let env \8592 getEnv"
                , "  let n : Name := ["
                    ++ intercalate ", " (map leanStringLit comps)
                    ++ "].foldl (fun a s => Name.str a s) Name.anonymous"
                , "  if !env.contains n then"
                , "    logInfo s!\"unknown constant `{n}` "
                    ++ "(session-local names have no docstrings)\""
                , "  else"
                , "    match \8592 findDocString? env n with"
                , "    | some doc => logInfo doc"
                , "    | none => logInfo \"(no documentation string)\""
                ]
          result <- runCmd st (Just env) program
          case result of
            Left err -> emitLn st =<< cRed st err
            Right v -> void (printResponse st Nothing v)

cmdSearch :: St -> Bool -> String -> IO ()
cmdSearch st byType arg
  | null arg = emitLn st =<< cRed st "usage: :search TEXT  |  :search? TYPE"
  | byType = do
      result <- runCurrentCmd st ("example : (" ++ arg ++ ") := by exact?")
      case result of
        Left err -> emitLn st =<< cRed st err
        Right v
          | any (\(s, d) -> s == "error" && "unknown tactic" `isInfixOf` d)
              (respMessages v) -> do
            message <- cRed st ":search? needs the `exact?` tactic \8212 "
            hint <- cBold st ":import Mathlib.Tactic"
            emitLn st (message ++ "try " ++ hint)
          | otherwise -> void (printResponse st Nothing v)
  | otherwise = do
      envOr <- ensureBrowseEnv st
      case envOr of
        Left err -> emitLn st =<< cRed st err
        Right env -> do
          state <- readIORef st
          -- hide Lean-API hits unless the user imported Lean themselves
          let leanImported = any (\i -> i == "Lean" || "Lean." `isPrefixOf` i)
                (rsImports state)
              hidden = if leanImported then "[]" else "[\"Lean\"]"
              program = unlines $
                [ "open Lean in run_cmd do"
                , "  let env \8592 getEnv"
                , "  let needle := (" ++ leanStringLit arg ++ ").toLower"
                , "  let hidden : List String := " ++ hidden
                ] ++ generatedFilterLines ++
                [ "  let hits := env.constants.fold (init := #[]) fun a n _ =>"
                , "    if keep n && !hidden.contains n.getRoot.toString"
                , "        && (n.toString.toLower.splitOn needle).length > 1"
                , "    then a.push n else a"
                , "  if hits.isEmpty then"
                , "    logInfo \"(no matches)\""
                , "  else"
                , "    let sorted := hits.qsort (\183.toString < \183.toString)"
                , "    let shown := sorted.toList.take 100"
                , "    let more := if sorted.size > 100 then"
                , "      s!\"\\n... ({sorted.size} matches, first 100 shown)\" else \"\""
                , "    logInfo (String.intercalate \"\\n\" (shown.map toString) ++ more)"
                ]
          result <- runCmd st (Just env) program
          case result of
            Left err -> emitLn st =<< cRed st err
            Right v -> void (printResponse st Nothing v)
          history <- rsHistory <$> readIORef st
          let matching = [ n | n <- concatMap sessionDeclNames history
                         , lower arg `isInfixOf` lower n ]
          unless (null matching) $ do
            emitLn st =<< cDim st "-- declared in this session:"
            mapM_ (emitLn st) matching
 where
  lower = map toLower

-- :synth ---------------------------------------------------------------------
--
-- Term synthesis via the in-process Djex Djinn (LJT) engine; see
-- SYNTHESIS_PROPOSAL.md.  The pipeline: translate the goal on the backend
-- (serializer metaprogram), refuse honestly when out of fragment, run the
-- engine, then verify every shown candidate with `example : (T) := term`
-- in the user's environment - the engine is never trusted.

-- | The base environment for :synth goal translation: session imports
-- plus the Lean metaprogramming API, with the compiled serializer
-- prelude on top (run_tac runs interpreted and cannot host `let rec`).
ensureSynthBase :: St -> IO (Either String Integer)
ensureSynthBase st = do
  state <- readIORef st
  case rsSynthBase state of
    Just env -> pure (Right env)
    Nothing -> case rsSnapshotBase state of
      Just snapshot -> prepareSnapshotBase snapshot
      Nothing -> prepareImportedBase state
 where
  remember env = do
    modifyIORef' st (\state -> state { rsSynthBase = Just env })
    pure (Right env)

  compilePrelude imported externalSnapshot = do
    names <- map fst . rsRatings <$> readIORef st
    prelude <- runCmd st (Just imported) (synthPrelude names)
    case prelude of
      Left err -> pure (Left err)
      Right response
        | hasErrors response || isJust (respFatal response) ->
            if externalSnapshot
              then pure (Left ("`:synth` is unavailable for this external "
                ++ "snapshot because it does not contain Lean's "
                ++ "metaprogramming API; recreate it with Leant `:pickle` "
                ++ "to save a synthesis companion"))
              else do
                _ <- printResponse st Nothing response
                pure (Left "failed to compile the synthesis serializer")
        | Just env <- respEnv response -> remember env
        | otherwise -> pure (Left "synthesis environment has no id")

  prepareSnapshotBase snapshot = do
    emitLn st =<< cDim st
      "preparing synthesis environment from snapshot base..."
    case snapshotToolingPath snapshot of
      Nothing -> rebuildFromMain snapshot
      Just tooling -> do
        restored <- restoreEnvironmentArtifact st tooling
        case restored of
          Right env -> compilePrelude env False
          Left (SnapshotTransportError err) -> pure (Left err)
          Left (SnapshotRejected err) -> do
            snapshotWarning st ("synthesis companion could not be restored: "
              ++ err ++ "; rebuilding from the main snapshot")
            rebuildFromMain snapshot

  rebuildFromMain snapshot = do
    restored <- restoreEnvironmentArtifact st
      (snapshotEnvironmentPath snapshot)
    case restored of
      Left (SnapshotTransportError err) -> pure (Left err)
      Left (SnapshotRejected err) -> pure (Left err)
      Right snapshotEnv -> compilePrelude snapshotEnv True

  prepareImportedBase state = do
    emitLn st =<< cDim st
      "preparing synthesis environment (session imports + Lean)..."
    let imports = nub (rsImports state ++ ["Lean"])
    result <- runCmd st Nothing (unlines (map ("import " ++) imports))
    case result of
      Left err -> pure (Left err)
      Right response
        | hasErrors response || isJust (respFatal response) -> do
            _ <- printResponse st Nothing response
            pure (Left "failed to build the synthesis environment")
        | Just importEnv <- respEnv response ->
            compilePrelude importEnv False
        | otherwise -> pure (Left "synthesis environment has no id")

-- | The synthesis environment: the base plus the session history, so goals
-- may mention session-local declarations.  A cached chronological prefix is
-- extended by replaying only the appended suffix; undo or replacement starts
-- again from the base.  Entries Lean rejects (e.g. names clashing with the
-- Lean import) are skipped with a note, but a transport failure aborts the
-- replay so a backend-local environment id is never cached after death.
ensureSynthEnv :: St -> IO (Either String Integer)
ensureSynthEnv st = do
  state <- readIORef st
  let history = rsHistory state
  case rsSynthEnv state of
    Just (env, cachedHistory) -> case planReplay cachedHistory history of
      Reuse -> pure (Right env)
      ReplaySuffix suffix -> finishReplay env history suffix
      ReplayAll fullHistory -> replayAll fullHistory
    Nothing -> replayAll history
 where
  replayAll history = do
    baseOr <- ensureSynthBase st
    case baseOr of
      Left err -> pure (Left err)
      Right base -> finishReplay base history history

  finishReplay env history entries = do
    replayed <- replaySynth env entries
    case replayed of
      Left err -> pure (Left err)
      Right env' -> do
        modifyIORef' st (\s -> s { rsSynthEnv = Just (env', history) })
        pure (Right env')

  replaySynth env [] = pure (Right env)
  replaySynth env (code : rest) = do
    result <- runCmd st (Just env) code
    case result of
      Left err -> pure (Left err)
      Right v | not (hasErrors v), Nothing <- respFatal v
              , Just env' <- respEnv v ->
        replaySynth env' rest
      Right _ -> do
        emitLn st =<< cDim st
          ("note: `" ++ takeWhile (/= '\n') code
           ++ "` is not visible to :synth (it did not replay over the "
           ++ "Lean import)")
        replaySynth env rest

-- | The goal target (the part after \8866) of a pretty-printed goal, plus
-- the context lines before it.
goalTarget :: String -> Maybe (String, [String])
goalTarget goalText = case rest of
  [] -> Nothing
  (turnstile : more) ->
    let first' = trim (drop 1 (dropWhile isSpace turnstile))
        target = trim (intercalate "\n" (first' : more))
    in if null target then Nothing else Just (target, before)
 where
  (before, rest) =
    break (\l -> "\8866" `isPrefixOf` dropWhile isSpace l) (lines goalText)

-- | Wrap a pretty-printed goal's accessible hypotheses around its
-- target as explicit binders (proposal A of SYNTHESIS_PROPOSAL.md \167 7):
-- @h : A@ and @n m : T@ context lines become @\8704 (h : A) (n m : T),
-- target@, so the ordinary pipeline synthesizes with the hypotheses as
-- premises and a selected candidate is applied to the hypothesis
-- names.  Returns (wrapped goal, argument names, skipped inaccessible
-- names).
wrapGoal :: String -> Maybe (String, [String], [String])
wrapGoal goalText = do
  (target, before) <- goalTarget goalText
  let hyps = parseHyps before
      usable = [(names, ty) | (names, ty) <- hyps, all accessible names]
      skipped =
        [n | (names, _) <- hyps, n <- names, not (accessible n)]
      args = concatMap fst usable
      wrapped
        | null usable = target
        | otherwise = "\8704" ++ concat
            [ " (" ++ unwords names ++ " : " ++ ty ++ ")"
            | (names, ty) <- usable
            ]
            ++ ", " ++ target
  pure (wrapped, args, skipped)
 where
  accessible = notElem '\10013'  -- the \10013 marker of inaccessible names

-- | Parse pretty-printed context lines into hypothesis groups
-- (names, type).  A hypothesis starts on an unindented line holding the
-- first @ : @ separator; indented lines continue the previous type.
parseHyps :: [String] -> [([String], String)]
parseHyps = go . filter (not . null . trim)
 where
  go [] = []
  go (l : ls)
    | "case " `isPrefixOf` trim l = go ls
    | take 1 l == " " = go ls  -- stray continuation
    | (names@(_ : _), ty0) <- splitHyp l =
        let (conts, rest) = span (\x -> take 1 x == " ") ls
            ty = unwords (map trim (ty0 : conts))
        in (names, ty) : go rest
    | otherwise = go ls
  splitHyp l = case findSep "" l of
    Just (namePart, ty) -> (words namePart, ty)
    Nothing -> ([], "")
  findSep pre s = case s of
    (' ' : ':' : ' ' : rest) -> Just (reverse pre, rest)
    (c : rest) -> findSep (c : pre) rest
    [] -> Nothing

providerCacheCapacity :: Int
providerCacheCapacity = 12

-- | Wall-clock guard on the engine, in seconds (0 waits indefinitely).
-- Propositional goals answer in microseconds, but bounded hypothesis
-- instantiation can widen a quantified goal's space enough to run for
-- minutes, which an interactive REPL must not do silently.  The session
-- setting is read at each :synth; ':set synth-timeout N' changes it and
-- LEANT_SYNTH_TIMEOUT seeds it at startup.
synthTimeoutSeconds :: St -> IO Int
synthTimeoutSeconds st = rsSynthTimeout <$> readIORef st

-- | Print every :synth session setting with its current value.
showSynthSettings :: St -> IO ()
showSynthSettings st = do
  state <- readIORef st
  let limits = rsSynthLimits state
      row name value = emitLn st =<< cDim st (name ++ ": " ++ value)
  row "synth-engine" (synthEngineName (rsSynthEngine state))
  row "synth-steps" (show (rsSynthSteps state))
  row "synth-queue" (show (synthLimitQueue limits))
  row "synth-budget" (showSynthBudget (synthLimitBudget limits))
  row "synth-window" (show (synthLimitWindow limits))
  row "synth-verify" (show (synthLimitTried limits))
  row "synth-shown" (show (synthLimitShown limits))
  row "synth-classical" (onOffLabel (rsSynthClassical state))
  row "synth-library" (onOffLabel (rsSynthLibrary state))
  row "synth-library-premises" (show (rsSynthLibraryPremises state))
  row "synth-providers" (onOffLabel (rsSynthProviders state))
  row "synth-provider-cap" (show (rsSynthProviderCap state))
  row "synth-timeout" (showSynthTimeout (rsSynthTimeout state))
  row "backend-timeout" (showSynthTimeout (fromMaybe 0 (rsTimeout state)))
  row "synth-debug" (onOffLabel (rsSynthDebug state))

-- | How a setting names itself in its own report: the option spelling with
-- its separators opened up, as every ':set' report has always printed it.
settingLabel :: String -> String
settingLabel = map (\c -> if c == '-' then ' ' else c)

-- | Set one positive integer field of the retunable search bounds.
setSynthLimit
  :: St -> String -> String -> (Int -> SynthLimits -> SynthLimits) -> IO ()
setSynthLimit st name value update = case reads value of
  [(n, "")] | n > (0 :: Int) -> do
    modifyIORef' st (\s -> s { rsSynthLimits = update n (rsSynthLimits s) })
    emitLn st =<< cDim st (settingLabel name ++ ": " ++ show n)
  _ -> emitLn st =<< cRed st
    ("usage: :set " ++ name ++ " N   (a positive count)")

-- | Show one field of the retunable search bounds.
showSynthLimit :: St -> String -> (SynthLimits -> Int) -> IO ()
showSynthLimit st name project = do
  n <- project <$> synthLimitsOf st
  emitLn st =<< cDim st (settingLabel name ++ ": " ++ show n)

-- | Set one wall clock, in whole seconds; both clocks read @0@ as "no
-- limit" and report themselves the same way.
setSynthTimeoutLimit
  :: St -> String -> String -> String -> (Int -> ReplState -> ReplState)
  -> IO ()
setSynthTimeoutLimit st name value zeroMeaning update = case reads value of
  [(n, "")] | n >= (0 :: Int) -> do
    modifyIORef' st (update n)
    emitLn st =<< cDim st (settingLabel name ++ ": " ++ showSynthTimeout n)
  _ -> emitLn st =<< cRed st
    ("usage: :set " ++ name ++ " N   (seconds; " ++ zeroMeaning ++ ")")

-- | Show one wall clock.
showSynthTimeoutLimit :: St -> String -> (ReplState -> Int) -> IO ()
showSynthTimeoutLimit st name project = do
  limit <- project <$> readIORef st
  emitLn st =<< cDim st (settingLabel name ++ ": " ++ showSynthTimeout limit)

-- | Set one @on@ / @off@ session switch.
setSynthFlag :: St -> String -> String -> (Bool -> ReplState -> ReplState)
  -> IO ()
setSynthFlag st name value update
  | value `elem` ["on", "true"] = accept True
  | value `elem` ["off", "false"] = accept False
  | otherwise = emitLn st =<< cRed st ("usage: :set " ++ name ++ " on|off")
 where
  accept enabled = do
    modifyIORef' st (update enabled)
    emitLn st =<< cDim st (settingLabel name ++ ": " ++ onOffLabel enabled)

-- | Show one @on@ / @off@ session switch.
showSynthFlag :: St -> String -> (ReplState -> Bool) -> IO ()
showSynthFlag st name project = do
  enabled <- project <$> readIORef st
  emitLn st =<< cDim st (settingLabel name ++ ": " ++ onOffLabel enabled)

-- | How every switch reports its state.
onOffLabel :: Bool -> String
onOffLabel enabled = if enabled then "on" else "off"

-- | Report the clamp when the candidate window is narrower than the
-- verification frontier: 'admissibleCursorBatch' silently narrows the batch,
-- so the two settings say so together rather than disagreeing in silence.
noteFrontierClamp :: St -> IO ()
noteFrontierClamp st = do
  state <- readIORef st
  let limits = rsSynthLimits state
      frontier = synthVerificationWindowWith limits (rsSynthEngine state)
      admitted = admissibleCursorBatch limits frontier
  when (admitted /= frontier) $ emitLn st =<< cDim st
    ("note: each lane verifies " ++ show admitted ++ " groups, clamped by "
     ++ "synth-window " ++ show (synthLimitWindow limits))

-- | How ':set synth-budget' reports the setting.
showSynthBudget :: Maybe Integer -> String
showSynthBudget = maybe "off (unbounded)" show

-- | The session's retunable search bounds.
synthLimitsOf :: St -> IO SynthLimits
synthLimitsOf st = rsSynthLimits <$> readIORef st

-- | Whether ':set synth-debug on' (or LEANT_SYNTH_DEBUG at startup) is in
-- force for this session.
synthDebugEnabled :: St -> IO Bool
synthDebugEnabled = fmap rsSynthDebug . readIORef

-- | How ':set synth-timeout' and ':set backend-timeout' report a limit.
showSynthTimeout :: Int -> String
showSynthTimeout n
  | n <= 0 = "0 (wait indefinitely)"
  | otherwise = show n ++ "s"

-- | The startup value of the :synth wall clock: LEANT_SYNTH_TIMEOUT when it
-- is a whole number of seconds (0 = wait indefinitely), otherwise 20.
initialSynthTimeoutSeconds :: IO Int
initialSynthTimeoutSeconds = do
  setting <- lookupEnv "LEANT_SYNTH_TIMEOUT"
  pure $ case setting >>= readMaybeInt of
    Just n | n >= 0 -> n
    _ -> 20
 where
  readMaybeInt text = case reads (trim text) of
    [(n, "")] -> Just n
    _ -> Nothing

cmdSynth :: St -> String -> IO ()
cmdSynth st rawArg = case parseLengthSynthNativeInlineCommand rawArg of
  Left failure -> do
    emitLn st =<< cRed st
      ("inline finite-spine Length command rejected: " ++ show failure)
    emitLn st =<< cRed st
      ("usage: :synth --where LEAN-LENGTH-CLAUSE -- TYPE")
  Right (Just command) -> runNativeInline command
  Right Nothing -> case parseLengthSynthInlineCommand rawArg of
    Left failure -> do
      emitLn st =<< cRed st
        ("inline finite-spine Length command rejected: " ++ show failure)
      emitLn st =<< cRed st
        ("usage: :synth --behavior-mode filter --length-model " ++
         "list-scalar-exact-cases|list-binary-product-exact-cases " ++
         "--length-inputs arg0[,argN...] --where CLAUSE -- TYPE")
    Right (Just command) -> runInline command
    Right Nothing -> runEstablished
 where
  runEstablished :: IO ()
  runEstablished = case parseLengthSynthCommand rawArg of
    Left _ -> emitLn st =<< cRed st
      ("usage: :synth TYPE | :synth [--behavior-mode rank|filter] " ++
       "[--length-contract ABSOLUTE-PATH] -- TYPE " ++
       "(TYPE may be empty in prove mode / after a `sorry`)")
    Right command -> do
      state <- readIORef st
      case resolveSynthCommandGoal state $ lengthSynthCommandGoal command of
        Left err -> emitLn st =<< cRed st err
        Right (goal, args, skipped) -> do
          requestOr <- lengthAssessmentRequestForCommand state command
          case requestOr of
            Left failure -> emitLn st =<< cRed st failure
            Right assessmentRequest -> do
              reportSynthCommandScope st args skipped
              synthRun assessmentRequest st args goal

  runInline :: LengthSynthInlineCommand -> IO ()
  runInline command = do
    state <- readIORef st
    case resolveSynthCommandGoal state $ lengthSynthInlineCommandGoal command of
      Left err -> emitLn st =<< cRed st err
      Right (goal, args, skipped) ->
        case authorizeExplicitLengthAssessmentRequest
            LengthBehaviorFilter (rsLengthAssessmentMode state) of
          Left failure -> emitLn st =<< cRed st
            ("finite-spine Length request rejected before IO: " ++
             show failure)
          Right permission ->
            case parseLeanLengthWhereSource
                $ lengthSynthInlineCommandWherePlan command of
              Left failure -> emitLn st =<< cRed st
                ("inline finite-spine Length where clause rejected: " ++
                 show failure)
              Right source -> do
                reportSynthCommandScope st args skipped
                synthInlineRun permission source st args goal

  runNativeInline :: LengthSynthNativeInlineCommand -> IO ()
  runNativeInline command = do
    state <- readIORef st
    case resolveSynthCommandGoal state
        $ lengthSynthNativeInlineCommandGoal command of
      Left err -> emitLn st =<< cRed st err
      Right (goal, args, skipped) ->
        case authorizeExplicitLengthAssessmentRequest
            LengthBehaviorFilter (rsLengthAssessmentMode state) of
          Left failure -> emitLn st =<< cRed st
            ("finite-spine Length request rejected before IO: " ++
             show failure)
          Right permission ->
            case parseLeanNativeLengthWhereSource
                $ lengthSynthNativeInlineCommandWherePlan command of
              Left failure -> emitLn st =<< cRed st
                ("inline finite-spine Length where clause rejected: " ++
                 show failure)
              Right source -> do
                reportSynthCommandScope st args skipped
                synthNativeInlineRun permission source st args goal

-- | Resolve the ordinary explicit goal or the current prove/sorry goal before
-- any Length request authority is selected.  The result retains the same
-- inaccessible-hypothesis accounting used by every synthesis entrance.
resolveSynthCommandGoal
  :: ReplState
  -> String
  -> Either String (String, [String], [String])
resolveSynthCommandGoal state arg
  | not (null arg) = Right
      (substIt (rsItCounter state) (rsSynthIts state) arg, [], [])
  | otherwise = case rsProve state of
      Just pv | (_, goal : _, _) : _ <- pvStack pv -> extract goal
      _ -> case rsLastSorry state of
        Just (_, goal) -> extract goal
        Nothing -> Left
          ("usage: :synth TYPE   (or bare :synth in prove mode / " ++
           "after a `sorry`)")
 where
  extract goal = case wrapGoal goal of
    Just resolved -> Right resolved
    Nothing -> Left "cannot extract the goal target"

-- | Report only after the command-local Length request has been admitted.
-- This preserves the established ordering for file-backed and startup
-- requests and gives the inline entrance the same premise diagnostics.
reportSynthCommandScope :: St -> [String] -> [String] -> IO ()
reportSynthCommandScope st args skipped = do
  unless (null skipped) $ emitLn st =<< cDim st
    ("(inaccessible hypotheses are not visible to :synth: " ++
     unwords skipped ++ ")")
  unless (null args) $ emitLn st =<< cDim st
    ("(synthesizing with hypotheses " ++ unwords args ++ " as premises)")

-- | Select one command-local assessment authority.  Explicit requests must
-- first obtain permission from the already activated mode; only then is the
-- path admitted and read exactly once.  The decoded contract and permission
-- travel on the stack through every synthesis lane and never enter ReplState.
lengthAssessmentRequestForCommand
  :: ReplState
  -> LengthSynthCommand
  -> IO (Either String LengthAssessmentRequest)
lengthAssessmentRequestForCommand state command =
  let behavior = lengthSynthCommandBehaviorMode command
      mode = rsLengthAssessmentMode state
      rejectedBeforeIO failure = Left
        $ "finite-spine Length request rejected before IO: "
            ++ show failure
  in
  case lengthSynthCommandContractPath command of
    Nothing -> pure $ case startupLengthAssessmentRequest behavior mode of
      Left failure -> rejectedBeforeIO failure
      Right assessmentRequest -> Right assessmentRequest
    Just path -> case authorizeExplicitLengthAssessmentRequest behavior mode of
      Left failure -> pure $ rejectedBeforeIO failure
      Right permission -> case mkLengthContractFileRequest
          $ LengthContractFileSource path
              lengthContractFileDefaultTimeoutMilliseconds of
        Left failure -> pure $ Left
          $ "one-shot finite-spine Length contract admission failed: "
              ++ show failure
        Right admittedRequest -> do
          loaded <- loadLengthContractFile admittedRequest
          pure $ case loaded of
            Left failure -> Left
              $ "one-shot finite-spine Length contract load failed: "
                  ++ show failure
            Right selection -> Right
              $ explicitLengthAssessmentRequest permission selection

synthRun :: LengthAssessmentRequest -> St -> [String] -> String -> IO ()
synthRun assessmentRequest st args goal =
  withLengthAssessmentRequestContext assessmentRequest $ \assessmentContext -> do
    translateSynthGoalWithRetry st goal
      $ synthGo assessmentContext st args

-- | Activate one already authorized and bounded inline source only after Lean
-- translation has supplied the physical arrow arity.  Failed translation or
-- target association creates no counterexample bank; success creates exactly
-- one nominal context shared by every synthesis lane.
synthInlineRun
  :: ExplicitLengthAssessmentPermission
  -> LeanLengthWhereSource
  -> St
  -> [String]
  -> String
  -> IO ()
synthInlineRun permission source st args goal =
  translateSynthGoalWithRetry st goal
    $ \retriedVars translatedGoal parsed ->
      case resolveLeanLengthWhereSource
          (translatedPhysicalArrowArity parsed) source of
        Left failure -> emitLn st =<< cRed st
          ("inline finite-spine Length where target rejected: " ++
           show failure)
        Right selection ->
          withLengthAssessmentRequestContext
              (explicitLengthAssessmentRequest permission selection)
            $ \assessmentContext ->
                synthGo assessmentContext st args retriedVars
                  translatedGoal parsed

-- | Activate the concise source after translation supplies the exact List
-- arguments and scalar-or-product result shape used for conservative defaults.
synthNativeInlineRun
  :: ExplicitLengthAssessmentPermission
  -> LeanNativeLengthWhereSource
  -> St
  -> [String]
  -> String
  -> IO ()
synthNativeInlineRun permission source st args goal =
  translateSynthGoalWithRetry st goal
    $ \retriedVars translatedGoal parsed ->
      case resolveLeanNativeLengthWhereSource parsed source of
        Left failure -> emitLn st =<< cRed st
          ("inline finite-spine Length where target rejected: " ++
           show failure)
        Right selection ->
          withLengthAssessmentRequestContext
              (explicitLengthAssessmentRequest permission selection)
            $ \assessmentContext ->
                synthGo assessmentContext st args retriedVars
                  translatedGoal parsed

-- | Translate once and preserve the existing narrowing retry state machine,
-- while letting each request entrance choose when its nominal Length context
-- begins.  The continuation is invoked exactly once on the first successful
-- direct or narrowed translation.
translateSynthGoalWithRetry
  :: St
  -> String
  -> (Maybe [String] -> String -> ParsedGoal -> IO ())
  -> IO ()
translateSynthGoalWithRetry st goal continuation = do
  outcome <- translateGoal st goal
  case outcome of
    Right parsed -> continuation Nothing goal parsed
    Left errors
      | any stuckUniverse errors ->
          synthUniverseRetry st goal errors continuation
      | otherwise -> reportTranslationErrors st errors
 where
  stuckUniverse = ("stuck at solving universe constraint" `isInfixOf`)

-- | Count only source arrows.  Type quantifiers, instance binders, and exact
-- contexts remain part of the renderer layout but are not physical target
-- arguments in a Length contract.
translatedPhysicalArrowArity :: ParsedGoal -> Natural
translatedPhysicalArrowArity parsed = fromIntegral $ length
  [() | SlotArrow _ <- fragSpine $ pgFrag parsed]

-- | Run the serializer on one goal; 'Left' carries the error texts.
-- An error next to an emitted translation means Lean recovered from a
-- bad goal and the translation is garbage, so errors always win.
translateGoal :: St -> String -> IO (Either [String] ParsedGoal)
translateGoal st goal = do
  envOr <- ensureSynthEnv st
  case envOr of
    Left err -> pure (Left [err])
    Right env -> do
      result <- runCmd st (Just env) (serializerProgram goal)
      case result of
        Left err -> pure (Left [err])
        Right v -> do
          let infos = [d | (sev, d) <- respMessages v, sev == "info"]
              errors = [d | (sev, d) <- respMessages v, sev == "error"]
          pure $ case (respFatal v, errors) of
            (Just fatal, _) -> Left [fatal]
            (_, _ : _) -> Left errors
            (Nothing, []) -> case parseUniqueGoalTranslation infos of
              Left err -> Left [err]
              Right parsed -> Right parsed

reportTranslationErrors :: St -> [String] -> IO ()
reportTranslationErrors st errors = do
  emitLn st =<< cRed st "cannot translate this goal:"
  forM_ errors $ \e ->
    forM_ (lines (trim e)) $ \l -> emitLn st ("  " ++ l)

-- | Auto-bound variables get `Sort ?u`, and Type-level connectives
-- (\215/\8853) over arrows of such variables leave Lean's universe unifier
-- stuck.  Binding the same variables at `Type u` makes those constraints
-- solvable, so: find the goal's auto-implicit-shaped tokens, keep the
-- ones that resolve to nothing in the synthesis environment's scope
-- (full name resolution, so opened namespaces and session declarations
-- are respected and never shadowed), and retry with them bound
-- explicitly at Type.  When the wrapped goal fails because some
-- variable must not live at Type (say, an operand of a Prop
-- connective), that variable's marker universe @u_synth_v@ appears in
-- the new errors; such variables are dropped and the retry narrows
-- until it translates or no candidates remain.
synthUniverseRetry
  :: St
  -> String
  -> [String]
  -> (Maybe [String] -> String -> ParsedGoal -> IO ())
  -> IO ()
synthUniverseRetry st goal originalErrors continuation = do
  let vars = autoShapedTokens goal
  unknowns <- if null vars then pure [] else do
    envOr <- ensureSynthEnv st
    case envOr of
      Left _ -> pure []
      Right env -> do
        result <- runCmd st (Just env) (unknownCheckProgram vars)
        case result of
          Right v | not (hasErrors v), Nothing <- respFatal v ->
            pure (parseUnknowns v)
          _ -> pure []
  narrowingRetry unknowns
 where
  narrowingRetry [] = giveUp
  narrowingRetry wrapVars = do
    let binders = concat
          [" {" ++ v ++ " : Type u_synth_" ++ v ++ "}" | v <- wrapVars]
        wrapped = "\8704" ++ binders ++ ", " ++ goal
    emitLn st =<< cDim st ("(retrying with " ++ unwords wrapVars
      ++ " : Type \8212 Sort-polymorphic elaboration was stuck)")
    outcome <- translateGoal st wrapped
    case outcome of
      Right parsed -> continuation (Just wrapVars) wrapped parsed
      Left retryErrors -> do
        let misplaced =
              [ v | v <- wrapVars
              , any (mentionsMarker ("u_synth_" ++ v)) retryErrors ]
            remaining = [v | v <- wrapVars, v `notElem` misplaced]
        if null misplaced || null remaining
          then giveUp
          else narrowingRetry remaining

  giveUp = do
    emitLn st =<< cDim st
      "(the auto-Type retry did not apply; the original errors:)"
    reportTranslationErrors st originalErrors
    emitLn st =<< cDim st
      ("hint: annotate the variables' types yourself, e.g. "
       ++ ":synth (\8704 a b : Type, ...)")

  parseUnknowns v = case
      [ trim d | (sev, d) <- respMessages v, sev == "info"
      , "(unknown" `isPrefixOf` trim d ] of
    (d : _) -> words (takeWhile (/= ')') (drop (length "(unknown") d))
    [] -> []

-- | Whether an error text names this marker universe.  A plain infix
-- test would let @u_synth_a@ match inside @u_synth_a1@ and blame a
-- variable Lean never complained about, so the match must end at a
-- non-identifier character.
mentionsMarker :: String -> String -> Bool
mentionsMarker marker text = any ends (tails text)
 where
  ends suffix = case stripPrefix marker suffix of
    Just (c : _) -> not (isAlphaNum c || c == '_' || c == '\'')
    Just [] -> True
    Nothing -> False

-- | Tokens shaped like short auto-implicit variables: one plain letter
-- (ASCII or Greek), optionally followed by digits, primes, or subscript
-- digits - a deliberate subset of Lean's relaxed auto-implicit shape
-- (which admits any unknown atomic identifier; wrapping arbitrary
-- unknown words would turn typos into phantom Type binders).  Tokens
-- adjacent to a dot are qualified names or namespace prefixes, reserved
-- letters (\955, \931, \928) can never be binders, and letterlike notation
-- symbols (\8469, \8484, ...) are parser tokens rather than identifiers, so
-- all of those are excluded.
autoShapedTokens :: String -> [String]
autoShapedTokens text = nub (go Nothing text)
 where
  go prev s = case break identChar s of
    (_, []) -> []
    (skipped, s') ->
      let (t, rest) = span identChar s'
          prevChar = if null skipped then prev else Just (last skipped)
          keep = autoShape t
            && prevChar /= Just '.'
            && not (qualifier rest)
      in [t | keep] ++ go (Just (last t)) rest
  autoShape (c : rest) = plainLetter c && all suffixChar rest
  autoShape [] = False
  plainLetter c =
    (isAscii c && isAlpha c)
      || (c >= '\945' && c <= '\969' && c /= '\955')  -- α..ω minus λ
      || (c >= '\913' && c <= '\937'                  -- Α..Ω minus Σ Π
          && c `notElem` "\931\928")
  suffixChar c =
    isDigit c || c == '\'' || (c >= '\8320' && c <= '\8329')
  qualifier ('.' : c : _) = identChar c
  qualifier _ = False

unknownCheckProgram :: [String] -> String
unknownCheckProgram vars = unlines
  [ "open Lean in run_cmd do"
  , "  let names : List String := ["
      ++ intercalate ", " (map leanStringLit vars) ++ "]"
  , "  let mut unknown : List String := []"
  , "  for s in names do"
  , "    let resolved \8592 resolveGlobalName (Name.mkSimple s)"
  , "    if resolved.isEmpty then"
  , "      unknown := unknown ++ [s]"
  , "  logInfo (\"(unknown \" ++ String.intercalate \" \" unknown ++ \")\")"
  ]

synthGo
  :: LengthAssessmentContext command
  -> St
  -> [String]
  -> Maybe [String]
  -> String
  -> ParsedGoal
  -> IO ()
synthGo assessmentContext st args retriedVars goal parsed = do
  debugFrag <- synthDebugEnabled st
  when debugFrag $
    emitLn st =<< cDim st ("debug fragment: " ++ show (pgFrag parsed))
  synthGo' assessmentContext st args retriedVars goal parsed

synthGo'
  :: LengthAssessmentContext command
  -> St
  -> [String]
  -> Maybe [String]
  -> String
  -> ParsedGoal
  -> IO ()
synthGo' assessmentContext st args retriedVars goal parsed = do
  state <- readIORef st
  let fragment = pgFrag parsed
      engine = rsSynthEngine state
      refusal = fragRefusal fragment
      limits = rsSynthLimits state
      libraryPremises
        | rsSynthLibrary state =
            selectLibraryPremises (rsSynthLibraryPremises state)
              (rsRatings state) parsed
        | otherwise = []
      -- A live value can inhabit an otherwise opaque atomic goal, but it
      -- cannot repair a structural translation that stopped at FDepth.
      -- ':set synth-providers off' skips discovery altogether.
      discoverProviders = rsSynthProviders state && case refusal of
        Nothing -> True
        Just _ -> fragProviderMayOpen fragment
      -- A live provider inventory can add a capped batch of values to
      -- either engine's search (@:set synth-provider-cap@, default eighty).  Preserve the ordinary structural search as an isolated first
      -- lane: if one of its candidates survives Lean verification, discovering
      -- providers cannot improve whether the goal is solved and must not crowd
      -- that term out.  A provider-free Djinn refutation is retained as a
      -- fallback, but is not a verdict about the larger live environment: a
      -- verified provider candidate must still get a chance to win.  Atomic/
      -- provider-open refusals go straight to the provider lane because the
      -- baseline has no usable structure.
      structuralFirst = isNothing refusal
  debug <- synthDebugEnabled st
  when (structuralFirst && debug) $
    forM_ libraryPremises $ \(name, premise) ->
      emitLn st =<< cDim st
        ("debug premise: " ++ name ++ " : " ++ show premise)
  limit <- synthTimeoutSeconds st
  started <- getCurrentTime
  let deadline
        | limit <= 0 = Nothing
        | otherwise = Just (addUTCTime (fromIntegral limit) started)
      runSynthesis includeLibrary checked laneEngine providers accumulation =
        let base = synthesizeWithProvidersSkippingDetailedWith limits
              laneEngine (rsSynthSteps state) checked providers fragment
            -- Library premises are an isolated, deliberately budgeted
            -- extension of the structural lane.  Their candidates lead the
            -- unchanged base candidates, while only the base may contribute a
            -- negative verdict.  Provider lanes remain separate so discovery
            -- cannot crowd out either ordinary or library synthesis.
            outcome
              | includeLibrary && not (null libraryPremises) =
                  mergeLibraryDetailedOutcomes base
                    (synthesizeTunedDetailedWith limits laneEngine
                      (rsSynthSteps state)
                      (synthLimitWindow limits, Just 100000)
                      [ (name, stripRecCtors premise)
                      | (name, premise) <- libraryPremises
                      ]
                      (stripRecCtors fragment) fragment)
              | otherwise = base
        in runSynthLaneCursor assessmentContext
          (ordinarySynthLaneCursorPolicy assessmentContext laneEngine limits)
          deadline st goal id outcome accumulation
      -- This first checkpoint is limited to the ordinary provider-free
      -- baseline.  Retuned schedules, library premises, filter successors,
      -- provider widening, and classical lanes retain their exact serial path.
      -- RTS capabilities are inspected only after this static policy admits
      -- the structural baseline.
      baselinePolicy =
        ordinarySynthLaneCursorPolicy assessmentContext EngineBoth limits
      parallelBaselineStaticallyEligible =
        engine == EngineBoth
          && limits == defaultSynthLimits
          && null libraryPremises
          && not (synthLaneCursorAllowsFilterSuccessor baselinePolicy)
      runParallelStructuralBaseline accumulation = do
        let runBranch laneEngine =
              synthesizeWithProvidersSkippingDetailedWith limits
                laneEngine (rsSynthSteps state) Set.empty [] fragment
        prepared <- forceDetailedSynthPairBefore
          (synthLimitTried limits) deadline
          (runBranch EngineDjinn) (runBranch EngineExference)
        case prepared of
          Nothing -> pure SynthLaneRun
            { synthLaneRunAccumulation = accumulation
            , synthLaneRunCheckedFrontierSpellings = []
            , synthLaneRunCandidateGroupCount = 0
            , synthLaneRunNotes = []
            , synthLaneRunEnd = SynthLaneRunTimedOut
            }
          Just branches ->
            let outcome = fmap
                  (uncurry $ mergeDetailedOutcomesSkipping Set.empty)
                  branches
            in runSynthLaneCursor assessmentContext baselinePolicy deadline
              st goal id outcome accumulation
  if structuralFirst
    then do
      baseline <-
        if parallelBaselineStaticallyEligible
          then do
            capabilities <- getNumCapabilities
            if capabilities >= 2
              then runParallelStructuralBaseline emptySynthLaneAccumulation
              else runSynthesis True Set.empty engine []
                emptySynthLaneAccumulation
          else runSynthesis True Set.empty engine []
            emptySynthLaneAccumulation
      case synthLaneRunEnd baseline of
        -- A provider inventory cannot repair an engine failure, and the two
        -- lanes share one wall-clock deadline.  Preserve the baseline
        -- diagnostic instead of spending another full timeout and replacing
        -- it with a less informative fallback result.
        SynthLaneRunTimedOut -> report deadline baseline
        SynthLaneRunCursorAdmissionFailed _ -> report deadline baseline
        SynthLaneRunEngineFailed _ -> report deadline baseline
        -- A complete Djinn refutation proves the provider-free structural
        -- environment impossible, but a live declaration may still inhabit
        -- the goal.  Keep the proof-backed result as the fallback for empty,
        -- unavailable, timed-out, or unsuccessful provider search.  Reporting
        -- it (and therefore any classical retry) is delayed until those
        -- constructive lanes have failed.
        SynthLaneRunRefuted True -> do
          providers <-
            if discoverProviders
              then loadSynthProviders st (pgProviderQuery parsed)
              else pure []
          if null providers
            then report deadline baseline
            else runProviderLanes deadline (Just baseline)
              (runSynthesis False) Set.empty
              (synthLaneRunAccumulation baseline)
              (providerStages engine providers)
        SynthLaneRunStoppedByDisposition ->
          finalize (synthLaneRunAccumulation baseline)
        _ -> continueAfterBaseline deadline runSynthesis discoverProviders
          engine baseline
    else do
      providers <-
        if discoverProviders
          then loadSynthProviders st (pgProviderQuery parsed)
          else pure []
      case refusal of
        Just reason
          | not (fragProviderMayOpen fragment && not (null providers)) ->
              emitLn st =<< cRed st ("out of fragment: " ++ reason)
        _ -> runProviderLanes deadline Nothing (runSynthesis False) Set.empty
          emptySynthLaneAccumulation
          (providerStages engine providers)
 where
  continueAfterBaseline runDeadline runLane discover laneEngine baseline = do
    providers <-
      if discover
        then loadSynthProviders st (pgProviderQuery parsed)
        else pure []
    let accumulation = synthLaneRunAccumulation baseline
        checked = Set.fromList
          (synthLaneRunCheckedFrontierSpellings baseline)
    if null providers
      then report runDeadline baseline
      else runProviderLanes runDeadline Nothing (runLane False)
        checked accumulation (providerStages laneEngine providers)

  runProviderLanes runDeadline fallback runLane checked accumulation lanes =
    case lanes of
    [] -> finish SynthLaneRun
      { synthLaneRunAccumulation = accumulation
      , synthLaneRunCheckedFrontierSpellings = []
      , synthLaneRunCandidateGroupCount = 0
      , synthLaneRunNotes = []
      , synthLaneRunEnd = SynthLaneRunNoTerm
      }
    (laneEngine, providers) : remaining -> do
      fresh <- runLane checked laneEngine providers accumulation
      case synthLaneRunEnd fresh of
        SynthLaneRunTimedOut -> finish fresh
        SynthLaneRunCursorAdmissionFailed _ -> finish fresh
        SynthLaneRunEngineFailed _ -> finish fresh
        SynthLaneRunStoppedByDisposition ->
          finalize (synthLaneRunAccumulation fresh)
        _ ->
          if null remaining
            then finish fresh
            else runProviderLanes runDeadline fallback runLane
              (Set.union checked $ Set.fromList
                $ synthLaneRunCheckedFrontierSpellings fresh)
              (synthLaneRunAccumulation fresh) remaining
   where
    -- Once the provider-free lane has proved a sound refutation, every
    -- provider-side miss is weaker structural evidence.  Retain that result as
    -- the control-flow fallback while carrying every completed lane into final
    -- behavioral output.  'report' is also the sole classical entry point, so
    -- this ordering keeps classical search strictly after constructive
    -- provider search.
    finish fresh = case fallback of
      Just fallbackRun -> report runDeadline
        (fallbackRun
          { synthLaneRunAccumulation = synthLaneRunAccumulation fresh })
      Nothing -> report runDeadline fresh

  finalize accumulation = do
    _ <- finalizeSynthLaneAccumulation st args goal accumulation
    pure ()

  -- Abnormal engine completion remains visible even if an earlier lane was
  -- behaviorally rejected.  Completed lane effects are finalized first, and
  -- no weaker lane notes are appended to the abnormal diagnostic.
  report _ laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunTimedOut } = do
    _ <- finalizeSynthLaneAccumulation st args goal
      (synthLaneRunAccumulation laneRun)
    limit <- synthTimeoutSeconds st
    emitLn st =<< cYellow st
      ("the engine did not finish within " ++ show limit
       ++ "s \8212 no answer, not a verdict")
    emitLn st =<< cDim st
      ("(bounded hypothesis instantiation can widen the search a lot; "
       ++ ":set synth-timeout N chooses another number of seconds, "
       ++ "or 0 to wait indefinitely)")
  report _ laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunCursorAdmissionFailed err } = do
    _ <- finalizeSynthLaneAccumulation st args goal
      (synthLaneRunAccumulation laneRun)
    emitLn st =<< cRed st
      ("synthesis engine error: detailed cursor admission failed: " ++ show err)
  report _ laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunEngineFailed err } = do
    _ <- finalizeSynthLaneAccumulation st args goal
      (synthLaneRunAccumulation laneRun)
    emitLn st =<< cRed st ("synthesis engine error: " ++ err)
  report runDeadline laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunRefuted sound }
    | sound = do
          wantClassical <- rsSynthClassical <$> readIORef st
          classicalAccumulation <-
            if wantClassical
              then synthClassical assessmentContext runDeadline
                st goal parsed (synthLaneRunAccumulation laneRun)
              else pure (synthLaneRunAccumulation laneRun)
          classical <- finalizeSynthLaneAccumulation
            st args goal classicalAccumulation
          case classical of
            SynthLaneNoVerified -> do
              message <- cYellow st
                ("provably uninhabited \8212 no closed term of this "
                 ++ "polymorphic type exists")
              emitLn st message
            SynthLaneSurvivors _ _ -> pure ()
            SynthLaneAllBehaviorallyRejected _ -> pure ()
            SynthLaneAssessmentPreserved _ _ -> pure ()
          forM_ retriedVars $ \vars -> emitLn st =<< cDim st
            ("(for the goal with the unresolved variables " ++ unwords vars
             ++ " bound at Type; a variable the goal itself binds is "
             ++ "shadowed harmlessly \8212 annotate types yourself if "
             ++ "this is not what you meant)")
          case classical of
            SynthLaneNoVerified -> when (pgSort parsed == GoalProp) $
              emitLn st =<< cDim st
                ("(constructively \8212 a classical proof may still exist; "
                 ++ "this is not a disproof of the proposition)")
            SynthLaneSurvivors _ _ -> pure ()
            SynthLaneAllBehaviorallyRejected _ -> pure ()
            SynthLaneAssessmentPreserved _ _ -> pure ()
    | otherwise = do
          disposition <- finalizeSynthLaneAccumulation
            st args goal (synthLaneRunAccumulation laneRun)
          case disposition of
            SynthLaneNoVerified -> do
              let atoms = fragUnsafeAtoms (pgFrag parsed)
                  listing = intercalate "`, `" (take 3 atoms)
              emitLn st =<< cYellow st
                ("no term found within bounds (opaque atoms `" ++ listing
                 ++ "` hide structure the engine cannot analyze \8212 "
                 ++ "not a refutation)")
            SynthLaneSurvivors _ _ -> pure ()
            SynthLaneAllBehaviorallyRejected _ -> pure ()
            SynthLaneAssessmentPreserved _ _ -> pure ()
  report _ laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunNoTerm } = do
      disposition <- finalizeSynthLaneAccumulation st args goal
        (synthLaneRunAccumulation laneRun)
      case disposition of
        SynthLaneNoVerified -> do
          emitLn st =<< cYellow st "no term found within the search bounds"
          reportSynthLaneNotes st (synthLaneRunNotes laneRun)
        SynthLaneSurvivors _ _ -> pure ()
        SynthLaneAllBehaviorallyRejected _ -> pure ()
        SynthLaneAssessmentPreserved _ _ -> pure ()
  report _ laneRun@SynthLaneRun
      { synthLaneRunEnd = SynthLaneRunStoppedByDisposition } =
    finalize (synthLaneRunAccumulation laneRun)
  report _ laneRun = reportCandidateCompletion laneRun

  reportCandidateCompletion laneRun = do
    disposition <- finalizeSynthLaneAccumulation st args goal
      (synthLaneRunAccumulation laneRun)
    case disposition of
      SynthLaneNoVerified -> do
        emitLn st =<< cRed st
          ("the engine proposed "
           ++ show (synthLaneRunCandidateGroupCount laneRun)
           ++ " candidate(s) but none survived Lean verification")
        reportSynthLaneNotes st (synthLaneRunNotes laneRun)
      SynthLaneSurvivors _ _ -> pure ()
      SynthLaneAllBehaviorallyRejected _ -> pure ()
      SynthLaneAssessmentPreserved _ _ -> pure ()

-- | Ask Lean for the bounded value inventory relevant to this goal.  A
-- provider failure degrades to structural synthesis: inventory discovery is
-- an optimization and never weakens the ordinary Djinn/Exference boundary.
loadSynthProviders :: St -> ProviderQuery -> IO [ProviderFrag]
loadSynthProviders st query = do
  cached <- atomicModifyIORef' st $ \state ->
    let (result, cache') = lookupProviderCache
          (rsProviderWorld state) query (rsProviderCache state)
    in (state { rsProviderCache = cache' }, result)
  maybe discover pure cached
 where
  discover = do
    envOr <- ensureSynthEnv st
    case envOr of
      Left _ -> pure []
      Right env -> do
        state <- readIORef st
        let world = rsProviderWorld state
            sessionNames = nub
              (concatMap sessionDeclNames (rsHistory state))
        result <- runCmd st (Just env)
          (providerProgramWith (rsSynthProviderCap state) sessionNames query)
        case result of
          Right response
            | not (hasErrors response), Nothing <- respFatal response ->
                case
                  [ trim body
                  | (severity, body) <- respMessages response
                  , severity == "info"
                  , isPrefixOf "(providers" (trim body)
                  ] of
                  translated : _ -> case parseProviderSexp translated of
                    Right providers -> do
                      modifyIORef' st $ \current ->
                        if rsProviderWorld current == world
                          then current
                            { rsProviderCache = insertProviderCache
                                world query providers
                                (rsProviderCache current)
                            }
                          else current
                      debug <- synthDebugEnabled st
                      when debug $
                        forM_ providers $ \provider ->
                          emitLn st =<< cDim st
                            ("debug provider: " ++ show provider)
                      pure providers
                    Left err -> unavailable err
                  [] -> unavailable "Lean emitted no provider inventory"
          Left err -> unavailable err
          Right _ -> unavailable "Lean rejected provider discovery"

  unavailable reason = do
    debug <- synthDebugEnabled st
    when debug $
      emitLn st =<< cDim st ("provider inventory unavailable: " ++ reason)
    pure []

-- | The default library inventory with ratings, Djex @*.ratings@ style:
-- lower is better, and a rating of 100 or more disables an entry.  A
-- project file @leant.ratings@ (lines of @Name Rating@, @#@ comments)
-- merges over these at startup - override an entry to re-rank or
-- disable it, add new names to grow the inventory toward the
-- browse-env scale of SYNTHESIS_PROPOSAL.md phase 3.
defaultRatings :: [(String, Double)]
defaultRatings =
  [ ("List.map", 1.0)
  , ("List.append", 1.5)
  , ("List.flatten", 1.5)
  , ("List.foldr", 2.0)
  , ("List.reverse", 2.0)
  , ("List.length", 2.0)
  , ("Nat.add", 2.0)
  , ("List.replicate", 2.2)
  , ("List.foldl", 2.5)
  , ("List.flatMap", 2.5)
  , ("List.join", 3.0)
  , ("List.zip", 3.0)
  , ("Nat.mul", 3.0)
  , ("List.take", 3.2)
  , ("List.drop", 3.2)
  , ("List.zipWith", 3.4)
  , ("List.filterMap", 3.5)
  -- List.head? earned its exclusion: its Option-valued codomain
  -- expands into case analysis and floods the batch with match junk
  ]

-- | The merged inventory, best rating first: defaults overlaid with the
-- working directory's @leant.ratings@, entries rated out (>= 100) and
-- names that could not splice into a Lean name literal dropped.
loadRatings :: IO [(String, Double)]
loadRatings = do
  exists <- doesFileExist "leant.ratings"
  user <- if not exists then pure [] else do
    contents <- readFile "leant.ratings"
    pure
      [ (name, rating)
      | line <- lines contents
      , let payload = takeWhile (/= '#') line
      , [name, ratingText] <- [words payload]
      , (rating, "") <- reads ratingText
      ]
  let merged = foldl override defaultRatings user
      override table (name, rating) =
        (name, rating) : [entry | entry@(n, _) <- table, n /= name]
  pure $ sortOn snd
    [ entry
    | entry@(name, rating) <- merged
    , rating < 100
    , not (null name)
    , all nameChar name
    ]
 where
  nameChar c = isAlphaNum c || c `elem` "_.'!?"

-- | The serializer's library premises, filtered to the ones this goal
-- can honestly use: in-fragment (no depth marker), and mentioning no
-- recursive inductive the goal does not itself mention (an unknown
-- occurrence would drag a fresh opaque atom and its constructor
-- premises into the search).  Two functions with the same type at the
-- offered instantiation (List.flatten and List.join, say) would only
-- double the engine's work, so the type dedups, keeping the
-- better-rated name (offers arrive in rating order).  Every premise
-- multiplies the junk-proof space, so the survivors are capped, keeping
-- first a premise whose type is exactly the goal (the type-directed
-- library lookup answer) and then preferring the better rating, with
-- small types - which apply directly rather than through invented
-- arguments - breaking ties.  The order matters beyond the cap: the
-- engine tries antecedents oldest-first, so the front of this list is
-- the front of the search.
selectLibraryPremises
  :: Int -> [(String, Double)] -> ParsedGoal -> [(String, Frag)]
selectLibraryPremises kept ratings parsed = take kept (sortOn rank offered)
 where
  goalKeys = fragRecKeys (pgFrag parsed)
  offered = nubBy (\x y -> snd x == snd y)
    [ prem
    | prem@(_, frag) <- pgPrems parsed
    , not (fragHasDepth frag)
    , all (`elem` goalKeys) (fragRecKeys frag)
    ]
  rank (name, frag) =
    ( frag /= pgFrag parsed
    , fromMaybe 99 (lookup name ratings)
    , fragSize frag
    )
  fragSize :: Frag -> Int
  fragSize f = 1 + case f of
    FArr a b -> fragSize a + fragSize b
    FProd a b -> fragSize a + fragSize b
    FLeanProd a b -> fragSize a + fragSize b
    FSum a b -> fragSize a + fragSize b
    FAll _ _ b -> fragSize b
    _ -> 0

-- | Combine the base search with the library-premise search: library
-- candidates first (they use the goal's arguments through real library
-- functions - the feature), the base run's other candidates after,
-- and negative verdicts only from the base run (the library run is
-- budgeted, so its negatives claim nothing).
mergeLibraryDetailedOutcomes
  :: Either String DetailedSynthOutcome
  -> Either String DetailedSynthOutcome
  -> Either String DetailedSynthOutcome
mergeLibraryDetailedOutcomes base lib = case (base, lib) of
  (Left err, _) -> Left err
  (_, Left err) -> Left err
  (Right x, Right y) -> Right (merge x y)
 where
  merge x y = case (x, y) of
    (DetailedSynthCandidates a na, DetailedSynthCandidates b nb) ->
      let libraryVariants = map detailedCandidateGroupVariants b
      in DetailedSynthCandidates
        (b ++ filter
          ((`notElem` libraryVariants) . detailedCandidateGroupVariants) a)
        (nub (na ++ nb))
    (DetailedSynthCandidates a na, other) ->
      DetailedSynthCandidates a (na ++ notesOf other)
    (other, DetailedSynthCandidates b nb) ->
      DetailedSynthCandidates b (notesOf other ++ nb)
    (other, _) -> other
  notesOf outcome = case outcome of
    DetailedSynthCandidates _ notes -> notes
    DetailedSynthNoTerm notes -> notes
    DetailedSynthRefuted _ -> []

-- | The batch a lane may request of its cursor: at least one group, and
-- never more than the window the cursor observes through.  The two bounds
-- are independent settings (@:set synth-verify@ and @:set synth-window@),
-- so a session may name a window below the verification frontier; clamping
-- keeps such a session searching instead of failing cursor admission.
admissibleCursorBatch :: SynthLimits -> Int -> Int
admissibleCursorBatch limits requested =
  max 1 (min requested (synthLimitWindow limits))

-- | Ordinary rank and disabled commands retain one established verification
-- window.  Filtering may consume exactly one returned successor, giving
-- standalone engines 12+12 groups and the combined engine 24+24 without
-- rerunning either search.
ordinarySynthLaneCursorPolicy
  :: LengthAssessmentContext command
  -> SynthEngine
  -> SynthLimits
  -> SynthLaneCursorPolicy
ordinarySynthLaneCursorPolicy assessmentContext engine limits =
  SynthLaneCursorPolicy
    { synthLaneCursorBatchSize =
        admissibleCursorBatch limits (synthVerificationWindowWith limits engine)
    , synthLaneCursorAllowsFilterSuccessor = case
        lengthAssessmentContextBehaviorMode assessmentContext of
          LengthBehaviorRank -> False
          LengthBehaviorFilter -> True
    , synthLaneCursorRetainsRunNotes = True
    , synthLaneCursorWindow = synthLimitWindow limits
    , synthLaneCursorShown = synthLimitShown limits
    }

-- | Admit and force one opaque cursor step before the command's absolute
-- deadline.  Admission stays outside the timeout and, by Engine's contract,
-- does not demand the cursor.  A missing deadline retains the explicit
-- @LEANT_SYNTH_TIMEOUT=0@ wait-forever behavior.
runDetailedSynthCursorBefore
  :: Int
  -> Int
  -> Maybe UTCTime
  -> DetailedSynthCursor
  -> IO
      (Maybe
        (Either DetailedSynthCursorError DetailedSynthCursorStep))
runDetailedSynthCursorBefore requested window deadline cursor =
  case advanceDetailedSynthCursorWith window requested cursor of
    Left err -> pure (Just (Left err))
    Right step -> case deadline of
      Nothing ->
        Just (Right step) <$ evaluate (forceDetailedSynthCursorStep step)
      Just absoluteDeadline -> do
        now <- getCurrentTime
        let remainingMicros = floor
              (realToFrac (diffUTCTime absoluteDeadline now) * 1000000
                :: Double)
        if remainingMicros <= 0
          then pure Nothing
          else do
            done <- timeout remainingMicros
              (evaluate (forceDetailedSynthCursorStep step))
            pure (Right step <$ done)

-- | Force one bounded fresh prefix from each independent engine beneath the
-- command's existing absolute deadline.  The worker boundary is deliberately
-- one standalone verification frontier, not the engine's full bounded trace;
-- any additional demand introduced by cross-engine deduplication remains in
-- the merged cursor and is forced later beneath the remaining same deadline.
-- Normal engine failures are values, observed with Djinn/left precedence by
-- the scoped pair runner.  A timeout cancels and joins both workers.
forceDetailedSynthPairBefore
  :: Int
  -> Maybe UTCTime
  -> Either String DetailedSynthOutcome
  -> Either String DetailedSynthOutcome
  -> IO (Maybe (Either String (DetailedSynthOutcome, DetailedSynthOutcome)))
forceDetailedSynthPairBefore requested deadline djinn exference =
  beforeDeadline $ runParallelEitherPairOrdered
    (strictPrefix djinn) (strictPrefix exference)
 where
  strictPrefix outcome =
    outcome <$ evaluate (forceDetailedOutcome requested outcome)

  beforeDeadline action = case deadline of
    Nothing -> Just <$> action
    Just absoluteDeadline -> do
      now <- getCurrentTime
      let remainingMicros = floor
            (realToFrac (diffUTCTime absoluteDeadline now) * 1000000
              :: Double)
      if remainingMicros <= 0
        then pure Nothing
        else timeout remainingMicros action

-- | Filtering owns one command-wide deadline, including both classical
-- routes.  Rank and disabled commands retain their historical classical
-- budgets: excluded middle and double negation each capture a fresh full
-- configured duration when that route begins.  The explicit zero setting
-- remains an unbounded wait in either policy.
classicalSynthLaneDeadline
  :: LengthAssessmentContext command
  -> Maybe UTCTime
  -> St
  -> IO (Maybe UTCTime)
classicalSynthLaneDeadline assessmentContext commandDeadline st =
  case lengthAssessmentContextBehaviorMode assessmentContext of
    LengthBehaviorFilter -> pure commandDeadline
    LengthBehaviorRank -> do
      limit <- synthTimeoutSeconds st
      if limit <= 0
        then pure Nothing
        else do
          started <- getCurrentTime
          pure $ Just (addUTCTime (fromIntegral limit) started)

-- | Consume one lazy detailed outcome under a lane policy.  Every nonempty
-- cursor batch is verified and behaviorally assessed exactly once.  Only an
-- ordinary filter lane may request a successor, and then only after its first
-- batch produced no verified term or rejected every verified term.  The
-- second candidate batch ends by policy without a third tail probe.
runSynthLaneCursor
  :: LengthAssessmentContext command
  -> SynthLaneCursorPolicy
  -> Maybe UTCTime
  -> St
  -> String
  -> (DetailedCandidateGroup -> DetailedCandidateGroup)
  -> Either String DetailedSynthOutcome
  -> SynthLaneAccumulation
  -> IO SynthLaneRun
runSynthLaneCursor assessmentContext policy deadline st goal transform outcome
    initialAccumulation =
  observe (1 :: Int) 0 [] [] (startDetailedSynthCursor outcome)
 where
  observe batchOrdinal groupCount reverseOutcomes runNotes cursor = do
    forced <- runDetailedSynthCursorBefore
      (synthLaneCursorBatchSize policy) (synthLaneCursorWindow policy)
      deadline cursor
    case forced of
      Nothing -> finish reverseOutcomes groupCount runNotes
        SynthLaneRunTimedOut
      Just (Left err) -> finish reverseOutcomes groupCount runNotes
        (SynthLaneRunCursorAdmissionFailed err)
      Just (Right step) -> case step of
        DetailedSynthCursorCandidateBatch batch successor -> do
          let groups = map transform (detailedCandidateBatchGroups batch)
              notes = detailedCandidateBatchNotes batch
              nextCount = groupCount + length groups
          when (synthLaneCursorRetainsRunNotes policy) $
            debugSynthLaneGroups st groupCount groups
          lane <- verifySynthLane assessmentContext
            (synthLaneCursorBatchSize policy) st goal [] groups
          let reverseOutcomes' = lane : reverseOutcomes
          case synthLaneDispositionWith (synthLaneCursorShown policy) lane of
            SynthLaneSurvivors _ _ ->
              finish reverseOutcomes' nextCount notes
                SynthLaneRunStoppedByDisposition
            SynthLaneAssessmentPreserved _ _ ->
              finish reverseOutcomes' nextCount notes
                SynthLaneRunStoppedByDisposition
            SynthLaneNoVerified -> continueOrStop batchOrdinal nextCount reverseOutcomes' notes successor
            SynthLaneAllBehaviorallyRejected _ -> continueOrStop batchOrdinal nextCount reverseOutcomes' notes successor
        DetailedSynthCursorNaturallyExhausted notes ->
          finish reverseOutcomes groupCount notes
            SynthLaneRunNaturallyExhausted
        DetailedSynthCursorHardCapReached notes ->
          finish reverseOutcomes groupCount notes SynthLaneRunHardCapReached
        DetailedSynthCursorEngineFailed err ->
          finish reverseOutcomes groupCount runNotes
            (SynthLaneRunEngineFailed err)
        DetailedSynthCursorRefuted sound ->
          finish reverseOutcomes groupCount runNotes
            (SynthLaneRunRefuted sound)
        DetailedSynthCursorNoTerm notes ->
          finish reverseOutcomes groupCount notes SynthLaneRunNoTerm

  continueOrStop batchOrdinal groupCount reverseOutcomes notes successor
    | synthLaneCursorAllowsFilterSuccessor policy && batchOrdinal < 2 =
        observe (batchOrdinal + 1) groupCount reverseOutcomes notes successor
    | otherwise = finish reverseOutcomes groupCount notes
        SynthLaneRunBatchPolicyReached

  finish reverseOutcomes groupCount notes runEnd =
    let noteOwnedReverseOutcomes
          | synthLaneCursorRetainsRunNotes policy =
              attachNotesToRightmostHandled notes reverseOutcomes
          | otherwise = reverseOutcomes
        chronologicalOutcomes = reverse noteOwnedReverseOutcomes
        accumulation = foldl
          (flip accumulateSynthLaneOutcome)
          initialAccumulation chronologicalOutcomes
    in pure SynthLaneRun
      { synthLaneRunAccumulation = accumulation
      , synthLaneRunCheckedFrontierSpellings = concatMap
          synthLaneCheckedFrontierSpellings chronologicalOutcomes
      , synthLaneRunCandidateGroupCount = groupCount
      , synthLaneRunNotes = notes
      , synthLaneRunEnd = runEnd
      }

  -- Outcomes are buffered only for this run (at most two).  Ordinary notes
  -- attach once to the latest handled result.  If every batch is a Lean miss,
  -- they stay solely on the run receipt for the final diagnostic.
  attachNotesToRightmostHandled _ [] = []
  attachNotesToRightmostHandled notes (lane : earlier) =
    case synthLaneDispositionWith (synthLaneCursorShown policy) lane of
      SynthLaneNoVerified ->
        lane : attachNotesToRightmostHandled notes earlier
      SynthLaneSurvivors _ _ ->
        lane { synthLaneOutcomeNotes = notes } : earlier
      SynthLaneAllBehaviorallyRejected _ ->
        lane { synthLaneOutcomeNotes = notes } : earlier
      SynthLaneAssessmentPreserved _ _ ->
        lane { synthLaneOutcomeNotes = notes } : earlier

-- | Debug candidate ordinals cover the complete same-run sequence rather
-- than restarting at one for a filter successor batch.
debugSynthLaneGroups :: St -> Int -> [DetailedCandidateGroup] -> IO ()
debugSynthLaneGroups st priorGroupCount groups = do
  debug <- synthDebugEnabled st
  when debug $
    forM_ (zip [priorGroupCount + 1 ..] groups) $ \(i, group) ->
      forM_ (detailedCandidateGroupVariants group) $ \variant ->
        emitLn st =<< cDim st ("debug " ++ show i ++ ": " ++ variant)

-- | The Glivenko fallback (SYNTHESIS_PROPOSAL.md \167 7 B): a sound
-- constructive refutation of a goal with a quantifier-free body may
-- still admit a classical proof.  For a propositional body the
-- double-negation translation is complete \8212 the body is classically
-- provable exactly when \172\172body is intuitionistically provable \8212 so
-- run the engine once more on prefix + \172\172body and wrap each candidate
-- in @Classical.byContradiction@.  Verification against the original
-- goal keeps the move honest for free: on a goal that is not actually
-- a @Prop@ (where @byContradiction@ does not apply) every wrapped
-- candidate fails to elaborate and the ordinary verdict stands, so the
-- fallback runs for every sound refutation rather than trusting the
-- serializer's sort classification of Sort-polymorphic goals.
-- Returns the updated command accumulation without finalization.  The sound-
-- refutation caller remains the sole output and state-effect boundary.
synthClassical
  :: LengthAssessmentContext command
  -> Maybe UTCTime
  -> St
  -> String
  -> ParsedGoal
  -> SynthLaneAccumulation
  -> IO SynthLaneAccumulation
synthClassical assessmentContext commandDeadline st goal parsed accumulation =
  case glivenkoSplit (pgFrag parsed) of
  Nothing -> pure accumulation
  Just (prefix, body) -> do
    state <- readIORef st
    let engine = rsSynthEngine state
        steps = rsSynthSteps state
        limits = rsSynthLimits state
        -- route 1: an excluded-middle premise per atomic subformula.
        -- For a propositional body, intuitionistic + atom-instances of
        -- em is exactly classical, so this is complete whenever the
        -- \172\172 route is - and the candidates read as case splits on
        -- Classical.em.  The prefix's binders stay free opaque
        -- variables for the engine; fitting and verification use the
        -- original quantified goal, and a variable that turns out not
        -- to be a Prop just fails verification.
        atoms = propAtoms body
        emPremises =
          [("Classical.em _", FSum v (FArr v FBot)) | v <- atoms]
        -- the engine goal is just the body: synthesizeTunedDetailed prepends
        -- the premises itself, and the prefix's binders stay free
        -- opaque variables
        emEngineFrag = body
    if null atoms || length atoms > 5
      then runDoubleNegation engine steps prefix body accumulation
      else do
        -- Excluded-middle premises multiply the proof space, so this search
        -- retains its established choice-point cutoff and half-window.  It
        -- never consumes a successor, including in filter mode.
        emDeadline <- classicalSynthLaneDeadline
          assessmentContext commandDeadline st
        emRun <- runSynthLaneCursor assessmentContext
          SynthLaneCursorPolicy
            { synthLaneCursorBatchSize =
                admissibleCursorBatch limits (synthLimitTried limits `div` 2)
            , synthLaneCursorAllowsFilterSuccessor = False
            , synthLaneCursorRetainsRunNotes = False
            , synthLaneCursorWindow = synthLimitWindow limits
            , synthLaneCursorShown = synthLimitShown limits
            }
          emDeadline st goal id
          (synthesizeTunedDetailedWith limits engine steps
            (synthLimitTried limits, Just 100000)
            emPremises emEngineFrag (pgFrag parsed))
          accumulation
        debug <- synthDebugEnabled st
        when debug $ emitLn st =<< cDim st
          ("debug em outcome: " ++ debugSynthLaneRun emRun)
        case synthLaneRunEnd emRun of
          SynthLaneRunStoppedByDisposition ->
            pure (synthLaneRunAccumulation emRun)
          _ -> runDoubleNegation engine steps prefix body
            (synthLaneRunAccumulation emRun)
 where
  runDoubleNegation engine steps prefix body accumulation' = do
      limits <- synthLimitsOf st
      -- route 2: the double-negation translation, wrapped in
      -- Classical.byContradiction (complete by Glivenko's theorem)
      let nnFrag =
            foldr (\(explicit, binder) acc -> FAll explicit binder acc)
              (FArr (FArr body FBot) FBot) prefix
          explicits = length (filter fst prefix)
          binders = ["cl" ++ show i | i <- [1 .. explicits]]
          wrap term
            | null binders =
                "Classical.byContradiction (" ++ term ++ ")"
            | otherwise = "fun " ++ unwords binders
                ++ " => Classical.byContradiction ((" ++ term ++ ") "
                ++ unwords binders ++ ")"
          djinnCandidateCutoff = case
              lengthAssessmentContextBehaviorMode assessmentContext of
            LengthBehaviorRank -> synthLimitTried limits
            LengthBehaviorFilter -> synthLimitWindow limits
          ordinaryPolicy = ordinarySynthLaneCursorPolicy
            assessmentContext engine limits
          nnPolicy = ordinaryPolicy
            { synthLaneCursorRetainsRunNotes = False }
      nnDeadline <- classicalSynthLaneDeadline
        assessmentContext commandDeadline st
      nnRun <- runSynthLaneCursor assessmentContext nnPolicy nnDeadline st goal
        (mapDetailedCandidateGroupVariantsDroppingSemanticSidecar wrap)
        (synthesizeTunedDetailedWith limits engine steps
          (djinnCandidateCutoff, Nothing) [] nnFrag nnFrag)
        accumulation'
      pure (synthLaneRunAccumulation nnRun)

  debugSynthLaneRun laneRun
    | synthLaneRunCandidateGroupCount laneRun > 0 =
        show (synthLaneRunCandidateGroupCount laneRun) ++ " groups: "
          ++ show (take 6 $ synthLaneRunCheckedFrontierSpellings laneRun)
    | otherwise = case synthLaneRunEnd laneRun of
        SynthLaneRunStoppedByDisposition -> "0 groups"
        SynthLaneRunBatchPolicyReached -> "0 groups"
        SynthLaneRunNaturallyExhausted -> "0 groups (exhausted)"
        SynthLaneRunHardCapReached -> "0 groups (candidate limit reached)"
        SynthLaneRunTimedOut -> "timeout"
        SynthLaneRunCursorAdmissionFailed err ->
          "cursor admission error: " ++ show err
        SynthLaneRunEngineFailed err -> "error: " ++ err
        SynthLaneRunRefuted _ -> "refuted"
        SynthLaneRunNoTerm ->
          "no term: " ++ show (synthLaneRunNotes laneRun)

-- | Verify and behaviorally assess one caller-bounded lane without emitting
-- result metrics, warnings, candidate rows, or engine notes, and without
-- binding candidates or changing the synthesis-splice cache.  The finite
-- 'take' precedes behavior-mode projection because verification quotas count
-- accepted groups rather than attempted groups.  Ranking retains the
-- historical five-success quota; filtering may inspect the complete bounded
-- lane so a later survivor can replace an earlier behavioral rejection.
verifySynthLane
  :: LengthAssessmentContext command
  -> Int
  -> St
  -> String
  -> [String]
  -> [DetailedCandidateGroup]
  -> IO SynthLaneOutcome
verifySynthLane assessmentContext groupLimit st goal notes groups =
  case take groupLimit groups of
    [] -> pure SynthLaneOutcome
      { synthLaneCheckedFrontierSpellings = []
      , synthLaneCallbackAttemptVariants = []
      , synthLaneOutcomeObservations = mempty
      , synthLaneOutcomeNotes = notes
      , synthLaneAssessed = Nothing
      }
    boundedGroups -> do
      shown <- synthLimitShown <$> synthLimitsOf st
      let successQuota = case
            lengthAssessmentContextBehaviorMode assessmentContext of
              LengthBehaviorRank -> shown
              LengthBehaviorFilter -> groupLimit
      (verification, callbackAttempts) <- synthVerify successQuota st goal
        (map detailedCandidateGroupVerificationVariants boundedGroups)
      let observations =
            candidateRenderingRouteObservations
              (map detailedCandidateGroupRoute boundedGroups)
            <> verificationObservations verification
      assessment <-
        assessLengthVerificationContext assessmentContext verification
      pure SynthLaneOutcome
        { synthLaneCheckedFrontierSpellings =
            concatMap detailedCandidateGroupVariants boundedGroups
        , synthLaneCallbackAttemptVariants = callbackAttempts
        , synthLaneOutcomeObservations = observations
        , synthLaneOutcomeNotes = notes
        , synthLaneAssessed = Just AssessedSynthLane
            { assessedSynthLaneVerification = verification
            , assessedSynthLaneLengthAssessment = assessment
            }
        }

-- | Classify a lane without output or state changes.  Presentation is capped
-- only for survivor/preserve-all output; rejection rows retain the complete
-- bounded projection.  The all-rejected constructor therefore remains
-- inspectable before a future scheduler chooses whether to finalize it.
-- | Presentation is capped at @shown@ survivors, the @:set synth-shown@
-- setting, whose default is five.
synthLaneDispositionWith :: Int -> SynthLaneOutcome -> SynthLaneDisposition
synthLaneDispositionWith shown outcome = case synthLaneAssessed outcome of
  Nothing -> SynthLaneNoVerified
  Just assessed
    | null $ verifiedCandidateReceipts
        $ assessedSynthLaneVerification assessed -> SynthLaneNoVerified
    | otherwise ->
    let assessment = assessedSynthLaneLengthAssessment assessed
        presentations =
          take shown $ presentLengthAssessment assessment
        rejections = presentLengthAssessmentRejections assessment
    in case lengthAssessmentFailure assessment of
      Just _ -> SynthLaneAssessmentPreserved presentations rejections
      Nothing
        | not (null presentations) ->
            SynthLaneSurvivors presentations rejections
        | not (null rejections) ->
            SynthLaneAllBehaviorallyRejected rejections
        -- The total presentation adapters currently make this branch
        -- unreachable.  If that contract changes, a callback-verified batch
        -- must still remain terminal rather than masquerading as Lean loss.
        | otherwise -> SynthLaneSurvivors [] []

-- | Fold a reverse lane history into one command disposition.  No-verified
-- lanes add no rows.  Every continuing all-rejected lane contributes its
-- complete rejection projection in attempt order; a later survivor or
-- preserve-all lane supplies the sole candidate presentation while retaining
-- those prior rejections ahead of its own.
synthLaneAccumulationDisposition
  :: Int
  -> SynthLaneAccumulation
  -> SynthLaneDisposition
synthLaneAccumulationDisposition shown
    (SynthLaneAccumulation reverseOutcomes) =
  foldl accumulateDisposition SynthLaneNoVerified
    (map (synthLaneDispositionWith shown) $ reverse reverseOutcomes)
 where
  accumulateDisposition accumulated disposition = case accumulated of
    SynthLaneSurvivors _ _ -> accumulated
    SynthLaneAssessmentPreserved _ _ -> accumulated
    _ -> case disposition of
      SynthLaneNoVerified -> accumulated
      SynthLaneAllBehaviorallyRejected rejections ->
        appendRejections accumulated rejections
      SynthLaneSurvivors presentations rejections ->
        SynthLaneSurvivors presentations
          (dispositionRejections accumulated ++ rejections)
      SynthLaneAssessmentPreserved presentations rejections ->
        SynthLaneAssessmentPreserved presentations
          (dispositionRejections accumulated ++ rejections)

  appendRejections accumulated rejections = case accumulated of
    SynthLaneNoVerified ->
      SynthLaneAllBehaviorallyRejected rejections
    SynthLaneAllBehaviorallyRejected prior ->
      SynthLaneAllBehaviorallyRejected (prior ++ rejections)
    SynthLaneSurvivors _ _ -> accumulated
    SynthLaneAssessmentPreserved _ _ -> accumulated

  dispositionRejections disposition = case disposition of
    SynthLaneNoVerified -> []
    SynthLaneSurvivors _ rejections -> rejections
    SynthLaneAllBehaviorallyRejected rejections -> rejections
    SynthLaneAssessmentPreserved _ rejections -> rejections

-- | Finalize one command's already verified/assessed lanes.  This is the sole
-- owner of result metrics, preserve-all warnings, reverse binding and
-- splice-cache mutation, survivor rows, complete rejection rows, and notes for
-- handled lanes.  A no-verification disposition emits its observations but
-- withholds notes so an intermediate lane cannot leak weaker engine
-- diagnostics; the final caller reports its error before those notes.
finalizeSynthLaneAccumulation
  :: St
  -> [String]
  -> String
  -> SynthLaneAccumulation
  -> IO SynthLaneDisposition
finalizeSynthLaneAccumulation st args goal
    accumulation@(SynthLaneAccumulation reverseOutcomes) = do
  shown <- synthLimitShown <$> synthLimitsOf st
  let outcomes = reverse reverseOutcomes
      dispositions = map (synthLaneDispositionWith shown) outcomes
      effectiveLanes = throughFirstTerminal $ zip outcomes dispositions
  debug <- synthDebugEnabled st
  when debug $ forM_ outcomes $ \outcome ->
    forM_ (leantObservationCodeEntries
      $ synthLaneOutcomeObservations outcome) $ \(code, count) ->
      emitLn st =<< cDim st
        ("debug metric: " ++ code ++ "=" ++ show count)
  forM_ (map fst effectiveLanes) $ \outcome -> case synthLaneAssessed outcome of
    Nothing -> pure ()
    Just assessed -> forM_
      (lengthAssessmentFailure
        $ assessedSynthLaneLengthAssessment assessed)
      $ \failure -> do
        prefix <- cYellow st "warning: "
        emitLn st $ prefix ++
          "finite-spine Length behavioral assessment preserved all verified "
          ++ "candidates: " ++ show failure
  let disposition = synthLaneAccumulationDisposition shown accumulation
  case disposition of
    SynthLaneNoVerified -> pure ()
    SynthLaneSurvivors presentations rejections ->
      finalizeSynthLanePresentations st args goal presentations rejections
    SynthLaneAllBehaviorallyRejected rejections -> do
      -- An accepted filter can intentionally remove the whole verified batch.
      -- This is handled but creates no itN binding and invalidates the prior
      -- synthesis-splice cache.
      modifyIORef' st (\s -> s
        { rsSynthIts = [], rsSynthItsProve = False })
      reportLengthAssessmentRejections st rejections
    SynthLaneAssessmentPreserved presentations rejections ->
      finalizeSynthLanePresentations st args goal presentations rejections
  forM_ effectiveLanes $ \(outcome, laneDisposition) ->
    case laneDisposition of
      SynthLaneNoVerified -> pure ()
      SynthLaneSurvivors _ _ ->
        reportSynthLaneNotes st (synthLaneOutcomeNotes outcome)
      SynthLaneAllBehaviorallyRejected _ ->
        reportSynthLaneNotes st (synthLaneOutcomeNotes outcome)
      SynthLaneAssessmentPreserved _ _ ->
        reportSynthLaneNotes st (synthLaneOutcomeNotes outcome)
  pure disposition
 where
  throughFirstTerminal lanes = case lanes of
    [] -> []
    lane@(_, laneDisposition) : remaining -> lane :
      case laneDisposition of
        SynthLaneSurvivors _ _ -> []
        SynthLaneAssessmentPreserved _ _ -> []
        SynthLaneNoVerified -> throughFirstTerminal remaining
        SynthLaneAllBehaviorallyRejected _ ->
          throughFirstTerminal remaining

-- | Bind and present the already capped survivor/preserve-all projection.
-- Callback acceptance, semantic origin, and renderer ordinal remain together
-- inside each opaque presentation value.
finalizeSynthLanePresentations
  :: St
  -> [String]
  -> String
  -> [LengthCandidatePresentation]
  -> [LengthCandidateRejectionPresentation]
  -> IO ()
finalizeSynthLanePresentations st args goal presentations rejections = do
  let shown = map lengthCandidatePresentationText presentations
  proving <- isJust . rsProve <$> readIORef st
  splices <-
    if proving
      then pure
        [ case args of
            [] -> "(" ++ term ++ ")"
            _ -> "((" ++ term ++ ") " ++ unwords args ++ ")"
        | term <- shown
        ]
      else do
        -- Bind worst-first, so the newest binding - bare `it` - is best.
        counters <- mapM (synthBind st goal) (reverse shown)
        pure
          [ maybe ("(" ++ term ++ ")") itName counter
          | (term, counter) <- zip shown (reverse counters)
          ]
  modifyIORef' st (\s -> s
    { rsSynthIts = splices, rsSynthItsProve = proving })
  forM_ (zip [1 :: Int ..] presentations) $ \(i, presentation) -> do
    label <- cBold st ("it" ++ show i)
    let term = lengthCandidatePresentationText presentation
    emitLn st ("  " ++ label ++ "  " ++ term)
    forM_ (lengthCandidatePresentationNote presentation) $ \note ->
      emitLn st ("       " ++ note)
  reportLengthAssessmentRejections st rejections

reportSynthLaneNotes :: St -> [String] -> IO ()
reportSynthLaneNotes st notes =
  forM_ notes $ \note -> emitLn st =<< cDim st ("note: " ++ note)

reportLengthAssessmentRejections
  :: St
  -> [LengthCandidateRejectionPresentation]
  -> IO ()
reportLengthAssessmentRejections st rejections =
  forM_ rejections $ \rejection -> do
    label <- cYellow st "rejected"
    emitLn st
      ("  " ++ label ++ "  "
        ++ lengthCandidateRejectionPresentationText rejection)
    emitLn st
      ("            " ++ lengthCandidateRejectionPresentationNote rejection)

-- | Leave prove mode.  Prove-scoped `itN` splices mention the goal's
-- hypotheses and stop making sense outside the proof, so they go too.
leaveProve :: St -> IO ()
leaveProve st = modifyIORef' st $ \s -> s
  { rsProve = Nothing
  , rsSynthIts = if rsSynthItsProve s then [] else rsSynthIts s
  , rsSynthItsProve = False
  }

-- | Bind one verified candidate under the next mangled it-name,
-- retrying @noncomputable@ (classical data-level terms need it).
-- 'Nothing' makes the splice fall back to the candidate text itself.
synthBind :: St -> String -> String -> IO (Maybe Int)
synthBind st goal term = do
  plain <- attempt ""
  case plain of
    Just n -> pure (Just n)
    Nothing -> attempt "noncomputable "
 where
  attempt keyword = do
    state <- readIORef st
    candidate <- firstUnusedItCounter st (rsItCounter state + 1) 10000
    case candidate of
      Nothing -> pure Nothing
      Just n -> do
        let code = "set_option autoImplicit true in " ++ keyword ++ "def "
              ++ itName n ++ " : (" ++ goal ++ ") := (" ++ term ++ ")"
        result <- runCurrentCmd st code
        case result of
          Right v | not (hasErrors v), Nothing <- respFatal v -> do
            modifyIORef' st (\s -> s { rsItCounter = n })
            advanceEnv st (respEnv v) code
            pure (Just n)
          _ -> pure Nothing

-- | Verify candidate groups against the backend, best first, lazily:
-- stop once enough verified candidates are collected (design rule: only
-- backend-verified candidates are ever shown).  Within a group, textual
-- variants of one engine candidate are tried in order and the first that
-- elaborates represents the group.  Failure classification is deliberately
-- ordered: transport, fatal response, error diagnostic, then a `sorry`.
synthVerify
  :: Int
  -> St
  -> String
  -> [[DetailedVerificationVariant]]
  -> IO
      ( VerificationBatch DetailedVerificationVariant
      , [DetailedVerificationVariant]
      )
synthVerify successQuota st goal groups = do
  reverseAttempts <- newIORef []
  verification <- verifyCandidateGroups successQuota
    (verifyVariant reverseAttempts) groups
  attempts <- reverse <$> readIORef reverseAttempts
  pure (verification, attempts)
 where
  verifyVariant reverseAttempts variant = do
    -- Trace at the exact callback boundary: failed variants before an
    -- acceptance are present, while the accepted group's remaining variants
    -- and every group beyond the success quota are absent.
    modifyIORef' reverseAttempts (variant :)
    let term = detailedVerificationVariantText variant
    result <- runCurrentCmd st (candidateVerificationProgram goal term)
    pure $ case result of
      Left _ -> VariantRejected BackendRequestFailure
      Right response
        | isJust (respFatal response) ->
            VariantRejected BackendFatalResponse
        | hasErrors response -> VariantRejected LeanErrorDiagnostic
        | not (null (respSorries response)) ->
            VariantRejected LeanContainsSorry
        | otherwise -> VariantAccepted

completionCandidates :: St -> String -> IO [String]
completionCandidates st prefix = do
  state <- readIORef st
  case lookup prefix (rsComplCache state) of
    Just cached -> pure cached
    Nothing -> do
      let sessionNames =
            [ n | n <- concatMap sessionDeclNames (rsHistory state)
            , prefix `isPrefixOf` n ]
      envOr <- ensureBrowseEnv' True st
      backendNames <- case envOr of
        Left _ -> pure []
        Right env -> do
          let program = unlines $
                [ "open Lean in run_cmd do"
                , "  let env \8592 getEnv"
                , "  let pre := " ++ leanStringLit prefix
                ] ++ generatedFilterLines ++
                [ "  let hits := env.constants.fold (init := #[]) fun a n _ =>"
                , "    if keep n && pre.isPrefixOf n.toString then a.push n else a"
                , "  let sorted := hits.qsort (\183.toString < \183.toString)"
                , "  logInfo (String.intercalate \"\\n\""
                , "    (sorted.toList.take 200 |>.map toString))"
                ]
          result <- try (runCmd st (Just env) program)
          case result of
            Right (Right v) -> pure
              [ n | (sev, d) <- respMessages v, sev == "info"
              , n <- lines d, not (null n) ]
            Right (Left _) -> pure []
            Left (_ :: SomeException) -> pure []
      let merged = nub (sessionNames ++ backendNames)
      modifyIORef' st (\s -> s
        { rsComplCache = (prefix, merged) : rsComplCache s })
      pure merged

cmdBrowse :: St -> Bool -> String -> IO ()
cmdBrowse st showAll rawArg
  | null arg = do
      history <- rsHistory <$> readIORef st
      let decls = concatMap sessionDeclNames history
      if null decls
        then emitLn st =<< cDim st "(no session declarations)"
        else mapM_ (emitLn st) decls
  | any isSpace arg || any null nameComponents = do
      message <- cRed st ("invalid namespace `" ++ arg ++ "`")
      emitLn st (message
        ++ " - :browse expects a dotted name such as Nat or List.Perm")
  | otherwise = do
      envOr <- ensureBrowseEnv st
      case envOr of
        Left err -> emitLn st =<< cRed st err
        Right env -> do
          result <- runCmd st (Just env)
            (browseProgram showAll nameComponents)
          case result of
            Left err -> emitLn st =<< cRed st err
            Right v -> void (printResponse st Nothing v)
      -- the browse environment predates session declarations; list those
      -- separately from the recorded history
      history <- rsHistory <$> readIORef st
      let matching =
            [ name
            | name <- concatMap sessionDeclNames history
            , (arg ++ ".") `isPrefixOf` name || arg == name
            ]
      unless (null matching) $ do
        emitLn st =<< cDim st "-- declared in this session:"
        mapM_ (emitLn st) matching
 where
  -- a leading '@' (pasted from :t @f output) is meaningless here; drop it
  arg = dropWhile (== '@') (trim rawArg)
  nameComponents = splitOn '.' arg

-- Names bound by a history entry, parsed textually (namespace blocks are not
-- tracked; names are reported as typed).
sessionDeclNames :: String -> [String]
sessionDeclNames entry =
  [ name
  | line <- lines entry
  , Just name <- [declName (words (stripAttrs line))]
  ]
 where
  stripAttrs l = case dropWhile isSpace l of
    '@' : '[' : rest -> drop 1 (dropWhile (/= ']') rest)
    other -> other

  modifiers =
    [ "private", "protected", "noncomputable", "partial", "unsafe"
    , "scoped", "local", "mutual" ]
  binders =
    [ "def", "theorem", "lemma", "abbrev", "inductive", "structure"
    , "class", "instance", "axiom", "opaque", "example" ]

  declName (w : rest)
    | w `elem` modifiers = declName rest
    | w `elem` binders, name : _ <- rest
    , isIdentStart name, w /= "example"
    , not ("\171it!" `isPrefixOf` name) = Just (takeWhile isIdentChar name)
  declName _ = Nothing

  isIdentStart s = case s of
    c : _ -> c `notElem` "({[:="
    [] -> False
  isIdentChar c = not (isSpace c) && c `notElem` "({[:="

snapshotArgumentPath :: ReplState -> FilePath -> FilePath
snapshotArgumentPath state =
  resolveSnapshotPath (bcWorkingDir (rsConfig state)) . withOlean

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = catchIOError (removeFile path) $ \err ->
  unless (isDoesNotExistError err) (ioError err)

ioResult :: IO a -> IO (Either String a)
ioResult action = do
  result <- tryIOError action
  pure (either (Left . show) Right result)

-- Reserve a collision-resistant sibling name, but leave it absent for the
-- backend, whose pickle operation creates the artifact itself.
freshSiblingPath :: FilePath -> IO (Either String FilePath)
freshSiblingPath target = ioResult $ do
  (path, handle) <- openBinaryTempFile (takeDirectory target)
    (takeFileName target ++ ".tmp")
  hClose handle
  removeFile path
  pure path

copyManagedArtifact :: FilePath -> IO (Either String FilePath)
copyManagedArtifact source = do
  temporary <- getTemporaryDirectory
  reserved <- freshSiblingPath (temporary </> "leant-session.olean")
  case reserved of
    Left err -> pure (Left err)
    Right path -> do
      copied <- ioResult (copyFile source path)
      case copied of
        Left err -> do
          cleanupManagedArtifact path
          pure (Left err)
        Right () -> pure (Right path)

cleanupSnapshotBase :: SnapshotBase -> IO ()
cleanupSnapshotBase snapshot = forM_ paths cleanupManagedArtifact
 where
  paths = snapshotEnvironmentPath snapshot
    : maybe [] pure (snapshotToolingPath snapshot)

-- Publish one prepared artifact without sacrificing an existing destination
-- if the final rename fails (notably important on Windows, where replacing an
-- existing file via rename is not uniformly atomic).
publishArtifact :: FilePath -> FilePath -> IO (Either String ())
publishArtifact temporary destination = do
  exists <- doesFileExist destination
  if not exists
    then ioResult (renameFile temporary destination)
    else do
      backupOr <- freshSiblingPath destination
      case backupOr of
        Left err -> pure (Left err)
        Right backup -> do
          movedOld <- ioResult (renameFile destination backup)
          case movedOld of
            Left err -> pure (Left err)
            Right () -> do
              installed <- ioResult (renameFile temporary destination)
              case installed of
                Right () -> do
                  _ <- ioResult (removeFileIfExists backup)
                  pure (Right ())
                Left err -> do
                  restored <- ioResult (renameFile backup destination)
                  pure $ case restored of
                    Right () -> Left err
                    Left restoreErr -> Left (err ++ "; the previous artifact "
                      ++ "remains at " ++ backup ++ " (restore failed: "
                      ++ restoreErr ++ ")")

detachMetadataMarker :: FilePath -> IO (Either String (Maybe FilePath))
detachMetadataMarker marker = do
  existsOr <- ioResult (doesFileExist marker)
  case existsOr of
    Left err -> pure (Left err)
    Right False -> pure (Right Nothing)
    Right True -> do
      backupOr <- freshSiblingPath marker
      case backupOr of
        Left err -> pure (Left err)
        Right backup -> do
          moved <- ioResult (renameFile marker backup)
          pure $ case moved of
            Left err -> Left err
            Right () -> Right (Just backup)

restoreMetadataMarker :: St -> FilePath -> Maybe FilePath -> IO ()
restoreMetadataMarker _ _ Nothing = pure ()
restoreMetadataMarker st marker (Just backup) = do
  restored <- ioResult (renameFile backup marker)
  case restored of
    Left err -> snapshotWarning st ("previous snapshot metadata remains at "
      ++ backup ++ " because restore failed: " ++ err)
    Right () -> pure ()

writeFileUtf8Atomic :: FilePath -> String -> IO (Either String ())
writeFileUtf8Atomic destination contents = do
  temporaryOr <- freshSiblingPath destination
  case temporaryOr of
    Left err -> pure (Left err)
    Right temporary -> do
      written <- ioResult $ withFile temporary WriteMode $ \handle -> do
        hSetEncoding handle utf8
        hPutStr handle contents
      case written of
        Left err -> do
          cleanupManagedArtifact temporary
          pure (Left err)
        Right () -> do
          published <- publishArtifact temporary destination
          cleanupManagedArtifact temporary
          pure published

snapshotWarning :: St -> String -> IO ()
snapshotWarning st message = do
  prefix <- cYellow st "warning: "
  emitLn st (prefix ++ message)

removeArtifactWithWarning :: St -> String -> FilePath -> IO ()
removeArtifactWithWarning st description path = do
  removed <- ioResult (removeFileIfExists path)
  case removed of
    Left err -> snapshotWarning st
      (description ++ " could not be removed: " ++ err)
    Right () -> pure ()

currentSynthesisCompanionABI :: String
currentSynthesisCompanionABI =
  -- The companion is a clean Lean-equipped transport environment; the
  -- current rated inventory is compiled after restore.  Hash the prelude's
  -- inventory-independent shape so project-local rating changes do not make
  -- an otherwise compatible snapshot stale.
  synthesisToolingABI ("transport-environment-v1\n" ++ synthPrelude [])

-- Read optional Leant metadata.  Invalid metadata never makes the main
-- upstream snapshot unusable; it merely disables result-counter restoration
-- and the synthesis companion.
readSnapshotSidecar
  :: St -> FilePath -> FilePath -> IO (Int, Maybe FilePath)
readSnapshotSidecar st sourcePath managedEnvironment = do
  let metadataPath = snapshotMetadataPath sourcePath
  exists <- doesFileExist metadataPath
  if not exists then pure (0, Nothing) else do
    textOr <- ioResult (readFileUtf8 metadataPath)
    case textOr >>= decodeSnapshotMetadata of
      Left err -> do
        snapshotWarning st ("ignoring snapshot metadata: " ++ err)
        pure (0, Nothing)
      Right metadata -> do
        mainFingerprintOr <- ioResult (fingerprintSnapshot managedEnvironment)
        case mainFingerprintOr of
          Left err -> do
            snapshotWarning st ("could not validate snapshot metadata: " ++ err)
            pure (0, Nothing)
          Right mainFingerprint
            | mainFingerprint /= snapshotMainFingerprint metadata -> do
                snapshotWarning st
                  "ignoring stale snapshot metadata (main file changed)"
                pure (0, Nothing)
            | otherwise -> do
                companion <- validateCompanion metadata
                pure (snapshotItCounter metadata, companion)
 where
  validateCompanion metadata = case snapshotSynthesisCompanion metadata of
    Nothing -> pure Nothing
    Just companion
      | snapshotCompanionABI companion /= currentSynthesisCompanionABI -> do
          snapshotWarning st
            "snapshot synthesis companion was made by different tooling"
          pure Nothing
      | otherwise -> do
          let path = takeDirectory sourcePath
                </> snapshotCompanionFile companion
          exists <- doesFileExist path
          if not exists then do
            snapshotWarning st "snapshot synthesis companion is missing"
            pure Nothing
          else do
            managedOr <- copyManagedArtifact path
            case managedOr of
              Left err -> do
                snapshotWarning st
                  ("snapshot synthesis companion could not be copied: " ++ err)
                pure Nothing
              Right managed -> do
                fingerprintOr <- ioResult (fingerprintSnapshot managed)
                case fingerprintOr of
                  Right fingerprint
                    | fingerprint == snapshotCompanionFingerprint companion ->
                        pure (Just managed)
                  _ -> do
                    cleanupManagedArtifact managed
                    snapshotWarning st
                      "snapshot synthesis companion is stale or unreadable"
                    pure Nothing

manageSnapshotBase
  :: St -> FilePath -> IO (Either String SnapshotBase)
manageSnapshotBase st source = do
  environmentOr <- copyManagedArtifact source
  case environmentOr of
    Left err -> pure (Left err)
    Right environment -> do
      (counter, tooling) <- readSnapshotSidecar st source environment
      pure (Right SnapshotBase
        { snapshotSourcePath = source
        , snapshotEnvironmentPath = environment
        , snapshotToolingPath = tooling
        , snapshotBaseItCounter = counter
        })

cleanupManagedArtifact :: FilePath -> IO ()
cleanupManagedArtifact path =
  catchIOError (removeFileIfExists path) (const (pure ()))

currentEnvironmentId :: St -> IO (Either String Integer)
currentEnvironmentId st = do
  backendOr <- ensureBackend st
  case backendOr of
    Left err -> pure (Left err)
    Right _ -> do
      state <- readIORef st
      case rsEnv state of
        Just env -> pure (Right env)
        Nothing -> do
          materialized <- runCmd st Nothing "#check True"
          pure $ case materialized of
            Right response
              | not (hasErrors response)
              , Nothing <- respFatal response
              , Just env <- respEnv response -> Right env
            _ -> Left "could not materialize the current environment"

-- Build a pickleable Lean-equipped copy of the logical session without the
-- compiled serializer itself.  Upstream environment snapshots restore
-- constants but not Lean's LCNF compiler extension, so the serializer must be
-- compiled anew after unpickling this transport environment.
prepareSnapshotToolingEnvironment :: St -> IO (Either String Integer)
prepareSnapshotToolingEnvironment st = do
  state <- readIORef st
  baseOr <- case rsSnapshotBase state of
    Nothing -> importedBase state
    Just snapshot -> snapshotBase snapshot
  case baseOr of
    Left err -> pure (Left err)
    Right base -> do
      let names = map fst (rsRatings state)
      probeResult <- runCmd st (Just base) (synthPrelude names)
      case probeResult of
        Left err -> pure (Left err)
        Right response -> case checkedEnvironment
            "failed to compile snapshot synthesis tooling" (Right response) of
          Left _ -> pure (Left ("the session base does not expose compatible "
            ++ "Lean metaprogramming APIs"))
          Right probeBase -> replayHistory base probeBase (rsHistory state)
 where
  importedBase state = do
    let imports = nub (rsImports state ++ ["Lean"])
    result <- runCmd st Nothing (unlines (map ("import " ++) imports))
    pure $ checkedEnvironment
      "failed to build snapshot synthesis tooling" result

  snapshotBase snapshot = case snapshotToolingPath snapshot of
    Just tooling -> do
      restored <- restoreEnvironmentArtifact st tooling
      case restored of
        Right environment -> pure (Right environment)
        Left (SnapshotTransportError err) -> pure (Left err)
        Left (SnapshotRejected err) -> do
          snapshotWarning st ("existing synthesis companion was rejected: "
            ++ err ++ "; rebuilding from the main snapshot")
          restoreMain snapshot
    Nothing -> restoreMain snapshot

  restoreMain snapshot = flattenRestore <$> restoreEnvironmentArtifact st
    (snapshotEnvironmentPath snapshot)

  -- Validate each entry against a prelude-equipped branch before adding it
  -- to the clean transport branch.  Internal LeantSynth name collisions are
  -- therefore skipped exactly as they are in ordinary synthesis replay.
  replayHistory environment _ [] = pure (Right environment)
  replayHistory environment probeEnvironment (code : rest) = do
    probeResult <- runCmd st (Just probeEnvironment) code
    case acceptedEnvironment probeResult of
      Left err -> pure (Left err)
      Right Nothing -> do
        skipped code
        replayHistory environment probeEnvironment rest
      Right (Just nextProbe) -> do
        transportResult <- runCmd st (Just environment) code
        case acceptedEnvironment transportResult of
          Left err -> pure (Left err)
          Right Nothing -> do
            skipped code
            replayHistory environment probeEnvironment rest
          Right (Just nextEnvironment) ->
            replayHistory nextEnvironment nextProbe rest

  acceptedEnvironment result = case result of
    Left err -> Left err
    Right response
      | not (hasErrors response), Nothing <- respFatal response
      , Just environment <- respEnv response -> Right (Just environment)
      | otherwise -> Right Nothing

  skipped code = emitLn st =<< cDim st
    ("note: `" ++ takeWhile (/= '\n') code
      ++ "` is not visible in the snapshot synthesis companion")

  checkedEnvironment label result = case result of
    Left err -> Left err
    Right response
      | Just fatal <- respFatal response -> Left (trim fatal)
      | hasErrors response -> Left label
      | Just environment <- respEnv response -> Right environment
      | otherwise -> Left (label ++ ": no environment returned")

  flattenRestore = either (Left . renderRestoreError) Right

  renderRestoreError (SnapshotTransportError err) = err
  renderRestoreError (SnapshotRejected err) = err

pickleEnvironment :: St -> FilePath -> Integer -> IO (Either String ())
pickleEnvironment st path env = do
  result <- runPayload st (pickleEnvironmentPayload path env)
  pure $ case result of
    Left err -> Left err
    Right response
      | Just fatal <- respFatal response -> Left (trim fatal)
      | errors@(_ : _) <- [ trim message
                          | (severity, message) <- respMessages response
                          , severity == "error" ] ->
          Left (intercalate "\n" errors)
      | otherwise -> Right ()

prepareSnapshotArtifact
  :: St
  -> FilePath
  -> Integer
  -> IO (Either String (FilePath, SnapshotFingerprint))
prepareSnapshotArtifact st destination env = do
  temporaryOr <- freshSiblingPath destination
  case temporaryOr of
    Left err -> pure (Left err)
    Right temporary -> do
      pickled <- pickleEnvironment st temporary env
      case pickled of
        Left err -> do
          cleanupManagedArtifact temporary
          pure (Left err)
        Right () -> do
          fingerprintOr <- ioResult (fingerprintSnapshot temporary)
          case fingerprintOr of
            Left err -> do
              cleanupManagedArtifact temporary
              pure (Left err)
            Right fingerprint -> pure (Right (temporary, fingerprint))

cmdPickle :: St -> String -> IO ()
cmdPickle st arg
  | null arg = emitLn st =<< cRed st "usage: :pickle FILE"
  | otherwise = do
      state <- readIORef st
      let environmentPath = snapshotArgumentPath state arg
          companionPath = snapshotCompanionPath environmentPath
          metadataPath = snapshotMetadataPath environmentPath
      currentOr <- currentEnvironmentId st
      case currentOr of
        Left err -> emitLn st =<< cRed st err
        Right current -> do
          mainOr <- prepareSnapshotArtifact st environmentPath current
          case mainOr of
            Left err -> emitLn st . ("snapshot failed: " ++) =<< cRed st err
            Right (mainTemporary, mainFingerprint) -> do
              synthOr <- prepareSnapshotToolingEnvironment st
              companionPrepared <- case synthOr of
                Left err -> do
                  snapshotWarning st ("saved the Lean environment, but not "
                    ++ "its synthesis companion: " ++ err)
                  pure Nothing
                Right synthEnv -> do
                  prepared <- prepareSnapshotArtifact st companionPath synthEnv
                  case prepared of
                    Left err -> do
                      snapshotWarning st ("saved the Lean environment, but not "
                        ++ "its synthesis companion: " ++ err)
                      pure Nothing
                    Right artifact -> pure (Just artifact)
              markerDetached <- detachMetadataMarker metadataPath
              case markerDetached of
                Left err -> do
                  cleanupManagedArtifact mainTemporary
                  forM_ companionPrepared (cleanupManagedArtifact . fst)
                  emitLn st . ("snapshot publish failed: " ++) =<< cRed st err
                Right oldMarker -> do
                  mainPublished <- publishArtifact mainTemporary environmentPath
                  case mainPublished of
                    Left err -> do
                      cleanupManagedArtifact mainTemporary
                      forM_ companionPrepared (cleanupManagedArtifact . fst)
                      restoreMetadataMarker st metadataPath oldMarker
                      emitLn st . ("snapshot publish failed: " ++) =<< cRed st err
                    Right () -> do
                      forM_ oldMarker cleanupManagedArtifact
                      companionMetadata <- case companionPrepared of
                        Nothing -> do
                          removeArtifactWithWarning st
                            "stale synthesis companion" companionPath
                          pure Nothing
                        Just (temporary, fingerprint) -> do
                          published <- publishArtifact temporary companionPath
                          cleanupManagedArtifact temporary
                          case published of
                            Left err -> do
                              snapshotWarning st
                                ("synthesis companion publish failed: " ++ err)
                              removeArtifactWithWarning st
                                "stale synthesis companion" companionPath
                              pure Nothing
                            Right () -> pure (Just SnapshotCompanion
                              { snapshotCompanionFile = takeFileName companionPath
                              , snapshotCompanionFingerprint = fingerprint
                              , snapshotCompanionABI = currentSynthesisCompanionABI
                              })
                      currentState <- readIORef st
                      let metadata = SnapshotMetadata
                            { snapshotItCounter = rsItCounter currentState
                            , snapshotMainFingerprint = mainFingerprint
                            , snapshotSynthesisCompanion = companionMetadata
                            }
                      metadataWritten <- writeFileUtf8Atomic metadataPath
                        (encodeSnapshotMetadata metadata ++ "\n")
                      case metadataWritten of
                        Left err -> snapshotWarning st
                          ("snapshot metadata could not be published: " ++ err)
                        Right () -> pure ()
                      emitLn st =<< cDim st
                        ("environment saved to " ++ environmentPath
                          ++ if isJust companionMetadata
                               then " (synthesis companion saved)" else "")

cmdUnpickle :: St -> String -> IO ()
cmdUnpickle st arg
  | null arg = emitLn st =<< cRed st "usage: :unpickle FILE"
  | otherwise = do
      state <- readIORef st
      let path = snapshotArgumentPath state arg
      managedOr <- manageSnapshotBase st path
      case managedOr of
        Left err -> emitLn st .
          ("snapshot could not be copied safely: " ++) =<< cRed st err
        Right snapshot -> do
          backendOr <- ensureBackendProcess st
          case backendOr of
            Left err -> do
              cleanupSnapshotBase snapshot
              emitLn st =<< cRed st err
            Right (_, spawned) -> do
              result <- runPayload st (unpickleEnvironmentPayload
                (snapshotEnvironmentPath snapshot))
              case result of
                Right response -> do
                  errored <- printResponse st Nothing response
                  case (errored, respEnv response) of
                    (False, Just env) -> do
                      current <- readIORef st
                      let counter = snapshotBaseItCounter snapshot
                          restored = (clearSessionTransients current)
                            { rsSnapshotBase = Just snapshot
                            , rsBaseEnv = Just env
                            , rsEnv = Just env
                            , rsEnvStack = []
                            , rsHistory = []
                            , rsLoadedFile = Nothing
                            , rsItCounter = counter
                            }
                      writeIORef st (invalidateProviderWorld
                        (invalidateDerivedEnvironments restored))
                      forM_ (rsSnapshotBase current) cleanupSnapshotBase
                      emitLn st =<< cDim st
                        ("environment restored from " ++ path
                          ++ " (new undo/history base)")
                    (False, Nothing) -> do
                      cleanupSnapshotBase snapshot
                      abandonReplacementBackend st spawned
                      emitLn st =<< cRed st
                        "snapshot restore returned no environment; session unchanged"
                    (True, _) -> do
                      cleanupSnapshotBase snapshot
                      abandonReplacementBackend st spawned
                Left err -> do
                  cleanupSnapshotBase snapshot
                  abandonReplacementBackend st spawned
                  emitLn st =<< cRed st err

withOlean :: String -> String
withOlean path =
  if ".olean" `isSuffixOf` path then path else path ++ ".olean"

readFileUtf8 :: FilePath -> IO String
readFileUtf8 path = do
  h <- openFile path ReadMode
  hSetEncoding h utf8
  contents <- hGetContents h
  length contents `seq` hClose h
  pure contents

-- Interactive prove mode ------------------------------------------------------

proveHelp :: String
proveHelp = unlines
  [ ""
  , "Prove mode: every input line is a tactic applied to the current goals."
  , ""
  , "  :goals             reprint the current goals"
  , "  :undo [N]          take back the last N tactics (default 1)"
  , "  :script            show the tactic script so far"
  , "  :suggest           reprint Lean's suggested next tactic"
  , "  :auto              try common finishing tactics on the current goal"
  , "  :synth             synthesize terms for the goal, with the hypotheses"
  , "                     as premises (then `exact it1` records the step)"
  , "  :synth --behavior-mode filter --"
  , "                     filter with the activated startup Length contract"
  , "  :synth --where List.length result = List.length arg0 --"
  , "                     infer the fixed List profile for this goal"
  , "  :synth [--behavior-mode rank|filter]"
  , "         --length-contract ABSOLUTE-PATH --"
  , "                     use one Length contract for this command's goal"
  , "  :synth --behavior-mode filter"
  , "         --length-model list-scalar-exact-cases"
  , "         --length-inputs arg0[,argN...] --where CLAUSE --"
  , "                     use one inline Length constraint for this goal"
  , "  :qed [NAME]        finish - save as `theorem NAME` in the session"
  , "                     (a `def` if the statement is not a proposition)"
  , "  :abort             leave prove mode (the script is printed, not lost)"
  , "  :help              this help;  :quit exits the REPL"
  , ""
  , "Tip: `exact?`, `simp?`, `rw?` record the tactic they *found* in the"
  , "script, not the question mark form."
  , "Automatic suggestions are advisory and never enter the script."
  ]

autoTactics :: [String]
autoTactics = ["rfl", "trivial", "decide", "simp", "omega", "exact?", "aesop"]

-- Suggestion probes: quick certain finishers first, then structural progress
-- steps shaped by the goal and its hypotheses, then broader searches. Each
-- candidate is actually run against the current immutable proof state; a
-- tactic is suggested only if Lean accepts it and returns a successor state.
-- Unlike :auto, probing does not stop at the first accepted candidate: ones
-- that merely advance the goal are remembered while the search keeps looking
-- for one that closes it outright, and if no single tactic does, a second
-- phase chains the finishers -- plus `simp_all`, with and without the
-- definitions the goal mentions -- onto the remembered candidates
-- (`t <;> finisher`) hunting for a complete proof.
-- `apply?` is deliberately absent: its partial `refine ?_` suggestions are
-- rarely actionable, and probing it over the proof-state protocol can panic
-- the REPL backend (a UTF-8 slicing bug in repl v1.3.18), destroying every
-- live proof state.
-- `assumption` and `contradiction` sit before `trivial`, which subsumes
-- both, so the more informative name is the one that gets shown.
suggestionFinishers :: [String]
suggestionFinishers =
  ["rfl", "assumption", "contradiction", "trivial", "decide", "omega"]

-- | Build the ordered candidate list for one pretty-printed goal. Shape
-- analysis only picks which candidates are worth probing -- `left`/`right`
-- instead of `constructor` on a disjunction goal, `cases`/`obtain` on a
-- hypothesis whose type a single step can take apart, `induction` on a
-- data-typed variable the target mentions, `simp_all?` only when there are
-- hypotheses to use -- so a mis-parse costs a wasted probe, never a wrong
-- suggestion.
goalCandidates :: String -> [String]
goalCandidates g = concat
  [ suggestionFinishers
  , ["exact?"]
  , introCands
  , destructCands  -- take hypotheses apart before building the goal
  , splitCands
  , inductionCands
  , ["simp?"]
  , ["simp_all?" | not (null hyps)]
  , ["aesop?"]
  ]
 where
  hyps = goalHypGroups g
  used = concatMap fst hyps
  targetIdents = maybe [] (identSplit . fst) (goalTarget g)
  -- `intro` names the binders it would introduce when the goal's shape
  -- allows it, keeping the bare form as a fallback should Lean reject them
  introCands = case introNames g of
    Just names -> ["intro " ++ unwords names, "intro"]
    Nothing -> ["intro"]
  splitCands
    | (typeConnective . fst =<< goalTarget g) == Just '\8744' =
        ["left", "right"]
    | otherwise = ["constructor"]
  destructCands = take 2
    [ cand
    | (name : _, ty) <- hyps
    , Just cand <- [destructFor name ty]
    ]
  destructFor name ty = case typeConnective ty of
    Just '\8744' -> Just ("cases " ++ name)                        -- h : a ∨ b
    Just '\8707' -> Just (obtainWith (freshX : take 1 freshHs) name)
    Just c | c `elem` "\8743\8596" ->                              -- ∧ and ↔
      Just (obtainWith (take 2 freshHs) name)
    Nothing | trim ty == "Bool" -> Just ("cases " ++ name)
    _ -> Nothing
  obtainWith fields name =
    "obtain \10216" ++ intercalate ", " fields ++ "\10217 := " ++ name
  -- A variable of a data type (`n : Nat`, `l : List Nat`, a user inductive)
  -- that the target actually mentions is a candidate for induction. The
  -- head-constant test only needs to rule out shapes induction cannot help
  -- with -- sorts, `Bool` (destructFor's `cases` already covers it), and
  -- anything with a logical connective on top; a data-looking hypothesis
  -- whose type is not really inductive just wastes the probe.
  inductionCands = take 1
    [ "induction " ++ name
    | (names, ty) <- hyps
    , isInductionTy ty
    , name <- names
    , name `elem` targetIdents
    ]
  isInductionTy ty =
    isNothing (typeConnective ty)
    && case words (trim ty) of
         hd@(c0 : _) : _ ->
           isUpper c0 && hd `notElem` ["Bool", "Prop", "Type", "Sort"]
         _ -> False
  freshHs = [n | n <- "h" : ["h" ++ show i | i <- [1 :: Int ..]]
               , n `notElem` used]
  freshX = fromMaybe "x" $ listToMaybe
    [n | n <- ["x", "y", "z"] ++ ["x" ++ show i | i <- [1 :: Int ..]]
       , n `notElem` used]

-- | Hypothesis groups of a pretty-printed goal as (names, type) pairs, with
-- wrapped continuation lines rejoined. Groups with inaccessible (\10013) or
-- otherwise unusable names are dropped.
goalHypGroups :: String -> [([String], String)]
goalHypGroups g =
  [ (names, trim (intercalate ":" tyParts))
  | grp <- joinWrapped hypLines
  , not ("case " `isPrefixOf` grp)
  , namesPart : tyParts@(_ : _) <- [splitDepth0 ':' grp]
  , names@(_ : _) <- [words namesPart]
  , all usable names
  ]
 where
  (hypLines, _) = break ("\8866" `isPrefixOf`) (lines g)
  joinWrapped [] = []
  joinWrapped (l : ls) =
    let (conts, rest) = span indented ls
    in unwords (concatMap words (l : conts)) : joinWrapped rest
  indented (c : _) = isSpace c
  indented [] = True
  usable n = not (any (`elem` "()[]{},:\10013\8866\10216\10217") n)

-- | The top-level connective of a pretty-printed type, approximated by
-- Lean's precedence order: a leading binder, else the loosest depth-0
-- connective (\8594, then \8596, \8744, \8743). Only an approximation --
-- callers verify every derived candidate against the live proof state.
typeConnective :: String -> Maybe Char
typeConnective t0 = case dropWhile isSpace t0 of
  "" -> Nothing
  t@(c : _)
    | c `elem` "\8704\8707" -> Just c
    | otherwise -> listToMaybe [op | op <- "\8594\8596\8744\8743", depth0 op t]
 where
  depth0 op s = length (splitDepth0 op s) > 1

suggestionHeartbeatLimit :: Int
suggestionHeartbeatLimit = 20000

respGoals :: JValue -> [String]
respGoals v = fromMaybe [] $ do
  gs <- jLookup "goals" v >>= jArray
  pure (mapMaybe jString gs)

respProofState :: JValue -> Maybe Integer
respProofState v = jLookup "proofState" v >>= jInt

formatGoals :: St -> [String] -> IO ()
formatGoals st goals
  | null goals = emitLn st =<< color st "32" "All goals accomplished \127881"
  | otherwise = do
      let n = length goals
      forM_ (zip [1 :: Int ..] goals) $ \(i, g) -> do
        when (n > 1) $
          emitLn st =<< cDim st ("\8212 goal " ++ show i ++ " of " ++ show n ++ " \8212")
        forM_ (lines (trimEnd' g)) $ \line ->
          if "case " `isPrefixOf` line
            then emitLn st =<< cCyan st line
            else if "\8866" `isPrefixOf` line
              then emitLn st =<< cBold st line
              else emitLn st line
 where
  trimEnd' = reverse . dropWhile isSpace . reverse

parseTryThis :: [(String, String)] -> Maybe String
parseTryThis messages = listToMaybe'
  [ intercalate "\n" cleaned
  | (sev, d) <- messages, sev == "info"
  , "Try this:" `isPrefixOf` dropWhile isSpace d
  , let cleaned = [ stripMarker (trim ln)
                  | ln <- drop 1 (lines d), not (null (trim ln)) ]
  , not (null cleaned)
  ]
 where
  listToMaybe' (x : _) = Just x
  listToMaybe' [] = Nothing
  stripMarker ln = case ln of
    '[' : rest -> case break (== ']') rest of
      (_, ']' : ' ' : suggestion) -> suggestion
      (_, ']' : suggestion) -> suggestion
      _ -> ln
    _ -> ln

proveScript :: ProveState -> [String]
proveScript pv = reverse [e | (_, _, Just e) <- pvStack pv]

-- Depth-aware scanning of pretty-printed goal text ---------------------------

bracketDepthStep :: Int -> Char -> Int
bracketDepthStep d c
  | c `elem` "([{\10216\10627" = d + 1          -- ( [ { \10216 \10627
  | c `elem` ")]}\10217\10628" = max 0 (d - 1)
  | otherwise = d

-- Split at occurrences of a character that sit outside every bracket pair.
splitDepth0 :: Char -> String -> [String]
splitDepth0 sep = go 0 ""
 where
  go _ acc [] = [reverse acc]
  go d acc (c : rest)
    | d == 0 && c == sep = reverse acc : go 0 "" rest
    | otherwise = go (bracketDepthStep d c) (c : acc) rest

-- | Maximal identifier-character runs of pretty-printed Lean text. The
-- namespace/projection dot is a separator, so @l.length@ yields both @l@
-- and @length@ -- the right reading for "does the target mention this
-- variable" checks.
identSplit :: String -> [String]
identSplit s = case dropWhile (not . identChar) s of
  "" -> []
  s' -> let (tok, rest) = span identChar s' in tok : identSplit rest

identChar :: Char -> Bool
identChar c = isAlphaNum c || c `elem` "_'"

-- | Tokens of the goal target that plausibly name definitions the goal is
-- about, for `simp_all [f]` chain candidates that unfold them: lowercase-
-- initial, not qualified or projected (no dot keeps @l.length@ and
-- @List.length@ out), and bound neither by a hypothesis nor by a binder
-- inside the target itself. A false positive costs one rejected probe.
goalDefNames :: String -> [String]
goalDefNames g = case goalTarget g of
  Nothing -> []
  Just (target, _) ->
    take 2 $ nub
      [ tok
      | tok@(c0 : _) <- dotted target
      , isLower c0
      , tok `notElem` concatMap fst (goalHypGroups g)
      , tok `notElem` binderBound target
      , tok `notElem` ["fun", "if", "then", "else", "match", "with", "let",
                       "do", "by", "at", "in", "have", "show", "this"]
      ]
 where
  dotted = filter ('.' `notElem`) . tokens
  tokens s = case dropWhile (not . dottedChar) s of
    "" -> []
    s' -> let (tok, rest) = span dottedChar s' in tok : tokens rest
  dottedChar c = identChar c || c == '.'
  -- names bound by a \8704/\8707/\955/`fun` binder: everything between the
  -- binder head and its depth-0 `,` or `=>` (types in the group included --
  -- they are capitalized or rebound elsewhere, so over-excluding is safe)
  binderBound = goB '\0'
   where
    goB _ [] = []
    goB prev s@(c : rest)
      | c `elem` "\8704\8707\955" = takeGroup rest
      | not (identChar prev)
      , Just r <- stripPrefix "fun" s
      , maybe True (not . identChar) (listToMaybe r) = takeGroup r
      | otherwise = goB c rest
    takeGroup s =
      let (grp, rest) = breakGroupEnd 0 s
      in identSplit grp ++ goB '\0' rest
    breakGroupEnd d s = case s of
      [] -> ("", "")
      ',' : rest | d == 0 -> ("", rest)
      '=' : '>' : rest | d == 0 -> ("", rest)
      '\8614' : rest | d == 0 -> ("", rest)
      c : rest ->
        let (grp, rest') = breakGroupEnd (bracketDepthStep d c) rest
        in (c : grp, rest')

-- | Name the binders a bare `intro` would introduce, from the pretty-printed
-- goal: leading \8704 binder groups contribute their own names, then each
-- depth-0 arrow of the body -- and a bare \172 conclusion, which intro also
-- unfolds -- contributes a fresh hypothesis name. The result is only shown
-- after Lean accepts it against the live proof state, so a mis-parse costs
-- one wasted probe, never a wrong suggestion.
introNames :: String -> Maybe [String]
introNames goal = do
  target <- case targetLines of
    [] -> Nothing
    t : more -> Just (unwords (concatMap words (drop 1 t : more)))
  (binders, body) <- case target of
    '\8704' : rest -> parseBinders (dropWhile isSpace rest) []
    _ -> Just ([], target)
  -- count arrows only up to the first depth-0 \8704 of the body; anything
  -- beyond it belongs to a nested quantifier with its own binder names
  let (cutSegments, wasCut) = case splitDepth0 '\8704' body of
        prefix : _ : _ -> (splitDepth0 '\8594' prefix, True)
        _ -> (splitDepth0 '\8594' body, False)
      arrows = length cutSegments - 1
      negBonus = if not wasCut && bareNegation (last cutSegments) then 1 else 0
      used = hypNames ++ binders
      fresh = take (arrows + negBonus)
        [n | n <- "h" : ["h" ++ show i | i <- [1 :: Int ..]], n `notElem` used]
      names = binders ++ fresh
  if null names then Nothing else Just names
 where
  (hypLines, targetLines) = break ("\8866" `isPrefixOf`) (lines goal)
  -- wrapped hypothesis and target lines are indented continuations
  hypNames = concat
    [ words namesPart
    | l@(c0 : _) <- hypLines
    , not ("case " `isPrefixOf` l), not (isSpace c0)
    , namesPart : _ : _ <- [splitDepth0 ':' l]
    ]
  parseBinders s acc = case dropWhile isSpace s of
    ',' : rest -> Just (reverse acc, dropWhile isSpace rest)
    '(' : rest -> do
      (content, rest') <- balancedParen (1 :: Int) "" rest
      namesPart <- case splitDepth0 ':' content of
        np : _ : _ -> Just np
        _ -> Nothing
      names <- traverse checkName (words namesPart)
      if null names then Nothing else parseBinders rest' (reverse names ++ acc)
    "" -> Nothing
    s'@(c0 : _)
      -- implicit/instance groups: bare `intro` still introduces them, but
      -- suggesting explicit names for them is more confusing than helpful
      | c0 `elem` "{[\10627" -> Nothing
      | otherwise -> do
          let (tok, rest') = break (\c -> isSpace c || c == ',') s'
          name <- checkName tok
          parseBinders rest' (name : acc)
  balancedParen depth acc str = case str of
    [] -> Nothing
    ')' : rest
      | depth == 1 -> Just (reverse acc, rest)
      | otherwise -> balancedParen (depth - 1) (')' : acc) rest
    '(' : rest -> balancedParen (depth + 1) ('(' : acc) rest
    c : rest -> balancedParen depth (c : acc) rest
  checkName tok
    | null tok = Nothing
    | any (`elem` "()[]{},:\10013\8866\10216\10217") tok = Nothing
    | otherwise = Just tok
  bareNegation seg =
    case filter (not . null) (splitDepth0 ' ' (trim seg)) of
      [tok] -> "\172" `isPrefixOf` tok
      _ -> False

annotateSuggestion :: String -> String -> String
annotateSuggestion note text = case lines text of
  [] -> text
  first : rest -> intercalate "\n" ((first ++ "  (" ++ note ++ ")") : rest)

emitSuggestion :: St -> String -> IO ()
emitSuggestion st suggestion = case lines suggestion of
  [] -> pure ()
  first : rest -> do
    emitLn st =<< cDim st ("suggestion: " ++ first)
    forM_ rest $ \line -> emitLn st =<< cDim st ("            " ++ line)

-- | Find and display a useful next tactic without changing the user's proof
-- stack. The backend proof-state protocol is persistent, so speculative
-- children do not affect the state to which the next user tactic is applied.
-- Candidates that merely make progress are remembered (up to three) while
-- the search keeps looking for one that closes the goal; if none does, a
-- second phase chains the quick finishers onto each remembered candidate
-- (`t <;> finisher`) so the suggestion can still be a complete verified
-- proof. The annotation on the shown suggestion says which kind it is.
suggestTactic :: St -> IO ()
suggestTactic st = do
  state <- readIORef st
  case rsProve state of
    Just pv | (ps, goals@(g : _), _) : _ <- pvStack pv ->
      case lookup ps (pvSuggestions pv) of
        Just cached -> forM_ cached (emitSuggestion st)
        Nothing ->
          probe ps (length goals) (chainExtras g) (goalCandidates g) []
    _ -> pure ()
 where
  -- Chain finishers beyond the quick certain ones: `simp_all` can use the
  -- case hypotheses an `induction` or `cases` step introduces, and when
  -- the target mentions definitions, `simp_all [f]` unfolds them -- the
  -- move that closes `induction l <;> simp_all [myLen]` proofs. Probed
  -- after `exact?` so an informative found term still wins over a
  -- sledgehammer when both close the goal.
  chainExtras g =
    "simp_all" : ["simp_all [" ++ d ++ "]" | d <- goalDefNames g]
  -- Run one heartbeat-bounded candidate against the immutable proof state.
  -- The bound keeps proactive help responsive even when a project has a very
  -- large premise database. A heartbeat exhaustion is an ordinary tactic
  -- error, unlike the REPL's wall-clock timeout, so it does not kill the
  -- backend or invalidate the user's proof state. Returns Nothing when the
  -- backend died (the emergency exit has already run), Just Nothing when
  -- Lean rejected the candidate.
  probeOnce :: Integer -> String -> IO (Maybe (Maybe JValue))
  probeOnce ps tactic = do
    let bounded = "set_option maxHeartbeats "
          ++ show suggestionHeartbeatLimit ++ " in " ++ tactic
    result <- runTactic st ps bounded
    case result of
      Left err -> Nothing <$ proveEmergencyExit st
        ("the backend failed while suggesting a tactic: " ++ err)
      Right v
        | Nothing <- respFatal v
        , null [() | (severity, _) <- respMessages v, severity == "error"]
        , Just _ <- respProofState v -> pure (Just (Just v))
        | otherwise -> pure (Just Nothing)

  probe ps nGoals extras [] helds = chainPhase ps nGoals extras helds
  probe ps nGoals extras ("intro" : rest) helds
    | any (("intro " `isPrefixOf`) . fst) helds =
        probe ps nGoals extras rest helds  -- the named intro variant held
  probe ps nGoals extras (tactic : rest) helds = do
    outcome <- probeOnce ps tactic
    case outcome of
      Nothing -> pure ()
      Just Nothing -> probe ps nGoals extras rest helds
      Just (Just v) -> do
        let text = fromMaybe tactic (parseTryThis (respMessages v))
            remaining = length (respGoals v)
            -- library-search tactics can "close" the probe state with
            -- metavariables and say so in a Remaining-subgoals comment;
            -- never present those as closing the goal
            partial = any (("-- Remaining subgoals:" `isPrefixOf`) . trim)
              (lines text)
        if remaining < nGoals && not partial
          then conclude ps (Just (annotateSuggestion "closes the goal" text))
          else probe ps nGoals extras rest $ if length helds >= 3 then helds
            else helds ++ [(text, if remaining > nGoals
                   then Just ("splits into "
                     ++ show (remaining - nGoals + 1) ++ " goals")
                   else Nothing)]

  -- No single candidate closed the goal: try to discharge each remembered
  -- candidate's residual subgoals in one more step. `<;>` (rather than `;`)
  -- makes the finisher run on every subgoal the candidate produces, so
  -- acceptance means the chain is a complete proof of the current goal.
  -- `exact?` is only chained onto the first candidate to bound the cost of
  -- the expensive library searches; the `simp_all` extras come after it so
  -- an informative found term beats a sledgehammer. A candidate whose text
  -- spans lines is never chained, since composing it would not yield a
  -- tactic the user could type back. If no chain closes either, the first
  -- remembered candidate is shown with its own annotation.
  chainPhase ps _ _ [] = conclude ps Nothing
  chainPhase ps nGoals extras helds@(first : _) =
    goHeld (zip (True : repeat False) helds)
   where
    fallback = conclude ps (Just (annotateHeld first))
    goHeld [] = fallback
    goHeld ((isFirst, (text, _)) : more)
      | '\n' `elem` text = goHeld more
      | otherwise = goChain text
          (suggestionFinishers ++ ["exact?" | isFirst] ++ extras) more
    goChain _ [] more = goHeld more
    goChain text (fin : rest) more = do
      outcome <- probeOnce ps (text ++ " <;> " ++ fin)
      case outcome of
        Nothing -> pure ()
        Just (Just v)
          | length (respGoals v) < nGoals
          , Just chained <- renderChain text fin v ->
              conclude ps (Just (annotateSuggestion "closes the goal" chained))
          -- a simp_all link that was accepted without closing may have
          -- rewritten the residual goals into omega's arithmetic reach
          -- (`induction n <;> simp_all [f] <;> omega`); one extension probe
          | "simp_all" `isPrefixOf` fin -> do
              let fin' = fin ++ " <;> omega"
              outcome' <- probeOnce ps (text ++ " <;> " ++ fin')
              case outcome' of
                Nothing -> pure ()
                Just (Just v') | length (respGoals v') < nGoals ->
                  conclude ps $ Just $ annotateSuggestion "closes the goal"
                    (text ++ " <;> " ++ fin')
                Just _ -> goChain text rest more
        Just _ -> goChain text rest more
    -- The chained text must be something the user can type back verbatim.
    -- A literal finisher composes trivially; `exact?` has to splice in the
    -- term it found, which is only sound when the chain ran it against
    -- exactly one subgoal (one Try-this message) and the found tactic fits
    -- on one line (a Remaining-subgoals comment never does).
    renderChain text "exact?" v = case
      [ d | (sev, d) <- respMessages v, sev == "info"
          , "Try this:" `isPrefixOf` dropWhile isSpace d ] of
      [only] | Just found <- parseTryThis [("info", only)]
             , '\n' `notElem` found ->
        Just (text ++ " <;> " ++ found)
      _ -> Nothing
    renderChain text fin _ = Just (text ++ " <;> " ++ fin)

  annotateHeld (text, note) = maybe text (`annotateSuggestion` text) note

  conclude ps suggestion = do
    cache ps suggestion
    forM_ suggestion (emitSuggestion st)

  cache ps suggestion = modifyIORef' st $ \s -> s
    { rsProve = case rsProve s of
        Just pv
          | (currentPs, _, _) : _ <- pvStack pv
          , currentPs == ps -> Just pv
              { pvSuggestions = (ps, suggestion) : pvSuggestions pv }
        -- The proof state can only change here through an emergency exit, but
        -- preserve a newer state defensively rather than restoring old data.
        newer -> newer
    }

proveEmergencyExit :: St -> String -> IO ()
proveEmergencyExit st why = do
  state <- readIORef st
  forM_ (rsProve state) $ \pv -> do
    emitLn st =<< cRed st why
    let script = proveScript pv
    unless (null script) $ do
      emitLn st =<< cDim st "tactic script so far (proof states were lost):"
      forM_ script $ \t -> emitLn st ("  " ++ t)
  leaveProve st

cmdProve :: St -> String -> IO ()
cmdProve st rawArg = do
  state <- readIORef st
  case rsProve state of
    Just _ -> emitLn st =<< cRed st
      "already in prove mode \8212 :abort or :qed first"
    Nothing -> do
      let arg = substIt (rsItCounter state) (rsSynthIts state)
            (trim rawArg)
      entered <- if not (null arg)
        then do
          result <- runCurrentCmd st
            ("example : (" ++ arg ++ ") := by sorry")
          case result of
            Left err -> False <$ (emitLn st =<< cRed st err)
            Right v -> do
              let errs = [d | (s, d) <- respMessages v, s == "error"]
              case respSorries v of
                ((Just ps, goal) : _) | null errs -> do
                  modifyIORef' st (\s -> s { rsProve = Just (ProveState
                    (Just arg) [(ps, [goal], Nothing)] []) })
                  pure True
                _ -> do
                  forM_ errs $ \e ->
                    emitLn st . (++ e) =<< cRed st "error: "
                  when (null errs) $ emitLn st =<< cRed st
                    "could not create a proof state \8212 is the statement a proposition?"
                  pure False
        else case rsLastSorry state of
          Just (ps, goal) -> do
            modifyIORef' st (\s -> s { rsProve = Just (ProveState
              Nothing [(ps, [goal], Nothing)] []) })
            emitLn st =<< cDim st
              ("resuming from the last `sorry` \8212 on :qed the script is "
               ++ "printed for you to paste")
            pure True
          Nothing -> False <$ (emitLn st =<< cRed st
            "usage: :prove PROPOSITION   (or :prove after a `sorry`)")
      when entered $ do
        emitLn st =<< cDim st
          "entering prove mode \8212 type tactics; :help for commands"
        stateNow <- readIORef st
        forM_ (rsProve stateNow) $ \pv ->
          case pvStack pv of
            (_, goals, _) : _ -> formatGoals st goals
            [] -> pure ()
        suggestTactic st

-- Apply one tactic; returns True if the proof state advanced.
applyTactic :: St -> Bool -> String -> IO Bool
applyTactic st quiet tactic = do
  state <- readIORef st
  case rsProve state of
    Nothing -> pure False
    Just pv -> case pvStack pv of
      [] -> pure False
      (ps, _, _) : _ -> do
        result <- runTactic st ps tactic
        case result of
          Left err -> do
            proveEmergencyExit st ("the backend failed: " ++ err)
            pure False
          Right v
            | Just fatal <- respFatal v -> do
                let cleaned = case lines (trim fatal) of
                      ("Lean error:" : rest@(_ : _)) -> intercalate "\n" rest
                      _ | null (trim fatal) -> "the tactic failed to elaborate"
                        | otherwise -> trim fatal
                unless quiet $ emitLn st . (++ cleaned) =<< cRed st "error: "
                pure False
            | errs@(_ : _) <- [d | (s, d) <- respMessages v, s == "error"] -> do
                unless quiet $ forM_ errs $ \e ->
                  emitLn st . (++ trimEnd' e) =<< cRed st "error: "
                pure False
            | Just newPs <- respProofState v -> do
                let entry = fromMaybe tactic (parseTryThis (respMessages v))
                when (entry /= tactic && not quiet) $
                  emitLn st =<< cDim st ("recorded as: " ++ headLine entry)
                unless quiet $
                  forM_ [d | (s, d) <- respMessages v, s == "warning"] $ \w ->
                    emitLn st . (++ trimEnd' w) =<< cYellow st "warning: "
                modifyIORef' st (\s -> s { rsProve = Just pv
                  { pvStack = (newPs, respGoals v, Just entry) : pvStack pv } })
                pure True
            | otherwise -> do
                unless quiet $ emitLn st =<< cRed st
                  "the tactic produced no new proof state"
                pure False
 where
  headLine t = case lines t of
    l : _ -> l
    [] -> t
  trimEnd' = reverse . dropWhile isSpace . reverse

currentGoals :: St -> IO [String]
currentGoals st = do
  state <- readIORef st
  pure $ case rsProve state of
    Just pv | (_, goals, _) : _ <- pvStack pv -> goals
    _ -> []

-- Handle one input line in prove mode. Returns False to exit the REPL.
proveInput :: St -> String -> IO Bool
proveInput st text = do
  let stripped = trim text
  if null stripped then pure True
  else if ":" `isPrefixOf` stripped && not (":=" `isPrefixOf` stripped)
    then do
      let (word, rest) = break isSpace (drop 1 stripped)
          arg = trim rest
      case word of
        w | w `elem` ["q", "quit", "exit"] -> pure False
        w | w `elem` ["h", "help", "?"] -> True <$ emit st proveHelp
        "goals" -> do
          formatGoals st =<< currentGoals st
          suggestTactic st
          pure True
        "undo" -> do
          let n = if all (`elem` "0123456789") arg && not (null arg)
                then read arg else 1 :: Int
          popped <- popTactics n
          if popped == 0
            then emitLn st =<< cRed st "nothing to undo"
            else do
              formatGoals st =<< currentGoals st
              suggestTactic st
          pure True
        "script" -> do
          state <- readIORef st
          case rsProve state of
            Just pv | script@(_ : _) <- proveScript pv ->
              mapM_ (emitLn st) script
            _ -> emitLn st =<< cDim st "(no tactics yet)"
          pure True
        "suggest" -> True <$ suggestTactic st
        "auto" -> True <$ cmdAuto st
        "synth" -> True <$ cmdSynth st arg
        "qed" -> True <$ cmdQed st arg
        "abort" -> do
          state <- readIORef st
          forM_ (rsProve state) $ \pv -> do
            let script = proveScript pv
            if null script
              then emitLn st =<< cDim st "left prove mode"
              else do
                emitLn st =<< cDim st "left prove mode; the script was:"
                forM_ script $ \t -> emitLn st ("  " ++ t)
          leaveProve st
          pure True
        _ -> do
          emitLn st =<< cRed st ("no :" ++ word ++ " inside prove mode \8212 "
            ++ "tactics, :goals, :undo, :script, :auto, :synth, :qed, "
            ++ ":suggest, :abort, :quit")
          pure True
    else do
      state <- readIORef st
      advanced <- applyTactic st False
        (substIt (rsItCounter state) (rsSynthIts state) stripped)
      when advanced $ do
        goals <- currentGoals st
        formatGoals st goals
        if null goals
          then emitLn st =<< cDim st "finish with :qed [NAME], inspect with :script"
          else suggestTactic st
      pure True
 where
  popTactics :: Int -> IO Int
  popTactics n = go n 0
   where
    go 0 acc = pure acc
    go k acc = do
      state <- readIORef st
      case rsProve state of
        Just pv | (_, _, Just entry) : rest <- pvStack pv -> do
          modifyIORef' st (\s -> s { rsProve = Just pv { pvStack = rest } })
          emitLn st =<< cDim st ("undid: " ++ takeWhile (/= '\n') entry)
          go (k - 1) (acc + 1)
        _ -> pure acc

cmdAuto :: St -> IO ()
cmdAuto st = do
  before <- length <$> currentGoals st
  go before autoTactics []
 where
  go _ [] tried = emitLn st . (++ dimTried tried "") =<< cRed st "no luck \8212 "
  go before (tac : rest) tried = do
    stillActive <- rsProve <$> readIORef st
    case stillActive of
      Nothing -> pure ()  -- emergency exit fired
      Just _ -> do
        advanced <- applyTactic st True tac
        if not advanced then go before rest (tried ++ [tac])
        else do
          goals <- currentGoals st
          if length goals < before || null goals
            then do
              state <- readIORef st
              let entry = case rsProve state of
                    Just pv | (_, _, Just e) : _ <- pvStack pv -> e
                    _ -> tac
              closed <- color st "32" ("closed by: " ++ takeWhile (/= '\n') entry)
              note <- cDim st ("  (tried "
                ++ intercalate ", " (tried ++ [tac]) ++ ")")
              emitLn st (closed ++ note)
              formatGoals st goals
              if null goals
                then emitLn st =<< cDim st "finish with :qed [NAME]"
                else suggestTactic st
            else do
              -- advanced without closing a goal: take it back
              modifyIORef' st $ \s -> s { rsProve = case rsProve s of
                Just pv | _ : rest' <- pvStack pv -> Just pv { pvStack = rest' }
                other -> other }
              go before rest (tried ++ [tac])
  dimTried tried extra = "tried " ++ intercalate ", " (tried ++ [extra | not (null extra)])

cmdQed :: St -> String -> IO ()
cmdQed st arg = do
  goals <- currentGoals st
  state <- readIORef st
  case rsProve state of
    Nothing -> pure ()
    Just pv
      | not (null goals) -> emitLn st =<< cRed st
          (show (length goals) ++ " goal"
           ++ (if length goals > 1 then "s" else "")
           ++ " remain \8212 :goals to see them, :abort to give up")
      | otherwise -> do
          let script = proveScript pv
              body = if null script then "by trivial"
                else "by\n" ++ intercalate "\n"
                  ["  " ++ ln | t <- script, ln <- lines t]
          when (any ("sorry" `isInfixOf`) script) $
            emitLn st . (++ "the script contains `sorry`")
              =<< cYellow st "warning: "
          case pvStmt pv of
            Nothing -> do
              emitLn st =<< cDim st
                "replace the `sorry` in the original declaration with:"
              emitLn st body
              leaveProve st
            Just stmt -> do
              let name = if null (trim arg)
                    then "prove_" ++ show (rsProveCounter state + 1)
                    else trim arg
                  codeFor kw = kw ++ " " ++ name ++ " : (" ++ stmt ++ ") := " ++ body
                  -- Type-valued statements (e.g. a Decidable instance) cannot
                  -- be theorems; Lean rejects them with
                  -- "type of theorem `NAME` is not a proposition".
                  notAProp v = any
                    (\(sev, d) -> sev == "error"
                      && "type of theorem" `isInfixOf` d
                      && "is not a proposition" `isInfixOf` d)
                    (respMessages v)
                  save kw = do
                    result <- runCurrentCmd st (codeFor kw)
                    case result of
                      Left err -> do
                        emitLn st =<< cRed st err
                        emitLn st =<< cRed st
                          ("could not save the " ++ kw
                           ++ " \8212 still in prove mode")
                      Right v
                        | kw == "theorem" && notAProp v -> save "def"
                        | otherwise -> do
                            errored <- printResponse st Nothing v
                            if errored
                              then emitLn st =<< cRed st
                                ("could not save the " ++ kw
                                 ++ " \8212 still in prove mode (:script to inspect)")
                              else do
                                advanceEnv st (respEnv v) (codeFor kw)
                                when (null (trim arg)) $ modifyIORef' st
                                  (\s -> s { rsProveCounter = rsProveCounter s + 1 })
                                saved <- color st "32"
                                  ("saved: " ++ kw ++ " " ++ name ++ " : " ++ stmt)
                                emitLn st saved
                                leaveProve st
              save "theorem"

-- Main loop -----------------------------------------------------------------

banner :: String
banner = unlines
  [ ""
  , "   __                  __"
  , "  / /  ___ ___ ____   / /_"
  , " / /__/ -_) _ `/ _ \\_/ __/"
  , "/____/\\__/\\_,_/_//_/ \\__/"
  ]

replLoop :: St -> InputT IO ()
replLoop st = do
  step <- handleInterrupt onInterrupt $ withInterrupt $ do
    input <- readLogicalInput st
    case input of
      Nothing -> do
        liftIO (emitLn st =<< cDim st "goodbye")
        pure False
      Just text -> do
        proving <- liftIO (isJust . rsProve <$> readIORef st)
        case () of
          _ | null (trim text) -> pure True
            | proving -> liftIO (proveInput st text)
            | ":" `isPrefixOf` trim text && not (":=" `isPrefixOf` trim text) ->
                liftIO (dispatchCommand st (trim text))
            | otherwise -> do
                evalWithRetry text
                pure True
  when step (replLoop st)
 where
  onInterrupt = do
    liftIO $ do
      emitLn st =<< cRed st "interrupted"
      proveEmergencyExit st "the interrupt discards proof states"
      state <- readIORef st
      when (isJust (rsBackend state)) $ do
        backendDied st
        emitLn st =<< cDim st
          "the Lean backend was restarted; the session replays on the next command"
    pure True

  evalWithRetry text = do
    outcome <- liftIO (evalInput st True text)
    case outcome of
      EvalDone -> pure ()
      EvalIncomplete -> do
        extra <- readContinuationLines st []
        if null extra
          then void (liftIO (evalInput st False text))
          else evalWithRetry (text ++ "\n" ++ intercalate "\n" extra)

-- Read one line, handling prompt display, echo, and transcript capture for
-- both interactive and piped stdin.
readLine :: St -> Bool -> String -> InputT IO (Maybe String)
readLine st isMain promptText = do
  interactive <- liftIO (rsInteractive <$> readIORef st)
  if interactive
    then do
      input <- getInputLine promptText
      forM_ input (liftIO . transcriptInput' st isMain promptText)
      pure input
    else do
      liftIO $ do
        state <- readIORef st
        when (rsTimestamps state && isMain) $
          forM_ (rsTranscript state) $ \(_, h) -> do
            now <- getZonedTime
            hPutStrLn h (formatTime defaultTimeLocale "[%H:%M:%S]" now)
        emit st promptText
      -- read stdin directly: Haskeline's file backend decodes with the
      -- locale codepage, corrupting UTF-8 input on Windows
      input <- liftIO (catchIOError (Just <$> getLine)
        (\e -> if isEOFError e then pure Nothing else ioError e))
      case input of
        Nothing -> Nothing <$ liftIO (emitLn st "")
        Just l -> do
          liftIO (emitLn st l)  -- echo piped input so transcripts are readable
          pure (Just l)

readContinuationLines :: St -> [String] -> InputT IO [String]
readContinuationLines st acc = do
  next <- readLine st False contPrompt
  case next of
    Nothing -> pure (reverse acc)
    Just l
      | null (trim l) -> pure (reverse acc)
      | otherwise -> readContinuationLines st (l : acc)

-- One logical (possibly multi-line) input; Nothing on EOF.
readLogicalInput :: St -> InputT IO (Maybe String)
readLogicalInput st = do
  promptText <- liftIO (promptOf st)
  input <- readLine st True promptText
  case input of
    Nothing -> pure Nothing
    Just line -> case () of
      _ | trim line == ":{" -> Just <$> collectBlock []
        | ":" `isPrefixOf` trim line && not (":=" `isPrefixOf` trim line) ->
            pure (Just line)
        | needsContinuation line -> do
            extra <- readContinuationLines st []
            pure (Just (intercalate "\n" (line : extra)))
        | otherwise -> pure (Just line)
 where
  collectBlock acc = do
    next <- readLine st False contPrompt
    case next of
      Nothing -> pure (intercalate "\n" (reverse acc))
      Just l
        | trim l == ":}" -> pure (intercalate "\n" (reverse acc))
        | otherwise -> collectBlock (l : acc)

mkSettings :: St -> Settings IO
mkSettings st = Settings
  { complete = completeWord Nothing " \t()[]{},\10216\10217" completer
  , historyFile = Nothing  -- set in main
  , autoAddHistory = True
  }
 where
  completer word
    | ":" `isPrefixOf` word =
        pure [simpleCompletion c | c <- commandNames, word `isPrefixOf` c]
    | length word >= 2 = do
        result <- try (completionCandidates st word)
        case result of
          Right cands -> pure (map simpleCompletion cands)
          Left (_ :: SomeException) -> pure []
    | otherwise = pure []

trim :: String -> String
trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

-- | Entry point: set UTF-8 handles, parse the command line, and hand the
-- options to 'run', which loads the optional Length ranking mode, locates and
-- probes the Lean REPL backend, and drives the interactive loop until exit.
-- A command-line parse failure prints the message and exits with status 2.
main :: IO ()
main = do
  hSetEncoding stdin utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  hSetBuffering stdout (BlockBuffering Nothing)
  args <- getArgs
  restoreConsole <- setupConsoleUtf8
  case parseArgs args of
    Left message -> putStrLn message >> exitWith (ExitFailure 2)
    Right opts -> run opts `finally` restoreConsole

run :: Options -> IO ()
run opts = do
  vtOk <- enableVT
  tty <- hIsTerminalDevice stdout
  interactive <- hIsTerminalDevice stdin
  let useColor = vtOk && tty

  lengthAssessmentMode <- case lengthAssessmentSetup opts of
    Nothing -> pure disabledLengthAssessmentMode
    Just (activation, source) -> do
      loaded <- loadLengthAssessmentMode activation source
      case loaded of
        Left failure -> do
          putStrLn $ "error: finite-spine Length counterexample " ++
            "ranking setup failed: " ++ show failure
          exitWith $ ExitFailure 1
        Right mode -> pure mode

  replExe <- case optReplExe opts of
    Just path -> pure (Just path)
    Nothing -> discoverReplExe
  case replExe of
    Nothing -> do
      putStrLn "error: could not find the Lean REPL backend executable."
      putStrLn "Pass --repl-exe / set LEANT_BACKEND to a repl.exe built from"
      putStrLn "https://github.com/leanprover-community/repl for your toolchain."
      exitWith (ExitFailure 1)
    Just exe0 -> do
      exe <- makeAbsolute exe0
      project <- case (optPlain opts, optProject opts) of
        (True, _) -> pure Nothing
        (_, Just dir) -> pure (Just dir)
        _ -> findProject
      -- Plain mode runs in the backend's own Lake project. LeanInteract cache
      -- layouts vary across platforms, so locate its lakefile instead of
      -- assuming a fixed depth above @.lake/build/bin/repl@.
      workingDir0 <- case project of
        Just directory -> pure directory
        Nothing -> do
          backendProject <- findBackendProject exe
          case backendProject of
            Just directory -> pure directory
            Nothing -> do
              putStrLn "error: could not locate the Lean backend's Lake project."
              putStrLn "Pass --project, or point --repl-exe / LEANT_BACKEND at"
              putStrLn "an executable built below a lakefile.lean or lakefile.toml."
              exitWith (ExitFailure 1)
      workingDir <- makeAbsolute workingDir0
      let config = BackendConfig
            { bcLakePath = optLake opts
            , bcReplExe = exe
            , bcWorkingDir = workingDir
            }
      ratings <- loadRatings
      synthTimeout <- initialSynthTimeoutSeconds
      synthDebug <- isJust <$> lookupEnv "LEANT_SYNTH_DEBUG"
      st <- newIORef ReplState
        { rsBackend = Nothing
        , rsConfig = config
        , rsProjectDir = project
        , rsEnv = Nothing
        , rsBaseEnv = Nothing
        , rsSnapshotBase = Nothing
        , rsEnvStack = []
        , rsImports = optImports opts
        , rsHistory = []
        , rsLoadedFile = Nothing
        , rsShowTime = optTime opts
        , rsTimestamps = optTimestamps opts
        , rsTranscript = Nothing
        , rsProve = Nothing
        , rsProveCounter = 0
        , rsLastSorry = Nothing
        , rsItCounter = 0
        , rsComplCache = []
        , rsBrowseEnv = Nothing
        , rsSynthBase = Nothing
        , rsSynthEnv = Nothing
        , rsProviderWorld = initialProviderWorld
        , rsProviderCache = emptyProviderCache providerCacheCapacity
        , rsSynthIts = []
        , rsSynthItsProve = False
        , rsSynthEngine = EngineDjinn
        , rsSynthSteps = 4096
        , rsSynthClassical = True
        , rsSynthLibrary = True
        , rsSynthTimeout = synthTimeout
        , rsSynthLimits = defaultSynthLimits
        , rsSynthProviders = True
        , rsSynthProviderCap = defaultProviderCap
        , rsSynthLibraryPremises = 8
        , rsSynthDebug = synthDebug
        , rsLengthAssessmentMode = lengthAssessmentMode
        , rsRatings = ratings
        , rsTimeout = if optTimeout opts <= 0 then Nothing
            else Just (optTimeout opts)
        , rsColor = useColor
        , rsInteractive = interactive
        }

      forM_ (optTranscript opts) (transcriptStart st)
      case project of
        Just dir -> do
          emitLn st =<< cDim st ("using Lake project: " ++ dir)
          built <- isBuiltProject dir
          unless built $ do
            warning <- cYellow st "warning: "
            emitLn st (warning ++ dir ++ " has no .lake build - run `lake build` there first")
        Nothing -> emitLn st =<< cDim st
          ("no Lake project; using the backend's own project (" ++ workingDir ++ ")")

      -- startup probe (spawns the backend and surfaces setup problems early)
      started <- getCurrentTime
      probe <- runCmd st Nothing "#eval (0 : Nat)"
      case probe of
        Left err -> do
          emitLn st =<< cRed st "the Lean backend failed to start:"
          emitLn st err
          exitWith (ExitFailure 1)
        Right _ -> do
          finished <- getCurrentTime
          emitLn st =<< cDim st ("backend responding ("
            ++ show (round (diffUTCTime finished started) :: Integer) ++ "s)")

      -- imports requested on the command line
      importsOk <- do
        imports <- rsImports <$> readIORef st
        if null imports then pure True else rebuildSession st
      unless importsOk $ emitLn st =<< cRed st "startup imports failed"

      emit st =<< cCyan st banner
      bold1 <- cBold st ":help"
      bold2 <- cBold st ":quit"
      emitLn st ("Leant (Haskell) - a GHCi-style REPL for Lean 4.  Type "
        ++ bold1 ++ " for help, " ++ bold2 ++ " to exit.")
      case lengthAssessmentModeActivationPolicy lengthAssessmentMode of
        Nothing -> pure ()
        Just activation -> do
          emitLn st =<< cDim st (case activation of
            RequirePinnedExecutable ->
              "Finite-spine Length counterexample ranking enabled for " ++
                "eligible typed Exference origins with a startup-fixed " ++
                "contract; a solver executable digest expectation was required."
            PermitUnpinnedExecutable ->
              "Finite-spine Length counterexample ranking enabled for " ++
                "eligible typed Exference origins with a startup-fixed " ++
                "contract; unpinned solver execution was explicitly permitted.")
          case lengthAssessmentModeExecutableLaunchStrategy
              lengthAssessmentMode of
            Just LengthSMTLibDescriptorBoundExecutableLaunch ->
              emitLn st =<< cDim st
                ("Descriptor-bound solver executable launch selected; any " ++
                  "configured digest will be checked against the sealed " ++
                  "staged main-image bytes used for descriptor launch.")
            Just
                LengthSMTLibDescriptorBoundEffectiveIDExecutableAccessLaunch ->
              emitLn st =<< cDim st
                ("Effective-ID executable-access descriptor launch selected; " ++
                  "the opened source must pass Linux faccessat2 X_OK under " ++
                  "effective filesystem credentials before copying and again " ++
                  "immediately before child allocation; any configured digest " ++
                  "is checked against the sealed staged main-image bytes.")
            Just
                LengthSMTLibDescriptorBoundExecveCheckExecutableAccessLaunch ->
              emitLn st =<< cDim st
                ("Descriptor-bound execve-check executable-access launch " ++
                  "selected; the opened source must pass Linux faccessat2 X_OK " ++
                  "under effective filesystem credentials and AT_EXECVE_CHECK " ++
                  "before copying and again immediately before child " ++
                  "allocation; the sealed staged image must pass " ++
                  "AT_EXECVE_CHECK immediately before child allocation; any " ++
                  "configured digest is checked against the sealed staged " ++
                  "main-image bytes.")
            Just LengthSMTLibPathSnapshotThenDirectSpawn -> pure ()
            Nothing -> pure ()
          emitLn st =<< cDim st
            "Select synth-engine exference or both to produce graph-eligible candidates."

      forM_ (optFile opts) (cmdLoad st)

      home <- getHomeDirectory
      let settings = (mkSettings st)
            { historyFile = if interactive
                then Just (home </> ".leant_history")
                else Nothing }
          behavior = if interactive then defaultBehavior else useFileHandle stdin
      runInputTBehavior behavior settings (replLoop st)

      -- cleanup
      state <- readIORef st
      when (isJust (rsTranscript state)) (transcriptStop st)
      forM_ (rsBackend state) killBackend
      forM_ (rsSnapshotBase state) cleanupSnapshotBase
