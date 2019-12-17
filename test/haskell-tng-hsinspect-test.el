;;; haskell-tng-hsinspect-test.el --- Tests for hsinspect features -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

(require 'ert)

(require 'haskell-tng-mode)
(require 'haskell-tng-hsinspect)

(require 'haskell-tng-testutils
         "test/haskell-tng-testutils.el")

;; TODO tests of the user facing functions in the golden data format

(ert-deftest haskell-tng-hsinspect-test-qualify-latest ()
  (let ((imports
         (haskell-tng--util-read
          (testdata "data/hsinspect-0.0.8-imports.sexp.gz"))))

    ;; function search
    (should
     (equal
      (haskell-tng--hsinspect-qualify imports "contramap")
      "Data.Functor.Contravariant.contramap"))

    ;; operator search
    (should
     (equal
      (haskell-tng--hsinspect-qualify imports ">$<")
      "Data.Functor.Contravariant.>$<"))

    ;; TODO type search
    ;; TODO constructor search
    ))

(ert-deftest haskell-tng-hsinspect-test-import-candidates-latest ()
  (let ((index
         (haskell-tng--util-read
          (testdata "data/hsinspect-0.0.8-index.sexp.gz"))))

    ;; function search
    (should
     (equal
      (haskell-tng--hsinspect-import-candidates index "throw")
      '(((unitid . "base")
         (module . "Control.Exception.Base")
         (name . "throw")
         (type . "forall a e. Exception e => e -> a")
         (class . id)
         (export (unitid . "base")
                 (module . "GHC.Exception"))
         (flavour))
        ((unitid . "base")
         (module . "Control.Exception")
         (name . "throw")
         (type . "forall a e. Exception e => e -> a")
         (class . id)
         (export (unitid . "base")
                 (module . "GHC.Exception"))
         (flavour))
        ((unitid . "base")
         (module . "GHC.Exception")
         (name . "throw")
         (type . "forall a e. Exception e => e -> a")
         (class . id)
         (export)
         (flavour)))))

    ;; operator search
    (should
     (equal
      (haskell-tng--hsinspect-import-candidates index ">$<")
      '(((unitid . "base")
         (module . "Data.Functor.Contravariant")
         (name . ">$<")
         (type . "forall (f :: * -> *) a b. Contravariant f => (a -> b) -> f b -> f a")
         (class . id)
         (export)
         (flavour)))))

    ;; type / typeclass search
    (should
     (equal
      (haskell-tng--hsinspect-import-candidates index "Contravariant")
      '(((unitid . "base")
         (module . "Data.Functor.Contravariant")
         (name)
         (type . "Contravariant")
         (class . tycon)
         (export)
         (flavour . "class")))))

    ;; TODO constructor search
    ;;(message "%S" (haskell-tng--hsinspect-import-candidates index "Contravariant"))
    ))

(ert-deftest haskell-tng-hsinspect-test-extract-imports ()
  (let ((index
         (haskell-tng--util-read
          (testdata "data/hsinspect-0.0.8-index.sexp.gz"))))

    ;; explicit import
    (should
     (equal
      (haskell-tng--hsinspect-extract-imports index "Data.List" nil "head")
      '(((local . "head")
         (full . "Data.List.head")))))

    ;; qualified import
    (should
     (equal
      (seq-take
       (haskell-tng--hsinspect-extract-imports index "Data.List" "L")
       2)
      '(((qual . "L.all")
         (full . "Data.List.all"))
        ((qual . "L.and")
         (full . "Data.List.and")))))

    ;; unqualified import
    (should
     (equal
      (seq-take
       (haskell-tng--hsinspect-extract-imports index "Data.List" nil)
       2)
      '(((local . "all")
         (full . "Data.List.all"))
        ((local . "and")
         (full . "Data.List.and")))))
    ))

;; TODO tests for 0.0.7 data

;;; haskell-tng-hsinspect-test.el ends here
