#!/usr/bin/perl
# contributed by ryan sweet <ryan@end.org>
my $gmetric="gmetric";
my @df = `df -kl | grep -v "Filesystem"`; # RS: get info from df, leave out first line

my $calcpercentused;
foreach (@df)   # RS: for each line of df output
{
	my @line = split(/\s+/, $_); # RS: split the line on whitespace
	my @reversed = reverse @line; # RS: reverse the order of @line - this is because IRIX df outputs different items than linux
	my $size = $reversed[4]; # RS: the filesystem size is the fifth element in the reversed list
	my $used = $reversed[3];
	# RS: calculated percent used (df gets it wrong sometimes) is (100(used))/size
	$used = $used * 100;
	$calcpercentused = int($used/$size);
	my $fsname=$line[5]; # RS: get the mount point
	$fsname =~ s/\//_/; # RS: replace / with _
	if ($fsname eq "_") { $fsname="_root"; }
	# RS: send the data to gmond using gmetric
	system("$gmetric --name=disk_percent_used$fsname --value=$calcpercentused --type=uint8 --units=\precent_free"); 
}
