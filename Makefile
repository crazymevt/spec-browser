# Makefile for spec-browser. Needs Quicklisp, loaded from your Lisp's init file.

LISP ?= sbcl
RUN = $(LISP) --non-interactive --eval '(require :asdf)' --eval '(push (truename ".") asdf:*central-registry*)'

.PHONY: sources export check-docsets compare clean run

DPANS = https://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/lisp/doc/standard/ansi/dpans
HYPERSPEC = https://ftp.lispworks.com/pub/software_tools/reference/HyperSpec-7-0.tar.gz

# Fetch the dpANS3 sources, and the HyperSpec for comparing against (never redistributed)
sources:
	mkdir -p sources/dpans3 sources/dpans3r
	cd sources && curl -sSLO $(DPANS)/dpans3.tgz && curl -sSLO $(DPANS)/dpans3r.tgz && curl -sSLO $(HYPERSPEC)
	cd sources && tar xzf dpans3.tgz -C dpans3 && tar xzf dpans3r.tgz -C dpans3r && tar xzf HyperSpec-7-0.tar.gz

# Write the Common Lisp docset to data/common-lisp/ from the dpANS3 sources
export:
	$(RUN) --eval '(ql:quickload :spec-browser/export)' --eval '(spec-export:export-common-lisp)'

# Check every docset the browser can find: its own, and gtk4's and raylib's when installed
check-docsets:
	$(RUN) --eval '(ql:quickload :docset)' \
		--eval '(let ((n 0)) (dolist (d (docset:find-docsets :directories (list (truename "data/")))) (incf n (docset:check-docset (docset:docset-directory d)))) (uiop:quit (if (zerop n) 0 1)))'

# Compare the imported entries with the HyperSpec and the Community Spec; writes build/compare/
compare:
	$(LISP) --dynamic-space-size 4096 --non-interactive --eval '(require :asdf)' --eval '(push (truename ".") asdf:*central-registry*)' \
		--eval '(ql:quickload :spec-browser/compare)' --eval '(spec-compare:run)'

clean:
	rm -rf build
	find . -name '*.fasl' -delete

run:
	$(RUN) --eval '(ql:quickload :spec-browser/app)' --eval '(spec-browser.app:main)'
