#!/bin/bash

unset Y2DEBUG
unset Y2DEBUGGER

(test -f /usr/share/YaST2/data/printer/models.equiv || cp ../../data/models.equiv /usr/share/YaST2/data/printer/;)

(./runag_ppd -l - $1 >$2) 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed '-e s/^....-..-.. ..:..:.. [^)]*) //g' > $3

