/* runcups.cc
 *
 * Testing stub for the cups agent
 *
 * Authors: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 *
 * Based on modules agent testsuite.
 */

#include <stdio.h>
#include <unistd.h>

#include <ycp/y2log.h>
#include <ycp/YCPParser.h>
#include <y2/Y2StdioComponent.h>
#include <scr/SCRInterpreter.h>
#include <scr/SCRAgent.h>

#include "../src/CupsAgent.h"

extern int yydebug;

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
		fprintf (stderr, "Bad argument '%s'\nUsage: runag_rcconfig "
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

    // create CupsAgent?
    SCRAgent *agent = new CupsAgent ();
    if (!agent) {
	fprintf (stderr, "Failed to create RcAgent\n");
	exit (EXIT_FAILURE);
    }

    // create interpreter
    SCRInterpreter *interpreter = new SCRInterpreter (agent);
    if (!interpreter) {
	fprintf (stderr, "Failed to create SCRInterpreter\n");
	exit (EXIT_FAILURE);
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
	// ignore return value printf ("(%s)\n", value->toString ().c_str ());
    }

    if (infile != stdin)
	fclose (infile);

    delete interpreter;
    delete agent;
    delete user_interface;
    delete parser;

    exit (EXIT_SUCCESS);
}
