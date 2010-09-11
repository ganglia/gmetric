#!/bin/sh

###########################################################################
# Author: Vladimir Vuksan http://vuksan.com/blog/
#
# This shell script collects total memory usage for a set of processes
# matching a name e.g. you want to keep track of full memory usage of 
# all Apache processes
###########################################################################
if [ $# -ne 2 ]; then
   echo "You need to supply process name and name of metric e.g."
   echo "     $0 httpd apache_mem_usage"
   echo "Exiting ...."
   exit 1
fi

PROCESS_NAME="${1}"
METRIC_NAME="${2}"
GMETRIC_BIN="/usr/bin/gmetric -d 120 "

MEM_USAGE=`ps -ylC ${PROCESS_NAME} --sort:rss | awk '{ SUM += $8 } END { print SUM*1024 }'`

if [ "x$MEM_USAGE" != "x" ]; then
        $GMETRIC_BIN -t float -n $METRIC_NAME -v $MEM_USAGE -u Bytes
else
	echo "Nothing to report. Check process name"
fi
