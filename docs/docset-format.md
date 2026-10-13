# Docset format, version 1

A docset is the documentation of one language or library, in a form the
spec browser (and Cadre) can read without parsing HTML or Markdown. The Common
Lisp standard is one docset; gtk4 and raylib each ship one of their own.

A docset is a directory holding three files, all UTF-8 Lisp data read with
`*read-eval*` off. The data uses only keywords, strings, integers, lists, `nil`
and `t`. Readers read it in a package of its own that imports just `nil` and `t`
from Common Lisp, so a stray symbol never lands in a real package.

```
manifest.sexp   what the docset is, and its table of contents
index.sexp      one record per entry: names, kind, package, summary, and where it is
entries.sexp    the entries themselves, one per line, read one at a time
```

## Where docsets live

- The browser ships the Common Lisp docset.
- A library ships its docset in `docs/docset/` under its ASDF system's
  directory. The browser looks there for each library it knows about (gtk4,
  raylib) that ASDF can find, and in `~/.local/share/spec-browser/docsets/*/`.

## manifest.sexp

One plist:

```lisp
(:format 1
 :id "gtk4"                        ; unique among docsets
 :title "GTK 4"
 :subtitle "GTK 4 bindings for SBCL"
 :version "1.0.2"
 :system "gtk4"                    ; the ASDF system documented, if any
 :packages ("GTK" "GDK" ...)       ; packages whose symbols the entries document
 :source "https://..."             ; where the text comes from
 :attribution "..."                ; shown in the browser's About box
 :license "..."
 :entry-count 12345
 :toc (NODE ...))
```

A table-of-contents NODE is `(:title "Conses" :entry "id-or-nil" :children (NODE ...))`.
`:entry` and `:children` are optional.

## index.sexp

A list of records, one per entry, in the order of `entries.sexp`:

```lisp
("function/mapc"                   ; id, unique in the docset
 :names ("mapc" "mapcar" "mapcan" "mapl" "maplist" "mapcon")
 :kind :function
 :kind-name "Function"
 :package "COMMON-LISP"            ; or NIL for entries that are not symbols
 :parent "id"                      ; optional: the entry this one belongs to
 :summary "Applies function to successive sets of arguments..."
 :position 123456)                 ; file position of the entry in entries.sexp
```

Names are given as they would be typed, in lowercase. A browser finds the
entry for a symbol by its package name and symbol name.

## entries.sexp

Each entry is one form:

```lisp
(:entry "function/mapc"
 :names (...) :kind :function :kind-name "Function" :package "COMMON-LISP"
 :parent "id" :children ("id" ...)  ; both optional
 :upstream "https://..."            ; optional: the original documentation
 :sections (("Syntax" BLOCK ...)
            ("Description" BLOCK ...)
            ...))
```

Section labels are strings, shown as headings, in the order given. The Common
Lisp docset uses the standard's labels (Syntax, Arguments and Values,
Description, Examples, Affected By, Exceptional Situations, See Also, Notes,
...). Libraries use what suits them (Parameters, Returns, Properties, ...).

### Blocks

```lisp
(:p INLINE ...)                                     ; a paragraph
(:heading LEVEL INLINE ...)                         ; LEVEL 1-4, in pages
(:code-block LANGUAGE INLINE ...)                   ; LANGUAGE "lisp", "c" or NIL; text keeps its line breaks
(:syntax :kind KIND :name (INLINE ...) :args (INLINE ...) [:values (INLINE ...)] [:setf t])
(:list ITEM ...)                                    ; ITEM is (:item [(:label INLINE ...)] BLOCK ...)
(:table :caption (INLINE ...) :header (CELL ...) :rows ((CELL ...) ...))   ; CELL is (INLINE ...)
(:quote BLOCK ...)
```

`:syntax` is a definition line such as `mapcar function &rest lists+ ⇒ result-list`.
With `:setf t` it is the `(setf (name args) new-value)` form; its `:values`
holds the new value.

### Inlines

```lisp
"text"
(:code INLINE ...)              ; inline code
(:i INLINE ...) (:b INLINE ...)
(:param INLINE ...)             ; a parameter name
(:ref "id" INLINE ...)          ; link to an entry in the same docset
(:term "id" INLINE ...)         ; a glossary term; id is NIL when it has no entry
(:link "url" INLINE ...)        ; external link
(:secref "key" INLINE ...)      ; a section of the document, by its key
(:sup INLINE ...) (:sub INLINE ...)
(:sense "1" ...)                ; a glossary sense number, shown as a subscript
(:math INLINE ...)
(:input INLINE ...)             ; what the user types, in examples
(:note INLINE ...)              ; an editor's or reviewer's note
```

In code blocks, examples use `⇒` before a value, `▷` before printed output,
`≡` for equivalence, and `OR⇒` / `NOT⇒` for alternatives.

Readers ignore block and inline types they do not know, showing their
string contents, so later versions can add types.
