;;;; export.lisp — writes the Common Lisp docset: the dictionary entries and the glossary.

(in-package #:spec-export)

(defparameter *attribution*
  "Converted from the TeX sources of dpANS3, the third draft proposed American National
Standard for Common Lisp (X3J13, 1994), the draft the final ANSI X3.226-1994 was
made from. It is not the official standard, whose wording differs in a few places.")

;;; Entry ids and kinds

(defun slug (string)
  (string-downcase (substitute #\- #\Space (string-trim " " string))))

(defun entry-id (entry)
  (format nil "~A/~A" (slug (entry-kind entry)) (first (entry-names entry))))

(defun kind-keyword (kind-name)
  (intern (string-upcase (slug kind-name)) :keyword))

;;; Resolving (:ref kind name) to the entry it names

(defvar *by-name* (make-hash-table :test 'equal)
  "Lowercase symbol name -> the dictionary entries naming it.")

(defparameter *ref-kinds*
  '((:function "function" "standard generic function" "accessor" "local function")
    (:macro "macro" "local macro" "special operator")
    (:special-operator "special operator" "macro")
    (:type "system class" "class" "type" "condition type" "type specifier" "structure")
    (:variable "variable" "constant variable")
    (:constant "constant variable" "variable")
    (:declaration "declaration")
    (:package))
  "For each kind of reference, the entry kinds it prefers, best first.")

(defvar *unresolved-refs* (make-hash-table :test 'equal)
  "Names of references that matched no entry -> how many times, for the export report.")

(defun ref-target (kind name)
  (let ((entries (gethash (string-downcase name) *by-name*)))
    (unless entries (incf (gethash name *unresolved-refs* 0)))
    (when entries
      (entry-id (or (loop for k in (rest (assoc kind *ref-kinds*))
                          thereis (find k entries :key #'entry-kind :test #'string-equal))
                    (first entries))))))

;;; Nodes -> docset inlines and blocks

(defun collapse-spaces (string)
  (cl-ppcre:regex-replace-all "\\s+" string " "))

(defun inlines (nodes &key code)
  "Docset inlines for import NODES. In CODE, spacing and line breaks are kept."
  (loop for node in nodes
        append (cond ((stringp node) (list (if code node (collapse-spaces node))))
                     ((atom node) nil)
                     (t (inline-node node code)))))

(defun inline-node (node code)
  (flet ((kids () (inlines (cdr node) :code code)))
    (case (car node)
      ((:code :i :b :param :sup :sub :sense :math :input :note) (list (cons (car node) (kids))))
      (:term (let ((text (nodes->text (cdr node))))
               (list (list* :term (glossary-target text) (kids)))))
      (:ref (destructuring-bind (kind name) (cdr node)
              (let ((target (ref-target kind name)))
                (list (if target (list :ref target name) (list :code name))))))
      (:secref (destructuring-bind (key title) (cdr node) (list (list :secref key title))))
      (:caption nil)
      ((:par :row) (list (if code (string #\Newline) " ")))
      (:cell (list " "))
      ((:syntax :table :item :list-begin :list-end) nil)
      (t (kids)))))

(defun syntax-block (node)
  (destructuring-bind (kind name args &key (values nil values-p)) (cdr node)
    (append (list :syntax :kind kind :name (inlines name) :args (trim-inlines (inlines args)))
            (when values-p (list :values (trim-inlines (inlines values))))
            (when (eq kind :setf) (list :setf t)))))

(defun trim-inlines (inlines)
  "INLINES without leading and trailing blank text."
  (flet ((blank (x) (and (stringp x) (string= "" (string-trim " " x)))))
    (let* ((start (position-if-not #'blank inlines))
           (end (position-if-not #'blank inlines :from-end t)))
      (if start
          (let ((trimmed (subseq inlines start (1+ end))))
            (when (stringp (first trimmed))
              (setf (first trimmed) (string-left-trim " " (first trimmed))))
            (when (stringp (car (last trimmed)))
              (setf (car (last trimmed)) (string-right-trim " " (car (last trimmed)))))
            trimmed)
          '()))))

(defun split-on (marker nodes)
  "NODES split into runs at each node equal to MARKER."
  (let ((runs '()) (run '()))
    (dolist (n nodes)
      (if (equal n marker)
          (progn (push (nreverse run) runs) (setf run '()))
          (push n run)))
    (push (nreverse run) runs)
    (nreverse runs)))

(defun table-block (caption headers rows)
  (let ((rows (loop for row in (split-on '(:row) rows)
                    for cells = (mapcar (lambda (cell) (trim-inlines (inlines cell)))
                                        (split-on '(:cell) row))
                    when (some #'identity cells) collect cells))
        (caption (trim-inlines (inlines caption))))
    (append (list :table)
            (when caption (list :caption caption))
            (when headers (list :header (mapcar (lambda (h) (trim-inlines (inlines h))) headers)))
            (list :rows rows))))

(defun table-caption (rows)
  "The caption a hand-built \\halign figure carries among its rows."
  (labels ((find-caption (nodes)
             (dolist (n nodes)
               (when (consp n)
                 (if (eq (car n) :caption)
                     (return (cdr n))
                     (let ((inner (find-caption (cdr n)))) (when inner (return inner))))))))
    (find-caption rows)))

(defun paragraph-blocks (nodes)
  "A paragraph's nodes as blocks: its definition lines become :syntax blocks, the rest :p."
  (let ((blocks '()) (run '()))
    (flet ((end-run ()
             (let ((inl (trim-inlines (inlines (nreverse run)))))
               (when inl (push (cons :p inl) blocks)))
             (setf run '())))
      (dolist (n nodes)
        (if (and (consp n) (eq (car n) :syntax))
            (progn (end-run) (push (syntax-block n) blocks))
            (push n run)))
      (end-run))
    (nreverse blocks)))

(defun convert-blocks (blocks)
  (loop for block in blocks
        append (ecase (car block)
                 (:p (paragraph-blocks (cdr block)))
                 (:code (list (list* :code-block "lisp" (trim-code (inlines (cdr block) :code t)))))
                 (:table (destructuring-bind (caption headers rows) (cdr block)
                           (list (table-block (or (and caption (remove "" caption :test #'equal))
                                                  (table-caption rows))
                                              headers rows))))
                 (:list (list (cons :list (mapcar #'convert-item (cdr block))))))))

(defun convert-item (item)
  (cons :item
        (loop for part in (cdr item)
              append (if (eq (car part) :label)
                         (let ((label (trim-inlines (inlines (cdr part)))))
                           (when label (list (cons :label label))))
                         (convert-blocks (list part))))))

(defun trim-code (inlines)
  "Code block INLINES without the blank lines that start and end the block."
  (let ((inlines (copy-list inlines)))
    (when (stringp (first inlines))
      (setf (first inlines) (string-left-trim '(#\Newline) (first inlines))))
    (when (stringp (car (last inlines)))
      (setf (car (last inlines)) (string-right-trim '(#\Newline #\Space) (car (last inlines)))))
    (remove "" inlines :test #'equal)))

;;; Summaries

(defun blocks-text (blocks)
  (with-output-to-string (s)
    (labels ((walk (x)
               (cond ((stringp x) (write-string x s))
                     ((consp x) (mapc #'walk (if (member (car x) '(:ref :term :link :secref)) (cddr x) (cdr x)))))))
      (mapc #'walk blocks))))

(defun first-paragraph (blocks)
  "The first paragraph in BLOCKS, looking inside lists, that says more than a word or two."
  (dolist (block blocks)
    (case (car block)
      (:p (when (> (length (string-trim " " (blocks-text (list block)))) 12)
            (return block)))
      (:list (let ((p (first-paragraph (loop for item in (cdr block) append (cdr item)))))
               (when p (return p)))))))

(defun summary (blocks)
  "The first sentence of the first paragraph in BLOCKS, at most about 200 characters."
  (let ((p (first-paragraph blocks)))
    (when p
      (let* ((text (string-trim " " (collapse-spaces (blocks-text (list p)))))
             (end (cl-ppcre:scan "[.;:](\\s|$)" text)))
        (let ((sentence (if end (subseq text 0 (1+ end)) text)))
          (if (> (length sentence) 200)
              (concatenate 'string (subseq sentence 0 (or (position #\Space sentence :from-end t :end 197) 197)) "…")
              sentence))))))

;;; Chapters

(defun chapters (directory)
  "(number title dict-file) for each chapter, in order."
  (sort (loop for file in (directory (merge-pathnames "chap-*.tex" directory))
              for text = (spec-import::read-file file)
              for (number title) = (cl-ppcre:register-groups-bind (n title)
                                       ("\\\\beginchapter\\{([^}]*)\\}\\{([^}]*)\\}" text)
                                     (list n title))
              for dict = (cl-ppcre:register-groups-bind (d) ("\\\\includeDictionary\\{([^}]*)\\}" text) d)
              when number collect (list number title dict))
        #'< :key (lambda (c) (or (parse-integer (first c) :junk-allowed t) 99))))

;;; The docset

(defun entry-form (id names kind-name sections &key package parent children)
  (let ((blocks (or (cdr (assoc "Description" sections :test #'string=))
                    (cdr (first sections)))))
    (append (list :entry id :names names :kind (kind-keyword kind-name) :kind-name kind-name)
            (when package (list :package package))
            (when parent (list :parent parent))
            (when children (list :children children))
            (let ((s (summary blocks))) (when s (list :summary s)))
            (list :sections sections))))

(defun dictionary-entry-form (entry)
  (entry-form (entry-id entry)
              (entry-names entry)
              (entry-kind entry)
              (loop for (label . tex) in (entry-sections entry)
                    for blocks = (convert-blocks (section-blocks tex))
                    when blocks collect (cons label blocks))
              :package "COMMON-LISP"))

(defun export-common-lisp (&key (sources (merge-pathnames "sources/dpans3/dpANS3/"
                                                          (asdf:system-source-directory "spec-browser")))
                                (output (merge-pathnames "data/common-lisp/"
                                                         (asdf:system-source-directory "spec-browser"))))
  "Writes the Common Lisp docset to OUTPUT from the dpANS3 sources."
  (let* ((*dpans-directory* sources)
         (entries (read-all-entries sources))
         (glossary (read-glossary sources)))
    (clrhash *by-name*)
    (clrhash *glossary-terms*)
    (clrhash *unresolved-refs*)
    (dolist (e entries)
      (dolist (name (entry-names e))
        (push e (gethash (string-downcase name) *by-name*))))
    (maphash (lambda (k v) (setf (gethash k *by-name*) (reverse v))) *by-name*)
    (dolist (g glossary)
      (setf (gethash (string-downcase (nodes->text (parse-tex (car g) :literal t))) *glossary-terms*)
            (glossary-id (nodes->text (parse-tex (car g) :literal t)))))
    (let* ((dictionary (mapcar #'dictionary-entry-form entries))
           (glossary-forms
             ;; A few terms are entered twice, with different definitions: one entry each
             (let ((merged '()))
               (loop for (term . tex) in glossary
                     for name = (nodes->text (parse-tex term :literal t))
                     for blocks = (convert-blocks (section-blocks tex))
                     for seen = (assoc name merged :test #'string-equal)
                     do (if seen
                            (setf (cdr seen) (append (cdr seen) blocks))
                            (push (cons name blocks) merged)))
               (loop for (name . blocks) in (nreverse merged)
                     collect (entry-form (glossary-id name) (list name) "Glossary Term"
                                         (list (cons "Definition" blocks))))))
           (toc (append
                 (loop for (number title dict) in (chapters sources)
                       for file = (and dict (concatenate 'string dict ".tex"))
                       for members = (remove-if-not (lambda (e) (string= (entry-file e) file)) entries)
                       when members
                         collect (list :title (format nil "~A. ~A" number title)
                                       :children (loop for e in members
                                                       collect (list :title (format nil "~{~A~^, ~}" (entry-names e))
                                                                     :entry (entry-id e)))))
                 (list (list :title "26. Glossary"
                             :children (loop for g in glossary-forms
                                             collect (list :title (first (getf (cddr g) :names))
                                                           :entry (second g))))))))
      (write-docset output
                    (list :id "common-lisp"
                          :title "Common Lisp"
                          :subtitle "The ANSI Common Lisp standard, from the dpANS3 draft"
                          :version "dpANS3 (15.17R, 1994)"
                          :packages '("COMMON-LISP")
                          :source "https://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/lisp/doc/standard/ansi/dpans/"
                          :attribution *attribution*
                          :license "The dpANS3 drafts were published by X3J13 for public review."
                          :toc toc)
                    (append dictionary glossary-forms))
      (format t "~&Wrote ~D dictionary entries and ~D glossary terms to ~A~%"
              (length dictionary) (length glossary-forms) output)
      (let ((names (loop for k being the hash-keys of *unresolved-refs* using (hash-value v)
                         collect (format nil "~A (~D)" k v))))
        (when names
          (format t "References to symbols with no entry, shown as code: ~{~A~^, ~}~%" (sort names #'string<))))
      output)))
