/**
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Printerdb agent implementation
 *
 * Authors:
 *   Petr Blahos <pblahos@suse.cz>
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

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

#define _(X)	dgettext (DB_TEXTDOMAIN, X)
#define __(X)	dgettext (PRG_TEXTDOMAIN, X)
extern int yylineno;

/**
 * Constructor
 */
PrinterdbAgent::PrinterdbAgent() : SCRAgent()
{
    bindtextdomain (DB_TEXTDOMAIN, "/usr/lib/YaST2/locale");
    bind_textdomain_codeset (DB_TEXTDOMAIN, "UTF-8");
    bindtextdomain (PRG_TEXTDOMAIN, "/usr/lib/YaST2/locale");
    bind_textdomain_codeset (PRG_TEXTDOMAIN, "UTF-8");
    db_up = false;
}

/**
 * Destructor
 */
PrinterdbAgent::~PrinterdbAgent()
{
    if (db_up){
	spdbFree ();
	db_up = false;
    }
}

/**
 * Dir
 */
YCPValue PrinterdbAgent::Dir(const YCPPath& path)
{
    return YCPVoid();
}

YCPMap getAllValueItems (ValueItem *item)
{
    YCPMap m;
    while (item)
    {
	m->add (item->type ? YCPString (item->type) : YCPString (""), item->val ? YCPString (item->val) : YCPString (""));
	item = item->next;
    }
    return m;
}

YCPValue PrinterdbAgent::getValuesList (List*vl)
{
    YCPList l;
    while (vl) {
	Value*v = (Value*)vl->data;
	YCPMap m;
	m->add (YCPString ("text"), YCPString (_(v->text)));
	m->add (YCPString ("val"), getAllValueItems(v->items));//v->items->val ? YCPString (v->items->val) : YCPString (""));
	if (v->use)
	    m->add (YCPString ("sub"), getOptionTree (v->use));
	l->add (m);
	vl = vl->next;
    }
    return l;
}
YCPMap PrinterdbAgent::getFirstAutoQueue (Config*c)
{
    YCPMap m;
    if (c->type) {
	m->add (YCPString ("config"), YCPString (c->ident));
    }
    else {
	List*walk = c->use;
	while (walk) {
	    Useconfig*c = (Useconfig*)walk->data;
	    if (c->queue) {
		m = getFirstAutoQueue (c->use);
		if (m->size ())
		    break;
	    }
	    walk = walk->next;
	}
    }
    return m;
}
YCPList PrinterdbAgent::getAutoQueues (List*cfgs)
{
    YCPList aq;
    List*walk = cfgs;
    while (walk) {
	Useconfig*c = (Useconfig*)walk->data;
	if (c->queue) {
	    YCPMap m = getFirstAutoQueue (c->use);
	    m->add (YCPString ("name"), YCPString (c->queue));
	    m->add (YCPString ("comment"), YCPString (_(c->text)));
	    aq->add (m);
	}
	walk = walk->next;
    }
    return aq;
}
/**
 * Returns tree of options (list of lists).
 * @param  opts List of Useoptions
 * @return List of options (for YCP UI Selection)
 */
YCPList PrinterdbAgent::getOptionTree (List*opts)
{
    YCPList l;
    List*walk = opts;
    while (walk) {
	Useoption*uo = (Useoption*)walk->data;
	Option*o = uo->use;
	if (o) {
	    YCPMap v;
	    v->add (YCPString ("ident"), YCPString (uo->as));
	    v->add (YCPString ("text"),  YCPString (_(uo->text)));
	    v->add (YCPString ("comment"), o->comment ? YCPString (_(o->comment)) : YCPString (""));
	    switch (o->type) {
	    case 1:
		v->add (YCPString ("int"), numint2ycp (o->numint));
		break;
	    case 2:
		v->add (YCPString ("float"), numfloat2ycp (o->numfloat));
		break;
	    case 3:
		v->add (YCPString ("text"), text2ycp (o->valtext));
		break;
	    default:
		v->add (YCPString ("values"), getValuesList (o->vals));
		break;
	    }
	    l->add (v);
	}
	else {
	    y2error ("Error in use option: %s %s", uo->ident, uo->text);
	}
	walk = walk->next;
    }
    return l;
}
YCPList PrinterdbAgent::getConfigTree (List*cfgs)
{
    YCPList l;
    List*walk = cfgs;
    while (walk) {
	Useconfig*u = (Useconfig*)walk->data;
	Config*c = u->use;
	if (c) {
	    c->queue = u->queue;
	    YCPMap m;
	    m->add (YCPString ("ident"), YCPString (u->ident));
	    m->add (YCPString ("comment"), c->comment ? YCPString (_(c->comment)) : YCPString (""));
	    m->add (YCPString ("text"), YCPString (_(u->text)));
	    m->add (YCPString ("queue"), u->queue ? YCPString (u->queue) : YCPString (""));
	    if (!c->type)
		m->add (YCPString ("sub"), getConfigTree (c->use));
	    l->add (m);
	}
	walk = walk->next;
    }
    return l;
}
string PrinterdbAgent::getSupportPrefix (Config *c)
{
    string text = "";
    YCPMap m = YCPMap ();
    int flags = 0;
    bool cups = (getConfFile (c->use, m, flags, "ppd:file").length() > 0);
    bool lprng = (getConfFile (c->use, m, flags, "file:upp:device").length() > 0);
    if (cups && !lprng) text = string (__(CUPS_ONLY_STRING)) + " " + text;
    else if (!cups && lprng) text = string (__(LPRNG_ONLY_STRING)) + " " + text;
    else if (!cups && !lprng) text = string (__(NOT_AVAILABLE_STRING)) + " " + text;
    return text;
}
bool PrinterdbAgent::isSupported(Config *c, string spooler)
{
    YCPMap m = YCPMap ();
    int flags = 0;
    if (spooler == "cups")
	return getConfFile (c->use, m, flags, "ppd:file").length();
    if (spooler == "lprng")
	getConfFile (c->use, m, flags, "file:upp:device").length();
    return true;
}
string PrinterdbAgent::getConfigRichText (List*cfgs, string spooler)
{
    string s ("");
    List*walk = cfgs;
    while (walk) {
	Useconfig*u = (Useconfig*)walk->data;
	Config*c = u->use;
	if (c) {
	    c->queue = u->queue;
	    if (c->type) {
		string text = string (_(u->text));
		text = getSupportPrefix (c) + text;
		if (isSupported (c, spooler))
		    s = s + "<b><a href=\"" + u->ident + "\">" + text + "</a></b><br>";
		else
		    s = s + "<b>" + text + "</b><br>";
		if (c->comment) {
		    s = s + "<ul>" + c->comment + "</ul>";
		}
	    }
	    else {
		s = s + "<big><b>" + _(u->text) + "</b></big><br>";
		if (c->comment)
		    s = s + "<ul>" + c->comment + "</ul>";
		s = s + "<ul>" + getConfigRichText (c->use, spooler) + "</ul>";
	    }
	}
	walk = walk->next;
    }
    return s;
}
void PrinterdbAgent::getConfigCombo (List*cfgs, YCPList&l, string pre)
{
    List*walk = cfgs;
    while (walk) {
	Useconfig*u = (Useconfig*)walk->data;
	Config*c = u->use;
	if (c) {
	    c->queue = u->queue;
	    if (!c->type)
		getConfigCombo (c->use, l, pre + _(u->text) + ": ");
	    else {
		string text = getSupportPrefix (c) + pre;
		YCPTerm t ("item", true);
		YCPTerm id ("id", true);
		id->add (YCPString (u->ident));
		t->add (id);
		t->add (YCPString (text + _(u->text)));
		l->add (t);
	    }
	}
	walk = walk->next;
    }
}

/**
 * Get info about a printer.
 * @param l list of [vendor_ieee, model_ieee]
 * @return list of [ vendor , model ]
 */
YCPValue PrinterdbAgent::Detect (YCPList&l)
{
    if (2 != l->size ())
	return YCPError ("Wrong arguments to .detect");
    if (!l->value (0)->isString () || !l->value (1)->isString ())
	return YCPError ("Expecting list of 2 strings as an argument.");
    string vend = l->value(0)->asString()->value();
    string mod = l->value(1)->asString()->value();
    const char*dm = 0;
    const char*dv = detectVendor (vend.c_str ());
    if (dv)
	dm = detectModel (dv, mod.c_str ());
    YCPList x;
    if (dm && dv)
    {
	x->add (YCPString (dv));
	x->add (YCPString (dm));
    }
    return x;
}
/**
 * Get config nice name.
 * @param l list of [ vendor_id, model_id, config_id ]
 * @return nice name of the config
 */
YCPValue PrinterdbAgent::ConfigName (YCPList&l)
{
    if (3 > l->size ())
	return YCPError ("Wrong arguments to .configname");
    if (!l->value (0)->isString () || !l->value (1)->isString () || !l->value (2)->isString ())
	return YCPError ("Expecting list of 3 strings as an argument.");
    char* vend = (char*)l->value(0)->asString()->value().c_str();
    char* mod = (char*)l->value(1)->asString()->value().c_str();
    char* con = (char*)l->value(2)->asString()->value().c_str();
    getnames (&vend, &mod, &con);
    string out;
    if (con)
	out = _((const char*)con);
    return YCPString (out);
}
/**
 * Get printer nice name.
 * @param l list of [ vendor_id, model_id ]
 * @return nice name of the printer
 */
YCPValue PrinterdbAgent::PrinterName (YCPList&l)
{
    if (2 > l->size ())
	return YCPError ("Wrong arguments to .printername");
    if (!l->value (0)->isString () || !l->value (1)->isString ())
	return YCPError ("Expecting list of 2 strings as an argument.");
    char* vend = (char*)l->value(0)->asString()->value().c_str();
    char* mod = (char*)l->value(1)->asString()->value().c_str();
    char*v_ieee = 0;
    char*m_ieee = 0;
    if (l->size () > 2 && l->value (2)->isString ())
	v_ieee = (char*)l->value (2)->asString ()->value ().c_str();
    if (l->size () > 3 && l->value (3)->isString ())
	m_ieee = (char*)l->value (3)->asString ()->value ().c_str();
    getnames (&vend, &mod, 0, v_ieee, m_ieee);
    string out;
    if (vend) {
	out = _((const char*)vend);
	out = out + ": ";
    }
    if (mod) 
	out = out + _((const char*)mod);
    return YCPString (out);
}
/**
 * get list of vendors
 */
YCPList PrinterdbAgent::Vendors (string&preselect, string&pre_ieee)
{
    int preselected = 0;
    List*walk = mains;
    YCPList l;
    if (!walk)
	return l;
    while (walk) {
	//
	// Build structure to return to caller
	//
	YCPTerm t ("item", true);
	YCPTerm id ("id", true);
	YCPList idlist;
	idlist->add (YCPString (((Main*)walk->data)->use));
	idlist->add (((Main*)walk->data)->ieee ? YCPString (((Main*)walk->data)->ieee) : YCPString (""));
	id->add (idlist);
	t->add (id);
	t->add (YCPString (_(((Main*)walk->data)->text)));
	if (2 != preselected && preselect == ((Main*)walk->data)->use) {
	    t->add (YCPBoolean (true));
	    preselected = ((Main*)walk->data)->ieee && pre_ieee == ((Main*)walk->data)->ieee ? 2 : 1;
	}
	l->add (t);
	walk = walk->next;
    }
    if (!preselected) {
	YCPValue v = l->value (0);
	if (v->isTerm()) 
	    v->asTerm ()->add (YCPBoolean (true));
	l->remove (0);
	l = l->functionalAdd (v, true);
    }
    return l;
}
/**
 * Read
 */
YCPValue PrinterdbAgent::Read(const YCPPath &path, const YCPValue& arg)
{
    /**
     * @builtin Read (.deep_check) --> Boolean
     * Checks if there are conflicts between options identifiers used in
     * config. See description of keyword <tt>As</tt> for explanation.
     */
    if (path->component_str (0) == "deep_check") {
	check_deep_conflicts ();
	return YCPBoolean (true);
    }
    if (path->component_str (0) == "detect" && !arg.isNull () && arg->isList ()) {
	/**
	 * @builtin Read (.detect, [ "ieee_vendor", "ieee_model" ]) -> [ "vendor_id", "model_id" ]
	 * Tries to detect vendor, model pair.
	 */
	YCPList l = arg->asList ();
	return Detect (l); 
    }
    if (path->component_str (0) == "printername" && !arg.isNull () && arg->isList ()) {
	/**
	 * @builtin Read (.printername, [ "vendor_id", "model_id", "vendor_ieee", "model_ieee" ]) -> "Vendor Text Model Text"
	 * Get vendor and printer name.
	 */
	YCPList l = arg->asList ();
	return PrinterName (l);
    }
    if (path->component_str (0) == "configname" && !arg.isNull () && arg->isList ()) {
	/**
	 * @builtin Read (.configname, [ "vendor_id", "model_id", "config_id" ]) -> "Config Text"
	 * Get config name.
	 */
	YCPList l = arg->asList ();
	return ConfigName (l);
    }

    if (path->component_str(0) == "vendors") {
	/**
	 * @builtin Read (.vendors) -> list of items -- vendors
	 * Read (.vendors, [ "preselect_id", "preselect_ieee" ]) -> list of items -- vendors
	 * list of vendor names, if preselect is specified and found
	 * between vendor identifiers, the item is selected. Otherwise
	 * first item is selected.<br>
	 * Example of an item:
	 * @example Item: `item (`id (["vendor_id", "vendor_ieee"]), "Vendor Text");
	 */
	string preselect = "";
	string preselect_ieee = "";
	if (!arg.isNull () && arg->isList()) {
	    if (arg->asList ()->size () > 0 && arg->asList ()->value (0)->isString())
		preselect = arg->asList ()->value (0) ->asString ()->value_cstr ();
	    if (arg->asList ()->size () > 1 && arg->asList ()->value (1)->isString())
		preselect_ieee = arg->asList ()->value (1) ->asString ()->value_cstr ();
	}
	return Vendors (preselect, preselect_ieee);
    }
    else if (path->component_str(0) == "configinfo" && !arg.isNull () && arg->isString ()) {
	/**
	 * @builtin Read (.configinfo, "config_id") -> map
	 * Info whether config is gdi or supported or problematic. Get config comment.
	 * <pre>
	 * $[
	 * <dd> "gdi" : boolean,
	 * <dd> "supported" : boolean,
	 * <dd> "comment" : string,
	 * <dd> "lprng" : boolean,
	 * <dd> "cups" : boolean
	 * ];</pre>
	 */
	bool gdi = true;
	bool supported = false;
	YCPMap info;
	Config**c = (Config**)findinset (configset, configsize, (char*)arg->asString ()->value_cstr ());
	if (!c)
	    return YCPError (arg->asString ()->value () + ": config not found.");
	if (!(*c)->type)
	    return YCPError (arg->asString ()->value () + ": only leaf-configs are allowed here.");
	// supported?
	if ((*c)->param && *((*c)->param) || (*c)->use) {
	    gdi = false;
	}
	if ((*c)->queue) {
	    supported = true;
	    info->add (YCPString ("queue"), YCPString ((*c)->queue));
	}
	if (gdi && supported)
	{
	    supported = false;
	    y2error ("%s: Queue is supported and gdi.", (*c)->ident);
	}
	info->add (YCPString ("gdi"), YCPBoolean (gdi));
	info->add (YCPString ("supported"), YCPBoolean (supported));
	if ((*c)->comment)
	    info->add (YCPString ("comment"), YCPString (_((*c)->comment)));
	YCPMap m = YCPMap();
	int flags = 0;
	info->add (YCPString("cups"), YCPBoolean(getConfFile ((*c)->use, m, flags, "ppd:file").length() > 0));
	info->add (YCPString("lprng"), YCPBoolean(getConfFile ((*c)->use, m, flags, "file:upp:device").length() > 0));
	return info;
    }
    else if (path->component_str(0) == "info" && arg->isList ()) {
	/**
	 * @builtin Read (.info, [ "vendorid", "modelid" ]) -> map
	 * Info about printer: is printer supported/problematic/gdi?
	 * Printer comment, vendor comment, sometimes config comment.
	 * <pre>$[
	 * <dd> "vendor" : "vendor comment",
	 * <dd> "printer" : "printer comment",
	 * <dd> "type" : [0|1|2], // 0 -- supported, 1 -- problematic, 2 -- gdi
	 * <dd> "config" : "first config comment", // only for problematic | gdi printers
	 * ]</pre>
	 */
	YCPMap info;
	YCPList l = arg->asList ();
	if (l->size() != 2) {
	    return YCPError ("Expecting [ vendor, model ] as an argument");
	}
	if (!l->value(0)->isString () || !l->value(1)->isString ()) {
	    return YCPError ("Expecting [ vendor, model ] as an argument");
	}
	Vendor**v = (Vendor**)findinset (vendorset, vendorsize, (char*)l->value(0)->asString()->value_cstr ());
	Printer**m = (Printer**)findinset (printerset, printersize, (char*)l->value(1)->asString()->value_cstr ());
	if (v) {
	    if ((*v)->comment)
		info->add (YCPString ("vendor"), YCPString (_((*v)->comment)));
	}
	else
	    y2error ("Vendor %s not found.", l->value(0)->asString()->value_cstr ());
	if (m) {
	    if ((*m)->comment) // if there is a printer comment, take it.
		info->add (YCPString ("printer"), YCPString (_((*m)->comment)));
	    // is there the only one gdi printer?
	    int sup = is_supported (*m);
	    info->add (YCPString ("type"), YCPInteger (sup));
	    if (2 == sup) {
		if ((*m)->use) {
		    Useconfig*c = (Useconfig*)((*m)->use->data);
		    if (c->use->comment)
			info->add (YCPString ("config"), YCPString (_(c->use->comment)));
		}
	    }
	    else
		info->add (YCPString ("supported"), YCPBoolean (true));
	}
	else
	    y2error ("Printer %s not found.", l->value(1)->asString()->value_cstr ());
	return info;
    }
    else if (path->length () == 2 && path->component_str(0) == "models") {
	/**
	 * @builtin Read (.models.VENDOR) -> list of models
	 * @builtin Read (.models.VENDOR, [ "model_id", "ieee" ]) -> list of models for selection box
	 * May preselect model_id or first item. Example of item:
	 * @example Item: `item (`id (["model_id", "model_ieee"]), "Model text");
	 */
	string ident = path->component_str (1);
	string preselect = "";
	string preselect_ieee = "";
	int preselected = 0;
	if (!arg.isNull () && arg->isList()) {
	    if (arg->asList ()->size () > 0 && arg->asList ()->value (0)->isString())
		preselect = arg->asList ()->value (0) ->asString ()->value_cstr ();
	    if (arg->asList ()->size () > 1 && arg->asList ()->value (1)->isString())
		preselect_ieee = arg->asList ()->value (1) ->asString ()->value_cstr ();
	}
	Vendor**v = (Vendor**)findinset (vendorset, vendorsize, (char*)ident.c_str ());
	YCPList l;
	if (NULL == v)
	    return YCPError (ident + ":Vendor not found.", l);
	List*walk = (*v)->use;
	if (!walk)
	    return l;
	while (walk) {
	    Useprinter*p = (Useprinter*)walk->data;
	    YCPTerm t ("item", true);
	    YCPTerm id ("id", true);
	    YCPList idlist;
	    idlist->add (YCPString (p->ident));
	    idlist->add (p->ieee ? YCPString (p->ieee) : YCPString (""));
	    id->add (idlist);
	    t->add (id);
	    t->add (YCPString (_(p->text)));
	    if (2 != preselected && preselect == p->ident) {
		t->add (YCPBoolean (true));
		preselected = p->ieee && preselect_ieee == p->ieee ? 2 : 1;
	    }
	    l->add (t);
	    walk = walk->next;
	}
	if (!preselected) {
	    YCPValue v = l->value (0);
	    if (v->isTerm())
		v->asTerm ()->add (YCPBoolean (true));
	    l->remove (0);
	    l = l->functionalAdd (v, true);
	}
	return l;
    }
    else if (path->length () == 1 && path->component_str (0) == "configs" && !arg.isNull () && arg->isString ()) {
	string ident = arg->asString ()->value ();
	Printer**p = (Printer**)findinset (printerset, printersize, (char*)ident.c_str());
	YCPList l;
	if (!p)
	    return YCPError (ident + ":Config not found.", l);
	List *cfgs = ((*p)->use);
	List*walk = cfgs;
        while (walk) {
            Useconfig*u = (Useconfig*)walk->data;
            Config*c = u->use;
            if (c) {
                c->queue = u->queue;
                if (c->type)
                {
                    l->add (YCPString (u->ident));
                }
            }
            walk = walk->next;
        }
	return l;
    }
    else if (path->length () == 2 && path->component_str (0) == "configstree") {
	/**
	 * @builtin Read (.configstree.PRINTER) -> list
	 * Tree of all configurations of printer. List of maps:<pre>
	 * $[
	 * <dd> "ident" : string
	 * <dd> "comment" : string
	 * <dd> "text" : string
	 * <dd> "queue" : string
	 * <dd> "sub" : list of subconfigs
	 * ]</pre>
	 */
	string ident = path->component_str (1);
	Printer**p = (Printer**)findinset (printerset, printersize, (char*)ident.c_str());
	YCPList l;
	if (!p)
	    return YCPError (ident + ": Printer not found.", l);
	l = getConfigTree((*p)->use);
	return l;
    }
    else if (path->length () == 1 && path->component_str (0) == "auto" && !arg.isNull () && arg->isString ()) {
	/**
	 * @builtin Read (.auto, "printer_id") -> map
	 * Get queues that will be auto-installed. <pre>
	 * [
	 * $[
	 * <dd>  "config" : "config_id",
	 * <dd>  "name" : "queuename",
	 * <dd>  "comment" : "nicename",
	 * <dd>]
	 * ]</pre>
	 */
	string ident = arg->asString ()->value ();
	Printer**p = (Printer**)findinset (printerset, printersize, (char*)ident.c_str());
	YCPMap m;
	if (!p)
	    return YCPError (ident + ": Printer not found.", m);
	return getAutoQueues ((*p)->use);
    }
    else if (path->length () == 2 && path->component_str (0) == "configsrt") {
	/**
	 * @builtin Read (.configsrt.PRINTER) -> list
	 * Get configurations for PRINTER. Returns rich text contents
	 * as first item of the list, contents of config menu in 2nd
	 * item and contents of combo box in 3rd.
	 */
	string ident = path->component_str (1);
	string spooler = arg->asString ()->value_cstr();
	Printer**p = (Printer**)findinset (printerset, printersize, (char*)ident.c_str());
	YCPList l;
	if (!p)
	    return YCPError (ident + ":Config not found.", l);
	string s = getConfigRichText ((*p)->use, spooler);
	YCPList ret;
	ret->add (YCPString (s));
	l = YCPList ();
	getConfigCombo ((*p)->use, l, "");
	ret->add (l);
	return ret;
    }
    else if (path->length () == 2 && path->component_str (0) == "optionstree") {
	/**
	 * @builtin Read (.optionstree.CONFIG) -> list
	 * Get tree of options. List of maps.
	 */
	string ident = path->component_str (1);
	Config**c = (Config**)findinset (configset, configsize, (char*)ident.c_str());
	YCPList l;
	if (!c)
	    return YCPError (ident + ":Config not found.", l);
	if (!(*c)->type)
	    return YCPError (ident + ":Config has subconfigs, not suboptions!", l);
	l = getOptionTree((*c)->use);
	return l;
    }
    else if (path->length () >= 2 && path->component_str (0) == "options") {
	/**
	 * @builtin Read (.options.CONFIG.OPTION, map preset) -> list
	 * OPTION and preset are optional.<br>
	 * Get item list for options of config CONFIG. Preselects item
	 * OPTION if exists. Presets values from map preset.
	 */
	string ident = path->component_str (1);
	string preselect = "";
	if (path->length () > 2)
	    preselect = path->component_str (2);
	Config**c = (Config**)findinset (configset, configsize, (char*)ident.c_str());
	if (!c)
	    return YCPError (ident + ":Config not found.", YCPList ());
	if (!(*c)->type)
	    return YCPError (ident + ":Config has subconfigs, not suboptions!", YCPList ());
	YCPMap m;
	if (!arg.isNull () && arg->isMap ())
	    m = arg->asMap ();
	YCPList l = getOptionItems ((*c)->use, m, "", preselect.c_str());
	return l;
    }
    else if (path->length () == 2 && path->component_str (0) == "option_comment") {
	string ident = path->component_str (1);
	Option**o = (Option**)findinset (optionset, optionsize, (char*)ident.c_str());
	if (o && (*o)->comment && *((*o)->comment))
	    return YCPString (_((*o)->comment));
	return YCPString ("");
    }
    else if (path->length () == 2 && path->component_str (0) == "values") {
	/**
	 * @builtin Read (.values.OPTION) -> list
	 * Get option. For numerical option it returns:<pre>
	 * `int (low, high, step, defautl, preset)
	 * `float (low, high, step, default, preset)</pre>
	 * where default and preset may be nil, in that cases value
	 * is use driver default. For enumerated options it returns
	 * list of items <tt> `item (`id (index), "Text")</tt>
	 */
	string ident = path->component_str (1);
	YCPValue a = YCPVoid ();
	if (!arg.isNull ())
	    a = arg;
	return Values (ident.c_str(), a);
    }
/*    else if (path->component_str (0) == "isppd" && !arg.isNull () && arg->isString ()) {
	return isPpd (arg->asString()->value_cstr ());
    }
    else if (path->component_str (0) == "ppdinfo" && !arg.isNull () && arg->isString ()) {
	return ppdInfo (arg->asString()->value_cstr ());
    }*/

    y2error("Wrong path '%s' in Read().", path->toString().c_str());
    return YCPVoid();
}
YCPValue PrinterdbAgent::Values (const char*ident, YCPValue&arg)
{
    Option**o = (Option**)findinset (optionset, optionsize, (char*)ident);
    if (!o)
	return YCPError (string (ident) + ": Option not found.", YCPList ());
    switch ((*o)->type){
    case 1:
	{
	    YCPTerm t ("int", true);
	    t->add (YCPInteger ((*o)->numint->lo));
	    t->add (YCPInteger ((*o)->numint->hi));
	    t->add (YCPInteger ((*o)->numint->step));
	    if ((*o)->numint->flags & NUMOPT_NODEF)
		t->add (YCPVoid ());
	    else
		t->add (YCPInteger ((*o)->numint->def));
	    if (arg->isInteger ())
		t->add (arg->asInteger());
	    else
		t->add (YCPVoid ());
	    return t;
	}
    case 2:
	{
	    YCPTerm t ("float", true);
	    t->add (YCPFloat ((*o)->numfloat->lo));
	    t->add (YCPFloat ((*o)->numfloat->hi));
	    t->add (YCPFloat ((*o)->numfloat->step));
	    if ((*o)->numfloat->flags & NUMOPT_NODEF)
		t->add (YCPVoid ());
	    else
		t->add (YCPFloat ((*o)->numfloat->def));
	    if (arg->isFloat ())
		t->add (arg->asFloat ());
	    else
		t->add (YCPVoid ());
	    return t;
	}
    case 3:
	{
	    YCPTerm t ("text", true);
	    t->add (YCPString ((*o)->valtext->chars));
	    if (arg->isString ())
		t->add (arg->asString ());
	    else
		t->add (YCPString (""));
	    return t;
	}
    default:
	{
	    int preselect = -1;
	    bool preselected = false;
	    if (arg->isInteger ())
		preselect = arg->asInteger()->value ();
	    YCPList l;
	    int i = 0;
	    List*walk = (*o)->vals;
	    while (walk) {
		YCPTerm t ("item", true);
		YCPTerm id ("id", true);
		id->add (YCPInteger (i));
		t->add (id);
		t->add (YCPString (_(((Value*)walk->data)->text)));
		if (preselect == i) {
		    preselected = true;
		    t->add (YCPBoolean (true));
		}
		l->add (t);
		i++;
		walk = walk->next;
	    }
	    if (!preselected) {
		YCPValue v = l->value (0);
		if (v->isTerm())
		    v->asTerm ()->add (YCPBoolean (true));
		l->remove (0);
		l = l->functionalAdd (v, true);
	    }
	    return l;
	}
    }
}
/*YCPBoolean PrinterdbAgent::isPpd (const char* filename)
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
YCPMap PrinterdbAgent::ppdInfo (const char *filename)
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
}*/
string PrinterdbAgent::getOptions (List*u, YCPMap&selected)
{
    char buf[200];
    string s ("");
    List*walk = u;
    while (walk) {
	Useoption*uo = (Useoption*)walk->data;
	Option*o = uo->use;
	if (o) {
	    YCPValue v = selected->value (YCPString (uo->as));
	    *buf = 0;

	    switch (o->type) {
	    case 1:
		{
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isInteger ())
			    snprintf (buf, 199, "(%s: %d) mm\n", _(uo->text), (int)v->asInteger()->value());
		    }
		    else {
			if (!(o->numint->flags & NUMOPT_NODEF))
			    snprintf (buf, 199, "(%s: %d) mm\n", _(uo->text), (int)o->numint->def);
		    }
		    if (*buf)
			s = s + buf;
		}
		break;
	    case 2:
		{
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isFloat ())
			    snprintf (buf, 199, "(%s: %f) mm\n", _(uo->text), v->asFloat()->value());
		    }
		    else {
			if (!(o->numfloat->flags & NUMOPT_NODEF))
			    snprintf (buf, 199, "(%s: %f) mm\n", _(uo->text), o->numfloat->def);
		    }
		    if (*buf)
			s = s + buf;
		}
		break;
	    case 3:
		{
		    if (!v.isNull () && v->isString ()) {
			snprintf (buf, 199, "(%s: %s) mm\n", _(uo->text), v->asString ()->value_cstr ());
			s = s + buf;
		    }
		}
		break;
	    default:
		{
		    int sel = 0;
		    if (!v.isNull() && v->isInteger ())
			sel = v->asInteger()->value();
		    List*vall = o->vals;
		    while (sel-- > 0 && vall)
			vall = vall->next;
		    if (-1 != sel || !vall)
			vall = o->vals;
		    Value*val = (Value*)vall->data;
		    if (val) {
			s = s + "(" + _(uo->text) + ": " + _(val->text) + ") mm\n";
		    }
		    if (val->use)
			s = s + getOptions (val->use, selected);
		}
		break;
	    }
	}
	else
	    y2error ("Error in use option: %s %s", uo->ident, uo->text);
	walk = walk->next;
    }
    return s;
}
YCPList PrinterdbAgent::getOptionItems (List*u, YCPMap&selected, string indent, const char*preselect)
{
    bool preselected = false;
    YCPList l;
    List*walk = u;
    while (walk) {
	Useoption*uo = (Useoption*)walk->data;
	Option*o = uo->use;
	if (o) {
	    YCPList idx;
	    YCPList childern;
	    YCPValue v = selected->value (YCPString (uo->as));
	    YCPTerm id ("id", true);
	    YCPTerm t ("item", true);
	    idx->add (YCPString (uo->as));
	    idx->add (YCPString (o->ident));
	    id->add (idx);
	    t->add (id);
	    string text = indent + _(uo->text);

	    switch (o->type) {
	    case 1:
		{
		    char buf[50];
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isInteger ())
			    snprintf (buf, 49, ": %d", (int)v->asInteger()->value());
			else
			    snprintf (buf, 49, ": %s", __(NOT_USED_STRING));
		    }
		    else {
			if (o->numint->flags & NUMOPT_NODEF)
			    snprintf (buf, 49, ": %s", __(NOT_USED_STRING));
			else
			    snprintf (buf, 49, ": %d", (int)o->numint->def);
		    }
		    text = text + buf;
		}
		break;
	    case 2:
		{
		    char buf[50];
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isFloat ())
			    snprintf (buf, 49, ": %f", v->asFloat()->value());
			else
			    snprintf (buf, 49, ": %s", __(NOT_USED_STRING));
		    }
		    else {
			if (o->numfloat->flags & NUMOPT_NODEF)
			    snprintf (buf, 49, ": %s", __(NOT_USED_STRING));
			else
			    snprintf (buf, 49, ": %f", o->numfloat->def);
		    }
		    text = text + buf;
		}
		break;
	    case 3:
		{
		    char buf[50];
		    if (!v.isNull () && v->isString ()) {
			snprintf (buf, 49, ": %s", v->asString()->value_cstr());
		    }
		    else
			*buf = 0;
		    text = text + buf;
		}
		break;
	    default:
		{
		    int sel = 0;
		    if (!v.isNull() && v->isInteger ())
			sel = v->asInteger()->value();
		    List*vall = o->vals;
		    while (sel-- > 0 && vall) {
			vall = vall->next;
		    }
		    if (-1 != sel || !vall)
			vall = o->vals;
		    // val is default.
		    Value*val = (Value*)vall->data;
		    text = text + ": ";
		    text = text + _(val->text);
		    if (val->use)
			childern = getOptionItems (val->use, selected, indent + "    ", preselect);
		}
		break;
	    }
	    t->add (YCPString (text));
	    if (!strcmp (preselect, uo->as)) {
		preselected = true;
		t->add (YCPBoolean (true));
	    }
	    if ((!preselect || !*preselect) && !preselected && indent == "") {
		preselected = true;
		t->add (YCPBoolean (true));
	    }
	    l->add (t);
	    {
		int len = childern->size ();
		for (int i = 0;i<len;i++)
		    l->add (childern->value (i));
	    }
	}
	else
	    y2error ("Error in use option: %s %s", uo->ident, uo->text);
	walk = walk->next;
    }
    return l;
}

/**
 * Write
 */
YCPValue PrinterdbAgent::Write (const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
    if (2 == path->length () && path->component_str (0) == "gettext" && value->isString ()) {
	/**
	 * @builtin Write (.gettext, filename) -> nil
	 * Writes all translatable strings into file filename. Prepends
	 * comment // xgettext: no-c-string before each message that
	 * contains %.
	 */
	return WriteTransStrings (value->asString()->value_cstr (), path->component_str (1).c_str ());
    }
    if (1 == path->length () && path->component_str (0) == "testscript" && value->isString ()) {
	/**
	 * @builtin Write (.testscript, filename) -> nil
	 * Writes name and parameters of default configuration of each
	 * configuration. Used in test script test_printerdb_params.
	 */
	FILE*f = fopen (value->asString()->value_cstr(), "wt");
	if (NULL == f)
	    return YCPError (string ("Can not open ") + value->asString()->value_cstr());
	List*walk = configs;
	YCPMap m;
	for (;walk;walk = walk->next) {
	    int flags = 0;
	    Config*c = (Config*)walk->data;
	    if (!c->type)
		continue;
	    string s;
	    if (c->param) {
		s = c->param;
		s = s + " ";
	    }
	    if (c->use) {
		s = s + getConfFile (c->use, m, flags, "file:upp");
		for (string::iterator w = s.begin ();w != s.end (); w++)
		    if (*w == '\n')
			*w = ' ';
	    }
	    fprintf (f, "export CONFIG=%s\nPARAMS %s\n", c->ident, s.c_str ());
	}
	fclose (f);
    }
    else if (2 == path->length () && path->component_str (0) == "upp") {
	/**
	 * @builtin Write (.upp.CONFIG, map settings) -> string
	 * Get upp file for CONFIG with settings. FIXME: this should be in
	 * Read IMHO.
	 */
	string cfg = path->component_str (1);
	Config**c = (Config**)findinset (configset, configsize, (char*)cfg.c_str());
	if (!c)
	    return YCPError (cfg + ": config not found.", YCPString (""));
	if (!(*c)->type)
	    return YCPError (cfg + ": only leaf-configs are allowed here.", YCPString (""));
	string s = "";
	if ((*c)->param)
	    s = s + (*c)->param + "\n";
	if ((*c)->use) {
	    YCPMap m;
	    if (!value.isNull () && value->isMap ())
		m = value->asMap ();
	    int flags = 0;
	    s = s + getConfFile ((*c)->use, m, flags, "file:upp");
	}
	return YCPString (s);
    }
    else if (path->length () == 2 && path->component_str (0) == "ppd") {
	/**
         * @builtin Write (.ppd.CONFIG, map settings) -> string
         * Get ppd file for CONFIG with settings. FIXME: this should be in
         * Read IMHO.
         */
        string cfg = path->component_str (1);
        Config**c = (Config**)findinset (configset, configsize, (char*)cfg.c_str());
        if (!c)
            return YCPError (cfg + ": config not found.", YCPString (""));
        if (!(*c)->type)
            return YCPError (cfg + ": only leaf-configs are allowed here.", YCPString (""));
        string s = "";
        if ((*c)->param)
            s = s + (*c)->param + "\n";
        if ((*c)->use) {
            YCPMap m;
            if (!value.isNull () && value->isMap ())
            	m = value->asMap ();
	    int flags = 0;
	    s = s + getConfFile ((*c)->use, m, flags, "ppd:patch");
	    string ppdFilename = getConfFile ((*c)->use, m, flags, "ppd:file");
	    if (ppdFilename == "")
		return YCPError ("PPD file not specified.", YCPString (""));
	    s = getPatchedPpdFile (ppdFilename.c_str(), s);
	    if (s == "")
		return YCPError ("Error while patching PPD file, may be not found", YCPString(""));
	}
	return YCPString (s);
    }
    else if (path->length () >= 4 && path->component_str (0) == "testpg_options"  && value->isString ()) {
	/**
	 * @builtin Write (.testpg_options.vendor.model.config.vendor_label.model_label.encoding, filename, map settings) -> void
	 * Returns options that should be on the test page. Each line is in 
	 * format (text) mm
	 */
	FILE*f = fopen (value->asString()->value_cstr(), "wt");
	if (NULL == f)
	    return YCPError (string ("Can not open ") + value->asString()->value_cstr());
	string cfg = path->component_str (3);
	string enc = "X";
	if (path->length () > 6) {
	    enc = path->component_str (6);
	    int len = enc.length ();
	    for (int i = 0; i< len; i++)
		enc[i] = toupper (enc[i]);
	    if (enc != "ISO-8859-2" && enc != "ASCII" && enc != "ISO-8859-15" && enc != "ISO-8859-1")
		enc = "X";
	}
	Config**c = (Config**)findinset (configset, configsize, (char*)cfg.c_str());
	if (cfg != "")
	{
	    if (!c)
	    	return YCPError (cfg + ": config not found.", YCPString (""));
	    if (!(*c)->type)
	    	return YCPError (cfg + ": only leaf-configs are allowed here.", YCPString (""));
	}
	string s = "";
	//
	// Adjust language. We aren't going to output to ycp but to 8-bit
	// ascii file. If encoding is other than iso-8859-[1|2|15], switch
	// to English.
	//
	char*old_lang = 0;
	if (enc == "X") {
	    extern int _nl_msg_cat_cntr;
	    old_lang = getenv ("LANGUAGE");
	    setenv ("LANGUAGE", "C", 1);
	    bind_textdomain_codeset (DB_TEXTDOMAIN, "ISO-8859-1");
	    bind_textdomain_codeset (PRG_TEXTDOMAIN, "ISO-8859-1");
	    ++_nl_msg_cat_cntr;
	} else {
	    bind_textdomain_codeset (DB_TEXTDOMAIN, enc.c_str ());
	    bind_textdomain_codeset (PRG_TEXTDOMAIN, enc.c_str ());
	}
	if (c && (*c)->use) {
	    YCPMap m;
	    if (!arg.isNull () && arg->isMap ())
		m = arg->asMap ();
	    s = s + getOptions ((*c)->use, m);
	}
	char*vv = (char*)path->component_str (1).c_str();
	char*mm = (char*)path->component_str (2).c_str();
	char*con = (char*)path->component_str (3).c_str();
	char*ven = (char*)path->component_str (4).c_str();
	char*mod = (char*)path->component_str (5).c_str();
	getnames (&vv, &mm, &con);

	ven = textWithoutDetails (ven);
	mod = textWithoutDetails (mod);
	con = (cfg == "") ? strdup(__(PPD_FILE_STRING)) : textWithoutDetails (con);

	fprintf (f, "----X-ENCODING: %s\n", "ISO-8859-2" == enc ? "h02" : "h01");
	fprintf (f, "----X-VENDOR: (%s: %s)\n", ven ? (const char*)ven : "", mod ? (const char*)mod : "");
	fprintf (f, "----X-CONFIG: (%s)\n", con ? (const char*)con : "");
	fprintf (f, "----X-QUEUE-L: (%s)\n", __(PRINT_QUEUE_STRING));
	fprintf (f, "----X-PRINTER-L: (%s)\n", __(PRINTER_STRING));
	fprintf (f, "----X-CONFIG-L: (%s)\n", __(CONFIGURATION_STRING));
	fprintf (f, "----X-OPTION-L: (%s)\n", cfg == "" ? __(NO_OPTS_STRING) : __(OPTIONS_STRING));
	fprintf (f, "----X-HEAD: (%s)\n", __(Y2TESTPAGE_STRING));
	// add other info here...
	if (enc == "ISO-8859-2")
	    fputs ("unit 2 div f02\n",f);
	fputs (s.c_str (), f);
	if (enc == "X") {
	    extern int _nl_msg_cat_cntr;
	    if (0 == old_lang)
		unsetenv ("LANGUAGE");
	    else
		setenv ("LANGUAGE", old_lang, 1);
	    ++_nl_msg_cat_cntr;
	}
	bind_textdomain_codeset (DB_TEXTDOMAIN, "UTF-8");
	bind_textdomain_codeset (PRG_TEXTDOMAIN, "UTF-8");
	fclose (f);
	if (ven) free (ven);
	if (mod) free (mod);
	if (con) free (con);
    }
    else
        y2error("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPVoid();
}

/**
 * otherCommand
 */
YCPValue PrinterdbAgent::otherCommand(const YCPTerm& term)
{
    string sym = term->symbol()->symbol();
    YCPString v = YCPString ("/usr/lib/YaST2/data/printerdb/suse.prdb");
    if (term->size () > 0 && term->value (0)->isString ())
	v = term->value (0)->asString ();

    if (sym == "PrinterdbAgent") {
	spdbStart (v->value_cstr ());
	db_up = true;
        return YCPVoid();
    }

    return YCPNull();
}

/**
 * Debugging function...
 */
void spdbReportError (int line, const char*file, const char*func, const char*format, ...)
{
    va_list ap;
    va_start(ap, format);
    y2_vlogger (LOG_ERROR, "ag_printerdb", file, line, func, format, ap);
    va_end(ap);
}

/**
 * Return given string without parts in parenthesis
 */
char* textWithoutDetails (char* long_string){
    char*short_string;
    char*ptr_src, *ptr_dst;
    int parenthesis = 0;

    if(!(long_string))return NULL;

    long_string = _((const char*)long_string);

    short_string = (char*) malloc (strlen (long_string) +1);
    if (! (short_string))
    {
	return NULL;
    }

    ptr_dst = short_string;
    ptr_src = long_string;
    while (*ptr_src)
    {
        if (*ptr_src == '(') parenthesis++;
        else if (*ptr_src == ')') parenthesis--;
        else
        {
            if (parenthesis < 0) parenthesis = 0;
            if (parenthesis == 0)
            {
                *ptr_dst = *ptr_src;
                ptr_dst++;
            }
        }
        ptr_src++;
    }
    *ptr_dst = 0;
    return short_string;
}

