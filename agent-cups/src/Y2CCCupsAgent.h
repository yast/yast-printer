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

#ifndef _Y2CCCupsAgent_h
#define _Y2CCCupsAgent_h

#define y2log_component "ag_cups"
#include "Y2.h"

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

#endif /* _Y2CCCupsAgent_h */
