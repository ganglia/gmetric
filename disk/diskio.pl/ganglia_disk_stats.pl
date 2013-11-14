#!/usr/bin/perl -w

###########################################################################
# Author: Vladimir Vuksan http://vuksan.com/linux/
# Collects Disk IO metrics
# Last Changed: $Date: 2009-08-28 10:42:48 -0400 (Pet, 28 Kol 2009) $
# License: GNU Public License (http://www.gnu.org/copyleft/gpl.html)
# Currently it will collect and send to Ganglia following metrics
# 4 -> reads, 8 -> writes, 12 -> ios IO requests waiting
# If you would like some of the other stats append them
# below to @which_metrics
###########################################################################
use strict;
use v5.10;

my $VERBOSE=0;
my $gmetric_command = "/usr/bin/gmetric";

if ( !-x $gmetric_command ) {
    die("Gmetric command is not executable. Exiting...");
}

# Optional:
# Aggregate reports under the disk (default) section.
# Uncomment following line if you applyed a gmetric patch - available here: http://tobym.posterous.com/gmetric-track-and-group-arbitrary-metrics-wit
# $gmetric_command = $gmetric_command . " --group disk";


my $numArgs = $#ARGV + 1;

unless ( $numArgs >= 1 ) {
    die("You need to supply device(s) e.g. auto, sda, hda, md0, etc.");
}

my @which_metrics = split( / /, "4 8 6 10 13" );

# Where to store the last stats file
my $tmp_dir_base = "/tmp/disk_stats";

# Where are the disk stats stored
my $proc_file = "/proc/diskstats";

###########################################################################
# This is the order of metrics in /proc/diskstats
# 0 major         Major number
# 1 minor         Minor number
# 2 blocks        Blocks
# 3 name          Name
# 4 reads         This is the total number of reads completed successfully.
# 5 merge_read    Reads and writes which are adjacent to each other may be merged for
#               efficiency.  Thus two 4K reads may become one 8K read before it is
#               ultimately handed to the disk, and so it will be counted (and queued)
#               as only one I/O.  This field lets you know how often this was done.
# 6 s_read        This is the total number of sectors read successfully.
# 7 ms_read       This is the total number of milliseconds spent by all reads.
# 8 writes        This is the total number of writes completed successfully.
# 9 merge_write   Reads and writes which are adjacent to each other may be merged for
#               efficiency.  Thus two 4K reads may become one 8K read before it is
#               ultimately handed to the disk, and so it will be counted (and queued)
#               as only one I/O.  This field lets you know how often this was done.
# 10 s_write       This is the total number of sectors written successfully.
# 11 ms_write      This is the total number of milliseconds spent by all writes.
# 12 ios           The only field that should go to zero. Incremented as requests are
#               given to appropriate request_queue_t and decremented as they finish.
# 13 ms_io         This field is increases so long as field 9 is nonzero.
# 14 ms_weighted   This field is incremented at each I/O start, I/O completion, I/O
###########################################################################
my %disk_stat = (
    4  => "reads",
    5  => "merge_read",
    6  => "s_read",
    7  => "ms_read",
    8  => "writes",
    9  => "merge_write",
    10 => "s_write",
    11 => "ms_write",
    12 => "ios",
    13 => "ms_io",
    14 => "ms_weighted"
);

# If the tmp directory doesn't exit create it
if ( !-d $tmp_dir_base ) {
    system("mkdir -p $tmp_dir_base");
}
my $arg;

if( $ARGV[0] eq "auto" ) {
    foreach $arg ( find_all_devices() ) {
	do_stats($arg);
    }
}
else {
    foreach $arg (<@ARGV>) {
	do_stats($arg);
    }
}

sub find_all_devices {
    open( my $PARTITIONS, "< /proc/partitions");
    my @devices;
    while(<$PARTITIONS>) {
	my $line = $_;
	chomp($line);
	$line =~ s{^\s+}{};
	my @line = split(/\s+/, $line);
	next unless $line[0];
	next if $line[0] =~ m{^(\s*|major|loop|drdb|dm-.*)$}x;
	push(@devices, $line[3]);
    }
    return @devices;
}

sub do_stats {
    my $device         = shift;

    # temp dir creation
    my @splitted        = split(/\//,$device);
    for ( my $i=0 ; $i < $#splitted ; $i++ ) {
        $tmp_dir_base = $tmp_dir_base . "$splitted[$i]/";
    }

    # $device variable for parsing init
    $device = "";
    for (my  $i=2 ; $i < $#splitted ; $i++ ) {
        $device = $device . "$splitted[$i]/";
    }
    
    $device = $device . "$splitted[$#splitted]";
    my $tmp_stats_file = $tmp_dir_base . "/$splitted[$#splitted]";

###############################################################################
    # We need to store a baseline with statistics. If it's not there let's dump
    # it into the file. Don't do anything else
###############################################################################
    if ( !-f $tmp_stats_file ) {
        print "Creating baseline. No output this cycle\n" if $VERBOSE;
        system("cat $proc_file > $tmp_stats_file");
    }
    else {

        # Let's read in the file from the last poll
        open( my $OLDSTATUS, "< $tmp_stats_file" );
        my @old_stats;
        while (<$OLDSTATUS>) {
            my $line = $_;
            chomp($line);
            @old_stats = split( / +/, $line );
            if ( $old_stats[3] eq $device ) {
                last;
            }
            undef(@old_stats);

        }

        close($OLDSTATUS);

        # Get the time stamp when the stats file was last modified
        my $old_time = ( stat $tmp_stats_file )[9];

        open( my $NEWSTATUS, "< $proc_file" );
        my @new_stats;
        while (<$NEWSTATUS>) {
            my $line = $_;
            chomp($line);
            @new_stats = split( / +/, $line );
            if ( $new_stats[3] eq $device ) {
                system("echo '$line' >  $tmp_stats_file");
                last;
            }
            undef(@new_stats);
        }

        close($NEWSTATUS);
        my $new_time = time();

        # Time difference between this poll and the last poll
        my $time_difference = $new_time - $old_time;
        if ( $time_difference < 1 ) {
            die("Time difference can't be less than 1");
        }

        # Calculate deltas and send them to ganglia
        for ( my $i = 0 ; $i <= $#which_metrics ; $i++ ) {
            my $metric = $which_metrics[$i];
            my $delta  = $new_stats[$metric] - $old_stats[$metric];
            my $rate   = int( $delta / $time_difference );

            if ( $rate < 0 ) {
                print "Something is fishy. Rate for " . $metric
                  . " shouldn't be negative. Perhaps counters were reset. Doing nothing";
            }
            else {
####################################################################################################
# Metrics 6 and 10 are sectors read
# http://svn.wikimedia.org/viewvc/mediawiki/trunk/ganglia_metrics/GangliaMetrics.py?view=log
#      The sector size in this case is hard-coded in the kernel as 512 bytes
#      There doesn't appear to be any simple way to retrieve that figure
		
		#replacing "/" by "_" for later graph generation
                $device =~ s/\//\_/;

                if ( $which_metrics[$i] == "6" || $which_metrics[$i] == "10" ) {
                    $rate = $rate * 512;
                    print "$disk_stat{$metric} = $rate bytes/sec\n" if $VERBOSE;
                    system( $gmetric_command
                          . " -tdouble -u 'bytes/sec' -n diskstat_"
                          . $device . "_"
                          . $disk_stat{$metric} . " -v "
                          . $rate );
                }
		elsif ($which_metrics[$i] == "13") {
		    my $percentage=$rate/10;	# convert ms/s to a percentage
		    print "$disk_stat{$metric} = $percentage%\n" if $VERBOSE;
		    system( $gmetric_command
                          . " -tdouble -u 'percent' -n diskstat_"
                          . $device . "_"
                          . "utilisation" . " -v "
                          . $percentage );
                }
                else {
                    print "$disk_stat{$metric} = $rate / sec\n" if $VERBOSE;
                    system( $gmetric_command
                          . " -tuint16 -u 'calls/sec' -n diskstat_"
                          . $device . "_"
                          . $disk_stat{$metric} . " -v "
                          . $rate );
                }

            }
        }
        call_gmetric( @new_stats, $device );

    }
}

sub call_gmetric {
    my @new_stats = @_;
    my $device    = shift;

    # io requests waiting is not a counter but an absolute value
    my $metric = 12;
    system( $gmetric_command
          . " -tuint16 -u 'ops in queue' -n diskstat_"
          . $device
          . "_iowait_queue -v "
          . $new_stats[$metric] );
}
