#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: buildgdlist.pl
#
#        USAGE: ./buildgdlist.pl  
#
#  DESCRIPTION: Recursively descend Google Drive tree of folders and create a
#               lookup table of filepath/filename = fileid.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Gary Ashton-Jones (GAJ), gary@ashton-jones.com.au
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 22/11/2013 10:56:42
#     REVISION: ---
#===============================================================================

use 5.010;
use Log::Log4perl qw(:easy);
use Net::Google::Drive::Simple;

package GDFileLookup;
# Print path/file + Google ID of any mpeg files found
# Call itself if file is a folder
#
sub new {
    my ( $class ) = @_;
    $class = ( ref $class || $class );
    my $self = {};
    bless( $self, $class );
    # requires a ~/.google-drive.yml file with an access token, 
    $self->{gd} = Net::Google::Drive::Simple->new();
    return $self;
}

sub gd {
    return $_[0]->{gd};
}

sub printfiles {
    my ( $self, $path ) = @_;
    my $index;

    my $children = $self->gd->children($path);
    for my $child ( @$children ) {
      my $file = $child->title;
      warn $file;
      if ($child->mimeType eq 'application/vnd.google-apps.folder') {  #it's a folder
        $self->printfiles("$path/$file");
      } elsif ($child->mimeType eq 'audio/mpeg') {  #it's an MP3
        my $id = $child->id;
        print "$path/$file, $id\n";
      } #else ignore the file
    }

    return 1;
}

package main;

Log::Log4perl->easy_init($DEBUG);
my $ftbl = GDFileLookup->new();
$ftbl->printfiles('/practice');

# vi:ai:et:sw=2 ts=2

