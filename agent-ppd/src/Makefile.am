#
# Makefile.am for source/printer/agent-ppd/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-ppd\"

liby2ag_ppd_la_LIBADD = -lcups -lz
libpy2ag_ppd_la_LIBADD = -lcups -lz

plugin_LTLIBRARIES = libpy2ag_ppd.la
lib_LTLIBRARIES = liby2ag_ppd.la

liby2ag_ppd_la_SOURCES = 	\
	PPDAgent.cc		\
	PPDAgent.h		\
	Y2Logger.h		\
	PPDdb.cc		\
	PPDdb.h			\
	PPDVendors.h		\
	PPDfile.cc		\
	PPDfile.h		

liby2ag_ppd_la_LDFLAGS = -version-info 2:0

libpy2ag_ppd_la_SOURCES =		\
	$(liby2ag_ppd_la_SOURCES)	\
	Y2CCPPDAgent.h			\
	Y2CCPPDAgent.cc		\
	Y2PPDAgentComponent.h		\
	Y2PPDAgentComponent.cc
libpy2ag_ppd_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)
