/* ClassesConf.cc
 *
 * Classes for reading/writting classes.conf.
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

#include <fstream>
#include <cups/ppd.h>
#include <cups/cups.h>
#include <cups/language.h>
#include "ClassesConf.h"
#include "Y2Logger.h"
#include "CupsCalls.h"
#include <ycp/YCPVoid.h>

void setClassOptions(const char*name,YCPMap&options,bool deflt = false);
bool newClass(const YCPValue&value);
set<string> YCPList2set (const YCPList&l);

YCPValue set2YCPList(const set<string>&l);
YCPValue list2YCPList(const list<string>&l);
YCPValue map2YCPMap(const map<string,string>&m);

bool ClassesConf::readSettings(const char*fn)
{
  Clear();
  if(!getClasses())
    {
      Y2_ERROR("ClassesConf::getClasses failed");
      return false;
    }
  if(!completeEntries())
    {
      Y2_ERROR("ClassesConf::completeEntries failed");
      return false;
    }
  return true;
}

/**
 * New version of get-classes that works over ipp...
 */
bool ClassesConf::getClasses ()
{
    http_t*http = httpConnect("localhost"/*cupsServer()*/, ippPort());
    ipp_t *request,	/* IPP Request */
        *response;	/* IPP Response */
    ipp_attribute_t *attr;	/* Current attribute */
    cups_lang_t	*language;	/* Default language */

    if(http == NULL)
        return false;

    /*
     * Build a CUPS_GET_CLASSES request, which requires the following
     * attributes:
     */
    
    request = ippNew();
    
    request->request.op.operation_id = CUPS_GET_CLASSES;
    request->request.op.request_id = 1;
    
    language = cupsLangDefault();
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_CHARSET,"attributes-charset",NULL,cupsLangEncoding(language));
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_LANGUAGE,"attributes-natural-language",NULL,language->language);

    /*
     * Do the request and get back a response...
     */

    if ((response = cupsDoRequest(http, request, "/")) != NULL)
        {
            Y2_DEBUG("cupsDoRequest to get classes succeded");
            if (response->request.status.status_code > IPP_OK_CONFLICT)
                {
                    Y2_DEBUG("lpstat: get-classes failed: %s\n",
                            ippErrorString(response->request.status.status_code));
                    ippDelete(response);
                    return false;
                }
            
            /*
             * Loop through the printers returned in the list and display
             * their devices... :-( well this comment is really obsoleted)
             */
            
            for (attr = response->attrs; attr != NULL; attr = attr->next)
                {
                    /*
                     * Skip leading attributes until we hit a job...
                     */
                    
                    while (attr != NULL && attr->group_tag != IPP_TAG_PRINTER)
                        attr = attr->next;

                    if (attr == NULL)
                        break;

                    ClassEntry newclass;
                    while (attr != NULL && attr->group_tag == IPP_TAG_PRINTER)
                        {
                            if (strcmp(attr->name, "printer-name") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    newclass.setName(attr->values[0].string.text);
                                    Y2_DEBUG("Class found: %s",attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-location") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newclass.setLocation(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-info") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newclass.setInfo(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "device-uri") == 0 && attr->value_tag == IPP_TAG_URI)
                                {
                                    newclass.setUri(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-state") == 0 && attr->value_tag == IPP_TAG_ENUM)
                                {
                                    newclass.setState(5==attr->values[0].integer ? "stopped" : "idle");
                                }
                            else if (strcmp(attr->name, "printer-state-message") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newclass.setStateMessage(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-state-message") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newclass.setInfo(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-is-accepting-jobs") == 0 && attr->value_tag == IPP_TAG_BOOLEAN)
                                {
                                    newclass.setAccepting(attr->values[0].boolean);
                                }
                            else if (strcmp(attr->name, "job-sheets-default") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    if(attr->num_values>1)
                                        newclass.setBannerEnd(attr->values[1].string.text);
                                    if(attr->num_values>0)
                                        newclass.setBannerStart(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "requesting-user-name-allowed") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    for(int i = 0;i<attr->num_values;i++)
                                        newclass.addAllowUsers(attr->values[i].string.text);
                                }
                            else if (strcmp(attr->name, "requesting-user-name-denied") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    for(int i = 0;i<attr->num_values;i++)
                                        newclass.addDenyUsers(attr->values[i].string.text);
                                }
                            else if (strcmp(attr->name, "member-names") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    Y2_DEBUG ("SOME member(s)...");
                                    for(int i = 0;i<attr->num_values;i++)
                                        {
                                            Y2_DEBUG ("     member %s",attr->values[i].string.text);
                                            newclass.addPrinters(attr->values[i].string.text);
                                        }
                                }
                            attr = attr->next;
                        }
                    // we need name and members
                    if(!newclass.getClass().empty() && newclass.getPrintersSize())
                        {
                            Y2_DEBUG("class %s valid", newclass.getClass().c_str());
                            Classes.insert(Classes.begin(),newclass);
                        }

                    if (attr == NULL)
                        break;
                }
            ippDelete(response);
        }
    else
        Y2_DEBUG("lpstat: get-classes failed: %s",ippErrorString(cupsLastError()));

    httpClose(http);
    
    return true;
}
/**
 * Convert options to map.
 * fixme: remove this function (it is already present as PrinterOptions2map)
 */
void ClassOptions2map(cups_dest_t*dest,map<string,string>&m)
{
  for(int i = 0;i<dest->num_options;i++)
    {
      m[dest->options[i].name] = dest->options[i].value;
    }
}
/**
 * Fill in options and ppd
 */
bool ClassesConf::completeEntries()
{
  int         num_dests;
  cups_dest_t *dests;
  cups_dest_t *dest;
  list<ClassEntry>::iterator it = Classes.begin();
  const char*ppd;
  
  num_dests = cupsGetDests(&dests);
  for(;it!=Classes.end();it++)
    {
      // get ppd
      ppd = getPPD(it->getClass_str());
      if(NULL!=ppd)
        it->setppd(ppd);
      // get options
      dest = cupsGetDest(it->getClass_str(),NULL,num_dests,dests);
      if(NULL!=dest)
        {
          // convert dest to options...
          ClassOptions2map(dest,it->getOptions());
        }
    }
  cupsFreeDests(num_dests,dests);
  
  return true;
}

list<ClassEntry>::iterator ClassesConf::getClassEntry(const string name)
{
  list<ClassEntry>::iterator it = Classes.begin();

  for(;it!=Classes.end();it++)
    {
      if(it->getClass()==name)
        return it;
    }
  // we have not found, create new
  ClassEntry p;
  p.setName(name.c_str());
  return Classes.insert(Classes.begin(),p);
}

list<ClassEntry>::iterator ClassesConf::findClass(const string name)
{
  list<ClassEntry>::iterator it = Classes.begin();

  for(;it!=Classes.end();it++)
    {
      if(it->getClass()==name)
        break;
    }
  return it;
}

void ClassesConf::dump() const
{
  for(list<ClassEntry>::const_iterator it = Classes.begin();it!=Classes.end();it++)
    it->dump();
}
void ClassEntry::dump() const
{
  Y2_DEBUG("Class[%c]: %s",Default ? 'D' : '-',Name.c_str());
  Y2_DEBUG("Info:        %s",Info.c_str());
  Y2_DEBUG("Location:    %s",Location.c_str());
  Y2_DEBUG("Uri:         %s",Uri.c_str());
}

YCPValue ClassEntry::Read() const
{
  YCPMap m;

#define ADD_MAP(X) {char* Y=TOLOWER(#X);m->add(YCPString(Y),YCPString(X));free(Y);}
  ADD_MAP(Name);
  ADD_MAP(Info);
  ADD_MAP(Location);
  ADD_MAP(State);
  ADD_MAP(StateMessage);
  ADD_MAP(BannerStart);
  ADD_MAP(BannerEnd);
#undef ADD_MAP
  
  m->add(YCPString("default"),YCPBoolean(Default));
  m->add(YCPString("accepting"),YCPBoolean(Accepting));
  m->add(YCPString("allowusers"),set2YCPList(AllowUsers));
  m->add(YCPString("denyusers"),set2YCPList(DenyUsers));
  m->add(YCPString("options"),map2YCPMap(options));
  m->add(YCPString("printers"),set2YCPList(Printers));

  return m;
}

YCPValue ClassesConf::Read()
{
  //
  // clear all and re-read setting
  //
  Clear();
  if(!readSettings("/etc/cups/classes.conf"))
    return YCPVoid();
  
  YCPList l;
  list<ClassEntry>::const_iterator it = Classes.begin();
  for(;it!=Classes.end();it++)
    l->add(it->Read());
  
  return l;
}

YCPBoolean ClassesConf::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
    if(2==path->length() && path->component_str(1) == "add")
    {
	if(value->isVoid())
	{
	    Y2_ERROR("Wrong value '%s' in Write(%s). We do not implement delete.",value->toString().c_str(),path->toString().c_str());
	    return YCPBoolean(false); //FIXME: it should return YCPValue(true/false)
	}
	else
	{
	    /*
	     * Writing:
	     *  Write(.cups.classes.<Class_name>,<value>)
	     */
	    //
	    // value should be list and arg should be empty
	    //
	    if(value->isMap())
	    {
		Clear();
		readSettings("/etc/cups/classes.conf");
		YCPMap cups_class = value->asMap();
		return YCPBoolean (modifyClass(cups_class));
	    }
	    else
		Y2_ERROR("There must be map (printer definition).");
	    return YCPBoolean (false);
	}
    }
    if (2 == path->length() && path->component_str(1) == "remove")
    {
        if(value->isVoid())
        {
            Y2_ERROR("Wrong value '%s' in Write(%s). We do not implement delete.",value->toString().c_str(),path->toString().c_str());
            return YCPBoolean (false);
        }
        else
        {
            //
            // value should be map and arg should be empty
            //
            if(value->isString())
            {
                Clear ();
                readSettings ("/etc/cups/classes.conf");
                YCPString cupsclass = value->asString();
                string name = cupsclass->asString()->value();
                deleteClass(name.c_str());  // save changes
		return YCPBoolean (true);
            }
            else
                Y2_ERROR("There must be map (printer definition).");
            return YCPBoolean (false);
        }
    }
    Y2_ERROR("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPBoolean(false);
}

bool newClass(const YCPValue&value)
{
    const char*xClass = NULL;
    const char*xInfo = NULL;
    const char*xLoc = NULL;
    const char*xUri = NULL;
    const char*xState = NULL;
    const char*xStateMsg = NULL;
    const char*xAccepting = NULL;
    const char*xBannerStart = NULL;
    const char*xBannerEnd = NULL;
    const char*xppd = NULL;
    set<string>xAllowUsers;
    set<string>xDenyUsers;
    set<string>xPrinters;
    YCPMap m;
    YCPValue v = YCPNull();
    bool ret = false;
  
    if(!value->isMap())
        {
            Y2_ERROR("Class definition must be map");
            return false;
        }
    m = value->asMap();
    if(!(v = m->value(YCPString("name"))).isNull())       if(v->isString())       xClass = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("info"))).isNull())       if(v->isString())       xInfo = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("location"))).isNull())   if(v->isString())       xLoc = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("uri"))).isNull())        if(v->isString())       xUri = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("state"))).isNull())      if(v->isString())       xState = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("statemessage"))).isNull())if(v->isString())      xStateMsg = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("accepting"))).isNull())  if(v->isBoolean())      xAccepting = v->asBoolean()->value() ? "Yes" : "No";
    if(!(v = m->value(YCPString("bannerstart"))).isNull())if(v->isString())       xBannerStart = v->asString()->value_cstr();
    if(!(v = m->value(YCPString("bannerend"))).isNull())  if(v->isString())       xBannerEnd = v->asString()->value_cstr();
    // allow users and deny users can not be used together
    // give precedence to allow users
    if(!(v = m->value(YCPString("allowusers"))).isNull())
        {
            YCPList l = v->asList();
            xAllowUsers = YCPList2set(l);
        }
    if(!(v = m->value(YCPString("denyusers"))).isNull())
        {
            YCPList l = v->asList();
            xDenyUsers = YCPList2set(l);
        }
    if(!(v = m->value(YCPString("printers"))).isNull())
        {
            YCPList l = v->asList();
            xPrinters = YCPList2set(l);
        }
    Y2_DEBUG("Number of printers in class %s: %d\n",xClass,xPrinters.size());

    if(!(v = m->value(YCPString("ppd"))).isNull())        if(v->isString())       xppd = v->asString()->value_cstr();
    ret = ::setClass(xClass,xInfo,xLoc,xState,xStateMsg,xBannerStart,xBannerEnd,xAllowUsers,xDenyUsers,xAccepting,xPrinters);
    Y2_DEBUG ("setClass %s",ret ? "OK" : "Error");

    if(!(v = m->value(YCPString("options"))).isNull())
        if(v->isMap())
            {
                YCPMap mp = v->asMap();
                setClassOptions(xClass,mp,false);
            }
  
    return ret;
}

bool ClassEntry::changeClass(const YCPValue&value)
{
  const char*xClass = NULL;
  const char*xInfo = NULL;
  const char*xLoc = NULL;
  const char*xUri = NULL;
  const char*xState = NULL;
  const char*xStateMsg = NULL;
  bool acc = Accepting;
  const char*xAccepting = NULL;
  const char*xBannerStart = NULL;
  const char*xBannerEnd = NULL;
  set<string>xAllowUsers;
  set<string>xDenyUsers;
  set<string>xPrinters;
  const char*xppd = NULL;
  YCPMap m;
  YCPValue v = YCPNull();
  bool ret = false;
  
  if(!value->isMap())
    {
      Y2_ERROR("Class definition must be map");
      return false;
    }
  m = value->asMap();
  if(!(v = m->value(YCPString("name"))).isNull())    if(v->isString())       xClass = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("info"))).isNull())       if(v->isString())       xInfo = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("location"))).isNull())   if(v->isString())       xLoc = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("uri"))).isNull())        if(v->isString())       xUri = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("state"))).isNull())      if(v->isString())       xState = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("statemessage"))).isNull())if(v->isString())      xStateMsg = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("accepting"))).isNull())  if(v->isBoolean())      xAccepting = (acc = v->asBoolean()->value()) ? "Yes" : "No";
  if(!m->value(YCPString("bannerstart")).isNull() || !m->value(YCPString("bannerstart")).isNull())
    {
      xBannerStart = m->value(YCPString("bannerstart"))->asString()->value_cstr();
      xBannerEnd = m->value(YCPString("bannerend"))->asString()->value_cstr();
    }
    // allow users and deny users can not be used together
    // give precedence to allow users
    if(!(v = m->value(YCPString("allowusers"))).isNull())
        {
            YCPList l = v->asList();
            xAllowUsers = YCPList2set(l);
        }
    if(!(v = m->value(YCPString("denyusers"))).isNull())
        {
            YCPList l = v->asList();
            xDenyUsers = YCPList2set(l);
        }
    if(xAllowUsers==AllowUsers && xDenyUsers==DenyUsers)
        {
            xAllowUsers.clear();
            xDenyUsers.clear();
        }
    if(!(v = m->value(YCPString("printers"))).isNull())
        {
            YCPList l = v->asList();
            xPrinters = YCPList2set(l);
        }
    if(xPrinters==Printers)
        {
            xPrinters.clear();
        }

  if(!(v = m->value(YCPString("ppd"))).isNull())        if(v->isString())       xppd = v->asString()->value_cstr();

  if(NULL!=xInfo && Info==xInfo)                  xInfo = NULL;
  if(NULL!=xLoc && Location==xLoc)                xLoc = NULL;
  if(NULL!=xUri && Uri==xUri)                     xUri = NULL;
  if(NULL!=xState && State==xState)               xState = NULL;
  if(NULL!=xStateMsg && StateMessage==xStateMsg)  xStateMsg = NULL;
  if(NULL!=xBannerStart && NULL!=xBannerEnd && BannerStart==xBannerStart && BannerEnd==xBannerEnd)
    xBannerStart = xBannerEnd = NULL;
  if(NULL!=xppd && ppd==xppd)                     xppd = NULL;
  if(Accepting==acc)                              xAccepting = NULL;

  ret = ::setClass(xClass,xInfo,xLoc,xState,xStateMsg,xBannerStart,xBannerEnd,xAllowUsers,xDenyUsers,xAccepting,xPrinters);
  Y2_DEBUG ("Change class: %s",ret ? "OK" : "Error");

  //
  // class is set, now set options...
  // I am affraid we really have to read all options and the choose one,
  // modify it and then set it
  //

  if(!(v = m->value(YCPString("options"))).isNull())
    if(v->isMap())
      {
        YCPMap mp = v->asMap();
        setClassOptions(xClass,mp,false);
      }

  setSaved();
  
  return ret;
}

/**
 * Set class options in cups system.
 * @param name Name of the class.
 * @param opt YCPMap of options.
 * @param defls Is this class default class?
 */
void setClassOptions(const char*name,YCPMap&opt,bool deflt)
{
  int         num_dests;
  cups_dest_t *dests;
  cups_dest_t *dest;
  int		num_options = 0;	/* Number of options */
  cups_option_t	*options = NULL;	/* Options */
  
  num_dests = cupsGetDests(&dests);
  dest = cupsGetDest(name,NULL,num_dests,dests);
  if(NULL==dest)
    { // request to change options to non-existing class
      cupsFreeDests(num_dests,dests);
      return ;
    }
  
  // we have the class
  if(deflt)
    {
      for(int j = 0;j<num_dests;j++)
        dests[j].is_default = 0;
      dest->is_default = 1;
    }
  YCPMapIterator it = opt->begin();
  for(;it!=opt->end();it++)
    {
      string k,v;
      if(it.key()->isString())
        {
          k = it.key()->asString()->value();
          if(it.value()->isString())
            v = it.value()->asString()->value();
        }
      if(!k.empty())
        {
          num_options = cupsAddOption(k.c_str(),v.c_str(),num_options,&options);
        }
    }
  cupsFreeOptions(dest->num_options,dest->options);
  dest->num_options = num_options;
  dest->options = options;
  cupsSetDests(num_dests,dests);
  cupsFreeDests(num_dests,dests);
  
  return ;  
}

bool ClassesConf::modifyClass(YCPMap clas)
{
  //
  // Get clas name
  //
  YCPValue temp = clas->value(YCPString("name"));
  if(!temp->isString())
    {
      Y2_ERROR("Invalid class entry");
      return false;
    }
  string name = temp->asString()->value();

  //
  // find this clas in list of classes
  //
  list<ClassEntry>::iterator it = findClass(name);
  if(Classes.end()==it)
    {
      //
      // new clas
      //
      return newClass(clas);
    }
  else
    {
        //
        // modify clas
        //
        it->setSaved();
        return newClass(clas);
    }
}
