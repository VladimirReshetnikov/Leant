-- | Bounded kernel proof checks for an explicitly supplied host-language assertion.
-- These observations concern the exact named candidate and supplied proposition;
-- passing examples never creates a universal behavioral or Length certificate.
module Leant.Synth.Behavioral
  ( BehavioralVerdict (..)
  , BehavioralProofMethod (..)
  , behavioralSyntaxProgram
  , behavioralPreflightProgram
  , behavioralDecisionProgram
  , behavioralProofProgram
  , decideBehavioralBy
  , proveBehavioralBy
  ) where

import Language.Haskell.Synthesis.Behavioral (BehavioralQuery (..))

data BehavioralVerdict
  = BehavioralSatisfied
  | BehavioralFalsified
  | BehavioralInconclusive String
  deriving (Eq, Show)

-- Decision remains the first method for both polarities. Simplification may
-- prove propositions without an executable Decidable instance, but must close
-- the entire goal; progress or a changed proposition is not an observation.
data BehavioralProofMethod = BehavioralDecide | BehavioralSimp
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
behavioralDecisionProgram = behavioralProofProgram BehavioralDecide

behavioralProofProgram
  :: BehavioralProofMethod -> Bool -> BehavioralQuery -> String -> String
behavioralProofProgram method negatePredicate query term = options ++ unlines
  [ "example : " ++ (if negatePredicate then "¬ (" else "(")
  , "let " ++ behavioralName query ++ " : ("
  , behavioralType query
  , ") := ("
  , term
  , "); ("
  , behavioralPredicate query
  , ")) := " ++ proof
  ]
 where
  proof = case method of
    BehavioralDecide -> "by decide"
    BehavioralSimp -> "by\n  solve\n  | simp (config := { maxSteps := 10000 })"

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
decideBehavioralBy decide = proveWithMethods [BehavioralDecide]
  "Lean could decide neither the assertion nor its negation"
  (const decide)

-- | Try positive and negative decisions before either simplification attempt.
-- Each callback must check the same complete candidate at the requested type
-- under the same command deadline. Left aborts all remaining attempts; only a
-- checked proof of one polarity can classify a candidate as true or false.
proveBehavioralBy
  :: Monad m
  => (BehavioralProofMethod -> Bool -> m (Either String Bool))
  -> m BehavioralVerdict
proveBehavioralBy = proveWithMethods [BehavioralDecide, BehavioralSimp]
  "Lean could prove neither the assertion nor its negation by bounded decide or simp"

proveWithMethods
  :: Monad m
  => [BehavioralProofMethod]
  -> String
  -> (BehavioralProofMethod -> Bool -> m (Either String Bool))
  -> m BehavioralVerdict
proveWithMethods methods inconclusive prove = go
  [(method, negative) | method <- methods, negative <- [False, True]]
 where
  go [] = pure $ BehavioralInconclusive inconclusive
  go ((method, negative) : remaining) = do
    result <- prove method negative
    case result of
      Right True -> pure $ if negative then BehavioralFalsified else BehavioralSatisfied
      Right False -> go remaining
      Left failure -> pure $ BehavioralInconclusive failure
