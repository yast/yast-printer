#
# Makefile.am for y2c_prnt/src
#

YCPCFLAGS = -I common -I cups -I lprng

module_DATA =			\
	Printer.ycp		\
	Printerlib.ycp		\
	CUPS.ycp		\
	LPRng.ycp		\
	Spooler.ycp		\
	Printerdb.ycp		\
	PrinterTest.ycp

EXTRA_DIST =				\
	$(module_DATA)

symlinks:
	test -d lprng || mkdir lprng && ln -sf ../../lprng lprng/printer
	test -d cups || mkdir cups && ln -sf ../../cups cups/printer
	test -d common || mkdir common && ln -sf ../../common common/printer

ycpchook = symlinks



include $(top_srcdir)/Makefile.am.common
