#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "structs.h"


#include "PrinterdbAgent.h"
#include "suseprinterdb.h"
#include "structs.h"

#include <libintl.h>
#include <stdarg.h>
#include <langinfo.h>
    
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/stat.h>



List*mains = 0;
List*vendors = 0;
List*printers = 0;
List*configs = 0;
List*options = 0;

Option**optionset = 0;
int optionsize = 0;
Config**configset = 0;
int configsize = 0;
Printer**printerset = 0;
int printersize = 0;
Vendor**vendorset = 0;
int vendorsize = 0;

void PasteOptions (Option*opt, const char*current_option);
void PasteConfigs (Config*cfg, const char*current_cfg);
void PastePrinter (Printer*cfg, const char*current_cfg);
void PasteVendor (Vendor*cfg, const char*current_cfg);

struct makeseter
{
    char*ident;
};
    

/**
 * Get size of list
 * @param l list
 * @return size of list
 */
int listsize (List*l)
{
    int s = 0;
    while (l)
	{
	    s++;
	    l = l->next;
	}
    return s;
}

int compareidents (const void*a, const void*b)
{
    const makeseter**s1 = (const makeseter**)a;
    const makeseter**s2 = (const makeseter**)b;
    return strcmp ((*s1)->ident,(*s2)->ident);
}

/**
 * Create set(sorted array) from linked list.
 * @param l list
 * @return set
 */
void*makeset (List*l,int*size_out)
{
    int len = listsize (l);
    if (size_out)
	*size_out = len;
    makeseter**set = new makeseter*[len];
    makeseter**walk = set;
    while (l)
	{
	    *walk = (makeseter*)l->data;
	    walk++;
	    l = l->next;
	}
    // sort the array
    qsort (set, len, sizeof (makeseter*), compareidents);
    return (void*)set;
}

void*findinset (void*vset, int len, const char*ident)
{
    makeseter*key = new makeseter;
    key->ident = (char*)ident;
    void*ret = bsearch (&key, vset, len, sizeof (makeseter*), compareidents);
    delete key;
    return ret;
}
ValueItem::~ValueItem ()
{
    if (type) delete [] type;
    if (val) delete [] val;
    if (next) delete next;
}
ValueItem*ValueItem::copy ()
{
    ValueItem*v = new ValueItem;
    v->type = type ? strdup (type) : 0;
    v->val = val ? strdup (val) : 0;
    v->next = next ? next->copy() : 0;
    return v;
}
Value::~Value () 
{
    if (items) delete items;
    if (text) delete [] text;
    List*walk = use;
    while (walk) 
    {
	Useoption*v = (Useoption*)walk->data;
	delete v;
	use = walk;
	walk = walk->next;
	delete use;
    }
}
Value*Value::copy ()
{
    Value*v = new Value;
    v->items = items ? items->copy() : 0;
    v->text = text ? strdup (text) : 0;
    v->use = 0;
    v->type = type;
    List*n = 0;
    List*walk = use;
    while (walk) {
	if (!n) {
	    v->use = n = new List;
	}
	else {
	    n->next = new List;
	    n = n->next;
	}
	n->next = 0;
	Useoption*uo = new Useoption;
	n->data = uo;
	uo->ident = strdup (((Useoption*)walk->data)->ident);
	uo->as = strdup (((Useoption*)walk->data)->as);
	uo->text = strdup (((Useoption*)walk->data)->text);
	uo->use = 0;
	walk = walk->next;
    }
    return v;
}

Option::~Option ()
{
    if (ident)   delete [] ident;
    if (comment) delete [] comment;
    switch (type) 
    {
      case 1:
	delete numint;
	break;
      case 2:
	delete numfloat;
	break;
      case 3:
	delete valtext;
	break;
      default:
	{
	    List*walk = vals;
	    while (walk)
	    {
		vals = walk;
		Value*v = (Value*)walk->data;
		delete v;
		walk = walk->next;
		delete vals;
	    }
	}
	break;
    }
}
Config::~Config ()
{
    if (ident) delete [] ident;
    if (comment)delete [] comment;
    if (type && param) delete param;
    List*walk = use;
    while (walk)
    {
	use = walk;
	if (type)
	{
	    Useoption*v = (Useoption*)walk->data;
	    delete v;
	}
	else
	{
	    Useconfig*v = (Useconfig*)walk->data;
	    delete v;
	}
	walk = walk->next;
    }
}
Printer::~Printer ()
{
    if (ident) delete [] ident;
    if (comment)delete [] comment;
    List*walk = use;
    while (walk)
    {
	Useconfig*v = (Useconfig*)walk->data;
	delete v;
	use = walk;
	walk = walk->next;
	delete use;
    }
}

Vendor::~Vendor ()
{
    if (ident)  delete [] ident;
    if (comment)delete [] comment;
    List*walk = use;
    while (walk)
    {
	Useprinter*v = (Useprinter*)walk->data;
	use = walk;
	walk = walk->next;
	delete v;
	delete use;
    }
}

Main::~Main()
{
    if (text) delete [] text;
    if (ieee) delete [] ieee;
    if (use)  delete [] use;
}
Useoption::~Useoption () 
{ 
    if (as == ident) as = 0;
    if (as) delete [] as;
    if (ident) delete [] ident; 
    if (text) delete [] text; 
}
Useprinter::~Useprinter () 
{
    if (ident) delete [] ident;
    if (text) delete [] text;
    if (ieee) delete [] ieee;
}
Useconfig::~Useconfig () 
{ 
    if (ident) delete [] ident; 
    if (text) delete [] text; 
    if (queue) delete [] queue;
}

/**
 * Create use pointers in Use* values.
 */
int preprocess ()
{
    void*cache;
    List*walk = vendors;
    while (walk) {
	Vendor*v = (Vendor*)walk->data;
	PasteVendor (v, v->ident);
	List*use = v->use;
	while (use) {
	    Useprinter*p = (Useprinter*)use->data;
	    cache = findinset (printerset, printersize, p->ident);
	    if (!cache)
		DB_ERROR ("Printer %s used but not defined.", p->ident);
	    p->use = cache ? *(Printer**)cache : 0;
	    use = use->next;
	}
	walk = walk->next;
    }
    walk = printers;
    while (walk) {
	Printer*v = (Printer*)walk->data;
	PastePrinter (v, v->ident);
	List*use = v->use;
	while (use) {
	    Useconfig*p = (Useconfig*)use->data;
	    cache = findinset (configset, configsize, p->ident);
	    if (!cache)
		DB_ERROR ("Config %s used but not defined.", p->ident);
	    p->use = cache ? *(Config**)cache : 0;
	    use = use->next;
	}
	walk = walk->next;
    }
    walk = configs;
    while (walk) {
	Config*v = (Config*)walk->data;
	List*use = v->use;
	if (v->type) {
	    while (use) {
		Useoption*p = (Useoption*)use->data;
		cache = findinset (optionset, optionsize, p->ident);
		if (!cache)
		    DB_ERROR ("Option %s used but not defined.", p->ident);
		p->use = cache ? *(Option**)cache : 0;
		use = use->next;
	    }
	}
	else {
	    PasteConfigs (v, v->ident);
	    use = v->use;
	    while (use) {
		Useconfig*p = (Useconfig*)use->data;
		cache = findinset (configset, configsize, p->ident);
		if (!cache)
		    DB_ERROR ("Config %s used but not defined.", p->ident);
		p->use = cache ? *(Config**)cache : 0;
		use = use->next;
	    }
	}
	walk = walk->next;
    }
    walk = options;
    while (walk) {
	Option*v = (Option*)walk->data;
	if (!v->type) {
	    PasteOptions (v, v->ident);
	    List*vals = v->vals;
	    while (vals) {
		Value*val = (Value*)vals->data;
		List*use = val->use;
		while (use) {
		    Useoption*u = (Useoption*)use->data;
		    cache = findinset (optionset, optionsize, u->ident);
		    if (!cache)
			DB_ERROR ("Option %s used but not defined.", u->ident);
		    u->use = cache ? *(Option**)cache : 0;
		    use = use->next;
		}
		vals = vals->next;
	    }
	}
	walk = walk->next;
    }
    return 0;
}
/**
 * Get list of configs(leafs) from the list of Useconfig
 * @param use List of Useconfig
 * @return List of Useconfigs. These Useconfigs contain only options, no
 * 	subconfigs.
 */
List*getconfigs (List*use)
{
    // create copy of the list
    List*n = NULL;
    while (use) {
	List*i = new List;
	i->data = use->data;
	i->next = n;
	n = i;
	use = use->next;
    }
    n = reverse_list (n);

    // walk through copy and each item that is config replace by list
    List*walk = n;
    while (walk) {
	Useconfig*c = (Useconfig*)walk->data;
	if (c && c->use) {
	    if (!c->use->type) {
		List*sub = getconfigs (c->use->use);
		if (sub) {
		    List*w2 = sub;
		    while (w2->next) {
			w2 = w2->next;
		    }
		    w2->next = walk->next;
		    walk->data = sub->data;
		    walk->next = sub->next;
		    delete sub;
		}
	    }
	}
	else {
	    DB_ERROR ("Config %s not found\n", c->ident);
	}
	walk = walk->next;
    }

    walk = n;
    List*prev = 0;
    while (walk) {
	List*next = walk->next;
	Useconfig*c = (Useconfig*)walk->data;
	if (!c || !c->use || !c->use->type) {
	    // remove this item from list
	    if (!prev)
		n = walk->next;
	    else
		prev->next = walk->next;
	    delete walk;
	}
	else {
	    prev = walk;
	    c->use->queue = c->queue;
	}
	walk = next;
    }
    return n;
}
List*reverse_list (List*l)
{
    List*n = 0;
    while (l) {
	List*next = l->next;
	l->next = n;
	n = l;
	l = next;
    }
    return n;
}

/**
 * Return 0 if not successful
 */
int CopyOption (List*l, Option*o, List*use)
{
    List*next = l->next;

    if (o->type) {
	DB_ERROR ("PasteOption %s: can not paste numeric option.", o->ident);
	return 0;
    }
    List*walk = o->vals;
    List*n = 0;
    List*first = 0;
    while (walk) {
	if (!first) {
	    n = first = new List;
	}
	else {
	    n->next = new List;
	    n = n->next;
	}
	n->data = ((Value*)walk->data)->copy();
	walk = walk->next;
    }
    if (first) {
	if (use) {
	    List*u = ((Value*)n->data)->use;
	    if (u) {
		while (u->next)
		    u = u->next;
		u->next = use;
	    }
	    else
		((Value*)n->data)->use = use;
	}
	n->next = next;
	l->data = first->data;
	l->next = first->next;
	delete first;
	return 1;
    }
    DB_ERROR ("PasteOption %s: option has no values.", o->ident);
    return 0;
}
void PasteOptions (Option*opt, const char*current_option)
{
    List*walk = opt->vals;
    List**prev = &(opt->vals);
    while (walk) {
	if (!((Value*)walk->data)->text) //if(text==0) this is a PasteOption
	    break;
	prev = &(walk->next);
	walk = walk->next;
    }
    if (!walk) // no PasteOptions found
	return ;

    // find option in option list
    while (walk) {
	if (!((Value*)walk->data)->text) {
	    Value*v = (Value*)walk->data;
	    // Find option
	    Option**o = (Option**)findinset (optionset, optionsize, v->paste);
	    // Paste option here
	    int success = 0;
	    int doit = 1;
	    if (!o) {
		DB_ERROR ("PasteOption %s: option not found.", v->paste);
		doit = 0;
	    }
	    if (doit && !strcmp (current_option, (*o)->ident)) {
		DB_ERROR ("PasteOption %s: is pasting itself!!!", current_option);
		doit = 0;
	    }
	    if (doit) {
		if (!opt->comment && (*o)->comment)
		    opt->comment = strdup ((*o)->comment);
		success = CopyOption (walk, *o, v->use);
		v->use = 0;
	    }
	    if (!success) {
		*prev = walk->next;
		delete walk;
		walk = *prev;
	    }
	    delete v;
	}
	else {
	    prev = &(walk->next);
	    walk = walk->next;
	}
    }
}
int CopyConfig (List*l, Config*o)
{
    List*next = l->next;

    List*walk = o->use;
    List*n = 0;
    List*first = 0;
    while (walk) {
	if (!first) {
	    n = first = new List;
	}
	else {
	    n->next = new List;
	    n = n->next;
	}
	n->data = ((Useconfig*)walk->data)->copy();
	walk = walk->next;
    }
    if (first) {
	n->next = next;
	l->data = first->data;
	l->next = first->next;
	delete first;
	return 1;
    }
    DB_ERROR ("PasteOption %s: option has no values.", o->ident);
    return 0;
}
Useconfig*Useconfig::copy()
{
    Useconfig*c = new Useconfig;
    c->ident = ident ? strdup(ident) : 0;
    c->text = text ? strdup(text) : 0;
    c->queue = queue ? strdup(queue) : 0;
    c->use = 0; // will be filled later
    return c;
}
Useprinter*Useprinter::copy()
{
    Useprinter*p = new Useprinter;
    p->ident = ident ? strdup(ident) : 0;
    p->text = text ? strdup(text) : 0;
    p->ieee = ieee ? strdup(ieee) : 0;
    p->use = 0;
    return p;
}
void PasteConfigs (Config*cfg, const char*current_cfg)
{
    List*walk = cfg->use;
    List**prev = &(cfg->use);
    while (walk) {
	if (!((Useconfig*)walk->data)->text) //if(text==0) this is a PasteConfig
	    break;
	prev = &(walk->next);
	walk = walk->next;
    }
    if (!walk) // no PasteOptions found
	return ;

    // find config in config list
    while (walk) {
	if (!((Useconfig*)walk->data)->text) {
	    Useconfig*v = (Useconfig*)walk->data;
	    // Find option
	    Config**o = (Config**)findinset (configset, configsize, v->ident);
	    // Paste option here
	    int success = 0;
	    int doit = 1;
	    if (!o) {
		DB_ERROR ("PasteConfig %s: config not found.", v->ident);
		doit = 0;
	    }
	    if (doit && !strcmp (current_cfg, (*o)->ident)) {
		DB_ERROR ("PasteConfig %s: is pasting itself!!!", current_cfg);
		doit = 0;
	    }
	    if (doit && (*o)->type) {
		DB_ERROR ("PasteConfig %s: can not paste leaf config!!!", (*o)->ident);
		doit = 0;
	    }
	    if (doit) {
		if (!cfg->comment && (*o)->comment)
		    cfg->comment = strdup ((*o)->comment);
		success = CopyConfig (walk, *o);
		v->use = 0;
	    }
	    if (!success) {
		*prev = walk->next;
		delete walk;
		walk = *prev;
	    }
	    delete v;
	}
	else {
	    prev = &(walk->next);
	    walk = walk->next;
	}
    }
}
int CopyPrinter (List*l, Printer*o)
{
    List*next = l->next;

    List*walk = o->use;
    List*n = 0;
    List*first = 0;
    while (walk) {
	if (!first) {
	    n = first = new List;
	}
	else {
	    n->next = new List;
	    n = n->next;
	}
	n->data = ((Useconfig*)walk->data)->copy();
	walk = walk->next;
    }
    if (first) {
	n->next = next;
	l->data = first->data;
	l->next = first->next;
	delete first;
	return 1;
    }
    DB_ERROR ("PastePrinter %s: printer has no configs.", o->ident);
    return 0;
}
void PastePrinter (Printer*cfg, const char*current_cfg)
{
    List*walk = cfg->use;
    List**prev = &(cfg->use);
    while (walk) {
	if (!((Useconfig*)walk->data)->text) //if(text==0) this is a PasteConfig
	    break;
	prev = &(walk->next);
	walk = walk->next;
    }
    if (!walk) // no PastePrinter found
	return ;

    // find printer in printer list
    while (walk) {
	if (!((Useconfig*)walk->data)->text) {
	    Useconfig*v = (Useconfig*)walk->data; //But the identifier here isn't config but printer!
	    // Find option
	    Printer**o = (Printer**)findinset (printerset, printersize, v->ident);
	    // Paste option here
	    int success = 0;
	    int doit = 1;
	    if (!o) {
		DB_ERROR ("PastePrinter %s: printer not found.", v->ident);
		doit = 0;
	    }
	    if (doit && !strcmp (current_cfg, (*o)->ident)) {
		DB_ERROR ("PastePrinter %s: is pasting itself!!!", current_cfg);
		doit = 0;
	    }
	    if (doit) {
		if (!cfg->comment && (*o)->comment)
		    cfg->comment = strdup ((*o)->comment);
		success = CopyPrinter (walk, *o);
		v->use = 0;
	    }
	    if (!success) {
		*prev = walk->next;
		delete walk;
		walk = *prev;
	    }
	    delete v;
	}
	else {
	    prev = &(walk->next);
	    walk = walk->next;
	}
    }
}

int CopyVendor (List*l, Vendor*o)
{
    List*next = l->next;

    List*walk = o->use;
    List*n = 0;
    List*first = 0;
    while (walk) {
        if (!first) {
            n = first = new List;
        }
        else {
            n->next = new List;
            n = n->next;
        }
        n->data = ((Useprinter*)walk->data)->copy();
        walk = walk->next;
    }
    if (first) {
        n->next = next;
        l->data = first->data;
        l->next = first->next;
        delete first;
        return 1;
    }
    DB_ERROR ("PasteVendor %s: vendor has no configs.", o->ident);
    return 0;
}
void PasteVendor (Vendor*cfg, const char*current_cfg)
{
    List**prev = &(cfg->use);
    List*walk = cfg->use;
    while (walk) {
        if (!((Useconfig*)walk->data)->text)
            break;
	prev = &(walk->next);
        walk = walk->next;
    }
    if (!walk) // no PasteVendor found
        return ;

    // find option in option list
    while (walk) {
        if (!((Useprinter*)walk->data)->text) {
            Useprinter*v = (Useprinter*)walk->data; //But the identifier here isn't config but vendor!
            // Find option
            Vendor**o = (Vendor**)findinset (vendorset, vendorsize, v->ident);
            // Paste option here
            int success = 0;
            int doit = 1;
            if (!o) {
                DB_ERROR ("PasteVendor %s: vendor not found.", v->ident);
                doit = 0;
            }
            if (doit && !strcmp (current_cfg, (*o)->ident)) {
                DB_ERROR ("PasteVendor %s: is pasting itself!!!", current_cfg);
                doit = 0;
            }
            if (doit) {
                if (!cfg->comment && (*o)->comment)
                    cfg->comment = strdup ((*o)->comment);
                success = CopyVendor (walk, *o);
                v->use = 0;
            }
            if (!success) {
                *prev = walk->next;
                delete walk;
                walk = *prev;
            }
            delete v;
        }
        else {
            prev = &(walk->next);
            walk = walk->next;
        }
    }
}



/**
 * Counts gdi, problematic and supported configs of printer.
 * @param walk list of Useconfigs
 * @param gdi gdi printers
 * @param ok supported printers
 * @param probl problematic printers
 */
void is_supported (List*walk,int&gdi,int&ok,int&probl)
{
    if (!walk)
	return ;
    while (walk) {
	Useconfig*c = (Useconfig*)walk->data;
	if (c->use->type) {
	    // options
	    if (c->use->param && *(c->use->param) || c->use->use) {
		if (c->queue)
		    ok++;
		else
		    probl++;
	    }
	    else
		gdi++;
	}
	else {
	    is_supported (c->use->use,gdi,ok,probl);
	}
	walk = walk->next;
    }
}

/**
 * Counts configurations. if there is at least one supported or problematic
 * configuration, returns true. Otherwise false.
 * @param p printer
 * @return is printer supported (0) problematic (1) or unsupported/gdi (2)
 */
int is_supported (Printer*p)
{
    int gdi = 0;
    int probl = 0;
    int ok = 0;
    List*walk = p->use;
    if (!walk) // empty printer list
	return 2;
    is_supported (walk, gdi, ok, probl);
    if (ok)
	return 0;
    if (probl)
	return 1;
    return 2;
}

using namespace std;

string removeBlanks (string arg)
{
    string res = "";
    for (string::iterator i = arg.begin ();i != arg.end (); i++)
    if (*i != ' ' && *i != '-' && *i != '.' && *i != '/')
	res = res + (char)tolower (*i);
    return res;
}
const Main*detectVendorStruct (const char*ieee)
{
    string fixed = removeBlanks (string (ieee));
    Main*use = 0;
    List*walk = mains;
    while (walk) {
	Main*m = (Main*)walk->data;
	if (m->ieee && !strcasecmp (fixed.c_str(), removeBlanks (string (m->ieee)).c_str())) {
	    use = m;
	    break;
	}
	walk = walk->next;
    }
    return use;
}
const char*detectVendor (const char*ieee)
{
    const Main*use = detectVendorStruct (ieee);
    if (use && use->use) {
	Vendor**v = (Vendor**)findinset (vendorset, vendorsize, use->use);
	return v ? (*v)->ident : 0;
    }
    return 0;
}
const Useprinter*detectModelStruct (const char*vendor,const char*ieee)
{
    string fixed = removeBlanks (string (ieee));
    Vendor**v = (Vendor**)findinset (vendorset, vendorsize, (char*)vendor);
    if (!v)
	return 0;
    List*walk = (*v)->use;
    while (walk) {
	Useprinter*m = (Useprinter*)walk->data;
	if (m->ieee && !strcasecmp (fixed.c_str(), removeBlanks (string (m->ieee)).c_str()))
	    return m;
	walk = walk->next;
    }
    return 0;
}
const char*detectModel (const char*vendor,const char*ieee)
{
    const Useprinter*use = detectModelStruct (vendor, ieee);
    return use && use->ident ? use->ident : 0;
}


void getnames (char**vv, char**mm, char**cc, char*v_ieee, char*m_ieee)
{
    char*ven = NULL;
    char*mod = NULL;
    char*con = NULL;

    if (vv) {
	ven = *vv;
	*vv = 0;
    }
    if (mm) {
	mod = *mm;
	*mm = 0;
    }
    if (cc) {
	con = *cc;
	*cc = 0;
    }

    if (!ven || !*ven)	return;
    // find vendor
    List*walk = mains;
    List*best = 0;
    while (walk) {
	if (!strcmp (((Main*)walk->data)->use, ven)) {
	    if (!best)
		best = walk;
	    if (v_ieee && ((Main*)walk->data)->ieee && !strcasecmp (((Main*)walk->data)->ieee, v_ieee)) {
		best = walk;
		break;
	    }
	}
	walk = walk->next;
    }
    if (!best)
	return;
    walk = best;

    Main*m = (Main*)walk->data;
    // we have a vendor
    if (vv)
	*vv = m->text;
    if (!mod || !*mod)	return;
    Vendor**v = (Vendor**)findinset (vendorset, vendorsize, ven);
    if (!v)
	return;
    walk = (*v)->use;
    best = 0;
    while (walk) {
	if (!strcmp (((Useprinter*)walk->data)->ident, mod)) {
	    if (!best)
		best = walk;
	    if (m_ieee && ((Useprinter*)walk->data)->ieee && !strcasecmp (((Useprinter*)walk->data)->ieee, m_ieee)) {
		best = walk;
		break;
	    }
	}
	walk = walk->next;
    }
    if (!best)
	return ;
    walk = best;
    // we have a model
    if (mm)
	*mm = ((Useprinter*)walk->data)->text;
    if (!con || !*con)
	return;
    Printer*p = ((Useprinter*)walk->data)->use;
    List*cl = getconfigs (p->use);
    walk = cl;
    while (walk) {
	if (!strcmp (((Useconfig*)walk->data)->ident,con))
	    break;
	walk = walk->next;
    }
    if (walk && cc) {
	*cc = ((Useconfig*)walk->data)->text;
    }
    walk = cl;
    while (walk) {
	cl = walk;
	walk = walk->next;
	delete cl;
    }
}
static List*getsubtreeoptions (List*use, List*append);
static List*getoptions (List*use, List*append)
{
    List*new_list = append;
    while (use) {
	new_list = getsubtreeoptions (use, new_list);
	use = use->next;
    }
    return new_list;
}
static List*getsubtreeoptions (List*use, List*append)
{
    List*new_list = new List;
    new_list->data = use->data;
    new_list->next = append;
    Option*o = ((Useoption*)use->data)->use;
    if (o && !o->type) {
	List*vals = o->vals;
	while (vals) {
	    Value*v = (Value*)vals->data;
	    if (v->use)
		new_list = getoptions (v->use, new_list);
	    vals = vals->next;
	}
    }
    return new_list;
}

static void check_config_conflicts (char*config_name, List*use)
{
    if (use->next) {
	// check first branch with the rest
	List*first = getsubtreeoptions (use, 0);
	List*rest = getoptions (use->next, 0);
	List*i = first;
	while (i) {
	    List*j = rest;
	    while (j) {
		if (!strcmp (((Useoption*)i->data)->as,((Useoption*)j->data)->as ))
		    DB_ERROR ("%s: Conflict in UseOption identifiers %s", config_name, ((Useoption*)i->data)->as);
		j = j->next;
	    }
	    i = i->next;
	}
	while (first) {
	    List*cache = first->next;
	    delete first;
	    first = cache;
	}
	while (rest) {
	    List*cache = rest->next;
	    delete rest;
	    rest = cache;
	}
	check_config_conflicts (config_name, use->next);
    }
    // check 1st subtree
    Useoption*uo = (Useoption*)use->data;
    if (!uo->use->type && uo->use->vals) {
	List*vals = uo->use->vals;
	while (vals) {
	    if (((Value*)vals->data)->use)
		check_config_conflicts (config_name, ((Value*)vals->data)->use);
	    vals = vals->next;
	}
    }	
}

/**
 * Check if there are some conflicts in option names
 * in any config.
 */
void check_deep_conflicts ()
{
    List*walk = configs;
    while (walk) {
	Config*c = (Config*)walk->data;
	if (c->type && c->use)
	    check_config_conflicts (c->ident, c->use);
	walk = walk->next;
    }
}
