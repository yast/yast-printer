/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD Agent Component
 *
 * Authors:
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#include "Y2PPDAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "PPDAgent.h"

bool
Y2PPDAgentComponent::isServer() const
{
  return true;
}

/**
 * Y2PPDAgentComponent evaluate
 */
YCPValue Y2PPDAgentComponent::evaluate(const YCPValue& value) {
  if (!interpreter) {
    agent = new PPDAgent();
    interpreter = new SCRInterpreter(agent);
  }

  return interpreter->evaluate(value);
}

Y2PPDAgentComponent::~Y2PPDAgentComponent() {
	if (interpreter) {
	    delete agent;
	    delete interpreter;
	}
    }

/* EOF */
