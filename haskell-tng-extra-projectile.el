;;; haskell-tng-extra-projectile.el --- Projectile integration -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;; Code:

(require 'projectile)

;; TODO fix the haskell-stack detection to also include cabal
;; TODO populate the projectile compile/run/test commands

(add-hook
 'haskell-tng-mode-hook
 (lambda ()
   (setq-local projectile-tags-command "fast-tags -Re --exclude=dist-newstyle --exclude=.stack-work .")
   ))

(provide 'haskell-tng-extra-projectile)
;;; haskell-tng-extra-projectile.el ends here