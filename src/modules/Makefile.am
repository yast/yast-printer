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

lprng:
	test -d lprng || mkdir lprng && ln -sf ../../lprng lprng/printer

cups:
	test -d cups || mkdir cups && ln -sf ../../cups cups/printer

common:
	test -d common || mkdir common && ln -sf ../../common common/printer

ycpchook = lprng cups common



include $(top_srcdir)/Makefile.am.common
