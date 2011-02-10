#!/bin/bash

# Script to collect stats about NVidia GPUs
# Written for 2 GPUs per machine
# Reports cpu usage, mem usage, temp, fan speed, and number of processes using the GPUs

# Variables 
# Set the variables we are collecting
#
GMETRIC="/usr/bin/gmetric"

# GPU Usage for card 0 and 1
GPU_USAGE_0=$(nvidia-smi -q -g 0 |egrep "GPU.[^0].*\:" |awk {' print $3 '} |sed s/%//g)
GPU_USAGE_1=$(nvidia-smi -q -g 1 |egrep "GPU.[^0].*\:" |awk {' print $3 '} |sed s/%//g)
MEM_USAGE_0=$(nvidia-smi -q -g 0 |egrep "Mem" |awk {' print $3 '} |sed s/%//g)
MEM_USAGE_1=$(nvidia-smi -q -g 1 |egrep "Mem" |awk {' print $3 '} |sed s/%//g)
TEMP_0=$(nvidia-smi -q -g 0 |egrep "Temp" |awk {' print $3 '} |sed s/%//g)
TEMP_1=$(nvidia-smi -q -g 1 |egrep "Temp" |awk {' print $3 '} |sed s/%//g)
FAN_0=$(nvidia-smi -q -g 0 |egrep "Fan" |awk {' print $4 '} |sed s/%//g)
FAN_1=$(nvidia-smi -q -g 1 |egrep "Fan" |awk {' print $4 '} |sed s/%//g)
NPROC_0=$(/usr/sbin/lsof /dev/nvidia0|awk {' print $2 '} | grep -v PID|sort -u |wc -l)
NPROC_1=$(/usr/sbin/lsof /dev/nvidia1|awk {' print $2 '} | grep -v PID|sort -u |wc -l)


$GMETRIC -n GPU_USAGE_0 -v $GPU_USAGE_0  -t uint16 -u '%' 
$GMETRIC -n GPU_USAGE_1 -v $GPU_USAGE_1  -t uint16 -u '%' 
$GMETRIC -n MEM_USAGE_0 -v $GPU_USAGE_0  -t uint16 -u '%' 
$GMETRIC -n MEM_USAGE_1 -v $GPU_USAGE_1  -t uint16 -u '%' 
$GMETRIC -n TEMP_GPU_0 -v $TEMP_0  -t uint16 -u Celcius 
$GMETRIC -n TEMP_GPU_1 -v $TEMP_1  -t uint16 -u Celcius 
$GMETRIC -n FAN_GPU_0 -v $FAN_0  -t uint16 -u '%'
$GMETRIC -n FAN_GPU_1 -v $FAN_1  -t uint16 -u '%'
$GMETRIC -n Num_Procs_GPU_0 -v $NPROC_0 -t uint16 -u Procs
$GMETRIC -n Num_Procs_GPU_1 -v $NPROC_1 -t uint16 -u Procs
