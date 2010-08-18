#!/bin/bash
# Author Sumanth J.V (sumanth@cse.unl.edu)
# Date 17-June-2002

# Ensure that top, seq, sed , awk are in ur path
# Also check if this is the right location of gmetric
GMETRIC=/usr/bin/gmetric

list=(`
        top -b -n 1 |\
        sed -n -e "11,15p" |\
        awk '{print $12, $2, $9, $10, $11}'
`)

for i in `seq 0 5 24`
do
        let id=id+1

        val="Proc:${list[${i}]}_User:${list[$((${i}+1))]}\
        _CPU:${list[$((${i}+2))]}_Mem:${list[$((${i}+3))]}\
        _Time:${list[$((${i}+4))]}"

        $GMETRIC --name "Resource_Usage_Rank ${id}" \
        --value $val --type string --units ' '
done

exit 0
