/*
   File:       yhgen.cc
   Generator of yh files from printer database and printerdb agent

   Author:     Jiri Srain <jsrain@suse.cz>
   Maintainer: Jiri Srain <jsrain@suse.cz>

*/

#include "../src/PrinterdbAgent.h"
#include "suseprinterdb.h"

int
main (int argc, char *argv[])
{
    PrinterdbAgent a = PrinterdbAgent ();
    a.otherCommand (YCPTerm (YCPSymbol ("PrinterdbAgent", false), string ("suse.prdb")));
    spdbStart ("suse.prdb");
    a.Write (YCPPath (".gettext.db"), YCPString ("database.ycp"));
    a.Write (YCPPath (".gettext.prg"), YCPString ("agent.ycp"));
}
