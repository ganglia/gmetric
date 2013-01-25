#!/usr/bin/python

###############################################################################
# Get ping metrics. Supply an IP address or a name
#
# Uses ping command. Make sure you can run ping as the user.
#
# AUTHOR: Vladimir Vuksan
###############################################################################
import subprocess
import sys
import re
import os

# Variables that can be set
ping_binary = "/bin/ping"
ganglia_metric_group = "gw_ping"
gmetric_bin = "/usr/bin/gmetric"
number_of_pings = "5"

if (len(sys.argv) < 2):
  print "\nSupply name of host to ping....\n"
  exit(1)

host = sys.argv[1]

ping = subprocess.Popen(
    [ ping_binary, "-W", "1", "-c", number_of_pings , host],
    stdout = subprocess.PIPE,
    stderr = subprocess.PIPE
)

out, error = ping.communicate()

rtt_re = re.compile("(.*)min(.*) = (?P<min>\d+.\d+)/(?P<avg>\d+.\d+)/(?P<max>\d+.\d+)/(?P<mdev>\d+.\d+) ms$")
pkts_re = re.compile("(.*), (?P<packet_loss>.*)% packet loss")

gmetric_bin = gmetric_bin + " -g " + ganglia_metric_group  + " -t float"

for line in out.split('\n'):
    regMatch = rtt_re.match(line)
    if regMatch:
        linebits = regMatch.groupdict()
        for key in linebits:
            try:
                dur = float(linebits[key]) / 1000;
            except Exception:
                dur = 2
        
            os.system(gmetric_bin + " -u sec -n ping_time_" + host.replace(".","_") + "_" + key + " -v " + str(dur))


    regMatch2 = pkts_re.match(line)
    if regMatch2:
        linebits2 = regMatch2.groupdict()
        os.system(gmetric_bin + " -u sec -n ping_pktloss_" + host.replace(".","_") + " -v " + str(linebits2['packet_loss']))
