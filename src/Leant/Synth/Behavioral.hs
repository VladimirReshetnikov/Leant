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
  , behavioralCombinedDecisionProgram
  , decodeBehavioralDecisionTags
  , decideBehavioralBy
  , proveBehavioralBy
  ) where

import Language.Haskell.Synthesis.Behavioral (BehavioralQuery (..))
import Data.Char (isSpace)
import Data.List (isPrefixOf)

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

-- | Check the full candidate and attempt both decision polarities in one
-- ephemeral example. A dependent pair retains the candidate as a value even
-- when the predicate ignores it, so erasure cannot hide candidate sorries.
-- Its second field contains a checked proof of p or its negation, or none
-- when neither attempt closes. A trace follows only the
-- successfully closed branch. The complete command must still pass the kernel:
-- an error or sorry can coexist with a trace and invalidates the observation.
-- This uses only core commands/tactics and introduces no user-visible name.
behavioralCombinedDecisionProgram :: BehavioralQuery -> String -> String
behavioralCombinedDecisionProgram query term = options ++ unlines
  [ "example : _root_.PSigma (fun " ++ behavioralName query ++ " : ("
  , behavioralType query
  , ") => _root_.Option (_root_.Decidable ("
  , behavioralPredicate query
  , "))) := by"
  , "  refine ⟨("
  , term
  , "  ), ?_⟩"
  , "  first"
  , "  | exact _root_.Option.some (_root_.Decidable.isTrue (by decide))"
  , "    trace \"LEANT_BEHAVIOR_DECISION:1\""
  , "  | exact _root_.Option.some (_root_.Decidable.isFalse (by decide))"
  , "    trace \"LEANT_BEHAVIOR_DECISION:2\""
  , "  | exact _root_.Option.none"
  , "    trace \"LEANT_BEHAVIOR_DECISION:0\""
  ]

-- | Decode only the protocol, not proof authority. The caller must first
-- validate the complete Lean response. Missing, malformed or duplicate tags
-- cannot classify a candidate, even if one of them looks like a success.
decodeBehavioralDecisionTags :: [String] -> Either String (Maybe Bool)
decodeBehavioralDecisionTags messages = case tags of
  ["LEANT_BEHAVIOR_DECISION:0"] -> Right Nothing
  ["LEANT_BEHAVIOR_DECISION:1"] -> Right (Just True)
  ["LEANT_BEHAVIOR_DECISION:2"] -> Right (Just False)
  _ -> Left "Lean did not return exactly one valid behavioral decision tag"
 where
  tags = filter ("LEANT_BEHAVIOR_DECISION:" `isPrefixOf`) $
    map (reverse . dropWhile isSpace . reverse . dropWhile isSpace) messages

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
