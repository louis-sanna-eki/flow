#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/coleorrhyncha/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use HTML_func qw (html_header html_footer);
use Style qw ($conf_file $background $css $jscript_imgs $dblabel);

# Gets parameters
#####################################################################################################################################################################
my $page;
my @argus;

my $dbc = db_connection(get_connection_params($conf_file));

my $jscript = 	"var addonimg = new Image ();
		var addoffimg = new Image ();
		addonimg.src = '/Editor/add1.png';
		addoffimg.src = '/Editor/add0.png';
		var updateonimg = new Image ();
		var updateoffimg = new Image ();
		updateonimg.src = '/Editor/update1.png';
		updateoffimg.src = '/Editor/update0.png';";		


my %headerHash = (

	titre => 'Welcome',
	bgcolor => $background,
	css => $css,
	background => '',
	jscript => $jscript
);

print html_header(\%headerHash),

div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),

div({-class=>'wcenter'},
	
	span({-class=>'textNavy'}, b('Instructions:'),p,
		span({-class=>'comment'},
			"I&nbsp; - Create taxon names from highest rang to lowest",br,br,
			"II - Create Taxon valid names before other related names (synonym, transfer, ...)", br
		)
	),
	
	h3({-class=>'textNavy'},"Select an action:"),p,
									
	a(	{-onMouseover=>"document.adddata.src=eval('addonimg.src')", -onMouseout=>"document.adddata.src=eval('addoffimg.src')", -href=>"typeSelect.pl?action=add&type=all"},
		img({-border=>0, -src=>'/Editor/add0.png', -alt=>'ADD DATA', -name=>'adddata'})
	),
	"&nbsp;",
	a(	{-onMouseover=>"document.updatedata.src=eval('updateonimg.src')", -onMouseout=>"document.updatedata.src=eval('updateoffimg.src')", -href=>"typeSelect.pl?action=update&type=all"},
		img({-border=>0, -src=>'/Editor/update0.png', -alt=>'UPDATE DATA', -name=>'updatedata'})
	)
)
					,
end_form(),

html_footer();

$dbc->disconnect();

exit;
