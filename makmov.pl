#!/usr/bin/env perl
# Assuming I have used Sibelius to create:
# $song_satb.aiff
# $song_s.aiff
# $song_a.aiff
# $song_t.aiff
# $song_b.aiff
# from $song.sib
# and Sibelius First to create $song.mov,
# this script will create a YouTube-compatible video for each part in addition to the
# SATB video, then it will load each video up to YouTube together with a description
# which contains links to the other parts.

use 5.010;
use autodie;
use WebService::GData::YouTube;
use WebService::GData::ClientLogin;
use Getopt::Long;
use Config::Tiny;

my $Config = Config::Tiny->new;
$Config = Config::Tiny->read( "$ENV{HOME}/.youtube/cred.conf" ) or die "Can't open cred.conf";
my $Email    = $Config->{_}->{Email};
my $Password = $Config->{_}->{Password};
my $Key      = $Config->{_}->{Key};

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

# Load commandline parameters.
my ($song, $title, $parts, $x, $y);
my $sy = 1;
my $unlisted = '';
GetOptions(
  'file=s' => \$song,
  'title=s' => \$title,
  'parts=s' => \$parts,
  'offset=i' => \$x,
  'incr=i' => \$y,
  'systems=i' => \$sy,
  'unlisted' => \$unlisted,
);
die "Usage: $0 --file filename --title song_title --parts 's1 s2 a t b' --offset 35 --incr 102 --systems 1 --unlisted"
  unless $song and $title and $parts and $x and $y;
# my $song = 'bach_joy';
# my $title = "Jesu, Joy of Man's Desiring";
# my $x = 35;
# my $y = 102;
# my @Voices=qw(s a t b satb);
my @Voices=split /\s+/, $parts;
push @Voices, 'satb'; #always create an SATB version

#Check that all the required files are present before commencing processing.
die "Missing ${song}.mov" unless -e "${song}.mov";
for my $i (@Voices) {
  die "Missing ${song}_$i.aiff" unless -e "${song}_$i.aiff";
}

#Extract video part of .mov
system "ffmpeg -i ${song}.mov -vcodec copy -an ${song}_satb.mp4";

#Extract single frame from movie
system "ffmpeg -vframes 1 -i ${song}.mov ${song}_single_frame.png";
# :TODO :14/10/2012 11:46:27:GAJ: Extract coords of staves from single frame

# Create an overlay image for each voice
# Overlay consists of two slightly greyed rectangles above and below a fully
# transparent rectangle which overlays the staff being highlighted.
# Numbers are hardwired for the moment.
#No overlay for SATB version
my $base = "convert -size 1280x720 canvas:transparent -fill '#D3D3D380' -stroke '#D3D3D380' -define png:color-type=6 -alpha set -channel rgba";
my $cmd;
for my $i (0 .. $#Voices-1) { #ignore 'satb'
  my $j=$x+$y*$i;
  my $k=$j+$y;
  $cmd = $base;
  if ($sy == 1) {
    $cmd .= " -draw \"rectangle 0,0 1280,$j\" -draw \"rectangle 0,$k 1280,720\"";
  } else {
    my $l = 360 + $j + 33;
    my $m = 360 + $k + 33;
    $cmd .= " -draw \"rectangle 0,0 1280,$j\"";
    $cmd .= " -draw \"rectangle 0,$k,1280,$l\"";
    $cmd .= " -draw \"rectangle 0,$m 1280,720\"";
  }
  $cmd .= " gradient_$Voices[$i].png";
  system $cmd;
}

print "Press return to continue";
my $dummy = <STDIN>;
my %ids;
my $id;
for my $i (@Voices) {
  #Boost the audio a bit for headphone use then normalise it.
  system "sox -V3 --norm -B ${song}_$i.aiff -t aiff -B - | ffmpeg -y -i pipe: -ab 256k ${song}_$i.m4a";

  #Add a static image overlaid as a mask to highlight part being played in video.
  #Can't stream output of this because muxing command can't handle streamed
  #Must be 30fps for YouTube. (No need to overlay the SATB version.)
  if ($i ne 'satb') {
    system "ffmpeg -y -i ${song}_satb.mp4 -r 30 -vf \"movie=gradient_$i.png [gradient]; [in][gradient] overlay=0:0 [out]\" -an -vcodec libx264 ${song}_$i.mp4";
    unlink "gradient_$i.png"; #Cleanup
  }
  #Now mux the video (mp4) and the audio (m4a) back into .mov format.
  system "ffmpeg -y -i ${song}_$i.mp4 -i ${song}_$i.m4a -vcodec copy -acodec copy ${song}_$i.mov";
  unlink "${song}_$i.m4a","${song}_$i.mp4"; #Cleanup

  #Upload each video and collect its videoID
  $cmd = "youtube-upload --get-upload-form-info --email='$Email' --password='$Password' --title=\"$title - $Vnames{$i}\" --description=\"$title - $Vnames{$i}\" --category=Music --keywords='practice, choral' ".($unlisted?'--unlisted ':'')."${song}_$i.mov";
  $id = `$cmd | upload_with_curl.sh`;
  chomp $id;
  $id =~ s/\r$//;
  $id =~ s/\A[^=]+=(.*)\z/$1/ms;
  $ids{$i} = $id;

  unlink "${song}_$i.mov";  #Cleanup
}

#Update the description text of each video to contain links to the other members of the set.
my $auth;
eval {
  $auth = WebService::GData::ClientLogin->new(
    email    => $Email,
    password => $Password,
    key      => $Key,
  );
};
if (my $error = $@){
  die "Can't login to YouTube:",$error->code,':',$error->content;
}

my $k;
for my $i (0..$#Voices) {
  my $video = WebService::GData::YouTube->new($auth)->get_video_by_id($ids{$Voices[$i]});
  my $description = "If you want to learn to sing the other choir voices for this song, you can practice them by following the training tracks below:\n";
  for my $j (0..$#Voices) {
    next if ($j == $i);
    $description .= "$Vnames{$Voices[$j]} at http://youtu.be/$ids{$Voices[$j]}?hd=1\n";
  }
  $description .= "\nLearn more about St Mary's Singers at http://www.stmaryssingers.com";
  $video->description($description);
  ($k = $Voices[$i]) =~ s/\d+$//;
  my $tags='learn, practice, training, choir, choral, ' . lc($Vnames{$k});
  $video->keywords($tags);
  $video->save;
}

# vi:ai:et:sw=2 ts=2
