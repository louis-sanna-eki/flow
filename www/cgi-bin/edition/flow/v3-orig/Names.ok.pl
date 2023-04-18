#!/usr/bin/perl

use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use CGI::Ajax;
use DBCommands qw(get_connection_params db_connection request_tab request_row);
use Conf qw($conf_file $css $js request_tab_with_values html_header html_footer $cross_tables $maintitle %statuts);
use utf8;

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EDITOR');
my $user = remote_user();

my $action = url_param('action') || 'insert';
my $action0 = param('action0') || $action;
unless (param('action0')) { param('action0', $action0); }
unless (param('nameOrder')) { param('nameOrder', url_param('nameOrder')); }

my ($genusOrder) = @{request_tab("SELECT ordre FROM rangs WHERE en = 'genus';", $dbc, 1)};
my ($speciesOrder) = @{request_tab("SELECT ordre FROM rangs WHERE en = 'species';", $dbc, 1)};

# fast access
my $jscript;
$jscript = "function setThesaurusItems() { 
		var arr = arguments[0].split('_ARG_');
		var idx = arr[0]; 
		var tbl = arr[1]; 
		var str = arr[2]; 
		var nb = arr[3]; 
		var expr = arr[4]; 
		var test = expr.search('--');
//if (nb == 0 && test == -1) { alert('No data matches \"'+expr+'\"');
		eval(str);
		if (location.search.search('test=1') != -1) {  }
		if(__AutoComplete[idx]) { AutoComplete_HideDropdown(idx); }
		if (tbl == 'taxons') {
			if (idx == 'taxon') {
				AutoComplete_Create(idx, tbl, 'taxonID_COL_targetID_COL__COL_', 'nameForm', 670, 'true');
			}
			else if (idx == 'newtaxon') {
				AutoComplete_Create(idx, tbl, 'newtaxonID_COL_newtargetID_COL__COL_', 'nameForm', 670, 'true');
			}
			else if  (idx == 'sciname') {
				AutoComplete_Create(idx, tbl, '_COL_nameID_COL_', 'nameForm', 670, 'true');
			}
			else if  (idx == 'parent') {
				AutoComplete_Create(idx, tbl, 'parentTaxonID_COL_parentNameID_COL_parentName_COL_parentOrder', 'nameForm', 770, 'valeurs[2] < ".param('nameOrder')."');
			}
		}
		else if (tbl == 'oids') {
			AutoComplete_Create(idx, tbl, 'OID0', 'selectForm', 770, 'valeurs[2] = ".param('nameOrder')."');
		}
		else if (tbl == 'authors') {
			if (idx.search(/^AFN[0-9]+/) != -1) {
				var t = idx.split('AFN');
				var n = t[1];
				AutoComplete_Create(idx, tbl, 'ref_author'+n+'_COL_AFN'+n+'_COL_ALN'+n, 'nameForm', 410, 'true');
			}
			else if (idx.search(/p[1-4]AFN[0-9]+/) != -1) {
				var t = idx.split('p');
				var u = t[1].split('AFN');
				var n = u[0];
				var m = u[1];
				AutoComplete_Create(idx, tbl, 'p'+n+'ref_author'+m+'_COL_p'+n+'AFN'+m+'_COL_p'+n+'ALN'+m, 'nameForm', 410, 'true');
			}
		}
		else if (tbl == 'publications') {
			AutoComplete_Create(idx, tbl, 'ref_'+idx, 'nameForm', 725, 'true');
		}
		else if (tbl == 'journals') {
			var t = idx.split('journal');
			var n = t[1];
			AutoComplete_Create(idx, tbl, 'journalID'+n, 'nameForm', 800, 'true');
		}
		else if  (tbl == 'labels') {
			AutoComplete_Create(idx, tbl, idx, 'nameForm', 200, 'true');
		}
		else if (tbl == 'editions') {
			var t = idx.split('edition');
			var n = t[1];
			AutoComplete_Create(idx, tbl, 'editionID'+n+'_COL_cityID'+n+'_COL_stateID'+n+'_COL_city'+n+'_COL_state'+n, 'nameForm', 800, 'true');
		}
		else if (tbl == 'cities') {
			var t = idx.split('city');
			var n = t[1];
			AutoComplete_Create(idx, tbl, 'cityID'+n+'_COL_stateID'+n+'_COL_state'+n, 'nameForm', 400, 'true');
		}
		else if (tbl == 'states') {
			var t = idx.split('state');
			var n = t[1];
			AutoComplete_Create(idx, tbl, 'stateID'+n, 'nameForm', 400, 'true');
		}
		else {
			document.getElementById('Tampon').innerHTML = 'ERROR ID='+idx;
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

if (url_param('homonymy')) { 
	param('homonymy', url_param('homonymy'));
	param('action0', url_param('action0'));
	param('statusID', url_param('statusID'));
	param('nameID', url_param('nameID'));
	param('ref_pub4', url_param('ref_pub4'));
	param('page4', url_param('page4'));
	my $nameID = param('nameID');
	my $taxonID = param('homonymy');
	my $pubID = param('ref_pub4');
	my $req = "SELECT CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '')
			ELSE
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '') 
				|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '')
			END
		FROM taxons_x_noms AS txn 
		LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
		LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
		LEFT JOIN noms AS n ON n.index = nc.index
		LEFT JOIN noms AS n2 ON n2.index = nt.index
		WHERE txn.ref_nom = $nameID
		AND txn.ref_nom = $taxonID
		AND txn.ref_statut = 11;"; 
	my ($label) = @{request_tab($req, $dbc, 1)};
	param('sciname', $label);
	if (param('ref_pub4')) {
		my $req = "SELECT coalesce(get_ref_authors(p.index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')
			FROM publications AS p 
			WHERE p.index = $pubID;";
		my ($publabel) = @{request_tab($req, $dbc, 1)};
		param('pub4', $publabel);
	}
}

foreach (param()) {
	if ( !param($_) or param($_) =~ m/^-- / ) { Delete($_); }
}

if ($action eq 'insert') {
	name_form();
}
elsif ($action eq 'authorMore') {
	if (url_param('target') eq 'name') {
		my $nb = param('authors');
		Delete('authors');
		$nb++;
		param('authors', $nb);
	}
	elsif (url_param('target') eq 'pub') {
		my $index = url_param('n');
		my $nb = param("p".$index."Authors");
		Delete("p".$index."Authors");
		$nb++;
		param("p".$index."Authors", $nb);
	}
	name_form();
}
elsif ($action eq 'authorLess') {
	if (url_param('target') eq 'name') {
		my $nb = param('authors');
		Delete('authors');
		Delete("AFN$nb");
		Delete("ALN$nb");
		Delete("ref_author$nb");
		$nb--;
		$nb = $nb < 0 ? 1 : $nb;
		param('authors', $nb);
	}
	elsif (url_param('target') eq 'pub') {
		my $index = url_param('n');
		my $nb = param("p".$index."Authors");
		Delete("p".$index."Authors");
		Delete("p".$index."AFN$nb");
		Delete("p".$index."ALN$nb");
		Delete("p".$index."ref_author$nb");
		$nb--;
		$nb = $nb < 0 ? 1 : $nb;
		param("p".$index."Authors", $nb);
	}
	name_form();
}
elsif ($action eq 'preFill') {
	my $nord = param('nameOrder');
	my $tid = param('taxonID');
	my $nid = param('targetID');
	my $sid = param('statusID');
	my $req;
	#if ($nord <= $genusOrder) {
	#	$req = "SELECT t.ref_taxon_parent, txn.ref_nom, r.ordre, n.orthographe, n.annee, n.parentheses, n.fossil, nc.orthographe || coalesce(' ' || nc.autorite, '')
	#		FROM taxons AS t
	#		LEFT JOIN noms AS n ON n.index = $nid
	#		LEFT JOIN noms_complets AS nc ON nc.index = n.ref_nom_parent
	#		LEFT JOIN taxons AS tp ON tp.index = t.ref_taxon_parent
	#		LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = t.ref_taxon_parent
	#		LEFT JOIN rangs AS r ON r.index = tp.ref_rang
	#		WHERE t.index = $tid
	#		AND txn.ref_statut = 1;";
	#}
	#else {
		$req = "SELECT t.ref_taxon_parent, n.ref_nom_parent, r.ordre, n.orthographe, n.annee, n.parentheses, n.fossil, nc.orthographe || coalesce(' ' || nc.autorite, '')
			FROM taxons AS t
			LEFT JOIN noms AS n ON n.index = $nid
			LEFT JOIN noms_complets AS nc ON nc.index = n.ref_nom_parent
			LEFT JOIN taxons AS tp ON tp.index = t.ref_taxon_parent
			LEFT JOIN rangs AS r ON r.index = tp.ref_rang
			WHERE t.index = $tid;";
	#}
	
	my $values = request_row($req, $dbc);
	
	if ($sid != 4 and $sid != 23 and $values->[0]) {
		param('parentTaxonID', $values->[0]);
		param('parentNameID', $values->[1]);
		param('parentName', $values->[3]);
		param('parentOrder', $values->[2]);
		param('parent', $values->[7]);
	}
	
	if ($sid != 3 and $sid != 12 and $sid != 15) { param('spelling', $values->[3]); }
	else { param('spelling', $values->[3].'?'); }
	
	if ($sid != 10) { param('year', $values->[4]); }
	if ($sid != 4 and $sid != 10) { param('brackets', $values->[5]); }
	
	param('fossil', $values->[6]);
	
	if ($sid != 10) { 
		$req = "SELECT a.index, a.nom, a.prenom FROM noms_x_auteurs AS nxa LEFT JOIN auteurs AS a ON a.index = nxa.ref_auteur WHERE nxa.ref_nom = $nid ORDER BY nxa.position;";
		$values = request_tab($req, $dbc, 2);
		param('authors', scalar(@{$values}));		
		my $iter = 1;
		foreach (@{$values}) {
			param("ref_author$iter", $_->[0]);
			param("AFN$iter", $_->[1]);
			if ($_->[2]) { param("ALN$iter", $_->[2]); }
			$iter++;
		}
	}
	
	name_form();
}
elsif ($action eq 'execute') {
	#die join("\n", map { "$_ = ".param($_) } param());
	treat_data();
}
elsif ($action eq 'get') {
	get_name();
}
elsif ($action eq 'destroy') {
	my $OID0 = url_param('OID0');
	my $order = url_param('order');
	my ($rankName)	= @{ request_tab("SELECT en FROM rangs WHERE ordre = $order",$dbc,1) };
	my ($title, $icon, $msg);
	my ($exists) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE oid = $OID0;", $dbc, 1)};
	if ($exists) {
		updateCrossTables($OID0, undef);
		# name to delete
		my $req = "SELECT ref_taxon, ref_nom, ref_statut FROM taxons_x_noms WHERE oid = $OID0;";
		my $res = request_tab($req, $dbc, 2);
		my ($t1,$n1,$s1) = ($res->[0][0], $res->[0][1], $res->[0][2]);							
		if ($s1==1) {
			my $names = request_tab("SELECT oid FROM taxons_x_noms WHERE ref_taxon = $t1 AND ref_nom != $n1 AND ref_statut NOT IN (3,5,8,10,17,18,20,21,22);", $dbc, 2);
			foreach (@{$names}) { updateCrossTables($_->[0], undef); }
			
			$req = "DELETE FROM taxons_x_noms WHERE ref_taxon = $t1; ";		
			foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
				if($table =~ /taxons/) { $req .= "DELETE FROM $table WHERE ref_taxon = $t1; "; }
			}
			if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
		}
		elsif (is_taxonomic_status($s1)) {
			$req = "DELETE FROM taxons_x_noms WHERE oid = $OID0; ";
			my ($test) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_nom = $n1 AND oid != $OID0;", $dbc, 1)};
			unless ($test) { 
				foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
					$req .= "DELETE FROM $table WHERE ref_nom = $n1; ";
				}	
			}
			if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
		}
		else {
			$req = "DELETE FROM taxons_x_noms WHERE oid = $OID0;";
			if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
		}
		clear_data();
		
		$title = "Process done";
		$icon = img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"});
		$msg = span({-style=>'color: green'}, "The element has been removed");
	}
	else {
		$title = "Process failed";
		$icon = img({-border=>0, -src=>'/dbtntDocs/stop.png', -name=>"stop" , -alt=>"STOP"});
		$msg = span({-style=>'color: crimson'}, "The element is not in the database");
	}

	my %headerHash = ( titre => $title, css => $css );

	print 	html_header(\%headerHash),
		$maintitle,
		div({-class=>"wcenter"}, p,
			#join(br, map { "$_ = ".param($_) } param()), p,
			$icon, p,
			$msg, p,
			table(
				Tr(	td({-style=>'padding: 10px 20px 10px 0;'}, "Treat another $rankName name:"),
					td(	
						a({-href=>"Names.pl?action=insert&nameOrder=$order", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"Names.pl?action=get&nameOrder=$order", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				),
				Tr(
					td({-style=>'padding: 0 20px 10px 0;'}, "Treat another data:"),
					td(	a({-href=>"dbtnt.pl?action=insert&type=all", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"dbtnt.pl?action=update&type=all", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				)
			)
		),
		html_footer();
}
elsif ($action eq 'getNameData') {
	if (url_param('refresh')) { name_form(); }
	else {
		my $OID = param('OID0') || url_param('OID0');
		get_data($OID);
	}
}

$dbc->disconnect;
exit;

sub get_data {
	
	my ($oid) = @_;
	
	my $template = url_param('template');
	
	unless ($template) { param('OID0', $oid); }
	
	my $req = "SELECT ref_taxon, ref_nom, ref_nom_cible, ref_statut, nom_label, nom_cible_label, 
			ref_publication_utilisant, page_utilisant, ref_publication_denonciation, page_denonciation, remarques
		FROM taxons_x_noms 
		WHERE oid = $oid;"; 

	my $result = request_tab($req, $dbc, 2);
		
	unless ($template) { param('taxonID0', $result->[0][0]); }
	param('taxonID', $result->[0][0]);
	unless ($template) { param('nameID0', $result->[0][1]); }
		
	#param('nameID', $result->[0][1]);
	if ($result->[0][2]) {
		param('targetID', $result->[0][2]);
		$req = "SELECT CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '')
				ELSE
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '') 
					|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '')
				END
			FROM taxons_x_noms AS txn 
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
			LEFT JOIN noms AS n ON n.index = nc.index
			LEFT JOIN noms AS n2 ON n2.index = nt.index
			WHERE txn.ref_nom = ".$result->[0][2]."
			AND txn.ref_taxon = ".$result->[0][0].";"; 
		my ($taxon) = @{request_tab($req, $dbc, 1)};
		unless ($taxon) {
			$req = "SELECT CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
						nt.orthographe || coalesce(' ' || nt.autorite, '') || coalesce(' = ' || nc.orthographe, '') || coalesce(' ' || nc.autorite, '')
					ELSE
						nt.orthographe || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '') 
						|| coalesce(' = ' || nc.orthographe, '') || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '')
					END
				FROM taxons_x_noms AS txn 
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
				LEFT JOIN noms AS n ON n.index = nc.index
				LEFT JOIN noms AS n2 ON n2.index = nt.index
				WHERE txn.ref_nom_cible = ".$result->[0][2]."
				AND txn.ref_taxon = ".$result->[0][0].";"; 
			($taxon) = @{request_tab($req, $dbc, 1)};		
		}
		
		param('taxon', $taxon);
	}
	
	unless ($template) { param('statusID0', $result->[0][3]); }
	param('statusID', $result->[0][3]);
	param('slabel2', $result->[0][4]);
	param('tlabel', $result->[0][5]);
	if ($result->[0][6]) { 
		param('ref_pub3', $result->[0][6]);
		if ($result->[0][7]) { param('page3', $result->[0][7]);	}
		$req = "SELECT coalesce(get_ref_authors(p.index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')
			FROM publications AS p 
			WHERE p.index = ".$result->[0][6].";";
		my ($publabel) = @{request_tab($req, $dbc, 1)};
		param('pub3', $publabel);
	}
	if ($result->[0][8]) { 
		param('ref_pub4', $result->[0][8]);
		if ($result->[0][9]) { param('page4', $result->[0][9]);	}
		$req = "SELECT coalesce(get_ref_authors(p.index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')
			FROM publications AS p 
			WHERE p.index = ".$result->[0][8].";";
		my ($publabel) = @{request_tab($req, $dbc, 1)};
		param('pub4', $publabel);
	}
	if ($result->[0][10]) { param('remarks', $result->[0][10]); }
			
	$req = "SELECT ref_taxon_parent FROM taxons WHERE index = ".$result->[0][0].";"; 
	my ($parentTaxonID) = @{request_tab($req, $dbc, 1)};
	if ($parentTaxonID) {
		unless ($template) { param('parentTaxonID0', $parentTaxonID); }
		param('parentTaxonID', $parentTaxonID);
	}
		
	$req = "SELECT 	nc.index, 
			CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '')
			ELSE
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '') 
				|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '')
			END, 
			nc.orthographe, 
			(SELECT ordre FROM rangs WHERE index = nc.ref_rang), 
			txn.ref_statut
			FROM taxons_x_noms AS txn 
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
			LEFT JOIN noms AS n ON n.index = nc.index
			LEFT JOIN noms AS n2 ON n2.index = nt.index
			WHERE txn.ref_nom = (SELECT ref_nom_parent FROM noms WHERE index = ".$result->[0][1].")
			ORDER BY txn.ref_statut;";			

	my $parent = request_tab($req, $dbc, 2);		

	unless ($parent->[0][0] or !$parentTaxonID) {
		$req = "SELECT 	nc.index, 
				CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '')
				ELSE
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '') 
					|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '')
				END, 
				nc.orthographe, 
				(SELECT ordre FROM rangs WHERE index = nc.ref_rang) 
				FROM taxons_x_noms AS txn 
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
				LEFT JOIN noms AS n ON n.index = nc.index
				LEFT JOIN noms AS n2 ON n2.index = nt.index
				WHERE nc.index = (SELECT ref_nom FROM taxons_x_noms WHERE ref_taxon = $parentTaxonID AND ref_statut = 1);";			
		$parent = request_tab($req, $dbc, 2);
	}
	if ($parent->[0]) {
		param('parent', $parent->[0][1]);
		param('parentNameID', $parent->[0][0]);
		param('parentName', $parent->[0][2]);
		param('parentOrder', $parent->[0][3]);
	}
	
	$req = "SELECT n.orthographe, n.annee, n.parentheses, n.fossil, n.gen_type, n.ref_type_designation, n.ref_publication_designation, n.page_designation, n.ref_publication_princeps, n.page_princeps, nc.orthographe || coalesce(' ' || nc.autorite, '') FROM noms AS n LEFT JOIN noms_complets AS nc ON nc.index = n.index WHERE n.index = ".$result->[0][1].";"; 
	my $name = request_tab($req, $dbc, 2);
	
	if (param('statusID') == 8 or param('statusID') == 17 or param('statusID') == 21 or param('statusID') == 22 ) { param('taxon', $name->[0][10]); param('targetID', $result->[0][1]); }
	param('spelling', $name->[0][0]);
	param('year', $name->[0][1]);
	if ($name->[0][2]) { param('brackets', $name->[0][2]); }
	if ($name->[0][3]) { param('fossil', $name->[0][3]); }
	if ($name->[0][4]) { param('gentype', $name->[0][4]); }
	if ($name->[0][5]) { param('designed', 1); param('designation', $name->[0][5]); }
	if ($name->[0][6]) { 
		param('ref_pub1', $name->[0][6]);
		if ($name->[0][7]) { param('page1', $name->[0][7]); }
		$req = "SELECT coalesce(get_ref_authors(p.index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')
			FROM publications AS p 
			WHERE p.index = ".$name->[0][6].";";
		my ($publabel) = @{request_tab($req, $dbc, 1)};
		param('pub1', $publabel);
	}
	if ($name->[0][8]) { 
		param('ref_pub2', $name->[0][8]);
		if ($name->[0][9]) { param('page2', $name->[0][9]); }
		$req = "SELECT coalesce(get_ref_authors(p.index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
			coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
			coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
			coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
			coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
			coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')
			FROM publications AS p 
			WHERE p.index = ".$name->[0][8].";";
		my ($publabel) = @{request_tab($req, $dbc, 1)};
		param('pub2', $publabel);
	}
	
	$req = "SELECT index, nom, prenom FROM auteurs LEFT JOIN noms_x_auteurs ON ref_auteur = index WHERE ref_nom = ".$result->[0][1]." ORDER BY position;"; 
	my $authors = request_tab($req, $dbc, 2);
	my $i = 1;
	foreach (@{$authors}) { 
		param("ref_author$i", $_->[0]);
		param("AFN$i", $_->[1]);
		param("ALN$i", $_->[2]);
		$i++;
	}
	param("authors", $i-1);
	
	name_form();
}

sub insert_journal {
	my ($suffix) = @_;
	my $journalID;	
	my $nom = param("journal$suffix");	
	my @values = ($nom);
	my $req = "SELECT index FROM revues WHERE nom = trim(BOTH FROM ?);";
	my ($test) = @{request_tab_with_values($req, \@values, $dbc, 1)};	
	if ($test) { $journalID = $test; }
	else {		
		my $req = "INSERT INTO revues (index, nom) VALUES (default, trim(BOTH FROM ?));";
		if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
		$req = "SELECT MAX(index) FROM revues;";
		($journalID) = @{request_tab($req, $dbc, 1)};
	}	
	return $journalID;
}

sub insert_city {
	my ($suffix) = @_;
	my %fields_values;
	my %fields_insert;
	my $cityID;	
	
	$fields_values{"nom"} = param("city$suffix");
	$fields_insert{"nom"} = "trim(BOTH FROM ?)";	
	
	if (param("stateID$suffix")) { 
		$fields_values{"ref_pays"} = param("stateID$suffix"); 
		$fields_insert{"ref_pays"} = "?"; 
	
	} 
	else { 
		$fields_values{"ref_pays"} = undef; 
		$fields_insert{"ref_pays"} = "?"; 
	}
	
	my @fields = sort(keys(%fields_values));
	my @values = map { $fields_values{$_} } @fields;
	my @inserts = map { $fields_insert{$_} } @fields;
	
	my @conditions = map { $fields_values{$_} ? "$_ = ".$fields_insert{$_} : "$_ IS NULL" } @fields;
	my @core; foreach (@values) { if($_) { push(@core, $_); } }	
	
	my $req = "SELECT index FROM villes WHERE ".join(' AND ' , @conditions).";";
	my ($test) = @{request_tab_with_values($req, \@core, $dbc, 1)};	
	if ($test) { $cityID = $test; }
	else {		
		my $req = "INSERT INTO villes (index, ".join(', ', @fields).") VALUES (default, ".join(', ', @inserts).");";
		if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
		$req = "SELECT MAX(index) FROM villes;";
		($cityID) = @{request_tab($req, $dbc, 1)};
	}	
	return $cityID;
}

sub insert_edition {
	my ($suffix) = @_;
	my %fields_values;
	my %fields_insert;
	my $editionID;	
	
	$fields_values{"nom"} = param("edition$suffix");
	$fields_insert{"nom"} = "trim(BOTH FROM ?)";	
	
	if (param("cityID$suffix")) { 
		$fields_values{"ref_ville"} = param("cityID$suffix"); 
		$fields_insert{"ref_ville"} = "?";	
	} 
	elsif (param("city$suffix")) { 
		$fields_values{"ref_ville"} = insert_city($suffix); 
		$fields_insert{"ref_ville"} = "?";	
	}
	else { 
		$fields_values{"ref_ville"} = undef; 
		$fields_insert{"ref_ville"} = "?";	
	}
	
	my @fields = sort(keys(%fields_values));
	my @values = map { $fields_values{$_} } @fields;
	my @inserts = map { $fields_insert{$_} } @fields;
	
	my @conditions = map { $fields_values{$_} ? "$_ = ".$fields_insert{$_} : "$_ IS NULL" } @fields;
	my @core; foreach (@values) { if($_) { push(@core, $_); } }	
	
	my $req = "SELECT index FROM editions WHERE ".join(' AND ', @conditions).";";
	my ($test) = @{request_tab_with_values($req, \@core, $dbc, 1)};	
	if ($test) { $editionID = $test; }
	else {		
		my $req = "INSERT INTO editions (index, ".join(', ', @fields).") VALUES (default, ".join(', ', @inserts).");";
		if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
		$req = "SELECT MAX(index) FROM editions;";
		($editionID) = @{request_tab($req, $dbc, 1)};
	}	
	return $editionID;
}

sub insert_publication {
	
	my ($suffix) = @_;
	my %fields_values;
	my %fields_insert;
	# Type
	$fields_values{"ref_type_publication"} = param("type$suffix");
	$fields_insert{"ref_type_publication"} = "?";	
	# Title
	$fields_values{"titre"} = param("title$suffix");
	$fields_insert{"titre"} = "trim(BOTH FROM ?)";	
	# Year
	if (param("year$suffix")) { 
		$fields_values{"annee"} = param("year$suffix"); 
		$fields_insert{"annee"} = "?";	
	} else { 
		$fields_values{"annee"} = undef; 
		$fields_insert{"annee"} = "?";	
	}		
	# Volume
	if (param("vol$suffix")) { 
		$fields_values{"volume"} = param("vol$suffix"); 
		$fields_insert{"volume"} = "trim(BOTH FROM ?)";	
	} else { 
		$fields_values{"volume"} = undef; 
		$fields_insert{"volume"} = "?";	
	}		
	# Fascicule
	if (param("fasc$suffix")) { 
		$fields_values{"fascicule"} = param("fasc$suffix"); 
		$fields_insert{"fascicule"} = "trim(BOTH FROM ?)";	
	} else { 
		$fields_values{"fascicule"} = undef; 
		$fields_insert{"fascicule"} = "?";	
	}		
	# First page
	if (param("FP$suffix")) { 
		$fields_values{"page_debut"} = param("FP$suffix"); 
		$fields_insert{"page_debut"} = "trim(BOTH FROM ?)";	
	} else { 
		$fields_values{"page_debut"} = undef; 
		$fields_insert{"page_debut"} = "?";	
	}		
	# Last page
	if (param("LP$suffix")) { 
		$fields_values{"page_fin"} = param("LP$suffix"); 
		$fields_insert{"page_fin"} = "trim(BOTH FROM ?)";	
	} else { 
		$fields_values{"page_fin"} = undef; 
		$fields_insert{"page_fin"} = "?";	
	}
		
	my $pubID;
	my @fields = sort(keys(%fields_values));
	my @values = map { $fields_values{$_} } @fields;
	my @inserts = map { $fields_insert{$_} } @fields;
	
	my @conditions = map { $fields_values{$_} ? "$_ = ".$fields_insert{$_} : "$_ IS NULL" } @fields;
	my @core; foreach (@values) { if($_) { push(@core, $_); } }	

	my $req = "SELECT index FROM publications WHERE ".join(' AND ', @conditions).";";
	my ($test) = @{request_tab_with_values($req, \@core, $dbc, 1)};
		
	if ($test) { $pubID = $test; }
	else {
		
		if (param("journalID$suffix")) { 
			$fields_values{"ref_revue"} = param("journalID$suffix"); 
			$fields_insert{"ref_revue"} = "?";	
		} 
		elsif (param("journal$suffix")) { 
			$fields_values{"ref_revue"} = insert_journal($suffix); 
			$fields_insert{"ref_revue"} = "?";	
		}
		else { 
			$fields_values{"ref_revue"} = undef; 
			$fields_insert{"ref_revue"} = "?";	
		}
		
		if (param("editionID$suffix")) { 
			$fields_values{"ref_edition"} = param("editionID$suffix"); 
			$fields_insert{"ref_edition"} = "?";	
		} 
		elsif (param("edition$suffix")) { 
			$fields_values{"ref_edition"} = insert_edition($suffix); 
			$fields_insert{"ref_edition"} = "?";	
		}
		else { 
			$fields_values{"ref_edition"} = undef; 
			$fields_insert{"ref_edition"} = "?";	
		}
		
		if (param("ref_book$suffix")) { 
			$fields_values{"ref_publication_livre"} = param("ref_book$suffix"); 
			$fields_insert{"ref_publication_livre"} = "?";	
		} 
		else { 
			$fields_values{"ref_publication_livre"} = undef; 
			$fields_insert{"ref_publication_livre"} = "?";	
		}
		
		$fields_values{"nombre_auteurs"} = param("p".$suffix."Authors");
		$fields_insert{"nombre_auteurs"} = "?";	
		
		@fields = sort(keys(%fields_values));
		@values = map { $fields_values{$_} } @fields;
		@inserts = map { $fields_insert{$_} } @fields;
		
		#die join(", ",@fields) ."\n". join(", ",@inserts) ."\n". join(", ",@values) ."\n" ;
		#die join("\n", map { "$_ = ".param($_) } param());
		
		my $req = "INSERT INTO publications (index, ".join(', ', @fields).") VALUES (default, ".join(', ', @inserts).");";
		if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
		$req = "SELECT MAX(index) FROM publications;";
		($pubID) = @{request_tab($req, $dbc, 1)};
		
		create_authority('auteurs_x_publications', $pubID, "p$suffix");
	}
	
	return $pubID;
}

sub treat_data {
	
	my $msg;
	my $test;
	my $case;
	my $sth;	
	my $order	= param("nameOrder");
	my ($rankID)	= @{ request_tab("SELECT index FROM rangs WHERE ordre = $order",$dbc,1) };
	my ($rankName)	= @{ request_tab("SELECT en FROM rangs WHERE ordre = $order",$dbc,1) };
		
	# Name data
	my $nameID		= param('nameID');
	my $parentNameID	= param('parentNameID');
	my $spelling		= param('spelling');
	my $year 		= param('year');
	my $brackets 		= param('brackets');
	my $fossil		= param('fossil');
	my $gentype 		= param('gentype');
	my $designtype	 	= param('designation');
	my $designed		= param('designed');
	my $tlabel		= param('tlabel');
	my $remarks		= param('remarks');
	my $slabel;
	if ($nameID) { 	$slabel = param('slabel'); }
		else { 	$slabel = param('slabel2'); }
	my $designation;
	my $princeps;
	my $page;
	my $newPub;
	
	my $parentTaxonID0 	= param('parentTaxonID0');
	my $taxonID0		= param('taxonID0');
	my $nameID0		= param('nameID0');
	my $statusID0 		= param('statusID0');
	my $OID0 		= param('OID0');
	
	my %fields_values;
	my %fields_insert;
		
	my $statusID		= param('statusID');
	my $taxonID 		= param('taxonID') || param('taxonID0');
	my $targetID		= param('targetID');
	my $newtaxonID 		= param('newtaxonID');
	my $newtargetID		= param('newtargetID');
	my $parentTaxonID 	= param('parentTaxonID') || undef;
	
	if ($statusID == 8 or $statusID == 17 or $statusID == 21) { $nameID = $targetID; $targetID = undef; }
	
	#die join("\n", map { "$_ = ".param($_) } param());
						
	unless ($nameID or ($nameID = testpreexistence() and $action0 eq 'insert')) {
				
		$test .= "get name values...\n";
		# Rank
		$fields_values{"ref_rang"} = $rankID;
		$fields_insert{"ref_rang"} = "?";	
		# Parent name
		if ($parentNameID) { 
			$fields_values{"ref_nom_parent"} = $parentNameID; 
			$fields_insert{"ref_nom_parent"} = "?"; 
		} else { 
			$fields_values{"ref_nom_parent"} = undef; 
			$fields_insert{"ref_nom_parent"} = "?"; 
		}		
		# Spelling
		$fields_values{"orthographe"} = $spelling;
		$fields_insert{"orthographe"} = "trim(BOTH FROM ?)";	
		# Year
		if ($year) { 
			$fields_values{"annee"} = $year; 
			$fields_insert{"annee"} = "?"; 
		} else { 
			$fields_values{"annee"} = undef; 
			$fields_insert{"annee"} = "?"; 
		}		
		# Brackets
		if ($brackets) { 
			$fields_values{"parentheses"} = "true"; 
			$fields_insert{"parentheses"} = "?"; 
		} else { 
			$fields_values{"parentheses"} = 'false'; 
			$fields_insert{"parentheses"} = "?"; 
		}		
		# Fossil
		if ($fossil) { 
			$fields_values{"fossil"} = "true"; 
			$fields_insert{"fossil"} = "?"; 
		} else { 
			$fields_values{"fossil"} = 'false'; 
			$fields_insert{"fossil"} = "?"; 
		}		
		# Type name
		if ($gentype) { 
			$fields_values{"gen_type"} = "true"; 
			$fields_insert{"gen_type"} = "?"; 
		} else { 
			$fields_values{"gen_type"} = 'false'; 
			$fields_insert{"gen_type"} = "?"; 
		}		
		# Designation type
		if ($designtype) { 
			$fields_values{"ref_type_designation"} = $designtype; 
			$fields_insert{"ref_type_designation"} = "?"; 
		} else { 
			$fields_values{"ref_type_designation"} = undef; 
			$fields_insert{"ref_type_designation"} = "?"; 
		}		
		# Designation publication
		#if (param('designed')) {
			$designation = param('ref_pub1');
			$page = param('page1');
			$newPub = param('newPub1');
			if (!$designation and $newPub) {
				$designation = insert_publication(1);
			}
			if ($designation) {
				$fields_values{"ref_publication_designation"} = $designation;
				$fields_insert{"ref_publication_designation"} = "?";
				if ($page) { 
					$fields_values{"page_designation"} = $page; 
					$fields_insert{"page_designation"} = "trim(BOTH FROM ?)"; 
				} else { 
					$fields_values{"page_designation"} = undef; 
					$fields_insert{"page_designation"} = "?"; 
				}
			}
			else { 
				$fields_values{"ref_publication_designation"} = undef; 
				$fields_insert{"ref_publication_designation"} = "?"; 
				$fields_values{"page_designation"} = undef; 
				$fields_insert{"page_designation"} = "?"; 
			}
		#}
		# Original publication
		if ($statusID == 3 or $statusID == 4 or $statusID == 12 or $statusID == 15) { 
			($princeps) = @{request_tab("SELECT ref_publication_princeps FROM noms WHERE index = $targetID", $dbc, 1)};
			($page) = @{request_tab("SELECT page_princeps FROM noms WHERE index = $targetID", $dbc, 1)};
		}
		else {
			$princeps = param('ref_pub2');
			$page = param('page2');
			$newPub = param('newPub2');
			if (!$princeps and $newPub) {
				$princeps = insert_publication(2);
			}
		}
		if ($princeps) {
			$fields_values{"ref_publication_princeps"} = $princeps;
			$fields_insert{"ref_publication_princeps"} = "?";
			if ($page) { 
				$fields_values{"page_princeps"} = $page; 
				$fields_insert{"page_princeps"} = "trim(BOTH FROM ?)";
			} else { 
				$fields_values{"page_princeps"} = undef; 
				$fields_insert{"page_princeps"} = "?";
			}
		}
		else { 
			$fields_values{"ref_publication_princeps"} = undef; 
			$fields_insert{"ref_publication_princeps"} = "?"; 
			$fields_values{"page_princeps"} = undef; 
			$fields_insert{"page_princeps"} = "?"; 
		}
		# User name
		$fields_values{"createur"} = $user;
		$fields_insert{"createur"} = "?"; 
		$fields_values{"modificateur"} = $user;
		$fields_insert{"modificateur"} = "?";
			
		my @fields = sort(keys(%fields_values));
		my @values = map { $fields_values{$_} } @fields;
		my @inserts = map { $fields_insert{$_} } @fields;
		
		if ($action0 eq 'insert' and !$nameID) {
			#die join(", ",@fields) ."\n". join(", ",@inserts) ."\n". join(", ",@values) ."\n" . scalar(@fields) ."=". scalar(@fields) ."=". scalar(@fields)."\n";
			my $req = "INSERT INTO noms (index, ".join(', ', @fields).") VALUES (default, ".join(', ', @inserts).");";
			if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
			$req = "SELECT MAX(index) FROM noms;";
			($nameID) = @{request_tab($req, $dbc, 1)};
		}
		elsif ($action0 ne 'insert') {
			$test .= "updating name...\n";
			if (!$nameID) { $nameID = $nameID0 }
						
			my $req = "UPDATE noms SET ".join(', ' , map("$_ = ".$fields_insert{$_}, @fields))." WHERE index = $nameID;";
			
			my @alter = ($nameID);
			my @typos = (0);
			my $end = 0;
			while (!$end) {
				
				my ($prvreq, $nxtreq, $misreq, $emdreq);
				
				$prvreq = "SELECT ref_nom FROM taxons_x_noms WHERE ref_nom_cible IN (".join(', ', @alter).") AND ref_statut IN (4, 12, 15) AND ref_nom NOT IN (".join(', ', @alter).");";
				$nxtreq = "SELECT ref_nom_cible FROM taxons_x_noms WHERE ref_nom IN (".join(', ', @alter).") AND ref_statut IN (4, 12, 15) AND ref_nom_cible NOT IN (".join(', ', @alter).");";
				
				$emdreq = "SELECT ref_nom FROM taxons_x_noms WHERE ref_nom_cible IN (".join(', ', @alter).") AND ref_statut = 3 AND ref_nom NOT IN (".join(', ', @typos).");";
				$misreq = "SELECT ref_nom_cible FROM taxons_x_noms WHERE ref_nom IN (".join(', ', @alter).") AND ref_statut = 3 AND ref_nom_cible NOT IN (".join(', ', @typos).");";
				
				my $count = scalar(@alter);
				
				@alter = (@alter, @{request_tab($prvreq, $dbc, 1)});
				@alter = (@alter, @{request_tab($nxtreq, $dbc, 1)});
								
				@typos = (@typos, @{request_tab($emdreq, $dbc, 1)});
				@typos = (@typos, @{request_tab($misreq, $dbc, 1)});

				$end = $count == scalar(@alter) ? 1 : 0;							
			}
			if (scalar(@alter) > 1) {
								
				shift @alter;
								
				$req = "BEGIN; $req ";
				if ($year) {
					$req .= "UPDATE noms SET annee = $year WHERE index IN (".join(', ', @alter)."); ";
				}
				if ($princeps) {
					my $ppage = $page ? ", page_princeps = trim(BOTH FROM '$page')" : undef;
					$req .= "UPDATE noms SET ref_publication_princeps = $princeps $ppage WHERE index IN (".join(', ', @alter, @typos)."); ";
				}				
				$req .= "COMMIT;";
				
				foreach (@alter) { create_authority('noms_x_auteurs', $_, undef); }
			}
									
			if ( my $sth = $dbc->prepare($req) ){
				if ( $sth->execute(@values) ) {
					$sth->finish();
				} else { die "Execute error: $req with ".$dbc->errstr; }
			} else { die "Prepare error: $req with ".$dbc->errstr; }
			
			if ($princeps) {
				# Update page princeps for previous combinations
				$req = "UPDATE noms SET ref_publication_princeps = ".$fields_values{"ref_publication_princeps"}.", page_princeps = '".$fields_values{"page_princeps"}."' WHERE index IN (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_statut = 4 AND ref_nom_cible = $nameID) OR index IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_statut = 4 AND ref_nom = $nameID);";		
				if ( my $sth = $dbc->prepare($req) ) { if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
			}
		}
		# Link authors to a name	
		create_authority('noms_x_auteurs', $nameID, undef);
	}
		
	# Taxon data
	my $insest = 0;
	if ($taxonID0) { ($insest) = @{request_tab("SELECT count(*) FROM hierarchie WHERE index_taxon_parent = $taxonID0 AND index_taxon_fils = $taxonID", $dbc, 1)}; }
	#if ($insest) { $msg = 'Cannot proceed because taxa are related in hierarchy'; $case = 'fail'; }
	#unless ($msg) {
		# If taxon need to be created (by insertion or by modification) 
		$parentTaxonID0 = $parentTaxonID0 ? $parentTaxonID0 : 'NULL';
		$parentTaxonID = $parentTaxonID ? $parentTaxonID : 'NULL';
		if ($action0 eq 'insert' or ($statusID0 and $statusID0 != 1 and $statusID0 != 20)) {
			$test .= "creating a taxon...\n";
			if ($statusID == 1) {
				my $req = "SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID AND ref_statut = $statusID;";
				my ($test) = @{request_tab($req, $dbc, 1)};
				unless ($test) {
					$req = "INSERT INTO taxons (index, ref_taxon_parent, ref_rang, createur, modificateur) VALUES (default, $parentTaxonID, $rankID, '$user', '$user');";
					if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
					$req = "SELECT MAX(index) FROM taxons;";
					($taxonID) = @{request_tab($req, $dbc, 1)};
				} 
				else { $taxonID = $test; $msg = "This name is already in the database as valid name"; $case = 'fail'; }
			}
			elsif ($statusID == 20) {
				my $req = "SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID AND ref_statut = $statusID;";
				my ($taxon) = @{request_tab($req, $dbc, 1)};
				unless ($taxon) {
					$req = "INSERT INTO taxons (index, ref_taxon_parent, ref_rang, createur, modificateur) VALUES (default, $parentTaxonID, $rankID, '$user', '$user');";
					if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
					$req = "SELECT MAX(index) FROM taxons;";
					($taxonID) = @{request_tab($req, $dbc, 1)};
				}
				else { 	$taxonID = $taxon; }
			}
		}
		# If the taxon must be modified
		elsif (!$insest) {
			$test .= "modifying a taxon...\n";
			#my $parents = request_tab("SELECT DISTINCT index_taxon_parent FROM hierarchie WHERE index_taxon_fils IN ($taxonID0,$taxonID);", $dbc, 1);
			#my $sons = request_tab("SELECT DISTINCT index_taxon_fils FROM hierarchie WHERE index_taxon_parent IN ($taxonID0,$taxonID);", $dbc, 1);
			#if (scalar(@{$parents}) or scalar(@{$sons})) {
			#	my $hreq = "UPDATE taxons set modificateur = '$user' WHERE index IN (".join(', ', @{$parents}, @{$sons}).");";
			#	if ( my $sth = $dbc->prepare($hreq) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $hreq ".$dbc->errstr; } } else { die "Prepare error: $hreq ".$dbc->errstr; }
			#}
			# Name initially valid ...
			if ($statusID0 == 1) {
				# ... remains valid
				if ($statusID == 1) {
					# If parent taxon changes
					if ($parentTaxonID0 != $parentTaxonID) {
						my $req = "UPDATE taxons SET ref_taxon_parent = $parentTaxonID WHERE index = $taxonID;";
						if ( my $sth = $dbc->prepare($req) ){
							if ( $sth->execute() ){
								$sth->finish();
							} else { die "Execute error: $req ".$dbc->errstr; }
						} else { die "Prepare error: $req ".$dbc->errstr; }
					}
				}
				# ... becomes foreign
				elsif ($statusID == 20) {
					my $req = "UPDATE taxons SET ref_taxon_parent = $parentTaxonID, ref_rang = $rankID WHERE index = $taxonID;";
					if ( my $sth = $dbc->prepare($req) ){
						if ( $sth->execute() ){
							$sth->finish();
						} else { die "Execute error: $req ".$dbc->errstr; }
					} else { die "Prepare error: $req ".$dbc->errstr; }
				}
				# ... becomes unvalid => move all children taxa to the new taxon
				else {
					# TODO : Create automatically new combinations for childrens where parent became unvalid !!! 
					my $req = "UPDATE taxons SET ref_taxon_parent = $taxonID WHERE ref_taxon_parent = $taxonID0;";
					if ( my $sth = $dbc->prepare($req) ){
						if ( $sth->execute() ){
							$sth->finish();
						} else { die "Execute error: $req ".$dbc->errstr; }
					} else { die "Prepare error: $req ".$dbc->errstr; }
				}
			}
			elsif ($statusID0 == 20) {
				if ($statusID == 1) {
					my $req = "UPDATE taxons SET ref_taxon_parent = $parentTaxonID, ref_rang = $rankID WHERE index = $taxonID;";
					if ( my $sth = $dbc->prepare($req) ){
						if ( $sth->execute() ){
							$sth->finish();
						} else { die "Execute error: $req ".$dbc->errstr; }
					} else { die "Prepare error: $req ".$dbc->errstr; }
				}
			}
		}
	#}
	
	unless ($msg) {
		# Taxon X Names (statusID, taxonID, nameID, targetID, slabel, tlabel, pub3, pub4, remarks)
		%fields_values = ();
		my ($usage, $denonce);	
		# Status
		$fields_values{"ref_statut"} = $statusID;
		# Taxon
		$fields_values{"ref_taxon"} = $taxonID;
		# Name
		$fields_values{"ref_nom"} = $nameID;
		# Target name
		if ($targetID) { $fields_values{"ref_nom_cible"} = $targetID; } else { $fields_values{"ref_nom_cible"} = undef; }		
		# Using publication	
		$usage = param('ref_pub3');
		$page = param('page3');
		$newPub = param('newPub3');
		if (!$usage and $newPub) {
			$usage = insert_publication(3);
		}
		if ($usage) {
			$fields_values{"ref_publication_utilisant"} = $usage;
			if ($page) { $fields_values{"page_utilisant"} = $page; }
			else { $fields_values{"page_utilisant"} = undef; }
		}
		else { $fields_values{"ref_publication_utilisant"} = undef; $fields_values{"page_utilisant"} = undef; }
		# Denouncing publication
		$denonce = param('ref_pub4');
		$page = param('page4');
		$newPub = param('newPub4');
		if (!$denonce and $newPub) {
			$denonce = insert_publication(4);
		}
		if ($denonce) {
			$fields_values{"ref_publication_denonciation"} = $denonce;
			if ($page) { $fields_values{"page_denonciation"} = $page; }
			else { $fields_values{"page_denonciation"} = undef; }
		}
		else { $fields_values{"ref_publication_denonciation"} = undef; $fields_values{"page_denonciation"} = undef; }
		# Name label
		if ($slabel) { $fields_values{"nom_label"} = $slabel; } else { $fields_values{"nom_label"} = undef; }		
		# Target name label
		if ($tlabel) { $fields_values{"nom_cible_label"} = $tlabel; } else { $fields_values{"nom_cible_label"} = undef; }		
		# remarks
		if ($remarks) { $fields_values{"remarques"} = $remarks; } else { $fields_values{"remarques"} = undef; }		
		
		my @fields = sort(keys(%fields_values));
		my @values = map { $fields_values{$_} } @fields;
				
		my @conditions = map { $fields_values{$_} ? "$_ = ?" : "$_ IS NULL" } @fields;
		my @core; 
		foreach (@values) { if($_) { push(@core, $_); } }
		
		my $req = "SELECT oid FROM taxons_x_noms WHERE ".join(' AND ', @conditions).";";
		my ($OID) = @{request_tab_with_values($req, \@core, $dbc, 1)};
				
		# User name
		$fields_values{"createur"} = $user;
		$fields_values{"modificateur"} = $user;		
		
		@fields = sort(keys(%fields_values));
		@values = map { $fields_values{$_} } @fields;
				
		# If resulting data is already in the database
		if ($OID and $action0 eq 'insert') {
			#if ($OID0) {
			#	$req = "DELETE FROM taxons_x_noms WHERE oid = $OID0;";
			#	$sth = $dbc->prepare($req) or die "$req";
			#	$sth->execute() or die "$req";
			#}
			#$req = "UPDATE taxons_x_noms SET ".join(', ' , map("$_ = ?", @fields)).", date_modification = default WHERE oid = $OID;";
			#$sth = $dbc->prepare($req) or die "$req \n ";
			#$sth->execute(@values) or die "$req \n ";
			
			$msg = 'The data is already in the database'; $case = 'fail';
		}
		else {
			if ($action0 eq 'insert') {
				$req = "INSERT INTO taxons_x_noms (".join(', ', @fields).", date_creation, date_modification) VALUES (".join(', ', ('?') x scalar(@fields)).", default, default);";
				$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
				$sth->execute(@values) or die "$req ".$dbc->errstr;
				# Case of nomen novum => allow to insert homonymy
				if ($statusID == 11) {
					$msg = 'You have inserted an junior homonym, you can link it to his senior homonym ';
					$msg .= a({-href=>"Names.pl?homonymy=$taxonID&nameOrder=$order&action0=insert&statusID=10&nameID=$nameID&ref_pub4=".$fields_values{"ref_publication_denonciation"}."&page4=".$fields_values{"page_denonciation"}, -style=>'text-decoration: none; color: navy;'}, 'Here');
					$case = 'warning';
				}
				# Case of new identification => insert misidentification
				elsif ($statusID == 18) {
					my ($taxon2ID) = @{request_tab("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID AND ref_statut IN (1,2,4,12,14,15,19,23,25) ORDER BY ref_statut LIMIT 1;",$dbc,1)};
					if ($taxon2ID) {
						my @tab = ($taxon2ID, $nameID, undef, 17, $fields_values{"ref_publication_utilisant"}, $fields_values{"page_utilisant"}, $fields_values{"ref_publication_denonciation"}, $fields_values{"page_denonciation"});
						$req = "INSERT INTO taxons_x_noms 
							(ref_taxon, ref_nom, ref_nom_cible, ref_statut, ref_publication_utilisant, page_utilisant, ref_publication_denonciation, page_denonciation, date_creation, date_modification) 
							VALUES (".join(', ', ('?') x scalar(@tab)).",default,default);";
						$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
						$sth->execute(@tab) or die "$req ".$dbc->errstr;
					}
				}
				# Case of homonymy => make reciprocal link
				elsif ($statusID == 10 and param('homonymy')) {
					
					$req = "SELECT oid FROM taxons_x_noms WHERE ref_taxon = ".param('homonymy')." AND ref_nom = ".$fields_values{"ref_nom"}." AND ref_nom_cible = ".$fields_values{"ref_nom_cible"}." AND ref_statut = 10;";
					my ($testh) =  @{request_tab($req, $dbc, 1)};
					unless ($testh) {
						my @tab = (param('homonymy'),$fields_values{"ref_nom"},$fields_values{"ref_nom_cible"},10,$fields_values{"nom_label"},$fields_values{"nom_cible_label"},$fields_values{"ref_publication_denonciation"},$fields_values{"page_denonciation"});
						$req = "INSERT INTO taxons_x_noms (ref_taxon, ref_nom, ref_nom_cible, ref_statut, nom_label, nom_cible_label, ref_publication_denonciation, page_denonciation, date_creation, date_modification) 
							VALUES (?,?,?,?,?,?,?,?,default,default);";
						$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
						$sth->execute(@tab) or die "$req ".$dbc->errstr;	
					}
				}
				# Link the data of an preexisiting name to the taxon to which it is linked
				if (is_taxonomic_status($statusID)) {
					$req = undef;
					foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
						if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = $taxonID WHERE ref_nom = $nameID AND ref_taxon IS NULL; "; }
					}
					if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
				}
					
				# If status revivisco, make automatic changes
				if ($statusID == 21) {
										
					my $req = "SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'taxons_x_%'";
					my $tables = request_tab($req, $dbc, 1);
					unless ($newtaxonID) {
						# insert the name as valid is it doesnt already exists
						($newtaxonID) = @{request_tab("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $nameID AND ref_statut = 1;",$dbc,1)};
						unless($newtaxonID) {
							
							my ($newParentName) = @{request_tab("SELECT ref_nom_parent FROM noms WHERE index = $nameID",$dbc,1)};
							my $newParentID;
							if ($newParentName) {
								($newParentID) = @{request_tab("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $newParentName and ref_statut IN (1,2,4,12,14,15,19,23,25) ORDER BY ref_statut LIMIT 1",$dbc,1)};
							}
							
							($newtaxonID) = @{request_tab("INSERT INTO taxons (index, ref_taxon_parent, ref_rang, createur, modificateur) VALUES (default, $newParentID, $rankID, '$user', '$user') RETURNING index",$dbc,1)};
													
							$req = "INSERT INTO taxons_x_noms (ref_taxon, ref_nom, ref_statut, createur, modificateur) values ($newtaxonID, $nameID, 1, '$user', '$user'); ";
							if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req : ".$dbc->errstr; } } 
							else { die "Prepare error: $req : ".$dbc->errstr; }
						}
					}
					$req = undef;
					foreach my $table (@{$tables}) {
						$req = "SELECT column_name FROM information_schema.columns WHERE table_name = '$table' AND column_name != 'ref_taxon'";
						my $fields = request_tab($req, $dbc, 1);
						my $ccfields = join(", ",@{$fields});						
						
						$req = "SELECT $ccfields FROM $table AS model WHERE (ref_taxon = $taxonID OR ref_taxon IS NULL) AND ref_nom = $nameID;";
						my $models = request_tab($req, $dbc, 2);
						
						foreach my $model (@{$models}) {
							
							my @tests;
							my @values;
							for (my $i=0; $i<scalar(@{$model}); $i++) {
																
								if ($model->[$i]) { push(@tests, $fields->[$i]." = ?"); push(@values, $model->[$i]); }
								else { push(@tests, $fields->[$i]." IS NULL"); }
							}
													
							$req = "INSERT INTO $table (ref_taxon, $ccfields) 
							SELECT $newtaxonID, ".join(', ', ('?') x scalar(@{$model}))." 
							WHERE NOT EXISTS (SELECT 1 FROM $table WHERE ref_taxon = $newtaxonID AND ".join(" AND ", @tests).")";
																												
							if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@{$model},@values) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } 
							else { die "Prepare error: $req with ".$dbc->errstr; }
						}
						
						my $maj;
						if ($ccfields =~ m/ref_publication_maj/) { $maj = 'ref_publication_maj' }
						elsif ($ccfields =~ m/ref_pub_maj/) { $maj = 'ref_pub_maj' }
												
						if ($maj) {	
							
							my $updates;
							$updates .= $denonce ? "$maj = $denonce" : "";
							$updates .= $page ? ", page_maj = $page" : "";
														
							if ($updates) {
								$req = "UPDATE $table SET $updates WHERE (ref_taxon = $taxonID OR ref_taxon IS NULL) AND ref_nom = $nameID; ";
								if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute() ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } 
								else { die "Prepare error: $req with ".$dbc->errstr; }
							}
						}
					}
				}
				
			}
			else {
				if ($OID and $OID != $OID0) { $msg = 'The data is already in the database'; $case = 'fail'; }
				elsif (!$OID) {
					$req = "UPDATE taxons_x_noms SET ".join(', ' , map("$_ = ?", @fields)).", date_modification = default WHERE oid = $OID0;";
					#die $req." with (".join(',',@values).")";
					$sth = $dbc->prepare($req) or die "$req \n @values";
					$sth->execute(@values) or die "$req \n @values";
					
					# IF you update the publication that made a "status revivisco", update it in all the occurrences of this statement
					if ($statusID0 == 21 and $statusID == 21 and $taxonID0 == $taxonID and $nameID0 == $nameID) {
						my @v = ($fields_values{"ref_publication_denonciation"}, $fields_values{"page_denonciation"});
						$req = "UPDATE taxons_x_noms SET ref_publication_denonciation = ?, page_denonciation = ?, date_modification = default WHERE ref_taxon != $taxonID AND ref_nom = $nameID AND ref_statut = 21;";
						$sth = $dbc->prepare($req) or die "$req \n @v";
						$sth->execute(@v) or die "$req \n @v";
					}
					
					my @default = ($taxonID0, $nameID0, $statusID0);
					if (($taxonID0 != $taxonID or $statusID0 != $statusID) and $nameID0 == $nameID) {
						updateCrossTables($OID0, \@default);
						# Move from valid name to any unvalid name except external taxon
						if ($statusID0 == 1 && $statusID != 1 && $statusID != 20) {
							my $names = request_tab("SELECT oid, ref_nom, ref_statut FROM taxons_x_noms WHERE ref_taxon = $taxonID0 AND ref_nom != $nameID0 AND ref_statut NOT IN (3,5,8,10,17,18,20,21,22);", $dbc, 2);
		
							$req = "UPDATE taxons_x_noms SET ref_taxon = $taxonID, date_modification = default WHERE ref_taxon = $taxonID0;";
							$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
							$sth->execute() or die "$req ".$dbc->errstr;
							
							$req = "UPDATE taxons SET ref_taxon_parent = $taxonID WHERE ref_taxon_parent = $taxonID0;";
							$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
							$sth->execute() or die "$req ".$dbc->errstr;
							
							foreach (@{$names}) {
								@default = ($taxonID0, $_->[1], $_->[2]);
								updateCrossTables($_->[0], \@default);
							}
						}
						# change taxon and keep taxonomic status
						elsif ($taxonID0 != $taxonID and is_taxonomic_status($statusID0) and is_taxonomic_status($statusID)) {
							my $names;
							my @prev = ($nameID);
							my %done;
							$done{$nameID} = 1;
							while (scalar(@prev)) {
								my $res = request_tab("SELECT oid, ref_nom, ref_statut FROM taxons_x_noms WHERE ref_taxon = $taxonID0 AND ref_nom_cible IN (".join(',',@prev).") ", $dbc, 2);
								@prev = ();
								foreach (@{$res}) {
									$req = "UPDATE taxons_x_noms SET ref_taxon = $taxonID, date_modification = default WHERE oid = ".$_->[0].";";
									$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
									$sth->execute() or die "$req ".$dbc->errstr;
									
									unless (exists $done{$_->[1]}) {
										@default = ($taxonID0, $_->[1], $_->[2]);
										updateCrossTables($_->[0], \@default);
									
										push(@prev, $_->[1]);
										$done{$_->[1]} = 1;
									}
								}
							}
						}
						# move associated names
						if ($taxonID0 != $taxonID) {
							$req = "UPDATE taxons SET ref_taxon_parent = $taxonID WHERE index IN (
									SELECT index FROM taxons WHERE index IN (
										SELECT DISTINCT ref_taxon FROM taxons_x_noms WHERE ref_nom IN (
											SELECT DISTINCT index FROM noms WHERE ref_nom_parent = $nameID
										)
									)
									AND ref_taxon_parent = $taxonID0
									AND index != $taxonID
								);";
							$sth = $dbc->prepare($req) or die "$req ".$dbc->errstr;
							$sth->execute() or die "$req ".$dbc->errstr;
						}
					}
					elsif ($nameID0 != $nameID) { 
						# For $nameID0
						updateCrossTables(undef, \@default);
						# For $nameID
						@default = ($taxonID, $nameID, $statusID);
						updateCrossTables($OID0, \@default);
					}
									
					if (($statusID0 == 11 and $statusID != 11) or ($statusID0 == 10 and $statusID != 10)) { $msg = 'You changed an homonym, make sure to deal with the reciprocal homonym.'; $case = 'warning'; }
					elsif (($statusID0 == 17 and $statusID != 17) or ($statusID0 == 18 and $statusID != 18)) { $msg = 'You changed a misidentification, make sure to verify the misapplied name.'; $case = 'warning'; }				
													
					# Case of names not linked to any taxon but linked to some data in cross tables : keep the data but set taxon to null
					# if ($taxonID0 == $taxonID and $nameID0 != $nameID) {
					#	$req = undef;
					#	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
					#		if($table =~ /taxons/) { 
					#			$req .= "UPDATE $table 
					#				SET ref_taxon = NULL 
					#				WHERE ref_taxon = $taxonID0 
					#				AND ref_nom NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_taxon = $taxonID0) 
					#				AND ref_nom NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_taxon = $taxonID0 AND ref_nom_cible IS NOT NULL); "; 
					#		}
					#	}
					#	if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
					# }
				}
			}
			
			unless ($msg) { $case = 'gg'; }
		}
	}
		
	# Clear database
	clear_data();
	
	my ($icon, $sentence, $title);
	if ($case eq 'gg') {
		$title = "Process done";
		$icon = img({-border=>0, -src=>'/dbtntDocs/done.png', -name=>"done" , -alt=>"DONE"});
		$sentence = span({-style=>'color: green'}, $title);
	}
	elsif ($case eq 'fail') {
		$title = "Process failed";
		$icon = img({-border=>0, -src=>'/dbtntDocs/stop.png', -name=>"stop" , -alt=>"STOP"});
		$sentence = span({-style=>'color: crimson'}, $msg);
	}
	elsif ($case eq 'warning') {
		$title = "Process partially done";
		$icon = img({-border=>0, -src=>'/dbtntDocs/caution.png', -name=>"warn" , -alt=>"CAUTION"});
		$sentence = span({-style=>'color: brown'}, $msg);
	}
	
	my $req = "SELECT CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '')
			ELSE
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n.ref_nom_parent) || ')', '') 
				|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms_complets WHERE index = n2.ref_nom_parent) || ')', '')
			END
		FROM taxons_x_noms AS txn 
		LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
		LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
		LEFT JOIN noms AS n ON n.index = nc.index
		LEFT JOIN noms AS n2 ON n2.index = nt.index
		WHERE txn.ref_nom = $nameID
		AND txn.ref_statut = $statusID;"; 
	
	my ($label) = @{request_tab($req, $dbc, 1)};

	my %headerHash = ( titre => $title, css => $css );
	my $links;
	my $otherLinks;			
	my $thirdlinks;
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		if($table =~ /taxons/) {
			$links .= Tr(
					td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>"crosstable.pl?cross=$table&xaction=fill&xid=$taxonID%23$nameID&elementX=$label", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"crosstable.pl?cross=$table&xaction=modify&xid=$taxonID%23$nameID&elementX=$label", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
		}
		elsif($table =~ /noms/) {
			$links .= Tr(
					td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>"crosstable.pl?cross=$table&xaction=fill&xid=$nameID&elementX=$label", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"crosstable.pl?cross=$table&xaction=modify&xid=$nameID&elementX=$label", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
		}
		$otherLinks .= Tr(
					td({-style=>'padding: 0 20px;'}, lc($cross_tables->{$table}->{'title'})),
					td(	a({-href=>"crosstable.pl?cross=$table&xaction=fill", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"crosstable.pl?cross=$table&xaction=modify", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				);
	}
	
	
	
	$thirdlinks .= 	table(
				Tr(	td({-style=>'padding: 10px 20px 10px 0;'}, "Treat another $rankName name:"),
					td(	
						a({-href=>"Names.pl?action=insert&nameOrder=$order", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"Names.pl?action=get&nameOrder=$order", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				),
				Tr(
					td({-style=>'padding: 0 20px 10px 0;'}, "Treat another data:"),
					td(	a({-href=>"dbtnt.pl?action=insert&type=all", -style=>'text-decoration: none; color: navy;'}, 'Insert') .
						'&nbsp; / &nbsp;' . 
						a({-href=>"dbtnt.pl?action=update&type=all", -style=>'text-decoration: none; color: navy;'}, 'Update')
					)
				)
			);
	
	$links = div({-style=>'padding: 0 0 10px 0;'}, "Treat $label:"). table($links);
	$otherLinks = div({-style=>'padding: 16px 0 10px 0;'}, 'Treat another taxon:'). table($otherLinks);			

	my $back;
	if ($action0 eq 'insert') { 
		#$back = "backform.action = 'Names.pl?action=get&nameOrder=$order';"; 
	}
	else { 
		$back = td( img({-onMouseOver=>"this.style.cursor = 'pointer';", 
				-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleBack').innerHTML = 'Back';", 
				-onMouseOut=>"document.getElementById('bulleBack').innerHTML = '';",
				-onClick=>"backform.action = 'Names.pl?action=getNameData&nameOrder=$order&OID0=$OID0'; backform.submit();", 
				-border=>0, 
				-src=>'/dbtntDocs/back.png', 
				-name=>'back',
				-style=>'margin-left: 15px;'}) ).
		td({-id=>"bulleBack", -style=>'width: 100px; color: darkgreen;'}, ''); 
	}
	
	
	print 	html_header(\%headerHash),

		$maintitle,

		div({-class=>"wcenter"}, p,
			
			#join(br, map { "$_ = ".param($_) } param()), p,
			
			start_form(-name=>'backform', -method=>'post'),
			
			$icon, p,
			
			table( Tr( td( span({-style=>'font-size: 15px;'}, $sentence) ), $back ) ),
				
			end_form(), p,

			$links, 
			$otherLinks,
			$thirdlinks
		),

		html_footer();
}

sub updateCrossTables {
	my ($oid,$default) = @_;
	my ($t1,$t2,$n1,$s1,$s2);
	my ($req,$res);
	if ($oid and $default) { # Update
		# Previous values
		($t1,$n1,$s1) = @{$default};
		if (is_taxonomic_status($s1)) {
			# New values
			$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE oid = $oid;";
			$res = request_tab($req, $dbc, 2);
			($t2,$s2) = ($res->[0][0], $res->[0][1]);
			if (is_taxonomic_status($s2) or $t1 != $t2) {	
				foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
					if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = $t2 WHERE (ref_taxon = $t1 OR ref_taxon IS NULL) AND ref_nom = $n1; "; }
				}
				if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
			}
			else {
				$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE ref_nom = $n1 AND ref_statut NOT IN (3,5,8,10,17,18,20,21,22) ORDER BY ref_statut LIMIT 1;";
				$res = request_tab($req, $dbc, 2);
				($t2,$s2) = ($res->[0][0], $res->[0][1]);
				if ($t2) {
					foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
						if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = $t2 WHERE (ref_taxon = $t1 OR ref_taxon IS NULL) AND ref_nom = $n1; "; }
					}
					if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
				}
				else {
					foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
						if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = NULL WHERE ref_taxon = $t1 AND ref_nom = $n1; "; }
					}
					if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
				}
			}
		}
	}
	else {
		if ($oid) { # Delete by deleting
			# name to delete
			$req = "SELECT ref_taxon, ref_nom, ref_statut FROM taxons_x_noms WHERE oid = $oid;";
			$res = request_tab($req, $dbc, 2);
			($t1,$n1,$s1) = ($res->[0][0], $res->[0][1], $res->[0][2]);							
			# Check if the name is linked to another taxon
			$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE ref_nom = $n1 AND oid != $oid AND ref_statut NOT IN (3,5,8,10,17,18,20,21,22) ORDER BY ref_statut LIMIT 1;";
			$res = request_tab($req, $dbc, 2);
			unless ($res) {
				$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE ref_nom = $n1 AND oid != $oid AND ref_statut IN (3,5,8,10,17,18,20,21,22) ORDER BY ref_statut LIMIT 1;";
				$res = request_tab($req, $dbc, 2);
			}
			($t2,$s2) = ($res->[0][0], $res->[0][1]);
		}
		else { # Delete by updating
			($t1,$n1,$s1) = @{$default};
			# Check if the name is linked to another taxon
			$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE ref_nom = $n1 AND ref_statut NOT IN (3,5,8,10,17,18,20,21,22) ORDER BY ref_statut LIMIT 1;";
			$res = request_tab($req, $dbc, 2);
			unless ($res) {
				$req = "SELECT ref_taxon, ref_statut FROM taxons_x_noms WHERE ref_nom = $n1 AND ref_statut IN (3,5,8,10,17,18,20,21,22) ORDER BY ref_statut LIMIT 1;";
				$res = request_tab($req, $dbc, 2);
			}
			($t2,$s2) = ($res->[0][0], $res->[0][1]);
		}

		if ($t2) {
			if (is_taxonomic_status($s2)) {
				foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
					if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = $t2 WHERE (ref_taxon = $t1 OR ref_taxon IS NULL) AND ref_nom = $n1; "; }
				}
				if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
			}
			else {
				foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
					if($table =~ /taxons/) { $req .= "UPDATE $table SET ref_taxon = NULL WHERE ref_taxon = $t1 AND ref_nom = $n1; "; }
				}
				if ( my $sth = $dbc->prepare("BEGIN; $req COMMIT;") ) { if ( $sth->execute() ){ $sth->finish(); } else { die "Execute error: $req ".$dbc->errstr; } } else { die "Prepare error: $req ".$dbc->errstr; }
			}
		}
	}
}


sub is_taxonomic_status {
	my ($statut) = @_;
	my @unvalids = (3,5,8,10,17,18,20,21,22, 25);
	my $result = 1;
	foreach (@unvalids) { if($statut == $_) { $result = 0; last; } }
	return $result;
}

sub clear_data {
	
	my $whereTaxon;
	my $whereName;
	my $whereRefName;
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		if($table =~ /taxons/) {
			$whereName .= "AND index NOT IN (SELECT DISTINCT ref_nom FROM $table WHERE ref_nom IS NOT NULL) ";
			$whereRefName .= "AND ref_nom NOT IN (SELECT DISTINCT ref_nom FROM $table WHERE ref_nom IS NOT NULL) ";
			$whereTaxon .= "AND index NOT IN (SELECT DISTINCT ref_taxon FROM $table WHERE ref_taxon IS NOT NULL) ";
		}
		elsif($table =~ /noms/) {
			$whereName .= "AND index NOT IN (SELECT DISTINCT ref_nom FROM $table WHERE ref_nom IS NOT NULL) ";
		}
	}
		
	my $dreq = "BEGIN;
		
		DELETE FROM noms_x_auteurs
		WHERE ref_nom NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
		AND ref_nom NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
		AND ref_nom NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL)
		$whereRefName;
		
		DELETE FROM noms_complets
		WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
		AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
		AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL)
		$whereName;
		
		DELETE FROM noms
		WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
		AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
		AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL)
		$whereName;
		
		DELETE FROM taxons 
		WHERE index NOT IN (SELECT DISTINCT ref_taxon FROM taxons_x_noms) 
		AND index NOT IN (SELECT DISTINCT ref_taxon_parent FROM taxons WHERE ref_taxon_parent IS NOT NULL)
		$whereTaxon;
		
		DELETE FROM auteurs 
		WHERE index NOT IN (SELECT DISTINCT ref_auteur FROM noms_x_auteurs WHERE ref_auteur IS NOT NULL)
		AND index NOT IN (SELECT DISTINCT ref_auteur FROM auteurs_x_publications WHERE ref_auteur IS NOT NULL);
		
		COMMIT;";
				
	my $sth = $dbc->prepare($dreq) or die "$dreq ".$dbc->errstr;
	$sth->execute() or die "$dreq ".$dbc->errstr;
}

# fast access
sub get_name {	
	
	my $template = url_param('template');
	
	my ($target, $jsaction, $xfield, $xhiddens, $xsubmit);	
	my $title = "Select a scientific name";
	my $order = param('nameOrder') ? "AND r.ordre = ".param('nameOrder') : undef;
	
	my $cgi = new CGI();
	my $pjx = new CGI::Ajax( 'getThesaurusItems' => \&getThesaurusItems );		
	
	my $default = '-- scientific name --';
	$xfield = textfield(
		-name=> 'label', 
		-id => 'label', 
		-autocomplete=>'off',
		-style=>'width: 770px;', 
		-value => param("label") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.selectForm.OID0.value = ''; this.value = '';",
		-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyDown(document.getElementById('label').getAttribute('id'), event);
				}
				else { AutoComplete_HideDropdown(document.getElementById('label').getAttribute('id')); }",
		-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyUp(document.getElementById('label').getAttribute('id'), event);
				}
				else {
					function callServerScript() { 
						if(document.getElementById('label').value.length > 2) { 
							getThesaurusItems(['args__label', 'args__oids', 'args__'+encodeURIComponent(document.getElementById('label').value), 'args__$order', 'NO_CACHE'], [setThesaurusItems]);
						} 
						else {  
							AutoComplete_HideDropdown(document.getElementById('label').getAttribute('id')); 
						}
					}
					typewatch(callServerScript, 500);
				}",
		-onBlur =>  "if(!this.value || !document.selectForm.OID0.value) { this.value = '$default'; }"
	)."\n";
		
	$target = url()."?action=getNameData";
	if ($template) { param('action0', 'insert'); }
	$jsaction =  "document.selectForm.submit();";
	
	$xsubmit = 	table({-cellspacing=>0, -border=>0}, Tr(
				td(img({
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleSubmit').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleSubmit').innerHTML = '';",
					-onClick=>"if (document.selectForm.OID0.value) { document.selectForm.action = '$target'; $jsaction } 
							else { alert('Select a statement') }", -border=>0, 
					-src=>'/dbtntDocs/submit.png', 
					-name=>"OK"} )).
				td({-id=>"bulleSubmit", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '')
			));
	
	$xhiddens .= 	hidden(-name=>'OID0', -id=>'OID0').
			hidden(-name=>'action0', -id=>'action0').
			hidden(-name=>'nameOrder', -id=>'nameOrder');
		

	my $html .=		
	"<HTML>".
	"<HEAD>".
	"\n	<TITLE>$title</TITLE>".
	"\n	<STYLE TYPE='text/css'>$css</style>".
	"\n	<SCRIPT TYPE='text/javascript' SRC='/dbtntDocs/SearchMultiValue.js'></SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>\n$jscript\n</SCRIPT>".
	"</HEAD>".
	"<BODY>".
	#join(br, map { "$_ = ".param($_)."<BR>" } param()).
	$maintitle.
	"<DIV CLASS='wcenter'>".
	div({style=>"margin-bottom: 4%; font-size: 18px; font-style: italic;"}, $title).
	start_form(-name=>'selectForm', -method=>'post').
	$xfield.
	$xhiddens.
	p. br.
	$xsubmit.
	end_form().
	"</DIV>".
	"<div id='testDiv'></div>".
	"</BODY>".
	"</HTML>";	
		
	print 	$pjx->build_html($cgi, $html, {-charset=>'UTF-8'});
}

# Link authors to a name or a publication
sub create_authority {
	my ($table, $index, $prefix) = @_;
	my $field;
	if ($table eq 'noms_x_auteurs') { $field = 'ref_nom'; }
	elsif ($table eq 'auteurs_x_publications') { $field = 'ref_publication'; }
	my $i=1;
	my $greq = "DELETE FROM $table WHERE $field = $index; ";
	while(my $nom = param($prefix."AFN$i")) {
		my $authorID = param($prefix."ref_author$i");
		my $initiales = param($prefix."ALN$i");
		unless ($authorID) {
			my @v = ($nom);
			my $req = "SELECT index FROM auteurs WHERE nom = trim(BOTH FROM ?)";
			if ($initiales) { $req .= " AND prenom = trim(BOTH FROM ?) "; push(@v, $initiales); }
			else { $req .= " AND prenom IS NULL"; push(@v, undef); }
			my ($test) = @{request_tab_with_values($req, \@v, $dbc, 1)};
			if ($test) { $authorID = $test; }
			else {
				my $req = "INSERT INTO auteurs (index, nom, prenom) VALUES (default, trim(BOTH FROM ?), trim(BOTH FROM ?));";
				if ( my $sth = $dbc->prepare($req) ){ if ( $sth->execute(@v) ) { $sth->finish(); } else { die "Execute error: $req with ".$dbc->errstr; } } else { die "Prepare error: $req with ".$dbc->errstr; }
				$req = "SELECT MAX(index) FROM auteurs;";
				($authorID) = @{request_tab($req, $dbc, 1)};
			}
		}
		$greq .= "INSERT INTO $table ($field, ref_auteur, position) VALUES ($index, $authorID, $i); ";
		$i++;
	}
		
	if ( my $sth = $dbc->prepare("BEGIN; $greq COMMIT;") ){
		if ( $sth->execute() ){
			$sth->finish();
		} else { die "Execute error: $greq ".$dbc->errstr; }
	} else { die "Prepare error: $greq ".$dbc->errstr; }
}

# teste la preexistence d'un nom de la table noms
sub testpreexistence {

	# Fields and values for noms table
	my @fields;
	my @values;

	my $order = param("nameOrder");
	my ($rankid) = @{ request_tab("SELECT index FROM rangs WHERE ordre = $order",$dbc,1) };
	push(@values, "$rankid");
	push(@fields, "ref_rang");

	my $sciname = param("spelling");
	$sciname =~ s/'/\\'/g;
	push(@values, "trim(BOTH FROM '$sciname')");
	push(@fields, "orthographe");

	my $year = param("year");
	if ($year) { push(@values, $year); } else { push(@values, 'NULL'); }
	push(@fields, "annee");

	if (param("brackets")) { push(@values, "true"); }
	else { push(@values, "false"); }
	push(@fields, "parentheses");
	
	if (param('parentNameID')) {
		push(@values, param('parentNameID'));
		push(@fields, "ref_nom_parent");
	}

	my $req = "SELECT index FROM noms WHERE (".join(', ', @fields).") = (".join(', ', @values).")";
	
	# Look if the name already exists
	my $already = 0;
	my $names = request_tab($req,$dbc,1);
	if (scalar @{$names}) {

		while (!$already and my $id = shift @{$names}) {
			
			$req = "SELECT a.nom, a.prenom FROM auteurs AS a LEFT JOIN noms_x_auteurs AS na ON na.ref_auteur = a.index WHERE na.ref_nom = $id ORDER BY na.position";

			my $authors = request_tab($req,$dbc,2);
			$already = $id;

			my $i=0;
			my $j=1;

			while (param("AFN$j") and $already) {
				my $nom = param("AFN$j");
				$nom =~ s/\s+$//;
				$nom =~ s/^\s+//;
				my $prenom = param("ALN$j");
				$prenom =~ s/\s+$//;
				$prenom =~ s/^\s+//;
				my $nsaisi = $authors->[$i][0];
				$nsaisi =~ s/\s+$//;
				$nsaisi =~ s/^\s+//;
				my $psaisi = $authors->[$i][1];
				$psaisi =~ s/\s+$//;
				$psaisi =~ s/^\s+//;
				unless ( $nom eq $nsaisi and $prenom eq $psaisi ) { $already = 0 }
				$i++;
				$j++;
			}
			# If matching name has more authors than inserted name
			if ($already and $authors->[$i][0]) { $already = 0 }
		}
	}

	return $already;
}

sub getPublicationTitle { 
	my ($num, $index) = @_; 
	
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
	
	return($num.'_ARG_'.$value); 
}

# fast access
sub getThesaurusItems {
	
	my ($id, $table, $expr, $cond) = @_;	
	my ($req, $res, $str, $req2);

	$str = "$table = {}; ";
	$expr =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	$expr =~ s/\*/\%/g;
		
	if ($table eq 'taxons') { 
		
		my $xfields;
		my $xfields2;
		if ($id eq 'sciname') {
			
			$xfields = "NULL, 
				txn.ref_nom, 
				r.ordre,
				CASE WHEN (SELECT ordre FROM rangs WHERE index = n.ref_rang) > (SELECT ordre FROM rangs WHERE en ILIKE 'genus') THEN
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') || coalesce(' [' || txn.ref_taxon || ']', '')
				ELSE
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') || coalesce(' [' || txn.ref_taxon || ']', '')
				END";
				
			$xfields2 = "NULL, 
				txn.ref_nom_cible, 
				r.ordre,
				nt.orthographe || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') || coalesce(' [' || txn.ref_taxon || ']', '')";
		} else {
			
			$xfields = "txn.ref_taxon, 
				txn.ref_nom, 
				r.ordre,
				nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') 
				|| coalesce(' = ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (select all_to_rank(nt.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '')
				|| coalesce(' [' || txn.ref_taxon || ']', '')";
			
			$xfields2 = "txn.ref_taxon, 
				txn.ref_nom_cible, 
				r.ordre,
				nt.orthographe || coalesce(' ' || nt.autorite, '') || coalesce(' (' || (select all_to_rank(nt.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') 
				|| coalesce(' = ' || nc.orthographe, '') || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '')
				|| coalesce(' [' || txn.ref_taxon || ']', '')";
		} 
		
		$req = "SELECT DISTINCT
				$xfields,
				nc.orthographe,
				nc.autorite,
				txn.ref_statut,
				CASE WHEN txn.ref_statut = 14 THEN
					' dead end'
				ELSE
					NULL
				END,
				ref_taxon
			FROM taxons_x_noms AS txn 
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
			LEFT JOIN noms AS n ON n.index = nc.index
			LEFT JOIN noms AS n2 ON n2.index = nt.index
			LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
			LEFT JOIN rangs AS r ON r.index = t.ref_rang
			WHERE nc.orthographe ILIKE '%$expr%'
			$cond
			ORDER BY 5, 6, 7, 4;";
		

		$req2 = "SELECT DISTINCT
				$xfields2,
				nt.orthographe,
				nt.autorite,
				txn.ref_statut,
				CASE WHEN txn.ref_statut = 14 THEN
					' dead end'
				ELSE
					NULL
				END
			FROM taxons_x_noms AS txn 
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
			LEFT JOIN noms AS n ON n.index = nc.index
			LEFT JOIN noms AS n2 ON n2.index = nt.index
			LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
			LEFT JOIN rangs AS r ON r.index = t.ref_rang
			WHERE nt.orthographe ILIKE '%$expr%'
			AND txn.ref_nom_cible not in (select ref_nom from taxons_x_noms)
			$cond
			ORDER BY 5, 6, 7, 4;";
		
		$res = request_tab($req, $dbc, 2);
		if ($req2) { push(@{$res}, @{request_tab($req2, $dbc, 2)}); }
		
		my ($full, $partial);
		foreach ( sort {$a->[4] cmp $b->[4] || $a->[5] cmp $b->[5] || $a->[6] cmp $b->[6] || $a->[3] cmp $b->[3] } @{$res}) {
			my $value = $_->[3].$_->[7];
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;			
			if(lc($_->[4]) eq lc($expr)) { 
				$full .= $table.'["'.$value.'"] = "'.$_->[0].'_COL_'.$_->[1].'_COL_'.$_->[4].'_COL_'.$_->[2].'"; '; 
			}
			else { 
				$partial .= $table.'["'.$value.'"] = "'.$_->[0].'_COL_'.$_->[1].'_COL_'.$_->[4].'_COL_'.$_->[2].'"; '; 
			}
		}
		$str = $str . $full . $partial;
	}
	elsif ($table eq 'oids') {
						
		$req = 	"SELECT txn.oid,
				CASE WHEN nc.index != nt.index THEN
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '') || 
					coalesce(' [' || (select abbrev from statuts where index = txn.ref_statut) || '] ' || nt.orthographe, '') || coalesce(' ' || nt.autorite, '') || 
					coalesce(' (' || (select all_to_rank(nt.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '')
				ELSE
					nc.orthographe || coalesce(' ' || nc.autorite, '') || coalesce(' (' || (select all_to_rank(nc.index, 'subtribe', 'suborder', ',', 'down', 'notfull')) || ')', '')
				END,	
				nc.orthographe,
				nc.autorite,
				txn.ref_statut,
				CASE WHEN txn.ref_statut = 14 THEN
					' dead end'
				WHEN txn.ref_statut = 21 THEN
					' status revivisco'
				WHEN txn.ref_statut = 22 THEN
					' combinatio revivisco'
				ELSE
					NULL
				END,
				coalesce(' by ' || (SELECT get_ref_authors(index) || coalesce(' ' || annee, '') FROM publications WHERE index = txn.ref_publication_utilisant AND txn.ref_statut IN (3,5,8,12,17,18)), ''),
				coalesce(' according ' || (SELECT get_ref_authors(index) || coalesce(' ' || annee, '') FROM publications WHERE index = txn.ref_publication_denonciation), ''),
				CASE WHEN (SELECT count(*) FROM taxons_x_noms WHERE ref_nom = txn.ref_nom AND ref_nom_cible = txn.ref_nom_cible) > 1 THEN
					' in taxon '||(SELECT orthographe || coalesce(' '||autorite,'') FROM noms_complets WHERE index = (SELECT ref_nom FROM taxons_x_noms where ref_taxon = txn.ref_taxon and ref_statut = 1))
				END,
				txn.ref_taxon
				
			FROM taxons_x_noms AS txn
			LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
			LEFT JOIN noms_complets AS nt ON txn.ref_nom_cible = nt.index
			LEFT JOIN noms AS n ON n.index = nc.index
			LEFT JOIN noms AS n2 ON n2.index = nt.index
			LEFT JOIN taxons AS t ON txn.ref_taxon = t.index
			LEFT JOIN rangs AS r ON r.index = nc.ref_rang
			WHERE (nc.orthographe ILIKE '%$expr%' OR nt.orthographe ILIKE '%$expr%')
			$cond
			ORDER BY 3, 4, 5, 2;";
				
		$res = request_tab($req, $dbc, 2);
				
		my ($full, $partial, %done);
		foreach (@{$res}) {
			my $value = $_->[1] . $_->[5] . $_->[6] . $_->[7] . $_->[8] . " {$_->[9]}";
			if (exists $done{$value}) { $done{$value}++; } else { $done{$value} = 1; }
			my $version = $done{$value}>1 ? " ($done{$value})" : '';
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;
			if (lc($_->[2]) eq lc($expr)) { $full .= $table.'["'.$value.$version.'"] = "'.$_->[0].'"; '; }
			else { $partial .= $table.'["'.$value.$version.'"] = "'.$_->[0].'"; '; }
		}
		$str = $str . $full . $partial;
	}
	elsif ($table eq 'labels') {
		
		$req = "SELECT DISTINCT nom_label FROM taxons_x_noms ORDER BY nom_label;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			$str .= $table.'["'.$_->[0].'"] = "'.$_->[0].'"; ';
		}
		
		$req = "SELECT DISTINCT nom_cible_label FROM taxons_x_noms ORDER BY nom_cible_label;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			$str .= $table.'["'.$_->[0].'"] = "'.$_->[0].'"; ';
		}
	}
	elsif ($table eq 'authors') {
				
		$req = "SELECT index, nom, prenom FROM auteurs WHERE reencodage(nom) ILIKE reencodage('%$expr%') ORDER BY reencodage(nom), prenom;";
				
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			my $auteur = $_->[1];
			$auteur .= $_->[2] ? ' '.$_->[2] : '';
			$str .= $table.'["'.$auteur.'"] = "'.$_->[0].'_COL_'.$_->[1].'_COL_'.$_->[2].'"; ';
		}
	}
	elsif ($table eq 'publications') {
					
		$req = "SELECT 	index, coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '')
				FROM publications AS p 
				WHERE reencodage(coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '') || coalesce(' {n' || p.index || '}', '')) ILIKE reencodage('%$expr%')
				$cond				
				ORDER BY coalesce(get_ref_authors(index), '') || ' ' || p.annee || ' - ' || coalesce(p.titre||'.', '') || 
				coalesce(' ' || (SELECT nom FROM editions WHERE index = p.ref_edition)||'.', '') || 
				coalesce(' ' || (SELECT nom FROM revues WHERE index = p.ref_revue)||'.', '') || 
				coalesce(' In: ' || (SELECT get_ref_authors(index) || ' ' || annee FROM publications WHERE index = p.ref_publication_livre), '') || 
				coalesce(' Vol.' || p.volume, '') || coalesce(' ' || p.page_debut, '') || 
				coalesce('-' || p.page_fin, '');";
				
		$res = request_tab($req, $dbc, 2);
			
		foreach (@{$res}) {
			my $value = $_->[1];
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;
			$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; ';
		}
	}
	elsif ($table eq 'journals') {
		
		$req = "SELECT index, nom FROM revues WHERE reencodage(nom) ILIKE reencodage('%$expr%') ORDER BY nom;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			my $value = $_->[1];
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;
			$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; ';
		}
	}
	elsif ($table eq 'editions') {
		
		$req = "SELECT e.index, e.nom, v.nom, p.en, e.ref_ville, v.ref_pays  
			FROM editions AS e
			LEFT JOIN villes AS v ON v.index = e.ref_ville 		
			LEFT JOIN pays AS p ON p.index = v.ref_pays
			WHERE reencodage(e.nom) ILIKE reencodage('%$expr%')
			ORDER BY e.nom, v.nom, p.en;";
				
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			my $value = $_->[1];
			#$value .= $_->[2] ? ", ".$_->[2] : '';
			#$value .= $_->[3] ? ", ".$_->[3] : '';
			$value =~ s/"/\\"/g;
			$str .= $table.'["'.$value.'"] = "'.$_->[0].'_COL_'.$_->[4].'_COL_'.$_->[5].'_COL_'.$_->[2].'_COL_'.$_->[3].'"; ';
		}
	}
	elsif ($table eq 'cities') {
		
		$req = "SELECT v.index, v.nom, p.en, v.ref_pays  
			FROM villes AS v
			LEFT JOIN pays AS p ON p.index = v.ref_pays
			WHERE reencodage(v.nom) ILIKE reencodage('%$expr%')
			ORDER BY v.nom, p.en;";
				
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			my $value = $_->[1];
			$value .= $_->[2] ? " (".$_->[2].")" : '';
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;
			$str .= $table.'["'.$value.'"] = "'.$_->[0].'_COL_'.$_->[3].'_COL_'.$_->[2].'"; ';
		}
	}
	elsif ($table eq 'states') {
		
		$req = "SELECT index, en, tdwg, tdwg_level 
			FROM pays 
			WHERE (
				tdwg_level IN ('1', '2', '4') 
				OR index IN (
					SELECT index FROM pays WHERE tdwg_level = '3' AND en NOT IN (
						SELECT DISTINCT en FROM pays WHERE tdwg_level = '4'
					)
				)
			)
			AND reencodage(en) ILIKE reencodage('%$expr%')
			ORDER BY en;";
				
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) {
			my $value = $_->[1];
			#$value .= $_->[3] ? " [TDWG".$_->[3]."]" : '';
			$value =~ s/"/\\"/g;
			$value =~ s/&nbsp;/ /g;
			$value =~ s/  / /g;
			$str .= $table.'["'.$value.'"] = "'.$_->[0].'"; ';
		}
	}
	
	return($id.'_ARG_'.$table.'_ARG_'.$str.'_ARG_'.scalar(@{$res}).'_ARG_'.$expr);
}

sub name_form {

	#my ($msg) = @_;
	my $xorder = param('nameOrder');
	my $actlabel = ($action0 eq 'insert') ? 'Create' : 'Modify';
	my $html;
	my $default;
	my $hiddens;
	my $xdisp;
	my $testDisplay;
	my $interligne = div({-style=>'height: 10px;'}, '');
			
	my $cgi = new CGI();
	my $pjx = new CGI::Ajax( 'getThesaurusItems' => \&getThesaurusItems, 'getPublicationTitle' => \&getPublicationTitle,  'testFunc' => \&testFunc );
	
	## Publication types
	my $tab = request_tab("SELECT index, en FROM types_publication ORDER BY en;", $dbc, 2);
	my $pubTypes;
	$pubTypes->{0} = '-- type --';
	foreach (@{$tab}) {
		$pubTypes->{$_->[0]} = lc($_->[1]);
	}
	
	## designation types
	$tab = request_tab("SELECT index, en FROM types_designation ORDER BY en;", $dbc, 2);
	my $designationTypes;
	$designationTypes->{0} = '-- designation --';
	foreach (@{$tab}) {
		$designationTypes->{$_->[0]} = lc($_->[1]);
	}
	
	# FORM FIELDS
	# Taxonomic status
	my $xstatut;
	$xstatut = popup_menu(
		-name=>'statusID', 
		-id=>'statusID', 
		-values=>[0,1,2,4,3,10,11,15,12,17,18,23,19,5,8,21,22,14,20,25], 
		-labels=>\%statuts, 
		-onFocus=>"AutoComplete_HideAll(); Reset_TabIndex();", 
		-onChange=>"testStatement(this);"
	)."\n";
	
	# Reamarks field
	my $remarks;
	$default = '-- Remarks --';
	$remarks = textarea(
		-name=> 'remarks', 
		-id => 'remarks', 
		-autocomplete=>'off',
		-rows=>'3',
		-style=>'margin-left: 10px; width: 620px;', 
		-value => param("remarks") || $default,
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '-- Remarks --') { this.value = ''; } /*alert(document.getElementById('taxonID').value);*/",
		-onBlur => "if (!this.value) { this.value = '-- Remarks --'; }"
	)."\n";
					
	# NAME FIELDS
	# Taxon and target name
	my $xtaxon;
	$default = '-- scientific name --';
	my $fieldID = 'taxon';
	$xtaxon = textfield(
		-name=> $fieldID, 
		-id => $fieldID, 
		-autocomplete=>'off',
		-style=>'margin-left: 10px; width: 670px;', 
		-value => param("$fieldID") || $default,
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('taxonID').value = ''; document.getElementById('targetID').value = ''; this.value = '';",
		-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyDown(document.getElementById('$fieldID').getAttribute('id'), event);
				}
				else { AutoComplete_HideDropdown(document.getElementById('$fieldID').getAttribute('id')); }",
		-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyUp(document.getElementById('$fieldID').getAttribute('id'), event);
				}
				else {
					function callServerScript() { 
						if(document.getElementById('$fieldID').value.length > 2) { 
							getThesaurusItems(['args__$fieldID', 'args__taxons', 'args__'+encodeURIComponent(document.getElementById('$fieldID').value), 'args__AND txn.ref_statut NOT IN (5,8,17,18,20,21,22)', 'NO_CACHE'], [setThesaurusItems]);
						} 
						else {  
							AutoComplete_HideDropdown(document.getElementById('$fieldID').getAttribute('id')); 
						}
					}
					typewatch(callServerScript, 500);
				}",
		-onBlur =>  "if(!this.value || !document.getElementById('taxonID').value) { this.value = '$default' }"
	)."\n";
						
	# Target name nomenclatural status
	$default = '-- nomenclatural status --';
	$xtaxon .= textfield(
		-name=> 'tlabel', 
		-id => 'tlabel', 
		-autocomplete=>'off',
		-style=>'width: 170px;', 
		-value => param("tlabel") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' } getThesaurusItems(['args__tlabel', 'args__labels', 'args__'+encodeURIComponent(this.value), 'args__', 'NO_CACHE'], [setThesaurusItems]);",
		-onBlur =>  "if(!this.value) { this.value = '$default' }"
	)."\n";
		
	$hiddens .= hidden(-name=>'taxonID', -id=>'taxonID')."\n";
	$hiddens .= hidden(-name=>'targetID', -id=>'targetID')."\n";
	
	
	# NEW NAME FIELDS
	my $ntaxon;
	if ($action0 eq 'insert') {
		$default = '-- scientific name --';
		$fieldID = 'newtaxon';
		$ntaxon .= textfield(
			-name=> $fieldID, 
			-id => $fieldID, 
			-autocomplete=>'off',
			-style=>'margin-left: 10px; width: 670px;', 
			-value => param("$fieldID") || $default,
			-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('newtaxonID').value = ''; document.getElementById('newtargetID').value = ''; this.value = '';",
			-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyDown(document.getElementById('$fieldID').getAttribute('id'), event);
					}
					else { AutoComplete_HideDropdown(document.getElementById('$fieldID').getAttribute('id')); }",
			-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyUp(document.getElementById('$fieldID').getAttribute('id'), event);
					}
					else {
						function callServerScript() { 
							if(document.getElementById('$fieldID').value.length > 2) { 
								getThesaurusItems(['args__$fieldID', 'args__taxons', 'args__'+encodeURIComponent(document.getElementById('$fieldID').value), 'args__AND txn.ref_statut NOT IN (5,8,17,18,20,21,22)', 'NO_CACHE'], [setThesaurusItems]);
							} 
							else {  
								//AutoComplete_HideDropdown(document.getElementById('$fieldID').getAttribute('id')); 
							}
						}
						typewatch(callServerScript, 500);
					}",
			-onBlur =>  "if(!this.value || !document.getElementById('newtaxonID').value) { this.value = '$default' }"
		)."\n";
		
		$ntaxon = "<FIELDSET class='round fieldset1' id='newnameField' style='margin-bottom: 10px;'>\n".	
				"<LEGEND class='round' id='newnameLegend'></LEGEND>\n".
				$ntaxon.
			"</FIELDSET>\n";
	}
		
	$hiddens .= hidden(-name=>'newtaxonID', -id=>'newtaxonID')."\n";
	$hiddens .= hidden(-name=>'newtargetID', -id=>'newtargetID')."\n";

	## Epithet + brackets + type species
	my $epithet;
	my $xtype;
	my $xbrackets;
	$xdisp = param('designed') ? 'inline' : 'none';
	if ($xorder <= $genusOrder) { 
		$epithet = '-- scientific name --'; 
		if ($xorder == $genusOrder) { 
			$xtype = 
			table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
				Tr(
					td( checkbox(
						-name=>'gentype', 
						-id=>'gentype', 
						-value=>1, 
						-label=>'', 
						-onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();', 
						-onClick=>"	clearSearchedName(); 
								if (this.checked) { 
									document.getElementById('designation').style.display = 'inline';
									document.getElementById('designed').value = 1;
								} else {  
									document.getElementById('designation').style.display = 'none'; 
									document.getElementById('designation').selectedIndex = 0; 
									document.getElementById('designed').value = 0;
									document.getElementById('pubField1').style.display = 'none';
									clearSearchedPub(1);
									clearPub(1);
									hidePub(1);
								}"
					)."\n" )."\n",
					td( span({-style=>'color: navy; font-size: 13px; padding-right: 6px;'}, 'type genus')."\n" )."\n",
					td(
						popup_menu(	
							-name=>"designation",
							-id=>"designation",
							-style=>"display: $xdisp;",
							-values=>[sort { $designationTypes->{$a} cmp $designationTypes->{$b} } keys(%{$designationTypes})], 
							-labels=>$designationTypes, 
							-onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();',
							-onChange=>"	if (this.value == 1) { 
										document.getElementById('pubField1').style.display = 'inherit';
									} 
									else { document.getElementById('pubField1').style.display = 'none'; clearSearchedPub(1); clearPub(1); hidePub(1); }
									/*reloadSearch();*/"
						)."\n"		
					)."\n"
				)."\n"
			)."\n"; 
		}
	}
	else { 
		my ($rg) = @{request_tab("SELECT en FROM rangs WHERE ordre = $xorder;", $dbc, 1)};
		
		if ($rg eq 'subgenus') { $epithet = '-- subgeneric epithet --' }
		elsif ($rg eq 'super species') { $epithet = '-- super species epithet --' }
		else { 
			$xbrackets = 
			table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
				Tr(
					td( checkbox(-name=>'brackets', -id=>'brackets', -value=>1, -label=>'', -onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();', -onClick=>'clearSearchedName();', -checked=>param('brackets'))."\n" )."\n",
					td( span({-style=>'color: navy; font-size: 13px;'}, 'brackets')."\n" )."\n"
				)."\n"
			)."\n"; 
			if ($rg eq 'species') { 
				$epithet = '-- specific epithet --'; 
				$xtype = 
				table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
					Tr(
						td( checkbox(
							-name=>'gentype', 
							-id=>'gentype', 
							-value=>1, 
							-label=>'', 
							-onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();',
							-onClick=>"	clearSearchedName(); 
									if (this.checked) { 
										document.getElementById('designation').style.display = 'inline';
										document.getElementById('designed').value = 1;
									} else {  
										document.getElementById('designation').style.display = 'none'; 
										document.getElementById('designation').selectedIndex = 0; 
										document.getElementById('designed').value = 0;
										document.getElementById('pubField1').style.display = 'none'; 
										clearSearchedPub(1);
										clearPub(1);
										hidePub(1);
									}
									/*reloadSearch();*/"
						)."\n" )."\n",
						td( span({-style=>'color: navy; font-size: 13px; padding-right: 6px;'}, 'type species')."\n" )."\n",
						td(
							popup_menu(	
								-name=>"designation",
								-id=>"designation",
								-style=>"display: $xdisp;",
								-values=>[sort { $designationTypes->{$a} cmp $designationTypes->{$b} } keys(%{$designationTypes})], 
								-labels=>$designationTypes, 
								-onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();',
								-onChange=>"	if (this.value == 1) { 
											document.getElementById('pubField1').style.display = 'inherit';
										} 
										else { document.getElementById('pubField1').style.display = 'none'; clearSearchedPub(1); clearPub(1); hidePub(1); }
										/*reloadSearch();*/"

							)."\n"	
						)."\n"
					)."\n"
				)."\n";		
			}
			elsif ($rg eq 'subspecies') { $epithet = '-- subspectific epithet --' }
			else { $epithet = '-- epithet --' }
			
		}
	}
	$hiddens .= hidden(-name=>'designed', -id=>'designed')."\n";

	# Name search
	my ($xname, $slabel, $slabel2);
	$default = '-- scientific name --';
	$xname = textfield(
		-name=> 'sciname', 
		-id => 'sciname', 
		-autocomplete=>'off',
		-style=>'width: 670px;', 
		-value => param("sciname") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('nameID').value = ''; this.value = ''; clearName('$epithet');",
		-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyDown(document.getElementById('sciname').getAttribute('id'), event);
				}
				else { AutoComplete_HideDropdown(document.getElementById('sciname').getAttribute('id')); }",
		-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyUp(document.getElementById('sciname').getAttribute('id'), event);
				}
				else {
					function callServerScript() { 
						if(document.getElementById('sciname').value.length > 2) { 
							getThesaurusItems(['args__sciname', 'args__taxons', 'args__'+encodeURIComponent(document.getElementById('sciname').value), 'args__AND txn.ref_statut NOT IN (5,8,17,18,20,21,22)', 'NO_CACHE'], [setThesaurusItems]);
						} 
						else {  
							AutoComplete_HideDropdown(document.getElementById('sciname').getAttribute('id')); 
						}
					}
					typewatch(callServerScript, 500);
				}",
		-onBlur =>  "if(!this.value || !document.getElementById('nameID').value) { this.value = '$default' }"
	)."\n";

	#die join("\n", map { "$_ = ".param($_) } param());

	$default = '-- nomenclatural status --';
	$slabel = textfield(
		-name=> 'slabel', 
		-id => 'slabel', 
		-autocomplete=>'off',
		-style=>'width: 170px;', 
		-value => param("slabel") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' } getThesaurusItems(['args__slabel', 'args__labels', 'args__'+encodeURIComponent(this.value), 'args__', 'NO_CACHE'], [setThesaurusItems]); clearName('$epithet');",
		-onBlur =>  "if(!this.value) { this.value = '$default' }"
	)."\n";
	$slabel2 = textfield(
		-name=> 'slabel2', 
		-id => 'slabel2', 
		-autocomplete=>'off',
		-style=>'width: 170px;', 
		-value => param("slabel2") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' } getThesaurusItems(['args__slabel2', 'args__labels', 'args__'+encodeURIComponent(this.value), 'args__', 'NO_CACHE'], [setThesaurusItems]); clearSearchedName();",
		-onBlur =>  "if(!this.value) { this.value = '$default' }"
	)."\n";
	$xname .= $slabel;
		
	$hiddens .= hidden(-name=>'nameID', -id=>'nameID')."\n";
	
	# Name creation
	## Parent name
	my $xparent;
	if (param('parentTaxonID') and !param('parent')) {
		$default = param('parentTaxonID');
		param('parent', $default);
	}
	$default = '-- parent name --';
	$xparent = textfield(
		-name=> 'parent', 
		-id => 'parent', 
		-autocomplete=>'off',
		-style=>'width: 770px;', 
		-value => param("parent") || $default, 
		-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.nameForm.parentTaxonID.value = ''; document.nameForm.parentNameID.value = ''; document.nameForm.parentName.value = ''; document.nameForm.parentOrder.value = ''; this.value = ''; clearSearchedName(); testPreFill();",
		-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyDown(document.getElementById('parent').getAttribute('id'), event);
				}
				else { AutoComplete_HideDropdown(document.getElementById('parent').getAttribute('id')); }",
		-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
					return AutoComplete_KeyUp(document.getElementById('parent').getAttribute('id'), event);
				}
				else {
					function callServerScript() { 
						if(document.getElementById('parent').value.length > 2) { 
							getThesaurusItems(['args__parent', 'args__taxons', 'args__'+encodeURIComponent(document.getElementById('parent').value), 'args__AND ordre < $xorder AND txn.ref_statut NOT IN (8,17,18,21,22)', 'NO_CACHE'], [setThesaurusItems]);
						} 
						else {  
							AutoComplete_HideDropdown(document.getElementById('parent').getAttribute('id')); 
						}
					}
					typewatch(callServerScript, 500);
				}",
		-onBlur =>  "if(!this.value || !document.nameForm.parentTaxonID.value) { this.value = '$default' }"
	)."\n";
		
	$hiddens .= hidden(-name=>'parentTaxonID', -id=>'parentTaxonID')."\n";
	$hiddens .= hidden(-name=>'parentNameID', -id=>'parentNameID')."\n";
	$hiddens .= hidden(-name=>'parentName', -id=>'parentName')."\n";
	$hiddens .= hidden(-name=>'parentOrder', -id=>'parentOrder')."\n";
		
	## Name spelling
	my $xortograf = textfield(	-name=> 'spelling', 
					-id => 'spelling', 
					-autocomplete=>'off',
					-style=>'width: 523px;', 
					-value => param("spelling") || $epithet, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$epithet') { this.value = ''; } clearSearchedName();",
					-onBlur	 => "if (!this.value) { this.value = '$epithet'; } else if (document.nameForm.nameOrder.value < $speciesOrder) { this.value = this.value.capitalize(); }" )."\n";
	
	## Year
	$default = '-- year --';
	my $xyear = textfield(	-name=> 'year', 
				-id => 'year', 
				-autocomplete=>'off',
				-style=>'width: 65px;', 
				-maxlength=>4,
				-value => param("year") || $default, 
				-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedName();",
				-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
	
	## Authors
	my $nba = param('authors') || 1;	
	$hiddens .= hidden(-name=>'authors', -id=>'authors', -value=>$nba)."\n";	
		
	my $xauthors;
	for (my $i=1; $i<=$nba; $i++) {
		
		my $addAuthor;
		
		if($i == $nba) {
			$addAuthor = 	img({	-onClick=>"if (document.getElementById('type2').value == 0) { document.getElementById('p2Authors').value = $nba-1; } clearSearchedName(); document.nameForm.action = 'Names.pl?action=authorLess&target=name'; document.nameForm.submit();", 
						-src=>'/dbtntDocs/less.png',
						-onMouseOver=>"this.style.cursor = 'pointer';"}).
					img({	-onClick=>"if (document.getElementById('type2').value == 0) { document.getElementById('p2Authors').value = $nba+1; } clearSearchedName(); document.nameForm.action = 'Names.pl?action=authorMore&target=name'; document.nameForm.submit();", 
						-src=>'/dbtntDocs/more.png',
						-onMouseOver=>"this.style.cursor = 'pointer';"});
		}		
		
		$xauthors .= table({-cellspacing=>0, -cellpadding=>0},
				Tr(
					td( 
						textfield(
							-name=> "AFN$i", 
							-id => "AFN$i", 
							-autocomplete=>'off',
							-style=>'width: 200px;', 
							-value => param("AFN$i") || "-- author name --", 
							-onFocus  => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- author name --') { this.value = ''; } clearSearchedName();",
							-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyDown(document.getElementById('AFN$i').getAttribute('id'), event);
									}
									else { AutoComplete_HideDropdown(document.getElementById('AFN$i').getAttribute('id')); }",
							-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
										return AutoComplete_KeyUp(document.getElementById('AFN$i').getAttribute('id'), event);
									}
									else {
										function callServerScript() { 
											if(document.getElementById('AFN$i').value.length > 1) { 
												getThesaurusItems(['args__AFN$i', 'args__authors', 'args__'+encodeURIComponent(document.getElementById('AFN$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
											} 
											else {  
												AutoComplete_HideDropdown(document.getElementById('AFN$i').getAttribute('id')); 
											}
										}
										typewatch(callServerScript, 500);
									}",
							-onChange => "document.getElementById('ref_author$i').value = '';",
							-onBlur   => "if(!this.value || this.value == '-- author name --') { 	
										this.value = '-- author name --'; 
										document.nameForm.ALN$i.value = '-- author initials --'; 
										document.getElementById('ref_author$i').value = ''; 
									}
									else { this.value = this.value.capitalize(); }"
						)."\n"
					)."\n",
					td(
						textfield(
							-name=> "ALN$i", 
							-id => "ALN$i", 
							-autocomplete=>'off',
							-style=>'width: 200px;', 
							-value => param("ALN$i") || "-- author initials --", 
							-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- author initials --') { this.value = ''; } clearSearchedName();",
							-onChange => "document.getElementById('ref_author$i').value = '';",
							-onBlur =>  "if(!this.value) { this.value = '-- author initials --'; }"
						)."\n"
					)."\n",
					td(
						$addAuthor
					)."\n"
				)
			)."\n";
		
		$hiddens .= hidden(-name=>"ref_author$i", -id=>"ref_author$i")."\n";
	}
	
	## Fossils
	my $xfossil = 
	table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
		Tr(
			td( checkbox(-name=>'fossil', -id=>'fossil', -value=>1, -label=>'', -onFocus=>'AutoComplete_HideAll(); Reset_TabIndex();', -onClick=>'clearSearchedName();')."\n" )."\n",
			td( span({-style=>'color: navy; font-size: 13px;'}, 'fossil')."\n" )."\n"
		)."\n"
	)."\n"; 
	
	# PUBLICATIONS FIELDS
	my ($publications, $princeps);
	my %pubLabels = ( 1=>'Type designation publication' );
	my $i = 1;
	# 1 : type designation publication
	# 2 : taxon original publication
	# 3 : publication using a name
	# 4 : publication making a subsequent taxonomic act
	while ($i<5) {
		# Search
		my $clear;
		if ($i<3) { $clear = "clearSearchedName();" }
		my ($reference, $xreference, $xpubtype);
		my $default1 = '-- index --';
		my $default2 = '-- title --';
		$xreference = 
		table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
			Tr(
				td(
					textfield(
						-name=> "ref_pub$i", 
						-id => "ref_pub$i", 
						-autocomplete=>'off',
						-style=>'width: 75px;', 
						-value => param("ref_pub$i") || $default1, 
						-onFocus => "	AutoComplete_HideAll(); Reset_TabIndex(); this.value = ''; document.getElementById('pub$i').value = ''; document.getElementById('pub$i').tabIndex = '-$i'; clearPub($i); hidePub($i); $clear",
						-onKeyUp => "	if(event.keyCode != 9 && event.keyCode != 13 && event.keyCode != 27 && event.keyCode != 38 && event.keyCode != 40) {
									function callServerScript() { 
										getPublicationTitle(['args__$i', 'args__'+document.getElementById('ref_pub$i').value], [setPublicationTitle]); 
										document.getElementById('ref_pub$i').blur(); 
									} 
									typewatch(callServerScript, 1000);
								}",
						-onBlur =>  "	if(!this.value) { this.value = '$default1'; document.getElementById('pub$i').value = '$default2'; }
								else { getPublicationTitle(['args__$i', 'args__'+this.value], [setPublicationTitle]); }"
					)."\n"
				)."\n",
				td(
					textarea(
						-name=> "pub$i", 
						-id => "pub$i", 
						-autocomplete=>'off',
						-rows=>3,
						-style=>'width: 545px;', 
						-value => param("pub$i") || $default2, 
						-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('ref_pub$i').value = ''; this.value = ''; clearPub($i); hidePub($i); $clear",
						-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
									return AutoComplete_KeyDown(document.getElementById('pub$i').getAttribute('id'), event);
								}
								else { AutoComplete_HideDropdown(document.getElementById('pub$i').getAttribute('id')); }",
						-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
									return AutoComplete_KeyUp(document.getElementById('pub$i').getAttribute('id'), event);
								}
								else {
									function callServerScript() { 
										if(document.getElementById('pub$i').value.length > 2) { 
											getThesaurusItems(['args__pub$i', 'args__publications', 'args__'+encodeURIComponent(document.getElementById('pub$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
										} 
										else {  
											AutoComplete_HideDropdown(document.getElementById('pub$i').getAttribute('id')); 
										}
									}
									typewatch(callServerScript, 500);
								}",
						-onBlur =>  "if(!this.value || !document.getElementById('ref_pub$i').value) { this.value = '$default2', document.getElementById('ref_pub$i').value = '$default1'; };"
					)."\n"
				)."\n",
				td(
					img({	
						-onClick=>"clearSearchedName(); clearSearchedPub($i); hidePub($i); document.getElementById('type$i').value = 0; document.getElementById('newPub$i').value = 1; document.getElementById('pubCreateField$i').style.display = 'inherit'; /*reloadSearch();*/
								if ($i==2 && document.getElementById('type2').value == 0) { 
									document.getElementById('p2Authors').value = $nba; 
									var i = 1;
									while (i <= $nba) {
										if (document.getElementById('p2AFN'+i)) {
											document.getElementById('p2AFN'+i).value = document.getElementById('AFN'+i).value;
											document.getElementById('p2ALN'+i).value = document.getElementById('ALN'+i).value;
										}
										i++;
									}
								}", 
						-src=>'/dbtntDocs/more.png',
						-onMouseOver=>"this.style.cursor = 'pointer';"
					})."\n"
				)."\n"
			)."\n"
		)."\n";
			
		# Create
		## Publication type
		$xpubtype = popup_menu(	
			-name=>"type$i",
			-id=>"type$i",
			-values=>[sort { $pubTypes->{$a} cmp $pubTypes->{$b} } keys(%{$pubTypes})], 
			-labels=>$pubTypes, 
			-onFocus=>"AutoComplete_HideAll(); Reset_TabIndex(); clearSearchedPub($i);",
			-onChange=>"testPubType($i);",
			-style=>'display: inherit;'
		)."\n";
			
		## Title
		$default = '-- title --';
		$reference .= textfield(-name=> "title$i",
					-id => "title$i",
					-autocomplete=>'off',
					-style=>'width: 454px;', 
					-value => param("title$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' } else { this.value = this.value.capitalize(); }" )."\n";
		
		## Year
		$default = '-- year --';
		$reference .= textfield(-name=> "year$i", 
					-id => "year$i", 
					-autocomplete=>'off',
					-style=>'width: 65px;', 
					-maxlength=>4,
					-value => param("year$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
		
		## Volume
		$default = '-- vol --';
		$reference .= textfield(-name=> "vol$i", 
					-id => "vol$i", 
					-autocomplete=>'off',
					-style=>'width: 55px;', 
					-value => param("vol$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
	
		## Fascicule
		$default = '-- fasc --';
		$reference .= textfield(-name=> "fasc$i",
					-id => "fasc$i",
					-autocomplete=>'off',
					-style=>'width: 65px;', 
					-value => param("fasc$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
		
		## First page
		$default = '-- page --';
		$reference .= textfield(-name=> "FP$i", 
					-id => "FP$i", 
					-autocomplete=>'off',
					-style=>'width: 75px;', 
					-value => param("FP$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
		$reference .= "-\n";
		## Last page
		$default = '-- page --';
		$reference .= textfield(-name=> "LP$i", 
					-id => "LP$i", 
					-autocomplete=>'off',
					-style=>'width: 75px;', 
					-value => param("LP$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";
		
		$reference .= div({-style=>'height: 10px;', -id=>"optionIL$i"}, '');
		
		# Journal
		$default = '-- journal --';
		$reference .= table({-cellspacing=>0, -cellpadding=>0, -border=>0},
		Tr(
			td(
				textfield(
					-name=> "journal$i", 
					-id => "journal$i", 
					-autocomplete=>'off',
					-style=>'width: 650px;', 
					-value => param("journal$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' } clearSearchedPub($i);",
					-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
								return AutoComplete_KeyDown(document.getElementById('journal$i').getAttribute('id'), event);
							}
							else { AutoComplete_HideDropdown(document.getElementById('journal$i').getAttribute('id')); }",
					-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
								return AutoComplete_KeyUp(document.getElementById('journal$i').getAttribute('id'), event);
							}
							else {
								function callServerScript() { 
									if(document.getElementById('journal$i').value.length > 2) { 
										getThesaurusItems(['args__journal$i', 'args__journals', 'args__'+encodeURIComponent(document.getElementById('journal$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
									} 
									else {  
										AutoComplete_HideDropdown(document.getElementById('journal$i').getAttribute('id')); 
									}
								}
								typewatch(callServerScript, 500);
							}",
					-onChange=> "document.getElementById('journalID$i').value = '';",
					-onBlur =>  "if(!this.value) { this.value = '$default' } else { this.value = this.value.capitalize(); }"
				)."\n"
			)
			#td(
			#	a({-href=>'Publications.pl?action=fill&page=revue', -target=>'_blank', -id=>"newJournal$i"}, img({-src=>'/dbtntDocs/more.png'}))
			#)
		));
		
		$hiddens .= hidden(-name=>"journalID$i", -id=>"journalID$i")."\n";
						
		# Edition
		## Edition name
		$default = '-- edition name --';
		$reference .= textfield(
			-name=> "edition$i", 
			-id => "edition$i", 
			-autocomplete=>'off',
			-style=>'width: 454px;', 
			-value => param("edition$i") || $default, 
			-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' }  clearSearchedPub($i);",
			-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyDown(document.getElementById('edition$i').getAttribute('id'), event);
					}
					else { AutoComplete_HideDropdown(document.getElementById('edition$i').getAttribute('id')); }",
			-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyUp(document.getElementById('edition$i').getAttribute('id'), event);
					}
					else {
						function callServerScript() { 
							if(document.getElementById('edition$i').value.length > 2) { 
								getThesaurusItems(['args__edition$i', 'args__editions', 'args__'+encodeURIComponent(document.getElementById('edition$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
							} 
							else {  
								AutoComplete_HideDropdown(document.getElementById('edition$i').getAttribute('id')); 
							}
						}
						typewatch(callServerScript, 500);
					}",
			-onChange=> "document.getElementById('editionID$i').value = '';",
			-onBlur =>  "if(!this.value) {
						this.value = '$default';
						if (this.value == '-- edition name --') {
							document.getElementById('cityID$i').value = '';
							document.getElementById('stateID$i').value = '';
							document.getElementById('city$i').value = '-- edition city --';
							document.getElementById('state$i').value = '-- edition country --';
						}
					} else { this.value = this.value.capitalize(); }"
		)."\n";
		## Edition city
		$default = '-- edition city --';
		$reference .= textfield(
			-name=> "city$i", 
			-id => "city$i", 
			-autocomplete=>'off',
			-style=>'width: 150px;', 
			-value => param("city$i") || $default, 
			-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '$default') { this.value = '' } clearSearchedPub($i);",
			-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyDown(document.getElementById('city$i').getAttribute('id'), event);
					}
					else { AutoComplete_HideDropdown(document.getElementById('city$i').getAttribute('id')); }",
			-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyUp(document.getElementById('city$i').getAttribute('id'), event);
					}
					else {
						function callServerScript() { 
							if(document.getElementById('city$i').value.length > 2) { 
								getThesaurusItems(['args__city$i', 'args__cities', 'args__'+encodeURIComponent(document.getElementById('city$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
							} 
							else {  
								AutoComplete_HideDropdown(document.getElementById('city$i').getAttribute('id')); 
							}
						}
						typewatch(callServerScript, 500);
					}",
			-onChange=> "document.getElementById('cityID$i').value = '';",
			-onBlur =>  "if(!this.value) { this.value = '$default'; } else { this.value = this.value.capitalize(); }"
		)."\n";
		## Edition state
		$default = '-- edition country --';
		$reference .= textfield(
			-name=> "state$i", 
			-id => "state$i", 
			-autocomplete=>'off',
			-style=>'width: 190px;', 
			-value => param("state$i") || $default, 
			-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('stateID$i').value = ''; this.value = ''; clearSearchedPub($i);",
			-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyDown(document.getElementById('state$i').getAttribute('id'), event);
					}
					else { AutoComplete_HideDropdown(document.getElementById('state$i').getAttribute('id')); }",
			-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyUp(document.getElementById('state$i').getAttribute('id'), event);
					}
					else {
						function callServerScript() { 
							if(document.getElementById('state$i').value.length > 2) { 
								getThesaurusItems(['args__state$i', 'args__states', 'args__'+encodeURIComponent(document.getElementById('state$i').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
							} 
							else {  
								AutoComplete_HideDropdown(document.getElementById('state$i').getAttribute('id')); 
							}
						}
						typewatch(callServerScript, 500);
					}",
			-onChange=> "document.getElementById('stateID$i').value = ''; document.getElementById('state$i').value = '-- edition country --';",
			-onBlur =>  "if(!this.value) { this.value = '$default'; }"
		)."\n";
				
		$hiddens .= hidden(-name=>"editionID$i", -id=>"editionID$i")."\n";
		$hiddens .= hidden(-name=>"cityID$i", -id=>"cityID$i")."\n";
		$hiddens .= hidden(-name=>"stateID$i", -id=>"stateID$i")."\n";
		
		$reference .= $interligne;
		
		## Authors
		my $nbpa = param("p".$i."Authors") || 1;
				
		$hiddens .= hidden(-name=>"p".$i."Authors", -id=>"p".$i."Authors", -value=>$nbpa)."\n";	
			
		for (my $j=1; $j<=$nbpa; $j++) {
			
			my $addAuthor;
			
			if($j == $nbpa) {
				$addAuthor = 	img({	-onClick=>"clearSearchedPub($i); document.nameForm.action = 'Names.pl?action=authorLess&target=pub&n=$i'; document.nameForm.submit();", 
							-src=>'/dbtntDocs/less.png',
							-onMouseOver=>"this.style.cursor = 'pointer';"}).
						img({	-onClick=>"clearSearchedPub($i); document.nameForm.action = 'Names.pl?action=authorMore&target=pub&n=$i'; document.nameForm.submit();", 
							-src=>'/dbtntDocs/more.png',
							-onMouseOver=>"this.style.cursor = 'pointer';"});
			}		
			
			$reference .= table({-cellspacing=>0, -cellpadding=>0},
					Tr(
						td( 
							textfield(
								-name=> "p".$i."AFN$j", 
								-id => "p".$i."AFN$j", 
								-autocomplete=>'off',
								-style=>'width: 200px;', 
								-value => param("p".$i."AFN$j") || "-- author name --", 
								-onFocus  => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- author name --') { this.value = ''; } clearSearchedPub($i);",
								-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
											return AutoComplete_KeyDown(document.getElementById('p".$i."AFN$j').getAttribute('id'), event);
										}
										else { AutoComplete_HideDropdown(document.getElementById('p".$i."AFN$j').getAttribute('id')); }",
								-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
											return AutoComplete_KeyUp(document.getElementById('p".$i."AFN$j').getAttribute('id'), event);
										}
										else {
											function callServerScript() { 
												if(document.getElementById('p".$i."AFN$j').value.length > 1) { 
													getThesaurusItems(['args__p".$i."AFN$j', 'args__authors', 'args__'+encodeURIComponent(document.getElementById('p".$i."AFN$j').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
												} 
												else {  
													AutoComplete_HideDropdown(document.getElementById('p".$i."AFN$j').getAttribute('id')); 
												}
											}
											typewatch(callServerScript, 500);
										}",
								-onChange => "document.getElementById('p".$i."ref_author$j').value = '';",
								-onBlur   => "if(!this.value || this.value == '-- author name --') { 
											this.value = '-- author name --'; 
											document.nameForm.p".$i."ALN$j.value = '-- author initials --'; 
											document.getElementById('p".$i."ref_author$j').value = ''; 
										}
										else { this.value = this.value.capitalize(); }"
							)."\n"
						),
						td(
							textfield(
								-name=> "p".$i."ALN$j", 
								-id => "p".$i."ALN$j", 
								-autocomplete=>'off',
								-style=>'width: 200px;', 
								-value => param("p".$i."ALN$j") || "-- author initials --", 
								-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if(this.value == '-- author initials --') { this.value = ''; } clearSearchedPub($i);",
								-onChange => "document.getElementById('p".$i."ref_author$j').value = '';",
								-onBlur =>  "if(!this.value) { this.value = '-- author initials --'; }"
							)."\n"
						),
						td(
							$addAuthor
						)
					)
				)."\n";
						
			$hiddens .= hidden(-name=>"p".$i."ref_author$j", -id=>"p".$i."ref_author$j")."\n";
		}
		
		$reference .= $interligne;
		
		## Book reference (In book) 
		$default = '-- book --';
		$reference .= table({-cellspacing=>0, -cellpadding=>0},
			Tr(
				td(
					textfield(
						-name=> "book$i", 
						-id => "book$i", 
						-autocomplete=>'off',
						-style=>'width: 725px;', 
						-value => param("book$i") || $default, 
						-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); document.getElementById('ref_book$i').value = ''; this.value = ''; clearSearchedPub($i);",
						-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
									return AutoComplete_KeyDown(document.getElementById('book$i').getAttribute('id'), event);
								}
								else { AutoComplete_HideDropdown(document.getElementById('book$i').getAttribute('id')); }",
						-onKeyUp => "	
								if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
									return AutoComplete_KeyUp(document.getElementById('book$i').getAttribute('id'), event);
									alert(3);
								}
								else {
									function callServerScript() { 
										if(document.getElementById('book$i').value.length > 2) { 
											getThesaurusItems(['args__book$i', 'args__publications', 'args__'+encodeURIComponent(document.getElementById('book$i').value), 'args__AND ref_type_publication = 1', 'NO_CACHE'], [setThesaurusItems]);
										} 
										else {  
											AutoComplete_HideDropdown(document.getElementById('book$i').getAttribute('id')); 
										}
									}
									typewatch(callServerScript, 500);
								}",
						-onBlur =>  "if(!this.value || !document.getElementById('ref_book$i').value) { this.value = '$default' };"
					)
				),
				td(
					a({-href=>'Publications.pl?action=fill&page=pub&pubType=Book', -target=>'_blank', -id=>"newBook$i"}, img({-src=>'/dbtntDocs/more.png'}))
				)
			)
		)."\n";
		
		$hiddens .= hidden(-name=>"ref_book$i", -id=>"ref_book$i")."\n";
		
		## citation page
		$default = '-- citation page(s) --';
		my $page .= textfield(-name=> "page$i",
					-id => "page$i",
					-autocomplete=>'off',
					-style=>'width: 135px;',
					-class=>'pagep',
					-value => param("page$i") || $default, 
					-onFocus => "AutoComplete_HideAll(); Reset_TabIndex(); if (this.value == '$default') { this.value = '' }",
					-onBlur	 => "if (!this.value) { this.value = '$default' }" )."\n";	
	
		# Display elements in fieldsets tags
		my $disp = ($i == 1 and param('designation') == 1) ? 'inherit' : 'none';
		my $disp2 = param("newPub$i") ? 'inherit' : 'none';
		my $classL = ($i == 3 or $i == 4) ? 'padding0' : '';
		my $tmp = 
		"<FIELDSET class='round fieldset1' id='pubField$i' style='margin-top: 6px; display: $disp;'>\n".
			"<LEGEND class='round' id='pubLegend$i'>".$pubLabels{$i}."</LEGEND>\n".
			"<FIELDSET class='round fieldset2' id='pubSearchField$i' style='margin-bottom: 5px;'>\n".	
				"<LEGEND class='$classL'>Search</LEGEND>\n".
				$xreference.
			"</FIELDSET>\n".
			"<FIELDSET class='round fieldset2' id='pubCreateField$i' style='margin-bottom: 5px; display: $disp2;'>\n".	
				"<LEGEND class='$classL'>Create</LEGEND>\n".
				$xpubtype.
				div({-id=>"pubDiv$i"},
					$interligne,
					$reference
				).
			"</FIELDSET>\n".
			$page.
		"</FIELDSET>\n";
	
		if ($i == 3 or $i == 4) { $publications .= $tmp; }
		else { $princeps .= $tmp; }
		$hiddens .= hidden(-name=>"newPub$i", -id=>"newPub$i")."\n";
		$i++;
	}

	# Common hidden data
	$hiddens .= hidden(-name=>'action0', -name=>'action0', -value=>$action0)."\n";
	$hiddens .= hidden(-name=>'nameOrder', -id=>'nameOrder', -value=>$xorder)."\n";
	$hiddens .= hidden(-name=>'parentTaxonID0', -id=>'parentTaxonID0')."\n";
	$hiddens .= hidden(-name=>'taxonID0', -id=>'taxonID0')."\n";
	$hiddens .= hidden(-name=>'nameID0', -id=>'nameID0')."\n";
	$hiddens .= hidden(-name=>'statusID0', -id=>'statusID0')."\n";
	$hiddens .= hidden(-name=>'OID0', -id=>'OID0')."\n";
	$hiddens .= hidden(-name=>'homonymy', -id=>'homonymy')."\n";
	
	my $xreset;
	my $xerase;
	my $percent;
	if ($action0 eq 'insert') {}
	else {
		$xreset = td({-style=>'width: 22px; padding-left: 5px;'},
				img({
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleReset').innerHTML = 'Reset';", 
					-onMouseOut=>"document.getElementById('bulleReset').innerHTML = '';",
					-onClick=>"var url = window.location.toString(); url = url.replace(/&refresh=1/g,''); document.nameForm.action = url; document.nameForm.submit();", 
					-src=>'/dbtntDocs/clear.png'
				})
			).
			td({-id=>"bulleReset", -style=>'width: 100px; color: darkgreen;'}, '');

		$xerase = td({-style=>'width: 22px; padding-right: 5px;'},
				a({
					-href=>url()."?action=destroy&order=".$xorder."&OID0=".param('OID0'), 
					-onMouseover=>"document.getElementById('bulleDelete').innerHTML = 'Delete';", 
					-onMouseOut=>"document.getElementById('bulleDelete').innerHTML = '';",
					-onclick=>"javascript:return confirm('Please confirm:\\nThis action will delete the selected data and all associated data.\\nMake sure of the implications of this suppression.')"}, 
						img({-src=>'/dbtntDocs/delete.png'})
				)
			).
			td({-id=>"bulleDelete", -style=>'width: 60px; color: darkgreen;'}, '');
	}
	
	my $xreload = td({-style=>'width: 22px; padding-left: 5px;'},
				img({
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleReload').innerHTML = 'Refresh';", 
					-onMouseOut=>"document.getElementById('bulleReload').innerHTML = '';",
					-onClick=>"document.nameForm.action = window.location+'&refresh=1'; document.nameForm.submit();", 
					-src=>'/dbtntDocs/reload.png'
				})
			).
			td({-id=>"bulleReload", -style=>'width: 100px; color: darkgreen;'}, '');
		
	my $xsubmit = 	td({-style=>'width: 22px;'},
				img({	-src=>'/dbtntDocs/ok.png', 
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleSubmit').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleSubmit').innerHTML = '';",
					-onClick=>"verification();"
				})
			).
			td({-id=>"bulleSubmit", -style=>'width: 100px; color: darkgreen;'}, '');
	
	my $maindisp;
	if (param('statusID') eq '-- select --' or !param('statusID')) { $maindisp = 'none'; } else { $maindisp = 'inherit'; }
	
	$jscript .= $js . "\n";	
	$jscript .= "	function setPublicationTitle() { 
				var arr = arguments[0].split('_ARG_');
				if (arr[1]) {
					document.getElementById('pub'+arr[0]).value = arr[1];
				}
				else {
					document.getElementById('ref_pub'+arr[0]).value = '-- index --';
					document.getElementById('pub'+arr[0]).value = '-- title --';
				}
			}\n";

my $ninja .=<<EOC;
	<DIV 	class='wcenter' 
		onClick="
			var str = 'Hiddens:\\n';
			if (document.getElementById('action0') && document.getElementById('action0').value != '') { str += 'action0 = '+document.getElementById('action0').value + '\\n'; }
			if (document.getElementById('nameOrder') && document.getElementById('nameOrder').value != '') { str += 'nameOrder = '+document.getElementById('nameOrder').value + '\\n'; }
			if (document.getElementById('taxonID') && document.getElementById('taxonID').value != '') { str += 'taxonID = '+document.getElementById('taxonID').value + '\\n'; }
			if (document.getElementById('targetID') && document.getElementById('targetID').value != '') { str += 'targetID = ' + document.getElementById('targetID').value + '\\n'; }
			if (document.getElementById('nameID') && document.getElementById('nameID').value) { str += 'nameID = ' + document.getElementById('nameID').value + '\\n'; }
			if (document.getElementById('parentTaxonID') && document.getElementById('parentTaxonID').value != '') { str += 'parentTaxonID = ' + document.getElementById('parentTaxonID').value + '\\n'; }
			if (document.getElementById('parentNameID') && document.getElementById('parentNameID').value != '') { str += 'parentNameID = ' + document.getElementById('parentNameID').value + '\\n'; }
			if (document.getElementById('parentName') && document.getElementById('parentName').value != '') { str += 'parentName = ' + document.getElementById('parentName').value + '\\n'; }
			if (document.getElementById('parentOrder') && document.getElementById('parentOrder').value != '') { str += 'parentOrder = ' + document.getElementById('parentOrder').value + '\\n'; }
			
			if (document.getElementById('ref_author1') && document.getElementById('ref_author1').value != '') { str += 'ref_author1 = ' + document.getElementById('ref_author1').value + '\\n'; }
			if (document.getElementById('ref_author2') && document.getElementById('ref_author2').value != '') { str += 'ref_author2 = ' + document.getElementById('ref_author2').value + '\\n'; }
			
			if (document.getElementById('newPub1') && document.getElementById('newPub1').value != 0) { str += 'newPub1 = ' + document.getElementById('newPub1').value + '\\n'; }
			if (document.getElementById('ref_pub1') && document.getElementById('ref_pub1').value != '-- index --') { str += 'ref_pub1 = ' + document.getElementById('ref_pub1').value + '\\n'; }
			if (document.getElementById('p1ref_author1') && document.getElementById('p1ref_author1').value != '') { str += 'p1ref_author1 = ' + document.getElementById('p1ref_author1').value + '\\n'; }
			if (document.getElementById('p1ref_author2') && document.getElementById('p1ref_author2').value != '') { str += 'p1ref_author2 = ' + document.getElementById('p1ref_author2').value + '\\n'; }
			if (document.getElementById('journalID1') && document.getElementById('journalID1').value != '') { str += 'journalID1 = ' + document.getElementById('journalID1').value + '\\n'; }
			if (document.getElementById('editionID1') && document.getElementById('editionID1').value != '') { str += 'editionID1 = ' + document.getElementById('editionID1').value + '\\n'; }
			if (document.getElementById('cityID1') && document.getElementById('cityID1').value != '') { str += 'cityID1 = ' + document.getElementById('cityID1').value + '\\n'; }
			if (document.getElementById('stateID1') && document.getElementById('stateID1').value != '') { str += 'stateID1 = ' + document.getElementById('stateID1').value + '\\n'; }
			if (document.getElementById('ref_book1') && document.getElementById('ref_book1').value != '') { str += 'ref_book1 = ' + document.getElementById('ref_book1').value + '\\n'; }
			
			if (document.getElementById('newPub2') && document.getElementById('newPub2').value != 0) { str += 'newPub2 = ' + document.getElementById('newPub2').value + '\\n'; }
			if (document.getElementById('ref_pub2') && document.getElementById('ref_pub2').value != '-- index --') { str += 'ref_pub2 = ' + document.getElementById('ref_pub2').value + '\\n'; }
			if (document.getElementById('p2ref_author1') && document.getElementById('p2ref_author1').value != '') { str += 'p2ref_author1 = ' + document.getElementById('p2ref_author1').value + '\\n'; }
			if (document.getElementById('p2ref_author2') && document.getElementById('p2ref_author2').value != '') { str += 'p2ref_author2 = ' + document.getElementById('p2ref_author2').value + '\\n'; }
			if (document.getElementById('journalID2') && document.getElementById('journalID2').value != '') { str += 'journalID2 = ' + document.getElementById('journalID2').value + '\\n'; }
			if (document.getElementById('editionID2') && document.getElementById('editionID2').value != '') { str += 'editionID2 = ' + document.getElementById('editionID2').value + '\\n'; }
			if (document.getElementById('cityID2') && document.getElementById('cityID2').value != '') { str += 'cityID2 = ' + document.getElementById('cityID2').value + '\\n'; }
			if (document.getElementById('stateID2') && document.getElementById('stateID2').value != '') { str += 'stateID2 = ' + document.getElementById('stateID2').value + '\\n'; }
			if (document.getElementById('ref_book2') && document.getElementById('ref_book2').value != '') { str += 'ref_book2 = ' + document.getElementById('ref_book2').value + '\\n'; }
			
			if (document.getElementById('newPub3') && document.getElementById('newPub3').value != 0) { str += 'newPub3 = ' + document.getElementById('newPub3').value + '\\n'; }
			if (document.getElementById('ref_pub3') && document.getElementById('ref_pub3').value != '-- index --') { str += 'ref_pub3 = ' + document.getElementById('ref_pub3').value + '\\n'; }
			if (document.getElementById('p3ref_author1') && document.getElementById('p3ref_author1').value != '') { str += 'p3ref_author1 = ' + document.getElementById('p3ref_author1').value + '\\n'; }
			if (document.getElementById('p3ref_author2') && document.getElementById('p3ref_author2').value != '') { str += 'p3ref_author2 = ' + document.getElementById('p3ref_author2').value + '\\n'; }
			if (document.getElementById('journalID3') && document.getElementById('journalID3').value != '') { str += 'journalID3 = ' + document.getElementById('journalID3').value + '\\n'; }
			if (document.getElementById('editionID3') && document.getElementById('editionID3').value != '') { str += 'editionID3 = ' + document.getElementById('editionID3').value + '\\n'; }
			if (document.getElementById('cityID3') && document.getElementById('cityID3').value != '') { str += 'cityID3 = ' + document.getElementById('cityID3').value + '\\n'; }
			if (document.getElementById('stateID3') && document.getElementById('stateID3').value != '') { str += 'stateID3 = ' + document.getElementById('stateID3').value + '\\n'; }
			if (document.getElementById('ref_book3') && document.getElementById('ref_book3').value != '') { str += 'ref_book3 = ' + document.getElementById('ref_book3').value + '\\n'; }
			
			if (document.getElementById('newPub4') && document.getElementById('newPub4').value != 0) { str += 'newPub4 = ' + document.getElementById('newPub4').value + '\\n'; }
			if (document.getElementById('ref_pub4') && document.getElementById('ref_pub4').value != '-- index --') { str += 'ref_pub4 = ' + document.getElementById('ref_pub4').value + '\\n'; }
			if (document.getElementById('p4ref_author1') && document.getElementById('p4ref_author1').value != '') { str += 'p4ref_author1 = ' + document.getElementById('p4ref_author1').value + '\\n'; }
			if (document.getElementById('p4ref_author2') && document.getElementById('p4ref_author2').value != '') { str += 'p4ref_author2 = ' + document.getElementById('p4ref_author2').value + '\\n'; }
			if (document.getElementById('journalID4') && document.getElementById('journalID4').value != '') { str += 'journalID4 = ' + document.getElementById('journalID4').value + '\\n'; }
			if (document.getElementById('editionID4') && document.getElementById('editionID4').value != '') { str += 'editionID4 = ' + document.getElementById('editionID4').value + '\\n'; }
			if (document.getElementById('cityID4') && document.getElementById('cityID4').value != '') { str += 'cityID4 = ' + document.getElementById('cityID4').value + '\\n'; }
			if (document.getElementById('stateID4') && document.getElementById('stateID4').value != '') { str += 'stateID4 = ' + document.getElementById('stateID4').value + '\\n'; }
			if (document.getElementById('ref_book4') && document.getElementById('ref_book4').value != '') { str += 'ref_book4 = ' + document.getElementById('ref_book4').value + '\\n'; }
			alert(str);
		" 
		style='margin-bottom: 10px;'>
		< Hiddens revelations >
	</DIV>
EOC

	$html .=		
	"<HTML>".
	"<HEAD>".
	"\n	<TITLE>Scientific name</TITLE>".
	"\n	<STYLE TYPE='text/css'>$css</style>".
	"\n	<SCRIPT TYPE='text/javascript' SRC='/dbtntDocs/SearchMultiValue.js'></SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>$jscript</SCRIPT>".
	"</HEAD>".
	"<BODY ONLOAD=\"testStatement(document.getElementById('statusID'));\">".
	$maintitle.
	#$ninja.	
	start_form(-name=>'nameForm', -method=>'post').
	"<FIELDSET class='wcenter round' style='margin-bottom: 10px;'>\n".	
		"<LEGEND class='round'>Statement</LEGEND>\n".
		$xstatut.
		a({-href=>url()."?action=get&template=1&nameOrder=".param('nameOrder'), -style=>'margin-left: 25px; text-decoration: none; color: #444444;'}, 'Use a template').
	"</FIELDSET>\n".
	"<FIELDSET class='wcenter round' id='mainField' style='padding-top: 15px; display: $maindisp;'>\n".
		"<LEGEND class='round' id='mainLegend'></LEGEND>\n".
		"<FIELDSET class='round fieldset1' id='targetField' style='margin-bottom: 10px;'>\n".	
			"<LEGEND class='round' id='targetLegend'></LEGEND>\n".
			$xtaxon.
		"</FIELDSET>\n".
		$ntaxon.
		"<FIELDSET class='round fieldset1' id='nameField' style='margin-bottom: 10px;'>\n".	
			"<LEGEND class='round' id='nameLegend'></LEGEND>\n".
			"<FIELDSET class='round fieldset2' id='nameSearchField' style='margin-bottom: 5px; border-left: 1px #888888 solid; border-top: 1px #888888 solid;'>\n".	
				"<LEGEND>Search</LEGEND>\n".
				$xname.
			"</FIELDSET>\n".
			"<FIELDSET class='round fieldset2' id='nameCreateField' style='margin-bottom: 5px; border-left: 1px #888888 solid; border-top: 1px #888888 solid;'>\n".	
				"<LEGEND>$actlabel</LEGEND>\n".
				$xparent.
				$interligne."\n".
				table({-cellspacing=>0, -cellpadding=>0, -style=>'display: inherit;'},
					Tr(
						td({-style=>'padding-right: 6px;'}, $xortograf)."\n",
						td({-style=>'padding-right: 6px;'}, $slabel2)."\n"
					)."\n"
				)."\n".
				$interligne."\n".
				$xyear.
				$interligne."\n".
				$xauthors.
				$interligne."\n".
				$xbrackets.
				$xtype.
				$xfossil.
				$princeps.
			"</FIELDSET>\n".
		"</FIELDSET>\n".
		$publications.
		"<FIELDSET class='round fieldset1' style='margin-top: 10px;'>\n".	
			"<LEGEND class='round'>Remarks</LEGEND>\n".
			$remarks.
		"</FIELDSET>\n".
		$hiddens.
		table({style=>'width: 900px; margin-top: 5px;', border=>0}, $xreload.td().$xsubmit.td().$xreset.td().$xerase).
	"</FIELDSET>\n".
	end_form().
	div({-class=>'wcenter', -id=>'waiting', -style=>'display: none; text-decoration: blink;'}, 'Loading...').
	#join(br, map { "$_ = ".param($_) } param()).
	div({-style=>'color: red; width: 100px; margin: auto;'}, $testDisplay).
	"</BODY>".
	"</HTML>";
	
	print $pjx->build_html($cgi, $html, {-charset=>'UTF-8'});
}

### NAME FORM FIELDS ####
#-----------------------#
# action0               #
# statusID + 0          #
# OID0                  #
#-----------------------#
#--- Taxon & Target ----#
#-----------------------#
# taxon                 #
# taxonID + 0           #
# targetID              #
# tlabel                #
#-----------------------#
#--- Existing name -----#
#-----------------------#
# sciname               #
# nameID + 0            #
# slabel                #
#-----------------------#
#------ New name -------#
#-----------------------#
# nameOrder             #
# parent                #
# parentTaxonID + 0     #
# parentNameID          #
# parentName            #
# parentOrder           #
# spelling              #
# year                  #
# brackets              #
# slabel2               #
# fossil                #
# gentype               #
# designation           #
# designed              #
#                       #
# authors               #
# AFN($i)               #
# ALN($i)               #
# ref_author($i)        #
#-----------------------#
#---  Publications  ----#
#-----------------------#
# $i=1 designation ref  #
# $i=2 princeps ref     #
# $i=3 using ref        #
# $i=4 denouncing ref   #
#-----------------------#
# pub($i)               #
# ref_pub($i)           #
#                       #
# newPub($i)            #
# type($i)              #
# title($i)             #
# year($i)              #
# vol($i)               #
# fasc($i)              #
# FP($i)                #
# LP($i)                #
# journal($i)           #
# journalID($i)         #
# edition($i)           #
# editionID($i)         #
# city($i)              #
# cityID($i)            #
# state($i)             #
# stateID($i)           #
#                       #
# p($i)Authors          #
# p($i)AFN($j)          #
# p($i)ALN($j)          #
# p($i)ref_author($j)   #
#                       #
# book($i)              #
# ref_book($i)          #
#                       #
# page($i)              #
#-----------------------#
# remarks		#
#-----------------------#
