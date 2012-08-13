#!/usr/bin/perl

use strict;

###########################################################################
# Author: Vladimir Vuksan http://vuksan.com/linux/
# License: GNU Public License (http://www.gnu.org/copyleft/gpl.html)
# Collects ethtool metrics ie. things you get by running
# ethtool -S <interface name>
###########################################################################

# NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf
my $gmetric_exec = "/usr/bin/gmetric";
my $gmetric_options = " -g ethtool";
my $ethtool_bin = "/sbin/ethtool";
my $metric_prefix = "ethtool";

# DON"T TOUCH BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
if ( ! -x $gmetric_exec ) {
	die("Gmetric binary is not executable. Exiting...");
}

############################################################################
# List of metrics we are interested in
############################################################################
my @metrics = (
	"multicast",
	"collisions",
	"rx_over_errors",
	"rx_crc_errors",
	"rx_frame_errors",
	"rx_fifo_errors",
	"rx_missed_errors",
	"tx_aborted_errors",
	"tx_carrier_errors",
	"tx_fifo_errors",
	"tx_heartbeat_errors",
	"lsc_int",
	"tx_busy",
	"non_eop_descs",
	"broadcast",
	"rx_no_buffer_count",
	"tx_timeout_count",
	"tx_restart_queue",
	"rx_long_length_errors",
	"rx_short_length_errors",
	"tx_flow_control_xon",
	"rx_flow_control_xon",
	"tx_flow_control_xoff",
	"rx_flow_control_xoff",
	"rx_csum_offload_errors",
	"alloc_rx_page_failed",
	"alloc_rx_buff_failed",
	"lro_aggregated",
	"lro_flushed",
	"lro_recycled",
	"rx_no_dma_resources",
	"hw_rsc_aggregated",
	"hw_rsc_flushed",
	"fdir_match",
	"fdir_miss",
	"fdir_overflow"
);

my $gmetric_command = $gmetric_exec . " " . $gmetric_options;
my $numArgs = $#ARGV + 1;

unless ( $numArgs >= 1 ) {
    die("You need to supply at least one network interface. For more than one use space delimited e.g. eth0 eth1");
}

# Where to store the last stats file
my $tmp_dir_base="/root/ethtool_stats";

# If the tmp directory doesn't exit create it
if ( ! -d $tmp_dir_base ) {
	system("mkdir -p $tmp_dir_base");
}

my $interface;

###############################################################################
# Now let's look through each supplied interface
###############################################################################
foreach $interface (<@ARGV>) {

  # Make sure interface actually exists
  if ( ! -l "/sys/class/net/${interface}" ) {
	print "Interface ${interface} is not a valid ethernet interface. Skipping.\n";
	next;
  }

  my $tmp_stats_file=$tmp_dir_base . "/" . "ethtool_${interface}";

  my $stats_command = "$ethtool_bin -S $interface";

  ###############################################################################
  # We need to store a baseline with statistics. If it's not there let's dump 
  # it into a file. Don't do anything else
  ###############################################################################
  if ( ! -f $tmp_stats_file ) {
    print "Creating baseline. No output this cycle\n";
    system("$stats_command > $tmp_stats_file");
  } else {

    my %old_stats;
    my %new_stats;
    
    ######################################################
    # Let's read in the file from the last poll
    open(OLDSTATUS, "< $tmp_stats_file");
    
    while(<OLDSTATUS>)
    {
         if (/(\s+)(.*): (\d+)/) {
              $old_stats{$2}=${3};
         }	
    }
    
    # Get the time stamp when the stats file was last modified
    my $old_time = (stat $tmp_stats_file)[9];
    close(OLDSTATUS);
    
    #####################################################
    # Get the new stats
    #####################################################
    system("$stats_command > $tmp_stats_file");
    open(NEWSTATUS, "< $tmp_stats_file");
    my $new_time = time(); 
    
    while(<NEWSTATUS>)
    {
         if (/(\s+)(.*): (\d+)/) {
              $new_stats{$2}=${3};
         }
    }
    close(NEWSTATUS);
    
    # Time difference between this poll and the last poll
    my $time_difference = $new_time - $old_time;
    if ( $time_difference < 1 ) {
         die("Time difference can't be less than 1");
    }
    
    #################################################################################
    # Calculate deltas for counter metrics and send them to ganglia
    #################################################################################	
    foreach my $metric ( @metrics ) {
         if ( defined $new_stats{$metric} ) {
              my $rate = ($new_stats{$metric} - $old_stats{$metric}) / $time_difference;
    
              if ( $rate < 0 ) {
                   print "Something is fishy. Rate for " . $metric . " shouldn't be negative. Perhaps counters were reset. Doing nothing";
              } else {
                   system($gmetric_command . " -tdouble -u '/s' -n ${metric_prefix}_${interface}_" . $metric . " -v " . $rate);
                   
              }
         }
    }

  } # end of if ( ! -f $tmp_stats_file ) {

  # Send pause parameters for the interface
  my $pause_params = `${ethtool_bin} --show-pause ${interface} | xargs echo | sed "s/.*Autonegotiate/Autonegotiate/g"`;
  system($gmetric_command . " -tstring -n ${metric_prefix}_pause_parameters_${interface} -v '${pause_params}'");
  
}


