-- | Pure command-line parsing for the Leant executable.
--
-- Keeping this separate from @Main@ makes startup policy testable without
-- opening the Lean backend or finite-list-spine Length ranking.
module Leant.Options
  ( Options (..)
  , lengthAssessmentSetup
  , parseArgs
  , usage
  ) where

import Data.List (isPrefixOf)
import Data.Maybe (isJust, isNothing)

import Leant.Synth.Length.Configuration.File.Acquire
  ( lengthRankingConfigurationFileMaximumTimeoutMilliseconds )
import Leant.Synth.Length.Integration
  ( LengthRankingConfigurationActivationPolicy (..)
  , LengthRankingConfigurationFileSource (..)
  )

-- | Parsed command-line options.  'optTranscript' is @Just Nothing@ for a
-- transcript at the default location and @Just (Just path)@ for an explicit
-- one.
data Options = Options
  { optProject :: Maybe FilePath
  , optPlain :: Bool
  , optImports :: [String]
  , optTimeout :: Int
  , optTime :: Bool
  , optTranscript :: Maybe (Maybe FilePath)
  , optTimestamps :: Bool
  , optReplExe :: Maybe FilePath
  , optLake :: FilePath
  , optLengthRankingConfig :: Maybe FilePath
  , optLengthRankingLoadTimeout :: Maybe Int
  , optLengthRankingAllowUnpinned :: Bool
  , optFile :: Maybe FilePath
  }

defaultOptions :: Options
defaultOptions = Options
  Nothing False [] 300 False Nothing False Nothing "lake"
  Nothing Nothing False Nothing

defaultLengthAssessmentLoadTimeoutMilliseconds :: Int
defaultLengthAssessmentLoadTimeoutMilliseconds = 5000

-- | The complete optional setup decision consumed by Main.  Keeping the pin
-- default and file-load timeout here makes command-line admission and startup
-- execution share one interpretation.
lengthAssessmentSetup
  :: Options
  -> Maybe
      ( LengthRankingConfigurationActivationPolicy
      , LengthRankingConfigurationFileSource
      )
lengthAssessmentSetup options = case optLengthRankingConfig options of
  Nothing -> Nothing
  Just path -> Just
    ( if optLengthRankingAllowUnpinned options
        then PermitUnpinnedExecutable
        else RequirePinnedExecutable
    , LengthRankingConfigurationFileSource path
        $ maybe defaultLengthAssessmentLoadTimeoutMilliseconds id
        $ optLengthRankingLoadTimeout options
    )

-- | Parse the command line, validating option combinations.  @--help@ and
-- errors return 'Left' with the message to print.
parseArgs :: [String] -> Either String Options
parseArgs = go defaultOptions
 where
  go opts [] = validateOptions opts
  go opts (argument : rest) = case argument of
    "--project" -> withValue rest (\value remaining ->
      go opts { optProject = Just value } remaining)
    "-p" -> withValue rest (\value remaining ->
      go opts { optProject = Just value } remaining)
    "--plain" -> go opts { optPlain = True } rest
    "--import" -> withValue rest (\value remaining ->
      go opts { optImports = optImports opts ++ splitCommas value } remaining)
    "-i" -> withValue rest (\value remaining ->
      go opts { optImports = optImports opts ++ splitCommas value } remaining)
    "--timeout" -> withValue rest (\value remaining -> case reads value of
      [(parsed, "")] -> go opts { optTimeout = parsed } remaining
      _ -> Left "--timeout expects a number")
    "--time" -> go opts { optTime = True } rest
    "--transcript" -> case rest of
      value : remaining | not ("-" `isPrefixOf` value) ->
        go opts { optTranscript = Just $ Just value } remaining
      _ -> go opts { optTranscript = Just Nothing } rest
    "--timestamps" -> go opts { optTimestamps = True } rest
    "--repl-exe" -> withValue rest (\value remaining ->
      go opts { optReplExe = Just value } remaining)
    "--lake" -> withValue rest (\value remaining ->
      go opts { optLake = value } remaining)
    "--length-ranking-config" -> withValue rest (\value remaining ->
      go opts { optLengthRankingConfig = Just value } remaining)
    "--length-ranking-config-timeout" ->
      withValue rest (\value remaining -> case reads value of
        [(parsed, "")]
          | parsed > (0 :: Integer)
          , parsed <= toInteger
              lengthRankingConfigurationFileMaximumTimeoutMilliseconds ->
              go opts
                { optLengthRankingLoadTimeout = Just $ fromInteger parsed }
                remaining
        _ -> Left $ "--length-ranking-config-timeout expects 1.." ++
          show lengthRankingConfigurationFileMaximumTimeoutMilliseconds ++
          " milliseconds")
    "--length-ranking-allow-unpinned" -> go opts
      { optLengthRankingAllowUnpinned = True } rest
    "--help" -> Left usage
    _ | "-" `isPrefixOf` argument ->
          Left $ "unknown option " ++ argument ++ "\n" ++ usage
      | otherwise -> go opts { optFile = Just argument } rest

  withValue (value : remaining) continuation =
    continuation value remaining
  withValue [] _ = Left "missing option value"

  splitCommas = filter (not . null) . splitOn ','

  validateOptions opts
    | isNothing (optLengthRankingConfig opts)
        && isJust (optLengthRankingLoadTimeout opts) = Left
          "--length-ranking-config-timeout requires --length-ranking-config"
    | isNothing (optLengthRankingConfig opts)
        && optLengthRankingAllowUnpinned opts = Left
          "--length-ranking-allow-unpinned requires --length-ranking-config"
    | otherwise = Right opts

-- | The complete @--help@ text.
usage :: String
usage = unlines
  [ "usage: leant [FILE] [options]"
  , "  --project DIR    path to a Lake project to run inside"
  , "  --plain          do not use any Lake project (backend project only)"
  , "  -i, --import M   module to import at startup (repeatable)"
  , "  --timeout N      per-command timeout in seconds (0 = none, default 300)"
  , "  --time           show per-command timing"
  , "  --transcript [F] record a full transcript of the session"
  , "  --timestamps     timestamp each command in the transcript"
  , "  --repl-exe PATH  Lean REPL backend executable (see also LEANT_BACKEND)"
  , "  --lake PATH      lake executable (default: lake)"
  , "  --length-ranking-config PATH"
  , "                   absolute configuration path (POSIX acquisition only)"
  , "                   for typed or exact-duplicate Exference origins"
  , "  --length-ranking-config-timeout MS"
  , "                   configuration load timeout (default " ++
      show defaultLengthAssessmentLoadTimeoutMilliseconds ++ ", max " ++
      show lengthRankingConfigurationFileMaximumTimeoutMilliseconds ++ ")"
  , "  --length-ranking-allow-unpinned"
  , "                   explicitly permit a config without an executable pin"
  ]

splitOn :: Eq value => value -> [value] -> [[value]]
splitOn separator values = case break (== separator) values of
  (chunk, []) -> [chunk]
  (chunk, _ : rest) -> chunk : splitOn separator rest
