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

#include "Y2CCPrinterdbAgent.h"
#include "Y2PrinterdbAgentComponent.h"


Y2CCPrinterdbAgent::Y2CCPrinterdbAgent()
    : Y2ComponentCreator(Y2ComponentBroker::BUILTIN)
{
}


bool
Y2CCPrinterdbAgent::isServerCreator() const
{
    return true;
}


Y2Component *
Y2CCPrinterdbAgent::create(const char *name) const
{
    if (!strcmp(name, "ag_printerdb")) return new Y2PrinterdbAgentComponent();
    else return 0;
}


Y2CCPrinterdbAgent g_y2ccag_printerdb;
