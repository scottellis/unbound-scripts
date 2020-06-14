#!/usr/bin/perl -T

use warnings;
use strict;
use Getopt::Long qw(GetOptions);

my %noerror;
my %nxdomain;
my %servfail;
my %stats = ( total => { queries => 0, success => 0, block => 0, fail => 0 } );

my @valid_cmds = ('hosts', 'failed', 'blocked', 'success');

my $cmd = 'hosts';
my $number = 10;
my $verbose = '';

GetOptions('cmd|c=s' => \$cmd, 'number|n=i' => \$number, 'verbose|v' => \$verbose) or die "Bad options\n";

my $valid = grep { /$cmd/ } @valid_cmds;

if ($valid != 1) {
    print("Unknown command: $cmd\n");
    print("\nUsage: blockstats.pl [--cmds=<cmd>] [--number=<number-of-lines>] [--verbose]\n");
    print("  --cmds       all, hosts, failed, blocked, success, default is all\n");
    print("  --number     default is 10\n");
    print("  --verbose    verbose output\n");
    exit 1;
}

while (<>) {
    my @fields = split;

    my $len = scalar(@fields);

    # skip log entries that are not query responses
    next unless $len == 15;

    my $dst = $fields[8];

    # remove trailing period
    $dst =~ s/\.$//;

    next if ($dst =~ /\.jumpnow$/);

    # skip Chrome's non-existent domain requests (no '.' in hostname)
    next unless $dst =~ /\./;

    $stats{total}{queries}++;

    my $src = $fields[7];

    if (exists($stats{$src})) {
        $stats{$src}{queries}++;
    }
    else {
        $stats{$src} = { queries => 1, success => 0, block => 0, fail => 0 };
    }

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

if ($cmd eq 'hosts') {
    dump_hosts(\%stats)
}
elsif ($cmd eq 'failed') {
    dump_targets('Failed', \%servfail);
}
elsif ($cmd eq 'blocked') {
    dump_targets('Blocked', \%nxdomain);
}
elsif ($cmd eq 'success') {
    dump_targets('Success', \%noerror);
}

sub dump_hosts {
    my $hash = shift;

    if ($verbose) {
        print("Summaries by Host\n");
    }

    foreach my $host (sort keys %{$hash}) {
        my $queries = $hash->{$host}{queries};
        my $success = $hash->{$host}{success};
        my $block = $hash->{$host}{block};
        my $fail = $hash->{$host}{fail};

        if ($verbose) {
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

    if ($verbose) {
        print("======== Top $number $prompt Targets ========\n");
    }

    my $count = 0;

    foreach my $target (@sorted_targets) {
        print("$hash->{$target} $target\n");

        if ($number > 0) {
            $count++;
            last if ($count >= $number);
        }
    }
}
