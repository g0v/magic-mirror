#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;

unless (@ARGV == 2) {
    print "$0 processor/uv-xml-to-json /data/mirror/uv.xml \n";
    exit;
}

my ($processor, $data_file) = @ARGV;

die "$processor does not exist" unless -f $processor;
die "$data_file does not exist" unless -f $data_file;


open my $data_fh, "<", $data_file;
my $data_content = do { local $/; <$data_fh> };

my $proc = do $processor;
my $processed_content = $proc->($data_content);
print $processed_content;

