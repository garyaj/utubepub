#!/usr/bin/env perl
# Upload MP3s to relevant directory (create if needed) then update directory
# index pages.
use 5.010;
use autodie;
use Getopt::Long;
use Net::OpenSSH;
use Cwd;
use File::Slurp;
use Mojo::DOM;

my $ssh = Net::OpenSSH->new("ssnfs");
# Get display names
my $dwork;
GetOptions(
  'work=s' => \$dwork,
);
die "Usage: $0 --work work"
  unless $dwork;

#Make files and dirs writeable
$ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB");
$ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
  for (qw(page page/recordings.dat));
# Upload comp-work.dat for new song/work (can overwrite old if it exists)
my $text = "<p>$dwork\n";
# Read GoogleDrive IDs from Work_gdid.txt file
open(my $gdfh, "<", "${dwork}_gdid.txt") or die "Can't open ${dwork}_gdid file";
while (my $gdline = <$gdfh>) {
  chomp $gdline;
  my($title, $gdid) = split /,/, $gdline;
  $text .= "<br>\n<a href=\"http://drive.google.com/uc?export=view&amp;id=$gdid\">$title</a>\n";
}
close $gdfh;
$text .= "</p>\n";

# Insert text into recordings.dat
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/recordings.dat", "/tmp/recordings.dat")
  or die "Can't get recordings.dat";
insertlink('/tmp/recordings.dat', $text);
$ssh->scp_put("/tmp/recordings.dat", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/recordings.dat")
  or die "Can't put recordings.dat";

#Make files and dirs non-writeable
$ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB");
$ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
  for (qw(page page/recordings.dat));

sub insertlink {
  #Search @lines for place to insert new title/link
  my ($file, $links) = @_;
  my $text = read_file( $file );
  utf8::decode($text);
  my $dom = Mojo::DOM->new();
  $dom = $dom->parse($text);
  $dom->at('div.column_2 > div > p')->prepend($links);
  utf8::encode($dom);
  write_file($file, $dom);
}
# vi:ai:et:sw=2 ts=2
