module Main (main) where

import Control.Concurrent (getNumCapabilities)
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM, unless)
import Data.Bits (xor)
import qualified Data.ByteString as ByteString
import Data.List (sort, stripPrefix)
import qualified Data.Set as Set
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
import Numeric (showHex)
import System.Environment (getArgs, getExecutablePath, lookupEnv)
import System.Exit (ExitCode (..), die)
import System.Process (readProcessWithExitCode)
import Text.Printf (printf)
import Text.Read (readMaybe)

import Leant.Synth.Engine
  ( DetailedCandidateGroup
  , DetailedSynthOutcome (..)
  , DetailedVerificationVariant
  , SynthEngine (..)
  , defaultSynthLimits
  , detailedCandidateGroupRoute
  , detailedCandidateGroupVerificationVariants
  , detailedVerificationVariantOrdinal
  , detailedVerificationVariantRoute
  , detailedVerificationVariantText
  , forceDetailedOutcome
  , mergeDetailedOutcomesSkipping
  , synthLimitWindow
  , synthLimitTried
  , synthVerificationWindowWith
  , synthesizeTunedDetailedWith
  , synthesizeWithProvidersSkippingDetailedWith
  )
import Leant.Synth.Engine.Parallel (runParallelEitherPairOrdered)
import Leant.Synth.Fragment (Frag (..), stripRecCtors)

data SearchMode = Serial | Parallel
  deriving (Eq, Show)

data TimedRun = TimedRun
  { timedRunWallSeconds :: !Double
  , timedRunTranscript :: String
  }

benchmarkSamplesVariable :: String
benchmarkSamplesVariable = "LEANT_PARALLEL_BENCH_SAMPLES"

benchmarkCapabilitiesVariable :: String
benchmarkCapabilitiesVariable = "LEANT_PARALLEL_BENCH_CAPABILITIES"

benchmarkSteps :: Int
benchmarkSteps = 4096

expectedLaneFrontier :: Int
expectedLaneFrontier = 12

expectedCombinedFrontier :: Int
expectedCombinedFrontier = 24

laneFrontier :: Int
laneFrontier = synthLimitTried defaultSynthLimits

combinedFrontier :: Int
combinedFrontier = synthVerificationWindowWith defaultSynthLimits EngineBoth

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [] -> runCoordinator
    ["library"] -> runLibraryCoordinator
    ["worker", modeText, expectedCapabilitiesText] -> do
      mode <- parseMode modeText
      expectedCapabilities <- parsePositive
        "worker capability argument" expectedCapabilitiesText
      runWorker mode expectedCapabilities
    ["library-worker", engineText, modeText, expectedCapabilitiesText] -> do
      engine <- parseLibraryEngine engineText
      mode <- parseMode modeText
      expectedCapabilities <- parsePositive
        "worker capability argument" expectedCapabilitiesText
      runLibraryWorker engine mode expectedCapabilities
    _ -> die
      "usage: leant-parallel-bench [library | worker (serial|parallel) \
      \CAPABILITIES | library-worker (djinn|exference|both) \
      \(serial|parallel) CAPABILITIES]"

runCoordinator :: IO ()
runCoordinator = do
  validateBenchmarkContract
  samples <- readPositiveVariable benchmarkSamplesVariable 5
  capabilities <- readPositiveVariable benchmarkCapabilitiesVariable 2
  executable <- getExecutablePath
  putStrLn "Leant deterministic parallel search benchmark"
  putStrLn
    "workload: quartic rank-N; steps=4096; no providers; no checked terms"
  putStrLn $ "frontier: " ++ show laneFrontier
    ++ " groups per engine; " ++ show combinedFrontier ++ " groups combined"
  putStrLn $ "samples: " ++ show samples
  putStrLn $ "worker capabilities: " ++ show capabilities
  putStrLn
    "timing: fresh worker-process wall time (startup + search + transcript)"

  preflightSerial <- runFreshWorker executable capabilities Serial
  preflightParallel <- runFreshWorker executable capabilities Parallel
  ensureEquivalent "preflight"
    (timedRunTranscript preflightSerial)
    (timedRunTranscript preflightParallel)
  let expectedTranscript = timedRunTranscript preflightSerial
  putStrLn "preflight semantic transcript: byte-for-byte equal"
  putStrLn $ "semantic transcript FNV-1a-64/UTF-8: "
    ++ renderWord64 (hashTranscript expectedTranscript)

  results <- forM [1 .. samples] $ \sampleNumber -> do
    let serialFirst = odd sampleNumber
    (serialRun, parallelRun) <- if serialFirst
      then do
        serialResult <- runFreshWorker executable capabilities Serial
        parallelResult <- runFreshWorker executable capabilities Parallel
        pure (serialResult, parallelResult)
      else do
        parallelResult <- runFreshWorker executable capabilities Parallel
        serialResult <- runFreshWorker executable capabilities Serial
        pure (serialResult, parallelResult)
    ensureEquivalent ("sample " ++ show sampleNumber)
      expectedTranscript (timedRunTranscript serialRun)
    ensureEquivalent ("sample " ++ show sampleNumber)
      expectedTranscript (timedRunTranscript parallelRun)
    printf
      "sample %d (%s first): serial %.6f s; parallel %.6f s\n"
      sampleNumber
      (if serialFirst then "serial" else "parallel")
      (timedRunWallSeconds serialRun)
      (timedRunWallSeconds parallelRun)
    pure (timedRunWallSeconds serialRun, timedRunWallSeconds parallelRun)

  let serialTimes = map fst results
      parallelTimes = map snd results
      serialMedian = median serialTimes
      parallelMedian = median parallelTimes
  printSummary "serial" serialTimes
  printSummary "parallel" parallelTimes
  printf "observed median wall ratio (serial / parallel): %.3fx\n"
    (serialMedian / parallelMedian)

-- The established no-argument quartic benchmark and its v1 transcript stay
-- unchanged.  The explicit @library@ mode measures the separate outer pair
-- used by Main when selected library premises are present: one provider-free
-- structural search and one tuned library search, with EngineBoth itself
-- remaining serial inside each action.
runLibraryCoordinator :: IO ()
runLibraryCoordinator = do
  validateBenchmarkContract
  samples <- readPositiveVariable benchmarkSamplesVariable 5
  capabilities <- readPositiveVariable benchmarkCapabilitiesVariable 2
  executable <- getExecutablePath
  putStrLn "Leant deterministic outer library-search benchmark"
  putStrLn
    "workload: List.map goal; selected map/reverse/append premises; steps=4096"
  putStrLn
    "scope: no providers, Lean backend, verification, or nested engine work"
  putStrLn $ "samples per engine: " ++ show samples
  putStrLn $ "worker capabilities: " ++ show capabilities
  putStrLn
    "timing: fresh worker-process wall time (startup + search + transcript)"
  mapM_ (runLibraryEngineCoordinator executable capabilities samples)
    [EngineDjinn, EngineExference, EngineBoth]

runLibraryEngineCoordinator :: FilePath -> Int -> Int -> SynthEngine -> IO ()
runLibraryEngineCoordinator executable capabilities samples engine = do
  let libraryFrontier = synthVerificationWindowWith defaultSynthLimits engine
  putStrLn $ "engine: " ++ libraryEngineArgument engine
  putStrLn $ "bounded demand: base 0 groups; library "
    ++ show libraryFrontier ++ " groups"

  preflightSerial <- runFreshLibraryWorker executable capabilities engine Serial
  preflightParallel <-
    runFreshLibraryWorker executable capabilities engine Parallel
  ensureEquivalent ("library " ++ libraryEngineArgument engine ++ " preflight")
    (timedRunTranscript preflightSerial)
    (timedRunTranscript preflightParallel)
  let expectedTranscript = timedRunTranscript preflightSerial
  putStrLn "preflight semantic transcript: byte-for-byte equal"
  putStrLn $ "semantic transcript FNV-1a-64/UTF-8: "
    ++ renderWord64 (hashTranscript expectedTranscript)
  putStrLn $ "actual library candidate groups inside demand cap: "
    ++ show (libraryTranscriptGroupCount expectedTranscript)

  results <- forM [1 .. samples] $ \sampleNumber -> do
    let serialFirst = odd sampleNumber
    (serialRun, parallelRun) <- if serialFirst
      then do
        serialResult <-
          runFreshLibraryWorker executable capabilities engine Serial
        parallelResult <-
          runFreshLibraryWorker executable capabilities engine Parallel
        pure (serialResult, parallelResult)
      else do
        parallelResult <-
          runFreshLibraryWorker executable capabilities engine Parallel
        serialResult <-
          runFreshLibraryWorker executable capabilities engine Serial
        pure (serialResult, parallelResult)
    ensureEquivalent
      ("library " ++ libraryEngineArgument engine ++ " sample "
        ++ show sampleNumber ++ " serial")
      expectedTranscript (timedRunTranscript serialRun)
    ensureEquivalent
      ("library " ++ libraryEngineArgument engine ++ " sample "
        ++ show sampleNumber ++ " parallel")
      expectedTranscript (timedRunTranscript parallelRun)
    printf
      "sample %d (%s first): serial %.6f s; parallel %.6f s\n"
      sampleNumber
      (if serialFirst then "serial" else "parallel")
      (timedRunWallSeconds serialRun)
      (timedRunWallSeconds parallelRun)
    pure (timedRunWallSeconds serialRun, timedRunWallSeconds parallelRun)

  let serialTimes = map fst results
      parallelTimes = map snd results
      serialMedian = median serialTimes
      parallelMedian = median parallelTimes
  printSummary "serial" serialTimes
  printSummary "parallel" parallelTimes
  printf "observed median wall ratio (serial / parallel): %.3fx\n"
    (serialMedian / parallelMedian)

runWorker :: SearchMode -> Int -> IO ()
runWorker mode expectedCapabilities = do
  validateBenchmarkContract
  actualCapabilities <- getNumCapabilities
  unless (actualCapabilities == expectedCapabilities) $ die $
    "worker capability mismatch: expected " ++ show expectedCapabilities
      ++ ", got " ++ show actualCapabilities
  outcome <- case mode of
    Serial -> runSerialSearch
    Parallel -> runParallelSearch
  transcript <- evaluate $ force $ semanticTranscript outcome
  putStr transcript

runLibraryWorker :: SynthEngine -> SearchMode -> Int -> IO ()
runLibraryWorker engine mode expectedCapabilities = do
  validateBenchmarkContract
  actualCapabilities <- getNumCapabilities
  unless (actualCapabilities == expectedCapabilities) $ die $
    "worker capability mismatch: expected " ++ show expectedCapabilities
      ++ ", got " ++ show actualCapabilities
  outcome <- case mode of
    Serial -> runSerialLibrarySearch engine
    Parallel -> runParallelLibrarySearch engine
  transcript <- evaluate $ force $ librarySemanticTranscript engine outcome
  putStr transcript

runSerialSearch :: IO (Either String DetailedSynthOutcome)
runSerialSearch = do
  let outcome = search EngineBoth
  _ <- evaluate $ forceDetailedOutcome combinedFrontier outcome
  pure outcome

runParallelSearch :: IO (Either String DetailedSynthOutcome)
runParallelSearch = do
  paired <- runParallelEitherPairOrdered
    (runLane EngineDjinn)
    (runLane EngineExference)
  let outcome = fmap
        (uncurry $ mergeDetailedOutcomesSkipping Set.empty)
        paired
  _ <- evaluate $ forceDetailedOutcome combinedFrontier outcome
  pure outcome
 where
  runLane engine = do
    let outcome = search engine
    _ <- evaluate $ forceDetailedOutcome laneFrontier outcome
    pure outcome

search :: SynthEngine -> Either String DetailedSynthOutcome
search engine =
  synthesizeWithProvidersSkippingDetailedWith
    defaultSynthLimits engine benchmarkSteps Set.empty [] quarticGoal

runSerialLibrarySearch
  :: SynthEngine
  -> IO (Either String (DetailedSynthOutcome, DetailedSynthOutcome))
runSerialLibrarySearch engine = do
  baseOutcome <- strictLibraryPrefix 0 (libraryBaseSearch engine)
  case baseOutcome of
    Left err -> pure (Left err)
    Right base -> do
      libraryOutcome <- strictLibraryPrefix
        (synthVerificationWindowWith defaultSynthLimits engine)
        (libraryPremiseSearch engine)
      pure $ fmap (\library -> (base, library)) libraryOutcome

runParallelLibrarySearch
  :: SynthEngine
  -> IO (Either String (DetailedSynthOutcome, DetailedSynthOutcome))
runParallelLibrarySearch engine =
  runParallelEitherPairOrdered
    (strictLibraryPrefix 0 (libraryBaseSearch engine))
    (strictLibraryPrefix
      (synthVerificationWindowWith defaultSynthLimits engine)
      (libraryPremiseSearch engine))

strictLibraryPrefix
  :: Int
  -> Either String DetailedSynthOutcome
  -> IO (Either String DetailedSynthOutcome)
strictLibraryPrefix requested outcome = do
  _ <- evaluate $ forceDetailedOutcome requested outcome
  pure outcome

libraryBaseSearch :: SynthEngine -> Either String DetailedSynthOutcome
libraryBaseSearch engine =
  synthesizeWithProvidersSkippingDetailedWith
    defaultSynthLimits engine benchmarkSteps Set.empty [] libraryGoal

libraryPremiseSearch :: SynthEngine -> Either String DetailedSynthOutcome
libraryPremiseSearch engine =
  synthesizeTunedDetailedWith defaultSynthLimits engine benchmarkSteps
    (synthLimitWindow defaultSynthLimits, Just 100000)
    [ (name, stripRecCtors premise)
    | (name, premise) <- libraryPremises
    ]
    (stripRecCtors libraryGoal) libraryGoal

-- This mirrors the first checked case in test/synth-library.txt.  Main's
-- serializer instantiates selected premises at the goal's own element types;
-- the goal retains its recursive constructor schemas for the ordinary action,
-- while the tuned action receives the same constructor-stripped premise and
-- goal forms used by Main.
libraryGoal :: Frag
libraryGoal = libraryMapBody

libraryPremises :: [(String, Frag)]
libraryPremises =
  [ ("List.map", libraryMapBody)
  , ("List.map", libraryMapAA)
  , ("List.map", libraryMapBA)
  , ("List.map", libraryMapBB)
  , ("List.append", FArr libraryListA (FArr libraryListA libraryListA))
  , ("List.append", FArr libraryListB (FArr libraryListB libraryListB))
  , ("List.reverse", FArr libraryListA libraryListA)
  , ("List.reverse", FArr libraryListB libraryListB)
  ]

libraryMapBody :: Frag
libraryMapBody =
  FArr (FArr libraryElementA libraryElementB)
    (FArr libraryListA libraryListB)

libraryMapAA, libraryMapBA, libraryMapBB :: Frag
libraryMapAA =
  FArr (FArr libraryElementA libraryElementA)
    (FArr libraryListA libraryListA)
libraryMapBA =
  FArr (FArr libraryElementB libraryElementA)
    (FArr libraryListB libraryListA)
libraryMapBB =
  FArr (FArr libraryElementB libraryElementB)
    (FArr libraryListB libraryListB)

libraryElementA, libraryElementB, libraryListA, libraryListB :: Frag
libraryElementA = FVar "a"
libraryElementB = FVar "b"
libraryListA = libraryList "List a" libraryElementA
libraryListB = libraryList "List b" libraryElementB

libraryList :: String -> Frag -> Frag
libraryList key element = FParamRec True "List" key [element]
  [ ("List.nil", [])
  , ("List.cons", [element, FAtom False key])
  ]

-- This is the exact fragment used by Spec's balanced eight-site quartic
-- rank-N synthesis case. It intentionally exercises only in-process search:
-- no provider discovery, Lean backend, verification, or behavioral solver.
quarticGoal :: Frag
quarticGoal =
  FAll True "s0"
    (FAll True "s1" (FAll True "s2" (FAll True "s3" body)))
 where
  variable = FVar
  universe = FAtom False "Type"
  scheme codomain = foldr FArr codomain (replicate 5 universe)
  identity = FAll True "s4"
    (FArr (variable "s4") (variable "s4"))
  q = variable "s0"
  r = variable "s1"
  z = variable "s2"
  m = variable "s3"
  result = foldr1 FProd
    [ scheme q, scheme r, scheme z, scheme m
    , identity, identity, identity, identity
    ]
  body = foldr FArr result [scheme q, scheme r, scheme z, scheme m]

semanticTranscript :: Either String DetailedSynthOutcome -> String
semanticTranscript outcome = unlines $ schemaLine : case outcome of
  Left err ->
    [ "outcome\terror"
    , "error\t" ++ show err
    , "notes-count\t0"
    ]
  Right (DetailedSynthRefuted sound) ->
    [ "outcome\trefuted"
    , "sound\t" ++ show sound
    , "notes-count\t0"
    ]
  Right (DetailedSynthNoTerm notes) ->
    ["outcome\tno-term"] ++ noteLines notes
  Right (DetailedSynthCandidates groups notes) ->
    let frontier = take combinedFrontier groups
    in [ "outcome\tcandidates"
       , "group-count\t" ++ show (length frontier)
       ]
      ++ concat (zipWith groupLines [0 :: Int ..] frontier)
      ++ noteLines notes
 where
  schemaLine = "schema\tleant-parallel-search-v1"

librarySemanticTranscript
  :: SynthEngine
  -> Either String (DetailedSynthOutcome, DetailedSynthOutcome)
  -> String
librarySemanticTranscript engine outcome = unlines $
  [ "schema\tleant-parallel-library-search-v1"
  , "engine\t" ++ libraryEngineArgument engine
  , "base-demand-cap\t0"
  , "library-demand-cap\t"
      ++ show (synthVerificationWindowWith defaultSynthLimits engine)
  ] ++ case outcome of
    Left err ->
      [ "pair-outcome\terror"
      , "error\t" ++ show err
      ]
    Right (baseOutcome, libraryOutcome) ->
      ["pair-outcome\tsuccess"]
        ++ boundedOutcomeLines "base" 0 baseOutcome
        ++ boundedOutcomeLines "library"
          (synthVerificationWindowWith defaultSynthLimits engine)
          libraryOutcome

boundedOutcomeLines :: String -> Int -> DetailedSynthOutcome -> [String]
boundedOutcomeLines label requested outcome = case outcome of
  DetailedSynthRefuted sound ->
    [ label ++ "-outcome\trefuted"
    , label ++ "-sound\t" ++ show sound
    , label ++ "-notes-count\t0"
    ]
  DetailedSynthNoTerm notes ->
    (label ++ "-outcome\tno-term") : boundedNoteLines label notes
  DetailedSynthCandidates groups notes ->
    let frontier = take requested groups
    in [ label ++ "-outcome\tcandidates"
       , label ++ "-group-count\t" ++ show (length frontier)
       ]
      ++ concat (zipWith (boundedGroupLines label) [0 :: Int ..] frontier)
      ++ boundedNoteLines label notes

boundedGroupLines :: String -> Int -> DetailedCandidateGroup -> [String]
boundedGroupLines label groupOrdinal group =
  [ label ++ "-group\t" ++ show groupOrdinal
      ++ "\troute\t" ++ show (detailedCandidateGroupRoute group)
      ++ "\tvariant-count\t" ++ show (length variants)
  ] ++ concat
    (zipWith (boundedVariantLines label groupOrdinal) [0 :: Int ..] variants)
 where
  variants = detailedCandidateGroupVerificationVariants group

boundedVariantLines
  :: String
  -> Int
  -> Int
  -> DetailedVerificationVariant
  -> [String]
boundedVariantLines label groupOrdinal variantIndex variant =
  [ label ++ "-variant\t" ++ show groupOrdinal
      ++ "\tindex\t" ++ show variantIndex
      ++ "\tordinal\t" ++ show (detailedVerificationVariantOrdinal variant)
      ++ "\troute\t" ++ show (detailedVerificationVariantRoute variant)
      ++ "\ttext\t" ++ show (detailedVerificationVariantText variant)
  ]

boundedNoteLines :: String -> [String] -> [String]
boundedNoteLines label notes =
  (label ++ "-notes-count\t" ++ show (length notes))
    : zipWith renderNote [0 :: Int ..] notes
 where
  renderNote index note =
    label ++ "-note\t" ++ show index ++ "\ttext\t" ++ show note

libraryTranscriptGroupCount :: String -> Int
libraryTranscriptGroupCount transcript = case
    [ value
    | line <- lines transcript
    , Just raw <- [stripPrefix "library-group-count\t" line]
    , Just value <- [readMaybe raw]
    ] of
  [count] -> count
  counts -> error $ "library transcript group-count invariant failed: "
    ++ show counts

groupLines :: Int -> DetailedCandidateGroup -> [String]
groupLines groupOrdinal group =
  [ "group\t" ++ show groupOrdinal
      ++ "\troute\t" ++ show (detailedCandidateGroupRoute group)
      ++ "\tvariant-count\t" ++ show (length variants)
  ] ++ concat (zipWith (variantLines groupOrdinal) [0 :: Int ..] variants)
 where
  variants = detailedCandidateGroupVerificationVariants group

variantLines
  :: Int
  -> Int
  -> DetailedVerificationVariant
  -> [String]
variantLines groupOrdinal variantIndex variant =
  [ "variant\t" ++ show groupOrdinal
      ++ "\tindex\t" ++ show variantIndex
      ++ "\tordinal\t" ++ show (detailedVerificationVariantOrdinal variant)
      ++ "\troute\t" ++ show (detailedVerificationVariantRoute variant)
      ++ "\ttext\t" ++ show (detailedVerificationVariantText variant)
  ]

noteLines :: [String] -> [String]
noteLines notes =
  ("notes-count\t" ++ show (length notes))
    : zipWith renderNote [0 :: Int ..] notes
 where
  renderNote index note =
    "note\t" ++ show index ++ "\ttext\t" ++ show note

runFreshWorker :: FilePath -> Int -> SearchMode -> IO TimedRun
runFreshWorker executable capabilities mode = do
  started <- getMonotonicTimeNSec
  (exitCode, output, errors) <- readProcessWithExitCode executable
    [ "worker"
    , modeArgument mode
    , show capabilities
    , "+RTS"
    , "-N" ++ show capabilities
    , "-RTS"
    ]
    ""
  _ <- evaluate $ force output
  _ <- evaluate $ force errors
  finished <- getMonotonicTimeNSec
  case exitCode of
    ExitFailure code -> die $ modeArgument mode ++ " worker exited "
      ++ show code ++ ": " ++ errors
    ExitSuccess -> unless (null errors) $ die $
      modeArgument mode ++ " worker wrote to stderr: " ++ errors
  pure TimedRun
    { timedRunWallSeconds = nanosecondsToSeconds (finished - started)
    , timedRunTranscript = output
    }

runFreshLibraryWorker
  :: FilePath
  -> Int
  -> SynthEngine
  -> SearchMode
  -> IO TimedRun
runFreshLibraryWorker executable capabilities engine mode = do
  started <- getMonotonicTimeNSec
  (exitCode, output, errors) <- readProcessWithExitCode executable
    [ "library-worker"
    , libraryEngineArgument engine
    , modeArgument mode
    , show capabilities
    , "+RTS"
    , "-N" ++ show capabilities
    , "-RTS"
    ]
    ""
  _ <- evaluate $ force output
  _ <- evaluate $ force errors
  finished <- getMonotonicTimeNSec
  case exitCode of
    ExitFailure code -> die $ "library " ++ libraryEngineArgument engine
      ++ " " ++ modeArgument mode ++ " worker exited "
      ++ show code ++ ": " ++ errors
    ExitSuccess -> unless (null errors) $ die $
      "library " ++ libraryEngineArgument engine ++ " "
        ++ modeArgument mode ++ " worker wrote to stderr: " ++ errors
  pure TimedRun
    { timedRunWallSeconds = nanosecondsToSeconds (finished - started)
    , timedRunTranscript = output
    }

ensureEquivalent :: String -> String -> String -> IO ()
ensureEquivalent phase expected observed =
  unless (expected == observed) $ die $
    phase ++ " semantic transcript mismatch; expected hash "
      ++ renderWord64 (hashTranscript expected) ++ ", observed hash "
      ++ renderWord64 (hashTranscript observed) ++ "; "
      ++ firstDifference expected observed

firstDifference :: String -> String -> String
firstDifference = go 0
 where
  go :: Int -> String -> String -> String
  go _offset [] [] = "no differing character (length check failed)"
  go offset [] right = "expected EOF at character " ++ show offset
    ++ ", observed " ++ show (take 80 right)
  go offset left [] = "observed EOF at character " ++ show offset
    ++ ", expected " ++ show (take 80 left)
  go offset left@(leftChar : leftTail) right@(rightChar : rightTail)
    | leftChar == rightChar = go (offset + 1) leftTail rightTail
    | otherwise = "first difference at character " ++ show offset
        ++ "; expected " ++ show (take 80 left)
        ++ ", observed " ++ show (take 80 right)

hashTranscript :: String -> Word64
hashTranscript = ByteString.foldl' hashByte 14695981039346656037
  . Text.encodeUtf8 . Text.pack
 where
  hashByte hashValue byte =
    (hashValue `xor` fromIntegral byte) * 1099511628211

renderWord64 :: Word64 -> String
renderWord64 value = replicate (16 - length digits) '0' ++ digits
 where
  digits = showHex value ""

nanosecondsToSeconds :: Word64 -> Double
nanosecondsToSeconds nanoseconds = fromIntegral nanoseconds / 1000000000

printSummary :: String -> [Double] -> IO ()
printSummary label values =
  printf "%s wall: median %.6f s; p95 %.6f s\n"
    label (median values) (percentile95 values)

median :: [Double] -> Double
median values = case sort values of
  [] -> error "median requires at least one sample"
  ordered
    | odd count -> ordered !! middle
    | otherwise -> (ordered !! (middle - 1) + ordered !! middle) / 2
   where
    count = length ordered
    middle = count `div` 2

percentile95 :: [Double] -> Double
percentile95 values = case sort values of
  [] -> error "percentile95 requires at least one sample"
  ordered -> ordered !! max 0
    (ceiling (0.95 * fromIntegral (length ordered) :: Double) - 1)

modeArgument :: SearchMode -> String
modeArgument mode = case mode of
  Serial -> "serial"
  Parallel -> "parallel"

parseMode :: String -> IO SearchMode
parseMode mode = case mode of
  "serial" -> pure Serial
  "parallel" -> pure Parallel
  _ -> die $ "unknown worker mode: " ++ show mode

libraryEngineArgument :: SynthEngine -> String
libraryEngineArgument engine = case engine of
  EngineDjinn -> "djinn"
  EngineExference -> "exference"
  EngineBoth -> "both"

parseLibraryEngine :: String -> IO SynthEngine
parseLibraryEngine engine = case engine of
  "djinn" -> pure EngineDjinn
  "exference" -> pure EngineExference
  "both" -> pure EngineBoth
  _ -> die $ "unknown library benchmark engine: " ++ show engine

readPositiveVariable :: String -> Int -> IO Int
readPositiveVariable variable fallback = do
  value <- lookupEnv variable
  case value of
    Nothing -> pure fallback
    Just raw -> parsePositive variable raw

parsePositive :: String -> String -> IO Int
parsePositive label raw = case readMaybe raw of
  Just value | value > 0 -> pure value
  _ -> die $ label ++ " expects a positive Int, got " ++ show raw

validateBenchmarkContract :: IO ()
validateBenchmarkContract = unless
    (laneFrontier == expectedLaneFrontier
      && combinedFrontier == expectedCombinedFrontier
      && combinedFrontier == 2 * laneFrontier) $ die $
  "default synthesis limits changed: benchmark requires 12 groups per lane "
    ++ "and 24 groups combined, got " ++ show laneFrontier ++ " and "
    ++ show combinedFrontier
