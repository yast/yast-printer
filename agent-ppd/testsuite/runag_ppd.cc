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

#include <stdio.h>
#include <unistd.h>
#include <utime.h>

#include <ycp/y2log.h>
#include <ycp/YCPParser.h>
#include <y2/Y2StdioComponent.h>
#include <scr/SCRInterpreter.h>
#include <scr/SCRAgent.h>

#include "../src/PPDAgent.h"

int
main (int argc, char *argv[])
{
    const char *fname = 0;
    FILE *infile = stdin;

    if (argc > 1) {
	int argp = 1;
	while (argp < argc) {
	    if ((argv[argp][0] == '-')
		&& (argv[argp][1] == 'l')
		&& (argp + 1 < argc)) {
		argp++;
		set_log_filename (argv[argp]);
	    } else if (fname == 0) {
		fname = argv[argp];
	    } else {
		fprintf (stderr, "Bad argument '%s'\nUsage: runag_ini "
			 "[name.ycp]\n", argv[argp]);
	    }
	    argp++;
	}
    }

    // create parser
    YCPParser *parser = new YCPParser ();
    if (!parser) {
	fprintf (stderr, "Failed to create YCPParser\n");
	exit (EXIT_FAILURE);
    }

    // create stdio as UI component, disable textdomain calls
    Y2Component *user_interface = new Y2StdioComponent (false, true);
    if (!user_interface) {
	fprintf (stderr, "Failed to create Y2StdioComponent\n");
	exit (EXIT_FAILURE);
    }

    // create IniAgent
    SCRAgent *agent = new PPDAgent ();
    if (!agent) {
	fprintf (stderr, "Failed to create IniAgent\n");
	exit (EXIT_FAILURE);
    }

    // create interpreter
    SCRInterpreter *interpreter = new SCRInterpreter (agent);
    if (!interpreter) {
	fprintf (stderr, "Failed to create SCRInterpreter\n");
	exit (EXIT_FAILURE);
    }

    // load config file (if existing)
    if (fname) {
	int len = strlen (fname);
	if (len > 5 && strcmp (&fname[len-4], ".ycp") == 0) {
	    // construct a term:
	    // `ag_ppd (PPDAgent("test/cname.spdb"))
	    char *cname = strdup (fname);
	    cname[len-4] = 0;
	    strcpy (&cname[len-4], ".db");
	    YCPTerm term (string ("PPDAgent"), false);
	    term->add (YCPString (cname));
	    interpreter->evaluate (term);
	    free (cname);
	}
    }

    // open ycp script
    if (fname != 0) {
	infile = fopen (fname, "r");
	if (infile == 0) {
	    fprintf (stderr, "Failed to open '%s'\n", fname);
	    exit (EXIT_FAILURE);
	}
    } else {
	fname = "stdin";
    }

    // evaluate ycp script
    parser->setInput (infile, fname);
    parser->setBuffered ();
    YCPValue value = YCPVoid ();
    while (true) {
	value = parser->parse ();
	if (value.isNull ())
	    break;
	value = interpreter->evaluate (value);
	printf ("(%s)\n", value->toString ().c_str ());
    }

    if (infile != stdin)
	fclose (infile);

    delete interpreter;
    delete agent;
    delete user_interface;
    delete parser;

    exit (EXIT_SUCCESS);
}
