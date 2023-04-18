#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul);
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBI;
use DBCommands qw (get_connection_params db_connection request_tab request_hash get_title request_row);
use utf8;
#jompo
use open ':std', ':encoding(UTF-8)';

my ($db, $card, $id, $lang, $alph, $from, $to, $rank, $search, $searchtable, $searchid, $mode, $privacy, $limit, $test);

$db = url_param('db') || 'psylles'; 
$card = url_param('card');
$id = url_param('id');
$lang = url_param('lang') || 'en';
$alph = url_param('alph');
$from = url_param('from');
$to = url_param('to');
$rank = url_param('rank');
$mode = url_param('mode');
$privacy = url_param('privacy');
$limit = url_param('limit');
$searchtable = param('searchtable') || 'noms_complets';
$searchid = param('searchid');

$test = '<div id="testDiv"></div>';
my $config_file = '/etc/flow/psyllesexplorer.conf';
my $config = get_connection_params($config_file);
my $dbc = db_connection($config);
my $trans = read_lang($config);
my $searchjs = '/var/www/html/Documents/explorerdocs/'.$config->{'SEARCHJS'};

my $argvs; 
my $argvtop = " -card=top ";

my %types = ( 
	'noms_complets' => $trans->{sciname}->{$lang},
	'auteurs' => $trans->{author}->{$lang},
	'publications' => $trans->{publication}->{$lang},
	'pays' => $trans->{country}->{$lang},
	'taxons_associes' => $trans->{associated_taxa}->{$lang}
);

my %attributes = (
	'noms_complets' => {'class'=>'tableoption'},
	'auteurs' => {'class'=>'tableoption'},
	'publications' => {'class'=>'tableoption'},
	'pays' => {'class'=>'tableoption'},
	'taxons_associes' => {'class'=>'tableoption'}
);

$search = url_param('search');
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	#jompo
	if ( defined ($schstr) ) {
		if (ucfirst($schstr) ne ucfirst($trans->{search}->{$lang})) { $search = $schstr; }
	}
}

my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN nc.autorite ELSE coalesce(nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms WHERE index = (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) || ')', '') END FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','subfamily','tribe','subtribe','genus','species','subgenus','subspecies') AND nc.index IN (SELECT DISTINCT ref_nom FROM taxons_x_noms) ORDER BY nc.orthographe;",$dbc,2);
my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
my $pubs = request_tab("SELECT p.index, coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre, '') || coalesce( ' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') FROM publications AS p ORDER BY get_ref_authors(index) || ' ' || p.annee || ' - ' || coalesce(p.titre, '');",$dbc,2);
my $distribs = request_tab("SELECT index, $lang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
my $associes = request_tab("SELECT index, get_taxon_associe_full_name(index) AS fullname FROM taxons_associes WHERE index in (SELECT DISTINCT ref_taxon_associe FROM taxons_x_taxons_associes) ORDER BY fullname;",$dbc,2);

search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
search_formating('publications', $pubs, \$thesauri, \$onload, $dbc);
search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);
search_formating('taxons_associes', $associes, \$thesauri, \$onload, $dbc);

if ( open(SEARCHJS, ">$searchjs") ) {
	print SEARCHJS $thesauri;
	close(SEARCHJS);
}
else {
	die "Can't open $searchjs";
}


if ($db) { $argvs .= " -db=$db "; $argvtop .= " -db=$db "; } else { $argvs .= " -db=psylles "; $argvtop .= " -db=psylles "; }
if ($card) { $argvs .= " -card=$card " } else { $argvs .= " -card=top " }
if ($id) { $argvs .= " -id=$id " }
if ($lang) { $argvs .= " -lang=$lang "; $argvtop .= " -lang=$lang "; } else { $argvs .= " -lang=en "; $argvtop .= " -lang=fr "; $lang = 'en'; }
if ($alph) { $argvs .= " -alph=$alph " }
if ($from) { $argvs .= " -from=$from " }
if ($to) { $argvs .= " -to=$to " }
if ($rank) { $argvs .= " -rank=$rank " }
if ($mode) { $argvs .= " -mode=$mode " }
if ($privacy) { $argvs .= " -privacy=$privacy " }
if ($limit) { $argvs .= " -limit=$limit " }
if ($search) { $argvs .= " -search=\"$search\" " } else { $argvs .= " -search='' " }
if ($searchtable) { $argvs .= " -searchtable='$searchtable' " }
if ($searchid) { $argvs .= " -searchid=$searchid " }

my $analytics =<<END;
	var _gaq = _gaq || [];
	_gaq.push(['_setAccount', 'UA-21289361-1']);
	_gaq.push(['_trackPageview']);
	(function() {
		var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
		ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
	})();
END

html_maker();
$dbc->disconnect;
exit;

sub html_maker {
	
	my $roads;	
	my @params;
	if (url_param) { 
		foreach (url_param()) { 
			if ($_ ne 'lang') { push(@params, $_); }
		}
	}
	
	my $args = join('&', map { "$_=".url_param($_) } @params );

	#jompo
	if ( ! defined($searchid) ) {
		$searchid = '';
	}
	if ( ! defined($search) ) {
		$search = '';
	}
	my $flags = 	span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;',
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=fr"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{-src=>"/explorerdocs/fr.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=en"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/explorerdocs/en.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=es"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/explorerdocs/es.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=de"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/explorerdocs/de.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=pt"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/explorerdocs/br.png", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=zh"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/explorerdocs/zh.png", -width=>'22px', -style=>'border: 0;'}
			);
	
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
				document.getElementById(identities[index]).value = '".ucfirst($trans->{search}->{$lang})."';
			}
			if (from == 'popup') {
				if (valeur) { 
					document.getElementById(identity).value = valeur;
					document.getElementById(identity).focus();
				}
			}
		}
	";
	
	my $searchid = param('searchid');
	Delete('searchid');
	my $typdef = param('searchtable');
	unless ($typdef) { $typdef = 'noms_complets'};
	my $search_fields;
	my $z = 1;
	foreach my $key (sort {$types{$a} cmp $types{$b}} keys(%types)) {
		$search_fields .= textfield(	-name=>"search$z", 
						-class=>'searchfield',
						-style=>"z-index: $z;",
						-id=>"$key",
						-onFocus=>"if(this.value != '".ucfirst($trans->{search}->{$lang})."'){ AutoComplete_ShowDropdown(this.getAttribute('id')); } else { this.value = '' }",
						-onBlur=>"if(!this.value) { this.value = '".ucfirst($trans->{search}->{$lang})."' }"
				);
		$z++;
	}
	
	my $sb = start_form(    -name=>'searchform', 
				-method=>'post',
				-action=>url()."?db=$db&card=searching&lang=$lang",
				-class=>'searchform'
		).
		table({-style=>'background: transparent; padding: 0; margin: 0;', -cellspacing=>0, -cellpadiing=>0, -border=>0},
			Tr(	
				td({-style=>'margin: 0; padding: 0; width: 218px; text-align: left; vertical-align: top;'}, 	
					div({-class=>"searchtitle"}, ucfirst($trans->{dbaxs}->{$lang}) )
				),
				td({-style=>'margin: 0; padding: 0; width: 220px; text-align: right;'}, 	
					popup_menu(
						-name=>'searchtable',
						-class=>'tablepopup',
						-id=>'searchpop',
						# jompo -values=>[sort {$types{$a} cmp $types{$b}} keys(%types), '.' x 50],
						-values=>[sort keys(%types), '.' x 50],
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

	my $intro;
	my $content;
	my $info = url_param('info');
	
	my @menus = (	a( {-href=>url()."?lang=$lang"}, ucfirst($trans->{main_page}->{$lang})),
			a( {-href=>url()."?info=psylloidea&lang=$lang"}, 'Psylloidea'),
			a( {-href=>url()."?info=contributors&lang=$lang"}, ucfirst($trans->{contributors}->{$lang})),
			a( {-href=>url()."?info=projects&lang=$lang"}, ucfirst($trans->{projects}->{$lang})),
			a( {-href=>url()."?info=technical&lang=$lang"}, ucfirst($trans->{tech_key}->{$lang})),
			a( {-href=>url()."?info=howtocite&lang=$lang"}, ucfirst($trans->{citation}->{$lang})),
			a( {-href=>url()."?info=links&lang=$lang"}, ucfirst($trans->{extlinks}->{$lang})),
			a( {-href=>url()."?db=psylles&lang=$lang&card=board"}, ucfirst($trans->{board}->{$lang})),
			a( {-href=>url()."?info=contact&lang=$lang"}, ucfirst($trans->{contact}->{$lang}))
	);

	if ($argvs=~ m/card=top/ and !$info) { 
		$content = div({-class=>'infos', -style=>'text-align : none;'}, br. br. $trans->{psyltext}->{$lang});
		$menus[0] = span({-class=>'activemenu'}, $menus[0]);
	}

	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	#$onload .= "PngFixImg(); PngFixBkground();";
	$onload .= "if (top.location.href != location.href) { top.location.href = location.href };";
			
	my $css = $config->{CSS};
	#jompo added
	if ( ! defined($card) ) {
		$card='';
	}	
	#jompo added
	if ( ! defined($info) ) {
		$info='';
	}	
	my $title = get_title($dbc, $db, $card, $id, $search, $lang, $info, $alph || 'NULL', $trans);
		
	print start_html(-title  =>$title,
			-author =>'anta@mnhn.fr',
			-base   =>'true',
			-head	=>[ 
                             	meta({	-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=utf8'}),
				Link({	-rel=>'shortcut icon',
					-href=>'/explorerdocs/psylicon.jpg',
					-type=>'image/x-icon'}),
				Link({	-rel=>'icon',
					-href=>'/explorerdocs/psylicon.jpg',
					-type=>'image/x-icon'})
			],

			-meta   =>{'keywords'   =>'psyllid, psyllids, jumping plant lice, jumping plant louse, psylle, psylles, psylliden, psyllidos, psyllido, psylloidea, psyllomorpha, psyllodea, psyllidomorpha, dbtnt', 'description'=>'explorer'},
			-script=>[	{-language=>'JAVASCRIPT',-src=>'/explorerdocs/pngfixall.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/SearchAutoComplete_utf8.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/'.$config->{'SEARCHJS'}},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/javascriptFuncs.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/cs_script.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/mouseScrolling.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/jquery-2.0.3.min.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/OpenLayers-2.13.1/OpenLayers.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/compositeMaps.js'},
					$analytics,
					$search_actions],
			-style  =>{'src'=>$css},
			-onLoad	=> "	$onload
					clear_search_except('onload', '$typdef'); "
		);

	print	"<a name='psyltop'>";
	print	"<IMG src='/explorerdocs/FondDiapo.png' alt='IAMGE' STYLE='position: fixed; top:0; right:0; z-index: -1;'>";
	print	p;
	print	table(
			Tr(
				td(	a({-href=>url()."?lang=$lang"}, span({-class=>'sitetitle'}, "Psyl'list")) . 
					$flags . 
					div({-id=>'roadstyle', -style=>'width: 400px; border: 0px solid #222222;'}, a( {-href=>url()."?info=contact&lang=$lang"}, i({-style=>'color: #ff9000;'}, "$trans->{'BY'}->{$lang} David Ouvrard") ) )
				),
				td({-style=>'padding-left: 30px;'},
					table({-style=>'margin-bottom: 10px;', -border=>0}, 
						Tr(
							td({-style=>'width: 112px; text-align: center;'}, a( {-href=>'http://www.mnhn.fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/psyllist/logo_mnhn.png", -height=>'80px'})), 
							td({-style=>'width: 116px; text-align: center;'}, a( {-href=>'http://www.nhm.ac.uk', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/psyllist/logo_nhm.png", -height=>'60px'})), 
							td({-style=>'width: 166px; text-align: right; padding-top: 15px;'}, a( {-href=>'http://www.upmc.fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/psyllist/logoUPMC.png", -height=>'40px'})),
							td({-style=>'text-align: right; padding-top: 15px;'}, '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.a( {-href=>'https://www.anses.fr/fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/psyllist/Anses80.png", -height=>'40px'}))
						))
				)
			)
		);
	
	my $espaceur;
	#jompo
	if ( ! defined($info) ) {
		$info = '';
	}
	my $yyy = url_param('card');
	if ( ! defined($yyy)) { $yyy = ''; }
	if ($info eq 'psylloidea') {
		$content = div({-class=>'infos'}, $trans->{psyl_psylloidea}->{$lang});
		$menus[1] = span({-class=>'activemenu'}, $menus[1]);
	}
	elsif ($info eq 'contributors') {
		$content = div({-class=>'infos'}, $trans->{psyl_contrib}->{$lang});
		$menus[2] = span({-class=>'activemenu'}, $menus[2]);
	}
	elsif ($info eq 'projects') {
		$content = div({-class=>'infos'}, 
				br. br. br. br.
				a( {-href=>"http://www.4d4life.eu/", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{-src=>"/explorerdocs/4D4Life.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://www.catalogueoflife.org/details/database/id/54", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/CoL.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://eol.org/pages/7670777/entries/33739280/overview", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/eol.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://e-taxonomy.eu/", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/edit.png", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://data.gbif.org/datasets/resource/13588/", -style=>'display: block; float: clear; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/gbif.jpg", -height=>'75px', -style=>'border: 0;'}),
			);
		$menus[3] = span({-class=>'activemenu'}, $menus[3]);
	}
	elsif ($info eq 'technical') {
		$content = div({-class=>'infos'}, br. br. br. $trans->{psyl_tech}->{$lang});
		$menus[4] = span({-class=>'activemenu'},$menus[4]);
	}
	elsif ($info eq 'howtocite') {
		$content = div({-class=>'infos'}, br. br. br. br. $trans->{psyl_cite}->{$lang});
		$menus[5] = span({-class=>'activemenu'}, $menus[5]);
		print	"<script type='text/javascript'>
				var months=new Array(12);
				months[0]='January';
				months[1]='February';
				months[2]='March';
				months[3]='April';
				months[4]='May';
				months[5]='June';
				months[6]='July';
				months[7]='August';
				months[8]='September';
				months[9]='October';
				months[10]='November';
				months[11]='December';
			</script> ";

	}
	elsif ($info eq 'links') {
		$menus[6] = span({-class=>'activemenu'}, $menus[6]);
		
		$content = div({-class=>'infos'}, $trans->{psyl_links}->{$lang});
			
	}	
	# jompo elsif (url_param('card') eq 'board') {
	elsif ($yyy eq 'board') {
		$espaceur = br;
		$menus[7] = span({-class=>'activemenu'}, $menus[7]);
	}
	elsif ($info eq 'contact') {
		$content = div({-class=>'infos'},
			"<form name='formulaire' action='traitement.php' method='post'>
			<div class='mailtitle'>$trans->{lastname}->{$lang} &nbsp;</div>
			<input name='nom' type='text' size='50' class='mailfield'><br>
			<div class='mailtitle'>$trans->{firstname}->{$lang} &nbsp;</div>
			<input name='prenom' type='text' size='50' class='mailfield'><br>
			<div class='mailtitle'>Email &nbsp;</div>
			<input name='email' type='text' size='50' class='mailfield'><br>
			<div class='mailtitle'>$trans->{subject}->{$lang} &nbsp;</div>
			<input name='sujet' type='text' size='50' class='mailfield'><p>
			<textarea name='texte'  cols='50' rows='20' class='mailfield' style='margin-left: 100px;'></textarea><p>
			<input name='annuler' type='reset' value='Reset' style='margin-left: 100px;'>&nbsp;
			<input name='soumettre' type='submit' value='Submit'><br>
			</form>"
		);
		$menus[8] = span({-class=>'activemenu'}, $menus[8]);
		
		#-src=>'/explorerdocs/DOMailAddress.png'
		$content = div({-class=>'infos'}, $trans->{psyltocontact}->{$lang} . ' ' . img{-style=>'margin-top: 0px; display: block;', -src=>'/explorerdocs/DOMailAddress.png'});
	}
		
	print	$test . p;
	print	"<TABLE CLASS='menushaut' STYLE='margin-left: 35px; border: solid 1px #777777; width: 950px; text-align: center;' CELLPADDING=0 CELLSPACING=0>";
	print	"<TR><TD COLSPAN=30 STYLE='text-align: right; vertical-align: middle; background: #222222; padding: 3px 2px 3px 2px; border-bottom: solid 1px #777777;'>" . $sb . "</TD></TR>";
	# jompo system 	"/var/www/html/perl/explorer20.pl $argvtop -mode=" . url_param('card');
	if ($yyy eq '' ) {
	} else {
		system 	"/var/www/html/perl/explorer20.pl $argvtop -mode=" . $yyy;
	}
	print	"</TABLE>";
	if ( defined ($espaceur) ) {
		print	$espaceur;
	}
	if ($content) {
		print 	$content;
	} else {
		print "<DIV class='contentContainer'>";
		system 	"/var/www/html/perl/explorer20.pl $argvs";
		print "</DIV>";
	}
	print	"<table class='menusbas' cellspacing=0>";
	print	"<tr><td valign=center>" . join('</td><td style="background: black; vertical-align: middle; text-align: center; padding: 2px;">-</td><td style="background: black;  vertical-align: middle; text-align: center; padding: 4px 2px;">', @menus) . "&nbsp;</td></tr>";
	print	"</table><p>";
	
	#print	div( {	-style=>'position: fixed; left: 2px; top: 15px; font-size: 10px;', 
	#		-onMouseOver=>"this.style.cursor = 'pointer';",
	#		-onClick=>"	document.searchform.action = '".url()."?$args&lang=$lang#psyltop"."'; 
	#				document.getElementById('searchpop').value = '$searchtable';
	#				document.getElementsByName('searchid')[0].value = '$searchid';
	#				document.getElementById('$searchtable').value = '$search';
	#				document.searchform.submit();"}, 
	#		img({-src=>"/explorerdocs/flechetop.png", -style=>'border: 0;'})
	#	);
	#print	div( {	-style=>'position: fixed; left: 2px; top: 38px; font-size: 10px;', 
	#		-onMouseOver=>"this.style.cursor = 'pointer';",
	#		-onClick=>"	document.searchform.action = '".url()."?$args&lang=$lang#psylbottom"."'; 
	#				document.getElementById('searchpop').value = '$searchtable';
	#				document.getElementsByName('searchid')[0].value = '$searchid';
	#				document.getElementById('$searchtable').value = '$search';
	#				document.searchform.submit();"}, 
	#		img({-src=>"/explorerdocs/flechebottom.png", -style=>'border: 0;'})
	#	);
	#print time()-$start;
	print end_html();
}

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
				my ($res) = @{request_row("SELECT reencodage(E'".$_->[1]."');", $dbh)};
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
		$tr = $dbc->selectall_hashref("SELECT id, $lang FROM traductions;", "id");
		$dbc->disconnect;
		return $tr;
	}
	else {
		my $error_msg .= $DBI::errstr;
		print 	header(),
			start_html(-title  =>'Error'),
			h1("Database connection error"),
			pre($error_msg),p;

		return undef;
	}
}
