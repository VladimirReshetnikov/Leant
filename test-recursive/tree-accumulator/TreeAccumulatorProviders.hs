{-# LANGUAGE RankNTypes #-}
module TreeAccumulatorProviders (Tree(..), foldTree) where

data Tree a = Leaf a | Branch (Tree a) (Tree a)

foldTree :: forall a r. (a -> r) -> (r -> r -> r) -> Tree a -> r
foldTree leaf _ (Leaf x) = leaf x
foldTree leaf branch (Branch left right) =
  branch (foldTree leaf branch left) (foldTree leaf branch right)
