/* ClassesConf.h -*- c++ -*-
 *
 * classes for reading classes.conf configuration file
 * and writing classes definitions via cups library calls
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */
#ifndef _ClassesConf_h_
#define _ClassesConf_h_

#include <string>
#include <map>
#include <list>
#include <set>
#include <Y2.h>

using namespace std;

#define WHITESPACE      " \t\n"

/**
 * This contains one entry from the classes.conf file
 *
 * @short One entry in classes.conf file
 * @author Petr Blahos <pblahos@suse.cz>
 * @version $Id$
 *
 */
class ClassEntry
{
private:
  string Name;
  bool   Default;  //FIXME: remove this
  string Info;
  string Location;
  string Uri;
  string State;
  string StateMessage;
  bool   Accepting;
  string BannerStart;
  string BannerEnd;
  set<string> AllowUsers;
  set<string> DenyUsers;
  set<string> Printers;
  string ppd;
  map<string,string>options;

  /**
   * This value indicates if classes was saved in ClassesConf::Write.
   * ClassesConf::Write clears saved for all classes.
   * ClassesConf::Write sets saved for each classes it saves.
   * Classes that do not have saved bit set were not saved and must be deleted.
   */
  bool saved;
public:
  /**
   * Default constructor.
   */
  ClassEntry() 
    : Name(), Default(false), Info(), Location(), Uri(), State(), StateMessage(),
      Accepting(false), BannerStart(), BannerEnd(), AllowUsers(), DenyUsers(), Printers(), ppd(), options(),
      saved(false)
      {
      }
  
  /**
   * Destructor.
   */
  ~ClassEntry()
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
   * CREATE_SET(Class,string) --> void setClass(string Class_){ Class = Class_;}
   */
#define CREATE_SET(x,y) void set##x(const y x##_){x = x##_;}
  CREATE_SET(Name,char*);
  CREATE_SET(Default,bool);
  CREATE_SET(Info,char*);
  CREATE_SET(Location,char*);
  CREATE_SET(Uri,char*);
  CREATE_SET(State,char*);
  CREATE_SET(StateMessage,char*);
  CREATE_SET(Accepting,bool);
  CREATE_SET(BannerStart,char*);
  CREATE_SET(BannerEnd,char*);
  CREATE_SET(ppd,char*);  
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
  void addPrinters(const string p)
      {
        Printers.insert(p);
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
   * Get class name.
   * @return Class name.
   */
  string getClass() const
      {
        return Name;
      }
  /**
   * Get class name.
   * @return Class name as string. 
   */
  const char*getClass_str() const
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

    int getPrintersSize ()
            {
                return Printers.size();
            }
    
  /**
   * Dump values, for debugging purposes.
   */
  void dump() const;

  /**
   * Convert ClassEntry to YCPValue
   * @return Class settings as described in cups.txt (.cups.classes)
   */
  YCPValue Read() const;

  /**
   * Helper function for Write. Update class definition in cups system.
   * Updates class entry (this). Saves only changed items.
   * @param value New value of ClassEntry.
   * @return Success state.
   */
  bool changeClass(const YCPValue&value);

  /**
   * Add new class. Replace 
   */
  bool newClass(const YCPValue&value);
};

class ClassesConf
{
private:
  /**
   * List of ClassEntries.
   */
  list<ClassEntry> Classes;
  /**
   * Parse file classes.conf.
   * @param fn File to parse.
   * @return if the operation was successful.
   */
  bool parseFile(const char*fn);
    bool getClasses ();
  /**
   * Not all of the settings can be read from file classes.conf. This function reads additional
   * settings via cups library calls.
   * @return True if settings was read successfully.
   */
  bool completeEntries();
  /**
   * Erase all settings.
   */
  void Clear()
      {
        Classes.clear();
      }
  /**
   * Update class.
   */
  bool modifyClass(YCPMap clas);
  /**
   * Read classes.conf file. Build list of classes (Classes).
   * @param fn filename of the classes.conf.
   * @return True if file was read successfully.
   */
  bool readSettings(const char*fn);
  /**
   * Returns class entry by class name. If the class does not have an entry, it is created.
   * @param name Class name.
   * @return Iterator that points to class entry for class.
   */
  list<ClassEntry>::iterator getClassEntry(const string name);
  
  /**
   * Returns class entry by class name. If the class does not have an entry, returns Classes.end().
   * @param name Class name.
   * @return Iterator that points to class entry for class or Class.end()
   */  
  list<ClassEntry>::iterator findClass(const string name);

  void DeleteUnsavedClasses();  
  void UnsaveClasses();
public:
  /**
   * Default Constructor.
   */
  ClassesConf()
    : Classes()
      {
      }

  /**
   * Destructor.
   */
  ~ClassesConf()
      {
      }
  /**
   * Dump all classes.
   */
  void dump() const;
  
  /**
   * Convert ClassesConf to YCPValue
   */
  YCPValue Read();

  /**
   * Write classes...
   */
  YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());

};

#endif//_ClassesConf_h_
