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

#ifndef _PPDdb_h
#define _PPDdb_h

#include <sys/types.h>

#include <string>
#include <list>
#include <map>
#include <vector>
#include <set>

using namespace std;

#define MAX        2048
#define WHITESPACE " \t\n"

#define PPD_DIR "/usr/share/cups/model"
#define PPD_DB  "/var/lib/YaST2/ppd_db.ycp"

class PPD {
    public:

        class PPDInfo {
            public:
                string filename;
                string vendor;
                string printer;
                set<string> products;
                string nick;
		string shortnick;
                string lang;
                string pnp_vendor;
                string pnp_printer;
		string checksum;
		off_t size;
		string filter;
		string vendor_db;
		string printer_db;
        };

        typedef string VendorKey;
        typedef string ModelKey;
        typedef string DriverKey;

        /* typedef string Info; */
        class DriverInfo {
            public:
                string filename;
                string pnp_vendor;
                string pnp_printer;
		string checksum;
		off_t size;
		string filter;
	    DriverInfo () {
		filename = "";
		pnp_vendor = "";
		pnp_printer = "";
		checksum = "";
		size = 0;
		filter = "";
	    }
        };

	typedef map<DriverKey, DriverInfo> Drivers;

	class ModelInfo {
	    public:
		string label;
		string support;
		string mcomment;
		Drivers drivers;
		bool fuzzy_label;
	    ModelInfo () {
		support = "";
		label = "";
		mcomment = "";
		fuzzy_label = false;
	    }
	};

	typedef map<ModelKey, ModelInfo> Models;

	class VendorInfo {
	    public:
		string label;
		string vcomment;
		Models models;
	    VendorInfo () {
		label = "";
		vcomment = "";
		models = Models ();
	    }
	};

	typedef map<VendorKey, VendorInfo> Vendors;

        class PpdFileInfo {
            public:
                bool file_newer;
                bool dir_newer;
		bool update;
            PpdFileInfo () {
                file_newer = "";
                dir_newer = "";
		update = true;
            }
        };

	typedef map<string, PpdFileInfo> PpdFiles;

	typedef map<VendorKey, set<string> > ModelLabels;
	typedef set<string> VendorLabels;

        PPD(const char *ppddir = PPD_DIR, const char *ppddb = PPD_DB);
        ~PPD();

        bool createdb();
	static void* startCreatedbThread (void* instance);
	void* createdbThread (const char* filename);
	int  creationStatus ();
        bool changed(int *count);
	string getVendorId (string vendor);
	string getModelId (string vendor, string model);
	bool fileinfo(const char *file, PPDInfo *info);
	bool setCheckMethod (YCPSymbol method);
	YCPList sortItems (const YCPMap& items);

    private:
	friend class PPDfile;

        Vendors db;
	PpdFiles ppdfiles;
	ModelLabels modellabels;
	VendorLabels vendorlabels;

	string datadir;
	string var_datadir;
        char ppd_dir[MAX];
        char ppd_db[MAX];
        time_t mtime;

	typedef map<string, string> VendorsMap;
	VendorsMap vendors_map;
	typedef map<string, vector<pair <string, string> > > ModelsMap;
	ModelsMap models_map;

        bool mtimes(const char *dirname, time_t mtime, int *count);
	int  countFiles (const char *dirname);
        bool process_dir(const char *dirname);
        bool process_file(const char *filename, PPDInfo *newinfo = NULL);
        void preprocess(PPDInfo info, PPDInfo *newinfo);
	void addAdditionalInfo ();
        void debugdb() const;
	// creation status variables
	volatile int creation_status;
	volatile int total_files;
	volatile int done_files;
	bool fast_check;

	bool loadPrebuiltDatabase ();
	bool createFileList(const char *dirname, time_t mtime);
	bool cleanupLists ();
	bool processNewFiles ();
	bool cleanupEmptyEntries ();
	string fileChecksum (const string &filename);
	off_t fileSize (const string &filename);
	string updateLabel (const string& label);

    protected:
        string strupper(const string s);
        string killchars(const string s, const string chr);
        string killspaces(const string s);
        string killbraces(const string s);
        string addbrace(const string s);
        string first(const string s, const string sep = " -/");
        string clean(const char *s);
	string filternotchars(const string s, const string chr);
	string regexpsub (const string input, const string pattern,
		const string result);
	bool validateModel (const string vendor, const string printer);
};

#endif /* _PPDdb_h */

