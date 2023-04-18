#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/lucanidae/'} 
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use CGI::Ajax;
use DBCommands qw (get_connection_params db_connection request_tab request_row);
use Conf qw ($conf_file $css $jscript_for_hidden $cross_tables html_header html_footer arg_persist $maintitle);
use utf8;

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EDITOR');
my $user = remote_user();
my $test;

foreach (param()) { if ( !param($_) or param($_) =~ m/^-- / or param($_) eq 'undefined' ) { Delete($_); } }

my $cgi = new CGI();
my $pjx = new CGI::Ajax( 'getThesaurusItems' => \&getThesaurusItems, 'getPubTitle' => \&getPubTitle );	

my ($table1, $field1, $tables2, $title, $name);
my $cross = url_param('cross');
my $xid;
my $xname;
my $xlabel = param('elementX') || url_param('elementX');
if (param('xid') or url_param('xid')) {
	my $value = param('xid') || url_param('xid');
	($xid, $xname) = split('#', $value);
	Delete('xid');
	param('xid', $xid);
}

my $xaction = url_param('xaction');

if ($cross) {
	@{$tables2} = split(/_x_/, $cross);
	$table1 = shift(@{$tables2});
}
# fast access
my $jscript = "function setThesaurusItems() { 
		var arr = arguments[0].split('_ARG_');
		var idx = arr[0]; 
		var tbl = arr[1]; 
		var str = arr[2]; 
		var nb = arr[3]; 
		var expr = arr[4]; 
		var test = expr.search('--');
		//if (nb == 0 && test == -1) { alert('No data matches \"'+expr+'\"'); }
		eval(str);
		if(__AutoComplete[idx]) { AutoComplete_HideDropdown(idx); }
		if (tbl == 'taxons') {
			AutoComplete_Create(idx, tbl, 'xid', 'selectForm', 770, 'true');
		}
		else if (tbl == 'noms') {
			AutoComplete_Create(idx, tbl, 'xid', 'selectForm', 770, 'true');
		}
		else {
			AutoComplete_Create(idx, tbl, 'ref_'+idx, 'crossForm', 770, 'true');
		}
		__AutoComplete[idx]['data'] = eval(tbl);
		AutoComplete_ShowDropdown(idx);
	}\n
	var typewatch = function(){
		var timer = 0;
		return function(callback, ms){
			clearTimeout(timer);
			timer = setTimeout(callback, ms);
		}  
	}();\n";

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
my $taxonid;
my $nameid;

unless ($xid) {
	get_first_table($table1);
}
else {
	if ($table1 eq 'taxons') {
		$name = $xlabel;
		$field1 = 'ref_taxon';
		$taxonid = $xid;
		$nameid = param('nameid') || $xname;
	}
	elsif ($table1 eq 'noms') {
		my $req = "SELECT nc.orthographe, nc.autorite, txn.ref_taxon FROM noms_complets AS nc LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index WHERE nc.index = $xid; ";
		my $res = request_tab($req, $dbc, 2);		
		$name = $xlabel;
		$field1 = 'ref_nom';
		if (scalar(@{$res}) == 1) {
			$taxonid = $res->[0][2];
		}
		$nameid = $xid;
	}
			
	# elements needed to sort items in case of update action
	$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'} || [];
	$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
	$order = $cross_tables->{$cross}->{'order'};
	
	# page title
	$title = $cross_tables->{$cross}->{'title'};
	# fields definitions
	$table_definition = $cross_tables->{$cross}->{'definition'};
	# obligatory fields
	$obligatory = $cross_tables->{$cross}->{'obligatory'};

	foreach (@{$table_definition}) {
		if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { push(@{$table_fields}, $_->{'ref'}); }
		else { push(@{$table_fields}, $_->{'id'}); }
	}	

	# Main body Function selection #####################################################################################################################
	if ($xaction eq 'fill') {
		$new_elem = param('new_elem') || 1;
		Delete('new_elem');
		$reaction = 'insert';
		Xform();
	}
	if ($xaction eq 'modify' or $xaction eq 'get') {
		$nb_elem = param('nb_elem');
		Delete('nb_elem');
		$reaction = 'update';
		Xform();
	}
	elsif ($xaction eq 'verify') {
		$xaction = param('xaction');
		if ($xaction eq 'fill') { $reaction = 'insert'; }
		elsif ($xaction eq 'modify' or $xaction eq 'get') { $reaction = 'update'; }
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
# fast access
sub getThesaurusItems {
	
	my ($id, $table, $expr) = @_;	
	my ($req, $res, $str, $where);

	if ($id) {
		$str = "$table = {}; ";
		$expr =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		$expr =~ s/\*/\%/g;
	}
		
	if ($table eq 'taxons') { 
		
		$req = "SELECT t.index || '#' || nc.index,
			
			CASE WHEN nc.index != nt.index THEN
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'family', ',', 'down', 'notfull')) || ')', '') || 
				coalesce(' [' || (select abbrev from statuts where index = txn.ref_statut) || '] ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || 
				coalesce(' (' || (select all_to_rank(nt.index, 'subtribe', 'family', ',', 'down', 'notfull')) || ')', '')
			ELSE
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'family', ',', 'down', 'notfull')) || ')', '')
			END,
			
			nc.orthographe,
			nc.autorite,
			txn.ref_statut,
			CASE WHEN (SELECT count(*) FROM taxons_x_noms WHERE ref_nom = txn.ref_nom AND ref_nom_cible = txn.ref_nom_cible) > 1 THEN
			' => '||(SELECT orthographe || coalesce(' '||autorite,'') FROM noms_complets WHERE index = (SELECT ref_nom FROM taxons_x_noms where ref_taxon = txn.ref_taxon and ref_statut = 1))
			END
		FROM taxons_x_noms AS txn 
		LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
		LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
		LEFT JOIN noms AS n ON n.index = nc.index
		LEFT JOIN noms AS n2 ON n2.index = nt.index
		LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
		WHERE txn.ref_statut NOT IN (5,8,17,18,20,21)
		AND nc.orthographe ILIKE '%$expr%'
		ORDER BY 3, 4, 5, 2;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) { 
				my $value = $_->[1].$_->[5];
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; '; 
		}
	}
	
	elsif ($table eq 'taxons_associes') { 
		
		if ($id) { $where = "WHERE (get_taxon_associe(x.index)).nom ILIKE '%$expr%'"; }
		else { $where = "WHERE index = $expr"; }
		
		
		$req = "SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') ||
			coalesce (
			CASE WHEN (get_taxon_associe(x.index)).ordre IS NOT NULL AND (get_taxon_associe(x.index)).famille IS NOT NULL THEN
			' (' || (get_taxon_associe(x.index)).ordre || ', ' || (get_taxon_associe(x.index)).famille || ')'
			WHEN (get_taxon_associe(x.index)).ordre IS NOT NULL OR (get_taxon_associe(x.index)).famille IS NOT NULL THEN
			' (' || coalesce( (get_taxon_associe(x.index)).ordre ,'') || coalesce( (get_taxon_associe(x.index)).famille ,'') || ')'
			END, '')
			FROM taxons_associes AS x 
			$where
			ORDER BY (get_taxon_associe(x.index)).nom;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { 
			foreach (@{$res}) { 
				my $value = $_->[1];
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; '; 
			} 
		}
		else { $str = $res->[0][1]; }
	}
	
	elsif ($table eq 'noms') { 
		
		$req = "SELECT index, orthographe || coalesce(' ' || autorite, '') FROM noms_complets WHERE orthographe ILIKE '%$expr%' AND index IN (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_statut NOT IN (5,8,17,18,20,21,22)) ORDER BY 2;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) { 
				my $value = $_->[1];
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; '; 
		}
	}
	elsif ($table eq 'publications') {
		
		if ($id) { $where = "WHERE reencodage(coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')) ILIKE reencodage('%$expr%')
				ORDER BY coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '')"; 
		}
		else { $where = "WHERE index = $expr"; }
				
		$req = "SELECT 	index, coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '')
				FROM publications AS p 
				$where;";
				
		$res = request_tab($req, $dbc, 2);
			
		if ($id) { 
			foreach (@{$res}) {
				my $value = $_->[1];
				$value =~ s/"/\\"/g;
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; ';
			}
		}
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'tdwg') {
		
		if ($id) { $where = "WHERE ( tdwg_level IN ('1', '2', '4') 
				OR index IN (
					SELECT index FROM pays WHERE tdwg_level = '3' AND en NOT IN (
						SELECT DISTINCT en FROM pays WHERE tdwg_level = '4'
					)
				)
			)
			AND reencodage(en) ILIKE reencodage('%$expr%')
			ORDER BY en"; 
		}
		else { $where = "WHERE index = $expr"; }

		$req = "SELECT index, en, tdwg, tdwg_level FROM pays $where;";
				
		$res = request_tab($req, $dbc, 2);
				
		if ($id) { 
			foreach (@{$res}) {
				my $value = $_->[1];
				$value .= $_->[3] ? " [TDWG".$_->[3]."]" : '';
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;				$value =~ s/"/\\"/g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; ';
			}
		}
		else { 
			$str = $res->[0][1]; 
		}
	}
	elsif ($table eq 'images') { 
		if ($id) { $where = "WHERE substring(url from \'[^/]+\$\') ILIKE '%$expr%' ORDER BY url"; }
		else { $where = "WHERE index = $expr"; }
		
		$req = "SELECT index, substring(url from \'[^/]+\$\') FROM images $where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'documents') { 
		if ($id) { $where = "WHERE reencodage(titre) ILIKE reencodage('%$expr%') ORDER BY titre"; }
		else { $where = "WHERE index = $expr"; }
		
		$req = "SELECT index, titre FROM documents $where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'vernaculars') {
		if ($id) { $where = "WHERE reencodage(nv.nom) ILIKE reencodage('%$expr%') ORDER BY nv.nom, nv.transliteration, l.langage, p.en, remarques"; }
		else { $where = "WHERE nv.index = $expr"; }

		$req = "SELECT nv.index, nv.nom || coalesce(' (' || nv.transliteration || ')','') || coalesce(' - ' || p.en,'') || coalesce(' (' || l.langage || ')','') 
			FROM noms_vernaculaires AS nv
			LEFT JOIN pays AS p ON p.index = nv.ref_pays
			LEFT JOIN langages AS l ON l.index = nv.ref_langage
			$where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'localities') {
		if ($id) { $where = "WHERE reencodage(l.nom) ILIKE reencodage('%$expr%') ORDER BY l.nom, p.en"; }
		else { $where = "WHERE l.index = $expr"; }

		$req = " SELECT l.index, l.nom || coalesce(' (' || p.en || ')','') 
			 FROM localites AS l 
			 LEFT JOIN pays AS p ON p.index = l.ref_pays 
			 $where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { 
			foreach (@{$res}) { 
				my $value = $_->[1];
				$value =~ s/&nbsp;/ /g;
				$value =~ s/  / /g;
				$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; '; 
			}
		}
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'deposits') {
		if ($id) { $where = "WHERE reencodage(nom) ILIKE reencodage('%$expr%') ORDER BY nom, en"; }
		else { $where = "WHERE l.index = $expr"; }

		$req = " SELECT l.index, nom || coalesce(' (' || en || ')','')
			 FROM lieux_depot AS l 
			 LEFT JOIN pays AS p ON p.index = l.ref_pays 
			 $where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	elsif ($table eq 'regions') { 
		if ($id) { $where = "WHERE reencodage(nom) ILIKE reencodage('%$expr%') ORDER BY nom, en"; }
		else { $where = "WHERE r.index = $expr"; }

		$req = " SELECT r.index, nom || coalesce(' (' || en || ')','') 
			 FROM regions AS r 
			 LEFT JOIN pays AS p ON p.index = r.ref_pays 
			 $where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	elsif ($cross eq 'associations') {
		if ($id) { $where = "WHERE reencodage((get_taxon_associe(x.index)).nom) ILIKE reencodage('%$expr%') ORDER BY (get_taxon_associe(x.index)).nom"; }
		else { $where = "WHERE x.index = $expr"; }

		$req = "SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') 
			FROM taxons_associes AS x 
			$where;";
		
		$res = request_tab($req, $dbc, 2);
		
		if ($id) { foreach (@{$res}) { $str .= $table.'["'.$_->[1].'"] = "'.$_->[0].'"; '; } }
		else { $str = $res->[0][1]; }
	}
	
	if ($id) { return($id.'_ARG_'.$table.'_ARG_'.$str.'_ARG_'.scalar(@{$res}).'_ARG_'.$expr); }
	else { return($str); }
}

sub getPubTitle { 
	my ($field, $index) = @_; 
	
	my $req = "SELECT coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '')
			FROM publications AS p 
			WHERE index = $index;";
			
	my ($value) = @{request_tab($req, $dbc, 1)};
	$value =~ s/"/\\"/g;	
	
	return($field.'_ARG_'.$value);
}

sub Xform {
	
	my ($req, $res, $preexist);
	my $crosslinks;
	my $explorer;
	my @hiddens;
	my $noid = scalar(@{$table_fields}) + scalar(@{$foreign_fields});
	#die scalar(@{$table_fields}).' + '.scalar(@{$foreign_fields}).' = '.$noid;
	#$test = join("\n", map { "$_ = ".param($_) } param());
	
	my $virgule;
	if (scalar(@{$foreign_fields})) { $virgule = ', '; }
	
	my $nameCond = !$new_elem ? "AND ref_nom = $nameid" : undef;
		
	$req = "SELECT tx." . join(', tx.', @{$table_fields}) . $virgule . join(', ', @{$foreign_fields}) . ", tx.oid " . " FROM $cross AS tx $foreign_joins WHERE $field1 = $xid $nameCond $order;";
			
	$preexist = request_tab($req, $dbc, 2);	
		
	push(@hiddens, ['xaction', $xaction]);
	push(@hiddens, ['elementX', $xlabel]);
	if (my $dup = param('duplicate')) {
		
		my $penult = $new_elem - 1;
		my $vide = 1;
		foreach (@{$table_definition}) {
			if (($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') and  param($_->{'ref'}.$penult)) { $vide = 0; last; }
			elsif (($_->{'type'} ne 'foreign' and $_->{'type'} ne 'pub') and param($_->{'id'}.$penult)) { $vide = 0; last; }
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
							if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { 
								my $value = getThesaurusItems(undef, $_->{'thesaurus'}, $row->[$i]);
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
					if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { param($_->{'ref'}.$new_elem, param($_->{'ref'}.$dup)); }
					param($_->{'id'}.$new_elem, param($_->{'id'}.$dup));
				}
			}
		}
		Delete("delete$new_elem");
		param("delete$new_elem", 'no');
		Delete('duplicate');
	}
	
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
					if ($field->{'type'} eq 'foreign') {
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ': ' . span({-style=>"color: $color;"},
								getThesaurusItems(undef, $field->{'thesaurus'}, $row->[$i]) ) . '') . ' ';
					}
					elsif ($field->{'type'} eq 'pub') {
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ': ' . span({-style=>"color: $color;"},
								publication($row->[$i], 0, 1, $dbc)." <sup>[$row->[$i]]</sup>" ) . '') . ' ';
					}
					elsif ($field->{'type'} eq 'select') {
						my $tmp;
						$tmp = span({-style=>"color: #444444;"}, $title) . ': ';
						if (exists $field->{'labels'}) {
							$tmp .= span({-style=>"color: $color;"}, $field->{'labels'}->{$row->[$i]}) . '';
						}
						else { 
							$tmp .= span({-style=>"color: $color;"}, $row->[$i]) . ''; 
						}
						$element .= span({-style=>'white-space:nowrap;'}, $tmp) . ' ';
					} 
					else {
						$element .= span({-style=>'white-space:nowrap;'}, span({-style=>"color: #444444;"}, $title) . ': ' . span({-style=>"color: $color;"}, $row->[$i]) . '') . ' ';
					}
				}
				$i++;
			}
			$element = td({-style=>'font-size: 14px;'}, $element);
			$element = td(img({	-onMouseover=>"this.style.cursor='pointer';", 
						-onClick=>"if($new_elem < 8) { document.crossForm.duplicate.value='p".$row->[$noid]."'; crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate'; crossForm.submit(); } else { alert('Please submit current data before adding any additional data'); }", 
						-src=>'/dbtntDocs/duplicate.png'})) . $element;

			$explorer .= Tr($element);
		}
		if (scalar(@{$preexist})) {
			$explorer = span({-style=>'color: black;'}, 'Existing item(s):') . p . table({-width=>'100%', -border=>'0px solid black;'}, $explorer);
		}
	}
	else {
		if (!$nb_elem) {		
			my $i = 1;
			foreach my $row (@{$preexist}) {
				my $j = 0;
				push(@hiddens, ["oid$i", pop(@{$row})]);
				foreach my $col (@{$row}) {
					if (($table_definition->[$j]{'type'} eq 'foreign' or $table_definition->[$j]{'type'} eq 'pub') and $col) { 
						param($table_definition->[$j]{'id'}.$i, getThesaurusItems(undef, $table_definition->[$j]{'thesaurus'}, $col));
					}
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
	my $hiddisplay;
	for (my $i=$iter; $i>0; $i--) {
		
		unless (param("delete$i") eq 'yes') {
			param("delete$i", 'no');
			my $dupfield;
			if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
				
				$dupfield = 	td(img({-style=>'margin-left: 5px;', 
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleI$i').innerHTML = 'Submit';", 
							-onMouseOut=>"document.getElementById('bulleI$i').innerHTML = '';",
							-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", 
							-border=>0, 
							-src=>'/dbtntDocs/submit.png', 
							-name=>'okbtn' })).
						td({-id=>"bulleI$i", -style=>'width: 100px; color: darkgreen;'}, '').
					   	td(img({-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleII$i').innerHTML = 'Duplicate';", 
							-onMouseOut=>"document.getElementById('bulleII$i').innerHTML = '';",
					   		-onClick=>"if($iter < 8) { document.crossForm.duplicate.value='$i'; crossForm.action='crosstable.pl?cross=$cross&xaction=duplicate'; crossForm.submit(); } else { alert('Please submit current data before adding any additional data'); }", 
					   		-src=>'/dbtntDocs/duplicate.png' })).
						td({-id=>"bulleII$i", -style=>'width: 100px; color: darkgreen;'}, '');
			}
			else {
				$dupfield = 	td(img({-style=>'margin-left: 5px;', 
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle$i').innerHTML = 'Submit';", 
							-onMouseOut=>"document.getElementById('bulle$i').innerHTML = '';",
							-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", 
							-border=>0, 
							-src=>'/dbtntDocs/submit.png', 
							-name=>'okbtn'})).
						td({-id=>"bulle$i", -style=>'width: 100px; color: darkgreen;'}, '');
			}
			my $linkhead;
			my $linkbody;
			my $linktail = $dupfield;
			my $clear_actions;
			$clear_actions .= "document.getElementById('tail$i').style.display = 'none';";
			$clear_actions .= "document.crossForm.delete$i.value = 'yes'; ";
			$clear_actions .= "document.getElementById('decompte').innerHTML = document.getElementById('decompte').innerHTML - 1;";
			foreach (@{$table_definition}) {
			
				my $id = $_->{'id'};
				my $ref = $_->{'ref'};
				my $thesaurus = $_->{'thesaurus'};
				my $default = lc($_->{'title'});
				my $display = $_->{'display'} || 'table-row';
				if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') {
					
					my $field;
					my $padding;
					if ($_->{'type'} eq 'foreign') {
						$field = textfield(
							-name=> "$id$i", 
							-id => "$id$i", 
							-style=>'width: 800px;', 
							-autocomplete=>'off',
							-value => param("$id$i") || "-- $default --", 
							-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('$ref$i').value = ''; this.value = '';",
							-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyDown(document.getElementById('$id$i').getAttribute('id'), event);
									}
									else { AutoComplete_HideDropdown(document.getElementById('$id$i').getAttribute('id')); }",
							-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyUp(document.getElementById('$id$i').getAttribute('id'), event);
									}
									else {
										function callServerScript() { 
											if(document.getElementById('$id$i').value.length > 2) { 
												getThesaurusItems(['args__$id$i', 'args__$thesaurus', 'args__'+encodeURIComponent(document.getElementById('$id$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
											} 
											else {  
												AutoComplete_HideDropdown(document.getElementById('$id$i').getAttribute('id')); 
											}
										}
										typewatch(callServerScript, 500);
									}",
							-onBlur =>  "if(!this.value || !document.getElementById('$ref$i').value) { this.value = '-- $default --'; document.getElementById('$ref$i').value = ''; }"
						);
						$field .= hidden(-name=>"$ref$i", -id=>"$ref$i");
						my $more;
						if ($_->{'addurl'}) {
							$more = a({-href=>$_->{'addurl'}, -target=>'_blank', -style=>'text-decoration: none;', -onClick=>"document.getElementById('bulleR').innerHTML = 'Reload'; document.getElementById('bulleR').style.textDecoration = 'blink';"}, 
									img({-border=>0, -src=>'/dbtntDocs/more.png'}));
						}					
						$field = Tr(td($field), td({-style=>'padding-left: 6px;'}, $more));
						$padding = '10px 0';	
					}
					else {	
						$field = textfield(
							-name=> "$ref$i", 
							-id => "$ref$i", 
							-style=>'width: 75px;', 
							-autocomplete=>'off',
							-default => param("$ref$i") || '-- index --', 
							-onFocus => "	AutoComplete_HideAll(); Reset_TabIndex(); this.value = ''; document.getElementById('$id$i').value = ''; document.getElementById('$id$i').tabIndex='-1';",
							-onKeyUp => "	if(event.keyCode != 9 && event.keyCode != 13 && event.keyCode != 27 && event.keyCode != 38 && event.keyCode != 40) {
										function callServerScript() { 
											getPubTitle(['args__$id$i', 'args__'+document.getElementById('$ref$i').value], [setPublicationTitle]); 
											document.getElementById('$ref$i').blur(); 
										} 
										typewatch(callServerScript, 1000);
									}",
							-onBlur =>  "if(!this.value) { this.value = '-- index --'; document.getElementById('$id$i').value = '-- $default --'; }
									else { getPubTitle(['args__$id$i', 'args__'+document.getElementById('$ref$i').value], [setPublicationTitle]); }"
						);
						$field .= textfield(
							-name=> "$id$i", 
							-id => "$id$i", 
							-style=>'width: 725px;', 
							-autocomplete=>'off',
							-value => param("$id$i") || "-- title --", 
							-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('$ref$i').value = ''; this.value = '';",
							-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyDown(document.getElementById('$id$i').getAttribute('id'), event);
									}
									else { AutoComplete_HideDropdown(document.getElementById('$id$i').getAttribute('id')); }",
							-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyUp(document.getElementById('$id$i').getAttribute('id'), event);
									}
									else {
										function callServerScript() { 
											if(document.getElementById('$id$i').value.length > 2) { 
												getThesaurusItems(['args__$id$i', 'args__$thesaurus', 'args__'+encodeURIComponent(document.getElementById('$id$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
											} 
											else {  
												AutoComplete_HideDropdown(document.getElementById('$id$i').getAttribute('id')); 
											}
										}
										typewatch(callServerScript, 500);
									}",
							-onBlur =>  "if(!this.value || !document.getElementById('$ref$i').value) { this.value = '-- title --'; document.getElementById('$ref$i').value = '-- index --'; }"
						);
						my $more;
						if ($_->{'addurl'}) {
							$more = a({-href=>$_->{'addurl'}, -target=>'_blank', -style=>'text-decoration: none;', -onClick=>"document.getElementById('bulleR').innerHTML = 'Reload'; document.getElementById('bulleR').style.textDecoration = 'blink';"}, img({-border=>0, -src=>'/dbtntDocs/more.png'}));
						}
						$field = Tr(td({-colspan=>2, -style=>'font-size: 15px; color: navy;'}, $default)) . Tr(td($field), td({-style=>'padding-left: 6px;'}, $more));
						
						$padding = '0';
					}
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, 
							td({-colspan=>2, -style=>"padding: $padding;"}, 
								table({-cellspacing=>0, -cellpadding=>0, -border=>0}, $field)));
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "document.crossForm.$ref$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
					
					$hiddisplay .= "if (document.getElementById('$ref$i').value && document.getElementById('$ref$i').value != '') { str += '$ref$i = '+ document.getElementById('$ref$i').value + '\\n'; } ";
				}
				elsif ($_->{'type'} eq 'select') {
										
					$default = param("$id$i") || $_->{'default'};
					my $more;
					if ($_->{'addurl'}) {
						$more = td( a({-href=>$_->{'addurl'}, -target=>'_blank', -style=>'text-decoration: none;', -onClick=>"document.getElementById('bulleR').innerHTML = 'Reload'; document.getElementById('bulleR').style.textDecoration = 'blink';"}, img({-border=>0, -src=>'/dbtntDocs/more.png'})) );
					}
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, 
							td({-colspan=>3, -style=>"padding: 0 0 10px 0;"}, 
								table({-cellspacing=>0, -cellpadding=>0}, 
									Tr(
										td({-style=>'padding-right: 6px;'}, 
											popup_menu(	-class=>'phantomTextField0', 
													-style=>"padding: 0; width: 200px;", 
													-name=>"$id$i", 
													-default=>$default, 
													-onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();', 
													-values=>$_->{'values'}, 
													-labels=>$_->{'labels'}
											)
										). $more
									)
								)
							)
						);
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
				}
				elsif ($_->{'type'} eq 'internal') {
					
					my $textZone;
					my $l = $_->{'length'} || 70;
					$default = param("$id$i") || $_->{'default'} || "-- ".lc($_->{'title'})." --";
					if ($_->{'style'} and $_->{'style'} eq 'area') {
						$textZone = textarea(	-class=>'phantomTextField0', 
										-name=>"$id$i", 
										-value=>$default,
										-rows=>5,
										-columns=>$l,
										-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- ".lc($_->{'title'})." --') { this.value = ''; }",
										-onBlur => "if(!this.value) { this.value = '-- ".lc($_->{'title'})." --'; }"
							);
					} else {
						$textZone = textfield(	-class=>'phantomTextField0', 
										-name=>"$id$i", 
										-value=>$default, 
										-size=>$l,
										-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- ".lc($_->{'title'})." --') { this.value = ''; }",
										-onBlur => "if(!this.value) { this.value = '-- ".lc($_->{'title'})." --'; }"
							);
					}
					$linkbody .= Tr({-id=>"row_$id$i", -style=>"display: $display;"}, 
							td({-colspan=>2, -style=>'padding-bottom: 10px;'}, 
								$textZone
							)
						     );
					
					$clear_actions .= "document.crossForm.$id$i.value = ''; ";
					$clear_actions .= "document.getElementById('row_$id$i').style.display = 'none';";
				}
				$clear_actions .= "document.getElementById('fieldset$i').style.display = 'none';";
				Delete("$id$i");
			}
						
			$linktail .= 	td(img({-id=>"clear$i", 
						-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleIII$i').innerHTML = 'Delete';", 
						-onMouseOut=>"document.getElementById('bulleIII$i').innerHTML = '';",
						-onClick=>"if(confirm('Remove from the database?')) { $clear_actions recadre(); } else { return false; };", 
						-border=>0, 
						-src=>'/dbtntDocs/delete.png', -name=>"clearbtn" })).
					td({-id=>"bulleIII$i", -style=>'width: 100px; color: darkgreen;'}, '');

			$crosslinks .= Tr(td(	"<FIELDSET class='wcenter round fieldset1' style='margin-bottom: 10px;' ID='fieldset$i'>".
						"<LEGEND class='round'>Item $i</legend>".
						table({-border=>0}, $linkbody . Tr({-id=>"tail$i"}, td( table(Tr($linktail)) ))).
						"</FIELDSET>"
					));
		}
		else { $reste--; }
	}

	my $ninja ="<DIV class='wcenter' ID='ninja' onClick=\"var str = ''; $hiddisplay  alert(str);\" style='margin-bottom: 10px;'>< Hiddens revelations ></DIV>";
		
	my $addrelation;
	if ($xaction eq 'fill' or $xaction eq 'more' or $xaction eq 'duplicate') {
		$addrelation = 	td({-style=>'padding-left: 20px;'},
					img({
						-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleAdd').innerHTML = 'Add an item';", 
						-onMouseOut=>"document.getElementById('bulleAdd').innerHTML = '';",
						-onClick=>"if($iter < 8) { crossForm.action='crosstable.pl?cross=$cross&xaction=more'; crossForm.submit(); } else { alert('Please submit current data before adding any additional data'); }", 
						-src=>'/dbtntDocs/plus.png' })
				).
				td({-id=>"bulleAdd", -style=>'width: 100px; color: darkgreen;'}, '');
	}
	
	my $xhiddens;
	foreach (@hiddens) {
		Delete($_->[0]);
		$xhiddens .= hidden(-id=>$_->[0], -name=>$_->[0], -value=>$_->[1]);
	}
	$xhiddens .= hidden('taxonid', $taxonid);
	$xhiddens .= hidden('nameid', $nameid);
	$xhiddens .= hidden(-name=>'duplicate');
		
	my $str = span({-style=>'font-weight: bold;'}, span({-id=>'decompte'}, $reste)." item(s)");
	#if ($iter > 1) { $str .= " items" }
	#else { $str .= " item" }
	
	my $last;	
	if ($reste) { 
		$last = td({-colspan=>3, -style=>'padding-left: 20px;'}, 
				img({	-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleO').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleO').innerHTML = '';",
					-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=verify'; crossForm.submit();", 
					-border=>0, 
					-src=>'/dbtntDocs/submit.png', -name=>'okbtn'})
			).
			td({-id=>"bulleO", -style=>'width: 100px; color: darkgreen;'}, '');
	}
	my $reload = 	td({-colspan=>3, -style=>'padding-left: 20px;'}, 
				img({	-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleR').innerHTML = 'Reload';", 
					-onMouseOut=>"document.getElementById('bulleR').innerHTML = '';",
					-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$xaction'; crossForm.submit();", 
					-border=>0, 
					-src=>'/dbtntDocs/reload.png', -name=>'reload'})
			).
			td({-id=>"bulleR", -style=>'width: 100px; color: darkgreen;'}, '');
	
	my $html =		
	"<HTML>".
	"<HEAD>".
	"\n	<TITLE>$title</TITLE>".
	"\n	<STYLE TYPE='text/css'>$css</style>".
	"\n	<SCRIPT TYPE='text/javascript' SRC='/dbtntDocs/SearchMultiValue.js'></SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>
			function setPublicationTitle() {
				var arr = arguments[0].split('_ARG_');
				if (arr[1]) {
					document.getElementById(arr[0]).value = arr[1];
				}
				else {
					document.getElementById('ref_'+arr[0]).value = '-- index --';
					document.getElementById(arr[0]).value = '-- title --';
				}
			}
		</SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>$jscript</SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>$jscript_for_hidden</SCRIPT>\n".
	"</HEAD>".
	"<BODY>".
	$maintitle.
	"<DIV CLASS='wcenter'>". p.
	table(	Tr(	td(ucfirst("$title of "), span({-style=>'font-weight: normal;'}, $name)), 
			td({-style=>'padding-left: 20px;'}, 
				a({-href=>"crosstable.pl?cross=$cross&xaction=$xaction"}, 
					img({	
						-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleB').innerHTML = 'Back';", 
						-onMouseOut=>"document.getElementById('bulleB').innerHTML = '';",
						-border=>0, 
						-src=>'/dbtntDocs/back.png', 
						-name=>"backbtn"}
					)
				)
			),
			td({-id=>"bulleB", -style=>'width: 100px; color: darkgreen;'}, '')
		)
	).
	start_form(-name=>'crossForm', -method=>'post',-action=>'').
	table({-style=>'margin-bottom: 8px;'},
		Tr(	td({-style=>'padding-left: 5px;'}, $str),
			$addrelation,
			$last,
			$reload
		)
	).
	$crosslinks. p.			
	$explorer.
	$xhiddens.
	$test.
	arg_persist().
	end_form().
	"</DIV>".
	"</BODY>".
	"</HTML>";
	
	print 	$pjx->build_html($cgi, $html, {-charset=>'UTF-8'});
}

sub Xexecute {
	
	my %headerHash = (
		titre => $title,
		css => $css
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
						
			if ($table1 eq 'taxons') {				
				my $name = param('nameid');
				push(@fields, 'ref_nom');
				push(@values, $name);
			}
			
			my @nullfields = ();
			my @nulls = ();
			foreach (@{$table_definition}) {
				if (param($_->{'id'}.$i)) {
					my ($f, $v);
					if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') {
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
					if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { $f = $_->{'ref'}; }
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
	
	my $fullid = $table1 eq 'taxons' ? param('taxonid').'%23'.param('nameid') : param('nameid');
	foreach (param()) { Delete($_); }

	my $links;
	my $otherLinks;			
	my $xaction = param('xaction');
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		if($table =~ /$table1/) {
			$links .= Tr(
					td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$fullid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>url()."?cross=$table&xaction=modify&xid=$fullid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
			$otherLinks .= Tr(
					td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
		}
		else {
			if ($table1 eq 'taxons') {
				$links .= Tr(
						td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$nameid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify&xid=$nameid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
				$otherLinks .= Tr(
						td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
			}
			elsif  ($table1 eq 'noms') {
				
				if ($taxonid) {
					$links .= Tr(
							td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
							td(	a({-href=>url()."?cross=$table&xaction=fill&xid=$taxonid%23$nameid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
								'&nbsp; / &nbsp;' . 
								a({-href=>url()."?cross=$table&xaction=modify&xid=$taxonid%23$nameid&elementX=$xlabel", -style=>'text-decoration: none; color: navy;'}, 'Update')
							)
						);
				}
				
				$otherLinks .= Tr(
						td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
						td(	a({-href=>url()."?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
							'&nbsp; / &nbsp;' . 
							a({-href=>url()."?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
						)
					);
			}
		}
	}
	
	my $links = div({-style=>'padding: 0 0 10px 0;'}, "Treat $name:") . table($links);
	my $otherLinks = div({-style=>'padding: 16px 0 10px 0;'}, 'Treat another taxon:') . table($otherLinks);			
	
	my $thirdlinks .= table(
				Tr(
					td({-style=>'padding: 10px 20px 10px 0;'}, "Treat another data:"),
					td(	a({-href=>"dbtnt.pl?action=insert&type=all", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"dbtnt.pl?action=update&type=all", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				)
			);
		
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		$maintitle,
		
		div({-class=>"wcenter"},
									
			img{-src=>'/dbtntDocs/done.png'}, p,
			
			table( Tr(
				td({-style=>'padding-right: 20px;'}, span({-style=>'color: green'}, "Modifications done") ),
				#td( img({-onMouseover=>"this.style.cursor='pointer';", -onClick=>"Form.action = 'crosstable.pl?cross=$cross&xaction=modify&xid=$xid'; Form.submit();", -border=>0, -src=>'/dbtntDocs/modify.png', -name=>"backbtn"}))
			) ), p,
			
			#join(', ', @msg),
			
			start_form(-name=>'Form', -method=>'post',-action=>''),
			
			arg_persist(),
						
			end_form(), 
			
			table({-border=>0},
				$links,
				$otherLinks
			),
			$thirdlinks
		), p,
	
		html_footer();
}


sub Xrecap {
	
	my %headerHash = ( titre => $title, css => $css );
		
	my $crosslinks;
	my %doublons;
			
	my $test;
	
	my $iter = param('new_elem') || param('nb_elem');
	#$test = join("<br>", map { "$_ = ".param($_) } param()) . "<br> iter = $iter";
	my $valid = 0;
	my $unvalid = 0;
	for (my $i=$iter; $i>0; $i--) {	
		my $msg;
		foreach (@{$obligatory}) {
			#$test .= "<br> param(".$_.$i.") = ".param($_.$i);
			unless (param($_.$i)) { $msg = "Uncomplete item ignored"; } 
		}
		unless ($msg) {
			my $rows;
			my $key;
			my @conditions = ("$field1 = ?");
			my @valeurs = ($xid);
			foreach (@{$table_definition}) {
				
				if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') {
					if (my $ref = param($_->{'ref'}.$i)) {
						push(@conditions, $_->{'ref'}.' = ?');
						push(@valeurs, $ref);
					}
					else { 
						push(@conditions, $_->{'ref'}.' IS NULL'); 
					}
				}
				
				if (param($_->{'id'}.$i)) {
					my $title = $_->{'title'};
					$title =~ s/ /&nbsp;/g;
					if ($_->{'type'} eq 'select') {
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
					
					if ($_->{'type'} ne 'foreign' and $_->{'type'} ne 'pub') {
						push(@conditions, "$_->{'id'} = ?");
						push(@valeurs, param($_->{'id'}.$i));
					}
				}
				else { 
					if ($_->{'type'} ne 'foreign' and $_->{'type'} ne 'pub') {
						push(@conditions, "$_->{'id'} IS NULL");
					}
				}
			}
						
			my $double = 0;
			my $request = "SELECT count(*) FROM $cross WHERE ".join(' AND ', @conditions).";";
						
			if ( my $sth = $dbc->prepare($request) ){
				if ( $sth->execute(@valeurs) ){
					($double) = $sth->fetchrow_array;
					$sth->finish();
				} else { die( "Execute error $i: $request with @valeurs ".scalar(@valeurs).$dbc->errstr ); }
			} else { die( "Prepare error $i: $request with @valeurs ".scalar(@valeurs).$dbc->errstr ); }
						
			if ($double) { $doublons{$key} = 1; }
			
			#$crosslinks .= Tr( td({-colspan=>2}, "$request with @valeurs => $double") );
						
			unless(exists $doublons{$key}) {
				$doublons{$key} = 1;
				my $sentence;
				$sentence = img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: darkgreen'}, " Valid item");
				$crosslinks .= "<FIELDSET class='wcenter round fieldset1' style='margin-bottom: 10px;'>".
						"<LEGEND class='round'>$sentence</legend>".
						table({-style=>'margin-top: 4px;', -cellspacing=>'4px', -border=>0}, $rows).
						table({-style=>'margin-top: 4px;'}, Tr(
							td( img({
								-style=>'padding: 0 0 0 6px;', 
								-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle$i').innerHTML = 'Submit';", 
								-onMouseOut=>"document.getElementById('bulle$i').innerHTML = '';",
								-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", 
								-border=>0, 
								-src=>'/dbtntDocs/submit.png', 
								-name=>'okbtn'})
							),
							td({-id=>"bulle$i", -style=>'width: 100px; color: darkgreen;'}, '') 
						) ).
						"</FIELDSET>";
				$valid ++;
			}
			else {
				my $sentence;
				if($reaction eq 'insert') {
					foreach (@{$table_definition}) {
						if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { Delete($_->{'ref'}.$i); }
						Delete($_->{'id'}.$i);
					}
					$sentence = img({-border=>0, -src=>'/dbtntDocs/stop.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, " Duplicated item ignored");
				}
				elsif ($reaction eq 'update') {
					$sentence = img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"hep" , -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: darkgreen'}, " Unchanged Item");
				}
				my $body;
				if (1 || $rows) { 
					$body = table({-style=>'margin-top: 4px;', -cellspacing=>'4px', -border=>0}, $rows).
						table({-style=>'margin-top: 4px;'}, Tr(
							td( img({
								-style=>'padding: 0 0 0 6px;', 
								-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle$i').innerHTML = 'Submit';", 
								-onMouseOut=>"document.getElementById('bulle$i').innerHTML = '';",
								-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", 
								-border=>0, 
								-src=>'/dbtntDocs/submit.png', 
								-name=>'okbtn'})
							),
							td({-id=>"bulle$i", -style=>'width: 100px; color: darkgreen;'}, '') 
						) );
				}
				$crosslinks .= "<FIELDSET class='wcenter round fieldset1' style='margin-bottom: 10px;'>".
						"<LEGEND class='round'>$sentence</legend>".
						$body.
						"</FIELDSET>";
				$unvalid ++;
			}
		}
		else {	
			my $sentence;
			foreach (@{$table_definition}) {
				if ($_->{'type'} eq 'foreign' or $_->{'type'} eq 'pub') { Delete($_->{'ref'}.$i); }
				Delete($_->{'id'}.$i);
			}
			if($reaction eq 'insert') {
				$sentence = img({-border=>0, -src=>'/dbtntDocs/stop.png', -name=>"hep", -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, " $msg");
			}
			elsif ($reaction eq 'update') {
				$sentence = img({-border=>0, -src=>'/dbtntDocs/caution.png', -name=>"hep", -alt=>"CAUTION", -style=>'margin-bottom: -5px; width: 20px;'}) . span({-style=>'color: crimson'}, "1 item to be deleted");
			}

			$crosslinks .= "<FIELDSET class='wcenter round fieldset1' style='margin-bottom: 10px;'>".
						"<LEGEND class='round'>$sentence</legend>".
						#table({-style=>'margin-top: 4px;'}, Tr(
						#	td( img({
						#		-style=>'padding: 0 0 0 9px;', 
						#		-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulle$i').innerHTML = 'Submit';", 
						#		-onMouseOut=>"document.getElementById('bulle$i').innerHTML = '';",
						#		-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", 
						#		-border=>0, 
						#		-src=>'/dbtntDocs/submit.png', 
						#		-name=>'okbtn'})
						#	),
						#	td({-id=>"bulle$i", -style=>'width: 100px; color: darkgreen;'}, '') 
						#) ).
					"</FIELDSET>";
		}
	}
		
	my $subtitle;
	if($reaction eq 'insert') { 
		$subtitle = div({-style=>'padding: 8px 0 8px 15px; font-weight: bold;'}, "$valid valid item(s)");
	}
	
	my $last;
	if($reaction eq 'update' and !$valid and !$unvalid) {
		$last = table({-style=>'margin-top: 4px;'}, Tr(
				td( img({
					-style=>'padding: 0 0 0 9px;', 
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleL').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleL').innerHTML = '';",
					-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$reaction'; crossForm.submit();", 
					-border=>0, 
					-src=>'/dbtntDocs/submit.png', 
					-name=>'okbtn'})
				),
				td({-id=>"bulleL", -style=>'width: 100px; color: darkgreen;'}, '') 
			) );
	}
	
	print 	html_header(\%headerHash),
		
		$test,		
		$maintitle,
		
		div({-class=>"wcenter"},
					
			table(	Tr(	td("$title of ", span({-style=>'font-weight: normal;'}, $name)), 
					td({-style=>'padding-left: 20px;'}, 
						img({	
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleB').innerHTML = 'Back';", 
							-onMouseOut=>"document.getElementById('bulleB').innerHTML = '';",
							-onClick=>"crossForm.action = 'crosstable.pl?cross=$cross&xaction=$xaction'; crossForm.submit();", 
							-border=>0, 
							-src=>'/dbtntDocs/back.png', 
							-name=>"backbtn"}
						)
					),
					td({-id=>"bulleB", -style=>'width: 100px; color: darkgreen;'}, '')
				)
			),
						
			start_form(-name=>'crossForm', -method=>'post',-action=>''),
						
			$subtitle, p,

			$crosslinks, p,
			
			$last,
						
			arg_persist(),
			
			end_form(),
		), p,
			
		html_footer();
}

sub get_first_table() {

	my ($table) = @_;
	my $reaction = url_param('xaction') || param('xaction') || 'fill';
	my $default;
	if ($table eq 'taxons') { $default = 'taxon'; } elsif ($table eq 'noms') { $default = 'scientific name'; }
		
	my $xfield = textfield(
		-name=> 'elementX', 
		-id => 'elementX', 
		-style=>'width: 770px;', 
		-autocomplete=>'off',
		-value => param('elementX') || "-- $default --", 
		-onFocus => "document.selectForm.xid.value = ''; this.value = '';",
		-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyDown(document.getElementById('elementX').getAttribute('id'), event);
				}
				else { AutoComplete_HideDropdown(document.getElementById('elementX').getAttribute('id')); }",
		-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyUp(document.getElementById('elementX').getAttribute('id'), event);
				}
				else {
					function callServerScript() { 
						if(document.getElementById('elementX').value.length > 2) { 
							getThesaurusItems(['args__elementX', 'args__$table', 'args__'+encodeURIComponent(document.getElementById('elementX').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
						} 
						else {  
							AutoComplete_HideDropdown(document.getElementById('elementX').getAttribute('id')); 
						}
					}
					typewatch(callServerScript, 500);
				}",
		-onBlur =>  "if(!this.value || !document.selectForm.xid.value) { this.value = '-- $default --'; document.selectForm.xid.value = ''; }"
	)."\n";
		
	my $xhiddens = hidden(-name=>'xid', -id=>'xid');
		
	my $xsubmit = 	table({-cellspacing=>0, -border=>0}, Tr(
				td(img({-src=>'/dbtntDocs/submit.png', 
					-name=>'next',
					-border=>0,
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleSubmit').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleSubmit').innerHTML = '';",
					-onClick=>"if (document.selectForm.xid.value) { document.selectForm.submit(); } else { alert('Select a $default'); }" })).
				td({-id=>"bulleSubmit", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '')
			));
	
	my $html .=		
	"<HTML>".
	"<HEAD>".
	"\n	<TITLE>".ucfirst($default)." selection</TITLE>".
	"\n	<STYLE TYPE='text/css'>$css</style>".
	"\n	<SCRIPT TYPE='text/javascript' SRC='/dbtntDocs/SearchMultiValue.js'></SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>$jscript</SCRIPT>".
	"</HEAD>".
	"<BODY>".
	$maintitle.
	"<DIV CLASS='wcenter'>".
	div({style=>"margin-bottom: 4%; font-size: 18px; font-style: italic;"}, "Select a $default").
	start_form(-name=>'selectForm', -method=>'post', -action=>url()."?cross=$cross&xaction=$reaction").
	$xfield.
	$xhiddens.
	p. br.
	$xsubmit.
	end_form().
	#join(br, map { "$_ = ".param($_)."<BR>" } param()).
	"</DIV>".
	"</BODY>".
	"</HTML>";
	
	print 	$pjx->build_html($cgi, $html, {-charset=>'UTF-8'});
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
