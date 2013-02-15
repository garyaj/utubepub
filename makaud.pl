#!/usr/bin/env perl
# Assuming I have used Sibelius to create:
# $song_satb.aiff
# $song_s.aiff
# $song_a.aiff
# $song_t.aiff
# $song_b.aiff
# from $song.sib
# this script will create compressed, normalised MP3s from the AIFFs.

use 5.010;
use autodie;
use Getopt::Long;

# Load commandline parameters.
my ($song, $parts);
GetOptions(
  'file=s' => \$song,
  'parts=s' => \$parts,
);
die "Usage: $0 --file filename --parts 's1 s2 a t b'"
  unless $song and $parts;
my @Voices=split /\s+/, $parts;
push @Voices, 'satb'; #always create an SATB version

#Check that all the required files are present before commencing processing.
for my $i (@Voices) {
  die "Missing ${song}_$i.aiff" unless -e "${song}_$i.aiff";
}

for my $i (@Voices) {
  #Boost the audio a bit for headphone use then normalise it.
  # system "sox -V3 --norm -B ${song}_$i.aiff -B -t aiff - contrast 75 earwax gain -n | ffmpeg -y -i pipe: -ab 256k ${song}_$i.mp3";
  system "sox -V3 --norm -B ${song}_$i.aiff -t aiff -B - | ffmpeg -y -i pipe: -ab 192k ${song}_$i.mp3";
}

# vi:ai:et:sw=2 ts=2
