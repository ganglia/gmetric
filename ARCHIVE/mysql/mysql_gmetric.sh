#!/bin/bash

### $Header: /var/lib/cvs/ops/ganglia/mysql_gmetric.sh,v 1.3 2006/07/11 17:51:13 ben Exp $

### this script is a replacement for mysql_metrics.sh
###  instead of just returning a single metric, this
###  script gets all three and submits them so you 
###  only hit mysqladmin once per minute instead of 
###  3 times

###  Copyright Simply Hired, Inc. 2006
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

VERSION=1.5

GMETRIC="/usr/bin/gmetric"
GMETRIC_ARGS="-c /etc/gmond.conf"
STATEFILE="/var/lib/ganglia/metrics/mysql.stats"
MYSQL_SOCKFILE="/var/lib/mysql/mysql.sock"
ERROR_NOTROOT="/tmp/mysql_gmetric_notroot"
ERROR_NOSOCKFILE="/tmp/mysql_gmetric_nosockfile"
ERROR_CANT_CONNECT="/tmp/mysql_gmetric_cant_connect"
ERROR_CREATE="/tmp/mysql_gmetric_create_statefile_failed"

# this script requires a user with usage and 'replication slave' privs.  if you
# don't check any slaves, you can leave out repl privs it will silently fail
# the slave test and not report the metric.
# usage means 'no privs' so having it on *.* doesn't expose anything. *.* is
# required for replication client.
### grant USAGE on *.* to 'ganglia'@'localhost' identified by 'xxxxx';
### grant REPLICATION CLIENT on *.* to 'ganglia'@'localhost' identified by 'xxxxx';
MYSQL_USER="ganglia"
MYSQL_PASS="xxxxx"

date=`date +%s`

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
  echo "Usage: submit_mysql_gmetric.sh [--clean]"
  echo "  --clean       delete all tmp files"
  exit 0
fi

if [ "x$1" == "x--clean" ]
then
  rm -f $STATEFILE $ERROR_NOTROOT $ERROR_NOSOCKFILE $ERROR_CANT_CONNECT $ERROR_CREATE
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

# if the sockfile doesn't exist, mysql probably isn't running.
if [ ! -e $MYSQL_SOCKFILE ]
then
  if [ -e $ERROR_NOSOCKFILE ] ; then exit 1 ; fi
  echo "Mysql sock file ($MYSQL_SOCKFILE) doesn't exist."
  echo "This usually implies that mysql isn't running."
  echo "I'm going to stop reporting until the sock file comes back."
  touch $ERROR_NOSOCKFILE
  exit 1
fi

# if we passed the sockfile test, but $ERROR_NOSOCKFILE exists, it was probably just started.
if [ -e $ERROR_NOSOCKFILE ]
then
	echo "The sock file has returned.  I'm starting up again."
	rm $ERROR_NOSOCKFILE
fi

exec 3>&2
exec 2>/dev/null
string=`mysqladmin --connect_timeout=15 -u $MYSQL_USER -p${MYSQL_PASS} status`
retval=$?
slavestr=`mysql --connect_timeout=15 -u $MYSQL_USER -p${MYSQL_PASS} -e "show slave status\G" | grep "Seconds_Behind_Master"`
exec 2>&3
exec 3>&-

if [ $retval -ne 0 ]
then
  if [ -e $ERROR_CANT_CONNECT ] ; then exit 1 ; fi
  echo "Even though the sock file exists, I can't connect to mysql."
  echo "Bummer. "
  touch $ERROR_CANT_CONNECT 
  exit 1
fi


threads=`echo $string | sed 's/.*Threads: \([0-9]*\) .*/\1/'`
queries=`echo $string | sed -e "s/.*Questions: \([0-9]*\) .*/\1/"`
slow_q=`echo $string | sed -e "s/.*Slow queries: \([0-9]*\) .*/\1/"`
# slave_sec might be empty if this db host is not a slave
slave_sec=`echo $slavestr | sed -e "s/.*Seconds_Behind_Master: \([0-9]*\).*/\1/"`

# save and turn off /STDERR for th estatefile tests
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
  echo "$date $queries $slow_q" > $STATEFILE
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

old_stats=(`cat $STATEFILE`)
old_date=${old_stats[0]}
old_queries=${old_stats[1]}
old_slow_q=${old_stats[2]}

echo "$date $queries $slow_q" > $STATEFILE

time_diff=$(($date - $old_date))
queries_diff=$(($queries - $old_queries))
slow_q_diff=$((slow_q - $old_slow_q))

if [ $time_diff -eq 0 ]
then
  if [ -e $ERROR_TIMEDIFF ] ; then exit 1 ; fi
  echo "something is broken."
  echo "time_diff is 0."
  touch $ERROR_TIMEDIFF
  exit 1
fi

if [ $queries_diff -le 0 ] ; then queries_diff=0 ; fi
if [ $slow_q_diff -le 0 ] ; then slow_q_diff=0 ; fi


#queries per second
qps=`echo "scale=3;$queries_diff / $time_diff" | bc`
sqps=`echo "scale=3;$slow_q_diff / $time_diff" | bc`

$GMETRIC $GMETRIC_ARGS --name="mysql_threads" --value=${threads} --type=int16
$GMETRIC $GMETRIC_ARGS --name="mysql_queries" --value=${qps} --type=float --units="qps"
$GMETRIC $GMETRIC_ARGS --name="mysql_slow_queries" --value=${sqps} --type=float --units="qps"

# if slave sec exists, i.e. this mysqld host is a slave.  
# If it's not, don't submit the metric
if [ -n "${slave_sec}" ]
then
	$GMETRIC $GMETRIC_ARGS --name="mysql_slave" --value="${slave_sec}" --type="int16" --units="sec"
fi
