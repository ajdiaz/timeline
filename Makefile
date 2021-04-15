#
# Makefile
# ajdiaz, 2016-02-07 09:19
#

SRCDIR=src
DOCDIR=man
OUTBIN=./tl

DOCSRC=$(wildcard $(DOCDIR)/*.md)
DOCOBJ=$(DOCSRC:%.md=%)

all: tl doc

tl: $(SRCDIR)/*
	@echo "#! /bin/bash -i" > $(OUTBIN)
	@echo "TIMELINE_VERSION='$(shell git describe --tags)'" >> $(OUTBIN)
	find $(SRCDIR) -type f -exec cat {} \; >> $(OUTBIN)
	@echo 'main "$$@"' >> $(OUTBIN)
	@chmod 755 $(OUTBIN)
	@ls -l $(OUTBIN)

doc: $(DOCOBJ)

$(DOCOBJ): $(DOCSRC)
	VERSION='$(shell git describe --tags)'; name="$@.md"; f="$@.md"; \
	name="$${name##*/}"; name="$${name%.md}"; mansect="$${name##*.}" name="$${name%.*}"; \
	pandoc -s -t man -o "$@" -M "title:$${name^^}($$mansect) Timeline v${VERSION} | Timeline Manual" -M "date:$$(date +'%Y-%m-%d')" "$$f"

clean:
	rm -f $(OUTBIN)
	rm -f $(DOCDIR)/*.{1..9}
# vim:ft=make
