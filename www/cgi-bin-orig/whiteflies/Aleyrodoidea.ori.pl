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

$db = url_param('db') || 'aleurodes'; 
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

my $config_file = '/etc/flow/aleurodsexplorer.conf';
my $config = get_connection_params($config_file);
my $dbc = db_connection($config);
my $trans = read_lang($config);
my $searchjs = '/var/www/html/Documents/explorerdocs/'.$config->{'SEARCHJS'};
#my $searchjs = '/var/www/html/Documents/explorerdocs/'.$config->{'SEARCHJS'};

my $argvs; 
my $argvtop = " -card=top ";

my %types = ( 
	'noms_complets' => $trans->{sciname}->{$lang},
	'auteurs' => $trans->{author}->{$lang},
	'publications' => $trans->{publication}->{$lang},
	'pays' => $trans->{country}->{$lang},
	'plantes' => $trans->{plant}->{$lang}
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
	if (ucfirst($schstr) ne ucfirst($trans->{search}->{$lang})) { $search = $schstr; }
}

my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN nc.autorite ELSE coalesce(nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms WHERE index = (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) || ')', '') END FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species','subgenus','subspecies') ORDER BY nc.orthographe;",$dbc,2);
my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
my $pubs = request_tab("SELECT p.index, coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre, '') || coalesce( ' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') FROM publications AS p ORDER BY get_ref_authors(index) || ' ' || p.annee || ' - ' || coalesce(p.titre, '');",$dbc,2);
my $distribs = request_tab("SELECT index, $lang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
my $plants = request_tab("SELECT index, get_host_plant_name(index) AS fullname FROM plantes WHERE index in (SELECT DISTINCT ref_plante FROM taxons_x_plantes) ORDER BY fullname;",$dbc,2);

search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
search_formating('publications', $pubs, \$thesauri, \$onload, $dbc);
search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);

if ( open(SEARCHJS, ">$searchjs") ) {
	print SEARCHJS $thesauri;
	close(SEARCHJS);
}
else {
	die "Can't open $searchjs";
}


if ($db) { $argvs .= " -db=$db "; $argvtop .= " -db=$db "; } else { $argvs .= " -db=aleurodes "; $argvtop .= " -db=aleurodes "; }
if ($card) { $argvs .= " -card=$card " } else { $argvs .= " -card=top " }
if ($id) { $argvs .= " -id=$id " }
if ($lang) { $argvs .= " -lang=$lang "; $argvtop .= " -lang=$lang "; } else { $argvs .= " -lang=fr "; $argvtop .= " -lang=fr "; $lang = 'en'; }
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
	_gaq.push(['_setAccount', 'UA-21289361-3']);
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

	my $url = url();
	my @dd = ('none') x 6;
	my @langs = ('en','fr','es','de', 'pt', 'zh');
	my $i = 0;
	foreach (@langs) { if ($lang eq $_) { $dd[$i] = 'inline'; last; } $i++; }
	
	my $flags = span( {-class=>'reactiveFlags', 
			-id=>'en', 
			-style=>"display: $dd[0];",
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=en'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>'/explorerdocs/en.png', -alt=>"English", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'fr', 
			-style=>"display: $dd[1];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=fr'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>'/explorerdocs/fr.png', -alt=>"French", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'es', 
			-style=>"display: $dd[2];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=es'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>'/explorerdocs/es.png', -alt=>"Spanish", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'de', 
			-style=>"display: $dd[3];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=de'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>'/explorerdocs/de.png', -alt=>"German", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'pt', 
			-style=>"display: $dd[4];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=pt'; 
					document.getElementById('searchpop').value = '$searchtable';
					document.getElementsByName('searchid')[0].value = '$searchid';
					document.getElementById('$searchtable').value = \"$search\";
					document.searchform.submit();"}, 
			img({-src=>'/explorerdocs/br.png', -alt=>"Portuguese", -width=>22, -border=>0})
		).
		span( {	-class=>'reactiveFlags', 
			-id=>'zh', 
			-style=>"display: $dd[5];", 
			-onMouseOver=>"this.style.cursor = 'pointer'; magicFlagsH('reactiveFlags', 'onMouseOver', '$lang');",
			-onMouseOut=>"magicFlagsH('reactiveFlags', 'onMouseOut', '$lang');",
			-onClick=>"	document.searchform.action = '$url?$args&lang=zh'; 
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
		div({style=>'background: transparent; margin-left:auto; margin-right:auto; width: 500px;'},
			table({-style=>'background: transparent; padding: 0;', -cellspacing=>0, -cellpadiing=>0, -border=>0},
				Tr(	
					#td({-style=>'margin: 0; padding: 0; /*width: 168px;*/ text-align: left; vertical-align: top;'}, 	
					#	div({-class=>"searchtitle"}, ucfirst($trans->{dbaxs}->{$lang}) )
					#),
					td({-style=>'margin: 0; padding: 0; /*width: 220px; text-align: right;*/'}, 	
						popup_menu(
							-name=>'searchtable',
							-class=>'tablepopup',
							-id=>'searchpop',
							-values=>[sort {$types{$a} cmp $types{$b}} keys(%types), '.' x 50],
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
			)
		).
		hidden('searchid', '').
		end_form();

	my $info = url_param('info');
	
	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	$onload .= "if (top.location.href != location.href) { top.location.href = location.href };";
			
	my $css = $config->{CSS};
	
	my $title = get_title($dbc, $db, $card, $id, $search, $lang, $info, $alph || 'NULL', $trans);
	
	my @menus = (	a( {-style=>' color: #DDDDDD;', -href=>url()."?lang=$lang"}, ucfirst($trans->{main_page}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=Aleyrodoidea&lang=$lang"}, 'Aleyrodoidea'),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=contributors&lang=$lang"}, ucfirst($trans->{contributors}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=projects&lang=$lang"}, ucfirst($trans->{projects}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=technical&lang=$lang"}, ucfirst($trans->{tech_key}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=howtocite&lang=$lang"}, ucfirst($trans->{citation}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=links&lang=$lang"}, ucfirst($trans->{extlinks}->{$lang})),
			a( {-style=>' color: #DDDDDD;', -href=>url()."?card=contact&lang=$lang"}, ucfirst($trans->{contact}->{$lang}))
	);
	
	my $content;
	my $tail = table({-style=>'margin-bottom: 10px;', -border=>0}, 
			Tr(
				td({-style=>'width: 256px; text-align: left;'}, a( {-href=>'http://www.mnhn.fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/aleurodes/logo_mnhn.png", -height=>'80px'})), 
				td({-style=>'width: 278px; text-align: center;'}, a( {-href=>'http://www.nhm.ac.uk', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/aleurodes/logo_nhm.png", -height=>'60px'})), 
				td({-style=>'width: 330px; text-align: center; padding-top: 15px;'}, a( {-href=>'http://www.upmc.fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/aleurodes/logoUPMC.png", -height=>'40px'})),
				td({-style=>'width: 170px; text-align: right; padding-top: 15px;'}, a( {-href=>'https://www.anses.fr/fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/psyllist/Anses80.png", -height=>'40px'}))
			));
	
	my $explorer = 0;
	if (!$card) {
		my $img;
		if ($lang eq 'en') { $img = 'WFDB_homeEN.png'; }
		elsif ($lang eq 'fr') { $img = 'WFDB_homeFR.png'; }
		elsif ($lang eq 'es') { $img = 'WFDB_homeES.png'; }
		elsif ($lang eq 'de') { $img = 'WFDB_homeDE.png'; }
		else { $img = 'WFDB_homeEN.png'; }
		
		
		$content .= div({-style=>'width: 950px; height: 440px;'}, 
				div({-style=>'position: absolute; z-index: 1;'},
					img{-src=>"/explorerdocs/aleurodes/$img", -usemap=>'#home', -border=>0},
					"<map name='home'>
					<area shape='polygon' coords='6,170,39,51,55,55,65,24,112,41,119,56,229,93,225,112,239,119,192,235' href='http://hemiptera.infosyslab.fr/whiteflies/?card=subfamilies&lang=$lang'>
					<area shape='polygon' coords='174,73,180,51,196,55,207,24,250,38,258,55,370,93,366,112,380,119,334,233,210,191,239,119,225,112,229,93' href='http://hemiptera.infosyslab.fr/whiteflies/?card=genera&lang=$lang'>
					<area shape='polygon' coords='314,73,320,51,336,55,347,24,390,38,398,55,510,93,506,112,520,119,474,233,350,191,379,119,365,112,369,93' href='http://hemiptera.infosyslab.fr/whiteflies/?card=speciess&lang=$lang'>
					<area shape='polygon' coords='455,73,461,51,477,55,488,24,531,38,539,55,651,93,647,112,661,119,615,233,491,191,520,119,506,112,510,93' href='http://hemiptera.infosyslab.fr/whiteflies/?card=names&lang=$lang'>
					<area shape='polygon' coords='596,73,602,51,618,55,629,24,672,38,680,55,792,93,788,112,802,119,756,233,632,191,661,119,647,112,651,93' href='http://hemiptera.infosyslab.fr/whiteflies/?card=authors&lang=$lang'>
					<area shape='polygon' coords='737,73,743,51,759,55,770,24,813,38,821,55,933,93,929,112,943,119,897,233,773,191,802,119,788,112,792,93' href='http://hemiptera.infosyslab.fr/whiteflies/?card=publications&lang=$lang'>
					<area shape='polygon' coords='8,379,41,260,57,264,67,233,114,250,121,265,231,302,227,321,241,328,194,444' href='http://hemiptera.infosyslab.fr/whiteflies/?card=countries&lang=$lang'>
					<area shape='polygon' coords='176,282,182,260,198,264,209,233,252,247,260,264,372,302,368,321,382,328,336,442,212,400,241,328,227,321,231,302' href='http://hemiptera.infosyslab.fr/whiteflies/?card=plants&lang=$lang'>
					<area shape='polygon' coords='316,282,322,260,338,264,349,233,392,247,400,264,512,302,508,321,522,328,476,442,352,400,381,328,367,321,371,302' href='http://hemiptera.infosyslab.fr/whiteflies/?card=fossils&lang=$lang'>
					<area shape='polygon' coords='457,282,463,260,479,264,490,233,533,247,541,264,653,302,649,321,663,328,617,442,493,400,522,328,508,321,512,302' href='http://hemiptera.infosyslab.fr/whiteflies/?card=images&lang=$lang'>
					<area shape='polygon' coords='598,282,604,260,620,264,631,233,674,247,682,264,794,302,790,321,804,328,758,442,634,400,663,328,649,321,653,302' href='http://hemiptera.infosyslab.fr/whiteflies/?card=vernaculars&lang=$lang'>
					<area shape='polygon' coords='739,282,745,260,761,264,772,233,815,247,823,264,935,302,931,321,945,328,899,442,775,400,804,328,790,321,794,302' href='http://hemiptera.infosyslab.fr/whiteflies/?card=board&lang=$lang'>
					</map>"
				)
		);
		$menus[0] = span({-class=>'activemenu'}, $menus[0]);
	}
	elsif ($card eq 'Aleyrodoidea') {
		$content = div({-class=>'infos'}, $trans->{aleurod_aleyrodoidea}->{$lang} || 'Not available');
		$menus[1] = span({-class=>'activemenu'}, $menus[1]);
	}
	elsif ($card eq 'contributors') {
		$content = div({-class=>'infos'}, $trans->{aleurod_contrib}->{$lang} || 'Not available');
		$menus[2] = span({-class=>'activemenu'}, $menus[2]);
	}
	elsif ($card eq 'projects') {
		$content = div({-class=>'infos'}, 
				br. br. br. br.
				a( {-href=>"http://www.4d4life.eu/", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{-src=>"/explorerdocs/4D4Life.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://www.catalogueoflife.org/details/database/id/54", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/CoL.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://eol.org/pages/7670777/entries/33739280/overview", -style=>'display: block; float: left; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/eol.jpg", -height=>'75px', -style=>'border: 0;'}),
				a( {-href=>"http://data.gbif.org/datasets/resource/13588/", -style=>'display: block; float: clear; margin: 0 30px 30px 0;', -target=>'_blank'}, img{src=>"/explorerdocs/gbif.jpg", -height=>'75px', -style=>'border: 0;'})
			);
		$menus[3] = span({-class=>'activemenu'}, $menus[3]);
	}
	elsif ($card eq 'technical') {
		$content = div({-class=>'infos'}, $trans->{aleurod_tech}->{$lang} || 'Not available');
		$menus[4] = span({-class=>'activemenu'}, $menus[4]);
	}
	elsif ($card eq 'howtocite') {
		$content = "<script type='text/javascript'>
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
		$content .= div({-class=>'infos'}, $trans->{aleurod_cite}->{$lang} || 'Not available');
		$menus[5] = span({-class=>'activemenu'}, $menus[5]);

	}
	elsif ($card eq 'links') {
		$content = div({-class=>'infos'}, $trans->{aleurod_links}->{$lang} || 'Not available');
		$menus[6] = span({-class=>'activemenu'}, $menus[6]);		
	}	
	elsif ($card eq 'contact') {
		$content = div({-class=>'infos', -style=>'margin-left: 400px;'}, img{-style=>'margin-top: 0px; display: block;', -src=>'/explorerdocs/DOMailAddress.png'} || 'Not available');
		$menus[7] = span({-class=>'activemenu'}, $menus[7]);
	}
	else {
		$explorer = 1;
	}

	print start_html(-title  =>$title,
			-author =>'anta@mnhn.fr',
			-base   =>'true',
			-head	=>[ 
                             	meta({	-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=utf8'}),
				Link({	-rel=>'shortcut icon',
					-href=>'/explorerdocs/aleurodes/LogoWF20.png',
					-type=>'image/x-icon'}),
				Link({	-rel=>'icon',
					-href=>'/explorerdocs/aleurodes/LogoWF20.png',
					-type=>'image/x-icon'})
			],
			-meta   =>{'keywords'   =>'Aleurodes,whiteflies,white-files', 'description'=>'explorer'},
			-script=>[	{-language=>'JAVASCRIPT',-src=>'/explorerdocs/pngfixall.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/SearchAutoComplete_utf8.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/'.$config->{'SEARCHJS'}},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/javascriptFuncs.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/cs_var.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/cs_script.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/jquery-2.0.3.min.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/json2.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/OpenLayers-2.13.1/OpenLayers.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/compositeMaps.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/mouseScrolling.js'},
					$analytics,
					$search_actions],
			-style  =>{'src'=>$css},
			-onLoad	=> "	$onload
					clear_search_except('onload', '$typdef'); "
		);
	
	print	"<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 STYLE='width: 980px;'>";
	print 	"<TR><TD COLSPAN=5 CLASS=menu1>";
	print		"<TABLE BORDER=0 STYLE='margin-left:auto; margin-right:auto; color: #DDDDDD; padding: 4px 0;'><TR>";
	print		"<TD VALIGN=CENTER STYLE='padding: 2px;'>" . join('</TD><TD STYLE="padding: 2px;">-</TD><TD STYLE="padding: 4px 2px;">', @menus) . " </TD>";
	print	 	"<TD STYLE='width: 28px;'>";
	print		"<DIV STYLE='position: absolute; margin: -14px 0 0 15px; padding: 2px;'>$flags</DIV>";
	print		"</TD>";
	print		"</TR></TABLE>";
	print 	"</TD></TR>";
	print 	"<TR><TD COLSPAN=5 CLASS=menu2>";
	print		"<TABLE BORDER=0 style='margin-left:auto; margin-right:auto; color: #DDDDDD;'>";
#	system 		"/var/www/html/perl/explorer20.pl $argvtop -mode=" . url_param('card');
	system 		"/var/www/perl/explorer20.pl $argvtop -mode=" . url_param('card');
	print		"</TABLE>";
	print 	"</TD></TR>";
	if (!$card) {
		print 	"<TR><TD ROWSPAN=2 STYLE='padding-top: 5px;'>";
		print	img{-src=>"/explorerdocs/aleurodes/Title_file1.png", -style=>'border: 0;'};
		print 	"</TD><TD STYLE='text-align: center;'>";
		print 	div({-style=>'font-size: 30px; font-weight: bold; margin-top: 20px; color: #555555;'}, "Taxonomic checklist of the world’s whiteflies (Insecta: Hemiptera: Aleyrodidae)");
		print 	"</TD></TR>";
		print 	"<TR><TD style='height: 80px;'>";
		print	$sb;
		print 	"</TD></TR>";	
		print 	"<TR><TD COLSPAN=2 ALIGN=CENTER>$content</TD></TR>";
		print	"</TABLE>";
		print	$tail;
	} else {
		print 	"<TR><TD ROWSPAN=2 STYLE='padding-top: 5px;'>";
		print	a({-href=>url()."?lang=$lang"}, img{-src=>"/explorerdocs/aleurodes/LogoWF80.png", -style=>'border: 0; margin-left: 20px; width: 80px;'});
		print 	"</TD><TD STYLE='text-align: center;'>";
		print 	a({-href=>url()."?lang=$lang"}, div({-class=>'sitetitle'}, "Taxonomic checklist of the world’s whiteflies (Insecta: Hemiptera: Aleyrodidae)"));
		print 	"</TD></TR>";
		print 	"<TR><TD>";
		print	$sb;
		print 	"</TD></TR>";	
		print	"</TABLE>";
		if ($content) {
			print $content;
			print	$tail;
		} elsif ($explorer) {
			print 	"<DIV class='contentContainer'>";
#			system 	"/var/www/html/perl/explorer20.pl $argvs";
			system 	"/var/www/perl/explorer20.pl $argvs";
			print 	"</DIV>";
			print	$tail;
		}
	}
	#print	div({-id=>'roadstyle'}, a( {-href=>url()."?info=contact&lang=$lang"}, i({-style=>'color: #ff9000;'}, "David Ouvrard & Jon H. Martin") ) );
	#print	"<TR><TD COLSPAN=30 STYLE='text-align: right; vertical-align: middle; background: #222222; padding: 3px 2px 3px 2px; border-bottom: solid 1px #777777;'>" . $sb . "</TD></TR>";
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
				#jompo my ($res) = @{request_row("SELECT reencodage(E'".$_->[1]."');", $dbh)};
				my ($res) = @{request_row("SELECT reencodage(".$_->[1].");", $dbh)};
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
