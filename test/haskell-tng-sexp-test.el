;;; haskell-tng-sexp-test.el --- Tests for sexp navigation -*- lexical-binding: t -*-

;; Copyright (C) 2018-2019 Tseen She
;; License: GPL 3 or any later version

(require 'ert)
(require 's)

(require 'haskell-tng-mode)

(require 'haskell-tng-testutils
         "test/haskell-tng-testutils.el")

;; This test was originally going to use
;; `thing-at-point-bounds-of-list-at-point' to generate all the bounds for a
;; file. But `scan-lists' (and many other sexp / list commands) are not SMIE
;; aware.
;;
;; Therefore we calculate the s-expression bounds at every point in the file.
;; However, this fails to find all bounds because there is ambiguity at virtual
;; tokens.

(ert-deftest haskell-tng-sexp-file-tests ()
  (should (have-expected-sexps (testdata "src/layout.hs")))

  ;; TODO enable when layout.hs gives better results...
  ;;(should (have-expected-sexps (testdata "src/medley.hs")))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SMIE testing utilities

;; `thing-at-point--beginning-of-sexp' and `thing-at-point--end-of-sexp' cannot
;; be trusted because they assume the language is a lisp. This finds the nearest
;; forward/backward sexps at the current point (which is not necessarilly
;; beginning / end of current sexp), using only the primitives `forward-sexp'
;; and `backward-sexp', provided by SMIE.
(defun haskell-tng-sexp-test:sexps-at-point (p)
  "Return a list of cons cells (start . end)"
  (let* (sexps
         (forward-backward
          (ignore-errors
            (save-excursion
              (goto-char p)
              (forward-sexp)
              (let ((forward (point)))
                (backward-sexp)
                (cons (point) forward)))))
         (backward-forward
          (ignore-errors
            (save-excursion
              (goto-char p)
              (backward-sexp)
              (let ((backward (point)))
                (forward-sexp)
                (cons backward (point)))))))
    (when forward-backward
      (push forward-backward sexps))
    (when backward-forward
      (push backward-forward sexps))
    sexps))

(defun haskell-tng-sexp-test:sexps ()
  "All the unique sexp bounds for the current buffer."
  (goto-char (point-min))
  (let (sexps)
    (while (not (eobp))
      (unless (nth 8 (syntax-ppss)) ;; don't query in comments/strings
        (let ((here (haskell-tng-sexp-test:sexps-at-point (point))))
          (setq sexps (append here sexps))))
      (forward-char))
    (delete-dups sexps)))

(defun haskell-tng-sexp-test:sexps-to-string (sexps)
  "Renders the current buffer, marked up by sexps."
  (let (chars exit)
    (goto-char (point-min))
    (while (not exit)
      (--each sexps
        (cond
         ((= (point) (car it)) (push "(" chars))
         ((= (point) (cdr it)) (push ")" chars))
         (t nil)))
      (if (eobp)
          (setq exit 't)
        (push (string (char-after)) chars)
        (forward-char)))
    (s-join "" (reverse chars))))

(defun have-expected-sexps (file)
  (haskell-tng-testutils:assert-file-contents
   file
   #'haskell-tng-mode
   (lambda ()
     (haskell-tng-sexp-test:sexps-to-string
      (haskell-tng-sexp-test:sexps)))
   "sexps"))

;;; haskell-tng-sexp-test.el ends here
