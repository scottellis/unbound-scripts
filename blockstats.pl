#!/usr/bin/perl -w
#
# %stats is a hash of hashes with the following structure
#
# $stats{host_ip or 'total'}{ 'queries' => <count>,
#                             'success' => <count>,
#                             'block' => <count>,
#                             'fail' => <count> }

my $log = "/var/log/unbound";

my %noerror;
my %nxdomain;
my %servfail;
my %stats = ( total => { queries => 0, success => 0, block => 0, fail => 0 } );

open(FILE, $log) || die "Could not open $log\n";

LINE: while (<FILE>) {
    my @fields = split;

    my $len = scalar(@fields);

    # skip log entries that are not query responses
    next LINE if $len != 15;

    # skip noscript-csp.invalid, WTF is this?
    # stop these queries on the workstation running Firefox with NoScript
    # e.g. a /etc/hosts entry like this
    # 127.0.0.1  noscript-csp.invalid
    # this line can be removed after that change
    next LINE if ($fields[8] =~ /noscript-csp.invalid/);

    # skip my local domain
    next LINE if ($fields[8] =~ /jumpnow.$/);

    # skip Chrome's non-existent domain requests (no '.' in hostname)
    next LINE if ($fields[8] !~ /\.\w+/);

    $stats{'total'}{'queries'}++;

    my $src = $fields[7];

    if (exists($stats{$src})) {
        $stats{$src}{'queries'}++;
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

        $stats{'total'}{'success'}++;
        $stats{$src}{'success'}++;
    }
    elsif ($response eq 'NXDOMAIN') {
        if (exists($nxdomain{$dst})) {
            $nxdomain{$dst}++;
        }
        else {
            $nxdomain{$dst} = 1;
        }

        $stats{'total'}{'block'}++;
        $stats{$src}{'block'}++;
    }
    elsif ($response eq 'SERVFAIL') {
        if (exists($servfail{$dst})) {
            $servfail{$dst}++;
        }
        else {
            $servfail{$dst} = 1;
        }

        $stats{'total'}{'fail'}++;
        $stats{$src}{'fail'}++;
    }
    else {
        print("Unhandled response type: $response\n");
    }
}

close(FILE);

print("\n==== Host Query Summaries ====\n");

foreach my $host (sort keys %stats) {
    my $queries = $stats{$host}{'queries'};
    my $success = $stats{$host}{'success'};
    my $block = $stats{$host}{'block'};
    my $fail = $stats{$host}{'fail'};

    print("\n$host\n");
    printf("    Queries: %d\n", $queries);
    printf("    Success: %d (%.1f%%)\n", $success, (100.0 * $success) / $queries);
    printf("    Blocked: %d (%.1f%%)\n", $block, (100.0 * $block) / $queries);
    printf("     Failed: %d (%.1f%%)\n", $fail, (100.0 * $fail) / $queries);
}

print("\n==== Blocked Targets ====\n\n");

# sort blocked targets in count descending order
my @sorted_hosts = sort { $nxdomain{$b} <=> $nxdomain{$a} } keys %nxdomain;

foreach my $host (@sorted_hosts) {
    print("$host : $nxdomain{$host}\n");
}

print("\n==== Failed Targets ====\n\n");

# sort failed targets in count descending order
@sorted_hosts = sort { $servfail{$b} <=> $servfail{$a} } keys %servfail;

foreach my $host (@sorted_hosts) {
    print("$host : $servfail{$host}\n");
}

print("\n");

