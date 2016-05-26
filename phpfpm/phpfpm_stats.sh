#!/bin/bash
#
# Usage: phpfpm_stats.sh http://127.0.0.1/phpfpm-status
#
# Point it to the URL you have your php-fpm status enabled (status_path
# setting inside php-fpm configuration file)
#
# Recommendation: set up a background process with sleep or watch
# that runs this script every N seconds

RM=/bin/rm
MKTEMP=/bin/mktemp
WGET=/usr/bin/wget
GMETRIC=/usr/bin/gmetric
GREP=/bin/grep
AWK=/bin/awk

STATUS_URL=$1

TMPFILE=`$MKTEMP`
http_proxy= $WGET -q -O $TMPFILE $STATUS_URL
if [ $? -eq 0 ]; then

    ACCEPTED_CONNECTIONS=`$GREP '^accepted conn:' $TMPFILE | $AWK '{print $3}'`
    LISTEN_QUEUE=`$GREP '^listen queue:' $TMPFILE | $AWK '{print $3}'`
    MAX_LISTEN_QUEUE=`$GREP '^max listen queue:' $TMPFILE | $AWK '{print $4}'`
    IDLE_PROCESSES=`$GREP '^idle processes:' $TMPFILE | $AWK '{print $3}'`
    ACTIVE_PROCESSES=`$GREP '^active processes:' $TMPFILE | $AWK '{print $3}'`
    TOTAL_PROCESSES=`$GREP '^total processes:' $TMPFILE | $AWK '{print $3}'`
    MAX_ACTIVE_PROCESSES=`$GREP '^max active processes:' $TMPFILE | $AWK '{print $4}'`
    MAX_CHILDREN_REACHED=`$GREP '^max children reached:' $TMPFILE | $AWK '{print $4}'`

    $GMETRIC -t uint32 -n phpfpm_accepted_connections -x 60 -u connections -g phpfpm \
        -D "Total number of accepted connections" -s positive -v $ACCEPTED_CONNECTIONS
    $GMETRIC -t uint32 -n phpfpm_listen_queue -x 60 -u connections -g phpfpm \
        -D "Current number of queued requests" -s both -v $LISTEN_QUEUE
    $GMETRIC -t uint32 -n phpfpm_max_listen_queue -x 60 -u connections -g phpfpm \
        -D "Maximum reached number of queued requests" -s both -v $MAX_LISTEN_QUEUE
    $GMETRIC -t uint32 -n phpfpm_idle -x 60 -u processes -g phpfpm \
        -D "Current number of idle workers" -s both -v $IDLE_PROCESSES
    $GMETRIC -t uint32 -n phpfpm_active -x 60 -u processes -g phpfpm \
        -D "Current number of active workers" -s both -v $ACTIVE_PROCESSES
    $GMETRIC -t uint32 -n phpfpm_total_processes -x 60 -u processes -g phpfpm \
        -D "Current number of workers" -s both -v $TOTAL_PROCESSES
    $GMETRIC -t uint32 -n phpfpm_max_active -x 60 -u processes -g phpfpm \
        -D "Maximum reached number of active workers" -s both -v $MAX_ACTIVE_PROCESSES
    $GMETRIC -t uint32 -n phpfpm_max_children_reached -x 60 -u times -g phpfpm \
        -D "Number of times that max children were reached" -s both -v $MAX_CHILDREN_REACHED
fi
$RM -f $TMPFILE
