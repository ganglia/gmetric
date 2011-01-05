#!/bin/bash

squeue | awk '
        BEGIN { pending=running=error=0; }
        ($5 ~ /^PD/)   { pending++; }
        ($5 ~ /[rRt]/) { running++; }
        ($5 ~ /E/ )    { error++;   }
    END {
                cmd="/usr/bin/gmetric --name slurmq_pending --value "pending" --type uint16";
                system(cmd);
                cmd="/usr/bin/gmetric --name slurmq_running --value "running" --type uint16";
                system(cmd);
                cmd="/usr/bin/gmetric --name slurmq_error   --value "error" --type uint16";
                system(cmd);
                #print "Pending="pending" Running="running" Errors="error;
        }'


exit

