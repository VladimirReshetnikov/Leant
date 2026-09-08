module Main where
import TreeAccumulatorControls (controlResults)
main :: IO ()
main = do
  print controlResults
  if all snd controlResults then pure () else fail "tree accumulator control failure"
