/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD agent implementation
 *
 * Authors:
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#ifndef _PPDAgent_h
#define _PPDAgent_h

//#define y2log_component "ag_ppd"
#include <Y2.h>
#include <scr/SCRAgent.h>

#include "PPDdb.h"
#include "PPDfile.h"

/**
 * @short An interface class between YaST2 and PPD Agent
 */
class PPDAgent : public SCRAgent {

private:
    /**
      * Agent private variables
      */
    PPD database;
    PPDfile fileops;
public:
	/**
	 * Default constructor.
	 */
    PPDAgent();
	/**
	 * Destructor.
	 */
    virtual ~PPDAgent();

	/**
	 * Provides SCR Read ().
	 * @param path Path that should be read.
	 * @param arg Additional parameter.
	 */
    virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull(), const YCPValue& opt = YCPNull());

	/**
	 * Provides SCR Write ().
	 */
    virtual YCPBoolean Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());

	/**
	 * Provides SCR Write ().
	 */
    virtual YCPList Dir(const YCPPath& path);

	/**
	 * Used for mounting the agent.
	 */
    virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _PPDAgent_h */
