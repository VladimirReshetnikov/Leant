-- Root-owned compilation/execution only. This program performs bounded search
-- and source-graph checking; the Python owner independently executes behavior.
module Main (main) where

import Control.Monad (unless)
import Data.Char (ord)
import Data.List (intercalate, nub)
import Language.Haskell.Djex hiding (Backend (..), backend, backendName)
import Language.Haskell.Djex.Exference.HaskellSrc (parseExferenceRequest)
import qualified Language.Haskell.Synthesis.TypedGenerated.Haskell as TypedHaskell
import Numeric (showHex)
import System.Directory (createDirectoryIfMissing, doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO (IOMode (WriteMode), hPutStr, hSetEncoding, utf8, withFile)

signature :: String
signature = "forall a s. (s -> a -> s) -> s -> Tree a -> s"

data Row = Row Int String Bool String String (Maybe String)

expectRight :: Show failure => Either failure value -> IO value
expectRight = either (fail . show) pure

declarations :: IO [Declaration String kindVariable ()]
declarations = do
  tree <- expectRight $ mkIdentifier "Tree"
  leaf <- expectRight $ mkIdentifier "Leaf"
  branch <- expectRight $ mkIdentifier "Branch"
  foldName <- expectRight $ mkIdentifier "foldTree"
  let a = TypeVariable "a"
      r = TypeVariable "r"
      treeOf ty = TypeApplication (TypeConstructor tree) ty
      foldType = ForallType ["a", "r"] [] $
        FunctionType (FunctionType a r) $
          FunctionType (FunctionType r $ FunctionType r r) $
            FunctionType (treeOf a) r
  pure
    [ DataTypeDeclaration () tree [TypeParameter "a" Nothing]
        [DataConstructor () leaf [a], DataConstructor () branch [treeOf a, treeOf a]]
    , ValueDeclaration $ ValueSignature () foldName foldType
    ]

-- These are the only declaration-bound identities. Never collapse a future
-- unrecognized variable onto the fold carrier, as a catch-all mapper would.
exferenceVariable :: String -> ExferenceTypeVariable
exferenceVariable "a" = FlexibleVariable 0
exferenceVariable "r" = FlexibleVariable 1
exferenceVariable other = error $ "unregistered declaration type variable: " ++ other

checkRow
  :: (Ord identity, Show identity, Ord local, Show local, Show failure)
  => [Name]
  -> Name
  -> Type (Variable identity)
  -> (local -> String)
  -> Int
  -> Bool
  -> FunctionClause local
  -> Either failure (TermGraph (Type (Variable identity)) local)
  -> Row
checkRow allowed foldName expected renderLocal ordinal residualsEmpty clause graphResult =
  case graphResult of
    Left failure -> Row ordinal "" False (show clause) "" $ Just $ "graph unavailable: " ++ show failure
    Right graph ->
      let erased = eraseTermGraph graph
          globals = nub $ expressionGlobals erased
          usesFold = foldName `elem` globals
          failed message = Row ordinal "" usesFold (show clause) (show graph) $ Just message
      in if not residualsEmpty then failed "candidate retains residual constraints"
         else if eraseTermGraphToFunctionClause (clauseName clause) graph /= clause
           then failed "graph erasure differs from this exact compatibility clause"
         else if not $ null $ expressionHoles erased
           then failed "graph contains an unresolved hole"
         else if any (`notElem` allowed) globals
           then failed $ "graph acquired an undeclared global: " ++ show globals
         else case lookupTermNode (termGraphRoot graph) graph of
           Nothing -> failed "graph root is missing"
           Just root | not $ alphaEquivalentTypes expected $ termNodeType root ->
             failed "graph root differs from the full retained source request"
           Just _ -> case TypedHaskell.renderHaskellTermGraph (defaultRenderOptions renderLocal) graph of
             Left failure -> failed $ "typed renderer refused: " ++ show failure
             Right term -> Row ordinal term usesFold (show clause) (show graph) Nothing

main :: IO ()
main = do
  arguments <- getArgs
  case arguments of
    [engine, output] | engine `elem` ["djinn", "exference"] -> do
      exists <- doesFileExist $ output </> "candidates.json"
      unless (not exists) $ fail "refusing to overwrite an earlier candidate receipt"
      createDirectoryIfMissing True output
      source <- declarations
      foldName <- expectRight $ mkIdentifier "foldTree"
      allowed <- mapM (expectRight . mkIdentifier) ["foldTree", "Leaf", "Branch"]
      target <- expectRight $ mkIdentifier $ "tree_accumulator_" ++ engine
      (inventory, description, rows) <- if engine == "djinn" then do
        environment <- expectRight (mkEnvironment source :: Either
          (EnvironmentError DjinnTypeVariable) DjinnEnvironment)
        session <- expectRight $ mkDjinnSession environment
        let actual = environmentDeclarations $ djinnSessionEnvironment session
        unless (length actual == 2 && [valueName value | ValueDeclaration value <- actual] == [foldName]) $
          fail "prepared Djinn inventory differs from Tree plus foldTree"
        request <- expectRight $ parseDjinnRequest session
          defaultQueryOptions
            { optionCutoff = 1024, optionAlternatives = True, optionSorted = False
            , optionStrategy = Interleave, optionBudget = Just 100000
            }
          target "tree-accumulator-probe" signature
        result <- expectRight $ runDjinnTypedQuery session request
        let expected = fmap FlexibleVariable $ requestContextualType $ djinnRequestQuery request
            candidates = take 1024 $ batchCandidates $ resultSearch result
            checked = zipWith (\ordinal candidate ->
              let compatibility = typedCandidateCompatibility candidate
              in checkRow allowed foldName expected id ordinal
                   (null $ candidateResidualConstraints compatibility)
                   (candidateOutput compatibility) (typedCandidateTermGraph candidate))
                [0 ..] candidates
        pure (map show actual, show (resultEvidence result, batchProgress $ resultSearch result), checked)
      else do
        environment <- expectRight (mkEnvironment
          (map (mapDeclarationTypeVariables exferenceVariable) source) :: Either
          (EnvironmentError ExferenceTypeVariable) ExferenceEnvironment)
        session <- expectRight $ mkExferenceSession environment
        let actual = environmentDeclarations $ exferenceSessionEnvironment session
        unless (length actual == 2 && [valueName value | ValueDeclaration value <- actual] == [foldName]) $
          fail "prepared Exference inventory differs from Tree plus foldTree"
        request <- expectRight $ parseExferenceRequest session
          defaultExferenceOptions
            { exferenceMaximumSteps = 100000, exferenceMaximumQueueSize = Just 1024
            , exferenceAllowUnused = True, exferenceMultiConstructorPatterns = True
            }
          target "tree-accumulator-probe" signature
        results <- expectRight $ runExferenceTypedQuery session request
        let expected = requestContextualType $ exferenceRequestQuery request
            candidates = take 1024 $ concatMap (batchCandidates . resultSearch) results
            checked = zipWith (\ordinal candidate ->
              let compatibility = typedCandidateCompatibility candidate
              in checkRow allowed foldName expected (\local -> "v" ++ show local) ordinal
                   (null $ candidateResidualConstraints compatibility)
                   (candidateOutput compatibility) (typedCandidateTermGraph candidate))
                [0 ..] candidates
        -- Do not force unobserved result tails to manufacture a final status.
        pure (map show actual, "at most1024 raw candidates;100000 steps;queue1024;unobserved tail not forced", checked)
      let good (Row _ _ _ _ _ failure) = case failure of Nothing -> True; Just _ -> False
          passed = all good rows
          payload = object
            [ ("status", string $ if passed then "checked" else "failed")
            , ("engine", string engine), ("full_signature", string signature)
            , ("actual_inventory", array $ map string inventory)
            , ("settings", object [("raw_limit", "1024"), ("djinn_choice_budget", "100000")
                , ("exference_steps", "100000"), ("exference_queue", "1024")
                , ("allow_unused", "true"), ("djinn_strategy", string "interleave")])
            , ("search_description", string description), ("observed_count", show $ length rows)
            , ("behavior_evaluated", "false"), ("candidates", array $ map rowJSON rows)
            ]
      withFile (output </> "candidates.json") WriteMode $ \handle -> do
        hSetEncoding handle utf8
        hPutStr handle $ payload ++ "\n"
      putStrLn $ "TREE_ACCUMULATOR_CANDIDATES " ++ show (length rows)
      unless passed exitFailure
    _ -> fail "usage: TreeAccumulatorProbe djinn|exference OUTPUT-DIRECTORY"

rowJSON :: Row -> String
rowJSON (Row ordinal term usesFold compatibility graph failure) = object
  [ ("ordinal", show ordinal), ("term", string term), ("uses_fold", if usesFold then "true" else "false")
  , ("compatibility", string compatibility), ("graph", string graph)
  , ("failure", maybe "null" string failure)
  ]

object :: [(String, String)] -> String
object fields = "{" ++ intercalate "," [string name ++ ":" ++ value | (name, value) <- fields] ++ "}"

array :: [String] -> String
array values = "[" ++ intercalate "," values ++ "]"

string :: String -> String
string value = '"' : concatMap escape value ++ "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape character | ord character < 32 =
    let digits = showHex (ord character) "" in "\\u" ++ replicate (4 - length digits) '0' ++ digits
  escape character = [character]
