#!/bin/bash
# Script to get lighttpd stats
# Created by @hdanniel
# http://hdanniel.com/sl

# This script needs the mod_status module enabled in lighttpd.conf
# http://redmine.lighttpd.net/projects/lighttpd/wiki/Docs:ModStatus

# lighttpd.conf
# server.modules = ( ..., "mod_status", ... )
#
# $HTTP["remoteip"] == "127.0.0.1" {
#       status.status-url = "/server-status"
# }

# This script must run as root

# Paths
WGET="/usr/bin/wget"
GMETRIC="/usr/bin/gmetric"

STATUS_URL="http://127.0.0.1/server-status"
METRICS_TEMPFILE="/tmp/lighttpdmetrics"
ERRORS_TEMPFILE="/tmp/lighttpderrors"

USER=""
PASSWORD=""

$WGET --user=$USER --password=$PASSWORD -q -O - $STATUS_URL?auto > $METRICS_TEMPFILE
if [ -s $METRICS_TEMPFILE ]; then
        echo "OK"
        $GMETRIC --name lighttpd_busy_servers --value `grep BusyServers $METRICS_TEMPFILE | cut -d " " -f 2` --type float --units "Busy Servers"
        $GMETRIC --name lighttpd_idle_servers --value `grep IdleServers $METRICS_TEMPFILE | cut -d " " -f 2` --type float --units "Idle Servers"
else
        echo "Can't connect to $STATUS_URL" > $ERRORS_TEMPFILE
fi
rm -f $METRICS_TEMPFILE


