;;;; spec-browser.asd

(defsystem "spec-browser"
  :description "A browser for the Common Lisp standard and library docs. For now, its docset reader."
  :author "Jessie Hughart"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("spec-browser/docset"))

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
