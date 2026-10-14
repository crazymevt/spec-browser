# Spec browser — app design

A GTK 4 app for reading the Common Lisp standard, and the gtk4 and raylib
documentation when those libraries are installed, with entries laid out
properly: syntax lines, highlighted examples, links that work, and search.
Later, its entry view moves into Cadre.

This is a learning project, built tutorial style: each step below is written
by hand, with Claude explaining, pointing at the right API, and reviewing.
The data side is already done; see "What exists" below.

## What exists

- **Docsets** (see [docs/docset-format.md](docs/docset-format.md)): three files of
  plain Lisp data per docset. The Common Lisp one is in `data/common-lisp/`
  (1,389 entries); gtk4 and raylib build theirs into `docs/docset/` with
  `make docset` (15,137 and 862 entries).
- **The reader**, system `spec-browser/docset`, package `spec-docset`, no dependencies:
  - `(find-docsets :directories (list data-dir))` opens every docset it can find.
  - `docset-title`, `docset-id`, `docset-toc`, `docset-index`.
  - `(search-names docset "hash")` returns index records, best first.
  - `(lookup-symbol docsets "mapcar" "COMMON-LISP")` returns `(docset . record)` pairs.
  - `(docset-entry docset id)` reads an entry (cached after the first time).
  - `record-id`, `record-names`, `record-kind-name`, `record-summary`, `record-parent`.
  - `entry-sections` gives `(("Syntax" block...) ("Description" block...) ...)`.

Try it at the REPL before writing any UI:

```lisp
(ql:quickload :spec-browser/docset)
(defvar *docsets* (spec-docset:find-docsets :directories (list #p"~/projects/lisp/spec-browser/data/")))
(spec-docset:search-names (first *docsets*) "hash")
(spec-docset:docset-entry (first *docsets*) "function/mapc")
```

## Two layers: the view and the app

The code is split by what moves into Cadre later:

- **The view** (`src/view/`, package `spec-browser.view`): draws an entry into a
  text buffer, and keeps a page's history. It knows nothing about windows,
  colors, fonts, highlighting or where docsets live; whoever uses it (the
  app, or Cadre) supplies those. It depends only on `gtk4` and `spec-docset`.
- **The app** (`src/app/`, package `spec-browser.app`): the window, header bar,
  sidebar, search list, contents tree, and its own styles and highlighter.

The rule that keeps the split honest: nothing in `src/view/` may refer to
`spec-browser.app`, a global holding app state, a color, or a font name.

## The window (app)

```
┌────────────────────────────────────────────────────────────────────────┐
│ ◀ ▶   [Common Lisp ▾]          Spec Browser           [ search…      ] │  header bar
├──────────────────────┬─────────────────────────────────────────────────┤
│ Search │ Contents    │  mapcar                              Function   │
│──────────────────────│                                                 │
│ mapcar     Function  │  Syntax                                         │
│ mapcan     Function  │   mapcar function &rest lists+ ⇒ result-list    │
│ mapc       Function  │                                                 │
│ map        Function  │  Description                                    │
│ map-into   Function  │   The mapping operation involves applying       │
│ maphash    Function  │   function to successive sets of arguments…     │
│ …                    │                                                 │
│                      │  Examples                                       │
│                      │  ┌───────────────────────────────────────────┐  │
│                      │  │ (mapcar #'car '((1 a) (2 b))) ⇒ (1 2)     │  │
│                      │  └───────────────────────────────────────────┘  │
└──────────────────────┴─────────────────────────────────────────────────┘
```

- **Header bar**: back and forward buttons, a drop-down choosing the docset,
  and a search entry.
- **Sidebar** (left side of a `gtk:paned`): a stack with two pages, Search
  (a list view of results) and Contents (a tree of the docset's table of
  contents).
- **Entry view** (right side): a read-only, word-wrapped `gtk:text-view` in a
  scrolled window, drawn by the view layer.

## The view layer

### Why a text view for entries

An entry is mostly running text with styled spans (code, parameters, links),
which is what a text buffer with tags does well. It also gives selection,
copying and one scroll position for free. Cadre's Markdown preview
(`src/ui/markdown.lisp` in Cadre) works the same way, which makes the move
easier. Tables and a code block's copy button can go in as child widgets at
child anchors (`gtk:text-buffer-create-child-anchor`,
`gtk:text-view-add-child-at-anchor`).

### Styles: semantic names, styled by the host

The view never makes a color or names a font. It tags text with **style
keywords** and asks a **style table** (a function or hash table the host
gives it) for the tag to use:

| Data | Style |
| --- | --- |
| entry name, at the top | `:title`, kind beside it in `:kind` |
| section label | `:heading` |
| `(:heading level ...)` in pages | `:heading-1` … `:heading-4` |
| `(:p ...)` | `:body` (everything gets `:body` underneath) |
| `(:code-block lang ...)` | `:code-block`, plus whatever the highlighter returns |
| `(:syntax ...)` | `:syntax`, the name in `:syntax-name` |
| `(:code ...)` | `:code` |
| `(:param ...)` | `:param` |
| `(:quote ...)` | `:quote` |
| `(:i ...)`, `(:b ...)` | `:italic`, `:bold` |
| `(:ref ...)`, `(:term ...)`, `(:link ...)` | `:link` |
| `(:note ...)` | `:note` |
| list markers | `:marker`, and an indent style per level |
| tables | `:table`, `:table-header` |
| anything unknown | its strings, with no style |

Making tags and coloring them are separate functions on the host's side, so a
theme or dark-mode change recolors the tags without drawing the entry again.
The app's table makes its own tags (`(make-instance 'gtk:text-tag :name ...)`
added with `gtk:text-tag-table-add`; `gtk_text_buffer_create_tag` is variadic
in C and isn't bound). In Cadre the same keywords map to theme faces and the
editor's font.

### Highlighting: a function the host passes in

Code blocks call a highlighter: `(funcall highlighter language text)` returns
spans `(start end style)` within TEXT, using style keywords (`:comment`,
`:string`, `:keyword`, `:symbol`, `:result`, `:output`...). The app passes its own
small tokenizer (step 11); before that, a highlighter that returns no spans.
Cadre passes one built on its Lisp lexer.

### Links: recorded by the view, followed by the host

While inserting a link, the view records `(start-offset end-offset target)`,
the same shape Cadre's preview uses. TARGET is `(:entry docset-id entry-id)`,
`(:term docset-id entry-id)` or `(:url "https://...")`. A click finds the
offset under the pointer (`gtk:text-view-window-to-buffer-coords`, then
`gtk:text-view-get-iter-at-location`), looks it up, and calls the host's
**navigate callback** with the target. The app shows the entry in its window;
Cadre opens or reuses a docs tab. A motion controller switches the pointer to a
hand over links (`gtk:widget-set-cursor-from-name` with `"pointer"`).

### The page: no globals

A **page** object holds what one entry view needs:

- the docsets it can show, and how to style, highlight and navigate (the
  style table, highlighter and navigate callback)
- the current docset and entry, and the current link ranges
- history: a back stack and a forward stack of `(docset-id . entry-id)`

`show-entry`, `go-back` and `go-forward` take a page. The app makes one page for
its window (and may keep it in a global for the REPL); Cadre would make one
per docs tab. History is pure Lisp (`visit`, `go-back`, `go-forward`,
`can-go-back-p`) and gets Parachute tests before any button uses it.

### Interface the view exports

```lisp
(make-page &key docsets text-view style highlighter navigate)
(show-entry page docset-id entry-id)      ; draw it, record the visit
(go-back page) (go-forward page) (can-go-back-p page) (can-go-forward-p page)
(page-docset page) (page-entry-id page)
(render-entry text-view entry &key docset style highlighter)  ; returns link ranges
(link-at-point page x y)                  ; for the host's own gestures, if wanted
```

## Files

```
src/view/
  package.lisp    the spec-browser.view package and its exports
  history.lisp    back/forward stacks (no GTK)
  render.lisp     entry -> text buffer: blocks, inlines, styles, link ranges
  page.lisp       the page object, show-entry, links and clicks
src/app/
  package.lisp    the spec-browser.app package
  styles.lisp     the app's style table: tags, colors, fonts, dark mode
  highlight.lisp  the app's Lisp highlighter for code blocks
  search.lisp     the search list
  contents.lisp   the contents tree
  window.lisp     the window, header bar, sidebar, wiring
  main.lisp       the application, startup, finding docsets
tests/
  view.lisp       history, the plain-text walk of an entry
  app.lisp        the highlighter
```

New systems in `spec-browser.asd`: `spec-browser/view` depending on `"gtk4"` and
`"spec-browser/docset"`; `spec-browser/app` depending on `"spec-browser/view"`;
`spec-browser/tests` with Parachute. Add a `make run` target. On macOS GTK must
run on the first thread, so in Cadre use Run GTK App.

## Steps

Each step ends with something to run or test. Commit after each.

1. **Project and an empty window.** Add the systems and packages (the view's
   can start nearly empty), a `main` that makes a `gtk:application` and
   presents a window titled "Spec Browser", and `make run`. Pointers:
   `examples/hello-world.lisp`, manual chapter 2.

2. **Load the docsets.** The app finds them at startup (its `data/` directory,
   found through `asdf:system-source-directory`, plus gtk4 and raylib through
   `find-docsets`' defaults) and prints what was found. Done when the REPL shows
   three docsets.

3. **Show one entry as plain text.** A scrolled text view in the window. A
   first `render-entry` in the view layer that inserts every string it finds
   in the blocks, with blank lines between blocks. Hard-code `function/mapc` to
   start. Pointers: `demos/demos/text-view.lisp`, `examples/editor.lisp`.

4. **Styles.** The view dispatches on block and inline types (`ecase` on the
   keyword, with an unknown-type fallback) and applies style keywords through
   the style table. The app's `styles.lisp` makes the tags: titles, headings,
   code, parameters, syntax lines, code blocks. Done when `mapc` reads like the
   mock-up above, and swapping in a different style table changes the look
   without touching `src/view/`.

5. **History and the page, with tests.** Write the history functions and their
   Parachute tests first, then the page object and `show-entry`.

6. **Links.** Record link ranges while rendering; a click on the text view
   calls the page's navigate callback; a motion controller switches the
   cursor. Back and forward buttons in a header bar. Pointers:
   `demos/demos/paint.lisp` (gestures), `demos/demos/key-events.lisp`, manual
   chapter 6.

7. **Search.** A search entry in the header bar and a list view of results in
   the sidebar: name and kind on each row, activating a row shows the entry.
   Use `search-names` across the current docset. Pointers:
   `demos/demos/list-filter.lisp`, `demos/demos/lisp-model.lisp`, manual
   chapter 10 (list models).

8. **Several docsets.** A drop-down in the header bar to pick the docset that
   search and contents use. Links stay within the docset they came from. If
   gtk4 or raylib is installed but its docset isn't built, say so in the
   sidebar, with the `make docset` command.

9. **Lists and tables.** Bullets and indentation for lists; tables as a
   `gtk:grid` of labels at a child anchor (or as aligned text, the way Cadre's
   preview does it). The raylib parameter tables and enum value tables are
   good test cases.

10. **Contents tree.** The Contents page: a `gtk:tree-list-model` over the
    docset's table of contents, with `gtk:tree-expander` rows, in a stack with
    the search page. Pointers: `demos/demos/stack-sidebar.lisp`; there's no
    tree demo, so look up `gtk:tree-list-model-new` and
    `gtk:tree-expander-new` in the gtk4 docset (your own app, by now).

11. **Highlighting.** The app's tokenizer for code blocks: comments, strings,
    keywords, `#'` and quotes, and the `⇒` / `▷` markers, returning
    `(start end style)` spans. Test it with Parachute on plain strings, then
    pass it to the page.

12. **Polish.** A copy button on code blocks, font size (Ctrl+= / Ctrl+-),
    dark mode (recolor the tags, don't redraw), remembering the window size and
    the last entry.

## Moving into Cadre

When the app works, the move is a copy plus a few small adapters:

| Piece | In Cadre |
| --- | --- |
| `src/docset/` (`spec-docset`) | copied into Cadre's core; it has no dependencies, which core requires |
| `data/common-lisp/` | shipped with Cadre's resources; the gtk4 and raylib docsets still come from those libraries |
| `src/view/` | copied into Cadre's UI |
| style table | maps the style keywords to Cadre's theme faces and editor font, recolored on theme change |
| highlighter | built on Cadre's Lisp lexer (the one its Markdown preview uses) |
| navigate callback | opens or reuses a docs tab (a read-only buffer, like the preview) |
| search | Cadre's picker over `search-names` results, instead of the app's sidebar |
| finding docsets | opened on the first lookup, not at startup (the gtk4 index is 3.6 MB) |

New in Cadre: a "Look up in spec" command on the symbol at point, using
`lookup-symbol` with the buffer's package, and the summary line
(`record-summary`) in its hover hints. Not moved: the app's window, header
bar, sidebar, contents tree and style table.

## Notes

- Entries are read from disk when first shown (`docset-entry` caches them), and
  opening all three docsets takes about 25 ms, so no threads are needed.
- `entries.sexp` and `index.sexp` must not be edited by hand; regenerate them
  (`make export` here, `make docset` in gtk4 and raylib) and check them with
  `make check-docsets`.
- The HyperSpec in `sources/` is only for `make compare` and is never committed
  or shipped.
