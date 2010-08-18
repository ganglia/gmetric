
#!/bin/sh

CLIENT="/usr/bin/gmetric"

TCP=(`egrep TCP /proc/net/sockstat`)

inuse=${TCP[2]}
orphan=${TCP[4]}
time_wait=${TCP[6]}
alloc=${TCP[8]}
mem=${TCP[10]}

let "established=$inuse-$orphan"

$CLIENT -t uint16 -n tcp_established -v $established
exec $CLIENT -t uint16 -n tcp_time_wait -v $time_wait
