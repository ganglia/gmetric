#!/usr/bin/python
# vim: set ts=4 sw=4 et :

from subprocess import Popen
import sys, os, urllib2

try:
    import json
except ImportError:
    import simplejson as json

GMETRIC = "/usr/bin/gmetric --name=\"%s\" --value=\"%s\" --type=\"int32\" --units=\"%s\""

class ServerStatus:
    ops_tmp_file = os.path.join("/", "tmp", "mongo-prevops")

    def __init__(self):
        self.status = self.getServerStatus()
        # call individual metrics
        for f in ["conns", "btree", "mem", "repl", "ops", "lock"]:
            getattr(self,f)()

    def getServerStatus(self):
        raw = urllib2.urlopen( "http://127.0.0.1:28017/_status" ).read()
        return json.loads( raw )["serverStatus"]

    def callGmetric(self, d):
        for k,v in d.iteritems():
            cmd = GMETRIC % ("mongodb_" + k, v[0], v[1])
            Popen(cmd, shell=True)

    def conns(self):
        ss = self.status
        self.callGmetric({
            "connections" : (ss["connections"]["current"], "connections")
        })

    def btree(self):
        b = self.status["indexCounters"]["btree"]
        self.callGmetric({
            "btree_accesses" : (b["accesses"], "count"),
            "btree_hits" : (b["hits"], "count"),
            "btree_misses" : (b["misses"], "count"),
            "btree_resets" : (b["resets"], "count"),
            "btree_miss_ratio" : (b["missRatio"], "ratio"),
        })

    def mem(self):
        m = self.status["mem"]
        self.callGmetric({
            "mem_resident" : (m["resident"], "MB"),
            "mem_virtual" : (m["virtual"], "MB"),
            "mem_mapped" : (m["mapped"], "MB"),
        })

    def ops(self):
        out = {}
        cur_ops = self.status["opcounters"]
        try:
            f = open(self.ops_tmp_file, "r")
            content = f.read()
            prev_ops = json.loads(content)
            f.close()
        except (ValueError, IOError):
            prev_ops = {}

        for k,v in cur_ops.iteritems():
            if k in prev_ops:
                name = k + "s_per_second"
                if k == "query":
                    name = "queries_per_second"
                out[name] = ((float(v) - float(prev_ops[k]) ) / 60, "ops/s")

        f = open(self.ops_tmp_file, 'w')
        try:
            f.write(json.dumps(cur_ops))
        finally:
            f.close()

        self.callGmetric(out)

    def repl(self):
        self.callGmetric({
            "is_master" : (self.status["repl"]["ismaster"], "boolean")
        })

    def lock(self):
        self.callGmetric({
            "lock_ratio" : (self.status["globalLock"]["ratio"], "ratio")
        })

if __name__ == "__main__":
    ServerStatus()
