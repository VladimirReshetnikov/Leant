-- Generate controls through the production command builder, so these exercise
-- its exact lexical embedding and proof protocol in an Init-only environment.
module Main (main) where

import Control.Monad (forM_)
import Language.Haskell.Synthesis.Behavioral (BehavioralQuery (..))
import Leant.Synth.Behavioral (behavioralCombinedDecisionProgram)
import System.Environment (getArgs)
import System.FilePath ((</>))
import System.IO (IOMode (WriteMode), hPutStr, hSetEncoding, utf8, withFile)

main :: IO ()
main = do
  [output] <- getArgs
  let ty = "∀ α : Type, α → α"
      identity = "fun _ x => x"
      query predicate = BehavioralQuery "f" ty predicate
      cases =
        [ ("positive", "", query "f Nat 11 = 11", identity)
        , ("negative", "", query "False", identity)
        , ("undecided", "", query "∀ p : Prop, p", identity)
        , ("illtyped", "", query "True", "true")
        , ("sorry", "", query "True", "by sorry")
        , ("duplicate", "", query "False",
            "by\n  trace \"LEANT_BEHAVIOR_DECISION:1\"\n  exact fun _ x => x")
        , ("comments", "", BehavioralQuery "f" (ty ++ " -- type")
            "f Nat 11 = 11 -- assertion", identity ++ " -- candidate")
        , ("lexical", "def f : " ++ ty ++ " := " ++ identity ++ "\n",
            query "f Nat 11 = 11", "f")
        , ("namespace", "namespace UserNamespace\n",
            query "f Nat 11 = 11", identity)
        , ("collision", "def leantBehaviorCertificate : Nat := 37\n",
            query "f Nat 11 = 11", identity)
        ]
  forM_ cases $ \(name, prelude, specification, term) ->
    withFile (output </> name ++ ".lean") WriteMode $ \handle -> do
      hSetEncoding handle utf8
      hPutStr handle $ prelude ++ behavioralCombinedDecisionProgram specification term
        ++ if name == "namespace" then "end UserNamespace\n" else ""
