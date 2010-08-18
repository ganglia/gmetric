#!/bin/sh
CLIENT="/usr/local/bin/gmetric"
VALUE=`/bin/netstat -t -n|egrep "ESTABLISHED"|wc -l`
$CLIENT -t uint16 -n TCP_ESTABLISHED -v $VALUE
