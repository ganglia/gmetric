#!/usr/bin/perl
#
# Script to monitor Varnish metrics via Ganglia
#
# Author: pippoppo <pippoppo@gmail.com>
# based on the work of Vladimir Vuksan http://vuksan.com/linux/ (other ganglia perl scripts)
#
# Requirements:
# 	- Needs access to varnishstat command
#

use strict;
use warnings FATAL => 'all';
use XML::Simple;
use Getopt::Long;

sub print_usage ();

####################################################################################
# YOU MAY NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf
####################################################################################
my $gmetric_exec    = "/usr/bin/gmetric";
my $gmetric_options = " -d 120 ";
####################################################################################
my $gmetric_command = $gmetric_exec . $gmetric_options;
my $debug           = 0;
my $opt_help;
my %newstats;
my %oldstats;
my $oldtime;
my $newtime;
my $varnishstat        = "/usr/bin/varnishstat";
my $varnishstatcommand = $varnishstat . " -1 -x";
my $tmp_dir_base       = "/tmp/varnish_stats";
my $varnishstatxml     = $tmp_dir_base . "/varnishstat.xml";
my $varnishstatxmlold  = $tmp_dir_base . "/varnishstat.xml.old";

###################################################################
#for a complete list of available metrics, please run in debug mode
###################################################################

my %counter_metrics = (
    "cache_hit"  => "hits",
    "cache_miss" => "hits",
);

my %absolute_metrics = ( "accept_fail" => "number", );

# If the tmp directory doesn't exist create it
if ( !-d $tmp_dir_base ) {
    system("mkdir -p $tmp_dir_base");
}

my $cmdline = GetOptions(
    "help" => \$opt_help,    #flag
    "d"    => \$debug
);

unless ($cmdline) {
    print_usage;
    exit 1;
}

if ( defined($opt_help) ) {
    print_usage;
    exit 1;
}

if ( !-f $varnishstat ) {
    die("Missing varnishstat command\n");
}

system("$varnishstatcommand > $varnishstatxml");
if ( !-f $varnishstatxml ) {
    die("Missing $varnishstatxml file\n");
}
else {
    $newtime = ( stat $varnishstatxml )[9];
}
if ( !-f $varnishstatxmlold ) {
    print "Missing $varnishstatxmlold file\n";
    print "Creating baseline. No output this cycle\n";
    system("mv $varnishstatxml $varnishstatxmlold");
    exit 0;
}
else {
    $oldtime = ( stat $varnishstatxmlold )[9];
}
my $timediff = $newtime - $oldtime;
if ( $timediff < 1 ) {
    die("Time difference can't be less than 1");
}
my $xs = new XML::Simple;
my $newstatsxml = $xs->XMLin( $varnishstatxml, ForceArray => 1 );
if ( $debug != 0 ) {
    use Data::Dumper;
    print Dumper($newstatsxml);
}
my $oldstatsxml = $xs->XMLin( $varnishstatxmlold, ForceArray => 1 );
if ( $debug != 0 ) {
    use Data::Dumper;
    print Dumper($oldstatsxml);
}

foreach my $stat ( @{ $newstatsxml->{stat} } ) {
    if ( $debug != 0 ) {
        print "NEW " . $stat->{name}->[0] . "=" . $stat->{value}->[0] . "\n";
    }
    $newstats{ $stat->{name}->[0] } = $stat->{value}->[0];
}

foreach my $stat ( @{ $oldstatsxml->{stat} } ) {
    if ( $debug != 0 ) {
        print "OLD " . $stat->{name}->[0] . "=" . $stat->{value}->[0] . "\n";
    }
    $oldstats{ $stat->{name}->[0] } = $stat->{value}->[0];
}

system("mv $varnishstatxml $varnishstatxmlold");

if ( $newstats{'uptime'} < $oldstats{'uptime'} ) {
    die("negative number, maybe server was restarted");
}

#################################################################################
# Calculate deltas for counter metrics and send them to ganglia
#################################################################################
while ( my ( $metric, $units ) = each(%counter_metrics) ) {
    my $rate = ( $newstats{$metric} - $oldstats{$metric} ) / $timediff;

    if ( $rate < 0 ) {
        print "Something is fishy. Rate for " . $metric
          . " shouldn't be negative. Perhaps counters were reset. Doing nothing";
    }
    else {
        print "$metric = $rate / sec\n";
        if ( $debug == 0 ) {
            system( $gmetric_command
                  . " -u '$units/sec' -tfloat -n varnish_"
                  . $metric . " -v "
                  . $rate );
        }
    }
}
#################################################################################
# Just send absolute metrics. No need to calculate delta
#################################################################################
while ( my ( $metric, $units ) = each(%absolute_metrics) ) {
    print "$metric = $newstats{$metric}\n";
    if ( $debug == 0 ) {
        system( $gmetric_command
              . " -u $units -tuint16 -n varnish_"
              . $metric . " -v "
              . $newstats{$metric} );
    }
}

exit 0;

sub print_usage () {
    print <<'END_USAGE'
Usage: ganglia-varnish-stats.pl [OPTION]...
Collect varnish statistics

Options:
  -help                     Usage information
  -d                        Debug flag. If not supplied defaults to false
END_USAGE
      ;
    exit;
}
