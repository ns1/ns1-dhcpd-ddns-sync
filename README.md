# ns1-dhcpd-ddns-sync
Tool to synchronize NS1 DNS record management with an ISC DHCPD server

## Installation
Create an API key in the NS1 portal if you have not already done so by going to **Account** -> **Settings & Users** -> **Manage API Keys** -> **Add a New Key**.

Create a zone to contain your forward `A` records (`example.com`) and a zone to contain your reverse `PTR` records (`in-addr.arpa`) in the NS1 portal if you have not already done so by going to **Zones** -> **Add a New Zone**.

Copy the `ns1-dhcpd-ddns-sync.pl` script to a suitable location on your DHCP server, such as `/usr/local/bin`.

Add it to root's crontab so it executes frequently, ideally every minute:

`* * * * * /usr/local/bin/ns1-dhcpd-ddns-sync.pl --api-key=<key> --forward-zone=<zone> --reverse-zone=<zone>`
