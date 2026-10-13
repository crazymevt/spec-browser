;;;; package.lisp

(defpackage #:spec-export
  (:use #:cl #:spec-import)
  (:import-from #:spec-docset #:write-docset)
  (:export #:export-common-lisp))
