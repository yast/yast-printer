#
# Makefile.am for y2a_cups/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-cups\"

liby2ag_cups_la_LIBADD = -lcups -lz
libpy2ag_cups_la_LIBADD = -lcups -lz

plugin_LTLIBRARIES = libpy2ag_cups.la
noinst_LTLIBRARIES = liby2ag_cups.la

liby2ag_cups_la_SOURCES = 	\
	CupsAgent.cc		\
	CupsAgent.h		\
	PrintersConf.cc		\
	PrintersConf.h		\
	CupsCalls.cc		\
	CupsCalls.h		\
	ClassesConf.cc		\
	ClassesConf.h		\
	DefaultDest.cc		\
	DefaultDest.h		\
	Y2Logger.h

liby2ag_cups_la_LDFLAGS = -version-info 2:0

libpy2ag_cups_la_SOURCES =		\
	$(liby2ag_cups_la_SOURCES)	\
	Y2CCCupsAgent.h			\
	Y2CCCupsAgent.cc		\
	Y2CupsAgentComponent.h		\
	Y2CupsAgentComponent.cc
libpy2ag_cups_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)
