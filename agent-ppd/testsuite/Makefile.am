#
# Makefile.am for yast2 agent testsuite
#

SUBDIRS = config lib ag_ppd.test tests

AM_CXXFLAGS = -DY2LOG=\"agent-ppd\"

PACKAGE = ag_ppd
AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

noinst_PROGRAMS = runag_ppd
runag_ppd_SOURCES = runag_ppd.cc

runag_ppd_LDADD = -lscr -ly2 -lycp
runag_ppd_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	$(plugindir)/libpy2stdio.la	\
	../src/libpy2ag_ppd.la	\
	-Xlinker --no-whole-archive
