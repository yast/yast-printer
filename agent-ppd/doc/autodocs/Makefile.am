#
# Makefile.am for printer/agent-ppd/doc/autodocs
#

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.h
	cd $(srcdir)/../../src && @ybindir@/ydoc agent-ppd *.h
	mv -f $(srcdir)/../../src/*.html .
