#!/usr/bin/perl
#
# Calculate NFS client and server stats and send them to ganglia
# Inspired by Karl Kopper's client stats BASH script from
# http://ganglia.sourceforge.net/gmetric/view.php?id=26
#
# Author: Greg Wimpey, Colorado School of Mines 20 May 2004
# Email:  gwimpey <at> mines <dot> edu
#
# This script may be freely copied, distributed, or modified
# as long as authorship and copyright information is maintained.
# Copyright 2004 Colorado School of Mines
#
$nfsproc='/proc/net/rpc/nfs';
$nfsdproc='/proc/net/rpc/nfsd';
$tmpclient='/tmp/nfsclientstats';
$tmpserver='/tmp/nfsserverstats';
#
# initialize everything in case we can't read it
# (note that by initializing time to 0, we don't get spike on first run)
#
$oldcgetattr=0;
$oldcread=0;
$oldcwrite=0;
$oldctime=0;
$rcgetattr=0.0;
$rcread=0.0;
$rcwrite=0.0;
$nfsqaratio=-1.0;
$oldsgetattr=0;
$oldsread=0;
$oldswrite=0;
$oldstime=0;
$rsgetattr=0.0;
$rsread=0.0;
$rswrite=0.0;
$nfsdqaratio=-1.0;

if ( -r $nfsproc ) { # we are a client

  open NFS,"<$nfsproc" || die "can't open $nfsproc for reading\n";
  $clienttime=time;
  while (<NFS>) {
    if(/^proc3/) { # change here if NFS version != 3
      @newstats=split;
      $clientgetattr=$newstats[3];
      $clientread=$newstats[8];
      $clientwrite=$newstats[9];
    }
  }
  close NFS;

  if ( -r $tmpclient) {
    open CLIENT,"<$tmpclient" || die "can't open $tmpclient for reading\n";
    $junk=<CLIENT> || die "can't read stats from $tmpclient\n";
    @oldstats=split ' ',$junk;
    close CLIENT;
    $oldcgetattr=$oldstats[0];
    $oldcread=$oldstats[1];
    $oldcwrite=$oldstats[2];
    $oldctime=$oldstats[3];
  } 

  open CLIENT,">$tmpclient" || die "can't open $tmpclient for writing\n";
  print CLIENT "$clientgetattr $clientread $clientwrite $clienttime\n";
  close CLIENT;
  $ictime=1.0/($clienttime-$oldctime);
  $rcgetattr=($clientgetattr-$oldcgetattr)*$ictime;
  $rcread=($clientread-$oldcread)*$ictime;
  $rcwrite=($clientwrite-$oldcwrite)*$ictime;
  $nfsqaratio=$rcgetattr != 0 ? ($rcread+$rcwrite)/$rcgetattr : -1.0;
}

if ( -r $nfsdproc ) { # we are a server

  open NFSD,"<$nfsdproc" || die "can't open $nfsdproc for reading\n";
  $servertime=time;
  while (<NFSD>) {
    if(/^proc3/) { # change here if NFSD version != 3
      @newstats=split;
      $servergetattr=$newstats[3];
      $serverread=$newstats[8];
      $serverwrite=$newstats[9];
    }
  }
  close NFSD;

  if ( -r $tmpserver) {
    open SERVER,"<$tmpserver" || die "can't open $tmpserver for reading\n";
    $junk=<SERVER> || die "can't read stats from $tmpserver\n";
    @oldstats=split ' ',$junk;
    close SERVER;
    $oldsgetattr=$oldstats[0];
    $oldsread=$oldstats[1];
    $oldswrite=$oldstats[2];
    $oldstime=$oldstats[3];
  } 

  open SERVER,">$tmpserver" || die "can't open $tmpserver for writing\n";
  print SERVER "$servergetattr $serverread $serverwrite $servertime\n";
  close SERVER;
  $istime=1.0/($servertime-$oldstime);
  $rsgetattr=($servergetattr-$oldsgetattr)*$istime;
  $rsread=($serverread-$oldsread)*$istime;
  $rswrite=($serverwrite-$oldswrite)*$istime;
  $nfsdqaratio=$rsgetattr != 0 ? ($rsread+$rswrite)/$rsgetattr : -1.0;
}

#
# so that all nodes are reporting, we send back defaults even if
# this node is not both client and server
#

system("/usr/bin/gmetric -nnfsgetattr -v$rcgetattr -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfsread -v$rcread -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfswrite -v$rcwrite -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfsqaratio -v$nfsqaratio -tfloat -ucalls");

system("/usr/bin/gmetric -nnfsdgetattr -v$rsgetattr -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfsdread -v$rsread -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfsdwrite -v$rswrite -tfloat -ucalls/sec");
system("/usr/bin/gmetric -nnfsdqaratio -v$nfsdqaratio -tfloat -ucalls");

exit 0;
