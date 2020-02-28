-- IMPORTS "../data/hsinspect-0.0.8-imports.sexp.gz"
-- INDEX "../data/hsinspect-0.0.9-index.sexp.gz"
module Medley.Wibble where

import Data.Functor.Contravariant as C
import Medley.Wobble
import Prelude (zip)

-- COMPLETE 11
foo = C.pha

-- COMPLETE 9
bar = wob

-- IMPORT 9 "Data.List"
baz = nubBy bar zipped

-- IMPORT- 9 "Data.List"
bag = nubBy bag' zipped
  -- COMPLETE 21
  where bag' = L.part

-- IMPORT 11
zaz = NEL.fromList bag

-- JUMP 17 "base/4.13.0.0/base-4.13.0.0.tar.gz" "GHC/List.hs"
zipped = [1,2,3] zip "abc"
