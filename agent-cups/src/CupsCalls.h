/* CupsCalls.h -*- c++ -*-
 *
 * Functions for working with cups.
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */
#ifndef _CUPSCALLS_H_
#define _CUPSCALLS_H_

#include <Y2.h>
#include <set>
#include <string>
#include <cups/ipp.h>

using namespace std;

/**
 * Modify or add printer. If any of the params is NULL, it is not set.
 * @param name Printer name.
 * @param info Printer info.
 * @param loc  Printer location.
 * @param state Printer state.
 * @param statemsg Description of printer state.
 * @param bannerstart Banner 
 * @param bannerend Banner 
 * @param deviceuri
 * @param allowusers
 * @param denyusers
 * @param ppd
 * @param accepting 
 */ //FIXME: return value
bool setPrinter(const char*name,const char*info,const char*loc,const char*state,const char*statemsg,
                const char*bannerstart,const char*bannerend,const char*deviceuri,
                const set<string>allowusers,const set<string>denyusers,const char*ppd,const char*accepting);


/**
 * Delete printer.
 * @param name Printer name.
 * @return True if successful.
 */ //FIXME: return value
bool deletePrinter(const char*name);

/**
 * Get path to ppd file for the printer or class.
 * @param name Name of the printer or the class.
 * @return Path to ppd file or 0 if no ppd is associated with printer/class.
 */
const char*getPPD(const char*name);

/**
 * Set printer options in cups system.
 * @param name Name of the printer.
 * @param opt YCPMap of options.
 * @param defls Is this printer default printer?
 */
void setPrinterOptions(const char*name,YCPMap&options,bool deflt = false);

/**
 * Get default destination.
 * @return Name of printer.
 */
string getDefaultDest();

/**
 * Set default destination.
 * @param d Name of default destination.
 * @return Success state.
 */
bool setDefaultDest(const char*d);

bool setClass(const char*name,const char*info,const char*loc,const char*state,const char*statemsg,
              const char*bannerstart,const char*bannerend,
              const set<string>allowusers,const set<string>denyusers,const char*accepting,
              const set<string>members);

bool deleteClass(const char*name);

/**
 * Get printers on remote host.
 * @param host host name to check
 * @param what_to_get one of CUPS_GET_PRINTERS and CUPS_GET_CLASSES
 * @param ret printer names will be added here
 * @return success state
 */
bool getRemoteDestinations(const char*host,YCPList&ret,ipp_op_t what_to_get);

char* TOLOWER(char* src);

#endif//_CUPSCALLS_H_
