#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul);
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBI;
use DBCommands qw (get_connection_params db_connection request_tab request_hash request_row get_pub_params pub_formating);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $lang = url_param('lang') || 'en';

my $config_file = '/etc/flow/peloridexplorer.conf';
my $config = get_connection_params($config_file);
my $dbc = db_connection($config);
my $trans = read_lang($config);
my $searchjs = '/var/www/html/Documents/explorerdocs/'.$config->{'SEARCHJS'};

my $argvs;
my $param;

my %types = ( 
	'noms_complets' => $trans->{sciname}->{$lang},
	'auteurs' => $trans->{author}->{$lang},
	'publications' => $trans->{publication}->{$lang},
	'pays' => $trans->{country}->{$lang},
	'plantes' => $trans->{plant}->{$lang}
);	

my $search = url_param('search');
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	if (my $schstr = param("search$i")) { $search = $schstr; }
}

if ($param = url_param('db')) { $argvs .= " -db=$param " } else { $argvs .= " -db=coleorrhyncha " }
if ($param = url_param('card')) { $argvs .= " -card=$param " } else { $argvs .= " -card=top " }
if ($param = url_param('id')) { $argvs .= " -id=$param " }
if ($lang) { $argvs .= " -lang=$lang "; }
if ($param = url_param('alph')) { $argvs .= " -alph=$param " }
if ($param = url_param('from')) { $argvs .= " -from=$param " }
if ($param = url_param('to')) { $argvs .= " -to=$param " }
if ($param = url_param('rank')) { $argvs .= " -rank=$param " }
if ($param = url_param('mode')) { $argvs .= " -mode=$param " }
if ($param = url_param('privacy')) { $argvs .= " -privacy=$param " }
if ($search) { $argvs .= " -search='$search' " }
if ($param = param('searchtable')) { $argvs .= " -searchtable='$param' " }
if ($param = param('searchid')) { $argvs .= " -searchid=$param " }

#if (url_param('card') eq 'searching') { die $search; }

my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, nc.autorite FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species') ORDER BY r.ordre, nc.orthographe;",$dbc,2);
my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
my $pubs = request_tab("SELECT index from publications;",$dbc,2);
my $distribs = request_tab("SELECT index, $lang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);
my $plants = request_tab("SELECT index, get_host_plant_name(index) AS fullname FROM plantes WHERE index in (SELECT DISTINCT ref_plante FROM taxons_x_plantes) ORDER BY fullname;",$dbc,2);

search_formating('noms_complets', $names, \$thesauri, \$onload, $dbc);
search_formating('auteurs', $authors, \$thesauri, \$onload, $dbc);
search_formating('publications', $pubs, \$thesauri, \$onload, $dbc);
search_formating('pays', $distribs, \$thesauri, \$onload, $dbc);
search_formating('plantes', $plants, \$thesauri, \$onload, $dbc);

if ( open(SEARCHJS, ">$searchjs") ) {
	print SEARCHJS $thesauri;
	close(SEARCHJS);
}
else {
	die "Can't open $searchjs";
}


my $analytics =<<END;
	var _gaq = _gaq || [];
	_gaq.push(['_setAccount', 'UA-21289361-2']);
	_gaq.push(['_trackPageview']);
	(function() {
		var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
		ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
		var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
	})();
END

html_maker("Coleorrhyncha", $lang, $argvs);
$dbc->disconnect();

exit;

sub search_formating {
	my ($table, $arr, $thesaur, $load, $dbh) = @_;
	
	if ($table eq 'publications') {
		foreach (@{$arr}) { $_->[1] = pub_formating(get_pub_params($dbh, $_->[0]), '', $dbh); }
	}
		
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
			if ($_->[1] =~ m|[^A-Z a-z 0-9 : , ( ) \[ \] ! _ = & ° . * ; “ " ’ ” ' \/ \- – ? ‡ \n ]|) {
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
		print 	html_header('Error'),
			h1("Database connection error"),
			pre($error_msg),p;

		return undef;
	}
}

sub html_maker {
	my ($title, $lang, $argvs) = @_;
	
	my $roads; #= a( {href=>url()."?lang=$lang&page=top", -style=>'font-size: 20px;'}, $trans->{"topics"}->{$lang} );
	
	my @params;
	if (url_param) { foreach (url_param()) { if ($_ ne 'lang') { push(@params, $_) } } }
	
	my $args = join('&', map { "$_=".url_param($_) } @params );

	my $flags = 	span( {	-style=>'margin-right: 6px; position: relative; z-index: 3; margin-left: 25px;',
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"document.searchform.action = '".url()."?$args&lang=fr"."'; document.searchform.submit();"}, 
				img{-src=>"/explorerdocs/fr.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"document.searchform.action = '".url()."?$args&lang=en"."'; document.searchform.submit();"}, 
				img{src=>"/explorerdocs/en.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"document.searchform.action = '".url()."?$args&lang=es"."'; document.searchform.submit();"}, 
				img{src=>"/explorerdocs/es.gif", -width=>'22px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"document.searchform.action = '".url()."?$args&lang=de"."'; document.searchform.submit();"}, 
				img{src=>"/explorerdocs/de.gif", -width=>'22px', -style=>'border: 0;'}
			);
       	
	my $search_actions = "
		function clear_search_except(identity) {
			var identities = new Array('".join("','", keys(%types))."');
			for (index in identities) {
				document.getElementById(identities[index]).value = '';
				if (identities[index] != identity) {
					document.getElementById(identities[index]).style.visibility = 'hidden';
				}
				else {
					document.getElementById(identities[index]).style.visibility = 'visible';
				}
			}
		}
	";
	
	my $searchid = param('searchid');
	Delete('searchid');
	my $typdef = param('searchtable') || 'noms_complets';
	my $search_fields;
	my $z = 1;
	foreach my $key (keys(%types)) {
		$search_fields .= textfield(	-name=>"search$z", 
						-class=>'searchfield',
						-style=>"z-index: $z;",
						-id=>"$key",
						-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));" );
		$z++;
	}
	my $sb = start_form(    -name=>'searchform', 
				-method=>'post',
				-action=>"coleorrhyncha.pl?db=coleorrhyncha&card=searching&lang=$lang",
				-class=>'searchform'
		).
		table({-style=>'background: transparent; padding: 0; margin-left: 30px;', -cellspacing=>0, -cellpadiing=>0},
			Tr(	
				td(	span({-style=>'margin-right: 10px;'}, $trans->{search}->{$lang}	) ),
				td(	popup_menu(
						-name=>'searchtable',
						-class=>'typepopup',
						-style=>'margin-right: 10px;',
						-values=>[sort {$types{$a} cmp $types{$b}} keys(%types)],
						-default=> $typdef,
						-labels=>\%types,
						-onChange=>"clear_search_except(this.value);"
					)
				),
				td({-style=>'position: relative; display: inline;'},
					$search_fields
				)
			)
		).
		hidden('searchid', '').
		end_form();
		
	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	print start_html(-title  =>$title,
			-author =>'anta@mnhn.fr',
			-base   =>'true',
			-head   =>meta({-http_equiv => 'Content-Type', -content    => 'text/html; charset=UTF-8'}),
			-meta   =>{'keywords'   =>'DBTNT, RYNCHOTEAM', 'description'=>'explorer'},
			-script=>[	{-language=>'JAVASCRIPT',-src=>'/explorerdocs/pngfixall.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/Search_complete_pelorid_utf8.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/'.$config->{'SEARCHJS'}},
					$analytics,
					$search_actions],
			-style  =>{'src'=>$config->{CSS}},
			-onLoad	=> "	PngFixImg();
					PngFixBkground();
					$onload
					clear_search_except('$typdef');
					if (top.location.href != location.href) {
						top.location.href = location.href;
					};"
		);

	print	div({-id=>'leftdiv'},
			#"searchid = $searchid", br, map { $_ . " = " . param($_) . br } param(), 
			img{-src=>"/explorerdocs/MBB_Logo_changing.gif", width=>'90%', -style=>'margin: 20px 0 0 20px; float: none;'}, p,
			span({-class=>'roadstyle'}, b("$trans->{'BY'}->{$lang} Daniel Burckhardt")),
			span({-class=>'roadstyle'}, b('daniel.burckhardt@unibas.ch')), br, br,
			$flags,
			div({-style=>'background: transparent; margin-top: 40px;'},
				img{-src=>"/explorerdocs/pelo1.png", -width=>'42%', -style=>'margin: 0 0 0 20px; float: left;'},
				img{-src=>"/explorerdocs/pelo2.png", -width=>'42%', -style=>'margin: 0 0 0 10px; float: none;'}
			),
			div({-style=>'background: #CCEEEE; margin-top: 40px; width: 90%; margin-left: 8%; padding: 20px 0 20px 0; font-weight: normal;'},
                                a( {-href=>url()."?lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'main_page'}->{$lang})),			
				a( {-href=>url()."?card=top&db=coleorrhyncha&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'flow_db'}->{$lang})),
				a( {-href=>url()."?page=coleorrhyncha&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, 'Coleorrhyncha'),
				a( {-href=>url()."?page=morphology&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'morpho_key'}->{$lang}) . 
						" $trans->{'taxaand'}->{$lang} $trans->{'anato'}->{$lang}" ),
				a( {-href=>url()."?page=biology&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'biology'}->{$lang})),
				a( {-href=>url()."?page=phylogeny&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'phylo_key'}->{$lang})),
				a( {-href=>url()."?page=fossils&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'fossils'}->{$lang})),
				a( {-href=>url()."?page=biogeography&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'biogeo_key'}->{$lang})),
				a( {-href=>url()."?page=references&lang=$lang", -style=>'display: block; margin: 0 0 8px 15px;'}, ucfirst($trans->{'pubref_key'}->{$lang}))
			)
		),
		
		div({-class=>'sitetitle'}, "Moss Bug Base" ),
		div({-class=>'sitesubtitle'}, $trans->{'coleorrhyncha_title'}->{$lang}),
		
		"<DIV id=middiv>",
			$sb . p;
	#jompo
	my $yyy = url_param('page');
	if ( ! defined($yyy) ) {
		$yyy = '';
	}
	if (url_param('db')) {
		system  "/var/www/html/perl/explorer2.pl $argvs";
	}
	elsif ($yyy eq 'coleorrhyncha') {
		print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Coleorrhyncha section under construction');
	}
	elsif ($yyy eq 'morphology') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Morphology section under construction');
	}
	elsif ($yyy eq 'biology') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Biology section under construction');
	}
	elsif ($yyy eq 'phylogeny') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Phylogeny section under construction');
	}
	elsif ($yyy eq 'fossils') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Fossils section under construction');
	}
	elsif ($yyy eq 'biogeography') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'Biogeography section under construction');
	}
	elsif ($yyy eq 'references') {
		 print span({-style=>'display: block; margin: 60px 0 0 280px'}, 'References section under construction');
	}
	else {
		print div({-class=>'intro'}, $trans->{'mbb_intro'}->{$lang});		
	}
	print	"</DIV>",
		div({-id=>'rightdiv'},
			img{-src=>"/explorerdocs/Bild_6.jpg", -style=>'margin: 10px 0 0 10px; float: right;', -width=>'86%'},
			img{-src=>"/explorerdocs/Bild_1.jpg", -style=>'margin: 10px 0 0 10px; float: right;', -width=>'86%'},
			img{-src=>"/explorerdocs/Bild_5.jpg", -style=>'margin: 10px 0 0 10px; float: right;', -width=>'86%'},
			img{-src=>"/explorerdocs/Bild_3.jpg", -style=>'margin: 10px 0 0 10px; float: right;', -width=>'86%'}
		);
}
