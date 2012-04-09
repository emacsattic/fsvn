VERSION = 0.9.13

RELEASE_FILES = \
	fsvn-admin.el fsvn-blame.el fsvn-browse.el fsvn-cmd.el fsvn-config.el \
	fsvn-data.el fsvn-debug.el fsvn-deps.el fsvn-dev.el fsvn-diff.el \
	fsvn-dired.el fsvn-env.el fsvn-fs.el fsvn-logview.el fsvn-magic.el \
	fsvn-make.el fsvn-minibuf.el fsvn-mode.el fsvn-msgedit.el \
	fsvn-parasite.el fsvn-pkg.el fsvn-popup.el fsvn-proc.el \
	fsvn-proclist.el fsvn-propview.el fsvn-pub.el fsvn-select.el \
	fsvn-svk.el fsvn-test.el fsvn-tortoise.el fsvn-ui.el fsvn-url.el \
	fsvn-win.el fsvn-xml.el fsvn.el \
	mw32cmp.el mw32cmp-test.el Makefile \
	MAKE-CFG.el MAKE-TARGETS.mk BUG INSTALL README TODO ChangeLog

PACKAGE = fsvn

RELEASE_SAMPLES = \
	Samples/Makefile* Samples/MAKE-CFG.el*

RELEASE_IMAGES = \
	images/*.xpm

EXCLUDE_RELEASE = \
	Samples fsvn-make.el *-test.el Makefile MAKE-CFG.el MAKE-TARGETS.mk INSTALL

ARCHIVE_DIR_PREFIX = ..

GOMI	= *.elc *~

default: elc

check: clean
	$(EMACS) $(CHECKFLAGS) -f check-fsvn $(CONFIG)

elc:
	$(EMACS) $(FLAGS) -f compile-fsvn $(CONFIG)

what-where:
	$(EMACS) $(FLAGS) -f what-where-fsvn $(CONFIG)

install: elc
	$(EMACS) $(FLAGS) -f install-fsvn $(CONFIG)

uninstall:
	$(EMACS) $(FLAGS) -f uninstall-fsvn $(CONFIG)

clean:
	-$(RM) $(GOMI)

release: archive single-file package
	$(RM) -f $(ARCHIVE_DIR_PREFIX)/$(PACKAGE)-$(VERSION).tar.bz2 $(ARCHIVE_DIR_PREFIX)/$(PACKAGE)-$(VERSION).tar.gz
	$(RM) -f $(ARCHIVE_DIR_PREFIX)/fsvn.el
	$(RM) -f $(ARCHIVE_DIR_PREFIX)/fsvn.el.bz2
	$(RM) -f $(ARCHIVE_DIR_PREFIX)/fsvn.el.gz
	mv /tmp/$(PACKAGE)-$(VERSION).tar.bz2 /tmp/$(PACKAGE)-$(VERSION).tar.gz /tmp/$(PACKAGE)-$(VERSION).tar $(ARCHIVE_DIR_PREFIX)/
	mv fsvn.el.tmp $(ARCHIVE_DIR_PREFIX)/fsvn.el
	bzip2 --keep $(ARCHIVE_DIR_PREFIX)/fsvn.el
	gzip $(ARCHIVE_DIR_PREFIX)/fsvn.el

archive: prepare
	cd /tmp ; \
	tar cjf $(PACKAGE)-$(VERSION).tar.bz2 $(PACKAGE)-$(VERSION) ; \
	tar czf $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)

package: prepare
	cd /tmp/$(PACKAGE)-$(VERSION) ; \
	rm -rf $(EXCLUDE_RELEASE) ; \
	cd .. ; \
	tar cf $(PACKAGE)-$(VERSION).tar $(PACKAGE)-$(VERSION)

prepare:
	rm -rf /tmp/$(PACKAGE)-$(VERSION)
	mkdir /tmp/$(PACKAGE)-$(VERSION)
	cp -pr $(RELEASE_FILES) /tmp/$(PACKAGE)-$(VERSION)
	chmod 644 /tmp/$(PACKAGE)-$(VERSION)/*
	mkdir /tmp/$(PACKAGE)-$(VERSION)/Samples
	cp -p $(RELEASE_SAMPLES) /tmp/$(PACKAGE)-$(VERSION)/Samples
	mkdir /tmp/$(PACKAGE)-$(VERSION)/images
	cp -p $(RELEASE_IMAGES) /tmp/$(PACKAGE)-$(VERSION)/images
	chmod 744 /tmp/$(PACKAGE)-$(VERSION)/Samples

single-file:
	$(EMACS) $(FLAGS) -f make-fsvn $(CONFIG)

