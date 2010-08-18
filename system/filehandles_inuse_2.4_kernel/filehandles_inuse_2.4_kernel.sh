#!/bin/sh

CLIENT="/usr/bin/gmetric"

FDS=(`< /proc/sys/fs/file-nr`)

system_reserved=${FDS[0]}
current_used=${FDS[1]}
fd_limit=${FDS[2]}

#echo $system_reserved
#echo $current_used
#echo $fd_limit

exec $CLIENT -t uint16 -n fd_inuse -v $current_used
