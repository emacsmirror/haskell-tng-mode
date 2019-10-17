;;; haskell-tng-extra.el --- Untested features -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;  Untested / untestable commands that may require an external process to exist
;;  on PATH.
;;
;;; Code:

;; TODO a generic wrapper around commands that can be downloaded and built using
;;      cabal v2-install.

;; TODO cabal-fmt on new file creation (for the `insert' support). Maybe with a
;; hook in both `before-save-hook' (detecting that the file is new) and
;; `after-save-hook' (running the command and resetting the newfile var).

(require 'subr-x)

;;###autoload
(defun haskell-tng-newline (&optional alt)
  "A `newline-and-indent' with a better user experience for `haskell-tng-mode'.

When in a comment and called with a prefix, the comment will be completed."
  (interactive "P")
  ;; TODO a dynamically bound variable might improve the quality of
  ;;      'empty-line-token predictions. Parens are special-cased.
  (when (<= (- (point-max) 1) (point))
    ;; WORKAROUND https://debbugs.gnu.org/cgi/bugreport.cgi?bug=36432
    ;; TODO fix the bug properly in SMIE
    (save-excursion (insert "\n\n")))
  (let ((rem (save-excursion
               (skip-syntax-forward " ")
               (unless (looking-at (rx (syntax close-parenthesis)))
                 (when (/= (point) (line-end-position))
                   (buffer-substring-no-properties (point) (line-end-position)))))))
    (when rem
      (delete-region (point) (line-end-position)))
    ;; TODO don't continue line comments if there is code before them
    ;;
    ;; TODO in-comment indent should observer but not repeat | haddock markers
    (cond
     (alt
      (call-interactively #'newline-and-indent))
     ((looking-back (rx (>= 3 "-")) (line-beginning-position))
      ;; don't continue or indent visual line breaks
      (call-interactively #'newline))
     (t
      (call-interactively #'comment-indent-new-line)))
    (when rem
      (save-excursion
        (insert rem)))))

;;;###autoload
(defun haskell-tng-stylish-haskell ()
  "Apply `stylish-haskell' rules."
  ;; TODO use https://github.com/purcell/reformatter.el
  ;; TODO error buffer should be easy to dismiss
  (interactive)
  (save-buffer)
  (unless (= 0 (call-process "stylish-haskell" nil "*stylish-haskell*" nil "-i" buffer-file-name))
    (pop-to-buffer "*stylish-haskell*" nil t))
  (revert-buffer t t t))

;;;###autoload
(defun haskell-tng-ormolu ()
  "Apply `ormolu' rules."
  ;; TODO use https://github.com/purcell/reformatter.el
  ;; TODO error buffer should be easy to dismiss
  ;; TODO pass parameters via a buffer local variable
  (interactive)
  (save-buffer)
  (unless (= 0 (call-process "ormolu" nil "*ormolu*" nil
                             ;; "-p"
                             "-o" "-XTypeApplications"
                             "-o" "-XBangPatterns"
                             "-o" "-XPatternSynonyms"
                             "-m" "inplace"
                             buffer-file-name))
    (pop-to-buffer "*ormolu*" nil t))
  (revert-buffer t t t))

;;;###autoload
(defun haskell-tng-stack2cabal ()
  "Prepare a stack project for use with cabal."
  (interactive)
  (when-let (default-directory
              (locate-dominating-file default-directory "stack.yaml"))
    (call-process "stack2cabal")))

;;;###autoload
(defun haskell-tng-goto-imports ()
  "Hack to jump to imports"
  ;; TODO imenu navigation will replace this
  (interactive)
  (re-search-backward (rx line-start "import" word-end)))

;;;###autoload
(defun haskell-tng-current-module ()
  "Puts the current module name into the kill ring."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (re-search-forward (rx bol "module" word-end))
    (forward-comment (point-max))
    (re-search-forward (rx point (group (+ (not space))) space))
    (kill-new (match-string 1))))

;;;###autoload
(defun haskell-tng-filename-to-modulename ()
  "Infers the ModuleName for the current file based on filesystem layout."
  (mapconcat
   #'identity
   (reverse
    (seq-take-while
     (lambda (e) (let (case-fold-search)
              (string-match-p (rx bos upper) e)))
     (reverse
      (split-string
       (file-name-sans-extension buffer-file-name)
       "\\/"))))
   "."))

(provide 'haskell-tng-extra)
;;; haskell-tng-extra.el ends here