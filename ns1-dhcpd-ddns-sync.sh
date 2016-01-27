#!/bin/bash

DHCPD_LEASES_FILE="/var/lib/dhcpd/dhcpd.leases"
NS1_API_KEY=$1
FORWARD_DOMAIN=$2
REVERSE_DOMAIN=$3

if [[ "$NS1_API_KEY" == "" ]] || [[ "$DEFAULT_DOMAIN" == "" ]]; then
    echo "Usage: $0 <NS1_API_key> <domain.tld> <rev.in-addr.arpa>"
    echo
    echo "Example: $0 SzZ4yUfHraE3nlFqrVZV example.com 10.in-addr.arpa"
    echo
    echo "Note that <domain.tld> and <rev.in-addr.arpa> are the"
    echo "(existing) domains within NS1 in which DDNS records"
    echo "will be created or destroyed in synchronization with"
    echo "your ISC DHCP server."
    echo
    echo "To activate this script on most Linux distributions,"
    echo "place it somewhere owned by root, and add it to"
    echo "root's crontab with:"
    echo
    echo "* * * * * /path/to/$0 <NS1_API_key> <domain.tld> <rev.in-addr.arpa>"
    echo
    echo "If your dhcpd.leases file does not live at"
    echo "$DHCPD_LEASES_FILE"
    echo "edit this script and adjust the third line accordingly."
    
    exit 1
fi

