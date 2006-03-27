/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD Agent Component Creator
 *
 * Authors:
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "PPDAgent.h"


typedef Y2AgentComp <PPDAgent> Y2PpdAgentComp;

Y2CCAgentComp <Y2PpdAgentComp> g_y2ccag_ppd ("ag_ppd");

/* EOF */
