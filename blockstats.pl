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

    # only process record type A
    next LINE if $fields[9] ne 'A';

    # skip noscript-csp.invalid, WTF is this?
    next LINE if ($fields[8] =~ /noscript-csp.invalid/);

    # skip my local lan 
    next LINE if ($fields[8] =~ /jumpnow.$/);

    # skip Chrome's non-existent domain requests 
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

print("  Total: $total\n");
print("Success: $success\n");
print("   Fail: $failed\n");
print("Blocked: $blocked\n");

print("\n==== Blocked Hosts ====\n");
my @sorted_hosts = sort { $nxdomain{$b} <=> $nxdomain{$a} } keys %nxdomain;

foreach my $host (@sorted_hosts) {
    print("$host : $nxdomain{$host}\n");
}

print("\n");

