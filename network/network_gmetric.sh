#!/bin/bash 

###  $Header: /var/lib/cvs/ops/ganglia/network_gmetric.sh,v 1.3 2006/07/11 17:29:27 ben Exp $

###  this script reports network metrics to ganglia.
###  It should be called from cron every n minutes.
###  It will report network usage per interface
###  and will automatically adjust for whatever 
###  timeframe it is called

###  Copyright Simply Hired, Inc. 2006
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

VERSION=1.3

GMETRIC="/usr/bin/gmetric"
GMETRIC_ARGS="-c /etc/gmond.conf"
STATEFILE="/var/lib/ganglia/metrics/net.stats"
date=`date +%s`
procfile="/proc/net/dev"

ERROR_CREATE="/tmp/network_gmetric_create_statefile_failed"
ERROR_IOSTAT="/tmp/network_gmetric_no_procfile"
ERROR_DEVNAMES="/tmp/network_gmetric_bad_devname"
ERROR_DEVNAMES2="/tmp/network_gmetric_bad_devname_didnt_fix"
ERROR_GMETRIC="/tmp/network_gmetric_no_gmetric"
ERROR_TIMEDIFF="/tmp/network_gmetric_timediff"
ERROR_NOTROOT="/tmp/network_gmetric_notroot"

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
  echo "Usage: network_gmetric.sh [--clean]"
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

# if the /proc/net/dev file doesn't exist (eh?!) complain
if [ ! -e $procfile ]
then
  if [ -e $ERROR_IOSTAT ]
  then
    exit 1
  fi
  echo ""
  echo "Error: $procfile doesn't seem to exist."
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
  cat $procfile | sed -e "s/:/ /" | grep "eth" >> $STATEFILE 
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

# this script uses gets its stats directly from /proc
stats=(`cat $procfile | sed -e "s/:/ /" | grep "eth"`)
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
	base=$1
  let "base *= 17"
  if [ "k${stats[$base]}" == "k" ]
  then
		# we're done looping
		return 1;
  else
	devname=${stats[$base]}
	read=${stats[$(($base + 1))]}
	write=${stats[$(($base + 9))]}
	return 0
  fi
}

function get_old_rw() {
	base=$1
	let "base *= 17"
	let "base += 1"
  if [ "k${old_stats[$base]}" == "k" ]
  then
        # we're done looping
        return 1;
  else
        old_devname=${old_stats[$base]}
        old_read=${old_stats[$(($base + 1))]}
        old_write=${old_stats[$(($base + 9))]}
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
  if [ $read -lt $old_read ]
  then
    # counter wrapped - add 2^32
    let "read += 4294967296"
  fi
  if [ $write -lt $old_write ]
  then
    # counter wrapped - add 2^32
    let "write += 4294967295"
  fi
  read_diff=$(($read - $old_read))
  write_diff=$(($write - $old_write))
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

	# log current values
#	echo `date +%Y.%m.%d.%H:%M:%S` "network_gmetric values: ${devname}: old_read: $old_read old_write: $old_write read: $read write: $write RPS: $rps WPS: $wps" >> /var/log/gmetric.log
	
  # report what we have calculated
	# only send in metric if it's greater than 0
	if [ `expr $rps \> 0` -eq 1 ];
	then
	  $GMETRIC $GMETRIC_ARGS --name="${devname}_rx" --value="$rps" --type="float" --units="bytes/sec"
	fi
	if [ `expr $wps \> 0` -eq 1 ];
	then
	  $GMETRIC $GMETRIC_ARGS --name="${devname}_tx" --value="$wps" --type="float" --units="bytes/sec"
	fi

#  echo "$devname $rps $wps $read_sum $write_sum " >> /tmp/foo.txt

  devnum=$((devnum + 1))
  get_rw $devnum
  get_old_rw $devnum
  res=$?
done

# log current values
#echo `date +%Y.%m.%d.%H:%M:%S` "network_gmetric values: sum: RPS: $read_sum WPS: $write_sum" >> /var/log/gmetric.log

# only send in metric if it's greater than 0
if [ `expr $read_sum \> 0` -eq 1 ];
then
	$GMETRIC $GMETRIC_ARGS --name="network_rx" --value="$read_sum" --type="float" --units="bytes/sec"
fi
if [ `expr $write_sum \> 0` -eq 1 ];
then
	$GMETRIC $GMETRIC_ARGS --name="network_tx" --value="$write_sum" --type="float" --units="bytes/sec"
fi

echo "$date" > $STATEFILE
cat $procfile | sed -e "s/:/ /" | grep "eth" >> $STATEFILE

rm -f $ERROR_CREATE $ERROR_IOSTAT $ERROR_DEVNAME2 $ERROR_DEVNAME $ERROR_GMETRIC $ERROR_TIMEDIFF $ERROR_NOTROOT

