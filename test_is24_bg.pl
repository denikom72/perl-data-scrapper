use strict;
use Data::Dumper;
use WWW::Mechanize;
use Storable qw(store);

my $is24_file = "is24.html";
my $base = "https://www.immobilienscout24.de";

my ( %prep_hash, %exp_uri, @list_hash, @file, $pages, $last_page, $cont, $resp, @next_page, $key, %hash ); 
my $IN = 0;
my $url = 'https://www.immobilienscout24.de/Suche/S-T/Wohnung-Kauf/'.$ARGV[0].'/'.$ARGV[1].'/-/'.$ARGV[2].'';
my $m = WWW::Mechanize->new();
$m->agent('User-Agent=Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.7');


eval{
	$resp = $m->get($url);
	$resp->is_success or die $resp->status_line;
};
if ($@) {
	print "$! Recovered from a GET error\n";    
}

$cont = $m->content;

@file = split "\n", $cont;
map { 
	s/.*(expose\/\d+).*/$1/gi; $exp_uri{$1} = "placeholder"; 
} grep { 
	/expose\/\d+/gi; 
} @file;

map { 
	m/.*(value="\/Suche)(\s*\S*)/i;
	$pages = substr ( [ split /S-T/, $2 ] -> [1], 0, 5 );
	$pages =~ m|P\-\d+|gi && do { $last_page = $pages };
} grep { 
	/option.*/gi; 
} @file;

print $last_page."\n________________________";

my $nmb = sprintf("%d", [ split "-", $last_page ] -> [1]) - 2;#shorting length for two, cause first url was already called
#print $nmb." NUMBERRRRR\n";

for(0..$nmb){
	#first page is allready loaded, so start from $_ + 2
	$next_page[$_] = join "S-T/P-".sprintf("%s", $_+ 2), split "S-T", $url;

	eval{
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

print Dumper keys %exp_uri;
sleep(4);

my @det_uri = sort keys %exp_uri;
for(0..$#det_uri ){
	my @content;	
	my $uri = $base."/".$det_uri[$_];
	my $exp = $det_uri[$_];
	print $uri."\n";

	eval{
		$resp = $m->get($uri);
		$resp->is_success or die $resp->status_line;
	};
	if ($@) {
		print "Recovered from a GET error\n";    
	}
	$cont = join ">\n<", split />\s*?</, $m->content;
	sleep(1);
	
	for my $line( split /\n/, $cont ){
		#print $line;	
		$line =~ /is24\-ex\-details/i && do { $IN = 1 };

		if($IN == 1){
		
			#my $in_cont = join ">\n<", split />\s*?</i, $line;
			#@content = ( @content, split "\n", $in_cont );	
			push @content, $line;

		}	
		
	}	

	my ( $k, $v ); 
	my $RENT = 0;
	$hash{'Mieteinnahmen'} = 0;

	for(0..$#content){
		
		if(my ($ky) = $content[$_] =~ m/>(.*?)<\/dt/i){
			$k = $ky;
			$ky = "0";
			$k = [ split " ", $k ]-> [0];
			
			$k =~ s/<wbr>//gi;
			$k =~ s/\x{e4}/ae/ig;
			
			if ( $k == "Mieteinnahmen" ){
				 $RENT = 1;
			}
	
		} elsif (my ($vl) = $content[$_] =~ m/>(.*?)<\/dd/i){
			#print $content[$_]."\n";
			$v = $vl;
			$vl = "0";

			print $vl."______".$v."\n";
			$hash{$k} = $v; 
		} 
	}

	print $hash{'Mieteinnahmen'}."--------------------------------------------------------------------------\n";	
	
	my $rent = defined ( $hash{'Mieteinnahmen'} ) && $hash{'Mieteinnahmen'} > 0 ? sprintf("%0.2f", $hash{'Mieteinnahmen'}) : 0;
	$hash{'Mieteinnahmen'} = 0;
	print "\n\nRENT: ".$rent."_____________________________________________".$hash{'Mieteinnahmen'}."\n\n";

	my $area = sprintf("%0.2f", [ split " ", $hash{'Wohnflaeche'} ] -> [0]);
	my $price = sprintf("%.0f", [ split " ", join "", split /\./, $hash{'Kaufpreis'} ] -> [0]);
	
	
	my $rendite = $rent != 0 ? sprintf ("%0.2f", 12 * $rent / $price) : 0;
	my $faktor = $rent != 0 ? sprintf ("%0.2f", $price / 12 / $rent) : 0;		
	my $qmPrice = sprintf ("%0.2f", $price / $area);

	my $city = $ARGV[1];
	
	$prep_hash{'city'} = $city;
	$prep_hash{'uri'} = $uri;
	$prep_hash{'area'} = $area;
	$prep_hash{'rent'} = $rent;
	$rent = 0;
	$prep_hash{'price'} = $price;
	$prep_hash{'rendite'} = $rendite;
	$prep_hash{'faktor'} = $faktor;
	$prep_hash{'qmPrice'} = $qmPrice;
	$prep_hash{'price'} = $price;
	
	print Dumper \%prep_hash;
	print "\n______________\n";
	
	push @list_hash,  { %prep_hash };
	sleep(2);
	
	$prep_hash{'rent'} = undef;
	
}
# USE THIS URIs TO SAMPLE ALL DATA IN A CSV FILE ( every city and room-number has own csv, create new data like m²price immediatelly - and whole his requirements ). 

print Dumper \@list_hash;
open(FILE, '>', 'store.data') or die("couldn't open file store.data: $!");
print FILE Dumper \@list_hash;
close(FILE) or die "$!";

my $str_cont = "";

#make file empty
open(JS, '>', 'store.js') or die("couldn't open file store.data: $!");
print JS $str_cont;
close JS or die("$!");;

open(JS, '>>', 'store.js') or die("couldn't open file store.data: $!");

open(FILE, '<', 'store.data') or die("couldn't open file store.data: $!");
while(<FILE>){
	chomp;
	s/\$VAR1/var testdata/gi;
	s/=>/:/gi;
	print JS;
	print JS "\n";
}

close JS or die("$!");;


