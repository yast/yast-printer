#
# Makefile.am for y2c_prnt/doc
#

SUBDIRS = autodocs

htmldir = @docdir@

html_DATA = 			\
	index.html		\
	internals.html		\
	des_common.html		\
	spec_printconf.html	\
	todo.html		\
	des_local.html		\
	read.html		\
	spec_filter.html	\
	tools.html		\
	write.html		\
	errors.html

EXTRA_DIST = $(html_DATA)

SOURCES = $(wildcard *.xml)

ps: printer.ps

pdf: printer.pdf

html: printer.html

dvi: printer.dvi

printer.dvi: $(SOURCES)
	db2dvi printer.xml

printer.ps: $(SOURCES)
	db2ps printer.xml

printer.pdf: $(SOURCES)
	db2pdf printer.xml

printer.html: $(SOURCES)
	db2html printer.xml
	chmod -R og+rX printer


