(in-package #:spec-browser.view)


(defun insert-buffer-string (buffer string)
  (let ((end-iter (gtk:text-buffer-get-end-iter buffer)))
    (gtk:text-buffer-insert buffer end-iter string -1)))

(defun render-inlines (buffer inlines)        ; a list of inlines
  (dolist (inline inlines)
    (render-inline buffer inline)))

(defun render-inline (buffer inline)          ; exactly one inline
  (if (stringp inline)
      (insert-buffer-string buffer inline)
      (case (first inline)
        ((:ref :term :link :secref :sense) (render-inlines buffer (cddr inline)))
        (otherwise (render-inlines buffer (rest inline))))))

(defun render-cells (buffer cells)
  (dolist (cell cells)
    (render-inlines buffer cell)
    (insert-buffer-string buffer (string #\tab))))

(defun render-rows (buffer rows)
  (dolist (row rows)
    (render-cells buffer row)
    (insert-buffer-string buffer (string #\Newline))))

(defun render-table (buffer table)
  (when table
    (when (eq :caption (first table))
      (render-inlines buffer (cadr table))
      (insert-buffer-string buffer (string #\Newline)))
    (when (eq :header (first table))
      (render-cells buffer (cadr table))
      (insert-buffer-string buffer (string #\Newline)))
    (when (eq :rows (first table))
      (render-rows buffer (cadr table))
      (insert-buffer-string buffer (string #\Newline)))
    (render-table buffer (rest table))))
      
(defun render-blocks (buffer blocks)
  (dolist (b blocks)
    (render-block buffer b)
    (insert-buffer-string buffer (format nil "~%~%"))))

(defun render-syntax (buffer line)
  (render-inlines buffer (getf line :name))
  (insert-buffer-string buffer " ")
  (render-inlines buffer (getf line :args))
  (when (getf line :values)
    (insert-buffer-string buffer " ⇒ ")
    (render-inlines buffer (getf line :values))))

(defun render-block (buffer block)
  (case (first block)
    ((:quote) (render-blocks buffer (rest block)))
    ((:heading :code-block) (render-inlines buffer (cddr block)))
    ((:list) (dolist (item (rest block))
               (if (eq :label (first item))
                   (render-inlines buffer (rest item))
                   (render-blocks buffer (rest item)))))
    ((:table) (render-table buffer (rest block)))
    ((:syntax) (render-syntax buffer (rest block)))
    (otherwise (render-inlines buffer (rest block)))))

(defun render-entry (text-view entry)
  (let ((buffer (gtk:text-view-buffer text-view)))
    (setf (gtk:text-buffer-text buffer) "")
    (loop for section in (spec-docset:entry-sections entry)
          for i from 0
          do
            (when (> i 0)
              (insert-buffer-string buffer (format nil "~%")))
            (insert-buffer-string buffer (first section))
            (insert-buffer-string buffer (string #\Newline))
            (render-blocks buffer (rest section)))))