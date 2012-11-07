#!/usr/bin/python

###############################################################################
# You need Ganglia installed on Arista or alternatively install the
# gmetric.py from Ganglia_Contrib repo
#
# Don't run this script too often as it takes quite a bit of time
#
# AUTHOR: Vladimir Vuksan
###############################################################################
import sys
import re
import os
import datetime
import time
import subprocess

metric_suffix = "transceiver"
gmetric_cmd = "/usr/bin/gmetric -d 4000 -g transceiver "

transceiver_re=re.compile('(?P<port>\w+)(\s+)(?P<temp>[0-9.]+)(\s+)(?P<voltage>[0-9.]+)(\s+)(?P<bias_current>[0-9.]+)(\s+)(?P<optical_tx_power>[0-9\-.]+)(\s+)(?P<optical_rx_power>[0-9\-.]+)(\s+)(?P<last_update>.*)$')

try:
  output = subprocess.check_output(["/usr/bin/Cli", "-c", "show interfaces transceiver"])
  now = time.time()
  # Parse output
  for line in output.split('\n'):
  
    # First check whether it is showing the absolute value of routes
    regMatch = transceiver_re.match(line)
    if regMatch:
      linebits = regMatch.groupdict()
      port = linebits['port'].lower()
      os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_temp -u C -v " + linebits['temp'])
      os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_voltage -u V -v " + linebits['voltage'])
      os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_bias_current -u mA -v " + linebits['bias_current'])
      os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_optical_tx_power -u dBm -v " + linebits['optical_tx_power'])
      os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_optical_rx_power -u dBm -v " + linebits['optical_rx_power'])
      #time_diff = now - time.mktime(datetime.datetime.strptime(linebits['last_update'], "%Y-%m-%d %H:%M:%S").timetuple())
      #os.system( gmetric_cmd + " -t float -n " + port + "_" + metric_suffix + "_last_update -u sec -v " + str(time_diff))

except OSError, e:
  print e
