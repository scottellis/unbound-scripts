#!/bin/sh
#
# Run with 'verbose' as an argument to see progress
#

tmpfile=$(mktemp)

blocklist="/tmp/blocklist.conf"

verbose=${1:-silent}

#
# List of dns-over-https servers
#
doh_servers="\
    https://jumpnowtek.com/downloads/doh_servers.txt \
" 

#
# For lists in /etc/hosts format like this
# 127.0.0.1 aaa.com 
# 0.0.0.0   bbb.com 
# 
hosts_format="\
    http://sysctl.org/cameleon/hosts \
    https://adaway.org/hosts.txt \
    https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
    https://raw.githubusercontent.com/BartsPrivacy/PrivacyHostList/master/BlockHosts-Facebook.txt \
    https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt \
"

#
# For simple lists with just the domain name 
# 
simple_format="\
    https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt \
    https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt \
    https://mirror1.malwaredomains.com/files/justdomains \
    https://v.firebog.net/hosts/Easyprivacy.txt \
    https://v.firebog.net/hosts/Prigent-Ads.txt \
    https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt \
    https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt \
    https://v.firebog.net/hosts/AdguardDNS.txt \
"

#
# Fetch and strip comments, blank lines and trailing white space
#
function fetch_and_strip {
  ftp -VMo - $1 | \
      sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]*$//'
}

#
# Add canary domain to block DNS over HTTPS (DOH)
#
echo 'use-application-dns.net' >> $tmpfile

for list in $doh_servers; do
    [ $verbose == "verbose" ] && echo "Fetching $list"
    fetch_and_strip $list >> $tmpfile
done


for list in $simple_format; do
    [ $verbose == "verbose" ] && echo "Fetching $list"
    fetch_and_strip $list >> $tmpfile
done

#
# Ugly special cases..., need a whitelist
#
for list in $hosts_format; do
    [ $verbose == "verbose" ] && echo "Fetching $list"
    fetch_and_strip $list \
        | egrep '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
        | awk '{ print $2 }' \
        | egrep -v '^broadcasthost$' \
        | egrep -v '^local$' \
        | egrep -v '^localhost\.localdomain$' \
        | egrep -v '^0\.0\.0\.0$' \
        >> $tmpfile
done


#
# Sort, remove duplicates, then output in unbound.conf format
#
# Possible response types can be found in unbound.conf(5) in the local-zone
# section. Some options are 'static', 'always_nxdomain', 'refuse', 'deny'
#
sort -fu $tmpfile \
    | awk '{ print "local-zone: \"" $1 "\" always_nxdomain" }' \
    > $blocklist


rm -f $tmpfile

[ $verbose == "verbose" ] && echo "Wrote file: $blocklist"

exit 0
