#!/usr/local/bin/bash
TOP=/usr/bin/top
AWK=/bin/awk
GMETRIC=/usr/bin/gmetric

$TOP -ibn 1 | $AWK /COMMAND/,/++++++++++/ | head -2 | tail -1 > /tmp/t$$
$GMETRIC --name UserName  --value `$AWK '{print($2)}'  /tmp/t$$`  --type string  --units 'name'
$GMETRIC --name UserProg  --value `$AWK '{print($12)}' /tmp/t$$`  --type string  --units 'name'
$GMETRIC --name UserCPU   --value `$AWK '{print($9)}'  /tmp/t$$`  --type float   --units '%'
$GMETRIC --name UserTime  --value `$AWK '{print($11)}' /tmp/t$$`  --type string  --units 'min:sec'

$GMETRIC --name eth0_out  --value ` grep eth0 /proc/net/dev | awk -F\: '{print($2)}' | awk '{print($9)}' ` --type uint32 --units 'bytes'
$GMETRIC --name eth1_out  --value ` grep eth1 /proc/net/dev | awk -F\: '{print($2)}' | awk '{print($9)}' ` --type uint32 --units 'bytes'


$GMETRIC --name eth0_in  --value ` grep eth0 /proc/net/dev | awk -F\: '{print($2)}' | awk '{print($1)}' ` --type uint32 --units 'bytes'
$GMETRIC --name eth1_in  --value ` grep eth1 /proc/net/dev | awk -F\: '{print($2)}' | awk '{print($1)}' ` --type uint32 --units 'bytes'

$GMETRIC --name SCSI0read --value ` grep 'Total transfers' /proc/scsi/aic7xxx/0 | awk -F\( '{print($2)}' | awk '{print($1)}' ` --type uint32 --units 'qnty'
$GMETRIC --name SCSI0writ --value ` grep 'Total transfers' /proc/scsi/aic7xxx/0 | awk -F\( '{print($2)}' | awk '{print($4)}' ` --type uint32 --units 'qnty'
