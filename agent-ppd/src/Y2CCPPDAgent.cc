/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD Agent Component Creator
 *
 * Authors:
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#include "Y2CCPPDAgent.h"
#include "Y2PPDAgentComponent.h"

/**
 * Y2CCPPDAgent create
 */
Y2Component *Y2CCPPDAgent::create(const char *name) const {
  if (!strcmp(name, "ag_ppd")) return new Y2PPDAgentComponent();
  else return 0;
}

/**
 * Y2CCPPDAgent instance
 */
Y2CCPPDAgent g_y2ccag_ppd;

/* EOF */
