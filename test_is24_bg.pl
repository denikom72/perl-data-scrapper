use strict;
use Data::Dumper;
use WWW::Mechanize;
use Storable qw(store);

my $is24_file = "is24.html";
my $base = "https://www.immobilienscout24.de";

my ( %prep_hash, %exp_uri, @list_hash, @file, $pages, $last_page, $cont, $resp, @next_page, $key, %hash ); 
my $IN = 0;
#my $url = 'https://www.immobilienscout24.de/Suche/S-T/Wohnung-Kauf/Nordrhein-Westfalen/Bonn/-/2,00-2,50';
my $url = 'https://www.immobilienscout24.de/Suche/S-T/Wohnung-Kauf/'.$ARGV[0].'/'.$ARGV[1].'/-/'.$ARGV[2].'';
#print $url; die();
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

#while(split $cont, "\n"){
#	print;
#}

#open(FILE, $is24_file) or die "$!\n";
#@file = <FILE>;
#chomp @file;

@file = split "\n", $cont;
map { 
	s/.*(expose\/\d+).*/$1/gi; $exp_uri{$1} = "placeholder"; 
} grep { 
	/expose\/\d+/gi; 
} @file;

#print Dumper keys %exp_uri;
map { 
	m/.*(value="\/Suche)(\s*\S*)/i;
	$pages = substr ( [ split /S-T/, $2 ] -> [1], 0, 5 );
	$pages =~ m|P\-\d+|gi && do { $last_page = $pages };
} grep { 
	/option.*/gi; 
} @file;

print $last_page."\n________________________";

#
#map {
#	s/.*(expose\/\d+).*/$1/gi;
#	$exp_uri{$1} = "placeholder";
#} grep { 
#	/expose\/\d+/gi;
#} @file;

#print Dumper keys %exp_uri;

my $nmb = sprintf("%d", [ split "-", $last_page ] -> [1]) - 2;#shorting length for two, cause first url was already called
#print $nmb." NUMBERRRRR\n";

for(0..$nmb){
	#first page is allready loaded, so start from $_ + 2
	$next_page[$_] = join "S-T/P-".sprintf("%s", $_+ 2), split "S-T", $url;

	#print $next_page[$_]." URISSSSSS\n";

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
	#print $cont;die();	
	#$cont = "foo\nbar";
	for my $line( split /\n/, $cont ){
		#print $line;	
		$line =~ /is24\-ex\-details/i && do { $IN = 1 };

		if($IN == 1){
			#put new lines betwen two tags
			
			#my $in_cont = join ">\n<", split />\s*?</i, $line;
			#@content = ( @content, split "\n", $in_cont );	
			push @content, $line;

		}	
		
	}	
	
#	open(my $OP, "<", \$m->content) or die "Try to open \$content, but: $!\n";
#	while(<$OP>){
#		chomp;
#		/is24\-ex\-details/gi && do { $IN = 1 };
#		#print;
#		if($IN == 1){
#			#put new lines betwen two tags
#			
#			$cont = join ">\n<", split />\s*?</;
#			@content = ( @content, split "\n", $cont );		
#		}	
#	}
#	close($OP) or die $!."\n";
	
	#print Dumper @content; die();

	my ( $k, $v ); 
	my $RENT = 0;
	$hash{'Mieteinnahmen'} = 0;


#	open(CHECK, ">>", 'checker.txt');
#	print CHECK Dumper \@content;
#	close(CHECK);

	#BRK: {


	for(0..$#content){
		
		if(my ($ky) = $content[$_] =~ m/>(.*?)<\/dt/i){
			$k = $ky;
			$ky = "0";
			#$1 = undef;
			$k = [ split " ", $k ]-> [0];
			
			$k =~ s/<wbr>//gi;
			#HEXA SHOULD NOT BE MASK IN A REGEX-SUBST. SO LONG IT IS A PART OF A VAR-VALUE. BUT AS A SIMPLE ASCII-TEXT-STRING SHOULD BE MASK
			$k =~ s/\x{e4}/ae/ig;
			
			if ( $k == "Mieteinnahmen" ){
				 $RENT = 1;
			}

			#switch($key){
			#	case // { }
			#}
	
		} elsif (my ($vl) = $content[$_] =~ m/>(.*?)<\/dd/i){
			#print $content[$_]."\n";
			$v = $vl;
			$vl = "0";

			print $vl."__________________________XXXXXXXXXXXXXXXXXXXXXXXXXXX".$v."\n";
			$hash{$k} = $v; 
			
			
				
			#if($k == "Mieteinnahmen" && $RENT != 0){
			#	$hash{$k} = $v;
				#$k = "";
			#	$RENT = 0;
				#print "\n____________HEY_____________\n";
			#} else {
			#	$hash{$k} = $v;
			#}
			
		} 
		#else {
		#	last BRK;
		#}
	#}
	}

	print $hash{'Mieteinnahmen'}."--------------------------------------------------------------------------\n";	
	
	#print Dumper \%hash; print "\n_____________________________\n";
	
	#the part with \ just ovewriting old values, so use [] for making a ref
	#push @list_hash,  \%hash;
	#( my $rent = $hash{'Mieteinnahmen'} ) =~ s/\.//gi;	

	# separate just the numeric part and round + parse with sprintf	
	my $rent = defined ( $hash{'Mieteinnahmen'} ) && $hash{'Mieteinnahmen'} > 0 ? sprintf("%0.2f", $hash{'Mieteinnahmen'}) : 0;
	$hash{'Mieteinnahmen'} = 0;
	print "\n\nRENT: ".$rent."_____________________________________________".$hash{'Mieteinnahmen'}."\n\n";
	#$hash{'Mieteinnahmen'} = undef;
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

	print "\n_____________________________\n";
	
	push @list_hash,  { %prep_hash };
	sleep(2);
	#print Dumper \@list_hash; die();
	
	$prep_hash{'rent'} = undef;
	
	
#	map { 
	#		s/.*(expose\/\d+).*/$1/gi; $exp_uri{$1} = "placeholder"; 
	#	} grep { 
	#		/expose\/\d+/gi; 
	#	} split "\n", $cont;
	
}
# USE THIS URIs TO SAMPLE ALL DATA IN A CSV FILE ( every city and room-number has own csv, create new data like m²price immediatelly - and whole his requirements ). 


print Dumper \@list_hash;
open(FILE, '>', 'store.data') or die("couldn't open file store.data: $!");
print FILE Dumper \@list_hash;
close(FILE) or die "$!";


#open(FILE, '<', 'store.data') or die("couldn't open file store.data: $!");
#############CREATE JSON FILE ---- WAS SEPARATE SMALL SCRIPT DURING TESTS, NOW INTEGRATED BUT SHOULD BE EXPORTED AGAIN BY NORAMLISATION PROCESS#####

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


