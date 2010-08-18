#!/usr/bin/perl
#
# Feeds ganglia with web server error rate information.
#
# Can be called by Apache by setting up a special logger:
#
#   LogFormat "%>s" status_only
#   CustomLog "|/path/to/apache-logs-to-ganglia.pl -d 10" status_only
#
#
# Author: Nicolas Marchildon (nicolas@marchildon.net)
# Date: $Date: 2002/11/26 04:15:19 $
# Revision: $Revision: 1.3 $


use Getopt::Long;

# Defaults
$DELAY = 20;
$METRIC = 'Apache';

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
    $cmd = "/usr/bin/gmetric --name=$metric --value=$value --type=$type --units=$units --tmax=$timeValid";
    print $cmd."\n";
    $ret = system($cmd) / 256;
    if ($ret == -1) {
        print("Unable to send data to ganglia: $!");
    }
}

sub report {
    print "Reporting... ";
    lock $count500;
    $total = $count500 + $countOther;
    $delta = time - $start;
    $totalRate = $total / $delta;
    $errorRate = $count500 / $delta;
    if ($total > 0) {
        $percent500 = 100 * $count500 / $total;
    } else {
        $percent500 = 0;
    }
    broadcast $METRIC."ErrorPercentage", $percent500, "float", "%" ;
    broadcast $METRIC."ErrorRate", $errorRate, "float", "requests" ;
    broadcast $METRIC."RequestRate", $totalRate, "float", "requests" ;
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
