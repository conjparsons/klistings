use strict;
use warnings;

use Data::Dumper;
use Getopt::Std;
use LWP::Simple qw/ get $ua/;

#Emulate web session as browser so there is no agent error
$ua->agent(
	'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:37.0) Gecko/20100101 Firefox/37.0');

#Turn off output buffering
$| = 1;

=pod 
#Possible cleaner modulated regex matcher
sub regexMatch { 
	my ($string, $regex) = @_;
	if ($string =~ $regex) {
		return $1;
	}
}
=cut

my @lifetimeResults;

sub main {

	my %opts;
	my $repeatSearch = 10; 

	getopts 's:r:', \%opts;

	$repeatSearch = $opts{"r"};

	do {
		
		my @listings = scrape();

		my @filtered = filter( \@listings, $opts{"s"} );

		unless (@filtered) {
			print "\nNo new matches at this time.\n";
		}

		print Dumper @filtered;
		push @lifetimeResults, @filtered;
		
		print "Waiting $repeatSearch seconds......\n";
		sleep $repeatSearch;

	  } while (1);

}

sub scrape {

	#Scrape and store html
	#	-Allow user to define URL in future
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

				#print Dumper @formattedListings;

				return @formattedListings;
			}
		}
	}
	else {
		die "\nListings not found.\n";
	}
}

sub filter {
	my ( $listings, $regexSearches ) = @_;

	my @filtered;

	foreach my $listing (@$listings) {
		if (   $listing->{"title"} =~ /$regexSearches/i
			|| $listing->{"description"} =~ /$regexSearches/i )
		{
			if (isDupe($listing) == 1) {
				push @filtered, $listing;
			}
		}
	}

	return @filtered;
}

sub isDupe {
	my $listing = shift;
	
	foreach my $result (@lifetimeResults) {
		if ($listing->{"id"} == $result->{"id"}) {
			return 0;
		}
	}
	return 1;
}

main();
