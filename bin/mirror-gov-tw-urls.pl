#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;

use FindBin;
use JSON::PP;
use HTTP::Tiny;
use Getopt::Std;
use File::Basename qw(dirname);

sub write_file {
    my ($output, $content) = @_;
    my $_output = "$FindBin::Bin/../data/$output";

    my $dir = dirname($_output);
    mkdir($dir) unless -d $dir;

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
    my $ua = HTTP::Tiny->new;
    my $response = $ua->get($_[0]);
    die "fetch failed" unless $response->{success};
    return $response->{content};
}

sub HELP_MESSAGE {
    print "$0 -c etc/hourly.json\n";
    exit;
}

my %opts; getopts("hc:", \%opts);

if ($opts{c}) {
    my $sites = JSON::PP->new->utf8->decode( read_file($opts{c}) );

    @$sites = grep { $_->{name} && $_->{url} && $_->{output} } @$sites;

    for (@$sites) {
        write_file $_->{output}, fetch($_->{url});
    }
}
else {
    HELP_MESSAGE();
}
