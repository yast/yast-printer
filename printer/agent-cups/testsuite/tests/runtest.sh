#!/bin/bash

export LANG=C

unset Y2DEBUG
unset Y2DEBUGALL
unset Y2DEBUGGER

(./runcups -l - "$1" >"$2") 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed 's/^....-..-.. ..:..:.. [^)]*) //g' >$3

exit 0
