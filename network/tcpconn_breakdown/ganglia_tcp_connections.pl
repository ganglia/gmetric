#!/usr/bin/perl

use strict;
use warnings;

use File::Temp;
my $ft = File::Temp->new(
    UNLINK   => 0,
    TEMPLATE => '/tmp/ganglia_tcp.XXXXXXXXXX',
);

my $temp_file = $ft->filename;

$ENV{'PATH'} = '/bin:/usr/bin:/sbin';
my $ss_command="ss -an | grep -v ^State";
my $gmetric_command = "/usr/bin/gmetric -g tcpconn -t uint32 -d 86400 ";

# Dump ss command results into a temp file. We want to do it as quickly as
# possible to avoid blocking any sockets
system("$ss_command > " . $temp_file);

# Let's get breakdown of types of TCP connections
open(STATUS, "-|", "/bin/cat " . $temp_file . "|  cut -d ' ' -f 1 | sort | uniq -c | sort -rn");

my $total = 0;
my $synrecv = 0;

while(<STATUS>) {
    my ($value, $metric) = split;
    $metric =~ s/-//g;
    $metric = lc($metric);
    # 
    if ( $metric eq "synrecv" ) {
        $synrecv = $value;
    }
    my $full_metric_name = "tcpconn_" . $metric;
    system($gmetric_command . " -u conn -n " . $full_metric_name . " -v " . $value);
    $total += $value;
}

close(STATUS);

################################################################################
# Calculate SYN-RECV percentage
################################################################################
my $syn_percentage = 100 * ($synrecv / $total);
system($gmetric_command . " -n tcpconn_synrecv_percentage -u pct -T 'Pct of connections in Syn-Recv' -v " . $syn_percentage);

################################################################################
# Find out how many Unique IPS
################################################################################
my $uniq_ips = `/bin/cat $temp_file | awk '{ print \$5 }'  | cut -f1 -d: | sort | uniq | wc -l`;

if ( $uniq_ips >= 0 ) {
    system($gmetric_command . " -n tcpconn_uniq_ips -u ips -T 'Unique IPs connecting' -v " . $uniq_ips);
}


unlink($temp_file);
