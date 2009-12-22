/*
 *  gcc -Wall -o basicadd_displaytest basicadd_displaytest.c -L/usr/X11R6/lib -lX11 
 */

#include <stdio.h>
#include <stdlib.h>
#include <X11/Xlib.h>

int main (void)
{ char *display_name;
  Display *display;

  display_name=getenv( "DISPLAY" );
  display = XOpenDisplay( display_name );
  if( NULL == display )
  { fprintf( stderr, "Unable to open Display: %s\n", display_name );
    exit( 1 );
  }
  XCloseDisplay( display );
  return 0;
}

