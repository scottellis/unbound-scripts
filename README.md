### unbound-scripts

A script to fetch, parse and consolidate advertising and malware blocklists and format for use in [unbound(8)][unbound].

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

To monitor effectiveness, enable *extended-statistics* in [unbound.conf(5)][unbound-conf].

    server:
        ...
        extended-statistics: yes
        ...

Then [unbound-control(8)][unbound-control] with a *stats* or *stats_noreset* argument can be used to monitor blocked queries.

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
