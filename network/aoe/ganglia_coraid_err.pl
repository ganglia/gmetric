#!/usr/bin/perl
#
# Feeds ganglia with AoE error message information.
#
# Original author, to watch Apache error logs:
# Author: Nicolas Marchildon (nicolas@marchildon.net)
# Date: Date: 2002/11/26 04:15:19 
# Revision: Revision: 1.3 
# 
#
# Modified by Ben Hartshorne (still with Apache)
# $Header: /var/lib/cvs/ops/ganglia/ganglia_apache.pl,v 1.1 2006/07/11 17:29:27 ben Exp $
#
# Further modified by Jesse Becker to do AoE stuff in August 2010.
#

use Getopt::Long;
use strict;
use POSIX;
use Data::Dumper;
use Time::HiRes qw(time);

# Defaults
my $delay = 15;
my $METRIC = 'AoE Retrans';
my $GMETRIC = "/usr/bin/gmetric";

my $gmond_conf = -f '/etc/gmond.conf'         ? '/etc/gmond.conf'         :
                 -f '/etc/ganglia/gmond.conf' ? '/etc/ganglia/gmond.conf' : '' ;
my $GMETRIC_ARGS="-c $gmond_conf";

my $debug = 0;
my $nosend = 0;

# Parse command line
GetOptions( 'd|delay=i'  => \$delay,
            'm|metric=s' => \$METRIC,
            'v|verbose'  => \$debug,
            'n|nosend'   => \$nosend,
          );

# Validate command line
if ( length($delay) == 0  or 
     !$delay or 
     length($METRIC) == 0) {
        print STDERR <<EOS;
Parses apache log files and feeds a consolidated report of
response codes into the ganglia system.

Usage: $0 [OPTIONS]...

Other options:
  -m, --metric METRIC    the name of the metric the script is supposed to
                         check (default: "$METRIC")
  -d, --delay delay      number of seconds between reports are sent (>0)
                         (default: $delay)

EOS
        exit 1;
}


my %metrics;

my $start = time;

my $shucks;

#################################################################################
sub catch_hup {
    my $signame = shift;
    $shucks++;
    &report(%metrics);
}
#################################################################################
$SIG{HUP} = \&catch_hup;  # best strategy

sub broadcast {
    my $metric = shift;
    my $value = shift;
    my $type = shift;
    my $units = shift;
    my $timeValid = $delay + 10; # Number of seconds this sample is good for
    my $cmd = "$GMETRIC $GMETRIC_ARGS --name=$metric --value=$value --type=$type --units=$units --tmax=$timeValid";
    print "CMD: $cmd\n" if $debug;

    return if $nosend;
    
    my $ret = system($cmd) / 256;
    if ($ret == -1) {
        print("Unable to send data to ganglia: $!");
    }
}

sub report {
    my ($signal) = @_;
    #print "Reporting... ";

    my %rates;

    my $delta = time - $start;
    if ($delta < 1) { $delta =1};
    print "Reporting on($delta): ". Dumper(\%metrics) if $debug;
    foreach (keys %metrics) {
        my $rate = $metrics{$_} / $delta;
        $metrics{$_} = 0;
        broadcast ("aoe_$_", $rate, 'float', 'msg_per_sec');
    }
    
    $start = time;
    #print "ok.\n";
    alarm $delay;
}

sub parse_line {
    my ($metric_r, $line) = @_;
#     retransmit e50.0 oldtag=479651ce@145455266 newtag=47b45266 s=00156004fa93 d=0030486208bd nout=2
# unexpected rsp e50.0    tag=479651ce@145455266 s=0030486208bd d=00156004fa93

    #print Dumper($metric_r, $line);

    $metric_r->{retransmit}++     if $line =~ /retransmit/;
    $metric_r->{unexpected_rsp}++ if $line =~ /unexpected rsp/;

    return;
}

sysopen(ETHERD, "/dev/etherd/err",  O_RDONLY|O_NONBLOCK) || die "Failed open: [$!]";

$SIG{ALRM} = \&report;

alarm $delay;
my $first = 1 ;
while (1) {
    while (my $line=<ETHERD>) {
        #chomp $line;
        #print "Line: [$line]\n";
        parse_line \%metrics, $line;
    }
    #print 'Metrics after loop: '. Dumper(\%metrics);
    if ($first) {
        &report;
        $first=0;
    }
    sleep $delay -0.01;
}

close ETHERD;

