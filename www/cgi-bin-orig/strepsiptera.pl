#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul);
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBI;
use DBCommands qw (get_connection_params db_connection request_tab request_hash get_title request_row get_pub_params pub_formating);
use utf8;

my ($db, $card, $id, $lang, $alph, $from, $to, $rank, $search, $searchtable, $searchid, $mode, $privacy);

$db = url_param('db') || 'strepsiptera'; 
$card = url_param('card');
$id = url_param('id');
$lang = url_param('lang') || 'en';
$alph = url_param('alph');
$from = url_param('from');
$to = url_param('to');
$rank = url_param('rank');
$mode = url_param('mode');
$privacy = url_param('privacy');
$searchtable = param('searchtable') || 'noms_complets';
$searchid = param('searchid');

my $config_file = '/etc/flow/strepsexplorer.conf';
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
	'pays' => $trans->{country}->{$lang}
);

my %attributes = (
	'noms_complets' => {'class'=>'tableoption'},
	'auteurs' => {'class'=>'tableoption'},
	'publications' => {'class'=>'tableoption'},
	'pays' => {'class'=>'tableoption'}
);

my $search = url_param('search');
for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	if ($schstr) { $search = $schstr; }
}

my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN nc.autorite ELSE coalesce(nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms WHERE index = (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) || ')', '') END FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species','subgenus','subspecies') ORDER BY nc.orthographe;",$dbc,2);
my $authors = request_tab("SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs;",$dbc,2);
my $pubs = request_tab("SELECT p.index, coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre, '') || coalesce( ' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') FROM publications AS p ORDER BY get_ref_authors(index) || ' ' || p.annee || ' - ' || coalesce(p.titre, '');",$dbc,2);
my $distribs = request_tab("SELECT index, $lang from pays where index in (SELECT DISTINCT ref_pays FROM taxons_x_pays);",$dbc,2);

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


if ($db) { $argvs .= " -db=$db "; $argvtop .= " -db=$db "; } else { $argvs .= " -db=strepsiptera "; $argvtop .= " -db=strepsiptera "; }
if ($card) { $argvs .= " -card=$card " } else { $argvs .= " -card=top " }
if ($id) { $argvs .= " -id=$id " }
if ($lang) { $argvs .= " -lang=$lang "; $argvtop .= " -lang=$lang "; } else { $argvs .= " -lang=en "; $argvtop .= " -lang=fr "; $lang = 'en'; }
if ($alph) { $argvs .= " -alph=$alph " }
if ($from) { $argvs .= " -from=$from " }
if ($to) { $argvs .= " -to=$to " }
if ($rank) { $argvs .= " -rank=$rank " }
if ($mode) { $argvs .= " -mode=$mode " }
if ($privacy) { $argvs .= " -privacy=$privacy " }
if ($search) { $argvs .= " -search=\"$search\" " } else { $argvs .= " -search='' " }
if ($searchtable) { $argvs .= " -searchtable='$searchtable' " }
if ($searchid) { $argvs .= " -searchid=$searchid " }


html_maker();
$dbc->disconnect;
exit;

sub html_maker {
	
	my @params;
	if (url_param) { foreach (url_param()) { if ($_ ne 'lang') { push(@params, $_) } } }
	
	my $args = join('&', map { "$_=".url_param($_) } @params );
	
	my $flags = 	
			img({-src=>"/explorerdocs/en.gif",
				-width=>'22px',
				-style=>'border: 0;',			
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=en"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}
			).			
			img({-src=>"/explorerdocs/fr.gif",
				-width=>'22px',
				-style=>'border: 0;',			
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=fr"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}
			).
			img({-src=>"/explorerdocs/es.gif",
				-width=>'22px',
				-style=>'border: 0;',			
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=es"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}
			).
			img({-src=>"/explorerdocs/de.gif",
				-width=>'22px',
				-style=>'border: 0;',			
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=de"."'; 
						document.getElementById('searchpop').value = '$searchtable';
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}
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
				document.getElementById(identities[index]).value = '".$trans->{search}->{$lang}."';
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
						-onFocus=>"if(this.value != '".$trans->{search}->{$lang}."'){ AutoComplete_ShowDropdown(this.getAttribute('id')); } else { this.value = '' }",
						-onBlur=>"if(!this.value) { this.value = '".$trans->{search}->{$lang}."' }"
				);
		$z++;
	}
	
	my $sb = table({-style=>'background: transparent; padding: 0; margin: 0;', -cellspacing=>0, -cellpadiing=>0, -border=>0},
			Tr(	
				td({-style=>'margin: 0; padding: 0; width: 0px; text-align: left;'}, 	
					div({-class=>"searchtitle"}, '' )
				),
				td({-style=>'margin: 0; padding: 0; width: 0px; vertical-align: middle; text-align: right;'}, 	
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
		);
		
	my $title;
	if ($card) { $title = get_title($dbc, $db, $card, $id, $search, $lang, undef, 'NULL', $trans); } else { $title = 'Strepsiptera database'; }


	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	print start_html(-title  =>$title,
			-base   =>'true',
			-head	=>[ 
                             	meta({	-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=utf8'})
			],

			-meta   =>{'keywords'   =>'DBTNT, strepsiptera', 'description'=>'explorer'},
			-script=>[	{-language=>'JAVASCRIPT',-src=>'/explorerdocs/pngfixall.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/SearchAutoComplete_utf8.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/'.$config->{'SEARCHJS'}},
					$search_actions],
			-style  =>{'src'=>$config->{CSS}},
			-onLoad	=> "	$onload
					clear_search_except('onload', '$typdef'); "
		);

	print 	start_form(    -name=>'searchform', 
				-method=>'post',
				-action=>url()."?db=$db&card=searching&lang=$lang",
				-class=>'searchform'
		);
	
	my $dbinfos = request_tab("SELECT gsdid, short_name, name, title, description, version, version_date, view, contactlink, homelink, searchlink, logolink FROM dbinfo;", $dbc, 2);
	
	print	br;
	print 	"<TABLE style='margin-left: 15px;'>";
	print 	"	<Tr>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/1.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/2.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/3.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/4.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/5.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/6.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"		<Td>";
	print 				img{src=>"/strepsfotos/7.png", -height=>'150px', -style=>'border: 0;'};
	print 	"		</Td>";
	print 	"	</Tr>";
	print 	"</TABLE>";
	print	br;
	print	h1({-style=>'margin-left: 42px;'}, a({-href=>url()}, ucfirst($dbinfos->[0][1])));
	print	span({-style=>'margin-left: 42px;'},"$trans->{'BY'}->{$lang} $dbinfos->[0][7]") . p;
	print 	"<TABLE>";
	print 	"<TR><TD class=colonne1>" . table({-class=>'searchbar'}, Tr(td({-style=>'background: transparent; width: 400px;'}, $sb), td({-style=>'background: transparent; vertical-align: middle;'}, $flags)));
	print 	"</TD><TD class=colonne2>".a({-class=>'exploa', -style=>'margin-left: 40px;', -href=>url()."?lang=$lang"}, $trans->{websitehome}->{$lang})."</TD></TR>";
	print 	hidden('searchid', '');
	print	end_form();
		
	if ($card) {
		print	"<TR><TD class=colonne1 valign=\"top\">";
		system 	"/var/www/html/perl/explorer2.pl $argvs";
	}
	else {
		print	"<TR><TD class=colonne1 valign=\"top\">";
		print  div({-style=>'margin: 20px 0 0 40px; width: 600px;'}, span({-id=>'introduction'}, $trans->{web_front_text}->{$lang}));
	}
	print	"</TD><TD valign=\"top\">";
	print 	"<DIV class=colonne2>";
	system 	"/var/www/html/perl/explorer2.pl $argvtop";
	print 	"</DIV>";
	print	"</TD></TR>";
	print	"</TABLE>";
	
	
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
