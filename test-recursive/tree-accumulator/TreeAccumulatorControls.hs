{-# LANGUAGE RankNTypes #-}
module TreeAccumulatorControls where
import TreeAccumulatorProviders (Tree(..), foldTree)

observations :: (forall a s. (s -> a -> s) -> s -> Tree a -> s) -> [(String, Bool)]
observations f =
  [ ("singleton_seed", f (\state value -> (10 * state + value :: Int)) 7 (Leaf 2) == 72)
  , ("pair_zero_seed", f (\state value -> (10 * state + value :: Int)) 0 (Branch (Leaf 1) (Leaf 2)) == 12)
  , ("pair_nonzero_seed", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Leaf 1) (Leaf 2)) == 712)
  , ("pair_second_seed", f (\state value -> (10 * state + value :: Int)) 37 (Branch (Leaf 1) (Leaf 2)) == 3712)
  , ("left_associated", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Branch (Leaf 1) (Leaf 2)) (Leaf 3)) == 7123)
  , ("right_associated", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Leaf 1) (Branch (Leaf 2) (Leaf 3))) == 7123)
  , ("balanced_four", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Branch (Leaf 1) (Leaf 2)) (Branch (Leaf 3) (Leaf 4))) == 71234)
  , ("asymmetric_four", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Leaf 1) (Branch (Branch (Leaf 2) (Leaf 3)) (Leaf 4))) == 71234)
  , ("deep_five", f (\state value -> (10 * state + value :: Int)) 7 (Branch (Leaf 1) (Branch (Leaf 2) (Branch (Leaf 3) (Branch (Leaf 4) (Leaf 5))))) == 712345)
  , ("nonlinear_state", f (\state value -> (state * state + value :: Int)) 2 (Branch (Leaf 1) (Branch (Leaf 2) (Leaf 3))) == 732)
  , ("nonlinear_second_seed", f (\state value -> (state * state + value :: Int)) 3 (Branch (Branch (Leaf 1) (Leaf 2)) (Leaf 3)) == 10407)
  , ("boolean_elements", f (\state value -> (2 * state + (if value then 1 else 0) :: Int)) 3 (Branch (Leaf True) (Branch (Leaf False) (Leaf False))) == 28)
  , ("sequence_accumulator", f (\state value -> state ++ [value :: Int]) [9, 8] (Branch (Leaf 1) (Branch (Leaf 2) (Leaf 3))) == [9, 8, 1, 2, 3])
  , ("sequence_singleton", f (\state value -> state ++ [value :: Int]) [5] (Leaf 2) == [5, 2])
  , ("boolean_accumulator_true", f (\state value -> if (value :: Int) == 1 then not state else False) True (Leaf 1) == False)
  , ("boolean_accumulator_false", f (\state value -> if (value :: Int) == 1 then not state else False) False (Leaf 1) == True)
  ]

reference :: forall a s. (s -> a -> s) -> s -> Tree a -> s
reference = \step seed input -> foldTree (\value state -> step state value) (\left right state -> right (left state)) input seed

ignore_tree :: forall a s. (s -> a -> s) -> s -> Tree a -> s
ignore_tree = \_ seed _ -> seed

reverse_order :: forall a s. (s -> a -> s) -> s -> Tree a -> s
reverse_order = \step seed input -> foldTree (\value state -> step state value) (\left right state -> left (right state)) input seed

left_only :: forall a s. (s -> a -> s) -> s -> Tree a -> s
left_only = \step seed input -> foldTree (\value state -> step state value) (\left _ -> left) input seed

right_only :: forall a s. (s -> a -> s) -> s -> Tree a -> s
right_only = \step seed input -> foldTree (\value state -> step state value) (\_ right -> right) input seed

duplicate_left :: forall a s. (s -> a -> s) -> s -> Tree a -> s
duplicate_left = \step seed input -> foldTree (\value state -> step state value) (\left right state -> right (left (left state))) input seed

reset_at_branches :: forall a s. (s -> a -> s) -> s -> Tree a -> s
reset_at_branches = \step seed input -> foldTree (\value state -> step state value) (\left right _ -> right (left seed)) input seed

reset_at_leaves :: forall a s. (s -> a -> s) -> s -> Tree a -> s
reset_at_leaves = \step seed input -> foldTree (\value _ -> step seed value) (\left right state -> right (left state)) input seed

controlResults :: [(String, Bool)]
controlResults =
  [ ("reference", all snd (observations reference))
  , ("ignore_tree", not $ all snd (observations ignore_tree))
  , ("reverse_order", not $ all snd (observations reverse_order))
  , ("left_only", not $ all snd (observations left_only))
  , ("right_only", not $ all snd (observations right_only))
  , ("duplicate_left", not $ all snd (observations duplicate_left))
  , ("reset_at_branches", not $ all snd (observations reset_at_branches))
  , ("reset_at_leaves", not $ all snd (observations reset_at_leaves))
  ]
