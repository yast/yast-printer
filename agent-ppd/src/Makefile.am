#
# Makefile.am for source/printer/agent-ppd/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-ppd\"

AM_LDFLAGS = -L$(libdir)

liby2ag_ppd_la_LIBADD = -lcups -lz @AGENT_LIBADD@
libpy2ag_ppd_la_LIBADD = -lcups -lz @AGENT_LIBADD@

plugin_LTLIBRARIES = libpy2ag_ppd.la
noinst_LTLIBRARIES = liby2ag_ppd.la

liby2ag_ppd_la_SOURCES = 	\
	PPDAgent.cc		\
	PPDAgent.h		\
	Y2Logger.h		\
	PPDdb.cc		\
	PPDdb.h			\
	PPDVendors.h		\
	PPDfile.cc		\
	PPDfile.h		\
	md5.c

liby2ag_ppd_la_LDFLAGS = -version-info 2:0

libpy2ag_ppd_la_SOURCES =		\
	$(liby2ag_ppd_la_SOURCES)	\
	Y2CCPPDAgent.cc
libpy2ag_ppd_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)
