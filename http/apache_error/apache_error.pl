#!/usr/bin/perl
#
# Feeds ganglia with web server error rate information.
#
# The latest version can be found on GitHub:
#
# http://github.com/ganglia/gmetric/tree/master/http/apache_error/
# 
# This script can be called by Apache by setting up a special logger:
#
#   LogFormat "%>s" status_only
#   CustomLog "|/path/to/apache-logs-to-ganglia.pl -d 10" status_only
#
#
# Original Author: Nicolas Marchildon (nicolas@marchildon.net)
# Date: 2002/11/26 04:15:19
#
# Modified by Ben Hartshorne
# $Header: /var/lib/cvs/ops/ganglia/ganglia_apache.pl,v 1.1 2006/07/11 17:29:27 ben Exp $

use Getopt::Long;

# Defaults
$DELAY = 20;
$METRIC = 'Apache';
$GMETRIC = "/usr/bin/gmetric";
$GMETRIC_ARGS="-c /etc/gmond.conf";

# Parse command line
GetOptions( { d => \$DELAY, delay => \$DELAY,
              m => \$METRIC, metric => \$METRIC
              },
            'd|delay=i',
            'p|port=i',
            'h|host=s',
            'm|metric=s');

# Validate command line
if ( length($DELAY) == 0
     || length($METRIC) == 0) {
        print STDERR <<EOS;
Parses apache log files and feeds a consolidated report of
response codes into the ganglia system.

Usage: $0 [OPTIONS]...

Other options:
  -m, --metric METRIC    the name of the metric the script is supposed to
                         check (default: $METRIC)
  -d, --delay DELAY      number of seconds between reports are sent
                         (default: $DELAY)

EOS
        exit 1;
}

$count200 = 0;
$count300 = 0;
$count400 = 0;
$count500 = 0;
$countOther = 0;
$start = time;

sub catch_hup {
    my $signame = shift;
    $shucks++;
    report;
}
#$SIG{HUP} = 'catch_zap';  # could fail in modules
$SIG{HUP} = \&catch_zap;  # best strategy

sub broadcast {
    my $metric = shift;
    my $value = shift;
    my $type = shift;
    my $units = shift;
    $timeValid = $DELAY + 10; # Number of seconds this sample is good for
    $cmd = "$GMETRIC $GMETRIC_ARGS --name=$metric --value=$value --type=$type --units=$units --tmax=$timeValid";
    print $cmd."\n";
    $ret = system($cmd) / 256;
    if ($ret == -1) {
        print("Unable to send data to ganglia: $!");
    }
}

sub report {
    print "Reporting... ";
    lock $count500;
    $total = $count200 + $count300 + $count400 + $count500 + $countOther;
    $delta = time - $start;
    $totalRate = $total / $delta;
    $twoRate = $count200 / $delta;
    $threeRate = $count300 / $delta;
    $fourRate = $count400 / $delta;
    $fiveRate = $count500 / $delta;
    $otherRate = $countOther / $delta;
    broadcast "apache_200", $twoRate, "float", "req_per_sec" ;
    broadcast "apache_300", $threeRate, "float", "req_per_sec" ;
    broadcast "apache_400", $fourRate, "float", "req_per_sec" ;
    broadcast "apache_500", $fiveRate, "float", "req_per_sec" ;
    broadcast "apache_other", $otherRate, "float", "req_per_sec" ;
    broadcast "apacheTotal", $totalRate, "float", "req_per_sec" ;
    $count200 = 0;
    $count300 = 0;
    $count400 = 0;
    $count500 = 0;
    $countOther = 0;
    $start = time;
    print "ok.\n";
}

sub parse_line {
    my $line = shift;
    #print LOGS "Got: '$line'\n";
    #system("logger Got: '$line'");
    $_ = $line;
    if (/5\d\d/) {
        $count500++;
    } elsif (/2\d\d/) {
		    $count200++;
    } elsif (/3\d\d/) {
		    $count300++;
    } elsif (/4\d\d/) {
		    $count400++;
		} else {
        $countOther++;
    }
    lock $count500;
    
}

while (true) {
    eval {
        local $SIG{ALRM} = sub { die "alarm clock restart" };
        alarm $DELAY;
        while (<>) {
            parse_line $_;
        }
        alarm 0;
    };
    if ($@ and $@ !~ /alarm clock restart/) { die }
    report;
}


