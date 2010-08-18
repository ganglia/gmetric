#!/bin/bash
#
# watch_lvs
#
#
# Simple script to report the number of established connections to
# each real server in an LVS cluster. See www.linuxvirtualserver.org.
#
# You must set the list of "servers" and the LVS "serviceport" and
# "servicesports" before using this script.
#
#
# Original: Lorn Kay
# Modified: Jordi Prats Catala - CESCA - 2007
#

servers="192.168.11.1 192.168.11.2 192.168.11.121 192.168.11.122"
servicesports="8080 80 81 8089 2641"

for serviceport in $servicesports
  do
  for server in $servers
    do

    totalconnections=`/sbin/ipvsadm -L -c -n | grep "$server:$serviceport" |grep ESTABLISHED | wc -l`

        # Pull out last octet of host IP for Ganglia report.
    host=`/bin/echo $server | /bin/cut -d"." -f 4-`

        # Using a hack to set the hostname in the loopback case.
    if [ "$host" = "1" ]; then
        host="localhost"
    fi

    /usr/bin/gmetric --name host_${server}_port_${serviceport} --value $totalconnections --type uint16 --units Connections

  done

done
