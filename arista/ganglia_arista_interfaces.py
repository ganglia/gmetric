#!/usr/bin/env python

######################################################################
# Uses SysDb
#
# Run it with daemonize /persist/sys/ganglia_arista_interfaces.py
#
# Alternatively run it at boot with
#
# daemon ganglia_interfaces
#   command /persist/sys/ganglia_arista_interfaces.py    
######################################################################
import time, socket, json
import sys, os, copy 

import PyClient
pc = PyClient.PyClient('ar', 'Sysdb')

METRICS = {
    'time' : 0,
    'data' : {}
}

LAST_METRICS = dict(METRICS)

gmetric_cmd = "/usr/bin/gmetric -d 240 -g arista -c /persist/sys/gmond.conf  ";
# Get status of all interfaces
status = pc.root()['ar']['Sysdb']['interface']['status']['eth']['phy']

counters = dict()

####################################################################
# I want to convert any numbers to float. If they are no numbers
# but strings for whatever reason I want those to be set to 0
# e.g. out_discards often shows up as None. I don't want the script
# to die if that is the case so I'm using exceptions. Lame I know
####################################################################
def format_number(value):
  try:
    new_value = float(value)
  except:
    new_value = 0

  return new_value


new_metrics = dict() 

# Get a list of all interfaces
for ifname in status:
  # We need to "mount" every single interface. That way we do not have to keep remounting it
  counters[ifname] = pc.root()['ar']['Sysdb']['interface']['counter']['eth']['phy'][ifname]['current']
  new_metrics[ifname] = dict()


####################################################################
# Daemonize 
####################################################################
while 1:

  start_fetch = time.time() 
  new_time = time.time()

  # Loop through any know interfaces
  for ifname in status:
    new_metrics[ifname]["pkts_out"] = format_number(counters[ifname].statistics.outUcastPkts)
    new_metrics[ifname]["mcast_out"] = format_number(counters[ifname].statistics.outMulticastPkts)
    new_metrics[ifname]["bcast_out"] = format_number(counters[ifname].statistics.outBroadcastPkts)
    new_metrics[ifname]["pkts_in"] = format_number(counters[ifname].statistics.inUcastPkts)
    new_metrics[ifname]["mcast_in"] = format_number(counters[ifname].statistics.inMulticastPkts)
    new_metrics[ifname]["bcast_in"] = format_number(counters[ifname].statistics.inBroadcastPkts)
    new_metrics[ifname]["bytes_out"] = format_number(counters[ifname].statistics.outOctets)
    new_metrics[ifname]["bytes_in"] = format_number(counters[ifname].statistics.inOctets)
    new_metrics[ifname]["in_discards"] = format_number(counters[ifname].statistics.inDiscards)
    new_metrics[ifname]["in_errors"] = format_number(counters[ifname].statistics.inErrors)
    new_metrics[ifname]["out_discards"] = format_number(counters[ifname].statistics.outDiscards)
    new_metrics[ifname]["out_errors"] = format_number(counters[ifname].statistics.outErrors)

  end_fetch = time.time()

  fetch_time = end_fetch - start_fetch 

  # Emit metrics
  if LAST_METRICS['time'] != 0:
    time_diff = new_time - LAST_METRICS['time']
    for ifname in new_metrics:
      ifname_pretty = ifname.replace("Ethernet", "et").replace("Management", "ma").replace("Vlan", "vlan") 
      if status[ifname].linkStatus == "linkUp":
        for metric in new_metrics[ifname]:

          try:
            diff = (new_metrics[ifname][metric] - LAST_METRICS['data'][ifname][metric]) / time_diff

          except KeyError, e:
            pass

          # If difference is negative counters have rolled.
          if ( diff >= 0 ):
            os.system( gmetric_cmd + " -t float  -n "  + ifname_pretty + "_" + metric + " -u /sec -v " + str(diff))

  # update cache
  LAST_METRICS = {
     'time': time.time(),
     'data': copy.deepcopy(new_metrics)
  }

  time.sleep(30)
