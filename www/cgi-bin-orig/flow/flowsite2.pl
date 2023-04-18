#!/usr/bin/perl

use strict;
use CGI qw/:standard/;
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_hash request_tab request_row get_title);
use CGI::Ajax;

my $url = url();
my $cgi = new CGI();
my $pjx = new CGI::Ajax( 'getThesaurusItems' => \&getThesaurusItems );

# variables de navigation
my $xbase;
my $xpage;
my $xlang;
my $script;
my $test;
if (url_param('db')) { $xbase = url_param('db'); } else { $xbase = 'flow'; }
if (url_param('page')) { $xpage = url_param('page'); } else { $xpage = 'home'; }
if (url_param('lang')) { $xlang = url_param('lang'); } else { $xlang = 'en'; }
my $searchtable = param('searchtable') || 'noms_complets';
my $searchid = param('searchid');
Delete('searchid');

# traductions
my $config_file = '/etc/flow/flowexplorer.conf';

my $config = get_connection_params($config_file);

my $traduction = read_lang($config, $xlang);

my $dbc = db_connection($config);

my $last = request_row("SELECT modif FROM synopsis;",$dbc);

my $docfullpath = '/var/www/html/Documents/flowdocs/';
my $docpath = '/flowdocs/';

my $searchjs = $docfullpath.$config->{'SEARCHJS'};

my %types = ( 
	'noms_complets' => $traduction->{sciname}->{$xlang},
	'auteurs' => $traduction->{author}->{$xlang},
	'pays' => $traduction->{country}->{$xlang},
	'plantes' => $traduction->{plant}->{$xlang}
);

my %attributes = (
	'noms_complets' => {'class'=>'searchOption'},
	'auteurs' => {'class'=>'searchOption'},
	'pays' => {'class'=>'searchOption'},
	'plantes' => {'class'=>'searchOption'}
);

my $search = url_param('search') || '';
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	if (ucfirst($schstr) ne ucfirst($traduction->{search}->{$xlang})) { $search = $schstr; }
}

my $args;
my $thesauri;
my $onload;
#if ( open(SEARCHJS, "<$searchjs") ) {
#	
#	my $delai = time - (stat SEARCHJS)[9];
#	
#	close(SEARCHJS);
#		
#	if ($delai < 1800 and !url_param('reload')) {

		$onload .= "AutoComplete_Create('noms_complets', noms_complets_array, noms_complets_ids, autorites, 10);";
		$onload .= "AutoComplete_Create('auteurs', auteurs_array, auteurs_ids, '', 10);";
		$onload .= "AutoComplete_Create('pays', pays_array, pays_ids, '', 10);";
		$onload .= "AutoComplete_Create('plantes', plantes_array, plantes_ids, '', 10);";
#	}
#	else {
#		open(SEARCHJS, ">$searchjs");
#		
#		my $names = request_tab("SELECT nc.index, nc.orthographe, nc.autorite FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species','subgenus','subspecies') ORDER BY nc.orthographe;",$dbc,2);
#		my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
#		my $distribs = request_tab("SELECT index, $xlang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
#		my $plants = request_tab("SELECT index, get_host_plant_name(index) AS fullname FROM plantes WHERE index in (SELECT DISTINCT ref_plante FROM taxons_x_plantes) ORDER BY fullname;",$dbc,2);
#		
#		search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
#		search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
#		search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);
#		search_formating('plantes', $plants, \$thesauri, \$onload, $dbc);
#
#		print SEARCHJS $thesauri;
#	
#		close(SEARCHJS);
#	}
#}
#else {
#	die "Can't open $searchjs";
#}

sub getThesaurusItems {
	
	my ($table, $expr) = @_;	
	my ($req, $res, $str);

	$str .= "autorites = {}; ";
	$str .= $table."_ids = {}; ";
	$str .= $table."_array = {}; ";
		
	if ($table eq 'noms_complets') { 
		
		$req = "SELECT nc.index, nc.orthographe, nc.autorite FROM noms_complets AS nc 
			LEFT JOIN rangs AS r ON nc.ref_rang = r.index 
			WHERE r.en in ('family','genus','species','subgenus','subspecies')
			AND nc.orthographe ilike '%$expr%'
			ORDER BY nc.orthographe;";
		
		$res = request_tab($req, $dbc, 2);
		
		my $i=0;		
		foreach (@{$res}) {
			$str .= $table."_ids[$i] = ".$_->[0]."; ";
			$str .= $table."_array[$i] = ".'"'.$_->[1].'"'."; ";
			$str .= "autorites[$i] = ".'"'.$_->[2].'"'."; ";
			$i++;
		}
		
	}
		
	return($table.'_ARG_'.$str);
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
			document.getElementById(identities[index]).value = '".ucfirst($traduction->{search}->{$xlang})."';
		}
		if (from == 'popup') {
			if (valeur) { 
				document.getElementById(identity).value = valeur;
				document.getElementById(identity).focus();
			}
		}
	}
	function setThesaurusItems() { 
		var arr = arguments[0].split('_ARG_');
		var tbl = arr[0]; 
		var str = arr[1]; 
		alert(tbl);
		alert(str);
		eval(str);
		alert(__AutoComplete[tbl]);
		__AutoComplete[tbl]['autorites'] = eval('autorites');
		__AutoComplete[tbl]['data'] = eval(tbl+'_array');
		__AutoComplete[tbl]['dataids'] = eval(tbl+'_ids');
		AutoComplete_ShowDropdown(tbl);
	}
";

my $typdef = $searchtable;
my $search_fields;
my $z = 1;
foreach my $key (sort {$types{$a} cmp $types{$b}} keys(%types)) {
	$search_fields .= textfield(
		-name=> "search$z", 
		-class=>'searchField',
		-id=>$key,
		-style=>"z-index: $z;",
		-onFocus=>"if(this.value == '".ucfirst($traduction->{search}->{$xlang})."') { this.value = '' }",
		-onKeyUp => "if(this.value.length > 1) { getThesaurusItems(['args__$key', 'search$z', 'NO_CACHE'], [setThesaurusItems]); }",
		-onBlur=>"if(!this.value) { this.value = '".ucfirst($traduction->{search}->{$xlang})."' }"
	);
	$z++;
}

# varibales globales pour tout site		
my ($html, $bandeau, @menus,%submenus,%menulinks, @menuSpaces, $activepage, $content);

## LE CONTENU ##################################
my $header;
my $card = url_param('card') || '';
if ($xbase eq 'flow') {	
		
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
		if ($param = url_param('limit')) { $args .= " -limit=$param " }
		
		my $id = url_param('id') || '';
		
		#if (url_param('card') eq 'searching') { die param('hiddensearch'). " = $args" }
		
		my $alph = url_param('alph') || 'NULL';
		
		$pagetitle = get_title($dbc, $xbase, $card, $id, $search, $xlang, 'NULL', $alph, $traduction);
				
		$script = "/var/www/html/perl/explorer20.pl $args";
	}
	elsif ($xpage eq 'project') {
					
		$content = 	table(
					Tr(
					td({-style=>"padding-right: 20px; width: 700px;"},
							span({-name=>'ori', -class=>'paragrafTitleStyle'}, $traduction->{'ori_key'}->{$xlang}),p,
							$traduction->{'oritxt'}->{$xlang}
						),
						td({-style=>'width: 100px;'}, img({-src=>$docpath."intricata.png", alt=>"intricata", width=>'100px', height=>'200px'}))
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"}, img({-src=>$docpath."vohimana3.png", alt=>"vohimana", width=>'200px', height=>'150px'}),p),
						td(
							span({-name=>'desc', -class=>'paragrafTitleStyle'}, $traduction->{'descr_key'}->{$xlang}),p,
							$traduction->{'presenttxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'tech', -class=>'paragrafTitleStyle'}, $traduction->{'tech_key'}->{$xlang}),p,
							$traduction->{'techtxt'}->{$xlang}
						),
						td(img({-src=>$docpath."fulgore2.png", alt=>"fulgore", width=>'180px', height=>'200px'}))
					)
				).
				table(
					Tr(
						
						td(
							span({-name=>'com', -class=>'paragrafTitleStyle'}, $traduction->{'community'}->{$xlang}),p,
							$traduction->{'commutxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						
						td({-style=>"padding-right: 20px;"},
							span({-name=>'col', -class=>'paragrafTitleStyle'}, $traduction->{'collabos'}->{$xlang}), br, br,
							$traduction->{'collabtxt'}->{$xlang}, br, br,
							a({-href=>"http://www.gbif.org/"}, img{-src=>$docpath.'gbif.jpg', -style=>'border: 0; height:50px; width: 89px;'}),
							a({-href=>"http://www.sp2000.org/"}, img{-src=>$docpath.'sp2k.png', -style=>'border: 0; height:50px; width: 113px;'}),
							a({-href=>"http://www.biocase.org/index.shtml"}, img{-src=>$docpath.'biocase.png', -style=>'border: 0; height:50px; width: 77px;'}), p
						)
					)
				).
				table(
					Tr(
						td({-style=>"padding-right: 20px;"},
							span({-name=>'ctb', -class=>'paragrafTitleStyle'}, $traduction->{'contrib_key'}->{$xlang}), p({-style=>'text-indent: 20px'}),
							$traduction->{'contribtxt'}->{$xlang}
						)
					)
				).
				table(
					Tr(
						td(
							$traduction->{'dbtnt_standards'}->{$xlang}. p
						)
					)
				).
				span({-class=>'paragrafTitleStyle'}, $traduction->{'arigato'}->{$xlang}). p.	
				$traduction->{'thkintro'}->{$xlang}.		
				ul( "$traduction->{'fulgothanks'}->{$xlang}" );

			$content = div({-class=>'contentContainer card', -style=>'width: 970px; margin-left: 0px; padding: 15px;'}, $content);
	}
	elsif ($xpage eq 'intro') {
		
		$content  = div({-class=>'contentContainer card', -style=>'width: 970px; margin-left: 0px; padding: 15px;'}, 
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgointrotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgointro'}->{$xlang}, p({-style=>'text-indent: 20px'}),
			
			img({-src=>$docpath.'DSC02119.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>$docpath.'DSC02158.jpg', -style=>"width: 259px; height: 194px"}),

			img({-src=>$docpath.'IMG_0492.jpg', -style=>"width: 257px; height: 194pix"}), br, br,

			span({-class=>'paragrafTitleStyle'}, $traduction->{'beetitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgobio'}->{$xlang}, br, br,

			span({-class=>'paragrafTitleStyle'}, $traduction->{'econotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'pests'}->{$xlang}, br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgobiogeotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgobiogeo'}->{$xlang}, br, br,

			img({-src=>$docpath.'DSC02404.jpg', -style=>"width: 150px; height: 200px; margin-right: 50px; "}),

			img({-src=>$docpath.'IMG_0234.jpg', -style=>"width: 133px; height: 200px; margin-right: 50px;"}),

			img({-src=>$docpath.'IMG_0380.jpg', -style=>"width: 133px; height: 200px"}), br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgomorphotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgomorpho'}->{$xlang}, br, br,

			img({-src=>$docpath.'IMG_0301.jpg', -style=>"width: 143px; height: 200px; margin-right: 50px; "}),

			img({-src=>$docpath.'IMG_0469.jpg', -style=>"width: 300px; height: 200px"}), br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'fulgophylotitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),
			
			$traduction->{'fulgophylo'}->{$xlang}, br, br,
			
			span({-class=>'paragrafTitleStyle'}, $traduction->{'refstitle'}->{$xlang}), p({-style=>'text-indent: 20px'}),

			div({-style=>'position: relative; overflow: auto; height: 450px; width: 950px; margin-top: 20px; padding: 0; background: transparent;'},
				$traduction->{'flow_refs_list'}->{$xlang}
			)
		);
	}
	elsif ($xpage eq 'map') {
		$content .= 	div({-class=>'contentContainer'},
					"<div 	style='position: relative; overflow: auto; height: 450px; width: 940px; margin-top: 20px; padding: 0; background: transparent;' 
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
		my $mnhn = a({-href=>"http://www.mnhn.fr/museum/foffice/transverse/transverse/accueil.xsp", -style=>'float: left; text-decoration: none;'}, 
					img({-src=>$docpath.'logo_mnhn.png', -alt=>"MNHN", -style=>'border: 0;', -height=>'80px'}));
		my $upmc = a({-href=>"http://www.upmc.fr/", -style=>'float: left; text-decoration: none;'}, 
					img({-src=>$docpath.'logo_upmc.png', -alt=>"UPMC", -style=>'border: 0; margin-top: 20px;', -height=>'60px'}));
		$content = 	div({-style=>'text-align: center;'},
						#img({-src=>'flowWave.png', -alt=>"FLOW", -style=>"margin-top: 0 auto; padding: 20px 0 20px 0;"}), 
						p, br, p,
						div({-class=>'rotate30 tampon'}, "FLOW new version, v.8:", br, "new interface, new data", br, "and graphical display of name history" ),
						div({-style=>'font-size: 66px; width: 200px; margin-left: 400px;'}, 'FLOW'),
						p, br, p, 
						$traduction->{'home_intro'}->{$xlang}, p({-style=>'text-indent: 20px'}), br,
						$mnhn, $upmc,
						div({-style=>'background: transparent; padding-left: 375px;'},
							div({-style=>'background: transparent; width: 200px; text-align: center;'},
								"Version: ", span({-style=>"font-size: 110%; font-weight: bold"}, 8), br,
								"$traduction->{'dmaj'}->{$xlang}: ", span({-style=>"font-size: 110%; font-weight: bold"}, $last), p({-style=>'text-indent: 0px'}),
								a({-href=>'mailto:bourgoin@mnhn.fr', -style=>'text-decoration: none;'}, "$traduction->{'contact'}->{$xlang}")
							)
						)
					);
		
		$content  = div({-class=>'contentContainer card'}, $content );
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

my $iconMouseOver = "function makeBulle (myelem, myid) {
			var bulle = document.getElementById(myid);
			var pos = findPos(myelem);
			bulle.style.top = 0;
			bulle.style.left = pos[0] - 310 + 'px';
			bulle.style.display = 'block';
		}";


	$header = 	header({-Type=>'text/html', -Charset=>'UTF-8'}).

	start_html(	-title  =>$pagetitle,
			-author =>	'anta@mnhn.fr',
			-head   =>[ 
					meta({-http_equiv => 'Content-Type', -content    => 'text/html; charset=UTF-8'}),
					Link({	-rel=>'shortcut icon',
						-href=>$docpath.'wheel/img/minifulgo.png',
						-type=>'image/x-icon'}),
					Link({	-rel=>'icon',
						-href=>$docpath.'wheel/img/minifulgo.png',
						-type=>'image/x-icon'})
				],
			-meta   =>{'keywords'   =>'FLOW, Fulgoromorpha, Fulgores, Fulgoroidea, Taxonomy, dbtnt', 'description'=>'explorer'},
			-style  => 	{'src'=>$docpath.'flow.css'},
			-script => 	[	{-language=>'JAVASCRIPT', -src=>$docpath.'browserdetect.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'SearchAutoComplete_utf8.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'pngfixall.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'javascriptFuncs.js'},
						#{-language=>'JAVASCRIPT',-src=>$docpath.$config->{'SEARCHJS'}},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/cs_var.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/cs_script.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/jquery-1.7.1.js'},
						{-language=>'JAVASCRIPT',-src=>$docpath.'js/mouseScrolling.js'},
						$analytics,
						$search_actions,
						$iconMouseOver
					],
			-onLoad	=> "	clear_search_except('onload', '$typdef');
					$onload
					if (isIE) {
						document.getElementById('searchpop').style.height = '20px';
					}"
	);
}

my @argus;
foreach (url_param()) { if ($_ ne 'lang') { push(@argus, $_.'='.url_param($_)) } }

my $logo = a({-href=>"$url?db=$xbase&page=home&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/logo_flow.png', -alt=>"FLOW", -style=>'border: 0;', -height=>'46px'}));

my @dd = ('none') x 4;
my @langs = ('en','fr','es','de');
my $i = 0;
foreach (@langs) {
	if ($xlang eq $_) { $dd[$i] = 'block'; last; }
	$i++;
}

my $flags = 	span( {	-class=>'reactiveFlags', 
			-id=>'en', 
			-style=>"display: $dd[0];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=en'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>$docpath.'en.gif', -alt=>"English", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'fr', 
			-style=>"display: $dd[1];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=fr'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>$docpath.'fr.gif', -alt=>"French", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'es', 
			-style=>"display: $dd[2];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=es'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>$docpath.'es.png', -alt=>"Spanish", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'de', 
			-style=>"display: $dd[3];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');",
			-onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');",
			-onClick=>"	document.searchform.action = '$url?".join('&',@argus)."&lang=de'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>$docpath.'de.png', -alt=>"German", -width=>22, -border=>0})
		).
		div({-style=>'text-align: center;', -onMouseOver=>"this.style.cursor = 'pointer'; magicFlags('reactiveFlags', 'onMouseOver', '$xlang');", -onMouseOut=>"magicFlags('reactiveFlags', 'onMouseOut', '$xlang');"}, 
			img({-src=>$docpath.'triangle.png'})
		);	

my $icons = 	div({-class=>'info', -id=>"families", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'families'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=families&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'families');", -onMouseOut=>"document.getElementById('families').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Fam.png', -alt=>"Families", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"genera", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'genera'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=genera&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'genera');", -onMouseOut=>"document.getElementById('genera').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Gen.png', -alt=>"Genera", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"speciess", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'speciess'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=speciess&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'speciess');", -onMouseOut=>"document.getElementById('speciess').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Spe.png', -alt=>"Species", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"names", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'names'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=names&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'names');", -onMouseOut=>"document.getElementById('names').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Nam.png', -alt=>"Names", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"vernaculars", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'vernaculars'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=vernaculars&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'vernaculars');", -onMouseOut=>"document.getElementById('vernaculars').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/Ver.png', -alt=>"Vernacular names", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"publications", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'publications'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=publications&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'publications');", -onMouseOut=>"document.getElementById('publications').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/pub.png', -alt=>"Publications", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"authors", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'authors'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=authors&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'authors');", -onMouseOut=>"document.getElementById('authors').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/author.png', -alt=>"Authors", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"countries", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'countries'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=countries&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'countries');", -onMouseOut=>"document.getElementById('countries').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/world.png', -alt=>"Geographical distribution", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"plants", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'plants'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=plants&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'plants');", -onMouseOut=>"document.getElementById('plants').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/plant.png', -alt=>"Host plants", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"fossils", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'fossils'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=fossils&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'fossils');", -onMouseOut=>"document.getElementById('fossils').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/ere.png', -alt=>"Fossils", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"images", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'images'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=images&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'images');", -onMouseOut=>"document.getElementById('images').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/photos.png', -alt=>"Images", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"repositories", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'repositories'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&card=repositories&lang=$xlang", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'repositories');", -onMouseOut=>"document.getElementById('repositories').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/deposit.png', -alt=>"Type specimens repositories", -class=>'icon1'})). ' '.
		div({-class=>'info', -id=>"board", -style=>'position: absolute; z-index: 10; display: none;'}, ucfirst($traduction->{'board'}->{$xlang})).
		a({-href=>$url."?db=$xbase&page=explorer&lang=$xlang&card=board#base", -style=>'text-decoration: none;', -onMouseOver=>"makeBulle(this, 'board');", -onMouseOut=>"document.getElementById('board').style.display = 'none';"}, img({-src=>$docpath.'wheel/img/synopsis.png', -alt=>"Synopsis", -class=>'icon1'}));
		
#my $icons2 = 	p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"$url?db=$xbase&page=project&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/project.png', -alt=>"Project", -class=>'icon2'}))).
#		p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"$url?db=$xbase&page=intro&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/fulgo.png', -alt=>"Fulgoromorpha", -class=>'icon2'})));
#		p({-style=>'margin: 0 0 3px 0;'}, a({-href=>"classif.pl", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/classif.png', -alt=>"Classification", -class=>'icon2'})));

my $icons2 = a({-href=>"$url?db=$xbase&page=project&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/project.png', -alt=>"Project", -class=>'icon2'})).
		a({-href=>"$url?db=$xbase&page=intro&lang=$xlang", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/fulgo.png', -alt=>"Fulgoromorpha", -class=>'icon2'}));

my $sb = start_form(    -name=>'searchform', 
			-method=>'post',
			-action=>url()."?db=$xbase&page=explorer&card=searching&lang=$xlang",
			-class=>'searchForm'
	).
	table({-id=>'searchTable', -cellspacing=>0, -cellpadiing=>0},
		Tr(
			td({-style=>'height: 24px; margin: 0; padding-left: 6px; vertical-align: middle;'},
				a({-href=>"$url?".join('&',@argus)."&lang=$xlang&reload=1", -style=>'text-decoration: none;'}, img({-src=>$docpath.'wheel/img/reload.png', -alt=>"English", -width=>20, -border=>0}))
			),
			td({-style=>'height: 24px; padding-left: 4px; vertical-align: middle;'},
			#	div({-class=>"searchTitle"}, ucfirst($traduction->{search}->{$xlang}) )
			' '
			),
			td({-style=>'height: 24px; margin: 0; padding: 0; vertical-align: middle;'}, 	
				popup_menu(
					-name=>'searchtable',
					-class=>'searchPopup',
					-id=>'searchpop',
					-values=>[sort {$types{$a} cmp $types{$b}} keys(%types)],
					-default=> $typdef,
					-labels=>\%types,
					-attributes=>\%attributes,
					-onChange=>"clear_search_except('popup', this.value);"
				)
			),
			td({-style=>'width: 180px; height: 24px; margin: 0; padding: 0; vertical-align: top;'},
				span ({-style=>'position: absolute; margin: 0; padding: 0;'},
					$search_fields
				)
			)
		)
	).
	hidden('searchid', '').
	end_form();

## AFFICHAGE !!! ##########################################
my $arrow;

Delete('hiddensearch');
my $html;
$html .=	$header;
$html .=	$test;
$html .=	"<DIV id='main_container'>";
$html .=	"		<TABLE id='iconsSearchbar'>";
$html .=	"			<TR>";
$html .=	"				<TD ID=logoCell> $logo </TD>";
$html .=	"				<TD ID='searchCell'>";
$html .=	"					<TABLE><TR><TD ID='searchPill'> $sb </TD></TR></TABLE>";
$html .=	"				</TD>";
$html .=	"				<TD CLASS='iconsCell'> $icons </TD>";
$html .=	"				<TD CLASS='iconsCell'> $icons2 </TD>";
$html .=	"				<TD id='flagsCell'>";
$html .=						div ({-id=>'flagsDiv'}, $flags);
$html .=	"				</TD>";
#$html .=	"				<TD id='moreFlagsCell'>";
#$html .=							img({	-src=>'moreFlags.png', 
#								-id=>'moreFlagsImg',
#								-onMouseOver=>"magicFlags('reactiveFlags', 'onMouseOver', '$xlang');", 
#								-onMouseOut=>"this.style.cursor='pointer'; magicFlags('reactiveFlags', 'onMouseOut', '$xlang');"});
#$html .=	"				</TD>";
$html .=	"			<TR>";
$html .=	"		</TABLE>";

#if ($xpage ne 'explorer') {
#	print	"	<TABLE id='leftIcons'>";
#	print	"		<TR>";
#	print	"			<TD id='projectCell'>";
#	print	"				$icons2";
#	print	"			</TD>";
#	print	"		</TR>";
#	print "		</TABLE>";
#}

$html .= 		$content;
if ($xpage eq 'explorer') { 
	$html .= "<DIV class='contentContainer'>";
	my $explorer =  `$script`;
	$html .= $explorer;
	$html .= "</DIV>";
}
$html .=	"</DIV>";



$html .=	end_html();
	
print $pjx->build_html($cgi, $html, {-charset=>'UTF-8'});

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

sub classification {
	
	my $conf = get_connection_params('/etc/flow/classif.conf');
	
	my $dbh = db_connection($conf);
	
	my $trans = read_lang($conf);
	
	my $order = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'order';", $dbh, 2);
	my $classif .= span({-style=>'margin-left: 20px;'},$order->[0][1]) . br;
	
	my $suborders = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $order->[0][0] ORDER BY orthographe;", $dbh, 2);
	
	foreach my $suborder (@{$suborders}) {
	
		my $nom = $suborder->[1];
		
		if ($suborder->[2]) { $nom .= '' }
		
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
		
		my $infraorders = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $suborder->[0] ORDER BY orthographe;", $dbh, 2);
		
		foreach my $infraorder (@{$infraorders}) {
		
			if ($infraorder->[3] eq 'infraorder') {
				
				$nom = $infraorder->[1];
				
				if ($infraorder->[2]) { $nom .= '' }
				
				$classif .= span({-style=>'margin-left: 60px;'},$nom) . br;
				
				my $sons = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
				
				foreach my $son (@{$sons}) {
				
					if ($son->[3] eq 'super family') {
						
						$nom = $son->[1];
						
						if ($son->[2]) { $nom .= '' }
						
						$classif .=span({-style=>'margin-left: 80px;'},$nom) . br;
						
						my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $son->[0] ORDER BY orthographe;", $dbh, 2);
						
						foreach my $family (@{$families}) {
							
							$nom = $family->[1];
							
							if ($family->[2]) { $nom .= '' }
							
							$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
						}
					}
					elsif ($son->[3] eq 'family') {
						
						$nom = $son->[1];
						
						if ($son->[2]) { $nom .= '' }
						
						$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
					}
				}
			}
			elsif ($infraorder->[3] eq 'super family') {
				
				$nom = $infraorder->[1];
				
				if ($infraorder->[2]) { $nom .= '' }
				
				$classif .= span({-style=>'margin-left: 80px;'},$nom) . br;
				
				my $families = request_tab("SELECT n.index, orthographe, fossil, r.en FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE n.ref_nom_parent = $infraorder->[0] ORDER BY orthographe;", $dbh, 2);
			
				foreach my $family (@{$families}) {
					
					$nom = $family->[1];
					
					if ($family->[2]) { $nom .= '' }
					
					$classif .= span({-style=>'margin-left: 100px;'},$nom) . br;
				}
			}
		}
	}
	
	$classif .= p . span({-style=>'margin-left: 20px;'},"Incertae sedis") . br;
				
	my $incertae = request_tab("SELECT n.index, orthographe, fossil FROM noms AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = 'incertae sedis' ORDER BY orthographe;", $dbh, 2);
	
	foreach my $insed (@{$incertae}) {
		
		my $nom = $insed->[1];
		
		if ($insed->[2]) { $nom .= '' }
		
		$classif .= span({-style=>'margin-left: 40px;'},$nom) . br;
	}
			
	my $content = h2({-style=>'margin-left: 20px'}, "Hemiptera classification"). br. $classif;
}
