#include "CupsCalls.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/fcntl.h>
#include <cups/ppd.h>
#include <cups/cups.h>
#include <cups/language.h>
#include <ctype.h>

#include "Y2Logger.h"

/**
 * Get the ppd file for printer/class
 *
 * When no ppd is assotiated with printer/class, the file is html file that contains info
 * about an error. We must detect it and return 0.
 */
const char*getPPD(const char*name)
{
  char c;
  const char*fn = cupsGetPPD(name);
  int fd = open(fn,O_RDONLY);
  if(-1==fd)
    return 0;
  //
  // check if it is not html file
  //
  if(read(fd,&c,1)<1)
    fn = 0;
  else
    if('<'==c)
      fn = 0;
  close(fd);
  return fn;
}

// FIXME: return value...?
bool setPrinter(const char*name,const char*info,const char*loc,const char*state,const char*statemsg,
                const char*bannerstart,const char*bannerend,const char*deviceuri,
                const set<string>allowusers,const set<string>denyusers,const char*ppd,const char*accepting)
{
  http_t	*http;		/* Connection to server */
  ipp_t		*request,		/* IPP Request */
		*response;		/* IPP Response */
  cups_lang_t	*language;		/* Default language */
  char		uri[HTTP_MAX_URI];	/* URI for printer/class */
  bool ret = true;
  

  if(!(http = httpConnect("localhost"/*cupsServer()*/, ippPort())))
    {
      Y2_ERROR("Error while contacting CUPS server occured.");
      return false;
    }


  snprintf(uri, sizeof(uri), "ipp://localhost/printers/%s",name);

  request = ippNew();
  request->request.op.operation_id = CUPS_ADD_PRINTER;
  request->request.op.request_id   = 1;

  language = cupsLangDefault();

  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, uri);
  /*
   * settings
   */
  if(NULL!=bannerend || NULL!=bannerstart)
    {
      const char*valv[2];
      valv[0] = bannerstart;
      valv[1] = bannerend;  // fixme check these values for NULL!!!
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"job-sheets-default",2,NULL,valv);
    }
  if(NULL!=deviceuri)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_URI,"device-uri",NULL,deviceuri);
  if(NULL!=ppd)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"ppd-name",NULL,ppd);
  if(NULL!=accepting)
    {
      if(!strcasecmp(accepting,"yes"))
        ippAddBoolean(request,IPP_TAG_PRINTER,"printer-is-accepting-jobs",1);
      else if(!strcasecmp(accepting,"no"))
        ippAddBoolean(request,IPP_TAG_PRINTER,"printer-is-accepting-jobs",0);
    }
  if(NULL!=info)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-info",NULL,info);
  if(NULL!=loc)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-location",NULL,loc);
  if(NULL!=state)
    {
      if(!strcasecmp(state,"idle"))
         ippAddInteger(request,IPP_TAG_PRINTER,IPP_TAG_ENUM,"printer-state",IPP_PRINTER_IDLE);
      else if(!strcasecmp(state,"stopped"))
         ippAddInteger(request,IPP_TAG_PRINTER,IPP_TAG_ENUM,"printer-state",IPP_PRINTER_STOPPED);
    }
  if(NULL!=statemsg)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-state-message",NULL,statemsg);

  int len;
  if((len = allowusers.size()))
    {
      int i = 0;
      const char**v;
      v = new const char*[len];
      set<string>::const_iterator it = allowusers.begin();
      for(;it!=allowusers.end();it++)
        v[i++] = it->c_str();
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"requesting-user-name-allowed",len,NULL,v);
      delete [] v;  // this is correct, because ippAddString(s) copies arguments
    }
  else if((len = denyusers.size()))
    {
      int i = 0;
      const char**v;
      v = new const char*[len];
      set<string>::const_iterator it = denyusers.begin();
      for(;it!=denyusers.end();it++)
        v[i++] = it->c_str();
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"requesting-user-name-denied",len,NULL,v);
      delete [] v;  // this is correct, because ippAddString(s) copies arguments
    }
  else
    {
      ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_DELETEATTR,"requesting-user-name-allowed",NULL,NULL);
    }
  
  /*
   * Do the request and get back a response...
   */
  if(NULL!=ppd && '\0' != ppd[0])
    response = cupsDoFileRequest(http,request,"/admin/",ppd);
  else
    response = cupsDoRequest(http,request,"/admin/");
  if(response==NULL)
    {
      Y2_ERROR("cups(File)DoRequest error: %s",ippErrorString(cupsLastError()));
      ret = false;
    }  
  else
    {
      if (response->request.status.status_code > IPP_OK_CONFLICT)
        {
          Y2_ERROR("cups(File)DoRequest error: %s",ippErrorString(response->request.status.status_code));
          ret = false;
        }
      ippDelete(response);
    }
  
  httpClose(http);
  
  return ret;
}
bool setClass(const char*name,const char*info,const char*loc,const char*state,const char*statemsg,
              const char*bannerstart,const char*bannerend,
              const set<string>allowusers,const set<string>denyusers,const char*accepting,
              const set<string>members)
{
  http_t	*http;		/* Connection to server */
  ipp_t		*request,		/* IPP Request */
		*response;		/* IPP Response */
  cups_lang_t	*language;		/* Default language */
  char		uri[HTTP_MAX_URI];	/* URI for printer/class */
  bool ret = true;
  

  if(!(http = httpConnect("localhost"/*cupsServer()*/, ippPort())))
    {
      Y2_ERROR("Error while contacting CUPS server occured.");
      return false;
    }

  snprintf(uri, sizeof(uri), "ipp://localhost/classes/%s",name);

  request = ippNew();
  request->request.op.operation_id = CUPS_ADD_CLASS;
  request->request.op.request_id   = 1;

  language = cupsLangDefault();

  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, uri);
  /*
   * settings
   */
  if(NULL!=bannerend || NULL!=bannerstart)
    {
      const char*valv[2];
      valv[0] = bannerstart;
      valv[1] = bannerend; // fixme check these values for null
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"job-sheets-default",2,NULL,valv);
    }
  if(NULL!=accepting)
    {
      if(!strcasecmp(accepting,"yes"))
        ippAddBoolean(request,IPP_TAG_PRINTER,"printer-is-accepting-jobs",1);
      else if(!strcasecmp(accepting,"no"))
        ippAddBoolean(request,IPP_TAG_PRINTER,"printer-is-accepting-jobs",0);
    }
  if(NULL!=info)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-info",NULL,info);
  if(NULL!=loc)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-location",NULL,loc);
  if(NULL!=state)
    {
      if(!strcasecmp(state,"idle"))
         ippAddInteger(request,IPP_TAG_PRINTER,IPP_TAG_ENUM,"printer-state",IPP_PRINTER_IDLE);
      else if(!strcasecmp(state,"stopped"))
         ippAddInteger(request,IPP_TAG_PRINTER,IPP_TAG_ENUM,"printer-state",IPP_PRINTER_STOPPED);
    }
  if(NULL!=statemsg)
    ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_TEXT,"printer-state-message",NULL,statemsg);


  int len;
  if((len = allowusers.size()))
    {
      int i = 0;
      const char**v;
      v = new const char*[len];
      set<string>::const_iterator it = allowusers.begin();
      for(;it!=allowusers.end();it++)
        v[i++] = it->c_str();
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"requesting-user-name-allowed",len,NULL,v);
      delete [] v;  // this is correct, because ippAddString(s) copies arguments
    }
  else if((len = denyusers.size()))
    {
      int i = 0;
      const char**v;
      v = new const char*[len];
      set<string>::const_iterator it = denyusers.begin();
      for(;it!=denyusers.end();it++)
        v[i++] = it->c_str();
      ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_NAME,"requesting-user-name-denied",len,NULL,v);
      delete [] v;  // this is correct, because ippAddString(s) copies arguments
    }
  else
    {
      ippAddString(request,IPP_TAG_PRINTER,IPP_TAG_DELETEATTR,"requesting-user-name-allowed",NULL,NULL);
    }

  //
  // add printers finally
  //
  if((len = members.size()))
      {
          int i = 0;
          char added_uri[HTTP_MAX_URI];
          ipp_attribute_t*attr = ippAddStrings(request,IPP_TAG_PRINTER,IPP_TAG_URI,"member-uris",len,NULL,NULL);
          set<string>::const_iterator it = members.begin();
          for(;it!=members.end();it++)
              {
                  snprintf(added_uri,sizeof(added_uri),"ipp://localhost/printers/%s",it->c_str());
                  attr->values[i++].string.text = strdup(added_uri);
              }
      }
  /*
   * Do the request and get back a response...
   */
  response = cupsDoRequest(http,request,"/admin/");
  if(response==NULL)
    {
      Y2_ERROR("cups(File)DoRequest error: %s",ippErrorString(cupsLastError()));
      ret = false;
    }  
  else
    {
      if (response->request.status.status_code > IPP_OK_CONFLICT)
        {
          Y2_ERROR("cups(File)DoRequest error: %s",ippErrorString(response->request.status.status_code));
          ret = false;
        }
      ippDelete(response);
    }  
  httpClose(http);
  
  return ret;
}

bool deletePrinter(const char*name)
{
  bool ret = true;
  http_t *http;		/* Connection to server */
  ipp_t		*request,		/* IPP Request */
		*response;		/* IPP Response */
  cups_lang_t	*language;		/* Default language */
  char		uri[HTTP_MAX_URI];	/* URI for printer/class */


  if(!(http = httpConnect("localhost"/*cupsServer()*/, ippPort())))
    {
      Y2_ERROR("Error while contacting CUPS server occured");
      return false;
    }
  
  snprintf(uri,sizeof(uri),"ipp://localhost/printers/%s",name);

  request = ippNew();
  request->request.op.operation_id = CUPS_DELETE_PRINTER;
  request->request.op.request_id   = 1;

  language = cupsLangDefault();
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, uri);

 /*
  * Do the request and get back a response...
  */
  if ((response = cupsDoRequest(http, request, "/admin/")) == NULL)
    {
      Y2_ERROR("cupsDoRequest error: %s",ippErrorString(cupsLastError()));
//      fprintf(stderr, "lpadmin: delete-printer failed: %s\n",
//              ippErrorString(cupsLastError()));
      ret = false;
    }
  else
  {
    if (response->request.status.status_code > IPP_OK_CONFLICT)
      {
        Y2_ERROR("cupsDoRequest error: %s",ippErrorString(response->request.status.status_code));
//        fprintf(stderr, "lpadmin: delete-printer failed: %s\n",
//                ippErrorString(response->request.status.status_code));
        ret = false;
      }

    ippDelete(response);
  }  
  httpClose(http);
  
  return ret;
}

bool deleteClass(const char*name)
{
  bool ret = true;
  http_t *http;		/* Connection to server */
  ipp_t		*request,		/* IPP Request */
		*response;		/* IPP Response */
  cups_lang_t	*language;		/* Default language */
  char		uri[HTTP_MAX_URI];	/* URI for printer/class */


  if(!(http = httpConnect("localhost"/*cupsServer()*/, ippPort())))
    {
      Y2_ERROR("Error while contacting CUPS server occured");
      return false;
    }
  
  snprintf(uri,sizeof(uri),"ipp://localhost/printers/%s",name);

  request = ippNew();
  request->request.op.operation_id = CUPS_DELETE_CLASS;
  request->request.op.request_id   = 1;

  language = cupsLangDefault();
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, uri);

 /*
  * Do the request and get back a response...
  */
  if ((response = cupsDoRequest(http, request, "/admin/")) == NULL)
    {
      Y2_ERROR("cupsDoRequest error: %s",ippErrorString(cupsLastError()));
//      fprintf(stderr, "lpadmin: delete-printer failed: %s\n",
//              ippErrorString(cupsLastError()));
      ret = false;
    }
  else
  {
    if (response->request.status.status_code > IPP_OK_CONFLICT)
      {
        Y2_ERROR("cupsDoRequest error: %s",ippErrorString(response->request.status.status_code));
//        fprintf(stderr, "lpadmin: delete-printer failed: %s\n",
//                ippErrorString(response->request.status.status_code));
        ret = false;
      }

    ippDelete(response);
  }  
  httpClose(http);
  
  return ret;
}
/**
 * Get default destination.
 * @return Name of printer.
 */
string getDefaultDest()
{
  string s;
  cups_dest_t *dests;
  int num_dests = cupsGetDests(&dests);

  for(int i = 0;i<num_dests;i++)
  {
    if(dests[i].is_default)
      {
        s = dests[i].name;
        break;
      }
  }
  return s;
}

/**
 * Set default destination.
 * @param d Name of default destination.
 * @return Success state.
 */
bool setDefaultDest(const char*d)
{
  cups_dest_t *dests;
  int num_dests = cupsGetDests(&dests);
  for(int i = 0;i<num_dests;i++)
    if(dests[i].is_default)
      dests[i].is_default = 0;
  cupsSetDests(num_dests,dests);

  bool ret = true;
  http_t *http;		/* Connection to server */
  ipp_t		*request,		/* IPP Request */
		*response;		/* IPP Response */
  cups_lang_t	*language;		/* Default language */
  char		uri[HTTP_MAX_URI];	/* URI for printer/class */

  if(!(http = httpConnect("localhost"/*cupsServer()*/, ippPort())))
    {
      Y2_ERROR("Error while contacting CUPS server occured");
      return false;
    }

  snprintf(uri, sizeof(uri), "ipp://localhost/printers/%s",d);

  request = ippNew();
  request->request.op.operation_id = CUPS_SET_DEFAULT;
  request->request.op.request_id   = 1;

  language = cupsLangDefault();
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);
  ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_URI,
               "printer-uri", NULL, uri);
  
  /*
   * Do the request and get back a response...
   */
  if ((response = cupsDoRequest(http, request, "/admin/")) == NULL)
    {
      ret = false;
      Y2_ERROR("cupsDoRequest error: %s",ippErrorString(cupsLastError()));
    }
  else
    {
      if (response->request.status.status_code > IPP_OK_CONFLICT)
        {
          ret = false;
          Y2_ERROR("cupsDoRequest error: %s",ippErrorString(response->request.status.status_code));
        }
      ippDelete(response);
    }
  httpClose(http);
  
  return ret;
}

/**
 * New version of get-classes that works over ipp...
 */
bool getClasses ()
{
    http_t*http = httpConnect("localhost"/*cupsServer()*/, ippPort());
//    int		i;		/* Looping var */
    ipp_t		*request,	/* IPP Request */
        *response;	/* IPP Response */
    ipp_attribute_t *attr;	/* Current attribute */
    cups_lang_t	*language;	/* Default language */
    const char	*printer,	/* Printer class name */
        *printer_uri;	/* Printer class URI */
    ipp_attribute_t *members;	/* Printer members */
    
    if (http == NULL) 
        return false;  // fixme error message

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
    /* we want all! thats why this is commented out.
    ippAddStrings(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD,
                  "requested-attributes", sizeof(cattrs) / sizeof(cattrs[0]),
                  NULL, cattrs);*/

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

                    /*
                     * Pull the needed attributes from this job...
                     */

                    printer     = NULL;
                    printer_uri = NULL;
                    members     = NULL;

                    while (attr != NULL && attr->group_tag == IPP_TAG_PRINTER)
                        {
                            if (strcmp(attr->name, "printer-name") == 0 &&
                                attr->value_tag == IPP_TAG_NAME)
                                {
                                    printer = attr->values[0].string.text;
                                    printf("%s:\t%s\n",attr->name,attr->values[0].string.text);
                                }
                            else
                                printf("\t%s\n",attr->name);
                            
                            if (strcmp(attr->name, "printer-uri-supported") == 0 &&
                                attr->value_tag == IPP_TAG_URI)
                                printer_uri = attr->values[0].string.text;
                            
                            if (strcmp(attr->name, "member-names") == 0 &&
                                attr->value_tag == IPP_TAG_NAME)
                                members = attr;
                            
                            attr = attr->next;
                        }

                    /*
                     * See if we have everything needed...
                     */
                    
                    if (printer == NULL)
                        {
                            if (attr == NULL)
                                break;
                            else
                                continue;
                        }

                    if (attr == NULL)
                        break;
                }

            ippDelete(response);
        }
    else
        fprintf(stderr, "lpstat: get-classes failed: %s\n",
                ippErrorString(cupsLastError()));

    return true;
}

pthread_t timebomb, checker;
pthread_cond_t reply_cv;
pthread_mutex_t global, operation;
int detect_status;

void* timebombThread (void*)
{
    sleep (2);
    pthread_mutex_lock (&operation);
    if (detect_status == 0)
    {
	detect_status = -1;
	pthread_cond_broadcast (&reply_cv);
    }
    pthread_mutex_unlock (&operation);
    return NULL;
}

struct rdt_struct {
    const char*host;
    YCPList ret;
    ipp_op_t what_to_get;
    bool get_remote;
};


void* remoteDestinationsThread(void *rdt_v)
{
    struct rdt_struct *rdt = (struct rdt_struct *)rdt_v;
    http_t*http = httpConnect(rdt->host, ippPort());
    ipp_t *request,	/* IPP Request */
        *response;	/* IPP Response */
    ipp_attribute_t *attr;	/* Current attribute */
    cups_lang_t	*language;	/* Default language */
    static const char *cattrs[] =	/* Attributes we need ... */
    {
        "printer-name",
        "printer-uri-supported",
        "printer-type"
    };

    if(http == NULL)
        {
            Y2_ERROR("Error while contacting CUPS server %s occured.",
		rdt->host);
	    goto out_err;
//            return false;
        }
    /*
     * Build a CUPS_GET_CLASSES request, which requires the following
     * attributes:
     */    
    request = ippNew();
    
    request->request.op.operation_id = rdt->what_to_get;
    request->request.op.request_id = 1;
    
    language = cupsLangDefault();
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_CHARSET,"attributes-charset",NULL,cupsLangEncoding(language));
    
    ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_LANGUAGE,"attributes-natural-language",NULL,language->language);

    ippAddStrings(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD,"requested-attributes", sizeof(cattrs) / sizeof(cattrs[0]),NULL,cattrs);

    /*
     * Do the request and get back a response...
     */

    if ((response = cupsDoRequest(http, request, "/")) != NULL)
        {
            if (response->request.status.status_code > IPP_OK_CONFLICT)
                {
                    Y2_ERROR("cupsDoRequest error: %s",ippErrorString(response->request.status.status_code));
                    ippDelete(response);
		    goto out_err;
//                    return false;
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

                    YCPString name("");
                    int printer_type = -1;
                    while (attr != NULL && attr->group_tag == IPP_TAG_PRINTER)
                        {
//                            if (!strcmp(attr->name, "printer-name") && attr->value_tag == IPP_TAG_NAME)
                            if (!strcmp(attr->name, "printer-uri-supported") && attr->value_tag == IPP_TAG_URI)
                                {
                                    name = YCPString(attr->values[0].string.text);
                                }
                            if (!strcmp(attr->name, "printer-type") && attr->value_tag == IPP_TAG_ENUM)
                                {
                                    printer_type = attr->values[0].integer;
                                }
                            attr = attr->next;
                        }
                    if(!name->toString().empty())
                        {
                            if ((printer_type & 0x2) && ! rdt->get_remote)
                                {
                                    Y2_DEBUG("Skipping remote printer %s",name->value_cstr());
                                }
                            else
                                {
                                    Y2_DEBUG("Adding %s to list of remote printers.",name->value_cstr());
                                    rdt->ret->add(name);
                                }
                        }
                    if (attr == NULL)
                        break;
                }
            ippDelete(response);
        }
    else
        Y2_WARNING("cupsDoRequest: NULL response - not CUPS server or permission denied???");
    httpClose(http);
    pthread_mutex_lock (&operation);
    if (detect_status == 0)
    {
        detect_status = 1;
        pthread_cond_broadcast (&reply_cv);
    }
    pthread_mutex_unlock (&operation);
    return rdt;//true;

out_err:
    pthread_mutex_lock (&operation);
    if (detect_status == 0)
    {
        detect_status = 1;
        pthread_cond_broadcast (&reply_cv);
    }
    pthread_mutex_unlock (&operation);
    return NULL;


}

bool getRemoteDestinations(const char*host,YCPList&ret, ipp_op_t what_to_get,
    bool get_remote)
{
    pthread_cond_init (&reply_cv, NULL);
    pthread_mutex_init (&operation, NULL);
    pthread_mutex_lock (&operation);
    detect_status = 0;
    struct rdt_struct rdt;
    rdt.host = host;
    rdt.ret = ret;
    rdt.what_to_get = what_to_get;
    rdt.get_remote = get_remote;
    pthread_create (&checker, NULL, remoteDestinationsThread, (void*)&rdt);
    pthread_create (&timebomb, NULL, timebombThread, NULL);
    while (detect_status == 0)
    {
	pthread_cond_wait (&reply_cv, &operation);
    }
    pthread_cond_destroy (&reply_cv);

    bool retval;

    if (detect_status > 0)
    {
	pthread_detach (timebomb);
	pthread_cancel (timebomb);
	pthread_join (checker, NULL);

	retval = true;
    }
    else
    {
	pthread_detach (checker);
	pthread_cancel (checker);
	pthread_join (timebomb, NULL);

	retval = false;
    }


    pthread_mutex_unlock (&operation);
    pthread_mutex_destroy (&operation);
    pthread_cond_destroy (&reply_cv);
    return retval;
}

char* TOLOWER(char* src) {
    src = strdup (src);
    char* p = src;
    while (*p) {
        *p = tolower (*p);
        p++;
    }
    return src;
}

YCPValue getPrinters (string hostname) {
    YCPList ret = YCPList ();;
    http_t*http = httpConnect(hostname.c_str (), ippPort());
    ipp_t *request,     /* IPP Request */
        *response;      /* IPP Response */
    ipp_attribute_t *attr;      /* Current attribute */
    cups_lang_t *language;      /* Default language */

    if(http == NULL)
    {
        Y2_ERROR("Error while contacting CUPS server occured.");
        return YCPVoid ();
    }

    request = ippNew();

    request->request.op.operation_id = CUPS_GET_PRINTERS;
    request->request.op.request_id   = 1;

    language = cupsLangDefault();

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD,
               "requested-attributes", NULL, "printer-name");

    if ((response = cupsDoRequest(http, request, "/")) != NULL)
    {
	for (attr = response->attrs; attr != NULL; attr = attr->next)
	{
	    if (attr->name != NULL &&
		strcasecmp(attr->name, "printer-name") == 0 &&
		attr->value_tag == IPP_TAG_NAME)
	    {
		YCPString name = YCPString (attr->values[0].string.text);
		ret->add (name);
	    }
	}

	ippDelete(response);
	return ret;
    }

    return YCPVoid ();
}

YCPValue getClasses (string hostname) {
    YCPList ret = YCPList ();;
    http_t*http = httpConnect(hostname.c_str (), ippPort());
    ipp_t *request,     /* IPP Request */
        *response;      /* IPP Response */
    ipp_attribute_t *attr;      /* Current attribute */
    cups_lang_t *language;      /* Default language */

    if(http == NULL)
    {
        Y2_ERROR("Error while contacting CUPS server occured.");
        return YCPVoid ();
    }

    request = ippNew();

    request->request.op.operation_id = CUPS_GET_CLASSES;
    request->request.op.request_id   = 1;

    language = cupsLangDefault();

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_CHARSET,
               "attributes-charset", NULL, cupsLangEncoding(language));

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_LANGUAGE,
               "attributes-natural-language", NULL, language->language);

    ippAddString(request, IPP_TAG_OPERATION, IPP_TAG_KEYWORD,
               "requested-attributes", NULL, "printer-name");

    if ((response = cupsDoRequest(http, request, "/")) != NULL)
    {
        for (attr = response->attrs; attr != NULL; attr = attr->next)
        {
            if (attr->name != NULL &&
                strcasecmp(attr->name, "printer-name") == 0 &&
                attr->value_tag == IPP_TAG_NAME)
            {
                YCPString name = YCPString (attr->values[0].string.text);
                ret->add (name);
            }
        }

        ippDelete(response);
        return ret;
    }

    return YCPVoid ();

}

