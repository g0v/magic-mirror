#!/usr/bin/env perl
use v5.14;
use strict;
use FindBin;
use JSON::PP;
use Getopt::Std;

my %opts;
getopts("o:b:", \%opts);

my $json = JSON::PP->new->utf8;

my $base_url = $opts{b} || "http://g0v-data-mirror.gugod.org/";
my @entries;
local $/ = undef;
for my $config (<${FindBin::Bin}/../etc/*.json>) {
    my ($frequency) = $config =~ m!/([^/]+)\.json$!;

    open my $fh, "<", $config;
    my $sites = $json->decode(<$fh>);
    for my $site (@$sites) {
        push @entries, [
            $site->{name},
            $frequency,
            $site->{url},
            $base_url . $site->{output},
            $site->{process} ? $base_url . $site->{process}{output} : "",
        ];
    }
}

use utf8;
my $html = "";
for (@entries) {
    $html .= join "",
        "<h3>$_->[0] $_->[1]</h3>",
        "<ul>",
        qq{<li>原始網址： <a href="$_->[2]">$_->[2]</a></li>},
        qq{<li>本地備份： <a href="$_->[3]">$_->[3]</a></li>},
        qq{<li>整理轉檔： <a href="$_->[4]">$_->[4]</a></li>},
        "</ul>\n";
}

$html = <<"HTML";
<!doctype html>
<html>
    <meta charset="utf-8">
    <head><title>g0v-data mirror</title></head>
    <body>$html</body>
</html>
HTML

if ($opts{o}) {
    open my $fh, ">:utf8", $opts{o};
    say $fh $html;
}
else {
    binmode STDOUT, ":utf8";
    say $html;
}
