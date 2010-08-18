#!/usr/bin/python
###############################################################
# gmetric to monitor mysql replication delay between master and slave
# put this in a cronjob on the slave for every minute or 5 mins or however
# often you desire it to run, be sure to check the parameters
# given below
###############################################################
# REQs: python, gmetric
# DATE: 01 July 2008
# C Viven Rajendra, vivenrajendra@gmail.com
###############################################################
import commands, os

#########################################
# change these to the appropriate values
username = "root"
use_passwd = True # change this to False if you do not use a password to connect
password = "db"
## do not change below two default values unless you have done it on your machine
mcast_channel = '239.2.11.71'
mcast_port = 8649
##########################################


 
# mysql -u root -pdb -e 'show slave status\G' | grep 'Seconds_Behind_Master'
 
## do not touch anything below unless you are sure of what you are doing ##########

if __name__ == "__main__":
    gmetricCommand_usingPassword = "mysql -u " + username + " -p" + password +" -e 'show slave status\G' | grep 'Seconds_Behind_Master'"
    gmetricCommand_withoutPassword = "mysql -u " + username + " -e 'show slave status\G' | grep 'Seconds_Behind_Master'"
    s = None
    o = None
    if use_passwd:
        s,o = commands.getstatusoutput(gmetricCommand_usingPassword)
    else:
        s,o = commands.getstatusoutput(gmetricCommand_withoutPassword)
    print "status", s
    print "output", o
    if o == "" or s!=0 or s==256:
        print "Error : Probabaly, this is not a slave."
    elif s==0:
        o = o.split()
        print o[0]
        print o[1]
        if o[1] == "NULL":
            print "Error : Probabaly, slave cannot connect to master or try 'mysql>start slave'."
        else:
            gangliaMetric = "/usr/bin/gmetric --name=mysql_SecondsBehindMaster --value=" + str(o[1]) + " --type=uint8 --units=seconds --mcast_channel='" + mcast_channel +"' --mcast_port=" + str(mcast_port)
            print gangliaMetric
            res = os.system(gangliaMetric)
