# Sources for printer

module_DATA = \
  modules/Printer.rb \
  modules/Printerlib.rb

client_DATA = \
  clients/printer_proposal.rb \
  clients/printer.rb \
  clients/printer_auto.rb

yncludedir = @yncludedir@/printer
ynclude_DATA = \
  include/printer/driveroptions.rb \
  include/printer/readwrite.rb \
  include/printer/connectionwizard.rb \
  include/printer/wizards.rb \
  include/printer/basicmodify.rb \
  include/printer/overview.rb \
  include/printer/driveradd.rb \
  include/printer/policies.rb \
  include/printer/dialogs.rb \
  include/printer/basicadd.rb \
  include/printer/printingvianetwork.rb \
  include/printer/autoconfig.rb \
  include/printer/helps.rb \
  include/printer/sharing.rb

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/printer.rnc

desktop_DATA = \
  desktop/org.openSUSE.YaST.Printer.desktop

symbolicdir = @icondir@/hicolor/symbolic/apps
symbolic_DATA = \
  icons/hicolor/symbolic/apps/yast-printer-symbolic.svg

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA = \
  icons/hicolor/scalable/apps/yast-printer.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(schemafiles_DATA) $(desktop_DATA) $(symbolic_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
