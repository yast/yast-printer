/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD Agent Component
 *
 * Authors:
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#ifndef _Y2CupsAgentConponent_h
#define _Y2CupsAgentConponent_h

#include "Y2.h"

class SCRInterpreter;
class CupsAgent;

/**
 * @short A component for it
 */
class Y2CupsAgentComponent : public Y2Component
{
    CupsAgent *agent;
    SCRInterpreter *interpreter;
    
public:
    
    /**
     * Default constructor
     */
    Y2CupsAgentComponent() : Y2Component(), agent(0), interpreter(0) {}
    
    /**
     * Destructor
     */
    ~Y2CupsAgentComponent();
  
	/**
	 * Returns the name of the agent.
	 */
    virtual string name() const { return "ag_cups"; };

	/**
	 * Starts the server, if it is not already started and does
	 * what a server is good for: Gets a command, evaluates (or
	 * executes) it and returns the result.
	 * @param command The command to be executed. Any YCPValueRep
	 * can be executed. The execution is performed by some
	 * YCPInterpreter.
	 */
    virtual YCPValue evaluate(const YCPValue& command);

    /**
     * Returns true: The scr is a server component
     */
    bool isServer() const;
    
};

#endif /* _Y2PPDAgentConponent_h */
