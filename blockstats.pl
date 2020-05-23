#!/usr/bin/perl -w

my $log = "/var/log/unbound";

my %noerror;
my %nxdomain;
my %servfail;

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

    my $host = $fields[8];
    $host =~ s/\.$//;

    my $response = $fields[11];

    if ($response eq 'NOERROR') {
        if (exists($noerror{$host})) {
            $noerror{$host}++;
        }
        else {
            $noerror{$host} = 1;
        }
    }
    elsif ($response eq 'NXDOMAIN') {
        if (exists($nxdomain{$host})) {
            $nxdomain{$host}++;
        }
        else {
            $nxdomain{$host} = 1;
        }
    }
    elsif ($response eq 'SERVFAIL') {
        if (exists($servfail{$host})) {
            $servfail{$host}++;
        }
        else {
            $servfail{$host} = 1;
        }
    }
    else {
        print("Unhandled response type: $response\n");
    }
}

close(FILE);

my $success = 0;
my $blocked = 0;
my $failed = 0;

foreach my $host (keys %noerror) {
    $success += $noerror{$host};
}

foreach my $host (keys %nxdomain) {
    $blocked += $nxdomain{$host};
}

foreach my $host (keys %servfail) {
    $failed += $servfail{$host};
}

my $total = $success + $blocked + $failed;

print("\n==== Query Summary ====\n");

print("    Total: $total\n");
printf("  Success: %d (%.1f%%)\n", $success, (100.0 * $success) / $total);
printf("  Blocked: %d (%.1f%%)\n", $blocked, (100.0 * $blocked) / $total);
printf("   Failed: %d (%.1f%%)\n", $failed, (100.0 * $failed) / $total);

print("\n==== Blocked Hosts ====\n");

# sort blocked hosts in count descending order
my @sorted_hosts = sort { $nxdomain{$b} <=> $nxdomain{$a} } keys %nxdomain;

foreach my $host (@sorted_hosts) {
    print("$host : $nxdomain{$host}\n");
}

print("\n");

