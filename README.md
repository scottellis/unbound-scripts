## unbound-scripts

I am using [unbound(8)][unbound] with [OpenBSD][openbsd] to add some advertising and malware blocking at the DNS level to my local network.

The scripts and configs are not intended to be *OpenBSD* specific, but it is the only system where I am testing.

The script *blocklist.sh* will fetch, parse and consolidate the [DoH][doh], advertising and malware blocklists and format them for use in *unbound*.

The *ftp* command in the *blocklist.sh* script will need a replacement (probably curl, wget) for non-OpenBSD systems.

There are some example [unbound.conf(5)][unbound-conf] files provided. 

The blocklists I am using tend to come in one of two formats:

* host-format: 127.0.0.0 aaa.com or 0.0.0.0 bbb.com
* simple-format: aaa.com

There are three url lists in the script.

Place new urls in the appropriate list so they are correctly handled.

The script output gets saved to */tmp/blocklist*.

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


If satisfied with the result, copy the list to a more permanent location. I use */var/unbound/etc/blocklist.conf*.

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
    ==== Host Query Summaries ====
    
    192.168.10.11
        Queries: 48
        Success: 42 (87.5%)
        Blocked: 0 (0.0%)
         Failed: 6 (12.5%)

    192.168.10.112
        Queries: 625
        Success: 487 (77.9%)
        Blocked: 127 (20.3%)
         Failed: 11 (1.8%)

    192.168.10.221
        Queries: 8
        Success: 8 (100.0%)
        Blocked: 0 (0.0%)
         Failed: 0 (0.0%)

    192.168.10.8
        Queries: 6736
        Success: 5625 (83.5%)
        Blocked: 726 (10.8%)
         Failed: 385 (5.7%)

    192.168.10.90
        Queries: 186
        Success: 174 (93.5%)
        Blocked: 0 (0.0%)
         Failed: 12 (6.5%)

    total
        Queries: 7603
        Success: 6336 (83.3%)
        Blocked: 853 (11.2%)
         Failed: 414 (5.4%)

    ==== Blocked Targets ====
    
    www.googletagmanager.com : 236
    use.typekit.net : 102
    googleads.g.doubleclick.net : 99
    vjs.zencdn.net : 54
    ssc.api.bbc.com : 30
    c.betrad.com : 20
    fls-na.amazon.com : 20
    sb.scorecardresearch.com : 20
    app-measurement.com : 19
    www.myfinance.com : 18
    www.googleadservices.com : 16
    cloudfront-us-east-1.images.arcpublishing.com : 16
    pixiedust.buzzfeed.com : 12
    www.facebook.com : 11
    alb.reddit.com : 10
    fm.cnbc.com : 10
    www.google-analytics.com : 9
    adservice.google.com : 9
    i.clean.gg : 8
    _http._tcp.security.ubuntu.com : 8
    assets.adobedtm.com : 8
    _http._tcp.dl.google.com : 8
    dashboard.tinypass.com : 7
    mps.cnbc.com : 7
    x-default-stgec.uplynk.com : 6
    s.skimresources.com : 6
    ad.doubleclick.net : 6
    cdn.adligature.com : 6
    piwik.ssrn.com : 6
    k.intellitxt.com : 4
    static.doubleclick.net : 4
    ecdn.firstimpression.io : 4
    ecdn.analysis.fi : 4
    api-cdn.embed.ly : 4
    secure.quantserve.com : 4
    platform-api.sharethis.com : 4
    apps.shareaholic.com : 4
    eepurl.com : 4
    facebook.com : 4
    contextual.media.net : 3
    instagram.fbed1-2.fna.fbcdn.net : 3
    connect.facebook.net : 2
    graph.instagram.com : 2
    unix-school.blogspot.in : 2
    js-agent.newrelic.com : 2
    jsc.mgid.com : 2
    cdn.appdynamics.com : 2
    resources.infolinks.com : 2
    p2-aowfwwrqfrjv6-sl672iw4vjkoqfyg-if-v6exp3-v4.metric.gstatic.com : 1
    img.en25.com : 1
    4968236.fls.doubleclick.net : 1
    beacons.gcp.gvt2.com : 1
    13.111.102.109.in-addr.arpa : 1
    21.143.101.141.in-addr.arpa : 1

    ==== Failed Targets ====

    push.services.mozilla.com : 112
    webql-redesign.cnbcfm.com : 80
    www.bbc.com : 36
    news.ycombinator.com : 36
    safebrowsing.googleapis.com : 25
    support.mozilla.org : 24
    ocsp.pki.goog : 24
    shavar.services.mozilla.com : 16
    android.googleapis.com : 9
    audio-sv5-t1-2-v4v6.pandora.com : 8
    lists.yoctoproject.org : 8
    www.netflix.com : 7
    www.fuelcdn.com : 6
    pool.ntp.org : 6
    t1-4.p-cdn.us : 4
    quote.cnbc.com : 4
    fonts.gstatic.com : 2
    www.google.com : 2
    mtalk4.google.com : 2
    clientservices.googleapis.com : 2
    google.com : 1


Those 'Failed Targets' are mainly the result of an internet interruption while I was testing.


[unbound]: https://man.openbsd.org/unbound
[unbound-conf]: https://man.openbsd.org/unbound.conf
[unbound-control]: https://man.openbsd.org/unbound-control
[openbsd]: https://openbsd.org
[doh]: https://en.wikipedia.org/wiki/DNS_over_HTTPS
[syslog-conf]: https://man.openbsd.org/syslog.conf.5
[newsyslog]: https://man.openbsd.org/newsyslog.conf
