#!/bin/bash

# Script to collect stats about a Cray XT or XE system.
# Reports up, down, avail, and in use

/usr/bin/apstat -n | tail -1 | awk '{system("/usr/bin/gmetric -nnode_total -v" $2 " -tuint16 -u"$2"")} \
{system("/usr/bin/gmetric -nnode_avail -v" $6 " -tuint16 -u"$6"")} \
{system("/usr/bin/gmetric -nnode_up -v" $3 " -tuint16 -u"$3"")} \
{system("/usr/bin/gmetric -nnode_down -v" $7 " -tuint16 -u"$7"")} \
{system("/usr/bin/gmetric -nnode_use -v" $4 " -tuint16 -u"$4"")}'

#########################################################################
# Previous Iteration
########################################################################

#NODE_TOTAL=$(/usr/bin/apstat -n | tail -1 | awk '{print $2}')
#NODE_AVAIL=$(/usr/bin/apstat -n | tail -1 | awk '{print $6}')
#NODE_UP=$(/usr/bin/apstat -n | tail -1 | awk '{print $3}')
#NODE_DOWN=$(/usr/bin/apstat -n | tail -1 | awk '{print $7}')
#NODE_USE=$(/usr/bin/apstat -n | tail -1 | awk '{print $4}')

#$APPS/system/ganglia-3.1.7/bin/gmetric -n  node_total -v $NODE_TOTAL  -t string -u nodes 
#$APPS/system/ganglia-3.1.7/bin/gmetric -n  node_avail -v $NODE_AVAIL -t float -u nodes 
#$APPS/system/ganglia-3.1.7/bin/gmetric -n  node_up -v $NODE_UP -t float -u nodes 
#$APPS/system/ganglia-3.1.7/bin/gmetric -n  node_down -v $NODE_DOWN -t float -u nodes 
#$APPS/system/ganglia-3.1.7/bin/gmetric -n  node_use -v $NODE_USE -t float -u nodes 

