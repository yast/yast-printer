#
# Makefile.am for y2a_printerdb/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-printerdb\"

liby2ag_printerdb_la_LIBADD = -lz
libpy2ag_printerdb_la_LIBADD = -lz

plugin_LTLIBRARIES = libpy2ag_printerdb.la
lib_LTLIBRARIES = liby2ag_printerdb.la
ybin_PROGRAMS = yhgen

liby2ag_printerdb_la_SOURCES =                    \
	PrinterdbAgent.cc		\
	PrinterdbAgent.h
liby2ag_printerdb_la_LDFLAGS = -version-info 2:0

libpy2ag_printerdb_la_SOURCES =                           \
        $(liby2ag_printerdb_la_SOURCES)                   \
        Y2CCPrinterdbAgent.cc         Y2CCPrinterdbAgent.h  \
        Y2PrinterdbAgentComponent.cc  Y2PrinterdbAgentComponent.h \
	structs.cc structs.h	\
	parser.yy	\
	scanner.ll scanner.h	\
	suseprinterdb.cc suseprinterdb.h	\
	ycp.cc

libpy2ag_printerdb_la_LDFLAGS = -version-info 2:0

INCLUDES = -I$(includedir)

$(srcdir)/scanner.cc: scanner.ll parser.hh parser.cc structs.h
	flex -o$@ $<

$(srcdir)/parser.hh $(srcdir)/parser.cc: parser.yy structs.h
	bison -d -oparser.cc $<


BUILT_SOURCES = parser.cc scanner.cc parser.hh

client_DATA = printerdb.ycp

agent.ycp : yhgenlocal
	./yhgenlocal
	rm -f database.ycp


EXTRA_DIST = parser.yy scanner.ll $(client_DATA) $(ybin_PROGRAMS)

noinst_PROGRAMS = yhgenlocal
noinst_DATA = agent.ycp

yhgen_SOURCES = yhgen.cc		

yhgen_LDADD = -lscr -ly2 -lycp 
yhgen_LDFLAGS = -L$(libdir)   \
	-Xlinker --whole-archive        \
	$(plugindir)/libpy2stdio.la     \
	$(plugindir)/libpy2script.la    \
	libpy2ag_printerdb.la    \
	-Xlinker --no-whole-archive

yhgenlocal_SOURCES = yhgen.cc

yhgenlocal_LDADD = -lscr -ly2 -lycp
yhgenlocal_LDFLAGS = -L$(libdir)   \
	-Xlinker --whole-archive        \
	$(plugindir)/libpy2stdio.la     \
	$(plugindir)/libpy2script.la    \
	libpy2ag_printerdb.la    \
	-Xlinker --no-whole-archive

