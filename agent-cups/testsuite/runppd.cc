#include <stdio.h>
#include <ycp/y2log.h>

#include "../src/PPD.h"

int 
main (int argc, char*argv[])
{
    if (argc < 3)
	{
	    printf ("Usage: %s directory filename\n", *argv);
	    return -1;
	}

    argv++;
    y2setLogfileName ("-");

    {
	PPD ppd (argv[0], argv[1]);
	ppd.createdb ();
    }

    return 0;
}
