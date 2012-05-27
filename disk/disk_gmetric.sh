#!/bin/bash 

###  $Header: /var/lib/cvs/ops/ganglia/disk_gmetric.sh,v 1.5 2007/11/30 17:29:27 ben Exp $

###  this script reports disk metrics to ganglia.
###  It should be called from cron every n minutes.
###  It will report blocks per second on each disk,
###  and will automatically adjust for whatever 
###  timeframe it is called

###  Copyright Simply Hired, Inc. 2006
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

VERSION=1.5

GMETRIC="/usr/bin/gmetric"
GMETRIC_ARGS="-c /etc/gmond.conf"
STATEFILE="/var/lib/ganglia/metrics/io.stats"
date=`date +%s`
iostat="/usr/bin/iostat"

ERROR_CREATE="/tmp/disk_gmetric_create_statefile_failed"
ERROR_IOSTAT="/tmp/disk_gmetric_no_iostat"
ERROR_DEVNAMES="/tmp/disk_gmetric_bad_devname"
ERROR_DEVNAMES2="/tmp/disk_gmetric_bad_devname_didnt_fix"
ERROR_GMETRIC="/tmp/disk_gmetric_no_gmetric"
ERROR_TIMEDIFF="/tmp/disk_gmetric_timediff"
ERROR_NOTROOT="/tmp/disk_gmetric_notroot"

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
  echo "Usage: disk_gmetric.sh [--clean]"
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
  echo "Error: iostat doesn't seem to be installed."
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
  echo "$date" > $STATEFILE 
  $iostat -d | tail +4 >> $STATEFILE 
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
stats=(`$iostat -d | tail +4`)
old_stats=(`cat $STATEFILE`) 
old_date=${old_stats[0]}

read=0
write=0
old_read=0
old_write=0
read_sum=0
write_sum=0

### function get_rw sets the variables $read and $write
### to the total number of read blocks and write blocks 
### for a device.  Which device is specified as an argument
### to the function.  
### The function returns 1 if an invalid device number 
### was specified.
function get_rw() {
  base=$(($1 * 6 ))
  if [ "k${stats[$base]}" == "k" ]
  then
	# we're done looping
	return 1;
  else
	devname=${stats[$base]}
	read=${stats[$(($base + 4))]}
	write=${stats[$(($base + 5))]}
	return 0
  fi
}

function get_old_rw() {
  base=$(($1 * 6 ))
  base=$((base + 1))
  if [ "k${old_stats[$base]}" == "k" ]
  then
        # we're done looping
        return 1;
  else
        old_devname=${old_stats[$base]}
        old_read=${old_stats[$(($base + 4))]}
        old_write=${old_stats[$(($base + 5))]}
        return 0
  fi
}

time_diff=$(($date - $old_date))


devnum=0
get_rw $devnum
get_old_rw $devnum
res=$?
while [ $res -eq 0 ]
do
  # if devname and old_devname aren't the same,
  #  this whole function is invalid.
  if [ $devname != $old_devname ]
  then
    if [ -e $ERROR_DEVNAMES ]
    then
      if [ -e $ERROR_DEVNAMES2 ] ; then exit 1; fi
      echo "Sorry, my attempt at fixing the problem failed."
      echo "It's now up to you, dear human."
      touch $ERROR_DEVNAMES2
      exit 1
    fi
    echo "something is broken."
    echo "devnames are not the same."
    echo "devname=$devname old_devname=$old_devname"
    echo "I'm backing up the current statefile ($STATEFILE) "
    echo "and will recreate it next time to see if that fixes this."
    mydate=`date +%Y%m%d%H%M%S`
    mv -fv $STATEFILE{,.${mydate}}
    touch $ERROR_DEVNAMES
    exit 1
  fi
  rm -f $ERROR_DEVNAMES $ERROR_DEVNAME2
  #devname, read, write, old_devname, old_read, old_write
  # are all set.  calculate stat/sec and report.
  read_diff=$(($read - $old_read))
  write_diff=$(($write - $old_write))
  # if read_diff or write_diff are less than 0, the counter has wrapped
  # and we should reset ourselves
  if [ `expr $read_diff \< 0` -eq 1 -o `expr $write_diff \< 0` -eq 1 ]
  then
  	#just write out the new stats and exit; there's nothing we can do
	echo "$date" > $STATEFILE
	$iostat -d | tail +4 >> $STATEFILE
	exit 1
  fi
  # if the system gets backed up and multiple invocations are launched
  # at the same time, the time difference between them is 0 and the
  # metric is meaningless.
  if [ $time_diff -eq 0 ]
  then
    if [ -e $ERROR_TIMEDIFF ] ; then exit 1 ; fi
    echo "something is broken."
    echo "time_diff is 0."
    touch $ERROR_TIMEDIFF
    exit 1
  fi
  rm -f $ERROR_TIMEDIFF
  rps=`echo "scale=3;$read_diff / $time_diff" | bc`
  wps=`echo "scale=3;$write_diff / $time_diff" | bc`

  read_sum=`echo "scale=3;$read_sum + $rps" | bc`
  write_sum=`echo "scale=3;$write_sum + $wps" | bc`

  # report what we have calculated
  $GMETRIC $GMETRIC_ARGS --name="${devname}_reads" --value="$rps" --type="float" --units="blocks/sec"
  $GMETRIC $GMETRIC_ARGS --name="${devname}_writes" --value="$wps" --type="float" --units="blocks/sec"

#  echo "$devname $rps $wps $read_sum $write_sum " >> /tmp/foo.txt

  devnum=$((devnum + 1))
  get_rw $devnum
  get_old_rw $devnum
  res=$?
done

$GMETRIC $GMETRIC_ARGS --name="disk_reads" --value="$read_sum" --type="float" --units="blocks/sec"
$GMETRIC $GMETRIC_ARGS --name="disk_writes" --value="$write_sum" --type="float" --units="blocks/sec"

echo "$date" > $STATEFILE
$iostat -d | tail +4 >> $STATEFILE

rm -f $ERROR_CREATE $ERROR_IOSTAT $ERROR_DEVNAME2 $ERROR_DEVNAME $ERROR_GMETRIC $ERROR_TIMEDIFF $ERROR_NOTROOT

