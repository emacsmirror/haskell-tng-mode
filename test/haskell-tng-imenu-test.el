;;; haskell-tng-imenu-test.el --- Tests for imenu generation -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

(require 'ert)

(require 'haskell-tng-mode)

(require 'haskell-tng-testutils
         "test/haskell-tng-testutils.el")

(ert-deftest haskell-tng-lexer-file-tests:layout ()
  (should (have-expected-imenu (testdata "src/layout.hs"))))

(ert-deftest haskell-tng-lexer-file-tests:indentation ()
  (should (have-expected-imenu (testdata "src/indentation.hs"))))

(ert-deftest haskell-tng-lexer-file-tests:medley ()
  (should (have-expected-imenu (testdata "src/medley.hs"))))

(defun have-expected-imenu (file)
  (haskell-tng--testutils-assert-file-contents
   file
   #'haskell-tng-mode
   (lambda ()
     (imenu "module")
     (with-output-to-string
       (pp imenu--index-alist)))
   "imenu"))

(provide 'haskell-tng-imenu-test)
;;; haskell-tng-imenu-test.el ends here