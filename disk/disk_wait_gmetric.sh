#!/bin/bash 

###  $Header: /var/lib/cvs/ops/ganglia/disk_wait_gmetric.sh,v 1.3 2006/07/11 17:29:27 ben Exp $

###  this script reports disk metrics to ganglia.
###  It should be called from cron every n minutes.
###  It will report blocks per second on each disk,
###  and will automatically adjust for whatever 
###  timeframe it is called

###  Copyright Simply Hired, Inc. 2006
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

VERSION=1.0

GMETRIC="/usr/bin/gmetric"
GANGLIA_ARGS="-c /etc/gmond.conf"
STATEFILE="/var/lib/ganglia/metrics/io_wait.stats"
date=`date +%s`
iostat="/usr/bin/iostat"

ERROR_CREATE="/tmp/disk_wait_gmetric_create_statefile_failed"
ERROR_IOSTAT="/tmp/disk_wait_gmetric_no_iostat"
ERROR_DEVNAMES="/tmp/disk_wait_gmetric_bad_devname"
ERROR_DEVNAMES2="/tmp/disk_wait_gmetric_bad_devname_didnt_fix"
ERROR_GMETRIC="/tmp/disk_wait_gmetric_no_gmetric"
ERROR_TIMEDIFF="/tmp/disk_wait_gmetric_timediff"
ERROR_NOTROOT="/tmp/disk_wait_gmetric_notroot"

if [ $UID -ne 0 ]
then
  if [ -e $ERROR_NOTROOT ] ; then exit 1; fi
  echo "Error: this script must be run as root."
  touch $ERROR_NOTROOT
  exit 1
fi
rm -f $ERROR_NOTROOT

if [ "x$1" == "x-h" ]
then
  echo "Usage: disk_wait_gmetric.sh [--clean]"
  echo "  --clean	delete all tmp files"
  exit 0
fi

if [ "x$1" == "x--clean" ]
then
  rm -f $ERROR_CREATE $ERROR_IOSTAT $ERROR_DEVNAME $ERROR_DEVNAME2 $ERROR_GMETRIC $ERROR_TIMEDIFF $ERROR_NOTROOT $STATEFILE
  retval=$?
  if [ $retval -ne 0 ]
  then
    echo "failed to clean up."
    exit 1
  else
    echo "All cleaned up."
    exit 0
  fi
fi

# save and turn off /STDERR for th estatefile tests
exec 3>&2
exec 2>/dev/null

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

# if the iostat program isn't installed, compain
if [ ! -e $iostat ]
then
  if [ -e $ERROR_IOSTAT ]
  then
    exit 1
  fi
  echo ""
  echo "Error: iostat (from the package sysstat) doesn't seem to be installed."
  echo "$iostat doesn't exist."
  echo ""
  touch $ERROR_IOSTAT
  exit 1
fi

# if the statefile doesn't exist, we either havn't 
# run yet or there's something bigger wrong.
if [ ! -e $STATEFILE ]
then
  if [ ! -d `dirname $STATEFILE` ]
  then
    mkdir -p `dirname $STATEFILE`
  fi
	# iostat -x 1 2 gives a summary and a report for the last second
	# we're only interested in the second half.  We count the number of 
	# lines, strip the first, divide by 2, and strip the header.  
	# this gives us just the interesting part.
  tot_lines=`$iostat -x 1 2 | grep -v "^$" | wc -l`
	rel_lines=`expr \( $tot_lines - 1 \) / 2 - 1`
	echo $tot_lines > $STATEFILE 
	echo $rel_lines >> $STATEFILE 

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

# this script uses iostat (part of the sysstat packag) 
# to retrieve disk metrics
tot_lines=`$iostat -x 1 2 | grep -v "^$" | wc -l`
old_stats=(`cat $STATEFILE`) 
old_tot_lines=${old_stats[0]}

if [ $tot_lines -ne $old_tot_lines ]
then
	echo "something is broken."
	echo "the number of lines of iostat output has changed"
	echo "current tot_lines=$tot_lines old_tot_lines=$old_tot_lines"
	echo "I'm backing up the current statefile ($STATEFILE) "
	echo "and will recreate it next time to see if that fixes this."
	mydate=`date +%Y%m%d%H%M%S`
	mv -fv $STATEFILE{,.${mydate}}
	touch $ERROR_DEVNAMES
	exit 1
fi
	
rel_lines=${old_stats[1]}
#stats=(`$iostat -x 30 2 | grep -v "^$" | tail -$rel_lines`)
stats=(`$iostat -x 5 2 | grep -v "^$" | tail -$rel_lines`)
# the default gmond already reports this one...
#iowait=${stats[3]}

$GMETRIC $GMETRIC_ARGS --name="cpu_waitio" --value="$iowait" --type="float" --units="%"

res=0
index=19
while [ $res -eq 0 ]
do
	devname=${stats[$index]}
	await=${stats[$(($index + 11))]}
	util=${stats[$(($index + 13))]}

	$GMETRIC $GMETRIC_ARGS --name="${devname}_await" --value="$await" --type="float" --units="millisec"
	$GMETRIC $GMETRIC_ARGS --name="${devname}_util" --value="$util" --type="float" --units="%"
	
	index=$(($index + 14))
	#if we're done, cut out of the loop
	if [ "k${stats[$index]}" == "k" ]
	then
		res=1
	fi
done

#cleanup
rm -f $ERROR_CREATE $ERROR_IOSTAT $ERROR_DEVNAME2 $ERROR_DEVNAME $ERROR_GMETRIC $ERROR_TIMEDIFF $ERROR_NOTROOT

