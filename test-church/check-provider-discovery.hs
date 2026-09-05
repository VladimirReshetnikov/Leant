-- A live Lean regression for bounded, provider-local instance discovery.
-- Run from the repository root: runghc -isrc test-church/check-provider-discovery.hs
module Main where

import Control.Monad (unless)
import Data.List (isInfixOf, isPrefixOf, tails)
import Leant.Synth.Fragment
import System.Directory (createDirectoryIfMissing)
import System.Exit (ExitCode (..), exitFailure)
import System.FilePath ((</>))
import System.IO (hSetEncoding, stdout, utf8)
import System.Process (readProcessWithExitCode)

main :: IO ()
main = do
  hSetEncoding stdout utf8
  mapM_ check
    ["actual", "ordinary-exception", "local-heartbeat", "recursion-exception", "interrupt"]

check :: String -> IO ()
check mode = do
  let directory = "test-church/generated-provider-discovery"
      sourcePath = directory </> (mode ++ ".lean")
      action = "LeantSynth.providerInstantiationAssignments 80 info.type"
      fault
        | mode == "ordinary-exception" =
            "if n == `Or.by_cases then throwError \"injected assignment failure\" else " ++ action
        | mode == "local-heartbeat" =
            "if n == `Or.by_cases then LeantSynth.exhaustAssignmentBudget else " ++ action
        | mode == "recursion-exception" =
            "if n == `Or.by_cases then throwMaxRecDepthAt (← getRef) else " ++ action
        | mode == "interrupt" =
            "if n == `Or.by_cases then throwInterruptException else " ++ action
        | otherwise = action
      original = providerProgram [] (ProviderQuery ["Or"] (Just "Or"))
      program = replace action fault original
      source = unlines
        [ "import Lean"
        , "set_option maxHeartbeats 200000"
        , "theorem Or.zzzzAfter : True := True.intro"
        , "#print axioms Or.zzzzAfter"
        , synthPrelude []
        , heartbeatWitness
        , rollbackWitness
        , program
        ]
  unless (length (filter (isPrefixOf action) (tails original)) == 1
      && (mode == "actual" || program /= original)) $
    fail "provider assignment injection point changed; update the regression explicitly"
  createDirectoryIfMissing True directory
  writeFile sourcePath source
  (status, output, errors) <- readProcessWithExitCode "lean"
    ["+leanprover/lean4:v4.32.0", sourcePath] ""
  writeFile (directory </> (mode ++ ".kernel.txt")) (output ++ errors)
  let inventories =
        [ inventory
        | line <- lines output
        , Right inventory <- [parseProviderSexp line]
        ]
      valid = case inventories of
        [providers] ->
          let names = map providerLeanName providers
          in all (`elem` names) ["Or.imp", "Or.by_cases", "Or.zzzzAfter"]
              && position "Or.by_cases" names < position "Or.zzzzAfter" names
        _ -> False
      clean = "'Or.zzzzAfter' does not depend on any axioms" `isInfixOf` output
        && not ("sorryAx" `isInfixOf` (output ++ errors))
      escaped = case mode of
        "recursion-exception" ->
          status /= ExitSuccess && null inventories
            && "maximum recursion depth" `isInfixOf` (output ++ errors)
        "interrupt" ->
          -- Lean's command driver handles interruption without an error
          -- diagnostic/exit failure. The interrupted discovery command must
          -- abort before its inventory message, rather than swallowing the
          -- interrupt and continuing to the later provider.
          status == ExitSuccess && null inventories && clean
        _ -> False
  if escaped
    then putStrLn $ "PASS " ++ mode ++ ": exceptional control flow escapes optional evidence discovery."
  else if mode `elem` ["actual", "ordinary-exception", "local-heartbeat"]
      && status == ExitSuccess && valid && clean
    then putStrLn $ "PASS " ++ mode ++ ": Or.by_cases and earlier/later providers survive; resolver quota survives Meta rollback."
    else do
      putStrLn (output ++ errors)
      putStrLn $ "FAIL: kernel=" ++ show status
        ++ ", inventory=" ++ show valid ++ ", axiom check=" ++ show clean
      exitFailure
 where
  position target = length . takeWhile (/= target)

  replace needle replacement text
    | needle `isPrefixOf` text = replacement ++ drop (length needle) text
  replace needle replacement (character : rest) =
    character : replace needle replacement rest
  replace _ _ [] = []

heartbeatWitness :: String
heartbeatWitness = unlines
  [ "namespace LeantSynth"
  , "open Lean Meta"
  , "partial def exhaustAssignmentBudget : MetaM (Array (Array ProviderCandidateFragment)) := do"
  , "  Core.checkSystem \"injected expensive assignment\""
  , "  let _ ← mkFreshExprMVar (mkSort .zero)"
  , "  exhaustAssignmentBudget"
  , "end LeantSynth"
  ]

rollbackWitness :: String
rollbackWitness = unlines
  [ "open Lean Meta Elab Command in run_cmd do"
  , "  Lean.Elab.Command.liftTermElabM do"
  , "    let remaining ← IO.mkRef (1 : Nat)"
  , "    Lean.withoutModifyingState do"
  , "      unless ← LeantSynth.takeProviderResolutionAttempt remaining do"
  , "        throwError \"first resolution attempt was rejected\""
  , "    if ← LeantSynth.takeProviderResolutionAttempt remaining then"
  , "      throwError \"Meta rollback replenished the resolution quota\""
  ]
