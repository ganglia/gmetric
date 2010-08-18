#!/usr/bin/python
###############################################################
# gmetric to monitor how long it take for a web page to load textually
# put this in a cronjob for every minute or 5 mins or however often
# you desire it to run, change the url to want to monitor below
###############################################################
# REQs: python, gmetric
# DATE: 01 July 2008
# C Viven Rajendra, vivenrajendra@gmail.com
###############################################################
import time, os, urllib2
import urllib2, gzip, StringIO

#########################################
# change this to the appropriate values
url_to_monitor = "http://www.cse.iitb.ac.in"
## do not change below two default values unless you have done it on your machine
mcast_channel = '239.2.11.71'
mcast_port = 8649
##########################################


def get(uri):
    try:
        request = urllib2.Request(uri)
        request.add_header("Accept-encoding", "gzip")
        usock = urllib2.urlopen(request)
        data = usock.read()
        if usock.headers.get('content-encoding', None) == 'gzip':
            data = gzip.GzipFile(fileobj=StringIO.StringIO(data)).read()
        return data
    except Exception, e:
        print e # your error handling here

def wget_time(urli):
    start_t = time.time()
    get(urli)
    end_t = time.time()
    total_delay = end_t - start_t
    gangliaMetric = "/usr/bin/gmetric --name=wget.index.page --value=" + str(total_delay) + " --type=double --units=seconds --mcast_channel='" + mcast_channel +"' --mcast_port=" + str(mcast_port)"
    res = os.system(gangliaMetric)
    
    
if __name__ == "__main__":
    wget_time(url_to_monitor)
    