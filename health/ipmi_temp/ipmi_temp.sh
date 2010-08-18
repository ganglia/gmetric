#!/bin/bash

# Sending temperature data to Ganglia via ipmitool sensor readings.
# Any args are passed as extra args to gmetric.

# Dave Love <d.love@liv.ac.uk> / <fx@gnu.org>, 2008-07, public domain

# Can be run from cron, for instance:
#  # The multicast channel is currently different on each cluster,
#  # due to Streamline.  This is for Ganglia 2 config.
#  */5 * * * * root /usr/local/sbin/gmetric-temp -c $(awk '/^mcast_channel / {print $2}' /etc/gmond.conf)

# Avoid sending at the same time as all other nodes (modulo lack of
# synchronization of cron on each host and the slowness of ipmitool,
# which perhaps makes this irrelevant).
sleep $(($RANDOM / 1000))

# Sample output from `ipmitool sdr type Temperature':
# X4100:
#   sys.tempfail     | 03h | ok  | 23.0 | Predictive Failure Deasserted
#   mb.t_amb         | 05h | ok  |  7.0 | 31 degrees C
#   fp.t_amb         | 14h | ok  | 12.0 | 25 degrees C
#   pdb.t_amb        | 1Bh | ok  | 19.0 | 27 degrees C
#   io.t_amb         | 22h | ok  | 15.0 | 26 degrees C
#   p0.t_core        | 29h | ok  |  3.0 | 44 degrees C
#   p1.t_core        | 32h | ok  |  3.1 | 43 degrees C
# X2200:
#   CPU 0 Temp       | 90h | ok  |  3.1 | 44 degrees C
#   CPU 1 Temp       | 91h | ok  |  3.2 | 48 degrees C
#   Ambient Temp0    | 92h | ok  |  7.6 | 33 degrees C
#   Ambient Temp1    | 97h | ok  |  7.6 | 44 degrees C
# Supermicro:
#   CPU 1            | 00h | ok  |  7.1 | 45 degrees C
#   CPU 2            | 01h | ok  |  7.1 | 47 degrees C
#   System           | 02h | ok  |  7.1 | 33 degrees C

ipmitool sdr type Temperature |

  # filter out non-readings, e.g.
  #  CPU 1            | 00h | ns  |  7.1 | No Reading
  grep 'degrees C' |

  # Initially collapsing multiple spaces helps the matching.
  # Then pick out the sensor name and value, separating them with |.
  # Temperatures always seem to be integer, but allow them to be float.
  sed -e 's/  */ /g' \
      -e "s/\([^|][^|]*\) |.* \([0-9.][0-9.]*\) degrees C$/\1|\2/" |

  while IFS='|' read name value; do
      # Ganglia (at least the ancient version we have) doesn't like
      # spaces in names -- substitute underscores.
      gmetric -n ${name// /_} -v $value -t float -u Celsius "$@"
  done
