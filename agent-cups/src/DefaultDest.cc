#include "DefaultDest.h"
#include "CupsCalls.h"

YCPValue DefaultDest::Read()
{
  string s = getDefaultDest();
  return YCPString(s);
}

YCPValue DefaultDest::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
  //
  // value must be string
  //
  string argument = "";
  if (arg->isString ())
  {
    argument = arg->asString()->value();
  }

  if(value->isString())
  {
    if (argument == "local")
      setDefaultDestLocal (value->asString()->value_cstr());
    else
      setDefaultDest(value->asString()->value_cstr());
    return YCPBoolean(true);
  }
  return YCPBoolean(false);
}

