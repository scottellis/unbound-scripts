### unbound-scripts

The script *blocklist.sh* will fetch, parse and consolidate [DoH][doh], advertising and malware blocklists and format for use in [unbound(8)][unbound].

There are some example [unbound.conf(5)][unbound-conf] files to assist getting started.

I am using unbound with [OpenBSD][openbsd]. The scripts and configs are not intended to be OpenBSD specific, but it is the only system where I tested.

The *ftp* command in the *blocklist.sh* script will need a replacement (curl, wget) for non-OpenBSD systems.

The blocklists tend to come in one of two formats:

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


The DNS query results show up in */var/log/daemon*

    $ tail -f /var/log/daemon
    ...
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 asset.wsj.net. A IN NOERROR 0.095659 0 134
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 sts3.wsj.net. A IN NOERROR 0.032154 0 94
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. A IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. AAAA IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 ei.marketwatch.com. AAAA IN NOERROR 0.097240 0 172
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 i.mktw.net. AAAA IN NOERROR 0.100135 0 153
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com.jumpnow. AAAA IN NXDOMAIN 0.037228 0 118
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com.jumpnow. A IN NXDOMAIN 0.038150 0 118
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. A IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com. AAAA IN NXDOMAIN 0.000000 1 35
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com.jumpnow. A IN NXDOMAIN 0.000000 1 118
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 fonts.googleapis.com. A IN NOERROR 0.031350 0 54
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 fonts.googleapis.com. AAAA IN NOERROR 0.031760 0 66
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 s.marketwatch.com.jumpnow. AAAA IN NXDOMAIN 0.031728 0 118
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 fonts.gstatic.com. A IN NOERROR 0.033458 0 87
    May 20 16:29:19 black unbound: [79652:0] info: 192.168.10.8 fonts.gstatic.com. A IN NOERROR 0.051703 0 87
    ...


Enable *extended-statistics* in [unbound.conf(5)][unbound-conf] for more summary data.

    server:
        ...
        extended-statistics: yes
        ...


Then [unbound-control(8)][unbound-control] with a *stats* or *stats_noreset* argument to view stats on blocked queries.

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




[unbound]: https://man.openbsd.org/unbound
[unbound-conf]: https://man.openbsd.org/unbound.conf
[unbound-control]: https://man.openbsd.org/unbound-control
[openbsd]: https://openbsd.org
[doh]: https://en.wikipedia.org/wiki/DNS_over_HTTPS
