(in-package #:spec-browser.app)

;;; Each spec is a style keyword and the initargs for its gtk:text-tag. Tags
;;; added later win where they set the same property, so the list runs from
;;; general to specific: :body first, inline styles near the end.
(defparameter *style-specs*
  '((:body)
    ;; Blocks
    (:title :weight 700 :scale 1.8d0 :pixels-below-lines 4)
    (:kind :style :italic :foreground "dim gray")
    (:heading :weight 700 :scale 1.25d0 :pixels-above-lines 10 :pixels-below-lines 2)
    (:heading-1 :weight 700 :scale 1.6d0 :pixels-above-lines 12)
    (:heading-2 :weight 700 :scale 1.4d0 :pixels-above-lines 10)
    (:heading-3 :weight 700 :scale 1.2d0 :pixels-above-lines 8)
    (:heading-4 :weight 700 :scale 1.1d0 :pixels-above-lines 6)
    (:quote :left-margin 30)
    (:syntax :family "monospace" :left-margin 30)
    (:syntax-name :weight 700)
    (:code-block :family "monospace" :left-margin 30 :paragraph-background "#f2f2f2")
    (:table :family "monospace")
    (:table-header :weight 700)
    (:marker :weight 700)
    ;; Inlines
    (:italic :style :italic)
    (:bold :weight 700)
    (:code :family "monospace" :foreground "#6a3d9a")
    (:param :style :italic :foreground "#1f4e79")
    (:note :style :italic :foreground "dim gray")
    (:link :foreground "#1a5fb4" :underline :single)))

(defun make-style (tag-table)
  (let ((style-hash (make-hash-table)))
    (dolist (spec *style-specs*)
      (let* ((tag-name (string-downcase (first spec)))
             (tag (apply #'make-instance 'gtk:text-tag :name (cons tag-name (rest spec)))))
        (setf (gethash (first spec) style-hash) tag)
        (gtk:text-tag-table-add tag-table tag)))
    (lambda (key) (gethash key style-hash))))
  