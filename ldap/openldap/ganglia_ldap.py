#!/usr/bin/python

import ldap
import pickle
import os
import sys
import time


def load_stats(stats_file):
    old_stats = None
    if os.path.exists(stats_file):
        try:
            fh = open(stats_file, 'r')
            old_stats = pickle.load(fh)
            fh.close()
        except EOFError:
            old_stats = None
    return old_stats

def save_stats(old_stats, stats_file):
    fh = open(stats_file, 'w')
    pickle.dump(old_stats, fh)
    fh.close()

def main():
    ldap_server = 'localhost'
    ldap_port = '389'
    stats_file = '/tmp/gmetric-ldap.txt'
    gmetric = '/usr/bin/gmetric'
    old_stats = load_stats(stats_file)

    stats = {'Total_Connections': {'base': 'cn=Bytes,cn=Statistics,cn=Monitor', 'attr': 'monitorCounter'},
             'Bytes_Sent': {'base': 'cn=Operations,cn=Monitor', 'attr': 'monitorOpInitiated'},
             'Initiated_Operations': {'base': 'cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Completed_Operations': {'base': 'cn=Referrals,cn=Statistics,cn=Monitor', 'attr': 'monitorCounter'},
             'Referrals_Sent': {'base': 'cn=Entries,cn=Statistics,cn=Monitor', 'attr': 'monitorCounter'},
             'Entries_Sent': {'base': 'cn=Bind,cn=Operations,cn=Monitor', 'attr': 'monitorOpInitiated'},
             'Bind_Operations': {'base': 'cn=Bind,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Unbind_Operations': {'base': 'cn=Unbind,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Add_Operations': {'base': 'cn=Add,cn=Operations,cn=Monitor', 'attr': 'monitorOpInitiated'},
             'Delete_Operations': {'base': 'cn=Delete,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Modify_Operations': {'base': 'cn=Modify,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Compare_Operations': {'base': 'cn=Compare,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Search_Operations': {'base': 'cn=Search,cn=Operations,cn=Monitor', 'attr': 'monitorOpCompleted'},
             'Write_Waiters': {'base': 'cn=Write,cn=Waiters,cn=Monitor', 'attr': 'monitorCounter'},
             'Read_Waiters': {'base': 'cn=Read,cn=Waiters,cn=Monitor', 'attr': 'monitorCounter'}
            }

    # Poll ldap, update the stats
    conn = ldap.initialize('ldap://%s' % ldap_server)
    conn.start_tls_s()
    conn.simple_bind_s()
    for key in stats.keys():
        attr = stats[key]['attr']
        num = conn.search(stats[key]['base'],
                          ldap.SCOPE_BASE,
                          'objectClass=*',
                          [attr])
        try:
            result_type, result_data = conn.result(num, 0)
            stats[key]['value'] = int(result_data[0][1][attr][0])
        except:
            print sys.exc_info()
            stats[key]['value'] = -1
    # Add the timestamp to the stats, so we know when they were gathered
    stats['Timestamp'] = int(time.time())

    # Save these stats for the future
    save_stats(stats, stats_file)

    # If old_stats didn't return something earlier, quit now. We'll pick things
    # up on the next run when we have something to compare the current values
    # to.
    if not old_stats:
        sys.exit()

    # Now we do calculations to get the values per second, and send them to
    # gmetric
    timediff = stats['Timestamp'] - old_stats['Timestamp']
    for key in stats.keys():
      if key == 'Timestamp':
          continue
      rate = (stats[key]['value'] - old_stats[key]['value']) / timediff
      print '%s -u "per sec" -tfloat -n %s -v %s' % (gmetric, key, rate)
      os.system('%s -u "per sec" -tfloat -n %s -v %s' % (gmetric, key, rate))


if __name__ == '__main__':
    main()