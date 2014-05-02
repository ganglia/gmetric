#!/usr/bin/env python

######################################################################
# Uses eAPI
#
# Run it with daemonize /persist/sys/ganglia_arista_interfaces.py
#  --username - sets the eAPI username to use
#  --password - sets the eAPI password to use
#  --protocol [http | https] - sets the protocol to use
#
# Alternatively run it at boot with
#
# daemon ganglia_interfaces
#   command /persist/sys/ganglia_arista_interfaces.py
######################################################################
import time, socket, json
import sys, os, copy
import argparse
import urlparse

import jsonrpclib

METRICS = {
    'time' : 0,
    'data' : {}
}

LAST_METRICS = dict(METRICS)

gmetric_cmd = "/usr/bin/gmetric -d 240 -g arista -c /persist/sys/gmond.conf  ";

counters = dict()

def make_url(host, uid, pwd, proto, port):
  if proto not in ['http', 'https']:
    raise ValueError('invalid protocol specified')

  if proto == 'http' and not port:
    port = 80
  elif proto == 'https' and not port:
    port = 443

  if int(port) < 1 or port > 65535:
    raise ValueError('port value is out of range')

  scheme = proto
  netloc = '%s:%s@%s:%s' % (uid, pwd, host, port)
  path = '/command-api'

  return urlparse.urlunsplit((scheme, netloc, path, None, None))

def make_connection(url):
  return jsonrpclib.Server(url)

def run_command(connection, commands):
  assert isinstance(commands, list)
  return connection.runCmds(1, commands)

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

####################################################################
# Daemonize
####################################################################
def start(connection):
  while 1:

    start_fetch = time.time()
    new_time = time.time()

    data = run_command(connection, ['show interfaces'])
    new_metrics = dict()

    # Loop through any know interfaces
    for key, value in data[0]['interfaces'].items():
      if value['lineProtocolStatus'] == 'up':
        counters = value['interfaceCounters']
        new_metrics[str(key)] = dict()
        new_metrics[str(key)]['pkts_out'] = format_number(counters['outUcastPkts'])
        new_metrics[str(key)]['mcast_out'] = format_number(counters['outMulticastPkts'])
        new_metrics[str(key)]['bcast_out'] = format_number(counters['outBroadcastPkts'])
        new_metrics[str(key)]['pkts_in'] = format_number(counters['inUcastPkts'])
        new_metrics[str(key)]['mcast_in'] = format_number(counters['inMulticastPkts'])
        new_metrics[str(key)]['bcast_in'] = format_number(counters['inBroadcastPkts'])
        new_metrics[str(key)]['bytes_out'] = format_number(counters['outOctets'])
        new_metrics[str(key)]['bytes_in'] = format_number(counters['inOctets'])
        new_metrics[str(key)]['in_discards'] = format_number(counters['inDiscards'])
        new_metrics[str(key)]['in_errors'] = format_number(counters['totalInErrors'])
        new_metrics[str(key)]['out_discards'] = format_number(counters['outDiscards'])
        new_metrics[str(key)]['out_errors'] = format_number(counters['totalOutErrors'])

    end_fetch = time.time()

    fetch_time = end_fetch - start_fetch

    # Emit metrics
    global LAST_METRICS
    if LAST_METRICS['time'] != 0:
      time_diff = new_time - LAST_METRICS['time']
      for ifname in new_metrics:
        ifname_pretty = ifname.replace("Ethernet", "et").replace("Management", "ma").replace("Vlan", "vlan")

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

def main():
  parser = argparse.ArgumentParser()

  parser.add_argument('--username', '-u',
                      default='eapi',
                      help='Specifies the eAPI username')

  parser.add_argument('--password', '-p',
                      default='password',
                      help='Specifies the eAPI password')

  parser.add_argument('--hostname',
                      default='localhost',
                      help='Specifies the hostname of the EOS node')

  parser.add_argument('--protocol',
                      default='https',
                      choices=['http', 'https'],
                      help='Specifies the protocol to use (default=https)')

  parser.add_argument('--port',
                      default=0,
                      type=int,
                      help='Specifies the port to use (default=443)')

  args = parser.parse_args()

  url = make_url(args.hostname, args.username, args.password,
                 args.protocol, args.port)

  try:
    connection = make_connection(url)
    start(connection)
  except KeyboardInterrupt:
    parser.exit()
  except Exception as exc:
    parser.error(exc)

if __name__ == '__main__':
  main()
