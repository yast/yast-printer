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

#ifndef _Y2PPDAgentConponent_h
#define _Y2PPDAgentConponent_h

#include "Y2.h"

class SCRInterpreter;
class PPDAgent;

/**
 * @short A component for it
 */
class Y2PPDAgentComponent : public Y2Component
{
    PPDAgent *agent;
    SCRInterpreter *interpreter;
    
public:
    
    /**
     * Default constructor
     */
    Y2PPDAgentComponent() : Y2Component(), agent(0), interpreter(0) {}
    
    /**
     * Destructor
     */
    ~Y2PPDAgentComponent();
  
	/**
	 * Returns the name of the agent.
	 */
    virtual string name() const { return "ag_ppd"; };

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
