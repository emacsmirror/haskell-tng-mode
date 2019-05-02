;;; haskell-tng-contrib.el --- Untested features -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;  Untested / untestable commands that are either contributed by the community
;;  or require an external process to exist on PATH.
;;
;;; Code:

(require 'subr-x)

;; TODO a generic wrapper around commands that can be downloaded and built using
;;      cabal v2-install.

(defun haskell-tng-contrib:stylish-haskell ()
  "Apply `stylish-haskell' rules."
  (interactive)
  (save-buffer)
  (call-process "stylish-haskell" nil nil nil "-i" buffer-file-name)
  (revert-buffer t t t))

(defun haskell-tng-contrib:stack2cabal ()
  "Prepare a stack project for use with cabal."
  (interactive)
  (when-let (default-directory
              (locate-dominating-file default-directory "stack.yaml"))
    (call-process "stack2cabal")))

(provide 'haskell-tng-contrib)
;;; haskell-tng-contrib.el ends here
