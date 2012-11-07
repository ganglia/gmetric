#!/usr/bin/python

###############################################################################
# You need Ganglia installed on Arista or alternatively install the
# gmetric.py from Ganglia_Contrib repo
###############################################################################
import sys
import socket
import re
import os
import pickle
import time
import subprocess

gmetric_cmd = "/usr/bin/gmetric -d 240 -g arista ";
old_stats_file = "/var/tmp/arista_interface_stats"

#Ethernet2 is up, line protocol is up (connected)
#  Hardware is Ethernet, address is 001c.7315.4f4c (bia 001c.7315.4f4c)
#  MTU 9212 bytes, BW 10000000 Kbit
#  Full-duplex, 10Gb/s, auto negotiation: off
#  Up 28 days, 16 hours, 41 minutes, 31 seconds
#  Last clearing of "show interface" counters never
#  5 minutes input rate 94.6 Mbps (1.0% with framing), 44460 packets/sec
#  5 minutes output rate 914 Mbps (9.3% with framing), 102236 packets/sec
#     116444952493 packets input, 32638819092719 bytes
#     Received 11778 broadcasts, 0 multicast
#     0 runts, 0 giants
#     0 input errors, 0 CRC, 0 alignment, 0 symbol
#     0 PAUSE input
#     258494794597 packets output, 296163875263383 bytes
#     Sent 860721 broadcasts, 16166088 multicast
#     0 output errors, 0 collisions
#     0 late collision, 0 deferred
#     0 PAUSE output
interface_re=re.compile('^(?P<interface_type>\D+)(?P<interface>\d+)( is )(?P<interface_state>\w+)(, line protocol is )')
traffic_inbound_re=re.compile('(\s+)(?P<pkts_in>\d+)( packets input, )(?P<bytes_in>\d+)( bytes)')
traffic_outbound_re=re.compile('(\s+)(?P<pkts_out>\d+)( packets output, )(?P<bytes_out>\d+)( bytes)')
bcast_inbound_re=re.compile('(\s+)(Received )(?P<bcast_in>\d+)( broadcasts, )(?P<mcast_in>\d+)( multicast)')
bcast_outbound_re=re.compile('(\s+)(Sent )(?P<bcast_out>\d+)( broadcasts, )(?P<mcast_out>\d+)( multicast)')
pause_re=re.compile('(\s+)(?P<pause_value>\d+)( PAUSE )(?P<pause_type>output|input)')
input_errors_re=re.compile('(\s+)(?P<in_errors>\d+)( input errors, )(?P<in_crc>\d+)( CRC, )(?P<in_align>\d+)( alignment, )(?P<in_symbol>\d+)( symbol)')
output_errors_re=re.compile('(\s+)(?P<out_errors>\d+)( output errors, )(?P<out_collisions>\d+)( collisions)')
runts_re=re.compile('(\s+)(?P<runts>\d+)( runts, )(?P<giants>\d+)( giants)')
collision_re=re.compile('(\s+)(?P<late_collision>\d+)( late collision, )(?P<deferred>\d+)( deferred)')


old_stats = dict()
##############################################################################
# Read in old stats if the file is present
##############################################################################
if os.path.isfile(old_stats_file):
  pkl_file = open(old_stats_file, 'rb')
  old_stats = pickle.load(pkl_file)
  pkl_file.close()
  old_time = os.stat(old_stats_file).st_mtime

try:
  # Initialize dictionary
  new_stats = dict()

  current_interface = ""

  output = subprocess.check_output(["/usr/bin/Cli", "-c", "show interfaces"])
  new_time = time.time()
  # Parse output
  for line in output.split('\n'):
  
    # First check whether it is showing the absolute value of routes
    regMatch = interface_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      if linebits['interface_type'] == "Ethernet":
          current_interface = "et" + linebits['interface']
      else:
          current_interface = linebits['interface_type'].lower() + linebits['interface']        
      new_stats[current_interface] = dict()
      new_stats[current_interface]['state'] = linebits['interface_state']
      continue

    regMatch = traffic_inbound_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = traffic_outbound_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = bcast_inbound_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = bcast_outbound_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = input_errors_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = output_errors_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = runts_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = collision_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      for key in linebits:
        new_stats[current_interface][key] = linebits[key]
      continue

    regMatch = pause_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      metric_key = "pause_" + linebits['pause_type']
      new_stats[current_interface][metric_key] = linebits['pause_value']
      continue

    # Write up stats into a file for use next time around
    output = open(old_stats_file, 'wb')
    pickle.dump(new_stats, output)
    output.close()
  

  # Make sure we have old stats. Otherwise we can't calculate diffs
  if len(old_stats) > 0:
    time_diff = new_time - old_time
    for key in new_stats:
      # Only emit traffic stats for interfaces that are up
      if new_stats[key]['state'] == "up":
        for subkey in new_stats[key]:
          if subkey not in ['state']:
            #print key + "_" + subkey + "=" + new_stats[key][subkey]
            diff = (int(new_stats[key][subkey]) - int(old_stats[key][subkey])) / time_diff
            # If difference is negative counters have rolled.
            if ( diff >= 0 ):
              os.system( gmetric_cmd + " -t float  -n "  + key + "_" + subkey + " -u /sec -v " + str(diff))

except OSError, e:
  print e

