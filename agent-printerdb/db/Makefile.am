#
# Makefile.am
#

dbdir = $(YAST2DIR)/lib/printerdb

SOURCES = main.ascii manufacturers.ascii printers.ascii configs.ascii options.ascii

PPDS = *.ppd

db_DATA = suse.prdb *.ppd

suse.prdb: $(SOURCES)
	cat $(SOURCES) > suse.prdb

CLEANFILES = suse.prdb

EXTRA_DIST = $(SOURCES) $(PPDS)

noinst_DATA = database.yh agent.yh

database.yh : suse.prdb ../src/yhgen
	../src/yhgen

agent.yh : suse.prdb ../src/yhgen
	../src/yhgen

