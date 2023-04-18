#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul);
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBI;
use DBCommands qw(get_connection_params db_connection request_tab get_title request_row);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $config_file = '/etc/flow/tingides.conf';

my ($db, $card, $id, $lang, $alph, $from, $to, $rank, $search, $searchtable, $searchid, $mode, $privacy, $limit, $test);

my $config = get_connection_params($config_file);
my $dbc = db_connection($config, 'EXPLORER');

foreach (param()) {
	if ( !param($_) or param($_) =~ m/^-- / ) { Delete($_); }
}

$db = url_param('db') || $config->{"EXPLORER_DB"};
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

my $trans = read_lang($config);

my $searchjs = $ENV{'DOCUMENT_ROOT'}.'/'.$config->{'SEARCHJS'};

my $argvs; 
my $argvtop = " -card=top ";

my %types = ( 'noms_complets' => 1 );

#jompo my %types = ( 
%types = ( 
	'noms_complets' => $trans->{sciname}->{$lang},
	'auteurs' => $trans->{author}->{$lang},
	'publications' => $trans->{publication}->{$lang},
	'pays' => $trans->{country}->{$lang},
	#'plantes' => $trans->{plant}->{$lang}
);

my %attributes = (
	'noms_complets' => {'class'=>'tableoption'},
	'auteurs' => {'class'=>'tableoption'},
	'publications' => {'class'=>'tableoption'},
	'pays' => {'class'=>'tableoption'},
	#'plantes' => {'class'=>'tableoption'}
);

#jompo my $search = url_param('search') || param("search1");
$search = url_param('search') || param("search1");

for (my $i = 1; $i < scalar(keys(%types)) + 1; $i++) {
	my $schstr = param("search$i");
	#jompo
	if ( ! defined($schstr) ) {
		$schstr = '';
	}
	if (ucfirst($schstr) ne ucfirst($trans->{search}->{$lang})) { $search = $schstr; }
}

my $thesauri;
my $onload;
my $names = request_tab("SELECT nc.index, nc.orthographe, nc.autorite FROM noms_complets AS nc LEFT JOIN rangs AS r ON nc.ref_rang = r.index WHERE r.en in ('family','genus','species','subgenus','subspecies') ORDER BY nc.orthographe;",$dbc,2);
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

$argvs .= " -conf=$config_file ";
#jompo $argvtop .= " -conf=$config_file ";

if ($db) { $argvs .= " -db=$db "; $argvtop .= " -db=$db "; }
if ($card) { $argvs .= " -card=$card " } else { $argvs .= " -card=top " }
if ($id) { $argvs .= " -id=$id " }
if ($lang) { $argvs .= " -lang=$lang "; $argvtop .= " -lang=$lang "; } else { $argvs .= " -lang=en "; $argvtop .= " -lang=en "; $lang = 'en'; }
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
	if (! defined($searchid)) {
		$searchid = '';
	}
	my $flags = 	span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;',
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=fr"."'; 
						/*document.getElementById('searchpop').value = '$searchtable';*/
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{-src=>"/dbtntDocs/fr.png", -width=>'20px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=en"."'; 
						/*document.getElementById('searchpop').value = '$searchtable';*/
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/dbtntDocs/en.png", -width=>'20px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=es"."'; 
						/*document.getElementById('searchpop').value = '$searchtable';*/
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/dbtntDocs/es.png", -width=>'20px', -style=>'border: 0;'}
			).
			span( {	-style=>'margin-right: 6px; position: relative; z-index: 3;', 
				-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"	document.searchform.action = '".url()."?$args&lang=de"."'; 
						/*document.getElementById('searchpop').value = '$searchtable';*/
						document.getElementsByName('searchid')[0].value = '$searchid';
						document.getElementById('$searchtable').value = \"$search\";
						document.searchform.submit();"}, 
				img{src=>"/dbtntDocs/de.png", -width=>'20px', -style=>'border: 0;'}
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
						-style=>"z-index: $z; visibility: visible;",
						-value=>'-- '.ucfirst($trans->{search}->{$lang}).' --',
						-id=>"$key",
						-onFocus=>"this.value = ''; if(this.value != '-- ".ucfirst($trans->{search}->{$lang})." --'){ AutoComplete_ShowDropdown(this.getAttribute('id')); }",
						-onBlur=>"if(!this.value) { this.value = '-- ".ucfirst($trans->{search}->{$lang})." --' }"
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
				td({-style=>'margin: 0; padding: 0; width: 200px; text-align: left; vertical-align: top;'}, 	
					div({-class=>"searchtitle"}, ucfirst($trans->{dbaxs}->{$lang}) )
				),
				td({-style=>'margin: 0; padding: 0; width: 220px; text-align: right;'}, 	
					popup_menu(
						-name=>'searchtable',
						-class=>'tablepopup',
						-id=>'searchpop',
						#jompo -values=>[sort {$types{$a} cmp $types{$b}} keys(%types), '.' x 50],
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

	my $content;
	my $webpage = url_param('webpage');
	my @menus = (	a( {-href=>url()."?lang=$lang"}, ucfirst($trans->{main_page}->{$lang})),
			a( {-href=>url()."?webpage=contributors&lang=$lang"}, ucfirst($trans->{contributors}->{$lang})),
			a( {-href=>url()."?webpage=howtocite&lang=$lang"}, ucfirst($trans->{citation}->{$lang})),
			#a( {-href=>url()."?db=$db&lang=$lang&card=board"}, ucfirst($trans->{board}->{$lang})),
			a( {-href=>'mailto:guilbert@mnhn.fr'}, ucfirst($trans->{contact}->{$lang}))
	);
	#jompo
	if (! defined($webpage)) {
		$webpage = '';
	}	
	if ($webpage eq 'contributors') {
		$content = div({-class=>'infos'},
			"We would like to thank warmly the following people for their help and support:<br>
			<UL class=dotslist>
			<LI>Barbara Lis</LI>
			<LI>Melinda Moir</LI>
			<LI>Sara Montemayor</LI>
			</UL>"	
		);
	}
	elsif ($webpage eq 'howtocite') {
		$content = div({-class=>'infos'}, 
			"Guilbert, E. (<script type='text/javascript'>var currentTime = new Date();document.write(currentTime.getFullYear());</script>) - 
			$config->{DB_NAME} - http://www.hemiptera-databases.com/tingidae - searched on 
			<script type='text/javascript'>
				var currentTime = new Date();var month = currentTime.getMonth();document.write(currentTime.getDate()+' '+months[month]+' '+currentTime.getFullYear());
			</script>"
		);
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
			</script> $content";

	}	

	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	$onload .= "if (top.location.href != location.href) { top.location.href = location.href };";
	#jompo
	if (! defined($card)) {
		$card = '';
	}			
	my $title = get_title($dbc, $db, $card, $id, $search, $lang, $webpage, $alph || 'NULL', $trans);
			
	print start_html(-title  =>ucfirst($title),
			-base   =>'true',
			-head	=>[ meta({-http_equiv => 'Content-Type', -content => 'text/html; charset=utf8'}) ],
			-meta   =>{'keywords' => 'DBTNT', 'description' => 'explorer'},
			-script=>[	{-language=>'JAVASCRIPT',-src=>'/dbtntDocs/SearchAutoComplete_utf8.js'},
					{-language=>'JAVASCRIPT',-src=>'/dbtntDocs/javascriptFuncs.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/jquery-2.0.3.min.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/json2.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/OpenLayers-2.13.1/OpenLayers.js'},
					{-language=>'JAVASCRIPT',-src=>'/explorerdocs/js/compositeMaps.js'},
					{-language=>'JAVASCRIPT',-src=>'/'.$config->{'SEARCHJS'}},
					$search_actions	
			],
			-style  =>{'src'=>$config->{"EXPLORER_CSS"}},
			-onLoad	=> "$onload /*clear_search_except('onload', '$typdef');*/ "
		);
	print	p;
	print	table({border=>0}, Tr( 	td(a({-href=>url()."?lang=$lang"}, img{-src=>"/explorerdocs/logoTingids.png", -height=>'63px', -style=>"border: 0;"})),
					td({-style=>'width: 700px;'}, a({-href=>url()."?lang=$lang"}, span({-class=>'sitetitle'}, $config->{"DB_NAME"})) . 
						div({-id=>'roadstyle'}, $trans->{BY}->{$lang} . ' ' . $config->{"DB_AUTHORS"} . "<SPAN STYLE='padding-left: 200px;'>" . join("<SPAN STYLE='padding-left: 20px;'></SPAN>", @menus) . "</SPAN>" ) ), 
					td( a( {-href=>'http://www.mnhn.fr', -target=>'_blank'}, img{-style=>'border: 0;', -src=>"/explorerdocs/mnhnLogoSpelled.png", -height=>'80px'}) ) ) );
	print	p;
	print	"<TABLE CLASS='menushaut' STYLE='margin-left: 35px; border: solid 1px #000000; width: 950px; text-align: center;' CELLPADDING=0 CELLSPACING=0>";
	print	"<TR><TD COLSPAN=30 STYLE='text-align: right; vertical-align: middle; background: #000000; padding: 3px 2px 3px 2px; border-bottom: solid 1px #444444;'><TABLE><TR><TD STYLE='width: 800px;'>$sb</TD><TD>$flags</TD></TR></TABLE></TD>";
	system 	"/var/www/html/perl/explorer20.pl $argvtop";
	print	"</TABLE>";
	
	
	
	if ($content) {
		print 	$content;
	} elsif ($card and $card ne 'top') {
		print "<DIV class='contentContainer'>";
		system 	"/var/www/html/perl/explorer20.pl $argvs";
		print "</DIV>";
	} else {
		print "<DIV class='contentContainer'>";
		print div({-style=>'margin: 20px 50px;'}, $config->{'DB_ABSTRACT'});
		print img{-src=>"/explorerdocs/LaceBug.png", -style=>'border: 0; margin-left: 0px;'};
		print "</DIV>";
	}
	
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
