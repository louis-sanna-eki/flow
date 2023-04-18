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
	TXPform($new_elem);
}
elsif ($action eq 'verify') {
	TXPrecap();
}
elsif ($action eq 'enter') {
	TXPinsert();
}
elsif ($action eq 'more') {
	$new_elem = param('new_elem') + 1;
	Delete('new_elem');
	TXPform($new_elem);
}

sub TXPinsert {
	
	my %headerHash = (
		titre => "Taxon distribution",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $req = "SELECT index, en FROM pays ORDER BY tdwg_level DESC, en;";
	
	my $pays = request_tab($req,$dbc,2);
	
	my %paysid;
	foreach (@{$pays}) {
		unless (exists $paysid{$_->[1]}) {
			$paysid{$_->[1]} = $_->[0];
		}
	}

	my $taxon = param('taxonX');
	
	$req = "DELETE FROM taxons_x_pays WHERE ref_taxon = $taxon";
						
	my $sth = $dbc->prepare($req) or die "$req: ".$dbc->errstr;
		
	$sth->execute() or die "$req: ".$dbc->errstr;
	
	my $tot = param('old_elem')+param('new_elem');
		
	for (my $i=0; $i<$tot; $i++) {
		
		if (my $pays = param("ref_pays$i")) {
			
			my $pub = param("p$i") || 'NULL';
			
			$req = "INSERT INTO taxons_x_pays (ref_taxon, ref_pays, ref_publication_ori, createur, modificateur) VALUES ($taxon, ".$paysid{$pays}.", $pub, '$user', '$user')";
							
			my $sth = $dbc->prepare($req) or die "$req: $dbc->errstr";
		
			$sth->execute() or die "$req: $dbc->errstr";
		}
		Delete("ref_pays$i");
		Delete("p$i");
	}
	
	#Delete(param());
	
	for (my $i=param('old_elem'); $i<param('old_elem')+param('new_elem'); $i++ ) { 	
		Delete("ref_pays$i");
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
				-onClick=>"Form.action = 'taxonXcountries.pl?action=fill'; Form.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			end_form(),
			
			p, br,
			
			a({ -href=>"taxonXhp.pl?action=fill&taxonX=$taxid", -style=>'text-decoration: none;'}, "Taxon host plants"), p,
			
			a({ -href=>"taxaSelect.pl?target=country", -style=>'text-decoration: none;'}, "New taxon"), p, br,
			
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
		), p,
	
		html_footer();
}


sub TXPrecap {
	
	my %headerHash = (
		titre => "Taxon distribution",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $req = "SELECT orthographe, autorite FROM noms_complets AS nc LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
	WHERE txn.ref_taxon = $taxon AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid');";
	
	my $taxname = request_tab($req,$dbc,2);
	
	$req = "SELECT index, en FROM pays ORDER BY tdwg_level DESC, en;";
	
	my $pays = request_tab($req,$dbc,2);
	
	my %paysid;
	foreach (@{$pays}) {
		unless (exists $paysid{$_->[1]}) {
			$paysid{$_->[1]} = $_->[0];
		}
	}
	
	my $refs;
	my $exceptions;
	
	my $tot = param('old_elem')+param('new_elem');
	
	for (my $i=0; $i<$tot; $i++) {
		
		if (param("ref_pays$i")) {
			
			my @core = split(/ \/ /, param("ref_pays$i"));
			Delete("ref_pays$i");
			param("ref_pays$i", $core[0]);
			my $parami = $core[0];
			my $pi = param("p$i");
			
			if (exists $paysid{$parami}) {
				$refs->{$parami}{$i} = span({-style=>'color: #FF6633;'}, "Found in ") . span({-style=>'font-weight: bold;'}, $parami) . br;
				if($pi) {
					$refs->{$parami}{$i} .= span({-style=>'color: #FF6633;'},"according to ") . pub_formating(get_pub_params($dbc, $pi), 'html') . br;
				}
				$refs->{$parami}{$i} .= br;
			}
			else {
				$exceptions .= img({-border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"CAUTION"}) . span({-style=>'color: brown'}, "&nbsp; The country ") . span({-style=>'color: red'}, b($parami)) . span({-style=>'color: brown'}," is unvalid it has been deleted...") . p;
				Delete("ref_pays$i");
				Delete("p$i");
			}
		}
		else {
			Delete("ref_pays$i");
			Delete("p$i");
		}
	}
	
	if ($exceptions) { $exceptions .= span({-style=>'color: red'}, "If you want to create a country use the proper option." ) . p; }
	
	my @sortedids = sort { $a cmp $b } keys(%{$refs});
	
	foreach my $country (@sortedids) {
		if (scalar(keys(%{$refs->{$country}})) > 1) {
			my $nul = 'vide';
			my $bon = 'vide';
			foreach my $id (keys(%{$refs->{$country}})) {
				if (param("p$id")) {
					$bon = $id;
					if ($nul ne 'vide') {
						Delete("ref_pays$nul");
						Delete("p$nul");
						delete $refs->{$country}{$nul};
					}
				}
				else {
					if ($nul ne 'vide' or $bon ne 'vide') {
						Delete("ref_pays$id");
						Delete("p$id");
						delete $refs->{$country}{$id};
					}
					else {
						$nul = $id;
					}
				}
			}
		}
	}
	
	my $display;
	foreach my $country (@sortedids) {
		foreach my $id (keys(%{$refs->{$country}})) {
			$display .= $refs->{$country}{$id};
		}
	}
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()), br,
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
									
			div({-id=>'boutons', -style=>'display: none;'},
			
				span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
					-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
					-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=enter'; LocalitiesForm.submit();"
					},
					img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
				),

				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
				span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
					-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
					-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=fill'; LocalitiesForm.submit();"
					},
					img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
				),
			
				"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
				
				a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
				p
			),
			
			"Geographical distribution by countries of ", b("$taxname->[0][0] $taxname->[0][1]"), p,
			
			start_form(-name=>'LocalitiesForm', -method=>'post',-action=>''),
			
			$exceptions,
			
			$display,
			
			p,
			
			arg_persist(),

			end_form(),
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src')",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=enter'; LocalitiesForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			),

			"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
			
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=fill'; LocalitiesForm.submit();"
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


sub makeRelation {

	my ($i, $paysfield) = @_;
	
	my $default;
	my $label;
	if(param("treatp$i")) {
		Delete("treatp$i");
		if (param("p$i")) { Delete("p$i"); }
		$default = param('searchPubId');
		Delete('searchPubId');
		$label  .= div({-id=>"label$i", -style=>'width: 700px; color: crimson;'}, pub_formating(get_pub_params($dbc, $default), 'html') . p);
	}
	elsif (param("p$i")) {
		$default = param("p$i");
		Delete("p$i");
		$label  .= div({-id=>"label$i", -style=>'width: 700px; color: crimson;'}, pub_formating(get_pub_params($dbc, $default), 'html') . p);
	}
	
	return 	$paysfield.
       		" pub ref ".
		textfield(-class=>'phantomTextField', -name=>"p$i", size=>4, -default=>$default, -onBlur=>"LocalitiesForm.action='taxonXcountries.pl?action=fill';  LocalitiesForm.submit();").
		"&nbsp;" . 
		div(	{-style=>'display: inline;',
			-onMouseover=>"searchp.src=eval('searchonimg.src'); this.style.cursor='pointer';",
			-onMouseout=>"searchp.src=eval('searchoffimg.src')",
			-onClick=>"	appendHidden(document.LocalitiesForm, 'searchFrom', 'taxonXcountries.pl?action=fill');
					appendHidden(document.LocalitiesForm, 'searchTo', 'taxonXcountries.pl?action=fill');
					appendHidden(document.LocalitiesForm, 'treatp$i', '1');
					LocalitiesForm.action='pubsearch.pl?action=getOptions'; LocalitiesForm.submit();"},
			img({-border=>0, -src=>'/Editor/search0.png', -name=>"searchp"}) 
		).
		"&nbsp;&nbsp;".
		div(	{-style=>'display: inline;',
			-onMouseover=>"pubnew.src=eval('newonimg.src'); this.style.cursor='pointer';",
			-onMouseout=>"pubnew.src=eval('newoffimg.src')",
			-onClick=>"	appendHidden(document.LocalitiesForm, 'searchFrom', 'taxonXcountries.pl?action=fill');
					appendHidden(document.LocalitiesForm, 'searchTo', 'taxonXcountries.pl?action=fill');
					appendHidden(document.LocalitiesForm, 'treatp$i', '1');
					LocalitiesForm.action='typeSelect.pl?action=add&type=pub'; LocalitiesForm.submit();"},	
			img({-border=>0, -src=>'/Editor/new0.png', -name=>"pubnew"}) 		
		).
		p.
		$label.
		hr;
}

sub TXPform {
	
	my ($new_elem) = @_;
	
	my $req = "SELECT orthographe, autorite FROM noms_complets AS nc LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index 
	WHERE txn.ref_taxon = $taxon AND ref_statut = (SELECT index FROM statuts WHERE en = 'valid');";
	
	my $taxname = request_tab($req,$dbc,2);
	
	$req = "SELECT ref_pays, ref_publication_ori, en FROM taxons_X_pays  LEFT JOIN pays ON pays.index = ref_pays WHERE ref_taxon = $taxon ORDER BY en;";
	
	my $taxXpays = request_tab($req,$dbc,2);
	
	$req = "SELECT en, tdwg_level FROM pays ORDER BY tdwg_level DESC, en;";
	
	my $pays = request_tab($req,$dbc,2);
	
	my @formpays;
	my %done;
	foreach (@{$pays}) {
		unless (exists $done{$_->[0]}) {
			push(@formpays, "$_->[0] / (Level $_->[1])");
			$done{$_->[0]} = 1;
		}
	}
	
	my $relations;
	
	my $i=0;
	
	my $autofields;
	
	foreach my $relation (@{$taxXpays}) {
		
		my $default;
		
		unless ($default = param("ref_pays$i")) { $default = $relation->[2]; }
		
		my $paysfield = textfield(
			-class=>'phantomTextField',
			-name=>"ref_pays$i",
			-size=>40,
			-default=>$default,
			-id=>"ac$i",
			-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));"
		);
		
		$autofields .= "AutoComplete_Create('ac$i', data, 20);";
		
		unless(param("p$i")) { param("p$i", $relation->[1]) }
		
		$relations .= makeRelation($i, $paysfield);
		$i++;
	}
	
	my $addlink; 
	
	my $advise;
	unless ($i or $new_elem) { $new_elem = 1 }
	if ($new_elem >= 5) { $new_elem = 5; $advise = span({-style=>'color: crimson;'}, "Please, finish the entering process, and then, click on BACK button to add more distribution") . p;  }
	else { $addlink = span({-style=>'color: blue;', -onClick=>"LocalitiesForm.action='taxonXcountries.pl?action=more'; LocalitiesForm.submit();", -onMouseOver=>"this.style.cursor = 'pointer'"}, "Add a link").
			img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what",
					-onClick=>"document.getElementById('helpmsg0').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}).
			
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg0'}, br . "Add another relation between $taxname->[0][0] $taxname->[0][1] and another country" . br).
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
 }
	
	my $newlinks;
	
	for (my $j=$i; $j<$i+$new_elem; $j++) {
		
		my $default;
		
		$default = param("ref_pays$j");
		
		my $paysfield = textfield(
			-class=>'phantomTextField', 
			-name=>"ref_pays$j", 
			-size=>40, 
			-default=>$default, 
			-id=>"ac$j", 
			-onFocus=>"AutoComplete_ShowDropdown(this.getAttribute('id'));"
		);
		
		$autofields .= "AutoComplete_Create('ac$j', data, 20);";
		
		$newlinks = makeRelation($j, $paysfield) . $newlinks;
	}
		
	my $onload = "	data = ['".join("','", @formpays)."'];
			$autofields
			if (top.location.href != location.href) {
				top.location.href = location.href;
			};";
	
	my %headerHash = (
		titre => "Taxon distribution",
		bgcolor => $background,
		css => $css,
		jscript => [{-language=>'JAVASCRIPT', -code=>"$jscript_imgs"}, {-language=>'JAVASCRIPT', -code=>"$jscript_for_hidden"}, {-language=>'JAVASCRIPT', -src=>'/Editor/SearchAutoComplete.js'}],
		onLoad => $onload
	);
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
			
			a({ -href=>"/Editor/TDWG_geo2.pdf", -style=>'text-decoration: none;', -target=>'_blank'}, "TDWG_geo2.pdf"), p,
			
			"Geographical distribution by countries of ", span({-style=>'font-weight: bold;'}, "$taxname->[0][0] $taxname->[0][1]"), br, br,
			
			span({-style=>'color: #FF3300'}, "After entering the index of any publication, click anywhere outside of the index field 
			in order to make the complete reference appear"), 
			
			p,
			
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=verify'; LocalitiesForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			), 
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
			
			a(	{-href=>"taxaSelect.pl?target=country",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
						
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
			
			p,
			
			start_form(-name=>'LocalitiesForm', -method=>'post',-action=>''),
			
			$addlink,
			
			a({href=>'generique.pl?table=pays', target=>'_blank', style=>'text-decoration: none;', 
			onClick=>"document.getElementById('redalert').style.display = 'inline';"}, "Add a country"),
			img({	-style=>'height: 10px; width: 10px;', -border=>0, -src=>'/Editor/what1.png', -alt=>'What?', -name=>"what", 
				-onClick=>"document.getElementById('helpmsg1').style.display = 'inline';", -onMouseOver=>"this.style.cursor = 'pointer'"}),
			span({-style=>'display: none; color: #FF3300;', -id=>'helpmsg1'}, br . "A new tab/window will open, when data are entered, close the tab/window, go back to the the current page and reload it" . br),
			
			p,
						
			$advise,
			
			hr,									
			
			$newlinks,
			$relations,
			
			p,
			
			arg_persist(),	
			
			hidden('new_elem', $new_elem),
			hidden('old_elem', $i),
			
			end_form(),
						
			span(	{-onMouseover=>"document.okbtn.src=eval('okonimg.src'); this.style.cursor='pointer';",
				-onMouseout=>"document.okbtn.src=eval('okoffimg.src')",
				-onClick=>"LocalitiesForm.action = 'taxonXcountries.pl?action=verify'; LocalitiesForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn"})
			), 
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
			
			a(	{-href=>"taxaSelect.pl?target=country",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
						
			a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})),
												
		), p,
	
		html_footer();
}

$dbc->disconnect();
exit;
