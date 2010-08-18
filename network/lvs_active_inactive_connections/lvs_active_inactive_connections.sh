#!/bin/bash
# Frank Zwart frank.kanariepietje.nl
# Script detects VIP\\\'s in use and collects active/inactive connections


`cat /proc/net/ip_vs >  /tmp/ganglia_ipvs_tmp`
echo \\\"TCP\\\" >> /tmp/ganglia_ipvs_tmp

ACTIVE_CONNECTIONS=0
INACTIVE_CONNECTIONS=0

while read VAL1 VAL2 VAL3 VAL4 VAL5 VAL6 VAL7; do

    if [ \\\"${VAL1}\\\" = \\\"TCP\\\" ] ; then
    if [[ ${PREVIOUS_WAS_REALSERVER} = \\\"YES\\\" ]] && [[ ${SERVICE} != \\\"\\\" ]];then
          H1=`echo ${SERVICE} | cut -b1-4`
      H2=`echo ${SERVICE} | cut -b5-8`
          H3=`echo ${SERVICE} | cut -b10-13`
      SERVICE=`printf \\\"VIP_%d.%d.%d.%d_port_%d\\\" 0x${H1%??} 0x${H1#??} 0x${H2%??} 0x${H2#??} 0x${H3}`
      /usr/bin/gmetric --type uint32 --units ActiveConnections --name ${SERVICE}-Active --value ${ACTIVE_CONNECTIONS}
      /usr/bin/gmetric --type uint32 --units InactiveConnections --name ${SERVICE}-Inactive --value ${INACTIVE_CONNECTIONS}
      ACTIVE_CONNECTIONS=0
      INACTIVE_CONNECTIONS=0
    fi
    SERVICE=${VAL2}
        PROTOCOL=${VAL1}
    elif [ \\\"${VAL3}\\\" = \\\"Route\\\"  ]; then
        ACTIVE_CONNECTIONS=`expr ${ACTIVE_CONNECTIONS} + ${VAL5}`
        INACTIVE_CONNECTIONS=`expr ${INACTIVE_CONNECTIONS} + ${VAL6}`
        PREVIOUS_WAS_REALSERVER=\\\"YES\\\"
    fi
done < /tmp/ganglia_ipvs_tmp