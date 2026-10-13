# spec-browser

A browser for the Common Lisp standard and for library documentation, starting
with its data: the standard converted from the dpANS3 TeX sources into a
docset, a small format any Lisp program can read (see
[docs/docset-format.md](docs/docset-format.md)). The app itself is planned in
[DESIGN.md](DESIGN.md).

## Layout

| Path | Contents |
| --- | --- |
| `src/docset/` | Reads, writes and checks docsets. No dependencies, so the app and Cadre can share it. |
| `src/import/` | Reads the dpANS3 TeX sources into entries. |
| `src/export/` | Writes the Common Lisp docset from them. |
| `src/compare/` | Compares the imported entries with the HyperSpec and the Community Spec. |
| `data/common-lisp/` | The Common Lisp docset, built from dpANS3. |

## Docsets

The browser reads its own Common Lisp docset, and the docsets gtk4 and raylib
build in their `docs/docset/` when ASDF can find those libraries (`make docset`
in each). These aren't committed; they're regenerated.

## Make targets

- `make sources` fetches dpANS3, and the HyperSpec for comparing against, into `sources/` (not committed; the HyperSpec is never redistributed).
- `make export` rebuilds `data/common-lisp/` from `sources/`.
- `make check-docsets` checks every docset the browser can find.
- `make compare` compares the entries with the HyperSpec and the Community Spec, writing `build/compare/`. It needs the Community Spec's pages in `sources/clcs/`.
