-- | Idealised indentation scenarios.
--
--   Bugs and unexpected behaviour in (re-)indentation may be documented here.
module Indentation where

import Foo.Bar
import Foo.Baz hiding ( gaz,
                        baz
                      )

basic_do = do
  foo <- blah blah blah
  bar <- blah blah -- TODO same level as foo
         blah -- TODO manual correction
         blah -- continue the blah
  sideeffect -- manual correction
  sideeffect' blah
  let baz = blah blah
            blah -- TODO manual correction
      gaz = blah -- TODO same level as baz
      haz =      -- TODO same level as gaz
        blah
  pure faz -- manual correction

nested_do =
  do foo <- blah
     do bar <- blah -- TODO same level as foo
        baz -- TODO same level as bar

nested_where a b = foo a b
  where -- TODO 2
    foo = bar baz -- TODO indented
    baz = blah blah -- TODO same level as foo
      where -- manual correction
        gaz a = blah -- TODO indented
        faz = blah -- TODO same level as gaz

-- TODO case statements
-- TODO let / in

-- TODO coproduct definitions, the | should align with =

-- TODO lists, records, tuples

-- TODO long type signatures vs definitions
