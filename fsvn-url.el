;;; fsvn-url.el --- URL parser/utility for fsvn.el


;;; History:
;; 

;;; Commentary:
;; 

;;; Code:
;;



(require 'fsvn-deps)



(defvar system-type)



(defconst fsvn-url-encoding fsvn-svn-common-coding-system)
(defconst fsvn-url-with-revision-regexp "^\\(.*\\)@\\([^@]+\\)$")

;; url utility

;;FIXME not works on Emacs 23
(defun fsvn-url-decode-string (url)
  ;; url is multibyte string. if multibyte string,
  ;; `url-unhex-string' can't treat url correctly.(bug?)
  (let ((unibyte-url (fsvn-string-unibyte-only-p url)))
    (if unibyte-url
	(decode-coding-string (url-unhex-string unibyte-url) fsvn-url-encoding)
      url)))

(defun fsvn-url-escape-revision-mark (url)
  (if (string-match fsvn-url-with-revision-regexp url)
      (concat url "@")
    url))

(defun fsvn-url-string-url (url-string)
  (let ((obj (fsvn-url-string-parse url-string)))
    (car obj)))

(defun fsvn-url-string-revision (url-string)
  (let ((obj (fsvn-url-string-parse url-string)))
    (cdr obj)))

(defun fsvn-url-string-parse (url-string)
  (if (string-match fsvn-url-with-revision-regexp url-string)
      (cons (match-string 1 url-string) (match-string 2 url-string))
    (cons url-string nil)))

(defun fsvn-url-string-to-urlrev (url-string)
  (let ((obj (fsvn-url-string-parse url-string)))
    (fsvn-url-urlrev (car obj) (cdr obj))))

;; todo `@' contained file name escaped by following `@'
(defun fsvn-url-encode-string (urlrev)
  (let* ((urlobj (fsvn-urlrev-parse urlrev))
	 (url (car urlobj))
	 (rev (cdr urlobj)))
    (fsvn-url-urlrev
     (fsvn-url-concat-split-path
      (mapcar
       (lambda (x)
	 (cond
	  ((fsvn-string-unibyte-only-p x)
	   x)
	  (t
	   (url-hexify-string x))))
       (split-string url "/")))
     rev)))

(defun fsvn-urlrev-decode-string (urlrev)
  (let* ((urlobj (fsvn-urlrev-parse urlrev))
	 (url (car urlobj))
	 (rev (cdr urlobj)))
    (fsvn-url-urlrev (fsvn-url-decode-string url) rev)))

(defun fsvn-expand-url (part-of-url &optional url)
  (let* ((path (directory-file-name part-of-url))
	 (parent (and url (directory-file-name url)))
	 (path-list (split-string path "/"))
	 (paren-list (and parent (split-string parent "/"))))
    (when (and path-list (string= (car path-list) ""))
      (setq path-list (cdr path-list)))
    (fsvn-url-concat-split-path (nconc paren-list path-list))))

;; FIXME (fsvn-expand-url "A" "http://a/../../")
;;    -> "http:/A" but "http://A" is correct.
(defun fsvn-url-concat-split-path (path-list)
  "PATH-LIST modified."
  (let* ((topsegment (car path-list))
	 (lst (nreverse (cdr path-list)))
	 (ignore 0)
	 segment ret)
    (while lst
      (setq segment (car lst))
      (cond
       ((string= segment "."))		 ;; do nothing
       ((string= segment "..")		 ;; ignore next
	(setq ignore (1+ ignore)))
       ((> ignore 0)
	(setq ignore (1- ignore)))
       (t
	(setq ret (cons segment ret))))
      (setq lst (cdr lst)))
    (while (> ignore 0)
      (setq ret (cdr ret))
      (setq ignore (1- ignore)))
    (setq ret (cons topsegment ret))
    (mapconcat 'identity ret "/")))

(defun fsvn-url-ediff-filename (url)
  (let ((tmp (directory-file-name url)))
    (string-match "\\([^/]+\\)/?$" tmp)
    (match-string 1 tmp)))

(defun fsvn-url-directory-file-name (url)
  (if (string-match "/$" url)
      (substring url 0 -1)
    url))

(defun fsvn-url-dirname (url)
  (let ((tmp (directory-file-name url)))
    (when (string-match "^\\(.*/\\)\\([^/]+\\)$" tmp)
      (match-string 1 tmp))))

(defun fsvn-url-filename (url)
  (let ((tmp (directory-file-name url)))
    (when (string-match "\\([^/]+\\)$" tmp)
      (match-string 1 tmp))))

(defun fsvn-url-relative-name (url1 url2)
  (if (string-match (concat "^" (regexp-quote (fsvn-url-as-directory url1)) "\\(.*\\)") url2)
      (match-string 1 url2)
    url2))

(defun fsvn-urlrev-directory-file-name (urlrev)
  (let ((urlobj (fsvn-urlrev-parse urlrev)))
    (fsvn-url-urlrev (fsvn-url-directory-file-name (car urlobj)) (cdr urlobj))))

(defun fsvn-urlrev-dirname (urlrev)
  (let ((urlobj (fsvn-urlrev-parse urlrev)))
    (fsvn-url-urlrev (fsvn-url-dirname (car urlobj)) (cdr urlobj))))

(defun fsvn-urlrev-filename (urlrev)
  (let ((urlobj (fsvn-urlrev-parse urlrev)))
    (fsvn-url-filename (car urlobj))))

(defun fsvn-url-as-directory (url)
  (if (string-match "/$" url)
      url
    (concat url "/")))

;; (defun fsvn-urlrev-read-only-p (urlrev)
;;   (if (fsvn-url-repository-p urlrev)
;;       (not (string-match "@\\(HEAD\\)$" urlrev))))

(defun fsvn-url-repository-p (url)
  (string-match (concat "^" (regexp-opt fsvn-svn-url-scheme-segment-list)) url))

(defun fsvn-url-local-p (url)
  (and (not (fsvn-url-repository-p url))
       (file-name-absolute-p url)
       (not (fsvn-magic-file-name-absolute-p url))))

(defun fsvn-url-belongings-p (parent url)
  "URL is child of PARENT then return non-nil."
  (or (string-match (concat "^" (regexp-quote (file-name-as-directory parent))) url)
      (fsvn-file= parent url)))

(defun fsvn-url-urlrev (url rev)
  (if rev
      (let ((tmp (fsvn-get-revision-string rev)))
	(concat url "@" (fsvn-string-put-property tmp 'fsvn-revision-property t)))
    url))

(defun fsvn-urlrev-url (urlrev)
  "Remove revision string from URL."
  (car (fsvn-urlrev-parse urlrev)))

(defun fsvn-urlrev-revision (urlrev)
  (cdr (fsvn-urlrev-parse urlrev)))

(defun fsvn-urlrev-parse (urlrev)
  (let (pos)
    (if (setq pos (next-single-property-change 0 'fsvn-revision-property urlrev))
	(cons (substring urlrev 0 (1- pos)) (substring urlrev pos))
      (cons urlrev nil))))



;; file name concatenate and split

(if (memq system-type '(windows-nt))
    (defun fsvn-file-name-root-p (file)
      (string-match "^[a-zA-Z]:/?$" file))
  (defun fsvn-file-name-root-p (file)
    (string-match "^/$" file)))

(defun fsvn-file-name-directory (file)
  (directory-file-name (fsvn-expand-file (file-name-directory file))))

(defun fsvn-file-name-directory2 (file)
  (directory-file-name (file-name-directory (directory-file-name file))))

(defun fsvn-file-name-nondirectory (url)
  (cond
   ((string-match "/\\([^/]+\\)/?$" url)
    (match-string 1 url))
   ((string-match "^\\([^/]+\\)$" url)
    (match-string 1 url))
   (t
    (error "Error while parsing filename"))))

(defun fsvn-file-name-parent-directory (file level)
  (let ((tmp (directory-file-name file))
	(i 0))
    (while (< i level)
      (setq tmp (fsvn-file-name-directory tmp))
      (setq i (1+ i)))
    tmp))

(defun fsvn-expand-file (name &optional dir)
  (let ((ret (expand-file-name name dir)))
    (if (eq system-type 'windows-nt)
	;; todo expand-file-name bug?
	(replace-regexp-in-string "\\\\" "/" ret)
      ret)))

(defun fsvn-file-relative (name &optional dir)
  ;;todo remove copy-sequence..
  (copy-sequence (file-relative-name name dir)))

(defun fsvn-file-name-as-revisioned (file revision)
  ;; like tortoise
  (let* ((filename (file-name-sans-extension file))
	 (ext (file-name-extension file)))
    (concat filename "-"
	    (fsvn-get-revision-string revision)
	    (when ext (concat "." ext)))))

(defun fsvn-file-name-as-repository (file)
  (concat "file:///" file))

(if (memq system-type '(windows-nt))
    (defun fsvn-file= (file1 file2)
      (string= (upcase (directory-file-name file1)) (upcase (directory-file-name file2))))
  (defun fsvn-file= (file1 file2)
    (string= (directory-file-name file1) (directory-file-name file2))))

(if (memq system-type '(windows-nt))
    (defun fsvn-file-member (file list)
      (member-ignore-case file list))
  (defun fsvn-file-member (file list)
    (member file list)))

(defun fsvn-file-assoc (elt list)
  (or (fsvn-string-assoc elt list)
      (catch 'found
	(mapc
	 (lambda (item)
	   (let ((value
		  (cond
		   ((and (listp item) (stringp (car item)))
		    (car item))
		   ((atom item)
		    item)
		   (t
		    nil))))
	     (when (and value
			(fsvn-file= elt value))
	       (throw 'found item))))
	 list)
	nil)))

(if (memq system-type '(windows-nt))
    (defun fsvn-file-hash-key (file)
      (apply '+ (string-to-list (upcase file))))
  (defun fsvn-file-hash-key (file)
    (apply '+ (string-to-list file))))
  



;; for hash table
(define-hash-table-test 'fsvn-file-hash-test 'fsvn-file= 'fsvn-file-hash-key)
;; (put 'fsvn-file-hash-test 'hash-table-test nil)



(provide 'fsvn-url)

;;; fsvn-url.el ends here
