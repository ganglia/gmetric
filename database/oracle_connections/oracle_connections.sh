#!/bin/sh
CLIENT="/usr/bin/gmetric"
VALUE=`/bin/ps -ef |/bin/grep -c LOCAL`
$CLIENT -t uint16 -n ORACLE_Connections -v $VALUE

