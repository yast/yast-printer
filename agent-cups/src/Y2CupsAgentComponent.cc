/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Cups Agent Component
 *
 * Authors:
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#include "Y2CupsAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "CupsAgent.h"

bool
Y2CupsAgentComponent::isServer() const
{
  return true;
}

/**
 * Y2CupsAgentComponent evaluate
 */
YCPValue Y2CupsAgentComponent::evaluate(const YCPValue& value) {
  if (!interpreter) {
    agent = new CupsAgent();
    interpreter = new SCRInterpreter(agent);
  }

  return interpreter->evaluate(value);
}

Y2CupsAgentComponent::~Y2CupsAgentComponent() {
	if (interpreter) {
	    delete agent;
	    delete interpreter;
	}
    }

/* EOF */
