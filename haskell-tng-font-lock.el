;;; haskell-tng-font-lock.el --- Fontification for Haskell -*- lexical-binding: t -*-

;; Copyright (C) 2018 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;  A fontification scheme for Haskell with a goal to visually differentiate
;;  between values and types.
;;
;;  It is not possible to be completely accurate for all language extensions.
;;  For example TypeOperators and TypeApplications allow constructs that can
;;  only be disambiguated by semantic rules via the symbol table from the
;;  imported modules.
;;
;;  If an extension has been considered, but not implemented, the marker EXT:
;;  will appear with the extension name.
;;
;;  The detection of complex language constructs is not considered, for
;;  simplicity and speed. Maybe one day we could use
;;  https://github.com/tree-sitter/tree-sitter-haskell for 100% accurate
;;  parsing, but until that day, we do it the idiomatic Emacs way (with hacks
;;  and more hacks).
;;
;;  Some useful tools to assist with keywords and extend-region:
;;
;;  - https://github.com/Lindydancer/highlight-refontification
;;  - https://github.com/Lindydancer/font-lock-profiler
;;  - https://github.com/Lindydancer/font-lock-studio
;;
;;  The Emacs Lisp manual should be consulted
;;  https://www.gnu.org/software/emacs/manual/html_mono/elisp.html#Font-Lock-Mode
;;  in addition to `C-h f font-lock-keywords'
;;
;;; Code:

;; TODO: regression tests https://github.com/Lindydancer/faceup
;; TODO use levels so users can turn off type fontification

(require 'dash)
(require 'haskell-tng-util)

(defgroup haskell-tng:faces nil
  "Haskell font faces."
  :group 'haskell-tng)

(defface haskell-tng:keyword
  '((t :inherit font-lock-keyword-face))
  "Haskell reserved names and operators."
  :group 'haskell-tng:faces)

(defface haskell-tng:module
  '((t :inherit font-lock-variable-name-face :weight bold))
  "Haskell modules (packages)."
  :group 'haskell-tng:faces)

(defface haskell-tng:type
  '((t :inherit font-lock-type-face))
  "Haskell types."
  :group 'haskell-tng:faces)

(defface haskell-tng:constructor
  '((t :inherit font-lock-constant-face))
  "Haskell constructors."
  :group 'haskell-tng:faces)

(defface haskell-tng:toplevel
  '((t :inherit font-lock-function-name-face))
  "Haskell top level declarations."
  :group 'haskell-tng:faces)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Here are `rx' patterns that are reused as a very simple form of BNF grammar
(defconst haskell-tng:rx:conid '(: upper (* wordchar)))
(defconst haskell-tng:rx:qual `(: (+ (: ,haskell-tng:rx:conid (char ?.)))))
(defconst haskell-tng:rx:consym '(: ":" (+ (syntax symbol)))) ;; TODO exclude ::, limited symbol set
(defconst haskell-tng:rx:toplevel
  `(: line-start (group (| (: (any lower ?_) (* wordchar))
                           (: "(" (+? (syntax symbol)) ")")))
      symbol-end))
;; note that \n has syntax `comment-end'
(defconst haskell-tng:rx:newline
  '(| (syntax comment-end)
      (: symbol-start
         "--"
         (+ (not (syntax comment-end)))
         (syntax comment-end)))
  "Newline or line comment.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Here is the `font-lock-keywords' table of matchers and highlighters.
(setq
 haskell-tng:keywords
 ;; These regexps use the `rx' library so we can reuse common subpatterns. It
 ;; also increases the readability of the code and, in many cases, allows us to
 ;; do more work in a single regexp instead of multiple passes.
 (let ((conid haskell-tng:rx:conid)
       (qual haskell-tng:rx:qual)
       (consym haskell-tng:rx:consym)
       (toplevel haskell-tng:rx:toplevel)
       (bigspace `(| space ,haskell-tng:rx:newline)))
   `(;; reservedid / reservedop
     (,(rx-to-string
        '(|
          (: word-start
             (| "case" "class" "data" "default" "deriving" "do" "else"
                "foreign" "if" "import" "in" "infix" "infixl"
                "infixr" "instance" "let" "module" "newtype" "of"
                "then" "type" "where" "_")
             word-end)
          (: symbol-start
             (| ".." ":" "::" "=" "|" "<-" "->" "@" "~" "=>")
             symbol-end)
          (: symbol-start (char ?\\))))
      . 'haskell-tng:keyword)

     ;; TypeFamilies
     (,(rx word-start "type" (+ space) (group "family") word-end)
      (1 'haskell-tng:keyword))

     ;; Types
     (haskell-tng:font:explicit-type:keyword
      (1 'haskell-tng:type keep))
     (haskell-tng:font:topdecl:keyword
      (1 'haskell-tng:type keep))
     (haskell-tng:font:type:keyword
      (1 'haskell-tng:type keep))
     (haskell-tng:font:deriving:keyword
      (1 'haskell-tng:keyword keep)
      (2 'haskell-tng:type keep))

     ;; EXT:TypeFamilies (just paint the whole thing)

     ;; TypeApplications: Unfortunately it is not possible to disambiguate
     ;; between type applications when the following type is in parentheses, as
     ;; it could also be a value extractor in a pattern.
     (,(rx-to-string `(: symbol-start "@" (* space)
                         (group (opt ,qual) (| ,conid ,consym))))
      (1 'haskell-tng:type))

     ;; TODO modules

     ;; imports
     (haskell-tng:font:import:keyword
      (,(rx-to-string
         `(: line-start "import" (+ space)
             (group (opt word-start "qualified" word-end)) (* space)
             ;; EXT:PackageImports
             ;; EXT:Safe, EXT:Trustworthy, EXT:Unsafe
             (group symbol-start (* ,conid ".") ,conid symbol-end) (* ,bigspace)
             (group (opt word-start "as" word-end (* space)))
             (group (opt word-start "hiding" word-end (* space)))))
       (haskell-tng:font:multiline:pre) nil
       (1 'haskell-tng:keyword)
       (2 'haskell-tng:module)
       (3 'haskell-tng:keyword)
       (4 'haskell-tng:keyword))
      (,(rx word-start "as" (+ space) (group (+ word) word-end))
       (haskell-tng:font:multiline:pre) nil
       (1 'haskell-tng:module))
      ;; (haskell-tng:font:paren-search-forward
      ;;  (haskell-tng:font:multiline:pre 1 0) nil
      ;;  (0 'haskell-tng:constructor))
      ;;  TODO FIXME the paren in group 1
      ;; (,(rx-to-string `(: word-start ,conid word-end))
      ;;  (haskell-tng:font:multiline:pre 1) nil
      ;;  (0 'haskell-tng:type))
      ;; EXT:ExplicitNamespaces
      )

     ;; TODO: pragmas
     ;; TODO: numeric / char primitives?
     ;; TODO: haddock, different face vs line comments, and some markup.

     ;; top-level
     (,(rx-to-string toplevel)
      . 'haskell-tng:toplevel)

     ;; uses of F.Q.N.s
     (,(rx-to-string `(: symbol-start (+ (: ,conid "."))))
      . 'haskell-tng:module)

     ;; constructors
     (,(rx-to-string `(: symbol-start (| ,conid ,consym) symbol-end))
      . 'haskell-tng:constructor)

     )))

(defun haskell-tng:font:multiline:pre (&optional group jump)
  "MATCH-ANCHORED moving point to group beginning (plus JUMP) and extend LIMIT."
  (setq group (or group 0))
  ;; TODO: does a group inside an opt give nil? That would be better
  (when (match-string group)
    (when (< 0 group)
     (message "MATCHED GROUP %s AS %s"
              group
              (match-string group)))
    (goto-char (match-beginning group))
    (when jump
      (forward-char jump)
      (message "JUMPING FOR %s TO %s"
               (match-string group)
               (buffer-substring-no-properties (point) (+ 10 (point))))))
  (match-end 0))

(defun haskell-tng:font:paren-search-forward (limit)
  "Match the contents of balanced parenthesis."
  (when (re-search-forward "(" limit t)
    (when-let (close (haskell-tng:paren-close))
      (when (<= close limit)
        (re-search-forward (rx (+ anything)) close t)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Here are `function' matchers for use in `font-lock-keywords' and
;; `font-lock-extend-region-functions' procedures for extending the region.
;;
;; For these more complicated structures, the general rule is to find "negative
;; space" rather than to detect valid entries. Language extensions almost always
;; scupper any plan, e.g. TypeOperators and type literals.
;;
;; Note that because we are using `font-lock-multiline', multiline patterns will
;; always be re-highlighted as a group.
(eval-when-compile
  ;; NOTE: font-lock-end is non-inclusive.
  (defvar font-lock-beg)
  (defvar font-lock-end))

(defconst haskell-tng:extend-region-functions
  '(font-lock-extend-region-wholelines)
  "Used in `font-lock-extend-region-functions'.
Automatically populated by `haskell-tng:font:multiline'")

;; TODO (perf) don't extend if the TRIGGER has a multiline prop
(defmacro haskell-tng:font:multiline (name trigger find &rest limiters)
  "Defines `font-lock-keywords' / `font-lock-extend-region-functions' entries.

TRIGGER and FIND are forms that produce a regexp, which is
memoised by this macro. FIND typically begins by repeating
TRIGGER.

The generated `haskell-tng:PREFIX-extend' searches backwards for
TRIGGER from the end of the region. If a match is found, FIND is
called with no limit, which will extend the region if there is a
match.

The generated `haskell-tng:PREFIX-keyword' searches forward for
TRIGGER, limited to the fontification region. The point is reset
to the beginning of the TRIGGER's match and FIND is then
searched. This function is ideal for inclusion in the mode's
`font-lock-keywords' list and behaves like a regexp.

The LIMITERS are function names that are called if the TRIGGER
succeeds and may further restrict the FIND search limit."
  (declare (indent defun))
  (let* ((sname (concat "haskell-tng:font:" (symbol-name name)))
         (regexp-1 (intern (concat sname ":trigger")))
         (regexp-2 (intern (concat sname ":matcher")))
         (keyword (intern (concat sname ":keyword")))
         (extend (intern (concat sname ":extend"))))
    (cl-flet
        ((finder (lim)
                 `(re-search-forward
                   ,regexp-2
                   (-min (cons ,lim (-non-nil (-map 'funcall ',limiters))))
                   t)))
      `(progn
         (defconst ,regexp-1 ,trigger)
         (defconst ,regexp-2 ,find)
         (defun ,extend ()
           (goto-char font-lock-end)
           (when (re-search-backward ,regexp-1 font-lock-beg t)
             ,(finder '(point-max))
             (when (< font-lock-end (point))
               (setq font-lock-end (point))
               nil)))
         (defun ,keyword (limit)
           (when (re-search-forward ,regexp-1 limit t)
             (goto-char (match-beginning 0))
             ,(finder 'limit)))
         (add-to-list 'haskell-tng:extend-region-functions ',extend t)))))

(haskell-tng:font:multiline explicit-type
  (rx symbol-start "::" symbol-end)
  (rx symbol-start "::" symbol-end (group (+ anything)))
  haskell-tng:paren-close
  haskell-tng:indent-close-previous)

(haskell-tng:font:multiline topdecl
  (rx line-start (| "data" "newtype" "class" "instance") word-end)
  (rx line-start (| "data" "newtype" "class" "instance") word-end
      (group (+? anything))
      (| (: line-start symbol-start)
         (: symbol-start (| "where" "=") symbol-end))))

(haskell-tng:font:multiline type
  (rx line-start "type" word-end)
  (rx line-start "type" word-end (group (+ anything)))
  haskell-tng:indent-close)

;; DeriveAnyClass
;; DerivingStrategies
;; GeneralizedNewtypeDeriving
;; EXT:DerivingVia
;; EXT:StandaloneDeriving
(haskell-tng:font:multiline deriving
  (rx word-start "deriving" word-end)
  (rx word-start "deriving" word-end
      (+ space) (group (opt (| "anyclass" "stock" "newtype") word-end))
      (* space) ?\( (group (* anything)) ?\))
  haskell-tng:indent-close)

(haskell-tng:font:multiline import
  (rx line-start "import" word-end)
  (rx line-start "import" word-end
      (+? anything)
      (opt (group "(" (+ anything)))
      (* anything))
  haskell-tng:indent-close)

(haskell-tng:font:multiline module
  (rx line-start "module" word-end)
  (rx line-start "module" word-end (group (+ anything)))
  haskell-tng:indent-close)

(provide 'haskell-tng-font-lock)
;;; haskell-tng-font-lock.el ends here
