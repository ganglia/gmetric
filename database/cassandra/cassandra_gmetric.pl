#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use strict;

my(%opts);
my(@opts)=('period=i',
	   'nocsv|N', # warning, this could fork hundreds of times
	   'debug|d',
	   'nodetool|n=s',
    );

$opts{period} ||= 60;
$opts{nodetool} ||= '/usr/bin/nodetool';
my($t)=time;

my $gmetric="/usr/bin/gmetric";

die unless GetOptions(\%opts,@opts);
my($s)={};

for my $i (0..1){
    my($cfstats) = scalar(`$opts{nodetool} -h localhost cfstats`);
    for my $ks ($cfstats =~ /Keyspace: (.*?)----------------/smog){
	my($ksname) = $ks =~ /^(.*?)$/smo;
	#print "$ksname ---\n";
	my(@ksv) = $ks =~ /^\t([^\t].*?): (.*?)$/smog;
	while(scalar(@ksv)){
	    my($n, $v) = (shift(@ksv), shift(@ksv));
	    $v =~ s/ ms.//;
	    next if($v eq 'NaN');
	    $n =~ s/([^a-zA-Z0-9-]+)/_/smog;
	    $n =~ s/(_+)/_/smog;
	    $n =~ s/^(_)//smo;
	    $n =~ s/(_)$//smo;
	    $s->{"ksstats__${ksname}__$n"}[$i] = $v;
	    #print "ksstats__${ksname}__$n,$v,float,,,,,,\n"
	}
	for my $cf ($ks =~ /Column Family: (.*?)\n\n/smog){
	    my($cfname) = $cf =~ /^(.*?)$/smo;
	    my(@cfv) = $cf =~ /^\t\t([^\t].*?): (.*?)$/smog;
	    while(scalar(@cfv)){
		my($n, $v) = (shift(@cfv), shift(@cfv));
		$v =~ s/ ms.//;
		next if($v eq 'NaN');
		next if($v eq 'disabled');
		$n =~ s/([^a-zA-Z0-9-]+)/_/smog;
		$n =~ s/(_+)/_/smog;
		$n =~ s/^(_)//smo;
		$n =~ s/(_)$//smo;
		$s->{"cfstats__${ksname}__${cfname}__$n"}[$i] = $v;
		#print "cfstats__${ksname}__${cfname}__$n,$v,float,,,,,,\n"
	    }
	}
    }

    my($tpstats) = scalar(`$opts{nodetool} -h localhost tpstats`);
    my(@tp) = $tpstats =~ /^([^ ]*)[ ]*?([^ ]*)[ ]*?([^ ]*)[ ]*?([^ ]*)$/smog;
    while(scalar(@tp)){
	my($n, $a, $p, $c) = (shift(@tp), shift(@tp), shift(@tp), shift(@tp));
	#print "tpstats__${n}__active,$a,float,,,,,,\n";
	#print "tpstats__${n}__pending,$p,float,,,,,,\n";
	#print "tpstats__${n}__completed,$c,float,,,,,,\n";
	$s->{"tpstats__${n}__active"}[$i] = $a;
	$s->{"tpstats__${n}__pending"}[$i] = $p;
	$s->{"tpstats__${n}__completed"}[$i] = $c;
    }
    sleep $opts{period} unless($i);
    #print "-----\n";
}

my($f);
if(! $opts{nocsv}){
  if($opts{debug}){
    $f=*STDOUT; 
  }else{
    open($f,"|$gmetric --csv");
  }
}

while(my($k, $v) = each(%$s)){
    my($d);
    if(($k =~ /count$/i) ||
       ($k =~ /__completed/)){
	next if(($v->[0] eq undef) || ($v->[1] eq undef));
	$d = ($v->[1] - $v->[0]) / $opts{period};
    }else{
	next if($v->[1] eq undef);
	$d = $v->[1];
    }
    if($opts{nocsv}){
      `$gmetric --type=float --name=$k --value=$d -d 600`;
    }else{
      print $f "$k,$d,float,,,,600,,\n";
    }
}

close($f);

