/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Cups Agent Component Creator
 *
 * Authors:
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "CupsAgent.h"


typedef Y2AgentComp <CupsAgent> Y2CupsAgentComp;

Y2CCAgentComp <Y2CupsAgentComp> g_y2ccag_cups ("ag_cups");




/**
 * Y2CCCupsAgent create
 */
/*Y2Component *Y2CCCupsAgent::create(const char *name) const {
  if (!strcmp(name, "ag_cups")) return new Y2CupsAgentComponent();
  else return 0;
}
*/
/**
 * Y2CCCupsAgent instance
 */
//Y2CCCupsAgent g_y2ccag_cups;

/* EOF */
