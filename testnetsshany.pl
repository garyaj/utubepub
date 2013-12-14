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

use Net::SSH::Any;
my $ssh = Net::SSH::Any->new("ssnfs");
$ssh->system("ls -l");
# vi:ai:et:sw=2 ts=2

