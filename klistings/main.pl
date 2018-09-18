use strict;
use warnings;
use threads;

use Try::Tiny;
use Data::Dumper;
use Getopt::Std;
use LWP::Simple qw/ get $ua/;
use Email::Simple::Creator;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;

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

#Global variable containing all results found
my @lifetimeResults;

sub main {

	my %opts;
	my $repeatSearch = 60;    #Default search length at 60s

	#Nab paramaters -s and -r and store
	getopts 's:r:', \%opts;
	$repeatSearch = $opts{"r"};

	#Do-While so it executes the first time
	do {
		#Call subroutine to scrape and return stored listings
		my @listings = scrape();

		my @filtered;

		if (@listings) {

	   		#Call subroutine to filter listings based on search regex from parameters
			@filtered = filter( \@listings, $opts{"s"} );

			#Check for any results
			if ( !@filtered ) {
				print "\nNo new matches at this time.\n";
			}
			else {
				#Print results and add to lifetimeResults
				print Dumper @filtered;
				push @lifetimeResults, @filtered;

				#Send email in new thread of found results
				my $emailThread = threads->create( \&sendEmail, \@filtered );
				$emailThread->detach;
			}
		}

		#Wait given amount of seconds
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

	#Store passed parameters
	my ( $listings, $regexSearches ) = @_;

	my @filtered;

	foreach my $listing (@$listings) {

		#Search for passed regex in title or description in each listing
		if (   $listing->{"title"} =~ /$regexSearches/i
			|| $listing->{"description"} =~ /$regexSearches/i )
		{
			#Skip if listing was already found before
			if ( isDupe($listing) == 1 ) {
				push @filtered, $listing;
			}
		}
	}
	return @filtered;
}

sub isDupe {

	#Store passed parameter
	my $listing = shift;

	#Check ID against those in lifetimeResults to ensure this is a new found listing
	foreach my $result (@lifetimeResults) {
		if ( $listing->{"id"} == $result->{"id"} ) {
			return 0;
		}
	}
	return 1;
}

sub sendEmail {
	my $listings = shift;
	my $body     = "";

	foreach my $listing (@$listings) {
		$body =
		  $body . "https://classifieds.ksl.com/listing/$listing->{'id'}\n";
	}

	my $transport = Email::Sender::Transport::SMTP::TLS->new(
		host     => 'smtp.gmail.com',
		port     => 587,
		username => 'klistingsnotifications@gmail.com',
		password =>
'bK=nJ&c@YbTcQ6-Ld^SFJPt!P*EHBV*akC9!k6mZQ7L$SV6eJxr8EvXP8nRdK7r=6Ddh6YUN%7tS?t3M&dfF^RRZXa_CLcm6cX3L',
	);
	my $message = Email::Simple->create(
		header => [
			From    => 'klistingsnotifications@gmail.com',
			To      => 'katsnkubes@gmail.com, christina.a.whitmer@gmail.com',
			Subject => 'New Results',
		],
		body => $body,
	);
	try {
		sendmail( $message, { transport => $transport } );
	}
	catch {
		print "Error sending email: $_";
	}
}

main();
