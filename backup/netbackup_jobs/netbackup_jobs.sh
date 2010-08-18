#!/bin/bash

###  Author: Jordi Prats Catala - CESCA - 2007
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

ACTIVE=`/usr/openv/netbackup/bin/admincmd/bpdbjobs -noheader | grep Active | wc -l`
QUEUE=`/usr/openv/netbackup/bin/admincmd/bpdbjobs -noheader | grep -i Queued | wc -l`

VALUEACTIVE=${ACTIVE## * }
/usr/bin/gmetric -t uint16 -n NB_active_jobs -v$VALUEACTIVE -u '#'

VALUEQUEUE=${QUEUE## * }
/usr/bin/gmetric -t uint16 -n NB_queued_jobs -v$VALUEQUEUE -u '#'
