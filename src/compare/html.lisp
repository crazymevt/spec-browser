;;;; html.lisp — the HyperSpec's and the Community Spec's entries as plain text, by section.

(in-package #:spec-compare)

(defun read-file (file)
  (with-open-file (in file :external-format '(:utf-8 :replacement #\?))
    (let ((s (make-string (file-length in))))
      (subseq s 0 (read-sequence s in)))))

(defun decode-entities (string)
  (cl-ppcre:regex-replace-all
   "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);" string
   (lambda (match code)
     (declare (ignore match))
     (cond ((char= (char code 0) #\#)
            (string (code-char (if (char-equal (char code 1) #\x)
                                   (parse-integer code :start 2 :radix 16)
                                   (parse-integer code :start 1)))))
           (t (let ((known (assoc code '(("lt" . "<") ("gt" . ">") ("amp" . "&") ("quot" . "\"")
                                         ("apos" . "'") ("nbsp" . " "))
                                  :test #'string-equal)))
                (if known (cdr known) (format nil "&~A;" code))))))
   :simple-calls t))

(defun html->text (html)
  (let* ((s (cl-ppcre:regex-replace-all "(?i)<(br|p|/p|pre|/pre|tr|/tr|li|div|/div)\\b[^>]*>" html
                                        (string #\Newline)))
         (s (cl-ppcre:regex-replace-all "<[^>]*>" s "")))
    (decode-entities s)))

(defun entry-key (names kind)
  (cons (string-downcase (string-trim " " (first names))) (string-downcase (string-trim " " kind))))

(defun split-names (string)
  (mapcar (lambda (n) (string-trim '(#\Space #\Newline #\Tab) n)) (cl-ppcre:split "," string)))

;;; The HyperSpec: one Body/ page per entry, headed "<I>Kind</I> <B>NAME, NAME</B>",
;;; with sections headed "<B>Label:</B>".

(defun hyperspec-entry (file)
  (let ((html (with-open-file (in file :external-format :latin-1)
                (let ((s (make-string (file-length in))))
                  (subseq s 0 (read-sequence s in))))))
    (cl-ppcre:register-groups-bind (kind names) ("<I>([^<]+)</I> <B>([^<]+)</B>" html)
      (let* ((labels (cl-ppcre:all-matches "<B>[A-Z][A-Za-z ]+:</B>" html))
            ;; The entry ends at the first rule after its sections; the X3J13 issue list follows
            (end (or (and labels (search "<HR>" html :start2 (first labels))) (length html)))
            (sections '()))
        (loop for (start after) on labels by #'cddr
              for next = (or (third (member start labels)) end)
              do (let ((label (subseq html (+ start 3) (- after 5))))
                   (push (cons label (html->text (subseq html after (min next end)))) sections)))
        (list :key (entry-key (split-names (decode-entities names)) kind)
              :file (file-namestring file)
              :sections (nreverse sections))))))

(defun read-hyperspec (directory)
  (let ((entries (make-hash-table :test 'equal)))
    (dolist (file (directory (merge-pathnames "Body/*_*.htm" directory)))
      (when (alpha-char-p (char (pathname-name file) 0))
        (let ((entry (hyperspec-entry file)))
          (when (and entry (getf entry :sections))
            (setf (gethash (getf entry :key) entries) entry)))))
    entries))

;;; The Community Spec: a node-type div, an h4.subsection title followed by the
;;; syntax, then h4.subsubheading sections up to the Backlinks.

(defun clcs-entry (file)
  (let ((html (read-file file)))
    (cl-ppcre:register-groups-bind (kind names)
        ("<div class=\"node-type\">([^<]*)</div>\\s*<h4 class=\"subsection\">([^<]*)</h4>" html)
      (let* ((title-end (+ (search "</h4>" html :start2 (search "class=\"subsection\"" html)) 5))
             (end (or (search "<h3>Backlinks" html) (length html)))
             (heads (cl-ppcre:all-matches "<h4 class=\"subsubheading\">[^<]*</h4>" html :start title-end :end end))
             (sections (list (cons "Syntax" (html->text (subseq html title-end (or (first heads) end)))))))
        (loop for (start after) on heads by #'cddr
              for next = (or (third (member start heads)) end)
              do (let ((label (string-trim '(#\Space #\Newline #\:)
                                           (html->text (subseq html start after)))))
                   (push (cons label (html->text (subseq html after next))) sections)))
        (list :key (entry-key (split-names (decode-entities names)) kind)
              :file (file-namestring file)
              :sections (nreverse sections))))))

(defun read-clcs (directory)
  (let ((entries (make-hash-table :test 'equal)))
    (dolist (file (directory (merge-pathnames "*.html" directory)))
      (let ((entry (ignore-errors (clcs-entry file))))
        (when entry
          (setf (gethash (getf entry :key) entries) entry))))
    entries))
