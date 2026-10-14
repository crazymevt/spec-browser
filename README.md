# spec-browser

A browser for the Common Lisp standard and for library documentation, starting
with its data: the standard converted from the dpANS3 TeX sources into a
docset, a small format any Lisp program can read (see
[the docset library](https://github.com/crazymevt/docset/blob/main/docs/format.md), which reads and writes it). The app itself is planned in
[DESIGN.md](DESIGN.md).

## Setup

You need SBCL with [Quicklisp](https://www.quicklisp.org), GTK 4.14 or newer
(`brew install sbcl gtk4` on macOS), and two libraries that aren't in
Quicklisp's dist:

- the [gtk4 bindings](https://github.com/crazymevt/gtk4), for the window;
- the [docset library](https://github.com/crazymevt/docset), which reads and
  writes docsets.

Check them out and link them where Quicklisp finds local projects:

```sh
cd ~/projects/lisp
git clone https://github.com/crazymevt/gtk4.git
git clone https://github.com/crazymevt/docset.git
ln -s ~/projects/lisp/gtk4 ~/quicklisp/local-projects/gtk4
ln -s ~/projects/lisp/docset ~/quicklisp/local-projects/docset
```

If Quicklisp doesn't see a new link, run `(ql:register-local-projects)` once.
Quicklisp fetches the rest (cl-ppcre) on the first run. Then `make run`
opens the browser.

Rebuilding the Common Lisp docset (`make sources`, then `make export`) also
needs `curl` and `tar`. Only the docset library is needed for that, not gtk4.

## Layout

| Path | Contents |
| --- | --- |
| `src/import/` | Reads the dpANS3 TeX sources into entries. |
| `src/export/` | Writes the Common Lisp docset from them. |
| `src/compare/` | Compares the imported entries with the HyperSpec and the Community Spec. |
| `data/common-lisp/` | The Common Lisp docset, built from dpANS3. |

## Docsets

The browser reads its own Common Lisp docset, and the docsets [gtk4](https://github.com/crazymevt/gtk4) and
[raylib](https://github.com/crazymevt/raylib) build in their `docs/docset/` when ASDF can find those libraries (`make docset`
in each). These aren't committed; they're regenerated.

It also reads every docset in `~/.local/share/docsets/`. The
[docsets](https://github.com/crazymevt/docsets) project writes them for other
libraries, such as bordeaux-threads.

## Make targets

- `make sources` fetches dpANS3, and the HyperSpec for comparing against, into `sources/` (not committed; the HyperSpec is never redistributed).
- `make export` rebuilds `data/common-lisp/` from `sources/`.
- `make check-docsets` checks every docset the browser can find.
- `make compare` compares the entries with the HyperSpec and the Community Spec, writing `build/compare/`. It needs the Community Spec's pages in `sources/clcs/`.
