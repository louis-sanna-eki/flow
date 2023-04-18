#!/usr/bin/perl

use strict;
use CGI qw (-no_xhtml :standard);
use CGI::Carp qw (fatalsToBrowser warningsToBrowser);

use DBCommands qw (get_connection_params db_connection request_tab request_hash request_row);
# utilise DBCommands qui prend comme fonctions
# get_connection_params 
# db_connection 
# request_tab 
# request_hash 
# request_row	

#background-color:red;
#color:white;

my $css= " .option {
font-family:'trebuchet ms',sans-serif;
font-size : 10pt;
}

.italique {
font-style : italic;
}

.titrecat1 {
font-family:'trebuchet ms',sans-serif;
font-size : 20pt;
font-weight:bold;
}

.titrecat2 {
font-family:'trebuchet ms',sans-serif;
font-size : 15pt;
font-weight:bold;
}

.titrecat3 {
font-family:'trebuchet ms',sans-serif;
font-size : 10pt;
font-weight:bold;
}
.point {
border:2px outset red;
font-weight:bold;
cursor:pointer;
border : outset 1px ;
}

.point:hover {
background-color:white;
color:red;
}

.point:active {
border:2px inset red;
background-color:red;
color:white;
} 

";

my %genus_label;
my @sortedgl;
my $aut;
my $gid;
my  $JSCRIPT= "function index() {
			parent.bottom.document.write ($gid);
		}";

# connection à la base nomendb grace aux parametres se trouvant dans nomendb.conf
my $dbconnect = db_connection(get_connection_params("/etc/flow/nomendb.conf"));

# récupère tous les noms de genres de nomendb par ordre alpha
my $genus_list = request_tab ("SELECT n.index, orthographe, annee_princeps FROM noms AS n
				LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.rang = 'genre' AND disponibilite = 'disponible' ORDER BY orthographe;", $dbconnect,2);

foreach my $row (@{$genus_list}) {	
	$aut = getTaxonomists ($row->[0],'auteurs');
	my $formatedname = "$row->[1] $aut, $row->[2]";
	$genus_label{$row->[0]} = $formatedname;
	push (@sortedgl,$row->[0]);
}

# creation page web
print header();

print start_html (	
	-title => 'Taxalife',
	-script =>$JSCRIPT,
	-authors => 'aodent@hotmail.fr',
	-style=>{'-code'=>$css},
	-head => meta ({-http_equiv => 'Content-Type', 
					-content => 'text/html; charset = iso-8859-15',
					}),
	-BGCOLOR => 'Moccasin',
	
	
);


print start_form();

print table({-border=> 0, cellspacing=>'10px', width=> '100%'},
			
		Tr([
			  
			  td ({-align=> 'center', -class=> 'titrecat1'},"Bienvenue sur TaxaLife"),
			  td ({-align=> 'center', -class=> 'titrecat2'},"Exemples test sur les Hexapoda, Hemiptera, Cixiidea tirés de la base FLOW "),
			  td ({-align=> 'center', -class=> 'titrecat3'},"Veuillez choisir un nom de genre dans la liste et cliquez sur le bouton 'OK'"),
			  td ({-align=> 'center'}, popup_menu (-class=> 'option', -name=>'glist', -values=> [@sortedgl], -labels=> \%genus_label )),
			  td ({-align=> 'center'}, checkbox (-name=>'orthoerror', -checked=>1, -value=>1,-label=>'erreur d\'orthographe du nom de genre')),
			  td ({-align=> 'center'}, checkbox (-name=>'iderror', -checked=>1, -value=>1,-label=>'erreur d\'identification du nom de genre')),
			  td ({-align=> 'center'}, checkbox (-name=>'abstract', -checked=>1, -value=>1,-label=>'obtenir résumé')),
              td ({-align=> 'center'}, button(-name=>'gindex', -value=>'entrez',  -onClick=>"index()"), 	reset( -class=> 'point', -name=> 'reset'))
			 
		])
	);

$gid= param('glist');
               
print end_form();	
print end_html();

 

		
$dbconnect->disconnect();

##########################################################################################################
sub getTaxonomists {

	my ($index,$type) = @_;
	my $bool;

	if ($type eq 'auteurs') { $bool = 'TRUE' }
	elsif ($type eq 'reviseurs') { $bool = 'FALSE' }
	else { die "argument error getTaxonomists($type)"; }
	
	my $taxonomists = request_tab ("SELECT t.nom FROM taxonomistes AS t 
									LEFT JOIN noms_x_taxonomistes as nt ON nt.ref_taxonomiste = t.index 
									WHERE nt.ref_nom = $index 
									AND nt.auteur= $bool ORDER BY nt.position;", $dbconnect, 1);
									# recupere tous les noms et prenoms des taxonomistes	
	
	# met la liste (regroupe les element de @{$aut}) dans une chaine de caracteres a la fin du tableau @autority
	my $autorite = join (', ',@{$taxonomists});
	
	return ($autorite);
}

