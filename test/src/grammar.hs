-- | Tests for grammar rules (i.e. sexps, not indentation)
module Foo.Bar where

calc :: Int -> Int
calc a = if a < 10
         then a + a * a + a
         else (a + a) * (a + a)
