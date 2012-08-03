#!/usr/bin/perl -W

##############################################################################
# This script queries NDB MGM for data and index usages on the particular
# node. Run out of cron on NDB nodes
##############################################################################

# NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf
my $gmetric_exec = "/usr/bin/gmetric";
my $gmetric_options = "";

# DON"T TOUCH BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
if ( ! -x $gmetric_exec ) {
	die("Gmetric binary is not executable. Exiting...");
}

my $gmetric_command = "echo " . $gmetric_exec . " " . $gmetric_options;
my $debug = 0;

my $node_id = 1;

$stats_command = 'ndb_mgm -e "$node_id REPORT MemoryUsage"';

#####################################################
# Get the new stats
#####################################################
open(NEWSTATUS, $stats_command . " |");
	
while(<NEWSTATUS>) {
  if (/^Node (.*): (.*) usage is (\S+)(\%)/) {
    my $name = lc($2);
    my $value = $3;

    if ( $debug == 0 ) {
      system($gmetric_command . " -g mysql_cluster -u 'pct' -tfloat -n ndb_" . $name . "_usage -v " . $value);	
    } else {
      print "$name is $value\n";
    }

  }
}
close(NEWSTATUS);
