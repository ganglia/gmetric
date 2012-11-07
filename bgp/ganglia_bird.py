#!/usr/bin/python

###############################################################################
# This script collects stats for Bird Internet Routing daemon
# http://bird.network.cz/
#
# Script needs to run as root or you need a figure out a way to talk to
# bird over socked at /var/run/bird.ctl
#
# AUTHOR: Vladimir Vuksan
###############################################################################
import sys
import socket
import re
import os
import pickle
import time

if len(sys.argv) > 1:
  provider_name = sys.argv[1]
else:
  print "You need to specify provider name to match show protocols all ebgp_provider_name"
  sys.exit()

metric_prefix = "bird_" + provider_name;
gmetric_cmd = "/usr/bin/gmetric -d 240 -g bird ";
old_stats_file = "/var/tmp/bird_stats_" + provider_name + ".pkl"

# In the output these are the metrics we really care about
interesting_bits = ["received", "rejected", "filtered", "ignored", "accepted"]

# Regex matches
routes_re=re.compile('(\s+)(Routes:)(\s+)(?P<imported>[^ ]+) imported, (?P<exported>[^ ]+) exported, (?P<preferred>[^ ]+) preferred')
updates_re=re.compile('(\s+)(?P<type>Import|Export) (?P<action>updates|withdraws):(\s+)(?P<received>[0-9-]+)(\s+)(?P<rejected>[0-9-]+)(\s+)(?P<filtered>[0-9-]+)(\s+)(?P<ignored>[0-9-]+)(\s+)(?P<accepted>[0-9-]+)')

old_stats = dict()
##############################################################################
# Read in old stats if the file is present
##############################################################################
if os.path.isfile(old_stats_file):
  pkl_file = open(old_stats_file, 'rb')
  old_stats = pickle.load(pkl_file)
  pkl_file.close()
  old_time = os.stat(old_stats_file).st_mtime

s = socket.socket(socket.AF_UNIX)
s.connect("/var/run/bird.ctl")
# We don't care about the banner
s.recv(1024)
# Send command to bird
s.send('show protocols all ebgp_' + provider_name + '\n')
data = s.recv(16384)
lines = data.splitlines()
s.close()

new_time = time.time()

# Initialize dictionary
new_stats = dict()

# Parse output
for line in lines:
  
  # First check whether it is showing the absolute value of routes
  regMatch = routes_re.match(line)
  if regMatch:
    linebits = regMatch.groupdict()
    os.system( gmetric_cmd + " -t uint32 -n " + metric_prefix + "_routes_imported -u routes -v " + linebits['imported'])
    os.system( gmetric_cmd + " -t uint32 -n " + metric_prefix + "_routes_exported -u routes -v " + linebits['exported'])
    os.system( gmetric_cmd + " -t uint32 -n " + metric_prefix + "_routes_preferred -u routes -v " + linebits['preferred'])

  # Import/Export action counters
  regMatch = updates_re.match(line)
  if regMatch:
    linebits = regMatch.groupdict()
    key = linebits['type'].lower() + "_" + linebits['action'].lower()
    if not key in new_stats:
      new_stats[key] = dict()
    for bit in interesting_bits:
      # Check that it's a number
      if linebits[bit].isdigit():
        new_stats[key][bit] = linebits[bit]
      else:
        new_stats[key][bit] = 0
  
  output = open(old_stats_file, 'wb')
  pickle.dump(new_stats, output)
  output.close()
  
# Get time difference between last poll and new poll

# Make sure we have old stats. Otherwise we can't calculate diffs
if len(old_stats) > 0:
  time_diff = new_time - old_time
  for key in new_stats:
    for subkey in new_stats[key]:
      diff = (int(new_stats[key][subkey]) - int(old_stats[key][subkey])) / time_diff 
      if ( diff >= 0 ):
        os.system( gmetric_cmd + " -t float  -n bird_" + provider_name + "_" + key + "_" + subkey + " -u updates/sec -v " + str(diff))
