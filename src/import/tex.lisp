;;;; tex.lisp — reads the subset of plain TeX the dpANS sources use into a tree of nodes.
;;;
;;; A node is a string or a list whose head is a keyword, such as (:term "list")
;;; or (:ref :function "mapcar"). Macros come from a table: either a Lisp function
;;; that builds nodes from its argument sources, or a TeX body that is expanded
;;; and read again, the way TeX itself does it.

(in-package #:spec-import)

(defvar *src* "")
(defvar *pos* 0)

(defvar *code-mode* nil
  "True inside \\code blocks, where spaces and line breaks are kept and % is an ordinary character.")

(defvar *literal* nil
  "True inside inline code, where quotes and dashes stay as typed.")

(defvar *math* nil
  "True inside $...$, where ^ and _ make superscripts and subscripts.")

(defvar *unknown-macros* (make-hash-table :test 'equal)
  "Macro name -> how many times it was met without a definition.")

(defstruct (tex-macro (:constructor make-tex-macro (params &key body fn)))
  params body fn)

(defvar *macros* (make-hash-table :test 'equal))

(defmacro deftex (name params lambda-list &body body)
  "Defines macro NAME. PARAMS lists how each argument is read: :arg (one token or
{group}), :word (up to a space, as with TeX's #1<space>), :number, :dimen, or a
character the argument runs up to. BODY gets the arguments' sources and returns nodes."
  `(setf (gethash ,name *macros*)
         (make-tex-macro ',params :fn (lambda ,lambda-list
                                        (declare (ignorable ,@lambda-list))
                                        ,@body))))

(defun deftext (name params body)
  "Defines macro NAME as TeX source BODY, with #1... standing for its arguments."
  (setf (gethash name *macros*) (make-tex-macro params :body body)))

;;; Reading characters

(defun peek (&optional (offset 0))
  (let ((i (+ *pos* offset)))
    (when (< -1 i (length *src*)) (char *src* i))))

(defun letterp (c)
  (and c (or (char<= #\a c #\z) (char<= #\A c #\Z))))

(defun spacep (c)
  (member c '(#\Space #\Tab)))

(defun skip-spaces ()
  (loop while (spacep (peek)) do (incf *pos*)))

(defun skip-to-eol ()
  (loop for c = (peek) until (or (null c) (char= c #\Newline)) do (incf *pos*)))

(defun skip-comment ()
  "Skips a % comment, its line break and the next line's indentation, as TeX does."
  (skip-to-eol)
  (when (peek) (incf *pos*))
  (skip-spaces))

(defun blank-line-ahead-p ()
  "True when the line after point is blank, so the line break at point ends a paragraph."
  (loop for i from *pos*
        for c = (and (< i (length *src*)) (char *src* i))
        do (cond ((null c) (return t))
                 ((char= c #\Newline) (return t))
                 ((not (spacep c)) (return nil)))))

(defun skip-arg-space ()
  "Skips the spaces, and at most one line break, that TeX ignores before an argument."
  (unless *code-mode*
    (skip-spaces)
    (when (and (eql (peek) #\Newline) (not (progn (incf *pos*) (blank-line-ahead-p))))
      (skip-spaces))))

(defun read-letters ()
  (let ((start *pos*))
    (loop while (letterp (peek)) do (incf *pos*))
    (subseq *src* start *pos*)))

(defun read-balanced ()
  "Reads the {group} at point and returns its inner source."
  (incf *pos*)
  (let ((start *pos*) (depth 1))
    (loop for c = (peek)
          do (cond ((null c) (return (subseq *src* start)))
                   ((char= c #\\) (incf *pos* 2))
                   ((char= c #\{) (incf depth) (incf *pos*))
                   ((char= c #\})
                    (incf *pos*)
                    (when (zerop (decf depth))
                      (return (subseq *src* start (1- *pos*)))))
                   ((and (char= c #\%) (not *code-mode*)) (skip-to-eol))
                   (t (incf *pos*))))))

(defun read-arg ()
  (skip-arg-space)
  (let ((c (peek)))
    (cond ((null c) "")
          ((char= c #\{) (read-balanced))
          ((char= c #\\)
           (let ((start *pos*))
             (incf *pos*)
             (if (letterp (peek)) (read-letters) (incf *pos*))
             (subseq *src* start *pos*)))
          (t (incf *pos*) (string c)))))

(defun read-word ()
  "Reads an argument delimited by a space, as TeX reads #1 in \\def\\x#1 #2{...}."
  (loop while (or (spacep (peek)) (eql (peek) #\Newline)) do (incf *pos*))
  (flet ((skip-delimiter ()
           (skip-spaces)
           (when (eql (peek) #\Newline) (incf *pos*) (skip-spaces))))
    (if (eql (peek) #\{)
        (prog1 (read-balanced) (skip-delimiter))
        (let ((start *pos*))
          (loop for c = (peek)
                until (or (null c) (spacep c) (char= c #\Newline))
                do (incf *pos*))
          (prog1 (subseq *src* start *pos*) (skip-delimiter))))))

(defun read-number ()
  (skip-spaces)
  (let ((start *pos*))
    (when (member (peek) '(#\- #\+ #\' #\")) (incf *pos*))
    (if (eql (peek) #\`)
        (progn (incf *pos*) (when (eql (peek) #\\) (incf *pos*)) (incf *pos*))
        (loop while (and (peek) (digit-char-p (peek) 16)) do (incf *pos*)))
    (subseq *src* start *pos*)))

(defun read-dimen ()
  "Reads a TeX dimension or glue such as 4pt, 1pc plus 3pc, or \\normalparskip."
  (labels ((one ()
             (skip-spaces)
             (cond ((eql (peek) #\\) (incf *pos*) (read-letters))
                   (t (loop while (member (peek) '(#\- #\+ #\. #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9))
                            do (incf *pos*))
                      (skip-spaces)
                      (read-letters))))
           (keyword-ahead (word)
             (let ((save *pos*))
               (skip-spaces)
               (if (and (<= (+ *pos* (length word)) (length *src*))
                        (string= word *src* :start2 *pos* :end2 (+ *pos* (length word))))
                   (progn (incf *pos* (length word)) t)
                   (progn (setf *pos* save) nil)))))
    (let ((start *pos*))
      (one)
      (when (keyword-ahead "plus") (one))
      (when (keyword-ahead "minus") (one))
      (subseq *src* start *pos*))))

(defun read-until (char)
  (let ((start *pos*))
    (loop for c = (peek) until (or (null c) (char= c char)) do (incf *pos*))
    (prog1 (subseq *src* start *pos*)
      (when (peek) (incf *pos*)))))

(defun read-param (kind)
  (case kind
    (:arg (read-arg))
    (:word (read-word))
    (:number (read-number))
    (:dimen (read-dimen))
    (t (read-until kind))))

;;; Parsing

(defun parse-tex (string &key code literal)
  "Reads TeX source STRING into a list of nodes. CODE reads it as a \\code block."
  (let ((*src* string) (*pos* 0) (*code-mode* code) (*literal* (or literal code)))
    (parse-nodes)))

(defun parse-nested (string)
  "Reads STRING in the current mode, for macro arguments and expansions."
  (let ((*src* string) (*pos* 0))
    (parse-nodes)))

(defun parse-literal (string)
  (let ((*literal* t)) (parse-nested string)))

(defun parse-nodes (&optional stop)
  (let ((nodes '())
        (text (make-string-output-stream)))
    (labels ((flush ()
               (let ((s (get-output-stream-string text)))
                 (when (plusp (length s)) (push s nodes))))
             (add (more)
               (flush)
               (dolist (n more) (push n nodes)))
             (out (x)
               (if (stringp x) (write-string x text) (write-char x text)))
             (ahead (string)
               (let ((end (+ *pos* (length string))))
                 (and (<= end (length *src*)) (string= string *src* :start2 *pos* :end2 end)))))
      (loop for c = (peek)
            do (cond ((null c) (return))
                     ((and stop (char= c stop)) (incf *pos*) (return))
                     ((and (char= c #\{) (not *code-mode*) (tt-group-p))
                      ;; {\tt ...} is inline code, where ~ is a tilde
                      (incf *pos* 4)
                      (add (list (cons :code (let ((*literal* t)) (parse-nodes #\}))))))
                     ((char= c #\{) (incf *pos*) (add (parse-nodes #\})))
                     ((char= c #\}) (incf *pos*))
                     ((char= c #\\) (incf *pos*) (add (read-control)))
                     ((and *code-mode* (char= c #\#) (eql (peek 1) #\\) (letterp (peek 2)))
                      ;; #\b where the sources mean #\\b, as three examples have it
                      (incf *pos* 2) (out "#\\"))
                     ((and *code-mode* (char= c #\$) (member (peek 1) '(#\\ #\_ #\^)))
                      ;; Math in code, like #\$\alpha$; a $ alone is FORMAT's ~$
                      (add (read-math)))
                     (*code-mode* (incf *pos*) (out c))
                     ((char= c #\%) (skip-comment))
                     ((char= c #\$) (add (read-math)))
                     ((char= c #\Newline)
                      (incf *pos*)
                      (cond ((blank-line-ahead-p)
                             (loop while (and (peek) (or (spacep (peek)) (char= (peek) #\Newline)))
                                   do (incf *pos*))
                             (add (list (list :par))))
                            (t (out #\Space) (skip-spaces))))
                     ((char= c #\~) (incf *pos*) (out (if *literal* #\~ #\Space)))
                     ((and (char= c #\&) (not *literal*)) (incf *pos*) (add (list (list :cell))))
                     ((and *math* (member c '(#\^ #\_)))
                      (incf *pos*)
                      (add (list (cons (if (char= c #\^) :sup :sub) (parse-nested (read-arg))))))
                     (*literal* (incf *pos*) (out c))
                     ((ahead "---") (incf *pos* 3) (out "—"))
                     ((ahead "--") (incf *pos* 2) (out "–"))
                     ((ahead "``") (incf *pos* 2) (out "“"))
                     ((ahead "''") (incf *pos* 2) (out "”"))
                     ((char= c #\`) (incf *pos*) (out "‘"))
                     ((char= c #\') (incf *pos*) (out "’"))
                     (t (incf *pos*) (out c))))
      (flush)
      (nreverse nodes))))

(defun tt-group-p ()
  "True when point is at {\\tt followed by a non-letter."
  (and (< (+ *pos* 4) (length *src*))
       (string= "{\\tt" *src* :start2 *pos* :end2 (+ *pos* 4))
       (not (letterp (peek 4)))))

(defun read-math ()
  "Reads $...$ or $$...$$ at point."
  (incf *pos*)
  (when (eql (peek) #\$) (incf *pos*))
  (prog1 (list (cons :math (let ((*math* t)) (parse-nodes #\$))))
    (when (eql (peek) #\$) (incf *pos*))))

(defun read-control ()
  "Reads the control sequence after a backslash and returns what it expands to."
  (let ((c (peek)))
    (cond ((null c) nil)
          ((letterp c)
           (let ((name (read-letters)))
             (unless *code-mode* (skip-spaces))
             (expand name)))
          (t (incf *pos*)
             (control-symbol c)))))

(defun control-symbol (c)
  (case c
    ((#\{ #\} #\$ #\& #\# #\% #\_ #\^ #\~) (list (string c)))
    (#\\ (list "\\"))
    ((#\Space #\Newline #\Tab) (list " "))
    ((#\/ #\- #\, #\! #\; #\: #\+ #\.) nil)
    (#\> (list ">"))
    ((#\' #\` #\" #\=) (parse-nested (read-arg)))
    (t (incf (gethash (string c) *unknown-macros* 0)) nil)))

(defun substitute-params (body args)
  (with-output-to-string (s)
    (loop with i = 0
          while (< i (length body))
          do (let ((c (char body i)))
               (cond ((and (char= c #\#) (< (1+ i) (length body)) (digit-char-p (char body (1+ i))))
                      (write-string (or (nth (1- (digit-char-p (char body (1+ i)))) args) "") s)
                      (incf i 2))
                     ((and (char= c #\#) (< (1+ i) (length body)) (char= (char body (1+ i)) #\#))
                      (write-char #\# s)
                      (incf i 2))
                     (t (write-char c s) (incf i)))))))

(defvar *expansion-depth* 0)

(defvar *outer-macro* nil
  "The outermost macro being expanded, to tell where unknown macros come from.")

(defvar *unknown-sources* (make-hash-table :test 'equal)
  "(unknown . outermost macro) -> count.")

(defun expand (name)
  (let ((m (gethash name *macros*)))
    (cond ((null m)
           (incf (gethash name *unknown-macros* 0))
           (incf (gethash (cons name *outer-macro*) *unknown-sources* 0))
           nil)
          ((> *expansion-depth* 50)
           (warn "Macro \\~A expands too deeply." name)
           nil)
          (t
           (let ((args (mapcar #'read-param (tex-macro-params m)))
                 (*expansion-depth* (1+ *expansion-depth*))
                 (*outer-macro* (or *outer-macro* name)))
             (if (tex-macro-fn m)
                 (apply (tex-macro-fn m) args)
                 (parse-nested (substitute-params (tex-macro-body m) args))))))))
