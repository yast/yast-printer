/* PrintersConf.h -*- c++ -*-
 *
 * classes for reading printers.conf configuration file
 * and writing printers definitions via cups library calls
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */
#ifndef _PrintersConf_h_
#define _PrintersConf_h_

#include <string>
#include <map>
#include <list>
#include <set>
#include <Y2.h>
#include <ycp/YCPMap.h>
#include <ycp/YCPBoolean.h>

using namespace std;

#define WHITESPACE      " \t\n"

/**
 * This contains one entry from the printers.conf file
 *
 * @short One entry in printers.conf file
 * @author Petr Blahos <pblahos@suse.cz>
 * @version $Id$
 *
 */
class PrinterEntry
{
private:
  string Name;
  bool   Default;  //FIXME: remove this
  string Info;
  string Location;
  string Uri;
  string State;
  string StateMessage;
  bool Shared;
  bool   Accepting;
  string BannerStart;
  string BannerEnd;
  set<string> AllowUsers;
  set<string> DenyUsers;
  string ppd;
  map<string,string>options;

  /**
   * This value indicates if printer was saved in PrintersConf::Write.
   * PrintersConf::Write clears saved for all printers.
   * PrintersConf::Write sets saved for each printers it saves.
   * Printers that do not have saved bit set were not saved and must be deleted.
   */
  bool saved;
public:
  /**
   * Default constructor.
   */
  PrinterEntry() 
    : Name(), Default(false), Info(), Location(), Uri(), State(), StateMessage(), Shared(false),
      Accepting(false), BannerStart(), BannerEnd(), AllowUsers(), DenyUsers(), ppd(), options(),
      saved(false)
      {
      }
  /**
   * Destructor.
   */
  ~PrinterEntry()
      {
      }

  void setSaved()
      {
        saved = true;
      }
  void clearSaved()
      {
        saved = false;
      }
  bool isSaved()
      {
        return saved;
      }
  /**
   * set* functions to access private members.
   *
   * CREATE_SET(x,y) macro creates functions
   * void setX(y x_)
   * {
   *   x = x_;
   * }
   * e.g.:
   * CREATE_SET(Printer,string) --> void setPrinter(string Printer_){ Printer = Printer_;}
   */
#define CREATE_SET(x,y) void set##x(const y x##_){x = x##_;}
  CREATE_SET(Name,string);
  CREATE_SET(Default,bool);
  CREATE_SET(Shared,bool);
  CREATE_SET(Info,string);
  CREATE_SET(Location,string);
  CREATE_SET(Uri,string);
  CREATE_SET(State,string);
  CREATE_SET(StateMessage,string);
  CREATE_SET(Accepting,bool);
  CREATE_SET(BannerStart,string);
  CREATE_SET(BannerEnd,string);
  CREATE_SET(ppd,string);  
#undef  CREATE_SET

  /**
   * add* functions to add items to set/map
   * @param u username.
   */
  void addAllowUsers(const string u)
      {
        AllowUsers.insert(u);
      }
  void addDenyUsers(const string u)
      {
        DenyUsers.insert(u);
      }
  /**
   * Add or change option
   * @param name Name of the option.
   * @param value Value of the option.
   */
  void addOption(const string name,const string value)
      {
        options[name] = value;
      }
  /**
   * delete user from AllowUsers
   * @param u username.
   */
  void delAllowUsers(const string u)
      {
        AllowUsers.erase(u);
      }
  /**
   * delete user from DenyUsers
   */
  void delDenyUsers(const string u)
      {
        DenyUsers.erase(u);
      }
  /**
   * delete option
   * @param s Option name to delete.
   */
  void delOption(const string s)
      {
        options.erase(s);
      }
  /**
   * Get printer name.
   * @return Printer name.
   */
  string getPrinter() const
      {
        return Name;
      }
  /**
   * Get printer name.
   * @return Printer name as string. 
   */
  const char*getPrinter_str() const
      {
        return Name.c_str();
      }
  
  /**
   * Get reference to the map of the options.
   * @return Map of the options.
   */
  map<string,string>&getOptions()
      {
        return options;
      }
  
  /**
   * Dump values, for debugging purposes.
   */
  void dump() const;

  /**
   * Convert PrinterEntry to YCPValue
   * @return Printer settings as described in cups.txt (.cups.printers)
   */
  YCPValue Read() const;

  /**
   * Helper function for Write. Update printer definition in cups system.
   * Updates printer entry (this). Saves only changed items.
   * @param value New value of PrinterEntry.
   * @return Success state.
   */
  bool changePrinter(const YCPValue&value);

  /**
   * Add new printer. Replace 
   */
  bool newPrinter(const YCPValue&value);
};

class PrintersConf
{
private:
  /**
   * List of PrinterEntries.
   */
  list<PrinterEntry> Printers;
  /**
   * Parse file printers.conf.
   * @param fn File to parse.
   * @return if the operation was successful.
   */
  bool parseFile(const char*fn);
  /**
   * Not all of the settings can be read from file printers.conf. This function reads additional
   * settings via cups library calls.
   * @return True if settings was read successfully.
   */
  bool completeEntries();
  /**
   * Erase all settings.
   */
  void Clear()
      {
        Printers.clear();
      }
  /**
   * Update printer.
   */
  bool modifyPrinter(YCPMap printer);
  /**
   * Read printers.conf file. Build list of printers (Printers).
   * @param fn filename of the printers.conf.
   * @return True if file was read successfully.
   */
  bool readSettings(const char*fn);
  bool getPrinters ();
  /**
   * Returns printer entry by printer name. If the printer does not have an entry, it is created.
   * @param name Printer name.
   * @return Iterator that points to printer entry for printer.
   */
  list<PrinterEntry>::iterator getPrinterEntry(const string name);
  
  /**
   * Returns printer entry by printer name. If the printer does not have an entry, returns Printers.end().
   * @param name Printer name.
   * @return Iterator that points to printer entry for printer or Printer.end()
   */  
  list<PrinterEntry>::iterator findPrinter(const string name);

public:
  /**
   * Default Constructor.
   */
  PrintersConf()
    : Printers()
      {
      }

  /**
   * Destructor.
   */
  ~PrintersConf()
      {
      }
  /**
   * Dump all printers.
   */
  void dump() const;
  
  /**
   * Convert PrintersConf to YCPValue
   */
  YCPValue Read();

  /**
   * Write printers...
   */
  YCPBoolean Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());

};

#endif//_PrintersConf_h_
