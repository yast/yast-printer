#!/bin/bash

unset Y2DEBUG
unset Y2DEBUGALL
unset Y2DEBUGGER

(./runppd "$1" "$2" ) 2>&1 | sed 's/^....-..-.. ..:..:.. [^)]*) //g' >$3

#
# make output and error path-independent
# ("/../../../ppdfiles/*.ppd" --> ".../ppdfiles/*.ppd")
#

cat $2 | sed 's/\".*\(ppdfiles.*ppd\)\"/\"...\/\1\"/g' > $2.xxx
mv $2.xxx $2

cat $3 | sed 's/[^ ]*\(\/ppdfiles\/\)/...\1/g' | sort > $3.xxx
mv $3.xxx $3

exit 0
