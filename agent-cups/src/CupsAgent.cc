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
//#include "PpdOptions.h"

char last_error[1024];

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
YCPList CupsAgent::Dir(const YCPPath& path) 
{
    if (path->length() == 2)
    {
        if (path->component_str (0) == "printers")
	{
	    return getPrinters (path->component_str (1));
	}
	if (path->component_str (0) == "classes")
	{
            return getClasses (path->component_str (1));
	}
    }
    ycp2error (string (string ("Wrong path '") + path->toString() + string ("' in Dir().")).c_str());
    return YCPNull ();
}

/**
 * Read
 */
YCPValue CupsAgent::Read(const YCPPath &path, const YCPValue& arg, const YCPValue& opt)
{
    if (path->component_str (0) == "last_error")
	return YCPString (last_error);
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
                        getRemoteDestinations(arg->asString()->value_cstr(),l,CUPS_GET_PRINTERS, true);
                        getRemoteDestinations(arg->asString()->value_cstr(),l,CUPS_GET_CLASSES, true);
                        return l;
                    }
		return YCPError (string ("Read(.cups.remote): Wrong argument: ") + arg->toString() + string (". Expecting <string>."));
            }
    }

    // fallback...
    return YCPError(string ("Wrong path '") + path->toString() + string ("' in Read()."));
}

/**
 * Write
 */
YCPBoolean CupsAgent::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
    if(path->length()>=1) {
        if(path->component_str(0)=="printers")
            return printers.Write(path,value,arg);
        if(path->component_str(0)=="classes")
            return classes.Write(path,value,arg);
        if(path->component_str(0)=="default_dest")
            return defaultdest.Write(path,value,arg);
    }

    ycp2error(string (string ("Wrong path '%s' in Write().") + path->toString()).c_str());
    return YCPBoolean (false);
}

/**
 * otherCommand
 */
YCPValue CupsAgent::otherCommand(const YCPTerm& term) {
    string sym = term->name();

    if (sym == "CupsAgent") {
        /* Your initialization */
        return YCPVoid();
    }

    return YCPNull();
}
