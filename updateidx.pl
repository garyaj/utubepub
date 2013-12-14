#!/usr/bin/env perl
# Upload MP3s to relevant directory (create if needed) then update directory
# index pages.
use 5.010;
use autodie;
use Getopt::Long;
use Config::Tiny;
use Net::FTP;
use Cwd;
use File::Slurp;
use Mojo::DOM;

my $Config = Config::Tiny->new;
$Config = Config::Tiny->read( "$ENV{HOME}/.stms/cred.conf" ) or die "Can't open cred.conf";
my $Host     = $Config->{_}->{Host};
my $Login    = $Config->{_}->{Login};
my $Password = $Config->{_}->{Password};

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
my ($dcomposer, $dwork);
GetOptions(
  'composer=s' => \$dcomposer,
  'work=s' => \$dwork,
);
die "Usage: $0 --work work --composer composer"
  unless $dcomposer and $dwork;

#Generate lowercase equivalents of composer and work, taken from current
#directory
# ~gary/Music/sibs/sib/Saint-Saens/Oratorio_de_Noel
my $cwd = cwd();
my ($composer, $work) = (split /\//, $cwd)[-2,-1];   #2nd last is Composer, last is Work
(my $prcomposer = $composer) =~ s/[^a-zA-Z]//g;
$prcomposer =~ s/.*/\L$&/;
(my $prwork = $work) =~ s/[^a-zA-Z]//g;
$prwork =~ s/.*/\L$&/;

# establish FTP connection to NetRegistry host
my $ftp = Net::FTP->new($Host, Debug => 0)
 or die "Cannot connect to $Host: $@";

$ftp->login($Login,$Password)
 or die "Cannot login ", $ftp->message;

# move to /audio/practice/$prcomposer/$prwork (create it, if it doesn't exist)
if (!$ftp->cwd("/audio/practice/$prcomposer/$prwork")) {
  $ftp->mkdir("/audio/practice/$prcomposer/$prwork",1);
  $ftp->cwd("/audio/practice/$prcomposer/$prwork")
   or die "Cannot change working directory ", $ftp->message;
}

#Split list of MP3s and sort into name/SATB order
my @files = sort {
              $a->[1] cmp $b->[1]
                      ||
              $voc{$a->[2]} <=> $voc{$b->[2]}
                 }
            map { [$_, /^(.+)_[satb]+\d?\.mp3/, /_([satb]+)\d?\.mp3/ ] }
            glob("*.mp3");

#Upload the MP3s
for my $file (@files) {
  $ftp->put($file->[0]);
}

# Now move to /audio/directory/$composer
if (!$ftp->cwd("/audio/directory/$composer")) {
  # (create it, if it doesn't exist)
  $ftp->mkdir("/audio/directory/$composer");
  # TODO add new composer to index.html
  $ftp->cwd("/audio/directory/$composer")
   or die "Cannot change working directory ", $ftp->message;
}

#Check if composer is already in list, else add him(her).
#If new composer, add index file listing this work.
#If existing composer and add new work to existing index and create the new work
#directory entry
$ftp->get('/templates/work_tmpl.html','/tmp/work_tmpl.html')
  or die "Can't get work_tmpl.html";
my $text = read_file( '/tmp/work_tmpl.html' ) ;
my $dom = Mojo::DOM->new();
$dom = $dom->parse($text);
$dom->at('title')->append_content("$dcomposer - $dwork")->root;
$dom->at('div.reason h1')->replace_content("$dcomposer - $dwork")->root;
$dom->at('div.column_2 span')->replace("<table>\n<tr>\n<td></td>\n</tr>\n</table>\n")->root;
# $dom->parse("<table>\n<tr>\n<td></td>\n</tr>\n</table>\n")->root;

my $prevsong = '';
# @Songs is used to determine whether to create one or multiple entries in
# /audio/directory/Composer
my @Songs;

for my $file (@files) {
  my $song = $file->[1];
  if ($song ne $prevsong) {
    push @Songs, $song;
    if (!$prevsong) { #first time insert song name into dummy td element
      $dom->at('td')->replace_content($song)->root;
    } else {
      #otherwise append a new row with song name
      $dom->find('tr')->[-1]->append("<tr>\n<td>$song</td>\n</tr>\n")->root;
    }
    # Read YouTube IDs from Song_ytid.txt file
    open(my $ytfh, "<", "${song}_ytid.txt")
      or die "Can't open ${song}_ytid file";
    while (my $line = <$ytfh>) {
      my($voice, $ytid) = split /\s+/, $line;
      my $html = "<td><a href='http://youtu.be/$ytid?hd=1'><img style='padding:0 5px 0 20px;' ".
      "src='/images/icon_youtube_16x16.gif' alt='Click to view on YouTube' /></a>".
      "<a href='/audio/practice/$prcomposer/$prwork/${song}_$voice.mp3'>$Vnames{$voice}</a>".
      "</td>";
      $dom->find('td')->[-1]->append($html)->root;
    }
    close $ytfh;
  }
  $prevsong = $song;
}
# say $dom;
# exit;
write_file("/tmp/$work.html", $dom);

# get a list of existing files in remote directory
my @rfiles = $ftp->ls();

# upload $song.html
$ftp->put("/tmp/$work.html");

if (scalar @rfiles == 0) {
  # if there were no other files in the directory
  # create an index.html pointing to $work.html
  $ftp->get('/templates/index_tmpl.html','/tmp/index_tmpl.html')
    or die "Can't get index_tmpl.html";
  $text = read_file( '/tmp/index_tmpl.html' ) ;
  $dom = Mojo::DOM->new();
  $dom = $dom->parse($text);
  $dom->at('title')->append_content("$dcomposer")->root;
  $dom->at('div.reason h1')->replace_content("$dcomposer")->root;
  $dom->at('div.column_2 span')->replace("<a href=\"$work.html\">$dwork</a>\n")->root;
  write_file("/tmp/index.html", $dom);
  $ftp->put("/tmp/index.html");
} else {
  # add new link to index.html
  $ftp->get('index.html','/tmp/index_temp.html')
    or die "Can't get index.html";
  $text = read_file( '/tmp/index_temp.html' ) ;
  $dom = Mojo::DOM->new();
  $dom = $dom->parse($text);
  $dom->find('div.column_2 a')->[-1]->append("<br />\n<a href=\"$work.html\">$dwork</a>")->root;
  write_file("/tmp/index.html", $dom);
  $ftp->put("/tmp/index.html");
}
$ftp->quit;
# vi:ai:et:sw=2 ts=2
