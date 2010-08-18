#!/bin/bash
#
# Linux NFS Client statistics
#
# Report number of NFS client read, write and getattr calls since we were last called.
#
# (Use utility "nfsstat -c" to look at the same thing).
#
# Note: Uses temp files in /tmp
#

# GETATTR
if [ -f /tmp/nfsclientgetattr ]; then
        thisnfsgetattr=`cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$4}'`
        lastnfsgetattr=`cat /tmp/nfsclientgetattr`
        let "deltagetattr = thisnfsgetattr - lastnfsgetattr"
        # echo "delta getattr $deltagetattr"
        /usr/bin/gmetric -nnfsgetattr -v$deltagetattr -tuint16 -ucalls
fi

# READ
if [ -f /tmp/nfsclientread ]; then
        thisnfsread=`cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$9}'`
        lastnfsread=`cat /tmp/nfsclientread`
        let "deltaread = thisnfsread - lastnfsread"
        # echo "delta read $deltaread"
        /usr/bin/gmetric -nnfsread -v$deltaread -tuint16 -ucalls
fi

# WRITE
if [ -f /tmp/nfsclientwrite ]; then
        thisnfswrite=`cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$10}
'`
        lastnfswrite=`cat /tmp/nfsclientwrite`
        let "deltawrite = thisnfswrite - lastnfswrite"
        # echo "delta write $deltawrite"
        /usr/bin/gmetric -nnfswrite -v$deltawrite -tuint16 -ucalls
fi

# NFS Quality Assurance RATIO (nfsqaratio)
# If this value shrinks too much then perhaps an application
# program change introduced excessive GETATTR calls into production.
if [ "$deltagetattr" -ne 0 ];then
         let "nfsqaratio = (deltaread + deltawrite) / deltagetattr"
         /usr/bin/gmetric -nnfsqaratio -v$nfsqaratio -tuint16 -ucalls
fi


# Update the old values on disk for the next time around. (We ignore
# the fact that they have probably already changed while we made this
# calculation).
cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$9}'  > /tmp/nfsclientread
cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$10}' > /tmp/nfsclientwrite
cat /proc/net/rpc/nfs | tail -1 | awk '{printf "%s\n",$4}'  > /tmp/nfsclientgetattr