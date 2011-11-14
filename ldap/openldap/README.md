This script allows you to connect OpenLDAP metrics. It has been contributed
by engineering team at Etsy. To use 

Add following to slapd.conf

database    monitor

access to dn="cn=monitor"
   by * read

Then run gmetric_ldap.py script periodically.
