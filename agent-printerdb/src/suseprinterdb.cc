#include <string.h>
#include <stdio.h>

#include "structs.h"
#include "suseprinterdb.h"

extern int yyparse ();
extern int yylineno;
extern FILE*yyin;
const char*current_filename = 0;

void parse_file (const char*fn)
{
    yylineno = 0;
    if (NULL != (yyin = fopen(fn, "r" )))
        {
            yyparse ();
            fclose (yyin);
        }
    else
	DB_ERROR ("Can not open file %s", fn);
}

int spdbStart (const char*path)
{
//    int add_from = 0;

    setDb_dir(path);

    yylineno = 0;
    parse_file (current_filename = path);
/*
    current_filename = new char[strlen (path) + 25];
    add_from = strlen (path);
    if (add_from)
    {
	strcpy (current_filename, path);
	if (path[add_from-1] != '/')
	    current_filename [add_from++] = '/';
    }

    yylineno = 0;
    strcpy (current_filename + add_from, "main.ascii");
    parse_file (current_filename);
    
    yylineno = 0;
    strcpy (current_filename + add_from, "manufacturers.ascii");
    parse_file (current_filename);
    
    yylineno = 0;
    strcpy (current_filename + add_from, "printers.ascii");
    parse_file (current_filename);
    
    yylineno = 0;
    strcpy (current_filename + add_from, "configs.ascii");
    parse_file (current_filename);
    
    yylineno = 0;
    strcpy (current_filename + add_from, "options.ascii");
    parse_file (current_filename);

    delete [] current_filename;
*/
    mains = reverse_list (mains);
    vendors = reverse_list (vendors);
    printers = reverse_list (printers);
    configs = reverse_list (configs);
    options = reverse_list (options);

    //
    // now I should dump the structures as html and check their validity
    //
    optionset = (Option**)makeset (options, &optionsize);
    configset = (Config**)makeset (configs, &configsize);
    printerset = (Printer**)makeset (printers, &printersize);
    vendorset = (Vendor**)makeset (vendors, &vendorsize);

    //FIXME: check if UseManufacturer doesn't use something that doesn't
    //exist doesn't work
    preprocess ();

    return 0;
}
int spdbFree ()
{
#define DELETESOMETHING(X) if (X){ delete [] X; X = 0; }
    DELETESOMETHING (optionset);
    DELETESOMETHING (configset);
    DELETESOMETHING (printerset);
    DELETESOMETHING (vendorset);
#undef DELETESOMETHING

#define DELETESOMETHING(X,Y)    if (X) {	\
	List*walk = X;				\
	while (walk){				\
	    Y*v = (Y*)walk->data;		\
	    X = walk;				\
	    walk = walk->next;			\
	    delete v;				\
	    delete X;				\
	}					\
    }
    DELETESOMETHING (options,Option);
    DELETESOMETHING (configs,Config);
    DELETESOMETHING (printers,Printer);
    DELETESOMETHING (vendors,Vendor);
    DELETESOMETHING (mains,Main);
#undef DELETESOMETHING
    return 0;
}

int yyerror (char*c)
{
    spdbReportError (yylineno, current_filename, "", c);
    return 0;
}
