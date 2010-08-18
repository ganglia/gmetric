#!/bin/sh
#
# Report number of users logged in. Sorry it's not more exciting. :)
#
# Miles Davis <miles@cs.stanford.edu>
#
CLIENT="/usr/bin/gmetric"

# Last line in output of "who -q" is in the form "^# users=N$", so just
# grab the last line & split on the equals sign. This works on Linux, IRIX,
# Solaris, & probably most other un*xes.
USERS=`who -q | tail -1 | cut -d = -f 2`

#echo $USERS

$CLIENT -t uint16 -n users -v $USERS

exit $?