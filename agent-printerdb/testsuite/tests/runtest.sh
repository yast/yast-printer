#!/bin/bash

unset Y2DEBUG
unset Y2DEBUGGER

(./runag_printerdb -l - $1 >$2) 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed '-e s/^....-..-.. ..:..:.. [^)]*) //g' > $3

