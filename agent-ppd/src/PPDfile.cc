/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD implementation
 *
 * Authors:
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <cups/ppd.h>
#include <zlib.h>
#include <ctype.h>
#include <fcntl.h>

#include <map>
#include <string>

/*
    TODO
    - fix all FIXME
*/

#ifndef _DEVEL_

#include "ycp/y2log.h"
#include "PPDfile.h"

/*****************************************************************/

#undef y2debug
#define y2debug(format, args...)

#else
#define y2debug(format, args...) //fprintf(stderr, format "\n" , ##args)
#define y2warning(format, args...) fprintf(stderr, format "\n" , ##args)
#define y2error(format, args...) fprintf(stderr, format "\n" , ##args)

#include "PPD.h"
#endif

/*****************************************************************/

// misc functions

/**
 * Unpacks file to temp.
 * @return filename of ungziped temporary file. Must be delete[]d.
 */
bool unpackGzipped(const char*fn, const char* new_fn)
{
    char buf[2048];
    int out;
    
    if ((out = open (new_fn, O_RDWR|O_CREAT|O_EXCL, 0600)) < 0)
    {
        y2error ("Possible link attack detection");
        return false;
    }
    gzFile file = gzopen (fn, "rb");
    if (!file)
    {
        close (out);
        return false;
    }
    while (gzgets(file, buf, sizeof buf))
        write (out,buf, strlen (buf));
    close (out);
    gzclose (file);

    return true;
}



/**
 * Constructor
 */
PPDfile::PPDfile() {
}

/**
 * Destructor
 */
PPDfile::~PPDfile() {
}

YCPString PPDfile::openPpdFile (YCPString filename, YCPString tmpdir) {
    const char* fn = filename->value_cstr ();
    const char* td = tmpdir -> value_cstr ();

    bool ungzipped = false;
    int len = strlen (fn);
    char* new_name = tempnam (td, "ppd_file.");

    if (len>3 && !strcmp(fn+len-3,".gz"))
    {
        ungzipped = unpackGzipped (fn, new_name);
    }
    else
    {
	int out, in;

	if ((out = open (new_name, O_RDWR|O_CREAT|O_EXCL, 0600)) < 0)
	{
	    y2error ("Possible link attack detection");
	    free (new_name);
	    return YCPString ("");
	}
	if ((in = open (fn, O_RDONLY)) < 0)
	{
	    y2error ("Error opening PPD file >>%s<<", fn);
	    free (new_name);
	    close (out);
	    return YCPString ("");
	}

	char buf[2048];
	size_t count;

	while ((count = read (in, buf, 2048)) > 0)
	{
	    write (out, buf, count);
	}

	close (in);
	close (out);
	ungzipped = true;
    }

    YCPString s = YCPString ("");
    if (ungzipped)
	s = YCPString (new_name);
    free (new_name);
    return s;
}

YCPMap PPDfile::getOptionsGroups (YCPString filename) {
    const char* fn = filename->value_cstr ();
    int i;

    ppd_file_t *ppd;
    ppd_group_t *group;

    if ((ppd = ppdOpenFile(fn)) == NULL)
    {
        y2error ("Unable to open PPD file %s !", fn);
        return YCPMap ();
    }

    YCPList l;
    for (i = ppd->num_groups, group = ppd->groups; i > 0; i --, group ++)
    {
        l->add (YCPString (group->text));
    }

    YCPMap m;
    m->add (YCPString ("charset"), YCPString (""));
    m->add (YCPString ("data"), l);
    ppdClose(ppd);
    return m;
}

YCPMap PPDfile::getOptions (YCPString filename, YCPString section) {
    const char* fn = filename->value_cstr ();
    const char* sect = section->value_cstr ();
    int sec, opt, val;

    ppd_file_t *ppd;
    ppd_group_t *group;

    ppd_option_t  *option; 
    ppd_choice_t  *choice;

    if ((ppd = ppdOpenFile(fn)) == NULL)
    {
	y2error ("Unable to open PPD file %s", fn);
	return YCPMap ();
    }

    ppdMarkDefaults(ppd);

    YCPList options;

    for (sec = ppd->num_groups, group = ppd->groups; sec > 0;
	sec --, group ++)
    {
	if (0 == strcmp (sect, "") || 0 == strcmp (sect, group->text))
	{
	    for (opt = group->num_options, option = group->options; opt > 0;
		opt --, option ++)
	    {
		YCPMap values;
		YCPMap option1;
		YCPList valorder;
		for (val = option->num_choices, choice = option->choices;
		    val > 0; val --, choice ++)
		{
		    valorder->add (YCPString (choice->choice));
		    values->add (YCPString (choice->choice),
			YCPString (choice->text));
		    if (choice->marked)
		    {
			option1->add (YCPString ("current"),
			    YCPString (choice->choice));
		    }
		}
		option1->add (YCPString ("values"), values);
		option1->add (YCPString ("valorder"), valorder);
		option1->add (YCPString ("name"), YCPString (option->keyword));
		option1->add (YCPString ("gui"), YCPString (option->text));
		string opttype = "";
		if (option->ui == PPD_UI_PICKONE)
		    opttype = "PickOne";
		else if (option->ui == PPD_UI_PICKMANY)
		    opttype = "PickMany";
		else if (option->ui == PPD_UI_BOOLEAN)
		    opttype = "Boolean" ;
		option1->add (YCPString ("type"), YCPString (opttype));
		options->add (option1);
	    }
	}
    }
    YCPMap m;
    m->add (YCPString ("data"), options);
    m->add (YCPString ("charset"), YCPString (""));
    return m;
}
