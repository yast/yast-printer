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
	    DriverInfo () {
		filename = "";
		pnp_vendor = "";
		pnp_printer = "";
		checksum = "";
	    }
        };

	typedef map<DriverKey, DriverInfo> Drivers;

	class ModelInfo {
	    public:
		string label;
		int support;
		string mcomment;
		Drivers drivers;
	    ModelInfo () {
		support = -1;
		label = "";
		mcomment = "";
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

    private:
        Vendors db;
	PpdFiles ppdfiles;

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
        void debugdb() const;
	// creation status variables
	volatile int creation_status;
	volatile int total_files;
	volatile int done_files;

	bool loadPrebuiltDatabase ();
	bool createFileList(const char *dirname, time_t mtime);
	bool cleanupLists ();
	bool processNewFiles ();
	bool cleanupEmptyEntries ();
	string fileChecksum (const string &filename);

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

