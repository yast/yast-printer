/* PrintersConf.cc
 *
 * Classes for reading/writting printers.conf.
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

/*

  FIXME: default destination is read only from printers.conf,
  but it must be overrided by dest (cupsGetDests) settings.

*/

#include <fstream>
#include <cups/cups.h>
#include <cups/ppd.h>
#include <cups/language.h>
#include "PrintersConf.h"
#include "Y2Logger.h"
#include "CupsCalls.h"

bool newPrinter(const YCPValue&value);

bool PrintersConf::readSettings(const char*fn)
{
  Clear();
  if(!getPrinters())
    {
      Y2_ERROR("PrintersConf::getPrinters failed");
      return false;
    }
  if(!completeEntries())
    {
      Y2_ERROR("PrintersConf::completeEntries failed");
      return false;
    }
  return true;
}

/**
 * New version of get-classes that works over ipp...
 */
bool PrintersConf::getPrinters ()
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
    
    request->request.op.operation_id = CUPS_GET_PRINTERS;
    request->request.op.request_id = 1;
    
    language = cupsLangDefault();
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_CHARSET,"attributes-charset",NULL,cupsLangEncoding(language));
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_LANGUAGE,"attributes-natural-language",NULL,language->language);

    /*
     * Do the request and get back a response...
     */

    if ((response = cupsDoRequest(http, request, "/")) != NULL)
        {
            Y2_DEBUG("cupsDoRequest to get printers succeded");
            if (response->request.status.status_code > IPP_OK_CONFLICT)
                {
                    Y2_DEBUG("lpstat: get-printers failed: %s\n",
                            ippErrorString(response->request.status.status_code));
                    ippDelete(response);
		    httpClose(http);
                    return false;
                }
            
            /*
             * Loop through the printers returned in the list and display
             * their devices...
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

                    PrinterEntry newprinter;
                    while (attr != NULL && attr->group_tag == IPP_TAG_PRINTER)
                        {
                            if (strcmp(attr->name, "printer-name") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    newprinter.setName(attr->values[0].string.text);
                                    Y2_DEBUG("Printer found: %s",attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-location") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newprinter.setLocation(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-info") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newprinter.setInfo(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "device-uri") == 0 && attr->value_tag == IPP_TAG_URI)
                                {
                                    newprinter.setUri(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-state") == 0 && attr->value_tag == IPP_TAG_ENUM)
                                {
                                    newprinter.setState(5==attr->values[0].integer ? "stopped" : "idle");
                                }
                            else if (strcmp(attr->name, "printer-state-message") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newprinter.setStateMessage(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-state-message") == 0 && attr->value_tag == IPP_TAG_TEXT)
                                {
                                    newprinter.setInfo(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "printer-is-accepting-jobs") == 0 && attr->value_tag == IPP_TAG_BOOLEAN)
                                {
                                    newprinter.setAccepting(attr->values[0].boolean);
                                }
                            else if (strcmp(attr->name, "job-sheets-default") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    if(attr->num_values>1)
                                        newprinter.setBannerEnd(attr->values[1].string.text);
                                    if(attr->num_values>0)
                                        newprinter.setBannerStart(attr->values[0].string.text);
                                }
                            else if (strcmp(attr->name, "requesting-user-name-allowed") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    for(int i = 0;i<attr->num_values;i++)
                                        newprinter.addAllowUsers(attr->values[i].string.text);
                                }
                            else if (strcmp(attr->name, "requesting-user-name-denied") == 0 && attr->value_tag == IPP_TAG_NAME)
                                {
                                    for(int i = 0;i<attr->num_values;i++)
                                        newprinter.addDenyUsers(attr->values[i].string.text);
                                }
                            attr = attr->next;
                        }
                    // we need name
                    if(!newprinter.getPrinter().empty())
                        {
                            Y2_DEBUG("printer %s valid", newprinter.getPrinter().c_str());
                            Printers.insert(Printers.begin(),newprinter);
                        }

                    if (attr == NULL)
                        break;
                }
            ippDelete(response);
        }
    else
    {
        Y2_DEBUG("lpstat: get-printers failed: %s",ippErrorString(cupsLastError()));
	httpClose(http);
	return false;
    }

    httpClose(http);

    return true;
}

/**
 * Convert options to map.
 */
void PrinterOptions2map(cups_dest_t*dest,map<string,string>&m)
{
    for(int i = 0;i<dest->num_options;i++)
        m[dest->options[i].name] = dest->options[i].value;
}
/**
 * Fill in options and ppd
 */
bool PrintersConf::completeEntries()
{
  int         num_dests;
  cups_dest_t *dests;
  cups_dest_t *dest;
  list<PrinterEntry>::iterator it = Printers.begin();
  const char*ppd;
  
  num_dests = cupsGetDests(&dests);
  for(;it!=Printers.end();it++)
    {
      // get ppd
      ppd = getPPD(it->getPrinter_str());
      if(NULL!=ppd)
        it->setppd(ppd);
      // get options
      dest = cupsGetDest(it->getPrinter_str(),NULL,num_dests,dests);
      if(NULL!=dest)
        {
          // convert dest to options...
          PrinterOptions2map(dest,it->getOptions());
        }
    }
  cupsFreeDests(num_dests,dests);
  
  return true;
}

list<PrinterEntry>::iterator PrintersConf::getPrinterEntry(const string name)
{
  list<PrinterEntry>::iterator it = Printers.begin();

  for(;it!=Printers.end();it++)
    {
      if(it->getPrinter()==name)
        return it;
    }
  // we have not found, create new
  PrinterEntry p;
  p.setName(name);
  return Printers.insert(Printers.begin(),p);
}

list<PrinterEntry>::iterator PrintersConf::findPrinter(const string name)
{
  list<PrinterEntry>::iterator it = Printers.begin();

  for(;it!=Printers.end();it++)
    {
      if(it->getPrinter()==name)
        break;
    }
  return it;
}

void PrintersConf::dump() const
{
  for(list<PrinterEntry>::const_iterator it = Printers.begin();it!=Printers.end();it++)
    it->dump();
}
void PrinterEntry::dump() const
{
  Y2_DEBUG("Printer[%c]: %s",Default ? 'D' : '-',Name.c_str());
  Y2_DEBUG("Info:        %s",Info.c_str());
  Y2_DEBUG("Location:    %s",Location.c_str());
  Y2_DEBUG("Uri:         %s",Uri.c_str());
}

set<string> YCPList2set (const YCPList&l)
{
    set<string> out;
    int i,len = l->size();
    for (i = 0;i < len;i++)
        {
            if (l->value (i)->isString ())
                {
                    out.insert (l->value (i)->asString ()->value_cstr ());
                }
            else
                {
                    Y2_ERROR ("Expecting string here");
                }
        }
    return out;
}

YCPValue set2YCPList(const set<string>&l)
{
  YCPList out;
  set<string>::const_iterator it = l.begin();
  for(;it!=l.end();it++)
    out->add(YCPString(*it));
  return out;
}
YCPValue list2YCPList(const list<string>&l)
{
  YCPList out;
  list<string>::const_iterator it = l.begin();
  for(;it!=l.end();it++)
    out->add(YCPString(*it));
  return out;
}
YCPValue map2YCPMap(const map<string,string>&m)
{
  YCPMap out;
  map<string,string>::const_iterator it = m.begin();
  for(;it!=m.end();it++)
      {
          out->add(YCPString(it->first),YCPString(it->second));
      }
  return out;
}

YCPValue PrinterEntry::Read() const
{
  YCPMap m;

#define ADD_MAP(X) {char* Y=TOLOWER(#X);m->add(YCPString(Y),YCPString(X));free(Y);}
  ADD_MAP(Name);
  ADD_MAP(Info);
  ADD_MAP(Location);
  ADD_MAP(Uri);
  ADD_MAP(State);
  ADD_MAP(StateMessage);
  ADD_MAP(BannerStart);
  ADD_MAP(BannerEnd);
  ADD_MAP(ppd);
#undef ADD_MAP
  
  m->add(YCPString("default"),YCPBoolean(Default));
  m->add(YCPString("accepting"),YCPBoolean(Accepting));
  m->add(YCPString("allowusers"),set2YCPList(AllowUsers));
  m->add(YCPString("denyusers"),set2YCPList(DenyUsers));
  m->add(YCPString("options"),map2YCPMap(options));

  return m;
}

YCPValue PrintersConf::Read()
{
    //
    // clear all and re-read setting
    //
    YCPList l; 
    Clear();
    if(!readSettings("/etc/cups/printers.conf"))
        return l; // empty list

    list<PrinterEntry>::const_iterator it = Printers.begin();
    for(;it!=Printers.end();it++)
        l->add(it->Read());

    return l;
}

YCPBoolean PrintersConf::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
//  Y2_ERROR("Write .cups.printers");
    if(2==path->length() && path->component_str(1) == "add")
    {
        if(value->isVoid())
        {
            Y2_ERROR("Wrong value '%s' in Write(%s). We do not implement delete.",value->toString().c_str(),path->toString().c_str());
            return YCPBoolean (false);
        }
        else
        {
	    /*
             * Writing:
             *  Write(.cups.printers,<value>)
             */
            //
            // value should be map and arg should be empty
            //
            if(value->isMap())
            {
                Clear ();
                readSettings ("/etc/cups/printers.conf");
		YCPMap printer = value->asMap();
                return YCPBoolean (modifyPrinter(printer));  // save changes
            }
	    else
		Y2_ERROR("There must be map (printer definition).");
            return YCPBoolean(false);
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
                readSettings ("/etc/cups/printers.conf");
                YCPString printer = value->asString();
		string name = printer->asString()->value();
                deletePrinter(name.c_str());  // save changes
		return YCPBoolean (true);
            }
	    else
		Y2_ERROR("There must be map (printer definition).");
            return YCPBoolean(false);
        }
    }
    Y2_ERROR("Wrong path '%s' in Write().", path->toString().c_str());
    return YCPBoolean(false);
}

bool newPrinter(const YCPValue&value)
{
    const char*xPrinter = NULL;
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
    YCPMap m;
    YCPValue v = YCPNull();
    bool ret = false;
  
    if(!value->isMap())
        {
            Y2_ERROR("Printer definition must be map");
            return false;
        }
    m = value->asMap();
    if(!(v = m->value(YCPString("name"))).isNull())    if(v->isString())       xPrinter = v->asString()->value_cstr();
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

    if(!(v = m->value(YCPString("ppd"))).isNull())        if(v->isString())       xppd = v->asString()->value_cstr();
    ret = ::setPrinter(xPrinter,xInfo,xLoc,xState,xStateMsg,xBannerStart,xBannerEnd,xUri,xAllowUsers,xDenyUsers,xppd,xAccepting);

    if(!(v = m->value(YCPString("options"))).isNull())
        if(v->isMap())
            {
                YCPMap mp = v->asMap();
                setPrinterOptions(xPrinter,mp,false);
            }
  
    return ret;
}

bool PrinterEntry::changePrinter(const YCPValue&value)
{
    const char*xPrinter = NULL;
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
    const char*xppd = NULL;
    YCPMap m;
    YCPValue v = YCPNull();
    bool ret = false;
  
    if(!value->isMap())
        {
            Y2_ERROR("Printer definition must be map");
            return false;
        }
    m = value->asMap();
    if(!(v = m->value(YCPString("name"))).isNull())    if(v->isString())       xPrinter = v->asString()->value_cstr();
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

    ret = ::setPrinter(xPrinter,xInfo,xLoc,xState,xStateMsg,xBannerStart,xBannerEnd,xUri,xAllowUsers,xDenyUsers,xppd,xAccepting);
    Y2_DEBUG ("Change printer: %s", ret ? "OK" : "Error");

    //
    // printer is set, now set options...
    // I am affraid we really have to read all options and the choose one,
    // modify it and then set it
    //

    if(!(v = m->value(YCPString("options"))).isNull())
        if(v->isMap())
            {
                YCPMap mp = v->asMap();
                setPrinterOptions(xPrinter,mp,false);
            }

    setSaved();
  
    return ret;
}

/**
  * Get printer options in cups system
  * @param name Name of the printer.
  * @return YCPMap of options.
  */
YCPMap getPrinterOptions(const char *name) {
    int         num_dests;
    cups_dest_t *dests;
    cups_dest_t *dest;
  
    num_dests = cupsGetDests(&dests);
    dest = cupsGetDest(name,NULL,num_dests,dests);
    if(NULL==dest)
    { // request to change options to non-existing printer
	cupsFreeDests(num_dests,dests);
	return YCPMap ();
    }

    YCPMap m;
    for (int i = 0 ; i < dest->num_options; i++)
    {
	m->add (YCPString (dest->options[i].name),
	    YCPString (dest->options[i].value));
    }

    cupsFreeDests(num_dests,dests);
    return m;  
}

/**
 * Set printer options in cups system.
 * @param name Name of the printer.
 * @param opt YCPMap of options.
 * @param defls Is this printer default printer?
 */
void setPrinterOptions(const char*name,YCPMap&opt,bool deflt)
{
    int         num_dests;
    cups_dest_t *dests;
    cups_dest_t *dest;
    int		num_options = 0;	/* Number of options */
    cups_option_t	*options = NULL;	/* Options */
  
    num_dests = cupsGetDests(&dests);
    dest = cupsGetDest(name,NULL,num_dests,dests);
    if(NULL==dest)
        { // request to change options to non-existing printer
            cupsFreeDests(num_dests,dests);
            return ;
        }
  
    // we have the printer
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

bool PrintersConf::modifyPrinter(YCPMap printer)
{
    //
    // Get printer name
    //
    YCPValue temp = printer->value(YCPString("name"));
    if(!temp->isString())
        {
            Y2_ERROR("Invalid printer entry");
            return false;
        }
    string name = temp->asString()->value();

    //
    // find this printer in list of printers
    //
    list<PrinterEntry>::iterator it = findPrinter(name);
    if(Printers.end()==it)
        {
            //
            // new printer
            //
            return newPrinter(printer);
        }
    else
        {
            //
            // modify printer
            //
            it->setSaved();
            return newPrinter(printer);
        }
}
