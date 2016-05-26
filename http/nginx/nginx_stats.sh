#!/bin/bash
#
# Usage: nginx_stats.sh http://127.0.0.1/server-status

# Point it to the URL you have your nginx status enabled (see
# http://nginx.org/en/docs/http/ngx_http_stub_status_module.html)
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

    ACTIVE_CONNECTIONS=`$GREP '^Active' $TMPFILE | $AWK '{print $3}'`
    ACCEPTED_CONNECTIONS=`$GREP '^ ' $TMPFILE | $AWK '{print $1}'`
    HANDLED_CONNECTIONS=`$GREP '^ ' $TMPFILE | $AWK '{print $2}'`
    REQUESTS=`$GREP '^ ' $TMPFILE | $AWK '{print $3}'`
    READING_CONNECTIONS=`$GREP '^Read' $TMPFILE | $AWK '{ print $2 }'`
    WRITING_CONNECTIONS=`$GREP '^Read' $TMPFILE | $AWK '{ print $4 }'`
    WAITING_CONNECTIONS=`$GREP '^Read' $TMPFILE | $AWK '{ print $6 }'`

    $GMETRIC -t uint32 -n nginx_active -x 60 -u connections -g nginx -D "Total number of active connections" -s both -v $ACTIVE_CONNECTIONS
    $GMETRIC -t uint32 -n nginx_accepts -x 60 -u connections -g nginx -D "Total number of accepted connections" -s positive -v $ACCEPTED_CONNECTIONS
    $GMETRIC -t uint32 -n nginx_handled -x 60 -u connections -g nginx -D "Total number of handled connections" -s positive -v $HANDLED_CONNECTIONS
    $GMETRIC -t uint32 -n nginx_requests -x 60 -u requests -g nginx -D "Total number of requests" -s positive -v $REQUESTS
    $GMETRIC -t uint32 -n nginx_reading -x 60 -u connections -g nginx -D "Current connections in the reading state" -s both -v $READING_CONNECTIONS
    $GMETRIC -t uint32 -n nginx_writing -x 60 -u connections -g nginx -D "Current connections in the writing state" -s both -v $WRITING_CONNECTIONS
    $GMETRIC -t uint32 -n nginx_waiting -x 60 -u connections -g nginx -D "Current connections in the waiting state" -s both -v $WAITING_CONNECTIONS

fi
$RM -f $TMPFILE
