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

#ifndef _CupsAgent_h
#define _CupsAgent_h

#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

#include "PrintersConf.h"
#include "ClassesConf.h"
#include "DefaultDest.h"

/**
 * @short An interface class between YaST2 and Cups Agent
 */
class CupsAgent : public SCRAgent {

private:
  /**
   * Agent private variables
   */
  PrintersConf printers;
  ClassesConf classes;
  DefaultDest defaultdest;

public:
	/**
	 * Default constructor.
	 */
    CupsAgent();
	/**
	 * Destructor.
	 */
    virtual ~CupsAgent();

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

#if 0
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
    ~Y2CupsAgentComponent() {
	if (interpreter) {
	    delete agent;
	    delete interpreter;
	}
    }

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
};

/**
 * @short And a component creator for the component
 */
class Y2CCCupsAgent : public Y2ComponentCreator {
public:

	/**
	 * Enters this component creator into the global list of component creators.
	 */
    Y2CCCupsAgent() : Y2ComponentCreator(Y2ComponentBroker::BUILTIN) {};

	/**
	 * Specifies, whether this creator creates Y2Servers.
	 */
    virtual bool isServerCreator() const { return true; };

	/**
	 * Implements the actual creating of the component.
	 */
    virtual Y2Component *create(const char *name) const;
};
#endif//0

#endif /* _CupsAgent_h */
