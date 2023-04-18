#!/usr/bin/perl

# $Id: $
BEGIN {push @INC, '/var/www/cgi-bin/edition/aradides/‘}
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

my @confs;

# Gets parameters
################################################################
#my $id   = url_param('id'); # Gets id
my $table = url_param('table'); # Gets the table to edit

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
		
if ( param("new") ){ new_token() }
elsif ( param("create") ){ create_token() }
elsif ( param("id_change") ){ change_token() }
elsif ( param("modify") ){ modify_token() }
elsif ( param("home") ){ token_list() }
else { token_list() }
exit;


# Token list
#################################################################
sub token_list {
	if ( my $dbc = db_connection($config) ) { # connection
		
		my ($tokens,$col_names);
		
		my @options;
		my $optdisp;
		my $cols;
		my @types;
		my $order;
		
		my $known = 1;
		if ($table eq 'revues') { 
			$cols = 'index, nom';
			@types = ('i', 's');
			$order = "ORDER BY nom;"; 
		}
		elsif ($table eq 'auteurs') { 
			$cols = 'index, nom, prenom';
			@types = ('i', 's', 's');			
			$order = "ORDER BY nom, prenom;";
		}
		elsif ($table eq 'editions') { 
			my @opts = @{request_tab("SELECT v.index, v.nom, p.en FROM villes AS v LEFT JOIN pays AS p ON v.ref_pays = p.index ORDER BY v.nom;", $dbc, 2)};
			foreach my $row (@opts) {
				push(@options, "$row->[1] ($row->[2]) = $row->[0]");
			}
			$optdisp = "ref_ville index &nbsp;" . popup_menu(-class=>'PopupStyle', -name=>"opt", -values=>["",@options], -onChange=>"this.value = '';");
			$optdisp .= hidden('options',$optdisp) . p;
			$cols = 'index, nom, ref_ville';
			@types = ('i', 's', 'i');
			$order = "ORDER BY nom;"; 
		}
		elsif ($table eq 'villes') { 
			my @opts = @{request_tab("SELECT p.index, p.en FROM pays AS p ORDER BY p.en;", $dbc, 2)};
			foreach my $row (@opts) {
				push(@options, "$row->[1] = $row->[0]");
			}
			$optdisp = "ref_pays index  &nbsp;" . popup_menu(-class=>'PopupStyle', -name=>"opt", -values=>["",@options], -onChange=>"this.value = '';");
			$optdisp .= hidden('options',$optdisp) . p;
			$cols = 'index, nom, ref_pays';
			@types = ('i', 's', 'i');
			$order = "ORDER BY nom;";
		}
		elsif ($table eq 'pays') {
			$cols = "index, en, tdwg_level";
			@types = ('i', 's', 's');			
			$order = "ORDER BY tdwg_level DESC, en;";			
		}
		elsif ($table eq 'langages') {
			$cols = "index, langage, iso";
			@types = ('i', 's', 's');
			$order = "ORDER BY langage;";
		}
		else { 
			$order = "ORDER BY index;";
			$cols = '*';
			$known = 0;
		}

		my $request = "SELECT $cols FROM $table $order";
		
		if ( my $sth = $dbc->prepare($request) ){ # prepare
			if ( $sth->execute() ){ # execute
				$tokens = $sth->fetchall_arrayref;
				$col_names = $sth->{NAME};
				$sth->finish(); # finalize the request
			}
			else { # Could'nt execute sql request
				print_error( "Error: $request ".$dbc->errstr );
			}
		}
		else { # Could'nt prepare sql request
			print_error( "Error: $request ".$dbc->errstr );
		}
				
		my @max;
		my $tot = 0;
		if ($known) {
			my $i = 0;
			foreach (@{$col_names}) {
				my $req;
				if ($types[$i] eq 'i') { $req = "SELECT max(length('$_')) FROM $table;"; }
				elsif ($types[$i] eq 's') { $req = "SELECT max(length($_)) FROM $table;"; }
				
				if (my $sth = $dbc->prepare($req)) {
					if ($sth->execute()) {
						my @val = $sth->fetchrow_array;
						if ($val[0] > length($_)) { push(@max, $val[0]); $tot += $val[0]; }
						else { push(@max, length($_)); $tot += length($_); }
					} else { print_error( "Error: $request ".$dbc->errstr ) }
				} else { print_error( "Error: $request ".$dbc->errstr ) }
				
				$i++;
			}
		}
		
		my $deficit = 0;
		my $bigs = 0;
		my $i = 0;
		foreach (@max) { 
			my $calc = $_/$tot * 800;
			
			if ($calc < 50) { $deficit += 50 - $calc; $_ = 50; }
			elsif ($calc < 200){ $_ = $calc; }
			else { $bigs += 1; $_ = $calc; }
			$i++;
		}
		if ($bigs) {
			foreach (@max) { 
				if ($_ >= 200){ $_ -= $deficit / $bigs; }
			}
		}
				
		my %headerHash = (
		
			titre => $table,
			bgcolor => $background,
			css => $css . "	.wcenter { width: 1000px; margin: 0 auto; } ",
			jscript => $jscript
		);		
		
		my $tablerows = "<DIV STYLE='float: left; background: transparent; width: 50px; margin-top: -5px;'>" .
		span(	{	-onMouseover=>"document.newbtn.src=eval('newonimg.src');",
				-onMouseout=>"document.newbtn.src=eval('newoffimg.src');",
				-onClick=>"document.form.new.value=1; document.form.submit();"
			},
			img({-border=>0, -src=>'/Editor/new0.png', -name=>"newbtn"})
		) .
		"</DIV>";
		
		for (my $i=0; $i<=$#{$col_names}; $i++) {
			
			$tablerows .= "<DIV STYLE='float: left; margin-left: 5px; background: transparent; width: $max[$i]px;'>".b($col_names->[$i])."&nbsp;</DIV>";
		}
				
		$tablerows .= "<br><hr style='color: #EEEEEE; clear: both;'><P>";
			
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
								
			$tablerows .= 	"<DIV STYLE='float: left; background: transparent; width: 50px;'>&nbsp;</DIV>";
			for (my $i=0; $i<=$#{$token}; $i++) {
				
				$tablerows .=	"<DIV STYLE='float: left; margin-left: 5px; background: transparent; width: ".$max[$i]."px; margin-bottom: 5px;'>" .
				span({-onClick=>"document.form.new.value=0; document.form.id_change.value='$token->[0]'; document.form.submit();", -onMouseOver=>"this.style.cursor = 'pointer';"}, $token->[$i]) .
				"&nbsp;</DIV>";
			}
			
			$tablerows .= "<hr style='color: #EEEEEE; clear: both;'>";
			$i++;
		}
		
		Delete('new');
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
			
			div({-class=>'wcenter'},
			
			table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$table"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			),
			#join(br, map { "$_ = ".param($_) } param()), br,

			a(	{	-style=>'',
					-onMouseover=>"document.menubtn.src=eval('menuonimg.src');",
					-onMouseout=>"document.menubtn.src=eval('menuoffimg.src');",
					-href=>"action.pl"
				},
				img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"menubtn"})
			), br, br,
			
			span({-style=>'color: crimson;'}, "Click on selected item"), br, br,
			
			start_form(-name=>'form'),
			p,
			$optdisp,
			br,
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
		my $col_names;
		my $request = "SELECT * FROM $table ORDER BY index;"; # Unnecessary request... Only needed for the col names

		if ( my $sth = $dbc->prepare($request) ){ # prepare
			if ( $sth->execute() ){ # execute
				$col_names = $sth->{NAME};
				$sth->finish(); # finalize the request
			}
			else { # Could'nt execute sql request
				print_error( "Error: $request ".$dbc->errstr );
			}
		}
		else { # Could'nt prepare sql request
			print_error( "Error: $request ".$dbc->errstr );
		}
	
		my $tab;	
		for my $i ( 1..$#{$col_names} ){
			$tab .= Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b($col_names->[$i]) ] ) );
			$tab .= Tr( td( input( {-type=>'text',-name=>"$col_names->[$i]",-size=>80} ) ) );
		}

		my %headerHash = (
		
			titre => $table,
			bgcolor => $background,
			css => $css. "	.wcenter { width: 1000px; margin: 0 auto; } ",
			jscript => $jscript
		);
		
		Delete('new');
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
			
			div({-class=>'wcenter'},
				
				table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"$table"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				),
				#join(br, map { "$_ = ".param($_) } param()), br,
				start_form(),
				param('options'), p,
				table({-cellspacing=>6, -cellpadding=>0}, $tab),
				br, br,
				submit("create"),
				reset("clear"),
				submit("home"),
				hidden('options'),
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

		my ($tokens,$col_names);
		my $id = param('id_change');
		my $request = "SELECT * FROM $table WHERE index = $id;";

		if ( my $sth = $dbc->prepare($request) ){
			if ( $sth->execute() ){
				$tokens = $sth->fetchrow_arrayref;
				$col_names = $sth->{NAME};
				$sth->finish();
			}
			else { print_error( "Error: $request ".$dbc->errstr ); }
		}
		else { print_error( "Error: $request ".$dbc->errstr ); }
		
		my %headerHash = (
			titre => $table,
			bgcolor => $background,
			css => $css. "	.wcenter { width: 1000px; margin: 0 auto; } ",
			jscript => $jscript
		);
                
		my $tab;
                for my $i ( 1..$#{$col_names} ){
			$tab .= Tr( td({-align=>"left", -style=>"padding: 0 10px 10px 0;"}, [ b($col_names->[$i]) ] ) );
			$tab .= Tr( td( input( {-type=>'text',-name=>"$col_names->[$i]",-size=>80, -value=>$tokens->[$i], -style=>'padding-left: 5px;' } ) ) );
		}
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
			
			div({-class=>'wcenter'},
				table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},
							"$table"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				),
				start_form(),
				param('options'), p,
				table ({-cellspacing=>6, -cellpadding=>0}, $tab),
				hidden( -name=>'old_id', -value=>$id ),
				br, br,
				submit("modify"),
				submit("new"),
				submit("home"),
				hidden('options'),
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
		css => $css,
		jscript => $jscript
	);
	
	my $html = html_header(\%headerHash).
	
	div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor");


	my $titre = 	table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},
						"$table"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			);
	
	my $msg;
	my $alert = 0;
	
	my $modif;

	foreach (@confs, $config) {
		if ( my $dbc = db_connection($_) and !$alert ) {
			
			my $id = param("old_id");
			
			my $col_names;
			my $request = "SELECT * FROM $table;";
	
			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$col_names = $sth->{NAME};
					$sth->finish();
				} else { print_error( "Error: $request ".$dbc->errstr ); }
			} else { print_error( "Error: $request ".$dbc->errstr ); }
	
			my @values;
			
			my @tests;
			my $null = 1;

			my $insert = "UPDATE $table SET ";
			for my $i ( 1..$#{$col_names} ){
				
				$insert .= "$col_names->[$i] = ?,";
				
				my $param = param($col_names->[$i]);
				$param =~ s/^\s*//g;
				$param =~ s/\s*$//g;
				$param =~ s/\s+/ /g;
				
				push(@values, $param);
				
				$param =~ s/'/\\'/g;
				
				if ($param) {
					$null = 0;
					if ($param =~ /^[0-9]+$/) { push(@tests, "$col_names->[$i] = $param"); }
					else { push(@tests, "$col_names->[$i] = '$param'"); }
				}
				else { push(@tests, "($col_names->[$i] IS NULL OR $col_names->[$i] = '')"); }
			}
			chop $insert;
			$insert .= " WHERE index = $id;";
			
			unless ($null) {
				
				my $testreq = "SELECT count(*) FROM $table WHERE ".join(' AND ', @tests).';';

				#die $testreq;
				
				my ($count) = @{request_tab($testreq, $dbc, 1)};
				
				unless ($count) {
					
					if ( my $sth = $dbc->prepare($insert) ){
						if ( $sth->execute( @values ) ) {
							$sth->finish();
						}
						else { print_error( "Error: $request ".$dbc->errstr ); }
					}
					else { print_error( "Error: $request ".$dbc->errstr ); }
										
					$modif = hidden('id_change', '') . submit( -name=>'modif', -value=>"modify", -onClick=>"direction(this.form, '$id');" );
					
					$msg = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}). p.
							
						span({-style=>'font-size: 15px; color: green;'}, "Item added");

				}
				else {
					$alert = 1;
					
					$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
							
						span({-style=>'font-size: 15px; color: crimson;'}, "Item already in database");
				}
			}
			else {
				$alert = 1;
				
				$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
						
					span({-style=>'font-size: 15px; color: crimson;'}, "Empty item not allowed");
			}
			
			$dbc->disconnect; 
		}
		else { unless ($alert) { die "connection to database failed" } }
	}
	
	$html .= div({-class=>'wcenter'},
				
		$titre,	
		
		$msg,
		
		br, br,
														
		start_form(),
		
		hidden('options'),
		
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
		css => $css,
		jscript => $jscript
	);
	
	my $html = html_header(\%headerHash).
	div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor");

	my $titre = 	table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},
						"$table"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			);
	
	my $msg;
	my $alert = 0;
	
	my $modif;
	
	foreach (@confs, $config) {
		if ( my $dbc = db_connection($_) and !$alert) {
			my ($tokens, $col_names);
			my $request = "SELECT * FROM $table;"; # get col names
			
			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute() ){
					$tokens = $sth->fetchrow_arrayref;
					$col_names = $sth->{NAME};
					$sth->finish();
				}
				else { print_error( "Error: $request ".$dbc->errstr ); }
			}
			else { print_error( "Error: $request ".$dbc->errstr ); }
			
			my @values;
			
			my @tests;
			my $nbval = scalar @{$col_names} -1;
			my $insert = "INSERT INTO $table (";
			my $null = 1;
			for my $i ( 1..$#{$col_names} ){
				
				$insert .= "$col_names->[$i],";
								
				my $param = param($col_names->[$i]);
				$param =~ s/^\s*//g;
				$param =~ s/\s*$//g;
				$param =~ s/\s+/ /g;
				
				push(@values, $param);
				
				$param =~ s/'/\\'/g;
				
				if ($param) {
					$null = 0;
					if ($param =~ /^[0-9]+$/) { push(@tests, "$col_names->[$i] = $param"); }
					else { push(@tests, "$col_names->[$i] ilike '$param'"); }
				}
				else { push(@tests, "($col_names->[$i] IS NULL OR $col_names->[$i] = '')"); }
				
			}
			
			unless ($null) {
				
				my $testreq = "SELECT count(*) FROM $table WHERE ".join(' AND ', @tests).';';
				
				#die $testreq;
				
				my ($count) = @{request_tab($testreq, $dbc, 1)};
				
				unless ($count) {
				
					chop $insert;
					$insert .= ") VALUES (" . "?," x $nbval;
					chop $insert;
					$insert .= ");";
					if ( my $sth = $dbc->prepare($insert) ){
						if ( $sth->execute( @values ) ){
							$sth->finish();
						}
						else { print_error( "Error: $request ".$dbc->errstr ); }
					}
					else { print_error( "Error: $request ".$dbc->errstr ); }
					
					my $id = $dbc->last_insert_id(undef, "public", "$table", "index");
					
					$modif = hidden('id_change', '') . submit( -name=>'modif', -value=>"modify", -onClick=>"direction(this.form, '$id');" );
					
					$msg = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}). p.
							
						span({-style=>'font-size: 15px; color: green;'}, "Item added");

				}
				else {
					$alert = 1;
					
					$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
							
						span({-style=>'font-size: 15px; color: crimson;'}, "Item already in database");
				}
			}
			else {
				$alert = 1;
				
				$msg = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
						
					span({-style=>'font-size: 15px; color: crimson;'}, "Empty item not allowed");
			}
			
			$dbc->disconnect;
		}
		else { die "Connection $_ failed" }
	}
	
	$html .= div({-class=>'wcenter'},
				
		$titre,	
		
		$msg,
		
		br, br,
														
		start_form(),
		
		hidden('options'),
		
		$modif,
		
		submit("new"),
		
		submit("home"),
		
		#br, join(br, map { "$_ = ".param($_) } param()), br,
		
		end_form()
	).
	html_footer();

	print $html;
}

sub print_error {
	my ($message) = @_;
	print html_header(), # header
		h2("Error"), #title
		br(),
		$message,
		br(),
		html_footer();
	exit;	
}
