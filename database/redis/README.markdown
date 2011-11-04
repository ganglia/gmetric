Redis gmetric
=============

Sends redis metric using gmetric.
Requires ganglia > 3.1.X where --slope=positive will create a COUNTER data source type.

Usage
-----
`
redis_gmetric.rb [-h <host]> [-p <port>] [test]
`

If 'test' is there (or any other string), just print the commands, do not execute.

Commands send
--------------
`
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=redis_clients --type=int32 --units=clients --value=2 --slope=both --dmax=600
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=redis_used_memory --type=int32 --units=bytes --value=20434336 --slope=both --dmax=600
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=redis_connections --type=int32 --units=Conn/s --value=178842 --slope=positive --dmax=600
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name=redis_commands --type=int32 --units=Cmds/s --value=79281489 --slope=positive --dmax=600
`
