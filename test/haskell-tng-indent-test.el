;;; haskell-tng-indent-test.el --- Tests for indentation -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

(require 'ert)
(require 's)

(require 'haskell-tng-mode)

(require 'haskell-tng-testutils
         "test/haskell-tng-testutils.el")

(ert-deftest haskell-tng-indent-file-tests ()
  ;; Three indentation regression tests are possible:
  ;;
  ;;   1. newline-and-indent with the rest of the file deleted (append)
  ;;   2. newline-and-indent with the rest of the file intact (insert)
  ;;   3. indent-line-function at the beginning of each line (re-indent)
  ;;
  ;; each with alternative indentation suggestions.
  ;;
  ;; Expectations could use lines of symbols such as | and . or digits to
  ;; indicate where the indentation(s) go.
  ;;
  ;; Test 1 involves a lot of buffer refreshing and will be very slow.

  (should (have-expected-newline-indent-insert (testdata "src/layout.hs")))
  (should (have-expected-newline-indent-insert (testdata "src/medley.hs")))
  ;; TODO more tests
  )

(defun current-line-string ()
  (buffer-substring-no-properties
   (line-beginning-position)
   (- (line-beginning-position 2) 1)))

(defun haskell-tng-indent-test:newline-indent-insert ()
  (let (indents)
    (while (not (eobp))
      (end-of-line)
      (let ((indent (list (current-line-string)))
            alts)
        (call-interactively #'newline-and-indent)
        (push (current-column) indent)

        ;; TODO a better way to get the alts
        (while (< (length alts) 1)
          (message "LOOPING %s %s" this-command last-command)
          (call-interactively #'indent-for-tab-command)
          (push (current-column) alts))

        (setq indent
              (delete-dups
               (append (reverse indent) (reverse alts))))

        (push indent indents)
        (kill-whole-line)))
    (reverse indents)))

(defun haskell-tng-indent-test:indents-to-string (indents)
  "INDENTS is a list of INDENT.

INDENT is a non-empty list of (LINE . (INDENT . ALTS)) where LINE
is the string line of code before the indentation, INDENT is the
integer suggested next line indentation column and ALTS is a list
of integer alternative indentations."
  (s-join "\n" (-flatten
                (-map #'haskell-tng-indent-test:indent-to-string indents))))

(defun haskell-tng-indent-test:indent-to-string (indent)
  (let ((line (car indent))
        (indent (cadr indent))
        (_alts (cddr indent)))
    ;; FIXME show alts
    (list line (concat (s-repeat indent " ") "v"))))

(defun have-expected-newline-indent-insert (file)
  (haskell-tng-testutils:assert-file-contents
   file
   #'haskell-tng-mode
   (lambda ()
     (haskell-tng-indent-test:indents-to-string
      (haskell-tng-indent-test:newline-indent-insert)))
   "insert.indent"))

;;; haskell-tng-indent-test.el ends here
