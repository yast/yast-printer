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
#include <ycp/YCPInteger.h>
#include "PPDfile.h"
#include "PPDdb.h"

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
    char* new_name = tempnam (td, "ppd_file.");

    int len = strlen (fn);
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

/**
  * Check whether file is PPD file (try to open it using CUPS library calls)
  * @param filename file to check
  * @return true if is PPD file
  */
YCPBoolean PPDfile::isPpd (const char* filename)
{
    bool ret = true;
    const char* ppd_filename = filename;
    char* ungzipped = NULL;
    ppd_file_t *ppd; 
    
    ppd = ppdOpenFile(ppd_filename);
    if (! ppd)
    {
	ungzipped = tempnam ("/tmp", "ppd_file.");
	if (! ungzipped)
	    return YCPBoolean (false);
        ret = unpackGzipped (filename, ungzipped);
	if (! ret)
	    return YCPBoolean (false);
        ppd_filename = ungzipped; 
    }
    ppd = ppdOpenFile(ppd_filename);
    if (ppd)
    {
        ret = true;
        ppdClose(ppd);
    }
    else
        ret = false;

    if (ungzipped)
    {
        unlink (ungzipped);
        free (ungzipped);
    }
    return YCPBoolean (ret);
}
/**
  * Get the info about PPD file
  * @param filename file to check
  * @return true if is PPD file
  */
YCPMap PPDfile::ppdInfo (const char *filename)
{
    PPD::PPDInfo info;
    PPD db;
    db.process_file (filename, &info);
    YCPMap m = YCPMap();
    string printer = info.printer;
    if (info.products.size() > 0)
	printer = *(info.products.begin());
    m->add (YCPString ("manufacturer"), YCPString (info.vendor));
    m->add (YCPString ("model"), YCPString (info.printer));
    m->add (YCPString ("nick"), YCPString (info.nick));
    m->add (YCPString ("manufacturer_db"), YCPString (info.vendor_db));
    m->add (YCPString ("model_db"), YCPString (info.printer_db));
    m->add (YCPString ("filter"), YCPString (info.filter));
    m->add (YCPString ("language"), YCPString (info.lang));

    // and grab some info via CUPS libraries
    ppd_file_t *ppd; 

    if ((ppd = ppdOpenFile(filename)) == NULL)
    {
        y2error ("Unable to open PPD file %s !", filename);
        return m;
    }
    if (ppd->lang_encoding)
    {
	m->add (YCPString ("lang_encoding"), YCPString (ppd->lang_encoding));
    }
    if (ppd->lang_version)
    {
	m->add (YCPString ("lang_version"), YCPString (ppd->lang_version));
    }
    m->add (YCPString ("language_level"), YCPInteger (ppd->language_level));
    ppdClose (ppd);
    return m;
}

/**
  * Get UI constraints of a PPD file
  * @param filename of the PPD file
  * @return list of all constraints of the PPD file
  */
YCPList PPDfile::ppdConstraints (YCPString filename)
{
    ppd_file_t *ppd; 

    const char* fn = filename->value_cstr ();
    if ((ppd = ppdOpenFile(fn)) == NULL)
    {
        y2error ("Unable to open PPD file %s !", fn);
        return YCPList ();
    }
   
    YCPList ret = YCPList ();
    for (int i = 0; i < ppd->num_consts; i++)
    {
	YCPMap m = YCPMap ();
	ppd_const_t c = (ppd->consts)[i];
	m->add (YCPString ("option1"), YCPString (c.option1));
	m->add (YCPString ("value1"), YCPString (c.choice1));
	m->add (YCPString ("option2"), YCPString (c.option2));
	m->add (YCPString ("value2"), YCPString (c.choice2));
	ret->add (m);
    }
    ppdClose (ppd);
    return ret;
}

/**
  * Get the list of constrainting options
  * @param filename of the PPD file
  * @param options map of options to mark
  * @return list of all constrainting options in the PPD file
  */
YCPList PPDfile::ppdFailedConstraints (YCPString filename, YCPMap options)
{
    ppd_file_t *ppd; 

    const char* fn = filename->value_cstr ();

    if ((ppd = ppdOpenFile(fn)) == NULL)
    {
        y2error ("Unable to open PPD file %s !", fn);
        return YCPList ();
    }
    ppdMarkDefaults (ppd);
    int conflicts = 0;
    for (YCPMapIterator it = options->begin (); it != options->end (); it++)
    {
	YCPString key = it.key ()->asString ();
	YCPString value = it.value ()->asString ();
	conflicts = ppdMarkOption(ppd,
	    key->value_cstr (), value->value_cstr ());
    }
    YCPList constraints = YCPList ();
    for (int i = 0 ; i < ppd->num_groups; i++)
    {
	for (int j = 0 ; j < ppd->groups[i].num_options; j++)
	{
	    if (ppd->groups[i].options[j].conflicted)
	    {
		constraints->add (YCPString (
		    ppd->groups[i].options[j].keyword));
	    }
	}
    }

    return constraints;
}
