;;;; package.lisp

(defpackage #:spec-export
  (:use #:cl #:spec-import)
  (:import-from #:docset #:write-docset)
  (:export #:export-common-lisp))
