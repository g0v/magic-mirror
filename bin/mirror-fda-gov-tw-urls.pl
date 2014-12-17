#!/usr/bin/env perl
use v5.14;
use strict;
use warnings;
use autodie;

use IO::String;
use HTTP::Tiny;
use Getopt::Std;

use File::Copy "copy";
use File::Temp "tempdir"
use File::Path "make_path";
use File::Basename "basename";
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );;

my %opts; getopts("o:", \%opts);

unless ($opts{o}) {
    die;
}
my $real_outdir = $opts{o} . "/fda";
make_path($real_outdir) unless -d $real_outdir;

my $ua = HTTP::Tiny->new;

my $csvBaseUrl = 'http://data.fda.gov.tw/opendata/exportDataList.do?method=ExportData&logType=2&InfoId=';
for my $id (1..74) {
    my $outdir = tempdir( CLEANUP => 1 );
    chdir($outdir);

    my $url = $csvBaseUrl . $id;

    my $response = $ua->get($url);
    die "fetch failed" unless $response->{success};

    if ($response->{headers}{'content-type'} =~ /zip/) {
        my $zip_io = IO::String->new($response->{content});
        
        my $zip = Archive::Zip->new;
        $zip->readFromFileHandle($zip_io);

        my ($member) = $zip->members();
        my $extracted = $zip->extractMemberWithoutPaths($member);
    } else {
        open my $fh, ">", "${id}_2.csv";
        print $fh $response->{content};
        close($fh);
    }

    for my $path (<$outdir/*.csv>) {
        my $filename = basename($path);
        my $real_output = $real_outdir . "/$filename";
        copy($path, $real_outdir);
    }
}
