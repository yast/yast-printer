#
# Makefile.am for yast2 agent testsuite
#

AUTOMAKE_OPTIONS = dejagnu

INCLUDES = -I$(includedir)

noinst_PROGRAMS = dbbuild
dbbuild_SOURCES = dbbuild.cc

dbbuild_LDADD = -lscr -ly2 -lycp
dbbuild_LDFLAGS = -L$(libdir)	\
	-Xlinker --whole-archive	\
	$(plugindir)/libpy2stdio.la	\
	../src/libpy2ag_ppd.la	\
	-Xlinker --no-whole-archive

vardatadir = /var/lib/YaST2

vardata_DATA = \
        ppd_db.ycp

ppd_db.ycp: dbbuild
	./dbbuild
	echo "#this database was generated during package building" >> ppd_db.ycp

EXTRA_DIST =

