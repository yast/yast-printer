#
# Makefile.am for y2a_printerdb/doc
#
# $Id$
#

SUBDIRS = autodocs

htmldir = $(docdir)
asciidir = $(docdir)

ascii_DATA = configs.ascii main.ascii manufacturers.ascii options.ascii printers.ascii

html_DATA = printerdb.html grammar.txt ag_printerdb-builtins.html
EXTRA_DIST = $(html_DATA) $(ascii_DATA)

builtin = $(srcdir)/../src/PrinterdbAgent.cc

ag_printerdb-builtins.html: $(builtin)
	@ybindir@/makebuiltindocs -t "SCR printerdb agent functions" -a $(builtin) > $@.new
	mv $@.new $@

CLEANFILES = ag_printerdb-builtins.html

