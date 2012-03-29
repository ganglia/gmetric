Netapp metrics gathering script
===============================

Principle of operation
===============================

This script uses snmpwalk to fetch OID of interest from a Netapp server then 
injects those metrics into Ganglia. This script will use Ganglia's Spoof 
functionality to create "Netapp" hosts in Ganglia. 


Install
=======

To use modify the ganglia_netapp.php script. You will need to change following
variables in the script. 

    $servers= array("serv1","serv2");

This is a list of all the Netapp servers you have

    $community = "public";

This is your SNMP community string.

Graph reports
===============================

If you want report graphs like e.g. network traffic drop the *.json files in this
directory in $GANGLIA_WEB_HOME/graph.d e.g. /var/www/html/ganglia/graph.d
