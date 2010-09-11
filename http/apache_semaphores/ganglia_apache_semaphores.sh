#!/bin/sh

##############################################################
# You will need util-linux package for this script to work
# On Centos/RHEL type yum install util-linux
# Debian/Ubuntu apt-get install util-linux
# 
# This script collects the number of Apache semaphores. Trying
# to avoid this problem
# 
# http://rackerhacker.com/2007/08/24/apache-no-space-left-on-device-couldnt-create-accept-lock/
##############################################################
NUM_SEMAPHORES=`ipcs  -s | egrep "apache|www-data" | wc -l`

GMETRIC_BIN="/usr/bin/gmetric"

if [ "x$NUM_SEMAPHORES" != "x" ]; then
	$GMETRIC_BIN -d 180 -t uint16 -n apache_semaphores -v $NUM_SEMAPHORES
else
	echo "Nothing to report."
fi
