#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;

use FindBin;
use JSON;
use Try::Tiny;
use HTTP::Tiny;
use Path::Tiny qw(path);
use Getopt::Std;
use MCE::Loop;

sub fetch {
    my $url = shift;
    my $retries = 0;
    my $ua = HTTP::Tiny->new;
    my $response;

    while ($retries < 2) {
        $response = $ua->get($url);

        if ($response->{status} == 599) {
            sleep(5 * ($retries += 1));
        } else {
            last;
        }
    }

    return $response ->{success} ? $response->{content} : undef;
}

sub process {
    my ($processor, $content) = @_;
    my $plugin = "$FindBin::Bin/../processor/${processor}";
    my $proc = do "$plugin";

    unless ('CODE' eq ref($proc)) {
        die "$plugin load fail: $@" if $@;
        die "$plugin needs to return a sub.";
    }

    return $proc->($content);
}

sub current_time {
    my (undef, $min, $hour, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;

    return (
        sprintf('%04d%02d%02d', $year, $mon, $mday),
        sprintf('%02d%02d%02d', $hour, $min, 0),
    );
}

sub output_file {
    my ($dir, $collection, $dataset, $format) = @_;
    my ($ymd, $hms) = current_time();
    my $path = path($dir)->child($collection, $dataset, $ymd, $hms, $dataset . '.' . $format);
    $path->parent->mkpath;
    return $path;
}

sub work {
    my ($output_directory, $dataset) = @_;
    my $logprefix = "[$dataset->{collection}::$dataset->{name}]";

    my $content = fetch($dataset->{url});
    if (defined($content)) {
        MCE->say("$logprefix FETCH OK: $dataset->{url}");
    } else {
        MCE->say("$logprefix FETCH FAIL: $dataset->{url}");
    }

    for my $step (@{ $dataset->{workflow} }) {
        my $output = process( $step->{processor}, $content ) or next;

        my $p = output_file(
            $output_directory,
            $dataset->{collection},
            $dataset->{name},
            $step->{format},
        );

        $p->spew($output);
        MCE->say("$logprefix SAVED: $p");
    }
}

sub eq_any {
    my ($str, $arr) = @_;
    for my $s (@$arr) {
        return "1" if $s eq $str;
    }
    return ""
}

sub HELP_MESSAGE {
    die "$0 -c etc/data.json -o /data\n";
}

my %opts;
getopts("vgho:c:j:", \%opts);

unless ($opts{c} && $opts{o}) {
    HELP_MESSAGE();
}
my @names = @ARGV;

my $datasets = JSON->new->utf8->decode( scalar path($opts{c})->slurp );

MCE::Loop::init {
    max_workers => 4, chunk_size => 1
};

mce_loop {
    my $dataset = $_;
    if (!@names || eq_any($dataset->{"name"}, \@names)) {
        try {
            work($opts{o}, $dataset);
        }
        catch {
            MCE->say("[$dataset->{collection}::$dataset->{name}] ERROR: $_");
        }
    }
} @$datasets;
