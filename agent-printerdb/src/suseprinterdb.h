#ifndef __SuSEPRINTERDB__H__
#define __SuSEPRINTERDB__H__

#ifdef __cplusplus__
extern "C" {
#endif//__cplusplus__
/**
 * User defined function to report parse/scan error.
 */
void spdbReportError (int line, const char*file, const char*func, const char*format, ...);

/**
 * Load printer definition files. 
 */
int spdbStart (const char*path);

/**
 * Free memory occupied by database (allocated by spdbStart)
 */
int spdbFree ();

/**
 * Lookup functions.
 */
  

#ifdef __cplusplus__
}
#endif//__cplusplus__

#endif//__SuSEPRINTERDB__H__ 
