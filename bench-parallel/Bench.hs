module Main (main) where

import Control.Concurrent (getNumCapabilities)
import Control.DeepSeq (force)
import Control.Exception (evaluate)
import Control.Monad (forM, unless)
import Data.Bits (xor)
import qualified Data.ByteString as ByteString
import Data.List (sort)
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
  , synthLimitTried
  , synthVerificationWindowWith
  , synthesizeWithProvidersSkippingDetailedWith
  )
import Leant.Synth.Engine.Parallel (runParallelEitherPairOrdered)
import Leant.Synth.Fragment (Frag (..))

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
    ["worker", modeText, expectedCapabilitiesText] -> do
      mode <- parseMode modeText
      expectedCapabilities <- parsePositive
        "worker capability argument" expectedCapabilitiesText
      runWorker mode expectedCapabilities
    _ -> die
      "usage: leant-parallel-bench [worker (serial|parallel) CAPABILITIES]"

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
