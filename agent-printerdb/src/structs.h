#ifndef __STRUCTS_H__
#define __STRUCTS_H__

#include <string>
#include "suseprinterdb.h"

#define DB_ERROR(format, args...)  spdbReportError (__LINE__, __FILE__, __FUNCTION__, format, ##args)

struct Option;
struct Printer;
struct Config;

struct List
{
    List*next;
    void*data;
};

#define NUMOPT_NOHI	1
#define NUMOPT_NOLO	2
#define NUMOPT_NODEF	4
#define NUMOPT_NOSTEP	8

#define NOT_USED_STRING		"not set (using the driver default)"
#define PRINT_QUEUE_STRING 	"Print queue:"
#define PRINTER_STRING		"Printer:"
#define CONFIGURATION_STRING	"Configuration:"
#define OPTIONS_STRING		"Options:"
#define Y2TESTPAGE_STRING	"YaST2 test page"
#define CUPS_ONLY_STRING	"CUPS only:"
#define LPRNG_ONLY_STRING	"LPRng only:"
#define NOT_AVAILABLE_STRING	"Not available:"
#define PPD_FILE_STRING		"non-YaST PPD file"
#define NO_OPTS_STRING		"No options available for queues configured \n using non-YaST PPD files"
#define RAW_MODEL_STRING	"Unknown model"
#define RAW_CONFIG_STRING	"Raw printing"

#define DB_TEXTDOMAIN		"printerdb"
#define PRG_TEXTDOMAIN		"printer"


//#define	TRANSLATE_OPTIONS	1

struct ValueText
{
    char*pattern;
    char*chars;
    ~ValueText () { if (pattern) delete [] pattern; if (chars) delete [] chars; }
};
struct Numint
{
    char*pattern;
    int flags;
    int lo;
    int hi;
    int def;
    int step;
    ~Numint () { delete [] pattern; }
};
struct Numfloat
{
    char*pattern;
    int flags;
    double lo;
    double hi;
    double def;
    double step;
    ~Numfloat () { delete [] pattern; }
};
struct ValueItem
{
	char*type; //type as in printerdb
	char*val;  // value (for gs)
	ValueItem *next;

	ValueItem*copy (); // create copy of value
        ~ValueItem ();
        ValueItem () { type = NULL ; val = NULL ; next = NULL; }
};


struct Value // note that sometimes we misuse value. If val=0, then text is option name to paste here!
{
	char*paste;
	char*text; // nice text
	List*use;  // list of Useoption
	int type;  // 0 -- ordinary value, 1 -- pattern that takes following as its parameters
	ValueItem*items;
	Value*copy (); // create copy of value
	~Value (); 
	Value () { type = 0; items = NULL; paste = NULL; text = NULL; use = NULL; }
};
struct Useoption
{
	char*ident;  // option to use
	char*text;   // nice name 
	char*as;
	Option*use;
	~Useoption ();
};

struct Useprinter
{
	char*ident; // printer to use
	char*text;  // nice name
	char*ieee;  // ieee ident
	Printer*use;
	~Useprinter ();
	Useprinter*copy ();
};

struct Useconfig
{
	char*ident; //config to use
	char*text;  //nice name
	Config*use;
	char*queue; //default name for queue
	~Useconfig ();
	Useconfig*copy ();
};

struct Option
{
    char*ident;
    char*comment;
    int type;
    union 
    {
	List*vals;         // type == 0 list of Value
	Numint*numint;     // type == 1
	Numfloat*numfloat; // type == 2
	ValueText*valtext; // type == 3
    };
    ~Option ();    
};

struct Config
{
    char*ident;
    char*comment;
    int type;
    List*use; // Useconfig (type==0) | Useoption (type==1)
    char*param; // type == 1
    /*
     * This is an ugly hack. Queue name may vary if config is used in
     * various printers. So whenever we create some list of used printers,
     * we must update link <Useconfig>->use->queue = <Useconfig>->queue.
     */
    char*queue; // queue name

    Config () { ident = comment = param = queue = 0; use = 0; type = 0; }
    ~Config ();
};

struct Printer 
{
    char*ident;
    char*comment;
    List*use;  // list of Useconfig
    ~Printer ();
};

struct Vendor
{
    char*ident;
    char*comment;
    List*use; // list of Useprinter
    ~Vendor ();
};

struct Main
{
    char*text; // nice name
    char*ieee; // FIXME: patch ieee into Vendor !!!
    char*use;  //ident of vendor to use
    ~Main ();
};

extern List*mains;
extern List*vendors;
extern List*printers;
extern List*configs;
extern List*options;

extern Option**optionset;
extern int optionsize;
extern Config**configset;
extern int configsize;
extern Printer**printerset;
extern int printersize;
extern Vendor**vendorset;
extern int vendorsize;

void setDb_dir(const char* db);

void*makeset (List*l,int*size_out);
void*findinset (void*vset, int len, const char*ident);
List*findconfigs (const char*printer);
int preprocess ();
List*getconfigs (List*use);
List*reverse_list (List*l);
int is_supported (Printer*p);
const Main*detectVendorStruct (const char*ieee);
const char*detectVendor (const char*ieee);
const Useprinter*detectModelStruct (const char*vendor,const char*ieee);
const char*detectModel (const char*vendor,const char*ieee);
void getnames (char**vv, char**mm, char**cc, char*v_ieee = 0, char*m_ieee = 0);
void check_deep_conflicts ();

#endif//__STRUCTS_H__
