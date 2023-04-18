#!/usr/bin/perl
use utf8;                      # Source code is encoded using UTF-8.
use open ':std', ':encoding(UTF-8)';   # Set default encoding for file handles.
BEGIN { binmode(STDOUT, ':encoding(UTF-8)'); }  # HTML
BEGIN { binmode(STDERR, ':encoding(UTF-8)'); }  # Error log

use Encode;
# $Id: $
BEGIN {push @INC, '/var/www/cgi-bin/edition/psylles/v3/'}
use strict;
use warnings;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use CGI::Pretty;
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row request_bind);
use Conf qw ($conf_file $css $dblabel get_single_table_parameters make_single_table_fields get_single_table_thesaurus html_header html_footer arg_persist $maintitle);
use Data::Dumper;
use POSIX qw(ceil);


# Gets config
################################################################
my $config = get_connection_params($conf_file);

my @files;
if ($dblabel =~/Flow/i or $dblabel =~/Cool/i or $dblabel =~/Psyl'list/i or $dblabel =~/Psyllist/i or $dblabel =~/Whiteflies/i) {
	if ($conf_file ne '/etc/flow/floweditor.conf') { push(@files, '/etc/flow/floweditor.conf') };
	if ($conf_file ne '/etc/flow/cooleditor.conf') { push(@files, '/etc/flow/cooleditor.conf') };
	if ($conf_file ne '/etc/flow/psylleseditor.conf') { push(@files, '/etc/flow/psylleseditor.conf') };
	if ($conf_file ne '/etc/flow/aleurodseditor.conf') { push(@files, '/etc/flow/aleurodseditor.conf') };
}

my @confs;

# Gets parameters
################################################################
my $table = url_param('table');

foreach (param()) {
	if ( !param($_) or param($_) =~ m/^-- / ) { Delete($_); }
}


if ($table eq 'pays' or $table eq 'statuts' or $table eq 'langages' or $table eq 'types_cavernicolous' or $table eq 'periodes' or $table eq 'niveaux_geologiques' or $table eq 'lieux_depot' or $table eq 'types_association') { foreach (@files) { push(@confs, get_connection_params($_)) } }
if($table eq 'plantes') {
	if ($dblabel eq 'Psyllist') {
                push(@confs, get_connection_params('/etc/flow/aleurodseditor.conf'));	
	}
	elsif ($dblabel eq 'Whiteflies') { 
		push(@confs, get_connection_params('/etc/flow/psylleseditor.conf'));
	} 
}
# Main
################################################################
my $jscript = "function direction(form, id) { form.change.value=id }\n";

$css .= "a {color: #444444;}";
$css .= "a:hover {color: crimson;}";
$css .= ".linkLike:hover {color: crimson;}";

my $dbc = db_connection($config, 'EDITOR');
my ($title, $singular, $fields, $label, $join, $order);
my ($count, $offset, $limit);
my $champs;
my $rows;

$count = url_param('count') || 0;
$offset = url_param('offset') || 0;
$limit = url_param('limit') || 0;

my $nbsections = 1;
unless ($count or $table eq 'images') {
	($count) = @{request_tab("SELECT count(*) FROM $table;", $dbc, 1)};
	if ($count < 251) { $limit = 25; } 
	elsif ($count > 250 and $count < 501) { $limit = 50; } 
	elsif ($count > 500 and $count < 1001) { $limit = 100; }
	else { $limit = 200; } 
	$nbsections = ceil($count / $limit);
}

get_single_table_parameters($table, \$title, \$singular, \$label, \$join, \$order, \$champs);

if ( param('new') or url_param('new') )			{  new_token(); }
elsif ( param('change') or url_param('change') )	{ change_token(); }
elsif ( param('create') or url_param('create') )	{ my $bug = verify(); unless($bug) { treat_token('insert'); } else { new_token($bug); } }
elsif ( param('modify') or url_param('modify') )	{ my $bug = verify(); unless($bug) { treat_token('update'); } else { param('change', param('modify')); change_token($bug); } }
elsif (  param('delete') or url_param('delete') )	{ delete_token(); }
else { token_list() }

# Token list
#################################################################
sub token_list {		

	my $substr = $table ne 'plantes' ? ", substr($label, 1, 3)" : undef;
	
	my $req = "SELECT x.index, $label $substr FROM $table AS x $join $order;";	
	
	$rows = request_tab($req, $dbc, 2);
	
	#if ($table eq 'types_association') { die map {join(',',@{$_})} @{$rows}; }
		
	my @sections;
	my $off;
	if ($nbsections > 1) {
		unless ($rows->[0][2]) { $rows->[0][2] = substr($rows->[0][1], 0, 3); }
		@sections = ($rows->[0][2]);
		for (my $i=1; $i<=$nbsections; $i++) {
			my $borne = ($i*$limit)-1;
			if ($borne >= $count) { $borne = "$#{$rows}"; }
			unless ($rows->[$borne][2]) { $rows->[$borne][2] = substr($rows->[$borne][1], 0, 3); }
			$sections[$i-1] .=  " - $rows->[$borne][2]";
			$off = (($i-1)*$limit);
			$sections[$i-1] = a({-style=>'text-decoration: none;', -href=>url()."?table=$table&offset=$off" }, $sections[$i-1]);
			if ($rows->[$borne+1]) {
				unless ($rows->[$borne+1][2]) { $rows->[$borne+1][2] = substr($rows->[$borne+1][1], 0, 3); }
				$sections[$i] = $rows->[$borne+1][2];
			}
		}
		$off = ($nbsections*$limit);
		$sections[$#sections] = a({-style=>'text-decoration: none;', -href=>url()."?table=$table&offset=$off" }, $sections[$#sections]);
	
		if ($limit) { @{$rows} = @{$rows}[$offset..$offset+$limit-1]; }
	}
	
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => $jscript
	);		
				
	my $ul = start_ul({-style=>'list-style-type: none; padding: 0;'});
	my $i = 1;
	foreach my $row (@{$rows}) {
		$ul .= li({-style=>'padding: 0 0 6px 0;'}, span({-class=>'linkLike', -onClick=>"document.Form.new.value=0; document.Form.change.value='$row->[0]'; document.Form.submit();", -onMouseOver=>"this.style.cursor = 'pointer';"}, $row->[1] . " [$row->[0]]"));
		$i++;
	}
	$ul .= end_ul();
		
	my $divisions;
	if (scalar @sections) { $divisions = join('&nbsp; / &nbsp;', @sections) . p; }
		
	print 	html_header(\%headerHash),
		#join(br, map { "$_ = ".param($_) } param()), br,					
		$maintitle,
		div({-class=>'wcenter'},
			table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic; padding-right: 20px;'}, $title),
					td( 	
						img({	-src=>'/dbtntDocs/new.png', -name=>"new", -alt=>"new", 
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleNew').innerHTML = 'Add a new item';", 
							-onMouseOut=>"document.getElementById('bulleNew').innerHTML = '';",
							-onClick=>"document.Form.new.value=1; document.Form.submit();" }
						)
					),
					td({-id=>"bulleNew", -style=>'width: 200px; color: darkgreen; padding-left: 5px;'}, '')
				)
			),
			$divisions,
			start_form(-name=>'Form'),
				$ul,
				hidden(-name=>'new', -default=>0),
				hidden(-name=>"change"),
			end_form()
		),
		html_footer();
}

# New token
#################################################################
sub new_token {	
	
	my ($msg) = @_;
	my $title;
	my $retro_hash;
	my $onload;
	my $autofields;
	my $tablerows;
	my $hiddens;
	my $dependencies;
	my $hidrefs;
	my $onSubmit;
	my $reload = '&new=1';
	my $etrangere;
	my $values = [];
			
	my $hidden;
	$hidden .= hidden(-name=>'create', -value=>0);
	
	Delete('new'); Delete('change');
			
	get_single_table_thesaurus($dbc, $table, \$retro_hash, \$onload, $values);
	
	make_single_table_fields($table, $champs, \$retro_hash, \$values, \$hiddens, \$autofields, \$tablerows, \$dependencies, \$hidrefs, \$onSubmit, $reload, \$etrangere);
			
	$onload .= $autofields . $dependencies;
	
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => [ $jscript . ' function doOnClick() { AutoComplete_HideAll(); } document.onclick=doOnClick; ', {-language=>'JAVASCRIPT', -src=>'/dbtntDocs/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	if ($etrangere) { $etrangere = Tr(td({-style=>'color: navy;'}, '**'), td('write three asterisks to access to full data')); }
		
	print 	html_header(\%headerHash),
		#join(br, map { "$_ = ".param($_) } param()), br,			
		div({-class=>'wcenter'},
			div({-style=>'margin: 20px 0;'}, $maintitle ),			
			span({-id=>'redalert', -style=>'margin: auto 0; display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD" . br ),
			span({-style=>'margin: auto 0; color: red;'}, $msg ), p,
			"<FIELDSET class='round fieldset1'>",
			"<LEGEND class='round'>".span({-style=>'color: #222222; font-size: 18px; font-style: italic;'}, $singular)."</LEGEND>\n", p,
			start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				$hidden,
				$hidrefs,
				table({-style=>'margin-bottom: 30px;'}, $tablerows),
				table( Tr(
					td(submit({-class=>'buttonSubmit', -id=>'goon', -style=>'margin-left: 5px; width: 22px;', -onMouseOver=>"this.style.cursor = 'pointer'; document.getElementById('bulle1').innerHTML = 'Submit'; ".$onSubmit, -onMouseOut=>"document.getElementById('bulle1').innerHTML = '';", -onClick=>"document.Form.create.value=1;", -value=>''})),
					td({-id=>'bulle1', -style=>'width: 100px; color: darkgreen;'}, ''),
					td(submit({-class=>'buttonBack', -style=>'width: 22px;', -onMouseOver=>"this.style.cursor = 'pointer'; document.getElementById('bulle2').innerHTML = 'Back';", -onMouseOut=>"document.getElementById('bulle2').innerHTML = '';", -value=>''})),
					td({-id=>'bulle2', -style=>'width: 100px; color: darkgreen;'}, ''),
					td(a({	-style=>'text-decoration: none; width: 22px;', 
						-href=>url()."?table=$table$reload",
						-onMouseOver=>"document.getElementById('bulle3').innerHTML = 'Clear';", 
						-onMouseOut=>"document.getElementById('bulle3').innerHTML = '';" }, 
						img({-border=>0, -src=>'/dbtntDocs/clear.png', -name=>"clear" , -alt=>"clear"}))),
					td({-id=>'bulle3', -style=>'width: 100px; color: darkgreen;'}, ''),
				)),
			end_form(), 
			"</FIELDSET>", p,
			table(
				Tr(td({-style=>'color: crimson;'}, '*'), td('required fields')),
				$etrangere
			)
		),
		html_footer();
}

# Modifying a token
#################################################################
sub change_token {
	
	my ($msg) = @_;
	my $xid = param('change') || url_param('change');
	my $title;
	my $retro_hash;
	my $onload;
	my $autofields;
	my $tablerows;
	my $hiddens;		
	my $dependencies;
	my $hidrefs;
	my $onSubmit;
	my $reload = "&change=$xid";
	my $etrangere;
			
	# Get values for each field for selected item
	my @flds;
	foreach (@{$champs->{'definition'}}) {
		my $fld = $_->{'ref'} || $_->{'id'};
		push(@flds, $fld);
	}
	my $op;
	if ( $join =~ m/WHERE/ ) { $op = 'AND' } else { $op = 'WHERE' }
	my $values = request_tab("SELECT x.".join(', x.', @flds)." FROM $table AS x $join $op x.index = $xid;", $dbc, 2);
	#--------------------------------------------#
	
	Delete('new'); Delete('change'); Delete('modify');
	
	get_single_table_thesaurus($dbc, $table, \$retro_hash, \$onload, $values);
	
	make_single_table_fields($table, $champs, \$retro_hash, \$values, \$hiddens, \$autofields, \$tablerows, \$dependencies, \$hidrefs, \$onSubmit, $reload, \$etrangere);
	
	$onload .= $autofields . $dependencies;	
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => [ $jscript . ' function doOnClick() { AutoComplete_HideAll(); } document.onclick=doOnClick; ', {-language=>'JAVASCRIPT', -src=>'/dbtntDocs/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	if ($etrangere) { $etrangere = Tr(td({-style=>'color: navy;'}, '**'), td('write three asterisks to access to full data')); }
	
	print 	html_header(\%headerHash),
		#join(br, map { "$_ = ".param($_) } param()), br,			
		div({-class=>'wcenter'},
			div({-style=>'margin: 20px 0;'}, $maintitle ),		
			span({-id=>'redalert', -style=>'margin: auto 0; display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD" ),
			span({-style=>'margin: auto 0; color: red;'}, $msg ), p,
			"<FIELDSET class='round fieldset1'>",
			"<LEGEND class='round'>".span({-style=>'color: #222222; font-size: 18px; font-style: italic;'}, $singular)."</LEGEND>\n", p,
			start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				hidden( -name=>'modify', -value=>0 ),
				hidden( -name=>'delete', -value=>0 ),
				$hidrefs,	
				table({-style=>'margin-bottom: 30px;'}, $tablerows),
				table( Tr(
					td(submit({-class=>'buttonSubmit', -id=>'goon', -style=>'margin-left: 5px; width: 22px;', -onMouseOver=>"this.style.cursor = 'pointer'; document.getElementById('bulle1').innerHTML = 'Submit'; ".$onSubmit, -onMouseOut=>"document.getElementById('bulle1').innerHTML = '';", -onClick=>"document.Form.modify.value=$xid;", -value=>''})),
					td({-id=>'bulle1', -style=>'width: 100px; color: darkgreen;'}, ''),
					td(submit({-class=>'buttonBack', -style=>'width: 22px;', -onMouseOver=>"this.style.cursor = 'pointer'; document.getElementById('bulle2').innerHTML = 'Back';", -onMouseOut=>"document.getElementById('bulle2').innerHTML = '';", -value=>''})),
					td({-id=>'bulle2', -style=>'width: 100px; color: darkgreen;'}, ''),
					td(submit({-class=>'buttonDelete', -style=>'width: 22px;', -onMouseOver=>"this.style.cursor = 'pointer'; document.getElementById('bulle3').innerHTML = 'Delete';", -onMouseOut=>"document.getElementById('bulle3').innerHTML = '';", -onClick=>"if(confirm('Remove from the database?')) { document.Form.delete.value=$xid; } else { return false; };", -value=>''})),
					td({-id=>'bulle3', -style=>'width: 100px; color: darkgreen;'}, ''),
				)),
			end_form(),
			"</FIELDSET>", p,
			table(
				Tr(td({-style=>'color: crimson;'}, '*'), td('required fields')),
				$etrangere
			)
		),
		html_footer();
}

# Verifying data
#################################################################
sub verify {	
	my $alert;
	if ($table eq 'taxons_associes' and param('modify')) { 
		
		my $xid = param('modify');
		my $ref_rang = param('ref_rang');
		
		# Test if possible rank change is compatible with possible sons rank
		my $ordres = request_tab("SELECT ordre, (SELECT min(ordre) FROM taxons_associes AS ta LEFT JOIN rangs AS r on r.index = ta.ref_rang WHERE ref_parent = $xid) FROM rangs WHERE index = $ref_rang;", $dbc, 2);
		unless (!$ordres->[0][1] or $ordres->[0][1] > $ordres->[0][0]) { $alert = "Incompatibility between name's level and name's sons level" }
	}
	return $alert;
}

# Create a new token in the database
#################################################################
sub treat_token {
	my ($action) = @_;	
	my $msg;
	my $stop = 0;
	my $display;
	
	#die join(br, map { "$_ = ".param($_) } param());
	
	my $xid;
	foreach (@confs, $config) {
		if ( my $dbc2 = db_connection($_, 'EDITOR') and !$stop) {
			my $request;
			my @fields;
			my @values;
			my @tests;
						
			foreach (@{$champs->{'definition'}}) {
							
				my $xfield = $_->{'ref'} || $_->{'id'};
				my $xvalue = param($xfield);
				$xvalue =~ s/^\s*//g;
				$xvalue =~ s/\s*$//g;
				$xvalue =~ s/\s+/ /g;
				
				push(@fields, $xfield);
				if ($xvalue and $xvalue ne 'NULL') {
					push(@values, $xvalue);
					push(@tests, "$xfield = ?");
				}
				else { 
					push(@values, undef);					
					push(@tests, "($xfield IS NULL OR $xfield = ?)"); 
				}
			}
				
			$request = "SELECT count(*) FROM $table WHERE ".join(' AND ', @tests).";";
			#$request = "SELECT count(*) FROM $table";

			#print "Content-type: text/html\n\n";
            #print Dumper @tests;

			#$display .= $request . " : " . join(',', @values);
							
			my $count;
			if ( my $sth = $dbc2->prepare($request) ) {
				if ( $sth->execute( @values ) ) {
					($count) = @{$sth->fetchrow_arrayref};
					$sth->finish();
				} else { print_error( "Error 2: $request ".$dbc2->errstr ); }
			} else { print_error( "Error: $request ".$dbc2->errstr ); }
							
			unless ($count) {
				
				my $conclusion;
				if ($action eq 'insert') {
					my @marks = ('?') x scalar(@values);
					$request = "INSERT INTO $table (index, ".join(', ', @fields).") VALUES (default, ".join(', ', @marks).");";
					if ( my $sth = $dbc2->prepare($request) ){
						if ( $sth->execute( @values ) ){
							$sth->finish();
						} else { print_error( "Execute error: $request with @values ".$dbc2->errstr ); }
					} else { print_error( "Prepare error: $request with @values ".$dbc2->errstr ); }
					
					$xid = $dbc2->last_insert_id(undef, 'public', $table, 'index');
					
					$conclusion = 'Item inserted';
				}
				elsif ($action eq 'update') {
					$xid = param('modify');
					$request = "UPDATE $table SET ".join(', ' , map("$_ = ?", @fields))." WHERE index = $xid;";					
					if ( my $sth = $dbc2->prepare($request) ){
						if ( $sth->execute( @values ) ){
							$sth->finish();
						} else { print_error( "Execute error: $request with @values ".$dbc2->errstr ); }
					} else { print_error( "Prepare error: $request with @values ".$dbc2->errstr ); }
					
					$conclusion = 'Item updated';
				}				
				$msg = 	img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"}) . p .
					span({-style=>'font-size: large; color: green;'}, $conclusion);

			}
			else {
				$xid = param('modify');
				$stop = 1;
				$msg = 	img({-border=>0, -src=>'/dbtntDocs/stop.png', -name=>'stop' , -alt=>'STOP'}) . p .		
					span({-style=>'font-size: large; color: crimson;'}, 'Item already exists in the database');
			}
			
			$dbc2->disconnect;
		}
		elsif (!$stop) { die "Connection $_->{DEFAULT_DB} failed" }
	}

	
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => $jscript
	);
	
	my $back = td(	
			img({	-src=>'/dbtntDocs/modify.png', -name=>"modif", -alt=>"modify", 
				-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleMod').innerHTML = 'Back to the item';", 
				-onMouseOut=>"document.getElementById('bulleMod').innerHTML = '';",
				-onClick=>"document.Form.change.value=$xid; document.Form.submit();" }
			)
		).
		td({-id=>"bulleMod", -style=>'width: 120px; color: darkgreen;'}, '');
	
	$back = $xid ? $back : '';
	
	print	html_header(\%headerHash),
		#join(br, map { "$_ = ".param($_) } param()), br,			
	 	div({-class=>'wcenter'},
			div({-style=>'margin: 20px 0;'}, 
				$maintitle,
				span({-style=>'color: #222222; font-size: 18px; font-style: italic;'}, $singular),
			),		
			$msg, p,							
			start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				$display,
				hidden('new', 0),
				hidden('change', 0),
				table(	Tr(	$back,
						td(
							a({-href=>url()."?table=$table"},
								img({	-src=>'/dbtntDocs/back.png', -name=>"back" , -alt=>"back", 
									-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleBac').innerHTML = 'Back to items list';", 
									-onMouseOut=>"document.getElementById('bulleBac').innerHTML = '';",
									-border=>0 }
								)
							)
						),
						td({-id=>"bulleBac", -style=>'width: 120px; color: darkgreen;'}, ''),
						td( 	
							img({	-src=>'/dbtntDocs/new.png', -name=>"new", -alt=>"new", 
								-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleNew').innerHTML = 'Add a new item';", 
								-onMouseOut=>"document.getElementById('bulleNew').innerHTML = '';",
								-onClick=>"document.Form.new.value=1; document.Form.submit();" }
							)
						),
						td({-id=>"bulleNew", -style=>'width: 120px; color: darkgreen;'}, '') 
					)
				),	
			end_form()
		),
		html_footer();
}

sub delete_token {

	my $xid = param('delete');
	
	my $delete = "DELETE FROM $table WHERE index = $xid;";
		
	foreach (@confs, $config) {
		if ( my $dbc2 = db_connection($_, 'EDITOR')) {
			if ( my $sth = $dbc2->prepare($delete) ){
				if ( $sth->execute() ) {
					$sth->finish();
				} else { print_error( "Error: $delete ".$dbc2->errstr ); }
			} else { print_error( "Error: $delete ".$dbc2->errstr ); }
		}
	}
	
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => $jscript
	);
	
	print	html_header(\%headerHash),
		#join(br, map { "$_ = ".param($_) } param()), br,			
	 	div({-class=>'wcenter'},
			div({-style=>'margin: 20px 0;'}, 
				$maintitle,
				span({-style=>'color: #222222; font-size: 18px; font-style: italic;'}, $singular),
			),		
			img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"}), p,
			span({-style=>'font-size: large; color: green;'}, 'Item deleted'),
			start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),
				submit({-class=>'buttonBack', -onMouseOver=>"this.style.cursor = 'pointer';", -value=>''}),
			end_form()
		),
		html_footer();
}

sub print_error {
	my ($message) = @_;
	my %headerHash = (
		titre => $table,
		css => $css,
		jscript => $jscript
	);		
	print 	html_header(\%headerHash),
			div({-class=>'wcenter'},
				h2("Action impossible"), br,
				$message, p,
				start_form(-name=>'Form', -method=>'post', -action=>url()."?table=$table"),	
					submit({-class=>'buttonBack', -onMouseOver=>"this.style.cursor = 'pointer';", -value=>''}),
				end_form()
			),
			html_footer();
	exit;	
}

$dbc->disconnect;
exit;
