#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use URI;
use Web::Query;

sub extract {
    my ($dom, $base_uri, $push) = @_;
    $dom->find(".searchTitle a")->each(
        sub {
            $push->(
                $_->text,
                URI->new_abs($_->attr("href"), $base_uri)
            );
        },

    );
}

my $url = "http://data.gov.tw/opendata/Search?format=ALL";
my $base_uri = URI->new($url);
my $last_page;
my $first_page_dom = wq($url);
$first_page_dom
    ->find(".page_bar a:last-child")
    ->each(
        sub {
            my $href = $_->attr("href");
            $last_page = {
                page_number => $href =~ m!page=(\d+)$!,
                url => URI->new_abs($_->attr("href"), $base_uri)
            };
        }
    );


my @all_links;

extract(
    $first_page_dom,
    $base_uri,
    sub { push @all_links, [@_] }
);

for (my $n = 2; $n <= $last_page->{page_number}; $n++) {
    my $base_uri = URI->new("http://data.gov.tw/opendata/Search?format=ALL&page=" . $n);
    my $dom = wq($base_uri);
    extract($dom, $base_uri, sub { push @all_links, [@_] });
}

for (@all_links) {
    $_->[1] = $_->[1] ."";
}

use JSON::PP;
print JSON::PP->new->pretty->encode(\@all_links);
