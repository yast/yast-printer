/* DestBase.cc
 *
 * Internal structure for Printer or Class.
 *
 * Author: Petr Blahos <pblahos@suse.cz>
 *
 * $Id$
 */

#include <fstream>
#include <cups/cups.h>
#include "DestBase.h"
#include "Y2Logger.h"
#include "CupsCalls.h"

void setPrinterOptions(const char*name,YCPMap&options,bool deflt = false);
bool newPrinter(const YCPValue&value);

/**
 * Convert options to map.
 */
void PrinterOptions2map(cups_dest_t*dest,map<string,string>&m)
{
  for(int i = 0;i<dest->num_options;i++)
    {
      m[dest->options[i].name] = dest->options[i].value;
    }
}

void DestBase::dump() const
{
  Y2_DEBUG("Printer[%c]: %s",Default ? 'D' : '-',Printer.c_str());
  Y2_DEBUG("Info:        %s",Info.c_str());
  Y2_DEBUG("Location:    %s",Location.c_str());
  Y2_DEBUG("Uri:         %s",Uri.c_str());
}

YCPValue DestBase::Read() const
{
  YCPMap m;

#define ADD_MAP(X) m->add(YCPString(#X),YCPString(X))
  ADD_MAP(Printer);
  ADD_MAP(Info);
  ADD_MAP(Location);
  ADD_MAP(Uri);
  ADD_MAP(State);
  ADD_MAP(StateMessage);
  ADD_MAP(BannerStart);
  ADD_MAP(BannerEnd);
  ADD_MAP(ppd);
#undef ADD_MAP
  
  m->add(YCPString("Default"),YCPBoolean(Default));
  m->add(YCPString("Accepting"),YCPBoolean(Accepting));
  m->add(YCPString("AllowUsers"),set2YCPList(AllowUsers));
  m->add(YCPString("DenyUsers"),set2YCPList(DenyUsers));
  m->add(YCPString("options"),map2YCPMap(options));

  return m;
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
  const char*xAllowUsers = NULL;
  const char*xDenyUsers = NULL;
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
  if(!(v = m->value(YCPString("Printer"))).isNull())    if(v->isString())       xPrinter = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("Info"))).isNull())       if(v->isString())       xInfo = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("Location"))).isNull())   if(v->isString())       xLoc = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("Uri"))).isNull())        if(v->isString())       xUri = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("State"))).isNull())      if(v->isString())       xState = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("StateMessage"))).isNull())if(v->isString())      xStateMsg = v->asString()->value_cstr();
  if(!(v = m->value(YCPString("Accepting"))).isNull())  if(v->isBoolean())      xAccepting = v->asBoolean()->value() ? "Yes" : "No";
  if(!m->value(YCPString("BannerStart")).isNull() || !m->value(YCPString("BannerStart")).isNull())
    {
      xBannerStart = m->value(YCPString("BannerEnd"))->asString()->value_cstr();
      xBannerEnd = m->value(YCPString("BannerEnd"))->asString()->value_cstr();
    }
  // FIXME: allow userd, deny users
  
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

/**
 * Set printer options in cups system.
 * @param name Name of the printer.
 * @param opt YCPMap of options.
 * @param defls Is this printer default printer?
 */
void setPrinterOptions(const char*name,YCPMap&opt,bool deflt = false)
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

