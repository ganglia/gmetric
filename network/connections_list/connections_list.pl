#!/usr/bin/perl

$gmetric="/usr/local/ganglia/bin/gmetric";
$iface="eth0";
$port="22";
$metricname="active_ssh";


@connlist=`netstat -atn`;
$esta="none";

foreach $i(@connlist)
{
	if ($i=~/ESTABLISHED/)
	{
		$_=$i;
		($arg1,$arg2,$arg3,$from,$to,$state)=split(" ");
		$_=$from;
		($fromaddr,$fromport)=split(":");
		$fromaddr=~s/\n//g;
		$fromport=~s/\n//g;
		$_=$to;
		($toaddr,$toport)=split(":");
		$toaddr=~s/\n//g;
		$toport=~s/\n//g;
		if ($toport eq $port )
		{
			$esta=$esta."To:$toaddr  ";
			$esta=~s/none//;
		}
                if ($fromport eq $port )
                {
                        $esta=$esta."From:$toaddr  ";
			$esta=~s/none//;
                }
	}
}
#print "$gmetric -n$metricname -v\"$esta\" -tstring -i$iface";
`$gmetric -n$metricname -v\"$esta\" -tstring -i$iface`;
