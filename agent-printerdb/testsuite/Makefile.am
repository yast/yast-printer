#
# Makefile.am for yast2 agent testsuite
#

SUBDIRS = config lib ag_printerdb.test tests

AM_CXXFLAGS = -DY2LOG=\"agent-printerdb\"

PACKAGE = ag_printerdb
AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

noinst_PROGRAMS = runag_printerdb
runag_printerdb_SOURCES = runag_printerdb.cc

runag_printerdb_LDADD = -lscr -ly2 -lycp
runag_printerdb_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	$(plugindir)/libpy2stdio.la	\
	$(plugindir)/libpy2script.la	\
	../src/libpy2ag_printerdb.la	\
	-Xlinker --no-whole-archive
