#!/usr/bin/env perl
#
# perl fetch-data-gov-tw-data-list.pl > /mirror/data-gov-tw-data-list.json
#

use v5.14;
use strict;
use warnings;
use URI;
use URI::QueryParam;

use String::Trim;
use Web::Query;
use JSON::PP;

sub extract_data_detail_links {
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

sub extract_data_urls {
    my ($dom, $base_uri, $push) = @_;
    $dom->find(".format a[href^=addCount]")->each(
        sub {
            my $uri = URI->new_abs($_->attr("href"), $base_uri);
            $push->($uri->query_param("dataformat"), $uri->query_param("url"));
        }
    );
}

sub extract_data_description {
    my ($dom, $base_uri, $push) = @_;
    $dom->find("div.mainData > div")->each(
        sub {
            $push->(
                trim($_->find(".dataTitle")->text),
                trim($_->find(".dataMain")->text)
            );
        }
    );
}

sub fetch_all_data_list_by_oid {
    my $url0 = URI->new("http://data.gov.tw/opendata/List");
    my $dom = wq($url0);

    my %visited_url;
    $visited_url{$url0} = 1;

    my @org;
    my %org_title_by_oid;
    $dom->find("ul.org a")->each(
        sub {
            my $href = $_->attr("href");
            my $title = $_->attr("title");
            my ($oid) = $href =~ m/oid=(.+)\z/;
            my $url = URI->new_abs($href, $url0);
            $org_title_by_oid{$oid} = $title;
            push @org, {
                title => $title,
                oid => $oid,
                url => $url
            };
        },
    );

    for my $o (@org) {
        my ($oid) = $o->{url} =~ m/oid=(.+)\z/;
        my $dom = wq($o->{url});
        $visited_url{$o->{url}} = 1;

        $dom->find(".gov_list a[href*=oid]")->each(
            sub {
                my $href = $_->attr("href");
                my $title = $_->text =~ s!\(\d*\)!!r;
                my ($oid2) = $href =~ m/oid=(.+)\z/;
                my $url = URI->new_abs($href, $o->{url});
                if (!$org_title_by_oid{$oid2}) {
                    say "$title, $oid2";
                    $org_title_by_oid{$oid2} = $title;
                    push @org, {
                        title => $title,
                        oid   => $oid2,
                        url   => $url,
                    };
                }
            },
        );
    }

    return @org;
}

sub fetch_all_data_list {
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
                    url => URI->new_abs($href, $base_uri)
                };
            }
        );

    my @all_data;

    my $push_to_all_links = sub { push @all_data, { title => $_[0], _detail => $_[1] } };

    extract_data_detail_links( $first_page_dom, $base_uri, $push_to_all_links );

    for (my $n = 2; $n <= $last_page->{page_number}; $n++) {
        my $base_uri = URI->new("http://data.gov.tw/opendata/Search?format=ALL&page=" . $n);
        my $dom = wq($base_uri);
        extract_data_detail_links( $dom, $base_uri, $push_to_all_links );
    }

    for my $data (@all_data) {
        my $dom = wq($data->{_detail});

        extract_data_description(
            $dom,
            $data->{_detail},
            sub {
                push @{$data->{description_list}}, {
                    title       => $_[0],
                    description => $_[1],
                };
            }
        );

        extract_data_urls(
            $dom,
            $data->{_detail},
            sub {
                my ($format, $url) = @_;
                $data->{link}{$format} = $url;
            }
        );
    }

    for my $data (@all_data) {
        $data->{_detail} .= "";
        $_ .= "" for values %{$data->{link}};
    }

    return \@all_data;
}

print JSON::PP->new->pretty->canonical->encode(fetch_all_data_list());

# fetch_all_data_list_by_oid();
