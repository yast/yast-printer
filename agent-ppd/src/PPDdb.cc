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
#include <cups/ppd.h>
#include <zlib.h>
#include <ctype.h>

#include <map>
#include <string>

/*
    TODO
    - fix all FIXME
    - update only changed files
*/

#ifndef _DEVEL_

#include "ycp/y2log.h"
#include "PPDdb.h"

/*****************************************************************/

#undef y2debug
#define y2debug(format, args...)

#else
#define y2debug(format, args...) //fprintf(stderr, format "\n" , ##args)
#define y2warning(format, args...) fprintf(stderr, format "\n" , ##args)
#define y2error(format, args...) fprintf(stderr, format "\n" , ##args)

#include "PPDdb.h"
#endif

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

    /* Load strings mappings */
    #include "PPDVendors.h"

    /* Add all known vendors */
    for(i=0;(v=array_all[i]);i++)
        vendors_map[string(v)]=string(v);

    /* Add special vendors hacks */
    for(i=0;(v=array_map[i].key);i++)
        vendors_map[string(v)]=string(array_map[i].val);

    for (i=0;(v=array_model_map[i].key);i++)
    {
	map <string, string> vend;
	if(models_map.find(v)!=models_map.end())
	    vend = models_map[v];
	vend[string(array_model_map[i].key)] = string(array_model_map[i].val);
	models_map[string(v)]=vend;
    }

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

string PPD::getVendorId (string vendor) {
    if(vendors_map.find(vendor)!=vendors_map.end()) {
	vendor = vendors_map[vendor];
    }
    return vendor;
}

/**
 * Check modification times in the given directory
 */
bool PPD::mtimes(const char *dirname, time_t mtime, int *count) {

    DIR *dir;
    struct dirent *entry;
    struct stat fileinfo;
    char filename[MAX];

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

        if(fileinfo.st_mtime >= mtime) {
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
    return ((PPD*)instance) -> createdbThread ();
}

/**
 * Create a database of all ppd files in the /var/lib/YaST2/ppd_db.ycp
 * @return operation succeeded
 */
void* PPD::createdbThread() {
    bool f1 = false;
    bool f2 = false;
    bool f3 = false;
    char str[3] = "x\n";
//    bool ret = true;
    void* ret = (void*)1;

    total_files = countFiles (ppd_dir);
    done_files = 0;

    FILE *file;
    file = fopen(ppd_db,"w");
    if(!file) {
        y2error("Error opening ppd db (%s)", strerror(errno));
	creation_status = -1; //FIXME UNLOCK
        return NULL;//false;
    }

    creation_status = 10;

    if(process_dir(ppd_dir)!=true) {
        y2error("Error during creation of ppd db");
        ret = NULL;//false;  // FIXME (return) // LOCK unlock
    }

    creation_status = 90;

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
	fprintf(file,"    `label : \"%s\",\n", it1->first.c_str());
        PPD::Models::const_iterator it2 = (*it1).second.begin();
        for(f2 = true; it2 != (*it1).second.end(); it2++) {
            F(f2) fprintf(file,str);
            fprintf(file,"    \"%s\" : $[\n",strupper(it2->first).c_str());
	    fprintf(file,"      `label : \"%s\",\n", it2->first.c_str());
            PPD::Drivers::const_iterator it3 = (*it2).second.begin();
            for(f3 = true; it3 != (*it2).second.end(); it3++) {
                F(f3) fprintf(file,str);
                fprintf(file,"      \"%s\"", (*it3).first.c_str());
                fprintf(file," : [\n");
                fprintf(file,"        \"%s\",\n", (*it3).second.filename.c_str());
                fprintf(file,"        \"%s\",\n", (*it3).second.pnp_vendor.c_str());
                fprintf(file,"        \"%s\"\n", (*it3).second.pnp_printer.c_str());
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
        PPD::Models::const_iterator it2 = (*it1).second.begin();
        for(; it2 != (*it1).second.end(); it2++) {
            y2debug("    %s",it2->first.c_str());
            PPD::Drivers::const_iterator it3 = (*it2).second.begin();
            for(; it3 != (*it2).second.end(); it3++) {
                y2debug("      %s", (*it3).first.c_str());
                y2debug("      %s", (*it3).second.filename.c_str());
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
    char lang[MAX]="";
    char product[MAX]="";
    char pnp_vendor[MAX]="";
    char pnp_printer[MAX]="";
    char pnp_id[MAX]="";

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
        }
        else if(!strncmp(line, "*NickName:", 10)) {
            sscanf(line, "%*[^\"]\"%255[^\"\n]", nick);
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

            /* parse vendor from id */
            if((start=strstr(pnp_id,"MANUFACTURER:"))) start+=13;
            else if((start=strstr(pnp_id,"MFG:"))) start+=4;

            if(start && (end=strchr(start,';'))) {
                size=(end-start)<MAX?end-start:MAX;
                strncpy(pnp_vendor,start,size);
                y2debug("pnp_vendor: _%s_", pnp_vendor);
            }

            /* parse printer from id */
            if((start=strstr(pnp_id,"MODEL:"))) start+=6;
            else if((start=strstr(pnp_id,"MDL:"))) start+=4;

            if(start && (end=strchr(start,';'))) {
                size=(end-start)<MAX?end-start:MAX;
                strncpy(pnp_printer,start,size);
                y2debug("pnp_printer: _%s_", pnp_printer);
            }
            
            y2debug("PNP: _%s_", pnp_id);
            ready+=2;
        }

        /* Got all information */
        if(ready>6) break;
    }

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
    info.printer = clean(printer);
    info.product = clean(product);
    info.lang = clean(lang);
    info.nick = nick;
    info.pnp_vendor = pnp_vendor;
    info.pnp_printer = pnp_printer;
    preprocess(info, newinfo);

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
    string product = killbraces(info.product);
    string lang = killbraces(info.lang);
    string nick = info.nick;
    string pnp_vendor = info.pnp_vendor;
    string pnp_printer = info.pnp_printer;
    string tmp;

    /* Prepare vendor */
    if(vendor=="ESP") vendor = "";
    if(vendor=="") vendor = product;
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
            tmp = strupper(first(product," "));
            y2debug("2: %s",product.c_str());
            y2debug("2: %s",tmp.c_str());
            if(vendors_map.find(tmp)!=vendors_map.end()) {
                y2debug("2: %s",tmp.c_str());
                vendor = vendors_map[tmp];
            }
            else {
                tmp = strupper(first(product));
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

    /* Prepare printer */
    signed ind;
    signed size = vendor.size();
    if(strupper(printer.substr(0,size))==vendor) printer.erase(0,size);
    printer = killbraces(printer);

    ind = (signed) printer.find_last_of("(");
    if(ind!=-1) printer.erase(ind, printer.size());
    printer = killbraces(printer);

    /* model not found -- use nick */
    if(printer=="") printer = killbraces(nick);

    if(strupper(printer.substr(0,size))==vendor) printer.erase(0,size);
    printer = killbraces(printer);

    ind = (signed) printer.find_last_of("(");
    if(ind!=-1) printer.erase(ind, printer.size());
    printer = killbraces(printer);
    if(printer=="") printer = "Other";

    /* remove ", Foomatic..." from printer name */
    int br = printer.find (", ");
    if (br > 0)
	printer = printer.substr (0, br);

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
    nick = addbrace(nick);

    if(lang!="English")// return; // FIXME (not needed any more)
        nick = nick+" ("+lang+")";

    /* differentiate drivers with same nick */
    bool space = true;
    Drivers nicks = db[vendor][printer];
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

    /* finally, update the DB or newinfo (if not NULL) */
    
    if(newinfo) {
        newinfo->filename = filename;
        newinfo->vendor = vendor;
        newinfo->printer = printer;
        newinfo->product = product;
        newinfo->lang = lang;
        newinfo->nick = nick;
        newinfo->pnp_vendor = pnp_vendor;
        newinfo->pnp_printer = pnp_printer;
    }
    else {
        /* Info item = filename; */
        Info item;
        item.filename = filename;
        item.pnp_vendor = pnp_vendor;
        item.pnp_printer = pnp_printer;
        db[vendor][printer][nick]=item;
    }

    y2debug("File: %s", filename.c_str());
    y2debug("  Vendor: %s", vendor.c_str());
    y2debug("  Printer: %s",printer.c_str());
    y2debug("  Nick: %s",nick.c_str());
}

/*
    int i,j;
    ppd_file_t *ppd;
    ppd = ppdOpenFile("/usr/share/cups/model/Canon/BJC-6100-stp.ppd");

    y2debug("Nickname: %s",ppd->nickname);
    y2debug("Short nickname: %s",ppd->shortnickname);
    y2debug("Language: %s",ppd->lang_version);
    y2debug("Language encoding: %s",ppd->lang_encoding);
    y2debug("Model number: %d",ppd->model_number);
    y2debug("Manufacturer: %s",ppd->manufacturer);
    y2debug("Modelname: %s",ppd->modelname);
    y2debug("Product: %s",ppd->product);
    y2debug("Color device: %d",ppd->color_device);
    y2debug("Throughput: %d",ppd->throughput);

    y2debug("");
    y2debug("UI groups: %d",ppd->num_groups);
    for(i=0; i<ppd->num_groups; i++) {
        y2debug("  %s: %d,%d",ppd->groups[i].text,ppd->groups[i].num_options,ppd->groups[i].num_subgroups);
        for(j=0;j<ppd->groups[i].num_options;j++)
            y2debug("    %s: %s",ppd->groups[i].options[j].keyword,ppd->groups[i].options[j].text);
    }

    ppdClose(ppd);

    return 0;
}
*/

/* EOF */
