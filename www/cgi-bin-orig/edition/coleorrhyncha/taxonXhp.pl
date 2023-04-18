#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/coleorrhyncha/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use DBTNTcommons qw (pub_formating get_pub_params);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel);

Delete("genusX"); Delete("taxonOrder"); Delete("target");

my $user = remote_user();

my $cell1 = 250;
my $cell2 = 150;

my $dbc = db_connection(get_connection_params($conf_file));

my $taxon;
if (param('taxonX')) {
	$taxon = param('taxonX');
}
elsif (url_param('taxonX')) {
	$taxon = url_param('taxonX');
	param('taxonX', url_param('taxonX'));
}
my $new_elem;

my $action = url_param('action');

if ($action eq 'fill') {
	$new_elem = param('new_elem') || 0;
	TXHPform($new_elem);
}
elsif ($action eq 'verify') {
	TXHPrecap();
}
elsif ($action eq 'enter') {
	TXHPinsert();
}
elsif ($action eq 'more') {
	$new_elem = param('new_elem') + 1;
	Delete('new_elem');
	TXHPform($new_elem);
}

sub TXHPinsert {
	
	my %headerHash = (
		titre => "Taxon host plant(s)",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $taxon = param('taxonX');
	
	my $req = "DELETE FROM taxons_x_plantes WHERE ref_taxon = $taxon";
						
	my $sth = $dbc->prepare($req) or die "$req: $dbc->errstr";
		
	$sth->execute() or die "$req: $dbc->errstr";
	
	my $tot = param('old_elem')+param('new_elem');
	
	for (my $i=0; $i<$tot; $i++) {
		
		if (my $hp = param("ref_hp$i")) {
			
			my $pub = param("p$i") || 'NULL';
			my $cert = param("cert$i") || 'NULL';
			
			$req = "INSERT INTO taxons_x_plantes (ref_taxon, ref_plante, certitude, ref_publication_ori, createur, modificateur) VALUES ($taxon, $hp, '$cert', $pub, '$user', '$user')";
							
			my $sth = $dbc->prepare($req) or die "$req: $dbc->errstr";
		
			$sth->execute() or die "$req: $dbc->errstr";
		}
		Delete("ref_hp$i");
		Delete("hp$i");
		Delete("p$i");
		Delete("cert$i");
	}
	
	#Delete(param());
	
	for (my $i=param('old_elem'); $i<param('old_elem')+param('new_elem'); $i++ ) { 	
		Delete("ref_hp$i");
		Delete("p$i");
	}
	Delete('old_elem');
	Delete('new_elem');
	
	my $taxid = param('taxonX');
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
			
			img{-src=>'/Editor/done.jpg'}, p,
			
			span({-style=>'color: green'}, "Taxon treated"),
			
			p, br,
			
			start_form(-name=>'Form', -method=>'post',-action=>'').
			
			arg_persist(),
			
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"Form.action = 'taxonXhp.pl?action=fill'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			end_form(),
			
			p, br,
			
			a({ -href=>"taxonXcountries.pl?action=fill&taxonX=$taxid", -style=>'text-decoration: none;'}, "Taxon geographical distribution"), p,
			
			a({ -href=>"taxaSelect.pl?target=hostplant", -style=>'text-decoration: none;'}, "New taxon"), p, br,
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		), p,
	
		html_footer();
}


sub TXHPrecap {
	
	my %headerHash = (
		titre => "Taxon host plant(s)",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $req = "SELECT orthographe, autorite FROM noms_complets AS nc LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
	WHERE txn.ref_taxon = $taxon AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid');";
	
	my $taxname = request_tab($req,$dbc,2);
	
	my $refs;
	
	my $tot = param('old_elem')+param('new_elem');
	
	for (my $i=0; $i<$tot; $i++) {
		if (param("ref_hp$i")) {
			
			my $hpX = param("ref_hp$i");
			my $hpstr;
			
			my ($rang) = @{request_tab("SELECT r.en FROM plantes AS p LEFT JOIN rangs AS r ON r.index = p.ref_rang WHERE p.index = $hpX;", $dbc, 1)};
			
			if ($rang eq 'family') {
				
				$req = "SELECT p1.nom, p1.autorite
					FROM plantes AS p1
					WHERE p1.index = $hpX
					ORDER BY p1.nom;";
				
				my $hpfa = request_tab($req,$dbc,2);
				$hpstr = "$hpfa->[0][0] $hpfa->[0][1]";
			
			}
			elsif ($rang eq 'genus') {

				$req = "SELECT p2.nom, p1.nom, p1.autorite
					FROM plantes AS p1
					LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
					WHERE p1.index = $hpX
					ORDER BY p1.nom, p2.nom;";
				
				my $hpge = request_tab($req,$dbc,2);
				$hpstr = "$hpge->[0][1] $hpge->[0][2] ($hpge->[0][0])";
			
			}
			elsif ($rang eq 'species') {
				
				$req = "SELECT p3.nom, p2.nom, p1.nom, p1.autorite
					FROM plantes AS p1
					LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
					LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent
					WHERE p1.index = $hpX
					ORDER BY p2.nom, p1.nom, p3.nom;";
				
				my $hpsp = request_tab($req,$dbc,2);
				$hpstr = "$hpsp->[0][1] $hpsp->[0][2] $hpsp->[0][3] ($hpsp->[0][0])";
			}
			
			$refs->{$hpstr}{$i} = span({-style=>'color: #FF6633;'}, "Found on ") . span({-style=>'color: navy;'}, $hpstr) . br;
			if(param("p$i")) {
				$refs->{$hpstr}{$i} .= span({-style=>'color: #FF6633;'}, "according to ") . span({-style=>'color: navy;'}, pub_formating(get_pub_params($dbc, param("p$i")), 'html')) . br;
			}
			if(param("cert$i") eq 'certain') {
				$refs->{$hpstr}{$i} .= span({-style=>'color: navy;'}, "Data confirmed by biology.") . br;
			}
			$refs->{$hpstr}{$i} .= br;
		}
		else {
			Delete("ref_hp$i");
			Delete("p$i");
		}
	}
	
	my @sortedids = sort { $a cmp $b } keys(%{$refs});
	
	foreach my $host (@sortedids) {
		if (scalar(keys(%{$refs->{$host}})) > 1) {
			my $nul = 'vide';
			my $bon = 'vide';
			foreach my $id (keys(%{$refs->{$host}})) {
				if (param("p$id")) {
					$bon = $id;
					if ($nul ne 'vide') {
						Delete("ref_hp$nul");
						Delete("p$nul");
						delete $refs->{$host}{$nul};
					}
				}
				else {
					if ($nul ne 'vide' or $bon ne 'vide') {
						Delete("ref_hp$id");
						Delete("p$id");
						delete $refs->{$host}{$id};
					}
					else {
						$nul = $id;
					}
				}
			}
		}
	}
	
	my $display;
	foreach my $host (@sortedids) {
		foreach my $id (keys(%{$refs->{$host}})) {
			$display .= $refs->{$host}{$id};
		}
	}
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
			
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
			
		div({-class=>"wcenter"},
			
			br,
			
			div({-id=>'boutons', -style=>'display: none;'},
			
				span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
					-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
					-onClick=>"Form.action = 'taxonXhp.pl?action=enter'; Form.submit();"
					},
					img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
				),

				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
				span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
					-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
					-onClick=>"Form.action = 'taxonXhp.pl?action=fill'; Form.submit();"
					},
					img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
				),
			
				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
				
				a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
				p
			),
			
			"Host plant(s) of ", b("$taxname->[0][0] $taxname->[0][1]"),
			
			p,
						
			start_form(-name=>'Form', -method=>'post',-action=>''),

			$display,
			
			p,
			
			arg_persist(),

			end_form(),
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"Form.action = 'taxonXhp.pl?action=enter'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			),
			
			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"Form.action = 'taxonXhp.pl?action=fill'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),

			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		),p,
	
		"<script type='text/javascript'>
		<!--
		document.getElementById('boutons').style.display = 'inline';
		//-->
		</script>",

		html_footer();
}


sub makeRelation {

	my ($i, $field) = @_;
	
	my $default;
	my $label;
	if(param("treatp$i")) {
		Delete("treatp$i");
		if (param("p$i")) { Delete("p$i"); }
		$default = param('searchPubId');
		Delete('searchPubId');
		$label  .= Tr(td({-colspan=>6, -style=>'width: 800px;'}, div({-id=>"label$i", -style=>'color: crimson;'}, pub_formating(get_pub_params($dbc, $default), 'html') . p) ));
	}
	elsif (param("p$i")) {
		$label  .= Tr(td({-colspan=>6, -style=>'width: 800px;'}, div({-id=>"label$i", -style=>'color: crimson;'}, pub_formating(get_pub_params($dbc, param("p$i")), 'html') . p) ));
	}
	
	
	return Tr(
		td($field),
		td(popup_menu(-name=>"cert$i", -values=>["certain", 'uncertain'], -class=>'PopupStyle', -default=>param("cert$i"))),
		td("publication ID"),
		td(textfield(-class=>'phantomTextField', -name=>"p$i", size=>4, -default=>$default, -onBlur=>"Form.action='taxonXhp.pl?action=fill';  Form.submit();")),
		td(
			div(	{-onMouseover=>"searchp.src=eval('searchonimg.src');",
				-onMouseout=>"	searchp.src=eval('searchoffimg.src')",
				-onClick=>"	appendHidden(document.Form, 'searchFrom', 'taxonXhp.pl?action=fill');
						appendHidden(document.Form, 'searchTo', 'taxonXhp.pl?action=fill');
						appendHidden(document.Form, 'treatp$i', '1');
						Form.action='pubsearch.pl?action=getOptions'; Form.submit();"},
				
				img({-border=>0, -src=>'/Editor/search0.png', -name=>"searchp"})
			)					
		),
		td(
			div(	{-onMouseover=>"pubnew.src=eval('newonimg.src')",
				-onMouseout=>"	pubnew.src=eval('newoffimg.src')",
				-onClick=>"	appendHidden(document.Form, 'searchFrom', 'taxonXhp.pl?action=fill');
						appendHidden(document.Form, 'searchTo', 'taxonXhp.pl?action=fill');
						appendHidden(document.Form, 'treatp$i', '1');
						Form.action='typeSelect.pl?action=add&type=pub'; Form.submit();"},
				
				img({-border=>0, -src=>'/Editor/new0.png', -name=>"pubnew"})
			)					
		),
		td('&nbsp;')
	) . $label;
}

sub TXHPform {
	
	my ($new_elem) = @_;
	
	my $req = "	SELECT orthographe, autorite 
			FROM noms_complets AS nc 
			LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
			WHERE txn.ref_taxon = $taxon 
			AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid');";
	
	my $taxname = request_tab($req,$dbc,2);
	
	$req = "SELECT ref_plante, ref_publication_ori, certitude, p3.nom, p2.nom, p1.nom, p1.autorite
		FROM taxons_X_plantes
		LEFT JOIN plantes AS p1 ON p1.index = ref_plante
	        LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent 
		LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE ref_taxon = $taxon 
		AND r.en = 'species'
		ORDER BY p2.nom, p1.nom, p3.nom;";
	
	my $taxXhpsp = request_tab($req,$dbc,2);
	
	$req = "SELECT ref_plante, ref_publication_ori, certitude, p2.nom, p1.nom, p1.autorite
		FROM taxons_X_plantes
		LEFT JOIN plantes AS p1 ON p1.index = ref_plante
	        LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent 
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE ref_taxon = $taxon 
		AND r.en = 'genus'
		ORDER BY p1.nom, p2.nom;";
	
	my $taxXhpge = request_tab($req,$dbc,2);
	
	$req = "SELECT ref_plante, ref_publication_ori, certitude, p1.nom, p1.autorite
		FROM taxons_X_plantes
		LEFT JOIN plantes AS p1 ON p1.index = ref_plante
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE ref_taxon = $taxon
		AND r.en = 'family'
		ORDER BY p1.nom;";
	
	my $taxXhpfa = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.autorite, p3.nom, p2.nom, p1.nom
		FROM plantes AS p1
       		LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
		LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE r.en = 'species'
		ORDER BY p2.nom, p1.nom, p3.nom;";
	
	my $hpsp = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.autorite, p2.nom, p1.nom
		FROM plantes AS p1
       		LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE r.en = 'genus'
		ORDER BY p1.nom, p2.nom;";
	
	my $hpge = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.autorite, p1.nom
		FROM plantes AS p1
		LEFT JOIN rangs AS r ON r.index = p1.ref_rang
		WHERE r.en = 'family'
		ORDER BY p1.nom;";
	
	my $hpfa = request_tab($req,$dbc,2);
	
	my $relations;
	my $autofields;
	
	my $hplabels;
	foreach my $hplabl (@{$hpfa},@{$hpge},@{$hpsp}) {
			my $lab;
			if ($hplabl->[4]) {
				$lab = "$hplabl->[3] $hplabl->[4] $hplabl->[1] ($hplabl->[2])";
			}
			elsif ($hplabl->[3]) {
				$lab = "$hplabl->[3] $hplabl->[1] ($hplabl->[2])";
			}
			else {
				$lab = "$hplabl->[2] $hplabl->[1]";
			}
			$lab =~ s|  | |;
			$hplabels .= 'data["'.$lab.'"] = '.$hplabl->[0].';';
	}
	
	my $i=0;
	
	my $hiddens;
	foreach my $relation (@{$taxXhpfa},@{$taxXhpge},@{$taxXhpsp}) {

		my $default;
		unless ($default = param("hp$i")) {
			if ($relation->[6]) {
				$default = "$relation->[4] $relation->[5] $relation->[6] ($relation->[3])";
			}
			elsif ($relation->[5]) {
				$default = "$relation->[4] $relation->[5] ($relation->[3])";
			}
			else {
				$default = "$relation->[3] $relation->[4]";
			}
			$hiddens .= hidden("ref_hp$i", $relation->[0]);
		}
		
		unless(param("p$i")) { param("p$i", $relation->[1]); }
		unless(param("cert$i")) { param("cert$i", $relation->[2]); }
		
		my $hpfield = textfield(
			-class=>'phantomTextField',
			-id=>"ac$i",
			-name=>"hp$i",
			-size=>60,
			-default=>$default,
			-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));",
			-onChange=>"if (!this.value) { document.Form.ref_hp$i.value = ''; } else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }"
		);
		
		$autofields .= "AutoComplete_Create('ac$i', data, 20, 'ref_hp$i', 'Form');";
		
		$relations .= makeRelation($i, $hpfield);
		$i++;
	}
	
	my $new_relations;
	my $advise;
	unless ($i or $new_elem) { $new_elem = 1 }
	if ($new_elem >= 5) { $new_elem = 5; $advise = span({-style=>'color: crimson;'}, "Please, finish the entering process, and then, click on BACK button to add more Host plants") . p; }
	
	for (my $j=$i; $j<$i+$new_elem; $j++) {
		
		my $default;
		unless ($default = param("hp$j")) { 
			$hiddens .= hidden("ref_hp$j", '');
		}
		
		my $hpfield = textfield(
			-class=>'phantomTextField',
			-id=>"ac$j",
			-name=>"hp$j",
			-size=>60,
			-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));",
			-onChange=>"if(!this.value) { document.Form.ref_hp$j.value = ''; } else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }"
		);
		
		$autofields .= "AutoComplete_Create('ac$j', data, 20, 'ref_hp$j', 'Form');";
		
		$new_relations = makeRelation($j, $hpfield) . $new_relations;
	}
	
	my $onload = "	var data = {};
			$hplabels;
			$autofields";
	
	my %headerHash = (
		titre => "Taxon host plant(s)",
		bgcolor => $background,
		css => $css,
		jscript => [{-language=>'JAVASCRIPT', -code=>"$jscript_imgs"}, 
				{-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, 
				{-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoCompleteHash.js'}],
		onLoad => $onload
	);

	print 	html_header(\%headerHash),

		#join(br, map { "$_ = ".param($_) } param()),
			
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
			
			"Host plant(s) of ", span({-style=>'font-weight: bold;'}, "$taxname->[0][0] $taxname->[0][1]"),
			
			p,						
			
			span({-style=>'color: #FF3300'}, "After entering the index of any publication, click anywhere outside of the index field 
			in order to make the complete reference appear"), br, br,
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"Form.action = 'taxonXhp.pl?action=verify'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			),

			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a(	{-href=>"taxaSelect.pl?target=hostplant",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),

			p,
			
			span({-style=>'color: blue;', -onClick=>"Form.action='taxonXhp.pl?action=more'; Form.submit();", -onMouseOver=>"this.style.cursor = 'pointer'"}, "Add a link"),
			img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what",
				-onClick=>"document.getElementById('helpmsg0').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}),
				
			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;", 
			
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg0'}, br. "Add another relation between $taxname->[0][0] $taxname->[0][1] and another host plant" . br) .

			a({href=>'Plants.pl?action=fill', target=>'_blank', style=>'text-decoration: none;', 
			onClick=>"document.getElementById('redalert').style.display = 'inline';"}, "Add an host plant"),
			img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what", 
				-onClick=>"document.getElementById('helpmsg1').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}),
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg1'}, br . "A new tab/window will open, when data are entered, close the tab/window, go back to the the current page and reload it" . br),
			
			p,
									
			start_form(-name=>'Form', -method=>'post',-action=>''),
			
			$advise,

			table({ -border=>0 , -cellspacing=>6 , bgcolor=>$rowcolor},
				$new_relations,
				$relations
			),
			
			$hiddens,
			arg_persist(),

			hidden('new_elem', $new_elem),
			hidden('old_elem', $i),
			
			end_form(),
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"Form.action = 'taxonXhp.pl?action=verify'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			),

			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a(	{-href=>"taxaSelect.pl?target=hostplant",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		), p,
	
		html_footer();
}

$dbc->disconnect();
exit;
