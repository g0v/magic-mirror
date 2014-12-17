#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;

use FindBin;
use JSON::PP;
use HTTP::Tiny;
use Getopt::Std;
use File::Basename ("dirname", "basename");
use File::Path "make_path";

sub write_file {
    my ($output_base, $output, $content) = @_;
    my $_output = "${output_base}/$output";
    make_path dirname($_output);
    open my $fh, ">", $_output;
    print $fh $content;
    close $fh;
}

sub read_file {
    local $/ = undef;
    open my $fh, "<", $_[0];
    return <$fh>;
}

sub fetch {
    my $url = shift;
    my $ua = HTTP::Tiny->new;
    my $response = $ua->get($url);
    if ($response->{success}) {
        return $response->{content};
    }

    warn "fetch failed: url = $url";
    return;
}

sub process {
    my ($processor, $content) = @_;
    my $plugin = "$FindBin::Bin/../processor/${processor}";
    my $proc = do "$plugin";

    unless ('CODE' eq ref($proc)) {
        die "$plugin load fail: $@" if $@;
        die "$plugin needs to return a sub.";
    }

    return $proc->($content);
}

sub HELP_MESSAGE {
    print "$0 -c etc/hourly.json -o /data \n";
    exit;
}

my %opts; getopts("gho:c:", \%opts);

if ($opts{c} && $opts{o}) {
    my $sites = JSON::PP->new->utf8->decode( read_file($opts{c}) );

    @$sites = grep { $_->{name} && $_->{url} && $_->{output} } @$sites;

    for (@$sites) {
        my $fetched = fetch($_->{url});
        next unless defined $fetched;

        write_file $opts{o}, $_->{output}, $fetched;

        if ($_->{process}) {
            my $processed = process($_->{process}{processor}, $fetched);
            write_file $opts{o},$_->{process}{output}, $processed;
        }
    }

    if ($opts{g}) {
        my $x = basename($0);

        chdir($FindBin::Bin);
        chomp( my $sha1 = `git log -1 --format='%H' $x` );

        chdir($opts{o});
        system("git add --all");
        system("git commit -m 'autocommit with $x $sha1'");
        system("git pull");
        system("git push");
    }
}
else {
    HELP_MESSAGE();
}
