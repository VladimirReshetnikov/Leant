-- Emit and check the actual production discovery programs with a real kernel.
module Main (main) where

import qualified Data.ByteString as Bytes
import Data.List (sort)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Leant.Synth.Fragment
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["emit", mode, selection] -> do
      generator <- case mode of
        "ordinary" -> pure providerProgramWith
        "contextual" -> pure contextualProviderProgramWith
        _ -> fail "expected ordinary or contextual"
      (sessions, roots) <- case selection of
        "roots" -> pure ([], ["InventoryProbe"])
        "sessions" -> pure (expectedNames ++ auxiliaryNames, [])
        _ -> fail "expected roots or sessions"
      let query = ProviderQuery roots (Just "InventoryProbe.Tree")
      emit $ "import Lean\n" ++ synthPrelude [] ++ fixture
        ++ generator 80 sessions query
    ["check", path] -> do
      source <- Text.unpack . Encoding.decodeUtf8 <$> Bytes.readFile path
      providers <- either fail pure $ parseProviderSexp source
      let names = sort $ map providerLeanName providers
      if names == sort expectedNames
        then emit "PASS: exactly the fold, constructors and user elim remain\n"
        else fail $ "unexpected production inventory: " ++ show names
    _ -> fail "expected emit MODE roots|sessions or check INVENTORY"

emit :: String -> IO ()
emit = Bytes.putStr . Encoding.encodeUtf8 . Text.pack

expectedNames :: [String]
expectedNames =
  [ "InventoryProbe.foldTree", "InventoryProbe.Tree.leaf"
  , "InventoryProbe.Tree.branch", "InventoryProbe.elim"
  ]

auxiliaryNames :: [String]
auxiliaryNames =
  [ "InventoryProbe.Tree.leaf.elim", "InventoryProbe.Tree.branch.elim" ]

fixture :: String
fixture = unlines
  [ "namespace InventoryProbe"
  , "set_option genSizeOf false in"
  , "inductive Tree (a : Type) where"
  , "  | leaf : a → Tree a"
  , "  | branch : Tree a → Tree a → Tree a"
  , "def foldTree {a r : Type} (leaf : a → r) (branch : r → r → r) : Tree a → r"
  , "  | .leaf x => leaf x"
  , "  | .branch l r => branch (foldTree leaf branch l) (foldTree leaf branch r)"
  , "def elim {a : Type} (tree : Tree a) : Tree a := tree"
  , "end InventoryProbe"
  , "open Lean Elab Command in"
  , "run_cmd do"
  , "  let env ← getEnv"
  , "  for n in [``InventoryProbe.Tree.leaf.elim, ``InventoryProbe.Tree.branch.elim] do"
  , "    unless env.contains n && Lean.isAuxRecursor env n do"
  , "      throwError \"expected generated auxiliary recursor: {n}\""
  , "  unless env.contains ``InventoryProbe.elim && !Lean.isAuxRecursor env ``InventoryProbe.elim do"
  , "    throwError \"ordinary user elim lost its independent identity\""
  ]
