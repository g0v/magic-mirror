#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use URI;
use JSON::PP;
use File::Slurp qw(read_file);
use Encode qw(encode_utf8 decode_utf8);
use HTTP::Tiny;

my $JSON = JSON::PP->new->utf8->canonical;

sub report_error {
    my ($error) = @_;
    if ( $error->{response} ) {
        delete $error->{response}{content};
    }
    say STDERR $JSON->encode($error);    
}

my $input = $ARGV[0] or exit(1);

my $list_json = read_file($input);

my $res = JSON::PP->new->utf8->decode($list_json);

my @errors;
my %seen;
my $kDownloadlink = decode_utf8("下載連結");
my $records = $res->{Records};
for (my $i = 0; $i < @$records; $i++) {
    my $record = $records->[$i];
    my $url = encode_utf8($record->{$kDownloadlink});
    my $u = URI->new($url);

    my $uri_scheme = $u->scheme;
    if ($uri_scheme) {
        if ($uri_scheme =~ /\A https? \z/x) {
            $seen{$url} = $record;
        } else {
            report_error({ error => "Unsupported URI scheme.",  record => $record });
        }
    } else {
        report_error({ error => "undefined uri scheme.",  record => $record });
    }
}

for my $url (sort { $a cmp $b } keys %seen) {
    my $http = HTTP::Tiny->new;
    my $response = $http->get($url);
    unless ( $response->{success} ) {
        report_error({ error => "Non-successful http response.",  record => $seen{$url}, response => $response });
    }
}
