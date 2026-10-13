(in-package #:spec-browser.app)

(defvar *docsets* nil)

(defun data-directory ()
  (merge-pathnames "data/" (asdf:system-source-directory "spec-browser")))

(defun load-docsets ()
  (let ((docsets
         (spec-docset:find-docsets
          :directories (list (data-directory)))))
    (loop for docset in docsets
          do
            (format t "title: ~s id: ~s Length: ~d~%" 
                    (spec-docset:docset-title docset)
                    (spec-docset:docset-id docset)
                    (length (spec-docset:docset-index docset)))
            (finish-output))
    docsets))


(defun activate (app)
  (let ((window (make-instance 'gtk:application-window :application app
                               :title "Spec Browser" :default-width 1024 :default-height 768)))
    (gtk:window-present window)))

(defun main ()
  (unless (glib:main-thread-p)
    (error "GTK must run on the main thread; start this from a script."))
  (let ((app (gtk:application-new "org.lisp.SpecBrowser" '(:default-flags))))
    (gobject:connect app :activate 'activate)
    (glib:with-gtk-float-traps
      (setf *docsets* (load-docsets))
      (gio:application-run app nil))))