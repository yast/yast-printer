
%{

#include <stdio.h>
#include <string.h>

#include "structs.h"

using namespace std;

extern int yylex ();
extern int yyerror (char*c);

char*skipSpaces(char*p)
{
    while (' '==*p || '\t'==*p || '\r'==*p || '\n'==*p)
	p++;
    return p;
}
char*skipNonspaces(char*p)
{
    while (' '!=*p && '\t'!=*p && '\r'!=*p && '\n'!=*p && '\0'!=*p)
	p++;
    return p;
}
void check_pattern (char*pat)
{
    // there must not be some characters like \n, \r, \t in patterns
    char*p = pat;
    while (*p) {
        if (*p == '\n' || *p == '\r' || *p == '\t') {
	    DB_ERROR ("Bad pattern, truncating at the first invalid character: %s\n", pat);
	    *p = '\0';
	    break;
	}
    	p++;
    }
}
int createNumFloat (Numfloat*n,char*in,char*pat)
{
    char*p = in;
    check_pattern (pat);
    n->flags = 0;
    n->pattern = pat;
    n->lo = n->hi = 0;
    n->step = 1;
    n->def = 0;
    p = skipSpaces(p);
    sscanf(p, "%lf",&(n->lo));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    sscanf(p, "%lf",&(n->hi));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    sscanf(p, "%lf",&(n->step));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    if (sscanf(p, "%lf",&(n->def)) <= 0)
    	n->flags = NUMOPT_NODEF;
    return 0;
}
 
int createNumInt (Numint*n,char*in,char*pat)
{
    char*p = in;
    check_pattern (pat);
    n->flags = 0;
    n->pattern = pat;
    n->lo = n->hi = 0;
    n->step = 1;
    n->def = 0;
    p = skipSpaces(p);
    sscanf(p, "%i",&(n->lo));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    sscanf(p, "%i",&(n->hi));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    sscanf(p, "%i",&(n->step));
    p = skipNonspaces(p);
    p = skipSpaces(p);
    if (sscanf(p, "%i",&(n->def)) <= 0)
    	n->flags = NUMOPT_NODEF;
    return 0;
}

%}

%union {
	char* text;
	Numint* numint;
	Numfloat* numfloat;
	Value* value;
	Useoption* useoption;
	Useprinter*useprinter;
	Useconfig* useconfig;
	List*list;
	ValueText*valuetext;
	ValueItem*valueitem;
}

%token USEMANUFACTURER ENDUSEMANUFACTURER USEMANUFACTURER IEEE TEXT
%token MANUFACTURER ENDMANUFACTURER
%token COMMENT USEPRINTER PRINTER ENDPRINTER USECONFIG CONFIG ENDCONFIG PARAM
%token USEOPTION OPTION ENDOPTION VALUEINT VALUEFLOAT PATTERN VALUE VALUETEXT
%token PASTEOPTION PASTECONFIG PASTEPRINTER PASTEMANUFACTURER QUEUE AS TYPE

%token <text> _TEXT
%token <text> _IDENT

%type <numint> numint
%type <numfloat> numfloat
%type <valuetext> valuetext
%type <list> valuelist
%type <value> value
%type <list> useoptionlist
%type <useoption> useoption
%type <list> useprinterlist
%type <useprinter> useprinter
%type <list> useconfiglist
%type <useconfig> useconfig
%type <list> usepasteconfiglist
%type <useconfig> usepasteconfig
%type <text> text
%type <text> comment
%type <valueitem> valueitem

%%

db:
	/* empty */
|	somedefinition db
;
somedefinition:
	usemanufacturer 
|	manufacturer
|	printer
|	config
|	option
;
text:
	_IDENT
|	_TEXT
;

comment:
	/* empty */ { $$ = 0; }
|	COMMENT text { $$ = $2; }
;
/* ------------------ use manufacturer section --------------------- */

usemanufacturer:
	USEMANUFACTURER _IDENT IEEE text TEXT text usemanufacturerend {
		Main*m = new Main;
		m->use = $2;
		m->ieee = $4;
		m->text = $6;
		List*l = new List;
		l->data = m;
		l->next = mains;
		mains = l;
	}
|	USEMANUFACTURER _IDENT TEXT text IEEE text usemanufacturerend {
		Main*m = new Main;
		m->use = $2;
		m->ieee = $6;
		m->text = $4;
		List*l = new List;
		l->data = m;
		l->next = mains;
		mains = l;
	}
|	USEMANUFACTURER _IDENT TEXT text usemanufacturerend {
		Main*m = new Main;
		m->use = $2;
		m->ieee = 0;
		m->text = $4;
		List*l = new List;
		l->data = m;
		l->next = mains;
		mains = l;
	}
;
usemanufacturerend:
	/* empty */
|	ENDUSEMANUFACTURER _IDENT
|	ENDUSEMANUFACTURER
;

/* ------------------   manufacturer section   --------------------- */

manufacturer:
	MANUFACTURER _IDENT comment useprinterlist endmanufacturer {
		List*l = new List;
		Vendor*v = new Vendor;
		v->ident = $2;
		v->comment = $3;
		v->use = $4;
		l->data = v;
		l->next = vendors;
		vendors = l;
	}
;
endmanufacturer:
	/* empty */
|	ENDMANUFACTURER
|	ENDMANUFACTURER _IDENT
;
useprinterlist:
	useprinter {
	      $$ = new List;
	      $$->next = 0;
	      $$->data = (void*)$1;
	}
|	useprinter useprinterlist {
	      $$ = new List;
	      $$->next = $2;
	      $$->data = (void*)$1;
	}
;

useprinter:
	USEPRINTER _IDENT IEEE text TEXT text {
	       $$ = new Useprinter;
	       $$->ident = $2;
	       $$->text = $6;
	       $$->ieee = $4;
	}
|	USEPRINTER _IDENT TEXT text IEEE text {
	       $$ = new Useprinter;
	       $$->ident = $2;
	       $$->text = $4;
	       $$->ieee = $6;
	}
|	USEPRINTER _IDENT TEXT text {
	       $$ = new Useprinter;
	       $$->ident = $2;
	       $$->text = $4;
	       $$->ieee = 0;
	}
|       PASTEMANUFACTURER _IDENT {
              $$ = new Useprinter;
              $$->ident = $2;
              $$->text = 0; //<- text == 0 for Paste
              $$->ieee = 0;
        }
;
/* ------------------  printer         section --------------------- */

printer:
	PRINTER _IDENT comment useconfiglist endprinter {
		List*l = new List;
		Printer*p = new Printer;
		p->ident = $2;
		p->comment = $3;
		p->use = $4;
		l->data = p;
		l->next = printers;
		printers = l;
	}
;
endprinter:
	/* empty */
|	ENDPRINTER
|	ENDPRINTER _IDENT
;
useconfiglist:
	/* empty */ {
		$$ = 0;
	}
|	useconfig useconfiglist {
	      $$ = new List;
	      $$->next = $2;
	      $$->data = (void*)$1;
	}
;

useconfig:
	USECONFIG _IDENT TEXT text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $4;
	      $$->queue = 0;
	}
|	USECONFIG _IDENT TEXT text QUEUE text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $4;
	      $$->queue = $6;
	}
|	USECONFIG _IDENT QUEUE text TEXT text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $6;
	      $$->queue = $4;
	}
|	PASTEPRINTER _IDENT {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = 0; //<- text == 0 for Paste
	      $$->queue = 0;
	}
;
/* ------------------  configs         section --------------------- */

config:
	CONFIG _IDENT comment PARAM text useoptionlist endconfig {
		Config*c = new Config;
		c->ident = $2;
		c->comment = $3;
		c->param = $5;
		c->use = $6;
		c->type = 1;
		List*l = new List;
		l->data = c;
		l->next = configs;
		configs = l;
	}
|	CONFIG _IDENT comment useoptionlist endconfig {
		Config*c = new Config;
		c->ident = $2;
		c->comment = $3;
		c->param = 0;
		c->use = $4;
		c->type = 1;
		List*l = new List;
		l->data = c;
		l->next = configs;
		configs = l;
	}
|	CONFIG _IDENT comment usepasteconfiglist endconfig {
		Config*c = new Config;
		c->ident = $2;
		c->comment = $3;
		c->param = 0;
		c->use = $4;
		c->type = 0;
		List*l = new List;
		l->data = c;
		l->next = configs;
		configs = l;
	}
;
endconfig:
	/* empty */
|	ENDCONFIG
|	ENDCONFIG _IDENT
;
usepasteconfiglist:
	/* empty */ {
		$$ = 0;
	}
|	usepasteconfig usepasteconfiglist {
	      $$ = new List;
	      $$->next = $2;
	      $$->data = (void*)$1;
	}
;

usepasteconfig:
	USECONFIG _IDENT TEXT text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $4;
	      $$->queue = 0;
	}
|	USECONFIG _IDENT TEXT text QUEUE text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $4;
	      if ($6 && !*$6) {
			delete $6;
			$6 = 0;
	      }
	      $$->queue = $6;
	}
|	USECONFIG _IDENT QUEUE text TEXT text {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = $6;
	      if ($4 && !*$4) {
			delete $4;
			$4 = 0;
	      }
	      $$->queue = $4;
	}
|	PASTECONFIG _IDENT {
	      $$ = new Useconfig;
	      $$->ident = $2;
	      $$->text = 0; //<- text == 0 for Paste
	      $$->queue = 0;
	}
;
useoptionlist:
	useoption {
	      $$ = new List;
	      $$->next = 0;
	      $$->data = (void*)$1;
	}
|	useoption useoptionlist {
	      $$ = new List;
	      $$->next = $2;
	      $$->data = (void*)$1;
	}
;

useoption:
	USEOPTION _IDENT TEXT text {
	      $$ = new Useoption;
	      $$->ident = $2;
	      $$->text = $4;
	      $$->as = $2;
	}
|	USEOPTION _IDENT AS _IDENT TEXT text {
	      $$ = new Useoption;
	      $$->ident = $2;
	      $$->text = $6;
	      $$->as = $4;
	}
;
/* ------------------   options        section --------------------- */

option:
	OPTION _IDENT comment valuelist endoption {
		List*l = new List;
		Option*o = new Option;
		o->ident = $2;
		o->comment = $3;
		o->type = 0;
		o->vals = $4;
		l->data = o;
		l->next = options;
		options = l;
	}
|	OPTION _IDENT comment numint endoption {
		List*l = new List;
		Option*o = new Option;
		o->ident = $2;
		o->comment = $3;
		o->type = 1;
		o->numint = $4;
		l->data = o;
		l->next = options;
		options = l;
	}
|	OPTION _IDENT comment numfloat endoption {
		List*l = new List;
		Option*o = new Option;
		o->ident = $2;
		o->comment = $3;
		o->type = 2;
		o->numfloat = $4;
		l->data = o;
		l->next = options;
		options = l;
	}
|	OPTION _IDENT comment valuetext endoption {
		List*l = new List;
		Option*o = new Option;
		o->ident = $2;
		o->comment = $3;
		o->type = 3;
		o->valtext = $4;
		l->data = o;
		l->next = options;
		options = l;
	}
;

endoption:
	ENDOPTION _IDENT
|	ENDOPTION
;

numint:
	VALUEINT text PATTERN text {
	      $$ = new Numint;
	      createNumInt ($$, $2, $4);
	      delete $2;
	}
;
numfloat:
	VALUEFLOAT text PATTERN text {
	      $$ = new Numfloat;
	      createNumFloat ($$, $2, $4);
	      delete $2;
	}
;
valuetext:
	VALUETEXT text PATTERN text {
	    $$ = new ValueText;
	    $$->pattern = $4;
	    $$->chars = $2;
	}
;
valuelist:
	value {
	      $$ = new List;
	      $$->next = 0;
	      $$->data = (void*)$1;
	}
|	value valuelist {
	      $$ = new List;
	      $$->next = $2;
	      $$->data = (void*)$1;
	}
;

value:
	PATTERN valueitem TEXT text {
	      $$ = new Value;
	      $$->items = $2;
	      $$->text = $4;
	      $$->use = 0;
	      $$->type = 1;
	}
|	PATTERN valueitem TEXT text useoptionlist {
	      $$ = new Value;
	      $$->items = $2;
	      $$->text = $4;
	      $$->use = $5;
	      $$->type = 1;
	}
|	PASTEOPTION _IDENT {
	      $$ = new Value;
	      $$->paste = $2;
	      $$->text = 0; //<- text == 0 for Paste
	      $$->use = 0;
	}
|	PASTEOPTION _IDENT useoptionlist {
	      $$ = new Value;
	      $$->paste = $2;
	      $$->text = 0; //<- text == 0 for Paste
	      $$->use = $3;
	}
|	VALUE valueitem TEXT text {
	      $$ = new Value;
	      $$->items = $2;
	      $$->text = $4; //FIXME: report error if there is NULL
	      $$->use = 0;
	}
|	VALUE valueitem TEXT text useoptionlist {
	      $$ = new Value;
	      $$->items = $2;
	      $$->text = $4; //FIXME: report error if there is NULL
	      $$->use = $5;	    
	}
|       VALUE TEXT text {
              $$ = new Value;
              $$->items = NULL;
              $$->text = $3; //FIXME: report error if there is NULL
              $$->use = 0;
        }
|       VALUE TEXT text useoptionlist {
              $$ = new Value;
              $$->items = NULL;
              $$->text = $3; //FIXME: report error if there is NULL
              $$->use = $4;
        }

;

valueitem:
        TYPE text text {
                $$ = new ValueItem;
                $$->type = $2;
                $$->val = $3;
                $$->next = NULL;
        }
//|       text {
//                $$ = new ValueItem;
//                $$->type = strdup ("file:upp");
//                $$->val = $1;
//                $$->next = NULL;
//        }
|       TYPE text text valueitem {
                $$ = new ValueItem;
                $$->type = $2;
                $$->val = $3;
                $$->next = $4;
        }
//|       text valueitem {
//                $$ = new ValueItem;
//                $$->type = strdup ("file:upp");
//                $$->val = $1;
//                $$->next = $2;
//        }
;



%%
