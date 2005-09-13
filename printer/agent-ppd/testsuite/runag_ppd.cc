/*---------------------------------------------------------------------\
|                                                                      |
|                      __   __    ____ _____ ____                      |
|                      \ \ / /_ _/ ___|_   _|___ \                     |
|                       \ V / _` \___ \ | |   __) |                    |
|                        | | (_| |___) || |  / __/                     |
|                        |_|\__,_|____/ |_| |_____|                    |
|                                                                      |
|                               core system                            |
|                                                        (C) SuSE GmbH |
\----------------------------------------------------------------------/

   File:       runag_rcconfig.cc

   Author:     Arvin Schnell <arvin@suse.de>
	       Petr Blahos   <pblahos@suse.cz>
	       Jiri Srain    <jsrain@suse.cz>
   Maintainer: Petr Blahos   <pblahos@suse.cz>

/-*/

#include <scr/run_agent.h>

#include "../src/PPDAgent.h"

int main (int argc, char *argv[])
{
    run_agent <PPDAgent>(argc, argv, true);
}

