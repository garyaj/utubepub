#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: testnetsshany.pl
#
#        USAGE: ./testnetsshany.pl  
#
#  DESCRIPTION: Test Net::SSH::Any
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Gary Ashton-Jones (GAJ), gary@ashton-jones.com.au
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 05/12/2013 16:55:59
#     REVISION: ---
#===============================================================================

use 5.010;

# use Net::SSH::Any;
# my $ssh = Net::SSH::Any->new("ssnfs");
use Net::OpenSSH;
my $ssh = Net::OpenSSH->new("ssnfs");
$ssh->error and
  die "Couldn't establish SSH connection: ". $ssh->error;
# $ssh->scp_put('README.md')
#   or die "Put:$!";
$ssh->scp_get("/data/nfs/ss/www/channel/stmaryssingers/docs.stage/data/Component/SB/page/wood.dat")
  or die "scp_get:$!";
# vi:ai:et:sw=2 ts=2

