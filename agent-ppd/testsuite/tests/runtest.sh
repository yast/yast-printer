#!/bin/bash

unset Y2DEBUG
unset Y2DEBUGGER

export LANG="C"

(./runag_ppd -l - $1 >$2) 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed '-e s/^....-..-.. ..:..:.. [^)]*) //g' > $3

rm ppd_*  2>/dev/null || exit 0

