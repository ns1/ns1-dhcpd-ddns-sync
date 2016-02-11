#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use LWP::UserAgent;

my %params;
my %leases;

my $ua                = LWP::UserAgent->new (ssl_opts => { verify_hostname => 0 });
my $verbose           = undef;
my $dhcpd_leases_file = "/var/lib/dhcpd/dhcpd.leases";
my $api_key;
my $forward_zone;
my $reverse_zone;

GetOptions (
    "verbose"        => \$verbose,
    "leases-file=s"  => \$dhcpd_leases_file,
    "api-key=s"      => \$api_key,
    "forward-zone=s" => \$forward_zone,
    "reverse-zone=s" => \$reverse_zone
);

$forward_zone =~ s/\.$//;
$reverse_zone =~ s/\.$//;
$reverse_zone =~ s/\.in-addr\.arpa//;

unless (($dhcpd_leases_file) and ($api_key) and ($forward_zone) and ($reverse_zone)) {
    print "Usage: $0 [--verbose] [--leases-file=<file>] --api-key=<key> --forward-zone=<zone> --reverse-zone=<zone>\n\n";
    print "--verbose      Enables verbose output. Default is no output, suitable for use in a crontab.\n";
    print "--leases-file  Overrides the default DHCP server leases file location of $dhcpd_leases_file.\n";;
    print "--api-key      Sets the API key to be used for authenticating to the NS1 API.\n";
    print "--forward-zone Sets the forward DNS zone which should be synchronized with DHCP.\n";
    print "--reverse-zone Sets the reverse DNS zone which should be synchronized with DHCP.\n";

    exit 1;
}

$ua->default_header ('X-NSONE-Key' => $api_key);

print "* Using leases-file=$dhcpd_leases_file\n"          if $verbose;
print "* Using api-key=$api_key\n"                        if $verbose;
print "* Using forward-zone=$forward_zone\n"              if $verbose;
print "* Using reverse-zone=$reverse_zone.in-addr.arpa\n" if $verbose;

my $ip_addr;
my $inside_block;

open (LEASES, $dhcpd_leases_file) or die "Could not open DHCP leases file $dhcpd_leases_file: $!";
while (<LEASES>) {
    $inside_block = 1     if /\{$/;
    $inside_block = undef if /^\}/;
    
    if ($inside_block) {
        if (/^lease/) {
            $ip_addr = (split)[1];
        } elsif (/hardware ethernet/) {
            my $mac_addr = (split)[2];
               $mac_addr =~ s/;//g;
            $leases{$ip_addr}->{"mac_addr"} = $mac_addr;
        } elsif (/client-hostname/) {
            my $hostname = lc ((split ('"'))[1]);
               $hostname =~ s/;//g;
            $leases{$ip_addr}->{"hostname"} = $hostname;
        }
    }
}
close (LEASES);

print "* Retrieving list of records in forward zone $forward_zone\n" if $verbose;
my $response = $ua->get ("https://api.nsone.net/v1/zones/$forward_zone");
die $response->status_line unless $response->is_success;
foreach my $record (split ('"', $response->decoded_content)) {
    if ($record =~ /\.$forward_zone$/) {
        $response = $ua->get ("https://api.nsone.net/v1/zones/$forward_zone/$record/A");
        die $response->status_line unless $response->is_success;
        foreach my $mac_addr (split ('"', $response->decoded_content)) {
            if ($mac_addr =~ /^[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}$/) {
                if (grep { $leases{$_}->{"mac_addr"} eq $mac_addr } keys %leases) {
                    print "Keeping record $record for active lease to $mac_addr\n" if $verbose;
                } else {
                    print "Removing record $record for expired lease to $mac_addr\n" if $verbose;
                    $response = $ua->delete ("https://api.nsone.net/v1/zones/$forward_zone/$record/A");
                    die $response->status_line unless $response->is_success;
                }
            }
        }
    }
}

print "* Retrieving list of records in reverse zone $reverse_zone.in-addr.arpa\n" if $verbose;
$response = $ua->get ("https://api.nsone.net/v1/zones/$reverse_zone.in-addr.arpa");
die $response->status_line unless $response->is_success;
foreach my $record (split ('"', $response->decoded_content)) {
    if ($record =~ /\.$reverse_zone\.in-addr\.arpa$/) {
        $response = $ua->get ("https://api.nsone.net/v1/zones/$reverse_zone.in-addr.arpa/$record/PTR");
        die $response->status_line unless $response->is_success;
        foreach my $mac_addr (split ('"', $response->decoded_content)) {
            if ($mac_addr =~ /^[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}\:[0-9,a-f]{2,}$/) {
                if (grep { $leases{$_}->{"mac_addr"} eq $mac_addr } keys %leases) {
                    print "Keeping record $record for active lease to $mac_addr\n" if $verbose;
                } else {
                    print "Removing record $record for expired lease to $mac_addr\n" if $verbose;
                    $response = $ua->delete ("https://api.nsone.net/v1/zones/$reverse_zone.in-addr.arpa/$record/PTR");
                    die $response->status_line unless $response->is_success;
                }
            }
        }
    }
}

foreach my $ip_addr (sort (keys (%leases))) {
    my $mac_addr = $leases{$ip_addr}->{"mac_addr"};
    my $forward_hostname = $leases{$ip_addr}->{"hostname"} or undef;
    my $reverse_hostname = join (".", reverse (split (/\./, $ip_addr)));
       $reverse_hostname =~ s/\.$reverse_zone//;
    if ($forward_hostname) {
        $response = $ua->put (
            "https://api.nsone.net/v1/zones/$forward_zone/$forward_hostname.$forward_zone/A",
            Content => qq/{"zone":"$forward_zone","domain":"$forward_hostname.$forward_zone","type":"A","meta":{"note":"$mac_addr"},"answers":[{"answer":["$ip_addr"]}]}/
        );
        print "Adding record $forward_hostname.$forward_zone for active lease to $mac_addr\n" if $response->is_success and $verbose;
    }
    $response = $ua->put (
        "https://api.nsone.net/v1/zones/$reverse_zone.in-addr.arpa/$reverse_hostname.$reverse_zone.in-addr.arpa/PTR",
        Content => qq/{"zone":"$reverse_zone.in-addr.arpa","domain":"$reverse_hostname.$reverse_zone.in-addr.arpa","type":"PTR","meta":{"note":"$mac_addr"},"answers":[{"answer":["$ip_addr"]}]}/
    );
    print "Adding record $reverse_hostname.$reverse_zone.in-addr.arpa for active lease to $mac_addr\n" if $response->is_success and $verbose;
}
