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
#Make files and dirs writeable
# $ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
#   for (qw(page site.meta page/directory.dat page/all-titles.dat));

my %Vnames=(
  s => 'Soprano',
  a => 'Alto',
  t => 'Tenor',
  b => 'Bass',
  s1 => 'Soprano1',
  a1 => 'Alto1',
  t1 => 'Tenor1',
  b1 => 'Bass1',
  s2 => 'Soprano2',
  a2 => 'Alto2',
  t2 => 'Tenor2',
  b2 => 'Bass2',
  satb => 'SATB',
);
my %voc   = ( 's' => 0, 'a' => 1, 't' => 2, 'b' => 3, 'satb' => 4 );

# Get display names
my ($dcomposer, $dwork, $genre);
GetOptions(
  'composer=s' => \$dcomposer,
  'work=s' => \$dwork,
  'genre=s' => \$genre,
);
die "Usage: $0 --work work --composer composer --genre [mass|oratorio|motet|carol|hymn]"
  unless $dcomposer and $dwork;

#Generate lowercase equivalents of composer and work, taken from current
#directory
# ~gary/Music/sibs/sib/Durufle/UbiCaritas
my $cwd = cwd();
my ($composer, $work) = (split /\//, $cwd)[-2,-1];   #2nd last is Composer, last is Work
(my $prcomposer = $composer) =~ s/[^a-zA-Z]//g;
$prcomposer =~ s/.*/\L$&/;
(my $prwork = $work) =~ s/[^a-zA-Z]//g;
$prwork =~ s/.*/\L$&/;

# Upload comp-work.dat for new song/work (can overwrite old)
my $text = <<EOT;
<table>
<tbody>
<tr>
<td>$dwork</td>
EOT
# Read YouTube IDs from Work_ytid.txt file
open(my $ytfh, "<", "${work}_ytid.txt") or die "Can't open ${work}_ytid file";
# Read GoogleDrive IDs from Work_gdid.txt file
open(my $gdfh, "<", "${work}_gdid.txt") or die "Can't open ${work}_gdid file";
while (my $line = <$ytfh>) {
  my $gdline = <$gdfh>;
  my($voice, $ytid) = split /\s+/, $line;
  my(undef, $gdid) = split /\s+/, $gdline;
  $text .= "<td><a href='http://youtu.be/$ytid?hd=1'><img style='padding:0 5px 0 20px;' ".
  "src='/images/icon_youtube_16x16.gif' alt='Click to view on YouTube' /></a>".
  "<a href=\"http://drive.google.com/uc?export=view&amp;id=$gdid\">$Vnames{$voice}</a>".
  "</td>\n";
}
close $ytfh;
close $gdfh;
$text .= <<EOT;
</tr>
</tbody>
</table>
EOT
my $dfile = "$prcomposer-$prwork.dat";
write_file("/tmp/$dfile", $text);
# $ssh->scp_put("/tmp/$dfile", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/")
  # or die "Can't upload $dfile:".$ssh->error;

#Add comp-work page entry to site.meta
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/site.meta", "/tmp/site.meta")
  or die "Can't get site.meta";

my $label = "$dcomposer - $dwork";
my $uniqid = "$prcomposer-$prwork";
open(my $mt, ">>", "/tmp/site.meta") or die "Can't open /tmp/site.meta";
print $mt <<EOT;

[$uniqid]
label=$label
lastpublished=
lastupdated=1386245606
layout=work
title=$uniqid
type=page
url=/$uniqid.html
EOT
close $mt;

# Update all-titles.dat
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/all-titles.dat", "/tmp/all-titles.dat")
  or die "Can't get all-titles.dat";
my @lines = read_file( '/tmp/all-titles.dat' ) ;
$label = "$dwork - $dcomposer";
my $link = "<br /><a href=\"/$uniqid.html\">$label</a>\n";
insertlink($link, \@lines, 0, $#lines);
write_file('/tmp/all-titles.dat', @lines);
# $ssh->scp_put("/tmp/all-titles.dat", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/all-titles.dat")
#   or die "Can't put all-titles.dat";
# exit;

# Download existing composer.dat file and add new link to comp-work
if ($ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$prcomposer.dat", "/tmp/$prcomposer.dat")) {
  @lines = read_file( "/tmp/$prcomposer.dat" ) ;
  my $link = "<br /><a href=\"/$uniqid.html\">$dwork</a>\n";
  insertlink($link, \@lines, 0, $#lines);
} else {
#Add composer page entry to site.meta
  $ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/site.meta", "/tmp/site.meta")
    or die "Can't get site.meta";
  my $label = "$dcomposer";
  my $uniqid = "$prcomposer";
  open(my $mt, ">>", "/tmp/site.meta") or die "Can't open /tmp/site.meta";
  print $mt <<EOT;

[$uniqid]
label=$label
lastpublished=
lastupdated=1386245606
layout=work
title=$uniqid
type=page
url=/$uniqid.html
EOT
  close $mt;

  @lines = ("<p align=\"left\">\n", "<a href=\"/$uniqid\">$dwork</a>\n", "</p>\n");
}
# Upload composer.dat
write_file("/tmp/$prcomposer.dat", @lines);
# $ssh->scp_put("/tmp/$composer.dat", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$composer.dat")
#   or die "Can't put $composer.dat";

# Update directory.dat
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/directory.dat", "/tmp/directory.dat")
  or die "Can't get directory.dat";
@lines = read_file( '/tmp/directory.dat' ) ;
$link = "<br /><a href=\"/$prcomposer.html\">$dcomposer</a>\n";
my ($startcomp, $endcomp, $startmass, $endmass, $startorat, $endorat, $startmotet, $endmotet, $startcarol, $endcarol, $starthymn, $endhymn);
my $foundcomposer = 0;
for (my $i=0 ; $i < $#lines; $i++) {
  $foundcomposer = 1 if ($lines[$i] =~ /$prcomposer/i);
  $startcomp =  $i+2 if ($lines[$i] =~ /<h3>Composers/); 
  $endcomp =    $i if ($startcomp and $lines[$i] =~ /<\/p>/); 
  $startmass =  $i+2 if ($lines[$i] =~ /<h3>Masses/); 
  $endmass =    $i if ($startmass and $lines[$i] =~ /<\/p>/); 
  $startorat =  $i+2 if ($lines[$i] =~ /<h3>Oratorios/); 
  $endorat =    $i if ($startorat and $lines[$i] =~ /<\/p>/); 
  $startmotet = $i+2 if ($lines[$i] =~ /<h3>Motets/); 
  $endmotet =   $i if ($startmotet and $lines[$i] =~ /<\/p>/); 
  $startcarol = $i+2 if ($lines[$i] =~ /<h3>Carols/); 
  $endcarol =   $i if ($startcarol and $lines[$i] =~ /<\/p>/); 
  $starthymn =  $i+2 if ($lines[$i] =~ /<h3>Hymns/); 
  $endhymn =    $i if ($starthymn and $lines[$i] =~ /<\/p>/); 
}
# Insert composer link if not present
insertlink($link, \@lines, $startcomp, $endcomp) unless $foundcomposer;

# Insert link to song in appropriate category/genre
$link = "<br /><a href=\"/$prcomposer-$prwork.html\">$dwork - $dcomposer</a>\n";
insertlink($link, \@lines, $startmass, $endmass) if ($genre eq 'mass');
insertlink($link, \@lines, $startorat, $endorat) if ($genre eq 'oratorio');
insertlink($link, \@lines, $startmotet, $endmotet) if ($genre eq 'motet');
$link = "<br /><a href=\"/carol-$prwork.html\">$dwork</a>\n";
insertlink($link, \@lines, $startcarol, $endcarol) if ($genre eq 'carol');
$link = "<br /><a href=\"/hymn-$prwork.html\">$dwork</a>\n";
insertlink($link, \@lines, $starthymn, $endhymn) if ($genre eq 'hymn');

write_file('/tmp/directory.dat', @lines);
# $ssh->scp_get("/tmp/directory.dat","/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/directory.dat")
#   or die "Can't put directory.dat";

# $ssh->scp_put("/tmp/site.meta","/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/site.meta")
#   or die "Can't put site.meta";

#Make files and dirs non-writeable
# $ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
#   for (qw(page site.meta page/directory.dat page/all-titles.dat));

sub insertlink {
  #Search @lines for place to insert new title/link
  my ($link, $lines, $i, $j) = @_;
  my $found = 0;
  while ($i <= $j) {
    my ($title) = ($lines->[$i] =~ m%<a href="/.*\.html">([^<]+)</a>%);
    if ($title ge $label) {
      splice(@{$lines},$i,0,$link); #insert link
      $found = 1;
      last;
    }
    $i++;
  }
  if (not $found) {
    splice(@{$lines},$i-1,0,$link);  #Add link to end of list
  }
}
# vi:ai:et:sw=2 ts=2
