#!/usr/bin/perl

###########################################################################
# Author: Vladimir Vuksan http://vuksan.com/linux/
# Last Changed: $Date: 2009-09-06 20:51:39 -0400 (Ned, 06 Ruj 2009) $
# License: GNU Public License (http://www.gnu.org/copyleft/gpl.html)
# NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf

# Forked by Benjamin Goodacre to work with bind 9.8
# Handling of extraction of data needs tidying up, but works

$gmetric_exec = "/usr/bin/gmetric";
$gmetric_options = "-d 120 ";

# Path to the rndc binary
$rndc_exec = "/usr/sbin/rndc";

# Where to store the last stats file
$tmp_dir_base="/var/named/chroot/tmp/bind_stats";

# If you don't care about any of these particular metrics. Just remove them
# Only metrics whose string is unique in the named_stats file are supported
%counter_metrics = (
  "IPv4 requests received" => "req",
  "responses sent" => "req",
  "queries resulted in successful answer" => "req",
  "queries caused recursion" => "req",
  "queries resulted in SERVFAIL" => "req",
  "queries resulted in NXDOMAIN" => "req",
  "queries with RTT < 10ms" => "req",
  "queries with RTT 10-100ms" => "req",
  "queries with RTT 100-500ms" => "req",
  "queries with RTT 500-800ms" => "req",
);

$bind_stats = "/var/named/chroot/var/named/data/named_stats.txt";

# DON"T TOUCH BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
if ( ! -x $gmetric_exec ) {
  die("Gmetric binary is not executable. Exiting...");
}

if ( ! -x $rndc_exec ) {
  die("Rndc binary is not executable. Please check patch for \$rndc_exec. Exiting...");
}

$gmetric_command = $gmetric_exec . " " . $gmetric_options;
$debug = 0;

$tmp_stats_file=$tmp_dir_base . "/" . "bindstats";

# If the tmp directory doesn't exit create it
if ( ! -d $tmp_dir_base ) {
    print "Attempting to create directory $tmp_dir_base\n";
    system("mkdir -p $tmp_dir_base");
}


###############################################################################
# We need to store a baseline with statistics. If it's not there let's dump 
# it into a file. Don't do anything else
###############################################################################
if ( ! -f $tmp_stats_file ) {
  print "Creating baseline. No output this cycle\n";
  system("echo '' > $bind_stats; $rndc_exec stats ; egrep '^[a-z]* [0-9]*\$' $bind_stats > $tmp_stats_file");
} else {

	######################################################
	# Let's read in the file from the last poll
	open(OLDSTATUS, "< $tmp_stats_file");
	
	while(<OLDSTATUS>)
	{
		($blah, $value, $m1, $m2, $m3, $m4, $m5) = split (/\s+/);
		$metric = $m1 . " " . $m2 . " " . $m3 . " " . $m4 . " " . $m5;
		$metric =~ s/\s+$//;
		$old_stats{$metric}=${value};
	}
	
	# Get the time stamp when the stats file was last modified
	$old_time = (stat $tmp_stats_file)[9];
	close(OLDSTATUS);

	#####################################################
	# Get the new stats
	#####################################################
	system("echo > $bind_stats; $rndc_exec stats ; grep '^\\s*[0-9]'   $bind_stats > $tmp_stats_file");
	open(NEWSTATUS, "< $tmp_stats_file");
	$new_time = time(); 
	
	while(<NEWSTATUS>)
	{
		($blah, $value, $m1, $m2, $m3, $m4, $m5) = split (/\s+/);
		$metric = $m1 . " " . $m2 . " " . $m3 . " " . $m4 . " " . $m5;
		$metric =~ s/\s+$//;
		#print "$metric is $new_stats{$metricn} = ${value}\n";
		$new_stats{$metric}=${value};
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
	while ( my ($metric, $units) = each(%counter_metrics) ) {
	  my $rate = ($new_stats{$metric} - $old_stats{$metric}) / $time_difference;

	  if ( $rate < 0 ) {
	    print "Something is fishy. Rate for " . $metric . " shouldn't be negative. Perhaps counters were reset. Doing nothing";
	  } else {
	    #print "$metric = $new_stats{$metric}    $rate / sec\n";
	    if ( $debug == 0 ) {
	print $metric . " old " . $old_stats{$metric} . " new " . $new_stats{$metric} . "\n";
	   system($gmetric_command . " -g \"named_stats\" -u '$units/sec' -tfloat -n \"dns_" . $metric . "\" -v " . $rate);
	    }
	    
	  }
	  
	}
	
}

