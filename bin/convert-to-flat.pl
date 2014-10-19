#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;
use File::Path qw<make_path>;
use List::MoreUtils qw<apply>;

my ($mirror_repo, $flat_mirror_repo) = apply { s</$><>; } @ARGV;

sub timestamp_partition {
    my $ts = shift;
    my ($y,$mon,$d,$h,$min) = (gmtime($ts))[5,4,3,2,1];
    $y += 1900;
    $mon += 1;
    return sprintf('%04d/%02d/%02d/%02d/%02d', $y, $mon, $d, $h, $min);
}

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
        my $p = timestamp_partition($author_timestamp);
        my $flat_file_name =  $flat_mirror_repo . "/" . $dataset->{name} . "/" . $p . "." . $dataset->{format};
        my $flat_dir = $flat_file_name =~ s{/\d+?\.$dataset->{format}\z}{}r;

        # say "$dataset->{filename} + $sha1 + $author_timestamp => $flat_file_name";
        make_path($flat_dir) unless -d $flat_dir;
        system("git show ${sha1}:$dataset->{filename} > $flat_file_name");
    }
    close($fh);
}

