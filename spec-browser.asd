;;;; spec-browser.asd

(defsystem "spec-browser"
  :description "A browser for the Common Lisp standard and library docs."
  :author "Jessie Hughart"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("spec-browser/app")
  :entry-point "spec-browser.app:main")

(defsystem "spec-browser/docset"
  :description "Reads and writes docsets, the browser's documentation format. No dependencies."
  :author "Jessie Hughart"
  :license "MIT"
  :components ((:module "src/docset"
                :serial t
                :components ((:file "package")
                             (:file "docset")
                             (:file "check")))))

(defsystem "spec-browser/export"
  :description "Writes the Common Lisp docset from the dpANS3 sources."
  :author "Jessie Hughart"
  :license "MIT"
  :depends-on ("spec-browser/import" "spec-browser/docset")
  :components ((:module "src/export"
                :serial t
                :components ((:file "package")
                             (:file "glossary")
                             (:file "export")))))

(defsystem "spec-browser/import"
  :description "Turns the dpANS3 TeX sources of the Common Lisp standard into entry data."
  :author "Jessie Hughart"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("cl-ppcre")
  :components ((:module "src/import"
                :serial t
                :components ((:file "package")
                             (:file "tex")
                             (:file "macros")
                             (:file "entries")
                             (:file "text")))))

(defsystem "spec-browser/compare"
  :description "Checks the imported entries against the HyperSpec and the Community Spec."
  :author "Jessie Hughart"
  :license "MIT"
  :depends-on ("spec-browser/import")
  :components ((:module "src/compare"
                :serial t
                :components ((:file "package")
                             (:file "html")
                             (:file "compare")))))

(defsystem "spec-browser/view"
  :description "Draws docset entries into a GTK text view and keeps a page's history. The part that moves into Cadre."
  :author "Jessie Hughart"
  :license "MIT"
  :depends-on ("gtk4" "spec-browser/docset")
  :components ((:module "src/view"
                :serial t
                :components ((:file "package")
                             (:file "render")))))

(defsystem "spec-browser/app"
  :description "The spec browser's window: header bar, search, contents, and its own styles and highlighter."
  :author "Jessie Hughart"
  :license "MIT"
  :depends-on ("spec-browser/view")
  :components ((:module "src/app"
                :serial t
                :components ((:file "package")
                             (:file "main")))))
