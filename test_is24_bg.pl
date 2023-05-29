#!/usr/bin/perl
use strict;
use Data::Dumper;
use WWW::Mechanize;
use Storable qw(store);

=head1 NAME

process_data.pl - Script to process real estate data

=head1 SYNOPSIS

process_data.pl [options] <parameter1> <parameter2> <parameter3>

=head1 DESCRIPTION

This script retrieves real estate data from immobilienscout24.de and processes it.

=head1 OPTIONS

No options are currently available.

=head1 PARAMETERS

=over 4

=item <parameter1>

The first parameter.

=item <parameter2>

The second parameter.

=item <parameter3>

The third parameter.

=back

=head1 EXAMPLES

To run the script:

    perl process_data.pl value1 value2 value3

=head1 AUTHOR

Your Name

=cut

my $is24_file = "is24.html";
my $base = "https://www.immobilienscout24.de";

my (%prep_hash, %exp_uri, @list_hash, @file, $pages, $last_page, $cont, $resp, @next_page, $key, %hash);
my $IN = 0;
my $url = 'https://www.immobilienscout24.de/Suche/S-T/Wohnung-Kauf/' . $ARGV[0] . '/' . $ARGV[1] . '/-/' . $ARGV[2] . '';
my $m = WWW::Mechanize->new();
$m->agent('User-Agent=Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.7');

eval {
    $resp = $m->get($url);
    $resp->is_success or die $resp->status_line;
};
if ($@) {
    print "$! Recovered from a GET error\n";
}

$cont = $m->content;

@file = split "\n", $cont;
map {
    s/.*(expose\/\d+).*/$1/gi;
    $exp_uri{$1} = "placeholder";
} grep {
    /expose\/\d+/gi;
} @file;

map {
    m/.*(value="\/Suche)(\s*\S*)/i;
    $pages = substr([split /S-T/, $2]->[1], 0, 5);
    $pages =~ m|P\-\d+|gi && do {
        $last_page = $pages
    };
} grep {
    /option.*/gi;
} @file;

print $last_page . "\n________________________";

my $nmb = sprintf("%d", [split "-", $last_page]->[1]) - 2;

for (0 .. $nmb) {
    $next_page[$_] = join "S-T/P-" . sprintf("%s", $_ + 2), split "S-T", $url;

    eval {
        $resp = $m->get($next_page[$_]);
        $resp->is_success or die $resp->status_line;
    };
    if ($@) {
        print "Recovered from a GET error\n";
    }
    $cont = $m->content;
    map {
        s/.*(expose\/\d+).*/$1/gi;
        $exp_uri{$1} = "placeholder";
    } grep {
        /expose\/\d+/gi;
    } split "\n", $cont;
}

print Dumper keys %exp_uri.
