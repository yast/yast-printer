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

#ifndef _Y2CCPDAgent_h
#define _Y2CCPPDAgent_h

#define y2log_component "ag_ppd"
#include "Y2.h"

/**
 * @short And a component creator for the component
 */
class Y2CCPPDAgent : public Y2ComponentCreator {
public:

	/**
	 * Enters this component creator into the global list of component creators.
	 */
    Y2CCPPDAgent() : Y2ComponentCreator(Y2ComponentBroker::BUILTIN) {};

	/**
	 * Specifies, whether this creator creates Y2Servers.
	 */
    virtual bool isServerCreator() const { return true; };

	/**
	 * Implements the actual creating of the component.
	 */
    virtual Y2Component *create(const char *name) const;
};

#endif /* _Y2CCPPDAgent_h */
