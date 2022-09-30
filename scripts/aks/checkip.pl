#!/usr/bin/perl -T
use Net::IP;
use strict;
use warnings;
my $ip = shift 
    or die ("Missing address or network.\n");
$ip =~ m/^([\/\:\.0-9a-fA-F]+)$/
    or die("Bad address or network format.\n");
my $addr = new Net::IP($ip) 
    #or die (Net::IP::Error());
    or die("Bad address or network format.\n");
exit ( 0 );
