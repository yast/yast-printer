/**
 * YaST2 SuSE printer database ultimate tool.
 */

%{
#include <string>
#include <stdio.h>
#include <string.h>
#include "structs.h"
#include "parser.hh"

using namespace std;

extern YYSTYPE yylval;

int yylineno = 0;
string parsed_text;

%}

%option noyywrap

%x textstart intext waitfortextend

%%

^[\t ]*#.*$			{ /* Ignore Unix style Comments */ }

\n				{ /* Ignore newlines  */
				  yylineno++; }
[\t\r ]+			{ /* Ignore Whitespaces */ }

UseManufacturer			{ return USEMANUFACTURER;	}
EndUseManufacturer		{ return ENDUSEMANUFACTURER;	}
IEEE				{ return IEEE; }
Text				{ return TEXT; }
Manufacturer			{ return MANUFACTURER;		}
EndManufacturer			{ return ENDMANUFACTURER;	}
Comment				{ return COMMENT;		}
UsePrinter			{ return USEPRINTER;		}
Printer				{ return PRINTER; }
EndPrinter			{ return ENDPRINTER; }
UseConfig			{ return USECONFIG; }
Config				{ return CONFIG; }
EndConfig			{ return ENDCONFIG; }
Param				{ return PARAM; }
UseOption			{ return USEOPTION; }
PasteOption			{ return PASTEOPTION; }
PasteConfig			{ return PASTECONFIG; }
PastePrinter			{ return PASTEPRINTER; }
PasteManufacturer		{ return PASTEMANUFACTURER; }
Option				{ return OPTION; }
EndOption			{ return ENDOPTION; }
ValueInt			{ return VALUEINT; }
ValueFloat			{ return VALUEFLOAT; }
ValueText			{ return VALUETEXT; }
Value				{ return VALUE; }
Pattern				{ return PATTERN; }
Queue				{ return QUEUE;	}
As				{ return AS; }
Type				{ return TYPE; }

[a-zA-Z_][a-zA-Z_0-9\-]*        {
					yylval.text = new char[strlen(yytext)+1];
					strcpy (yylval.text,yytext);
					return _IDENT;
				}

\{[\t ]*\n?			{
					if (NULL != strchr (yytext, '\n'))
						yylineno++;
					parsed_text = "";
					BEGIN (textstart);
				}

<waitfortextend>[ \t]*\}	{
					BEGIN (INITIAL);
				}

<textstart>[ \t\n]*\}		{
					BEGIN (INITIAL);
					yylval.text = 0;
					return _TEXT;
				}

<textstart>[a-zA-Z_][a-zA-Z0-9_-]*/[ \t]*\} {
					BEGIN (waitfortextend);
					yylval.text = new char[strlen(yytext)+1];
					strcpy (yylval.text,yytext);
					return _IDENT;
				}

<intext>\n[ \t]*		{
					yylineno++;
					parsed_text = parsed_text + "\n";
				}

<textstart>[^\\\}]		{
					BEGIN (intext);
					char*p = yytext;
					while (' ' == *p || '\t' == *p || '\r' == *p)
					      p++;
					parsed_text = parsed_text + p;
				}


<textstart>\\.			{
					BEGIN (intext);
					if ('}' == *(yytext + 1))
					    parsed_text = parsed_text + '}';
					else
					    parsed_text = parsed_text + yytext;
				}
<intext>\\.			{
					if ('}' == *(yytext + 1))
					    parsed_text = parsed_text + '}';
					else
					    parsed_text = parsed_text + yytext;
				}

<intext>[ \t]*/\}		{
					BEGIN (waitfortextend);
					const char*p = parsed_text.c_str();
					const char*end = p + parsed_text.length() - 1;
					while (end > p && (' ' == *end || '\t' == *end)) {
					      end--;
					}
					parsed_text = parsed_text.substr (0, end - p + 1);
					yylval.text = new char [parsed_text.length()+1];
					strcpy (yylval.text,parsed_text.c_str());
					return _TEXT;
				}

<intext>[^\\\}\n]+		{
					if (NULL != strchr (yytext, '\n'))
						yylineno++;
					parsed_text = parsed_text + yytext;
				}

.				{
					DB_ERROR ("%d: Unexpected char '%s'\n", yylineno, yytext);
					return 0;
				}

%%

