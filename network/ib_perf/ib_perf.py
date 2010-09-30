#!/usr/bin/python
import os
import sys
import re
import time
from string import atoi

# Adjust to match your site configuration
PIDFILE = '/var/run/ibstat.py.pid'
PERFQUERY = '/usr/bin/perfquery'
GMETRIC = '/opt/ganglia/lx-x86/bin/gmetric'

r = re.compile('^(RcvBytes|XmtBytes)[^0-9]*([0-9]+)')
rr = re.compile('^(RcvPkts|XmtPkts)[^0-9]*([0-9]+)')

def get_ib_stats():
        global r, rr
        rxbytes = 0
        txbytes = 0
        rxpkts = 0
        txpkts = 0
        p = os.popen(PERFQUERY + " -r", 'r')
        ll = p.readlines()
        p.close()
        for l in ll:
                m = r.match(l)
                if m:
                        if m.groups()[0] == 'RcvBytes':
                                rxbytes = atoi(m.groups()[1])
                        else:
                                txbytes = atoi(m.groups()[1])
                m = rr.match(l)
                if m:
                        if m.groups()[0] == 'RcvPkts':
                                rxpkts = atoi(m.groups()[1])
                        else:
                                txpkts = atoi(m.groups()[1])
        return (rxbytes, txbytes, rxpkts, txpkts)

def main():
        oldtime = time.time()
        bytes = get_ib_stats()
        rbytes = 0
        tbytes = 0
        rpkts = 0
        tpkts = 0
        while True:
                time.sleep(1)
                newtime = time.time()
                bytes = get_ib_stats()
                rbytes += bytes[0]
                tbytes += bytes[1]
                rpkts += bytes[2]
                tpkts += bytes[3]
                # 20 seconds averaging. Adjust if necessary.
                if (newtime - oldtime) >= 20.0:
                        os.spawnl(os.P_WAIT, GMETRIC, 'gmetric',
                                '--name=ib_bytes_in',
                                '--value=%f' % (rbytes/(newtime - oldtime)),
                                '--type=float',
                                '--units=bytes/sec')
                        os.spawnl(os.P_WAIT, GMETRIC, 'gmetric',
                                '--name=ib_bytes_out',
                                '--value=%f' % (tbytes/(newtime - oldtime)),
                                '--type=float',
                                '--units=bytes/sec')
                        os.spawnl(os.P_WAIT, GMETRIC, 'gmetric',
                                '--name=ib_pkts_in',
                                '--value=%f' % (rpkts/(newtime - oldtime)),
                                '--type=float',
                                '--units=packets/sec')
                        os.spawnl(os.P_WAIT, GMETRIC, 'gmetric',
                                '--name=ib_pkts_out',
                                '--value=%f' % (tpkts/(newtime - oldtime)),
                                '--type=float',
                                '--units=packets/sec')
                        oldtime = newtime
                        rbytes = tbytes = 0
                        rpkts = tpkts = 0

# Double-fork daemonization
if __name__ == "__main__":
        try:
                pid = os.fork()
                if pid > 0:
                        sys.exit(0)
        except OSError, e:
                print >>sys.stderr, "fork #1 failed: %d (%s)" % (e.errno, e.strerror)
                sys.exit(1)

        os.chdir("/")
        os.setsid()
        os.umask(0)

        try:
                pid = os.fork()
                if pid > 0:
                        open(PIDFILE, 'w').write("%d" % pid)
                        sys.exit(0)
        except OSError, e:
                print >>sys.stderr, "fork #2 failed: %d (%s)" % (e.errno, e.strerror)

        main()
