/*
   File:       yhgen.cc
   Generator of yh files from printer database and printerdb agent

   Author:     Jiri Srain <jsrain@suse.cz>
   Maintainer: Jiri Srain <jsrain@suse.cz>

*/

#include "../src/PrinterdbAgent.h"

int
main (int argc, char *argv[])
{
    PrinterdbAgent a = PrinterdbAgent ();
    a.otherCommand (YCPTerm (YCPSymbol ("PrinterdbAgent", true), string ("suse.prdb")));
    a.Write (YCPPath (".gettext.db"), YCPString ("database.yh"));
    a.Write (YCPPath (".gettext.prg"), YCPString ("agent.yh"));
}
