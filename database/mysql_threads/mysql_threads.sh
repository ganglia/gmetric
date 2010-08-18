#!/bin/bash
 
# Source a conf file read only by root to get the mysql USER
# we should use.
if [ ! -f /etc/mysql-threads-gmetric.conf ] ; then
  echo "/etc/mysql-threads-gmetric.conf does not exist"
  exit 1
fi
 
. /etc/mysql-threads-gmetric.conf
 
# Check there is a gmond.conf file.
if [ ! -f /etc/gmond.conf ] ; then
  echo "/etc/gmond.conf does not exist"
  exit 1
fi
 
# Work out what multicast channel we are on (rather assumes there is only one space).
MCAST=`grep '^mcast_channel' /etc/gmond.conf | cut -d' ' -f 2`
PORT=`grep '^mcast_port' /etc/gmond.conf | cut -d' ' -f 2`
TTL=`grep '^mcast_ttl' /etc/gmond.conf | cut -d' ' -f 2`
 
[ -z "$MCAST" ] && MCAST="239.2.11.70"
[ -z "$PORT" ]  && PORT=8649
[ -z "$TTL" ] && TTL=1
 
 
STRING=`mysqladmin -u $USER status`
THREADS=`echo $STRING | sed 's/.*Threads: \([0-9]*\) .*/\1/'`
 
 
gmetric -tuint32 -c$MCAST -p$PORT -l$TTL -x180 -d300 -nmysql_threads -v$THREADS
 
 
