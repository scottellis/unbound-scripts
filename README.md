## unbound-scripts

I am using [unbound(8)][unbound] with [OpenBSD][openbsd] to add some advertising and malware blocking at the DNS level to my local network.

The scripts and configs are not intended to be *OpenBSD* specific, but it is the only system where I am testing.

The script *fetchlists.sh* will fetch, parse and consolidate the [DoH][doh], advertising and malware blocklists and format them for use in *unbound*.

If you provide an *allowlist* file as an argument to *fetchlists.sh* it will remove those items from the resulting *blocklist*.

The *fetchlists.sh* script uses the built-in *ftp* on OpenBSD. On Linux *curl* is required.

There are some example [unbound.conf(5)][unbound-conf] files provided.

The blocklists I am using come in one of two formats:

* hosts-file-format: 127.0.0.0 aaa.com or 0.0.0.0 bbb.com
* simple-format: aaa.com

There are two url lists in the script, one for each of the formats.

Place new urls in the appropriate list so they are correctly handled.

**Note:** The default lists probably block more then you want.

The *fetchlists.sh* output eventually gets saved to */tmp/blocklist.conf*.

The output format is

    local-zone: "aaa.com" always_nxdomain

for each entry in the blocklist.

A response type of *static* can be used instead of *always_nxdomain*.
See the *local-zone* section of [unbound.conf(5)][unbound-conf] for details.

It takes only a few seconds to download sources and format a blocklist file.

    scott@black:~$ time blocklist.sh
    Fetching https://jumpnowtek.com/downloads/doh_servers.txt
    Fetching https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
    Fetching https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
    Fetching https://mirror1.malwaredomains.com/files/justdomains
    Fetching https://v.firebog.net/hosts/Easyprivacy.txt
    Fetching https://v.firebog.net/hosts/Prigent-Ads.txt
    Fetching https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-blocklist.txt
    Fetching https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt
    Fetching https://v.firebog.net/hosts/AdguardDNS.txt
    Fetching http://sysctl.org/cameleon/hosts
    Fetching https://adaway.org/hosts.txt
    Fetching https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
    Fetching https://raw.githubusercontent.com/BartsPrivacy/PrivacyHostList/master/BlockHosts-Facebook.txt
    Fetching https://raw.githubusercontent.com/jmdugan/blocklists/master/corporations/facebook/all
    Fetching https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt
    Wrote file: /tmp/blocklist.conf
      179835 /tmp/blocklist.conf
        0m15.30s real     0m06.65s user     0m00.80s system


    scott@black:~$ head -5 /tmp/blocklist.conf
    local-zone: "-rotation.de" always_nxdomain
    local-zone: "-traffic.com" always_nxdomain
    local-zone: "0-act.channel.facebook.com" always_nxdomain
    local-zone: "0-edge-chat.facebook.com" always_nxdomain
    local-zone: "0.0.0.0.beeglivesex.com" always_nxdomain


If satisfied with the result, copy the list to a more permanent location.

On OpenBSD I use */var/unbound/etc/blocklist.conf*.

On *Yocto* built Linux systems I use */etc/unbound/blocklist.conf*.

Then tell [unbound][unbound] to use the list with an [unbound.conf(5)][unbound-conf] include statement.

    server:
        ...
        include: /var/unbound/etc/blocklist.conf
        ...

To monitor effectiveness enable logging

    server:
        ...
        use-syslog: yes
        log-replies: yes
        ...


The DNS query results by default show up in */var/log/daemon*

    $ tail -f /var/log/daemon
    ...
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 asset.wsj.net. A IN NOERROR 0.095659 0 134
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 sts3.wsj.net. A IN NOERROR 0.032154 0 94
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. A IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. AAAA IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 ei.marketwatch.com. AAAA IN NOERROR 0.097240 0 172
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 i.mktw.net. AAAA IN NOERROR 0.100135 0 153
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 fonts.gstatic.com. A IN NOERROR 0.051703 0 87
    ...


The **NXDOMAIN** responses are for the most part from the blocklist, though a few could be real.

For convenience you can isolate the unbound logs to their own file by adding a few lines to [syslog.conf(5)][syslog-conf]

    !!unbound
    *.*							/var/log/unbound
    !*

Then create the file and restart syslogd

    # touch /var/log/unbound
    # rcctl restart syslogd

Add a line to */etc/newsyslog.conf* so [newsyslog(8)][newsyslog] properly rotates the new log file.

Here I am rotating the unbound log when it reaches 2MB and keeping 5 older copies in compressed format.

    /var/log/unbound			640  5     2000 *     Z


After that you can just watch */var/log/unbound*

    scott@black:~$ tail -f /var/log/unbound
    May 23 08:05:09 black unbound: [93172:0] info: 192.168.10.8 b.thumbs.redditmedia.com. A IN NOERROR 0.000000 0 93
    May 23 08:05:09 black unbound: [93172:0] info: 192.168.10.8 b.thumbs.redditmedia.com. AAAA IN NOERROR 0.000000 0 135
    May 23 08:05:09 black unbound: [93172:0] info: 192.168.10.8 a.thumbs.redditmedia.com. A IN NOERROR 0.000000 0 93
    May 23 08:05:09 black unbound: [93172:0] info: 192.168.10.8 a.thumbs.redditmedia.com. AAAA IN NOERROR 0.000000 0 135
    May 23 08:05:32 black unbound: [93172:0] info: 192.168.10.8 slate.com. A IN NOERROR 0.053000 0 91
    May 23 08:05:32 black unbound: [93172:0] info: 192.168.10.8 slate.com. AAAA IN NOERROR 0.062139 0 105
    May 23 08:05:33 black unbound: [93172:0] info: 192.168.10.8 compote.slate.com. AAAA IN NOERROR 0.053126 0 123
    May 23 08:05:33 black unbound: [93172:0] info: 192.168.10.8 compote.slate.com. A IN NOERROR 0.053533 0 81
    May 23 08:05:52 black unbound: [93172:0] info: 192.168.10.8 black.jumpnow. A IN NOERROR 0.001148 0 47
    May 23 08:05:52 black unbound: [93172:0] info: 192.168.10.8 black.jumpnow. AAAA IN NOERROR 0.001160 0 31
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 www.forbes.com. A IN NOERROR 0.066390 0 89
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 www.forbes.com. AAAA IN NOERROR 0.067088 0 131
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 thumbor.forbes.com. A IN NOERROR 0.031400 0 93
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 thumbor.forbes.com. AAAA IN NOERROR 0.048476 0 135
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 specials-images.forbesimg.com. A IN NOERROR 0.062690 0 152
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 specials-images.forbesimg.com. AAAA IN NOERROR 0.062698 0 146
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 i.forbesimg.com. A IN NOERROR 0.053436 0 138
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 blogs-images.forbes.com. A IN NOERROR 0.071396 0 146
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 blogs-images.forbes.com. AAAA IN NOERROR 0.075590 0 140
    May 23 08:06:37 black unbound: [93172:0] info: 192.168.10.8 i.forbesimg.com. AAAA IN NOERROR 0.114647 0 132


You can get some stats from unbound with [unbound-control(8)][unbound-control] with a *stats* or *stats_noreset* argument.

And you can also enable *extended-statistics* in [unbound.conf(5)][unbound-conf].

    server:
        ...
        extended-statistics: yes
        ...

Here is an example

    root@nuc:~# unbound-control stats_noreset | grep num.answer
    num.answer.rcode.NOERROR=180
    num.answer.rcode.FORMERR=0
    num.answer.rcode.SERVFAIL=0
    num.answer.rcode.NXDOMAIN=1078
    num.answer.rcode.NOTIMPL=0
    num.answer.rcode.REFUSED=0
    num.answer.rcode.nodata=16
    num.answer.secure=0
    num.answer.bogus=0


To see a little more of what I am interested in I wrote a small Perl script.

    scott@black:~$ ./blockstats.pl

    ======== Query Summaries by Host ========

    192.168.10.107
        Queries: 7
        Success: 7 (100.0%)
        Blocked: 0 (0.0%)
         Failed: 0 (0.0%)

    192.168.10.11
        Queries: 41
        Success: 41 (100.0%)
        Blocked: 0 (0.0%)
         Failed: 0 (0.0%)

    192.168.10.112
        Queries: 24
        Success: 17 (70.8%)
        Blocked: 7 (29.2%)
         Failed: 0 (0.0%)

    192.168.10.25
        Queries: 614
        Success: 245 (39.9%)
        Blocked: 365 (59.4%)
         Failed: 4 (0.7%)

    192.168.10.8
        Queries: 182
        Success: 162 (89.0%)
        Blocked: 20 (11.0%)
         Failed: 0 (0.0%)

    total
        Queries: 868
        Success: 472 (54.4%)
        Blocked: 392 (45.2%)
         Failed: 4 (0.5%)

    ======== Failed Targets ========
    secure.whatcounts.com : 4

    ======== Blocked Targets ========
    trk.pinterest.com : 30
    vjs.zencdn.net : 18
    www.google-analytics.com : 9
    www.googletagmanager.com : 9
    c.amazon-adsystem.com : 8
    www.googletagservices.com : 8
    connect.facebook.net : 8
    securepubads.g.doubleclick.net : 7
    ib.adnxs.com : 6
    as-sec.casalemedia.com : 6
    ...

    ======== Success Targets ========
    duckduckgo.com : 41
    pool.ntp.org : 36
    fonts.googleapis.com : 11
    icons.duckduckgo.com : 10
    fonts.gstatic.com : 10
    safebrowsing.googleapis.com : 9
    ocsp.pki.goog : 8
    ocsp.digicert.com : 7
    api-global.squareup.com : 7
    www.google.com : 7
    ocsp.int-x3.letsencrypt.org : 6
    push.services.mozilla.com : 6
    ...

Too much data reported by that script right now, but not sure yet how I want to filter so I don't miss the important stuff.


[unbound]: https://man.openbsd.org/unbound
[unbound-conf]: https://man.openbsd.org/unbound.conf
[unbound-control]: https://man.openbsd.org/unbound-control
[openbsd]: https://openbsd.org
[doh]: https://en.wikipedia.org/wiki/DNS_over_HTTPS
[syslog-conf]: https://man.openbsd.org/syslog.conf.5
[newsyslog]: https://man.openbsd.org/newsyslog.conf
