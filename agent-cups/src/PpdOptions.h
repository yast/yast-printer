#ifndef __PpdOptions_h__
#define __PpdOptions_h__

#include <Y2.h>

YCPValue readPpd (const char*ppd_filename,const YCPMap&options);
YCPValue readCommonOptions (const char*ppd_filename,const YCPMap&options);

YCPBoolean isPpd (const char* filename);
YCPMap ppdInfo (const char *filename);

#endif//__PpdOptions_h__
