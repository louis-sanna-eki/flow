#!/usr/bin/perl

use strict;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);

use TaxalifeFonc qw (get_connection_params db_connection request_tab request_hash request_row getTaxonomists);
# utilise DBCommands qui prend comme fonctions
# get_connection_params 
# db_connection 
# request_tab 
# request_hash 
# request_row	




my %genus_label;
my @sortedgl;
my $aut;

# connection à la base nomendb grace aux parametres se trouvant dans nomendb.conf
my $dbconnect = db_connection(get_connection_params("/etc/flow/nomendb.conf"));

# traductions
my $dbc = db_connection(get_connection_params('/etc/flow/entomosite.conf'));
my $traduction = request_hash("SELECT index, fr, en FROM traduction;", $dbc, "index");

# argument lang dans l'url valeurs: en, fr, sp
my $xlang;
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'fr'; }

# récupère tous les noms de genres de nomendb par ordre alpha
my $genus_list = request_tab ("SELECT n.index, orthographe, annee_princeps FROM noms AS n
				LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.rang = 'genre' 
				AND disponibilite = 'disponible' 
				ORDER BY orthographe;", $dbconnect,2);

foreach my $row (@{$genus_list}) {	
	$aut = getTaxonomists ($row->[0],'auteurs');
	my $formatedname = "$row->[1] $aut, $row->[2]";
	$genus_label{$row->[0]} = $formatedname;
	push (@sortedgl,$row->[0]);
}

# creation page web
print header(),

start_html (

	-title => "$traduction->{'taxagenchoice'}->{$xlang}",
	-base   =>'true',
	-authors => 'aodent@hotmail.fr',
	-style  => {'src'=>'/Taxalifedocs/taxalife.css'},
	-head => meta ({-http_equiv => 'Content-Type', 
					-content => 'text/html; charset = iso-8859-15',
					})
),
div({-id=>'header'},img({-src=>'/siteWebEntomo/bandeauFlOW.png', -alt=>"header", -width=>'980px'})),
div({-class=>'centerdiv', -style=>'margin-top: 30px;' },
	a({-href=>url()."?lang=fr"}, img { -src=>'/SiteWebEntomo/fr.png', -border=>0 } ),
        a({-href=>url()."?lang=en"}, img { -src=>'/SiteWebEntomo/en.png', -border=>0 } ),
        #a({-href=>url()."?lang=es"}, img { -src=>'/SiteWebEntomo/sp.png', -border=>0 } )
),

div ({-class=>'centerdiv'},

	start_form(	-method=>'post',
			-action=>"http://silbermann.snv.jussieu.fr/cgi-bin/Taxalife/taxahistory.pl?lang=$xlang",
			-name=>'choiceform'),

	h1("$traduction->{'taxagen_intro'}->{$xlang}"),
	h2("$traduction->{'taxaintro'}->{$xlang}"),
	h3 ("$traduction->{'taxachoice'}->{$xlang}"),
	popup_menu (-class=> 'popup', -name=>'genus_list', -values=> [@sortedgl], -labels=> \%genus_label ), br, br,
			 
	h3 ("$traduction->{'taxaddinfo'}->{$xlang}"),	
	
	div({-style=>'background: transparent; width: 400px; margin: 0 auto;  text-align: left; padding-left: 220px;'},
		checkbox (-name=>'fullhistory', -checked=>1, -value=>1,-label=>"$traduction->{'taxaspehist'}->{$xlang}"), br,
		checkbox (-name=>'abstract', -checked=>1, -value=>1,-label=>"$traduction->{'taxabstract'}->{$xlang}"), br
	), 
	 br,

	a({-class=>'taxaok', -OnClick=>"choiceform.submit();"}),
               
	end_form(),
),

div ({-class=> 'taxaposlien'},
		a( {href=>"http://silbermann.snv.jussieu.fr/cgi-bin/entomoSite.pl?base=FLOW&page=home&lang=$xlang", class=>'lien'}," $traduction->{'taxaflow'}->{$xlang}" )." >> ". 
		a( {href=>"http://silbermann.snv.jussieu.fr/cgi-bin/Taxalife/taxalife.pl?lang=$xlang", class=>'lien'}," $traduction->{'taxahome'}->{$xlang}")." >> ". "$traduction->{'taxagenchoice'}->{$xlang}",
),
	
end_html();

$dbconnect->disconnect();
$dbc->disconnect();


