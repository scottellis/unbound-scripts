#!/usr/bin/perl -T

use warnings;
use strict;

my $log = '/var/log/unbound';

my %noerror;
my %nxdomain;
my %servfail;
my %stats = ( total => { queries => 0, success => 0, block => 0, fail => 0 } );

my @valid_cmds = ('summary', 'hosts', 'failed', 'blocked', 'success');

my $cmd = 'summary';

my $num_args = $#ARGV + 1;

if ($num_args > 0) {
    $cmd = $ARGV[0];

    my $count = grep { /$cmd/ } @valid_cmds;

    if ($count != 1) {
        print("Unknown command: $cmd\n");
        print("\nUsage: blockstats.pl [cmd]\n");
        print("  cmds: all, hosts, failed, blocked, success\n");
        print("  default is all\n");
        exit 1;
    }
}

open(FILE, $log) || die "Could not open $log\n";

while (<FILE>) {
    my @fields = split;

    my $len = scalar(@fields);

    # skip log entries that are not query responses
    next unless $len == 15;

    # skip noscript-csp.invalid, WTF is this?
    # stop these queries on the workstation running Firefox with NoScript
    # e.g. a /etc/hosts entry like this
    # 127.0.0.1  noscript-csp.invalid
    # this line can be removed after that change
    next unless $fields[8] !~ /noscript-csp.invalid/;

    # skip my local domain
    next unless $fields[8] !~ /jumpnow.$/;

    # skip Chrome's non-existent domain requests (no '.' in hostname)
    next unless $fields[8] =~ /\.\w+/;

    $stats{total}{queries}++;

    my $src = $fields[7];

    if (exists($stats{$src})) {
        $stats{$src}{queries}++;
    }
    else {
        $stats{$src} = { queries => 1, success => 0, block => 0, fail => 0 };
    }

    my $dst = $fields[8];
    $dst =~ s/\.$//;

    my $response = $fields[11];

    if ($response eq 'NOERROR') {
        if (exists($noerror{$dst})) {
            $noerror{$dst}++;
        }
        else {
            $noerror{$dst} = 1;
        }

        $stats{total}{success}++;
        $stats{$src}{success}++;
    }
    elsif ($response eq 'NXDOMAIN') {
        if (exists($nxdomain{$dst})) {
            $nxdomain{$dst}++;
        }
        else {
            $nxdomain{$dst} = 1;
        }

        $stats{total}{block}++;
        $stats{$src}{block}++;
    }
    elsif ($response eq 'SERVFAIL') {
        if (exists($servfail{$dst})) {
            $servfail{$dst}++;
        }
        else {
            $servfail{$dst} = 1;
        }

        $stats{total}{fail}++;
        $stats{$src}{fail}++;
    }
    else {
        print("Unhandled response type: $response\n");
    }
}

close(FILE);

sub dump_hosts {
    my $hash = shift;

    if ($cmd eq 'summary') {
        print("\n======== Query Summaries by Host ========\n");
    }

    foreach my $host (sort keys %{$hash}) {
        my $queries = $hash->{$host}{queries};
        my $success = $hash->{$host}{success};
        my $block = $hash->{$host}{block};
        my $fail = $hash->{$host}{fail};

        if ($cmd eq 'summary') {
            print("\n$host\n");
            printf("    Queries: %d\n", $queries);
            printf("    Success: %d (%.1f%%)\n", $success, (100.0 * $success) / $queries);
            printf("    Blocked: %d (%.1f%%)\n", $block, (100.0 * $block) / $queries);
            printf("     Failed: %d (%.1f%%)\n", $fail, (100.0 * $fail) / $queries);
        }
        else {
            print("$host $queries $success $block $fail\n");
        }
    }
}

sub dump_targets {
    my $prompt = shift;
    my $hash = shift;

    my @sorted_targets = sort { $hash->{$b} <=> $hash->{$a} } keys %{$hash};

    if ($cmd eq 'summary') {
        print("\n======== Top 10 $prompt Targets ========\n");

        my $count = 0;

        foreach my $target (@sorted_targets) {
            print("$hash->{$target} $target\n");
            $count++;
            last if ($count == 10);
        }
    }
    else {
        foreach my $target (@sorted_targets) {
            print("$hash->{$target} $target\n");
        }
    }
}

if ($cmd eq 'summary' || $cmd eq 'hosts') {
    dump_hosts(\%stats);
}

if ($cmd eq 'summary' || $cmd eq 'failed') {
    dump_targets('Failed', \%servfail);
}

if ($cmd eq 'summary' || $cmd eq 'blocked') {
    dump_targets('Blocked', \%nxdomain);
}

if ($cmd eq 'summary' || $cmd eq 'success') {
    dump_targets('Success', \%noerror);
}
