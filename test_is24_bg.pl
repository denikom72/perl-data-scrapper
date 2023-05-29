#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use WWW::Mechanize;
use Storable qw(store);

=head1 NAME

is24_data_extraction.pl - Extract data from immobilienscout24.de

=head1 SYNOPSIS

is24_data_extraction.pl [city] [arg1] [arg2]

=head1 DESCRIPTION

This script extracts data from the immobilienscout24.de website for a specific city and command line arguments.

=cut

# POD ends here.

# Store the HTML content in this variable
my $cont;

# Define the URL to scrape data from immobilienscout24.de
my $url = 'https://www.immobilienscout24.de/Suche/S-T/Wohnung-Kauf/'.$ARGV[0].'/'.$ARGV[1].'/-/'.$ARGV[2].'';

# Initialize a WWW::Mechanize object
my $m = WWW::Mechanize->new();
$m->agent('User-Agent=Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.7');

eval {
    my $resp = $m->get($url);
    die $resp->status_line unless $resp->is_success;
    $cont = $m->content;
};
if ($@) {
    print "Recovered from a GET error: $@\n";
}

# Split the content into lines
my @file = split "\n", $cont;

# Extract expose URIs from the content
my %exp_uri;
foreach my $line (@file) {
    if ($line =~ /expose\/(\d+)/gi) {
        $exp_uri{$1} = "placeholder";
    }
}

# Extract the last page number
my $last_page;
foreach my $line (@file) {
    if ($line =~ /option.*value="\/Suche(\s*\S*)/i) {
        my $pages = substr([split /S-T/, $1]->[1], 0, 5);
        if ($pages =~ /P-\d+/gi) {
            $last_page = $pages;
        }
    }
}

print $last_page."\n________________________";

# Calculate the number of pages to scrape
my $nmb = sprintf("%d", [split "-", $last_page]->[1]) - 2;

# Scrape additional pages
my @next_page;
for (0..$nmb) {
    $next_page[$_] = join "S-T/P-".sprintf("%s", $_+2), split "S-T", $url;

    eval {
        my $resp = $m->get($next_page[$_]);
        die $resp->status_line unless $resp->is_success;
        $cont = $m->content;
    };
    if ($@) {
        print "Recovered from a GET error\n";
    }

    # Extract expose URIs from the content of each page
    foreach my $line (split "\n", $cont) {
        if ($line =~ /expose\/(\d+)/gi) {
            $exp_uri{$1} = "placeholder";
        }
    }
}

print Dumper keys %exp_uri;
sleep(4);

# Sort and process expose URIs
my @det_uri = sort keys %exp_uri;
my @list_hash;

foreach my $index (0..$#det_uri) {
    my @content;
    my $uri = $base."/".$det_uri[$index];
    my $exp = $det_uri[$index];
    print $uri."\n";

    eval {
        my $resp = $m->get($uri);
        die $resp->status_line unless $resp->is_success;
        $cont = join ">\n<", split />\s*?</, $m->content;
        sleep(1);
    };
    if ($@) {
        print "Recovered from a GET error\n";
    }

    # Extract relevant content from the page
    my $IN = 0;
    foreach my $line (split /\n/, $cont) {
        $IN = 1 if $line =~ /is24\-ex\-details/i;

        if ($IN == 1) {
            push @content, $line;
        }
    }

    my %hash;
    my $RENT = 0;
    $hash{'Mieteinnahmen'} = 0;

    foreach my $index (0..$#content) {
        if (my ($ky) = $content[$index] =~ m/>(.*?)<\/dt/i) {
            $ky = [split " ", $ky]->[0];
            $ky =~ s/<wbr>//gi;
            $ky =~ s/\x{e4}/ae/ig;

            if ($ky eq "Mieteinnahmen") {
                $RENT = 1;
            }
        }
        elsif (my ($vl) = $content[$index] =~ m/>(.*?)<\/dd/i) {
            $hash{$ky} = $vl;
        }
    }

    my $rent = defined($hash{'Mieteinnahmen'}) && $hash{'Mieteinnahmen'} > 0 ? sprintf("%0.2f", $hash{'Mieteinnahmen'}) : 0;
    $hash{'Mieteinnahmen'} = 0;

    my $area = sprintf("%0.2f", [split " ", $hash{'Wohnflaeche'}]->[0]);
    my $price = sprintf("%.0f", [split " ", join("", split /\./, $hash{'Kaufpreis'})]->[0]);

    my $rendite = $rent != 0 ? sprintf("%0.2f", 12 * $rent / $price) : 0;
    my $faktor = $rent != 0 ? sprintf("%0.2f", $price / 12 / $rent) : 0;
    my $qmPrice = sprintf("%0.2f", $price / $area);

    my $city = $ARGV[1];

    my %prep_hash = (
        'city'    => $city,
        'uri'     => $uri,
        'area'    => $area,
        'rent'    => $rent,
        'price'   => $price,
        'rendite' => $rendite,
        'faktor'  => $faktor,
        'qmPrice' => $qmPrice,
    );

    print Dumper \%prep_hash;
    print "\n______________\n";

    push @list_hash, \%prep_hash;
    sleep(2);

    $prep_hash{'rent'} = undef;
}

print Dumper \@list_hash;

# Store the data in a file
store(\@list_hash, 'store.data');

# Convert the data to JavaScript format for further processing
open(my $js_file, '>', 'store.js') or die("couldn't open file store.js: $!");
print $js_file "";
close $js_file;

open(my $data_file, '<', 'store.data') or die("couldn't open file store.data: $!");
while (<$data_file>) {
    chomp;
    s/\$VAR1/var testdata/gi;
    s/=>/:/gi;
    open($js_file, '>>', 'store.js') or die("couldn't open file store.js: $!");
    print $js_file $_."\n";
    close $js_file;
}

close $data_file or die "$!";

# Pod documentation
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

Denis Komnenović

=cut
