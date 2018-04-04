#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;
use File::Path qw<make_path>;
use List::Util qw<shuffle>;
use List::MoreUtils qw<apply>;
use Getopt::Long;

my %opts;
GetOptions(\%opts, 'year=n', 'force');

die "$0 --year=NNNN /dir/mirror_repo /dir/flat_repo" if @ARGV < 2;

my ($mirror_repo, $flat_mirror_repo) = apply { s</$><>; } @ARGV[0,1];
my $dataset = $ARGV[2] || "*/*";

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
} sort glob("${mirror_repo}/${dataset}");

@dataset = shuffle(@dataset);

chdir $mirror_repo;

my $ABORT = 0;

for my $dataset (@dataset) {
    last if $ABORT;

    say ">> $dataset->{filename}";

    my $cmd = "git log --format='%H %at' $dataset->{filename}";
    open my $fh, "-|", $cmd;

    while (<$fh>) {
        last if $ABORT;

        chomp;
        my ($sha1, $author_timestamp) = split / /, $_, 2;
        my @t = (gmtime($author_timestamp))[5,4,3,2,1];
        $t[0] += 1900;
        $t[1] += 1;

        if ($opts{year}) {
            last if $t[0] < $opts{year};
            next if $t[0] > $opts{year};
        }

        my $p_dir = sprintf('%04d-%02d-%02d', @t[0,1,2]);
        my $p = sprintf('%02d-%02d', @t[3,4]);

        my $flat_dir = $flat_mirror_repo . "/" . $dataset->{name} . "/" . $p_dir;
        my $flat_file_name =  $flat_dir . "/" . $p . "." . $dataset->{format};

        last if !$opts{force} && -f $flat_file_name;

        say ">> $flat_file_name";
        make_path($flat_dir) unless -d $flat_dir;
        system("git show ${sha1}:$dataset->{filename} > $flat_file_name");

        state $prev_flat_dir;
        if (defined($prev_flat_dir) && $flat_dir ne $prev_flat_dir) {
            chdir($flat_mirror_repo);

            my $fn = $prev_flat_dir =~ s/\A${flat_mirror_repo}\///r;
            $ABORT = commit_once($fn);

            chdir($mirror_repo);
        }
        $prev_flat_dir = $flat_dir;
    }
}

chdir($flat_mirror_repo);
commit_once();


sub commit_once {
    my ($fn) = @_;
    $fn //= "-A";

    my $LOCK = "/tmp/gitlock";
    while(-f $LOCK) {
        sleep(1);
    }
    open(my $fh_lock, ">", $LOCK) or die $!;

    my $ABORT = 0;
    my $rc = system(qw(git add), $fn);
    if ($rc != 0) {
        say "ERROR when running: git add $fn";
        $ABORT = 1;
    } else {
        $rc = system(qw(git commit -a -m flatten --no-edit --author), 'Auto <nobody@somewhere>');
        if ($rc != 0 && (($rc >> 8) != 1)) {
            say "Commit failed: $rc -- $fn";
            $ABORT = 1;
        }
    }
    close($fh_lock);
    unlink($LOCK);
    return $ABORT;
}
