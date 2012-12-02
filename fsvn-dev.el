;;; fsvn-dev.el --- Experimental implementation.

;;; History:
;;

;;; Commentary:
;;

;;; Code:




(defvar fsvn-log-analyze-alist
  '(
    ("day" "%y-%m-%d" "%m-%d")
    ("week" "%y-%W" "%y(%W)")
    ("hour" "%H" "%H")
    ("week-day" "%w" "%w(%a)") ;; TODO for sorting
    ))
;;TODO chart by date, commit-user

;;TODO sort
;;     fill empty date.
(defun fsvn-log-analyze (key-format disp-format)
  (interactive
   (let ((setting (assoc
                   (completing-read "Analyze type: " fsvn-log-analyze-alist)
                   fsvn-log-analyze-alist)))
     (list (nth 1 setting) (nth 2 setting))))
  (require 'chart)
  (let ((inhibit-read-only t)
        alist)
    (mapcar
     (lambda (logentry)
       (let* ((date (fsvn-xml-log->logentry=>date$ logentry))
              (key (format-time-string key-format date))
              (disp (format-time-string disp-format date))
              (cell (assoc key alist)))
         (unless cell
           (setq cell (list key disp 0))
           (setq alist (cons cell alist)))
         ;; update count cell
         (setcar (nthcdr 2 cell) (incf (nth 2 cell)))))
     fsvn-log-list-entries)
    (chart-bar-quickie
     'vertical "Fsvn Log Analyze"
     (mapcar (lambda (x) (nth 1 x)) alist) "Date"
     (mapcar (lambda (x) (nth 2 x)) alist) "Commit Count"
     ;;TODO
     200
     (lambda (a b) (string-lessp (car a) (car b)))))
  (setq buffer-read-only t)
  (set-buffer-modified-p nil))



;; cherry-pick



;; destination url -> msgedit
;; mv -> switch
(defun fsvn-browse-move-this-in-repository (src-file to-url &optional args)
  "Execute `move' to repository file corresponding local file.
Optional ARGS (with \\[universal-argument]) means read svn subcommand arguments.
"
  (interactive)
  )

;;TODO
;; (defun fsvn-browse-copy-path-in-repository (to-url &optional args)
;;   "Execute `copy' to repository file corresponding current directory.
;; Optional ARGS (with \\[universal-argument]) means read svn subcommand arguments.

;; This makes faster copy than in working copy.
;; "
;;   (interactive)
;;   (fsvn-browse-copy-this-in-repository (fsvn-browse-current-repository-url) to-url args))



(defun fsvn-browse-cmd-read-diff-between-repository ()
  (let ((default (fsvn-browse-point-repository-urlrev))
        urlrev1 urlrev2 args)
    (fsvn-brief-message-showing
     (setq urlrev1 (fsvn-completing-read-urlrev "URL1: " default t))
     (fsvn-brief-message-add-message (format "URL1: %s" urlrev1))
     (setq urlrev2 (fsvn-completing-read-urlrev "URL2: " urlrev1 t))
     (fsvn-brief-message-add-message (format "URL2: %s" urlrev2))
     (setq args (fsvn-cmd-read-subcommand-args "diff" fsvn-default-args-diff))
     (list urlrev1 urlrev2 args))))

;;TODO between different repository
;;TODO easy menu
;; bound to = r
(defun fsvn-browse-diff-between-repository (src-urlrev dest-urlrev &optional args)
  "Execute `diff' between SRC-URLREV and DEST-URLREV.
Optional ARGS (with \\[universal-argument]) means read svn subcommand arguments.
"
  (interactive (fsvn-browse-cmd-read-diff-between-repository))
  (fsvn-diff-start-process src-urlrev dest-urlrev args))

(add-hook 'fsvn-browse-mode-hook
          (lambda ()
            (define-key fsvn-browse-diff-map "r" 'fsvn-browse-diff-between-repository)))

(add-hook 'fsvn-log-list-mode-hook
          (lambda ()
            (define-key fsvn-log-list-mode-map "\C-c\C-s" 'fsvn-log-list-diff-search-backward)
            ))



(defvar fsvn-log-list-diff-searched nil)

(add-to-list 'fsvn-log-list-buffer-local-variables
             '(fsvn-log-list-diff-searched))

(defun fsvn-log-list-diff-search-backward (regexp &optional fuzzy)
  "Search REGEXP current log list match to diff between two revision.
Optional arg FUZZY non-nil means match to all diff message."
  (interactive
   (list
    (fsvn-log-list-read-search-regexp)
    current-prefix-arg))
  (let ((targetp (if fuzzy
                     (lambda () t)
                   (lambda ()
                     (save-excursion
                       (forward-line 0)
                       (save-match-data
                         (looking-at "^[+-]"))))))
        rev)
    ;; next line to continue searching
    (when (equal fsvn-log-list-diff-searched regexp)
      (fsvn-log-list-next-line))
    (if (catch 'found
          (while (and (setq rev (fsvn-log-list-point-revision))
                      (not (eobp)))
            (message "Searching revision %s..." rev)
            (let* ((buffers (buffer-list)) ; preserve initial buffers
                   (proc (fsvn-log-list-diff-previous))
                   (buffer (process-buffer proc)))
              ;; wait until diff finishes.
              (while (not (memq (process-status proc) '(exit signal)))
                (sit-for 0.1))
              ;;TODO log message too? sibling filename too?
              (when (buffer-live-p buffer)
                (save-selected-window
                  (select-window (get-buffer-window buffer))
                  (goto-char (point-min))
                  (while (re-search-forward regexp nil t)
                    (when (funcall targetp)
                      ;; colorize
                      (let ((ov (make-overlay (match-beginning 0) (match-end 0))))
                        (overlay-put ov 'face fsvn-match-face))
                      ;;TODO delete overlay?
                      ;; (let ((next-event
                      ;;        (let ((inhibit-quit t))
                      ;;          (read-event))))
                      ;;   (setq unread-command-events (list next-event)))
                      (throw 'found t))))
                ;; cleanup buffer if buffer initially not exists.
                (unless (memq buffer buffers)
                  (kill-buffer buffer)))
              (fsvn-log-list-next-line))))
        (progn
          (setq fsvn-log-list-diff-searched regexp)
          (message "Match found."))
      (message "Not found.")
      (setq fsvn-log-list-diff-searched nil))))



(defun fsvn-vc-diff (&optional args)
  "Diff current file or current directory."
  (interactive
   (let ((args (fsvn-cmd-read-subcommand-args "diff" fsvn-default-args-diff)))
     (list args)))
  (let ((file (or buffer-file-name
                  default-directory)))
    (unless file
      (error "Buffer is not associated with a file"))
    (unless (fsvn-deps-file-registered-p file)
      (error "Buffer file is not under versioned"))
    (fsvn-diff-start-process file)))



;;TODO bound to C-c ! fsvn-command to which key?

(defun fsvn-browse-do-command (subcommand args)
  "Execute `svn SUBCOMMAND ARGS'"
  (interactive (let* ((subcommand (fsvn-read-svn-subcommand))
                      (args (fsvn-read-svn-subcommand-args subcommand)))
                 (list subcommand args)))
  (fsvn-popup-start-process subcommand args))


;;TODO
(defun fsvn-browse-merge-from-branch ()
  (interactive)
  )



(defcustom fsvn-browse-guessed-moved-parent-threshold 4
  ""
  :group 'fsvn
  :type 'integer)

(defun fsvn-browse-file-name-parent-directory (file max-level)
  (let ((tmp (fsvn-file-name-directory (directory-file-name file)))
        (i 0))
    (while (and (fsvn-directory-under-versioned-p (fsvn-file-name-directory tmp))
                (< i max-level))
      (setq tmp (fsvn-file-name-directory tmp))
      (setq i (1+ i)))
    tmp))

(defun fsvn-browse-search-guessed-moved-files (file file-versioned-p)
  (let ((dir (fsvn-browse-file-name-parent-directory file fsvn-browse-guessed-moved-parent-threshold)))
    (fsvn-mapitem
     (lambda (f)
       (let ((versioned (fsvn-deps-file-registered-p f)))
         (cond
          ((and file-versioned-p versioned))
          ((and (not file-versioned-p) (null versioned)))
          (t
           f))))
     ;;TODO hard-coding
    (fsvn-search-same-name-files dir file (+ fsvn-browse-guessed-moved-parent-threshold 2)))))

;;TODO change electric-select-file to be able to show message
(defun fsvn-browse-cmd-read-search-move/copy-file ()
  ;; (fsvn-browse-cmd-wc-only
   (let ((target-file (fsvn-browse-cmd-this-wc-file))
         files src-file dest-file
         target-versioned-p alist)
     (setq target-versioned-p (fsvn-deps-file-registered-p target-file))
     (if target-versioned-p
         (setq src-file target-file)
       (setq dest-file target-file))
     (setq files (fsvn-browse-search-guessed-moved-files target-file target-versioned-p))
     (while files
       (if target-versioned-p
           (setq dest-file (car files))
         (setq src-file (car files)))
       (setq alist (cons (cons src-file dest-file) alist))
       (setq files (cdr files)))
     alist))

(defun fsvn-browse-search-moved/copied-file (src-file dest-file copy-p)
  (interactive (fsvn-browse-cmd-read-search-move/copy-file))
  (fsvn-browse-wc-only
   (if copy-p
       (fsvn-browse-safe-copy-this src-file dest-file)
     (fsvn-browse-safe-move-this src-file dest-file))))



(defun fsvn-browse-stash-path ()
  (interactive)
  )

(defun fsvn-browse-stash-pop-path ()
  (interactive)
  )

(defun fsvn-stash-pop-read-time (directory)
  (let ((times (mapcar
                (lambda (tm)
                  (cons (format-time-string "%Y-%m-%d %H:%M:%S" tm) nil))
                (fsvn-stash-pop-directory-times directory))))
    (completing-read "TODO: " times)))

;;TODO stash-push and change and commit files.
;;     merge with stashed files
;;    patch and merge??
(defun fsvn-stash-pop (directory &optional time)
  (let* ((stashdir (fsvn-stash-pop-directory directory time)))
    (unless stashdir
      (error "No stashed directory"))
    ;;TODO copy stashdir to directory
    (fsvn-delete-directory stashdir)
    (when (file-directory-p stashdir)
      ;; delete if empty
      (unless (directory-files stashdir nil dired-re-no-dot)
        (delete-directory stashdir)))))

(defun fsvn-stash-push (directory)
  (let* ((stashdir (fsvn-stash-pushing-directory directory))
         (stashdirs (fsvn-stash-pushing-directories stashdir)))
    (unless (file-directory-p stashdir)
      (make-directory stashdir t))
    ;;TODO copy changed file and .svn
    (fsvn-copy-directory directory (car stashdirs))))

(defun fsvn-stash-pushing-directories (stashdir &optional time)
  (list
   (fsvn-expand-file "files" stashdir)
   (fsvn-expand-file "status" stashdir)))

(defun fsvn-stash-pushing-directory (directory &optional time)
  (let* ((stashdir (fsvn-expand-file (format-time-string "%s" time)
                                     (fsvn-stash-hash-directory directory))))
    stashdir))

(defun fsvn-stash-pop-directory (directory &optional time)
  (let ((dir
         (if time
             (fsvn-stash-pushing-directory directory time)
           (car (fsvn-stash-pop-directories directory)))))
    (when (and dir (file-exists-p dir))
      dir)))

(defun fsvn-stash-pop-directories (directory)
  (let* ((dir (fsvn-stash-hash-directory directory))
         (files (directory-files dir nil dired-re-no-dot)))
    (mapcar
     (lambda (sec)
       (fsvn-expand-file (format "%d" sec) dir))
     (sort
      (remove nil
              (mapcar
               (lambda (name)
                 (when (string-match "^[0-9]+$" name)
                   (string-to-number name)))
               files))
      '>))))

(defun fsvn-stash-pop-directory-times (directory)
  (mapcar
   (lambda (file)
     (let ((sec (string-to-number (fsvn-file-name-nondirectory file))))
       (seconds-to-time sec)))
   (fsvn-stash-pop-directories directory)))

(defun fsvn-stash-hash-directory (directory)
  (let ((dir (directory-file-name directory)))
    (fsvn-expand-file (md5 dir) (fsvn-stash-directory))))

(defun fsvn-stash-directory ()
  "Backup directory."
  (fsvn-expand-file "stash" fsvn-home-directory))

(defun fsvn-copy-file-tree (base-directory src-files dest-directory &optional ok-if-exists)
  (let ((files
         (mapcar
          (lambda (src)
            ;;TODO check traversal
            (fsvn-file-relative src base-directory))
          src-files)))
    (mapc
     (lambda (file)
       (let* ((src (fsvn-expand-file file base-directory))
              (dest (fsvn-expand-file file dest-directory))
              (dir (fsvn-file-name-directory2 dest)))
         (unless (file-directory-p dir)
           (make-directory dir t))
         (copy-file src dest ok-if-exists t)))
     files)
    nil))


;;TODO stash delete and other svn status

;;TODO
;;(add-to-list 'fsvn-temp-directory-dirs "stash")


;; testing

(defconst fsvn-xml-accessor-prefix "fsvn-xml-")

(defun fsvn-xml-create-accessor (dtd paren multi-nodes)
  (let* ((base-nodes (append paren (list (car dtd))))
         (base-name (concat fsvn-xml-accessor-prefix (fsvn-xml-create-accessor-node base-nodes multi-nodes)))
         (attrs (fsvn-xml-node-attributes dtd))
         (name (symbol-name (car dtd)))
         (children (fsvn-xml-node-children dtd)))
    (list
     (mapcar
      (lambda (attr)
        (concat base-name  "." (symbol-name (car attr))))
      attrs)
     (cond
      ((atom children)
       (concat fsvn-xml-accessor-prefix (fsvn-xml-create-accessor-node paren multi-nodes) "=" name))
      (t
       (mapcar
        (lambda (child)
          (fsvn-xml-create-accessor child base-nodes multi-nodes))
        children))))))

(defun fsvn-xml-create-accessor-node (paren multi-nodes)
  (let (seq)
    (setq seq (fsvn-xml-accessor-multi-most-match paren multi-nodes))
    (cond
     ((or (null seq)
          (equal seq paren))
      (mapconcat 'symbol-name paren "->"))
     (t
      (mapconcat 'symbol-name seq "=>")))))

(defun fsvn-xml-accessor-multi-most-match (nodes multi-nodes)
  (let (max)
    (mapc
     (lambda (seq)
       (let ((len (length seq))
             (i 0)
             node)
         (catch 'unmatch
           (while (< i len)
             (setq node (nth i nodes))
             (unless (eq node (nth i seq))
               (throw 'unmatch t))
             (setq i (1+ i)))
           (when (> len (length max))
             (setq max seq)))))
     multi-nodes)
    max))



;; TODO grep svn log
;;  async incremental search? what ui is?



(defvar fsvn-bugreport-mail-address "mhayashi1120@gmail.com")

;;TODO
(defvar fsvn-bugreport-salutation
  "
# If you are a Japanese, please write in Japanese.

Describe bug below, using a precise recipe.

When I executed M-x ...

How to send a bug report:
  1) Be sure to use the LATEST version of fsvn*.el.
  2) Enable debugger. M-x toggle-debug-on-error or (setq debug-on-error t)
  3) Use Lisp version instead of compiled one: (load \"fsvn.el\")
  4) If you got an error, please paste *Backtrace* buffer.
  5) Type C-c C-c to send.
")

(defun fsvn-bugreport ()
  (interactive)
  (let ((pkgname "fsvn.el"))
    (reporter-submit-bug-report
     fsvn-maintainer-mail-address
     pkgname
     (apropos-internal "^fsvn-" 'boundp)
     nil nil fsvn-bugreport-salutation)
    (mail-position-on-field "subject")
    (insert pkgname "; Bug report" )
    (unless (y-or-n-p
             (concat
              "This bug report may contain privacy information (Like password).\n"
              "Please delete manually. OK? " ))
      (set-buffer-modified-p nil)
      (kill-buffer (current-buffer)))))



;; ~/.fsvn/cache/log/{root-hash}
;; ~/.fsvn/cache/log/{root-hash}/revs
;; ~/.fsvn/cache/log/{root-hash}/revs/{1,2,3,....N}
;; ~/.fsvn/cache/log/{root-hash}/index/{path-hash}....

(defun fsvn-log-cache-create (root path entries)
  )

(defun fsvn-log-cache-search (urlrev root rev-range count)
  )

(defun fsvn-log-cache-clenup (root)
  )



(defun fsvn-cache-repository-directory ()
  "Repository directory."
  (fsvn-expand-file "repository" (fsvn-cache-directory)))

(defun fsvn-cache-repository-uuid-directory (uuid)
  (fsvn-expand-file (downcase uuid) (fsvn-cache-repository-directory)))

(defun fsvn-cache-repository-exists-p (uuid)
  (let ((repos (fsvn-cache-repository-uuid-directory uuid)))
    (file-directory-p repos)))

(defun fsvn-cache-uuid-repository (uuid)
  (let* ((repos (fsvn-cache-repository-uuid-directory uuid))
         (url (fsvn-directory-name-as-repository repos)))
    (unless (and (file-directory-p repos)
                 (> (length (directory-files repos nil dired-re-no-dot)) 0))
      (make-directory repos t)
      (fsvn-admin-call-command-discard "create" nil repos)
      (fsvn-admin-call-command-discard "setuuid" nil repos uuid)
      (fsvn-admin-create-empty-hook repos "pre-revprop-change"))
    url))

(defun fsvn-cache-enable-p ()
  (and fsvn-svnsync-command-internal
       (executable-find fsvn-svnsync-command-internal)))

(defun fsvn-cache-initialize-repository (url &optional root uuid)
  (unless (and root uuid)
    (let* ((info (fsvn-get-info-entry url)))
      (setq uuid (fsvn-xml-info->entry=>repository=>uuid$ info)
            root (fsvn-xml-info->entry=>repository=>root$ info))))
  (let* ((cached-url (fsvn-cache-uuid-repository uuid))
         (info (fsvn-get-info-entry cached-url)))
    (unless (and info (> (fsvn-xml-info->entry.revision info) 0))
      ;; No costed execute. sync process.
      (with-temp-buffer
        (unless (= (call-process fsvn-svnsync-command-internal nil (current-buffer) nil "initialize" cached-url root) 0)
          (signal 'fsvn-command-error (cons (buffer-string) nil)))))
    cached-url))

(defun fsvn-cache-mirror-start (url &optional root uuid)
  (let* ((cached-url (fsvn-cache-initialize-repository url root uuid))
         (buffer (fsvn-make-temp-buffer))
         proc)
    (fsvn-process-environment
     (setq proc (start-process "fsvn" buffer fsvn-svnsync-command-internal "synchronize" cached-url)))
    (set-process-sentinel proc
                          (lambda (p e)
                            (fsvn-process-exit-handler p e
                              (kill-buffer (process-buffer p)))))
    (set-process-filter proc (lambda (p e)))
    proc))

(defun fsvn-cache-start-command (subcommand buffer &rest args)
  (apply 'fsvn-start-command subcommand buffer args))



(define-minor-mode fsvn-log-diff-minor-mode
  ""
  nil nil nil
  )

;;TODO advice to fsvn-log-list-draw-details?
;; fsvn-log-list-subwindow-display-p
;; fsvn-log-list-draw-details
;; fsvn-log-list-set-subwindow-config

(defvar fsvn-log-list-diffs nil)

(defun fsvn-log-diff-turn-on ()
  ;;TODO
  )

(define-globalized-minor-mode fsvn-log-diff-global-minor-mode fsvn-log-diff-minor-mode
  fsvn-log-diff-turn-on
  )



;;TODO git -> svn
;; change svn:date revprop
;; this means can sort to svn:date in log-list



(defconst fsvn-proplist2-buffer-local-variables
  '(
    (font-lock-defaults . '(fsvn-proplist-font-lock-keywords t nil nil beginning-of-line))
    ;;TODO
    (revert-buffer-function . 'fsvn-proplist2-revert-buffer)
    (fsvn-buffer-repos-info)
    ;; TODO
    (fsvn-proplist-target-mode)
    ))

(defun fsvn-proplist2-mode ()
  "Major mode for browsing Subversion properties.

Entry to this mode calls the value of `fsvn-proplist2-mode-hook'.

Keybindings:
\\{fsvn-proplist-mode-map}
"
  (fsvn-global-initialize-mode)
  (use-local-map fsvn-proplist-mode-map)
  (setq major-mode 'fsvn-proplist-mode)
  (setq mode-name "Fsvn Property List")
  (setq truncate-lines t)
  (setq buffer-undo-list t)
  (fsvn-make-buffer-variables fsvn-proplist2-buffer-local-variables)
  (fsvn-proplist-setup-mode-line)
  (run-mode-hooks 'fsvn-proplist-mode-hook))

(defconst fsvn-proplist-line-process
  '(
    (fsvn-proplist-main-process " Getting properties... ")
    ))

(defun fsvn-proplist-setup-mode-line ()
  (or (assq 'fsvn-proplist-main-process mode-line-process)
      (setq mode-line-process
            (append fsvn-proplist-line-process mode-line-process))))

(defun fsvn-proplist-start-process ()
  (let* ((buffer (fsvn-make-temp-buffer))
         (proc (fsvn-start-command "proplist" buffer
                                   "--xml"
                                   "--recursive"
                                   ".")))
    (set-process-filter proc 'fsvn-proplist-process-filter)
    (set-process-sentinel proc 'fsvn-proplist-process-sentinel)
    (process-put proc 'fsvn-proplist-buffer (current-buffer))
    (setq fsvn-proplist-main-process proc)
    proc))


(defvar fsvn-proplist-main-process nil)
;;TODO local

(defun fsvn-proplist-process-filter (proc event)
  (fsvn-process-event-handler proc event
    (goto-char (process-mark proc))
    (insert-before-markers event)
    (goto-char (point-min))
    (let (targets start end)
      ;;FIXME if --xml output changed..
      (while (and (re-search-forward "\\(?:^[ \t]*\\|>\\)<target" nil t)
                  (setq start (match-beginning 0))
                  (re-search-forward "^[ \t]*</target>" nil t)
                  (setq end (match-end 0)))
        (setq targets
              (cons (fsvn-xml-parse-proplist-item start end) targets))
        (delete-region (point-min) end))
      (let ((buffer (process-get proc 'fsvn-proplist-buffer)))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            ;; avoid when other process is running.
            (when (eq fsvn-proplist-main-process proc)
              (fsvn-proplist-async-draw-targets targets))))))))

(defun fsvn-proplist-process-sentinel (proc event)
  (fsvn-process-exit-handler proc event
    (let ((buffer (process-get proc 'fsvn-proplist-buffer)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (setq fsvn-proplist-main-process nil))))
    (kill-buffer (current-buffer))))


(defun fsvn-proplist-async-draw-targets (targets)
  (let* ((proc fsvn-proplist-main-process)
         buffer-read-only)
    (save-excursion
      (goto-char (point-max))
      (dolist (target targets)
        (insert " Properties on ")
        (insert (fsvn-xml-properties->target.path target))
        (insert "\n\n")
        (dolist (prop (fsvn-xml-properties->target->properties target))
          (let ((name (fsvn-xml-properties->target->property.name prop)))
            (fsvn-proplist-insert-propname name)))
        (insert "\n")))
    (set-buffer-modified-p nil)))

(defun fsvn-open-propview2-mode (info working-dir)
  (let ((win-configure (current-window-configuration)))
    ;; for proplist mode
    (with-current-buffer (fsvn-proplist-get-buffer)
      (let ((inhibit-read-only t))
        (erase-buffer))
      (fsvn-proplist2-mode)
      (setq fsvn-buffer-repos-info info)
      (setq fsvn-propview-target-urlrev working-dir)
      (setq fsvn-propview-target-directory-p t)
      (setq fsvn-previous-window-configuration win-configure)
      ;; (setq fsvn-proplist-target-mode 'properties)
      (fsvn-set-default-directory working-dir)
      (fsvn-proplist-setup-window)
      (setq fsvn-default-window-configuration (current-window-configuration))
      (setq buffer-read-only t)
      (fsvn-proplist-start-process)
      (run-hooks 'fsvn-proplist-mode-prepared-hook))
    (switch-to-buffer (fsvn-proplist-get-buffer))))


(defun fsvn-browse-propview2-mode (file)
  (let ((info fsvn-buffer-repos-info)
        (working-dir
         (if (fsvn-url-local-p file)
             (fsvn-browse-current-directory-url)
           (fsvn-browse-current-magic-directory))))
    (fsvn-open-propview2-mode info working-dir)))

(defun fsvn-browse-propview2-path ()
  "Execute `proplist' by `fsvn-proplist-mode' to current directory."
  (interactive)
  (fsvn-browse-propview2-mode
   (fsvn-browse-current-directory-url)))

(add-hook 'fsvn-browse-mode-hook
          (lambda ()
            (define-key fsvn-browse-mode-map "\C-cP" 'fsvn-browse-propview2-path)))



;; background gardian
;; status `preparing' `prepared' `invoking'?? `done'

(defvar fsvn-gardian-timer nil)

(defun fsvn-gardian-invoke ()
  )

(defvar fsvn-gardian-registered-alist nil)

(defun fsvn-gardian-register (name)
  (unless fsvn-gardian-timer
    (setq fsvn-gardian-timer)))

(defun fsvn-gardian-mode ()
  )

(defun fsvn-gardian-draw-list ()
  (mapc
   (lambda (item)
     )
   fsvn-gardian-registered-alist))




(defvar fsvn-svn-commands nil)


(defun fsvn-add-svn-command (svn admin)
  ;;TODO local bind...
  (let ((fsvn-svn-command svn)
        (fsvn-svnadmin-command admin))
    (fsvn-initialize-loading)
    (setq fsvn-svn-commands
          (cons
           (list svn admin fsvn-svn-version)
           fsvn-svn-commands))))



(defun fsvn-url-branches (urlrev)
  (fsvn-url-branches/tags urlrev "branches"))

(defun fsvn-url-tags (urlrev)
  (fsvn-url-branches/tags urlrev "tags"))

(defun fsvn-url-branches/tags (urlrev name)
  (when (string-match "^\\(.*\\)/trunk" urlrev)
    (let ((rev (or (fsvn-urlrev-revision urlrev) "HEAD"))
          (b/t (concat (match-string 1 urlrev) "/" name "/")))
      (delq nil
            (mapcar
             (lambda (entry)
               (let ((node (fsvn-xml-get-child entry 'name)))
                 (when node
                   (fsvn-xml-get-text node 0))))
             (fsvn-get-ls (fsvn-url-urlrev b/t rev)))))))



(provide 'fsvn-dev)

;;; fsvn-dev.el ends here
