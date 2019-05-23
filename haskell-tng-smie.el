;;; haskell-tng-smie.el --- SMIE Rules for Haskell -*- lexical-binding: t -*-

;; Copyright (C) 2018-2019 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;  SMIE precedence table, providing s-expression navigation, and indentation
;;  rules.
;;
;;  Although SMIE provides the primary indentation suggest (when the user types
;;  RETURN), we cycle through alternative candidates on TAB. The philosophy is
;;  not to try and get indentation right 100% of the time, but to get it right
;;  90% of the time and make it so easy to fix it that it doesn't get in the
;;  way.
;;
;;  Users may consult the SMIE manual to customise their indentation rules:
;;  https://www.gnu.org/software/emacs/manual/html_mono/elisp.html#SMIE
;;
;;; Code:

(require 'smie)

(require 'haskell-tng-font-lock)
(require 'haskell-tng-lexer)

;; https://www.gnu.org/software/emacs/manual/html_mono/elisp.html#SMIE-Grammar
;; https://www.haskell.org/onlinereport/haskell2010/haskellch3.html
;; https://gitlab.haskell.org/ghc/ghc/blob/master/compiler/parser/Parser.y
;;
;; Many of these grammar rules cannot be expressed in SMIE because Haskell uses
;; whitespace separators a lot, whereas the BNF must use non-terminals.
;;
;; Rules that are unbounded on the right tend to misbehave quite badly, since
;; there is no way to know how to end the s-expression. For example, the BNF
;; definition of a TYPE will typically extend to an arbitrary point later in the
;; file. We cannot use `;' to end the TYPE definition, because symbols cannot be
;; closers and "neither" (i.e. infix) at the same time. An option is always to
;; push contextual functionality into the lexer, but one must draw a line
;; somewhere.
;;
;; We do not include rules unless they have an impact on indentation. Navigation
;; with a more complete grammar has been shown to be less than satisfactory,
;; therefore there is no reason to do more than is needed.
(defvar haskell-tng-smie:grammar
  ;; see docs for `smie-prec2->grammar'
  (smie-prec2->grammar
   (smie-bnf->prec2
    '((id)

      ;; commas only allowed in brackets
      (list
       ("(" list ")")
       ("[" list "]") ;; includes DataKinds
       (list "," list))

      ;; operators all have the same precedence
      (infixexp
       (id ":" infixexp) ;; keyword infix
       (id "':" infixexp) ;; DataKinds
       (id "SYMID" infixexp))

      ;; WLDOs
      (wldo
       ("module" blk "where" blk)
       (blk "where" blk)
       ("let" blk "in")
       ("do" blk)
       ("case" id "of" blk))
      (blk
       ("{" blk "}")
       (blk ";" blk)
       (id "=" id)
       (id "<-" id)
       (id "->" id)
       )

      (logic
       ("if" id "then" id "else" id))
      )

    ;; operator precedences
    '((assoc ";" ",")
      )

    )))

;; https://www.gnu.org/software/emacs/manual/html_mono/elisp.html#SMIE-Indentation
(defun haskell-tng-smie:rules (method arg)
  ;; see docs for `smie-rules-function'
;;  (message "INDENT %S %S" method arg)
  (pcase method
    (:elem
     (pcase arg
       ('basic smie-indent-basic)
       ))

    ;; TODO implement more indentation rules

    (:after
     (pcase arg
       ("where"
        (if (smie-rule-parent-p "module")
            '(column . 0)
          smie-indent-basic))
       ((or "::" "=" "let" "do" "of")
        smie-indent-basic)
       ))

    ;; TODO :before rules
    ))

(defconst haskell-tng-smie:return
  '(newline-and-indent newline)
  "Users with custom newlines should add their command.")

(defvar-local haskell-tng-smie:indentations nil)
(defun haskell-tng-smie:indent-cycle ()
  "When invoked more than once, returns an alternative indentation level."
  ;; There is a design choice here: either we compute all the indentation levels
  ;; (including a recursive call to `smie-indent-calculate') and put them into a
  ;; ring that we cycle, or we push/pop with recalculation. We choose the
  ;; latter, because cache invalidation is easier.
  (if (member this-command haskell-tng-smie:return)
      (setq haskell-tng-smie:indentations nil)
    (when (and
           (null haskell-tng-smie:indentations)
           (or
            ;; TAB+TAB and RETURN+TAB
            (eq this-command last-command)
            (member last-command haskell-tng-smie:return)))
      ;; avoid recalculating the prime indentation level
      (let ((prime (current-column)))
        (setq haskell-tng-smie:indentations
              (append
               ;; TODO backtab, does the cycle in reverse (use a local flag)
               (-remove-item prime (haskell-tng-smie:indent-alts))
               (list prime))))))
  (pop haskell-tng-smie:indentations))

(defun haskell-tng-smie:indent-alts ()
  "Returns a list of alternative indentation levels for the
current line."
  (save-excursion
    (let ((the-line (line-number-at-pos))
          indents)
      (when (re-search-backward haskell-tng:regexp:toplevel nil t)
        (while (< (line-number-at-pos) the-line)
          ;; FIXME improve the indentation alts
          ;; TODO add positions of WLDOS
          ;; TODO +- 2 WLDOS
          ;; TODO special cases for import (unless grammar handles it)
          ;; TODO special cases for multiple whitespaces (implies alignment)
          ;; TODO the-line +- 2
          (push (current-indentation) indents)
          (forward-line)))

      ;; alts are easier to use when ordered
      (setq indents (sort indents '<))
      ;; TODO consider ordering all alts, and cycling the list so the first alt
      ;; is the next higher than the current indentation level

      ;; indentation of the next line is common for insert edits, top priority
      (forward-line)
      (forward-comment (point-max))
      (when (/= the-line (line-number-at-pos))
        (push (current-indentation) indents))

      (-distinct indents))))

(defun haskell-tng-smie:setup ()
  (setq-local smie-indent-basic 2)

  (add-hook
   'after-change-functions
   #'haskell-tng-layout:cache-invalidation
   nil 'local)

  (add-hook
   'after-change-functions
   #'haskell-tng-lexer:state-invalidation
   nil 'local)

  (add-hook
   'smie-indent-functions
   #'haskell-tng-smie:indent-cycle
   nil 'local)

  ;; TODO alternative to indent-for-tab-command that does alignment

  (smie-setup
   haskell-tng-smie:grammar
   #'haskell-tng-smie:rules
   :forward-token #'haskell-tng-lexer:forward-token
   :backward-token #'haskell-tng-lexer:backward-token))

;; SMIE wishlist, in order of desirability:
;;
;; 1. if the lexer could return lists of tokens.
;;
;; 2. exposing the parse tree so that s-expression navigation could be
;;    implemented and tests could be easier to write.
;;
;; 3. if the Emacs regexps allowed arbitrary zero-width matches, especially if
;;    syntax "categories" were allowed. i.e. in the Java regexp engine these are
;;    (?=X) (?!X) (?<=X) (?<!X) where X can be an Emacs syntax category. A
;;    limitation with Emacs regexps is that they only support word-start,
;;    word-end, symbol-start and symbol-end zero-width matchers.
;;
;; 4. ambiguous tokens. e.g. the word "via" is a keyword in a specific location,
;;    but can otherwise be used as a varid. I'd like to be able to lex it as (or
;;    "via" "VARID") so that it can appear in multiple places in the grammar.

(provide 'haskell-tng-smie)
;;; haskell-tng-smie.el ends here
