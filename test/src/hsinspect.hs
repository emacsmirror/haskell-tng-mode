-- RUN (require 'haskell-tng-hsinspect)
-- RUN (setq haskell-tng--hsinspect-popup-tip t)
-- RUN (require 'haskell-tng-extra-company)
-- RUN (haskell-tng-extra-company-hook)
-- RUN (setq haskell-tng--hsinspect-imports (haskell-tng--util-read "test/data/hsinspect-0.0.8-imports.sexp.gz"))
-- RUN (setq haskell-tng--hsinspect-index (haskell-tng--util-read "test/data/hsinspect-0.0.9-index.sexp.gz"))

module Medley.Wibble where

import Data.Functor.Contravariant as C
import Medley.Wobble
-- FIXME (progn (next-line) (move-to-column 18) (let ((fqn (haskell-tng-fqn-at-point))) (next-line) (insert (concat "-- " fqn))))
import Prelude (zip)

-- RUN (progn (next-line) (company-complete))
foo = C.pha

-- RUN (progn (next-line) (company-complete))
bar = wob

-- RUN (progn (next-line) (move-to-column 9) (let ((haskell-tng--hsinspect-popup-menu "Data.List")) (haskell-tng-import-symbol-at-point)))
baz = nubBy bar zipped

-- RUN (progn (next-line) (move-to-column 9) (let ((haskell-tng--hsinspect-popup-menu "Data.List")) (haskell-tng-import-symbol-at-point '-)))
bag = nubBy bag' zipped
  where
    -- RUN (progn (next-line) (company-complete))
    bag' = L.part

-- RUN (progn (next-line) (move-to-column 11) (let ((haskell-tng--hsinspect-popup-menu "Data.List.NonEmpty")) (haskell-tng-import-symbol-at-point)))
zaz = NEL.fromList bag

-- RUN (progn (next-line) (move-to-column 20) (let ((this-buffer (current-buffer))) (haskell-tng-jump-to-definition) (kill-ring-save (line-beginning-position) (line-end-position)) (kill-append (concat "\n-- " (buffer-name)) nil) (switch-to-buffer this-buffer) (next-line) (insert "-- ") (yank)))
zipped = [1, 2, 3] zip "abc"


-- Local Variables:
--   haskell-tng--compile-command: "cd ../.. && cask exec ert-runner test/haskell-tng-dynamic-test.el"
-- End:
