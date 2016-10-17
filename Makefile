#
# Makefile
# ajdiaz, 2016-02-07 09:19
#

SRCDIR=src
OUTBIN=./tl

all:
	@echo "#! /bin/bash -i" > $(OUTBIN)
	find $(SRCDIR) -type f -exec cat {} \; >> $(OUTBIN)
	@echo 'main "$$@"' >> $(OUTBIN)
	@chmod 755 $(OUTBIN)
	@ls -l $(OUTBIN)

clean:
	rm -f $(OUTBIN)
# vim:ft=make
