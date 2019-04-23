;;; haskell-tng-mode.el --- Major mode for editing Haskell -*- lexical-binding: t -*-

;; Copyright (C) 2018-2019 Tseen She
;; License: GPL 3 or any later version

;; Homepage: https://gitlab.com/tseenshe/haskell-tng-mode
;; Keywords: languages
;; Package-Version: 0.0.1
;; Package-Requires: ((dash "2.14.1"))

;;; Commentary:
;;
;;  A modern rewrite of `haskell-mode'.
;;
;;; Code:

(require 'dabbrev)

(require 'haskell-tng-syntax)
(require 'haskell-tng-font-lock)
(require 'haskell-tng-smie)
(require 'haskell-tng-compile)

(defgroup haskell-tng ()
  "Haskell support: The Next Generation."
  :group 'languages)

;;;###autoload
(define-derived-mode haskell-tng-mode prog-mode "Hask"
  "Major mode for editing Haskell programs."
  :group 'haskell-tng
  :syntax-table haskell-tng:syntax-table

  ;; TODO paragraph-start, paragraph-separate, fill-paragraph-function
  ;;
  ;; TODO mark-defun / font-lock-mark-block-function

  ;; TODO use setq-local (write a macro to allow multiple parameters)
  (setq
   ;; TAB is evil
   indent-tabs-mode nil
   tab-width 8

   ;; case-sensitive language
   dabbrev-case-fold-search nil
   dabbrev-case-distinction nil
   dabbrev-case-replace nil

   words-include-escapes t
   syntax-propertize-function #'haskell-tng:syntax-propertize
   parse-sexp-lookup-properties t
   parse-sexp-ignore-comments t

   ;; annoying that comments need to be defined here and syntax table
   comment-start "--"
   comment-padding 1
   comment-start-skip (rx "-" (+ "-") (* " "))
   comment-end ""
   comment-end-skip (rx (* "\s") (group (| (any ?\n) (syntax comment-end))))
   comment-auto-fill-only-comments t

   font-lock-defaults '(haskell-tng:keywords)
   font-lock-multiline t
   font-lock-extend-region-functions haskell-tng:extend-region-functions

   ;; whitespace is meaningful, no electric indentation
   electric-indent-inhibit t)

  (haskell-tng-smie:setup))

;; TODO: autoload this when I'm ready to use tng instead of regular
(progn
  (add-to-list 'auto-mode-alist '("\\.hs\\'" . haskell-tng-mode))
  (modify-coding-system-alist 'file "\\.hs\\'" 'utf-8))

(provide 'haskell-tng-mode)
;;; haskell-tng-mode.el ends here
