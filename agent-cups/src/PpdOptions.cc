#include "PpdOptions.h"
#include "Y2Logger.h"

#include <cups/ppd.h>
#include <unistd.h>
#include <list>
#include <zlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>


/**
 * Unpacks file to temp.
 * @return filename of ungziped temporary file. Must be delete[]d.
 */
//FIXME remove, is in printerdb agent
char*unpackGzipped(const char*fn)
{
    char buf[2048];
    char*newname;
    int out;
    newname = new char[L_tmpnam];
    tmpnam(newname);

    if ((out = open (newname, O_RDWR|O_CREAT|O_EXCL, 0600)) < 0)
    {
	y2error ("Possible link attack detection");
	delete [] newname;
	return NULL;
    }
    gzFile file = gzopen (fn, "rb");
    if (!file)
    {
	close (out);
	delete [] newname;
	return NULL;
    }
    while (gzgets(file, buf, sizeof buf))
	write (out,buf, strlen (buf));
    close (out);
    gzclose (file);

    return newname;
}

YCPBoolean isPpd (const char* filename)
{
    bool ret = true;
    const char* ppd_filename = filename;
    char* ungzipped = NULL;
    int len = strlen (filename);
    ppd_file_t *ppd;

    if (len>3 && !strcmp(filename+len-3,".gz"))
    {
        ungzipped = unpackGzipped (filename);
        ppd_filename = ungzipped;
    }
    ppd = ppdOpenFile(ppd_filename);
    if (ppd)
    {
        ret = true;
        ppdClose(ppd);
    }
    else
        ret = false;

    if (ungzipped)
        free (ungzipped);
    return YCPBoolean (ret);
}
YCPMap ppdInfo (const char *filename)
{
    YCPMap m = YCPMap();
    const char* ppd_filename = filename;
    char* ungzipped = NULL;
    int len = strlen (filename);
    ppd_file_t *ppd;

    if (len>3 && !strcmp(filename+len-3,".gz"))
    {
        ungzipped = unpackGzipped (filename);
        ppd_filename = ungzipped;
    }
    ppd = ppdOpenFile(ppd_filename);
    if (ppd)
    {
        m->add (YCPString ("manufacturer"), YCPString (ppd->manufacturer));
        m->add (YCPString("model"), YCPString(ppd->modelname));
        m->add (YCPString ("nick"), YCPString(ppd->nickname));
    }
    if (ungzipped)
        free (ungzipped);
    return m;
}

