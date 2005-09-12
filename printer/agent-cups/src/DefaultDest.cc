#include "DefaultDest.h"
#include "CupsCalls.h"

YCPValue DefaultDest::Read()
{
  string s = getDefaultDest();
  return YCPString(s);
}

YCPBoolean DefaultDest::Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg)
{
  //
  // value must be string
  //
  string argument = "";
  if ((! arg.isNull ()) && arg->isString ())
  {
    argument = arg->asString()->value();
  }

  if((! value.isNull ()) && value->isString())
  {
    if (argument == "local")
      setDefaultDestLocal (value->asString()->value_cstr());
    else
      setDefaultDest(value->asString()->value_cstr());
    return YCPBoolean(true);
  }
  return YCPBoolean(false);
}

