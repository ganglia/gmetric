#!/usr/bin/perl
#
# Feeds ganglia with AoE error message information.
#
# Original Authors (to watch Apache logs):
#   Author: Nicolas Marchildon (nicolas@marchildon.net)
#   Modified by Ben Hartshorne
# 
# Further modified by Jesse Becker to do AoE stuff in August 2010.

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


my %units = (
    _default => 'msg_per_sec',
    nout     => 'Average value',
    nout_max => 'Max value per interval',
);


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
    my ($metric,$value,$type,$units) = @_;
    
    my $timeValid = $delay + 10; # Number of seconds this sample is good for
    my $cmd = "$GMETRIC $GMETRIC_ARGS --name=$metric --value=$value --type=$type --units='$units' --tmax=$timeValid";
    print '(Silent mode) ' if ($nosend && $debug);
    print  "CMD: $cmd\n" if $debug;

    
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
    
    foreach my $metric (keys %metrics) {
        my $rate= $metrics{$metric};
        $metrics{$metric} = 0;

         # Metrics of type foo_max and foo_min shouldn't be "averaged"
        if ( $metric eq 'nout' ) {
            if ($rate > 0 and $metrics{retransmit} > 0) {
                $rate /= $metrics{retransmit};
            }
        } 
        
        elsif ( $metric !~ /_(?:max|min)$/) {
            $rate /=  $delta;
        } 
        
        my $units = $units{$metric} || $units{_default};
        broadcast ("aoe_$metric", $rate, 'float', $units);
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

    if ($line =~ /retransmit.+nout=(\d+)/) {
        $metric_r->{retransmit}++;
        $metric_r->{nout}+=$1;
        $metric_r->{nout_max} = $1 > $metric_r->{nout_max} ? $1 : $metric_r->{nout_max};
        next;
    }
    
    elsif ($line =~ /unexpected rsp/) {
        $metric_r->{unexpected_rsp}++;
    }

    elsif ($line =~ /no frame available/) {
        $metric_r->{no_frame}++;
    } 
    
    else {
        $metric_r->{unknown}++;
    }

    
    return;
}

sysopen(ETHERD, "/dev/etherd/err",  O_RDONLY|O_NONBLOCK) || die "Failed open: [$!]";

$SIG{ALRM} = \&report;

alarm $delay;
my $first = 1;
while (1) {
    while (my $line=<ETHERD>) {
        #chomp $line;
        #print "Line: [$line]\n";
        parse_line \%metrics, $line;
    }
    #print 'Metrics after loop: '. Dumper(\%metrics);
    if ($first) {
        # don't report on first interval...  May have bogus old data.
        #&report;
        $first=0;
    }
    sleep $delay -0.01;
}

close ETHERD;

