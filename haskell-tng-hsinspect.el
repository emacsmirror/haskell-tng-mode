;;; haskell-tng-hsinspect.el --- hsinspect integration -*- lexical-binding: t -*-

;; Copyright (C) 2019 Tseen She
;; License: GPL 3 or any later version

;;; Commentary:
;;
;;  `hsinspect' is a companion tool to `haskell-tng' that uses the `ghc' api to
;;  extract semantic information. This file provides an integration layer and
;;  some features.
;;
;;; Code:

;; TODO this file needs tests, if not testing calling hsinspect then at least
;; with pre-canned data.

(require 'array)
(require 'subr-x)
(require 'tar-mode)
(require 'url)
(require 'xref)

;; Popups are not supported in stock Emacs so an extension is necessary:
;; https://emacs.stackexchange.com/questions/53373
;;
;; `x-show-tip' looks horrible and has no way to control when the popup closes.
;; `x-popup-menu' looks horrible and is incredibly complicated.
(require 'popup)

(require 'haskell-tng-compile)
(require 'haskell-tng-rx)
(require 'haskell-tng-util)

;;;###autoload
(defun haskell-tng-fqn-at-point (&optional alt)
  "Consult the imports in scope and display the fully qualified
name of the symbol at point in the minibuffer.

A prefix argument ensures that caches are flushes."
  (interactive "P")
  (if-let* ((sym (haskell-tng--hsinspect-symbol-at-point))
            (found (haskell-tng--hsinspect-qualify
                    (haskell-tng--hsinspect-imports nil alt)
                    sym)))
      ;; TODO multiple hits
      ;; TODO add type information from the index when available
      (popup-tip (format "%s" found)))
  (user-error "Not found"))

;;;###autoload
(defun haskell-tng-jump-to-definition (&optional alt)
  "Consult the `imports' in scope to calculate the symbol at point,
then find the package using the `index', then visit the
definition of the symbol in the build tool's source archive."
  (interactive "P")
  ;; TODO better error reporting when any of these things fail
  (when-let* ((imports (haskell-tng--hsinspect-imports nil alt))
              (index (haskell-tng--hsinspect-index alt))
              ;; TODO imports and index can be calculated in parallel
              (sym (haskell-tng--hsinspect-symbol-at-point))
              (found (haskell-tng--hsinspect-qualify imports sym)))
    (pcase-let* ((`(,imported . ,name) (haskell-tng--string-split-last found "."))
                 (`(,srcid . ,module) (haskell-tng--hsinspect-follow index nil imported name))
                 (`(,pkg . _) (haskell-tng--hsinspect-index-get-module index srcid module) )
                 (inplace (alist-get 'inplace pkg))
                 (tarball (haskell-tng--hsinspect-srcid-source srcid))
                 (file (concat
                        ;; TODO string-replace would be nice...
                        (mapconcat 'identity (split-string module (rx ".")) "/" )
                        ".hs")))
      (if inplace
          ;; TODO support local / git packages by consulting `plan.json'
          ;; TODO or should we error until it is supported properly?
          (xref-find-definitions name)
        (when (not (file-exists-p tarball))
          ;; We can't expect stack to reveal source locations because it
          ;; obfuscates all downloads. Cabal has "cabal get" but it is broken.
          ;; WORKAROUND https://github.com/haskell/cabal/issues/6443
          (let ((remote (haskell-tng--hsinspect-hackage-source srcid))
                (dir (file-name-directory tarball)))
            (unless (file-directory-p dir)
              (make-directory dir t))
            (message "%s was not found, attempting to download %s" tarball remote)
            (url-copy-file remote tarball)))
        (message "Loading %s from %s" sym tarball)
        (find-file tarball)
        ;; TODO it would be a faster UX if we used ZIP instead of TAR.GZ because
        ;;      this requires us to decompress the entire file to find the index,
        ;;      and then again until we reach the entry we want to load. But that
        ;;      would come with the cost of recompressing, plus the storage cost
        ;;      of caching it all.
        (let ((archive (current-buffer)))
          (goto-char (point-min))
          (re-search-forward (rx-to-string `(: (* any) ,file)))
          ;; TODO could set the index cache variable to the one we used for the
          ;;      search, if it provided any useful features.
          (tar-extract)
          (kill-buffer archive)
          (read-only-mode 1)
          (goto-char (point-min))
          ;; TODO re-use the imenu top-level parser, this is a massive hack
          (re-search-forward (rx line-start "import" word-end) nil t)
          (or
           (re-search-forward (rx-to-string `(: (| bol "| " "data " "type " "class ") ,name symbol-end)) nil t)
           (re-search-forward (rx-to-string `(: symbol-start ,name symbol-end)))))))))

(defun haskell-tng--string-split-last (str sep)
  "Return `(front . back)' of a STR split on the last SEP."
  ;; TODO optimise
  (let* ((parts (split-string str (regexp-quote sep)))
         (front (mapconcat 'identity (butlast parts) sep))
         (back (car (last parts))))
    (cons front back)))

(defun haskell-tng--hsinspect-srcid-source (srcid)
  (message "[haskell-tng] [DEBUG] tarball %s" srcid)
  (pcase-let ((`(,package . ,version) (haskell-tng--string-split-last srcid "-")))
    (expand-file-name
     (concat
      "~/.cabal/packages/hackage.haskell.org/"
      package "/" version "/" srcid
      ".tar.gz"))))

(defun haskell-tng--hsinspect-hackage-source (srcid)
  (concat "http://hackage.haskell.org/package/" srcid "/" srcid ".tar.gz"))

;; TODO haskell-tng-show-documentation

(defvar-local haskell-tng-hsinspect-as
  ;; TODO populate with even more than this
  '(("Data.Aeson" . "Json")
    ("Data.List" . "L")
    ("Data.List.NonEmpty" . "NE")
    ("Data.Map.String" . "M")
    ("Data.ByteString" . "BS")
    ("Data.ByteString.Lazy" . "LBS")
    ("Data.Text" . "T"))
  "An alist of (MODULE . NAME) to use for qualified imports.")
(put 'haskell-tng-hsinspect-as 'safe-local-variable #'listp)
(defun haskell-tng--hsinspect-as (module)
  (or
   (alist-get module haskell-tng-hsinspect-as nil nil 'equal)
   (read-string
    (concat "import qualified " module " as ")
    (car (last (split-string module (regexp-quote ".")))))))

(defcustom haskell-tng-hsinspect-qualify nil
  "`haskell-tng-import-symbol-at-point' will prefer qualified imports."
  :type 'booleanp
  :group 'haskell-tng)

;;;###autoload
(defun haskell-tng-import-symbol-at-point (&optional alt)
  "Import the symbol at point by querying the user to select from a menu.

If the symbol is qualified, the module will be imported
qualified.

If called with a `-' prefix, the module will be imported
qualified and the user will be asked for the name (behaviour is
reversed if `haskell-tng-hsinspect-qualify' is set).

Respects the `C-u' cache invalidation convention."
  (interactive "P")
  ;; TODO add parens around operators (or should that be in the utility?)
  (let (qual
        (flush-cache (and alt (not (eq '- alt)))))
    (when-let ((index (haskell-tng--hsinspect-index flush-cache))
               (sym (haskell-tng--hsinspect-symbol-at-point)))
      (message "Searching for '%s' in %s packages" sym (length index))

      (when (string-match (rx bos (group (+ anything)) "." (group (+ (not (any ".")))) eos) sym)
        (setq qual (match-string 1 sym))
        (setq sym (match-string 2 sym)))

      (when-let (hit (haskell-tng--hsinspect-import-popup index sym))
        (let* ((module (alist-get 'module hit))
               (class (alist-get 'class hit))
               (type (alist-get 'type hit))
               (name (alist-get 'name hit)))
          (cond
           (qual (haskell-tng--hsinspect-import-symbol index module qual))

           ((xor haskell-tng-hsinspect-qualify (eq '- alt))
            (when-let (as (haskell-tng--hsinspect-as module))
              (haskell-tng--hsinspect-import-symbol index module as)
              (save-excursion
                (haskell-tng--hsinspect-beginning-of-symbol)
                (insert as "."))))

           ((eq class 'tycon)
            (haskell-tng--hsinspect-import-symbol
             index
             module nil
             (haskell-tng--hsinspect-return-type type)))

           ((eq class 'con)
            (haskell-tng--hsinspect-import-symbol
             index
             module nil
             (concat (haskell-tng--hsinspect-return-type type) "(..)")))

           (t (haskell-tng--hsinspect-import-symbol index module nil name)))))
      )))

(defun haskell-tng--hsinspect-extract-imports (index module &optional as sym)
  "Calculates the imports from INDEX that are implied by MODULE AS and SYM."
  ;; TODO a nested seq-mapcat threaded syntax
  (if sym
      `(((local . ,sym) (full . ,(concat module "." sym))))
    (seq-mapcat
     (lambda (pkg-entry)
       (seq-mapcat
        (lambda (module-entry)
          (when (equal module (alist-get 'module module-entry))
            (seq-mapcat
             (lambda (entry)
               (let* ((name (alist-get 'name entry))
                      (type (alist-get 'type entry))
                      (id (pcase (alist-get 'class entry)
                            ((or 'id 'con 'pat) name)
                            ('tycon type)))
                      (full (concat module "." id)))
                 (if as
                     `(((qual . ,(concat as "." id))
                        (full . ,full)))
                   `(((local . ,id)
                      (full . ,full))))))
             (alist-get 'ids module-entry))))
        (alist-get 'modules pkg-entry)))
     index)))

(defun haskell-tng--hsinspect-return-type (type)
  (car
   (split-string
    (car
     (last
      (split-string
       type (rx "->" (* space))))))))

;; TODO expand out pattern matches (function defns and cases) based on the cons
;; for a type obtained from the Index.

;; TODO expand out wildcards in pattern matches. We can calculate the type by
;; looking at the names of the other data constructors that have been used.

(defun haskell-tng--hsinspect-qualify (imports sym)
  (cdar
   (last
    (seq-find
     (lambda (names) (member sym (seq-map #'cdr names)))
     imports))))

(defun haskell-tng--hsinspect-index-get-module (index srcid module)
  "Return the (pkg-entry . module-entry) for SRCID and MODULE."
  ;; TODO a more general solution that also searches for NAME would help simplify this file
  (car
   (seq-mapcat
    (lambda (pkg-entry)
      (let ((srcid_ (alist-get 'srcid pkg-entry)))
        (when (or (null srcid) (equal srcid srcid_))
          (when-let (found (seq-find
                            (lambda (module-entry)
                              (equal module (alist-get 'module module-entry)))
                            (alist-get 'modules pkg-entry)))
            (list (cons pkg-entry found))))))
    index)))

(defun haskell-tng--hsinspect-follow (index srcid module name)
  "Follow re-exports of MODULE to find which (srcid . module)
originally defined NAME.

The original module may not be exported and is therefore not
present in the index. If an unexported module exports another
unexported module's definition, we are unable to locate it."
  ;; TODO probably doesn't work for 'tycon
  ;; TODO use seq-find instead of seq-mapcat. Most uses of car . seq-mapcat in this
  ;;      file would be more efficient with something that flatmaps and takes
  ;;      the first element, without evaluating the rest.
  ;; TODO `hsinspect index' could evaluate all re-exports to their final destination
  (when srcid
    (message "[haskell-tng] [DEBUG] follow %s %s %s" srcid module name))
  (or
   (when-let*
       ((found (haskell-tng--hsinspect-index-get-module index srcid module))
        (pkg-entry (car found))
        (srcid_ (alist-get 'srcid pkg-entry))
        (module-entry (cdr found)))
     (car
      (seq-mapcat
       (lambda (entry)
         (let ((id (pcase (alist-get 'class entry)
                     ((or 'id 'con 'pat) (alist-get 'name entry))
                     ('tycon (alist-get 'type entry)))))
           (when (equal id name)
             (if-let* ((export (alist-get 'export entry))
                       (from (alist-get 'module export))
                       (pkg (or (alist-get 'srcid export) srcid_)))
                 (list (haskell-tng--hsinspect-follow index pkg from name))
               (list (cons srcid_ module))))))
       (alist-get 'ids module-entry))))
   (cons srcid module)))

(defun haskell-tng--hsinspect-import-popup (index sym)
  (when-let ((hits (haskell-tng--hsinspect-import-candidates index sym)))
    ;; TODO special case one hit
    ;; TODO show more context, like the type
    (when-let* ((entries (mapcar (lambda (el) (alist-get 'module el)) hits))
                (selected (popup-menu* entries)))
      (seq-find (lambda (el) (equal (alist-get 'module el) selected)) hits))))

;; TODO when the same name is reused as a type and data constructor we show dupe
;; entries to the user. We should dedupe that to just the cons unless we have a
;; way to make the choice clearer.
(defun haskell-tng--hsinspect-import-candidates (index sym)
  "Return an list of alists with keys: module, name, type.
When using hsinspect-0.0.8, also: class, export, flavour.
When using hsinspect-0.0.9, also: srcid."
  ;; TODO threading/do syntax
  ;; TODO alist variable binding like RecordWildcards
  (seq-mapcat
   (lambda (pkg-entry)
     (let ((srcid (alist-get 'srcid pkg-entry))
           (modules (alist-get 'modules pkg-entry)))
       (seq-mapcat
        (lambda (module-entry)
          (let ((module (alist-get 'module module-entry))
                (ids (alist-get 'ids module-entry)))
            (seq-mapcat
             (lambda (entry)
               (let ((name (alist-get 'name entry))
                     (type (alist-get 'type entry))
                     (class (alist-get 'class entry))
                     (export (alist-get 'export entry))
                     (flavour (alist-get 'flavour entry)))
                 (when (or (equal name sym) (equal type sym))
                   `(((srcid . ,srcid)
                      (module . ,module)
                      (name . ,name)
                      (type . ,type)
                      (class . ,class)
                      (export . ,export)
                      (flavour . ,flavour))))))
             ids)))
        modules)))
   index))

(defun haskell-tng--hsinspect-symbol-at-point ()
  "A `symbol-at-point' that includes FQN parts."
  (buffer-substring-no-properties
   (save-excursion
     (haskell-tng--hsinspect-beginning-of-symbol)
     (point))
   (save-excursion
     (re-search-forward
      (rx point (+ (| word (syntax symbol) ".")) symbol-end)
      (line-end-position) 't)
     (point))))

(defun haskell-tng--hsinspect-beginning-of-symbol ()
  (let ((lbp (line-beginning-position)))
    ;; can't use `smie-backward-token-function' because we could be at the start,
    ;; middle, or end.
    (re-search-backward
     (rx symbol-start (+ (| word (syntax symbol) ".")) point)
     lbp 't)
    ;; WORKAROUND non-greedy matches
    (while (looking-back haskell-tng--rx-c-qual lbp 't)
      (goto-char (match-beginning 0)))))

(defun haskell-tng--hsinspect-ghcflags ()
  ;; https://github.com/haskell/cabal/issues/6203
  "Obtain the ghc flags for the current buffer"
  (if-let (default-directory (locate-dominating-file default-directory ".ghc.flags"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name ".ghc.flags"))
        (split-string
         (buffer-substring-no-properties (point-min) (point-max))))
    (user-error "Could not find `.ghc.flags': add GhcFlags.Plugin and compile.")))

(defvar-local haskell-tng--hsinspect-imports nil)
(defun haskell-tng--hsinspect-imports (&optional no-work flush-cache)
  (haskell-tng--util-cached
   (lambda () (haskell-tng--hsinspect flush-cache "imports" buffer-file-name))
   'haskell-tng--hsinspect-imports
   (concat "hsinspect-0.0.7" buffer-file-name "." "imports")
   no-work
   flush-cache))

(defun haskell-tng--hsinspect-import-symbol (index module as &optional sym)
  "Add the import to the current buffer and update `haskell-tng--hsinspect-imports'.

Does not persist the cache changes to disk."
  (haskell-tng--util-import-symbol module as sym)
  (let ((updates (haskell-tng--hsinspect-extract-imports index module as sym)))
    (setq haskell-tng--hsinspect-imports
          (append haskell-tng--hsinspect-imports updates))))

;; TODO add a package-wide variable cache
(defun haskell-tng--hsinspect-index (&optional flush-cache)
  (when-let (ghcflags-dir
             (locate-dominating-file default-directory ".ghc.flags"))
    (haskell-tng--util-cached-disk
     (lambda () (haskell-tng--hsinspect flush-cache "index"))
     (concat "hsinspect-0.0.7" (expand-file-name ghcflags-dir) "index")
     nil
     flush-cache)))

;; TODO add a project-wide variable cache
(defun haskell-tng--hsinspect-exe (&optional flush-cache)
  "The cached binary to use for `hsinspect'"
  (when-let (package-dir (or
                          (haskell-tng--util-locate-dominating-file
                           haskell-tng--compile-dominating-project)
                          (haskell-tng--util-locate-dominating-file
                           haskell-tng--compile-dominating-package)))
    (haskell-tng--util-cached-disk
     #'haskell-tng--hsinspect-which-hsinspect
     (concat "which" (expand-file-name package-dir) "hsinspect")
     nil
     flush-cache)))

;; TODO discover the PATH from the build tool and set it when calling hsinspect

(defvar haskell-tng--hsinspect-which-hsinspect
  "cabal build -v0 :pkg:hsinspect:exe:hsinspect && cabal exec -v0 which -- hsinspect")
(defun haskell-tng--hsinspect-which-hsinspect ()
  "Finds and checks the hsinspect binary for the current buffer.

This is uncached, prefer `haskell-tng--hsinspect-exe'."
  (let ((supported '("0.0.7" "0.0.8" "0.0.9" "0.0.10" "0.0.11"))
        (bin
         (car
          (last
           (split-string
            (string-trim
             (shell-command-to-string
              haskell-tng--hsinspect-which-hsinspect))
            "\n")))))
    (if (file-executable-p bin)
        (let ((version
               (string-trim
                (shell-command-to-string (concat bin " --version")))))
          (if (member version supported)
              ;; TODO from 0.0.8+ do a --ghc-version check (a common failure mode)
              bin
            (user-error "The hsinspect binary is the wrong version: got `%s' require `%s'" version supported)))
      (user-error "The hsinspect binary is not executable: %S" bin))))

(defun haskell-tng--hsinspect (flush-cache &rest params)
  (ignore-errors (kill-buffer "*hsinspect*"))
  (when-let ((ghcflags (haskell-tng--hsinspect-ghcflags))
             (default-directory (haskell-tng--util-locate-dominating-file
                                 haskell-tng--compile-dominating-package)))
    (if (/= 0
            (let ((process-environment (cons "GHC_ENVIRONMENT=-" process-environment)))
              (apply
               #'call-process
               (or (haskell-tng--hsinspect-exe flush-cache)
                   (user-error "Could not find hsinspect: add to build-tool-depends"))
               nil "*hsinspect*" nil
               (append params '("--") ghcflags))))
        (user-error "Failed, see *hsinspect* buffer for more information")
      (with-current-buffer "*hsinspect*"
        ;; TODO remove this resilience against stdout / stderr noise
        (goto-char (point-max))
        (backward-sexp)
        (ignore-errors (read (current-buffer)))))))

(defun haskell-tng-hsinspect (&optional alt)
  "Fill the `hsinspect' caches"
  (interactive "P")
  (haskell-tng--hsinspect-imports nil alt)
  (haskell-tng--hsinspect-index alt))

(provide 'haskell-tng-hsinspect)
;;; haskell-tng-hsinspect.el ends here
