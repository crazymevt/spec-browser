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

(defun find-docset (docsets &key title id)
  (unless (or title id)
    (error "find-docset requires either a title or an id"))
  (let ((lookup-fn (if title 
                       #'spec-docset:docset-title
                       #'spec-docset:docset-id)))
    (find (or title id) docsets :test 'string= :key lookup-fn)))

(defun activate (app)
  (let ((window (make-instance 'gtk:application-window :application app
                               :title "Spec Browser" :default-width 1024 :default-height 768))
        (text-view (make-instance 'gtk:text-view 
                                       :editable nil 
                                       :cursor-visible nil
                                       :wrap-mode :word
                                       :left-margin 10
                                       :right-margin 10
                                       :top-margin 10
                                       :bottom-margin 10))
        (scrolled-window (make-instance 'gtk:scrolled-window)))
    (setf (gtk:scrolled-window-child scrolled-window) text-view)
    (setf (gtk:window-child window) scrolled-window)
    (gtk:window-present window)))

(defun main ()
  (unless (glib:main-thread-p)
    (error "GTK must run on the main thread; start this from a script."))
  (let ((app (gtk:application-new "org.lisp.SpecBrowser" '(:default-flags))))
    (gobject:connect app :activate 'activate)
    (glib:with-gtk-float-traps
      (setf *docsets* (load-docsets))
      (gio:application-run app nil))))