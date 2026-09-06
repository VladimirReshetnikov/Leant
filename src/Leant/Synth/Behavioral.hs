-- | Kernel decision checks for an explicitly supplied host-language assertion.
-- These observations concern the exact named candidate and supplied proposition;
-- passing examples never creates a universal behavioral or Length certificate.
module Leant.Synth.Behavioral
  ( BehavioralVerdict (..)
  , behavioralSyntaxProgram
  , behavioralPreflightProgram
  , behavioralDecisionProgram
  , decideBehavioralBy
  ) where

import Language.Haskell.Synthesis.Behavioral (BehavioralQuery (..))

data BehavioralVerdict
  = BehavioralSatisfied
  | BehavioralFalsified
  | BehavioralInconclusive String
  deriving (Eq, Show)

-- Parse both complete host terms before embedding them in a checked command.
-- In particular, a trailing command cannot escape the generated example.
behavioralSyntaxProgram :: BehavioralQuery -> String
behavioralSyntaxProgram query = unlines
  [ "open Lean Elab Command in"
  , "run_cmd do"
  , "  for source in [" ++ stringLiteral (behavioralType query) ++ ", "
      ++ stringLiteral (behavioralPredicate query) ++ "] do"
  , "    match Parser.runParserCategory (← getEnv) `term source with"
  , "    | .ok _ => pure ()"
  , "    | .error error => throwError error"
  ]

behavioralPreflightProgram :: BehavioralQuery -> String
behavioralPreflightProgram query = options ++ unlines
  [ "noncomputable example : ("
  , behavioralType query
  , ") → Prop := fun " ++ behavioralName query ++ " => ("
  , behavioralPredicate query
  , ")"
  ]

-- The predicate's binder is lexical, so it shadows a session declaration of
-- the same name without introducing or updating any interactive declaration.
behavioralDecisionProgram :: Bool -> BehavioralQuery -> String -> String
behavioralDecisionProgram negatePredicate query term = options ++ unlines
  [ "example : " ++ (if negatePredicate then "¬ (" else "(")
  , "let " ++ behavioralName query ++ " : ("
  , behavioralType query
  , ") := ("
  , term
  , "); ("
  , behavioralPredicate query
  , ")) := by decide"
  ]

options :: String
options = unlines
  [ "set_option autoImplicit false in"
  , "set_option maxHeartbeats 200000 in"
  ]

stringLiteral :: String -> String
stringLiteral source = '"' : concatMap escape source ++ "\""
 where
  escape '"' = "\\\""
  escape '\\' = "\\\\"
  escape '\n' = "\\n"
  escape '\r' = "\\r"
  escape '\t' = "\\t"
  escape c = [c]

-- | A failed positive decision is not a counterexample. Only a checked
-- decision of the negation establishes falsity. Transport failures abort
-- this attempt rather than consulting a potentially retired backend.
decideBehavioralBy
  :: Monad m
  => (Bool -> m (Either String Bool))
  -> m BehavioralVerdict
decideBehavioralBy decide = do
  positive <- decide False
  case positive of
    Right True -> pure BehavioralSatisfied
    Left failure -> pure $ BehavioralInconclusive failure
    Right False -> do
      negative <- decide True
      pure $ case negative of
        Right True -> BehavioralFalsified
        Right False -> BehavioralInconclusive
          "Lean could decide neither the assertion nor its negation"
        Left failure -> BehavioralInconclusive failure
