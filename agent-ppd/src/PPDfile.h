/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD implementation
 *
 * Authors:
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#ifndef _PPDfile_h
#define _PPDfile_h

#include <sys/types.h>

#include <string>
#include <list>
#include <map>

#include <Y2.h>

using namespace std;

class PPDfile {
    public:

        PPDfile();
        ~PPDfile();

	YCPMap getOptionsGroups (YCPString filename);
	YCPMap getOptions (YCPString filename, YCPString section);
	YCPString openPpdFile (YCPString filename, YCPString tmpdir);
	YCPBoolean isPpd (const char* filename);
	YCPMap ppdInfo (const char *filename);


    private:

    protected:

};

#endif /* _PPDfile_h */

