#
# Makefile.am for y2a_cups/testsuite
#

SUBDIRS = config lib ag_cups.test ag_cups.ppd ag_cups.cups tests ppdfiles cups conf

AM_CXXFLAGS = -DY2LOG=\"agent-cups\"

PACKAGE = ag_cups
AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

EXTRA_DIST = run_cups stop_cups

noinst_PROGRAMS = runcups runppd
runcups_SOURCES = runcups.cc
runppd_SOURCES = runppd.cc

runcups_LDADD = -lscr -ly2 -lycp -lcups
runcups_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	../src/libpy2ag_cups.la	\
	-Xlinker --no-whole-archive

runppd_DEPENDENCIES = ../src/PPD.o
runppd_LDADD = -lscr -ly2 -lycp -lz
runppd_LDFLAGS = -L$(libdir)		\
	../src/PPD.o			
