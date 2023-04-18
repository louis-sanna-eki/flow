#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/psylles/v3/'}
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $cross_tables $single_tables html_header html_footer arg_persist $maintitle);

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EXPLORER');

my $JSCRIPT = "";

my %headerHash = (
	titre => "Merging duplicate data",
	css => $css,
	jscript => $JSCRIPT,
	onLoad => ""
);

my @tables = (
'publications',
'auteurs',
'revues',
'editions',
'pays',
'villes',
'lieux_depot',
'noms_vernaculaires',
);

my $table = param('table');
my $index1 = param('index1');
my $index2 = param('index2');
my $action = url_param('action');

my $content;
my $xtable;
my $req1;
my $res1;
my $req2;
my $res2;
my $msg;
my $final;

if ($action eq 'go') {

	my $req = "	SELECT DISTINCT R.TABLE_NAME, R.COLUMN_NAME
			from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE u
			inner join INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS FK
			    on U.CONSTRAINT_CATALOG = FK.UNIQUE_CONSTRAINT_CATALOG
			    and U.CONSTRAINT_SCHEMA = FK.UNIQUE_CONSTRAINT_SCHEMA
			    and U.CONSTRAINT_NAME = FK.UNIQUE_CONSTRAINT_NAME
			inner join INFORMATION_SCHEMA.KEY_COLUMN_USAGE R
			    ON R.CONSTRAINT_CATALOG = FK.CONSTRAINT_CATALOG
			    AND R.CONSTRAINT_SCHEMA = FK.CONSTRAINT_SCHEMA
			    AND R.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
			WHERE U.COLUMN_NAME = 'index'
			  AND U.TABLE_NAME = '$table'
			  AND R.TABLE_NAME != '$table'
			ORDER BY R.TABLE_NAME, R.COLUMN_NAME;";
			
	my $depends = request_tab($req, $dbc, 2);
	
	my $breq = "BEGIN;";
	foreach (@{$depends}) {
		$breq .= "update $_->[0] set $_->[1] = $index1 where $_->[1] = $index2;";
	}
	$breq .= "delete from $table where index = $index2; COMMIT;";
	
	if ( my $sth = $dbc->prepare($breq) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $breq with ".$dbc->errstr; } } else { die "Prepare error: $breq with ".$dbc->errstr; }
	
	$content = 	img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"}).
			br.br.
			span({-style=>"color: darkgreen;"},"The items have been merged").
			br.br.
			a({-href=>'dedoublon.pl', -style=>'text-decoration: none;'},"Merge other items");

}
else {
	
	$xtable = "<OPTION VALUE='' CLASS='PopupStyle' STYLE='text-align: center;'> -- SELECT A TABLE -- </OPTION>";
	my $selected;
	foreach (@tables) {
		
		if ($_ eq $table) { $selected = 'selected="selected"' } else { $selected = '' }
		$xtable .= "<OPTION $selected VALUE='$_' CLASS='PopupStyle' STYLE='text-align: center;'> " . $_ . " </OPTION>";
	}
	
	$xtable = table({-border=>0, -cellspacing=>0},
			Tr(
				td(span({-style=>"margin-right: 20px;"}, "Database table")),
				td(
					"<SELECT NAME='table' onChange=\"if (document.getElementById('index1')) { document.getElementById('index1').value = ''; } if (document.getElementById('index2')) { document.getElementById('index2').value = ''; } document.mainForm.submit();\" CLASS='PopupStyle' STYLE='text-align: center; border: 1px solid #888888;'>$xtable"
				)
			)
		);
	
	
	if ($table) { 
		
		my $submit1;
		unless ($index1) { 
			
			$submit1 = 	td(
						div({
							-id=>'Img1',
							-style=>'display: block; margin-left: 10px;',
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle1').innerHTML = 'Submit';",
							-onMouseOut=>"document.getElementById('bulle1').innerHTML = '';",
							-onClick=>"document.mainForm.submit();"},
							
							img({-border=>0, -src=>'/Editor/ok.png', -name=>"index1btn"})
						)
					).
					td({-id=>"bulle1", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '');
		}
		
		$req1 = 	table({-border=>0, -cellspacing=>0}, 
					Tr(
						td(span({-style=>"margin-right: 20px;"}, "Index of the item TO KEEP")),
						td(
							textfield(
								-name=> "index1",
								-id => "index1",
								-autocomplete=>'off',
								-style=>'width: 60px;',
								-value => $index1
							)
						),
						$submit1
					)
				);
	
		if ($index1) {
			
			my $fields1 = request_tab("SELECT column_name FROM information_schema.columns WHERE table_name = '".$table."';",$dbc,1);
			my $values1 = request_tab("SELECT * FROM $table WHERE index = $index1;",$dbc,2);
			
			if (scalar(@{$values1})) {
				$res1 = table({-border=>1, -cellspacing=>0},
						Tr({-style=>"font-size: 10px;"},
							"<td style='text-align: center;'>".join("</td><td style='text-align: center;'>", @{$fields1})."</td>"
						),
						Tr({-style=>"font-size: 10px;"},
							"<td>".join('</td><td>', @{$values1->[0]})."</td>"
						)
					);
			}
			
			my $submit2;
			unless ($index2) { 
				
				$submit2 = 	td(
							div({
								-id=>'Img2',
								-style=>'display: block; margin-left: 10px;',
								-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle2').innerHTML = 'Submit';",
								-onMouseOut=>"document.getElementById('bulle2').innerHTML = '';",
								-onClick=>"document.mainForm.submit();"},
								
								img({-border=>0, -src=>'/Editor/ok.png', -name=>"index2btn"})
							)
						).
						td({-id=>"bulle2", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '');
			}
			
			$req2 = 	table({-border=>0, -cellspacing=>0},
						Tr(
							td(span({-style=>"margin-right: 20px;"}, "Index of item TO MERGE")),
							td(
								textfield(
									-name=> "index2",
									-id => "index2",
									-autocomplete=>'off',
									-style=>'width: 60px;',
									-value => $index2
								)
							),
							$submit2
						)
					);
			
			if ($index2) {
				my $fields2 = request_tab("SELECT column_name FROM information_schema.columns WHERE table_name = '".$table."';",$dbc,1);
				my $values2 = request_tab("SELECT * FROM $table WHERE index = $index2;",$dbc,2);
				
				if (scalar(@{$values2})) {
					$res2 = table({-border=>1, -cellspacing=>0},
							Tr({-style=>"font-size: 10px;"},
								"<td style='text-align: center;'>".join("</td><td style='text-align: center;'>", @{$fields2})."</td>"
							),
							Tr({-style=>"font-size: 10px;"},
								"<td>".join('</td><td>', @{$values2->[0]})."</td>"
							)
						);
				}
				
				my $target;
				if ($res1 and $res2) {					
					if ($index1 != $index2) { 
						if ($action eq 'confirm') { $msg = span({-style=>"color: darkgreen;"}, 'please confirm by submiting again').br.br; $target = "dedoublon.pl?action=go"; }
						else {$target = "dedoublon.pl?action=confirm"; }
					}
					else {
						$msg = span({-style=>"color: crimson;"}, "indexes are identical").br.br;
						$target = "dedoublon.pl";
					}
				}
				else {
					$msg = span({-style=>"color: crimson;"}, "An index is not valid").br.br;
					$target = "dedoublon.pl";
				}
				
				$final = table({-border=>0, -cellspacing=>0},
						Tr(
							td(
								div({
									-id=>'Img3',
									-style=>'display: block;',
									-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle3').innerHTML = 'Submit';",
									-onMouseOut=>"document.getElementById('bulle3').innerHTML = '';",
									-onClick=>"document.mainForm.action='$target'; document.mainForm.submit();"},
									
									img({-border=>0, -src=>'/Editor/ok.png', -name=>"finalbtn"})
								)
							),
							td({-id=>"bulle3", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '')
						)
					);		
			}
		}
	}
	
	
	
	$content = start_form(-name=>'mainForm', -method=>'post',-action=>'dedoublon.pl').
		
		$xtable.
		br.br.
		$req1.
		br.
		$res1.
		br.br.
		$req2.
		br.
		$res2.
		br.br.
		$msg.
		$final.
		
		arg_persist().
		
		end_form();
}

print 	html_header(\%headerHash),

	#join(br, map { "$_ = ".param($_) } param()).
	
	$maintitle,
	div({-class=>"wcenter", -style=>'width: 1300px;'},
		$content
	),
	
	html_footer();


$dbc->disconnect();
exit;
