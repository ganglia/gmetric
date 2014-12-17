#!/usr/bin/env python

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Targeting python2.6 for RHEL6 compatibility

import collections
import optparse
import logging
import subprocess
import sys

# Numeric for easy > 0 or == 0 numeric checks
ZPOOL_HEALTH = {
    'ONLINE': 0,
    'DEGRADED': 1,
    'FAULTED': 2,
    'OFFLINE': 3,
    'REMOVED': 4,
    'UNAVAIL': 5
    }

METRIC = collections.namedtuple('Metric', ['name', 'value', 'type', 'desc'])


# Backported check_output from 2.6
# From: https://gist.github.com/edufelipe/1027906
def check_output(*popenargs, **kwargs):
    r"""Run command with arguments and return its output as a byte string.

    Backported from Python 2.7 as it's implemented as pure python on stdlib.

    >>> check_output(['/usr/bin/python', '--version'])
    Python 2.6.2
    """
    process = subprocess.Popen(stdout=subprocess.PIPE, *popenargs, **kwargs)
    output, unused_err = process.communicate()
    retcode = process.poll()
    if retcode:
        cmd = kwargs.get("args")
        if cmd is None:
            cmd = popenargs[0]
        error = subprocess.CalledProcessError(retcode, cmd)
        error.output = output
        raise error
    return output


def send_metric(metric, dry_run=False):
    group = 'zpool'
    cmd = ('/usr/bin/gmetric --name=%s --value=%s --type=%s --group=%s --tmax=90 --dmax=600 --desc="%s"' %
           (metric.name, str(metric.value), metric.type, group, metric.desc))
    log.debug('Running cmd: %s' % cmd)
    if dry_run is False:
        try:
            subprocess.check_call(cmd, shell=True)
        except subprocess.CalledProcessError as e:
            log.warn('gmetric sending failed with %i, cmd was: %s' % (e.returncode, cmd))


def zpool_list():
    """ Get the list of all zpools.  Capture capacity & health along
    the way. """
    out = check_output(['zpool', 'list'])
    lines = out.splitlines()
    del lines[0]
    zpools = []
    # NAME   SIZE  ALLOC   FREE    CAP  DEDUP  HEALTH  ALTROOT
    for line in lines:
        columns = map(lambda s: s.strip(), line.split())
        zpool = {}
        zpool['name'] = columns[0]
        zpool['capacity'] = float(columns[4].strip('%'))
        health_s = columns[6]
        if health_s in ZPOOL_HEALTH:
            zpool['health'] = ZPOOL_HEALTH[health_s]
        else:
            zpool['health'] = 100
        zpools.append(zpool)
    return zpools


def zpool_find_errors(pool_name):
    """ There is no property that corresponds cleanly to the errors
    output line from `zpool status`.  Instead the full status command
    is run and anything other than 'no errors' is considered bad. """
    out = check_output(['zpool', 'status', pool_name])
    has_errors = 1
    for line in out.splitlines():
        if 'errors:' in line:
            msg = line.split('errors:')[1].strip()
            if msg == 'No known data errors':
                has_errors = 0
                break
    return has_errors


def make_metrics(zpool, has_errors):
    metrics = []
    metrics.append(METRIC('zpool.%s.capacity' % zpool['name'],
                          zpool['capacity'], 'double',
                          'Percentage of pool space used.'))
    metrics.append(METRIC('zpool.%s.health' % zpool['name'],
                          zpool['health'], 'uint8',
                          'The current health of the pool'))
    metrics.append(METRIC('zpool.%s.errors' % zpool['name'],
                          has_errors, 'uint8',
                          'non-zero indicates errors'))
    return metrics


#### Main and Friends

def setup_logging(level):
    global log

    log = logging.getLogger('zpool-status')
    formatter = logging.Formatter(' | '.join(['%(asctime)s', '%(name)s',
                                              '%(levelname)s', '%(message)s']))
    ch = logging.StreamHandler()
    ch.setFormatter(formatter)
    log.addHandler(ch)
    lmap = {
        'CRITICAL': logging.CRITICAL,
        'ERROR': logging.ERROR,
        'WARNING': logging.WARNING,
        'INFO': logging.INFO,
        'DEBUG': logging.DEBUG,
        'NOTSET': logging.NOTSET
        }
    log.setLevel(lmap[level])


def parse_args(argv):
    parser = optparse.OptionParser()
    parser.add_option('--log-level',
                      action='store', dest='log_level', default='WARNING',
                      choices=['CRITICAL', 'ERROR', 'WARNING', 'INFO',
                               'DEBUG', 'NOTSET'])
    parser.add_option('--dry-run',
                      action='store_true', dest='dry_run', default=False,
                      help='actually send data via gmetric')
    return parser.parse_args(argv)


def main(argv):
    (opts, args) = parse_args(argv)
    setup_logging(opts.log_level)
    zpools = zpool_list()
    metrics = []
    for zpool in zpools:
        has_errors = zpool_find_errors(zpool['name'])
        metrics.extend(make_metrics(zpool, has_errors))
    for metric in metrics:
        send_metric(metric, dry_run=opts.dry_run)


if __name__ == '__main__':
    main(sys.argv[1:])
