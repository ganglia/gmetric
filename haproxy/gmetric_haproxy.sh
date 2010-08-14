#!/bin/bash
# Script to get haproxy stats
# Created by @hdanniel
# http://hdanniel.com/sl

# This script needs the stats socket option in haproxy.cfg

# haproxy.cfg 
# global
#       ...     
#       stats socket /path/to/haproxy.sock
#       ...     

# Other requirements
# * must run as root
# * socat installed
# * only one backend

# Also you can use Net-SNMP perl plugin for HAProxy to get stats through SNMP
# http://haproxy.1wt.eu/download/contrib/netsnmp-perl/haproxy.pl

GMETRIC="/usr/bin/gmetric"
SOCKET_PATH="/var/run/haproxy.sock"
METRICS_TEMPFILE="/tmp/haproxymetrics"
ERRORS_TEMPFILE="/tmp/haproxyerrors"

declare -a SERVER

echo "show stat -1 7 -1" | socat unix-connect:$SOCKET_PATH stdio | grep -v svname > $METRICS_TEMPFILE
if [ -s $METRICS_TEMPFILE ]; then
        echo "OK"
        cat $METRICS_TEMPFILE | while read line;
        do
                PX=($(echo "${line}"|cut -d "," -f 1,5,34|tr ',' ' '))
                pxname=$(echo ${PX[0]} | tr '[:upper:]' '[:lower:]')
                SERVER=($(echo "${line}"|cut -d "," -f 2,5,34|tr ',' ' '))
                svname=$(echo ${SERVER[0]} | tr '[:upper:]' '[:lower:]')
                scur=${SERVER[1]}
                rate=${SERVER[2]}
                $GMETRIC --name "ha_"$pxname"_"$svname"_current_sessions" --value $scur --type float --units "Current Sessions"
                $GMETRIC --name "ha_"$pxname"_"$svname"_session_rate" --value $rate --type float --units "Session Rate"
        done
else
        echo "Can't connect to $SOCKET_PATH" > $ERRORS_TEMPFILE
fi
rm -f $METRICS_TEMPFILE
