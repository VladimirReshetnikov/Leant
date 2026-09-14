-- | Declaration-local universe templates and their source-selected instances.
-- A declaration parameter never becomes a caller universe by matching its name.
module Leant.Synth.ContextUniverse
  ( ContextUniverseSignature (..), ContextUniverseSelection
  , selectContextUniverses, selectionSignature, selectionLevels
  , selectionArgumentSorts, selectionResultSort, selectionIdentity, universeIdentity
  , normalizeUniverse, typeUniverse, universeParameters
  ) where

import Control.Monad (unless)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Language.Haskell.Synthesis.Collection (observedListLength)
import Leant.Synth.ContextRender (LeanName, LeanLevel (..), mkLeanName)

data ContextUniverseSignature = ContextUniverseSignature
  { signatureParameters :: [LeanName]
  , signatureArgumentSorts :: [LeanLevel]
  , signatureResultSort :: LeanLevel
  } deriving (Eq, Show)

-- The constructor is private: all retained levels and the declaration template
-- are normalized, the template is closed, and selection arity has been checked.
data ContextUniverseSelection = ContextUniverseSelection
  { selectionSignature :: ContextUniverseSignature
  , selectionLevels :: [LeanLevel]
  , selectionArgumentSorts :: [LeanLevel]
  , selectionResultSort :: LeanLevel
  } deriving (Eq, Show)

selectContextUniverses
  :: ContextUniverseSignature -> [LeanLevel] -> Either String ContextUniverseSelection
selectContextUniverses signature chosen = do
  let parameters = signatureParameters signature
      arguments = signatureArgumentSorts signature
      result = signatureResultSort signature
  unless (observedListLength 64 parameters <= 64) $
    Left "context-source: declaration universe parameter limit exceeded"
  unless (observedListLength 64 arguments <= 64 && observedListLength 64 chosen <= 64) $
    Left "context-source: declaration universe signature limit exceeded"
  unless (length parameters == Set.size (Set.fromList parameters)) $
    Left "context-source: duplicate declaration universe parameter"
  unless (length parameters == length chosen) $
    Left "context-source: selected universe vector has the wrong arity"
  normalizedArguments <- traverse normalizeUniverse arguments
  normalizedResult <- normalizeUniverse result
  unless (Set.unions (map universeParameters (normalizedResult : normalizedArguments))
      `Set.isSubsetOf` Set.fromList parameters) $
    Left "context-source: declaration universe template has a free parameter"
  levels <- traverse normalizeUniverse chosen
  canonicalNames <- traverse (either (Left . show) Right . mkLeanName . pure . ("declUniverse" ++) . show)
    [0 .. length parameters - 1]
  let instantiate replacements = normalizeUniverse . replace replacements
      actual = Map.fromList $ zip parameters levels
      canonical = Map.fromList $ zip parameters $ map LeanLevelParameter canonicalNames
  argumentSorts <- traverse (instantiate actual) normalizedArguments
  resultSort <- instantiate actual normalizedResult
  canonicalArguments <- traverse (instantiate canonical) normalizedArguments
  canonicalResult <- instantiate canonical normalizedResult
  pure $ ContextUniverseSelection
    (ContextUniverseSignature canonicalNames canonicalArguments canonicalResult)
    levels argumentSorts resultSort
 where
  replace replacements level = case level of
    LeanLevelZero -> LeanLevelZero
    LeanLevelParameter name -> Map.findWithDefault level name replacements
    LeanLevelSuccessor value -> LeanLevelSuccessor $ replace replacements value
    LeanLevelMax left right -> LeanLevelMax (replace replacements left) (replace replacements right)

-- Zero-only selections retain the historical translation key. Other selections
-- use their complete structured vector, without hashes or lossy printed levels.
selectionIdentity :: String -> ContextUniverseSelection -> String
selectionIdentity name = universeIdentity name . selectionLevels

universeIdentity :: String -> [LeanLevel] -> String
universeIdentity name levels
  | all (== LeanLevelZero) levels = name
  | otherwise = name ++ "$universes$" ++ show levels

universeParameters :: LeanLevel -> Set.Set LeanName
universeParameters level = case level of
  LeanLevelZero -> Set.empty
  LeanLevelParameter name -> Set.singleton name
  LeanLevelSuccessor value -> universeParameters value
  LeanLevelMax left right -> Set.union (universeParameters left) (universeParameters right)

-- Canonical max-of-offsets form for the represented level language.
normalizeUniverse :: LeanLevel -> Either String LeanLevel
normalizeUniverse level = rebuild <$> collect (128 :: Int) level
 where
  collect fuel _ | fuel <= 0 = Left "context-source: universe exceeds nesting limit"
  collect _ LeanLevelZero = Right $ Map.singleton Nothing (0 :: Int)
  collect _ (LeanLevelParameter name) = Right $ Map.singleton (Just name) 0
  collect fuel (LeanLevelSuccessor value) = Map.map (+ 1) <$> collect (fuel - 1) value
  collect fuel (LeanLevelMax left right) = Map.unionWith max
    <$> collect (fuel - 1) left <*> collect (fuel - 1) right
  rebuild offsets = foldr1 LeanLevelMax
    [ iterate LeanLevelSuccessor (maybe LeanLevelZero LeanLevelParameter name) !! offset
    | (name, offset) <- Map.toAscList reduced
    ]
   where
    reduced = case Map.lookup Nothing offsets of
      Just constant | any (>= constant) (Map.elems $ Map.delete Nothing offsets) -> Map.delete Nothing offsets
      _ -> offsets

-- Type binders have a known successor sort. General Sort/Prop binders retain
-- their independent admission restriction until their Pi-sort account exists.
typeUniverse :: LeanLevel -> Either String LeanLevel
typeUniverse level = normalizeUniverse level >>= predecessor
 where
  predecessor (LeanLevelSuccessor value) = Right value
  predecessor (LeanLevelMax left right) = do
    a <- predecessor left
    b <- predecessor right
    normalizeUniverse $ LeanLevelMax a b
  predecessor _ = Left "context-source: contextual type binder requires a Type universe"
