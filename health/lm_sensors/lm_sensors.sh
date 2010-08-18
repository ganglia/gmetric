#!/bin/bash
# author: Mike Snitzer <msnitzer@plogic.com>
# desc:   used to make lm_sensors metrics available to ganglia

# /etc/sysconfig/ganglia is used to specify INTERFACE
CONFIG=/etc/sysconfig/ganglia
[ -f $CONFIG ] && . $CONFIG

#default to eth0
if [ -z "$MCAST_IF" ]; then
    MCAST_IF=eth0
fi

GMETRIC_BIN=/usr/bin/gmetric
# establish a base commandline
GMETRIC="$GMETRIC_BIN -i $MCAST_IF"

SENSORS=/usr/bin/sensors

# load the lm_sensors modules
module=`/sbin/lsmod | awk '{print $1}' | grep i2c-piix4`
if [ -z "$module" ]; then
    /sbin/modprobe i2c-piix4
    # lm87 is for supermicro P3TDLE, replace when appropriate
    /sbin/modprobe lm87
fi

# send cpu temps if gmond is running
`/sbin/service gmond status > /dev/null`
if [ $? -eq 0 ]; then
    # send cpu temperatures
    let count=0
    for temp in `${SENSORS} | grep emp | cut -b 13-16`; do 
	$GMETRIC -t float -n "cpu${count}_temp" -u "C" -v $temp 
	let count+=1
    done

    # send cpu fan speed
    let count=0
    for fan in `${SENSORS} | grep fan | cut -b 9-14`; do
	$GMETRIC -t uint32 -n "cpu${count}_fan" -u "RPM" -v $fan
	let count+=1
    done
fi