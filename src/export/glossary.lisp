;;;; glossary.lisp — the glossary (chapter 26) as entries, and matching \term{...} to them.

(in-package #:spec-export)

(defun read-glossary (directory)
  "The glossary's entries as (term . tex) pairs, in order."
  (let* ((source (spec-import::read-file (merge-pathnames "concept-glossary.tex" directory)))
         (start (search "\\gentry{" source :start2 (search "%% Glossary" source)))
         (entries '()))
    (loop with pos = start
          while pos
          do (let* ((open (+ pos (length "\\gentry{")))
                    (close (let ((spec-import::*src* source) (spec-import::*pos* (1- open)))
                             (spec-import::read-balanced)
                             spec-import::*pos*))
                    (next (search "\\gentry{" source :start2 close))
                    (term (subseq source open (1- close)))
                    (body (subseq source close (or next (length source)))))
               (push (cons term (clean-glossary-body body)) entries)
               (setf pos next)))
    (nreverse entries)))

(defun clean-glossary-body (tex)
  "TEX without the glossary's letter headings, and with numbered senses as a list."
  (let* ((tex (cl-ppcre:regex-replace-all "(?m)^\\s*\\\\(first)?indextab\\{[^}]*\\}.*$" tex ""))
         (tex (cl-ppcre:regex-replace-all "(?m)^\\s*\\\\endlist\\s*$" tex ""))
         (tex (cl-ppcre:regex-replace-all "(?m)^\\s*%.*$" tex ""))
         (tex (cl-ppcre:regex-replace-all "(?m)^\\s*(\\d+[a-z]?\\.)\\s" tex
                                          (format nil "~%\\\\itemitem{\\1} ")))
         (first (search "\\itemitem{" tex)))
    (if first
        (format nil "~A~%\\beginlist~%~A~%\\endlist~%" (subseq tex 0 first) (subseq tex first))
        tex)))

(defun glossary-id (term)
  (concatenate 'string "glossary/" (string-downcase term)))

;;; Matching terms in the text to glossary entries

(defvar *glossary-terms* (make-hash-table :test 'equal)
  "Lowercase glossary term -> its entry id.")

(defun term-candidates (word)
  "WORD and the base forms it might be an inflection of."
  (let ((w (string-downcase (string-trim " " word))))
    (flet ((ends (suffix) (and (> (length w) (length suffix))
                               (string= suffix w :start2 (- (length w) (length suffix)))))
           (chop (n) (subseq w 0 (- (length w) n))))
      (remove-duplicates
       (remove nil
               (list w
                     (and (ends "'s") (chop 2))
                     (and (ends "ies") (concatenate 'string (chop 3) "y"))
                     (and (ends "es") (chop 2))
                     (and (ends "s") (chop 1))
                     (and (ends "ed") (chop 2))
                     (and (ends "ed") (chop 1))
                     (and (ends "ing") (chop 3))
                     (and (ends "ing") (concatenate 'string (chop 3) "e"))
                     (and (ends "ly") (chop 2))
                     ;; "conses of lists" -> "cons", the first word inflected
                     (let ((space (position #\Space w)))
                       (and space (let ((first (subseq w 0 space)))
                                    (and (> (length first) 1) (char= (char first (1- (length first))) #\s)
                                         (concatenate 'string (subseq first 0 (1- (length first)))
                                                      (subseq w space))))))))
       :test #'string= :from-end t))))

(defun glossary-target (text)
  (loop for candidate in (term-candidates text)
        for id = (gethash candidate *glossary-terms*)
        when id return id))
