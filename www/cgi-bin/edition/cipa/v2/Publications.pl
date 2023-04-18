#!/usr/bin/perl

use strict;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $authorsJscript makeAuthorsfields AonFocus add_author pub_formating get_pub_params html_header html_footer arg_persist $maintitle);


my $dbc = db_connection(get_connection_params($conf_file));

$css .= 'a { color: navy; text-decoration: none;}';

if (url_param('action') eq 'fill') { 
	
	if (url_param('page') eq 'revue') { print revue_form(); } 
	elsif (url_param('page') eq 'edition') { print edition_form(); } 
	elsif (url_param('page') eq 'city') { print city_form(); } 
	elsif (url_param('page') eq 'country') { print country_form(); } 
	elsif (url_param('page') eq 'pub') { print pub_form(); }

} 

elsif (url_param('action') eq 'verify') {
	
		my $verif = verification($dbc);
		if ( $verif eq 'ok') { 
				print recapitulation(pub_formating(make_pub_hash(), 'html'));
		}
		else { print pub_form($verif); }
	
}

elsif (url_param('action') eq 'enter') {
	
	if (url_param('page') eq 'revue') { 
		if (param('revuename')) { my $revid = add_revue(); clear_params('revue'); Delete('pubrevue'); param('pubrevue', $revid); print pub_form(); }
		else { print revue_form("You must enter a revue name."); }
	}
	elsif (url_param('page') eq 'edition') { 
		if (param('editionname')) { my $edid = add_edition(); Delete('pubedition'); clear_params('edition'); param('pubedition', $edid); print pub_form(); }
		else { print edition_form("You must enter an edition name."); }
	}
	elsif (url_param('page') eq 'city') { 
		if (param('cityname')) {
			if (param('citycountry')) { my $cityid = add_city(); clear_params('city'); Delete('editioncity'); param('editioncity', $cityid); print edition_form(); }
			else { print city_form("You must enter the city's country."); }
		}
		else { print city_form("You must enter a city name."); }
	}
	elsif (url_param('page') eq 'country') { 
		if (param('countryen')) { 
			my $paysid = add_country();
			clear_params('country');
			Delete('citycountry'); param('citycountry',$paysid); url_param('page','city'); print city_form(); 
		}
		else { print country_form("You must enter at least the english country name."); }
	}
	elsif (url_param('page') eq 'pub') { 
		my $authorsid = get_authors_id();
		my ($pubid, $msg) = add_publication(scalar(@{$authorsid}));
		my $type = param('pubType') || url_param('pubType');
		
		#clear_params('pub');
				
		param('searchPubId', $pubid);
		
		if ($msg) {
			param('msg', $msg);
			print redirection($type);
		}
		else {
			bind_pub_to_authors($pubid,$authorsid);
			print redirection($type);
		}
	}
}

# C'est dans l'ordre get puis modify enfin update...
elsif (url_param('action') eq 'get') {
	
	my $type = param('pubType');
		
	Delete('pubType');
		
	param('searchFrom',"typeSelect.pl?action=update&type=all");
	param('searchTo',"Publications.pl?action=modify");
	param('NoNew', 1);
	
						
	my %Hash = ( 	onLoad => "document.tmpform.action = 'pubsearch.pl?action=getOptions'; document.tmpform.submit();",
			css => $css
	);
			
	print html_header(\%Hash), start_form(-name=>'tmpform', -method=>'post',-action=>''), arg_persist(), hidden(-name=>'searchType', -value=>$type), end_form(), html_footer();

}

elsif (url_param('action') eq 'modify') {
	
	if (param('searchPubId')) {
										
		pub_form_params(get_pub_params($dbc, param('searchPubId')));
				
		param('pubupdate', param('searchPubId'));
		
		#Delete('searchPubId');
		
		print pub_form();
	}
	else {
		die "Error: no searchPubId found" . br . join(br, map { "$_ = ".param($_) } param());
	}
}

elsif (url_param('action') eq 'update') {
	
	my $authorsid = get_authors_id();
	
	update_publication(param('pubupdate'), scalar(@{$authorsid}));
	
	clear_pub_authors(param('pubupdate'));
	bind_pub_to_authors(param('pubupdate'), $authorsid);
	
	#clear_params('pub');
	
	print redirection(param('pubType'));

}

$dbc->disconnect();
exit;

sub error_message_maker {
	
	my ($msg) = @_;
	
	my %headerHash = ( titre => 'Error' );
	
	print html_header(\%headerHash), $msg, end_html();
}


sub pub_form_params {

	### pub form fields:
	## Common:
	# pubtitle
	# pubyear
	# pubpgdeb
	# pubpgfin
	# pubAFN$i ($i 1-n) & pubALN$i ($i 1-n)
	## Article:
	# pubrevue
	# pubvol
	# pubfasc
	## Book
	# pubedition
	# pubvol
	## Thesis
	# pubedition
	### params recieved: $pub->{index}->{field}

	my ($pub) = @_;
		
	my ($index) = keys(%{$pub});
		
	my $type = $pub->{$index}->{'type'};
	
	param('pubType',$type);
	
	# Get Authority
	my $nb_authors = $pub->{$index}->{'nombre_auteurs'};
	param('pubnbauts',$nb_authors);
	
	my $position = 1;
	while ( $position <= $nb_authors ) {
		param("pubAFN$position",$pub->{$index}->{'auteurs'}->{$position}->{'nom'});
		param("pubALN$position",$pub->{$index}->{'auteurs'}->{$position}->{'prenom'});
		$position++;
	}
	
	param('pubtitle',$pub->{$index}->{'titre'});
	param('pubyear',$pub->{$index}->{'annee'});
	param('pubpgdeb',$pub->{$index}->{'page_debut'});
	param('pubpgfin',$pub->{$index}->{'page_fin'});
	
	
	if ($type eq "Article") {
		
		param('pubrevue',$pub->{$index}->{'revueid'});
		param('pubvol',$pub->{$index}->{'volume'});
		param('pubfasc',$pub->{$index}->{'fascicule'});
	}
	
	elsif ($type eq "Book") {
		
		param('pubedition',$pub->{$index}->{'edid'});
		param('pubvol',$pub->{$index}->{'volume'});
	
	}
	
	elsif ($type eq "Thesis") {
		
		param('pubedition',$pub->{$index}->{'edid'});	
	}
	
	elsif ($type eq "In book") {
		
		param('bookSid',$pub->{$index}->{'indexlivre'});	
	}
}





sub clear_params {

	my ($type) = @_;
	
	if ($type eq 'revue') { Delete('revuename'); }
	elsif ($type eq 'edition') { Delete('editionname'); Delete('editioncity'); }
	elsif ($type eq 'city') { Delete('cityname'); Delete('citycountry'); }
	elsif ($type eq 'country') { Delete('countryen'); Delete('countryfr'); Delete('countrysp'); Delete('countrypt'); }
	elsif ($type eq 'pub') {
		
		my $i=1;
		while (param("pubAFN$i")) { Delete("pubAFN$i"); Delete("pubALN$i"); $i++; }
		
		Delete ("pubtitle");
		Delete ("pubyear");
		Delete ("pubpgdeb");
		Delete ("pubpgfin");
		Delete ("pubnbauts");
		
		$type = param('pubType');
		
		if ($type eq 'Article') { Delete("pubrevue"); Delete("pubvol"); Delete("pubfasc"); }
		elsif ($type eq 'Book') { Delete("pubedition"); Delete("pubvol"); }
		elsif ($type eq 'Thesis') { Delete("pubedition"); }
		elsif ($type eq 'In book') { Delete("bookid"); }
		
		Delete ("pubType");
	}
}


sub add_country {
	
	my $en = param('countryen');
	
	$en =~ s/'/\\'/g;
		
	my @flist = ('en'); #list of fields
	my @vlist = ("'$en'"); #list of values
	
	if (param('countryfr')) { my $fr = param('countryfr'); $fr =~ s/'/\\'/g; push(@flist, 'fr'); push(@vlist, "'$fr'"); }
	if (param('countrysp')) { my $sp = param('countrysp'); $sp =~ s/'/\\'/g; push(@flist, 'es'); push(@vlist, "'$sp'"); }
	if (param('countryde')) { my $de = param('countryde'); $de =~ s/'/\\'/g; push(@flist, 'de'); push(@vlist, "'$de'"); }
	if (param('countrypt')) { my $pt = param('countrypt'); $pt =~ s/'/\\'/g; push(@flist, 'pt'); push(@vlist, "'$pt'"); }
	if (param('countrycode')) { my $code = param('countrycode'); push(@flist, 'code'); push(@vlist, "'$code'"); }

	my $index;
	my $result = request_tab("SELECT index FROM pays WHERE en = '$en';",$dbc,1);
			
	if (scalar(@{$result})) {

		($index) = @{$result};
		
		my @update;
		
		my $i=0;
		while ($flist[$i]) { push(@update,"$flist[$i] = $vlist[$i]"); $i++; }
		
		my $req = "UPDATE pays SET ".join(',',@update)." WHERE index = $index;";

		my $sth = $dbc->prepare( $req ) or print header(),start_html(),$dbc->errstr,end_html();
		
		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();
		

	} else {

		my $sth = $dbc->prepare( "INSERT INTO pays (index, ".join(',',@flist).") VALUES (default, ".join(',',@vlist).");" ) or print header(),start_html(),$dbc->errstr,end_html();
		
		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM pays;";
		
		($index) = @{request_tab($req,$dbc,1)};
	}
	
	return $index;	
}


sub add_city {
	
	my $nom = param('cityname');

	$nom =~ s/'/\\'/g;
	
	my $countryid = param('citycountry');
		
	my $index;
	my $result = request_tab("SELECT index FROM villes WHERE nom = '$nom' AND ref_pays = $countryid;",$dbc,1);
		
	if (scalar(@{$result})) {

		($index) = @{$result};

	} else {

		my $sth = $dbc->prepare( "INSERT INTO villes (index, nom, ref_pays) VALUES (default, '$nom', $countryid);" ) or print header(),start_html(),$dbc->errstr,end_html();

		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM villes;";
		
		($index) = @{request_tab($req,$dbc,1)};
	}
	
	return $index;
}



sub add_edition {
	
	my $nom = param('editionname');

	$nom =~ s/'/\\'/g;
	
	my $cityid = param('editioncity');
	
	my @flist = ('index', 'nom'); #list of fields
	my @vlist = ('default',"'$nom'"); #list of values
	
	if ($cityid) { push(@flist, 'ref_ville'); push(@vlist, $cityid); }

	my $index;
	my $result = request_tab("SELECT index FROM editions WHERE nom = '$nom';",$dbc,1);
		
	if (scalar(@{$result})) {

		($index) = @{$result};

	} else {

		my $sth = $dbc->prepare( "INSERT INTO editions (".join(',',@flist).") VALUES (".join(',',@vlist).");" ) or print header(),start_html(),$dbc->errstr,end_html();

		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM editions;";
		
		($index) = @{request_tab($req,$dbc,1)};
	}
		
	return $index;	
}


sub redirection {
	
	my ($type) = @_;
	
	my $pubid;
	if (param('searchPubId')) { 
		$pubid = param('searchPubId'); 
		#Delete('searchPubId'); 
	}
	
	my $html;
	
	my $msg;
	if (param('msg')) { $msg = img({-border=>0, -src=>'/Editor/stop.png', -name=>"stop"}) . p . span({-style=>"color: crimson;"}, param('msg')); Delete('msg'); }
	else { $msg = img({-border=>0, -src=>'/Editor/done.png', -name=>"done"}) . p . span({-style=>'color: green;'}, "Publication treated") }
					
		my %headerHash = (
			titre => 'Next step',
			css => $css,
			jscript => $jscript_for_hidden
		);

		if (!param('pubupdate') and !param('searchTo')) { 

			$html .= html_header(\%headerHash).
			
			#join(br, map { "$_ = ".param($_) } param()).
			
			$maintitle.
			
			div({-class=>'wcenter'},
			
				$msg, p, br,
				
				start_form(-name=>'backform', -method=>'post'),
				
				arg_persist(),
				
				img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"backform.action = 'Publications.pl?action=fill&page=pub'; backform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"nameBack"}),
				
				end_form(), br, br,
							
				a(      {href=>"typeSelect.pl?action=insert&type=pub"}, "Enter another publication" ),

				p,
				
				a(	{href=>"typeSelect.pl?action=insert&type=all"}, "Enter another data" )
			).								
			
			html_footer();
		}
		elsif (param('pubupdate')) { 
			
			my $pubupdate = param('pubupdate');
						
			$html .= html_header(\%headerHash).
			
			#join(br, map { "$_ = ".param($_) } param()).
			
			$maintitle.
			
			div({-class=>'wcenter'},
			
				$msg, p, br,
				
				start_form(-name=>'backform', -method=>'post'),
				
				arg_persist(),
				
				img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"backform.action = 'Publications.pl?action=modify'; backform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"nameBack"}),
				
				
				end_form(), br, br,
				
				a({-href=>"typeSelect.pl?action=update&type=all"}, "Modify another data"), p,
				
				a({-href=>"typeSelect.pl?action=insert&type=all"}, "Add another data")
					
			).
						
			html_footer();			
		}
		
		elsif (param('searchTo')) {
					
			my $to = param('searchTo');
			
			Delete('searchTo');
			Delete('searchFrom');
						
			my %Hash = ( 	jscript => $jscript_for_hidden,
					css => $css,
					onLoad => "appendHidden(document.tmpform, 'searchPubId', '$pubid'); document.tmpform.action = '$to'; document.tmpform.submit();" );
			
			print html_header(\%Hash), start_form(-name=>'tmpform', -method=>'post',-action=>''), arg_persist(), end_form(), html_footer();
		}
	
	return $html;
}

sub bind_pub_to_authors {

	my ($pubid,$authorsid) = @_;
		
	my $i=1;
	foreach (@{$authorsid}) {
		
		my $count =  request_tab("SELECT count(*) FROM auteurs_x_publications WHERE ref_publication = $pubid AND position = $i",$dbc,1);
		
		unless ($count->[0]) { 
			
			my $sth = $dbc->prepare( "INSERT INTO auteurs_x_publications (ref_publication,ref_auteur,position) VALUES ($pubid,$_,$i);" ) or print header(),start_html(),$dbc->errstr,end_html();

			$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();
		}
				
		$i++;
	}
}


sub get_authors_id {
	
	my $ids;
	
	my $i = 1;
	while (param("pubAFN$i")) {
		
		my ($nom,$prenom);
		
		$nom = param("pubAFN$i");
		$prenom = param("pubALN$i");
		
		push(@{$ids},add_author($dbc, $nom, $prenom));
		
		$i++;
	}
	
	return $ids;
}

sub clear_pub_authors {
	
	my ($pubid) = @_;
	
	my $sth = $dbc->prepare( "DELETE FROM auteurs_x_publications WHERE ref_publication = $pubid;" ) or print header(),start_html(),$dbc->errstr,end_html();

	$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();
	
}

sub add_publication {

	my ($nbauts) = @_;
	
	my $request;
	my $index;
	
	my @pubfields;
	my @pubvals;
	
	my ($type, $titre, $annee, $pubpgdeb, $pubpgfin);

	my $typeid;
	$type = param("pubType");
	($typeid) = @{ request_tab("SELECT index FROM types_publication where en = '$type'",$dbc,1) };
	push(@pubvals, "$typeid");
	push(@pubfields, "ref_type_publication");
	
	$titre = param("pubtitle");
	$titre =~ s/'/\\'/g;
	push(@pubvals, "'$titre'");
	push(@pubfields, "titre");
	
	$annee = param("pubyear");
	push(@pubvals, $annee);
	push(@pubfields, "annee");
	
	$pubpgdeb = param("pubpgdeb");
	push(@pubvals, "'$pubpgdeb'");
	push(@pubfields, "page_debut");

	if (param("pubpgfin")) {
		$pubpgfin = param("pubpgfin");
		push(@pubvals, "'$pubpgfin'");
		push(@pubfields, "page_fin");
	}
			
	my $facultatifs;
	if (param("pubType") eq 'Article') {
	
		my ($volume, $fascicule, $ref_revue);
	
		if (param("pubvol")) {
			
			$volume = param("pubvol");
			push(@pubvals, "'$volume'");
			push(@pubfields, "volume");
		}
		else {
			$facultatifs .= " AND volume IS NULL";
		}
	
		if (param("pubfasc")) {

			$fascicule = param("pubfasc");
			push(@pubvals, "'$fascicule'");
			push(@pubfields, "fascicule");
		}
		else {
			$facultatifs .= " AND fascicule IS NULL";
		}

		$ref_revue = param("pubrevue");
		push(@pubvals, "$ref_revue");
		push(@pubfields, "ref_revue");
				
	}
	elsif (param("pubType") eq 'Book' or param("pubType") eq 'Thesis') {
	
		my ($volume, $ref_edition);
	
		if ($type eq 'Book') {
			
			if (param("pubvol")) {
				$volume = param("pubvol");
				push(@pubvals, "'$volume'");
				push(@pubfields, "volume");
			} 
			else {
				$facultatifs .= " AND volume IS NULL";
			}
		}

		if (param("pubedition")) {
			$ref_edition = param("pubedition");
			push(@pubvals, "$ref_edition");
			push(@pubfields, "ref_edition");
		}
		else {
			$facultatifs .= " AND ref_edition IS NULL";
		}				
	}
	elsif (param("pubType") eq 'In book') {
		
		my ($bookref);
			
		if (param("bookid")) {
			$bookref = param("bookid");
			push(@pubvals, $bookref);
			push(@pubfields, "ref_publication_livre");
		}		
	}
			
	$request = "SELECT index FROM publications WHERE (".join(',',@pubfields).") = (".join(',',@pubvals).") $facultatifs;";
	
	my $result = request_tab($request,$dbc,1);
	my $msg;
	
	if (scalar(@{$result})) {

		($index) = @{$result};
		$msg = "This publication already exists";
		
	} else {

		push(@pubvals, $nbauts);
		push(@pubfields, "nombre_auteurs");
		
		my $req = "INSERT INTO publications (index,".join(',',@pubfields).") VALUES (default,".join(',',@pubvals).");";
					
		my $sth = $dbc->prepare( $req ) or print header(),start_html(),$dbc->errstr,end_html();
		
		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM publications;";
		
		($index) = @{request_tab($req,$dbc,1)};
	}
			
	return ($index, $msg);

}


sub update_publication {

	my ($pubid, $nbauts) = @_;
	
	my $request;
	my $index;
	
	my @pubfields;
	
	my ($type, $titre, $annee, $pubpgdeb, $pubpgfin);

	my $typeid;
	$type = param("pubType");
	($typeid) = @{ request_tab("SELECT index FROM types_publication where en = '$type'",$dbc,1) };
	push(@pubfields, "ref_type_publication = $typeid");
	
	$titre = param("pubtitle");
	$titre =~ s/'/\\'/g;
	push(@pubfields, "titre = '$titre'");
	
	$annee = param("pubyear");
	push(@pubfields, "annee = $annee");
	
	$pubpgdeb = param("pubpgdeb");
	push(@pubfields, "page_debut = '$pubpgdeb'");

	if (param("pubpgfin")) {
		$pubpgfin = param("pubpgfin");
		push(@pubfields, "page_fin = '$pubpgfin'");
	}
			
	if (param("pubType") eq 'Article') {
	
		my ($volume, $fascicule, $ref_revue);
	
		if (param("pubvol")) {
			
			$volume = param("pubvol");
			push(@pubfields, "volume = '$volume'");
		} else {
			push(@pubfields, "volume = NULL");
		}
	
		if (param("pubfasc")) {

			$fascicule = param("pubfasc");
			push(@pubfields, "fascicule = '$fascicule'");
		} else {
			push(@pubfields, "fascicule = NULL");
		}

		$ref_revue = param("pubrevue");
		push(@pubfields, "ref_revue = $ref_revue");
				
	}
	elsif (param("pubType") eq 'Book' or param("pubType") eq 'Thesis') {
	
		my ($volume, $ref_edition);
	
		if ($type eq 'Book') {
			
			if (param("pubvol")) {
				$volume = param("pubvol");
				push(@pubfields, "volume = '$volume'");
			} else {
				push(@pubfields, "volume = NULL");
			}
		}

		if (param("pubedition")) {
			$ref_edition = param("pubedition");
			push(@pubfields, "ref_edition = $ref_edition");
		} else {
			push(@pubfields, "ref_edition = NULL");
		}
	}
	elsif (param("pubType") eq 'In book') {
	
		my ($bookref);
			
		if (param("bookid")) {
			$bookref = param("bookid");
			push(@pubfields, "ref_publication_livre = $bookref");
		} else {
			push(@pubfields, "ref_publication_livre = NULL");
		}	
		
	}
				
	push(@pubfields, "nombre_auteurs = $nbauts");
	
	my $req = "UPDATE publications SET ".join(',',@pubfields)." WHERE index = $pubid;";
				
	my $sth = $dbc->prepare( $req ) or print header(),start_html(),$dbc->errstr, $req, end_html();
	
	$sth->execute() or print header(),start_html(),$dbc->errstr, $req, end_html();
	
}


sub add_revue {
	
	my $nom = param('revuename');

	$nom =~ s/'/\\'/g;
	
	my $flist = "index, nom"; #list of fields
	my $vlist = "default,'$nom'"; #list of values

	my $index;
	my $result = request_tab("select index from revues where nom = '$nom';",$dbc,1);
		
	if (scalar(@{$result})) {

		($index) = @{$result};

	} else {

		my $sth = $dbc->prepare( "INSERT INTO revues ($flist) VALUES ($vlist);" ) or print header(),start_html(),$dbc->errstr,end_html();

		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM revues;";
		
		($index) = @{request_tab($req,$dbc,1)};
	}
	
	return $index;
}



sub revue_form {

	my ($msg) = @_;
	
	my $html;
		
	my %headerHash = (
		titre => 'Revue',
		css => $css
	);		
		
	if ($msg) { $msg = div({-style=>'margin-bottom: 4%;'}, $msg); }
	
	$html .= html_header(\%headerHash).		
	
	#join(br, map { "$_ = ".param($_) } param()).
		
	$maintitle.
					
	start_form(-name=>'revueform', -method=>'post',-action=>'').
		
		div({-class=>'wcenter'},
						
			span({-style=>"color:red;"}, $msg),
			
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'},"Journal"),
				)
			),
			
			table({-border=>0},
				Tr(
					td({-align=>'left'},span({style=>'padding-right: 10px;'},b("Name"))),
					td({-align=>'left', -style=>'padding-right: 10px;'}, textfield(-class=>'phantomTextField', -name=>'revuename', -style=>'width: 500px;')),
					td({-style=>'padding-right: 10px;'},
						img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"revueform.action='Publications.pl?action=fill&page=pub'; revueform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"revueBack"})
					),
					td(
						img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"revueform.action='Publications.pl?action=enter&page=revue'; revueform.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"revueOk"})
					)
				)
			)
		).
		
		arg_persist().
		
		end_form().
	
	html_footer();
	
	return $html;
}

sub edition_form {

	my ($msg) = @_;
	
	my $html;
			
	my %headerHash = (
		titre => 'Edition',
		css => $css
	);		
		
	if ($msg) { $msg = div({-style=>'margin-bottom: 4%;'},$msg); }
	
	my $villeslist = request_tab("SELECT v.index, v.nom, p.en FROM villes as v LEFT JOIN pays AS p ON v.ref_pays = p.index ORDER BY nom;",$dbc,2);
	my @villesorder;
	my %villeslabels;
	foreach (@{$villeslist}) {
		my $ville = $_->[1];
		if ($_->[2]) { $ville .= " ($_->[2])"; }
		$villeslabels{$_->[0]} = $ville;
		push(@villesorder,$_->[0]);
	}

	
	my $city = Tr(
			td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 25px;'}, span("City ")),
			td({-align=>'left', -style=>'padding-bottom: 25px;'},
				table ({-border=>0},Tr(
					td(popup_menu(-class=>'PopupStyle', -style=>'border: 1px solid #888888;', -name=>"editioncity",-values=>["",@villesorder], -labels=>\%villeslabels)),
					td(
						a({-href=>'generique.pl?table=villes&new=1', -target=>'_blank'}, img ({-name=>'newcity', -src=>'/Editor/new.png', -border=>0}))
					)
				))
			)
	);	

	$html .= html_header(\%headerHash).		
	
	#join(br, map { "$_ = ".param($_) } param()).
	
	$maintitle.
					
	start_form(-name=>'editionform', -method=>'post',-action=>'').
		
		div({-class=>'wcenter'},
						
			span({-style=>"color:red;"}, $msg),
			
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'}, "Edition"),
				)
			),			
			table({-border=>0},
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'}, span("Edition")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'editionname', -style=>'width: 500px;')),
				),
				
				$city,
				
				Tr(
					table({-border=>0},
						Tr(
							td({-style=>'padding-right: 10px;'},
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"editionform.action='Publications.pl?action=fill&page=pub'; editionform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"editionBack"})
							),
							td(
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"editionform.action='Publications.pl?action=enter&page=edition'; editionform.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"editionOk"})
							)
						)
					)
				)
			)
		).
		
		arg_persist().
		
		end_form().
	
	html_footer();
	
	return $html;
}


sub city_form {

	my ($msg) = @_;
	
	my $html;
		
	my %headerHash = (
		titre => 'City',
		css => $css
	);		
		
	if ($msg) { $msg = div({-style=>'margin-bottom: 4%;'},$msg); }
	
	my $payslist = request_tab("SELECT index, en FROM pays ORDER BY en;",$dbc,2);
	my @paysorder;
	my %payslabels;
	foreach (@{$payslist}) {
		my $pays = $_->[1];
		$payslabels{$_->[0]} = $pays;
		push(@paysorder,$_->[0]);
	}

	
	my $pays = Tr(
			td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 25px;'}, span("Country ")),
			td({-align=>'left', -style=>'padding-bottom: 25px;'},
				table ({-border=>0},Tr(
					td(popup_menu(-class=>'PopupStyle', -style=>'border: 1px solid #888888;', -name=>"citycountry",-values=>["",@paysorder], -labels=>\%payslabels)),
					td(
						a({-href=>'generique.pl?table=pays&new=1', -target=>'_blank'}, img({-name=>'newcountry', -src=>'/Editor/new.png', -border=>0}))
					)
				))
			)
	);
	
	$html .= html_header(\%headerHash).
	
	#join(br, map { "$_ = ".param($_) } param()).
	
	$maintitle.
					
	start_form(-name=>'cityform', -method=>'post',-action=>'').
		
		div({-class=>'wcenter'},
						
			span({-style=>"color:red;"}, $msg),
			
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'},"City"),
				)
			),					
			table({-border=>0},
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'}, span("City")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'cityname', -style=>'width: 500px;')),
				),
				
				$pays,
				
				Tr(
					table({-border=>0},
						Tr(
							td({-style=>'padding-right: 10px;'},
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"cityform.action = 'Publications.pl?action=fill&page=edition'; cityform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"cityBack"})
							),
							td(
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"cityform.action = 'Publications.pl?action=enter&page=city'; cityform.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"cityOk"})
							)
						)
					)
				)
			)
		).
				
		arg_persist().
		
		end_form().
	
	html_footer();
	
	return $html;
}

sub country_form {

	my ($msg) = @_;
	
	my $html;
			
	my %headerHash = (
		titre => 'Country',
		css => $css
	);		
		
	if ($msg) { $msg = div({-style=>'margin-bottom: 4%;'},$msg); }
	
	$html .= html_header(\%headerHash).		
	
	#join(br, map { "$_ = ".param($_) } param()).br.
	
	$maintitle.
	
	start_form(-name=>'countryform', -method=>'post',-action=>'').
		
		div({-class=>'wcenter'},
						
			span({-style=>"color:red;"}, $msg),
			
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'},"Country"),
				)
			),
					
			table({-border=>0},
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'},span("English")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'countryen', -style=>'width: 250px;')),
				),
				
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'},span("French")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'countryfr', -style=>'width: 250px;')),
				),
				
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'},span("Spanish")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'countrysp', -style=>'width: 250px;')),
				),
				
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 15px;'},span("German")),
					td({-align=>'left', -style=>'padding-bottom: 15px;'}, textfield(-class=>'phantomTextField', -name=>'countryde', -style=>'width: 250px;')),
				),
				
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 25px;'},span("Portuguese")),
					td({-align=>'left', -style=>'padding-bottom: 25px;'}, textfield(-class=>'phantomTextField', -name=>'countrypt', -style=>'width: 250px;')),
				),
				
				Tr(
					td({-align=>'left', -style=>'padding-right: 10px; padding-bottom: 25px;'},span("Code")),
					td({-align=>'left', -style=>'padding-bottom: 25px;'}, textfield(-class=>'phantomTextField', -name=>'countrycode', -style=>'width: 250px;')),
				),
								
				Tr(
					table({-border=>0},
						Tr(
							td({-style=>'padding-right: 10px;'},
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"countryform.action='Publications.pl?action=fill&page=city'; countryform.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"countryBack"})
							),
							td(
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"countryform.action='Publications.pl?action=enter&page=country'; countryform.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"countryOk"})
							)
						)
					)
				)
			)
		).
		
		arg_persist().
		
		end_form().
	
	html_footer();
	
	return $html;
}


sub pub_form {

	my ($msg) = @_;
		
	my $html;
		
	my $type = param('pubType');
	
	my $jscript = 	$authorsJscript . $jscript_for_hidden;
	
	my %headerHash = (
		titre => 'Publication',
		css => $css,
		jscript => $jscript,
		onLoad=>AonFocus('pub')
	);
		
	my $target = "Publications.pl?action=".url_param('action')."&page=pub";
	
	my ($fiche,$titre,$annee,$volume,$fascicule,$revue,$edition,$pages,$type_publication,$publication_livre);	
	
	$titre = Tr(
			td({-align=>'left'},span("Title ")),
			td(textfield(-class=>'phantomTextField', -name=>'pubtitle', -style=>'width: 700px;', -onFocus=>AonFocus('pub')))
		);
	
	$annee = Tr(
			td({-align=>'left'},span("Year ")),
			td(textfield(-class=>'phantomTextField', -name=>'pubyear', -maxlength=>4, size=>4, -onFocus=>AonFocus('pub')))
		);
		
	my $pages = Tr(
			td({-align=>'left'},span("Pages ")),
			td(textfield(-class=>'phantomTextField', -name=>'pubpgdeb', size=>4, -onFocus=>AonFocus('pub'))." - ".textfield(-class=>'phantomTextField', -name=>'pubpgfin', size=>4, -onFocus=>AonFocus('pub')))
		);
		
	my $nbauts;
	if (param('pubnbauts')) { $nbauts = param('pubnbauts'); }
	else { $nbauts = 1; }
	
	my $form = "pubform";
	
	my $authors_field;
	for (my $i=1;$i<$nbauts;$i++) {
	
		$authors_field .= Tr(	td({-align=>'left',-valign=>'bottom'},span("Author $i ")),
					td(makeAuthorsfields('pub', $i))
				);
	}
	my $i = $nbauts;
	my $last;
	unless ($i == 1) { $last = $i; }
	$authors_field .= Tr(	td({-align=>'left',-valign=>'center'},span("Author $last ")),
				td(
				div({-style=>'position: relative;'},
							makeAuthorsfields('pub', $i).
							div( {-id=>'lessAuts', -onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"ChangeNbAuts(pubform, pubform.pubnbauts, 'less', $nbauts, 'Publications.pl', 'pub');", -style=>'position: absolute; top: 3px; left: 320px;'},img ({-src=>'/Editor/less.png', -border=>0}) ).
							div( {-id=>'moreAuts', -onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"ChangeNbAuts(pubform, pubform.pubnbauts, 'more', $nbauts, 'Publications.pl', 'pub');", -style=>'position: absolute; top: 3px; left: 345px;'},img ({-src=>'/Editor/more.png', -border=>0}) )
					)
				)
			);
	
	$i++;
	while (defined(param("pubAFN$i"))) { Delete("pubAFN$i"); Delete("pubALN$i"); $i++; }
	
	my $hiddens;
	if (url_param('action')) { $hiddens .= hidden('action'); }
	
	unless (param('pubnbauts')) { $hiddens .= hidden('pubnbauts',1); }
			
	if ($type eq 'Article') {
						
		
		my $revueslist = request_tab("SELECT index,nom FROM revues order by nom;",$dbc,2);
		my @revuesorder;
		my %revueslabels;
		foreach (@{$revueslist}) {
			my $rev = $_->[1];
			my $limit = 120;
			if (length($rev) > $limit ) { 
				my @morceaux = split(/ /,$rev);
				my $strlg = 10;
				$rev = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]);
				while (length($rev) > $limit) { $strlg-=1; $rev = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]); }
				
			} 
			$revueslabels{$_->[0]} = $rev;
			push(@revuesorder,$_->[0]);
		}

		
		$revue = Tr(
				td({-align=>'left'},span("Journal ")),
				td(
					table ({-border=>0, -cellspacing=>0, cellpadding=>0},Tr(
						td(popup_menu(-class=>'PopupStyle', -style=>'border: 1px solid #888888;', -name=>"pubrevue",-values=>["",@revuesorder], -labels=>\%revueslabels, -onFocus=>AonFocus('pub'))),
						td({-style=>'padding-left: 6px;'},
							a({-href=>'generique.pl?table=revues&new=1', -target=>'_blank'}, img({-name=>'newrevue', -src=>'/Editor/new.png', -border=>0}))
						)
					))
				)
		);
		
		$volume = Tr(
				td({-align=>'left'},span("Volume ")),
				td(textfield(-class=>'phantomTextField', -name=>'pubvol', size=>4, -onFocus=>AonFocus('pub')))
			);
		
		$fascicule = Tr(
				td({-align=>'left'},span("Fascicule ")),
				td(textfield(-class=>'phantomTextField', -name=>'pubfasc', size=>4, -onFocus=>AonFocus('pub')))
			);
		
		$fiche = $titre . $annee . $authors_field . $revue . $volume . $fascicule . $pages;
		
	}
	
	elsif ($type eq 'Book' or $type eq 'Thesis') {
						
		
		my $editionlist = request_tab("SELECT e.index,e.nom,v.nom,p.en FROM editions AS e LEFT JOIN villes AS v ON (e.ref_ville = v.index) LEFT JOIN pays AS p ON (v.ref_pays = p.index) order by e.nom;",$dbc,2);
		my @editionorder;
		my %editionlabels;
		foreach (@{$editionlist}) {
			my $ed = $_->[1];
			my $limit = 120;
			if (length($ed) > $limit ) {
				my @morceaux = split(/ /,$ed);
				my $strlg = 10;
				$ed = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]);
				while (length($ed) > $limit) { $strlg-=1; $ed = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]); }
			}

			if ($_->[2]) { $ed .= ".  $_->[2]"; }
			if ($_->[3]) { $ed .= " ($_->[3])"; }
			
			$editionlabels{$_->[0]} = $ed;
			push(@editionorder,$_->[0]);
		}

		
		$edition = Tr(
				td({-align=>'left'},span("Edition ")),
				td(
					table ({-border=>0},Tr(
						td(popup_menu(-class=>'PopupStyle', -style=>'border: 1px solid #888888;', -name=>"pubedition",-values=>["",@editionorder], -labels=>\%editionlabels, -onFocus=>AonFocus('pub'))),
						td({-style=>'padding-left: 6px;'},
							a({-href=>'generique.pl?table=editions&new=1', -target=>'_blank'}, img({-name=>'newedition', -src=>'/Editor/new.png', -border=>0}))
						)
					))
				)
		);
		
		if ($type eq 'Book') {
			
			$volume = Tr(
				td({-align=>'left'},span("Volume ")),
				td(textfield(-class=>'phantomTextField', -name=>'pubvol', size=>4, -onFocus=>AonFocus('pub')))
			);
		}
				
		$fiche = $titre . $annee . $authors_field . $edition . $volume . $pages;
		
	}
	
	elsif ( $type eq 'In book' ) {
			
		my $booklist = request_tab("SELECT index FROM publications where ref_type_publication = (SELECT index from types_publication WHERE lower(en) = 'book');", $dbc, 1);
		
		if (scalar(@{$booklist})) {
			
			my %pubs;
			
			foreach (@{$booklist}) {
				
				my $str = pub_formating(get_pub_params($dbc, $_), 'text');
				my $limit = 120;
				if (length($str) > $limit ) {
					my @morceaux = split(/ /,$str);
					my $strlg = 10;
					$str = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]);
					while (length($str) > $limit) { $strlg-=1; $str = join(' ',@morceaux[0..$strlg])." ... ".join(' ',@morceaux[$#morceaux-$strlg..$#morceaux]); }
				}
								
				$pubs{$_} = $str;
			}
			
			my @sortedids = sort { $pubs{$a} cmp $pubs{$b} } keys(%pubs);
			
			my $bookselect = Tr( 
						td({-align=>'left'},span("Book ")),						
						td(popup_menu(-class=>'PopupStyle', -name=>"bookSid", -values=>["",@sortedids], -labels=>\%pubs, -style=>'border: 1px solid #888888; font-size: 15px; width: 820px;'))
					);
					#Tr(
					#	td({-align=>'left'},span("Book id")),
					#	td(textfield(-class=>'phantomTextField', -name=>'bookTid', -style=>'width: 40px;'))
					#);

			
			$fiche = $titre . $annee . $authors_field . $pages . $bookselect
		}
		else { die 'No book available'; }
	}
	
	else { $fiche = $titre . $annee . $authors_field }
	
	if ($msg) { $msg = div({-style=>'margin-bottom: 4%;'},$msg); }
	
	my $backaction;

	if (url_param('action') eq 'modify') { $backaction = "	appendHidden(document.backform, 'searchType', '$type');
								appendHidden(document.backform, 'searchYear', ".param('pubyear').");
								appendHidden(document.backform, 'searchFrom', 'typeSelect.pl?action=update&type=all');
								appendHidden(document.backform, 'searchTo', 'Publications.pl?action=modify');
								appendHidden(document.backform, 'NoNew', '1'); 
								document.backform.action = 'pubsearch.pl?action=getOptions';
								document.backform.submit();" 
	} 
		
	my $back;
	
	if ($backaction) {
		
		$back = start_form(-name=>'backform', -method=>'post').
			
			img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>$backaction, -border=>0, -src=>'/Editor/back.png', -name=>"pubBack"}).
			
			end_form();
	}
	

	$html .= html_header(\%headerHash).

		#join(br, map { "$_ = ".param($_) } param()).
		
		$maintitle.
		
		start_form(-name=>'pubform', -method=>'post',-action=>$target).
		
		div({-class=>'wcenter', -id=>'centre'},
		
			span({-style=>"color:red;"}, $msg),
				
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'},"$type reference"),
				)
			),
					
			table({-cellspacing=>10, -id=>'mytable'},
				$fiche,
				Tr(),Tr(),
				Tr(td(),td(
					table({-border=>0},
						Tr(
							td(
								img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"$form.action='Publications.pl?action=verify'; $form.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"pubOk"})
							)
						)
					)
				))
			),
		
			$hiddens,
		
			arg_persist(),
			
			"<script type='text/javascript'>
				if (document.getElementById('mytable').offsetWidth > 900) { 
					document.getElementById('maintable').style.width = '1400px'; 
					document.getElementById('centre').style.width = '1400px'; 
				}
				else if (document.getElementById('mytable').offsetWidth > 600) { 
					document.getElementById('maintable').style.width = '1200px'; 
					document.getElementById('centre').style.width = '1200px'; 
				}
			</script>".
			
			end_form(),
		
			div ({-style=>'margin-top: 3%;'}, $back )
		).
	
		html_footer();
	
	return $html;
	
}

sub verification {

	my ($dbc) = @_;
	
	my $respons;
	my @elmts;
	
	unless (param("pubtitle")) { push(@elmts,"A publication must have a Title.");}
	unless (int(param("pubyear"))) { push(@elmts,"A publication must have a valid Year. ex: 1915"); }
	else { if (param("pubyear") < 1735) { push(@elmts,"Invalid Year (< 1735)."); } }
	unless (param("pubpgdeb") ) { push(@elmts,"A publication must at least have a Page index."); }
	else { if (param("pubpgfin") and int(param("pubpgdeb")) > int(param("pubpgfin"))) { push(@elmts,"Page interval not allowed."); } }
	unless (param('pubAFN1')) { push(@elmts,"A publication must have an authority."); }
	
	
	if (param('pubType') eq 'Article') { 
		
		unless (param("pubrevue")) { push(@elmts,"An Article must be linked to a revue."); }
	}
	elsif (param('pubType') eq 'In book') {
		
		if (param("bookTid")) { 
			
			param('bookid', param("bookTid"));
			
			my $count = request_row("SELECT count(*) FROM publications WHERE index = ".param('bookTid'),$dbc);
						
			unless ($count->[0]) { push(@elmts,"Invalid Book index."); }
			
		}
		elsif (param("bookSid")) { param('bookid', param("bookSid")); }
		else { push(@elmts,"An In book must be linked to a Book."); }
		
		Delete("bookTid");
		Delete("bookSid");
	}
	
	if (scalar(@elmts)) { $respons = join(br,@elmts); }
	else { $respons = 'ok'; }
	
	return $respons;
}

# make an hash table using form parameters (transmitted by the method post) to feed the pub_formating function
sub make_pub_hash {
	
	my $pubHash = ();
	my $authorsHash = ();
	
	
	$pubHash->{0}{'type'} = param('pubType');
	$pubHash->{0}{'titre'} = param('pubtitle');
	$pubHash->{0}{'annee'} = param('pubyear');
	$pubHash->{0}{'page_debut'} = param('pubpgdeb');
	$pubHash->{0}{'page_fin'} = param('pubpgfin');
	$pubHash->{0}{'nombre_auteurs'} = 0;
	
	my $i = 1;
	while (param("pubAFN$i")) {
		$pubHash->{0}{'nombre_auteurs'} += 1;
		$authorsHash->{$i}{'nom'} = param("pubAFN$i");
		if ( param("pubALN$i") ) { $authorsHash->{$i}{'prenom'} = param("pubALN$i"); }
		$i++;
	}
	
	$pubHash->{0}{'auteurs'} = $authorsHash;
	
	if (param('pubType') eq 'Article') {
		
		$pubHash->{0}{'volume'} = param('pubvol');
		$pubHash->{0}{'fascicule'} = param('pubfasc');
					
		my $name = request_tab("SELECT nom FROM revues WHERE index = ".param('pubrevue'),$dbc,1);
		$pubHash->{0}{'revue'} = $name->[0];
	}	
	elsif (param('pubType') eq 'Book' or param('pubType') eq 'Thesis') {
				
		if (param('pubType') eq 'Book') { $pubHash->{0}{'volume'} = param('pubvol') }
		
		if (param('pubedition')) {
			
			my $edit = request_tab("SELECT e.nom, v.nom, p.en FROM editions AS e LEFT JOIN villes AS v ON ( v.index = e.ref_ville ) LEFT JOIN pays AS p ON ( p.index = v.ref_pays ) WHERE e.index = ".param('pubedition'),$dbc,2);
					
			$pubHash->{0}{'edition'} = $edit->[0][0];
		
			if ( $edit->[0][1] ) { $pubHash->{0}{'ville'} = $edit->[0][1]; }
			if ( $edit->[0][2] ) { $pubHash->{0}{'pays'} = $edit->[0][2]; }
		}
	}
	elsif (param('pubType') eq 'In book') {
					
			$pubHash->{0}{'indexlivre'} = param('bookid');
	}
	
	return $pubHash;
}


# print a pub recapitulation $publi and permit to back for error modify
sub recapitulation {
	
	
	my ($publi) = @_;
	
	my $html;

	my %headerHash = (
		titre => 'Verification',
		css => $css
	);
	
	my @args;
	foreach (param()) { push(@args,"$_ = ".param($_)) }
	
	my $type;
	if (param('pubType')) { $type = param('pubType') }

	
	my $back;
	my $oktgt;
	
	$back = img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"pubverif.action='Publications.pl?action=fill&page=pub'; pubverif.submit();", -border=>0, -src=>'/Editor/back.png', -name=>"pubBack"});
	
	if (param('pubupdate')) {		
		
		my $pubid = param('pubupdate');
		
		$oktgt = "Publications.pl?action=update&pubid=$pubid";
	}
	else {
		$oktgt = "Publications.pl?action=enter&page=pub";
	}
	
		
	$html .= html_header(\%headerHash).
		
		#join(br, map { "$_ = ".param($_) } param()).
		
		$maintitle.
		
		start_form(-name=>'pubverif', -method=>'post',-action=>'').
		
		div({-class=>'wcenter'},
		
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'font-size: 18px; font-style: italic;'}, "$type reference"),
				)
			),
			
			table({-border=>0,-width=>1000},Tr(td({-style=>''}, $publi))), p, br,
			
			table({-border=>0,-cellspacing=>0, cellpadding=>0}, Tr(
				td({-style=>'padding-right: 100px;'}, img({-onMouseOver=>"this.style.cursor = 'pointer';", -onClick=>"pubverif.action='$oktgt'; pubverif.submit();", -border=>0, -src=>'/Editor/ok.png', -name=>"pubOk"}) ),
				td( $back )
			) )
		).
		
		arg_persist().
		
		end_form().
	
		html_footer();
		
	return $html;
}

