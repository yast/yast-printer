#
# Makefile.am for y2c_prnt/src
#

YCPCFLAGS = -I common -I cups -I lprng

module_DATA =			\
	CUPS.ycp		\
	Spooler.ycp		\
	Printerlib.ycp		\
	Printerdb.ycp		\
	Printer.ycp		\
	PrinterTest.ycp

EXTRA_DIST =				\
	$(module_DATA)

cups:
	test -d cups || mkdir cups && ln -sf ../../cups cups/printer

common:
	test -d common || mkdir common && ln -sf ../../common common/printer

ycpchook = cups common



include $(top_srcdir)/Makefile.am.common
