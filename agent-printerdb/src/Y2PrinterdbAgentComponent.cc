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

#include "Y2PrinterdbAgentComponent.h"
#include <scr/SCRInterpreter.h>
#include "PrinterdbAgent.h"


Y2PrinterdbAgentComponent::Y2PrinterdbAgentComponent()
    : interpreter(0),
      agent(0)
{
}


Y2PrinterdbAgentComponent::~Y2PrinterdbAgentComponent()
{
    if (interpreter) {
        delete interpreter;
        delete agent;
    }
}


bool
Y2PrinterdbAgentComponent::isServer() const
{
    return true;
}

string
Y2PrinterdbAgentComponent::name() const
{
    return "ag_printerdb";
}


YCPValue Y2PrinterdbAgentComponent::evaluate(const YCPValue& value)
{
    if (!interpreter) {
        agent = new PrinterdbAgent();
        interpreter = new SCRInterpreter(agent);
    }
    
    return interpreter->evaluate(value);
}

