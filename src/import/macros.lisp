;;;; macros.lisp — what the dpANS macros mean.
;;;
;;; Macros that carry meaning (glossary terms, parameters, symbol references,
;;; definition lines, examples' arrows) are defined here as node builders. The
;;; many that only stand for text, like \Thetype or \Default, are read from the
;;; sources' own setup-*.tex files by LOAD-SETUP-DEFINITIONS.

(in-package #:spec-import)

(defvar *references* (make-hash-table :test 'equal)
  "Section or figure macro name, like \"Definitions\" -> its title, like
\"Section 1.4 (Definitions)\".")

(defun nodes (source)
  (parse-nested source))

(defun ref-name (source)
  "The symbol name a reference macro's argument spells."
  (string-trim " " (nodes->text (parse-literal source))))

;;; Semantic macros

(deftex "term" (:arg) (a) (list (cons :term (nodes a))))
(deftex "Term" (:arg) (a) (list (cons :term (nodes a))))
(deftex "param" (:arg) (a) (list (cons :param (parse-literal a))))
(deftex "f" (:arg) (a) (list (cons :code (parse-literal a))))
(deftex "i" (:arg) (a) (list (cons :i (nodes a))))
(deftex "j" (:arg) (a) (list (cons :i (nodes a))))
(deftex "b" (:arg) (a) (list (cons :b (nodes a))))
(deftex "ttref" (:arg) (a) (list (cons :code (parse-literal a))))
(deftex "loopref" (:arg) (a) (list (list :ref :loop (ref-name a))))
(deftex "kwd" (:arg) (a) (list (list :code (concatenate 'string ":" (ref-name a)))))

(macrolet ((refs (&rest pairs)
             `(progn ,@(loop for (name kind) on pairs by #'cddr
                             collect `(deftex ,name (:arg) (a) (list (list :ref ,kind (ref-name a))))))))
  (refs "funref" :function "macref" :macro "typeref" :type "specref" :special-operator
        "varref" :variable "declref" :declaration "conref" :constant "misc" :symbol
        "clref" :symbol))

(deftex "issue" (:arg) (a) nil)
(deftex "endissue" (:arg) (a) nil)
(deftex "reviewer" (:arg) (a) (list (cons :note (nodes a))))
(deftex "editornote" (:arg) (a) (list (cons :note (nodes a))))

(defun reference (source)
  (let* ((key (string-left-trim "\\" (string-trim " " source)))
         (title (gethash key *references*)))
    (list (list :secref key (or title key)))))

(deftex "secref" (:arg) (a) (reference a))
(deftex "chapref" (:arg) (a) (reference a))
(deftex "figref" (:arg) (a) (reference a))
(deftex "Figref" (:arg) (a) (reference a))

;;; Example arrows and markers

(deftex "EV" () () (list "⇒"))
(deftex "EQ" () () (list "≡"))
(deftex "OV" () () (list "OR⇒"))
(deftex "NV" () () (list "NOT⇒"))
(deftex "OUT" () () (list "▷"))
(deftex "IN" (:arg) (a) (list (cons :input (nodes a))))
(deftex "CRLF" () () (list "↩"))
(deftex "NoReturn" () () (list "|"))

;;; Definition lines (the Syntax section)

(defun syntax (kind name args &optional values)
  (list (list* :syntax kind (parse-literal name) (nodes args)
               (when values (list :values (nodes values))))))

(macrolet ((with-values (kind &rest names)
             `(progn ,@(loop for name in names
                             collect `(deftex ,name (:word :word :arg) (name args values)
                                        (syntax ,kind name args values)))))
           (no-return (kind &rest names)
             `(progn ,@(loop for name in names
                             collect `(deftex ,name (:word :arg) (name args)
                                        (syntax ,kind name args "\\NoReturn"))))))
  (with-values :function "DefunWithValues" "DefunWithValuesNewline")
  (with-values :macro "DefmacWithValues" "DefmacWithValuesNewline")
  (with-values :special-operator "DefspecWithValues" "DefspecWithValuesNewline")
  (with-values :generic-function "DefgenWithValues" "DefgenWithValuesNewline")
  (no-return :function "DefunNoReturn")
  (no-return :macro "DefmacNoReturn")
  (no-return :special-operator "DefspecNoReturn"))

(deftex "Defun" (:word :arg) (name args) (syntax :function name args))
(deftex "Defmac" (:word :arg) (name args) (syntax :macro name args))
(deftex "Defmeth" (:word :arg) (name args) (syntax :method name args))

(defun listed-names (source)
  "The names listed by \\entry{...} in the last argument of the Multi macros."
  (let ((names '()))
    (cl-ppcre:do-register-groups (name) ("\\\\entry\\{([^}]*)\\}" source)
      (push name names))
    (nreverse names)))

(deftex "DefunMultiWithValues" (:word :word :arg) (args values entries)
  (loop for name in (listed-names entries)
        append (syntax :function name args values)))

(deftex "DefunMultiAccessorWithValues" (:word :word :word :arg) (args values newvalue entries)
  (let ((names (listed-names entries)))
    (append (loop for name in names append (syntax :accessor name args values))
            (loop for name in names
                  collect (list :syntax :setf (list name) (nodes args) :values (nodes newvalue))))))

(deftex "DefsetfMulti" (:word :word :arg) (args newvalue entries)
  (loop for name in (listed-names entries)
        append (list (list :syntax :setf (list name) (nodes args) :values (nodes newvalue)))))

(deftex "Defsetf" (:word :word :arg) (name args newvalue)
  (list (list :syntax :setf (parse-literal name) (nodes args) :values (nodes newvalue))))

(deftex "Deftype" (:arg :arg) (name args)
  (list (list :syntax :type (parse-literal name) (nodes args))))

(deftex "entry" (:arg) (a) (nodes a))

;;; Figures and tables: (:table caption-nodes (header-nodes...) row-nodes), where
;;; the row nodes hold (:cell) and (:row) markers.

(defun table (caption headers rows)
  (list (list :table (nodes caption) (mapcar #'nodes headers) (nodes rows))))

(deftex "tablefigtwo" (:arg :arg :arg :arg) (caption a b rows) (table caption (list a b) rows))
(deftex "tablefigthree" (:arg :arg :arg :arg :arg) (caption a b c rows) (table caption (list a b c) rows))
(deftex "tablefigfour" (:arg :arg :arg :arg :arg :arg) (caption a b c d rows)
  (table caption (list a b c d) rows))

(dolist (name '("displaytwo" "displaythree" "displayfour" "showtwo" "showthree"))
  (deftex name (:arg :arg) (caption rows) (table caption '() rows)))

(deftex "endfig" () () nil)
(deftex "thenextfigure" () () (list "the next figure"))
(deftex "Thenextfigure" () () (list "The next figure"))

;;; Index entries are dropped; a new glossary term is still a term

(deftex "logidx" (:arg :arg) (kind text) nil)
(deftex "newterm" (:arg) (a) (list (cons :term (nodes a))))

(deftex "sub" (:arg) (a) (list (cons :sub (nodes a))))
(deftex "packref" (:arg) (a) (list (list :ref :package (string-upcase (ref-name a)))))
(deftex "uppercase" (:arg) (a) (list (string-upcase (nodes->text (nodes a)))))
(deftex "ff" (:arg) (a) (list (cons :code (parse-literal a)) " "))

;;; Lists

(deftex "beginlist" () () (list (list :list-begin)))
(deftex "endlist" () () (list (list :list-end)))
(deftex "item" (:arg) (a) (list (cons :item (nodes a))))
(deftex "itemitem" (:arg) (a) (list (cons :item (nodes a))))
(deftex "itemitemitem" (:arg) (a) (list (cons :item (nodes a))))

;;; Lambda list keywords and other small pieces

(deftex "opt" () () (list (list :code "&optional")))
(deftex "rest" () () (list (list :code "&rest")))
(deftex "key" () () (list (list :code "&key")))
(deftex "allow" () () (list (list :code "&allow-other-keys")))
(deftex "body" () () (list (list :code "&body")))
(deftex "whole" () () (list (list :code "&whole")))
(deftex "environment" () () (list (list :code "&environment")))
(deftex "aux" () () (list (list :code "&aux")))
(deftex "plus" (:arg) (a) (append (nodes a) (list "+")))
(deftex "star" (:arg) (a) (append (nodes a) (list "*")))
(deftex "curly" (:arg) (a) (append (list "{") (nodes a) (list "}")))
(deftex "ang" (:arg) (a) (list "⟨" (cons :i (nodes a)) "⟩"))
(deftex "lbr" () () (list "{"))
(deftex "rbr" () () (list "}"))
(deftex "lbracket" () () (list "["))
(deftex "rbracket" () () (list "]"))
(deftex "hat" () () (list "^"))
(deftex "bq" () () (list "`"))
(deftex "BSlash" () () (list "\\"))
(deftex "bull" () () (list "•"))
(deftex "tilde" () () (list "~"))
(deftex "formatOp" (:arg) (a) (list (list :code (concatenate 'string "~" (nodes->text (parse-literal a))))))
(deftex "etc" () () (when (eql (peek) #\.) (incf *pos*)) (list (list :i "etc.")))
(deftex "meaning" (:arg) (a) (list (cons :sense (nodes a))))
(deftex "sim" () () (list "~"))
(deftex "empty" () () (list (list :code "()")))
(deftex "Lisp" () () (list "Lisp"))
(deftex "CLtL" () () (list (list :i "Common Lisp: The Language")))
(deftex "TeX" () () (list "TeX"))

;;; TeX primitives and layout macros: kept for their contents, or dropped

(dolist (name '("relax" "ignorespaces" "noindent" "indent" "goodbreak" "medbreak" "smallbreak"
                "bigbreak" "endgraf" "leavevmode" "hfill" "hfil" "hss" "vfill" "vfil" "quad"
                "qquad" "dummy" "tt" "it" "rm" "bf" "sl" "sc" "sf" "prbfourteen" "bfsixteen"
                "keyword" "arg" "function" "word" "break" "nobreak" "allowbreak" "obeylines"
                "obeyspaces" "eatcr" "begingroup" "endgroup" "bgroup" "egroup" "displaystyle"
                "textstyle" "scriptstyle" "strut" "null" "unskip" "newpage" "eject"
                "fi" "else" "span" "omit" "hrule" "vrule" "removelastskip" "removedepth"
                "NIPS" "smash" "hfilneg" "enspace" "thinspace" "negthinspace" "noalign"
                "ifeditornotes" "ifisslog" "dospecialcomma" "donormalcomma" "centerline"
                "line" "rlap" "llap" "underline" "overline" "mathstrut" "phantom" "vphantom"
                "Vtop" "vtop" "blankline" "hbox" "vbox" "mbox" "par" "ifmmode" "settabs"
                "cleartabs" "openup" "jot" "boxfig" "cboxfig" "kcnocboxfig" "rulefig" "figure"))
  (unless (gethash name *macros*)
    (deftext name () "")))

(deftex "par" () () (list (list :par)))
(deftex "cr" () () (list (list :row)))
(deftex "crcr" () () (list (list :row)))
(deftex "penalty" (:number) (n) nil)
(deftex "vskip" (:dimen) (d) nil)
(deftex "hskip" (:dimen) (d) nil)
(deftex "kern" (:dimen) (d) nil)
(deftex "raise" (:dimen) (d) nil)
(deftex "lower" (:dimen) (d) nil)
(deftex "Vskip" (#\!) (d) nil)
(deftex "VPskip" (#\!) (d) nil)
(deftex "catcode" (:number #\=) (c eq) (read-number) nil)

(deftex "char" (:number) (n)
  (let ((code (cond ((zerop (length n)) nil)
                    ((char= (char n 0) #\') (parse-integer n :start 1 :radix 8 :junk-allowed t))
                    ((char= (char n 0) #\") (parse-integer n :start 1 :radix 16 :junk-allowed t))
                    ((char= (char n 0) #\`) (char-code (char n (1- (length n)))))
                    (t (parse-integer n :junk-allowed t)))))
    (when code (list (string (code-char code))))))

(deftex "let" () ()
  (read-arg) (skip-spaces)
  (when (eql (peek) #\=) (incf *pos*))
  (read-arg)
  nil)

(defun read-definition ()
  "Reads a \\def met in the text and defines it, if its parameters are simple ones."
  (let* ((name (string-left-trim "\\" (read-arg)))
         (start *pos*))
    (loop for c = (peek) until (or (null c) (char= c #\{)) do (incf *pos*))
    (let ((spec (subseq *src* start *pos*)))
      (when (peek)
        (let ((body (read-balanced)))
          (multiple-value-bind (params ok) (definition-params spec)
            (when (and ok (not (tex-macro-fn (gethash name *macros* (make-tex-macro nil)))))
              (deftext name params body)))))))
  nil)

(deftex "def" () () (read-definition))
(deftex "gdef" () () (read-definition))
(deftex "edef" () () (read-definition))

(deftex "halign" () ()
  ;; Skip "to \\hsize" and the template row, which is layout only
  (loop for c = (peek) until (or (null c) (char= c #\{)) do (incf *pos*))
  (let* ((body (read-balanced))
         (template-end (search "\\cr" body)))
    (table "" '() (if template-end (subseq body (+ template-end 3)) body))))

(deftex "caption" (:arg) (a) (list (cons :caption (nodes a))))
(deftex "dimen" (:number) (n)
  ;; \\dimen0=2pc sets a register; a bare \\dimen0 is a value inside another dimension
  (skip-spaces)
  (when (eql (peek) #\=) (incf *pos*) (read-dimen))
  nil)
(deftex "tabskip" (:dimen) (d) nil)

(deftex "setbox" () ()
  (read-number) (skip-spaces)
  (when (eql (peek) #\=) (incf *pos*))
  (read-arg) (read-arg)
  nil)

;;; Math

(loop for (name text) on '("rightarrow" "→" "Rightarrow" "⇒" "leftarrow" "←" "equiv" "≡"
                           "langle" "⟨" "rangle" "⟩" "ldots" "…" "cdots" "⋯" "dots" "…"
                           "le" "≤" "leq" "≤" "ge" "≥" "geq" "≥" "ne" "≠" "neq" "≠" "pi" "π"
                           "alpha" "α" "beta" "β" "gamma" "γ" "delta" "δ" "sigma" "σ"
                           "epsilon" "ε" "theta" "θ" "lambda" "λ" "mu" "μ" "times" "×"
                           "cdot" "·" "pm" "±" "infty" "∞" "lbrack" "[" "rbrack" "]"
                           "vert" "|" "mid" "|" "wedge" "∧" "vee" "∨" "neg" "¬" "lnot" "¬"
                           "triangleright" "▷" "hookleftarrow" "↩" "downarrow" "↓" "uparrow" "↑"
                           "sum" "Σ" "prod" "Π" "log" " log " "exp" " exp " "sin" " sin " "cos" " cos "
                           "tan" " tan " "over" "/" "lfloor" "⌊" "rfloor" "⌋" "lceil" "⌈"
                           "rceil" "⌉" "in" "∈" "subseteq" "⊆" "cup" "∪" "cap" "∩" "emptyset" "∅"
                           "backslash" "\\" "prime" "′" "circ" "∘" "bullet" "•" "ast" "*"
                           "lbrace" "{" "rbrace" "}" "sqrt" "√" "Longrightarrow" "⟹"
                           "longrightarrow" "⟶" "left" "" "right" "" "big" "" "Big" "" "bigl" ""
                           "bigr" "" "mathrel" "" "mathop" "" "limits" "" "nolimits" "")
               by #'cddr
      do (let ((text text)) (deftex name () () (list text))))

(deftex "buildrel" () ()
  (let ((above (read-arg)))
    (skip-spaces)
    (when (eql (peek) #\\) (incf *pos*) (read-letters))
    (append (nodes above) (nodes (read-arg)))))

;;; Text macros from the sources' setup files

(defun definition-params (spec)
  "Turns a \\def parameter text like \"#1 #2\" or \"#1#2\" into argument kinds,
or returns NIL when it uses other delimiters."
  (let ((spec (string-trim '(#\Space #\Tab #\Newline) spec)))
    (cond ((zerop (length spec)) (values '() t))
          ((cl-ppcre:scan "^(#\\d\\s*)+$" spec)
           (let ((params '()))
             (cl-ppcre:do-matches (s e "#\\d\\s*" spec)
               (push (if (and (< (+ s 2) e) (< e (length spec))) :word :arg) params))
             (values (nreverse params) t)))
          (t (values nil nil)))))

(defun load-setup-definitions (directory)
  "Defines every simple \\def in DIRECTORY's .tex files that this file did not
define itself, setup-*.tex first, and reads the section and figure titles."
  (let ((builtins (loop for name being the hash-keys of *macros* collect name))
        (files (sort (directory (merge-pathnames "*.tex" directory))
                     (lambda (a b)
                       (let ((sa (search "setup" (pathname-name a))) (sb (search "setup" (pathname-name b))))
                         (if (eql sa sb) (string< (namestring a) (namestring b)) (eql sa 0)))))))
    (dolist (file files)
      (let* ((source (read-file file))
             (setup (eql 0 (search "setup" (pathname-name file))))
             (references (or (search "setup-sections" (namestring file))
                             (search "setup-figures" (namestring file)))))
        (cl-ppcre:do-scans (s e rs re "\\\\[gex]?def\\\\([A-Za-z]+)" source)
          (let* ((name (subseq source (aref rs 0) (aref re 0)))
                 (line-start (or (position #\Newline source :end s :from-end t) 0))
                 (brace (position #\{ source :start e)))
            (when (and brace (not (find #\% source :start line-start :end s)))
              (multiple-value-bind (params ok) (definition-params (subseq source e brace))
                (when ok
                  (let ((body (let ((*src* source) (*pos* brace))
                                (read-balanced))))
                    (cond (references
                           (when (null params)
                             (setf (gethash name *references*) body)))
                          ((member name builtins :test #'string=))
                          ;; A chapter's own helpers add names but never replace the
                          ;; setup files' (concept-syntax.tex has its own \\t)
                          ((and (not setup) (gethash name *macros*)))
                          (t (deftext name params body)))))))))
        (when setup
          (cl-ppcre:do-register-groups (name target)
              ("(?m)^\\\\let\\\\([A-Za-z]+)\\s*=?\\s*\\\\([A-Za-z]+)" source)
            (let ((m (gethash target *macros*)))
              (when (and m (not (member name builtins :test #'string=)))
                (setf (gethash name *macros*) m)))))))))

(defun read-file (file)
  (with-open-file (in file :external-format :latin-1)
    (let ((s (make-string (file-length in))))
      (subseq s 0 (read-sequence s in)))))
