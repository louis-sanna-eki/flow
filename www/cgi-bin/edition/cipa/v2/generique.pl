#!/usr/bin/perl

# $Id: $

use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use CGI::Pretty;
use HTML_func qw (html_header html_footer arg_persist);
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row request_bind);
use Style qw ($conf_file $background $css $dblabel);

# Gets config
################################################################
my $config = get_connection_params($conf_file);

my @files;

#if ($conf_file ne '/etc/flow/floweditor.conf') { push(@files, '/etc/flow/floweditor.conf') };
#if ($conf_file ne '/etc/flow/cooleditor.conf') { push(@files, '/etc/flow/cooleditor.conf') };
#if ($conf_file ne '/etc/flow/psylleseditor.conf') { push(@files, '/etc/flow/psylleseditor.conf') };

my @confs;

# Gets parameters
################################################################
#my $id   = url_param('id'); # Gets id
my $table = url_param('table'); # Gets the table to edit

if ($table eq 'pays' or $table eq 'statuts' or $table eq 'langages') { foreach (@files) { push(@confs, get_connection_params($_)) } }

# Main
################################################################
my $jscript = "	var uonimg = new Image ();
		var uoffimg = new Image ();
		var newonimg = new Image ();
		var newoffimg = new Image ();
		var menuonimg = new Image ();
		var menuoffimg = new Image ();
		uonimg.src = '/Editor/little_update1.png';
		uoffimg.src = '/Editor/little_update0.png';
		newonimg.src = '/Editor/new1.png';
		newoffimg.src = '/Editor/new0.png';
		menuonimg.src = '/Editor/mainMenu1.png';
		menuoffimg.src = '/Editor/mainMenu0.png';
		
		function direction(form,id){form.id_change.value=id};";
		
if ( param("new") or url_param("new") ){ new_token() }
elsif ( param("create") or url_param("create") ){ create_token() }
elsif ( param("id_change") or url_param("id_change") ){ change_token() }
elsif ( param("modify") or url_param("modify") ){ modify_token() }
elsif ( param("home") or url_param("home") ){ token_list() }
elsif ( url_param('delete') ) { delete_token(); }
else { token_list() }
exit;

sub delete_token {

	my $table = url_param('table');
	my $xid = url_param('delete');
	
	my $delreq = "DELETE FROM $table WHERE index = $xid;";
	
	if ( my $dbc = db_connection($config) ) {
		if ( my $sth = $dbc->prepare($delreq) ){
			if ( $sth->execute() ) {
				$sth->finish();
			}
			else { print_error( "Error: $delreq ".$dbc->errstr ); }
		}
		else { print_error( "Error: $delreq ".$dbc->errstr ); }
	}
	
	token_list();
}

# Token list
#################################################################
sub token_list {
	if ( my $dbc = db_connection($config) ) { # connection
		
		my ($tokens,$colnames);
		
		my @options;
		my $optdisp;
		my $cols;
		my @types;
		my $order;
		my $title;
		
		my $request;
		my @fields;
		
		my $known = 1;
		if ($table eq 'revues') { 
			$title = 'Journals';
			$cols = 'index AS index, nom AS journal';
			$colnames = ['index', 'journal'];
			@types = ('i', 's');
			$order = "ORDER BY journal";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['nom', "$table"] );
		}
		elsif ($table eq 'auteurs') { 
			$title = 'Authors';
			$cols = 'index AS index, nom AS name, prenom AS initials';
			$colnames = ['index', 'name', 'initials'];
			@types = ('i', 's', 's');			
			$order = "ORDER BY name, initials";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['nom', "$table"], ['prenom', "$table"] );
		}
		elsif ($table eq 'editions') { 
			$title = 'Editions';
			$cols = 'e.index AS index, e.nom AS edition, v.nom AS city, p.en AS country';
			$colnames = ['index', 'edition', 'city', 'country'];
			@types = ('i', 's', 's', 's');
			$order = "ORDER BY edition, city, country";
			$request = 	"SELECT $cols 
					FROM $table AS e 
					LEFT JOIN villes AS v ON v.index = e.ref_ville
					LEFT JOIN pays AS p ON p.index = v.ref_pays
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['nom', "villes"],
					['en', "pays"]
				);
		}
		elsif ($table eq 'noms_vernaculaires') { 
			$title = 'Vernacular names';
			$cols = 'n.index AS index, n.nom AS name, n.transliteration AS transliteration, p.en AS country, l.langage AS language, n.remarques AS remarks';
			$colnames = ['index', 'name', 'transliteration', 'country', 'language', 'remarks'];
			@types = ('i', 's', 's', 's', 's', 's');
			$order = "ORDER BY name, transliteration, country, language";
			$request = 	"SELECT $cols 
					FROM $table AS n 
					LEFT JOIN pays AS p ON p.index = n.ref_pays
					LEFT JOIN langages AS l ON l.index = n.ref_langage
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['transliteration', "$table"],
					['en', "pays"],
					['langage', "langages"],
					['remarques', "$table"]
				);
		}
		elsif ($table eq 'agents_infectieux') { 
			$title = 'Infectious agents';
			$cols = 'a.index AS index, a.en AS agent, t.en AS type';
			$colnames = ['index', 'agent', 'type'];
			@types = ('i', 's', 's');
			$order = "ORDER BY agent, type";
			$request = 	"SELECT $cols 
					FROM $table AS a 
					LEFT JOIN types_agent_infectieux AS t ON t.index = a.ref_type_agent_infectieux
					$order";
						
			@fields = (	['index', "$table"],
					['en', "$table"],
					['en', "types_agent_infectieux"]
				);
		}
		elsif ($table eq 'villes') { 
			$title = 'Cities';
			$cols = 'v.index AS index, v.nom AS city, p.en AS country';
			$colnames = ['index', 'city', 'country'];
			@types = ('i', 's', 's');
			$order = "ORDER BY city, country";
			$request = 	"SELECT $cols 
					FROM $table AS v 
					LEFT JOIN pays AS p ON p.index = v.ref_pays
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['en', "pays"]
				);
		}
		elsif ($table eq 'pays') {
			$title = 'Countries';
			$cols = 'index AS index, en AS country, tdwg_level AS "TDWG level"';
			$colnames = ['index', 'country', 'TDWG level'];
			@types = ('i', 's', 's');			
			$order = 'ORDER BY "TDWG level" DESC, country';			
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"], ['tdwg_level', "$table"] );
		}
		elsif ($table eq 'langages') {
			$title = 'Languages';
			$cols = 'index AS index, langage AS language, iso AS "ISO code"';
			$colnames = ['index', 'language', 'ISO code'];
			@types = ('i', 's', 's');
			$order = "ORDER BY language";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['langage', "$table"], ['iso', "$table"] );
		}
		elsif ($table eq 'etats_conservation') { 
			$title = 'Conservation status';
			$cols = 'index AS index, en AS "conservation status"';
			$colnames = ['index', 'conservation status'];
			@types = ('i', 's');
			$order = 'ORDER BY "conservation status"';
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'habitats') { 
			$title = 'Habitats';
			$cols = 'index AS index, en AS habitat';
			$colnames = ['index', 'habitat'];
			@types = ('i', 's');
			$order = "ORDER BY habitat";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'lieux_depot') { 
			$title = 'Disposal sites';
			$cols = 'l.index AS index, l.nom AS name, p.en AS country';
			$colnames = ['index', 'name', 'country'];
			@types = ('i', 's', 's');
			$order = "ORDER BY name, country";
			$request = 	"SELECT $cols 
					FROM $table AS l 
					LEFT JOIN pays AS p ON p.index = l.ref_pays
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['en', "pays"]
				);
		}
		elsif ($table eq 'localites') { 
			$title = 'Localities';
			$cols = 'l.index AS index, l.nom AS locality, r.nom AS region, p.en AS country';
			$colnames = ['index', 'locality', 'region', 'country'];
			@types = ('i', 's', 's', 's');
			$order = "ORDER BY locality, region, country";
			$request = 	"SELECT $cols 
					FROM $table AS l 
					LEFT JOIN regions AS r ON r.index = l.ref_region
					LEFT JOIN pays AS p ON p.index = r.ref_pays
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['nom', "regions"],
					['en', "pays"]
				);
		}
		elsif ($table eq 'modes_capture') { 
			$title = 'Capture modes';
			$cols = 'index AS index, en AS "capture mode"';
			$colnames = ['index', 'capture mode'];
			@types = ('i', 's');
			$order = 'ORDER BY "capture mode"';
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'niveaux_confirmation') { 
			$title = 'Confirmation levels';
			$cols = 'index AS index, en AS "confirmation level"';
			$colnames = ['index', 'confirmation level'];
			@types = ('i', 's');
			$order = 'ORDER BY "confirmation level"';
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'niveaux_frequence') { 
			$title = 'Frequence levels';
			$cols = 'index AS index, en AS "frequence level"';
			$colnames = ['index', 'frequence level'];
			@types = ('i', 's');
			$order = 'ORDER BY "frequence level"';
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'periodes') { 
			$title = 'Periods';
			$cols = 'index AS index, en AS period';
			$colnames = ['index', 'period'];
			@types = ('i', 's');
			$order = "ORDER BY period";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'regions') { 
			$title = 'Regions';
			$cols = 'r.index AS index, r.nom AS region, p.en AS country';
			$colnames = ['index', 'region', 'country'];
			@types = ('i', 's', 's');
			$order = "ORDER BY region, country";
			$request = 	"SELECT $cols 
					FROM $table AS r 
					LEFT JOIN pays AS p ON p.index = r.ref_pays
					$order";
						
			@fields = (	['index', "$table"],
					['nom', "$table"],
					['en', "pays"]
				);
		}
		elsif ($table eq 'sexes') { 
			$title = 'Genders';
			$cols = 'index AS index, en AS gender';
			$colnames = ['index', 'gender'];
			@types = ('i', 's');
			$order = "ORDER BY gender";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'types_agent_infectieux') { 
			$title = 'Infectious agent types';
			$cols = 'index AS index, en AS type';
			$colnames = ['index', 'type'];
			@types = ('i', 's');
			$order = "ORDER BY type";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'types_depot') { 
			$title = 'Deposit types';
			$cols = 'index AS index, en AS type';
			$colnames = ['index', 'type'];
			@types = ('i', 's');
			$order = "ORDER BY type";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'types_observation') { 
			$title = 'Observation types';
		$cols = 'index AS index, en AS type';
			$colnames = ['index', 'type'];
			@types = ('i', 's');
			$order = "ORDER BY type";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'types_type') { 
			$title = 'Type specimen types';
			$cols = 'index AS index, en AS type';
			$colnames = ['index', 'type'];
			@types = ('i', 's');
			$order = "ORDER BY type";
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['en', "$table"] );
		}
		elsif ($table eq 'images') { 
			$title = 'Images';
			$cols = 'index AS index, url AS "image URL", icone_url AS "thumbnail URL"';
			$colnames = ['index', 'image URL', 'thumbnail URL'];
			@types = ('i', 's', 's');
			$order = 'ORDER BY "image URL"';
			$request = "SELECT $cols FROM $table $order";
			@fields = ( ['index', "$table"], ['url', "$table"], ['icone_url', "$table"] );
		}
		else { 
			$title = $table;
			$order = "ORDER BY index;";
			$cols = '*';
			$known = 0;
		}
		
		if ( my $sth = $dbc->prepare($request) ){ # prepare
			if ( $sth->execute() ){ # execute
				$tokens = $sth->fetchall_arrayref;
				$sth->finish(); # finalize the request
			}
			else { # Could'nt execute sql request
				print_error( "Error: $request ".$dbc->errstr );
			}
		}
		else { # Could'nt prepare sql request
			print_error( "Error: $request ".$dbc->errstr );
		}
				
		my @reqs;
		my @max;
		my $tot = 0;
		if ($known) {
			my $i = 0;
			foreach (@fields) {
				my $req;
				if ($types[$i] eq 'i') { 
					#my $t = $cols;
					#$t =~ s/[a-z]\.//g;
					#my @c = split(/, /, $t);
					#die join(', ', @c);
					$req = "SELECT max(req.\"$colnames->[$i]\") FROM ($request) AS req;";
					if (my $sth = $dbc->prepare($req)) {
						if ($sth->execute()) {
							my ($val) = $sth->fetchrow_array;
							$val = length($val);
							my $label = length($colnames->[$i]);
							if ($val > $label) { push(@max, $val); $tot += $val; }
							else { push(@max, $label * 1.5); $tot += $label * 1.5; }
						} else { print_error( "Error: $request ".$dbc->errstr ) }
					} else { print_error( "Error: $request ".$dbc->errstr ) }
				}
				elsif ($types[$i] eq 's') { 
					$req = "SELECT max(length(req.\"$colnames->[$i]\")) FROM ($request) AS req;";
					if (my $sth = $dbc->prepare($req)) {
						if ($sth->execute()) {
							my ($val) = $sth->fetchrow_array;
							my $label = length($colnames->[$i]);
							if ($val > $label) { push(@max, $val); $tot += $val; }
							else { push(@max, $label * 1.5); $tot += $label * 1.5; }
						} else { print_error( "Error: $request ".$dbc->errstr ) }
					} else { print_error( "Error: $request ".$dbc->errstr ) }
				}
				
				push(@reqs, $req);				
				$i++;
			}
		}
				
		my $deficit = 0;
		my $bigs = 0;
		my $i = 0;
		my $multi = 0.5;
		my $margins;
		my $unit = 'em';
		my $divcolor = 'transparent';
		$margins = 'margin: 0 50px;';
		if ($tot < 36) { $tot = 36; }
		$tot = int($tot * $multi) + scalar(@max);
		my $marginrow = 'margin-left: 0px;';
		
		foreach (@max) { 
			
			my $calc = int($_* $multi) + 1;
			
			$_ = $calc;
			#if ($calc < 50) { $_ = 50; }
			#elsif ($calc < 200){ $_ = $calc; }
			#else { $_ = $calc; }
			$i++;
		}
		#if ($bigs) {
		#	foreach (@max) { 
		#		if ($_ >= 200){ $_ -= $deficit / $bigs; }
		#	}
		#}
				
		my %headerHash = (
		
			titre => $table,
			bgcolor => $background,
			css => $css . "	.wcenter { width: $tot$unit; $margins background: transparent; }",
			jscript => $jscript
		);		
		
		my $newbtn = "<DIV STYLE='background: transparent; float: left; text-decoration: underline;'>" .
		span(	{	-onMouseOver=>"this.style.cursor = 'pointer';",
				-onClick=>"document.form.new.value=1; document.form.submit();"
			},
			'Add new element'
		) .
		"</DIV>";
		
		my $tablerows;
		
		for (my $i=0; $i<=$#{$colnames}; $i++) {
			
			$tablerows .= "<DIV STYLE='float: left; $marginrow background: $divcolor; width: $max[$i]$unit; text-align: left;'>".b($colnames->[$i])."&nbsp;</DIV>";
		}
				
		#$tablerows .= "<br><hr style='color: #EEEEEE; clear: both;'><P>";
		$tablerows .= "<br style='color: #EEEEEE; clear: both;'><P>";
			
		my $i = 0;		
		foreach my $token (@{$tokens}) {
										
#			$tablerows .= 	"<DIV STYLE='float: left; background: transparent; width: 50px;'>".
#					span(	{	-onMouseover=>"document.ubtn$i.src=eval('uonimg.src');",
#							-onMouseout=>"document.ubtn$i.src=eval('uoffimg.src');",
#							-onClick=>"document.form.new.value=0; document.form.id_change.value='$token->[0]'; document.form.submit();"
#						},
#						img({-border=>0, -src=>'/Editor/little_update0.png', -name=>"ubtn$i"})
#					).
#					"</DIV>";
								
#			$tablerows .= 	"<DIV STYLE='float: left; background: transparent; width: 50px;'>&nbsp;</DIV>";
			for (my $i=0; $i<=$#{$token}; $i++) {
				
				$tablerows .=	"<DIV STYLE='float: left; $marginrow background: $divcolor; width: $max[$i]$unit; margin-bottom: 5px;'>" .
				span({-onClick=>"document.form.new.value=0; document.form.id_change.value='$token->[0]'; document.form.submit();", -onMouseOver=>"this.style.cursor = 'pointer';"}, $token->[$i]) .
				"&nbsp;</DIV>";
			}
			
			#$tablerows .= "<hr style='color: #EEEEEE; clear: both;'>";
			$tablerows .= "<br style='color: #EEEEEE; clear: both;'>";
			$i++;
		}
		
		Delete('new');
		
		my $menubtn = 	a(	{	-style=>'color: navy;',
						-onMouseOver=>"this.style.cursor = 'pointer';",
						-href=>"action.pl"
					},
					'Main menu'
				);
		
		print 	html_header(\%headerHash),
			
			#join(', ', @max), " = ", $tot, p,
			
			div({-style=>'width: 1000px; height: 20px; margin: 1% 0 0 50px; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, 
				"$dblabel editor", p,
				table({-cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$title"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				)
			), p, br, p,
			
			div({-class=>'wcenter'},
			
			#join(br, map { "$_ = ".param($_) } param()), br,
			
			$newbtn . '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' . $menubtn . br . span({-style=>'clear: both;'}, '&nbsp;'), p,
			
			span({-style=>'color: crimson;'}, "Click on any following element for modification"), p,
			
			start_form(-name=>'form'),
			$tablerows,	
			br(),br(),
			hidden(-name=>'new', -default=>0),
			hidden(-name=>"id_change"),
			end_form()),
			html_footer();
		
		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# New token
#################################################################
sub new_token {
	if ( my $dbc = db_connection($config) ) { # connection
		my $cols;
		my $col_names;
		my $foreigns;
		my $title;
		my $msg;
		my $defs;
		
		if ($table eq 'revues') { 
			$title = 'Journal';
			$cols = ['nom'];
			$col_names = ['name'];
		}
		elsif ($table eq 'auteurs') {
			$title = 'Author';
			$cols = ['nom', 'prenom'];
			$col_names = ['last name', 'initials'];
		}
		elsif ($table eq 'editions') { 
			$title = 'Edition';
			$cols = ['nom'];
			$col_names = ['name'];
			my @opts = @{request_tab("SELECT v.index, v.nom, p.en FROM villes AS v LEFT JOIN pays AS p ON v.ref_pays = p.index ORDER BY v.nom;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] ($row->[2])";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('city') ] ) ).
							Tr(td( popup_menu(-class=>'PopupStyle', -name=>"ref_ville", -values=>["",@options], -labels=>\%labels) .
								'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=villes&new=1', 
												-target=>'_blank',
												-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a city')) );
		}
		elsif ($table eq 'noms_vernaculaires') { 
			$title = 'Vernacular name';
			$cols = ['nom', 'transliteration', 'remarques'];
			$col_names = ['name', 'transliteration', 'remarks'];
			my @opts = @{request_tab("SELECT index, en, tdwg_level FROM pays ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] [level $row->[2]]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a country') ) );
			
			@opts = @{request_tab("SELECT index, langage FROM langages ORDER BY langage;", $dbc, 2)};
			@options = ();
			%labels = ();
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns .= 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('language') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_langage", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=langages&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a language') ) );

		}
		elsif ($table eq 'agents_infectieux') { 
			$title = 'Infectious agent';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			my @opts = @{request_tab("SELECT index, en FROM types_agent_infectieux ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('type') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_type_agent_infectieux", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=types_agent_infectieux&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add an infectious agent type') ) );
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef ];
		}
		elsif ($table eq 'villes') { 
			$title = 'City';
			$cols = ['nom'];
			$col_names = ['name'];
			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'pays') {
			$title = 'Country';
			$cols = ['fr', 'en', 'es', 'de', 'pt', 'iso', 'tdwg', 'parent', 'tdwg_level'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese', 'ISO', 'TDWG', 'parent', 'TDWG level'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef, undef, undef, undef, 4];
		}
		elsif ($table eq 'langages') {
			$title = 'Language';
			$cols = ['langage', 'iso'];
			$col_names = ['language', 'iso'];
		}
		elsif ($table eq 'etats_conservation') { 
			$title = 'Conservation status';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'habitats') {
			$title = 'Habitat';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'lieux_depot') { 
			$title = 'Disposal site';
			$cols = ['nom'];
			$col_names = ['name'];
			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'localites') { 
			$title = 'Locality';
			$cols = ['nom'];
			$col_names = ['name'];
			my @opts = @{request_tab("SELECT r.index, r.nom, p.en FROM regions AS r LEFT JOIN pays AS p ON p.index = r.ref_pays ORDER BY r.nom, p.en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] ($row->[2])";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('region') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_region", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=regions&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Region') ) );			
		}
		elsif ($table eq 'modes_capture') { 
			$title = 'Capture mode';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'niveaux_confirmation') { 
			$title = 'Confirmation level';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'niveaux_frequence') { 
			$title = 'Frequence level';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'periodes') { 
			$title = 'Period';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'regions') { 
			$title = 'Region';
			$cols = ['nom'];
			$col_names = ['name'];
			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'sexes') { 
			$title = 'Gender';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'types_agent_infectieux') { 
			$title = 'Infectious agent type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'types_depot') { 
			$title = 'Deposit type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'types_observation') { 
			$title = 'Observation type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'types_type') { 
			$title = 'Type specimen type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$msg = "English field is required" . p;
			$defs = [undef, '?', undef, undef, undef];
		}
		elsif ($table eq 'images') { 
			$title = 'Image';
			$cols = ['url', 'icone_url'];
			$col_names = ['image URL', 'thumbnail URL'];
			$msg = '';
			$defs = [undef, undef];
		}

	
		my $tab;	
		for my $i ( 0..$#{$cols} ){
			$tab .= Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b($col_names->[$i]) ] ) );
			$tab .= Tr( td( input( {-type=>'text', -class=>'phantomTextField', -style=>"padding-left: 4px;", -name=>"$cols->[$i]",-size=>80, -value=>"$defs->[$i]"} ) ) );
		}
		$tab = $foreigns . $tab;

		my %headerHash = (
		
			titre => $table,
			bgcolor => $background,
			css => $css. "	.wcenter { width: 1000px; margin-left: 50px; } ",
			jscript => $jscript
		);
		
		Delete('new');
		
		my $hidden;
		if (url_param('new')) {
			param('tab', 1);
			$hidden = hidden('tab');
		}
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 1% 0 0 50px; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, 
				"$dblabel editor", p,
				table({-cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$title"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				)
			), p, br, p,
			
			div({-class=>'wcenter'},
				
				span({-id=>'redalert', -style=>'margin: auto 0; display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD" . p ),
								
				span({-style=>'margin: auto 0; color: crimson;'}, $msg ),
				#join(br, map { "$_ = ".param($_) } param()), br,
				start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				table({-cellspacing=>6, -cellpadding=>0}, $tab),
				br, br,
				submit("create"),
				reset("clear"),
				submit("home"),
				$hidden,
				end_form()
			),
			html_footer();
		$dbc->disconnect; # disconnection
	}
	else { } # Connection failed
}

# Modifying a token
#################################################################
sub change_token {
	if ( my $dbc = db_connection($config) ) { # connection

		my ($tokens, $cols, $col_names, $title, $foreigns);
		my $id = param('id_change');
		
		my %headerHash = (
			titre => $table,
			bgcolor => $background,
			css => $css. "	.wcenter { width: 1000px; margin-left: 50px; } ",
			jscript => $jscript
		);
                
		my $case = 0;
		
		if ($table eq 'revues') { 
			$title = 'Journal';
			$cols = ['nom'];
			$col_names = ['name'];
			$case = 1;
		}
		elsif ($table eq 'auteurs') {
			$title = 'Author';
			$cols = ['nom', 'prenom'];
			$col_names = ['last name', 'initials'];
			$case = 1;
		}
		elsif ($table eq 'editions') { 
			$title = 'Edition';
			$cols = ['nom'];
			$col_names = ['name'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_ville FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT v.index, v.nom, p.en FROM villes AS v LEFT JOIN pays AS p ON v.ref_pays = p.index ORDER BY v.nom;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] ($row->[2])";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('city') ] ) ).
							Tr(td( popup_menu(-class=>'PopupStyle', -name=>"ref_ville", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[1]) .
								'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=villes&new=1', 
												-target=>'_blank',
												-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a city')) );
		}
		elsif ($table eq 'noms_vernaculaires') { 
			$title = 'Vernacular name';
			$cols = ['nom', 'transliteration', 'remarques'];
			$col_names = ['name', 'transliteration', 'remarks'];

			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_pays, ref_langage FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT index, en, tdwg_level FROM pays ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] [level $row->[2]]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[3]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a country') ) );
			
			@opts = @{request_tab("SELECT index, langage FROM langages ORDER BY langage;", $dbc, 2)};
			@options = ();
			%labels = ();
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns .= 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('language') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_langage", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[4]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=langages&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a language') ) );

		}
		elsif ($table eq 'agents_infectieux') { 
			$title = 'Infectious agent';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_type_agent_infectieux FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT index, en FROM types_agent_infectieux ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('type') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_type_agent_infectieux", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[5]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=types_agent_infectieux&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add an infectious agent type') ) );
		}
		elsif ($table eq 'villes') { 
			$title = 'City';
			$cols = ['nom'];
			$col_names = ['name'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_pays FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[1]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'pays') {
			$title = 'Country';
			$cols = ['fr', 'en', 'es', 'de', 'pt', 'iso', 'tdwg', 'parent', 'tdwg_level'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese', 'ISO', 'TDWG', 'parent', 'TDWG level'];
			$case = 1;
		}
		elsif ($table eq 'langages') {
			$title = 'Language';
			$cols = ['langage', 'iso'];
			$col_names = ['language', 'iso'];
			$case = 1;
		}
		elsif ($table eq 'etats_conservation') { 
			$title = 'Conservation status';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'habitats') {
			$title = 'Habitat';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'lieux_depot') { 
			$title = 'Disposal site';
			$cols = ['nom'];
			$col_names = ['name'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_pays FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[1]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'localites') { 
			$title = 'Locality';
			$cols = ['nom'];
			$col_names = ['name'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_region FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT r.index, r.nom, p.en FROM regions AS r LEFT JOIN pays AS p ON p.index = r.ref_pays ORDER BY r.nom, p.en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1] ($row->[2])";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('region') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_region", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[1]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=regions&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Region') ) );			
		}
		elsif ($table eq 'modes_capture') { 
			$title = 'Capture mode';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'niveaux_confirmation') { 
			$title = 'Confirmation level';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'niveaux_frequence') { 
			$title = 'Frequence level';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'periodes') { 
			$title = 'Period';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'regions') { 
			$title = 'Region';
			$cols = ['nom'];
			$col_names = ['name'];
			
			my $request = "SELECT " . join(', ', @{$cols}) . ", ref_pays FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }

			my @opts = @{request_tab("SELECT index, en FROM pays WHERE tdwg_level = '4' ORDER BY en;", $dbc, 2)};
			my @options;
			my %labels;
			foreach my $row (@opts) {
				push(@options, $row->[0]);
				$labels{$row->[0]} = "$row->[1]";
			}
			$foreigns = 	Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b('country') ] ) ).
							Tr(	td( popup_menu(-class=>'PopupStyle', -name=>"ref_pays", -values=>["",@options], -labels=>\%labels, -default=>$tokens->[1]) . 
									'&nbsp;&nbsp;&nbsp;&nbsp;' . a({-href=>'generique.pl?table=pays&new=1', 
													-target=>'_blank',
													-onClick=>"document.getElementById('redalert').style.display = 'inline';"}, 'add a Country') ) );			
		}
		elsif ($table eq 'sexes') { 
			$title = 'Gender';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'types_agent_infectieux') { 
			$title = 'Infectious agent type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'types_depot') { 
			$title = 'Deposit type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'types_observation') { 
			$title = 'Observation type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'types_type') { 
			$title = 'Type specimen type';
			$cols = ['fr', 'en', 'es', 'de', 'pt'];
			$col_names = ['french', 'english', 'spanish', 'german', 'portuguese'];
			$case = 1;
		}
		elsif ($table eq 'images') { 
			$title = 'Image';
			$cols = ['url', 'icone_url'];
			$col_names = ['image URL', 'thumbnail URL'];
			$case = 1;
		}

		if ($case) {	
			my $request = "SELECT " . join(', ', @{$cols}) . " FROM $table WHERE index = $id;";

			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref; $sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }
		}
		
		my $tab;
        for my $i ( 0..$#{$cols} ){
			$tab .= Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b($col_names->[$i]) ] ) );
			$tab .= Tr( td( input( {-type=>'text', -class=>'phantomTextField', -name=>"$cols->[$i]",-size=>80, -value=>$tokens->[$i], -style=>'padding-left: 5px;' } ) ) );
		}
		$tab = $foreigns . $tab;
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 1% 0 0 50px; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, 
				"$dblabel editor", p,
				table({-cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$title"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				)
			), p, br, p,
			
			div({-class=>'wcenter'},
				
				span({-id=>'redalert', -style=>'margin: auto 0; display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD" . p ),

				start_form({-style=>'display: inline;'}),
				table ({-cellspacing=>6, -cellpadding=>0}, $tab),
				hidden( -name=>'old_id', -value=>$id ),
				br, br,
				submit("modify"),
				submit("new"),
				submit("home"),
				end_form(),
				start_form(-name=>'DelForm', -method=>'post', -action=>url()."?table=$table&delete=$id", -style=>'display: inline;'),
				submit({-style=>'color: black; margin-left: 375px;', -onClick=>"return(confirm('Are you sure?'));", -value=> "Delete"}),
				end_form()
			),
			html_footer();
		
		$dbc->disconnect;
	}
	else { }
}

# Modify a token in the database
#################################################################
sub modify_token {
	
	my %headerHash = (
	
		titre => $table,
		bgcolor => $background,
		css => $css . '	.wcenter { width: 1000px; margin-left: 50px; } ',
		jscript => $jscript
	);
	
	my $html = html_header(\%headerHash);
	
	my $msg;
	my $alert = 0;
	my $title;
	
	my $modif;

	foreach (@confs, $config) {
		if ( my $dbc = db_connection($_) and !$alert ) {
			
			my $id = param("old_id");
			
			my $cols;
			my $request;
			if ($table eq 'revues') { 
				$title = 'Journal';
				$cols = ['nom'];
			}
			elsif ($table eq 'auteurs') { 
				$title = 'Author';
				$cols = ['nom', 'prenom'];
			}
			elsif ($table eq 'editions') { 
				$title = 'Edition';
				$cols = ['nom', 'ref_ville'];
			}
			elsif ($table eq 'noms_vernaculaires') { 
				$title = 'Vernacular name';
				$cols = ['nom', 'transliteration', 'remarques', 'ref_pays', 'ref_langage'];
			}
			elsif ($table eq 'agents_infectieux') { 
				$title = 'Infectious agent';
				$cols = ['fr', 'en', 'es', 'de', 'pt', 'ref_type_agent_infectieux'];
			}
			elsif ($table eq 'villes') { 
				$title = 'City';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'pays') {
				$title = 'Country';
				$cols = ['fr', 'en', 'es', 'de', 'pt', 'iso', 'tdwg', 'parent', 'tdwg_level'];
			}
			elsif ($table eq 'langages') {
				$title = 'Language';
				$cols = ['langages', 'iso'];
			}
			elsif ($table eq 'etats_conservation') { 
				$title = 'Conservation status';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'habitats') {
				$title = 'Habitat';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'lieux_depot') { 
				$title = 'Disposal site';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'localites') { 
				$title = 'Locality';
				$cols = ['nom', 'ref_region'];
			}
			elsif ($table eq 'modes_capture') { 
				$title = 'Capture mode';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'niveaux_confirmation') { 
				$title = 'Confirmation level';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'niveaux_frequence') { 
				$title = 'Frequence level';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'periodes') { 
				$title = 'Period';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'regions') { 
				$title = 'Region';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'sexes') { 
				$title = 'Gender';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_agent_infectieux') { 
				$title = 'Infectious agent type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_depot') { 
				$title = 'Deposit type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_observation') { 
				$title = 'Observation type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_type') { 
				$title = 'Type specimen type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'images') { 
				$title = 'Image';
				$cols = ['url', 'icone_url'];
			}
	
			my @values;
			
			my @tests;
			my @testsval;
			my $null = 1;

			my $insert = "UPDATE $table SET ";
			for my $i ( 0..$#{$cols} ){
				
				$insert .= "$cols->[$i] = ?,";
				
				my $param = param($cols->[$i]);
				$param =~ s/^\s*//g;
				$param =~ s/\s*$//g;
				$param =~ s/\s+/ /g;
				
				if (($cols->[$i] eq 'fr' or $cols->[$i] eq 'es' or $cols->[$i] eq 'de' or $cols->[$i] eq 'pt') and !$param ) {
					$param = param('en');
					$param =~ s/^\s*//g;
					$param =~ s/\s*$//g;
					$param =~ s/\s+/ /g;
				}
				
				if ($param) {
					$null = 0;
					push(@values, $param);
					$param =~ s/'/\\'/g;
					push(@testsval, $param);
					push(@tests, "$cols->[$i] = ?");
				}
				else { 
					push(@values, undef);					
					push(@tests, "$cols->[$i] IS NULL"); 
				}

			}
			chop $insert;
			$insert .= " WHERE index = $id;";
			
			unless ($null) {
				
				my $testreq = "SELECT count(*) FROM $table WHERE ".join(' AND ', @tests).';';

				#die join(br, map { "$_ = ".param($_) } param());
				#die "$testreq with (@testsval)";

				my $count;
				if ( my $sth = $dbc->prepare($testreq) ){
					if ( $sth->execute( @testsval ) ) {
						($count) = @{$sth->fetchrow_arrayref};
						$sth->finish();
					}
					else { print_error( "Error: $testreq ".$dbc->errstr ); }
				}
				else { print_error( "Error: $testreq ".$dbc->errstr ); }
				
				unless ($count) {
					
					#die "$insert with (@values)";
					
					if ( my $sth = $dbc->prepare($insert) ){
						if ( $sth->execute( @values ) ) {
							$sth->finish();
						}
						else { print_error( "Error: $request ".$dbc->errstr ); }
					}
					else { print_error( "Error: $request ".$dbc->errstr ); }
										
					$modif = hidden('id_change', '') . submit( -name=>'modif', -value=>"modify", -onClick=>"direction(this.form, '$id');" );
					
					$msg = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}). p.
							
						span({-style=>'font-size: large; color: green;'}, "Item updated");

				}
				else {
					$alert = 1;
					
					$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
							
						span({-style=>'font-size: large; color: crimson;'}, "Item already in database");
				}
			}
			else {
				$alert = 1;
				
				$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
						
					span({-style=>'font-size: large; color: crimson;'}, "Empty item not allowed");
			}
			
			$dbc->disconnect; 
		}
		else { unless ($alert) { die "connection to database failed" } }
	}
	
	my $titre = div({-style=>'width: 1000px; height: 20px; margin: 1% 0 0 50px; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, 
			"$dblabel editor", p,
			table({-cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$title"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			)
		). p. br. p;
	
	$html .= $titre.
		
		div({-class=>'wcenter'},
				
		$msg,
		
		br, br,
														
		start_form(),
				
		$modif,
		
		submit("new"),
		
		submit("home"),
		
		#br, join(br, map { "$_ = ".param($_) } param()), br,
		
		end_form()
	).
	html_footer();

	print $html;

}

# Create a new token in the database
#################################################################
sub create_token {
	
	my %headerHash = (
	
		titre => $table,
		bgcolor => $background,
		css => $css . '	.wcenter { width: 1000px; margin-left: 50px; } ',
		jscript => $jscript
	);
	
	my $html = html_header(\%headerHash);
	
	my $msg;
	my $alert = 0;
	
	my $modif;
	my $title;
	
	foreach (@confs, $config) {
		if ( my $dbc = db_connection($_) and !$alert) {
			my ($tokens, $cols);
			my $request;
			if ($table eq 'revues') { 
				$title = 'Journal';
				$cols = ['nom'];
			}
			elsif ($table eq 'auteurs') { 
				$title = 'Author';
				$cols = ['nom', 'prenom'];
			}
			elsif ($table eq 'editions') { 
				$title = 'Edition';
				$cols = ['nom', 'ref_ville'];
			}
			elsif ($table eq 'noms_vernaculaires') { 
				$title = 'Vernacular name';
				$cols = ['nom', 'transliteration', 'remarques', 'ref_pays', 'ref_langage'];
			}
			elsif ($table eq 'agents_infectieux') { 
				$title = 'Infectious agent';
				$cols = ['fr', 'en', 'es', 'de', 'pt', 'ref_type_agent_infectieux'];
			}
			elsif ($table eq 'villes') { 
				$title = 'City';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'pays') {
				$title = 'Country';
				$cols = ['fr', 'en', 'es', 'de', 'pt', 'iso', 'tdwg', 'parent', 'tdwg_level'];
			}
			elsif ($table eq 'langages') {
				$title = 'Language';
				$cols = ['langages', 'iso'];
			}
			elsif ($table eq 'etats_conservation') { 
				$title = 'Conservation status';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'habitats') {
				$title = 'Habitat';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'lieux_depot') { 
				$title = 'Disposal site';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'localites') { 
				$title = 'Locality';
				$cols = ['nom', 'ref_region'];
			}
			elsif ($table eq 'modes_capture') { 
				$title = 'Capture mode';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'niveaux_confirmation') { 
				$title = 'Confirmation level';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'niveaux_frequence') { 
				$title = 'Frequence level';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'periodes') { 
				$title = 'Period';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'regions') { 
				$title = 'Region';
				$cols = ['nom', 'ref_pays'];
			}
			elsif ($table eq 'sexes') { 
				$title = 'Gender';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_agent_infectieux') { 
				$title = 'Infectious agent type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_depot') { 
				$title = 'Deposit type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_observation') { 
				$title = 'Observation type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'types_type') { 
				$title = 'Type specimen type';
				$cols = ['fr', 'en', 'es', 'de', 'pt'];
			}
			elsif ($table eq 'images') { 
				$title = 'Image';
				$cols = ['url', 'icone_url'];
			}
			
			my @values;
			
			my @tests;
			my @testsval;
			my $nbval = scalar @{$cols};
			my $insert = "INSERT INTO $table (";
			my $null = 1;
			for my $i ( 0..$#{$cols} ){
				
				$insert .= "$cols->[$i], ";
								
				my $param = param($cols->[$i]);
				$param =~ s/^\s*//g;
				$param =~ s/\s*$//g;
				$param =~ s/\s+/ /g;
				
				if (($cols->[$i] eq 'fr' or $cols->[$i] eq 'es' or $cols->[$i] eq 'de' or $cols->[$i] eq 'pt') and !$param ) {
					$param = param('en');
					$param =~ s/^\s*//g;
					$param =~ s/\s*$//g;
					$param =~ s/\s+/ /g;
				}
				
				if ($param) {
					$null = 0;
					push(@values, $param);
					$param =~ s/'/\\'/g;
					push(@testsval, $param);
					push(@tests, "$cols->[$i] = ?");
				}
				else { 
					push(@values, undef);					
					push(@tests, "$cols->[$i] IS NULL"); 
				}
				
			}
			
			unless ($null) {
				
				my $testreq = "SELECT count(*) FROM $table WHERE ".join(' AND ', @tests).';';
				
				#die join(br, map { "$_ = ".param($_) } param());
				#die "$testreq with (@testsval)";
				
				my $count;
				if ( my $sth = $dbc->prepare($testreq) ){
					if ( $sth->execute( @testsval ) ) {
						($count) = @{$sth->fetchrow_arrayref};
						$sth->finish();
					}
					else { print_error( "Error: $testreq ".$dbc->errstr ); }
				}
				else { print_error( "Error: $testreq ".$dbc->errstr ); }
								
				unless ($count) {
				
					chop $insert;
					chop $insert;
					$insert .= ") VALUES (" . "?, " x $nbval;
					chop $insert;
					chop $insert;
					$insert .= ");";
					
					#die "$insert with (@values)";
					
					if ( my $sth = $dbc->prepare($insert) ){
						if ( $sth->execute( @values ) ){
							$sth->finish();
						}
						else { print_error( "Execute error: $insert @values / ".$dbc->errstr ); }
					}
					else { print_error( "Prepare error: $insert ".$dbc->errstr ); }
					
					my $id = $dbc->last_insert_id(undef, "public", "$table", "index");
					
					$modif = hidden('id_change', '') . submit( -name=>'modif', -value=>"modify", -onClick=>"direction(this.form, '$id');" );
					
					$msg = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}). p.
							
						span({-style=>'font-size: large; color: green;'}, "Item added");

				}
				else {
					$alert = 1;
					
					$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
							
						span({-style=>'font-size: large; color: crimson;'}, "Item already in database");
				}
			}
			else {
				$alert = 1;
				
				$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
						
					span({-style=>'font-size: large; color: crimson;'}, "Empty item not allowed");
			}
			
			$dbc->disconnect;
		}
		else { die "Connection $_ failed" }
	}

	my $titre = div({-style=>'width: 1000px; height: 20px; margin: 1% 0 0 50px; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, 
			"$dblabel editor", p,
			table({-cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$title"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			)
		). p. br. p;

	my $close;
	if (param('tab')) { 
		$close = br . p . span({-style=>'margin: auto 0; text-decoration: blink; color: crimson; font-size: large;'}, "CLOSE THIS TAB AND RELOAD PREVIOUS ONE" );
	}
	
	$html .= $titre.
		
		div({-class=>'wcenter'},
		
		$msg,
		
		br, br,
														
		start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				
		$modif,
		
		submit("new"),
		
		submit("home"),
		
		#br, join(br, map { "$_ = ".param($_) } param()), br,
		
		end_form(),
		
		$close
	).
	html_footer();

	print $html;
}

sub print_error {
	my ($message) = @_;
	my %headerHash = (
	
		titre => $table,
		bgcolor => $background,
		css => $css . "	.wcenter { width: 1000px; margin: 1% 0 0 50px; background: transparent; }",
		jscript => $jscript
	);		
	print 	html_header(\%headerHash), # header
		div({-class=>'wcenter'},
			h2("Action impossible"), #title
			br,
			$message,
			p,
			'&nbsp;',
			p,
			start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),	
			submit("home"),			
			end_form()
		),
		html_footer();
	exit;	
}
