/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: PPD implementation
 *
 * Authors:
 *   Michal Svec <msvec@suse.cz>
 *
 * $Id$
 */

#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <cups/ppd.h>
#include <zlib.h>
#include <ctype.h>
#include <regex.h>
#include <stdio.h>
#include <fcntl.h>
#include <xcrypt.h>


#include <map>
#include <string>
#include <vector>

bool verbose = false;

/*
    TODO
    - fix all FIXME
    - update only changed files
*/

//#ifndef _DEVEL_

#include "ycp/y2log.h"
#include <ycp/Parser.h>
#include <ycp/YCode.h>
#include <YCP.h>
#include "PPDdb.h"

/*****************************************************************/
/*
#undef y2debug
#define y2debug(format, args...)

#else
#define y2debug(format, args...) //fprintf(stderr, format "\n" , ##args)
#define y2warning(format, args...) fprintf(stderr, format "\n" , ##args)
#define y2error(format, args...) fprintf(stderr, format "\n" , ##args)

#include "PPDdb.h"
#endif
*/
/*****************************************************************/

/**
 * Constructor
 */
PPD::PPD(const char *ppddir, const char *ppddb) {
    int i = 0;
    char *v;

    /* set mtime initially to 0 */
    mtime=0;

    /* init ppd_dir and ppd_db paths */
    strncpy(ppd_dir,ppddir,sizeof(ppd_dir));
    strncpy(ppd_db,ppddb,sizeof(ppd_db));

    string yast2_dir;
    if (char* tmp_yast2_dir = getenv ("Y2DIR"))
    {
	yast2_dir = tmp_yast2_dir;
    }
    else
    {
	yast2_dir = "/usr/share/YaST2";
    }

    if (char* tmp_ydata_dir = getenv ("Y2_PRINTER_DATA_DIR"))
    {
	datadir = tmp_ydata_dir;
    }
    else
    {
	datadir = yast2_dir + "/data/printer/";
    }
    var_datadir = "/var/lib/YaST2/";

    fast_check = false;

    /* Load strings mappings */
    #include "PPDVendors.h"

    /* Add all known vendors */
    for(i=0;(v=array_all[i]);i++)
        vendors_map[string(v)]=string(v);

    /* Add special vendors hacks */
    for(i=0;(v=array_map[i].key);i++)
    {
        vendors_map[string(v)]=string(array_map[i].val);
	vendors_map[string(array_map[i].val)] = string(array_map[i].val);
    }

    char buf[256];
    string filename = datadir + "models.equiv";
    FILE* f = fopen (filename.c_str(), "r");
    if (f)
    {
	while (fgets (buf, 255, f))
	{
	    unsigned int i = 0;
	    string vendor;
	    string pattern;
	    string res;
	    for (; i < strlen (buf) ; i++)
	    {
		if (buf[i] == '/')
		{
		    i++;
		    break;
		}
		vendor = vendor + buf[i];
	    }
            for (; i < strlen (buf) ; i++)
            {
                if (buf[i] == '/')
		{
		    i++;
                    break;
		}
                pattern = pattern + buf[i];
            }
            for (; i < strlen (buf) ; i++)
            {
                if (buf[i] == '/')
		{
		    i++;
                    break;
		}
                res = res + buf[i];
            }

	    if (vendor != "" && pattern != "" && res != "")
	    {
		pattern = "^" + pattern + "$";

		vector <pair <string, string> > vend;
		if(models_map.find(vendor) != models_map.end())
		    vend = models_map[vendor];
		vend.push_back (pair<string, string> (pattern, res));
		models_map[string(vendor)]=vend;
	    }
	}
	fclose (f);
    }
    else
	y2error ("Error while opening models equivalence list");

    /*
    VendorsMap::const_iterator it = vendors_all.begin();
    for(; it != vendors_all.end (); ++it) y2debug("it: %s",it->first.c_str());
    */
}

/**
 * Destructor
 */
PPD::~PPD() {
}

/**
 * Return info from the given file
 */
bool PPD::fileinfo(const char *file, PPDInfo *info) {
    if(!file || !info) {
        y2error("bad argument to fileinfo (%p,%p)",file,info);
        return false;
    }
    return process_file(file, info);
}

/**
 * Check if any ppd file has changed
 */
bool PPD::changed(int *count) {
    int cnt = 0;
    struct stat fileinfo;
    if(stat(ppd_db, &fileinfo))
        return true;
    if(fileinfo.st_size==0)
        return true;
    mtime = fileinfo.st_mtime;
    bool ret = mtimes(ppd_dir,mtime,&cnt);
    if(count) *count=cnt;
    return ret;
}

/**
 * Transform vendor name from PPD file/detection to key in database
 */
string PPD::getVendorId (string vendor) {
    vendor = strupper (vendor);
    if(vendors_map.find(vendor)!=vendors_map.end()) {
	vendor = vendors_map[vendor];
    }
    else
    {
	vendor = filternotchars (vendor, "/. -<>_");
    }
    return vendor;
}

/**
 * Remove the vendor name from the beginning of the model if present
 * @param vendor string vendor id
 * @param model string model label/id
 * @return string model label/id with removed vendor from the begining
 */
string PPD::removeVendorFromModel (string vendor, string model) {
    int size = vendor.size ();
    if (strupper (model.substr (0,size+1)) == vendor + " ")
    {
	model.erase (0,size);
    }
    else
    {
	for (VendorsMap::iterator it = vendors_map.begin ();
	    it != vendors_map.end ();
	    it++)
	{
	    string v_ppd = strupper (it->first);
	    string v = getVendorId (v_ppd);
	    int size = v_ppd.size ();
	    if (v == vendor && strupper (model.substr (0,size + 1)) == v_ppd + " ")
	    {
		model.erase (0,size);
		break;
	    }
	}
    }
    return model;
}

/**
 * Transform model name from PPD file/detection to key in database
 */
string PPD::getModelId (string vendor, string model) {
    bool found = false;
    string modres = "";
    model = strupper (model);
    model = removeVendorFromModel (vendor, model);
    vendor = getVendorId (vendor);
    model = removeVendorFromModel (vendor, model);
    model = filternotchars (model, "/. -<>_");

    if (models_map.find (vendor) != models_map.end ())
    {
	found = true;
	vector <pair<string, string> > vend = models_map[vendor];
	vector <pair<string, string> >::iterator it = vend.begin ();
	while (it != vend.end ())
	{
	    modres = regexpsub (model, it->first, it->second);
	    if (modres != "")
		break;
	    it++;
	}
    }
    if (modres != "")
	model = modres;
    modres = "";
//    y2error ("Result of manuf: %s", model.c_str ());
//    if (! found)
//    {
        vector <pair<string, string> > vend = models_map["_ALL_"];
        vector <pair<string, string> >::iterator it = vend.begin ();
        while (it != vend.end ())
        {
//	    y2error ("All checking against %s/%s", it->first.c_str (), it->second.c_str ());
            modres = regexpsub (model, it->first, it->second);
            if (modres != "")
                break;
            it++;
        }
//    }
    if (modres == "")
	modres = model;

    /* remove ", Foomatic..." */
    int br = modres.find (", ");
    if (br > 0)
        modres = modres.substr (0, br);

    return modres;
}

/**
 * Check modification times in the given directory
 */
bool PPD::mtimes(const char *dirname, time_t mtime, int *count) {

    DIR *dir;
    struct dirent *entry;
    struct stat fileinfo;
    char filename[MAX];

    if(stat(dirname, &fileinfo))
        return true;

    if(fileinfo.st_mtime >= mtime || fileinfo.st_ctime >= mtime) {
        return true;
    }

    dir = opendir(dirname);
    if(!dir) {
        y2error("opendir failed: %s (%s)", dirname, strerror(errno));
        return true;
    }

    while((entry=readdir(dir))) {
        if(entry->d_name[0]=='.' && entry->d_name[1]=='.')
            continue;

        snprintf(filename, sizeof(filename), "%s/%s", dirname, entry->d_name);

        if(stat(filename, &fileinfo))
            continue;

        if(fileinfo.st_mtime >= mtime || fileinfo.st_ctime >= mtime) {
            closedir(dir);
            return true;
        }

        if(entry->d_name[0]=='.')  // do not go deeper to directories beginning with .
            continue;

        if(S_ISDIR(fileinfo.st_mode) && mtimes(filename,mtime,count)) {
            closedir(dir);
            return true;
        }
        else count++;
    }

    closedir(dir);
    return false;
}

int PPD::creationStatus () {
    return creation_status;
}

/**
 * Count files to process
 */
int PPD::countFiles(const char *dirname) {

    DIR *dir;
    struct dirent *entry;
    struct stat fileinfo;
    char filename[MAX];
    int count = 0;
   
    dir = opendir(dirname);
    if(!dir) {
        y2error("opendir failed: %s (%s)", dirname, strerror(errno));
        return 0;
    }
    
    while((entry=readdir(dir))) {
        if(entry->d_name[0]=='.' && entry->d_name[1]=='.')
            continue;
	snprintf(filename, sizeof(filename), "%s/%s", dirname, entry->d_name);
        if(stat(filename, &fileinfo))
            continue;
        if(entry->d_name[0]=='.')  // do not go deeper to directories beginning with .
            continue;
        if(S_ISDIR(fileinfo.st_mode)) {
	    count += countFiles (filename);
        }
        else count++;
    }

    closedir(dir);
    return count;
}

/**
  * Create database of printers
  * Just start a thread and return immediately
  */
bool PPD::createdb () {
// TODO lock
    creation_status = 0;
    pthread_t id_creat;
    pthread_create (&id_creat, NULL, &(PPD::startCreatedbThread), this);
    return true;
}

void* PPD::startCreatedbThread (void* instance) {
    return ((PPD*)instance) -> createdbThread (NULL);
}

/**
 * Create a database of all ppd files in the /var/lib/YaST2/ppd_db.ycp
 * @return operation succeeded
 */
void* PPD::createdbThread(const char* filename) {
    y2milestone ("CreateDbThread started");

    bool f1 = false;
    bool f2 = false;
    bool f3 = false;
    char str[3] = "x\n";
    void* ret = (void*)1;
    bool updated = false;
    bool update_failed = false;

    total_files = countFiles (ppd_dir);
    done_files = 0;

    {
	y2debug ("Checking database file");
	struct stat fileinfo;
	if(stat(ppd_db, &fileinfo))
            goto start_from_scratch;
	if(fileinfo.st_size==0)
	    goto start_from_scratch;
	time_t mtime = fileinfo.st_mtime;

	y2debug ("Loading prebuilt database");
	if (! loadPrebuiltDatabase ())
	    goto start_from_scratch;
	creation_status = 2;
	y2debug ("Creating list of PPD files");
	if (! createFileList (ppd_dir, mtime))
            goto start_from_scratch;
	creation_status = 4;
	y2debug ("Cleaning up lists");
	if (! cleanupLists ())
	    goto start_from_scratch;
	creation_status = 10;
	y2debug ("Processing new files");
	if (! processNewFiles ())
	    update_failed = true;
	y2debug ("Emptying empty entries");
	if (! cleanupEmptyEntries ())
	    update_failed = true;
	updated = true;
	y2milestone ("Update database done");
    }

start_from_scratch:

    FILE *file;
    if (filename)
	file = fopen (filename, "w");
    else
	file = fopen(ppd_db,"w");

    if(!file) {
        y2error("Error opening ppd db (%s)", strerror(errno));
	creation_status = -1; //FIXME UNLOCK
        return NULL;//false;
    }

    if (! updated)
    {
	y2debug ("deleting database");
	creation_status = 10;
	db = Vendors();

	if(process_dir(ppd_dir)!=true) {
	    y2error("Error during creation of ppd db");
	    ret = NULL;//false;  // FIXME (return) // LOCK unlock
	}
    }

    creation_status = 90;

    // process list of SuSE database printers
    // do it always, as during database update information about printers
    // with no PPD file was removed
    addAdditionalInfo ();

    creation_status = 98;
    y2debug ("Flushing");

    fprintf(file,"/*\n");
    fprintf(file," * YCP database of all PPD files\n");
    fprintf(file," * GENERATED FILE, DON'T EDIT!\n");
    fprintf(file," */\n\n");
    fprintf(file,"$[\n\n");

    #define F(f) if(f==true) { *str=0; f=false; } else *str=',';

    PPD::Vendors::const_iterator it1 = db.begin ();
    for(f1 = true; it1 != db.end(); it1++) {
        F(f1) fprintf(file,str);
        fprintf(file,"\n  \"%s\" : $[\n", it1->first.c_str());
	string label = it1->second.label;
	if (label == "")
	    label = it1->first;
	if (label == "UNKNOWN")
	    label = "UNKNOWN MANUFACTURER";
	string vcomment = (*it1).second.vcomment;
	fprintf(file,"    `label : \"%s\",\n", label.c_str());
	if (vcomment != "")
	    fprintf(file,"    `vcomment : \"%s\",\n", vcomment.c_str ());
        PPD::Models::const_iterator it2 = (*it1).second.models.begin();
        for(f2 = true; it2 != (*it1).second.models.end(); it2++) {
            F(f2) fprintf(file,str);
            fprintf(file,"    \"%s\" : $[\n", it2->first.c_str ());

	    string support = (*it2).second.support;
	    string mcomment = (*it2).second.mcomment;

	    if (it2->second.label != "")
                fprintf(file,"      `label : \"%s\",\n",
		    it2->second.label.c_str ());
	    else
		fprintf(file,"      `label : \"%s\",\n", it2->first.c_str());

	    if (support != "")
		fprintf(file,"      `support : \"%s\",\n", support.c_str());
            if (mcomment != "" && mcomment != " ")
                fprintf(file,"      `mcomment : \"%s\",\n", mcomment.c_str ());

            PPD::Drivers::const_iterator it3 = (*it2).second.drivers.begin();
            for(f3 = true; it3 != (*it2).second.drivers.end(); it3++) {
		y2debug ("PPD file information: %s:%s:%s",
		    label.c_str(),
		    it2->second.label.c_str (),
		    (*it3).second.nickname.c_str()
		);
                F(f3) fprintf(file,str);
                fprintf(file,"      \"%s\"", (*it3).first.c_str());
                fprintf(file," : $[\n");
                fprintf(file,"        \"nickname\" : \"%s\",\n", (*it3).second.nickname.c_str());
                fprintf(file,"        \"pnp_vendor\" : \"%s\",\n", (*it3).second.pnp_vendor.c_str());
                fprintf(file,"        \"pnp_printer\" : \"%s\",\n", (*it3).second.pnp_printer.c_str());
		fprintf(file,"        \"checksum\" : \"%s\",\n", (*it3).second.checksum.c_str());
		fprintf(file,"        \"size\" : %d,\n", (*it3).second.size);
		fprintf(file,"        \"filter\" : \"%s\",\n", (*it3).second.filter.c_str());
		fprintf(file,"        \"language\" : \"%s\",\n", (*it3).second.language.c_str());
                fprintf(file,"      ]");
            }
            fprintf(file,"\n    ]");
        }
        fprintf(file,"\n  ]");
    }

    #undef F

    fprintf(file,"\n\n]\n\n/* EOF */\n");
    fclose(file);
    creation_status = 100;
    return ret;
}

void PPD::addAdditionalInfo () {
      y2debug ("Reading YaST2 file");
      char buf[16384];
      string filename = datadir + "printers_support";
      FILE* f = fopen (filename.c_str(), "r");
      if (f)
      {
        y2milestone ("File with support status entries opened, processing...");
        while (fgets (buf, 16384, f))
        {
            unsigned int i = 0;
            string vendor = "";
            string model = "";
            string support = "";
            for (; i < strlen (buf) ; i++)
            {
                if (buf[i] == '|' || buf[i] == '\n')
                {
                    i++;
                    break;
                }
                vendor = vendor + buf[i];
            }
            for (; i < strlen (buf) ; i++)
            {
                if (buf[i] == '|' || buf[i] == '\n')
                {
                    i++;
                    break;
                }
                model = model + buf[i];
            }
            for (; i < strlen (buf) ; i++)
            {
                if (buf[i] == '|' || buf[i] == '\n')
                {
                    i++;
                    break;
                }
                support = support + buf[i];
            }
	    // if printer is supported, it should have a PPD file
	    if (support != "not")
		continue;
            string mlabel = model;
	    string vlabel = strupper (vendor);
            vendor = getVendorId (vendor);
            model = getModelId (vendor, model);
            int size = vendor.size () + 1;
            if (strupper (mlabel.substr (0,size)) == vendor + " ")
                mlabel.erase (0, size);

            VendorInfo vi;
            if (db.find (vendor) != db.end ())
                vi = db[vendor];
	    else
		vi.label = vlabel;
            ModelInfo mi;
            bool updating_model = false;
            if (vi.models.find(model) != vi.models.end ())
            {
                mi = vi.models[model]; 
                updating_model = true;
		// continue - if PPD file exists, printer is supported
		continue;
            }
            else
            {
		mi.label = mlabel;
		updating_model = false;
            }
	    if (modellabels[vendor].find(mlabel) == modellabels[vendor].end()
		|| updating_model)
	    {
		mi.support = support;
		vi.models[model] = mi;
		db[vendor] = vi;
	    }
        }
        fclose (f);
      }
      else
        y2error ("Failed to open file with support status entries");

}

/**
 * Return the whole DB
 * /
PPD::Vendors PPD::getDB() const {
    return db;
}
*/
/**
 * Debug whole ppd db to the y2log
 */
void PPD::debugdb() const {
    y2debug("Dumping the DB...\n");

    PPD::Vendors::const_iterator it1 = db.begin ();
    for(; it1 != db.end(); it1++) {
        y2debug("  %s", it1->first.c_str());
        PPD::Models::const_iterator it2 = (*it1).second.models.begin();
        for(; it2 != (*it1).second.models.end(); it2++) {
            y2debug("    %s",it2->first.c_str());
            PPD::Drivers::const_iterator it3 = (*it2).second.drivers.begin();
            for(; it3 != (*it2).second.drivers.end(); it3++) {
                y2debug("      %s", (*it3).first.c_str());
                y2debug("      %s", (*it3).second.nickname.c_str());
            }
        }
    }
}

/**
 * Convert string to upper characters
 */
string PPD::strupper(const string s) {
    string X=s;
    for(unsigned i=0; i<X.size(); i++) X[i]=toupper(X[i]);
    return X;
}

/**
 * Kill all spaces from the start and end of the string
 */
string PPD::killspaces(const string s) {
    string tmp = s;
    signed ind = (signed) tmp.find_first_not_of(" ");
    if(ind!=-1)
        tmp = tmp.substr(ind);
    ind = (signed) tmp.find_last_not_of(" ");
    if(ind < (signed)tmp.size()-1 && tmp.size())
        tmp = tmp.substr(0,ind+1);
    return tmp;
}

/**
 * Kill the given chars from the start and end of the string
 */
string PPD::killchars(const string s, const string chr) {
    string tmp = killspaces(s);
    signed ind;

    ind = (signed) tmp.find_first_of(chr);
    if(ind==0)
        tmp.erase(0,ind+1);
    ind = (signed) tmp.find_first_of(chr);
    if((ind!=-1)&&(ind==((signed)tmp.size()-1)))
        tmp.erase(ind);

    return killspaces(tmp);
}

/**
 * Filter characters, leavo only listed ones
 */
string PPD::filternotchars(const string s, const string chr) {
    string tmp = s;
    signed ind = tmp.find_first_of(chr);
    while (ind >= 0)
    {
	tmp.erase (ind, 1);
	ind = tmp.find_first_of(chr);
    }
    return tmp;
}

#define ERR_MAX 80              // for regexp
#define SUB_MAX 10              // for regexp

/**
 * the same as YCP regexpsub builtin
 */
string PPD::regexpsub (const string input, const string pattern,
	const string result)
{
    int status;
    char error[ERR_MAX+1];

    regex_t compiled;
    regmatch_t matchptr[SUB_MAX+1];

    status = regcomp (&compiled, pattern.c_str (), REG_EXTENDED);
    if(status) {
	return "";
    }

    if(compiled.re_nsub > SUB_MAX) {
        snprintf(error, ERR_MAX, "too much subexpresions: %zd", compiled.re_nsub);
        regfree(&compiled);
	return "";
    }

    status = regexec(&compiled, input.c_str(), compiled.re_nsub+1, matchptr, 0);

    if(status) {
        regfree(&compiled);
	return "";
    }

    static const char *index[] = {
        "\\0", "\\1", "\\2", "\\3", "\\4",
        "\\5", "\\6", "\\7", "\\8", "\\9"
    };

    string input_str(input);
    string result_str(result);
    string match_str[SUB_MAX];

    for(unsigned int i=1; i<=compiled.re_nsub && i<SUB_MAX; i++) {
        match_str[i] = matchptr[i].rm_so >= 0 ? input_str.substr(matchptr[i].rm_so, matchptr[i].rm_eo - matchptr[i].rm_so) : "";

        string::size_type col = result_str.find(index[i]);
        while( col != string::npos ) {
            result_str.replace( col, 2, match_str[i]  );
            col = result_str.find(index[i], col + 1 );
        }
    }

    regfree (&compiled);
    return result_str;
}



/**
 * Kill braces (and other bad characters) from the start and end of the string
 */
string PPD::killbraces(const string s) {
    string tmp = s;
    tmp = killchars(tmp, "(");
    tmp = killchars(tmp, ")");
    tmp = killchars(tmp, "-");
    tmp = killchars(tmp, "_");
    return tmp;
}

/*
    ind = (signed) tmp.find_first_of("(");
    if(ind==0)
        tmp.erase(0,ind+1);
    ind = (signed) tmp.find_first_of(")");
    if((ind!=-1)&&(ind==((signed)tmp.size()-1)))
        tmp.erase(ind);

    return killspaces(tmp);
}
*/
    /* remove everything to the first '('
    if(ind!=-1)
        tmp.erase(0,ind+1);
    ind = (signed) tmp.find_first_of(")");
    if(ind!=-1)
        tmp.erase(ind);
    */

/**
 * Make s string from the char* and clean it from spaces and braces
 */
string PPD::clean(const char *s) {
    if(s) {
	return killbraces(string(s));
    }
    else return string("");
}

/**
 * Return the first word from the string
 */
string PPD::first(const string s, const string sep) {
    string tmp = killbraces(s);
    signed ind = (signed) tmp.find_first_of(sep);
    if(ind!=-1)
        tmp.erase(ind);
    return killbraces(tmp);
}

/**
 * Add a right brace if there is one left brace alone.
 */
string PPD::addbrace(const string s) {
    string tmp = killbraces(s);
    signed ind = (signed) tmp.find_last_of("(");
    if(ind!=-1) {
        tmp = tmp.substr(ind,tmp.size());
        if((signed)tmp.find(")") == -1) {
            //printf("xx: _%s_\n", tmp.c_str());
            return string(killbraces(s) + ")");
        }
    }
    return killspaces(s);
}

/**
 * Search given directory for ppd files and update the ppd database
 * @param dirname directory to be processed
 * @return operation succeeded
 */
bool PPD::process_dir(const char *dirname) {

    DIR *dir;
    struct dirent *entry;
    struct stat fileinfo;
    char filename[MAX];
    bool ret = true;

    y2debug("dirname=%s",dirname);
    dir = opendir(dirname);
    if(!dir) {
        y2error("opendir failed: %s (%s)", dirname, strerror(errno));
        return false;
    }

    while((entry=readdir(dir))) {
        if(entry->d_name[0]=='.')
            continue;

        snprintf(filename, sizeof(filename), "%s/%s", dirname, entry->d_name);

        if(stat(filename,&fileinfo))
            continue;

        if(S_ISDIR(fileinfo.st_mode)) {
            if(process_dir(filename)!=true)
                ret = false;
        }
        else
            if(S_ISREG(fileinfo.st_mode))
              if(process_file(filename)!=true)
                ret = false;
    }

    closedir(dir);
    return ret;
}

/**
 * Process one PPD file
 * @param filename the file to be processed
 * @return operation succeeded
 */
bool PPD::process_file(const char *filename, PPDInfo *newinfo) {
    gzFile file;
    char line[MAX]="";
    char vendor[MAX]="";
    char printer[MAX]="";
    char nick[MAX]="";
    char shortnick[MAX]="";
    char lang[MAX]="";
    char product[MAX]="";
    char pnp_vendor[MAX]="";
    char pnp_printer[MAX]="";
    char pnp_id[MAX]="";
    char filter[MAX]="";
    set<string> products;
    set<pair<string,string> > device_ids;

    y2debug("Processing: %s",filename);

    done_files++;

    const char *slash = strrchr(filename, '/');
    if(!slash) slash=filename;
    else slash++;

    if(!strncasecmp(slash,"readme",6)) {
        y2warning("skipping readme file (%s)",filename);
        return false;
    }

    file = gzopen(filename,"rb");
    if(!file) {
        y2error("open failed: %s (%s)",filename, strerror(errno));
        return false;
    }

    *line=0;
    gzgets(file, line, sizeof(line));
    if(strncmp(line,"*PPD-Adobe:",11)) {
        gzclose(file);
        y2error("not a ppd file: %s",filename);
        return false;
    }

    int ready = 0;
    while(gzgets(file, line, sizeof(line))) {
        if(!strncmp(line,"*Manufacturer:",14)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", vendor);
            ready++;
        }
        else if(!strncmp(line, "*ModelName:", 11)) {
            sscanf(line, "%*[^\"]\"%127[^\"\n]", printer);
            ready++;
        }
        else if(!strncmp(line, "*LanguageVersion:", 17)) {
            sscanf(line, "%*[^:]:%63s", lang);
            ready++;
        }
        else if(!strncmp(line, "*Product:", 9)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", product);
            ready++;
	    products.insert (clean (product));
        }
        else if(!strncmp(line, "*NickName:", 10)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", nick);
            ready++;
        }
        else if(!strncmp(line, "*ShortNickName:", 15)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", shortnick);
            ready++;
        }
        else if(!strncmp(line, "*pnpManufacturer:", 17)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", pnp_vendor);
            y2debug("pnp_v: %s",pnp_vendor);
            ready++;
        }
        else if(!strncmp(line, "*pnpModel:", 10)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", pnp_printer);
            y2debug("pnp_p: %s",pnp_printer);
            ready++;
        }
	else if(!strncmp(line, "*cupsFilter:", 12)) {
	    sscanf(line, "%*[^\"]\"%255[^\"\n]", filter);
	    char* index = rindex (filter, ' ');
	    if (index)
	    {
		strcpy (&(filter[0]), ++index);
	    }
	}
        else if(!strncmp(line, "*1284DeviceID:", 14)) {
            y2debug("%s", filename);
            int ret = sscanf(line, "%*[^\"]\"%255[^\"\n]", pnp_id);

            /* read whole multi-line id */
            if(ret<=0) {
                int count = 0;
                int size = strlen(line);
                int max = MAX - size -1;
                if(line[size-1]=='\n') line[size-1]=0;
                strncpy(pnp_id, line, MAX);
                do {
                    count++;
                    gzgets(file, line, sizeof(line));
                    y2debug("pnp_id: _%s_ line(%s) max(%d)",pnp_id,line,max);
                    size = strlen(line);
                    if(line[size-1]=='\n') line[size-1]=0;
                    strncat(pnp_id, line, max);
                    max -= size+1;
                } while(strncmp(line, "*End", 4) && max>0 && count<10);
                y2debug("WHILE(%s)",max<=0?"max":count>=10?"count":"strncmp");
            }

            int size;
            char *start, *end;
	    char vendor_id[MAX]="";
	    char device_id[MAX]="";

            /* parse vendor from id */
            if((start=strstr(pnp_id,"MANUFACTURER:"))) start+=13;
            else if((start=strstr(pnp_id,"MFG:"))) start+=4;
            else if((start=strstr(pnp_id,"MAKE:"))) start+=5;

            if(start) {
		end = strchr(start,';');
                size = end == NULL
		    ? (strlen(start) < MAX) ? strlen(start) : MAX
		    : (end-start) < MAX ? end-start : MAX;
                strncpy(vendor_id,start,size);
                y2debug("vendor_id: _%s_", vendor_id);
            }

            /* parse printer from id */
            if((start=strstr(pnp_id,"MODEL:"))) start+=6;
            else if((start=strstr(pnp_id,"MDL:"))) start+=4;
            else if((start=strstr(pnp_id,"Model:"))) start+=6;

            if(start) {
	 	end=strchr(start,';');
                size = end == NULL
		    ? (strlen(start) < MAX) ? strlen(start) : MAX
		    : (end-start) < MAX ? end-start : MAX;
                strncpy(device_id,start,size);
                y2debug("device_id: _%s_", device_id);
            }

	    pair<string,string> id = pair<string,string>(vendor_id, device_id);
	    device_ids.insert (id);
            
            y2debug("PNP: _%s_", pnp_id);
            ready+=2;
        }

        /* Got all information */
// test removed because of multiple *Product or *1284DeviceId entries
//        if(ready>7) break;
    }

    if (products.size () == 0)
	products.insert ("");

    gzclose(file);
    /* FIXME: debug
    if(strncmp(lang,"English",7))
        return true;
    else
        y2debug("lang=_%s_",lang);
    */

    PPDInfo info;
    info.filename = filename;
    info.vendor = clean(vendor);
    info.printer = removeVendorFromModel (
	getVendorId (info.vendor),
	clean(printer));
    info.vendor_db = info.vendor;
    info.printer_db = info.printer;
    info.products = products;
    info.lang = clean(lang);
    info.nick = nick;
    info.shortnick = shortnick;
    info.pnp_vendor = pnp_vendor;
    info.pnp_printer = pnp_printer;
    info.checksum = fileChecksum (filename);
    info.size = fileSize (filename);
    info.filter = filter;
    preprocess(info, newinfo);

    if (NULL == newinfo)
    {
	for (set<pair<string,string> >::iterator it = device_ids.begin ();
	    it != device_ids.end ();
	   it++)
	{
    	    info.vendor = clean (it->first.c_str ());
	    info.printer = clean (it->second.c_str ());
	    info.vendor_db = info.vendor;
	    info.printer_db = info.printer;
	    preprocess(info, newinfo);
	}
    }

    if (total_files != 0)
	creation_status = (done_files * 80) / (total_files) + 10;
    return true;
}

/**
 * Preprocess the strings, apply hacks and update the db.
 */
void PPD::preprocess(PPD::PPDInfo info, PPDInfo *newinfo) {

    string filename = info.filename;
    string vendor = killbraces(info.vendor);
    string printer = killbraces(info.printer);
    set<string> products = info.products;
    string lang = killbraces(info.lang);
    string nick = info.nick;
    string shortnick = info.shortnick;
    string pnp_vendor = info.pnp_vendor;
    string pnp_printer = info.pnp_printer;
    string filter = info.filter;
    string tmp;
    string label;
    string checksum = info.checksum;
    off_t filesize = info.size;

    y2debug ("New PPD file");

    /* Prepare vendor */
    if(vendor=="ESP") vendor = "";
    if(vendor=="") vendor = printer;
    vendor = strupper(vendor);

    if(vendors_map.find(vendor)!=vendors_map.end()) {
        y2debug("1: %s",vendor.c_str());
        vendor = vendors_map[vendor];
    }
    else {
        tmp = strupper(first(nick));
        y2debug("7: %s",tmp.c_str());
        if(vendors_map.find(tmp)!=vendors_map.end()) {
            y2debug("7: %s",tmp.c_str());
            vendor = vendors_map[tmp];
        }
        else {
            tmp = strupper(first(printer," "));
            y2debug("2: %s",printer.c_str());
            y2debug("2: %s",tmp.c_str());
            if(vendors_map.find(tmp)!=vendors_map.end()) {
                y2debug("2: %s",tmp.c_str());
                vendor = vendors_map[tmp];
            }
            else {
                tmp = strupper(first(printer));
                y2debug("3: %s",tmp.c_str());
                if(vendors_map.find(tmp)!=vendors_map.end()) {
                    y2debug("3: %s",tmp.c_str());
                    vendor = vendors_map[tmp];
                }
                else {
                    tmp = strupper(first(printer," "));
                    y2debug("4: %s",printer.c_str());
                    y2debug("4: %s",tmp.c_str());
                    if(vendors_map.find(tmp)!=vendors_map.end()) {
                        y2debug("4: %s",tmp.c_str());
                        vendor = vendors_map[tmp];
                    }
                    else {
                        tmp = strupper(first(printer));
                        y2debug("5: %s",tmp.c_str());
                        if(vendors_map.find(tmp)!=vendors_map.end()) {
                            y2debug("5: %s",tmp.c_str());
                            vendor = vendors_map[tmp];
                        }
                        else {
                            tmp = strupper(first(nick," "));
                            y2debug("6: %s",nick.c_str());
                            y2debug("6: %s",tmp.c_str());
                            if(vendors_map.find(tmp)!=vendors_map.end()) {
                                y2debug("6: %s",tmp.c_str());
                                vendor = vendors_map[tmp];
                            }
                            else {
                                y2debug("8: _%s_", tmp.c_str());
				vendor = getVendorId (vendor);
//                                vendor = "";
                            }
                        }
                    }
                }
            }
        }
    }

    vendor = strupper(vendor);
    vendor = killbraces(vendor);
    if(vendor=="") vendor = "Other";

    /* Prepare printer */ //-- product first*/
    string orig_printer = printer;
    if (validateModel (vendor, printer))
    {}
    else if (validateModel (vendor, shortnick))
	printer = shortnick;
    else if (validateModel (vendor, nick))
        printer = nick;

    /* remove ", Foomatic..." from printer name */
    int br = printer.find (", ");
    if (br > 0)
	printer = printer.substr (0, br);


    set<string>::const_iterator products_it = products.begin ();
    string product = killbraces (*products_it);

    /* special vendor/printer hacks */
    if(vendor=="CANON" && strupper(first(product," "))=="BIRMY")
        vendor="BIRMY";
    if(vendor=="FUJI" && strupper(first(printer," "))=="XEROX")
        vendor="XEROX";
    if(strupper(first(printer," "))=="DATAPRODUCTS")
        vendor="DATAPRODUCTS";
    if(strupper(first(printer," "))=="HITACHI")
        vendor="HITACHI";

    /* prepare nick */
    if (nick == "")
	nick = shortnick;
    if (nick == "")
	nick = filename;
    nick = addbrace(nick);

//    if(lang!="English")
//        nick = nick+" ("+lang+")";

    /* Modify the model db key */
    signed ind = (signed) printer.find_last_of("(");
    if(ind!=-1) 
    {
	printer.erase(ind, printer.size());
    }
    printer = killbraces(printer);
    if (strupper (printer.substr (0, 10)) == "GIMP-PRINT")
	printer = shortnick;
    else if (strupper (printer.substr (0,5)) == "CUPS ")
	printer = shortnick;
    else if (strupper (printer) == "UNKNOWN")
	printer = orig_printer;
    else if (strupper (printer) == "SEE NOTES")
	printer = shortnick;
    ind = (signed) printer.find_last_of("(");
    if(ind!=-1)
    {
        printer.erase(ind, printer.size());
    }
    printer = killbraces(printer);
    if (printer == "")
	label = printer = filename;
    else
	/* Save label for the printer */
	label = printer; //FIXME if will want to generate label other way

    /* differentiate drivers with same nick */
    bool space = true;
    printer = getModelId (vendor, printer);
// FIXME may not exist in the map
    Drivers nicks = db[vendor].models[printer].drivers;
    for(; nicks.find(nick)!=nicks.end(); nick+="I")
      if(space) {
        nick += " ";
        space = false;
      }

    /* prepare pnp information */
    if(strupper(first(pnp_vendor))=="UNKNOWN") pnp_vendor="";
    if(strupper(first(pnp_printer))=="UNKNOWN") pnp_printer="";

    if(strupper(killbraces(pnp_vendor))=="SEE NOTES") pnp_vendor="";
    if(strupper(killbraces(pnp_printer))=="SEE NOTES") pnp_printer="";


    if (! newinfo)
    {
	y2debug ("Adding printer %s to database with filename %s",
	    printer.c_str (),
	    filename.c_str ());
        /* Info item = filename; */
        DriverInfo item;
        item.nickname = nick;
        item.pnp_vendor = pnp_vendor;
        item.pnp_printer = pnp_printer;
	item.checksum = checksum;
	item.size = filesize;
	item.filter = filter;
	item.language = lang;
	bool updating_model = false;
	VendorInfo vi;
	if (db.find (vendor) != db.end ())
	    vi = db[vendor];
	ModelInfo mi;
	if (vi.models.find(printer) != vi.models.end ())
	{
	    updating_model = true;
	    mi = vi.models[printer];
	}

        /* Set the label */
	signed size = vendor.size() + 1;
	if(strupper(label.substr(0,size))==vendor+" ") label.erase(0,size);

        signed ind = (signed) label.find_last_of("(");
        if(ind!=-1) label.erase(ind, label.size());
        label = killbraces(label);
	if (label == "")
	    label = printer;
	label = updateLabel (label);

        if (((mi.label == "" || mi.label.size () > label.size ()))
	    && label.size () > 0)
        {
	    string old_label = mi.label;
	    bool old_fuzzy = mi.fuzzy_label;
	    bool new_fuzzy
		= modellabels[vendor].find(label) != modellabels[vendor].end();
	    if (new_fuzzy && (old_fuzzy || old_label == ""))
	    {
		y2error ("Same labels present in multiple PPD files - %s",
		    label.c_str());
		bool blank = true;
		while (modellabels[vendor].find(label)
		    != modellabels[vendor].end())
		{
		    if (blank)
		    {
			blank = false;
			label = label + " ";
		    }
		    label = label + "I";
		}
	    }
	    if (old_fuzzy || old_label == "" || ! new_fuzzy)
	    {
		mi.label = label;
		mi.fuzzy_label = new_fuzzy;
		if (modellabels[vendor].find (old_label)
		    != modellabels[vendor].end()
		    && updating_model)
		{
		    modellabels[vendor].erase(old_label);
		    y2milestone ("Removed label %s, replacing with %s", old_label.c_str(), mi.label.c_str());
		}
		modellabels[vendor].insert(mi.label);
		y2debug ("Inserted label %s", mi.label.c_str());
	    }
        }

	mi.drivers[filename] = item;
	vi.models[printer] = mi;
	db[vendor] = vi;

	y2debug("File: %s", filename.c_str());
	y2debug("  Vendor: %s", vendor.c_str());
	y2debug("  Printer: %s",printer.c_str());
	y2debug("  Nick: %s",nick.c_str());
    }

    /* finally, update the DB or newinfo (if not NULL) */
    
    if(newinfo) {
        newinfo->filename = filename;
	newinfo->vendor = info.vendor;
	newinfo->printer = info.printer;
        newinfo->vendor_db = vendor;
        newinfo->printer_db = printer;
        newinfo->lang = lang;
        newinfo->nick = nick;
	newinfo->shortnick = shortnick;
        newinfo->pnp_vendor = pnp_vendor;
        newinfo->pnp_printer = pnp_printer;
	newinfo->checksum = checksum;
	newinfo->size = filesize;
	newinfo->filter = filter;

	y2debug("File: %s", filename.c_str());
	y2debug("  Vendor: %s", vendor.c_str());
	y2debug("  Printer: %s",printer.c_str());
	y2debug("  Nick: %s",nick.c_str());
    }
}

bool PPD::validateModel (string vendor, string printer) {
    string model = getModelId (vendor, printer);

    /* test size */
    if (model.size () > 0)
	return true;
    return false;
}

bool PPD::loadPrebuiltDatabase () {
    Parser parser;

    FILE *infile = fopen (ppd_db, "r");
    if (! infile)
    {
	y2error ("Unable to open current database file");
	return false;
    }

    parser.setInput (infile, ppd_db);
    parser.setBuffered ();

    YCodePtr parsed_code = parser.parse ();
    YCPValue val = YCPNull ();
    if (parsed_code != NULL)
    {
	val = parsed_code->evaluate (true);
    }
    else
    {
	return false;
    }
    bool ret = true;

    if ((! val.isNull ()) && val->isMap ())
    {
	y2milestone ("Database file parsed correctly by YCP parser");
	YCPMap m = val->asMap ();
	for (YCPMapIterator it1 = m->begin (); it1 != m->end (); it1++)
	{
	    if (it1.key().isNull() || ! it1.key()->isString())
	    {
		y2error ("Incorrect database format");
		goto error_exit;
	    }
	    VendorKey vk = string (it1.key()->asString()->value_cstr());
            if (it1.value().isNull() || ! it1.value()->isMap())
            {
                y2error ("Incorrect database format");
                goto error_exit;
            }
	    YCPMap vm = it1.value()->asMap();
	    VendorInfo vi;
	    for (YCPMapIterator it2 = vm->begin (); it2 != vm->end (); it2++)
	    {
		if ((! it2.key().isNull ()) && it2.key()->isString ())
		{
		    ModelKey mk = string (it2.key()->asString()->value_cstr());

		    if (it2.value().isNull() || ! it2.value()->isMap())
		    {
			y2error ("Incorrect database format");
			goto error_exit;
		    }
		    YCPMap mm = it2.value()->asMap();
		    ModelInfo mi;
		    // process model
		    for (YCPMapIterator it3 = mm->begin ();
			it3 != mm->end (); it3++)
		    {
			if ((! it2.key().isNull()) && it3.key()->isString ())
			{
			    string config = it3.key()->asString()->value_cstr();
	                    if (it3.value().isNull() || ! it3.value()->isMap())
	                    {
	                        y2error ("Incorrect database format");
	                        goto error_exit;
	                    }

			    YCPMap info = it3.value()->asMap();
			    DriverInfo di;
			    for (YCPMapIterator it4 = info->begin ();
				it4 != info->end (); it4++)
			    {
				if (it4.key().isNull()
				    || ! it4.key()->isString()
				    || it4.value().isNull ())
				{
				    y2error ("Incorrect database format");
				    goto error_exit;
				}
				string ak = it4.key()->asString()->value_cstr();
				if (ak == "nickname")
				{
				    if (! it4.value()->isString ())
				    {
					y2error ("Incorrect database format");
					goto error_exit;
				    }
				    di.nickname = it4.value()->asString()
					->value_cstr();
				}
                                else if (ak == "pnp_vendor")
                                {
                                    if (! it4.value()->isString ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.pnp_vendor = it4.value()->asString()
                                        ->value_cstr();
                                }
                                if (ak == "pnp_printer")
                                {
                                    if (! it4.value()->isString ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.pnp_printer = it4.value()->asString()
                                        ->value_cstr();
                                }
                                if (ak == "checksum")
                                {
                                    if (! it4.value()->isString ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.checksum = it4.value()->asString()
                                        ->value_cstr();
                                }
                                if (ak == "size")
                                {
                                    if (! it4.value()->isInteger ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.size = it4.value()->asInteger()->value();
                                }
                                if (ak == "filter")
                                {
                                    if (! it4.value()->isString ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.filter = it4.value()->asString()
                                        ->value_cstr();
                                }
                                if (ak == "language")
                                {
                                    if (! it4.value()->isString ())
                                    {
                                        y2error ("Incorrect database format");
                                        goto error_exit;
                                    }
                                    di.language = it4.value()->asString()
                                        ->value_cstr();
                                }
			    }
			    mi.drivers[config] = di;
			}
			else
			{
			    if (it3.key().isNull() || ! it3.key()->isSymbol())
			    {
	                        y2error ("Incorrect database format");
                                goto error_exit;
			    }
			    string attrib = it3.key()->asSymbol()->toString();
			    if (attrib == "`label")
			    {
				if (it3.value().isNull() ||
				    ! it3.value()->isString())
				{
				    y2error ("Incorrect database format");
				    goto error_exit;
				}
				mi.label
				    = it3.value()->asString()->value_cstr();
			    }
			    else if (attrib == "`support")
			    {
                                if (it3.value().isNull() ||
                                    ! it3.value()->isString())
                                {
                                    y2error ("Incorrect database format");
                                    goto error_exit;
                                }
				mi.support = it3.value()->asString()->value_cstr();
			    }
                            else if (attrib == "`mcomment")
                            {
                                if (it3.value().isNull() ||
                                    ! it3.value()->isString())
                                {
                                    y2error ("Incorrect database format");
                                    goto error_exit;
                                }
                                string tmp 
                                    = it3.value()->asString()->value_cstr();
                                mi.mcomment = "";
                                for (string::const_iterator i = tmp.begin (); 
                                    i != tmp.end (); i++)
                                {
                                    if (*i == '\\' || *i == '\"')
                                        mi.mcomment = mi.mcomment + '\\';
                                    mi.mcomment = mi.mcomment + *i;
                                }
                            }
			}
			y2debug ("Inserted label %s", mi.label.c_str());
			modellabels[vk].insert (mi.label);
		    }

		    vi.models[mk] = mi;
		}
		else
		{
                    if (it2.key().isNull() || ! it2.key()->isSymbol())
                    {
                        y2error ("Incorrect database format");
                        goto error_exit;
                    }

		    if (it2.key()->asSymbol()->toString() == "`label")
		    {
                        if (it2.value().isNull() ||
                            ! it2.value()->isString())
                        {
                            y2error ("Incorrect database format");
                            goto error_exit;
                        }

			vi.label = it2.value()->asString()->value_cstr();
		    }
		    else if (it2.key()->asSymbol()->toString() == "`vcomment")
		    {
			if (it2.value().isNull() ||
			    ! it2.value()->isString())
			{
			    y2error ("Incorrect database format");
			    goto error_exit;
			}
			string tmp = it2.value()->asString()->value_cstr();
			vi.vcomment = "";
			for (string::const_iterator i = tmp.begin ();
			    i != tmp.end (); i++)
			{
			    if (*i == '\\' || *i == '\"')
				vi.vcomment = vi.vcomment + '\\';
			    vi.vcomment = vi.vcomment + *i;
			}
		    }
		}
	    }
	    db[vk] = vi;
	}
    }
    else
    {	
	y2error ("Incorrect database file structure");
	goto error_exit;
    }

    y2milestone ("Database contents is OK");
    fclose (infile);
    return ret;

error_exit:
    fclose (infile);
    db = Vendors ();
    return false;
}

/**
 * Creates a list of files with attrubutes about modification dates
 */
bool PPD::createFileList(const char *dirname, time_t mtime) {
    bool dir_changed = false;


    DIR *dir;
    struct dirent *entry;
    struct stat fileinfo;
    char filename[MAX];

    dir = opendir(dirname);
    if(!dir) {
        y2error("opendir failed: %s (%s)", dirname, strerror(errno));
        return false;
    }

    if (stat (dirname, &fileinfo))
    {
	closedir(dir);
	return false;
    }

    if (fileinfo.st_mtime >= mtime || fileinfo.st_ctime >= mtime)
	dir_changed = true;

    while((entry=readdir(dir))) {
	bool file_changed = false;
        if(entry->d_name[0]=='.') // parent dir, this dir ot begins with dor
            continue;

        snprintf(filename, sizeof(filename), "%s/%s", dirname, entry->d_name);

        if(stat(filename, &fileinfo))
	{
	    closedir(dir);
            return false;
	}

        if(fileinfo.st_mtime >= mtime || fileinfo.st_ctime >= mtime)
	    file_changed = true;

        if(S_ISDIR(fileinfo.st_mode))
	{
	    if (! createFileList (filename, mtime))
	    {
		closedir(dir);
		return false;
	    }
	    continue;
	}

	PpdFileInfo info;
	info.file_newer = file_changed;
	info.dir_newer = dir_changed;
	ppdfiles[filename] = info;
    }

    closedir(dir);
    return true;
}

bool PPD::cleanupLists () {
    PPD::Vendors::iterator it1 = db.begin ();
    for(; it1 != db.end(); it1++) {
        PPD::Models::iterator it2 = (*it1).second.models.begin();
        for(; it2 != (*it1).second.models.end(); it2++) {
            PPD::Drivers::iterator it3;
driver_init:
	    it3 = (*it2).second.drivers.begin();
            while(it3 != (*it2).second.drivers.end()){
y2debug("it3 cycle");
		DriverInfo di = it3->second;
		string driver_name = di.nickname;
		string filename = it3->first;
		PPD::PpdFiles::iterator it4 = ppdfiles.find(filename);
		if (it4 == ppdfiles.end())
		{ // no more existing file
		    y2debug ("Erasing file %s", driver_name.c_str());
		     (*it2).second.drivers.erase (filename);
		y2debug("goto driver_init");
			goto driver_init;
		}
		else if (it4->second.dir_newer || it4->second.file_newer)
		{ // parent dir changed or file changed,
		  // check MD5 or size for being sure
		    if (fast_check)
		    {
			off_t size = fileSize (filename);
			if (size != di.size)
			{
			    y2debug ("Erasing 1 %s", driver_name.c_str());
			    (*it2).second.drivers.erase (driver_name);
//			    goto driver_init;
			}
			else
			{
			    ppdfiles[filename].update = false;
			}
		    }
		    else
		    {
			string checksum = fileChecksum (filename);
			if (checksum != di.checksum)
			{
			    y2debug ("Erasing 2 %s", driver_name.c_str());
			    (*it2).second.drivers.erase (driver_name);
//			    goto driver_init;
			}
		        else
			{
			    ppdfiles[filename].update = false;
			}
		    }
		}
		else
		{ // not changed, we can ignore it
		    ppdfiles[filename].update = false;
		}
		it3++;
            }
        }
    }
    return true;
}

bool PPD::processNewFiles () {
    bool ret = true;
    for (PPD::PpdFiles::iterator it = ppdfiles.begin(); it != ppdfiles.end ();
	it++)
    {
	if (! (*it).second.update)
	{
	    done_files++;
	    continue;
	}

	struct stat fileinfo;
	string filename = it->first;

        if(stat(filename.c_str(),&fileinfo))
            continue;

        if(S_ISDIR(fileinfo.st_mode)) {
	    y2warning ("Directory appeared in PPD files list");
	    continue;
        }
        else if(S_ISREG(fileinfo.st_mode))
	{
	    if(process_file(filename.c_str())!=true)
	    {
		y2error ("Failed processing filename %s", filename.c_str());
                ret = false;
	    }
	}
    }
    return ret;
}

bool PPD::cleanupEmptyEntries () {
    vector<string> vendors_to_delete = vector<string> ();
    PPD::Vendors::iterator it1 = db.begin ();
    for(; it1 != db.end(); it1++) {
	vector<string> models_to_delete = vector<string> ();
        PPD::Models::iterator it2 = (*it1).second.models.begin();
        for(; it2 != (*it1).second.models.end(); it2++) {
	    if ((*it2).second.drivers.begin() == (*it2).second.drivers.end())
	    {
		models_to_delete.push_back ((*it2).first);
	    }
        }
	vector<string>::iterator dit = models_to_delete.begin ();
	for (; dit != models_to_delete.end (); dit++)
	{
	    (*it1).second.models.erase (*dit);
	}
	if ((*it1).second.models.begin() == (*it1).second.models.end())
	{
	    vendors_to_delete.push_back ((*it1).first);
	}
    }
    vector<string>::iterator dit = vendors_to_delete.begin ();
    for (; dit != vendors_to_delete.end (); dit++)
    {
	db.erase (*dit);
    }
    return true;
}

string PPD::fileChecksum (const string &filename) {
    FILE* f;
    char buf[16] __attribute__ ((aligned));
    char sum[33];
    string ret = "";

    f = fopen (filename.c_str(), "r");
    if (f)
    {
	if (! md5_stream (f, buf))
	{
	    for (int i = 0 ; i < 16 ; i++)
	    {
		sprintf (sum+2*i, "%02x", (unsigned char) buf[i]);
	    }
	    ret = sum;
	}
	fclose (f);
    }
    return ret;
}

off_t PPD::fileSize (const string &filename) {
    off_t size = 0;
    struct stat fileinfo;
    if (! lstat (filename.c_str(), &fileinfo))
	size = fileinfo.st_size;
    return size;
}

bool PPD::setCheckMethod (YCPSymbol method) {
    string s = method->toString ();
    if (s == "`size")
    {
	y2milestone ("Setting PPD files checking to size only");
	fast_check = true;
	return true;
    }
    else if (s == "`checksum")
    {
	y2milestone ("Setting PPD files checking to checksum");
	fast_check = false;
	return true;
    }
    return false;
}

string PPD::updateLabel (const string& label) {
    if (strupper (label.substr (0, 7)) == "DESKJET")
	return "DeskJet" + label.substr (7);
    if (strupper (label.substr (0, 8)) == "LASERJET")
        return "LaserJet" + label.substr (8);
    if (strupper (label.substr (0, 9)) == "OFFICEJET")
        return "OfficeJet" + label.substr (9);
    if (strupper (label.substr (0, 10)) == "PHOTOSMART")
        return "PhotoSmart" + label.substr (10);
    if (strupper (label.substr (0, 12)) == "STYLUS COLOR")
        return "Stylus Color" + label.substr (12);
    return label;
}

struct ltstr {
    bool operator()(const string& s1, const string& s2) const
    {
	return strcoll(s1.c_str(), s2.c_str()) < 0;
    }
};

YCPList PPD::sortItems (const YCPMap& items) {
    map<string, string, ltstr> listmap;
    YCPMapIterator it1 = items->begin();
    for (; it1 != items->end(); it1++)
    {
	YCPValue k = it1.key();
	YCPValue v = it1.value();
	if (v->isString () && k->isString ())
	{
	    string val = v->asString ()->value();
	    string key = k->asString ()->value();
	    listmap[val] = key;
	}
    }
    YCPList ret;
    map<string, string, ltstr>::const_iterator it = listmap.begin();
    for (; it != listmap.end(); it++)
    {
	YCPTerm k = YCPTerm ("id");// FIXME if corrected wrong, true);
	k->add (YCPString (it->second));
	YCPTerm item = YCPTerm ("item");// FIXME if corrected wrong, true);
	item->add (k);
	item->add (YCPString (it->first));
	ret->add (item);
    }
    return ret;
}

/* EOF */
