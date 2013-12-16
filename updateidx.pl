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

#Make files and dirs writeable
$ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB");
$ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
  for (qw(page site.meta page/directory.dat page/all-titles.dat));
if ($genre =~ /mass|oratorio|motet/) {
  $ssh->system("sudo -u netchant chmod go+w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$prcomposer.dat");
}
# Upload comp-work.dat for new song/work (can overwrite old if it exists)
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
$ssh->scp_put("/tmp/$dfile", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/tmp")
  or die "Can't upload $dfile:".$ssh->error;

$ssh->system("sudo -u netchant cp /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/tmp /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$dfile");
$ssh->system("rm /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/tmp");

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

# Insert new title into all-titles.dat
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/all-titles.dat", "/tmp/all-titles.dat")
  or die "Can't get all-titles.dat";
if ($genre =~ /mass|oratorio|motet/) {
  $label = "$dwork - $dcomposer";
} else {
  $label = $dwork;
}
my $link = "<a href=\"/$uniqid.html\">$label</a>";
insertlink ('/tmp/all-titles.dat', $link, $label, 'all', 'a');
$ssh->scp_put("/tmp/all-titles.dat", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/all-titles.dat")
  or die "Can't put all-titles.dat";

if ($genre =~ /mass|oratorio|motet/) {
  # Download existing composer.dat file and add new link to comp-work
  if ($ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$prcomposer.dat", "/tmp/$prcomposer.dat")) {
    $link = "<a href=\"/$uniqid.html\">$dwork</a>";
    insertlink ("/tmp/$prcomposer.dat", $link, $dwork, 'work', 'a');
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

    my $text = "<p align=\"left\">\n<a href=\"/$uniqid\">$dwork</a>\n</p>\n";
    write_file("/tmp/$prcomposer.dat", $text);
  }

# Upload composer.dat
$ssh->scp_put("/tmp/$prcomposer.dat", "/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$prcomposer.dat")
  or die "Can't put $prcomposer.dat";
}

# Update directory.dat
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/directory.dat", "/tmp/directory.dat")
  or die "Can't get directory.dat";
# Insert link to song in appropriate category/genre
if ($genre =~ /mass|oratorio|motet/) {
  #Insert composer if mass, oratorio or motet
  $link = "<a href=\"/$prcomposer.html\">$dcomposer</a>\n";
  insertlink ('/tmp/directory.dat', $link, $dcomposer, 'composer', "h3#composer ~ p > a");
  $link = "<a href=\"/$prcomposer-$prwork.html\">$dwork - $dcomposer</a>";
  $label = "$dwork - $dcomposer";
} else {
  $link = "<a href=\"/$genre-$prwork.html\">$dwork</a>";
  $label = $dwork;
}
insertlink ('/tmp/directory.dat', $link, $label, $genre, "h3#$genre ~ p > a");

$ssh->scp_put("/tmp/directory.dat","/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/directory.dat")
  or die "Can't put directory.dat";

$ssh->scp_put("/tmp/site.meta","/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/site.meta")
  or die "Can't put site.meta";

#Make files and dirs non-writeable
$ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB");
$ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/$_")
  for (qw(page site.meta page/directory.dat page/all-titles.dat));
if ($genre =~ /mass|oratorio|motet/) {
  $ssh->system("sudo -u netchant chmod go-w /data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/$prcomposer.dat");
}
sub insertlink {
  #Search @lines for place to insert new title/link
  my ($file, $link, $label, $genre, $css) = @_;
  my $text = read_file( $file );
  my $dom = Mojo::DOM->new();
  my $llb = lc($label);
  $dom = $dom->parse($text);
  my $found = 0;
  for my $e ($dom->find($css)->each) {
    my $test = lc(($genre eq 'composer') ? $e->attr('href') : $e->text);
    if ($test eq $llb) {
      $found = 1;
      last;
    } elsif ($test gt $llb) {
      $e->prepend("$link\n<br />");
      $found = 1;
      last;
    }
  }
  if (not $found) {
    my $last = $css.':last-child';
    $dom->at($last)->append("\n<br />$link");  #Add link to end of list
  }
  write_file($file, $dom);
}
# vi:ai:et:sw=2 ts=2
