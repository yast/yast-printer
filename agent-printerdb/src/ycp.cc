/**
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Printerdb agent implementation, routines that work with
 *   database and convert its content to ycp.
 *
 * Authors:
 *   Petr Blahos <pblahos@suse.cz>
 *   Jiri Srain <jsrain@suse.cz>
 *
 * $Id$
 */

#include <Y2.h>
#include <ycp/y2log.h>
#include <vector>

#include "structs.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <zlib.h>
#include <list>

struct opt_as {
    string as;
    string value;
    bool remove;
};

string db_dir = "";

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

const char*unescapePattern (string&s){
    unsigned i = 0;
    for (;i < s.length () - 1;i++)
    {
	if (s[i] == '\\' && (s[i+1] == '\\' || s[i+1] == '%')) {
	    s.replace (i, 2, s.substr (i,1));
	    continue;
	}
    }
    return s.c_str();
}
/**
 * Is the string pattern? (does contain %?)
 * @param pattern string to check
 * @return is it pattern?
 */

char* readFileToString (const char*filename) {
    if (strlen (filename) <= 0)
        return NULL;

    char *fn = (char*) malloc (db_dir.length() + strlen (filename) + 1);
    if (! fn)
	return NULL;

    strcpy (fn, db_dir.c_str());
    strcat (fn, filename);
    
    char* ungzipped = NULL;

    char *ppd_filename = fn;

    if (! (ppd_filename))
    {
	return NULL;
    }

    if (char* nul = index (fn, '\n'))
	*nul = 0;

    int len = strlen (fn);
    if (len>3 && !strcmp(fn+len-3,".gz"))
    {
	ungzipped = unpackGzipped (fn);
	ppd_filename = ungzipped;
    }

    if (! (ppd_filename))
    {
	free (fn);
	return NULL;
    }

    int fd;
    fd = open (ppd_filename, O_RDONLY);
    free (fn);
    if (fd<0){
	if(NULL!=ungzipped)
        {
            unlink(ungzipped);
            delete [] ungzipped;
        }
	return NULL;
    }
    struct stat s;
    int ret=fstat (fd,&s);
    if (ret == -1) {
        if(NULL!=ungzipped)
        {
            unlink(ungzipped);
            delete [] ungzipped;
        }
        return NULL;
    }
    len = s.st_size;
    char* data = (char*) malloc (len+2);
    if (!data) {
        close (fd);
        if(NULL!=ungzipped)
        {
            unlink(ungzipped);
            delete [] ungzipped;
        }
        return NULL;
    }

    read (fd, data, len);
    close (fd);
    if(NULL!=ungzipped)
    {
        unlink(ungzipped);
        delete [] ungzipped;
    }

    return data;
}

YCPList PPDArgsToList (string options) {
    YCPList l;
    char *opts = strdup (options.c_str());
    char* current = opts;
    char* next = strchr (current, '\n');

    while (next){
	*next = 0;
	next++;
	l->add (YCPString (current));
	current = next;
	next = index (current, '\n');
    }
    l->add (YCPString (current));
    free (opts);
    return l;
}	

string findValue (YCPList options, const char* optlabel, bool remove = false, const string next = "") {
    if (options->isEmpty ())return string ("");
    for (int i=0; i < options->size(); i++){
        const char* value = options->value (i)->asString ()->value_cstr ();
	if (strlen (value) == 0)
	    continue;
        if (strstr(value, optlabel)==value && (0 <= next.find (value[strlen(optlabel)]) || next.length() == 0)){
            string ret = string (options->value (i)->asString ()->value_cstr ());
            if (remove)
		options->remove (i);
            return ret;
        }
    }
    return string("");
}

YCPList preprocessOptions (char* file, YCPList opts){
    YCPList res;
    char* line;
    char* new_line;
    char* line_copy;
    char* tmp;
   
    if (!file)
	return YCPList();

    new_line = file;
    while (1) {
        line = new_line;
        if (! (line))
            break;
        new_line = index (line, '\n');
        if (new_line) {
            *new_line = 0;
            new_line ++;
        }
	if (*line != '*') {
	    continue;
	} else {
            line_copy = strdup (line);
            if (NULL == line_copy) {
                return YCPList();
            }
	    if (strstr (line, "*Default") == line) {
            } else {
                tmp = line_copy + 1;
                char* tmp2 = index (tmp, ':');
                if (tmp2)
                    *tmp2 = 0;
		tmp2 = index (tmp, '/');
		if (tmp2)
		    *tmp2 = 0;
		tmp2 = index (tmp, ' ');
		if (! tmp2) {
		    free (line_copy);
		    continue;
		}
		*tmp2 = 0;
		tmp2++;
		string def_line = string ("*Default") + string (tmp) + string (": ") + string (tmp2);
                string newline = findValue (opts, def_line.c_str(), true, string(":/"));
		if (newline.length() > 0){
		    res->add (YCPString(newline));
		}
            }
            free (line_copy);
	}
    }
    return res;
}

string getPatchedPpdFile (const char* filename, string options)
{
    string ret;
    char* ppd_file = readFileToString (filename);
    if (0 == ppd_file)
        return string ("");

    char *line;
    char *newline;
    char *line_copy;
    char *tmp;

    YCPList opts = PPDArgsToList (options);
    YCPList opts_to_remove_defaults = PPDArgsToList (options);

    opts = preprocessOptions (strdup (ppd_file), opts);
    opts_to_remove_defaults = opts;

    newline = ppd_file;

    while (1){
        line = newline;
        if (! (line))
            break;
        newline = index (line, '\n');
        if (newline) {
            *newline = 0;
            newline ++;
        }
        if (*line != '*') {
            if (*line)
		ret = ret + string (line) + string ("\n");
        } else {
            line_copy = strdup (line);
            if (NULL == line_copy) {
                free (ppd_file);
                return string ("");
            }
            tmp = strstr (line_copy, " ");
            if (! (tmp)) {
		if (*line_copy)
		    ret = ret + line_copy + string ("\n");
                free (line_copy);
		continue;
            }
            *tmp = 0;
            if (strstr (line, "*Default") == line) {
                string newline = findValue (opts, line_copy, false);
                if (newline.length() == 0) {
		    if (*line)
			ret = ret + string (line) + string ("\n");
		}
		else
		{
		    if (newline.length () > 0)
			ret = ret + newline + string ("\n");
		}
            } else {
		if (*line)
                    ret = ret + line + string ("\n");
            }
            free (line_copy);
        }
    }
    free (ppd_file);
    return ret;
}


bool isPattern (const char*pattern)
{
    for (;*pattern;pattern++)
    {
	if (*pattern == '\\' && (*(pattern+1) == '\\' || *(pattern+1) == '%')) {
	    pattern++;
	    continue;
	}
	if (*pattern == '%')
	    return true;
    }
    return false;
}
string putValuesInString ( string pattern, vector<opt_as>&f){
    
    vector<opt_as>::iterator i;
    for (i = f.begin (); i != f.end (); i++) {

        if ((*i).value.substr(0, 4) == "*~*~") 
             (*i).value = (*i).value.substr (4);

	string find_as = "%" + (*i).as + "%";
		
	int pos;
	pos = pattern.find (find_as);
	if (pos > 0 && pattern [pos - 1] == '\\')
	    continue;
	if (0 <= pos){
	    (*i).remove = true;
	    string paste = (*i).value;
	    if (paste.substr(0, 4) == "*~*~")
            	paste = paste.substr (4);

	    pattern = pattern.replace(pos,find_as.length(),paste);
	}
    }
    return pattern;
}
string putValueInString (const char*pattern, const char*buf)
{
    string out = pattern;
    unsigned i = 0;
    for (;i < out.length ();i++)
    {
	if (out[i] == '\\' && out[i+1] == '\\') {
	    out.replace (i, 2, "\\");
	    continue;
	}
	if (out[i] == '\\' && out[i+1] == '%') {
	    out.replace (i, 2, "%");
	    continue;
	}
	if (out[i] == '%')
	    out.replace (i, 1, buf);
    }
    return out;
}

void getConfFile (const List*u, YCPMap&selected,int&flags,vector<opt_as>&s, const string selection)
{
    opt_as oa;
    const List*walk = u;
    while (walk) {
	Useoption*uo = (Useoption*)walk->data;
	Option*o = uo->use;
	oa.as = string (uo->as);
	oa.remove = false;
	if (o) {
	    YCPValue v = selected->value (YCPString (uo->ident));
	
	    switch (o->type) {
	    case 1:
		{
		    char buf[50];
		    *buf = 0;
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isInteger ())
			    snprintf (buf, 49, "%d", (int)v->asInteger()->value());
		    }
		    else {
			if (!(o->numint->flags & NUMOPT_NODEF))
			    snprintf (buf, 49, "%d", (int)o->numint->def);
		    }
		    if (*buf){
			oa.value = putValueInString (o->numint->pattern, buf);
			s.push_back (oa);
		    }
		}
		break;
	    case 2:
		{
		    char buf[50];
		    *buf = 0;
		    if (!v.isNull ()) {
			if (!v->isVoid () && v->isFloat ())
			    snprintf (buf, 49, "%f", v->asFloat()->value());
		    }
		    else {
			if (!(o->numfloat->flags & NUMOPT_NODEF))
			    snprintf (buf, 49, "%f", o->numfloat->def);
		    }
		    if (*buf){
			oa.value = putValueInString (o->numfloat->pattern, buf);
			s.push_back (oa);
		    }
		}
		break;
	    case 3:
		{
		    if (!v.isNull () && v->isString ()){
			oa.value = putValueInString (o->valtext->pattern, v->asString ()->value_cstr ());
			s.push_back (oa);
		    }
		}
		break;
	    default:
		{
		    int sel = 0;
		    if (!v.isNull() && v->isInteger ())
			sel = v->asInteger()->value();
		    List*vall = o->vals;
		    while (sel-- > 0 && vall) {
			vall = vall->next;
		    }
		    if (-1 != sel || !vall)
			vall = o->vals;
		    Value*val = (Value*)vall->data;
		    ValueItem *item = val->items;
		    while (item){
			if (val->type) {
			    if ( 0 == strncmp (item->type, selection.c_str(), strlen (selection.c_str ()))) {
			        string xxx = "*~*~";
			        xxx = xxx + item->val;
				oa.value = xxx;
			        s.push_back (oa);
			    }
			}
			else {
                            if ( 0 == strncmp (item->type, selection.c_str(), strlen (selection.c_str ()))) {	
				oa.value = item->val;
				s.push_back (oa);
			    }
			}
			item=item->next;
		    }
		    if (val->use)
			getConfFile (val->use, selected, flags, s, selection);
		}
		break;
	    }
	}
	else
	    y2error ("Error in use option: %s %s", uo->ident, uo->text);
	walk = walk->next;
    }
}
string getConfFile (List*u, YCPMap&selected,int&flags, const string selection)
{
    vector<opt_as>f;
    getConfFile (u, selected, flags, f, selection);
    vector<opt_as>::iterator i;
    string pattern;
    string s = "";
    for (i = f.begin (); i != f.end (); i++) {
	if ((*i).value.substr(0, 4) == "*~*~") {
	     (*i).value = (*i).value.substr (4);
	    while (isPattern ((*i).value.c_str())){
	    	string tmp = putValuesInString ( (*i).value, f);
	    	if (tmp == (*i).value)break;
	    	(*i).value = tmp;
	    }    
	}
    }
    for (i = f.begin (); i != f.end (); i++) {
	if (! (*i).remove)
            s = s + (*i).value + "\n";
    }
    return s;
}

/**
 * Adds string to translate, possibly with comment into yh file.
 * @param f file to write to
 * @param c string to translate
 * @param cls class of the string denotes which comment will be added to
 * the string: <pre>
 * 	0 -- no comment
 * 	1 -- "Keep it short"
 * 	2 -- class-comment
 * 	3 -- class-option</pre>
 */
void addTranslatableString (FILE*f, const char*c, int cls = 0)
{
    if (!c)
	return;
    // replace ... " by \" and \ by \\  ...

    bool percent = false;
    string s;
    while (*c) {
	if ('\"' == *c || '\\' == *c)
	    s = s + '\\';
	s = s + *c;
	if ('%' == *c)
	    percent = true;
	c++;
    }
    switch (cls) {
    case 1: fputs ("//TRANSLATORS: keep this short! Only translations in languages with encodings ISO-8859-[1|2|15] will be used.\n", f); break;
    case 2: fputs ("//class-comments\n", f); break;
    case 3: fputs ("//class-options\n", f); break;
    }
    if (percent)
	fputs ("// xgettext: no-c-format\n", f);
    fprintf (f, "_(\"%s\");\n", s.c_str());
}


YCPValue WriteTransStrings (const char*fn, const char*type)
{
    FILE*f = fopen (fn, "wt");
    if (NULL == f)
	return YCPError (string ("Can not open ") + fn, YCPBoolean (false));
    fprintf (f, "{\n");
    if (0 == strcmp (type, "prg"))
    {
	fprintf (f, "textdomain \"%s\";\n", PRG_TEXTDOMAIN);
	addTranslatableString (f, NOT_USED_STRING);
	addTranslatableString (f, PRINT_QUEUE_STRING, 1);
	addTranslatableString (f, PRINTER_STRING, 1);
	addTranslatableString (f, CONFIGURATION_STRING, 1);
	addTranslatableString (f, OPTIONS_STRING, 1);
	addTranslatableString (f, Y2TESTPAGE_STRING, 1);
	addTranslatableString (f, CUPS_ONLY_STRING, 1);
	addTranslatableString (f, LPRNG_ONLY_STRING, 1);
	addTranslatableString (f, NOT_AVAILABLE_STRING, 1);
	addTranslatableString (f, PPD_FILE_STRING, 1);
	addTranslatableString (f, NO_OPTS_STRING, 1);
	fprintf (f, "}\n");
	fclose (f);
	return YCPBoolean (true);
    }
    fprintf (f, "textdomain \"%s\";\n", DB_TEXTDOMAIN);
    // extract translatable strings...
    List*walk = mains;
    while (walk) {
	Main*d = (Main*)walk->data;
	addTranslatableString (f, d->text);
	walk = walk->next;
//	addTranslatableString (f, d->text);
//	walk = walk->next;
    }
    walk = vendors;
    while (walk) {
	Vendor*d = (Vendor*)walk->data;
	addTranslatableString (f, d->comment, 2);
	List*use = d->use;
	while (use) {
	    addTranslatableString (f, ((Useprinter*)use->data)->text);
	    use = use->next;
	}
	walk = walk->next;
    }
    walk = printers;
    while (walk) {
	Printer*d = (Printer*)walk->data;
	addTranslatableString (f, d->comment, 2);
	List*use = d->use;
	while (use) {
	    addTranslatableString (f, ((Useconfig*)use->data)->text);
	    use = use->next;
	}
	walk = walk->next;
    }
    walk = configs;
    while (walk) {
	Config*d = (Config*)walk->data;
	addTranslatableString (f, d->comment, 2);
	List*use = d->use;
	while (use) { 
	    //This is tricky. there may be Useconfig
	    //or Useoption but both have text as 2nd 
	    //member.
	    addTranslatableString (f, ((Useconfig*)use->data)->text);
	    use = use->next;
	}
	walk = walk->next;
    }
    walk = options;
    while (walk) {
	Option*d = (Option*)walk->data;
	addTranslatableString (f, d->comment, 2);
#if TRANSLATE_OPTIONS
	if (!d->type) {
	    List*vals = d->vals;
	    while (vals) {
		Value*v = (Value*)vals->data;
		addTranslatableString (f, v->text, 3);
		if (v->use) {
		    List*w = v->use;
		    while (w) {
			addTranslatableString (f, ((Useoption*)w->data)->text, 3);
			w = w->next;
		    }
		}
		vals = vals->next;
	    }
	}
#endif//TRANSLATE_OPTIONS
	walk = walk->next;
    }
    fprintf (f, "}\n");
    fclose (f);
    return YCPBoolean (true);
}
YCPValue numint2ycp (const Numint*n)
{
    YCPMap l;
    l->add (YCPString ("pattern"), YCPString (n->pattern));
    l->add (YCPString ("lo"), YCPInteger (n->lo));
    l->add (YCPString ("hi"), YCPInteger (n->hi));
    if (n->flags & NUMOPT_NODEF)
	l->add (YCPString ("default"), YCPVoid ());
    else
	l->add (YCPString ("default"), YCPInteger (n->def));
    l->add (YCPString ("step"), YCPInteger (n->step));
    return l;
}
YCPValue numfloat2ycp (const Numfloat*n)
{
    YCPMap l;
    l->add (YCPString ("pattern"), YCPString (n->pattern));
    l->add (YCPString ("lo"), YCPFloat (n->lo));
    l->add (YCPString ("hi"), YCPFloat (n->hi));
    if (n->flags & NUMOPT_NODEF)
	l->add (YCPString ("default"), YCPVoid ());
    else
	l->add (YCPString ("default"), YCPFloat (n->def));
    l->add (YCPString ("step"), YCPFloat (n->step));
    return l;
}
YCPValue text2ycp (const ValueText*n)
{
    YCPMap l;
    l->add (YCPString ("pattern"), YCPString (n->pattern));
    l->add (YCPString ("chars"), YCPString (n->chars));
    return l;
}

void setDb_dir(const char* db){
    db_dir = string(db).substr(0, string(db).rfind("/")+1);
}
