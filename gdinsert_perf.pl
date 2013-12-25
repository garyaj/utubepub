#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: gdinsert_perf.pl
#
#        USAGE: ./gdinsert_perf.pl
#
#  DESCRIPTION: Find insertion point in GD performance directory tree and insert file.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Gary Ashton-Jones (GAJ), gary@ashton-jones.com.au
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 04/12/2013 11:56:02
#     REVISION: ---
#===============================================================================

use 5.010;
use Getopt::Long;
use Config::Tiny;
use Cwd;
use File::Slurp;
use Mojo::DOM;
use Log::Log4perl qw(:easy);
use Net::Google::Drive::Simple;

package GDFileUpload;
# Find and/or create directory for file upload.
# Then upload the file(s)
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

sub share_folder {
    my( $self, $id ) = @_;
    my $url = URI->new( $self->gd->{ api_file_url }.'/'.$id.'/permissions' );
    my $data = $self->gd->http_json( $url, {
        role => 'reader',
        type => 'anyone',
        value => 'me',
    } );
    return 1;
}

sub dir {
  my ($self, $path, $work) = @_;
  my ($id, $children, $parent);
  ($children, $parent) = $self->gd->children("$path/$work");
  if (!$children) {
    ($children, $parent) = $self->gd->children($path);
    $id = $self->gd->folder_create($work, $parent);
    $self->share_folder($id);
    $parent = $id;
  }
  return $parent;
}

package main;

# Get display names
my $dwork;
GetOptions(
  'work=s' => \$dwork,
);
die "Usage: $0 --work work"
  unless $dwork;

Log::Log4perl->easy_init($DEBUG);
my $ftbl = GDFileUpload->new();
my $dir = $ftbl->dir("/performance",$dwork);

my @files = glob("*.mp3");

open(my $fh, ">", "${dwork}_gdid.txt")
  or die "Can't open gdid output file";
#Upload the MP3s into $dir
for my $file (@files) {
  my $id = $ftbl->gd->file_upload($file, $dir);
  print $fh "$file $id\n";
}
close $fh;

# vi:ai:et:sw=2 ts=2

