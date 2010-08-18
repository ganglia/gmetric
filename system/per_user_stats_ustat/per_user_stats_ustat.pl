#!/usr/bin/perl

# effective tools to view users activity on each node 

# V 1.0 (c) Alexander Sudakov
# saa@univ.kiev.ua
# scriprt collect such metrics as :
#       cpu     -cpu % used by user
#       mem     -memory % used by user
#       rss     -rss
#       time    -time
#       procs   -number of process

# and something else but it needs to be correctly uncomented and cheked !!!!



# V 1.1 (c) orest
# Boyko Nikolay
# orest@univ.kiev.ua
# litTle fix this system proceses (demons ) - they are reported
# as one virtual user  "__SYSTEM__"

# implemented  on LINUX 2.2.x REDHAT  this mosix kernel patch

$GMETRIC="/usr/bin/gmetric ";

#$PORT=8649;
#$MCHANNEL="239.2.17.71";
#$GMETRIC"="/usr/bin/gmetric --mcast_port=$PORT --mcast_channel=\"$MCHANNEL\" ";

use FileHandle;
 use Fcntl ':flock'; # import LOCK_* constants
$UPDATE_TIME=1;
my $pcp = new FileHandle;
$| = 1;
#@user_params = ("nproc","cpu_time", "real_time", "nproc_pcnt",
#               "cpu_time_pcnt", "real_time_pcnt", "ksec");
$lock_file="/var/lock/.stat.pl";

# IF you want to see metrics  "rss" , "time", "procs" just uncomment  them here and "some" other code in script
@user_params = ("cpu",
                "mem"
#               ,"rss",
#               "time",
#               "procs"
                );
@proc_params = ();

@host_params = (
#               "3_3V",
#               "5V",
#               "12V",
#               "fan1",
#               "fan2",
                "CPU1_temp",
                "CPU2_temp",
                "Temp"
#               "swap_in",
 #               "swap_out",
  #              "disk_bin",
 #               "disk_bout",
  #              "sys_ints",
   #             "sys_contsw"
);
%param_units = (
        "nproc_pcnt"    =>      "%",
        "cpu_time_pcnt" =>      "%",
        "real_time_pcnt"=>      "%",
        "ksec"          =>      "",
        "cur_proc"      =>      "",
        "3_3V"          =>      "V",
        "5V"            =>      "V",
        "12V"           =>      "V",
        "fan1"          =>      "RPM",
        "fan2"          =>      "RPM",
        "CPU1_temp"     =>      "C",
        "CPU2_temp"     =>      "C",
        "Temp"          =>      "C",
        "swap_in"       =>      "KByts/c",
        "swap_out"      =>      "KByts/c",
        "disk_bin"      =>      "blocks/c",
        "disk_bout"     =>      "blocks/c",
        "sys_ints"      =>      "blocks/c",
        "sys_contsw"    =>      "blocks/c",
        "cpu"           =>      "%",
        "mem"           =>      "%",
        "time"          =>      "sec",
        "rss"           =>      "Byts",
        "procs"         =>      ""
);

%param_types = (
        "nproc_pcnt"    =>      "float",
        "cpu_time_pcnt" =>      "float",
        "real_time_pcnt"=>      "float",
        "ksec"          =>      "float",
        "cur_proc"      =>      "uint32",
        "3_3V"          =>      "float",
        "5V"            =>      "float",
        "12V"           =>      "float",
        "fan1"          =>      "uint32",
        "fan2"          =>      "uint32",
        "CPU1_temp"     =>      "float",
        "CPU2_temp"     =>      "float",
        "Temp"          =>      "float",
        "swap_in"       =>      "uint32",
        "swap_out"      =>      "uint32",
        "disk_bin"      =>      "uint32",
        "disk_bout"     =>      "uint32",
        "sys_ints"      =>      "uint32",
        "sys_contsw"    =>      "uint32",
        "cpu"           =>      "float",
        "mem"           =>      "float",
        "time"          =>      "uint32",
        "rss"           =>      "uint32",
        "procs"         =>      "uint32"
);

%user_info=();
sub get_users (){
        if($pid_ul=open (USTAT,"-|")){
                while (<USTAT>){
                        ($user, $passwd, $uid)=split(/:/);
                        #print "$user";
                        #print "$user $uid\n";
                        foreach $param (@user_params){
                                #if($uid < 1000  ){
                                #       $user_info{"__SYSTEM__"}{$param}=0;
                                        #delete ($user_info{"__SYSTEM__"}{$param});
                                #} else {
                                        $user_info{$user}{$param}=0;
                                #}
                        }
                        #$user_info{"__SYSTEM__"}{$param}=0;

                }
        close(USTAT);
                        foreach $param (@user_params){
                                delete($user_info{"__SYSTEM__"}{$param});
                        }
        }  else {
              print "cannot fork: $!" unless defined $pid_ul;
              exec("ypcat passwd");
        }
}
#
#
#
sub update_stats(){
        foreach my $usr (keys %user_info){
                foreach $param (@user_params){
                        #print "$usr $param $user_info{$usr}{$param}\n";
                        my $name="user--$usr--$param";
                        #print ">>> $name\n";
                        system("$GMETRIC --name=$name --type=$param_types{$param} --value=$user_info{$usr}{$param} --units=$param_units{$param} -i eth0 -l 1");
                }
        }
        foreach my $param (@host_params){
                        system("$GMETRIC --name=$param --type=$param_types{$param} --value=$host_info{$param} --units=$param_units{$param} -i eth0 -l 1");
        }

}
#
#
#
sub get_user_procs (){
        #my %tmp_uproc = ();
        #foreach $user (keys %user_info){
        #        print "$user\n";
        #}

        my @tup = `/bin/mps haux`;
        foreach my $ln  (@tup){
        $ln =~ s/^\s+//;

        # RS: split the line on whitespace, assigning vars
        my ($user,$pid,$cpu,$mem,$vsz,$rss,$tty,$node,$stat,$start,$time,$command,@args) = split(/\s+/, $ln);
        if(!exists  $user_info{$user}){
        #       print "$user\n";
                 $user="__SYSTEM__";
        }
        #print "$user\n";
        $user_info{$user}{"cpu"}+=$cpu;
        $user_info{$user}{"mem"}+=$mem;


#        $user_info{$user}{"rss"}+=($rss*1024);
        # RS: calculate the time in seconds rather than min:sec
#        my ($min,$sec)=split(/:/,$time);
#        $sec+=($min*60);
#        $user_info{$user}{"time"}+=$time;
#        $user_info{$user}{"procs"}+=1; # total number of procs per user

        }
        #foreach $user (keys %user_info){
        #       print "$user\n";
        #}
}
#
#
#
sub get_sensors(){
        my $sd = `/usr/local/bin/sensors 2>/dev/null`;
#3.3V:      +3.30 V  (min =  +3.12 V, max =  +3.47 V)
#5V:        +5.18 V  (min =  +4.73 V, max =  +5.26 V)
#12V:      +12.12 V  (min = +11.37 V, max = +12.62 V)
#fan1:     3443 RPM  (min = 3000 RPM, div = 2)
#fan2:     3497 RPM  (min = 3000 RPM, div = 2)
#temp1:       +30?C  (min =  +10?C, max =  +60?C)
#CPU_Temp:    +28?C  (min =  +10?C, max =  +60?C)
#CPU2_Temp:   +28?C  (min =  +10?C, max =  +60?C)
#vid:       +1.75 V
        #print "$sd\n";
        #return;
        #$sd =~ m/^3\.3V:[\t ]+\+([0-9]+)/m;
        #if($sd =~ /^3\.3V:[\t ]+\+([0-9.]+) V[ \t]+/m) {
        #       $host_info{"3_3V"}=$1+0;
                #print $host_info{"3_3V"};
        #} else {
        #       $host_info{"3_3V"}=0;
        #}
        #if($sd =~ /^5V:[\t ]+\+([0-9.]+) V[ \t]+/m) {
        #        $host_info{"5V"}=$1+0;
        #}else {
        #        $host_info{"5V"}=0;
        #}
        #if($sd =~ /^12V:[\t ]+\+([0-9.]+) V[ \t]+/m) {
        #        $host_info{"12V"}=$1+0;
        #}else {
        #        $host_info{"12V"}=0;
        #}
        #if($sd =~ /^fan1:[\t ]+([0-9]+) RPM[ \t]+/m) {
        #        $host_info{"fan1"}=$1+0;
        #}else {
        #        $host_info{"fan1"}=0;
        #}
        #if($sd =~ /^fan2:[\t ]+([0-9]+) RPM[ \t]+/m) {
        #        $host_info{"fan2"}=$1+0;
        #}else {
        #        $host_info{"fan2"}=0;
        #}
        if($sd =~ /^CPU_Temp:[\t ]+\+([0-9.]+)?C[ \t]+/m) {
                $host_info{"CPU1_temp"}=$1+0;
        }else {
                $host_info{"CPU1_temp"}=0;
        }
        if($sd =~ /^CPU2_Temp:[\t ]+\+([0-9.]+)?C[ \t]+/m) {
                $host_info{"CPU2_temp"}=$1+0;
        }else {
                $host_info{"CPU2_temp"}=0;
        }
        if($sd =~ /^temp1:[\t ]+\+([0-9.]+)?C[ \t]+/m) {
                $host_info{"Temp"}=$1+0;
        }else {
                $host_info{"Temp"}=0;
        }


        #print %host_info;
}
#
#
#
sub  get_user_stats (){
        if($pid_st=open (USTAT,"-|") ){
                       $_=<USTAT>;
                       ($tot_nproc, $pcnt_tot_nproc, $tot_re,
                        $pcnt_tot_re, $tot_cp, $pcnt_tot_cp,
                        $tot_avio, $tot_ksec) = split();
                       $tot_re+=0.; $tot_avio+=0.; $tot_cp+=0.; $tot_ksec+=0.;
                       $pcnt_tot_nproc+=0.; $pcnt_tot_re+=0.; $pcnt_tot_cp+=0.;

                        foreach (<USTAT>){
                               ($user,$nproc,$pcnt_nproc,$re,
                                $pcnt_re,$cp,$pcnt_cp,$avio,$ksec) = split();
                               $re+=0.; $avio+=0.; $cp+=0.; $ksec+=0.;
                               $pcnt_nproc+=0.; $pcnt_re+=0.; $pcnt_cp+=0.;
                                $user_info{$user}{"nproc_pcnt"}=$pcnt_nproc;
                                $user_info{$user}{"cpu_time_pcnt"}=$pcnt_cp;
                                $user_info{$user}{"real_time_pcnt"}=$pcnt_re;
                                $user_info{$user}{"ksec"}=exp($ksec/($tot_ksec+0.0001));
                                $user_info{$user}{"cur_proc"}=0;
                                #$ksec/=$tot_ksec;
                                #$ksec=log($ksec);
                               #print "$user: $ksec $pcnt_cp\n";
                       }
                       close USTAT;
               } else {
                       print "cannot fork: $!" unless defined $pid_st;
                       exec("sa -m -K -c");
               }

}

sub get_open_fds(){
        #`cat /proc/sys/fs/file-nr`;
        split(' ',`cat /proc/sys/fs/file-nr`);
        system("$GMETRIC --name=files_used --type=uint32 --value=@_[1]  -i eth0 -l 1");
        #print "@_[1]\n";
};

#$pid_pcp=open ($pcp,"-|");
#if($pid_pcp){

defined(my $pid = fork)         or die "Can't fork: $!";
exit if $pid;
setsid   or die "Can't start a new session: $!";


        while  (1){
                #@_=`vmstat  2>/dev/null`;
                #$ln="";
                #foreach $l (@_){
                        #print $l;
                #       if($l =~ /swpd|free/i ) {
                #               next;
                #       } else {
                #               $ln =$l;
                #       }
                #}
                #print $ln;
                #exit 0;
                #print $ln;
                #($ld_avg_1min, $mem_swapped, $mem_free, $mem_buff, $mem_cache,
                #$host_info{"swap_in"},
                #$host_info{"swap_out"},
                #$host_info{"disk_bin"},
                #$host_info{"disk_bout"},
                #$host_info{"sys_ints"},
                #$host_info{"sys_contsw"},
                #$cpu_u, $cpu_sys, $cpu_idle) = split(/[ \t\n]+/,$ln);
                #print "$ld_avg_1min $disk_bout\n";

#               unless (open(LOCK,">>$lock_file")){
#                       print  "Cannot open $lock_file\n";
#                       exit (1);
#               }
#               unless (flock(LOCK,LOCK_EX|LOCK_NB)) {
#                       close (LOCK);
#                       exit(0);
#               }
                get_users;
                #get_user_stats;
                get_user_procs;
                get_sensors;
                update_stats;
                get_open_fds;
#               flock(LOCK,LOCK_UN);
#               close (LOCK);

#               foreach $user (keys %user_info){
#                       $user_info{$user}{"ksec"} /= $tot_ksec;
#                       print "$user: $user_info{$user}{\"ksec\"} $user_info{$user}{\"nproc_pcnt\"} $user_info{$user}{\"cpu_time_pcnt\"} $user_info{$user}{\"real_time_pcnt\"}\n" ;
#               }
#               }
        #       sleep 300;
        #}
#} else {
#       print "cannot fork: $!" unless defined $pid_pcp;

#       exec("pmstat -t $UPDATE_TIME  -T $UPDATE_TIME 2>/dev/null");
        sleep 15;

}
                                                                                                                    