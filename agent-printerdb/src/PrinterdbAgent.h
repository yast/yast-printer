/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Printerdb agent implementation
 *
 * Authors:
 *   Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

#ifndef _PrinterdbAgent_h
#define _PrinterdbAgent_h

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

#include "structs.h"

/**
 * @short An interface class between YaST2 and Printerdb Agent
 */
class PrinterdbAgent : public SCRAgent
{
    private:
        /**
         * Agent private variables
         */
	bool db_up;
	YCPList getOptionTree (List*opts);
	YCPList getConfigTree (List*cfgs);
	string getSupportPrefix (Config *c);
	bool isSupported(Config *c, string spooler);
	string getConfigRichText (List*cfgs, string spooler);
	void getConfigCombo (List*cfgs, YCPList&l, string pre, string spooler,
	    bool show_sup_pref, bool filter);
	YCPList getOptionItems (List*u, YCPMap&selected, string indent, const char*preselect);
	string getOptions (List*u, YCPMap&selected, string prefix);
	YCPList getAutoQueues (List*cfgs);
	YCPList getAllQueues (List *cfgs);
	YCPMap getFirstAutoQueue (Config*c);
	YCPValue PrinterName (YCPList&l);
	YCPValue ConfigName (YCPList&l);
	YCPValue Detect (YCPList&l);
	YCPList Vendors (string&preselect,string&pre_ieee);
	YCPValue Values (const char*ident, YCPValue&arg);
	YCPValue getValuesList (List*vl);
	YCPBoolean isPpd (const char* filename);
	YCPMap ppdInfo (const char* filename);

    public:
        /**
         * Default constructor.
         */
        PrinterdbAgent();
        /** 
         * Destructor.
         */
        virtual ~PrinterdbAgent();

        /**
         * Provides SCR Read ().
         * @param path Path that should be read.
         * @param arg Additional parameter.
         */
        virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull());

        /**
         * Provides SCR Write ().
         */
        virtual YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());

        /**
         * Provides SCR Write ().
         */
        virtual YCPValue Dir(const YCPPath& path);

        /**
         * Used for mounting the agent.
         */    
        virtual YCPValue otherCommand(const YCPTerm& term);
};

string getConfFile (List*u, YCPMap&selected, int&flags, const string selection);
YCPValue WriteTransStrings (const char*fn, const char*type);
YCPValue numint2ycp (const Numint*n);
YCPValue numfloat2ycp (const Numfloat*n);
YCPValue text2ycp (const ValueText*n);
char* textWithoutDetails (char* long_string);
char* readFileToString (const char*filename);
string getPatchedPpdFile (const char* filename, string options);
char*unpackGzipped(const char*fn);

#endif /* _PrinterdbAgent_h */
