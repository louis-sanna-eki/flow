#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use Conf qw ($conf_file $css $dblabel html_header html_footer);

# Gets parameters
#####################################################################################################################################################################
my $page;
my @argus;

my $dbc = db_connection(get_connection_params($conf_file));

my %headerHash = (
	titre => 'Welcome',
	css => $css
);

my $maintitle = table({-style=>'width: 1000px; margin: 4% auto 2% auto;'}, Tr(td({-style=>'width: 200px; font-size: 20px; font-style: italic; font-weight: bold;'}, "$dblabel editor")));

print html_header(\%headerHash),

	$maintitle,
	div({-class=>'wcenter'},
		table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'font-size: 18px; font-style: italic;'},"Instructions"),
			)
		), p,
		span(
			"I&nbsp; - Insert names from the highest rank", p,
			"II - Insert valid name before synonyms"
		), p, br,
		table({-cellspacing=>0, cellpadding=>0}, 
			Tr( 
				td({-style=>'padding-right: 100px;'}, a({-style=>'text-decoration: none;', -href=>"typeSelect.pl?action=insert&type=all"}, img({-border=>0, -src=>'/Editor/insert.png'}) ) ),
				td( a({-href=>"typeSelect.pl?action=update&type=all", -style=>'text-decoration: none;'}, img({-border=>0, -src=>'/Editor/update.png'}) ) )
			)
		)
	),
	end_form(),
	html_footer();

$dbc->disconnect();
exit;
