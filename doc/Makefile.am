#
# Makefile.am for y2c_prnt/doc
#

SUBDIRS = autodocs

CATALOG="./catalog.xml"
BUILD=html
STYLESHEET_FO=$(ydatadir)/docbook/stylesheets/customize-fo.xsl
STYLESHEET_HTML=$(ydatadir)/docbook/stylesheets/customize-html.xsl

xml_files = $(wildcard *.xml)

EXTRA_DIST = $(xml_files) $(wildcard *.xsl) $(wildcard *.css)

CLEANFILES = *.dvi *.aux *.tex *.log *.bak *.out *.ent *.sum *.pdf *.ps \
  db2html.*

ps: printer.ps

pdf: printer.pdf

html: chunks

chunks:
	XML_CATALOG_FILES=$(CATALOG) \
	xsltproc -stringparam base.dir "$(BUILD)/" \
	--xinclude \
	$(STYLESHEET_HTML) \
	printer.xml

dvi: printer.dvi

printer.dvi: $(xml_files)
	db2dvi printer.xml

printer.ps: $(xml_files)
	db2ps printer.xml

printer.pdf: $(xml_files)
	db2pdf printer.xml

all: html

install-data-local:
	install -d -m 755 $(DESTDIR)/@docdir@/html
	cp -a $(BUILD)/* $(DESTDIR)/@docdir@/html
