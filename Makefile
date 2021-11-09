
PREFIX		= /usr
MODULEDIR	= $(PREFIX)/share/microconf
BINDIR		= $(PREFIX)/bin

all: ;

install:
	install -d $(DESTDIR)$(MODULEDIR)
	cp -va parts modules $(DESTDIR)$(MODULEDIR)
	install -d $(DESTDIR)$(BINDIR)
	cp microconf-prep $(DESTDIR)$(BINDIR)/microconf
