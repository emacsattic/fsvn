;;; fsvn-test.el --- test for fsvn.el

;;; Commentary:
;;

;;; History:
;;

;;; Code:



(require 'fsvn)



(defmacro fsvn-test-equal (executed-form expected-value)
  "Assertion for EXECUTED-FORM and EXPECTED-VALUE is equal."
  `(let ((RET ,executed-form))
     (unless (equal RET ,expected-value)
       (error "Assertion failed. Expected `%s' but `%s'" ,expected-value RET))
     RET))

(defmacro fsvn-test-nil (executed-form)
  `(let ((RET ,executed-form))
     (when RET
       (error "Assertion failed. Expected nil but `%s'" RET))
     RET))

(defmacro fsvn-test-non-nil (executed-form)
  `(let ((RET ,executed-form))
     (unless RET
       (error "Assertion failed Expected non-nil but `nil'"))
     RET))

(defmacro fsvn-test-buffer-has (buffer regexp)
  `(progn
     (with-current-buffer ,(cond ((processp buffer) (process-buffer buffer)) (t buffer))
       (save-excursion
         (goto-char (point-min))
         (unless (re-search-forward ,regexp nil t)
           (error "Assertion failed Expected %s have not found" ,regexp))))
     buffer))

(defmacro fsvn-test-new-popup-buffer-has (regexp &rest form)
  (declare (indent 1))
  `(let ((FIRST (buffer-list)))
     (progn ,@form)
     (let ((popup
            (catch 'found
              (mapc
               (lambda (b)
                 (unless (memq b FIRST)
                   (with-current-buffer b
                     (when (eq major-mode 'fsvn-popup-result-mode)
                       (throw 'found b)))))
               (buffer-list))
              nil)))
       (when (bufferp popup)
         (fsvn-test-buffer-has popup ,regexp)))))

(defvar fsvn-test-keep-buffers nil)
(defvar fsvn-test-sit-for-interval 0)

;;FIXME or some utility?
(defmacro fsvn-test-async (&rest form)
  `(let (FSVN-TEST-ASYNC-RET)
     (mapc
      (lambda (exec-form)
        (setq FSVN-TEST-ASYNC-RET (eval exec-form))
        (when (processp FSVN-TEST-ASYNC-RET)
          ;; wait until process exit.
          (while (not (eq (process-status FSVN-TEST-ASYNC-RET) 'exit))
            (sit-for 3))
          FSVN-TEST-ASYNC-RET))
      ',form)
     FSVN-TEST-ASYNC-RET))

(defmacro fsvn-test-excursion (&rest form)
  `(if noninteractive
       (progn
         (if (eq system-type 'windows-nt)
             ;; Ignore  when Windows (NTEmacs 22 & NTEmacs 23 & Meadow 3)
             ;; Following two code not works correctly when `noninteractive' call.

             ;; 1
             ;; (let ((buf (get-buffer-create "T"))
             ;;       proc)
             ;;   (with-current-buffer buf
             ;;     (make-variable-buffer-local 'kill-buffer-hook)
             ;;     (add-hook 'kill-buffer-hook (lambda () (message "i was killed"))))
             ;;   (setq proc (start-process "A" buf "true"))
             ;;   (set-process-sentinel proc
             ;;                         (lambda (p e)
             ;;                           (let ((b (process-buffer p)))
             ;;                             (kill-buffer b))))
             ;;   (sit-for 3))

             ;; 2
             ;; (let ((proc (start-process "TEST" nil "true")))
             ;;   (while (eq (process-status proc) 'run)
             ;;     (message "%s" (process-status proc))
             ;;     (sit-for 3)))

             (message "Not works on Windows. Skipped.")
           ,@form))
     (let ((PREV-BUFFER-LIST (buffer-list))
           (PREV-BUFFER (current-buffer))
           (PREV-WIN-CONFIG (current-window-configuration))
           (INIT-PROCESS-LIST (process-list)))
       (unwind-protect
           (progn ,@form)
         (fsvn-test-wait-for-all-process INIT-PROCESS-LIST)
         (unless fsvn-test-keep-buffers
           (mapc
            (lambda (b)
              (unless (memq b PREV-BUFFER-LIST)
                (let ((process (get-buffer-process b)))
                  (when (or (null process) (eq (process-status process) 'exit))
                    (kill-buffer b)))))
            (buffer-list)))
         (switch-to-buffer PREV-BUFFER)
         (set-window-configuration PREV-WIN-CONFIG)))))

(defun fsvn-test-switch-file (wc1 wc2 file)
  (let ((r (file-relative-name file wc1)))
    (expand-file-name r wc2)))

(defun fsvn-test-sit-for ()
  "Call `sit-for' with `fsvn-test-sit-for-interval' as argument.
To show and see result.
"
  (sit-for fsvn-test-sit-for-interval))

(defun fsvn-test-wait-for-all-process (init-processes)
  (let (buffer)
    (while (catch 'wait
             (mapc
              (lambda (p)
                (unless (memq p init-processes)
                  (when (not (eq (process-status p) 'exit))
                    (throw 'wait t))
                  (when (and (setq buffer (process-buffer p))
                             (buffer-live-p buffer))
                    (throw 'wait t))))
              (process-list))
             nil)
      (sit-for 2))))

(defun fsvn-test-unbound-functions ()
  (let ((targetp (lambda (s)
                   (and (string-match "\\`fsvn-test-" (symbol-name s))
                        (functionp s)
                        (listp (symbol-function s))))))
    (mapatoms
     (lambda (s)
       (when (funcall targetp s)
         (fmakunbound s)))
     obarray)))

(defun fsvn-test-quick-commit (message dir)
  (fsvn-test-async
   (fsvn-browse-commit-path)
   (fsvn-parasite-in-message-edit
    (insert message))
   (fsvn-parasite-commit-execute)
   (dired dir)))

(when (and (not noninteractive) (require 'testcover nil t))
  (testcover-start "fsvn-browse.el")
  (testcover-start "fsvn-url.el")

  ;; (when (boundp 'ALL-MODULES)
  ;;   (mapcar 'testcover-start ALL-MODULES))
  ;; (testcover-start "fsvn-admin.el")
  ;; (testcover-start "fsvn-cmd.el")
  ;; (testcover-start "fsvn-config.el")
  ;; (testcover-start "fsvn-data.el")
  ;; (testcover-start "fsvn-env.el")
  ;; (testcover-start "fsvn-fs.el")
  ;; (testcover-start "fsvn-magic.el")
  ;; (testcover-start "fsvn-mode.el")
  ;; (testcover-start "fsvn-pub.el")
  ;; (testcover-start "fsvn-tortoise.el")
  ;; (testcover-start "fsvn-ui.el")
  )

(fsvn-test-equal (fsvn-command-args-canonicalize '("a" 1 nil ("b" 2))) '("a" "1" "b" "2"))

(fsvn-test-equal (fsvn-expand-url "c" "http://a/b") "http://a/b/c")
(fsvn-test-equal (fsvn-expand-url "c" "http://a/b/..") "http://a/c")
(fsvn-test-equal (fsvn-expand-url "c" "http://a/b/./") "http://a/b/c")
(fsvn-test-equal (fsvn-expand-url "c" "http://a/b/../../") "http://c")
(fsvn-test-equal (fsvn-expand-url "c" "http://a/../b/../") "http://c")
(fsvn-test-equal (fsvn-expand-url "http://a/b/../") "http://a")
(fsvn-test-equal (fsvn-expand-url "http://a/b/") "http://a/b")
(fsvn-test-equal (fsvn-expand-url "http://a/b") "http://a/b")

;;todo
;;(fsvn-test-equal (fsvn-expand-url "c" "http://") "http://c")

(fsvn-test-equal (fsvn-urlrev-filename "http://a/foo.el") "foo.el")
(fsvn-test-equal (fsvn-urlrev-filename (fsvn-url-urlrev "http://a/foo.el" "HEAD")) "foo.el")
(fsvn-test-equal (fsvn-urlrev-filename "http://user@a/foo.el") "foo.el")
(fsvn-test-equal (fsvn-urlrev-filename (fsvn-url-urlrev "http://user@a/foo.el" 500)) "foo.el")


;; fsvn-url-ediff-filename

(fsvn-test-equal (fsvn-url-dirname "http://a/b") "http://a/")
(fsvn-test-equal (fsvn-url-dirname "http://a/b/") "http://a/")
(fsvn-test-equal (fsvn-url-dirname "c:/a/b") "c:/a/")
(fsvn-test-equal (fsvn-url-dirname "c:/a/b/") "c:/a/")
(fsvn-test-equal (fsvn-url-dirname "/a/b") "/a/")
(fsvn-test-equal (fsvn-url-dirname "/a/b/") "/a/")

(fsvn-test-equal (fsvn-urlrev-dirname "http://a/b") "http://a/")
(fsvn-test-equal (fsvn-urlrev-dirname "http://a/b/") "http://a/")
(fsvn-test-equal (fsvn-urlrev-dirname "c:/a/b") "c:/a/")
(fsvn-test-equal (fsvn-urlrev-dirname "c:/a/b/") "c:/a/")
(fsvn-test-equal (fsvn-urlrev-dirname "/a/b") "/a/")
(fsvn-test-equal (fsvn-urlrev-dirname "/a/b/") "/a/")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "http://a/b" 5)) "http://a@5")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "http://a/b/" 5)) "http://a@5")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "c:/a/b" 5)) "c:/a@5")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "c:/a/b/" 5)) "c:/a@5")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "/a/b" 5)) "/a@5")
(fsvn-test-equal (fsvn-urlrev-dirname (fsvn-url-urlrev "/a/b/" 5)) "/a@5")

(fsvn-test-equal (fsvn-urlrev-filename (fsvn-url-urlrev "http://a/b/" 5)) "b")
(fsvn-test-equal (fsvn-urlrev-filename (fsvn-url-urlrev "http://a/b" 5)) "b")

(fsvn-test-equal (fsvn-urlrev-revision (fsvn-url-urlrev "/a/b/" 5)) "5")
(fsvn-test-equal (fsvn-urlrev-revision (fsvn-url-urlrev "/a/b" 5)) "5")
(fsvn-test-equal (fsvn-urlrev-revision (fsvn-url-urlrev "/a/b/" 5)) "5")
(fsvn-test-equal (fsvn-urlrev-revision "/a/b/") nil)

(fsvn-test-non-nil (fsvn-url-repository-p "http://a/b/c"))
(fsvn-test-non-nil (fsvn-url-repository-p "http://"))
(fsvn-test-nil (fsvn-url-repository-p "http:/"))
(fsvn-test-nil (fsvn-url-repository-p "http:"))
(fsvn-test-nil (fsvn-url-repository-p "/a/b/c"))
(fsvn-test-nil (fsvn-url-repository-p ""))
(fsvn-test-nil (fsvn-url-repository-p "c:/a/b"))

(fsvn-test-equal (fsvn-url-relative-name "http://a/b/c" "http://a/b") "c")
(fsvn-test-equal (fsvn-url-relative-name "http://a/b/c/" "http://a/b") "c/")
(fsvn-test-equal (fsvn-url-relative-name "http://a/" "http://a/b") "../")
(fsvn-test-equal (fsvn-url-relative-name "http://A/B" "http://a/b") "../../A/B")
(fsvn-test-equal (fsvn-url-relative-name "http://A/B" "http://a/b/") "../../A/B")
(fsvn-test-equal (fsvn-url-relative-name "/A/B" "http://a/b/") "/A/B")
(fsvn-test-equal (fsvn-url-relative-name "http://a/b/" "/A/B") "http://a/b/")
(fsvn-test-equal (fsvn-url-relative-name "http://a/b/" "svn://A/B") "http://a/b/")
(fsvn-test-equal (fsvn-url-relative-name "/A/B" "/a/b") "../../A/B")
(fsvn-test-equal (fsvn-url-relative-name "/A/B" "/a/b/") "../../A/B")

(fsvn-test-equal (fsvn-magic-create-name "http://a/b/c") "/fsvn@HEAD/http/a/b/c")
(fsvn-test-equal (fsvn-magic-create-name "file:///a") "/fsvn@HEAD/file/a")
(fsvn-test-equal (fsvn-magic-create-name "/a/b") "/a/b")
(fsvn-test-equal (fsvn-magic-create-name "/a/b/") "/a/b/")

(fsvn-test-equal (fsvn-magic-parse-file-name "/fsvn@10/http/a") "http://a@10")
(fsvn-test-equal (fsvn-magic-parse-file-name "/fsvn@20/file/a") "file:///a@20")
(fsvn-test-equal (fsvn-magic-parse-file-name "/fsvn@30/svn/a/") "svn://a@30")

(fsvn-test-equal (file-name-nondirectory "/fsvn@10/") "")
(fsvn-test-equal (file-name-nondirectory "/fsvn@10/a") "a")
(fsvn-test-equal (file-name-nondirectory "/fsvn@10/a/") "")

(let ((url (fsvn-url-urlrev "http://a/b/c" 10))) (fsvn-test-equal (fsvn-magic-parse-file-name (fsvn-magic-create-name url)) url))
(if (memq system-type '(windows-nt))
    (let ((url "c:/a/b/c")) (fsvn-test-equal (fsvn-magic-parse-file-name (fsvn-magic-create-name url)) url))
  (let ((url "/a/b/c")) (fsvn-test-equal (fsvn-magic-parse-file-name (fsvn-magic-create-name url)) url)))

(fsvn-test-equal (fsvn-url-as-directory "http://a/b/c") "http://a/b/c/")
(fsvn-test-equal (fsvn-url-as-directory "http://a/b/c/") "http://a/b/c/")

(fsvn-test-equal (fsvn-url-escape-revision-mark "svn://localhost/hoge") "svn://localhost/hoge")
(fsvn-test-equal (fsvn-url-escape-revision-mark "svn://localhost/hoge@") "svn://localhost/hoge@@")
(fsvn-test-equal (fsvn-url-escape-revision-mark "svn://localhost/hoge@HEAD") "svn://localhost/hoge@HEAD@")
(fsvn-test-equal (fsvn-url-escape-revision-mark "svn://localhost/hoge@HEAD@") "svn://localhost/hoge@HEAD@@")
(fsvn-test-equal (fsvn-url-escape-revision-mark (fsvn-url-urlrev "svn://localhost/hoge" "HEAD")) "svn://localhost/hoge@HEAD")


(fsvn-test-equal
 (fsvn-complete-reading-split-arguments "-R \"white - space.txt\" -r 10:20")
 '("-R" "white - space.txt" "-r" "10:20"))

(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\"" 0) '((nil . 0) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\"" 2) '((0 . 0) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\"" 4) '((nil . 1) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\"" 5) '((1 . 1) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\"" 9) '((nil . 1) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text\" " 10) '((nil . 2) "-R" "text"))

;; unbalanced double quote
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text" 0) '((nil . 0) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text" 8) '((1 . 1) "-R" "text"))
(fsvn-test-equal (fsvn-complete-reading-split-arguments "-R \"text " 9) '((1 . 1) "-R" "text "))

(fsvn-test-equal (fsvn-complete-url-local-file-previous-segment "file:///home") "/")
(fsvn-test-equal (fsvn-complete-url-local-file-previous-segment "file:///home/") "/home/")
(fsvn-test-equal (fsvn-complete-url-local-file-previous-segment "file:///home/d") "/home/")
(fsvn-test-equal (fsvn-complete-url-local-file-previous-segment "file:///") "/")

;; fsvn-file-name-root-p
;; fsvn-file-name-nondirectory
;; fsvn-expand-file
;; fsvn-file-relative
;; fsvn-url-repository-p
;; fsvn-url-local-p

(fsvn-test-non-nil (fsvn-url-contains-p "http://a" "http://a/b"))
(fsvn-test-non-nil (fsvn-url-contains-p "http://a" "http://a/"))
(fsvn-test-non-nil (fsvn-url-contains-p "http://a/" "http://a/"))
(fsvn-test-nil (fsvn-url-contains-p "http://a/b" "http://a/"))

(fsvn-test-non-nil (fsvn-url-descendant-p "http://a" "http://a/b"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a" "http://a/"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a/" "http://a/"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a/b" "http://a/"))

(fsvn-test-equal (fsvn-file-name-directory "/abcd/efg/.") (expand-file-name "/abcd/efg"))
(fsvn-test-equal (fsvn-file-name-directory "/abcd/efg/") (expand-file-name "/abcd/efg"))
(fsvn-test-equal (fsvn-file-name-directory "/abcd/efg") (expand-file-name "/abcd"))

(fsvn-test-equal (fsvn-file-name-directory2 "/abcd/efg/.") "/abcd/efg")
(fsvn-test-equal (fsvn-file-name-directory2 "/abcd/efg/") "/abcd")
(fsvn-test-equal (fsvn-file-name-directory2 "/abcd/efg") "/abcd")

(fsvn-test-non-nil (fsvn-url-descendant-p "http://a/b/c" "http://a/b/c/d"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a/b/c" "http://a/b/c/"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a/b/c" "http://a/b/c"))
(fsvn-test-nil (fsvn-url-descendant-p "http://a/b/c" "http://a/b/"))

(fsvn-test-non-nil (fsvn-url-contains-p "http://a/b/c" "http://a/b/c"))
(fsvn-test-non-nil (fsvn-url-contains-p "http://a/b/c" "http://a/b/c/"))
(fsvn-test-non-nil (fsvn-url-contains-p "http://a/b/c" "http://a/b/c/d"))
(fsvn-test-nil (fsvn-url-contains-p "http://a/b/c" "http://a/b/"))

(fsvn-test-equal (fsvn-url-only-child "http://a/" "http://a/b/c/d") "http://a/b")
(fsvn-test-equal(fsvn-url-only-child "http://a/" "http://a/b/") "http://a/b")
(fsvn-test-equal(fsvn-url-only-child "http://a/" "http://a/b/c") "http://a/b")
(fsvn-test-nil (fsvn-url-only-child "http://a/" "http://a/"))
(fsvn-test-nil (fsvn-url-only-child "http://a/" "http://a"))
(fsvn-test-equal (fsvn-url-only-child "/a" "/a/b/c") "/a/b")
(fsvn-test-equal (fsvn-url-only-child "/a/b" "/a/b/c") "/a/b/c")
(fsvn-test-nil (fsvn-url-only-child "/a/b" "/a/b"))

(unless (or noninteractive (eq system-type 'windows-nt))
  (let ((buffer (fsvn-popup-result-create-buffer))
        proc)
    (fsvn-async-let ((test-buffer buffer))
      (start-process "TEST1" test-buffer "sh" "-c" "echo 1 && sleep 1 && echo 2")
      ;;TODO
      ;; (fsvn-async-let ()
      ;;   (start-process "TEST2" (current-buffer) "sh" "-c" "echo 3 && sleep 1 && echo 4")
      ;;   (start-process "TEST3" (current-buffer) "sh" "-c" "echo 5 && sleep 1 && echo 6"))
      (start-process "TEST4" test-buffer "sh" "-c" "echo 7 && sleep 1 && echo 8")
      (start-process "TEST5" test-buffer "sh" "-c" "echo 9 && sleep 1 && echo 10"))
    (while (and (setq proc (get-buffer-process buffer))
                (eq (process-status proc) 'run))
      (sit-for 0.5))
    (with-current-buffer buffer
      (fsvn-test-equal (buffer-string) "1\n2\nfinished\n7\n8\nfinished\n9\n10\nfinished\n"))
    (kill-buffer buffer)))

;; non interactive test
(fsvn-test-excursion
 (let* ((test-dir (fsvn-make-temp-directory))
        (repos-dir (expand-file-name "rep" test-dir))
        (repos-url (fsvn-directory-name-as-repository repos-dir))
        (wc1-dir (expand-file-name "wc1" test-dir))
        (wc2-dir (expand-file-name "wc2" test-dir))
        (wc3-dir (expand-file-name "wc3" test-dir))
        (trash-dir (expand-file-name "trash" test-dir))
        (default-directory test-dir)
        ;; cancel all configuration
        (fsvn-repository-alist nil)
        (fsvn-config-browse-show-update (default-value 'fsvn-config-browse-show-update))
        (fsvn-config-commit-default-file-select-p (default-value 'fsvn-config-commit-default-file-select-p))
        (fsvn-config-log-empty-warnings (default-value 'fsvn-config-log-empty-warnings))
        (fsvn-config-log-limit-count (default-value 'fsvn-config-log-limit-count))
        (fsvn-config-magic-remote-commit-message (default-value 'fsvn-config-magic-remote-commit-message))
        (fsvn-config-repository-default-coding-system (default-value 'fsvn-config-repository-default-coding-system))
        (fsvn-config-tortoise-property-use (default-value 'fsvn-config-tortoise-property-use))
        list file1 file2 file3 file4 dir1 dir2 dir3
        ignore-file)
   (make-directory wc1-dir)
   (make-directory wc2-dir)
   (make-directory wc3-dir)
   (make-directory trash-dir)
   (fsvn-test-async
    (fsvn-admin-create-repository repos-dir)
    (setq default-directory wc1-dir)
    (fsvn-checkout repos-url)
    (dired wc1-dir)
    ;;add three files and a dir
    (setq list nil)
    (setq file1 (expand-file-name "a" wc1-dir))
    (setq list (cons file1 list))
    (write-region "A" nil file1)
    (setq file2 (expand-file-name "b" wc1-dir))
    (setq list (cons file2 list))
    (write-region "B" nil file2)
    (setq file3 (expand-file-name "c" wc1-dir))
    (setq list (cons file3 list))
    (write-region "C" nil file3)
    (setq dir1 (expand-file-name "z" wc1-dir))
    (setq list (cons dir1 list))
    (make-directory dir1)
    (setq file4 (expand-file-name "a" dir1))
    (write-region "AA" nil file4)
    (setq ignore-file (expand-file-name "ignore" wc1-dir))
    (write-region "ignore" nil ignore-file)
    (fsvn-browse-prop-add-svn:ignore-selected (list ignore-file))
    (fsvn-browse-add-selected (nreverse list))
    (fsvn-test-quick-commit "add file" wc1-dir) ;; revision 1
    (call-interactively 'revert-buffer)
    (fsvn-browse-goto-file file1)
    (fsvn-browse-info-path)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-browse-next-file) ;; move to file2
    (fsvn-test-equal (fsvn-current-filename) "b")
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-browse-mark-file-mark)   ;; mark file2
    (call-interactively 'fsvn-browse-mark-file-delete) ;; delete mark file3
    (fsvn-test-sit-for)
    (fsvn-test-equal (fsvn-browse-cmd-selected-urls) (list file2))
    (fsvn-test-equal (fsvn-browse-cmd-selected-urlrevs) (list file2))
    (fsvn-test-sit-for)
    (fsvn-browse-previous-file 2) ;; move to file2
    (fsvn-test-equal (fsvn-browse-cmd-this-urlrev) file2)
    (fsvn-test-equal (fsvn-browse-cmd-this-wc-file) file2)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-browse-mark-file-unmark) ;; unmark file2
    (call-interactively 'fsvn-browse-mark-file-unmark) ;; unmark file3
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-previous-file)
    (fsvn-test-sit-for)
    ;; mkdir
    (setq dir2 (expand-file-name "y" wc1-dir))
    (fsvn-browse-mkdir dir2)
    ;; delete a file
    (fsvn-browse-delete-selected (list file1))
    (fsvn-test-quick-commit "delete file" wc1-dir) ;; revision 2
    (call-interactively 'revert-buffer)
    (fsvn-test-sit-for)
    ;; modify a file
    (write-region "Z" nil file2 t)
    (fsvn-browse-diff-this file2)
    (fsvn-test-quick-commit "modify file" wc1-dir) ;; revision 3
    (call-interactively 'revert-buffer)
    (fsvn-test-sit-for)
    ;; revert a file
    (write-region "Y" nil file3 t)
    (fsvn-browse-revert-selected (list file3))
    (revert-buffer)
    ;; sort
    (call-interactively 'fsvn-browse-toggle-sort)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-browse-toggle-sort)
    (fsvn-test-sit-for)
    ;; lock and unlock file
    (fsvn-test-new-popup-buffer-has "locked"
      (fsvn-browse-lock-selected (list file3)))
    (fsvn-test-sit-for)
    (fsvn-test-new-popup-buffer-has "unlocked"
      (fsvn-browse-unlock-selected (list file3)))
    (fsvn-test-sit-for)
    ;; info
    (fsvn-browse-info-path)
    (fsvn-test-sit-for)
    (fsvn-browse-info-selected (list file3))
    (fsvn-test-sit-for)
    ;; blame
    (fsvn-browse-blame-this file3)
    (fsvn-test-sit-for)
    ;; export
    (let ((export-file (expand-file-name "export-file" trash-dir))
          (export-dir (expand-file-name "export-dir" trash-dir)))
      (fsvn-test-async
       (fsvn-browse-export-this file3 export-file)
       (fsvn-test-sit-for)
       (fsvn-browse-export-path export-dir)
       (fsvn-test-sit-for)))
    ;; copy
    (if (version<= fsvn-svn-version "1.5.0")
        (fsvn-test-async
         (fsvn-browse-copy-selected (list file2) dir2)
         (fsvn-browse-copy-selected (list file3) dir2))
      (fsvn-browse-copy-selected (list file2 file3) dir2))
    (fsvn-test-sit-for)
    (fsvn-browse-copy-this file2 (expand-file-name "non-existence" dir2))
    (fsvn-test-sit-for)
    ;; cleanup
    (fsvn-browse-cleanup-path)
    (fsvn-test-sit-for)
    ;; property
    (fsvn-set-propset file3 "fsvn:test" "a\nb")
    (fsvn-browse-update-path)
    (fsvn-test-equal (fsvn-get-propget file3 "fsvn:test") "a\nb")
    (when (version< fsvn-svn-version "1.7")
      (fsvn-test-equal (length (fsvn-meta--get-properties file3)) 1))
    (fsvn-test-equal (fsvn-deps-get-property "fsvn:test" file3) "a\nb")
    (fsvn-test-equal (fsvn-get-proplist file3) '("fsvn:test"))
    (let* ((info (fsvn-get-info-entry (fsvn-file-name-nondirectory file2)))
           (url (fsvn-xml-info->entry=>url$ info))
           (tmpfile (fsvn-make-temp-file))
           magic2 magic3 magic4)
      ;; save file
      (fsvn-test-non-nil (fsvn-save-file (fsvn-url-urlrev url "HEAD") tmpfile))
      (fsvn-test-equal (fsvn-get-file-contents tmpfile) "BZ")
      (fsvn-test-non-nil (fsvn-save-file (fsvn-url-urlrev url 2) tmpfile))
      (fsvn-test-equal (fsvn-get-file-contents tmpfile) "B")
      (fsvn-test-equal (fsvn-get-revprop "svn:log" (fsvn-url-urlrev url 2)) "delete file")
      (setq magic2 (fsvn-magic-create-name (fsvn-url-urlrev url 2)))
      (setq magic3 (fsvn-magic-create-name (fsvn-url-urlrev url 3)))
      (setq magic4 (fsvn-magic-create-name (fsvn-url-urlrev url 4)))
      (with-temp-buffer
        (fsvn-test-non-nil (file-exists-p magic2))
        (fsvn-test-nil (file-directory-p magic2))
        (fsvn-test-non-nil (file-readable-p magic2))
        (fsvn-test-non-nil (file-regular-p magic2))
        (fsvn-test-non-nil (file-remote-p magic2))
        (fsvn-test-nil (file-writable-p magic2))
        ;;      (file-executable-p           magic2)
        ;;      (fsvn-test-nil (file-symlink-p magic2))
        (insert-file-contents magic2)
        (fsvn-test-equal (buffer-string) "B")
        )
      (with-temp-buffer
        (fsvn-test-non-nil (file-exists-p magic3))
        (fsvn-test-nil (file-directory-p magic3))
        (insert-file-contents magic3)
        (fsvn-test-equal (buffer-string) "BZ")
        )
      (with-temp-buffer
        (fsvn-test-nil (file-exists-p magic4))
        )
      )
    (fsvn-call-command-discard "commit" "--message" "modify file") ;; revision 4
    ;; move No.1
    (if (version<= fsvn-svn-version "1.5.0")
        (fsvn-test-async
         (fsvn-browse-move-selected (list file2) dir1)
         (fsvn-browse-move-selected (list file3) dir1))
      (fsvn-browse-move-selected (list file2 file3) dir1))
    (fsvn-test-sit-for)
    (fsvn-call-command-discard "commit" "--message" "modify file") ;; revision 5
    ;; move No.2
    (if (version<= fsvn-svn-version "1.5.0")
        (fsvn-test-async
         (fsvn-browse-move-selected (list (expand-file-name (file-name-nondirectory file2) dir1)) wc1-dir)
         (fsvn-browse-move-selected (list (expand-file-name (file-name-nondirectory file3) dir1)) wc1-dir))
      (fsvn-browse-move-selected (list (expand-file-name (file-name-nondirectory file2) dir1)
                                       (expand-file-name (file-name-nondirectory file3) dir1))
                                 wc1-dir))
    (fsvn-test-sit-for)
    (fsvn-call-command-discard "commit" "--message" "modify file") ;; revision 6
    ;; move No.3
    (fsvn-browse-move-this file2 (expand-file-name "non-existence" dir1))
    (fsvn-test-sit-for)
    (fsvn-call-command-discard "commit" "--message" "modify file") ;; revision 7
    ;; conflict test
    (cd wc2-dir)
    (fsvn-checkout repos-url)
    (find-file (fsvn-test-switch-file wc1-dir wc2-dir file2))
    (goto-char (point-max))
    (insert "Z")
    (save-buffer)
    (fsvn-call-command-discard "commit" "--message" "make conflicted state")
    (cd wc1-dir)
    (find-file file2)
    (goto-char (point-max))
    (insert "z")
    (save-buffer)
    ;;todo
    ;;     (let ((proc (fsvn-browse-update-path)))
    ;;       (while (eq (process-status proc) 'run)
    ;;      (sit-for 0.5))
    ;;       (process-send-string proc "p"))
    ;;todo
    ;;       (fsvn-set-revprop-value (fsvn-url-urlrev url 2)
    )
   (fsvn-test-async
    ;; open by browse-mode
    (dired wc3-dir)
    (fsvn-test-equal major-mode 'dired-mode)
    (fsvn-checkout repos-url)
    ;; switch to fsvn-browse-mode
    (fsvn-dired-toggle-browser)
    (fsvn-test-equal major-mode 'fsvn-browse-mode)
    (fsvn-test-sit-for)
    ;; switch to dired
    (fsvn-dired-toggle-browser)
    (fsvn-test-equal major-mode 'dired-mode)
    (fsvn-dired-toggle-browser)
    ;; check Log List Mode executable
    (fsvn-browse-logview-path)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-log-list-next-line)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-log-list-previous-line)
    (fsvn-test-sit-for)
    ;; mark two
    (fsvn-log-list-mark-put-mark)
    (fsvn-log-list-mark-put-mark)
    ;; first of mark
    (fsvn-log-list-previous-line 3)
    ;; skip mark
    (fsvn-log-list-next-mark)
    (fsvn-log-list-next-mark)
    (fsvn-log-list-previous-mark)
    (fsvn-log-list-previous-mark)
    ;; unmark all
    (fsvn-log-list-mark-unmark)
    (fsvn-log-list-mark-unmark)
    ;; show log details
    (fsvn-log-list-previous-line 2)
    ;; TODO cannot noninteractive test?
    ;; (call-interactively 'fsvn-log-list-show-details)
    (call-interactively 'fsvn-log-list-propview-this)
    (call-interactively 'fsvn-restore-previous-window-setting)
    ;; quit log list
    (fsvn-log-list-quit)
    (fsvn-test-sit-for)
    ;; check Property List Mode executable
    (fsvn-browse-propview-path)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-proplist-next-line)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-proplist-previous-line)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-proplist-show-value)
    (fsvn-test-sit-for)
    (call-interactively 'fsvn-restore-previous-window-setting)
    (fsvn-test-sit-for)
    ;; back to browse buffer
    (call-interactively 'fsvn-browse-propview-this)
    (call-interactively 'fsvn-restore-previous-window-setting)
    ;; check Commit buffer
    (fsvn-browse-commit-path)
    (fsvn-test-sit-for)
    (fsvn-parasite-quit)
    (fsvn-test-sit-for)
    )))



(defun fsvn-test-make-conflicted-file (file)
  (let (url magic)
    (write-region (format-time-string "%c\n") nil file t)
    (setq url (fsvn-wc-file-repository-url file))
    (setq magic (fsvn-magic-create-name url))
    (write-region (format-time-string "%c\n" (seconds-to-time (- (float-time) 20))) nil magic t)))

(defun fsvn-test-add-file-in-repos (dir)
  (let* ((file (fsvn-make-temp-file))
         (url (fsvn-wc-file-repository-url dir))
         (magic (fsvn-magic-create-name url)))
    (write-region (format-time-string "%c\n") nil file t)
    (fsvn-asap-add-file file url (format-time-string "%H-%M-%S"))))

;; todo
(defun fsvn-test-magic-handler ()
  (let (ret)
    (mapcar
     (lambda (cell)
       (cond
        ;; if Emacs function not provided, ignore this.
        ((not (functionp (car cell)))
         (setq ret (cons (format "%s is not a provided function." (car cell)) ret)))
        ((not (functionp (cdr cell)))
         (setq ret (cons (format "Magic handler not defined for %s" (car cell)) ret)))
        ((subrp (symbol-function (car cell)))
         )
        ((symbol-function (car cell))
         )
        ((equal (cadr (symbol-function (car cell)))
                (cadr (symbol-function (cdr cell))))
         cell)
        (t
         nil)))
     fsvn-magic-handler-alist)
    (nreverse ret)))

(defun fsvn-test-check-menu-spec (spec commands)
  (mapc
   (lambda (c)
     (unless (fsvn-test-check-menu-spec-internal spec c)
       (error "%s not bound" c)))
   commands))

(defun fsvn-test-check-menu-spec-internal (spec command)
  (catch 'found
    (mapc
     (lambda (s)
       (cond
        ((or (listp s)
             (vectorp s))
         (when (fsvn-test-check-menu-spec-internal s command)
           (throw 'found t)))
        ((and (symbolp s)
              (commandp s))
         (when (eq s command)
           (throw 'found t)))))
     spec)
    nil))

(fsvn-test-unbound-functions)




;;; fsvn-test.el ends here
