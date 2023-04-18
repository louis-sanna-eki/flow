#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/coleorrhyncha/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_row request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use DBTNTcommons qw (pub_formating get_pub_params make_thesaurus);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel $cross_tables);

my $user = remote_user();

my $dbc = db_connection(get_connection_params($conf_file));

my ($table1, $field1, $tables2, $title, $name, $onload);
my $cross = url_param('cross');
my $xid = param('xid') || url_param('xid');
my $xaction = url_param('xaction');

if ($cross) {
	@{$tables2} = split(/_x_/, $cross);
	$table1 = shift(@{$tables2});
}

# Tables definitions #####################################################################################################################
# table must have two date type fields:  date_creation & date_modification
# table must have two text fields:  createur & modificateur
# foreign keys arguments 	: type, title, id, ref, thesaurus, addurl, class
# publications arguments 	: type, title, id
# internal fields arguments 	: type, title, id
# select fields arguments 	: type, title, id, values
# hidden fields arguments 	: type, id, value

my $table_definition = [];
my $table_fields = [];
my $foreign_fields = [];
my $foreign_joins;
my $order;
my $retro_hash;
my $obligatory = [];
my $separators;
my $new_elem;
my $nb_elem;
my $reaction;

unless ($xid) {
	get_first_table($table1);
}
else {
	if ($table1 eq 'taxons') {
		my $req = "	SELECT orthographe, autorite 
				FROM noms_complets AS nc 
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
				WHERE txn.ref_taxon = $xid 
				AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid'); ";
	
		my $res = request_tab($req, $dbc, 2);
		
		$field1 = 'ref_taxon';
		$name = "$res->[0][0] $res->[0][1]";
	}
	elsif ($table1 eq 'noms') {
		my $req = "	SELECT orthographe, autorite 
				FROM noms_complets AS nc 
				WHERE index = $xid; ";
	
		my $res = request_tab($req, $dbc, 2);
		
		$field1 = 'ref_nom';
		$name = "$res->[0][0] $res->[0][1]";
	}
	
	if ( $cross eq 'taxons_x_pays' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index not in (SELECT index FROM pays WHERE tdwg_level = '3' and en in (SELECT en FROM pays WHERE tdwg_level = '4')) ORDER BY tdwg_level DESC, en;", 'pays', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, \$onload, $dbc);
		}
						
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	if ( $cross eq 'taxons_x_pays_x_agents_infectieux' or $cross eq 'taxons_x_pays_x_habitats' or $cross eq 'taxons_x_pays_x_modes_capture' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index not in (SELECT index FROM pays WHERE tdwg_level = '3' and en in (SELECT en FROM pays WHERE tdwg_level = '4')) ORDER BY tdwg_level DESC, en;", 'pays', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}
						
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}	
	elsif ( $cross eq 'taxons_x_plantes' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, get_host_plant_name(index) AS fullname FROM plantes ORDER BY fullname;", 'plantes', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_images' or $cross eq 'noms_x_images' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, substring(url from \'[^/]+\$\') FROM images ORDER BY url;", 'images', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}		
	}
	elsif ( $cross eq 'taxons_x_documents' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, titre FROM documents ORDER BY titre;", 'documents', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}		
	}
	elsif ( $cross eq 'taxons_x_vernaculaires' ) {
				
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT nv.index, nv.nom, nv.transliteration, l.langage, p.en 
					FROM noms_vernaculaires AS nv
					LEFT JOIN pays AS p ON p.index = nv.ref_pays
					LEFT JOIN langages AS l ON l.index = nv.ref_langage
					ORDER BY nv.nom, nv.transliteration, l.langage, p.en, remarques;",
					'vernaculaires',
					"\$intitule .= \$row->[1]; if(\$row->[2]) { \$intitule .= ' ('.\$row->[2].')'; } if(\$row->[4]) { \$intitule .= ' in '.\$row->[4]; } if(\$row->[3]) { \$intitule .= ' ('.\$row->[3].')'; }",
					\$retro_hash, 
					\$onload, 
					$dbc);
		}
			
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_localites' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus(
				'SELECT l.index, l.nom, r.nom, p.en 
				 FROM localites AS l 
				 LEFT JOIN regions AS r ON r.index = l.ref_region 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY l.nom, r.nom, p.en;',
				 'localites', 
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2]; } if(\$row->[3]) { \$row->[3] = ', '.\$row->[3].')'; } else { \$row->[3] = ')'; } \$intitule = \$row->[1].\$row->[2].\$row->[3];", 
				 \$retro_hash,
				 \$onload, 
				 $dbc
			);
		}
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_lieux_depot' or $cross eq 'noms_x_types' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus(
				'SELECT l.index, nom, en 
				 FROM lieux_depot AS l 
				 LEFT JOIN pays AS p ON p.index = l.ref_pays 
				 ORDER BY nom, en;',
				 'lieux_depot',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 \$onload, 
				 $dbc
			);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, \$onload, $dbc);
		}
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_periodes' ) {
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_regions' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus(
				'SELECT r.index, nom, en 
				 FROM regions AS r 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY nom, en;',
				 'regions',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 \$onload, 
				 $dbc
			);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, \$onload, $dbc);
		}
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_regions_x_agents_infectieux' or $cross eq 'taxons_x_regions_x_habitats' or $cross eq 'taxons_x_regions_x_modes_capture' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus(
				'SELECT r.index, nom, en 
				 FROM regions AS r 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY nom, en;',
				 'regions',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 \$onload, 
				 $dbc
			);
		}
		
		# elements needed to sort relations in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	
	# page title
	$title = $cross_tables->{$cross}->{'title'};
	# fields definitions
	$table_definition = $cross_tables->{$cross}->{'definition'};
	# obligatory fields
	$obligatory = $cross_tables->{$cross}->{'obligatory'};

	foreach (@{$table_definition}) {
		if ($_->{'type'} eq 'foreign') { push(@{$table_fields}, $_->{'ref'}); }
		else { push(@{$table_fields}, $_->{'id'}); }
	}	

	# Function selection #####################################################################################################################
	if ($xaction eq 'fill') {
		$new_elem = param('new_elem') || 1;
		Delete('new_elem');
		Xform();
	}
	if ($xaction eq 'modify') {
		$nb_elem = param('nb_elem');
		Delete('nb_elem');
		Xform();
	}
	elsif ($xaction eq 'verify') {
		$xaction = param('xaction');
		if ($xaction eq 'fill') { $reaction = 'insert'; }
		elsif ($xaction eq 'modify') { $reaction = 'update'; }
		Xrecap();
	}
	elsif ($xaction eq 'insert' or $xaction eq 'update') {
		Xexecute();
	}
	elsif ($xaction eq 'more' or $xaction eq 'duplicate') {
		$xaction = param('xaction');
		$new_elem = param('new_elem') + 1;
		Delete('new_elem');
		Xform();
	}
}

# Functions #############################################################################################################################

sub Xform {
	
	my ($req, $res, $preexist);
	my $crosslinks;
	my $explorer;
	my $autofields;
	my @hiddens;
	my $noid = scalar(@{$table_fields}) + scalar(@{$foreign_fields});
	#die scalar(@{$table_fields}).' + '.scalar(@{$foreign_fields}).' = '.$noid;
	
	my $virgule;
	if (scalar(@{$foreign_fields})) { $virgule = ','; }
		
	$req = "SELECT tx." . join(', tx.', @{$table_fields}) . $virgule . join(', ', @{$foreign_fields}) . ", tx.oid " . " FROM $cross AS tx $foreign_joins WHERE $field1 = $xid $order;";
	
	$preexist = request_tab($req, $dbc, 2);	
	
	push(@hiddens, ['xaction', $xaction]);
	if (my $dup = param('duplicate')) {
		
		if ($dup =~ /p/) {
			$dup = substr($dup, 1);
			foreach my $row (@{$preexist}) {
				if ($row->[$noid] == $dup) {
					my $i = 0;
					foreach (@{$table_definition}) {
						if($row->[$i]) {
							if ($_->{'type'} eq 'foreign') { 
								param($_->{'id'}.$new_elem, $retro_hash->{$_->{'thesaurus'}.$row->[$i]});
								param($_->{'ref'}.$new_elem, $row->[$i]);
							}
							else {
								param($_->{'id'}.$new_elem, $row->[$i]);
							}
						}
						$i++;
					}
					last;
				}
			}
		}
		else {
			foreach (@{$table_definition}) {
				if (param($_->{'id'}.$dup)) {
					if ($_->{'type'} eq 'foreign') { param($_->{'ref'}.$new_elem, param($_->{'ref'}.$dup)); }
					param($_->{'id'}.$new_elem, param($_->{'id'}.$dup));
				}
			}
		}
		Delete('duplicate');
	}
	
	my $sentence;
	if ($new_elem) { 
		push(@hiddens, ['new_elem', $new_elem]);
		foreach my $row (@{$preexist}) {
			my $element;
			my $i = 0;
			foreach my $field (@{$table_definition}) {
				if($row->[$i]) {
					my $color = 'navy';
					#if ($i % 2) { $color = '#CC4400'; }
					my $title = $field->{'title'};
					$title =~ s/ /&nbsp;/g;
					if ($field->{'type'} eq 'pub') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, publication($row->[$i], 0, 1, $dbc))));
						$element .= span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, publication($row->[$i], 0, 1, $dbc)) . 
														span({-style=>"color: #666666;"}, '[' . $row->[$i] . ']') . ' | ';
					}
					#pub_formating(get_pub_params($dbc, $row->[$i]), 'html')))
					elsif ($field->{'type'} eq 'foreign') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]})));
						$element .= span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . ' | ';
					} 
					elsif ($field->{'type'} eq 'select') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]})));
						$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
						if (exists $field->{'labels'}) {
							$element .= span({-style=>"color: $color;"}, $field->{'labels'}->{$row->[$i]}) . ' | ';
						}
						else { 
							$element .= span({-style=>"color: $color;"}, $row->[$i]) . ' | '; 
						}
					} 
					else {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $row->[$i])));
						$element .= span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, $row->[$i]) . ' | ';
					}
				}
				$i++;
			}
			$element = td( substr($element, 0, -3) );
			$element .= td({-style=>'text-align: left;'}, span(  {	-style=>"color: blue; text-decoration: none; background-color: #DDDDDD; padding: 2px 5px 2px 5px;",
										-onMouseover=>"	this.style.cursor='pointer';",
										-onClick=>"	appendHidden(document.crossForm, 'duplicate', 'p".$row->[$noid]."');
												crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate';
												crossForm.submit();"},
										'Duplicate') );

			$explorer .= Tr( $element ) . Tr( td({-colspan=>2}, hr) );
		}
		if (scalar(@{$preexist})) {
			$explorer = p . span({-style=>'color: black;'}, 'Existing relation(s):') . p . table({-width=>'100%', -border=>'0px solid black;'}, $explorer);
		}
	}
	else {
		if ($cross_tables->{$cross}->{'obligatory'}) {
			$sentence = img({-border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px;'});
			my @df;
			foreach my $field (@{$table_definition}) {
				foreach my $ob (@{$cross_tables->{$cross}->{'obligatory'}}) {
					if ($field->{'id'} eq $ob) { push(@df, $field->{'title'}); last; }
				}
			}
			$sentence .= span({-style=>'color: crimson;'}, " To delete a relation, clear a required field (") . join(span({-style=>'color: crimson;'},' or '), @df) . span({-style=>'color: crimson;'}, ") and click OK button") . p;
			
		}

		if (!$nb_elem) {		
			my $i = 1;
			foreach my $row (@{$preexist}) {
				my $j = 0;
				push(@hiddens, ["oid$i", pop(@{$row})]);
				foreach my $col (@{$row}) {
					if ($table_definition->[$j]{'type'} eq 'foreign') { param($table_definition->[$j]{'id'}.$i, $retro_hash->{$table_definition->[$j]{'thesaurus'}.$col}); }
					param($table_fields->[$j].$i, $col);
					$j++;
				}
				$i++;
			}
			
			$nb_elem = scalar(@{$preexist});
			push(@hiddens, ['nb_elem', $nb_elem]); 
		}
		elsif ($nb_elem) { 
			push(@hiddens, ['nb_elem', $nb_elem]); 
		}
	}
	
	$crosslinks .= Tr( td({-colspan=>2}, hr) );
	my $iter = $new_elem || $nb_elem;
	for (my $i=$iter; $i>0; $i--) {
		
		my $dupfield;
		if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
			
			$dupfield = span({	-style=>"color: blue; text-decoration: none;",
						-onMouseover=>"	this.style.cursor='pointer';",
						-onClick=>"	appendHidden(document.crossForm, 'duplicate', $i);
								crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate';
								crossForm.submit();"},
					'&nbsp; Duplicate &nbsp;'
				);
		}
		$crosslinks .= Tr({-style=>'background-color: #DDDDDD;'}, td(span({-style=>'color: crimson;'}, "&nbsp; Relation " . $i)), td({-style=>'text-align: left;', -colspan=>2}, $dupfield));
		foreach (@{$table_definition}) {
		
			my $default;
			if ($_->{'type'} eq 'foreign') {
			
				my $id = $_->{'id'};
				unless ($default = param("$id$i")) {
					Delete($_->{'ref'}.$i);
					push(@hiddens, [$_->{'ref'}.$i, '']);
				}
				else {
					push(@hiddens, [$_->{'ref'}.$i, param($_->{'ref'}.$i)]);
					Delete($_->{'ref'}.$i);
				}
				
				my $field = textfield(
					-class => 'phantomTextField', 
					-name=> "$id$i", 
					-size=>70, 
					-value => $default, 
					-id => "$id$i", 
					-onFocus => "	AutoComplete_ShowDropdown(this.getAttribute('id'));",
					-onChange=>"	if(!this.value) { document.crossForm." . $_->{'ref'}.$i . ".value = ''; } 
							else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }"
				);
				
				my $label = lc($_->{'title'});
				$label =~ s/ /&nbsp;/g;	
				my $more = '<NOBR> ' . a({-href=>$_->{'addurl'}, 
					     -target=>'_blank', 
					     -style=>'text-decoration: none; font-size: 12px;', 
					     -onClick=>"document.getElementById('redalert').style.display = 'inline';"
					  },
					  "Add a " . $label ).
					  img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what", 
						-onClick=>"document.getElementById('helpmsg1').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}) . '</NOBR>';
				
				$autofields .= "AutoComplete_Create('$id$i', " . $_->{'thesaurus'} . ", 20, '" . $_->{'ref'}.$i . "', 'crossForm'); ";
				
				$crosslinks .= Tr( td(span({-style=>'margin-right: 8px;'}, $_->{'title'})), td($field . '&nbsp; ' . $more) );
				
				
			}
			elsif ($_->{'type'} eq 'pub') {
				
				$crosslinks .= Tr( td(span({-style=>'margin-right: 8px;'}, $_->{'title'})), td({-colspan=>1}, makePubField($_->{'title'}, $_->{'id'}, $i)) );
			}
			elsif ($_->{'type'} eq 'select') {
				
				my $label = lc($_->{'title'});
				$label =~ s/ /&nbsp;/g;
				my $more = '<NOBR> ' . a({-href=>$_->{'addurl'}, 
					     -target=>'_blank', 
					     -style=>'text-decoration: none; font-size: 12px;', 
					     -onClick=>"document.getElementById('redalert').style.display = 'inline';"
					  },
					  "Add a " . $label ).
					  img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what", 
						-onClick=>"document.getElementById('helpmsg1').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}) . '</NOBR>';
				
				$crosslinks .= Tr( td(span({-style=>'margin-right: 0px;'}, $_->{'title'})), td(popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>$_->{'id'}.$i, -default=>$default, values=>$_->{'values'}, -labels=>$_->{'labels'}) . '&nbsp; ' . $more) );
			}
			elsif ($_->{'type'} eq 'internal') {
				
				my $l = $_->{'length'} || 70;
				$crosslinks .= Tr( td(span({-style=>'margin-right: 0px;'}, $_->{'title'})), td({-colspan=>1}, textfield(-class=>'phantomTextField', -name=>$_->{'id'}.$i, -default=>$default, -size=>$l)) );
			}
			Delete($_->{'id'}.$i);
		}
		$crosslinks .= Tr( td({-colspan=>2}, hr) );
	}
	$onload .= $autofields;
	
		
	my $addrelation;
	my $advise;
	if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
		$addrelation = 	'&nbsp;&nbsp;&nbsp;&nbsp;'.
				span({-style=>'color: blue;', -onClick=>"crossForm.action='crosstable.pl?cross=$cross&xaction=more'; crossForm.submit();", -onMouseOver=>"this.style.cursor = 'pointer'"}, "Add a relation").
				img({-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what",
				     -onClick=>"document.getElementById('helpmsg0').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}).
				span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg0'}, br . "Add $title");
	}
	
	my %headerHash = (
		titre => $title,
		bgcolor => $background,
		css => $css,
		jscript => [	{-language=>'JAVASCRIPT', -code=>"$jscript_imgs"}, 
				{-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, 
				{-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	my $hids;
	foreach (@hiddens) {
		Delete($_->[0]);
		$hids .= hidden($_->[0], $_->[1]);
	}
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()) . p . join(br, map { $_->[0]." = ".$_->[1] } @hiddens),
		
		div({-style=>'width: 1000px; height: 20px; margin: 1% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
						
			"$title for ", span({-style=>'font-weight: bold;'}, $name), p,
			
			$sentence,
			
			#span({-style=>'color: #FF3300'}, "After entering the index of any publication, 
			#				  click anywhere outside of the index field 
			#				  in order to make the complete reference appear"), 
			#p,
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
				 -onMouseout=>"document.okbtn.src=eval('okoffimg.src');",
				 -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			), 
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
			
			a(	{-href=>"crosstable.pl?cross=$cross&xaction=$xaction",
				 -onMouseover=>"document.backbtn.src=eval('backonimg.src');",
				 -onMouseout=>"document.backbtn.src=eval('backoffimg.src');",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
						
			a({-href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
			
			p,
			
			start_form(-name=>'crossForm', -method=>'post',-action=>''),
			
			b($iter) . " Relation(s) " . $addrelation,						
			
			br,			
			
			$advise,
			
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg1'}, 
				br . "A new page will open, when data is entered, close this page, go back to the current one and reload it" . br . br
			),		
						
			table({-width=>'100%', -border=>'0'}, $crosslinks),
			
			$explorer,
			
			p,
			
			arg_persist(),
			
			$hids,
			
			end_form(),			
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src');",
				-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			), 
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
			
			a(	{-href=>"crosstable.pl?cross=$cross&xaction=$xaction",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src');",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src');",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
						
			a({-href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
												
		),
	
		html_footer();
}

sub Xexecute {
	
	my %headerHash = (
		titre => $title,
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
		
	my ($req, $sth, @msg);
	my $iter = param('new_elem') || param('nb_elem');
	for (my $i=$iter; $i>0; $i--) {
		my $ok = 1;
		foreach (@{$obligatory}) {
			unless (param($_.$i)) { $ok = 0; } 
		}
		if ($ok) {
			my @fields = ($field1);
			my @values = ($xid);
			my @nullfields = ();
			my @nulls = ();
			foreach (@{$table_definition}) {
				if (param($_->{'id'}.$i)) {
					my ($f, $v);
					if ($_->{'type'} eq 'foreign') {
						$f = $_->{'ref'};
						$v = param($_->{'ref'}.$i);
					}
					else {
						$f = $_->{'id'};
						$v = param($_->{'id'}.$i);
					}
					push(@fields, $f);
					push(@values, $v);
				}
				else { 
					my $f;
					if ($_->{'type'} eq 'foreign') { $f = $_->{'ref'}; }
					else { $f = $_->{'id'}; }
					push(@nulls, $f.' IS NULL');
					push(@nullfields, $f);
				}
			}
			my $null;
			if (scalar(@nulls)) { $null = ' AND ' . join(' AND ', @nulls); }
			$req = "SELECT count(*) FROM $cross WHERE " . join(' = ? AND ', @fields) . " = ? $null;";
			
			$sth = $dbc->prepare($req) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
			
			$sth->execute(@values) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
												
			unless ($sth->fetchrow_array) {
							
				foreach (@nullfields) { push(@values, undef); }
				if ($xaction eq 'insert') {
					my $marks = '?,' x scalar(@fields) . '?,' x scalar(@nullfields);
					chop $marks;
					$req = "INSERT INTO $cross (" . join(', ', @fields, @nullfields) . ', createur, date_creation, modificateur, date_modification) VALUES (' . $marks . ", '$user', default, '$user', default);";
				}
				elsif ($xaction eq 'update') {
					my $oid = param('oid'.$i);
					$req = "UPDATE $cross SET " . join(' = ?, ', @fields, @nullfields) . " = ?, modificateur = '$user', date_modification = default WHERE oid = $oid;";
					push(@msg, span({-style=>'color: green;'}, "Relation $i updated"));
				}
											
				$sth = $dbc->prepare($req) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
			
				$sth->execute(@values) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
			}
			else {
				push(@msg, span({-style=>'color: crimson;'}, "Relation $i already exists : relation ignored"));
			}
		}
		else {
			if ($xaction eq 'update') {
				my $oid = param('oid'.$i);
				$req = "DELETE FROM $cross WHERE oid = $oid;";
				push(@msg, span({-style=>'color: green;'}, "Relation $i deleted"));
				
				$sth = $dbc->prepare($req) or die "$req ERROR: ".$dbc->errstr;
			
				$sth->execute() or die "$req ERROR: ".$dbc->errstr;
				Delete('oid'.$i);
			}
		}
		
	}
	Delete('nb_elem');
	
	my $links = 'For this taxon treat:' . p;
	my $xaction = param('xaction');
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		if($table ne $cross and $table =~ m/$table1/) {
			$links .= a({-href=>url()."?cross=$table&xaction=$xaction&xid=$xid", -style=>'text-decoration: none;'}, $cross_tables->{$table}->{'title'}) . p;
		}
	}
			
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		div({-style=>'width: 1000px; height: 20px; margin: 1% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
									
			img{-src=>'/Editor/done.jpg'}, p,
			
			span({-style=>'color: green'}, "Taxon treated"),
			
			p,
			
			join(', ', @msg),
			
			start_form(-name=>'Form', -method=>'post',-action=>''),
			
			arg_persist(),
						
			end_form(),
			
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"Form.action = 'crosstable.pl?cross=$cross&xaction=" . param('xaction') . "'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			'&nbsp;&nbsp;&nbsp;&nbsp;',
			a({-href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})), p,
			
			div({-style=>'float: left; margin-right: 50px; background: transparent;'}, $links),
									
			div(
				'For another taxon treat:', p,
				a({-href=>url()."?cross=$cross&xaction=$xaction", -style=>'text-decoration: none;'}, $cross_tables->{$cross}->{'title'})
				
			), p, 
		),
	
		html_footer();
}


sub Xrecap {
	
	my %headerHash = (
		titre => $title,
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
		
	my $crosslinks;
	my %doublons;
	my @msg;
		
	$crosslinks .= Tr( td({-colspan=>2}, hr) );
	my $iter = param('new_elem') || param('nb_elem');
	my $valid = 0;
	for (my $i=$iter; $i>0; $i--) {
		
		my $ok = 1;
		foreach (@{$obligatory}) {
			unless (param($_.$i)) { $ok = 0; } 
		}
		if ($ok) {
			my $rows;
			my $key;
			foreach (@{$table_definition}) {
				if (param($_->{'id'}.$i)) {
					my $title = $_->{'title'};
					$title =~ s/ /&nbsp;/g;
					if ($_->{'type'} eq 'pub') {
						$rows .= Tr(td(span($title)), td(pub_formating(get_pub_params($dbc, param($_->{'id'}.$i), 'html'))) );
					}
					elsif ($_->{'type'} eq 'select') {
						if (exists $_->{'labels'}) {
							$rows .= Tr(td(span($title)), td( $_->{'labels'}->{param($_->{'id'}.$i)} ) );
						}
						else {
							$rows .= Tr(td(span($title)), td( param($_->{'id'}.$i) ) );
					
						}
					}
					else {
						$rows .= Tr(td(span($title)), td(param($_->{'id'}.$i)) );
					}
					$key .= '|'.param($_->{'id'}.$i);
				}
			}
			unless(exists $doublons{$key}) {
				$doublons{$key} = 1;
				$crosslinks .= Tr( td({-colspan=>2}, span({-style=>'color: crimson;'}, "Relation " . ($i))));
				$crosslinks .= $rows;
				$crosslinks .= Tr( td({-colspan=>2}, hr) );
				$valid ++;
			}
			else {
				foreach (@{$table_definition}) {
					if ($_->{'type'} eq 'foreign') { Delete($_->{'ref'}.$i); }
					Delete($_->{'id'}.$i);
				}
				push(@msg, span({-style=>'color: crimson;'}, "Relation $i already exists : relation deleted"));
			}
		}
		else {	
			foreach (@{$table_definition}) {
				if ($_->{'type'} eq 'foreign') { Delete($_->{'ref'}.$i); }
				Delete($_->{'id'}.$i);
			}
			push(@msg, span({-style=>'color: crimson;'}, "Relation $i unvalid : relation deleted"));
		}
	}
		
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		div({-style=>'width: 1000px; height: 20px; margin: 1% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
									
			div({-id=>'boutons', -style=>'display: none;'},
			
				span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
					-onMouseout=>"document.okbtn.src=eval('okoffimg.src');",
					-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();"
					},
					img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
				),

				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
				span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src'); this.style.cursor='pointer';",
					-onMouseout=>"document.backbtn.src=eval('backoffimg.src');",
					-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$xaction'; crossForm.submit();"
					},
					img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
				),
			
				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
				
				a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
				p
			),
			
			"$title for ", span({-style=>'font-weight: bold;'}, $name), p,
			
			start_form(-name=>'crossForm', -method=>'post',-action=>''),
			
			join(', ', @msg),
			
			b($valid) . " valid Relation(s) ",
						
			table({-width=>'100%', -cellspacing=>'10px', -style=>'margin-left: -10px;', -border=>0}, $crosslinks),
			
			p,
			
			arg_persist(),

			end_form(),
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src');",
				-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			),

			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src'); this.style.cursor='pointer';",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src');",
				-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$xaction'; crossForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),

		),p,
		
		"<script type='text/javascript'>
		<!--
			document.getElementById('boutons').style.display = 'inline';
		//-->
		</script>",
	
		html_footer();
}

sub get_first_table() {

	my ($champ) = @_;
	
	my $reaction = url_param('xaction') || param('xaction') || 'fill';
	
	my @hiddens;
	
	my $default;
	unless ($default = param('elementX')) {
		Delete('xid');
		push(@hiddens, ['xid', '']);
	}
	else {
		push(@hiddens, ['xid', param('xid')]);
		Delete('xid');
		Delete('elementX');
	}
	
	my $intitule;
	if ($champ eq 'taxons') {
		$intitule = 'Taxon';
		
		make_thesaurus("SELECT t.index, nc.orthographe, nc.autorite
				FROM taxons_x_noms AS txn
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN taxons AS t ON txn.ref_taxon = t.index
				WHERE txn.ref_statut  = (SELECT index FROM statuts WHERE en = 'valid')
				ORDER BY orthographe, autorite;",
				'taxons',
				'$intitule = $row->[1]." ".$row->[2];',
				\$retro_hash,
				\$onload,
				$dbc);
		
		$onload .= "AutoComplete_Create('elementX', taxons, 20, 'xid', 'selectForm'); ";			
	}
	elsif ($champ eq 'noms') {
		$intitule = 'Name';
		
		make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;',
				'noms',
				'$intitule = $row->[1]." ".$row->[2];',
				\$retro_hash, 
				\$onload, 
				$dbc);
		
		$onload .= "AutoComplete_Create('elementX', noms, 20, 'xid', 'selectForm'); ";
	}
	
	my $field = 'Enter a name' . p .
	
	textfield(
		-class => 'phantomTextField', 
		-name=> 'elementX', 
		-size=>80, 
		-value => $default, 
		-id => 'elementX', 
		-onFocus => "	AutoComplete_ShowDropdown(this.getAttribute('id'));",
		-onChange=>"	if(!this.value) { document.selectForm.xid.value = ''; } 
				else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }"
	);
		
	my %headerHash = (
		titre => "$intitule selection",
		bgcolor => $background,
		css => $css,
		jscript => [	{-language=>'JAVASCRIPT', -code=>"$jscript_imgs"}, 
				{-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, 
				{-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	my $hidden;
	foreach (@hiddens) {
		$hidden .= hidden($_->[0], $_->[1]);
	}
	
	print 	html_header(\%headerHash),
	
		#join(br, map { "$_ = ".param($_) } param()),
		
		div({-style=>'width: 1000px; height: 20px; margin: 1% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
					
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Select a $intitule"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			),
			
			start_form(-name=>'selectForm', -method=>'post',-action=>url()."?cross=$cross&xaction=$reaction"),
			
			$field,
					
			$hidden,	
					
			p, br,
			
			span({	-onMouseover=>"document.btnok.src=eval('okonimg.src')",
				-onMouseout=>"document.btnok.src=eval('okoffimg.src')",
				-onClick=>"	if (document.selectForm.elementX.value) { document.selectForm.submit(); }
						else { alert('Select a taxon') }"},	
				img({-style=>'', -border=>0, -src=>'/Editor/ok0.png', -name=>"btnok"})
			),
			
			end_form(),
	
			p,
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		),
		
		html_footer();
}


sub makePubField {

	my ($title, $name, $i) = @_;
	
	my $target = "crosstable.pl?cross=$cross&xaction=$xaction";
	
	my $default;
	my $label;
	if(param("treat$name$i")) {
		Delete("treat$name$i");
		$default = param('searchPubId') || param("$name$i");
		if (param("$name$i")) { Delete("$name$i"); }
		Delete('searchPubId');
		$label  .= Tr( td({-colspan=>2, -id=>"label$name$i", -style=>'color: crimson;'}, pub_formating(get_pub_params($dbc, $default), 'html')) );
	}
	elsif (param("$name$i")) {
		$default = param("$name$i");
		Delete("$name$i");
		$label  .= Tr( td({-colspan=>2, -id=>"label$name$i", -style=>'color: crimson;'}, pub_formating(get_pub_params($dbc, $default), 'html')) );
	}
	
	return 	textfield(-class=>'phantomTextField', -name=>"$name$i", size=>4, -default=>$default, -onBlur=>"crossForm.action = '$target';  crossForm.submit();", -style=>'float: left; margin-top: 4px;').
		
		div({	-style=>'float: left; margin-top: 8px;',
			-onMouseover=>"searchp.src=eval('searchonimg.src'); this.style.cursor='pointer';",
			-onMouseout=>"searchp.src=eval('searchoffimg.src')",
			-onClick=>"	appendHidden(document.crossForm, 'searchFrom', '$target');
						appendHidden(document.crossForm, 'searchTo', '$target');
						appendHidden(document.crossForm, 'treat$name$i', '1');
						crossForm.action='pubsearch.pl?action=getOptions'; crossForm.submit();"},
			'&nbsp;&nbsp;&nbsp;&nbsp;'.
			img({-border=>0, -src=>'/Editor/search0.png', -name=>"searchp"}).
			'&nbsp;&nbsp;&nbsp;&nbsp;'
		) .
		
		div({	-style=>'float: left; margin-top: 8px;',
			-onMouseover=>"pubnew.src=eval('newonimg.src'); this.style.cursor='pointer';",
			-onMouseout=>"pubnew.src=eval('newoffimg.src')",
			-onClick=>"	appendHidden(document.crossForm, 'searchFrom', '$target');
						appendHidden(document.crossForm, 'searchTo', '$target');
						appendHidden(document.crossForm, 'treat$name$i', '1');
						crossForm.action='typeSelect.pl?action=insert&type=pub'; crossForm.submit();"},
			img({-border=>0, -src=>'/Editor/new0.png', -name=>"pubnew"})
		) .
		span({-style=>'clear: both;'}, '&nbsp;') . p . 
		$label;
}

$dbc->disconnect();
exit;

# Builds a publication from database
############################################################################################
sub publication {
	my ( $id, $full, $cpct, $dbh ) = @_;
	unless ( $id ){ return "" }
	my $publication;
	my $abrev;
	my $letter;
	# fetch publication data from db
	my $pre_pub = request_row("SELECT p.index, p.titre, p.annee, p.volume, p.fascicule, r.nom, e.nom, v.nom, p.page_debut, p.page_fin, t.en, p.nombre_auteurs
					FROM publications AS p LEFT JOIN types_publication AS t ON ( p.ref_type_publication = t.index )
					LEFT JOIN revues AS r ON ( p.ref_revue = r.index )
					LEFT JOIN editions AS e ON ( p.ref_edition = e.index )
					LEFT JOIN villes AS v ON ( e.ref_ville = v.index )
					WHERE p.index = $id;",$dbh);
	
	# Build authors list
	my $pre_authors = request_tab("SELECT a.nom, a.prenom, a.index, axp.position
					FROM auteurs_x_publications AS axp 
					LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index
					WHERE ref_publication = $id ORDER BY axp.position;",$dbh);
	
	my $authors;
	my $author;
	if ( $pre_pub->[11] > 1 ){ # Test if there are several authors
		if ( $full or $pre_pub->[11] < 3){
			for my $i ( 0..$pre_pub->[11]-1 ){
				if ( $i == $pre_pub->[11]-1 ){
					$authors .= "$pre_authors->[$i][0]";
				}
				else {
					$authors .= "$pre_authors->[$i][0] & ";
				}
			}
			
		}
		else {
			$authors = "$pre_authors->[0][0] " . i('et al.');
		}
		$author = $authors;
	}
	else {
		$authors = "$pre_authors->[0][0]";
		$author = "$pre_authors->[0][0]";
	}
	
	$abrev = "$author ($pre_pub->[2]$letter)";
	
	return ( $publication, $abrev );
}
