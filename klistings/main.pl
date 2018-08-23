use strict;
use warnings;

use Data::Dumper;
use LWP::Simple qw/ get $ua/;

#Emulate web session as browser so there is no agent error
$ua->agent(
	'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:37.0) Gecko/20100101 Firefox/37.0');

#Turn off output buffering
$| = 1;

#sub regexMatch { #Possible cleaner modulated regex matcher
#	my ($string, $regex) = @_;
#	if ($string =~ $regex) {
#		return $1;
#	}
#}

sub main {

	#Scrape and store html
	my $content = get(
		"https://classifieds.ksl.com//s/FREE/FREE+(items+only,+no+businesses)");

	#Check if scrape was successful and html was stored or end program
	unless ( defined $content ) {
		die "Unreachable url\n";
	}

	#Find listings in html
	if ( $content =~
		m/window.renderSearchSection\(\{\s*listings:\s*\[(\{.*\})\]/ )
	{
		#Store block of listings
		my $listingsXml = $1;

		#Ensure that listings were found and stored
		if ( defined $listingsXml ) {

			#Unescape any escaped characters from html and remove double quotes
			$listingsXml =~ s/\\|\"//g;
			
			#Split listings into array
			my @listings = $listingsXml =~ /\{(.*?)\}/g;

			#Ensure array was populated
			if (@listings) {
				my @formattedListings;
				
				#Loop through each listing in array
				foreach my $listing (@listings) {
					
					#Store all attributes in an array 
					# EXAMPLE attributes:
					#	"title" : "Lawn Mower"
					#	"price" : 1.00
					my @attributes = split /,/, $listing;
					
					#Reinstatiate new temp hash each iteration
					my %listing;
					#Loop through each attribute in array
					foreach my $attribute (@attributes) {
						#Break up attributes by key and value and store in temp hash
						if ( $attribute =~ /(.*):(.*)[;]?/ ) {
							$listing{$1} .= $2;
						}
					}
					#Populate array with each listing stored in hash
					push @formattedListings, \%listing;
				}
				print Dumper @formattedListings;
			}
		}
	}
	else {
		print "\nListings not found.\n";
	}
}

main();
