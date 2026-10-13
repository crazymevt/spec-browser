;;;; entries.lisp — splits the dict-*.tex files into dictionary entries and their sections.

(in-package #:spec-import)

(defvar *dpans-directory* nil
  "The unpacked dpANS3 directory, holding dict-*.tex and setup-*.tex.")

(defstruct entry
  names          ; ("mapc" "mapcar" ...)
  kind           ; "Function", "Macro", "Standard Generic Function", ...
  file line
  sections)      ; (("Syntax" . tex) ("Description" . tex) ...) in source order

(defun entry-section (entry label)
  (cdr (assoc label (entry-sections entry) :test #'string-equal)))

(defun source-lines (file)
  "FILE's lines, numbered, without the whole-line % comments outside code blocks.
An entry header split over several lines comes back as one line."
  (with-input-from-string (in (read-file file))
    (loop with code = nil
          for line = (read-line in nil)
          for n from 1
          while line
          do (cond ((cl-ppcre:scan "^\\\\code\\b" line) (setf code t))
                   ((cl-ppcre:scan "^\\\\endcode\\b" line) (setf code nil))
                   ((cl-ppcre:scan "^\\\\begincom\\{" line)
                    (loop until (or (search "\\ftype" line) (not (peek-char nil in nil)))
                          do (setf line (concatenate 'string line " " (string-trim " " (read-line in))))
                             (incf n))))
          unless (and (not code) (cl-ppcre:scan "^\\s*%" line))
            collect (cons n line))))

(defun expand-section-macros (lines)
  "LINES with each line that calls a macro whose body holds \\\\label sections,
like \\\\realtypespec{real}, replaced by the lines of its expansion."
  (loop for (n . line) in lines
        append (let ((m (cl-ppcre:register-groups-bind (name) ("^\\\\([A-Za-z]+)" line)
                          (gethash name *macros*))))
                 (if (and m (tex-macro-body m) (search "\\label" (tex-macro-body m)))
                     (let* ((*src* line) (*pos* (1+ (position-if-not #'letterp line :start 1))))
                       (decf *pos*)
                       (let ((args (mapcar #'read-param (tex-macro-params m))))
                         (mapcar (lambda (l) (cons n l))
                                 (cl-ppcre:split "\\n" (substitute-params (tex-macro-body m) args)))))
                     (list (cons n line))))))

(defun entry-header (line)
  "The names and kind of a \\begincom{...}\\ftype{...} line, or NIL."
  (cl-ppcre:register-groups-bind (names kind) ("^\\\\begincom\\{(.*)\\}\\\\ftype\\{(.*)\\}" line)
    (values (mapcar (lambda (name) (string-trim '(#\Space #\Tab #\Newline) name))
                    (cl-ppcre:split "," (nodes->text (parse-tex names :literal t))))
            kind)))

(defun read-entries (file)
  (let ((entries '()) (entry nil) (label nil) (text nil))
    (labels ((end-section ()
               (when label
                 (push (cons label (format nil "~{~A~%~}" (reverse text))) (entry-sections entry)))
               (setf label nil text nil))
             (end-entry ()
               (when entry
                 (end-section)
                 (setf (entry-sections entry) (nreverse (entry-sections entry)))
                 (push entry entries)
                 (setf entry nil))))
      (loop for (n . line) in (expand-section-macros (source-lines file))
            do (multiple-value-bind (names kind) (entry-header line)
                 (cond (names
                        (end-entry)
                        (setf entry (make-entry :names names :kind kind
                                                :file (file-namestring file) :line n)))
                       ((null entry))
                       ((cl-ppcre:scan "^\\\\endcom\\b" line) (end-entry))
                       (t (cl-ppcre:register-groups-bind (new colon rest)
                              ("^\\s*\\\\label\\s+([^:]+):(:?)(.*)$" line)
                            ;; "\label Notes:\None." is the short form of an empty section
                            (end-section)
                            (setf label (string-trim " " new)
                                  line (if (and (string= colon "") (search "\\None" rest :test #'char-equal)) "\\None" rest)))
                          (when label (push line text))))))
      (end-entry))
    (nreverse entries)))

(defun read-all-entries (&optional (directory *dpans-directory*))
  (load-setup-definitions directory)
  (loop for file in (sort (directory (merge-pathnames "dict-*.tex" directory)) #'string<
                          :key #'namestring)
        append (read-entries file)))

;;; Sections as blocks

(defun section-blocks (tex)
  "Reads a section's TeX into blocks: (:p nodes...), (:code nodes...), and
(:list (:item (:label nodes...) (:p nodes...)...)...)."
  (let ((blocks '()) (prose '()))
    (flet ((end-prose ()
             (when prose
               (setf blocks (append (reverse (prose-blocks (parse-tex (format nil "~{~A~%~}" (reverse prose)))))
                                    blocks))
               (setf prose nil))))
      (with-input-from-string (in tex)
        (loop for line = (read-line in nil)
              while line
              do (cond ((cl-ppcre:scan "^\\s*\\\\code\\b" line)
                        (end-prose)
                        (let ((code (loop for l = (read-line in nil)
                                          until (or (null l) (cl-ppcre:scan "^\\s*\\\\endcode\\b" l))
                                          collect l)))
                          (push (cons :code (parse-tex (format nil "~{~A~^~%~}" code) :code t))
                                blocks)))
                       (t (push line prose)))))
      (end-prose))
    (nreverse blocks)))

(defun prose-blocks (nodes)
  "Splits a run of prose nodes at paragraph breaks and gathers list items, which
may hold lists of their own."
  (let ((blocks '())
        (current '())
        (lists '()))              ; open lists, innermost first; each holds its items, newest first
    (labels ((add-block (block)
               (if lists
                   (if (car lists)
                       (nconc (first (car lists)) (list block))
                       (push (list :item block) (car lists)))
                   (push block blocks)))
             (end-paragraph ()
               (let ((p (trim-nodes (nreverse current))))
                 (when p (add-block (cons :p p))))
               (setf current '()))
             (end-list ()
               (let ((items (nreverse (pop lists))))
                 (add-block (cons :list items)))))
      (dolist (node nodes)
        (cond ((equal node '(:par)) (end-paragraph))
              ((equal node '(:list-begin)) (end-paragraph) (push '() lists))
              ((equal node '(:list-end)) (end-paragraph) (when lists (end-list)))
              ((and (consp node) (eq (car node) :table)) (end-paragraph) (add-block node))
              ((and lists (consp node) (eq (car node) :item))
               (end-paragraph)
               (push (list :item (cons :label (cdr node))) (car lists)))
              (t (push node current))))
      (end-paragraph)
      (loop while lists do (end-list)))
    (nreverse blocks)))

(defun trim-nodes (nodes)
  "NODES without blank strings at either end."
  (flet ((blank (n) (and (stringp n) (every (lambda (c) (member c '(#\Space #\Tab #\Newline))) n))))
    (let* ((start (position-if-not #'blank nodes))
           (end (position-if-not #'blank nodes :from-end t)))
      (when start (subseq nodes start (1+ end))))))
