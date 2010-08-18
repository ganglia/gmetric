#!/usr/bin/perl

###  Author: Jordi Prats Catala - CESCA - 2007
###  License to use, modify, and distribute under the GPL
###  http://www.gnu.org/licenses/gpl.txt

@HPLOGRES=`/sbin/hplog -f`;

shift @HPLOGRES;
pop @HPLOGRES;

for $line (@HPLOGRES)
{
    $line=~s/\(\s*(\d+)\)/ $1 /;
    @values=split(/\s+/,$line);
    @values=reverse @values;

    my $speed=shift @values;
    $speed=~s/\W+//ig;

    shift @values; # desc. speed
    shift @values; # redundant
    shift @values; # status

    pop @values; #null
    pop @values; #ID

    my $description="";

    $description.=$_ for (reverse @values);

    #some cleaning
    $description=~s/\W//g;

    system("/usr/bin/gmetric --name ".$description." --value ".$speed." --type uint16 --units rpm");
}
