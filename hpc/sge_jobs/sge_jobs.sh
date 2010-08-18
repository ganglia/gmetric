#!/bin/bash

#adjust for the local environment
source /usr/local/sge/default/common/settings.sh

qstat | awk '
        BEGIN { pending=running=error=0; }
        /^[ 1-9][0-9]/ && ($5 ~ /^qw/)   { pending++; }
        /^[ 1-9][0-9]/ && ($5 ~ /[rRt]/) { running++; }
        /^[ 1-9][0-9]/ && ($5 ~ /E/ )    { error++;   }
    END {
                cmd="/usr/bin/gmetric --name sge_pending --value "pending" --type uint16";
                system(cmd);
                cmd="/usr/bin/gmetric --name sge_running --value "running" --type uint16";
                system(cmd);
                cmd="/usr/bin/gmetric --name sge_error   --value "error" --type uint16";
                system(cmd);
                #print "Pending="pending" Running="running" Errors="error;
        }'


exit

#######################################################################


QP=`grep ' qw ' /tmp/qstat.$$ | wc -l`
if [ $QP -ge 3 ]; then
        QP=$(($QP-2))
fi
/usr/bin/gmetric --name sge_pending --value $QP --type uint16

QP=`grep ' [rRt] ' /tmp/qstat.$$ | wc -l`
if [ $QP -ge 3 ]; then
        QP=$(($QP-2))
fi
/usr/bin/gmetric --name sge_running --value $QP --type uint16

QP=`grep ' E ' /tmp/qstat.$$ | wc -l`
if [ $QP -ge 3 ]; then
        QP=$(($QP-2))
fi
/usr/bin/gmetric --name sge_error --value $QP --type uint16

