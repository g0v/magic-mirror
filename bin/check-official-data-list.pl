#!/usr/bin/env perl
use v5.18;
use strict;
use warnings;

use URI;
use JSON::PP;
use File::Slurp qw(read_file);
use Encode qw(encode_utf8 decode_utf8);

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

    if ($u->scheme) {
        $seen{$url} = 1;
    } else {
        push @errors, {
            reason => "undefined uri scheme",
            record => $record,
        }
    }
}

my $JSON = JSON::PP->new->utf8->canonical;
for (@errors) {
    say $JSON->encode($_);
}

# for my $url (sort { $a cmp $b } keys %seen) {
#     say $url;
# }
