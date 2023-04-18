#!/usr/bin/perl

use strict;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);
#use DBCommands qw (get_connection_params db_connection request_tab request_hash request_row);
use DBCommands qw (get_connection_params db_connection request_tab request_hash request_row read_lang);

# argument lang dans l'url valeurs: en, fr, sp
my $xlang;
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'fr'; }

# traductions
#my $dbc = db_connection(get_connection_params('/etc/flow/flowexplorer.conf'));
#my $traduction = request_hash("SELECT index, fr, en FROM traduction;", $dbc, "index");
my $traduction = read_lang(get_connection_params('/etc/flow/flowexplorer.conf'), $xlang);


# creation page web
print header(),

start_html (

	-title => 'TaxaLife',
	-base   =>'true',
	-authors => 'aodent@hotmail.fr',
	-style  => {'src'=>'/Taxalifedocs/taxalife.css'},
	-head => meta ({-http_equiv => 'Content-Type', 
					-content => 'text/html; charset = iso-8859-15',
					})
),
div({-id=>'header'},img({-src=>'/flowdocs/bandeauFLOW.png', -alt=>"header", -width=>'980px'})),

div ({-style => 'position: absolute; top: 11em; left: 2em;'},
		a( {href=>"/cgi-bin/flowsite.pl?base=flow&page=home&lang=$xlang", class=>'taxalifepuce'}," $traduction->{'taxaflow'}->{$xlang}" ), 
		a( {href=>"/cgi-bin/Taxalife/taxagenchoice.pl?lang=$xlang", class=>'taxalifepuce'}," $traduction->{'taxaresearch'}->{$xlang}" )
),

div({-class=>'centerdiv', -style=>'margin-top: 30px;' },
	a({-href=>url()."?lang=fr"}, img { -src=>'/fr.png', -border=>0 } ),
        a({-href=>url()."?lang=en"}, img { -src=>'/en.png', -border=>0 } ),
       # a({-href=>url()."?lang=es"}, img { -src=>'/SiteWebEntomo/sp.png', -border=>0 } ),br,
        h1("$traduction->{'taxawelcome'}->{$xlang}"),
),

div ({-style=>'	text-align: justify; margin-left: auto; margin-right: auto; width: 600px;'},
	"$traduction->{'taxalife_intro'}->{$xlang}", 
),
	
span ({-style=> 'position: absolute; top : 32em; right:4.1em; width: 100px; text-align: justify; font-size:x-small'},
	"$traduction->{'taxatxtposter'}->{$xlang} "
),

span ({-style => 'position: absolute; top: 10.32em; right: 2.6em;'},
	a( {-href=>"/Taxalifedocs/PosterSynonymie.pdf"},img { -src=>'/Taxalifedocs/Poster.jpg', -border=>0 })
), 



end_html();
#$dbc->disconnect();
