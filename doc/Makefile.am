#
# Makefile.am for y2c_prnt/doc
#

SUBDIRS = autodocs
htmldir = $(docdir)
xml_files =  $(wildcard *.xml) 

html_DATA = $(wildcard html/*.html) \
	    html/index.html \
	    html/yast2docs.css

pdf: printer.pdf

html/index.html: printer.xml
	XML_CATALOG_FILES=@XML_CATALOG@ \
	@XSLTPROC@ @XSLTPROC_FLAGS@ --xinclude \
	@STYLESHEET_HTML@ $<

printer.fo: printer.xml
	XML_CATALOG_FILES=@XML_CATALOG@ \
	@XSLTPROC@ @XSLTPROC_FLAGS@ --xinclude \
	-o $@ @STYLESHEET_PDF@  $<

printer.pdf: printer.fo
	fop -q $< $@


html/yast2docs.css: html/index.html
	cp @STYLESHEET_CSS@ html
	cp -a $(ydatadir)/docbook/images html


EXTRA_DIST = $(xml_files)

CLEANFILES =  $(html_DATA)

clean-local:
	rm -rf html

install-data-local:
	mkdir -p $(DESTDIR)$(htmldir)
	cp -a $(srcdir)/html/images $(DESTDIR)$(htmldir)

