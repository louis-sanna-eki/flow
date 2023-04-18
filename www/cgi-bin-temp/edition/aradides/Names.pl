#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/aradides/â€˜}
use strict;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use HTML_func qw (html_header html_footer  arg_persist);
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row request_bind);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel);
use DBTNTAuthors qw ($authorsJscript makeAuthorsfields AonFocus add_author);
use DBTNTcommons qw (pub_formating get_pub_params);

my $dbc = db_connection(get_connection_params($conf_file));

my $user = remote_user();

if (url_param('action') eq 'fill') { 
		
	if ( url_param('page') eq 'sciname' ) { print name_form(); }
}

elsif (url_param('action') eq 'verify') { 
		
	my $verif = verification($dbc);
	
	if ( $verif eq 'ok') { 

		print name_pubs_form();
	}
	else { print name_form($verif); }
}

elsif (url_param('action') eq 'enter') {

	if (url_param('page') eq 'sciname') { 
		
		my $authorsid = get_authors_id();
		
		my $eval = add_sciname($authorsid);
		
		whatsnext($eval);
	}
}

elsif (url_param('action') eq 'maj') {

	if (url_param('page') eq 'sciname') { 
		
		my $authorsid = get_authors_id();
						
		update_sciname($authorsid);
	}
	elsif ( url_param('page') eq 'dependances' ) {
		
		treat_dependances();
	}
}

elsif (url_param('action') eq 'loop') {

	redirection(url_param('type'));
}

elsif (url_param('action') eq 'get') {
	
	my $ranksinfo = request_hash("SELECT index, ordre, en FROM rangs;", $dbc, 'en');
	
	my $gorder = $ranksinfo->{'genus'}->{'ordre'};

	my $searchstr = '*';

	if (param('nameOrder') > $gorder) { $searchstr = param('genusX') . '[^\\\s]* .*' }
	elsif (param('nameOrder') == $gorder) { $searchstr = param('genusX') . '[^\\\s]*' }
	elsif (param('nameOrder') < $gorder) { $searchstr = '[^\\\s]*' }

	search_names($dbc, $searchstr, param('nameOrder'));
}

elsif (url_param('action') eq 'update') {
	
	my $ranksinfo = request_hash("SELECT index, ordre, en FROM rangs;", $dbc, 'en');
	
	my $gorder = $ranksinfo->{'genus'}->{'ordre'};
	
	get_name_data(url_param('oldtaxon'), url_param('oldname'), url_param('oldstatusid'), url_param('oldstatus'), url_param('oldcible'), url_param('oldhigh'), url_param('pub'));
	
	param('oldtaxon', url_param('oldtaxon'));
	param('oldname', url_param('oldname'));
	param('oldstatusid', url_param('oldstatusid'));
	param('oldstatus', url_param('oldstatus'));
	param('oldcible', url_param('oldcible'));
	param('oldhigh', url_param('oldhigh'));
	param('oldusage', url_param('pub'));
	
	print name_form();
}

$dbc->disconnect;

sub get_name_data {
	
	my ($oldtax, $oldname, $oldstatid, $oldstat, $oldcible, $oldhigh, $pub) = @_;
		
	my $params1 = request_tab("	SELECT n.orthographe, n.annee, r.ordre, n.parentheses, n.ref_nom_parent, n.ref_publication_princeps, n.gen_type, fossil
					FROM noms as n 
					LEFT JOIN rangs AS r ON r.index = n.ref_rang
					WHERE n.index = $oldname", $dbc, 2);
	
	param('sciname', $params1->[0][0]);
	param('nameyear', $params1->[0][1]);
	param('nameOrder', $params1->[0][2]);
	param('parentheses', $params1->[0][3]);
	if ($params1->[0][6]) { param('old_type', $params1->[0][6]) }
	if ($params1->[0][7]) { param('old_fossil', $params1->[0][7]) }
	
	if ($params1->[0][4]) {
		
		my $parent = request_tab("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $params1->[0][4]", $dbc, 1);
		
		if ($parent->[0]) { param('highname', $params1->[0][4].'/'.$parent->[0]) }
		else { param('highname', $params1->[0][4].'/NULL') } 
	}
	else {
		my $hightax = request_tab("SELECT ref_taxon_parent FROM taxons WHERE index = " . param('oldtaxon'), $dbc, 1);
		
		my $highname;
		
		if ($hightax->[0]) { $highname = request_tab("SELECT ref_nom FROM taxons_x_noms WHERE ref_taxon = $hightax->[0] AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid');", $dbc, 1); }
		
		param('highname', $highname->[0].'/'.$hightax->[0]);
	}
	
	my $authors = request_tab("	SELECT a.nom, a.prenom FROM auteurs as a
					LEFT JOIN noms_x_auteurs as nxa ON a.index = nxa.ref_auteur
					WHERE nxa.ref_nom = $oldname
					ORDER BY nxa.position", $dbc, 2);
	
	my $i=1;
	foreach (@{$authors}) {
		
		param("nameAFN$i",$_->[0]);
		param("nameALN$i",$_->[1]);
		
		$i++;
	}
	
	if ($i-1) { param('namenbauts', $i-1) }
	
	if ($oldstat) {
	
		if ($oldstat ne 'valid' and $oldstat ne 'correct use' and $oldstat ne 'misidentification' and $oldstat ne 'dead end') {
			
			my $pubtest;
			if ($pub) { $pubtest = "AND txn.ref_publication_utilisant = $pub" }
			
			my $req = "	SELECT txn.ref_nom_cible, txn.ref_publication_denonciation, n.orthographe, r.ordre
					FROM taxons_x_noms as txn
					LEFT JOIN noms AS n ON n.index = txn.ref_nom_cible
					LEFT JOIN rangs AS r ON r.index = n.ref_rang
					WHERE txn.ref_taxon = $oldtax
					AND txn.ref_nom = $oldname
					$pubtest
					AND txn.ref_statut = (SELECT index FROM statuts WHERE en = '$oldstat')";
			
			my $valid = request_tab($req, $dbc, 2);
			
			param('validname', $valid->[0][2]);
						
			my $hash = getTaxa($valid->[0][2], $valid->[0][3], $valid->[0][0]);
			my ($vtax) = keys(%{$hash});
			param('validtaxon', $vtax);
			
			if ($oldstat eq 'wrong spelling' or $oldstat eq 'previous identification') {
				param('firstpubid', $pub);
			} else {
				param('firstpubid', $params1->[0][5]);
			}
			param('denoncepubid', $valid->[0][1]);
		}
		else {
			param('validname', $params1->[0][0]);
			param('validtaxon', $oldname.'/'.$oldtax);
			
			if ($oldstat eq 'misidentification') {
				param('firstpubid', $pub);
				my $req = "	SELECT txn.ref_publication_denonciation
						FROM taxons_x_noms as txn
						WHERE txn.ref_taxon = $oldtax
						AND txn.ref_nom = $oldname
						AND txn.ref_publication_utilisant = $pub
						AND txn.ref_statut = (SELECT index FROM statuts WHERE en = '$oldstat')";
						
				my ($denon) = @{request_tab($req, $dbc, 1)};
				param('denoncepubid', $denon);
			}			
			elsif ($oldstat eq 'correct use') { param('firstpubid', $pub) }
			else { param('firstpubid', $params1->[0][5]) }
		}
		
		param('namestatus', $oldstat) 
	}

}

sub redirection {

	my ($type) = @_;
	
	my $to;
	
	#die join(br, map { "$_ = ".param($_) } param());
	
	my $rank = param('nameOrder');
	my $high = param('highname');
	my $genusx;
	if (param('genusX')) { $genusx = param('genusX'); }
	my $status = param('namestatus');
	my $validname = param('validname');
	my $validtaxon = param('validtaxon');
	
	if ($type eq 'bnwoh') {
		
		Delete(param());
		
		param('nameOrder', $rank);
		
		$to = "typeSelect.pl?action=add&type=sciname";
		
	}
	elsif ($type eq 'nwoh') {
						
		Delete(param());
		
		param('nameOrder', $rank);
		
		$to = "Names.pl?action=fill&page=sciname";
		
	}
	elsif ($type eq 'nwh') {
		
		Delete(param());
		
		param('nameOrder', $rank);
		if($genusx) { param('genusX', $genusx) }
		param('highname', $high);
	
		$to = "Names.pl?action=fill&page=sciname";
	}
	elsif ($type eq 'nwhas') {

		Delete(param());
		
		param('nameOrder', $rank);
		if($genusx) { param('genusX', $genusx) }
		param('highname', $high);
		param('namestatus', $status);
		param('validname', $validname);
		param('validtaxon', $validtaxon);		
		
		$to = "Names.pl?action=fill&page=sciname";
	}
	elsif ($type eq 't') {

		Delete('genusX', 'highname');		
		
		$to = "typeSelect.pl?action=add&type=sciname";
	}
	elsif ($type eq 'c') {

		Delete('firstpubid');		
		
		$to = "Names.pl?action=verify";
	}
	else { die 'No target specified' }
	
	my %Hash = ( 	css => $css,
			bgcolor => $background,
			onLoad => "document.tmpform.action = '$to'; document.tmpform.submit();" );
	
	print html_header(\%Hash), start_form(-name=>'tmpform', -method=>'post',-action=>''), arg_persist(), end_form(), html_footer();

}

sub whatsnext {
	
	my ($eval) = @_;
		
	my $content;
	
	if ($eval eq 'ok') {
		
		$content = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}) . p . span({-style=>'font-size: 15px; color: green;'}, "Scientific name treated") . br . br . br;
						
	}
	else {
		
		$content = 	img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . span({-style=>'color: crimson; font-size: 15px;'}, $eval) . br . br .

				start_form(-name=>'backform', -method=>'post').
						
					arg_persist().
					
					a(	{-onMouseover=>"nameBack.src=eval('backonimg.src')",
						-onMouseout=>"nameBack.src=eval('backoffimg.src')",
						-onClick=>"backform.action = 'Names.pl?action=fill&page=sciname'; backform.submit();"},
					
						img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
					).
					
				end_form() . br . br;
	}
		
	my $status = param('namestatus');
	my $higher = param('highnameid');
	my $r = param('nameOrder');
	my $taxid = param('taxonid') || param('validtaxonid');
	
	my ($highn, $higha) = @{request_tab("SELECT orthographe, autorite FROM noms_complets WHERE index = $higher", $dbc, 1)};
	my ($rank) = @{request_tab("SELECT en FROM rangs WHERE ordre = $r", $dbc, 1)};
	
	my $nametab = request_tab("SELECT orthographe, autorite FROM noms_complets WHERE index = " . param('scinameid'), $dbc, 2);
	my ($name, $authority) = ($nametab->[0][0], $nametab->[0][1]);
	
	my (@labels, @targets);
	
	if ($status eq 'correct use' or $status eq 'misidentification') {
						
		push(@labels, "Enter another $rank $status of $name $authority");
		
		push(@targets, "Names.pl?action=loop&type=c"); # => page 3
		
	}
	else {
						
		
		push(@labels, "Enter another $rank in $highn $higha");
		push(@labels, "Enter another $rank");			
			
		if ( param('nameOrder') > param('gorder') ) { 
			push(@targets, "Names.pl?action=loop&type=nwh"); # nom < genre avec higher taxon => page 2
			push(@targets, "Names.pl?action=loop&type=bnwoh"); # nom < genre sans higher taxon => page 1
		}
		else {
			push(@targets, "Names.pl?action=loop&type=nwh"); # nom > genre avec higher taxon => page 2
			push(@targets, "Names.pl?action=loop&type=nwoh"); # nom > genre sans higher taxon => page 2
		}
	}
	
	my $links;
	for (my $i=0; $i<scalar(@labels); $i++) {
		
		$links .= a({-style=>'color: blue;', -onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"nextform.action = '$targets[$i]'; nextform.submit();"}, $labels[$i]). br. br;
	}
	
	$content .= 	start_form(-name=>'nextform', -method=>'post').
			
				arg_persist().
			
				$links.										
			
			end_form().
			
			br.
			
			div(	a({ -href=>"taxonXcountries.pl?action=fill&taxonX=$taxid", -style=>'text-decoration: none;' }, "Enter $name $authority geographic distribution"),
				p,
				a({ -href=>"taxonXhp.pl?action=fill&taxonX=$taxid", -style=>'text-decoration: none;' }, "Enter $name $authority host plants")
			).

			br.
			
			div(	a({ -href=>"typeSelect.pl?action=add&type=sciname", -style=>'text-decoration: none;' }, "Enter another scientific name"),
				p,
				a({ -href=>"typeSelect.pl?action=add&type=all", -style=>'text-decoration: none;' }, "Enter another data"),
				p,
				a({ -href=>"action.pl", -style=>'text-decoration: none;' }, "Main menu"),
			).
			
			br;
	
	my %headerHash = (
		titre => 'Next step',
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs
	);
	
	print 	html_header(\%headerHash),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>'wcenter'},
			
			br, br,
			
			#join(br, map { "$_ = ".param($_) } param()), br,br, 
			
			$content,
					
			start_form(-name=>'wnform', -method=>'post',-action=>''),
			
			arg_persist(),
		
			end_form()
		),
		
		html_footer();
}

sub add_sciname {
	
	my ($authors) = @_;
	
	my $eval;
	
	my $author = $authors->[0];
	
	my ($status, $sciname, $annee, $parentheses, $order, $princeps, $utilise, $denonce, $rankid);
	
	my $statusid;
	$status = param("namestatus");
	($statusid) = @{ request_tab("SELECT index FROM statuts where en = '$status'",$dbc,1) };
		
	my $nameid;
	my $ncible = param('validnameid') || 'NULL';
		
	# Teste si le nom existe déjà
	unless ($nameid = param('scinameid') or $nameid = testpreexistence()) {
		
		my @nfields;
		my @nvals;
		
		if ($status eq 'wrong spelling') { ($princeps) = @{request_tab("SELECT ref_publication_princeps FROM noms WHERE index = $ncible", $dbc, 1)} }
		else { $princeps = param('firstpubid'); }
		
		if ($princeps) {
		
			push(@nvals, "$princeps");
			push(@nfields, "ref_publication_princeps");
		}
		
		if (param('gen_type')) {
		
                        push(@nvals, "true");
	                push(@nfields, "gen_type");
		}
		
		if (param('fossil')) {
		
                        push(@nvals, "true");
	                push(@nfields, "fossil");
		}
		
		push(@nvals, "'$user'");
		push(@nfields, "createur");
		
		push(@nvals, "'$user'");
		push(@nfields, "modificateur");
		
		my $fieldsstr = param('nfields');
		my $valuesstr = param('nvalues');
		
		if (scalar(@nfields)) {
			$fieldsstr .= ", ".join(', ', @nfields);
			$valuesstr .= ", ".join(', ', @nvals);
		}
		
		my $ireq = "INSERT INTO noms (index, $fieldsstr) VALUES (default, $valuesstr)";
		
		my $sth = $dbc->prepare($ireq) or die "$ireq: ".$dbc->errstr;
		
		$sth->execute() or die "$ireq: ".$dbc->errstr;
		
		my $mreq = "SELECT MAX(index) FROM noms;";
		
		($nameid) = @{request_tab($mreq, $dbc, 1)};
		
		bind_authors_to_name($nameid, $authors);
	}
		
	($rankid) = @{request_tab("SELECT ref_rang FROM noms WHERE index = $nameid", $dbc, 1)};
	
	Delete('scinameid'); param('scinameid', $nameid);
	
	# Teste si le nom n'a pas déjà ce statut nomenclatural
	if ($status eq 'valid') {
		
		my $req = "SELECT count(*) FROM taxons_x_noms WHERE ref_nom = $nameid AND ref_statut = $statusid;";
		
		my ($test) = @{request_tab($req, $dbc, 1)};
		
		unless ($test) {
			
			my $taxonid;
			
			my $hightaxon = param('hightaxonid');
			
			$req = "INSERT INTO taxons (index, ref_taxon_parent, ref_rang, createur, modificateur) VALUES (default, $hightaxon, $rankid, '$user', '$user')";
					
			my $sth = $dbc->prepare($req) or die "$req: $dbc->errstr";
			
			$sth->execute() or die "$req: $dbc->errstr";
			
			$req = "SELECT MAX(index) FROM taxons;";
			
			my ($taxonid) = @{request_tab($req, $dbc, 1)};
			
			param('taxonid', $taxonid);
		}
		else { $eval = "This name is already a valid name"; }
	}
	else {
		
		unless ( param('taxonid') ) { param('taxonid', param('validtaxonid')); }
		my $taxonid = param('taxonid');
		my $op;
		if ($ncible eq 'NULL') { $op = 'is' } else { $op = '=' }
		
		my $req;
		$req = "SELECT count(*) FROM taxons_x_noms WHERE ref_nom = $nameid AND ref_taxon = $taxonid AND ref_nom_cible $op $ncible AND ref_statut = $statusid";
		
		if ( $status eq 'correct use' or $status eq 'wrong spelling' or $status eq 'misidentification' or $status eq 'previous identification' ) {
			
			$req .= " AND ref_publication_utilisant = ".param('firstpubid');
		}
				
		my ($test) = @{request_tab($req, $dbc, 1)};
		if ($test) {  $eval = "This data is already in the database"; }

	}
	
	my $taxid = param('taxonid');
	
	#fields and values for taxons_x_noms table
	my @txnfields;
	my @txnvals;

	unless ($eval) { 
		
		push(@txnvals, $statusid);
		push(@txnfields, "ref_statut");
		
		push(@txnvals, $taxid);
		push(@txnfields, "ref_taxon");
		
		push(@txnvals, $nameid);
		push(@txnfields, "ref_nom");
						
		push(@txnvals, "'$user'");
		push(@txnfields, "createur");
		
		push(@txnvals, "'$user'");
		push(@txnfields, "modificateur");

		unless ($status eq 'valid') {
						
			push(@txnvals, $ncible);
			push(@txnfields, "ref_nom_cible");
			
			if (param('firstpubid')) {
				push(@txnvals, param('firstpubid'));
				push(@txnfields, "ref_publication_utilisant");
			}
					
			if (param('denoncepubid')) {
				push(@txnvals, param('denoncepubid'));
				push(@txnfields, "ref_publication_denonciation");
			}
		}
		
		my $req = "INSERT INTO taxons_x_noms (".join(', ', @txnfields).") VALUES (".join(', ', @txnvals).")";
						
		my $sth = $dbc->prepare($req) or die "$req \n @txnvals";
		
		$sth->execute() or die "$req \n @txnvals";
		
		$eval = 'ok'
	}
	
	return $eval;
	
}

sub taxon_dependances {

	my ($oldtaxon, $newtaxon) = @_;
	
	#my %tables = {
		#'taxons_x_regions_biogeo' => ['ref_region_biogeo'],
		#'taxons_x_regions' => [''],
		#'taxons_x_pays' => [''],
		#'taxons_x_localites' => [''],
		#'taxons_x_plantes' => [''],
		#'taxons_x_periodes' => [''],
		#'taxons_x_images' => ['']
	#};
	#foreach (keys(%tables)) {}
	
	my $req = "UPDATE taxons_x_regions_biogeo SET ref_taxon = $newtaxon, modificateur = '$user' WHERE ref_taxon = $oldtaxon;";
	
	my $sth = $dbc->prepare($req) or die "$req";
	
	$sth->execute() or die "$req";
	
	my $req = "UPDATE taxons_x_pays SET ref_taxon = $newtaxon, modificateur = '$user' WHERE ref_taxon = $oldtaxon;";
	
	my $sth = $dbc->prepare($req) or die "$req";
	
	$sth->execute() or die "$req";
	
	$req = "UPDATE taxons_x_plantes SET ref_taxon = $newtaxon, modificateur = '$user' WHERE ref_taxon = $oldtaxon;";
	
	my $sth = $dbc->prepare($req) or die "$req";
	
	$sth->execute() or die "$req";

	$req = "UPDATE taxons_x_periodes SET ref_taxon = $newtaxon, modificateur = '$user' WHERE ref_taxon = $oldtaxon;";

        my $sth = $dbc->prepare($req) or die "$req";

        $sth->execute() or die "$req";

}

sub treat_dependances {
	
	my $oldname = param('oldname');
	my $oldtaxon = param('oldtaxon');
	my $oldstatus = param('oldstatus');
	my $oldstatusid = param('oldstatusid');
	my $oldcible = param('oldcible') || 'NULL';
	my $oldusage = param('oldusage') || 'NULL';
	my $olddenonce = param('olddenonce') || 'NULL';
	
	my $newname = testpreexistence() || $oldname;
	my $newtaxon = param('validtaxonid') || $oldtaxon;
	my $newstatus = param('namestatus');
	my ($newstatusid) = @{ request_tab("SELECT index FROM statuts where en = '$newstatus'",$dbc,1) };
	my $newcible = param('validnameid') || 'NULL';
	my $newusage = param('firstpubid') || 'NULL';
	my $newdenonce = param('denoncepubid') || 'NULL';
	
	my ($opoc, $opnc);
	if ($oldcible eq 'NULL') { $opoc = 'IS' } else { $opoc = '=' }
	
	my $req = "UPDATE taxons_x_noms SET ref_taxon = $newtaxon, ref_nom = $newname, ref_statut = $newstatusid, ref_nom_cible = $newcible, modificateur = '$user'
			WHERE ref_taxon = $oldtaxon AND ref_nom = $oldname AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible;";
	
	my $sth = $dbc->prepare($req) or die "$req";
	
	$sth->execute() or die "$req";
	
	#my $i = 0;
	#while (param("ref_taxon$i")) {
		
		#my $t = param("ref_taxon$i");
		#my $n = param("ref_nom$i");
		#my $c = param("ref_cible$i") || 'NULL';
		#my $s = param("ref_statut$i");
		#my $ps;
		#if (param("pubd$i")) { $ps = ", ref_publication_denonciation = $pd" } else { $ps = ", ref_publication_denonciation = NULL" }
		#if (param("pubu$i")) { $ps = ", ref_publication_utilisant = $pu") } else { $ps = ", ref_publication_utilisant = NULL" }
		
		#my $op;
		#if ($c ne 'NULL') { $op = '=' } else { $op = 'IS' }
		
		$req = "UPDATE taxons_x_noms SET ref_taxon = $newtaxon, modificateur = '$user' WHERE ref_taxon = $oldtaxon;";
		
		$sth = $dbc->prepare($req) or die "$req";
		
		$sth->execute() or die "$req";
		
		#$i++;
	#}
	
	if ($oldtaxon != $newtaxon) { taxon_dependances($oldtaxon, $newtaxon); }
	
	my $dreq = "DELETE FROM taxons WHERE index = $oldtaxon";
					
	$sth = $dbc->prepare($dreq) or die "$dreq";
	
	$sth->execute() or die "$dreq";
	
	$dreq = 	"DELETE FROM taxons WHERE index not in (SELECT DISTINCT ref_taxon FROM taxons_x_noms);";
	$sth = $dbc->prepare($dreq) or die "$dreq";
	$sth->execute() or die "$dreq";
	
	$dreq =		"DELETE FROM noms_x_auteurs
			WHERE ref_nom IN (SELECT index FROM noms 
					WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
					AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
					AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
	$sth = $dbc->prepare($dreq) or die "$dreq";
	$sth->execute() or die "$dreq";
					
	$dreq =		"DELETE FROM noms_complets
			WHERE index IN (SELECT index FROM noms_complets 
					WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
					AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
					AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
	$sth = $dbc->prepare($dreq) or die "$dreq";
	$sth->execute() or die "$dreq";

	$dreq =		"DELETE FROM noms
			WHERE index IN (SELECT index FROM noms 
					WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
					AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
					AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
	
	$sth = $dbc->prepare($dreq) or die "$dreq";
	$sth->execute() or die "$dreq";
	
	my %headerHash = (
		titre => "Modification done",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my ($genusx) = @{request_tab("SELECT orthographe FROM noms_complets WHERE index = " . param('highnameid'), $dbc, 1)};
	
	my $nametab = request_tab("SELECT orthographe, autorite FROM noms_complets WHERE index = $newname", $dbc, 2);
	my ($name, $authority) = ($nametab->[0][0], $nametab->[0][1]);
	
	print 	html_header(\%headerHash),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		#join(br, map { "$_ = ".param($_) } param()),
			
		div({-class=>"wcenter"},
			
			img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}) . p . span({-style=>'color: green'}, "Modification done"), p, br,
			
			start_form(-name=>'backform', -method=>'post'),
				
			hidden('genusX', $genusx),
			hidden('nameOrder'),
			
			a({	-onMouseover=>"nameBack.src=eval('backonimg.src')",
				-onMouseout=>"nameBack.src=eval('backoffimg.src')",
				-onClick=>"backform.action = 'Names.pl?action=get&page=sciname'; backform.submit();"},
					
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
			),
			
			end_form(), br, br,

			a({ -href=>"taxonXcountries.pl?action=fill&taxonX=$newtaxon", -style=>'text-decoration: none;' }, "Enter $name $authority geographic distribution"),
			br, br,
			a({ -href=>"taxonXhp.pl?action=fill&taxonX=$newtaxon", -style=>'text-decoration: none;' }, "Enter $name $authority host plants"),
			br, br,
			a({ -href=>"typeSelect.pl?action=update&type=all", -style=>'text-decoration: none;' }, "Update another data"), 
			p, br,
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;'}, 
				img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		),
	
		html_footer();
}

sub makeStatusRelation {

	my ($synonyme, $i, $cible) = @_;
	
	my $default;
	my $label;
	my $status = param("statut$i");
	
#	if(param("treatp$i")) {
#		Delete("treatp$i");
#		if (param("pub$i")) { Delete("pub$i"); }
#		$default = param('searchPubId');
#		Delete('searchPubId');
#		$label  = span({-style=>'color: #FF6633;'}, "according to ") . div({-id=>"label$i", -style=>'display: inline;'}, 
#		pub_formating(get_pub_params($dbc, $default), 'html')) . br . br;
#	}
#	elsif (param("pubd$i")) {
#		$label  = span({-style=>'color: #FF6633;'}, "according to ") . div({-id=>"label$i", -style=>'display: inline;'}, 
#		pub_formating(get_pub_params($dbc, param("pubd$i")), 'html')) . br . br;
#	}
#	elsif (param("pubu$i")) {
#		$label  = span({-style=>'color: #FF6633;'}, "according to ") . div({-id=>"label$i", -style=>'display: inline;'}, 
#		pub_formating(get_pub_params($dbc, param("pubu$i")), 'html')) . br . br;
#	}
#	else { $label = br }
	
	my $term;
	if ($status eq 'nomen praeoccupatum') { $term = span({-style=>'color: #555555;'}, ' replaced by nomen novum &nbsp;'); }
	elsif ($status eq 'nomen oblitum') { $term = span({-style=>'color: #555555;'}, ', synonym of &nbsp;'); }
	elsif ($status eq 'dead end') { $term = span({-style=>'color: #555555;'}, ' related to &nbsp;'); }
	elsif ($status eq 'correct use' or $status eq 'misidentification') { $cible = ''; }	
	else { $term = span({-style=>'color: #555555;'}, ' of &nbsp;'); }
	
	my $cs = span({-style=>'color: crimson;'}, $status);
	
	return 	span({-style=>'padding-right: 10px; font-size: 15px; font-style: italic;'}, $synonyme).
		"$cs $term " . span({-style=>'font-size: 15px; font-style: italic;'}, $cible) . br . br;
}

sub update_sciname {
	
	my ($authors) = @_;
	
	my $eval;
	
	my $author = $authors->[0];
	
	my ($annee, $parentheses, $order, $utilise, $denonce, $rankid);
	
	my $oldname = param('oldname');
	my $oldtaxon = param('oldtaxon');
	my $oldstatus = param('oldstatus');
	my $oldstatusid = param('oldstatusid');
	my $oldcible = param('oldcible') || 'NULL';
	my $oldusage = param('oldusage') || 'NULL';
	my $olddenonce = param('olddenonce') || 'NULL';
	my $oldtype = param('old_type') || 'NULL';
	my $oldfossil = param('old_fossil') || 'NULL';
	my $oldhigh = param('oldhigh');

	my $preex = testpreexistence();
	unless ($oldusage) { param('oldusage', 'NULL'); $oldusage = 'NULL'; }
	unless ($olddenonce) { param('olddenonce', 'NULL'); $olddenonce = 'NULL'; }
	
	my $newname = $preex || $oldname;
	my $newtaxon = param('validtaxonid') || $oldtaxon;
	my $newstatus = param('namestatus');
	my ($newstatusid) = @{ request_tab("SELECT index FROM statuts where en = '$newstatus'",$dbc,1) };
	my $newcible = param('validnameid') || 'NULL';
	my $newusage = param('firstpubid') || 'NULL';
	my $newdenonce = param('denoncepubid') || 'NULL';
	my $newtype = param('gen_type') || 'NULL';
	my $newfossil = param('fossil') || 'NULL';
	my $newhigh = param('highnameid') || 'NULL';
	
	my $hightaxon = param('hightaxonid');
	my ($rankid) = @{ request_tab("SELECT index FROM rangs where ordre = ".param('nameOrder'), $dbc, 1) };
			
	my $case = 0;
	
	my ($opoc, $opnc, $opou, $opod, $opnu, $opnd);
	if ($oldcible eq 'NULL') { $opoc = 'IS' } else { $opoc = '=' }
	if ($newcible eq 'NULL') { $opnc = 'IS' } else { $opnc = '=' }
	if ($oldusage eq 'NULL') { $opou = 'IS' } else { $opou = '=' }
	if ($olddenonce eq 'NULL') { $opod = 'IS' } else { $opod = '=' }
	if ($newusage eq 'NULL') { $opnu = 'IS' } else { $opnu = '=' }
	if ($newdenonce eq 'NULL') { $opnd = 'IS' } else { $opnd = '=' }
	my $use;
	if ($newstatus eq 'correct use' or $newstatus eq 'misidentification' or $newstatus eq 'wrong spelling' or $newstatus eq 'previous identification') { $use = "AND ref_publication_utilisant $opnu $newusage" }
	
	unless (param('erase') and param('confirm')) {	
			
		my $req = "SELECT count(*) FROM taxons_x_noms WHERE ref_nom = $newname AND ref_taxon = $newtaxon AND ref_nom_cible $opnc $newcible AND ref_statut = $newstatusid AND ref_publication_denonciation $opnd $newdenonce $use";
				
		my ($test) = @{ request_tab($req, $dbc, 1) };
	
		#die "$req => $test";

		if ($test) {
			
			if (!$preex or $oldusage != $newusage or $oldtype != $newtype  or $oldfossil != $newfossil or $oldhigh != $newhigh) { $test = 0 }
		}
		
		#die "!$preex or $oldusage != $newusage or $oldtype != $newtype  or $oldfossil != $newfossil or $oldhigh != $newhigh ==> $test";
		
		unless ( $test ) {
			
			#fields and values for noms table
			my @nfields = split(',', param('nfields'));
			my @nvalues = split(',', param('nvalues'));
			
			if ($newstatus eq 'wrong spelling') { 
				my ($princeps) = @{request_tab("SELECT ref_publication_princeps FROM noms WHERE index = $newcible", $dbc, 1)};
				push(@nfields, 'ref_publication_princeps');
				push(@nvalues, $princeps);
			}
			elsif ( $newusage ) {
				
				push(@nfields, 'ref_publication_princeps');
				push(@nvalues, $newusage);
			}


			push(@nfields, 'gen_type');
			if ( $newtype ne 'NULL' ) { push(@nvalues, "true"); }
		       	else { push(@nvalues, $newtype); }
			
			push(@nfields, 'fossil');
			if ( $newfossil ne 'NULL' ) { push(@nvalues, "true"); }
		       	else { push(@nvalues, $newfossil); }
						
			push(@nvalues, "'$user'");
			push(@nfields, "modificateur");
			
			if ($newstatus ne 'correct use' and $newstatus ne 'misidentification' and $newstatus ne 'previous identification') {
			
				my @fandv;
				for (my $i=0; $i<scalar(@nfields); $i++) { push(@fandv, "$nfields[$i] = $nvalues[$i]")  }
							
				# Mise a jour du nom et de tous les binoms contenant ce nom
				my $ireq = "UPDATE noms SET ".join(',', @fandv)." WHERE index = $newname;";
				my $iireq = "UPDATE noms SET ref_nom_parent = $newname, modificateur = '$user' WHERE ref_nom_parent = $newname;";
				
				my $sth = $dbc->prepare($ireq) or die "$ireq";
				$sth->execute() or die "$ireq ".$dbc->errstr;
				
				$sth = $dbc->prepare($iireq) or die "$iireq";
				$sth->execute() or die "$iireq ".$dbc->errstr;
				
				my $dreq = "DELETE FROM noms_x_auteurs WHERE ref_nom = $newname";
							
				my $sth = $dbc->prepare($dreq) or die "$dreq";
				
				$sth->execute() or die "$ireq ".$dbc->errstr;
				
				bind_authors_to_name($newname, $authors);
			}
			
			my $pubs;
			if ($newusage ne 'NULL' and $newstatus ne 'valid') { $pubs .= ", ref_publication_utilisant = $newusage" } else { $pubs .= ", ref_publication_utilisant = NULL" }
			if ($newdenonce ne 'NULL') { $pubs .= ", ref_publication_denonciation = $newdenonce" } else { $pubs .= ", ref_publication_denonciation = NULL" }
			my $pubtest;
			if ($oldstatus eq 'correct use' or $oldstatus eq 'misidentification' or $oldstatus eq 'wrong spelling' or $oldstatus eq 'previous identification') { $pubtest = "AND ref_publication_utilisant $opou $oldusage" }
			
			my $req = "UPDATE taxons_x_noms SET ref_nom = $oldname, modificateur = '$user' $pubs WHERE ref_nom = $oldname AND ref_taxon = $oldtaxon AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible $pubtest;";
		
			my $sth = $dbc->prepare($req) or die "couldn't prepare $req";
			
			$sth->execute() or die "$req";
		
			if ($oldstatus eq 'valid') {
				
				if ($newstatus eq 'valid' and $oldname == $newname) {
					
					my $req =  "UPDATE taxons SET ref_taxon_parent = $hightaxon, modificateur = '$user' WHERE index = $oldtaxon;";
					
					my $sth = $dbc->prepare($req) or die "$req";
					
					$sth->execute() or die "$req";
					
					$case = 1;
				}
				elsif ($newstatus eq 'correct use' or $newstatus eq 'misidentification' or $newstatus eq 'previous identification') {
					
					$case = 4;
				}
				elsif ($newstatus ne 'valid') {
					
					if ($newtaxon == $oldtaxon) { $case = 2; }
					else {
						my $req = "SELECT ref_nom, ref_statut, nc.orthographe, nc.autorite, en, ref_publication_denonciation, ref_taxon,
								ref_nom_cible, ref_publication_utilisant, n2.orthographe, n2.autorite
								FROM taxons_x_noms AS txn
								LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
								LEFT JOIN statuts AS s ON s.index = txn.ref_statut
								LEFT JOIN noms_complets AS n2 ON n2.index = txn.ref_nom_cible
								WHERE ref_taxon in ($oldtaxon, $newtaxon) AND ref_statut != $oldstatusid
								ORDER BY ref_statut, nc.orthographe;";
						
						my $synonymes = request_tab($req, $dbc, 2);
						
						#$req = "SELECT index, en FROM statuts WHERE en not in ('valid') ORDER BY en;";
						
						#my $statuts = request_tab($req,$dbc,2);
						
						my $relations;
						
						my $i=0;
						
						my $nametab = request_tab("SELECT orthographe, autorite FROM noms_complets WHERE index = $newname", $dbc, 2);
						my ($name, $authority) = ($nametab->[0][0], $nametab->[0][1]);
																		
						foreach my $relation (@{$synonymes}) {
							
							#my $statutsList;
							#foreach my $element (@{$statuts}) {
							#	my $selected;
							#	if ($element->[0] eq $relation->[1]) { $selected = 'SELECTED' } else { $selected = '' }
							#	$statutsList .= "<OPTION VALUE='$element->[0]' $selected CLASS='PopupStyle' STYLE='text-align: center;'> $element->[1]";
							#}
							#unless (param("ref_nom$i")) { param("ref_nom$i", $relation->[0]) }
							#unless (param("ref_taxon$i")) { param("ref_taxon$i", $relation->[6]) }
							#unless (param("ref_cible$i")) { param("ref_cible$i", $relation->[7]) }
							#unless (param("ref_statut$i")) { param("ref_statut$i", $relation->[1]) }
							
							unless (param("pubu$i")) { param("pubu$i", $relation->[8]) }
							unless (param("pubd$i")) { param("pubd$i", $relation->[5]) }
							unless (param("statut$i")) { param("statut$i", $relation->[4]) }
							
							$relations .=  makeStatusRelation("$relation->[2] $relation->[3]", $i, "$relation->[9] $relation->[10]");
							$i++;
						}
															
						if ($relations) {
							$relations = span({-style=>'font-weight: bold;'}, "Other related names :"). p. br.
							
							$relations;		
						
						}
						
						my %headerHash = (
							titre => "Taxon overview",
							bgcolor => $background,
							css => $css,
							jscript => $jscript_imgs . $jscript_for_hidden,
						);
						
						my $vlabel = param('vlabel');
						
						my $term;						
						if ($newstatus eq 'nomen praeoccupatum') { $term = span({-style=>'color: #555555;'}, ' replaced by nomen novum &nbsp;'); }
						elsif ($newstatus eq 'nomen oblitum') { $term = span({-style=>'color: #555555;'}, ', synonym of &nbsp;'); }
						elsif ($newstatus eq 'dead end') { $term = span({-style=>'color: #555555;'}, ' related to &nbsp;'); }
						else { $term = span({-style=>'color: #555555;'}, 'of &nbsp;'); }
						
						my $cs = span({-style=>'color: crimson;'}, $newstatus);
						
						print 	html_header(\%headerHash),
						
							#join(br, map { "$_ = ".param($_) } param()),
							
							div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
							
							div({-class=>"wcenter"},
							
							table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
								Tr(
									td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
									td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Taxon overview"),
									td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
								)
							),
							
							start_form(-name=>'depForm', -method=>'post',-action=>''),
													
							span({-style=>'font-size: 15px;'}, span({-style=>'font-style: italic;'}, "$name $authority") . "&nbsp; $cs $term $vlabel"), p, br,
							
							$relations,
							
							arg_persist(),
														
							p, br,
							
							span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
								-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
								-onClick=>"depForm.action = 'Names.pl?action=maj&page=dependances'; depForm.submit();"
								},
								img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
							),
							
							end_form(),
							
							p, br,
							
							a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;' }, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
							),
							
							html_footer();
					}
				}
				else {
					$case = 2;
				}
			}
			elsif ($oldstatus ne 'valid' and  $oldstatus ne 'correct use' and  $oldstatus ne 'misidentification' and  $oldstatus ne 'previous identification') {
			
				if ($newstatus ne 'valid') {
					
					if($newstatus ne 'correct use' and $newstatus ne 'misidentification' and  $newstatus ne 'previous identification') {
						
						if ($oldtaxon != $newtaxon) {
							
							# TODO: dependances par nom_cible et par usage du nom
							
							my $req = "UPDATE taxons_x_noms SET ref_taxon = $newtaxon, ref_nom = $newname, ref_statut = $newstatusid, ref_nom_cible = $newcible, modificateur = '$user'
									WHERE ref_taxon = $oldtaxon AND ref_nom = $oldname AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible;";
							
							my $sth = $dbc->prepare($req) or die "$req";
							
							$sth->execute() or die "$req";
							
							$case = 7;
						}
						else {
							my $req = "UPDATE taxons_x_noms SET ref_taxon = $newtaxon, ref_nom = $newname, ref_statut = $newstatusid, ref_nom_cible = $newcible, modificateur = '$user'
									WHERE ref_taxon = $oldtaxon AND ref_nom = $oldname AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible;";
							
							my $sth = $dbc->prepare($req) or die "$req";
							
							$sth->execute() or die "$req";
							
							$case = 1;					
						}
					}
					else { $case = 4 }
				}
				elsif ($newstatus eq 'valid') {
								
					my $req = "SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom = $newname AND ref_statut = $newstatusid;";
					
					my ($test) = @{request_tab($req, $dbc, 1)};
					
					unless ($test) {
					
						# TODO: dependances par nom_cible et par usage du nom
										
						$req = "INSERT INTO taxons (index, ref_taxon_parent, ref_rang, createur, modificateur) VALUES (default, $hightaxon, $nvalues[0], '$user', '$user')";
						
						my $sth = $dbc->prepare($req) or die "$req";
						
						$sth->execute() or die "$req";
						
						$req = "SELECT currval('taxons_index_seq');";
						
						my ($taxonid) = @{request_tab($req, $dbc, 1)};
						
						param('validtaxonid', $taxonid);
								
						$req = "UPDATE taxons_x_noms SET ref_nom = $newname, ref_taxon = $taxonid, ref_statut = $newstatusid, ref_nom_cible = NULL, modificateur = '$user'
							WHERE ref_nom = $oldname AND ref_taxon = $oldtaxon AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible;";
						
						my $sth = $dbc->prepare($req) or die "$req";
						
						$sth->execute() or die "$req";
						
						$case = 7;
					}
					else { $case = 3 }
				}
			}
			elsif ($oldstatus eq 'correct use' ) {
				if ($newstatus eq 'correct use' and $oldtaxon == $newtaxon and $oldname == $newname) { $case = 1 }
				else { $case = 2 }
			}
			elsif ($oldstatus eq 'misidentification' ) {
				if ($newstatus eq 'misidentification' and $oldtaxon == $newtaxon and $oldname == $newname) { $case = 1 }
				else { $case = 2 }
			}
			elsif ($oldstatus eq 'previous identification' ) {
				if ($newstatus eq 'previous identification' and $oldtaxon == $newtaxon and $oldname == $newname) { $case = 1 }
				else { $case = 2 }
			}
			else { $case = 4 }
		}
		else { $case = 3 }
	}
	else { 
		
		if ($oldstatus ne 'valid') {
			
			my $req = "DELETE FROM taxons_x_noms WHERE ref_nom = $oldname AND ref_taxon = $oldtaxon AND ref_statut = $oldstatusid AND ref_nom_cible $opoc $oldcible AND ref_publication_denonciation $opod $olddenonce AND ref_publication_utilisant $opou $oldusage;";
			
			my $sth = $dbc->prepare($req) or die "$req";
						
			$sth->execute() or die "$req";
			
			$case = 5;
		} else {
			$case = 6;
		}
	}
	
	if ($case) {
		my $done = 0;
		my ($titre, $sentence);
		if ($case == 1) {
			$titre = "Modification done";
			$sentence = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}) . p . span({-style=>'color: green'}, "Modification done");
			$done = 1;
		}
		elsif ($case == 2) {
			$titre = "Modification impossible";
			$sentence = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . span({-style=>'color: crimson'}, "Modification not allowed. Delete this name and recreate it with the right status.");
		}
		elsif ($case == 3) {
			$titre = "Modification impossible";
			$sentence = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . span({-style=>'color: crimson'}, "This name already exists");
		}
		elsif ($case == 4) {
			$titre = "Modification impossible";
			$sentence = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . span({-style=>'color: crimson'}, "Modification from $oldstatus to $newstatus not allowed.");
		}
		elsif ($case == 5) {
			$titre = "Modification done";
			$sentence = img({-border=>0, -src=>'/Editor/done.jpg', -name=>"done" , -alt=>"DONE"}) . p . span({-style=>'color: green'}, "The relationship taxon/name has been erased.");
			$done = 1;
		}
		elsif ($case == 6) {
			$titre = "Modification impossible";
			$sentence = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . span({-style=>'color: crimson'}, "A valid name can't be erased only modified.");
		}
		elsif ($case == 7) {
			$titre = "Modification done";
			$sentence = img({-border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"CAUTION"}) . p . span({-style=>'color: brown'}, "Modification done. <br><br> You have moved a name from a taxon to another one, make sure that this name does not appear any more in his former taxon.");
			$done = 1;
		}
		
		if ($done) {
			
			my $dreq = 	"DELETE FROM taxons WHERE index not in (SELECT DISTINCT ref_taxon FROM taxons_x_noms);";
			my $sth = $dbc->prepare($dreq) or die "$dreq";
			$sth->execute() or die "$dreq";
			
			$dreq =		"DELETE FROM noms_x_auteurs
					WHERE ref_nom IN (SELECT index FROM noms 
							WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
							AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
							AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
			$sth = $dbc->prepare($dreq) or die "$dreq";
			$sth->execute() or die "$dreq";
							
			$dreq =		"DELETE FROM noms_complets
					WHERE index IN (SELECT index FROM noms_complets 
							WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
							AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
							AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
			$sth = $dbc->prepare($dreq) or die "$dreq";
			$sth->execute() or die "$dreq";

			$dreq =		"DELETE FROM noms
					WHERE index IN (SELECT index FROM noms 
							WHERE index NOT IN (SELECT DISTINCT ref_nom FROM taxons_x_noms)
							AND index NOT IN (SELECT DISTINCT ref_nom_cible FROM taxons_x_noms WHERE ref_nom_cible IS NOT NULL)
							AND index NOT IN (SELECT DISTINCT ref_nom_parent FROM noms WHERE ref_nom_parent IS NOT NULL));";
			
			$sth = $dbc->prepare($dreq) or die "$dreq";
			$sth->execute() or die "$dreq";
		}
		
		my %headerHash = (
			titre => $titre,
			bgcolor => $background,
			css => $css,
			jscript => $jscript_imgs . $jscript_for_hidden,
		);
				
		my $nametab = request_tab("SELECT orthographe, autorite FROM noms_complets WHERE index = $newname", $dbc, 2);
		my ($name, $authority) = ($nametab->[0][0], $nametab->[0][1]);

		my $genusx;
		if (param('nameOrder') > param('gorder')) {
			($genusx) = @{request_tab("SELECT orthographe FROM noms_complets WHERE index = " . param('highnameid'), $dbc, 1)};
		}
		else { $genusx = $name }
		
		my $nexts;
		unless ($case == 5) {
		
			$nexts = a({ -href=>"taxonXcountries.pl?action=fill&taxonX=$newtaxon", -style=>'text-decoration: none;'}, "Enter $name $authority geographic distribution").
				br. br.
				a({ -href=>"taxonXhp.pl?action=fill&taxonX=$newtaxon", -style=>'text-decoration: none;'}, "Enter $name $authority host plants").
				br. br;
		}
		
		print 	html_header(\%headerHash),
			
			div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
			
			div({-class=>"wcenter"}, p,

				#join(br, map { "$_ = ".param($_) } param()), p,

				span({-style=>'font-size: 15px;'}, $sentence), p, br,
				
				start_form(-name=>'backform', -method=>'post'),
				
				hidden('genusX', $genusx),
				hidden('nameOrder'),
				
				a({	-onMouseover=>"nameBack.src=eval('backonimg.src')",
					-onMouseout=>"nameBack.src=eval('backoffimg.src')",
					-onClick=>"backform.action = 'Names.pl?action=get&page=sciname'; backform.submit();"},
						
					img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
				),
				
				end_form(), br, br,
				
				$nexts,
				
				a({ -href=>"typeSelect.pl?action=update&type=all", -style=>'text-decoration: none;'}, "Update another data"), p, br,
				
				a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;'}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
			),
			
			html_footer();
	}
}

sub bind_authors_to_name {

	my ($nameid, $authors) = @_;
		
	my $i=1;
	foreach (@{$authors}) {
		
		my $count =  request_tab("SELECT count(*) FROM noms_x_auteurs WHERE ref_nom = $nameid AND position = $i",$dbc,1);
		
		unless ($count->[0]) { 
			
			my $sth = $dbc->prepare( "INSERT INTO noms_x_auteurs (ref_nom, ref_auteur, position) VALUES ($nameid, $_, $i);" ) or die $dbc->errstr;

			$sth->execute() or die $dbc->errstr;
		}
				
		$i++;
	}
}

# teste la preexistence d'un nom de la table noms
sub testpreexistence {
	
	#fields and values for noms table
	my @nfields;
	my @nvals;
		
	my $order = param("nameOrder");
	my ($rankid) = @{ request_tab("SELECT index FROM rangs WHERE ordre = $order",$dbc,1) };
	push(@nvals, "$rankid");
	push(@nfields, "ref_rang");
		
	my $sciname = param("sciname");
	$sciname =~ s/'/\\'/g;
	push(@nvals, "'$sciname'");
	push(@nfields, "orthographe");
	
	my $annee = param("nameyear");
	push(@nvals, $annee);
	push(@nfields, "annee");
	
	if (param("parentheses")) { push(@nvals, "true"); }
	else { push(@nvals, "'f'"); }
	push(@nfields, "parentheses");

	if (my $high = param('highnameid') and param('nameOrder') > param('gorder')) {

		push(@nvals, $high);
		push(@nfields, "ref_nom_parent");
	}
	
	Delete('nfields'); param('nfields', join(', ', @nfields));
	Delete('nvalues'); param('nvalues', join(', ', @nvals));

	my $req = "	SELECT n.index FROM noms AS n 
			WHERE (".param('nfields').") = (".param('nvalues').")";

	# Look if the name already exists
	my $already = 0;
	my $alreadies = request_tab($req,$dbc,1);

	if (scalar @{$alreadies}) {
		
		while (!$already and my $id = shift @{$alreadies}) {
			$req = "SELECT a.nom, a.prenom FROM auteurs AS a LEFT JOIN noms_x_auteurs AS na ON na.ref_auteur = a.index WHERE na.ref_nom = $id ORDER BY na.position";
			
			my $authors = request_tab($req,$dbc,2);
			$already = $id;
			
			my $i=0;
			my $j=1;
			
			while (param("nameAFN$j") and $already) {
				my $nom = param("nameAFN$j");
				my $prenom = param("nameALN$j");
				unless ( $nom eq $authors->[$i][0] and $prenom eq $authors->[$i][1] ) { $already = 0 }
				$i++;
				$j++;
			}
			if ($already and $authors->[$i][0]) { $already = 0 }
		}
	}
	
	return $already;
}


sub clear_pub_params {
		
	my $i=1;
	while (param("pubAFN$i")) { Delete("pubAFN$i"); Delete("pubALN$i"); $i++; }
	
	Delete ("pubtitle");
	Delete ("pubyear");
	Delete ("pubpgdeb");
	Delete ("pubpgfin");
	Delete ("pubnbauts");
	
	my $type = param('pubType');
	
	if ($type eq 'Article') { Delete("pubrevue"); Delete("pubvol"); Delete("pubfasc"); }
	elsif ($type eq 'Book') { Delete("pubedition"); Delete("pubvol"); }
	elsif ($type eq 'Thesis') { Delete("pubedition"); }
	elsif ($type eq 'In book') { Delete("bookid"); }
	
	Delete ("pubType");
	
}

sub name_pubs_form {

	my $persist = arg_persist();
	Delete('scinameid');
	
	clear_pub_params();
	
	my $html;
	
	my ($sciname, $namestatus, $nameyear);
	$sciname = param('sciname');
	$namestatus = param('namestatus');
	$nameyear;
       	if (param('nameyear') and param('nameyear') ne 'NULL') {
       		$nameyear = param('nameyear');
	}
	
	my $firstpub;
	my $denoncepub;
	
	#die join(br, map { "$_ = ".param($_) } param());
	
	if (param('treatFP')) {
		Delete('treatFP');
		Delete('firstpubid');
		$firstpub = param('searchPubId');
		Delete('searchPubId');
	}
	elsif (param('treatDP')) {
		Delete('treatDP');
		Delete('denoncepubid');
		$denoncepub = param('searchPubId');
		Delete('searchPubId');
	}
	
	if (param('firstpubid')) { 
		$firstpub = param('firstpubid'); 
		Delete('firstpubid');
	}
	
	if (param('action') eq 'update' and !param('oldusage')) {
		if ($firstpub) { param('oldusage', $firstpub) }
		else { param('oldusage', 'NULL') }
	}
	
	if (param('denoncepubid')) { 
		$denoncepub = param('denoncepubid'); 
		Delete('denoncepubid'); 
	}	
	
	if (param('action') eq 'update' and !param('olddenonce')) {
		if ($denoncepub) { param('olddenonce', $denoncepub) }
		else { param('olddenonce', 'NULL') }
	}
	
	# Make scientific name string
	my $preex;
	
	my @scinameparts;
	if (my $highname = param('highname')) {
		
		my ($nameid, $taxonid) = split(/\//,"$highname",2);
		
		Delete('highnameid'); param('highnameid', $nameid);
		Delete('hightaxonid'); param('hightaxonid', $taxonid);
				
		my ($highstr) = @{request_tab("SELECT orthographe FROM noms_complets WHERE index = $nameid", $dbc, 1)};
		
		if ( param('nameOrder') > param('gorder') ){ push(@scinameparts, $highstr); }
	}
	else {
		Delete('highnameid'); param('highnameid', 'null');
		Delete('hightaxonid'); param('hightaxonid', 'null');
		
		$preex .= img({-border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"Caution"}) . p .
			span({-style=>'color: brown'}, "This scientific name has no higher name") . br . br;

	}
	
	push(@scinameparts, $sciname);
	
	my $scinamestr = join(' ', @scinameparts);
	
	# Make authority string
	my @authors;
	my $i = 1;
	while (param("nameAFN$i")) {
		
		my $author = ucfirst(param("nameAFN$i"));
		push(@authors, $author);
		$i++;
	}
	my $last = pop(@authors);
	
	my $authorstr;
	if (scalar(@authors)) { $authorstr = join(', ',@authors).' & '.$last } else { $authorstr = $last };
	
	if ($nameyear) { $authorstr .= ", $nameyear"; }
	
	if (param('parentheses')) { $authorstr = "($authorstr)" }
	
	my $end;
	my $precision;
	my $already;
	
	$already = testpreexistence();
		
	if (my $validtaxon = param('validtaxon')) { 
		
		my ($nameid, $taxonid, $vlabel) = split(/\//,"$validtaxon",3);
				
		Delete('validnameid'); param('validnameid', $nameid);
		Delete('validtaxonid'); param('validtaxonid', $taxonid);
		Delete('vlabel');
				
		if ($vlabel) { param('vlabel', $vlabel); }
		else {
			my $req  = 	"SELECT orthographe, autorite FROM noms_complets AS nc 
					LEFT JOIN taxons_x_noms AS txn ON (txn.ref_nom = nc.index) 
					WHERE txn.ref_taxon = $taxonid AND txn.ref_statut = ( SELECT index FROM statuts WHERE en = 'valid' )";
		
			my $valid = request_tab($req, $dbc, 2);
				
			if($valid->[0]) { param('vlabel', "$valid->[0][0] $valid->[0][1]"); }
		}
	}
	if ($namestatus eq 'valid') { $namestatus .= " name" }
	
	if ( $already ) {
		
		Delete('scinameid'); param('scinameid', $already);
				
		if ( $namestatus ne 'correct use' and $namestatus ne 'misidentification' and $namestatus ne 'previous identification' and !param('oldname') ) {
			
			$preex .= img({-border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"Caution"}) . p .
			span({-style=>'color: brown'}, "This scientific name is already in the database, check for any conflict before continuing") . br . br;
		}
		elsif ( ($namestatus eq 'correct use' or $namestatus eq 'misidentification') and !param('oldname')) {
					
			Delete('validnameid');
			my $vtaxid = param('validtaxonid');
			Delete('validtaxonid');
			
			Delete('scinameid'); param('scinameid', $already);
			
			my $req = "	SELECT nc.index, txn.ref_taxon, nc.orthographe, nc.autorite, st.en, nc2.orthographe, nc2.autorite FROM noms_complets AS nc 
					LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
					LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom 
					LEFT JOIN statuts as st ON txn.ref_statut = st.index  
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index 
					WHERE nc.index = $already
					AND st.en not in ('correct use', 'misidentification', 'previous identification', 'wrong spelling');";	
			
			my $taxa = request_tab($req, $dbc, 2);
			
			if (scalar(@{$taxa}) > 1) { 
			
				my $select = "<SELECT CLASS=PopupStyle NAME=validtaxonid ONCHANGE=''><OPTION>";
				foreach(@{$taxa}) { 
					my $selected;
					if ($_->[1] == $vtaxid) { $selected = 'SELECTED'; }
					$select .= "<OPTION VALUE=$_->[1] $selected>$_->[2]&nbsp;&nbsp;$_->[3]";
					unless ($_->[4] eq 'valid') { $select .= "&nbsp;&nbsp;$_->[4] related to&nbsp;&nbsp;$_->[5]&nbsp;&nbsp;$_->[6]" }
				}
				$select .= "</SELECT>";
				
				$precision = table(
							Tr(
								td(span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "$namestatus of")),
								td($select)
							)
					     ) . br . br;
			}
			else { param('validtaxonid', $taxa->[0][1]); }
		}
	}
	elsif ( !$already and ($namestatus eq 'correct use' or $namestatus eq 'misidentification' or $namestatus eq 'previous identification')) { 
		
		$preex .= img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"stop"}) . p .
			span({-style=>'color: crimson'}, "Scientific name not in the database"); $end = 1;
		
	}
	
	my $localjscript = 	"function testIntegrity () {
										
					if ((document.nameform.namestatus.value == 'valid' || document.nameform.namestatus.value == 'correct use' || document.nameform.namestatus.value == 'misidentification' || document.nameform.namestatus.value == 'previous identification' || document.nameform.namestatus.value == 'wrong spelling') && document.nameform.firstpubid.value == '') { document.getElementById('hiddedmsg').style.display = 'inline'; }
					else { 
						if (document.nameform.oldname) { document.nameform.action='Names.pl?action=maj&page=sciname'; document.nameform.submit(); }
						else { document.nameform.action='Names.pl?action=enter&page=sciname'; document.nameform.submit(); }
					}
				}
				function testdpub () {
					if (document.nameform.denoncepubid.value == '$denoncepub') { document.getElementById('dlabel').style.display = 'inline' }
					else { document.getElementById('dlabel').style.display = 'none' }				
				}
				function testfpub () {
					if (document.nameform.firstpubid.value == '$firstpub') { document.getElementById('flabel').style.display = 'inline' }
					else { document.getElementById('flabel').style.display = 'none' }				
				}";
	
	my %headerHash = (
		titre => 'Scientific name',
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden . $localjscript,
		onLoad => ""
	);
	
	my $princeps;
	my $denoncefield;
	
	my $validstr = param('vlabel');
			
	if($namestatus eq 'valid name') { 
		$princeps = 'Taxon first description  publication';
		$validstr = '';
	}
	elsif ($namestatus eq 'correct use') { 
		$princeps = 'Correct use publication';
		$validstr = '';
	}
	elsif ($namestatus eq 'dead end') { 
		$princeps = 'Scientific name first publication'; 
		$validstr = span({-style=>'color: #555555;'}, ' related to &nbsp;') . $validstr;
	}
	else {
		
		my $label;
		if ($namestatus eq 'synonym' or $namestatus eq 'junior synonym') { 
			$princeps = 'Scientific name first publication';
			$label = 'Synonymy';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'previous combination') { 
			$princeps = 'Scientific name first publication';
			$label = 'Transfer';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'wrong spelling' ) { 
			$princeps = 'Scientific name first publication';
			$label = 'Correcting';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'misidentification' or $namestatus eq 'previous identification') { 
			$princeps = 'Misidentification publication';
			$label = 'Correcting';
			if ($namestatus eq 'previous identification') { $validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr; }
		}		
		elsif ($namestatus eq 'incorrect original spelling') { 
			$princeps = 'Scientific name first publication';
			$label = 'Emendation';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'incorrect subsequent spelling') { 
			$princeps = 'Scientific name first publication';
			$label = 'Unjustified emendation';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'homonym') { 
			$princeps = 'Scientific name first publication';
			$label = 'Homonymy';
			$validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'nomen praeoccupatum') { 
			$princeps = 'Scientific name first publication';
			$label = 'Nomen novum';
			$validstr = span({-style=>'color: #555555;'}, ' replaced by nomen novum &nbsp;') . $validstr;
		}
		elsif ($namestatus eq 'nomen nudum') { 
			$princeps = 'Scientific name first publication';
			$label = 'nomen nudum denonciation';
			if ($validstr) { $validstr = span({-style=>'color: #555555;'}, ' of &nbsp;') . $validstr; }
		}
		elsif ($namestatus eq 'nomen oblitum') {
			$princeps = 'Scientific name first publication';
			$label = 'synonymy';
			$validstr = span({-style=>'color: #555555;'}, ', synonym of &nbsp;') . $validstr;			
		}
		else { 
			$princeps = 'Scientific name first publication';
			$label = 'Nomenclatural act';
			$validstr = span({-style=>'color: #555555;'}, ' related to &nbsp;') . $validstr;
		}
		
		$denoncefield = Tr({-style=>'height: 10px;'}). 
				Tr(
					td({-align=>'left'},span({-style=>'font-size: normal; margin-right: 6px;'}, "$label publication index")),
					td(textfield(-class=>'phantomTextField', -name=>'denoncepubid', -style=>'width: 55px; margin-right: 10px;', -default=>$denoncepub, -onBlur=>"nameform.action='Names.pl?action=verify';  nameform.submit();")),
					td(
						div(	{-style=>'margin-right: 10px;',
							-onMouseover=>"	dp.src=eval('searchonimg.src');",
							-onMouseout=>"	dp.src=eval('searchoffimg.src')",
							-onClick=>"	appendHidden(document.nameform, 'searchFrom', 'Names.pl?action=verify');
									appendHidden(document.nameform, 'searchTo', 'Names.pl?action=verify');
									appendHidden(document.nameform, 'treatDP', '1');
									nameform.action='pubsearch.pl?action=getOptions'; nameform.submit();"},
							
							img({-border=>0, -src=>'/Editor/search0.png', -name=>"dp"})
						)					
					),
					td(
						div(	{
							-onMouseover=>"	pd.src=eval('newonimg.src')",
							-onMouseout=>"	pd.src=eval('newoffimg.src')",
							-onClick=>"	appendHidden(document.nameform, 'searchFrom', 'Names.pl?action=verify');
									appendHidden(document.nameform, 'searchTo', 'Names.pl?action=verify');
									appendHidden(document.nameform, 'treatDP', '1');
									nameform.action='typeSelect.pl?action=add&type=pub'; nameform.submit();"},
							img({-border=>0, -src=>'/Editor/new0.png', -name=>"pd"})
						)					
					),
					td ({-style=>'width: 400px;'})
				);
				
				if ( $denoncepub ) { $denoncefield  .= Tr(td({-colspan=>5, -style=>'width: 800px;'}, span({-id=>'dlabel', -style=>'color: crimson;'}, pub_formating(get_pub_params($dbc, $denoncepub), 'html')) )); }
	}
	
	my $usefield;
	
	$usefield = Tr(
			td({-align=>'left'},span({-style=>'font-size: normal; margin-right: 6px;'}, "$princeps index")),
			td(textfield(-class=>'phantomTextField', -name=>'firstpubid', -style=>'width: 55px; margin-right: 10px;', -default=>$firstpub, 
				-onBlur=>"nameform.action='Names.pl?action=verify'; nameform.submit();")),
			td(
				div(	{-style=>'margin-right: 10px;',
					-onMouseover=>"	fp.src=eval('searchonimg.src')",
					-onMouseout=>"	fp.src=eval('searchoffimg.src')",
					-onClick=>"	appendHidden(document.nameform, 'searchFrom', 'Names.pl?action=verify');
							appendHidden(document.nameform, 'searchTo', 'Names.pl?action=verify');
							appendHidden(document.nameform, 'treatFP', '1');
							nameform.action='pubsearch.pl?action=getOptions'; nameform.submit();"},
					
					img({-border=>0, -src=>'/Editor/search0.png', -name=>"fp"})
				)					
			),
			td(
				div(	{-onMouseover=>"pf.src=eval('newonimg.src')",
					-onMouseout=>"	pf.src=eval('newoffimg.src')",
					-onClick=>"	appendHidden(document.nameform, 'searchFrom', 'Names.pl?action=verify');
							appendHidden(document.nameform, 'searchTo', 'Names.pl?action=verify');
							appendHidden(document.nameform, 'treatFP', '1');
							nameform.action='typeSelect.pl?action=add&type=pub'; nameform.submit();"},
					img({-border=>0, -src=>'/Editor/new0.png', -name=>"pf"})
				)					
			),
			td ({-style=>'width: 400px;'})
		);

	if ( $firstpub ) { 
	
		$usefield .= Tr(	td({-colspan=>5, -style=>'width: 800px;'},
						span({-id=>'flabel', -style=>'color: crimson;'},
						pub_formating(get_pub_params($dbc, $firstpub), 'html')) 
					)
				);
	}
	
	my $erase;
	if (param('action') eq 'update') {
		$erase .= "Erase this relation by checking these boxes: " . checkbox(-name=>'erase', -value=>'1', -label=>'') . 
				" confirm erase " . checkbox(-name=>'confirm', -value=>'1', -label=>'') . br;
	}
	
	my $ok = table(
			Tr(
				td(
					div(	{-onMouseover=>"nameOk.src=eval('okonimg.src')",
						-onMouseout=>"nameOk.src=eval('okoffimg.src')",
						-onClick=>"testIntegrity();"},
						
						img({-border=>0, -src=>'/Editor/ok0.png', -name=>"nameOk"})
					)
				)
			)
		);
	
	my $content;
	unless ($end) {
				
		if (param('fossil')) { $scinamestr .= '†' }
						
		$content = div(
				div({-style=>'margin: 0 0 10px 0; font-size: 15px;'},
					
					"$scinamestr $authorstr &nbsp;".span({-style=>'color: crimson;'}, $namestatus)."$validstr"
				),
				
				br,
				
				span({-style=>'color: #FF3300'}, "After entering the index of any publication, click anywhere outside of the index field 
				in order to make the complete reference appear"), br, br,
				
				$precision,
				
				table( 
					$usefield,
					
					Tr(td(br)),
					
					$denoncefield
				),
				
				br,
				
				$erase,
				
				p, br,
				
				$ok,
								
				arg_persist(),
				
				end_form(),
				
				div({-id=>'hiddedmsg', -style=>'display: none;'}, br . img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . br . br . 
					span({-style=>'color: crimson;'}, "Precise the publication index" . br)),
				
				div ({-style=>'margin-top: 3%;'},
					
					start_form(-name=>'backform', -method=>'post'),
					
					$persist,
					
					a(	{-onMouseover=>"nameBack.src=eval('backonimg.src')",
						-onMouseout=>"nameBack.src=eval('backoffimg.src')",
						-onClick=>"backform.action = 'Names.pl?action=fill&page=sciname'; backform.submit();"},
					
						img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
					),
					
					end_form(), br, br,
								
					a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;' },
						img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})
					)
				)
			);
	}
	else {
		$content = 	end_form().
		
				div ({-style=>'margin-top: 3%;'},
					
					start_form(-name=>'backform', -method=>'post'),
					
					$persist,
					
					a(	{-onMouseover=>"nameBack.src=eval('backonimg.src')",
						-onMouseout=>"nameBack.src=eval('backoffimg.src')",
						-onClick=>"backform.action = 'Names.pl?action=fill&page=sciname'; backform.submit();"},
					
						img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
					),
					
					end_form(), br, br,
								
					a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;' },
						img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})
					)
				);
	}

	$html .= html_header(\%headerHash).

		#join(br, map { "$_ = ".param($_) } param()).
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor").
		
		start_form(-name=>'nameform', -method=>'post').
				
		div({-class=>'wcenter'},
							
		table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
				td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Scientific name publications"),
				td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
			)
		).
									
		$preex,
			
		br,

		$content
	);

	html_footer();

	return $html;

}

sub verification {
	
	my ($dbc) = @_;
	
	my $respons;
	my @elmts;
	
	my $shortcut;
	
	#die join(br, map { "$_ = ".param($_) } param());
	
	my $status = param('namestatus');
	
	unless ($status) { push(@elmts,"A scientific name must have a taxonomic status."); }
	elsif ($status ne 'correct use' and $status ne 'misidentification') {
		unless ($status eq 'valid') {
			unless (length(param('validname')) > 2) { push(@elmts,"Any name must have at least 3 letters."); }
			else{
				unless (param('validtaxon')) { $shortcut = 1; }
			}
		}
	}
	
	#if (!param('highname')) { push(@elmts,"Please precise a higher rank name."); }	
	
	unless (param("sciname")) { push(@elmts,"Please enter the scientific name."); }
	
	unless ($status eq 'nomen nudum' or $status eq 'wrong spelling') { 
		unless (int(param("nameyear"))) { push(@elmts,"A scientific must have a valid Year. ex: 1915"); }
		else { if (param("nameyear") < 1735) { push(@elmts,"Invalid Year (< 1735)."); } }
	} 
	else {
	       unless (param("nameyear")) { 
			param("nameyear", 'NULL');
		}
	}
	
	#unless (param('nameAFN1')) { 
	#	push(@elmts,"A scientific name must have an authority."); 
	#	unless (param('nameALN1')) { push(@elmts,"A scientific name must have an authority including initials.");  }
	#}
	#my $i = 2;
	#while (param("nameAFN$i")) {
	#	unless (param("nameALN$i")) { push(@elmts,"A scientific authorities must include initials.");  }
	#	$i++;
	#}
	
	if ($shortcut) { $respons = 'precise'; }	
	elsif (scalar(@elmts)) { $respons = join(br,@elmts); }
	else { $respons = 'ok'; }
	
	return $respons;
}


sub name_form {
	
	my ($msg) = @_;
		
	my $html;
	my $death;
	my $death2;
	
	my $persist = arg_persist();
	
	Delete('scinameid');
	
	my $genus;
	if(param('genusX')) { 	$genus = param('genusX'); }
	
	my $status;
	if(param('namestatus')) { $status = param('namestatus'); }
	Delete('namestatus');
	
	my $sciname;
	if(param('sciname')) { $sciname = param('sciname'); }
	Delete('sciname');
	
	my $vname;
	if(param('validname')) { $vname = param('validname'); }
	Delete('validname');
	
	my $vtaxon;
	if(param('validtaxon')) { $vtaxon = param('validtaxon'); }
	Delete('validtaxon');
		
	my $par;
	if ( $par = param('parentheses') ) { Delete('parentheses'); };
	
	my $xorder = param('nameOrder');
	
	my $ranksinfo = request_hash("SELECT index, ordre, en FROM rangs;", $dbc, 'en');
	
	my $gen_type;
	
	my $forder = $ranksinfo->{'family'}->{'ordre'};
	my $gorder = $ranksinfo->{'genus'}->{'ordre'};
	my $sorder = $ranksinfo->{'species'}->{'ordre'};
	
	Delete('forder'); param('forder', $forder);
	Delete('gorder'); param('gorder', $gorder);
	Delete('sorder'); param('sorder', $sorder);
		
	my $validlabel;
	my $vorder;
	# Genus level
	if ($xorder >= $gorder and $xorder < $sorder) {
		$vorder = $gorder;
	}
	# Species level
	elsif ($xorder >= $sorder) {
		if ($xorder == $sorder) { 
			my $check;
			if (param('old_type')) { $check = 1 } else { $check = 0 }
			
			$gen_type = Tr({-style=>'height: 10px;'}). Tr(td(span({-style=>'font-size: 15px; font-weight: bold;'},"Type species &nbsp;")),td(checkbox(-name=>'gen_type', -value=>1, -label=>'', -checked=>$check)));
		}
		
		$vorder = $sorder;
	}
	# higher levels
	else {
		$vorder = $xorder;
	}
	
	
	# precise de valid taxon if necessary
	my $taxa;
	my $vtfield;
	if ($msg eq 'precise' or $vtaxon or param('action') eq 'update') {
		
		if ($msg eq 'precise') { $msg = 'Select a taxon'; }
		
		$taxa = getTaxa($vname, $vorder, 0);
		
		my @sortedids = sort { $taxa->{$a} cmp $taxa->{$b} } keys(%{$taxa});
				
		if (scalar(@sortedids)) {
		
			my $select = "	<SELECT CLASS=PopupStyle NAME=validtaxon>
					<OPTION VALUE=''> Select a scientific name";
			foreach(@sortedids) { 
				if ($_ eq $vtaxon) {
										
					$select .= "<OPTION VALUE=\"$_\" SELECTED>$taxa->{$_}"
				}
				else {
					$select .= "<OPTION VALUE=\"$_\">$taxa->{$_}"
				}
			}
			$select .= "</SELECT>";
			
			my $sstr;
			if ($status eq 'valid') { $sstr = "valid name"; } else { $sstr = $status; }
			
			$vtfield = 	table( 
						Tr(
							td($select),
							td({-style=>'padding-left: 20px;'},
								span(	{-style=>'',
									-onMouseover=>"vchange.src=eval('clearonimg.src')",
									-onMouseout=>"vchange.src=eval('clearoffimg.src')",
							 		-onClick=>"testStatus(document.nameform); clearvtax();"},	
									
									img({-border=>0, -src=>'/Editor/clear0.png', -name=>"vchange"})
								)
							)
						)
					);
		} 
		else { $death2 = 1 }
	}
	
	# The higher taxon
	my $hightax;
	my $Hn;
	my $Hnlabel;
			
	if (param('genusX')) { 
		
		$Hn = getHigherNames($genus, $xorder);
	}
	else {
		$Hn = getHigherNames('', $xorder);
	}

	my $choice;
	if (scalar(keys(%{$Hn}))) {
				
		my @sortedids = sort { $Hn->{$a} cmp $Hn->{$b} } keys(%{$Hn});
				
		$choice = "<SELECT CLASS=PopupStyle NAME=highname><OPTION>";
		foreach(@sortedids) { my $checked; if($_ eq param('highname')){ $checked = 'SELECTED' } $choice .= "<OPTION VALUE=$_ $checked>$Hn->{$_}" }
		$choice .= "</SELECT>";
		
	}
	else { 
		$choice = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . 
		span({-style=>'font-size: 15px; color: crimson;'}, "No higher rank name matching with " .  param('genusX') . " in database") .
		end_form().
		start_form(-name=>'backform', -method=>'post').				
		$persist.
		a({	-onMouseover=>"nameBack.src=eval('backonimg.src')",
			-onMouseout=>"nameBack.src=eval('backoffimg.src')",
			-onClick=>"backform.action = 'typeSelect.pl?action=add&type=all'; backform.submit();"},
				
			img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
		).
		end_form();
		
		$death = 1;
	}
	
	$hightax = 	Tr(
				td(	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "Higher rank") ),
				td(	$choice )
			);
	
	# the scientic name field
	my ($scirank) = @{ request_tab("SELECT en FROM rangs WHERE ordre = $xorder;", $dbc, 1) };
	
	my $nom = 	Tr(
				td(	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, ucfirst($scirank)." ") ),
				td(	textfield(-class=>'phantomTextField', -name=>'sciname', -default=>$sciname, size=>30, -onFocus=>AonFocus('name'), -onBlur=>'testCase(this);') )
			);

	my $jscript = 	$authorsJscript . $jscript_imgs .
	
			"function getSelectedRadio(buttonGroup) {
			   if (buttonGroup[0]) { 
			      for (var i=0; i<buttonGroup.length; i++) {
				 if (buttonGroup[i].checked) {
				    return i
				 }
			      }
			   } else {
			      if (buttonGroup.checked) { return 0; }
			   }
			   return -1;
			} 
			
			function getSelectedRadioValue(buttonGroup) {
			   var i = getSelectedRadio(buttonGroup);
			   if (i == -1) {
			      return '';
			   } else {
			      if (buttonGroup[i]) {
				 return buttonGroup[i].value;
			      } else {
				 return buttonGroup.value;
			      }
			   }
			}
			
			function testStatus (form) {
														
				if (form.namestatus.value == '' || form.namestatus.value == 'correct use' || form.namestatus.value == 'valid' || form.namestatus.value == 'misidentification') {
				
					maskvnamediv();
					maskvtaxdiv();
				}
				else { 					
					if ($xorder >= $gorder && $xorder < $sorder) {
						if ( form.namestatus.value  == 'nomen praeoccupatum' ) {
							document.getElementById('statstr').value = ' replaced by nomen novum which generic epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.46;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else if ( form.namestatus.value  == 'dead end' ) {
							document.getElementById('statstr').value = ' related to scientific name which generic epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.42;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else if ( form.namestatus.value  == 'nomen oblitum' ) {
							document.getElementById('statstr').value = ' synonym of a scientific name which specific epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.44;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else {
							document.getElementById('statstr').value = ' of scientific name which generic epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.42;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
					}
					else if ($xorder >= $sorder) {
						if ( form.namestatus.value  == 'nomen praeoccupatum' ) {
							document.getElementById('statstr').value = ' replaced by nomen novum which specific epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.46;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else if ( form.namestatus.value  == 'dead end' ) {
							document.getElementById('statstr').value = ' related to scientific name which specific epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.42;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else if ( form.namestatus.value  == 'nomen oblitum' ) {
							document.getElementById('statstr').value = ' synonym of a scientific name which specific epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.44;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
						else {
							document.getElementById('statstr').value = ' of scientific name which specific epithet is ';
							var lw = document.getElementById('statstr').value.length * 0.42;
							document.getElementById('statstr').style.width = parseInt(lw) + 'em';
						}
					}
					else {
						document.getElementById('statstr').value = ' of scientific name ';
						document.getElementById('statstr').style.width = '150px';
					}
					
					if (form.namestatus.value  == 'homonym') { 
						document.getElementById('vnamediv').style.display = 'none';
						if (form.validname.value == '' || form.validname.value != form.sciname.value) {
							form.validname.value = form.sciname.value;
							maskvtaxdiv();
						}
						else {
							document.getElementById('vtaxdiv').style.display = 'inline';
						}
					}
					else if (form.namestatus.value  == 'previous combination') { 
						document.getElementById('vnamediv').style.display = 'inline';
						if ( '$vname' == '' ) { form.validname.value = form.sciname.value; }
						else {
							form.validname.value = '$vname';
							form.validtaxon.value = \"$vtaxon\";
							document.getElementById('vtaxdiv').style.display = 'inline';
						}
					}
					else { 
						document.getElementById('vnamediv').style.display = 'inline';
						if ( '$vname' != '' ) {
							form.validname.value = '$vname';
							form.validtaxon.value = \"$vtaxon\";
							document.getElementById('vtaxdiv').style.display = 'inline';
						}
					}
				}
			}
			
			function clearvtax () { 
					
				document.nameform.namestatus.value  = '';
				document.getElementById('precisestatus').style.display = 'inline';
				maskvtaxdiv();
				document.nameform.validname.value = '';
			}
			
			function maskvtaxdiv () {
				if (document.nameform.validtaxon) { document.nameform.validtaxon.value = ''; }
				document.getElementById('vtaxdiv').style.display = 'none';
			}
			function maskvnamediv () {
				if (document.nameform.validname) { document.nameform.validname.value = ''; }
				document.getElementById('vnamediv').style.display = 'none';
			}
			function testCase (textfield) {
				
				var sn = textfield.value;				
				var snl = sn.length;
								
				if ($xorder < $sorder) { textfield.value = sn.substring(0,1).toUpperCase() + sn.substring(1,snl).toLowerCase(); }
				else { textfield.value = sn.toLowerCase(); }
			}";
	
	my %headerHash = (
		titre => 'Scientific name',
		bgcolor => $background,
		css => $css,
		jscript => $jscript,
		onLoad=> AonFocus('name') . ' testStatus(document.nameform);'
	);
	
	my ($fiche, $annee);	
		
	# scientific name year field
	$annee = 	Tr(
				td(	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "Year ") ),
				td(	textfield(-class=>'phantomTextField', -name=>'nameyear', -maxlength=>4, size=>4, -onFocus=>AonFocus('name')) )
			);
				
	# the author(s) fields and params
	my $nbauts;
	if (param('namenbauts')) { $nbauts = param('namenbauts'); }
	else { $nbauts = 1; }
		
	my $authors_field;
	for (my $i=1;$i<$nbauts;$i++) {
	
		$authors_field .= 	Tr(
						td(	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "Author $i ") ),
						td(	makeAuthorsfields('name', $i) )
					);
	}
	my $i = $nbauts;
	$authors_field .= 	Tr(
						td( 	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "Author $i ") ),
						td( 	div({-style=>'position: relative;'},
								makeAuthorsfields('name', $i).
								div( {-id=>'lessAuts', -onClick=>"ChangeNbAuts(nameform, nameform.namenbauts, 'less', $nbauts, 'Names.pl', 'sciname');", -style=>'display: inline; position: absolute; top: 3px; left: 320px;'},img ({-src=>'/Editor/less.png', -border=>0}) ).
								div( {-id=>'moreAuts', -onClick=>"ChangeNbAuts(nameform, nameform.namenbauts, 'more', $nbauts, 'Names.pl', 'sciname');", -style=>'display: inline; position: absolute; top: 3px; left: 340px;'},img ({-src=>'/Editor/more.png', -border=>0}) )
							)
						)
					);
	if ($xorder > $gorder) {
		$authors_field .=	Tr({-style=>'height: 10px;'}).				
					Tr(
							td(	span({-style=>'font-size: 15px; color: navy; margin-right: 20px; font-weight: bold;'}, "Brackets ") ),
							td(	checkbox(-name=>'parentheses', -value=>'1', -label=>'', -checked=>$par) )
					);
	}
	
	$i++;
	while (defined(param("nameAFN$i"))) { Delete("nameAFN$i"); Delete("nameALN$i"); $i++; }

	my $hiddens;	
	unless (param('namenbauts')) { $hiddens .= hidden('namenbauts',1); }

	if (url_param('action')) { $hiddens .= hidden('action'); }
		
	my $backaction;

	if (url_param('action') eq 'modify') { $backaction = "	appendHidden(document.backform, 'field', 'value'); 
								document.backform.action = 'target.pl?action=???';
								document.backform.submit();" 
	}
		
	my $back;
	
	if ($backaction) {
		
		$back = start_form(-name=>'backform', -method=>'post').
			
			a(	{-onMouseover=>"nameBack.src=eval('backonimg.src')",
				-onMouseout=>"nameBack.src=eval('backoffimg.src')",
				-onClick=>$backaction},
			
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
			).
			
			end_form();
	}
	
	# the scientific name status field
	my $statusreq;
	my $except;
	#unless ($xorder > $gorder) { $except = ", 'previous combination'" }
	
	$statusreq = "	SELECT s.en, count(*) 
			FROM statuts AS s
			LEFT JOIN taxons_x_noms AS txn ON txn.ref_statut = s.index 
			WHERE en not in ('valid', 'correct use', 'wrong spelling', 'misidentification', 'previous identification' $except)
			GROUP BY s.en 
			ORDER BY count(*) DESC, s.en;";
	
	my $namestatus = request_tab($statusreq, $dbc, 1);
	
	my $etats;
	my $usages;
	foreach('valid', @{$namestatus}) { 
		if ($_ eq $status) {
			$etats .= "<OPTION VALUE='$_' SELECTED>$_"
		}
		else {
			$etats .= "<OPTION VALUE='$_'>$_"
		}
	}
	foreach('correct use', 'wrong spelling', 'misidentification', 'previous identification') {
		if ($_ eq $status) {
			$usages .= "<OPTION VALUE='$_' SELECTED>$_"
		}
		else {
			$usages .= "<OPTION VALUE='$_'>$_"
		}
	}
	
	my $statusfield = 	div({-id=>'precisestatus', -style=>'display: inline;'},
					span({-style=>'font-size: 15px; color: navy; font-weight: bold; margin-right: 20px;'},"Status / Uses"),
					
					"<SELECT CLASS=PopupStyle NAME=namestatus ONCHANGE='testStatus(this.form);' SELECTED=$status>",
					"<OPTION VALUE=''> ",
					"<OPTION VALUE='' STYLE='color: red; background: #AAAAFF; padding-left: 30px;'>Status",
					$etats,
					"<OPTION VALUE='' STYLE='color: red; background: #AAAAFF; padding-left: 30px;'>Uses",
					$usages,
					"</SELECT>",
										
					div({-id=>'vnamediv', -style=>'margin-left: 5px; display: none;'},
						textfield({-id=>'statstr', -name=>'statstr', -style=>'color: navy; background: transparent; border: 0;', -readonly=>'readonly'}),
						textfield(-class=>'phantomTextField', -name=>'validname', -style=>'margin-left: 5px; width: 160px; color: navy; background: FFFFDD;', 
						-onChange=>"if (this.value != '$vname') { form.validtaxon.value = ''; maskvtaxdiv(); } else { testStatus(this.form) }",
						-onBlur=>"testCase(this);", -default=>$vname)
					),
					
					a({-href=>'/Editor/status.html', -target=>'_blank'}, img({-style=>'width: 15px; height: 15px;', -border=>0, -src=>'/Editor/what1.png', -name=>"what"}))
				);
	
	my $fc;
	if (param('old_fossil')) { $fc = 1 } else { $fc = 0 }
			
	my $fossil = Tr({-style=>'height: 10px;'}). Tr(td(span({-style=>'font-size: 15px; font-weight: bold;'},"Fossil")),td(checkbox(-name=>'fossil', -value=>1, -label=>'', -checked=>$fc))); 


	my $content;
	unless ($death or $death2) {
		
		$content = 	div({-id=>'msgbox', -style=>"color:red; font-size: 15px;"},$msg). p.
				
		table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
				td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Scientific name"),
				td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
			)
		).
		
		div(
			table(
				$hightax,
				Tr({-style=>'height: 10px;'}),
				$nom,
				Tr({-style=>'height: 10px;'}),
				$annee,
				Tr({-style=>'height: 10px;'}),
				$authors_field,
				$gen_type,
				$fossil
			), p,
			$statusfield, p,
			
			div({-id=>'vtaxdiv', -style=>'display: none;'}, $vtfield)
		). br.
		
		table({-cellspacing=>10},
			Tr(
				td(
					div(	{-onMouseover=>"nameOk.src=eval('okonimg.src')",
						-onMouseout=>"nameOk.src=eval('okoffimg.src')",
						-onClick=>"nameform.action='Names.pl?action=verify'; nameform.submit();"},
						
						img({-border=>0, -src=>'/Editor/ok0.png', -name=>"nameOk"})
					)
				)
			)
		).
		
		$hiddens.
		
		arg_persist();
	}
	elsif ($death) {
		
		$content = $hightax ;
	}
	elsif ($death2) {
		
		$content = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) . p . 
		span({-style=>'font-size: 15px; color: crimson;'}, "No name matching with $vname in database") .
		end_form().
		start_form(-name=>'backform', -method=>'post').				
		$persist.
		a({	-onMouseover=>"nameBack.src=eval('backonimg.src')",
			-onMouseout=>"nameBack.src=eval('backoffimg.src')",
			-onClick=>"backform.action = 'Names.pl?action=fill&page=sciname'; backform.submit();"},
				
			img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
		).
		end_form();
	}

	
	$html .= html_header(\%headerHash).

		#join(br, map { "$_ = ".param($_) } param()).
			
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor").
		
		start_form(-name=>'nameform', -method=>'post').
				
		div({-class=>'wcenter'},
		
			$content,

			end_form(),
		
			div ({-style=>'margin-top: 3%;'},
				
				$back,
							
				a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;' },
					img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})
				)
			)
		).
	
		html_footer();
	
	return $html;
}


sub getHigherNames {
	
	my ($genus, $xorder) = @_;
		
	my $genus = ucfirst($genus);
	
	my $highnames;
		
	my ($index, $taxon, $orthographe, $autorite, $statut, $validO, $validA);
	
	my $cols = [ \($index, $taxon, $orthographe, $autorite, $statut, $validO, $validA) ];
	
	my $conditions;
	
	if($xorder <= param('gorder')) { 
				
		if ($xorder <= param('forder')) { $conditions .= "AND ordre < $xorder" }
		else { $conditions .= "AND ordre < $xorder AND ordre >= ".param('forder') }
	}
	elsif ($xorder <= param('sorder')) { $conditions = "AND ordre < $xorder AND ordre >= ".param('gorder') }
	else { $conditions = "AND ordre < $xorder AND ordre >= ".param('sorder') }
	
	my $req = "	SELECT nc.index, txn.ref_taxon, nc.orthographe, nc.autorite, st.en, nc2.orthographe, nc2.autorite FROM noms_complets AS nc 
			LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
			LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
			LEFT JOIN statuts as st ON txn.ref_statut = st.index
			LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
			WHERE nc.orthographe like '$genus%' $conditions
			AND st.en not in ('correct use', 'misidentification');";
			
	my $sth = request_bind($req, $dbc, $cols);
	
	while ( $sth->fetch() ){
		
		unless ($taxon) { $taxon = 'NULL' }
		
		$highnames->{"$index/$taxon"} = "$orthographe&nbsp;&nbsp;$autorite"; 
		
		unless (!$statut or $statut eq 'valid') { $highnames->{"$index/$taxon"} .= "&nbsp;&nbsp;$statut related to&nbsp;&nbsp;$validO &nbsp; $validA" }

	}
		
	return $highnames;
	
}

sub getTaxa {
	
	my ($name, $xorder, $id) = @_;
		
	my $validtaxa;
		
	my ($index, $taxon, $orthographe, $autorite, $statut, $validO, $validA);
	
	my $cols = [ \($index, $taxon, $orthographe, $autorite, $statut, $validO, $validA) ];
	
	my $conditions;
	
	my $token;
	
	if ($xorder >= param('sorder')) { $conditions = "AND ordre >= ".param('sorder'); $token = "% $name%"; }
	elsif ($xorder >= param('gorder')) { 
		$name = ucfirst($name); 
		if ($xorder > param('gorder')) {
			$conditions = "AND ordre >= ".param('gorder')." AND ordre <".param('sorder'); 
			$token = "% $name%";
		} else {
			$token = "$name%"; 
		}
	}
	else { $name = ucfirst($name); $conditions = "AND ordre <= $xorder"; $token = $name; }
	
	if ($id) {
		$conditions = " AND nc.index = $id";
	} 

	my $req = "	SELECT nc.index, txn.ref_taxon, nc.orthographe, nc.autorite, st.en, nc2.orthographe, nc2.autorite FROM noms_complets AS nc 
			LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
			LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
			LEFT JOIN statuts as st ON txn.ref_statut = st.index
			LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
			WHERE nc.autorite IS NOT NULL AND nc.orthographe like '$token%' $conditions
			AND st.en not in ('correct use', 'misidentification');";					

	my $sth = request_bind($req, $dbc, $cols);
	
	while ( $sth->fetch() ){ 
				
		my $str = "$orthographe&nbsp;&nbsp;$autorite"; 
		
		unless ($statut eq 'valid') { $str .= "&nbsp;&nbsp;$statut related to&nbsp;&nbsp;$validO&nbsp;&nbsp;$validA" }
	
		$validtaxa->{"$index/$taxon/$str"} = $str;
	}
	
	return $validtaxa;
	
}

sub get_authors_id {
	
	my $ids;
	
	my $i = 1;
	while (param("nameAFN$i")) {
		
		my ($nom,$prenom);
		
		$nom = param("nameAFN$i");
		$prenom = param("nameALN$i");
		
		push(@{$ids},add_author($nom,$prenom));
		
		$i++;
	}
	
	return $ids;
}


sub search_names {
        
	my ($dbc, $query, $order) = @_;
	
	my %headerHash = (
		titre => 'Select a name',
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs
	);

	print html_header(\%headerHash);
	print div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor");

        my $content;

        if ( $dbc ) {
                $query =~ s/^\s*/\^/;
                $query =~ s/\s*$/\$/;
                $query =~ s/'/\\'/g;
		
                $dbc->{RaiseError} = 1;
		
		my $req = 	"SELECT count(*) FROM taxons AS t 
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.ordre = $order
				AND nc.orthographe ~* '$query' ;";
	
		my $sth = $dbc->prepare($req) or die "$req: $dbc->errstr";
                $sth->execute( ) or die "$req: $dbc->errstr";
                my $nbresults;
                $sth->bind_columns( \( $nbresults ) );
                $sth->fetch();
                $sth->finish();
                if ( $nbresults ){
                        
			my $req = "SELECT t.index, nc.orthographe, nc.autorite, txn.ref_statut, s.en, r.en, nc.index, nc2.orthographe, nc2.autorite, p.index, a.nom, p.annee,
				txn.ref_nom_cible, n.ref_nom_parent, n.gen_type
				FROM taxons AS t
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
                                LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN noms AS n ON txn.ref_nom = n.index
				LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
                                LEFT JOIN statuts AS s ON txn.ref_statut = s.index
                                LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN publications AS p ON p.index = txn.ref_publication_utilisant
				LEFT JOIN auteurs_x_publications AS ap ON ap.ref_publication = p.index
				LEFT JOIN auteurs AS a ON a.index = ap.ref_auteur
                                WHERE r.ordre = $order
                                AND nc.orthographe ~* '$query'
				AND (txn.ref_publication_utilisant is null OR ap.position = 1)
                                ORDER BY nc.orthographe;";				
			
			$content .= table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},
						"$nbresults name(s) matching"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			);
                        
                        my $sth2 = $dbc->prepare( $req ) or die "$req: $dbc->errstr";
                        $sth2->execute( ) or die "$req: $dbc->errstr";
                        my ( $taxonid, $name, $autority, $statusid, $status, $rank, $nameid, $vo, $va, $pub, $aut, $year, $oldcible, $oldhigh, $gtype );
                        $sth2->bind_columns( \( $taxonid, $name, $autority, $statusid, $status, $rank, $nameid, $vo, $va, $pub, $aut, $year, $oldcible, $oldhigh, $gtype ) );
                        while ( $sth2->fetch() ){
				my $link = url()."?action=update&oldtaxon=$taxonid&oldname=$nameid&oldstatusid=$statusid&oldstatus=$status&oldcible=$oldcible&pub=$pub&oldhigh=$oldhigh";
				my $str;
				if ($status eq 'correct use' or $status eq 'misidentification') { $str = " in ($aut, $year)"; }
				elsif ($status eq 'nomen praeoccupatum') { $str = " replaced by $vo $va" }
				elsif ($status eq 'nomen oblitum') { $str = ", synonym of $vo $va" }
				elsif ($status eq 'dead end') { $str = " related to $vo $va" }
				elsif ($status ne 'valid') { $str = " of $vo $va"; }
				elsif ($gtype) { $str = span({-style=>'color: red;'}, '&nbsp; type species'); }

                                $content .= a( {href=>$link, -style=>'text-decoration: none;'}, i($name) . " &nbsp; $autority &nbsp; ".b($status).$str ) . p;
                        }
                        $sth2->finish();
                }
                else {
                        $content .= 	img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}). p.
					span({-style=>'color: crimson; font-size: 15px;'}, "No matching name").
					br. br.
					a(	{-onMouseover=>"nameBack.src=eval('backonimg.src')",
						-onMouseout=>"nameBack.src=eval('backoffimg.src')",
						-href=>'typeSelect.pl?action=update&type=all'},
					
						img({-border=>0, -src=>'/Editor/back0.png', -name=>"nameBack"})
					);
                }
        }
        else { }

	#print join(br, map { "$_ = ".param($_) } param()), p;
	
        print 	div({-class=>'wcenter'},
			a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')", -style=>'text-decoration: none;' },
				img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})
			), 
			br, br,
			$content
		), 
		html_footer();
}
