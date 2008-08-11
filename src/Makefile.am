# Makefile.am for printer/src

yncludedir = @yncludedir@/printer

client_DATA =			\
	printer.ycp		\
	printer_auto.ycp	\
	printer_proposal.ycp

ynclude_DATA =			\
	helps.ycp		\
	wizards.ycp		\
	readwrite.ycp		\
	overview.ycp		\
	basicadd.ycp		\
	basicmodify.ycp		\
	connectionwizard.ycp	\
	printingvianetwork.ycp	\
	sharing.ycp		\
	dialogs.ycp

desktop_DATA =			\
	printer.desktop

module_DATA =			\
	Printerlib.ycp		\
	Printer.ycp
#	Printer2.pm

# create a symlink for local build, #145327
printer:
	ln -sf . $@
ycpchook = printer

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
