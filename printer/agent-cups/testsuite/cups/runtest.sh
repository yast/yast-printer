#!/bin/bash

export LANG=C

unset Y2DEBUG
unset Y2DEBUGALL
unset Y2DEBUGGER

(/usr/lib/YaST2/bin/y2bignfat -l - "$1" wfm >"$2") 2>&1 | grep -v "^$" | sed 's/^....-..-.. ..:..:.. [^)]*) //g' >$3

exit 0
