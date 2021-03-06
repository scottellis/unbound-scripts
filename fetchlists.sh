#!/bin/sh
#
# Works with ksh and bash, but not dash.
#
# Can be run with bash explicitly like this
#
#   $ bash fetchlists.sh
#
# Leaving some intermediary files in /tmp for testing during dev
#

tmpfile=$(mktemp)

blocklist="/tmp/blocklist.conf"

if [ ! -z $1 ]; then
    allowlist=$1
fi

#
# For lists in /etc/hosts format like this
# 127.0.0.1 aaa.com
# 0.0.0.0   bbb.com
#
hosts_format="\
    https://jumpnowtek.com/downloads/doh_servers.txt \
    http://sysctl.org/cameleon/hosts \
    https://adaway.org/hosts.txt \
    https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
    https://raw.githubusercontent.com/BartsPrivacy/PrivacyHostList/master/BlockHosts-Facebook.txt \
    https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/all \
    https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt \
    https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt \
    https://www.github.developerdan.com/hosts/lists/facebook-extended.txt \
    https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt \
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
# Use ftp from base on OpenBSD
# Assume curl on Linux
#
function fetch_and_strip {
    os=$(uname)

    if [ $os == "OpenBSD" ]; then
        ftp -VMo - $1 | sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]*$//'
    elif [ $os == "Linux" ]; then
        curl -s $1 | sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]*$//'
    else
        echo "Unhandled O/S: $os"
        exit 1
    fi
}

function lower_sort_uniq {
    cat $1 | tr '[:upper:]' '[:lower:]' | sort -u
}

#
# Add the canary domain used by Mozilla to check if DOH should be used
#
echo 'use-application-dns.net' >> $tmpfile

for list in $simple_format; do
    echo "Fetching $list"
    fetch_and_strip $list >> $tmpfile
done

#
# Grab the second field in each line from these lists but only if the first
# field is an ipv4 address
#
for list in $hosts_format; do
    echo "Fetching $list"

    fetch_and_strip $list \
        | egrep '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
        | awk '{ print $2 }' \
        >> $tmpfile
done

#
# Sort and remove duplicates
#
# cat $tmpfile | tr '[:upper:]' '[:lower:]' | sort -u > /tmp/blocklist
lower_sort_uniq $tmpfile > /tmp/blocklist

rm -f $tmpfile

#
# If we have an allowlist with some entries, make sure it is lower case
# and sorted then remove those lines from the blocklist
#
if [ -z $allowlist ]; then
    mv /tmp/blocklist /tmp/final

elif [ -f $allowlist ]; then
    count=$(wc -l $allowlist | awk '{ print $1 }')

    if [ $count -gt 0 ]; then
        echo "Removing allowlist items from blocklist"
        # cat $allowlist | tr '[:upper:]' '[:lower:]' | sort -u > /tmp/allowlist
        lower_sort_uniq $allowlist > /tmp/allowlist
        comm -23 /tmp/blocklist /tmp/allowlist > /tmp/final
    fi
fi

#
# Output in unbound.conf format
#
# Possible response types can be found in unbound.conf(5) in the local-zone
# section. Some options are 'static', 'always_nxdomain', 'refuse', 'deny'

cat /tmp/final | awk '{ print "local-zone: \"" $1 "\" always_nxdomain" }' > $blocklist

wc -l $blocklist

exit 0
