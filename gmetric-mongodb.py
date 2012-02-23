#!/usr/bin/python
# vim: set ts=4 sw=4 et :

from subprocess import Popen
import sys, os, urllib2, time

try:
    import json
except ImportError:
    import simplejson as json

hasPyMongo = None
try:
    import pymongo
    hasPyMongo = True
except ImportError:
    hasPyMongo = False

GMETRIC = "/usr/bin/gmetric --name=\"%s\" --value=\"%s\" --type=\"%s\" --units=\"%s\""

class ServerStatus:
    ops_tmp_file = os.path.join("/", "tmp", "mongo-prevops")

    def __init__(self):
        self.status = self.getServerStatus()
        # call individual metrics
        for f in ["conns", "btree", "mem", "backgroundFlushing", "repl", "ops", "lock"]:
            getattr(self, f)()

        if (hasPyMongo):
            self.stats = self.getStats()
            self.writeStats()

    def getServerStatus(self):
        raw = urllib2.urlopen("http://localhost:28017/_status").read()
        return json.loads(raw)["serverStatus"]

    def getStats(self):
        c = pymongo.Connection("localhost:27017", slave_okay=True)
        stats = []

        for dbName in c.database_names():
            db = c[dbName]
            dbStats = db.command("dbstats")
            if dbStats["objects"] == 0:
                continue
            stats.append(dbStats)

        c.disconnect()
        return stats

    def writeStats(self):
        keys = { "numExtents":"extents", "objects":"objects",
                 "fileSize": "bytes", "dataSize": "bytes", "indexSize": "bytes", "storageSize": "bytes" }

        totals = {}
        for k in keys.keys():
            totals[k] = 0

        for status in self.stats:
            dbName = status["db"]

            for k, v in keys.iteritems():
                value = status[k]
                self.callGmetric({dbName + "_" + k: (value, v)})
                totals[k] += value

        for k, v in keys.iteritems():
            self.callGmetric({"total_" + k: (totals[k], v)})

        self.callGmetric({"total_dataAndIndexSize" : (totals["dataSize"]+totals["indexSize"], "bytes")})

    def callGmetric(self, d):
        for k, v in d.iteritems():
            unit = None
            if (isinstance(v[0], int)):
                unit = "int32"
            elif (isinstance(v[0], float)):
                unit = "double"
            else:
                raise RuntimeError(str(v[0].__class__) + " unknown (key: " + k + ")")

            cmd = GMETRIC % ("mongodb_" + k, v[0], unit, v[1])
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

    def backgroundFlushing(self):
        f = self.status["backgroundFlushing"]
        self.callGmetric({
            "flush_average" : (f["average_ms"], "ms"),
        })

    def ops(self):
        out = {}
        cur_ops = self.status["opcounters"]

        lastChange = None
        try:
            os.stat_float_times(True)
            lastChange = os.stat(self.ops_tmp_file).st_ctime
            with open(self.ops_tmp_file, "r") as f:
                content = f.read()
                prev_ops = json.loads(content)
        except (ValueError, IOError):
            prev_ops = {}

        for k, v in cur_ops.iteritems():
            if k in prev_ops:
                name = k + "s_per_second"
                if k == "query":
                    name = "queries_per_second"

                interval = time.time() - lastChange
                if (interval <= 0.0):
                    continue
                out[name] = (max(0, float(v) - float(prev_ops[k])) / interval, "ops/s")

        with open(self.ops_tmp_file, 'w') as f:
            f.write(json.dumps(cur_ops))

        self.callGmetric(out)

    def repl(self):
        ismaster = 0;
        if (self.status["repl"]["ismaster"]):
            ismaster = 1

        self.callGmetric({
            "is_master" : (ismaster, "boolean")
        })

    def lock(self):
        self.callGmetric({
            "lock_ratio" : (self.status["globalLock"]["ratio"], "ratio"),
            "lock_queue_readers" : (self.status["globalLock"]["currentQueue"]["readers"], "queue size"),
            "lock_queue_writers" : (self.status["globalLock"]["currentQueue"]["writers"], "queue size"),
        })

if __name__ == "__main__":
    ServerStatus()
