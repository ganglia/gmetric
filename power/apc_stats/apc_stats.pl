#!/usr/bin/perl
#
# Grab APC Uninterruptible Power Supply (UPS) stats and report to ganglia
# Requires that apcupsd and associated utilities (i.e., apcaccess) are
# installed.  This script has been tested on a RedHat Linux 7.3 system
# running on an APC SmartUPS5000 power supply connected via serial port.
# You may find apcupsd at:  http://www.apcupsd.com
#
# This script creates 3 metrics:
# ups_load: Load on UPS as percentage of capacity
# ups_batt_chg: Battery charge as percentage of capacity
# ups_time_left: UPS runtime left in minutes
#
# a typical /etc/cron.d line for this script would be:
#
# * * * * *    root  /usr/local/bin/apcups_metric > /dev/null 2>&1
# 
# Author: Greg Wimpey, Colorado School of Mines 26 May 2004
# Email:  gwimpey <at> mines <dot> edu
#
# This script may be freely copied, distributed, or modified
# as long as authorship and copyright information is maintained.
# Copyright 2004 Colorado School of Mines
#
#

$apcaccess='/sbin/apcaccess'; # location of apcaccess command
$statusarg='status';          # argument for apcaccess
$gmetric='/usr/bin/gmetric';  # ganglia gmetric command

# initialize metrics
$loadpct=0.0;
$bcharge=0.0;
$timeleft=0.0;

( -x $apcaccess ) || die "Can't execute $apcaccess\n";

open APC,"$apcaccess $statusarg |" ||
    die "Can't open pipe from $apcaccess $statusarg\n";
while (<APC>) {
    @field = split ':';
    if ($field[0] =~ /LOADPCT/) {
	($loadpct,$junk) = split ' ',$field[1];
    }
    elsif ($field[0] =~ /BCHARGE/) {
	($bcharge,$junk) = split ' ',$field[1];
    }
    elsif ($field[0] =~ /TIMELEFT/) {
	($timeleft,$junk) = split ' ',$field[1];
    }
}
close APC;

# send metrics to ganglia as floats
system("$gmetric -nups_load -v$loadpct -tfloat -u%");
system("$gmetric -nups_batt_chg -v$bcharge -tfloat -u%");
system("$gmetric -nups_time_left -v$timeleft -tfloat -umins");

exit 0;
