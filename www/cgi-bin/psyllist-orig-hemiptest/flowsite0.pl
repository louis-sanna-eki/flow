#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_hash request_tab request_row get_title);

# style
my $paragrafTitleStyle = "font-weight: bold; font-size: 1.2em;";

# acces
my $url = url();

# variables de navigation
my $xbase;
my $xpage;
my $xlang;
my $script;
if (url_param('db')) { $xbase = url_param('db'); } else { $xbase = 'psylles'; }
if (url_param('page')) { $xpage = url_param('page'); } else { $xpage = 'home'; }
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'en'; }
my $searchtable = param('searchtable') || 'noms_complets';
my $searchid = param('searchid');
Delete('searchid');

# traductions
my $config_file = '/etc/flow/psyllesexplorer.conf';

my $config = get_connection_params($config_file);

my $traduction = read_lang($config, $xlang);

my $dbc = db_connection($config);

my $last = request_row("SELECT modif FROM synopsis;",$dbc);

my $docfullpath = '/var/www/html/Documents/flow/flowdocs/';
my $docpath = '/flowdocs/';

my $searchjs = $docfullpath.$config->{'SEARCHJS'};

my %types = ( 
	'noms_complets' => $traduction->{sciname}->{$xlang},
	'auteurs' => $traduction->{author}->{$xlang},
	'pays' => $traduction->{country}->{$xlang},
	'plantes' => $traduction->{plant}->{$xlang}
);

my %attributes = (
	'noms_complets' => {'class'=>'tableoption'},
	'auteurs' => {'class'=>'tableoption'},
	'publications' => {'class'=>'tableoption'},
	'pays' => {'class'=>'tableoption'},
	'plantes' => {'class'=>'tableoption'}
);

my $search = url_param('search');
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	if (ucfirst($schstr) ne ucfirst($traduction->{search}->{$xlang})) { $search = $schstr; }
}

my $args;
my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, nc.autorite FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species','subgenus','subspecies') ORDER BY nc.orthographe;",$dbc,2);
my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
my $distribs = request_tab("SELECT index, $xlang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
my $plants = request_tab("SELECT index, get_host_plant_name(index) AS fullname FROM plantes WHERE index in (SELECT DISTINCT ref_plante FROM taxons_x_plantes) ORDER BY fullname;",$dbc,2);

search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);
search_formating('plantes', $plants, \$thesauri, \$onload, $dbc);

if ( open(SEARCHJS, ">$searchjs") ) {
	print SEARCHJS $thesauri;
}
else {
	die "Can't open $searchjs";
}

$args .= " -searchtable='$searchtable' ";
if ($search) { $args .= " -search=\"$search\" " } else { $args .= " -search='' " }
if ($searchid) { $args .= " -searchid=$searchid " }

my $search_actions = "
	function clear_search_except(from, identity) {
		var identities = new Array('".join("','", sort {$types{$a} cmp $types{$b}} keys(%types))."');
		var valeur;
		for (index in identities) {
			if (document.getElementById(identities[index]).value) { valeur = document.getElementById(identities[index]).value; } 
			if (identities[index] != identity) {
				document.getElementById(identities[index]).style.visibility = 'hidden';
			}
			else {
				document.getElementById(identities[index]).style.visibility = 'visible';
			}
			document.getElementById(identities[index]).value = '';
		}
		if (from == 'popup') {
			if (valeur) { 
				document.getElementById(identity).value = valeur;
				document.getElementById(identity).focus();
			}
		}
	}
";

my $typdef = $searchtable;
my $search_fields;
my $z = 1;
foreach my $key (sort {$types{$a} cmp $types{$b}} keys(%types)) {
	$search_fields .= textfield(	-name=>"search$z", 
					-class=>'searchfield',
					-style=>"z-index: $z;",
					-id=>"$key",
					-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));"
			);
	$z++;
}

my $sb = start_form(    -name=>'searchform', 
			-method=>'post',
			-action=>url()."?db=$xbase&page=explorer&card=searching&lang=$xlang",
			-class=>'searchform'
	).
	table({-style=>'background: transparent; padding: 0; margin: 0;', -cellspacing=>0, -cellpadiing=>0, -border=>0},
		Tr(	
			td({-style=>'margin: 0; padding: 0 0 0 30px; /*width: 180px;*/'}, 	
				div({-class=>"searchtitle"}, ucfirst($traduction->{dbsearch}->{$xlang}) )
			),
			td({-style=>'margin: 0; padding: 0; /*width: 220px; text-align: right;*/'}, 	
				popup_menu(
					-name=>'searchtable',
					-class=>'tablepopup',
					-id=>'searchpop',
					-values=>[sort {$types{$a} cmp $types{$b}} keys(%types)],
					-default=> $typdef,
					-labels=>\%types,
					-attributes=>\%attributes,
					-onChange=>"clear_search_except('popup', this.value);"
				)
			),
			td({-style=>'position: absolute; padding: 0;'},
				$search_fields
			)
		)
	).
	hidden('searchid', '').
	end_form();


# varibales globales pour tout site		
my ($html, $bandeau, @menus,%submenus,%menulinks, @menuSpaces, $activepage, $content);

## LE CONTENU ##################################
my $header;
my $card = url_param('card') || '';
if ($xbase eq 'flow') {
		
	## LE BANDEAU ###############################

	$bandeau = div({-id=>'header'}, img({-src=>'/flowdocs/bandeauFLOW.png', -alt=>"header", -width=>'980px'}));

	## LE MENU ##################################
				
	@menus = ($traduction->{'main_page'}->{$xlang}, $traduction->{'flow_project'}->{$xlang}, $traduction->{'flow_db'}->{$xlang}, "Synopsis", $traduction->{'persp'}->{$xlang}, "Fulgoromorpha");
	
	@menuSpaces = ('60px','20px','1px','1px','20px','20px');
	
	%submenus = (	$traduction->{'flow_project'}->{$xlang} => [
										[$traduction->{'ori_key'}->{$xlang} , "$url?db=$xbase&page=project&lang=$xlang"],
										[$traduction->{'descr_key'}->{$xlang} , "$url?db=$xbase&page=project&lang=$xlang"],
										[$traduction->{'tech_key'}->{$xlang} , "$url?db=$xbase&page=projectbis&lang=$xlang"],
										[$traduction->{'community'}->{$xlang} , "$url?db=$xbase&page=projectbis&lang=$xlang"],
										[$traduction->{'collabos'}->{$xlang} , "$url?db=$xbase&page=projectter&lang=$xlang"],
										[$traduction->{'contrib_key'}->{$xlang} , "$url?db=$xbase&page=projectter&lang=$xlang"],
										[$traduction->{'standards_used'}->{$xlang} , "$url?db=$xbase&page=standards&lang=$xlang"],
										[$traduction->{'arigato'}->{$xlang} , "$url?db=$xbase&page=projectthanks&lang=$xlang"]
									],
				$traduction->{'flow_db'}->{$xlang} => [
									[$traduction->{"topics"}->{$xlang} , $url."?db=$xbase&page=explorer&card=top&lang=$xlang"],
									[$traduction->{'families'}->{$xlang} , $url."?db=$xbase&page=explorer&card=families&lang=$xlang"],
									[$traduction->{'genera'}->{$xlang} , $url."?db=$xbase&page=explorer&card=genera&lang=$xlang"],
									[$traduction->{'speciess'}->{$xlang} , $url."?db=$xbase&page=explorer&card=speciess&lang=$xlang"],
									[$traduction->{'scinames'}->{$xlang} , $url."?db=$xbase&page=explorer&card=names&lang=$xlang"],
									[$traduction->{'auts_key'}->{$xlang} , $url."?db=$xbase&page=explorer&card=authors&lang=$xlang"],
									[$traduction->{'publications'}->{$xlang} , $url."?db=$xbase&page=explorer&card=publications&lang=$xlang"],
									[$traduction->{'pays_key'}->{$xlang} , $url."?db=$xbase&page=explorer&card=countries&lang=$xlang"],
									[$traduction->{'ph_key'}->{$xlang} , $url."?db=$xbase&page=explorer&card=plants&lang=$xlang"],
									[$traduction->{'vernaculars'}->{$xlang} , $url."?db=$xbase&page=explorer&card=vernaculars&lang=$xlang"]
								],
				"Fulgoromorpha" => [
							[$traduction->{'intro_key'}->{$xlang} , "$url?db=$xbase&page=intro&lang=$xlang"],
							[$traduction->{'bioecoetho_key'}->{$xlang} , "$url?db=$xbase&page=bioecoetho&lang=$xlang"],
							[$traduction->{'eco_key'}->{$xlang} , "$url?db=$xbase&page=econom&lang=$xlang"],
							[$traduction->{'biogeo_key'}->{$xlang} , "$url?db=$xbase&page=biogeo&lang=$xlang"],
							[$traduction->{'morpho_key'}->{$xlang} , "$url?db=$xbase&page=morpho&lang=$xlang"],
							[$traduction->{'phylo_key'}->{$xlang} , "$url?db=$xbase&page=phylo&lang=$xlang"],
							[$traduction->{'pubref_key'}->{$xlang} , "$url?db=$xbase&page=pubrefs&lang=$xlang"]
						]
	);
	
	%menulinks = (
		$traduction->{'flow_db'}->{$xlang} => $url."?db=$xbase&page=explorer&card=top&lang=$xlang",
		$traduction->{'main_page'}->{$xlang} => "$url?db=$xbase&page=home&lang=$xlang",
		"Synopsis" => $url."?db=$xbase&page=explorer&lang=$xlang&card=board#base",
		$traduction->{'persp'}->{$xlang} => "/cgi-bin/Taxalife/taxalife.pl?lang=$xlang",
		$traduction->{'flow_project'}->{$xlang} => "$url?db=$xbase&page=project&lang=$xlang",
		"Fulgoromorpha" => "$url?db=$xbase&page=intro&lang=$xlang",
		"Hemiptera" => "$url?db=$xbase&page=classif&lang=$xlang"
	);
		
	my $tableStyle  = "width: 800px; margin-bottom: 20px;";
	
	my $pagetitle = "FLOW Website";
	
	if ($xpage eq 'explorer') {
		
		my $param;
		if ($param = url_param('db')) { $args .= " -db=$param " }
		if ($param = url_param('card')) { $args .= " -card=$param " }
		
		if ($param eq 'board') { $activepage = "Synopsis" }
		else { $activepage = $traduction->{'flow_db'}->{$xlang} }
		
		if ($param = url_param('id')) { $args .= " -id=$param " }
		if ($param = url_param('lang')) { $args .= " -lang=$param " }
		if ($param = url_param('alph')) { $args .= " -alph=$param " }
		if ($param = url_param('from')) { $args .= " -from=$param " }
		if ($param = url_param('to')) { $args .= " -to=$param " }
		if ($param = url_param('rank')) { $args .= " -rank=$param " }
		if ($param = url_param('mode')) { $args .= " -mode=$param " }
		if ($param = url_param('privacy')) { $args .= " -privacy=$param " }
		
		my $id = url_param('id') || '';
		
		#if (url_param('card') eq 'searching') { die param('hiddensearch'). " = $args" }
		
		$pagetitle = get_title($dbc, $xbase, $card, $id, $search, $xlang, '');
				
		$script = "/var/www/html/perl/explorer2.pl $args";
	}
	elsif ($xpage eq 'project') {
		
		$activepage = $traduction->{'flow_project'}->{$xlang};
			
		$content = 	table({-style=>$tableStyle, border=>0},
					Tr(
					td({-style=>"padding-right: 20px; width: 700px;"},
							span({-name=>'ori', -style=>$paragrafTitleStyle}, $traduction->{'ori_key'}->{$xlang}),p,
							$traduction->{'oritxt'}->{$xlang}
						),
						td({-style=>'width: 100px;'}, img({-src=>"/flowdocs/intricata.png", alt=>"intricata", width=>'100px', height=>'200px'}))
					)
				).
				table({-style=>$tableStyle},
					Tr(
						
						td({-style=>"padding-right: 20px;"}, img({-src=>"/flowdocs/vohimana3.png", alt=>"vohimana", width=>'200px', height=>'150px'})),
						td(
							span({-name=>'desc', -style=>$paragrafTitleStyle}, $traduction->{'descr_key'}->{$xlang}),p,
							$traduction->{'presenttxt'}->{$xlang}
						)
					)
				);
				
			$content  = div({-class=>'content_container'}, 
					
					$content,
					div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
						a({-href=>"$url?db=$xbase&page=projectbis&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang}),
						' >> '
					)
				);
	}
	elsif ($xpage eq 'projectbis') {

		$activepage = $traduction->{'flow_project'}->{$xlang};
			
		$content = 	table({style=>$tableStyle},
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'tech', -style=>$paragrafTitleStyle}, $traduction->{'tech_key'}->{$xlang}),p,
							$traduction->{'techtxt'}->{$xlang}
						),
						td(img({-src=>"/flowdocs/fulgore2.png", alt=>"fulgore", width=>'180px', height=>'200px'}))
					)
				).
				table({style=>$tableStyle},
					Tr(
						
						td(
							span({-name=>'com', -style=>$paragrafTitleStyle}, $traduction->{'community'}->{$xlang}),p,
							$traduction->{'commutxt'}->{$xlang}
						)
					)
				);
			
			$content  = div({-class=>'content_container'}, 
					$content, br,
					div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
						a({-href=>"$url?db=$xbase&page=project&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
						' >> ',
						a({-href=>"$url?db=$xbase&page=projectter&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
					)
					
				);
	}
	elsif ($xpage eq 'projectter') {

		$activepage = $traduction->{'flow_project'}->{$xlang};
			
		$content = 	table({style=>$tableStyle},
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'col', -style=>$paragrafTitleStyle}, $traduction->{'collabos'}->{$xlang}), br, br,
							$traduction->{'collabtxt'}->{$xlang}, br, br,
							a({-href=>"http://www.gbif.org/"}, img{-src=>'/flowdocs/gbif.jpg', -style=>'border: 0; height:50px; width: 89px;'}),
							a({-href=>"http://www.sp2000.org/"}, img{-src=>'/flowdocs/sp2k.png', -style=>'border: 0; height:50px; width: 113px;'}),
							a({-href=>"http://www.biocase.org/index.shtml"}, img{-src=>'/flowdocs/biocase.png', -style=>'border: 0; height:50px; width: 77px;'})
						)
					)
				).
				table({style=>$tableStyle},
					Tr(
						td({-style=>"padding-right: 20px;"},
							span({-name=>'ctb', -style=>$paragrafTitleStyle}, $traduction->{'contrib_key'}->{$xlang}),p,
							$traduction->{'contribtxt'}->{$xlang}
						)
					)
				);
			
			$content  = div({-class=>'content_container'}, 
					$content, br,
					div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
						a({-href=>"$url?db=$xbase&page=projectbis&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
						' >> ',
						a({-href=>"$url?db=$xbase&page=standards&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
					)
				);
	}
	elsif ($xpage eq 'standards') {

		$activepage = $traduction->{'flow_project'}->{$xlang};
			
		$content = 	table({style=>$tableStyle},
					Tr(
						td(
							$traduction->{'dbtnt_standards'}->{$xlang}
						)
					)
				);
			
			$content  = 	div({-class=>'content_container'},
						div({-style=>'position: absolute; overflow: auto; height: 500px; width: 860px; margin-top: 20px; padding: 0; background: transparent;'},
							$content, br,
						),
						div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
							a({-href=>"$url?db=$xbase&page=projectter&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
							' >> ',
							a({-href=>"$url?db=$xbase&page=projectthanks&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
						)
				);
	}
	elsif ($xpage eq 'projectthanks') {
		
		$activepage = $traduction->{'flow_project'}->{$xlang};
	
		$content .= 	div({-class=>'content_container'},
					
					span({-style=>$paragrafTitleStyle}, $traduction->{'arigato'}->{$xlang}), br, br,
					
					$traduction->{'thkintro'}->{$xlang}, br,
					
					ul( "$traduction->{'fulgothanks'}->{$xlang}" ), br,
					
					div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
					
						'<< ', a({-href=>"$url?db=$xbase&page=standards&lang=$xlang"}, $traduction->{'prev'}->{$xlang})
					)

				);
	}
	elsif ($xpage eq 'intro') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'fulgointrotitle'}->{$xlang}), p,
			
			$traduction->{'fulgointro'}->{$xlang}, br, br,
			
			img({-src=>'/flowdocs/DSC02119.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>'/flowdocs/DSC02158.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>'/flowdocs/IMG_0492.jpg', -style=>"width: 257px; height: 194pix"}),

			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},

				a({-href=>"$url?db=$xbase&page=bioecoetho&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang}),
				' >> '
			)
		);
	}
	elsif ($xpage eq 'bioecoetho') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'beetitle'}->{$xlang}), p,
			
			$traduction->{'fulgobio'}->{$xlang}, br, br,
			
			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
			
				a({-href=>"$url?db=$xbase&page=intro&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
				' >> ',
				a({-href=>"$url?db=$xbase&page=econom&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
			)
		);
	}
	elsif ($xpage eq 'econom') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'econotitle'}->{$xlang}), p,
			
			$traduction->{'pests'}->{$xlang},
			
			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
			
				a({-href=>"$url?db=$xbase&page=bioecoetho&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
				' >> ',
				a({-href=>"$url?db=$xbase&page=biogeo&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
			)
		);
	}
	elsif ($xpage eq 'biogeo') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'fulgobiogeotitle'}->{$xlang}), p,
			
			$traduction->{'fulgobiogeo'}->{$xlang}, br, br,

			img({-src=>'/flowdocs/DSC02404.jpg', -style=>"width: 150px; height: 200px; margin-right: 50px; "}),

			img({-src=>'/flowdocs/IMG_0234.jpg', -style=>"width: 133px; height: 200px; margin-right: 50px;"}),

			img({-src=>'/flowdocs/IMG_0380.jpg', -style=>"width: 133px; height: 200px"}),

			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
			
				a({-href=>"$url?db=$xbase&page=econom&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
				' >> ',
				a({-href=>"$url?db=$xbase&page=morpho&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
			)
		);
	}
	elsif ($xpage eq 'morpho') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'fulgomorphotitle'}->{$xlang}), p,
			
			$traduction->{'fulgomorpho'}->{$xlang}, br, br,

			img({-src=>'/flowdocs/IMG_0301.jpg', -style=>"width: 143px; height: 200px; margin-right: 50px; "}),

			img({-src=>'/flowdocs/IMG_0469.jpg', -style=>"width: 300px; height: 200px"}),

			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
			
				a({-href=>"$url?db=$xbase&page=biogeo&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
				' >> ',
				a({-href=>"$url?db=$xbase&page=phylo&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
			)
		);		
	}
	elsif ($xpage eq 'phylo') {
			
		$activepage = "Fulgoromorpha";

		$content  = div({-class=>'content_container'}, 
			
			span({-style=>$paragrafTitleStyle}, $traduction->{'fulgophylotitle'}->{$xlang}), br, br,
			
			$traduction->{'fulgophylo'}->{$xlang},
			
			div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'},
				
				a({-href=>"$url?db=$xbase&page=morpho&lang=$xlang"}, $traduction->{'prev'}->{$xlang}),
				' >> ',
				a({-href=>"$url?db=$xbase&page=pubrefs&lang=$xlang"}, $traduction->{'nextstep'}->{$xlang})
			)
		);
	}
	elsif ($xpage eq 'pubrefs') {
		my @refs = (
			'Asche, M., 1985. - Zur Phylogenie der Delphacidae Leach, 1815 (Homoptera, Cicadina, Fulgoromorpha). Marburger Entomologische Publikationen, 2: 1-910.',
			'Asche, M., 1988. - Preliminary thoughts on the phylogeny of Fulgoromorpha (Homoptera, Auchenorrhyncha). Proceedings. 6th Auchenorrhyncha Meeting, Turin, Italy, 7-11 sept. 1987, pp. 47-53. ',
			'Asche, M., 1990. - Vizcayinae, a new subfamily of Delphacidae with revision of Vizcaya Muir (Homoptera: Fulgoroidea) - a significant phylogenetic link. Bishop Museum Occasional Papers, 30: 154-187.',
			'Boulard, M., 1987. - Contribution à l\'étude des Issidae. L\'oothèque terreuse des "Hysteropterum", un problème évolutif. Bull. Soc. Entomol. Fr., 92(1-2): 1-18.',
			'Bourgoin, Th., 1986. - Morphologie imaginale du tentorium des Hemiptera Fulgoromorpha. Int. J. Insect. Morphol. Embryol., 15(4): 237-252.',
			'Bourgoin, Th. & J. Huang, 1990. - Morphologie comparée des genitalia males des Trypetimorphini et remarques phylogénétiques (Hemiptera Fulgoromorpha : Tropiduchidae). Ann. Soc. Entomol. Fr., (N.S.), 26(4): 555-564.',
			'Bourgoin, Th., 1993. - Female genitalia in Fulgoromorpha (Insecta, Hemiptera): morphological and phylogenetical data. Ann. Soc. Entomol. Fr., (N.S.), 29(3): 225-244.',
			'Bourgoin, Th. & V. Deiss, 1994. - Sensory plate organs of the antenna in the Meenoplidae-Kinnaridae group (Hemiptera : Fulgoromorpha). Int. J. Insect. Morphol. Embryol., 23(2): 159-168.',
			'Bourgoin Th., 1997. - The Meenoplidae (Hemiptera, Fulgoromorpha) of New Caledonia, with a revision of the genus Eponisia Matsumura, 1914, and new morphological data on forewing venation and wax plate areas. In L. Matile, J. Najt & S. Tillier (eds), Zoologia Neocaledonica, 3. Mem. Mus. nat. Hist. nat., (Zoologie): 197-250.',
			'Bourgoin, Th., 1997. - Habitat and ant-attendance in Hemiptera : a phylogenetic test with emphasis on trophobiosis in Fulgoromorpha. In Grandcolas, P. (ed.), The origin of biodiversity in Insects : phylogenetics tests of evolutionary scenarios. Mem. Mus. nat. Hist. nat., 173: 109-124.',
			'Bourgoin Th., Steffen-Campbell, J.D. & B.C. Campbell, 1997. - Molecular phylogeny of Fulgoromorpha (Insecta, Hemiptera, Archaeorrhyncha). The enigmatic Tettigometridae : evolutionary affiliations and historical biogeography. Cladistics, 13(3): 207-224.',
			'Bourgoin Th. & B.C. Campbell, 2002. - Inferring a phylogeny for Hemiptera: falling into the autapomorphic trap. Denisia 4: 67-81.',
			'Campbell, B.C., Steffen-Campbell, J.D. & Gill, R. 1994. - Evolutionary origin of whiteflies (Hemiptera: Sternorrhyncha: Aleyrodidae) inferred from rDNA sequences. Insect Molecular Biology, 3(2): 73-88.',
			'Campbell, B.C., Steffen-Campbell, J.D., Sorensen, J. T. & R. Gill, 1995. - Paraphyly of Homoptera and Auchenorrhyncha inferred from 18S rDNA nucleotide sequences. Syst. Entomol., 20: 175-194.',
			'Carver, M., Ross, G.F. & T.E., Woodward, 1991. - Hemiptera (bugs, leafhoppers, cicada, aphids, scale insects, etc.) pp 429-509. In Naumann, I.D., Crane, P.B., Lawrence, J.F., Neilsen, E.S., Spradbery, J.P., Taylor, R.W., Whitten, M.J. & M.J. Littlejohn (eds). The Insects of Australia, a textbook for students and research workers. Vol. 1 (2nd ed). Melbourne Univ. Press, Melbourne, Australia. ',
			'Claridge, M.F. & P.W.F. de Vrijer, 1994. - Reproductive behavior : the role of acoustic signals in species recognition and speciation. In R.F. Denno & T.J. Perfect Edts, Planthoppers, their Ecology and Management, pp. 216-233.',
			'Cobben, R.H., 1965. - Das aero-mikropilare System der Homoptereneier und Evolutionstrends bei Zikadeneiern (Hom. Auchenorhyncha). Zool. Beitr., 11 1-2.',
			'Cronin, J.T. & D.R. Strong, 1994. - Parasitoid interactions and their contribution to the stabilization of Auchenorrhyncha populations. In R.F. Denno & T.J. Perfect Edts, Planthoppers, their Ecology and Management, pp. 400-428.',
			'Denno, R.F. & T.J. Perfect, 1994. - Planthoppers, their Ecology and Management. Chapman & Hall, 799 pp.',
			'Döbel, H.G. & R.F. Denno,  1994. - Predator-planthopper interactions. In R.F. Denno & T.J. Perfect Edts, Planthoppers, their Ecology and Management, pp. 325-399.',
			'Emeljanov, A.F., 1990. - An attempt of construction of phylogenetic tree of the planthoppers (Homoptera, Cicadina). Entomologicheskoye Obozreniye, 69: 353-356.',
			'Emeljanov, A.F., 2001. - Larval characters and their ontogenetic development in Fulgoroidea (Homoptera, Cicadina). Zoosystematica Rossica 9 (1): 101-121.',
			'Herdt, R.W., 1987. - Equity considerations in setting priorities for third world rice biotechnology research. Developments: seeds of change, 4: 19-24.',
			'Hoch, H., 1994. - Homoptera (Auchenorrhyncha Fulgoroidea). In C. Juberthie & V. Decu Edt., Encyclopedia Biospeleogica, Moulis - Bucarest, Soc. Biospéologie Pub., 1: 313-325.',
			'Hoch, H., 2002. - Hidden from the light of day: planthoppers in subterranean habitats (Hemiptera: Auchenorrhyncha: Fulgoromorpha). Denisia 4: 139-146.',
			'Muir, F., 1923. - On the classification of the Fulgoroidea (Homoptera). Proc. Hawaiian Ent. Soc., 5(2) : 205-247.',
			'Muir, F., 1930. - On the classification of the Fulgoroidea (Homoptera). Ann. Mag. Nat. Hist., 10(6): 461-478.',
			'Nickel, H. 2003. The leafhoppers and planthoppers of Germany (Hemiptera, Auchenorrhyncha): Patterns and strategies in a highly diverse group of phytophagous insects. Pensoft publishers, 460 pp.',
			'O\'Brien, L. & S. Wilson, 1985. - Planthopper systematics and external morphology. In Nault, L. R. and Rodrigues, J.G., The Leafhoppers and Planthoppers,  N.Y., Wiley and Sons, pp. 61-102.',
			'Sorensen, J.T., Campbell, B.C., Gill, R.J. & J.D. Steffen-Campbell, 1995. - Non-monophyly of Auchenorrhyncha ("Homoptera"), based upon 18S rDNA phylogeny : eco-evolutionary and cladistic implications within pre-Heteropterodea Hemiptera (s.l.) and a proposal for new monophyletic suborders. Pan-Pacific Entomol., 71(1): 31-60.',
			'Soulier-Perkins, A., 1997. - Systématique phylogenetique et test d\'hypotheses biogeographiques chez les Lophopidae (Hemiptera, Fulgoromorpha). I et II., These de Doctorat, Museum nat. Hist. nat., 128 + 165 pp.',
			'Soulier-Perkins, A., 1998. The Lophopidae (Hemiptera : Fulgoromorpha): Description of three new genera and key to the genera of the family. Eur. J. Entomol. 95: 599-618.',
			'Soulier-Perkins A., 2000. A phylogenetic and geotectonic scenario to explain the biogeography of the Lophopidae (Hemiptera, Fulgoromorpha). Palaeogeography, Palaeoclimatology, Palaeoecology 160, 239-254.',
			'Soulier-Perkins A., 2001. The phylogeny of the Lophopidae and the impact of sexual selection and coevolutionary sexual conflict. Cladistics, 17, 56-78.',
			'Szwedo, J., Bourgoin, Th. & F. Lefebvre. 2004. Fossil Planthoppers (Hemiptera: Fulgoromorpha) of the world: An annotated catalogue with notes on Hemiptera classification. Studio 1, 199 pp.',
			'Von Dohlen, C. & N.A. Moran, 1995. - Molecular phylogeny of the Homoptera : a paraphyletic taxon. J. Mol. Evol., 41: 211-223.',
			'Wilson, M.R. & M.F. Claridge, 1991. - Handbook for the identification of leafoppers and planthoppers of rice. C.A.B. International, 142 pp.',
			'Wilson, S.W., Mitter, C., Denno, R.F. & M.R. Wilson, 1994. - Evolutionary patterns of hostplant use by delphacid planthoppers and their relatives. In R.F. Denno & T.J. Perfect editors, Planthoppers : their Ecology and Management, pp. 7-113.',
			'Wilson S.W. & O\'Brien L.B., 1987. - A survey of planthoppers pests of economically important plants (Homoptera: Fulgoroidea). In Proceedings of 2nd International Workshop on Leafhoppers and Planthoppers of Economic importance, Wilson, M.R. & Nault, L.R., 28th July-1st August 1986, Brigham Young University, Provo, Utah, USA, London, CAB Int. Inst. Ent., pp. 343-360.',
			'Yang, C.-T. & S.-J. Fang, 1993. - Phylogeny of Fulgoromorpha nymphs, first results. Proceedings. 8th Auchenorrhyncha Congress, Delphi, Greece, 9-13 aug. 1993, pp. 25-26.',
			'Yang, C.-T. & W.-B. Yeh, 1994. - Nymphs of Fulgoroidea (Homoptera: Auchenorrhyncha) with description of two new species and notes on adults of Dictyopharidae. Chin. J. Entomol., Special Pub., 8: 1-189.'
		);
		
		my @refslist = map(li("$_<br><br>"), @refs);
		
		$activepage = "Fulgoromorpha";
	
		$content .= 	div({-class=>'content_container'}, 
				
					span({-style=>$paragrafTitleStyle}, $traduction->{'refstitle'}->{$xlang}).

					div({-style=>'position: absolute; overflow: auto; height: 450px; width: 860px; margin-top: 20px; padding: 0; background: transparent;'},
						ul( @refslist )
					).
				
					div({-style=>'position: absolute; background: transparent; left: 65px; top: 560px; width: 200px;'}, 
				
						'<< ' . a({-href=>"$url?db=$xbase&page=phylo&lang=$xlang"}, $traduction->{'prev'}->{$xlang})
					)
				);
	
	}
	elsif ($xpage eq 'map') {
		$content .= 	div({-class=>'content_container'},
					"<div 	style='position: absolute; overflow: auto; height: 450px; width: 860px; margin-top: 20px; padding: 0; background: transparent;' 
						id='map'>
					</div>
					<script src='http://maps.google.com/maps?file=api&amp;v=2&amp;key=ABQIAAAAjpkAC9ePGem0lIq5XcMiuhR_wWLPFku8Ix9i2SXYRVK3e45q1BQUd_beF8dtzKET_EteAjPdGDwqpQ'></script>
					<script type='text/javascript'>
					// make map available for easy debugging
					var map;
					
					// increase reload attempts 
					OpenLayers.IMAGE_RELOAD_ATTEMPTS = 3;
					
					function init(){
						var options = {
							projection: new OpenLayers.Projection('EPSG:900913'),
							displayProjection: new OpenLayers.Projection('EPSG:4326'),
							units: 'm',
							numZoomLevels: 18,
							maxResolution: 156543.0339,
							maxExtent: new OpenLayers.Bounds(-20037508, -20037508, 20037508, 20037508.34)
						};
						map = new OpenLayers.Map('map', options);
						
						var gsat = new OpenLayers.Layer.Google(
						'Google Satellite',
						{type: G_SATELLITE_MAP, 'sphericalMercator': true, numZoomLevels: 22}
						);
							
						map.addLayers([gsap]);
						map.zoomToMaxExtent();
					}
					init();
					</script>"
				);

	}
	else {
		$activepage = $traduction->{'main_page'}->{$xlang};
		
		$content = 	div({-style=>'background: transparent; width: 500px; height: 250px;'}, 
					img({-src=>'/flowdocs/logotest.png', -style=>"margin: 30px 0 0px 30px;"})
				).
				div({-style=>'background: transparent; text-align: center; margin: 0px 0 0 0px; width: 830px; height: 140px; font-family: Arial; font-style: italic; font-size: 15px;'},
					$traduction->{'home_intro'}->{$xlang}
				).
				div({-style=>'position: absolute; margin: 0; padding: 0; height: 80px; background: transparent;'},
					a({-style=>'position: absolute; display: block; margin: 140px 0 0 -6px; width: 150px; height: 60px; background: transparent; text-decoration: none;', -href=>'http://www.upmc.fr/'},'&nbsp;'),
					a({-style=>'position: absolute; display: block; margin: 130px 0 0 160px; width: 72px; height: 80px; background: transparent; text-decoration: none;', -href=>'http://www.mnhn.fr/'},'&nbsp;'),
					div({-style=>'position: absolute; top: 150px; bottom: 0; left: 310px; font-style: italic; width: 200px;'},
						"Version: ".span({-style=>"font-size: 110%; font-weight: bold"},7).br."$traduction->{'dmaj'}->{$xlang}: ".span({-style=>"font-size: 110%; font-weight: bold"}, $last)
					),
					div({-style=>'position: absolute; top: 150px; bottom: 0; left: 560px; font-style: italic;'},
						a({-href=>'mailto:bourgoin@mnhn.fr', -style=>'color: navy; font-weight: bold; text-decoration: none;'}, "$traduction->{'contact'}->{$xlang}")
					)
				);
		
		$content  = div({-class=>'content_container', -id=>'homebg'}, $content);
	}
	

	my $analytics =<<END;
	var _gaq = _gaq || [];
	_gaq.push(['_setAccount', 'UA-21288992-1']);
	_gaq.push(['_trackPageview']);
	(function() {
		var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
		ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
	})();
END

	$header = 	header({-Type=>'text/html', -Charset=>'UTF-8'}).

	start_html(	-title  =>$pagetitle,
			-author =>	'anta@mnhn.fr',
			-head   =>meta({-http_equiv => 'Content-Type', -content    => 'text/html; charset=UTF-8'}),
			-style  => 	{'src'=>'/flowdocs/menu.css'},
			-script => 	[	{-language=>'JAVASCRIPT', -src=>'/flowdocs/browserdetect.js'},
						{-language=>'JAVASCRIPT', -src=>'/flowdocs/dynMenu.js'},
						{-language=>'JAVASCRIPT',-src=>'/flowdocs/SearchAutoComplete_utf8.js'},
						{-language=>'JAVASCRIPT',-src=>'/flowdocs/pngfixall.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.$config->{'SEARCHJS'}},
						$analytics,
						$search_actions
					],
			-onLoad	=> "	clear_search_except('onload', '$typdef');
					$onload
					if (isIE) {
						document.getElementById('searchpop').style.height = '20px';
					}"
	);
}

## LA CREATION DE MENU ##################################

my @menu_elmts;
for my $i (0..$#menus) {
	my $max = length($menus[$i]);
	my $init = $max;
	my @subelmts;

	my $id;
	if ($menus[$i] eq $activepage) { $id = 'active'; } else { $id = 'inactive'; }
	
	if (exists($submenus{$menus[$i]})) {
		foreach my $sub (@{$submenus{$menus[$i]}}) {
			if ($max < length($sub->[0])) { $max = length($sub->[0]); }
		}
		
		if ($max > $init+4) { $max = $max/2.5 + 2; } else { $max = $max/2.5 + 4; }
		
		foreach my $sub (@{$submenus{$menus[$i]}}) {
			push(@subelmts,li( a({-href=>$sub->[1], -style=>"width: ".$max."em;"},$sub->[0])));
		}
		my $targ = '#';
		if (exists($menulinks{$menus[$i]})) { $targ = $menulinks{$menus[$i]} }
				
		push(@menu_elmts,li({-style=>"margin-left: $menuSpaces[$i];"},
				span({-id=>$id."_span"}, a({-href=>$targ, -id=>$id."_link", -style=>"width: ".$max."em;"},$menus[$i] )),
				ul({-class=>'sousMenu', -id=>$id."_ul"},@subelmts)
				)
		);
	}
	elsif (exists($menulinks{$menus[$i]})) {
		
		if ($max > $init+4) { $max = $max/2.5 + 2; } else { $max = $max/2.5 + 4; }
		
		push(@menu_elmts,li({-style=>"margin-left: $menuSpaces[$i];"},
					span({-id=>$id."_span"}, a({-href=>$menulinks{$menus[$i]}, -id=>$id."_link", -style=>"width: ".$max."em;"},$menus[$i]))
				)
		);
	}
}	

my $html_menus = div({-id=>'menu_container'}, ul({-id=>'menu'}, @menu_elmts ) ).
		
		script({-type=>'text/javascript'},'initMenu();');


## LA BARRE DE SEPARATION HORIZONTALE #######################

my $help = "	Search any scientific name using star * for truncature. \\n
		Examples: \\n
		a* returns all families and genera starting with \\'a\\' \\n
		a* * returns all species having a genus starting with \\'a\\' \\n
		* a* returns all species having a specific epithet starting with \\'a\\' \\n
		* (a*) * returns all species having subgenus starting with \\'a\\'	";

my $hbar = div({-id=>"title_centrer"}, 
		div({-id=>"title_container"},
			div({-id=>'title_end'})
		)
	);

## LES ONGLETS VERTICAUX DE LANGUES #########################

my ($enstatut, $frstatut, $spstatut, $destatut);

$enstatut = $frstatut = $spstatut = $destatut = 'inactive';

if ($xlang eq 'en' or !$xlang) { $enstatut = 'active' }
elsif ($xlang eq 'fr') { $frstatut = 'active' }
elsif ($xlang eq 'es') { $spstatut = 'active' }
elsif ($xlang eq 'de') { $destatut = 'active' }

my @argus;
foreach (url_param()) { if ($_ ne 'lang') { push(@argus, $_.'='.url_param($_)) } }

my $xlanguages = div({-id=>"vertival_tabs_container"},
				span( {	-class=>'reactive_flag', 
					-id=>$enstatut."_en", 
					-onMouseOver=>"this.style.cursor = 'pointer';",
					-onClick=>"	document.searchform.action = '"."$url?".join('&',@argus)."&lang=en"."'; 
							document.getElementById('searchpop').value = '$searchtable';
							document.getElementsByName('searchid')[0].value = '$searchid';
							document.getElementById('$searchtable').value = \"$search\";
							document.searchform.submit();"}, 
					'&nbsp;'
				),
				span( {	-class=>'reactive_flag', 
					-id=>$frstatut."_fr", 
					-onMouseOver=>"this.style.cursor = 'pointer';",
					-onClick=>"	document.searchform.action = '"."$url?".join('&',@argus)."&lang=fr"."'; 
							document.getElementById('searchpop').value = '$searchtable';
							document.getElementsByName('searchid')[0].value = '$searchid';
							document.getElementById('$searchtable').value = \"$search\";
							document.searchform.submit();"}, 
					'&nbsp;'
				),
				span( {	-class=>'reactive_flag', 
					-id=>$spstatut."_sp", 
					-onMouseOver=>"this.style.cursor = 'pointer';",
					-onClick=>"	document.searchform.action = '"."$url?".join('&',@argus)."&lang=es"."'; 
							document.getElementById('searchpop').value = '$searchtable';
							document.getElementsByName('searchid')[0].value = '$searchid';
							document.getElementById('$searchtable').value = \"$search\";
							document.searchform.submit();"}, 
					'&nbsp;'
				),
				span( {	-class=>'reactive_flag', 
					-id=>$destatut."_de", 
					-onMouseOver=>"this.style.cursor = 'pointer';",
					-onClick=>"	document.searchform.action = '"."$url?".join('&',@argus)."&lang=de"."'; 
							document.getElementById('searchpop').value = '$searchtable';
							document.getElementsByName('searchid')[0].value = '$searchid';
							document.getElementById('$searchtable').value = \"$search\";
							document.searchform.submit();"}, 
					'&nbsp;'
				),
				div({-style=>'	margin-top: 100px; margin-left: -70px;  background: #FF7000; width: 96px; padding: 0 0 2px 2px; 
						text-align: center; position: absolute: z-index: 3;'}, 
					a({-href=>"http://flow.snv.jussieu.fr/cgi-bin/classif.pl", -style=>'font-size: 14px; color: navy;'},
				"Hemiptera classification"))
		);

## LA BARRE DE SEPARATION VERTICALE #######################

my $vbar = div({-id=>'vertical_bar'});


## AFFICHAGE !!! ##########################################
my $arrow;

Delete('hiddensearch');

print	$header;
print	$bandeau;
print	$html_menus; 
print	"<DIV id='main_container'>";
print		$hbar;
print	"	<DIV id='second_container'>";
print			$xlanguages;
print			$vbar;
print 			$content;
print 	"		<DIV class='content_container' STYLE='z-index: 3; padding: 0 0 0 0px; width: 890px; top: 1.5em; height: 24px; background: url(/flowdocs/titleback.png);'>";
print 	"			<DIV STYLE='z-index: 3; padding: 0 0 0 0; width: 930px; height: 24px; background: url(/flowdocs/titleend.png) right top no-repeat;'>";
print 					$sb;
print	"			</DIV>";
print	"		</DIV>";
if ($xpage eq 'explorer') { 
	print "<DIV class='content_container'>"; system $script; print "</DIV>"; 
}
print	"	</DIV>";
print	"</DIV>";
print	end_html();

$dbc->disconnect;

exit;

sub search_formating {
	my ($table, $arr, $thesaur, $load, $dbh) = @_;
			
	my $ids;
	my $values;
	my $authors = [];
	foreach (@{$arr}) {
		$_->[1] =~ s/'/\\'/g;
		$_->[1] =~ s/"/\\"/g;
		$_->[1] =~ s/\[/\\[/g;
		$_->[1] =~ s/\]/\\]/g;
		$_->[1] =~ s/  / /g;
		
		push(@{$ids}, $_->[0]);
		push(@{$values}, $_->[1]);
		
		if ($table ne 'noms_complets') {
			if ($_->[1] =~ m|[^A-Z a-z 0-9 : , ( ) \[ \] ! _ = & ° . * ; “ " ’ ” ' \\ \/ \- – ? ‡ \n ]|) {
				my ($res) = @{request_row("SELECT reencodage('".$_->[1]."');", $dbh)};
				$res =~ s/'/\\'/g;
				$res =~ s/"/\\"/g;
				$res =~ s/\[/\\[/g;
				$res =~ s/\]/\\]/g;
				$res =~ s/  / /g;
				
				push(@{$ids}, $_->[0]);
				push(@{$values}, $res);
			}	
		}
		else {
			$_->[2] =~ s/'/\\'/g;
			$_->[2] =~ s/"/\\"/g;
			$_->[2] =~ s/\[/\\[/g;
			$_->[2] =~ s/\]/\\]/g;
			$_->[2] =~ s/  / /g;
			push(@{$authors}, $_->[2]);
		}
	}
	${$thesaur} .= $table . "ids = ['" . join("','", @{$ids}) . "']; $table = ['" . join("','", @{$values}) . "']; ";
	if ($table eq 'noms_complets') {
		${$thesaur} .= "authors = ['" . join("','", @{$authors}) . "']; ";
		${$load} .= "AutoComplete_Create('$table', $table, $table"."ids, authors, 10);";
	}
	else {
		${$load} .= "AutoComplete_Create('$table', $table, $table"."ids, '', 10);";
	}
}

sub read_lang {
	my ( $conf ) = @_;
	my $tr = { };
	my $rdbms  = $conf->{TRAD_RDBMS};
	my $server = $conf->{TRAD_SERVER};
	my $db     = $conf->{TRAD_DB};
	my $port   = $conf->{TRAD_PORT};
	my $login  = $conf->{TRAD_LOGIN};
	my $pwd    = $conf->{TRAD_PWD};
	my $webmaster = $conf->{TRAD_WMR};
	if ( my $dbc = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port", $login, $pwd) ){
		$tr = $dbc->selectall_hashref("SELECT id, $xlang FROM traductions;", "id");
		$dbc->disconnect;
		return $tr;
	}
	else {
		my $error_msg .= $DBI::errstr;
		print 	header('Error'),
			h1("Database connection error"),
			pre($error_msg),p;

		return undef;
	}
}
