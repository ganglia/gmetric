#!/usr/bin/php
<?php

# Specify a list of servers you want to monitor
$servers= array("serv1","serv2");

# snmp community
$community = "public";

# Add any other options you want.
$gmetric_cmd="/usr/bin/gmetric -d 180 ";

# List of OIDs we want monitored
$absolute_metrics = array(
  array("metric" => "cpuutil",
        "oid"    => ".1.3.6.1.4.1.789.1.2.1.3.0",
	"group"  => "cpu",
        "desc"   => "The percent of time that the CPU has been doing useful work since the last time a client requested the cpuBusyTimePerCent."
        )
);

# More metrics found here https://github.com/wAmpIre/check_netappfiler/blob/master/check_netappfiler.py
$counter_metrics = array(
  array("metric" => "cpu_context_switches",
	"oid"    => ".1.3.6.1.4.1.789.1.2.1.8.0",
	"group"  => "cpu"
	),
  array("metric" => "cifs_ops",
	"oid"    => "1.3.6.1.4.1.789.1.2.2.28.0",
	"group"  => "cifs"
	),
  array("metric" => "cifs_reads",
	"oid"    => ".1.3.6.1.4.1.789.1.7.3.1.1.5.0",
	"group"  => "cifs"
	),
  array("metric" => "cifs_writes",
	"oid"    => ".1.3.6.1.4.1.789.1.7.3.1.1.6.0",
	"group"  => "cifs"
	),
  array("metric" => "nfs_ops",
	"oid"    => "1.3.6.1.4.1.789.1.2.2.27.0",
	"group"  => "nfs"
	),
  array("metric" => "diskio_readbytes",
	"oid"    => ".1.3.6.1.4.1.789.1.2.2.32.0",
	"group"  => "disk"
	),
  array("metric" => "diskio_writebytes",
	"oid"    => ".1.3.6.1.4.1.789.1.2.2.33.0",
	"group"  => "disk"
	),
  array("metric" => "net_rcvd_bytes",
	"oid"    => ".1.3.6.1.4.1.789.1.2.2.30.0",
	"group"  => "network",
	),
  array("metric" => "net_sent_bytes",
	"oid"    => ".1.3.6.1.4.1.789.1.2.2.31.0",
	"group"  => "network"
	),
  array("metric" => "fcp_ops",
        "oid"    => ".1.3.6.1.4.1.789.1.17.25.0",
        "group"  => "fcp"
        )

);

$string_metrics = array(
  array("metric" => "global_status_message",
	"oid"    => ".1.3.6.1.4.1.789.1.2.2.25.0",
	"desc"   => "A string describing the global status, including a description of the condition (if any) that caused the status to be anything other than ok(3)."
	)
);

// Volume specific metrics. These will be returned for each volume on the filer
$vol_metrics = array(
  array("metric" => "vol_pct_used",
	"oid"    => ".1.3.6.1.4.1.789.1.5.4.1.6",
	"group"  => "disk",
	"label"  => "%"
	),
  array("metric" => "vol_disk_total",
	"oid"    => ".1.3.6.1.4.1.789.1.5.4.1.29",
	"group"  => "disk",
	"label"  => "GB"
	),
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

// Check for group support
$verstr = chop(`gmetric -V`);
$ver = explode(" ",$verstr,2);
$hasgroup = 0;
if ($ver[1] >= 3.2) {
  $hasgroup = 1;
}

$output = "";

foreach ( $servers as $index => $server ) {

  print $server . " ";
  # Absolute metrics
  foreach ( $absolute_metrics as $metric ) {
    $oid = $metric['oid'];
    $snmpout = chop(`snmpget -v 2c -c $community $server $oid`);
    $data = explode(" ",$snmpout,4);
    $value = $data[3];
    $xtra_args = "";			// additional args for gmetric
    if (isset($metric['group']) && $hasgroup == 1) {	// Allow group to be specified
      $xtra_args .= " --group \"". $metric['group'] ."\"";
    }
    if (isset($metric['desc']) && $hasgroup == 1) {	// Add description if listed
      $xtra_args .= " --desc \"". $metric['desc'] ."\"";
    }
    system($gmetric_cmd . " --spoof " . $server . ":" . $server . " --name netapp_" . $metric['metric'] . " --type float --units pct --value " . $value . $xtra_args);
  }

  # Counter metrics

  foreach ( $counter_metrics as $metric ) {
    $oid = $metric['oid'];
    $snmpout = chop(`snmpget -v 2c -c $community $server $oid`);
    $data = explode(" ",$snmpout,4);
    $snmp_value = $data[3];
    $time = microtime(TRUE);

    $output .= join(",", array($time , $server , $metric['metric'], $snmp_value) ) . "\n";

    # Calculate diff
    if ( isset($old_stats[$server][$metric['metric']]) ) {
      $value = ($snmp_value - $old_stats[$server][$metric['metric']]["value"]) / ( $time -$old_stats[$server][$metric['metric']]["time"] ) ;
      # If value is negative counter most likely reset so zero it out
      if ( $value < 0 )
        $value = 0;

    } else {
     $value = 0;
    }

    $xtra_args = "";			// additional args for gmetric
    if (isset($metric['group']) && $hasgroup == 1) {	// Allow group to be specified
      $xtra_args .= " --group \"". $metric['group'] ."\"";
    }
    if (isset($metric['desc']) && $hasgroup == 1) {	// Add description if listed
      $xtra_args .= " --desc \"". $metric['desc'] ."\"";
    }
    system($gmetric_cmd . "  --spoof " . $server . ":" . $server . " --name netapp_" . $metric['metric'] . " --type float --units '/s' --value " . $value . $xtra_args);

  }

  # String metrics
  foreach ( $string_metrics as $metric ) {
    $oid = $metric['oid'];
    $snmpout = chop(`snmpget -v 2c -c $community $server $oid`);
    $data = explode(" ",$snmpout,4);
    $value = $data[3];
    $xtra_args = "";			// additional args for gmetric
    if (isset($metric['group']) && $hasgroup == 1) {	// Allow group to be specified
      $xtra_args .= " --group \"". $metric['group'] ."\"";
    }
    if (isset($metric['desc']) && $hasgroup == 1) {	// Add description if listed
      $xtra_args .= " --desc \"". $metric['desc'] ."\"";
    }
    system($gmetric_cmd . " --spoof " . $server . ":" . $server . " --name netapp_" . $metric['metric'] . " --type string --value " . $value . $xtra_args);
  }

  // Get NetApp Volumes and space (and anything else in $vol_metrics)
  // Get volumes
  $snmpout = explode("\n",`snmpwalk -mALL -v2c -c public $server .1.3.6.1.4.1.789.1.5.4.1.2`);
  $volinfo = array();
  foreach ( $snmpout as $snmp_data ) {
    // Get index and volume name
    if ($snmp_data != "") {
      $data = explode(" ",$snmp_data);
      $oid = explode(".",$data[0]);
      $data[3] = trim($data[3],'"');	// strip quotes
      $data[3] = preg_replace('/\/$/',"",$data[3]);	// and trailing slash
      if (preg_match('/\.snapshot$/',$data[3]) == 0) {	// skip snapshots
        $volinfo[$oid[count($oid)-1]]['volume'] = $data[3];
        $metric_base = preg_replace('/\//','_',$data[3]);
        $metric_base = preg_replace('/^_/','',$metric_base);
        $volinfo[$oid[count($oid)-1]]['volume_metric_base'] = $metric_base;
      }
    }
  }
  // Get metrics for each volume
  foreach ( $vol_metrics as $metric ) {
    $oid = $metric['oid'];
    $snmpout = explode("\n",`snmpwalk -mALL -v2c -c $community $server $oid`);
    foreach ( $snmpout as $snmp_data ) {
      // Get space used for each volume
      if ($snmp_data != "") {
        $data = explode(" ",$snmp_data);
        $oid = explode(".",$data[0]);
        if ($metric['label'] == "GB") {
	  $data[3] = $data[3] / 1024 / 1024;
        }
        $value = $data[3];
        $xtra_args = "";
        if (isset($metric['group']) && $hasgroup == 1) {	// Allow group to be specified
          $xtra_args .= " --group \"". $metric['group'] ."\"";
        }
        if (isset($metric['desc']) && $hasgroup == 1) {	// Add description if listed
          $xtra_args .= " --desc \"". $metric['desc'] ."\"";
        }
        if (isset($volinfo[$oid[count($oid)-1]]['volume'])) {
	  system($gmetric_cmd . "  --spoof " . $server . ":" . $server . " --name netapp_vol_" . $volinfo[$oid[count($oid)-1]]['volume'] ."_". $metric['metric'] . " --type float --units ". $metric['label'] ." --value " . $value . $xtra_args);
          $volinfo[$oid[count($oid)-1]][$metric['metric']] = $data[3];
        }
      }
    }
  }


}

# Store the status in a file. We use it to get counter metrics deltas
file_put_contents($tmp_stats_file, $output);

print "\n";
?>
