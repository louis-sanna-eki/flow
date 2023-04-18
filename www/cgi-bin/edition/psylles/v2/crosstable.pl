#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_row request_hash);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $cross_tables pub_formating get_pub_params make_thesaurus html_header html_footer arg_persist $maintitle);

my $user = remote_user();

my $dbc = db_connection(get_connection_params($conf_file));

my ($table1, $field1, $tables2, $title, $name, $onload);
my $cross = url_param('cross');
my $xid;
if (param('xid')) {
	$xid = param('xid'); 
}
else { 
	$xid = url_param('xid');
	param('xid', $xid);
}
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
# internal fields arguments : type, title, id
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
my $taxonid;
my $nameid;

unless ($xid) {
	get_first_table($table1);
}
else {
	if ($table1 eq 'taxons') {
		my $req = "	SELECT orthographe, autorite, index
				FROM noms_complets AS nc 
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
				WHERE txn.ref_taxon = $xid 
				AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid'); ";
	
		my $res = request_tab($req, $dbc, 2);
		
		$field1 = 'ref_taxon';
		$name = "$res->[0][0] $res->[0][1]";
		$taxonid = $xid;
		$nameid = $res->[0][2];
	}
	elsif ($table1 eq 'noms') {
		my $req = "	SELECT nc.orthographe, nc.autorite, txn.ref_taxon
				FROM noms_complets AS nc
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index
				WHERE nc.index = $xid; ";
	
		my $res = request_tab($req, $dbc, 2);
		
		$field1 = 'ref_nom';
		$name = "$res->[0][0] $res->[0][1]";
		if (scalar(@{$res}) == 1) {
			$taxonid = $res->[0][2];
		}
		$nameid = $xid;
	}
	
	if ( $cross eq 'taxons_x_pays' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4')));", 'pays', '$intitule = "$row->[1] [$row->[3]]";', \$retro_hash, \$onload, $dbc);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, \$onload, $dbc);
		}
						
		# elements needed to sort items in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	if ( $cross eq 'taxons_x_pays_x_agents_infectieux' or $cross eq 'taxons_x_pays_x_habitats' or $cross eq 'taxons_x_pays_x_modes_capture' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index in (select index from pays AS p where (select reencodage(en) from pays AS p2 where p2.parent = p.tdwg LIMIT 1) not like '%'|| '('||reencodage(p.en)||')'||'%' OR tdwg_level = '4') ORDER BY en;", 'pays', '$intitule = "$row->[1] [$row->[3]]";', \$retro_hash, \$onload, $dbc);
		}
						
		# elements needed to sort items in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}	
	elsif ( $cross eq 'taxons_x_plantes' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT index, get_host_plant_name(index) AS fullname FROM plantes ORDER BY fullname;", 'plantes', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}
		
		# elements needed to sort items in case of update action
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
			
		# elements needed to sort items in case of update action
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
		
		# elements needed to sort items in case of update action
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
		
		# elements needed to sort items in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_periodes' ) {
		
		# elements needed to sort items in case of update action
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
		
		# elements needed to sort items in case of update action
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
		
		# elements needed to sort items in case of update action
		$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
		$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
		$order = $cross_tables->{$cross}->{'order'};	
	}
	elsif ( $cross eq 'taxons_x_taxons_associes' ) {
		
		if ($xaction eq 'fill' or $xaction eq 'modify' or $xaction eq 'more' or $xaction eq 'duplicate') {
					
			# thesauri definition for foreign keys
			make_thesaurus("SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') FROM taxons_associes AS x ORDER BY (get_taxon_associe(x.index)).nom;", 'taxons_associes', '$intitule = $row->[1];', \$retro_hash, \$onload, $dbc);
		}
		
		# elements needed to sort items in case of update action
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

	# Main body Function selection #####################################################################################################################
	if ($xaction eq 'fill') {
		$new_elem = param('new_elem') || 1;
		Delete('new_elem');
		$reaction = 'insert';
		Xform();
	}
	if ($xaction eq 'modify') {
		$nb_elem = param('nb_elem');
		Delete('nb_elem');
		$reaction = 'update';
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

$dbc->disconnect();
exit;

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
	
	my $tmp = param('duplicate');
	
	push(@hiddens, ['xaction', $xaction]);
	if (my $dup = param('duplicate')) {
		
		my $penult = $new_elem - 1;
		my $vide = 1;
		foreach (@{$table_definition}) {
			if ($_->{'type'} eq 'foreign' and  param($_->{'ref'}.$penult)) { $vide = 0; last; }
			elsif ($_->{'type'} ne 'foreign' and param($_->{'id'}.$penult)) { $vide = 0; last; }
		}			
		if ($vide) { $new_elem--; }
		
		# If duplicate an item that was already in the database
		if ($dup =~ /p/) {
			$dup = substr($dup, 1);
			foreach my $row (@{$preexist}) {
				if ($row->[$noid] == $dup) {
					my $i = 0;
					foreach (@{$table_definition}) {
						if($row->[$i]) {
							if ($_->{'type'} eq 'foreign') { 
								my $value = $retro_hash->{$_->{'thesaurus'}.$row->[$i]};
								$value =~ s/  / /g;
								param($_->{'id'}.$new_elem, $value);
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
		# If duplicate fields that have just been filled 
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
				if($row->[$i] and $field->{'display'} ne 'none') {
					my $color = 'navy';
					#if ($i % 2) { $color = '#CC4400'; }
					my $title = $field->{'title'};
					$title =~ s/ /&nbsp;/g;
					if ($field->{'type'} eq 'pub') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, publication($row->[$i], 0, 1, $dbc))));
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, publication($row->[$i], 0, 1, $dbc)) . span({-style=>"color: #666666;"}, '[' . $row->[$i] . ']') . '.') . ' ';
					}
					#pub_formating(get_pub_params($dbc, $row->[$i]), 'html')))
					elsif ($field->{'type'} eq 'foreign') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]})));
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . '.') . ' ';
					} 
					elsif ($field->{'type'} eq 'select') {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]})));
						my $tmp;
						$tmp = span({-style=>"color: #444444;"}, $title) . ' : ';
						if (exists $field->{'labels'}) {
							$tmp .= span({-style=>"color: $color;"}, $field->{'labels'}->{$row->[$i]}) . '.';
						}
						else { 
							$tmp .= span({-style=>"color: $color;"}, $row->[$i]) . '.'; 
						}
						$element .= span({-style=>'white-space:nowrap;'}, $tmp) . ' ';
					} 
					else {
						#$element .= Tr(td(span({-style=>"color: #444444;"}, $title)), td(span({-style=>"color: $color;"}, $row->[$i])));
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, $row->[$i]) . '.') . ' ';
					}
				}
				$i++;
			}
			$element = td( $element );
			$element = td({-style=>'width: 90px;'}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"appendHidden(document.crossForm, 'duplicate', 'p".$row->[$noid]."'); crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate'; crossForm.submit();", -src=>'/Editor/duplicate.png'})) . $element;

			$explorer .= Tr($element);
			$explorer .= Tr( td({-colspan=>2}, hr({-style=>'margin: 0px; color: #DDDDDD;'})) );
		}
		if (scalar(@{$preexist})) {
			$explorer = hr . span({-style=>'color: black;'}, 'Existing item(s):') . p . table({-width=>'100%', -border=>'0px solid black;'}, $explorer);
		}
	}
	else {
		#if ($cross_tables->{$cross}->{'obligatory'}) {
		#	$sentence = img({-border=>0, -src=>'/Editor/caution.png', -name=>"hep" , -alt=>"CAUTION", -style=>'width: 25px; margin-bottom: -5px;'});
		#	my @df;
		#	foreach my $field (@{$table_definition}) {
		#		foreach my $ob (@{$cross_tables->{$cross}->{'obligatory'}}) {
		#			if ($field->{'id'} eq $ob) { push(@df, $field->{'title'}); last; }
		#		}
		#	}
		#	$sentence .= span({-style=>'color: crimson;'}, " To delete an item, clear all the item fields and click on submit button") . p;
		#	
		#}

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
	
	my $iter = $new_elem || $nb_elem;
	my $reste = $iter;
	for (my $i=$iter; $i>0; $i--) {
		
		unless (param("delete$i") eq 'yes') {
			param("delete$i", 'no');
			my $dupfield;
			if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
				
				$dupfield = img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"appendHidden(document.crossForm, 'duplicate', $i); crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate'; crossForm.submit();", -src=>'/Editor/duplicate.png'});
			}
			else {
				$dupfield = img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", -border=>0, -src=>'/Editor/submit.png', -name=>"okbtn"});
			}
			my $linkhead = td({-style=>'padding-left: 15px;'}, "Item " . $i). td({-style=>'padding-left: 300px;'}, $dupfield);
			my $linkbody;
			my $clear_actions;
			$clear_actions .= "document.getElementById('head$i').style.display = 'none';";
			#$clear_actions .= "document.getElementById('tail$i').style.display = 'none';";
			$clear_actions .= "document.crossForm.delete$i.value = 'yes'; ";
			$clear_actions .= "document.getElementById('decompte').innerHTML = document.getElementById('decompte').innerHTML - 1;";
			foreach (@{$table_definition}) {
			
				my $id = $_->{'id'};
				my $ref = $_->{'ref'};
				my $default;
				my $display = $_->{'display'} || 'table-row';
				if ($_->{'type'} eq 'foreign') {
				
					unless (param("$ref$i")) {
						$default = $_->{'default'} || '-- Search --';
						push(@hiddens, ["$ref$i", 0]);
						Delete("$ref$i");
					}
					else {
						$default = param("$id$i");
						push(@hiddens, ["$ref$i", param("$ref$i")]);
						Delete("$ref$i");
					}
					my $field = textfield(
						-class => 'phantomTextField', 
						-name=> "$id$i", 
						-size=>70, 
						-value => $default, 
						-id => "$id$i", 
						-onFocus => "	if(this.value == '-- Search --') { this.value = ''; } AutoComplete_ShowDropdown(this.getAttribute('id'));",
						-onBlur => "	if(!this.value) { this.value = '-- Search --' } ",
						-onChange=>"	if(!this.value || this.value == '-- Search --') { document.crossForm.$ref$i.value = ''; }
								else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }"
					);
					
					my $label = lc($_->{'title'});
					$label =~ s/ /&nbsp;/g;	
					my $more;
					if ($_->{'addurl'}) {
						$more = td({-style=>'padding-left: 6px;'}, a({-href=>$_->{'addurl'}, -target=>'_blank', -style=>'text-decoration: none;', -onClick=>"document.getElementById('redalert').style.display = 'inline';"}, img({-border=>0, -src=>'/Editor/add.png'})) );
					}
					$autofields .= "AutoComplete_Create('$id$i', " . $_->{'thesaurus'} . ", 20, '$ref$i', 'crossForm'); ";
					
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, td(span({-style=>'margin-right: 6px; padding-left: 15px; white-space: nowrap;'}, $_->{'title'})), td({-colspan=>2}, table({-cellspacing=>0, -cellpadding=>0}, Tr(td($field).$more))));
					
					$clear_actions .= "document.crossForm.$id$i.value = '-- Search --'; ";
					$clear_actions .= "document.crossForm.$ref$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
					#$clear_actions .= "alert('foreign'); ";
				}
				elsif ($_->{'type'} eq 'pub') {
					
					$linkbody .= Tr({-id=>"row_$id$i"}, td(span({-style=>'margin-right: 6px; padding-left: 15px; white-space: nowrap;'}, $_->{'title'})), td({-colspan=>2}, makePubField($_->{'title'}, $id, $i)) );
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "if(document.getElementById('label$id$i')) { document.getElementById('label$id$i').innerHTML = ''; } ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
					#$clear_actions .= "alert('pub'); ";
				}
				elsif ($_->{'type'} eq 'select') {
					
					$default = param("$id$i") || $_->{'default'};
					my $label = lc($_->{'title'});
					$label =~ s/ /&nbsp;/g;
					my $more;
					if ($_->{'addurl'}) {
						$more = td( a({-href=>$_->{'addurl'}, -target=>'_blank', -style=>'text-decoration: none;', -onClick=>"document.getElementById('redalert').style.display = 'inline';"}, img({-border=>0, -src=>'/Editor/add.png'})) );
					}
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, td(span({-style=>'margin-right: 0px; padding-left: 15px; white-space: nowrap;'}, $_->{'title'})), td({-colspan=>2}, table({-cellspacing=>0, -cellpadding=>0}, Tr(td({-style=>'padding-right: 6px;'}, popup_menu(-class=>'phantomTextField', -style=>"padding: 0;", -name=>"$id$i", -default=>$default, values=>$_->{'values'}, -labels=>$_->{'labels'})).$more))));
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
					#$clear_actions .= "alert('select'); ";
				}
				elsif ($_->{'type'} eq 'internal') {

					$default = param("$id$i") || $_->{'default'};
					my $l = $_->{'length'} || 70;
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, td(span({-style=>'margin-right: 0px; padding-left: 15px; white-space: nowrap;'}, $_->{'title'})), td({-colspan=>2}, textfield(-class=>'phantomTextField', -name=>"$id$i", -default=>$default, -size=>$l)) );
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
					#$clear_actions .= "alert('text'); ";
				}
				Delete("$id$i");
			}
			
			#my $tests = "
			#alert('1 - '+document.getElementById('head4'));
			#alert('2 - '+document.crossForm.delete4.value);
			#alert('3 - '+document.getElementById('decompte').innerHTML);
			#alert('4 - '+document.crossForm.pays4.value);
			#alert('5 - '+document.crossForm.ref_pays4.value);
			#alert('6 - '+document.getElementById('row_pays4'));
			#alert('7 - '+document.crossForm.ref_publication_ori4.value);
			#alert('8 - '+document.getElementById('labelref_publication_ori4'));
			#alert('9 - '+document.getElementById('row_ref_publication_ori4'));
			#alert('10 - '+document.getElementById('row_page_ori4'));
			#alert('11 - '+document.getElementById('row_precision4'));
			#";
			
			$linkhead .= td({-style=>'text-align: center;'}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"if(confirm('Are you sure?')) { $clear_actions } else { return false; };", -border=>0, -src=>'/Editor/delete.png', -name=>"clearbtn"}));
			#$crosslinks .= Tr( td({-colspan=>2}, hr) );
			my $linktail;
			if ($xaction eq 'modify' and 0) {
				$linktail = Tr({-id=>"tail$i"}, td({-colspan=>3, -style=>'padding-top: 10px;'}, 
					img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", -src=>'/Editor/submit.png', -name=>"okbtn"}), p
				) );
			}
			$crosslinks .= Tr({-style=>'background-color: #DDDDDD;', -id=>"head$i"}, $linkhead) . $linkbody . $linktail;
		}
		else { $reste--; }
	}
	$crosslinks = Tr( td({-colspan=>3}, hr({-style=>'margin: 6px 0 4px 0; color: #DDDDDD;'}) ) ) . $crosslinks;
	$onload .= $autofields;
	
		
	my $addrelation;
	my $advise;
	if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
		$addrelation = 	td({-style=>'padding-left: 20px;'},
					img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action='crosstable.pl?cross=$cross&xaction=more'; crossForm.submit();", -src=>'/Editor/add.png'})
				);
	}
	
	my %headerHash = (
		titre => $title,
		css => $css,
		jscript => [	{-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, 
						{-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	my $hids;
	foreach (@hiddens) {
		Delete($_->[0]);
		$hids .= hidden($_->[0], $_->[1]);
	}
	$hids .= hidden('taxonid', $taxonid);
	$hids .= hidden('nameid', $nameid);
		
	my $str = span({-id=>'decompte'}, $reste);
	if ($iter > 1) { $str .= " items" }
	else { $str .= " item" }
		
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()) . p . join(br, map { $_->[0]." = ".$_->[1] } @hiddens), br, $tmp,
		
		$maintitle,
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
						
			table(	Tr(	td(span({-style=>'font-weight: normal;'}, ucfirst($reaction)) . " $title of ", span({-style=>'font-weight: normal;'}, $name)), 
					td({-style=>'padding-left: 20px;'}, a({-href=>"crosstable.pl?cross=$cross&xaction=$xaction"}, img({-border=>0, -src=>'/Editor/back.png', -name=>"backbtn"})))
				)
			), p,
			
			$sentence,
						
			start_form(-name=>'crossForm', -method=>'post',-action=>''),
			
			table(	Tr(	td("$str"),
					$addrelation,
					td({-style=>'padding-left: 20px;'}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", -border=>0, -src=>'/Editor/submit.png', -name=>"okbtn"}))
				)
			),		
			
			$advise,
			
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg1'}, 
				br . "A new page will open, when data is entered, close this page, go back to the current one and reload it" . br . br
			),		
						
			table({-width=>'100%', -border=>0}, 
				
				$crosslinks,
				Tr(td({-colspan=>3}, hr({-style=>'margin: 4px 0 6px 0; color: #DDDDDD;'}))),
				Tr(td({-colspan=>3}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", -border=>0, -src=>'/Editor/submit.png', -name=>"okbtn"})))
				
			), p,
						
			$explorer,
						
			arg_persist(),
			
			$hids,
			
			end_form()
		), p,
	
		html_footer();
}

sub Xexecute {
	
	my %headerHash = (
		titre => $title,
		css => $css,
		jscript => $jscript_for_hidden,
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
					push(@msg, span({-style=>'color: green;'}, "Item $i updated"));
				}
											
				$sth = $dbc->prepare($req) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
			
				$sth->execute(@values) or die "$req WITH (@values) ERROR: ".$dbc->errstr;
			}
			else {
				push(@msg, span({-style=>'color: crimson;'}, "Item $i already exists : Item ignored"));
			}
		}
		else {
			if ($xaction eq 'update') {
				my $oid = param('oid'.$i);
				$req = "DELETE FROM $cross WHERE oid = $oid;";
				push(@msg, span({-style=>'color: green;'}, "Item $i deleted"));
				
				$sth = $dbc->prepare($req) or die "$req ERROR: ".$dbc->errstr;
			
				$sth->execute() or die "$req ERROR: ".$dbc->errstr;
				Delete('oid'.$i);
			}
		}
		
	}
	Delete('nb_elem');
	Delete('new_elem');
	
	foreach (param()) { Delete($_); }

	my $links = Tr(td({-colspan=>2, -style=>'padding: 0 0 10px 0;'}, "for $name:"));
	my $otherLinks = Tr(td({-colspan=>2, -style=>'padding: 16px 0 10px 0;'}, 'for another taxon:'));			
	my $xaction = param('xaction');
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		if($table =~ /$table1/) {
			$links .= Tr(
					td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$xid", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>url()."?cross=$table&xaction=modify&xid=$xid", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
			$otherLinks .= Tr(
					td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
		}
		else {
			if ($table1 eq 'taxons') {
				$links .= Tr(
						td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$nameid", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify&xid=$nameid", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
				$otherLinks .= Tr(
						td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
			}
			elsif  ($table1 eq 'noms') {
				
				if ($taxonid) {
					$links .= Tr(
							td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
							td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$taxonid", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
								'&nbsp; / &nbsp;' . 
								a({-href=>url()."?cross=$table&xaction=modify&xid=$taxonid", -style=>'text-decoration: none; color: navy;'}, 'Update')
							)
						);
				}
				
				$otherLinks .= Tr(
						td({-style=>'padding-left: 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
			}
		}
	}
		
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		$maintitle,
		
		div({-class=>"wcenter"},
									
			img{-src=>'/Editor/done.png'}, p,
			
			table( Tr(
				td({-style=>'padding-right: 20px;'}, span({-style=>'color: green'}, "Modifications done") ),
				#td( img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"Form.action = 'crosstable.pl?cross=$cross&xaction=modify&xid=$xid'; Form.submit();", -border=>0, -src=>'/Editor/modify.png', -name=>"backbtn"}))
			) ), p,
			
			#join(', ', @msg),
			
			start_form(-name=>'Form', -method=>'post',-action=>''),
			
			arg_persist(),
						
			end_form(), 
			
			table({-border=>0},
				$links,
				$otherLinks
			)
		), p,
	
		html_footer();
}


sub Xrecap {
	
	my %headerHash = (
		titre => $title,
		css => $css,
		jscript => $jscript_for_hidden,
	);
		
	my $crosslinks;
	my %doublons;
	my @msg;
		
	$crosslinks .= Tr( td({-colspan=>2}, hr({-style=>'margin: 0; color: #DDDDDD;'})) );
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
			my @conditions = ("$field1 = ?");
			my @valeurs = ($xid);
			foreach (@{$table_definition}) {
				
				if ($_->{'type'} eq 'foreign') {
					if (param($_->{'ref'}.$i)) {
						push(@conditions, "$_->{'ref'} = ?");
						push(@valeurs, param($_->{'ref'}.$i));
					}
					else { 
						push(@conditions, "$_->{'ref'} IS NULL"); 
					}
				}
				
				if (param($_->{'id'}.$i)) {
					my $title = $_->{'title'};
					$title =~ s/ /&nbsp;/g;
					if ($_->{'type'} eq 'pub') {
						$rows .= Tr(td({-style=>'padding-right: 10px;'}, span({-style=>'white-space: nowrap;'}, $title)), td({-width=>'85%'}, pub_formating(get_pub_params($dbc, param($_->{'id'}.$i), 'html')) ) );
					}
					elsif ($_->{'type'} eq 'select') {
						if (exists $_->{'labels'}) {
							$rows .= Tr(td({-style=>'padding-right: 10px;'}, span({-style=>'white-space: nowrap;'}, $title)), td({-width=>'85%'}, $_->{'labels'}->{param($_->{'id'}.$i)} ) );
						}
						else {
							$rows .= Tr(td({-style=>'padding-right: 10px;'}, span({-style=>'white-space: nowrap;'}, $title)), td({-width=>'85%'}, param($_->{'id'}.$i) ) );
					
						}
					}
					else {
						$rows .= Tr(td({-style=>'padding-right: 10px;'}, span({-style=>'white-space: nowrap;'}, $title)), td({-width=>'85%'}, param($_->{'id'}.$i) ) );
					}
					$key .= '|'.param($_->{'id'}.$i);
					
					if ($_->{'type'} ne 'foreign') {
						if (param($_->{'id'}.$i)) {
							push(@conditions, "$_->{'id'} = ?");
							push(@valeurs, param($_->{'id'}.$i));
						}
					}
				}
				else { 
					if ($_->{'type'} ne 'foreign') {
						push(@conditions, "$_->{'id'} IS NULL");
					}
				}

			}
			my $double = 0;
			my $request = "SELECT count(*) FROM $cross WHERE ".join(' AND ', @conditions).";";
						
			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute( @valeurs ) ){
					($double) = $sth->fetchrow_array;
					$sth->finish();
				} else { die( "Execute error: $request with @valeurs ".$dbc->errstr ); }
			} else { die( "Prepare error: $request with @valeurs ".$dbc->errstr ); }
						
			if ($double) { $doublons{$key} = 1; }
			
			#$crosslinks .= Tr( td({-colspan=>2}, "$request with @valeurs => $double") );
			
			unless(exists $doublons{$key}) {
				$doublons{$key} = 1;
				$crosslinks .= Tr( td({-colspan=>2}, img({-border=>0, -src=>'/Editor/done.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: darkgreen'}, " Valid item")) );
				$crosslinks .= $rows;
				$crosslinks .= Tr( td({-colspan=>2}, hr({-style=>'margin: 0; color: #DDDDDD;'})) );

				$valid ++;
			}
			else {
				my $sentence;
				if($reaction eq 'insert') {
					foreach (@{$table_definition}) {
						if ($_->{'type'} eq 'foreign') { Delete($_->{'ref'}.$i); }
						Delete($_->{'id'}.$i);
					}
					$sentence = img({-border=>0, -src=>'/Editor/stop.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, " duplicated item ignored");
				}
				elsif ($reaction eq 'update') {
					$sentence = img({-border=>0, -src=>'/Editor/done.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: darkgreen'}, " item unchanged");
				}
				$crosslinks .= Tr( td({-colspan=>2}, $sentence) );
				$crosslinks .= $rows;
				$crosslinks .= Tr( td({-colspan=>2}, hr({-style=>'margin: 0; color: #DDDDDD;'})) );
			}
		}
		else {	
			my $sentence;
			foreach (@{$table_definition}) {
				if ($_->{'type'} eq 'foreign') { Delete($_->{'ref'}.$i); }
				Delete($_->{'id'}.$i);
			}
			if($reaction eq 'insert') {
				$sentence = img({-border=>0, -src=>'/Editor/stop.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, " empty item ignored");
			}
			elsif ($reaction eq 'update') {
				$sentence = img({-border=>0, -src=>'/Editor/caution.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, " one item deleted");
			}

			$crosslinks .= Tr( td({-colspan=>2}, $sentence));
			$crosslinks .= Tr( td({-colspan=>2}, hr({-style=>'margin: 0; color: #DDDDDD;'})) );
		}
	}
	
	my $message = join(', ', @msg);
	if ($message) { $message .= p; } 
	
	my $subtitle;
	if($reaction eq 'insert') { 
		my $str;
		if ($valid > 1) { $str .= "$valid valid items" }
		else { $str .= "$valid valid item" }
		$subtitle = td({-style=>'padding-right: 20px;'}, $str) 
	}
		
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		$maintitle,
		
		div({-class=>"wcenter"},
					
			table(	Tr(	td(span({-style=>'font-weight: normal;'}, ucfirst($reaction)) . " $title of ", span({-style=>'font-weight: normal;'}, $name)), 
					td({-style=>'padding-left: 20px;'}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$xaction'; crossForm.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"backbtn"}))
				)
			), p,
			
			start_form(-name=>'crossForm', -method=>'post',-action=>''),
			
			#$message,
			
			$subtitle, p,
			
			img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", -border=>0, -src=>'/Editor/submit.png', -name=>"okbtn"}),

			table({-cellspacing=>'4px', -style=>'', -border=>0}, $crosslinks), p,
			
			arg_persist(),
			
			img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", -border=>0, -src=>'/Editor/submit.png', -name=>"okbtn"}), p,

			end_form(),
		), p,
			
		html_footer();
}

sub get_first_table() {

	my ($champ) = @_;
	
	my $reaction = url_param('xaction') || param('xaction') || 'fill';
	
	my @hiddens;
	
	my $default;
	if (param('elementX')) {
		$default = param('elementX');
		push(@hiddens, ['xid', $default]);
		Delete('elementX');
		Delete('xid');
	}
	else {
		$default = '-- Search --';
		push(@hiddens, ['xid', 0]);
		Delete('xid');
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
		
	my $field = 
	#'Enter a name' . p .
	textfield(
		-class => 'phantomTextField', 
		-name=> 'elementX', 
		-size=>80, 
		-value => $default, 
		-id => 'elementX', 
		-onFocus => "	if(this.value == '-- Search --') { this.value = ''; } AutoComplete_ShowDropdown(this.getAttribute('id'));",
		-onBlur => "	if(!this.value) { this.value = '-- Search --' } else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = ''; }",
		-onChange=>"	if(!this.value || this.value == '-- Search --') { document.selectForm.xid.value = ''; }"
	);
		
	my %headerHash = (
		titre => "$intitule selection",
		css => $css,
		jscript => [	{-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, 
						{-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoCompleteHash.js'} ],
		onLoad => $onload
	);
	
	my $hidden;
	foreach (@hiddens) {
		$hidden .= hidden($_->[0], $_->[1]);
	}
	
	print 	html_header(\%headerHash),
	
		#join(br, map { "$_ = ".param($_) } param()),
		
		$maintitle,
		
		div({-class=>"wcenter"},
					
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'}, "Select a $intitule"),
				)
			),
			
			start_form(-name=>'selectForm', -method=>'post',-action=>url()."?cross=$cross&xaction=$reaction"),
			
			$field,
					
			$hidden,	
					
			p, br,
			
			img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"if (document.selectForm.elementX.value) { document.selectForm.submit(); } else { alert('Select a taxon') }", -border=>0, -src=>'/Editor/submit.png', -name=>"btnok"}),
			
			end_form()
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
		$label  .= Tr( td({-colspan=>3, -id=>"label$name$i", -style=>'color: crimson; padding-left: 15px;'}, pub_formating(get_pub_params($dbc, $default), 'html')) );
	}
	elsif (param("$name$i")) {
		$default = param("$name$i");
		Delete("$name$i");
		$label  .= Tr( td({-colspan=>3, -id=>"label$name$i", -style=>'color: crimson; padding-left: 15px;'}, pub_formating(get_pub_params($dbc, $default), 'html')) );
	}
	
	return 	table({-cellspacing=>0, -cellpadding=>0}, Tr(
			td({-style=>'padding-right: 6px;'}, textfield(-class=>'phantomTextField', -name=>"$name$i", -id=>"$name$i", size=>4, -default=>$default, -onBlur=>"crossForm.action = '$target';  crossForm.submit();")),
			td({-style=>'padding-right: 6px;'}, img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"appendHidden(document.crossForm, 'searchFrom', '$target'); appendHidden(document.crossForm, 'searchTo', '$target'); appendHidden(document.crossForm, 'treat$name$i', '1'); crossForm.action='pubsearch.pl?action=getOptions'; crossForm.submit();", -border=>0, -src=>'/Editor/search.png', -name=>"searchp"})),
			td(img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"appendHidden(document.crossForm, 'searchFrom', '$target'); appendHidden(document.crossForm, 'searchTo', '$target'); appendHidden(document.crossForm, 'treat$name$i', '1'); crossForm.action='typeSelect.pl?action=insert&type=pub'; crossForm.submit();", -border=>0, -src=>'/Editor/new.png', -name=>"pubnew"}))
			)
		) . $label;
}

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