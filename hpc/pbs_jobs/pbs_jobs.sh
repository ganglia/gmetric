#!/bin/sh
#
# Simple script which displays the number of running PBS batch 
# jobs on a given compute node (usually something boring like 
# zero, one or two for for SMP compute nodes).
#
# Contributed by Matt Cuttler <mcuttler at bnl dot gov>


GMETRIC="/usr/bin/gmetric"
NODE=`/bin/hostname -s`

# Might have to change path to reflect your PBS install.. 
QSTAT=`/usr/local/PBS/bin/qstat -n | grep -i $NODE | wc -l`

$GMETRIC --name PBSJOBS --type uint16 --units jobs --value $QSTAT

