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

/**
 * Array of all known vendors
 */
char *array_all[] = {
    "3M",
    "A.B.DICK",
    "ADOBE",
    "AGFA",
    "ALPS",
    "APOLLO",
    "APPLE",
    "AST",
    "AUTOLOGIC",
    "BIRMY",
    "BROTHER",
    "C.ITOH",
    "CALCOMP",
    "CANON",
    "CITIZEN",
    "COLOSSAL",
    "COMPAQ",
    "CYCLONE", // unsure
    "COMPUPRINT", // unsure
    "CROSFIELD",
    "DATAPRODUCTS",
    "DIGITAL",
    "DUPONT",
    "EFI",
    "ENCAD",
    "EPSON",
    "FARGO",
    "FUJI",
    "FUJITSU",
    "GDT",
    "GESTETNER",
    "HEIDELBERG",
    "HITACHI",
    "HP",
    "IBM",
    "IDT",
    "IMAGEN",
    "INDIGO", // unsure
    "INFOTEC",
    "JVC",
    "KODAK",
    "KYOCERA",
    "LASERMASTER",
    "LEXMARK",
    "LINOTYPE-HELL",
    "MGI", // unsure
    "MINOLTA",
    "MITSUBISHI",
    "MONOTYPE", // unsure
    "MUTOH",
    "NEC",
    "NEXT",
    "OCE",
    "OKI",
    "OLIVETTI",
    "PANASONIC",
    "PCPI",
    "PIX",
    "PREPRESS", // unsure
    "QMS",
    "QUME",
    "RAVEN",
    "RICOH",
    "SAMSUNG",
    "SCHLUMBERGER",
    "SCITEX", // unsure
    "SEIKO",
    "SHARP",
    "SHINKO",
    "SONY",
    "SPLASH TECHNOLOGY",
    "STAR",
    "SUN",
    "SUPERMAC", // unsure
    "TALLY",
    "TEKTRONIX",
    "TI",
    "TYPHOON", // unsure
    "UNISYS",
    "VARITYPER",
    "XANTE",
    "XEROX",
    NULL
};

/**
 * Array of all known string->vendor mappings
 */
struct { char *key, *val; } array_map[] = {
    { "CCL", "CALCOMP" },
    { "CCP", "CALCOMP" },
    { "CELIX", "CROSFIELD" },
    { "COLORLINK", "PIX" },
    { "COLORMATE", "NEC" },
    { "COLORPOINT", "SEIKO" },
    { "FIERY", "EFI" },
    { "LASERPRESS", "FUJI" },
    { "LHAG", "LINOTYPE-HELL" },
    { "LINO", "LINOTYPE-HELL" },
    { "LINOTRONIC", "LINOTYPE-HELL" },
    { "LINOTYPE", "LINOTYPE-HELL" },
    { "MANAGEMENT", "MGI" },
    { "SII", "SEIKO" },
    { "FIRST PROOF", "SEIKO" },
    { "HEWLETT-PACKARD", "HP" },
    { "MATSUSHITA", "PANASONIC" },
    { "OKIDATA", "OKI" },
    { "PS-IPU", "CANON" },
    { "HERK", "LINOTYPE-HELL" },
    { "XPRINT", "XEROX" },
    { "EASTMAN", "KODAK" },
    { "LASERWRITER", "APPLE" },
    { "COLORPOINT", "SEIKO" },
    { "PRIMERA", "FARGO" },
    { "APS-PS", "AUTOLOGIC" },
    { "LM", "LASERMASTER" },
    { "PANTHER", "PREPRESS" },
    { "PLATEMAKER", "XANTE" },
    { "SPARCPRINTER", "SUN" },
    { "DEC", "DIGITAL" },
    { "ACCEL-A-WRITER", "XANTE" },
    { "LUXSETTER", "FUJI" },
    { "SPLASH", "SPLASH TECHNOLOGY" },
    { "STYLESCRIPT", "GDT" },
    { "OCECOLOR", "OCE" },
    { "NWS", "SONY" },
    { "POSTARTPRO", "SONY" },
    { "PHASER", "TEKTRONIX" },
    { "MAJESTIK", "SUPERMAC" },
    { "DYMO", "DYMO-COSTAR" },
    { "CANON INC. (KOSUGI OFFIC", "CANON" },
    { "LEXMARK 2030", "LEXMARK" },
    { "LEXMARK INTERNATIONAL", "LEXMARK" },
    { "OKI DATA CORP", "OKI" },
    { "OKIDATA", "OKI" },
    { "GHOSTSCRIPT", "UNKNOWN" },
    { "GENERIC", "UNKNOWN" },
    { "GENERIC PRINTERS", "UNKNOWN" },
    { "GHOSTSCRIPT DEVICES", "UNKNOWN" },
    { "SAMSUNG ELECTRONICS", "SAMSUNG" },
    { "OTHER MANUFACTURERS", "UNKNOWN" },
    { "KYOCERA MITA", "KYOCERA" },
//    { "GHOSTSCRIPT", "Ghostscript devices" },
//    { "GENERIC", "Generic printers" },
    { NULL, NULL }
};

/* EOF */
