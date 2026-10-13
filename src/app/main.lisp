(in-package #:spec-browser.app)

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
      (gio:application-run app nil))))