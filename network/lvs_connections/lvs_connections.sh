#!/bin/bash
#
# watch_lvs
#
#
# Simple script to report the number of established connections to 
# each real server in an LVS cluster. See www.linuxvirtualserver.org. 
#
# You must set the list of "servers" and the LVS "serviceport" before
# using this script.
#
servers="127.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4 10.0.0.5 10.0.0.6"

# Load balanced service in this example is telnet.
serviceport="23"

for server in $servers
do

        totalconnections=`/sbin/ipvsadm -L -c -n | grep "$server:$serviceport" |grep ESTABLISHED | wc -l`

        # Pull out last octet of host IP for Ganglia report.
        host=`/bin/echo $server | /bin/cut -d"." -f 4-`
       
        # Using a hack to set the hostname in the loopback case.
        if [ "$host" = "1" ]; then
          host="localhost"
        fi

        /usr/bin/gmetric --name host_$host_port_$serviceport --value $totalconnections --type int16 --units Connections

done
