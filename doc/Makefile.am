#
# Makefile.am for y2c_prnt/doc
#

SUBDIRS = autodocs

CATALOG="./catalog.xml"
BUILD=html
STYLESHEET_FO=$(ydatadir)/docbook/stylesheets/customize-fo.xsl
STYLESHEET_HTML=$(ydatadir)/docbook/stylesheets/customize-html.xsl

htmldir = @docdir@

html_DATA = 			\
	internals.html		\
	spec_printconf.html	\
	read.html		\
	write.html		\
	errors.html		\
	lib.html

xml_files = $(wildcard *.xml)

EXTRA_DIST = $(html_DATA) $(xml_files) $(wildcard *.xsl) $(wildcard *.css)

CLEANFILES = *.dvi *.aux *.tex *.log *.bak *.out *.ent *.sum *.pdf *.ps \
  db2html.*

ps: printer.ps

pdf: printer.pdf

chunks:
	XML_CATALOG_FILES=$(CATALOG) \
	xsltproc -stringparam base.dir "$(BUILD)/" \
	--xinclude \
	$(STYLESHEET_HTML) \
	printer.xml

html: chunks

#html: printer.html

dvi: printer.dvi

printer.dvi: $(xml_files)
	db2dvi printer.xml

printer.ps: $(xml_files)
	db2ps printer.xml

printer.pdf: $(xml_files)
	db2pdf printer.xml

printer.html: $(xml_files)
	db2html printer.xml
	chmod -R og+rX printer

all: html

install-data-local:
	install -d -m 755 $(DESTDIR)/@docdir@/html
	cp -a $(BUILD)/* $(DESTDIR)/@docdir@/html
