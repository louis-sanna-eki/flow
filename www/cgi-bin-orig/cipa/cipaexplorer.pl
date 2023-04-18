#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul);
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use DBI;
use DBCommands qw (get_connection_params db_connection request_tab request_hash);


my $config_file = '/etc/flow/cipaexplorer.conf';

my $dbc = db_connection(get_connection_params($config_file));

my $names = request_tab("SELECT orthographe FROM noms_complets AS nc LEFT JOIN rangs AS r ON ref_rang = r.index WHERE r.en in ('family','genus','subgenus','species','subspecies') and (nc.index in (SELECT distinct(ref_nom) FROM taxons_x_noms) or nc.index in (SELECT distinct(ref_nom_cible) FROM taxons_x_noms)) GROUP by r.ordre, orthographe ORDER BY r.ordre, orthographe;",$dbc,1);

my $argvs;
my $param;
my $lang;
if ($param = url_param('db')) { $argvs .= " -db=$param " } else { $argvs .= " -db=cipa" }
if ($param = url_param('card')) { $argvs .= " -card=$param " } else { $argvs .= " -card=top " }
if ($param = url_param('id')) { $argvs .= " -id=$param " }
if ($param = url_param('lang')) { $argvs .= " -lang=$param "; $lang = url_param('lang'); } else { $argvs .= " -lang=fr "; $lang = 'fr' }
if ($param = url_param('alph')) { $argvs .= " -alph=$param " }
if ($param = url_param('from')) { $argvs .= " -from=$param " }
if ($param = url_param('to')) { $argvs .= " -to=$param " }
if ($param = url_param('rank')) { $argvs .= " -rank=$param " }
if ($param = param('hiddensearch')) { $argvs .= " -search='$param' " }
if ($param = url_param('mode')) { $argvs .= " -mode=$param " }
if ($param = url_param('privacy')) { $argvs .= " -privacy=$param " }

my $config = { };
if ( open(CONFIG, $config_file) ) {
	while (<CONFIG>) {
		chomp;
		s/#.*//; 
		s/^\s+//;
		s/\s+$//;
		next unless length;
		my ($option, $value) = split(/\s*=\s*/, $_, 2);
		$config->{$option} = $value;
	}
	close(CONFIG);
}
else {
	die "No configuration file could be found\n";
}


my $trans = read_lang($config);

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

	my $flags = 	a( {-href=>url()."?$args&lang=fr", -style=>'margin-right: 6px; position: relative; z-index: 3;'}, img{-src=>"/cipadocs/fr.gif", -width=>"20px", -style=>'border: 0;'}).
			a( {-href=>url()."?$args&lang=en", -style=>'margin-right: 6px; position: relative; z-index: 3;'}, img{src=>"/cipadocs/en.gif", -width=>"20px", -style=>'border: 0;'}).
			a( {-href=>url()."?$args&lang=es", -style=>'margin-right: 6px; position: relative; z-index: 3;'}, img{src=>"/cipadocs/es.gif", -width=>"20px", -style=>'border: 0;'}).
			a( {-href=>url()."?$args&lang=de", -style=>'margin-right: 6px; position: relative; z-index: 3;'}, img{src=>"/cipadocs/de.gif", -width=>"20px", -style=>'border: 0;'});
        
	my $sb = start_form(    -name=>'searchform', -method=>'post',-action=>url()."?db=cipa&card=searching&lang=$lang",
				-class=>'searchform',
				-onSubmit=>"this.action = this.action + '&search=\\'' + this.searchstring.value + '\\''"
		).
		textfield(      -name=>'searchstring', 
				-class=>'searchfield', 
				-default=>$trans->{searchName}->{$lang},
				-id=>'snames',
				-onFocus=>"if (this.value == '$trans->{searchName}->{$lang}') {this.value = ''}; AutoComplete_ShowDropdown(this.getAttribute('id'));",
				-onBlur=>"if(!this.value) { this.value = '$trans->{searchName}->{$lang}' }"
		).
		hidden('hiddensearch', '').
		end_form();
	$sb = undef;

	my $intro;
	if ($argvs=~ m/card=top/) { $intro = div({-class=>'intro'}, '') }

	print header({-Type=>'text/html', -Charset=>'UTF-8'});
	print start_html(-title  =>$title,
			-author =>'anta@mnhn.fr',
			-base   =>'true',
			-head   =>meta({-http_equiv => 'Content-Type',
					-content    => 'text/html; charset=utf8'}),
			-meta   =>{'keywords'   =>'DBTNT, RYNCHOTEAM', 'description'=>'explorer'},
			-script=>{-language=>'JAVASCRIPT',-src=>'/SearchAutoComplete.js'},
			-style  =>{'src'=>$config->{CSS}},
			-onLoad	=> "	data = ['".join("','", @{$names})."'];
					AutoComplete_Create('snames', data, 10);
					if (top.location.href != location.href) {
						top.location.href = location.href;
					};"
		);
	
	print	"</DIV>";
	print	div({-class=>'titlediv'}, span({-class=>'sitetitle'}, 'CIPA'), span({-class=>'sitetitle', -style=>'font-size: 16px; margin-left: 100px;'}, 'Computer-aided Identification of Phlebotomine sandlies of America'));
	#print	div({-class=>'roadstyle'}, i({-style=>'color: darkgreen;'}, "$trans->{'BY'}->{$lang}"));
	print 	div({-style=>'width: 980px; margin: 0 auto;'}, $flags . $sb);
	system 	"/var/www/html/perl/explorer2.pl $argvs"; 
}

html_maker("CIPA", $lang, $argvs);
$dbc->disconnect;
exit;
