#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;
use File::Path qw<make_path>;
use List::MoreUtils qw<apply>;

my ($mirror_repo, $flat_mirror_repo) = apply { s</$><>; } @ARGV;

my @dataset = map {
    my ($name, $format) = m<\A(.+)\.([a-z]{3,4})\z>;
    +{
        filename => $_,
        name     => $name,
        format   => $format,
    };
} apply {
    s<\A${mirror_repo}><>;
    s<^/><>;                    #// wtfemacs
} sort glob("${mirror_repo}/*/*");

chdir $mirror_repo;

for my $dataset (@dataset) {
    my $cmd = "git log --format='%H %at' $dataset->{filename}";
    open my $fh, "-|", $cmd;
    while (<$fh>) {
        chomp;
        my ($sha1, $author_timestamp) = split / /, $_, 2;
        my @t = (gmtime($author_timestamp))[5,4,3,2,1];
        $t[0] += 1900;
        $t[1] += 1;
        my $p_dir = sprintf('%04d-%02d-%02d', @t[0,1,2]);
        my $p = sprintf('%02d-%02d', @t[3,4]);

        my $flat_dir = $flat_mirror_repo . "/" . $dataset->{name} . "/" . $p_dir;
        my $flat_file_name =  $flat_dir . "/" . $p . "." . $dataset->{format};

        make_path($flat_dir) unless -d $flat_dir;
        system("git show ${sha1}:$dataset->{filename} > $flat_file_name");
    }
    close($fh);
}
