#!/usr/bin/perl
#
# a simple script to report some per user stats to ganglia
# contributed by Ryan Sweet <ryan@end.org>
#
my $gmetric="gmetric";
my $users,@ps; 

# RS: get ps aux output and skip the first line
# RS: ps has different behaviour on IRIX vs Linux
my $uname=`uname`;
if ( $uname =~ /Linux/ ) 
{
        @ps=`ps aux| grep -v USER`;
}else{
        # RS: pcpu is repeated because this ps doesn't give %mem stats
        @ps=`ps -eo user,pid,pcpu,pcpu,vsz,rss,tty,state,stime,time,comm`;
}


# RS: iterate over each line of the ps output
foreach my $line (@ps) 
{
        # RS: eat any leading whitespace
        $line =~ s/^\s+//;
        
        # RS: split the line on whitespace, assigning vars
        my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$stat,$start,$time,$command,@args) = split(/\s+/, $line);     

        # RS: populate the hash %users with references to the cumulative cpu,memz,time vars
        $users->{$user}{cpu}+=$cpu;
        $users->{$user}{mem}+=$mem;
        $users->{$user}{vsz}+=$vsz;
        # RS: calculate the time in seconds rather than min:sec
        my ($min,$sec)=split(/:/,$time);
        $sec+=($min*60);
        $users->{$user}{time}+=$time;
        $users->{$user}{procs}+=1; # total number of procs per user
        
}

# RS: for each user that was found, send the stats to gmond
foreach my $user (keys %$users)
{
        # cpu total
        system("gmetric --name=cpu_percent_$user --value=$users->{$user}{cpu} --type=float --units=\%cpu");
        
        # mem total (only reported on linux)
        if ( $uname =~ /Linux/ )
        {
                system("gmetric --name=mem_percent_$user --value=$users->{$user}{mem} --type=float --units=\%mem");
        }
        
        # vsz total
        system("gmetric --name=mem_vsz_kb_$user --value=$users->{$user}{vsz} --type=float --units=kilobytes");

        # cputime total
        system("gmetric --name=cpu_total_time_sec_$user --value=$users->{$user}{time} --type=float --units=seconds");
        
        # processes total
        system("gmetric --name=procs_total_$user --value=$users->{$user}{procs} --type=float --units=processes");
                        

} 
