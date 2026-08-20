-- | Leant profiles for the bounded Djex Length @where@ syntax.
--
-- This module deliberately separates three decisions.  The command parser
-- admits one explicit model and a complete, source-ordered set of observed
-- physical arguments.  Only after command-local policy authorization does
-- 'parseLeanLengthWhereSource' enter the bounded Djex parser.  Finally, after
-- Lean translation supplies the physical arrow arity,
-- 'resolveLeanLengthWhereSource' builds the complete role vector and expands
-- the fixed Leant profile.  No step infers authority from the clause or the
-- translated target.
module Leant.Synth.Length.Where
  ( LeanLengthWhereModel (..)
  , LeanLengthWhereInputSource
  , LeanLengthWhereInputSourceError (..)
  , LeanLengthWherePlan
  , LeanLengthWhereSource
  , LeanLengthWhereSourceError (..)
  , parseLeanLengthWhereInputSource
  , mkLeanLengthWherePlan
  , parseLeanLengthWhereSource
  , resolveLeanLengthWhereSource
  ) where

import Control.Monad (when)
import Data.Char (isDigit, ord)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Language.Haskell.Djex
  ( LengthTargetArgumentRole (..)
  , LengthWhereContractSource (..)
  , LengthWhereDomain (..)
  , LengthWhereElaborationError
  , LengthWhereParseError
  , defaultLengthLimits
  , elaborateLengthWhereSource
  , lengthContractInputLimit
  , parseLengthWhereSource
  )
import qualified Language.Haskell.Djex as Djex
import Numeric.Natural (Natural)

import Leant.Synth.Length.Contract
  ( LeanLengthCandidateCasePolicy (LeanLengthExactSpineZeroStepV1)
  , LeanLengthContract (..)
  , LeanLengthContractSelection (..)
  , LeanLengthSpineIdentity (..)
  , LeanLengthSpinePairContract (..)
  )

-- | The two fixed, explicit semantic profiles admitted by the first inline
-- surface.  The spelling is selected by the command parser; it is never
-- inferred from a result reference or a Lean type.
data LeanLengthWhereModel
  = LeanListScalarExactCases
  | LeanListBinaryProductExactCases
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | A nonempty, strictly increasing list of physical source-arrow indices.
-- The constructor stays private so complement roles can be generated without
-- revalidating caller input.
newtype LeanLengthWhereInputSource = LeanLengthWhereInputSource [Natural]

-- | Closed lexical refusals for the @--length-inputs@ token.  The taxonomy
-- retains no source spelling.
data LeanLengthWhereInputSourceError
  = LeanLengthWhereInputMalformed
  | LeanLengthWhereInputsNotStrictlyIncreasing
  | LeanLengthWhereInputLimitExceeded !Natural !Natural
  deriving (Eq, Ord, Show)

-- | A command-owned but still unparsed clause.  Its constructor and raw text
-- are private; in particular, no diagnostic 'Show' instance can echo it.
data LeanLengthWherePlan = LeanLengthWherePlan
  !LeanLengthWhereModel
  !LeanLengthWhereInputSource
  String

-- | A bounded Djex source associated with the same explicit model and input
-- declaration.  It is passive contract source and carries no solver or policy
-- authority; Main later activates the resolved selection inside one authorized
-- command-local assessment context.
data LeanLengthWhereSource = LeanLengthWhereSource
  !LeanLengthWhereModel
  !LeanLengthWhereInputSource
  Djex.LengthWhereSource

-- | Sanitized refusal across the post-authorization parse and
-- post-translation resolution boundaries.
data LeanLengthWhereSourceError
  = LeanLengthWhereParseRejected !LengthWhereParseError
  | LeanLengthWherePhysicalArrowLimitExceeded !Natural !Natural
  | LeanLengthWhereInputOutOfRange !Natural !Natural
  | LeanLengthWhereElaborationRejected !LengthWhereElaborationError
  deriving (Eq, Ord, Show)

-- | Parse the complete observed-input token.  Decimal indices are accumulated
-- only up to the first unavailable value, so a hostile digit run cannot build
-- an unbounded 'Natural'.  Leading zeroes have their ordinary numeric meaning;
-- the strict-order check therefore still rejects aliases such as
-- @arg0,arg00@.
parseLeanLengthWhereInputSource
  :: String
  -> Either LeanLengthWhereInputSourceError LeanLengthWhereInputSource
parseLeanLengthWhereInputSource source = do
  pieces <- nonemptyPieces source
  indices <- traverse parsePiece pieces
  if strictlyIncreasing indices
    then Right $ LeanLengthWhereInputSource indices
    else Left LeanLengthWhereInputsNotStrictlyIncreasing
 where
  maximumCount = lengthContractInputLimit defaultLengthLimits
  maximumIndex = fromIntegral $ maximumCount - 1
  firstUnavailable = fromIntegral maximumCount

  parsePiece piece = case stripArg piece of
    Just digits@(_ : _)
      | all decimalDigit digits ->
          case boundedDecimal firstUnavailable digits of
            Left observed -> Left $ LeanLengthWhereInputLimitExceeded
              maximumIndex observed
            Right value -> Right value
    _ -> Left LeanLengthWhereInputMalformed

  stripArg ('a' : 'r' : 'g' : rest) = Just rest
  stripArg _ = Nothing

-- | Associate the already validated command choices with the exact clause
-- slice.  No Djex syntax is inspected at this point.
mkLeanLengthWherePlan
  :: LeanLengthWhereModel
  -> LeanLengthWhereInputSource
  -> String
  -> LeanLengthWherePlan
mkLeanLengthWherePlan = LeanLengthWherePlan

-- | Enter the bounded Djex parser after the caller has authorized the inline
-- request.  Haskeline has already decoded terminal input to 'String'; this is
-- the single UTF-8 encoding boundary used for exact Djex byte offsets.
parseLeanLengthWhereSource
  :: LeanLengthWherePlan
  -> Either LeanLengthWhereSourceError LeanLengthWhereSource
parseLeanLengthWhereSource (LeanLengthWherePlan model inputs clause) =
  case parseLengthWhereSource defaultLengthLimits
      $ TextEncoding.encodeUtf8 $ Text.pack clause of
    Left failure -> Left $ LeanLengthWhereParseRejected failure
    Right source -> Right $ LeanLengthWhereSource model inputs source

-- | Resolve one parsed source against the authoritative number of physical
-- arrow slots from Lean translation.  The target supplies only that arity: the
-- model, observed roles, spine names, candidate-case policy, and provider-law
-- set all remain the explicit fixed profile selected before translation.
resolveLeanLengthWhereSource
  :: Natural
  -> LeanLengthWhereSource
  -> Either LeanLengthWhereSourceError LeanLengthContractSelection
resolveLeanLengthWhereSource arity
    (LeanLengthWhereSource model
      (LeanLengthWhereInputSource observedInputs) source) = do
  let maximumArity = fromIntegral
        $ lengthContractInputLimit defaultLengthLimits
  when (arity > maximumArity)
    $ Left $ LeanLengthWherePhysicalArrowLimitExceeded
        maximumArity arity
  case [index | index <- observedInputs, index >= arity] of
    index : _ -> Left $ LeanLengthWhereInputOutOfRange index arity
    [] -> pure ()
  let roles = map roleAt $ naturalPrefix arity
      domain = case model of
        LeanListScalarExactCases -> LengthWhereScalar
        LeanListBinaryProductExactCases -> LengthWhereBinaryProduct
  elaborated <- case elaborateLengthWhereSource domain roles source of
    Left failure -> Left $ LeanLengthWhereElaborationRejected failure
    Right value -> Right value
  pure $ expandProfile elaborated
 where
  roleAt index
    | index `elem` observedInputs = LengthObservedSpine
    | otherwise = LengthUnobservedTarget

-- | Expand only the two explicit built-in profiles.  Existing Handoff code
-- later checks these exact names against translation provenance.
expandProfile :: LengthWhereContractSource -> LeanLengthContractSelection
expandProfile source = case source of
  LengthWhereScalarContractSource roles contract ->
    LeanLengthScalarContractSelection LeanLengthContract
      { leanLengthContractSpine = listSpine
      , leanLengthContractTargetArgumentRoles = roles
      , leanLengthContractCandidateCasePolicy =
          LeanLengthExactSpineZeroStepV1
      , leanLengthContractSource = contract
      , leanLengthContractProviderLaws = []
      }
  LengthWhereBinaryProductContractSource roles contract ->
    LeanLengthSpinePairContractSelection LeanLengthSpinePairContract
      { leanLengthSpinePairContractSpine = listSpine
      , leanLengthSpinePairContractTargetArgumentRoles = roles
      , leanLengthSpinePairContractCandidateCasePolicy =
          LeanLengthExactSpineZeroStepV1
      , leanLengthSpinePairContractSource = contract
      , leanLengthSpinePairContractProviderLaws = []
      }

listSpine :: LeanLengthSpineIdentity
listSpine = LeanLengthSpineIdentity
  { leanLengthSpineFamilyName = "List"
  , leanLengthSpineZeroConstructorName = "List.nil"
  , leanLengthSpineStepConstructorName = "List.cons"
  }

nonemptyPieces
  :: String
  -> Either LeanLengthWhereInputSourceError [String]
nonemptyPieces [] = Left LeanLengthWhereInputMalformed
nonemptyPieces source = go [] [] source
 where
  go _ _ [] | null source = Left LeanLengthWhereInputMalformed
  go reversedPieces reversedPiece []
    | null reversedPiece = Left LeanLengthWhereInputMalformed
    | otherwise = Right
        $ reverse (reverse reversedPiece : reversedPieces)
  go reversedPieces reversedPiece (',' : rest)
    | null reversedPiece = Left LeanLengthWhereInputMalformed
    | otherwise = go (reverse reversedPiece : reversedPieces) [] rest
  go reversedPieces reversedPiece (character : rest) =
    go reversedPieces (character : reversedPiece) rest

decimalDigit :: Char -> Bool
decimalDigit character = isDigit character

boundedDecimal :: Natural -> String -> Either Natural Natural
boundedDecimal firstUnavailable = go 0
 where
  go value [] = Right value
  go value (character : rest) =
    let digit = fromIntegral $ ord character - ord '0'
        (maximumPrefix, maximumDigit) = firstUnavailable `quotRem` 10
        next
          | value >= firstUnavailable = firstUnavailable
          | value > maximumPrefix = firstUnavailable
          | value == maximumPrefix && digit >= maximumDigit =
              firstUnavailable
          | otherwise = value * 10 + digit
    in if next >= firstUnavailable
      then Left firstUnavailable
      else go next rest

strictlyIncreasing :: Ord value => [value] -> Bool
strictlyIncreasing values = case values of
  [] -> False
  first : rest -> go first rest
 where
  go _ [] = True
  go previous (current : remaining) =
    previous < current && go current remaining

naturalPrefix :: Natural -> [Natural]
naturalPrefix count = go 0
 where
  go index
    | index >= count = []
    | otherwise = index : go (index + 1)
