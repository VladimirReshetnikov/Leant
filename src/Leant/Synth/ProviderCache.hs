-- | A small semantic cache for Lean provider inventories.
--
-- Provider discovery depends on the target's nominal roots and final result
-- head, together with the current provider world.  It does not depend on
-- binder spellings or the raw goal text.  Keeping that contract in a pure
-- module makes cache sharing, invalidation, and eviction independently
-- testable.
module Leant.Synth.ProviderCache
  ( ProviderQuery (..)
  , ProviderWorld
  , ProviderCache
  , canonicalProviderQuery
  , initialProviderWorld
  , advanceProviderWorld
  , emptyProviderCache
  , clearProviderCache
  , lookupProviderCache
  , insertProviderCache
  , providerCacheSize
  , historyEntryAffectsProviders
  ) where

import Data.Char (isDigit, isSpace)
import Data.List (isPrefixOf, nub, sort, stripPrefix)

-- | The complete goal-dependent input to provider discovery.  Roots and the
-- result head use Lean's fully qualified @Name.toString@ spelling.
data ProviderQuery = ProviderQuery
  { providerQueryRoots :: [String]
  , providerQueryResultHead :: Maybe String
  }
  deriving (Eq, Ord, Show)

-- | Normalize a serializer observation into one stable cache key.  Lean's
-- used-constant traversal can repeat roots and does not promise an order.
canonicalProviderQuery :: [String] -> Maybe String -> ProviderQuery
canonicalProviderQuery roots resultHead = ProviderQuery
  { providerQueryRoots = sort
      (nub (filter (not . generatedResultName) (nonempty (map trim roots))))
  , providerQueryResultHead = resultHead >>= present . trim
  }
 where
  nonempty = filter (not . null)
  present "" = Nothing
  present value
    | generatedResultName value = Nothing
    | otherwise = Just value

-- Lean's pretty-printer removes the guillemets from a generated @«it!N»@
-- identifier.  Only a complete top-level generated spelling is discarded;
-- a normal namespace root or a name such as @Foo.it!1@ remains semantic.
generatedResultName :: String -> Bool
generatedResultName name = case stripPrefix "it!" name of
  Just digits -> not (null digits) && all isDigit digits
  Nothing -> False

-- | Monotonic identity of the declarations and imports eligible to become
-- providers.  'Integer' avoids a wraparound policy in a long-lived REPL.
newtype ProviderWorld = ProviderWorld Integer
  deriving (Eq, Ord, Show)

initialProviderWorld :: ProviderWorld
initialProviderWorld = ProviderWorld 0

advanceProviderWorld :: ProviderWorld -> ProviderWorld
advanceProviderWorld (ProviderWorld generation) =
  ProviderWorld (generation + 1)

data ProviderKey = ProviderKey ProviderWorld ProviderQuery
  deriving (Eq)

-- | Most-recently used entry first.  The value is intentionally polymorphic;
-- Main stores parsed provider inventories while tests can use small markers.
data ProviderCache value = ProviderCache Int [(ProviderKey, value)]

emptyProviderCache :: Int -> ProviderCache value
emptyProviderCache capacity = ProviderCache (max 0 capacity) []

clearProviderCache :: ProviderCache value -> ProviderCache value
clearProviderCache (ProviderCache capacity _) = ProviderCache capacity []

providerCacheSize :: ProviderCache value -> Int
providerCacheSize (ProviderCache _ entries) = length entries

-- | Lookup and refresh one entry's recency in the same operation.
lookupProviderCache
  :: ProviderWorld
  -> ProviderQuery
  -> ProviderCache value
  -> (Maybe value, ProviderCache value)
lookupProviderCache world query cache@(ProviderCache capacity entries) =
  case break ((== key) . fst) entries of
    (_, []) -> (Nothing, cache)
    (before, hit : after) ->
      (Just (snd hit), ProviderCache capacity (hit : before ++ after))
 where
  key = ProviderKey world query

-- | Insert or replace one entry and evict the least-recently used suffix.
insertProviderCache
  :: ProviderWorld
  -> ProviderQuery
  -> value
  -> ProviderCache value
  -> ProviderCache value
insertProviderCache world query value (ProviderCache capacity entries)
  | capacity == 0 = ProviderCache capacity []
  | otherwise = ProviderCache capacity
      (take capacity ((key, value) : filter ((/= key) . fst) entries))
 where
  key = ProviderKey world query

-- | Generated GHCi-style result declarations are deliberately absent from
-- provider discovery.  Appending one therefore does not change the provider
-- world and should not flush a useful inventory.  Every other successful
-- history entry is conservatively treated as provider-affecting.
historyEntryAffectsProviders :: String -> Bool
historyEntryAffectsProviders entry = not
  (any (`isPrefixOf` trim entry) generatedResultPrefixes)
 where
  generatedResultPrefixes =
    [ "def \171it!"
    , "set_option autoImplicit true in def \171it!"
    , "set_option autoImplicit true in noncomputable def \171it!"
    ]

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
 where
  dropWhileEnd predicate = reverse . dropWhile predicate . reverse
