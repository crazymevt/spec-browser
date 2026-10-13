;;;; compare.lisp — compares every section of every imported entry with the HyperSpec's
;;;; and the Community Spec's, and writes a summary and the differences to build/compare/.

(in-package #:spec-compare)

(defvar *sources-directory*
  (merge-pathnames "sources/" (asdf:system-source-directory "spec-browser")))

;;; Normalizing: the three renderings spell arrows, quotes and dashes differently,
;;; and break lines in different places. Words are compared, not spacing.

(defparameter *spellings*
  '(("↩" . "<NEWLINE>") ("•" . "") ("≤" . "<=") ("≥" . ">=") ("Figure:" . "") ("<<|" . "") ("|▷" . "▷") ("⟨" . "<") ("⟩" . ">") ("…" . "...") (". . ." . "...")
    ("OR=>" . "OR⇒") ("NOT=>" . "NOT⇒") ("=>" . "⇒") ("->" . "→") (">>" . "▷") ("|>" . "▷")
    ("==" . "≡") ("“" . "\"") ("”" . "\"") ("``" . "\"") ("''" . "\"") ("‘" . "'") ("’" . "'")
    ("---" . " ") ("—" . " ") ("--" . "-") ("–" . "-") (" " . " ")))

(defun normalize (text)
  (let ((s text))
    (loop for (from . to) in *spellings*
          do (setf s (cl-ppcre:regex-replace-all (cl-ppcre:quote-meta-chars from) s to)))
    ;; The Community Spec names a section by its title alone
    (setf s (cl-ppcre:regex-replace-all "(?:Section|Chapter) [\\d.]+ \\(([^)]*)\\)" s "\\1"))
    ;; The HyperSpec writes {form}* as form*, and drops the ↓ before some parameters
    (setf s (cl-ppcre:regex-replace-all "[{}↓]" s ""))
    (setf s (cl-ppcre:regex-replace-all "#<NoValue>" s "|"))
    ;; Figures are numbered only in the HyperSpec
    (setf s (cl-ppcre:regex-replace-all "Figure \\d+-\\d+\\s*\\." s ""))
    ;; Space around punctuation is a matter of layout
    (setf s (cl-ppcre:regex-replace-all "\\s*([(),.;:|\\[\\]])\\s*" s " \\1 "))
    (remove "" (cl-ppcre:split "\\s+" s) :test #'string=)))

;;; Comparing word lists

(defun lcs-table (a b)
  (let* ((n (length a)) (m (length b))
         (table (make-array (list (1+ n) (1+ m)) :element-type 'fixnum :initial-element 0)))
    (loop for i from (1- n) downto 0
          do (loop for j from (1- m) downto 0
                   do (setf (aref table i j)
                            (if (string= (aref a i) (aref b j))
                                (1+ (aref table (1+ i) (1+ j)))
                                (max (aref table (1+ i) j) (aref table i (1+ j)))))))
    table))

(defun lcs-length (a b)
  "The length of the longest common subsequence of word vectors A and B, in two rows of memory."
  (let ((prev (make-array (1+ (length b)) :element-type 'fixnum :initial-element 0))
        (row (make-array (1+ (length b)) :element-type 'fixnum :initial-element 0)))
    (loop for i from 1 to (length a)
          do (loop for j from 1 to (length b)
                   do (setf (aref row j)
                            (if (string= (aref a (1- i)) (aref b (1- j)))
                                (1+ (aref prev (1- j)))
                                (max (aref prev j) (aref row (1- j))))))
             (rotatef prev row))
    (aref prev (length b))))

(defun similarity (a b)
  (let ((a (coerce a 'vector)) (b (coerce b 'vector)))
    (if (and (zerop (length a)) (zerop (length b)))
        1.0
        (/ (* 2.0 (lcs-length a b)) (+ (length a) (length b))))))

(defun hunks (a b)
  "The differing runs of word lists A and B, as (a-words . b-words) pairs. Past a
size where a full table would cost too much, the middle that differs is one run."
  (let* ((a (coerce a 'vector)) (b (coerce b 'vector))
         (start (or (mismatch a b :test #'string=) (length a)))
         (from-end (mismatch a b :test #'string= :from-end t))
         (end-a (if from-end (max start from-end) start))
         (end-b (max start (- (length b) (- (length a) end-a)))))
    (setf a (subseq a start end-a) b (subseq b start end-b))
    (if (> (* (length a) (length b)) 4000000)
        (list (cons (coerce a 'list) (coerce b 'list)))
        (lcs-hunks a b))))

(defun lcs-hunks (a b)
  (let* ((table (lcs-table a b)) (i 0) (j 0) (da '()) (db '()) (out '()))
    (flet ((flush ()
             (when (or da db) (push (cons (reverse da) (reverse db)) out))
             (setf da '() db '())))
      (loop while (or (< i (length a)) (< j (length b)))
            do (cond ((and (< i (length a)) (< j (length b)) (string= (aref a i) (aref b j)))
                      (flush) (incf i) (incf j))
                     ((and (< i (length a))
                           (or (= j (length b)) (>= (aref table (1+ i) j) (aref table i (1+ j)))))
                      (push (aref a i) da) (incf i))
                     (t (push (aref b j) db) (incf j))))
      (flush))
    (nreverse out)))

;;; Classifying each section three ways

(defun classify (ours hs clcs)
  "How our words compare with the HyperSpec's and the Community Spec's, when they exist."
  (let ((oh (and hs (equal ours hs)))
        (oc (and clcs (equal ours clcs)))
        (hc (and hs clcs (equal hs clcs))))
    (cond ((and (null hs) (null clcs)) :only-ours)
          ((and oh (or oc (null clcs))) :agree)
          ((and oc (null hs)) :agree)
          (oh :clcs-differs)
          (oc :hyperspec-differs)
          (hc :ours-differs)
          (t :all-differ))))

(defun entry-key-of (entry)
  (cons (string-downcase (first (entry-names entry))) (string-downcase (entry-kind entry))))

(defun section-words (sections label)
  (let ((text (cdr (assoc label sections :test #'string-equal))))
    (when text (normalize text))))

(defun run (&key (sections '("Syntax" "Arguments and Values" "Description" "Examples"
                              "Affected By" "Exceptional Situations" "See Also" "Notes"
                              "Side Effects" "Value Type" "Initial Value"))
              (output (merge-pathnames "build/compare/" (asdf:system-source-directory "spec-browser"))))
  (let* ((*dpans-directory* (merge-pathnames "dpans3/dpANS3/" *sources-directory*))
         (entries (read-all-entries))
         (hyperspec (read-hyperspec (merge-pathnames "HyperSpec/" *sources-directory*)))
         (clcs (read-clcs (merge-pathnames "clcs/" *sources-directory*)))
         (counts (make-hash-table :test 'equal))
         (details '())
         (unmatched '()))
    (ensure-directories-exist output)
    (dolist (entry entries)
      (let* ((key (entry-key-of entry))
             (hs (gethash key hyperspec))
             (cl (gethash key clcs)))
        (unless (or hs cl) (push key unmatched))
        (dolist (label sections)
          (let ((tex (entry-section entry label)))
            (when tex
              (let* ((ours (normalize (blocks->text (section-blocks tex))))
                     (hs-words (and hs (section-words (getf hs :sections) label)))
                     (cl-words (and cl (section-words (getf cl :sections) label)))
                     (class (classify ours hs-words cl-words)))
                (incf (gethash (cons label class) counts 0))
                (incf (gethash (cons "All sections" class) counts 0))
                (unless (eq class :agree)
                  (push (list class label entry ours hs-words cl-words) details))))))))
    (write-summary (merge-pathnames "summary.txt" output) sections counts unmatched
                   (length entries) (hash-table-count hyperspec) (hash-table-count clcs))
    (write-details (merge-pathnames "details.txt" output) (nreverse details))
    (format t "~&Wrote ~A~%" output)))

(defparameter *classes* '(:agree :ours-differs :clcs-differs :hyperspec-differs :all-differ :only-ours))

(defun write-summary (file sections counts unmatched n-entries n-hs n-clcs)
  (with-open-file (s file :direction :output :if-exists :supersede :external-format :utf-8)
    (format s "Entries: ~D imported, ~D in the HyperSpec, ~D in the Community Spec; ~D matched in neither.~%~%"
            n-entries n-hs n-clcs (length unmatched))
    (format s "~26A~{~14@A~}~%" "Section" (mapcar #'string-downcase *classes*))
    (dolist (label (append sections '("All sections")))
      (format s "~26A~{~14D~}~%" label
              (mapcar (lambda (class) (gethash (cons label class) counts 0)) *classes*)))
    (when unmatched
      (format s "~%Not found in either:~%~{  ~A (~A)~%~}" (loop for (n . k) in unmatched collect n collect k)))))

(defun write-details (file details)
  (with-open-file (s file :direction :output :if-exists :supersede :external-format :utf-8)
    (dolist (class (rest *classes*))
      (format s "~&~%==================== ~A ====================~%" class)
      (loop for (c label entry ours hs cl) in details
            when (eq c class)
              do (format s "~%--- ~A / ~A (~A:~D)~%" (first (entry-names entry)) label
                         (entry-file entry) (entry-line entry))
                 (flet ((show (name other)
                          (when other
                            (format s "  vs ~A (~,2F):~%" name (similarity ours other))
                            (loop for (a . b) in (hunks ours other)
                                  for n from 0 below 6
                                  do (format s "    ours: ~{~A~^ ~}~%    ~4A: ~{~A~^ ~}~%"
                                             (subseq a 0 (min 25 (length a))) name
                                             (subseq b 0 (min 25 (length b))))))))
                   (show "HS" hs)
                   (show "CLCS" cl))))))
