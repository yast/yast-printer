/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Cups agent implementation
 *
 * Authors:
 *   Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

#include "Y2Logger.h"
#include "CupsAgent.h"
#include "CupsCalls.h"
#include "PpdOptions.h"

bool getClasses ();

/**
 * Constructor
 */
CupsAgent::CupsAgent() : SCRAgent()
{
}

/**
 * Destructor
 */
CupsAgent::~CupsAgent() {
}

/**
 * Dir
 */
YCPValue CupsAgent::Dir(const YCPPath& path) 
{
    return YCPError (string ("Wrong path '") + path->toString() + string ("' in Dir()."));
}

/**
 * Read
 */
YCPValue CupsAgent::Read(const YCPPath &path, const YCPValue& arg)
{
    if (path->component_str (0) == "isppd" && !arg.isNull () && arg->isString ()) {
        return isPpd (arg->asString()->value_cstr ());
    }
    else if (path->component_str (0) == "ppdinfo" && !arg.isNull () && arg->isString ()) {
        return ppdInfo (arg->asString()->value_cstr ());
    }
    else if(path->length() == 1) 
    {
        if(path->component_str(0)=="printers")
            return printers.Read();
        if(path->component_str(0)=="classes")
            return classes.Read();
        if(path->component_str(0)=="default_dest")
            return defaultdest.Read();
        if(path->component_str(0)=="remote")
            {
                if(arg->isString())
                    {
                        YCPList l;
                        getRemoteDestinations(arg->asString()->value_cstr(),l,CUPS_GET_PRINTERS);
                        getRemoteDestinations(arg->asString()->value_cstr(),l,CUPS_GET_CLASSES);
                        return l;
                    }
		return YCPError (string ("Read(.cups.remote): Wrong argument: ") + arg->toString() + string (". Expecting <string>."));
            }
    }
/*    if(path->length()==2 && path->component_str(0)=="ppd")
        {
            if(path->component_str(1)=="changed")
                return YCPBoolean(ppd.changed(NULL));
            if(path->component_str(1)=="options")
                {
                    if (arg->isString ())
                        {
                            return readPpd (arg->asString()->value_cstr(), YCPMap());
                        }
                    else if (arg->isList ())
                        {
                            YCPList l = arg->asList();
                            if(l->size() != 2 || !l->value(0)->isString() || !l->value(1)->isMap())
                                {
                                    return YCPError (string ("Read(.cups.ppd.options): Wrong argument: ") + l->toString() + string (". Expecting [<string>,<string>]."));
                                }
                            return readPpd (l->value(0)->asString()->value_cstr(),l->value(1)->asMap());
                        }
                    else if (arg->isVoid ())
                        {
                            y2error("Read(.cups.ppd.options): Reading of common options is not implemented yet.");
                        }
                }
            if(path->component_str(1)=="common_options")
                {
                    if (arg->isString ())
                        {
                            return readCommonOptions (arg->asString()->value_cstr(), YCPMap());
                        }
                    else if (arg->isList ())
                        {
                            YCPList l = arg->asList();
                            if(l->size() != 2 || !l->value(0)->isString() || !l->value(1)->isMap())
                                {
                                    return YCPError(string ("Read(.cups.ppd.options): Wrong argument: ") + l->toString() + string (". Expecting [<string>,<string>]."));
                                }
                            return readCommonOptions (l->value(0)->asString()->value_cstr(),l->value(1)->asMap());
                        }
                    else if (arg->isVoid ())
                        {
                            y2error("Read(.cups.ppd.options): Reading of common options is not implemented yet.");
                        }
                }
            if(path->component_str(1)=="info")
                {
                    if(arg->isString ())
                        {
                            PPD::PPDInfo info;
                            if(ppd.fileinfo(arg->asString()->value_cstr(),&info))
                                {
                                    YCPMap m;
                                    m->add(YCPString("manufacturer"),YCPString(info.vendor));
                                    m->add(YCPString("printer"),YCPString(info.printer));
                                    m->add(YCPString("product"),YCPString(info.product));
                                    m->add(YCPString("nick"),YCPString(info.nick));
                                    m->add(YCPString("lang"),YCPString(info.lang));
                                    return m;
                                }
                            else
                                {
                                    return YCPError(string ("Read(.cups.ppd.info): Can not read ppd file: ") + arg->asString()->value ());
                                }
                        }
                    else
                        {
                            return YCPError("Read(.cups.ppd.info): Expecting string as an argument.");
                        }
                }
        }*/

    // fallback...
    return YCPError(string ("Wrong path '") + path->toString() + string ("' in Read()."));
}

/**
 * Write
 */
YCPValue CupsAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
    if(path->length()>=1) {
        if(path->component_str(0)=="printers")
            return printers.Write(path,value,arg);
        if(path->component_str(0)=="classes")
            return classes.Write(path,value,arg);
        if(path->component_str(0)=="default_dest")
            return defaultdest.Write(path,value,arg);
    }

/*    if(path->length()==2 && path->component_str(0)=="ppd") {
        if(path->component_str(1)=="createdb")
            return YCPBoolean(ppd.createdb());
    }*/

    return YCPError(string ("Wrong path '%s' in Write().") + path->toString());
}

/**
 * otherCommand
 */
YCPValue CupsAgent::otherCommand(const YCPTerm& term) {
    string sym = term->symbol()->symbol();

    if (sym == "CupsAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
