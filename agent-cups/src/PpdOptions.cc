#include "PpdOptions.h"
#include "Y2Logger.h"

#include "ppdstruct.h"

#include <cups/ppd.h>
#include <unistd.h>
#include <list>
#include <zlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

/*
void print_ppd_struct(PpdOption*p,int tab,int cont)
{
    if(tab)for(int i = 0;i<tab;i++)printf(" ");printf("========================\n");
    while (p)
        {
            if(tab)for(int i = 0;i<tab;i++)printf(" ");printf("Option: %s (%s) type=%s\n",p->option.c_str(), p->name.c_str(),p->type.c_str());
            PpdValue*v = p->val;
            while(v)
                {
                    if(tab)for(int i = 0;i<tab;i++)printf(" ");printf("  %s (%s)\n",v->value.c_str(), v->name.c_str());
                    if(v->sub)
                        {
                            PpdOptionList*w = v->sub;
                            while(w)
                                {
                                    print_ppd_struct(w->opt,tab+4,0);
                                    w = w->next;
                                }
                        }
                    v = v->next;
                }
            if(cont)
                p = p->next;
            else
                break;
        }
    if(tab)for(int i = 0;i<tab;i++)printf(" ");printf("========================\n");
}
*/

/**
 * Unpacks file to temp.
 * @return filename of ungziped temporary file. Must be delete[]d.
 */
//FIXME remove, is in printerdb agent
char*unpackGzipped(const char*fn)
{
    char buf[2048];
    char*newname;
    int out;
    newname = new char[L_tmpnam];
    tmpnam(newname);

    if ((out = open (newname, O_RDWR|O_CREAT|O_EXCL, 0600)) < 0)
    {
	y2error ("Possible link attack detection");
	delete [] newname;
	return NULL;
    }
    gzFile file = gzopen (fn, "rb");
    if (!file)
    {
	close (out);
	delete [] newname;
	return NULL;
    }
    while (gzgets(file, buf, sizeof buf))
	write (out,buf, strlen (buf));
    close (out);
    gzclose (file);

    return newname;
}

YCPBoolean isPpd (const char* filename)
{
    bool ret = true;
    const char* ppd_filename = filename;
    char* ungzipped = NULL;
    int len = strlen (filename);
    ppd_file_t *ppd;

    if (len>3 && !strcmp(filename+len-3,".gz"))
    {
        ungzipped = unpackGzipped (filename);
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
        free (ungzipped);
    return YCPBoolean (ret);
}
YCPMap ppdInfo (const char *filename)
{
    YCPMap m = YCPMap();
    const char* ppd_filename = filename;
    char* ungzipped = NULL;
    int len = strlen (filename);
    ppd_file_t *ppd;

    if (len>3 && !strcmp(filename+len-3,".gz"))
    {
        ungzipped = unpackGzipped (filename);
        ppd_filename = ungzipped;
    }
    ppd = ppdOpenFile(ppd_filename);
    if (ppd)
    {
        m->add (YCPString ("manufacturer"), YCPString (ppd->manufacturer));
        m->add (YCPString("model"), YCPString(ppd->modelname));
        m->add (YCPString ("nick"), YCPString(ppd->nickname));
    }
    if (ungzipped)
        free (ungzipped);
    return m;
}



/**
 * Returns value from map // fixme there is MapRep->value (...) which I should use here but it does not work.
 */
YCPValue findvalue (const YCPMap&m, const char*key, const char*deflt)
{
    for (YCPMapIterator beg = m->begin();beg!=m->end();beg++)
        {
            if (beg.key()->asString()->value()==key)
                {
                    return beg.value();
                }
        }
    return YCPString(deflt);
}
bool isvaluepresent (const YCPMap&m, const char*key)
{
    for (YCPMapIterator beg = m->begin();beg!=m->end();beg++)
        {
            if (beg.key()->asString()->value()==key)
                {
                    return true;
                }
        }
    return false;
}
/**
 * we need name of type
 * @param ui_type member of enum ppd_ui_t
 * @return its description
 */
char*getOptionTypeName (ppd_ui_t ui_type)
{
    switch (ui_type)
        {
        case PPD_UI_BOOLEAN:
            return "boolean";
        case PPD_UI_PICKONE:
            return "pickone";
        case PPD_UI_PICKMANY:
            return "pickmany";
        }
    return "unknown";
}

/**
 * Is option suboption of some other option?
 * @return bool true if yes.
 */
bool isSuboption(ppd_const_t*consts,int consts_num,const char*opt)
{
    for(int i = 0;i<consts_num;i++)
        {
            if(!strcmp(consts[i].option1,opt) && !consts[i].choice1[0] && consts[i].choice2[0]
               ||
               !strcmp(consts[i].option2,opt) && !consts[i].choice2[0] && consts[i].choice1[0])
                {
                    return true;
                }
        }
    return false;
}

/**
 * convert option to YCP map
 */
PpdOption*parseOption (ppd_option_t*option)
{
    PpdOption*p = new PpdOption;
    p->name = option->text;
    p->option = option->keyword;
    p->deflt = option->defchoice;
    p->marked = option->defchoice;
    p->type = getOptionTypeName (option->ui);
    for (int i = 0;i<option->num_choices;i++)
        {
            PpdValue*v = new PpdValue;
            v->name = option->choices[i].text;
            v->value = option->choices[i].choice;
            if (option->choices[i].marked)
                p->marked = option->choices[i].choice;
            v->next = p->val;
            p->val = v;
        }
    return p;
}
/**
 * place all options in group to ycp list
 */
PpdOption*parseGroups (ppd_group_t*group,int group_num)
{
    PpdOption*head = 0;
    PpdOption*added;
    for (int i = 0;i<group_num;i++, group++)
        {
            for (int j = 0;j<group->num_options;j++)
                {
                    added = parseOption(group->options+j);
                    if(added)
                        {
                            added->next = head;
                            head = added;
                        }
                }
            added = parseGroups (group->subgroups,group->num_subgroups);
            if (added)
                {
                    added->next = head;
                    head = added;
                }
        }
    return head;
}
void deleteConflicts(PpdOption**static_list,int len)
{
    for (int i = 0;i<len;i++)
        delete static_list[i];
    delete static_list;
}
PpdOption**staticListPpd(PpdOption*opt,int*len)
{
    int num;
    int i;
    PpdOption*walk = opt;
    num = 0;
    while (walk)
        {
            num++;
            walk = walk->next;
        }
    PpdOption**static_list = new PpdOption*[num];
    walk = opt;
    i = 0;
    while (walk)
        {
            static_list[i++] = walk;
            walk = walk->next;
        }
    *len = num;
    return static_list;
}

PpdOption* processConflicts(PpdOption*opt,ppd_const_t*consts,int consts_num,PpdOption**static_list,int num)
{
    int i;
    PpdOption*walk_cache;
    PpdOption*walk = opt;
    for(i = 0;i<num;i++)
        {
            if (isSuboption(consts,consts_num,static_list[i]->option.c_str()))
                {
                    PpdConflict conflict;
                    for(int j = 0;j<consts_num;j++)
                        if(!strcmp(consts[j].option1,static_list[i]->option.c_str()) && !consts[j].choice1[0] && consts[j].choice2[0])
                            conflict.add(consts[j].option2,consts[j].choice2);
                        else if(!strcmp(consts[j].option2,static_list[i]->option.c_str()) && !consts[j].choice2[0] && consts[j].choice1[0])
                            conflict.add(consts[j].option2,consts[j].choice1);
                    // now rebuild opt
                    walk_cache = 0;
                    walk = opt;
                    while(walk)
                        {
                            // note there we already have non-planar structure but
                            // if we admit there can be more that one instances of
                            // one option, we need to remove only root items
                            if(walk==static_list[i])
                                {
                                    // we have it!
                                    if(!walk_cache)
                                        {
                                            opt = walk->next;
                                        }
                                    else
                                        {
                                            walk_cache->next = walk->next;
                                        }
                                    walk->next = 0;
                                    break;
                                }
                            walk_cache = walk;
                            walk = walk->next;
                        }
                    // and now add item as a children of some options
                    int count_of_additions = opt->rebuildDueConflicts(&conflict,static_list[i]);
                    if(!count_of_additions)
                        {
                            static_list[i]->next = opt;
                            opt = static_list[i];
                        }
                }
            // else this is not suboption, do not touch it.
        }
    return opt;
}
YCPValue optionsToYcpOne(PpdOption*opt)
{
    YCPMap m;
    YCPMap val;
    m->add (YCPString ("name"), YCPString (opt->name));
    m->add (YCPString ("option"), YCPString (opt->option));
    m->add (YCPString ("default"), YCPString (opt->deflt));
    m->add (YCPString ("marked"), YCPString (opt->marked));
    m->add (YCPString ("type"), YCPString (opt->type));
    PpdValue*w = opt->val;
    while(w)
        {
            val->add(YCPString(w->value),YCPString(w->name));
            if(w->sub)
                {
                    YCPList sub;
                    PpdOptionList*lw = w->sub;
                    while(lw)
                        {
                            sub->add (optionsToYcpOne(lw->opt));
                            lw = lw->next;
                        }
                    string s = w->value + ":sub";
                    val->add(YCPString(s),sub);
                }
            w = w->next;
        }
    m->add (YCPString ("values"), val);
    return m;
}
YCPValue optionsToYcp(PpdOption*opt)
{
    YCPList l;
    while(opt)
        {
            l->add(optionsToYcpOne(opt));
            opt = opt->next;
        }
    return l;
}
/**
 * read ppd file.
 * @param ppd_filename path + file name of ppd file
 * @param options map of user-defined options $[ "option" : "value" , ... ]
 * @return list of options
 */
YCPValue readPpd (const char*ppd_filename,const YCPMap&options)
{
    PpdOption*opt;
    PpdOption**static_list;
    int static_list_len = 0;
    YCPMap real_ret;
    YCPList ret;
    char*ungzipped = NULL;
    //
    // is the file gzipped?
    //
    int len = strlen(ppd_filename);
    if (len>3 && !strcmp(ppd_filename+len-3,".gz"))
        {
            ungzipped = unpackGzipped (ppd_filename);
            ppd_filename = ungzipped;
        }
    ppd_file_t*ppd = ppdOpenFile (ppd_filename);
    
    if (NULL == ppd)
        {
            if(NULL!=ungzipped)
                {
                    unlink(ungzipped);
                    delete [] ungzipped;
                }
            return YCPVoid();
        }
    //
    // mark default options
    //
    ppdMarkDefaults(ppd);
    //
    // mark user-selected options
    //
    for (YCPMapIterator beg = options->begin();beg!=options->end();beg++)
	ppdMarkOption (ppd, beg.key()->asString()->value_cstr(), beg.value()->asString()->value_cstr());

    //
    // and finally get groups
    //
    opt = parseGroups(ppd->groups,ppd->num_groups);
    static_list = staticListPpd(opt,&static_list_len);
    opt = processConflicts(opt,ppd->consts,ppd->num_consts,static_list,static_list_len);
//    print_ppd_struct(opt,0,1);
    real_ret->add (YCPString ("ppd"), optionsToYcp(opt));
    deleteConflicts(static_list,static_list_len);
    real_ret->add (YCPString ("charset"), YCPString (ppd->lang_encoding ? ppd->lang_encoding : ""));
    ppdClose(ppd);
    if(NULL!=ungzipped)
        {
            unlink(ungzipped);
            delete [] ungzipped;
        }
    return real_ret;
}

void createIntOption (const char*int_name, const char*out_name, int low, int up, const char*deflt, char*type, const YCPMap&options, YCPList&ret)
{
    YCPValue marked = findvalue (options, int_name, deflt);
    YCPMap option;
    option->add (YCPString ("name"), YCPLocale (YCPString (out_name)));
    option->add (YCPString ("type"), YCPString (type));
    option->add (YCPString ("lowermargin"), YCPInteger ((long long int)low));
    option->add (YCPString ("uppermargin"), YCPInteger ((long long int)up));
    option->add (YCPString ("option"), YCPString (int_name));
    option->add (YCPString ("default"), YCPString (deflt));
    option->add (YCPString ("marked"), marked);
    ret->add (option);
}
void createBoolOption (const char*int_name, const char*out_name, const char*deflt, const YCPMap&options, YCPList&ret)
{
    YCPMap option;
    option->add (YCPString ("name"), YCPLocale (YCPString (out_name)));
    option->add (YCPString ("type"), YCPString ("yesno"));
    option->add (YCPString ("option"), YCPString (int_name));
    option->add (YCPString ("default"), YCPString (deflt));
    option->add (YCPString ("marked"), YCPString (isvaluepresent (options, int_name) ? "true" : "false"));
    ret->add (option);
}
/**
 * Read common options...
 */
YCPValue readCommonOptions (const char*ppd_filename,const YCPMap&options)
{
    char*ungzipped = NULL;
    YCPList ret;
    //
    // is the file gzipped?
    //
    int len = strlen(ppd_filename);
    if (len>3 && !strcmp(ppd_filename+len-3,".gz"))
        {
            ungzipped = unpackGzipped (ppd_filename);
            ppd_filename = ungzipped;
        }

    ppd_file_t*ppd = ppdOpenFile (ppd_filename);
    //
    // mark default options
    //
    ppdMarkDefaults(ppd);
    //
    // mark user-selected options
    //
    for (YCPMapIterator beg = options->begin();beg!=options->end();beg++)
        {
            ppdMarkOption (ppd, beg.key()->asString()->value_cstr(), beg.value()->asString()->value_cstr());
        }

    //
    // get not-so-common common option (color)
    //
    if (NULL!=ppd)
        {
            if (ppd->color_device)
                {
                    char*colorspace_name = "CMYK";
                    switch (ppd->colorspace)
                        {
                        case PPD_CS_CMYK: colorspace_name = "CMYK"; break;
                        case PPD_CS_CMY:  colorspace_name = "CMY"; break;
                        case PPD_CS_RGB:  colorspace_name = "RGB"; break;
                        case PPD_CS_RGBK: colorspace_name = "RGBK"; break;
                        case PPD_CS_N:    colorspace_name = "N"; break;
                        default:          colorspace_name = "Gray"; break;
                        }
                    YCPValue marked = findvalue (options, "ColorModel",colorspace_name);
                    YCPMap values;
                    YCPMap option;
                    values->add(YCPString(colorspace_name),YCPLocale(YCPString("Yes")));
                    values->add(YCPString("Gray"),YCPLocale(YCPString("No")));
                    option->add (YCPString ("name"), YCPLocale (YCPString ("Color Printing")));
                    option->add (YCPString ("type"), YCPString ("pick_one"));
                    option->add (YCPString ("option"), YCPString ("ColorModel"));
                    option->add (YCPString ("default"), YCPString (colorspace_name));
                    option->add (YCPString ("marked"), marked);
                    option->add (YCPString ("values"), values);
                    ret->add (option);
                }
        }
    else
        {
            YCPValue marked = findvalue (options, "ColorModel","CMYK");
            YCPMap values;
            YCPMap option;
            values->add(YCPString("CMYK"),YCPLocale(YCPString("Yes")));
            values->add(YCPString("Gray"),YCPLocale(YCPString("No")));
            option->add (YCPString ("name"), YCPLocale (YCPString ("Color Printing")));
            option->add (YCPString ("type"), YCPString ("pick_one"));
            option->add (YCPString ("option"), YCPString ("ColorModel"));
            option->add (YCPString ("default"), YCPString ("CMYK"));
            option->add (YCPString ("marked"), marked);
            option->add (YCPString ("values"), values);
            ret->add (option);
        }
    //
    // get not-so-common common option (page size...)
    // (FIXME: I need to do final decision but I believe I do not need to add
    // page sizes, trays and paper types here because they are in non-common options).
    //
    
    //
    // and finally get common options
    //
    {
        YCPValue marked = findvalue (options, "orientation-requested","3");
        YCPMap values;
        YCPMap option;
        values->add(YCPString("3"),YCPLocale(YCPString("Portrait")));
        values->add(YCPString("4"),YCPLocale(YCPString("Landscape")));
        values->add(YCPString("5"),YCPLocale(YCPString("Reverse")));
        values->add(YCPString("6"),YCPLocale(YCPString("Reverse portrait")));
        option->add (YCPString ("name"), YCPLocale (YCPString ("Orientation")));
        option->add (YCPString ("type"), YCPString ("pick_one"));
        option->add (YCPString ("option"), YCPString ("orientation-requested"));
        option->add (YCPString ("default"), YCPString ("3"));
        option->add (YCPString ("marked"), marked);
        option->add (YCPString ("values"), values);
        ret->add (option);
    }
    {
        YCPValue marked = findvalue (options, "sides","");
        YCPMap values;
        YCPMap option;
        values->add(YCPString(""),YCPLocale(YCPString("None")));
        values->add(YCPString("two-sided-long-edge"),YCPLocale(YCPString("Long edge")));
        values->add(YCPString("two-sided-short-edge"),YCPLocale(YCPString("Short edge")));
        option->add (YCPString ("name"), YCPLocale (YCPString ("Duplex printing")));
        option->add (YCPString ("type"), YCPString ("pick_one"));
        option->add (YCPString ("option"), YCPString ("sides"));
        option->add (YCPString ("default"), YCPString (""));
        option->add (YCPString ("marked"), marked);
        option->add (YCPString ("values"), values);
        ret->add (option);
    }
    {
        YCPValue marked = findvalue (options, "number-up","1");
        YCPMap values;
        YCPMap option;
        values->add(YCPString("1"),YCPLocale(YCPString("1")));
        values->add(YCPString("2"),YCPLocale(YCPString("2")));
        values->add(YCPString("4"),YCPLocale(YCPString("4")));
        option->add (YCPString ("name"), YCPLocale (YCPString ("Pages per sheet")));
        option->add (YCPString ("type"), YCPString ("pick_one"));
        option->add (YCPString ("option"), YCPString ("number-up"));
        option->add (YCPString ("default"), YCPString ("1"));
        option->add (YCPString ("marked"), marked);
        option->add (YCPString ("values"), values);
        ret->add (option);
    }
    createIntOption ("brightness", "Brightness",		0, 200, "100", "slider", options, ret);
    createIntOption ("gamma",      "Gamma",      		0, 3000, "1000", "slider", options, ret);
    createIntOption ("cpi",        "Characters per inch",	1, 100, "10", "int", options, ret);
    createIntOption ("lpi",        "Lines per inch",		1, 100, "10", "int", options, ret);
    createIntOption ("columns",    "Number of columns",		1, 10, "1", "int", options, ret);
    createIntOption ("page-left",  "Left margin",		0, 10000, "8", "int", options, ret);
    createIntOption ("page-right", "Right margin",		0, 10000, "8", "int", options, ret);
    createIntOption ("page-top",   "Top margin",		0, 10000, "25", "int", options, ret);
    createIntOption ("page-bottom","Bottom margin",		0, 10000, "39", "int", options, ret);
    createBoolOption("prettyprint","Pretty printing",		"false", options, ret);
    createIntOption ("scaling",    "Image size (%)",		1, 800, "100", "slider", options, ret);
    createIntOption ("ppi",    	   "Image size (pixels per inch)",1, 1200, "100", "slider", options, ret);// fixme this is in colision with scaling, none of them need be used
    createIntOption ("hue",    	   "Hue of an image",		-360, 360, "0", "slider", options, ret);
    createIntOption ("saturation", "Saturation",		0, 200, "100", "slider", options, ret);
    createBoolOption("blackplot",  "Use only black pen",	"false", options, ret);
    createBoolOption("fitplot",    "Fit plot to page",		"false", options, ret);
    createIntOption ("penwidth", "Default pen width",		0, 10000, "1000", "int", options, ret);
    if(NULL!=ppd)
        ppdClose(ppd);
    if(NULL!=ungzipped)
        {
            unlink(ungzipped);
            delete [] ungzipped;
        }
    return ret;
}

/*
 *
  // media size, type, source
  // Color
  // banners are set elsewhere
  // ranges of pages, even/odd pages are set in print-time
 *
 */
