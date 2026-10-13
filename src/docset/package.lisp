;;;; package.lisp

(defpackage #:spec-docset
  (:use #:cl)
  (:export
   ;; Writing
   #:write-docset
   ;; Reading
   #:docset #:open-docset #:docset-directory #:docset-manifest #:docset-index
   #:docset-id #:docset-title #:docset-packages #:docset-toc
   #:docset-entry #:entry-record #:find-records
   #:record-id #:record-names #:record-kind #:record-kind-name #:record-package
   #:record-parent #:record-summary
   #:find-docsets #:*docset-directories* #:*library-systems*
   #:lookup-symbol #:search-names
   ;; Entries
   #:entry-sections #:entry-section
   ;; Checking
   #:check-docset))

(defpackage #:spec-docset.data
  (:use)
  (:import-from #:cl #:nil #:t)
  (:documentation "The package docset data is read in: NIL and T are Lisp's, and any
other symbol a docset should not contain lands here, not in a real package."))
