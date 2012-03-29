<?php

# Specify a list of servers you want to monitor
$servers= array("serv1","serv2");

$community = "public";

# Add any other options you want.
$gmetric_cmd="/usr/bin/gmetric -d 180 ";

# snmp community
$community = "public";

# List of OIDs we want monitored
$absolute_metrics = array(
  "cpuutil" => ".1.3.6.1.4.1.789.1.2.1.3.0"
);

# More metrics found here https://github.com/wAmpIre/check_netappfiler/blob/master/check_netappfiler.py
$counter_metrics = array(
  "cpu_context_switches" => ".1.3.6.1.4.1.789.1.2.1.8.0",
  "cifs_ops" => "1.3.6.1.4.1.789.1.2.2.28.0",
  "nfs_ops" => "1.3.6.1.4.1.789.1.2.2.27.0",
  "diskio_readbytes" => ".1.3.6.1.4.1.789.1.2.2.32",
  "diskio_writebytes" => ".1.3.6.1.4.1.789.1.2.2.33",
  "net_rcvd_bytes" => ".1.3.6.1.4.1.789.1.2.2.30.0",
  "net_sent_bytes" => ".1.3.6.1.4.1.789.1.2.2.31.0"
);

$string_metrics = array(
   "global_status_message" => ".1.3.6.1.4.1.789.1.2.2.25.0"
);

$tmp_stats_file = "/tmp/netappstats";

$old_stats = array();

if ( is_file($tmp_stats_file) ) {
  $file = fopen ( $tmp_stats_file, "r");

  while (!feof ($file)) {
    $line = fgets ($file, 1024);
    $exploded = explode(",", $line);
    if ( sizeof($exploded) > 3 ) 
      $old_stats[$exploded[1]][$exploded[2]] = array( "time" => $exploded[0],  "value" => $exploded[3]);

    unset($exploded);
  }

  unlink($tmp_stats_file);

}


$output = "";

foreach ( $servers as $index => $server ) {

  print $server . " ";
  # Absolute metrics
  foreach ( $absolute_metrics as $metric => $oid ) {
      $value = `snmpwalk -v 2c -c $community $server $oid | awk '{ print \$4 }'`;
      system($gmetric_cmd . " --spoof " . $server . ":" . $server . " --name netapp_" . $metric . " --type float --units pct --value " . $value);
  }

  # Counter metrics

  foreach ( $counter_metrics as $metric => $oid ) {
      $snmp_value = `snmpwalk -v 2c -c $community $server $oid | awk '{ print \$4 }'`;
      $time = microtime(TRUE);

      $output .= join(",", array($time , $server , $metric, $snmp_value) );

      # Calculate diff
      if ( isset($old_stats[$server][$metric]) ) {
	$value = ($snmp_value - $old_stats[$server][$metric]["value"]) / ( $time -$old_stats[$server][$metric]["time"] ) ;
	# If value is negative counter most likely reset so zero it out
	if ( $value < 0 )
	  $value = 0;

      } else {
	$value = 0;
      }

      system($gmetric_cmd . "  --spoof " . $server . ":" . $server . " --name netapp_" . $metric . " --type float --units '/s' --value " . $value);

  }


}

file_put_contents($tmp_stats_file, $output);

print "\n";
?>
