#!/bin/bash

### $Id: mcd_gmetric.sh 16661 2006-11-07 00:56:33Z ben $

###  This script queries a memcached server running
###  on localhost and reports a few statistics to 
###  ganglia.  
###  It reports
###    *mcd_curr_items - the number of objects stored
###    *mcd_curr_bytes - current bytes used
###    *mcd_curr_conns - current number of connections
###    *mcd_hit_perc - hits / gets for current time duration
###                 (current hit percentage)
###  For more description on any of these metrics,
###  see the protocols.txt file in the MCD docs.

###  Copyright Simply Hired, Inc. 2006
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

VERSION=1.1

GMETRIC="/usr/bin/gmetric"
GMETRIC_ARGS="-c /etc/gmond.conf"
STATEFILE="/var/lib/ganglia/metrics/mcd.stats"
ERROR_NOTROOT="/tmp/mcd_gmetric_notroot"
ERROR_CANT_CONNECT="/tmp/mcd_gmetric_cant_connect"
ERROR_CREATE="/tmp/mcd_gmetric_create_statefile_failed"
ERROR_GETS_EMPTY="/tmp/mcd_gets_empty"

MCD_CONF="/etc/sysconfig/memcached"
MCD_DEFAULT_PORT="11211"

date=`date +%s`

if [ $UID -ne 0 ]
then
  if [ -e $ERROR_NOTROOT ] ; then exit 1; fi
  echo "Error: this script must be run as root."
  touch $ERROR_NOTROOT
  exit 1
fi
rm -f $ERROR_NOTROOT

while [ -n "$1" ]
do
  case "x$1" in
    "x-h" | "x--help" )
      echo "Usage: mcd_gmetric.sh [--clean] [--config <file>]"
      echo "  --clean           delete all tmp files"
      echo "  --config <file>   the location of the mcd config file to read"
      echo "                       (default ${MCD_CONF})"
      exit 0
      ;;
    "x--clean" )
      rm -f $STATEFILE $ERROR_NOTROOT $ERROR_CANT_CONNECT $ERROR_CREATE
      retval=$?
      if [ $retval -ne 0 ]
      then
        echo "failed to clean up."
        exit 1
      else
        echo "All cleaned up."
        exit 0
      fi
      ;;
    "x--config" )
      shift
      mcd_config=$1
      if [ ! -n "$mcd_config" ]
      then
        echo "mcd configuration filename required"
        exit 1
      fi
      if [ ! -e "$mcd_config" ]
      then
        echo "mcd configuration file does not exist"
        exit 1
      fi
      if [ ! -r "$mcd_config" ]
      then
        echo "mcd configuration file cannot be read"
        exit 1
      fi
      source ${mcd_config}
      MCD_PORT=${PORT}
      ;;
    *)
      echo "unrecognized option."
      exit 1
      ;;
  esac
  shift
done

# set default MCD port if none specified
MCD_PORT=${MCD_PORT:-$MCD_DEFAULT_PORT}

# if the GMETRIC program isn't installed, compain
if [ ! -e $GMETRIC ]
then
  if [ -e $ERROR_GMETRIC ] ; then exit 1; fi
  echo ""
  echo "Error: GMETRIC doesn't seem to be installed."
  echo "$GMETRIC doesn't exist."
  echo ""
  touch $ERROR_GMETRIC
  exit 1
fi

# get current statistics
exec 3>&2 #turn off STDERR
exec 2>/dev/null
stats_array=(`echo "stats" | nc localhost $MCD_PORT`)
retval=$?
exec 2>&1 #turn on STDERR
exec 3>&-

if [ $retval -ne 0 ]
then
  if [ -e $ERROR_CANT_CONNECT ] ; then exit 1 ; fi
  echo "I can't connect to mcd."
  echo "Bummer. "
  touch $ERROR_CANT_CONNECT 
  exit 1
fi

mcd_curr_items=`echo ${stats_array[23]}|tr -c -d [0-9]` #this tr thing is because there's a trailing ^M on the string from netcat that breaks bc.
mcd_curr_bytes=`echo ${stats_array[29]}|tr -c -d [0-9]`
mcd_curr_conns=`echo ${stats_array[32]}|tr -c -d [0-9]`
mcd_total_gets=`echo ${stats_array[41]}|tr -c -d [0-9]`
mcd_total_sets=`echo ${stats_array[44]}|tr -c -d [0-9]`
mcd_total_hits=`echo ${stats_array[47]}|tr -c -d [0-9]`

if [ -z "$mcd_total_gets" ]
then
# this actually happens rather often for some reason, so I'm just going to fail silently.
#  if [ -e $ERROR_GETS_EMPTY ] ; then exit 1 ; fi
#   echo ""
#   echo "ERROR: mcd_total_gets empty."
#   echo ""
    exit 1
fi
rm -f $ERROR_GETS_EMPTY


# save and turn off /STDERR for the statefile tests
exec 3>&2
exec 2>/dev/null

# if the statefile doesn't exist, we either havn't
# run yet or there's something bigger wrong.
if [ ! -e $STATEFILE ]
then
  if [ ! -d `dirname $STATEFILE` ]
  then
    mkdir -p `dirname $STATEFILE`
  fi
  echo "$date $mcd_curr_items $mcd_curr_bytes $mcd_curr_conns $mcd_total_gets $mcd_total_sets $mcd_total_hits" > $STATEFILE
  if [ ! -e $STATEFILE ]
  then
    # if it didn't exist and we couldn't create
    #  it, we should just scream bloody murder and die.
    #  only scream once though...
    if [ -e $ERROR_CREATE ]
    then
      exit 1
    fi
    echo ""
    echo "ERROR: couldn't create $STATEFILE"
    echo ""
    touch $ERROR_CREATE
    exit 1
  fi
  echo "Created statefile.  Exitting."
  exit 0
fi

# restore stderr
exec 2>&3
exec 3>&-

old_stats_array=(`cat $STATEFILE`)
old_date=${old_stats_array[0]}
old_mcd_curr_items=${old_stats_array[1]}
old_mcd_curr_bytes=${old_stats_array[2]}
old_mcd_curr_conns=${old_stats_array[3]}
old_mcd_total_gets=${old_stats_array[4]}
old_mcd_total_sets=${old_stats_array[5]}
old_mcd_total_hits=${old_stats_array[6]}

echo "$date $mcd_curr_items $mcd_curr_bytes $mcd_curr_conns $mcd_total_gets $mcd_total_sets $mcd_total_hits" > $STATEFILE

time_diff=$(($date - $old_date))
mcd_total_gets_diff=$(($mcd_total_gets - $old_mcd_total_gets))
mcd_total_sets_diff=$(($mcd_total_sets - $old_mcd_total_sets))
mcd_total_hits_diff=$(($mcd_total_hits - $old_mcd_total_hits))

if [ $time_diff -eq 0 ]
then
  if [ -e $ERROR_TIMEDIFF ] ; then exit 1 ; fi
  echo "something is broken."
  echo "time_diff is 0."
  touch $ERROR_TIMEDIFF
  exit 1
fi

# none of these numbers should be less than 1, but if they are, just send back 1.
if [ $mcd_total_gets_diff -le 1 ] ; then mcd_total_gets_diff=1 ; fi
if [ $mcd_total_sets_diff -le 1 ] ; then mcd_total_sets_diff=1 ; fi
if [ $mcd_total_hits_diff -le 1 ] ; then mcd_total_hits_diff=1 ; fi

mcd_gets_per_sec=`echo "scale=3;${mcd_total_gets_diff}/${time_diff}"|bc`
mcd_sets_per_sec=`echo "scale=3;${mcd_total_sets_diff}/${time_diff}"|bc`
mcd_hits_per_sec=`echo "scale=3;${mcd_total_hits_diff}/${time_diff}"|bc`
mcd_hit_perc=`echo "scale=3; ${mcd_total_hits_diff} * 100 / ${mcd_total_gets_diff}" | bc`

# if we're running on a non-standard port, it might be the case that
# we've got multiple memcached's being watched.  Make the metric name
# differentiate between them.
if [ $MCD_PORT -ne $MCD_DEFAULT_PORT ]
then
    metric_name_uniquifier="${MCD_PORT}_"
fi

$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}seconds_measured" --value=${time_diff} --type=uint32 --units="secs"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}items_cached" --value=${mcd_curr_items} --type=uint32 --units="items"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}bytes_used" --value=${mcd_curr_bytes} --type=uint32 --units="bytes"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}conns" --value=${mcd_curr_conns} --type=uint32 --units="connections"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}gets" --value=${mcd_gets_per_sec} --type=float --units="gps"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}sets" --value=${mcd_sets_per_sec} --type=float --units="sps"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}cache_hits" --value=${mcd_hits_per_sec} --type=float --units="hps"
$GMETRIC $GMETRIC_ARGS --name="mcd_${metric_name_uniquifier}cache_hit%" --value=${mcd_hit_perc} --type=float --units="%"

