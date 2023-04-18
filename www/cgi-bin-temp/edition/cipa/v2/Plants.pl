#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use DBTNTcommons qw (pub_formating get_pub_params);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel);

Delete("target");

my $dbc = db_connection(get_connection_params($conf_file));

my $nb_elem;

my $action = url_param('action');

if ($action eq 'fill') {
	$nb_elem = param('nb_elem') || 1;
	HPform($nb_elem);
}
elsif ($action eq 'verify') {
	HPrecap();
}
elsif ($action eq 'enter') {
	HPinsert();
}
elsif ($action eq 'more') {
	$nb_elem = param('nb_elem') + 1;
	Delete('nb_elem');
	HPform($nb_elem);
}
elsif ($action eq 'modify') {
	HPprecise();
}
elsif ($action eq 'change') {
	HPform(0);
}
elsif ($action eq 'update') {
	updateHPform();
}

sub HPprecise {

	my %headerHash = (
		titre => "Host Plant",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
		onLoad => "	if (document.PlantsForm.rankX.value == 'species') { document.PlantsForm.text.value = 'Specific epithet'; document.PlantsForm.text.style.width = '120px'; }
				else { document.PlantsForm.text.value = 'Name'; document.PlantsForm.text.style.width = '60px'; }"
	);
	
	print 	html_header(\%headerHash),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
			
			table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Host plant"),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			),

			start_form(-name=>'PlantsForm', -method=>'post', -action=>'Plants.pl?action=change'),
			
			'Level &nbsp;', 
			
			popup_menu(	-class=>'PopupStyle', -name=>'rankX', -values=>['','order','family','genus','species'], 
			-onChange=>"if (this.value == 'species') { form.text.value = 'Specific epithet'; form.text.style.width = '120px'; } else { form.text.value = 'Name'; form.text.style.width = '60px'; }"
			),
			
			br, br,
			
			textfield({-class=>'phantomTextField', -name=>'text', -style=>'padding: 0; color: navy; background: transparent; border: 0; width: 40px;', -readonly=>'readonly', -value=>'Name'}),
			
			textfield({-class=>'phantomTextField', -name=>'startX', -style=>'width: 200px;'}),
			
			br, br, br, br,
			
			span(	{-onMouseover=>"nameOk.src=eval('okonimg.src')",
				-onMouseout=>"nameOk.src=eval('okoffimg.src')",
				-onClick=>"document.PlantsForm.submit();"},
				
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"nameOk"})
			),
			
			br, br,
			
			a(	{-href=>"typeSelect.pl?action=update&type=all",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			),
			
			br, br,
			
			a(	{-href=>"action.pl",
				-onMouseOver=>"mM.src=eval('mMonimg.src')",
				-onMouseOut=>"mM.src=eval('mMoffimg.src')"
				},
				img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM", -alt=>"NO"})
			), 

			
			end_form()
		),
		
		html_footer();
}

sub HPinsert {
	
	my %headerHash = (
		titre => "Host Plant Insert",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $nb = param('nb_elem');
	
	my $i = 0;
	
	my $msg;
	
	my $ranks = request_hash("SELECT index, ordre, en FROM rangs;", $dbc, 'en');
	
	while ($i<$nb) {
		
		my $rank = param("rank$i");
		my $rankid = $ranks->{$rank}->{'index'};
		my $ord = param("ord$i") || 'NULL';
		my $fam = param("fam$i");
		my $gen = param("gen$i");
		my $name = param("name$i");
		my $auth = param("authority$i");
		my $reqauth;
	   	if ($auth) {
	   		$reqauth = $auth;
			$auth =~ s/\(/\\\(/g;
			$auth =~ s/\)/\\\)/g;
			$auth =~ s/\'/\\\'/g;
			$auth = "'$auth'";
		} else { $auth = 'NULL' }
		my $status = param("status$i");
		my $vfam = param("vfam$i") || 'NULL';
		my $vgen = param("vgen$i") || 'NULL';
		my $vspe = param("vspe$i") || 'NULL';
		my $req;
		
		my $pop;
		if ($ord ne 'NULL') { $pop = '=' } else { $pop = 'IS' }
		
		if ($rank eq 'order') {
			my ($c) = @{request_tab("SELECT count(*) FROM plantes WHERE nom = '$name';", $dbc, 1)};
			if ($c) { $msg = img{-src=>'/Editor/stop.jpg'}, p, span({-style=>'color: crimson'}, "This order already in the database"), p }
			else {
				$req = "INSERT INTO plantes (index, ref_rang, nom, autorite, ref_parent, statut, ref_valide) VALUES (default, $rankid, '$name', $auth, NULL, '$status', $vfam);"
			}
		}
		if ($rank eq 'family') {
			my ($c) = @{request_tab("SELECT count(*) FROM plantes WHERE nom = '$name' AND ref_parent $pop $ord;", $dbc, 1)};
			if ($c) { $msg = img{-src=>'/Editor/stop.jpg'}, p, span({-style=>'color: crimson'}, "This family already in the database"), p }
			else {
				$req = "INSERT INTO plantes (index, ref_rang, nom, autorite, ref_parent, statut, ref_valide) VALUES (default, $rankid, '$name', $auth, $ord, '$status', $vfam);"
			}
		}
		elsif ($rank eq 'genus') {
			my ($c) = @{request_tab("SELECT count(*) FROM plantes WHERE nom = '$name' AND ref_parent = $fam;", $dbc, 1)};
			if ($c) { $msg = img{-src=>'/Editor/stop.jpg'}, p, span({-style=>'color: crimson'}, "This genus already in the database"), p }
			else {
				$req = "INSERT INTO plantes (index, ref_rang, nom, autorite, ref_parent, statut, ref_valide) VALUES (default, $rankid, '$name', $auth, $fam, '$status', $vgen);"
			}
		}
		elsif ($rank eq 'species') {
			my ($c) = @{request_tab("SELECT count(*) FROM plantes WHERE nom = '$name' AND ref_parent = $gen AND autorite = $auth;", $dbc, 1)};
			if ($c) { $msg = img{-src=>'/Editor/stop.jpg'}, p, span({-style=>'color: crimson'}, "This species already in the database"), p }
			else {
				$req = "INSERT INTO plantes (index, ref_rang, nom, autorite, ref_parent, statut, ref_valide) VALUES (default, $rankid, '$name', $auth, $gen, '$status', $vspe);"
			}
		}

		if ($req) {		
			
			$msg = img{-src=>'/Editor/done.jpg'}, p, span({-style=>'color: green'}, "Scientific name $name inserted"), p;
			
			my $sth = $dbc->prepare($req) or die "failing prepare $req";
		
			$sth->execute() or die "$req: ".$dbc->errstr;
		}
		
		$i++;
	}
	
	Delete(param());
	
	print 	html_header(\%headerHash),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
		
			#join(br, map { "$_ = ".param($_) } param()), br,
			
			$msg,
			
			br, br,
			
			a({-href=>'Plants.pl?action=fill', -style=>'color: blue; text-decoration: none;'}, "Insert more host plants"), br, br,
			
			a({-href=>'Plants.pl?action=modify', -style=>'color: blue; text-decoration: none;'}, "Modify host plants"), br, br, br, br,
			
			a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')" }, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM", -alt=>"NO"}))
		),
	
		html_footer();
}


sub HPrecap {
	
	my %headerHash = (
		titre => "Host plants",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	my $nb = param('nb_elem');
	
	my $i = 0;
	
	my $errors;
	my $null = 1;
	
	while ($i<$nb) {
		
		my $rank = param("rank$i");
		my $ord = param("ord$i");
		my $fam = param("fam$i");
		my $gen = param("gen$i");
		my $name = param("name$i");
		my $auth = param("authority$i");
		my $status = param("status$i");
		my $vfam = param("vfam$i");
		my $vgen = param("vgen$i");
		my $vspe = param("vspe$i");
		
		my $j = $i +1;
		
		if ($rank eq 'order') {
			unless ($name and $name ne 'name') { $errors .= "An Order has no name" . br }
			$null = 0;
		}
		if ($rank eq 'family') {
			if ($ord eq 'select an Order') { $errors .= "A Family has no Order" . br }
			unless ($name and $name ne 'name') { $errors .= "A Family has no name" . br }
			if ($status eq 'not valid' and !$vfam) { $errors .= "A Family has no valid name" . br }
			$null = 0;
		}
		elsif ($rank eq 'genus') {
			if ($fam eq 'select a Family') { $errors .= "A Genus has no Family" . br }
			unless ($name and $name ne 'name') { $errors .= "A Genus has no name" . br }
			if ($status eq 'not valid' and !$vgen) { $errors .= "A Genus has no valid name" . br }			
			$null = 0;
		}
		elsif ($rank eq 'species') {
			if ($gen eq 'select a Genus') { $errors .= "A Species has no Genus" . br }
			unless ($name and $name ne 'name') { $errors .= "A Species has no name" . br }
			if ($status eq 'not valid' and !$vspe) { $errors .= "A Species has no valid name" . br }			
			$null = 0;
		}

		#if ($rank ne 'level') {
		#	unless ($auth and $auth ne 'authority') { $errors .= "A scientific name has no authority" . br }
		#}
		$i++;
	}
	if ($null) { $errors .= "Select a level" . br }
	
	if ($errors) { HPform($nb, $errors.p ) }
	else { HPinsert() }
}

sub HPform {
		
	my ($nb, $errors) = @_;
	
	my $display;
	my @ordlist;
	my %ordlabels;	
	my @famlist;
	my %famlabels;	
	my @genlist;
	my %genlabels;	
	my @vfam;
	my %vflabels;
	my @vgen;
	my %vglabels;
	my @vspe;
	my %vslabels;
	my $pagetitle;
	my $action;
	my $test;
	my $hidden;
	my $link;
	my $back;
	
	push(@ordlist, '');
	$ordlabels{''} = 'NULL';
	
	my $req = "SELECT p1.index, p1.nom, r.en, p1.autorite 
			FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index 
			WHERE r.en = 'order' ORDER BY p1.nom;";
	
	my $orders = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p1.autorite 
			FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index 
			WHERE r.en = 'family' ORDER BY p1.nom;";
	
	my $families = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p2.nom, p1.autorite 
			FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index
			LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
			WHERE r.en = 'genus' ORDER BY p1.nom, p2.nom;";
	
	my $genera = request_tab($req,$dbc,2);
	
	$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p2.nom, p3.index, p3.nom, p1.autorite
			FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index
			LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
			LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent
			WHERE r.en = 'species' ORDER BY p2.nom, p1.nom;";
	
	my $species = request_tab($req,$dbc,2);
	
	my @vf = @{request_tab("SELECT plantes.index, nom, autorite FROM plantes LEFT JOIN rangs AS r ON ref_rang = r.index WHERE r.en = 'family' AND statut = 'valid' ORDER BY nom",$dbc,2)};
	
	my @vg = @{request_tab("SELECT p1.index, p1.nom, p2.nom, p1.autorite FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent WHERE r.en = 'genus' AND p1.statut = 'valid' ORDER BY p1.nom, p2.nom",$dbc,2)};
	
	my @vs = @{request_tab("SELECT p1.index, p1.nom, p2.nom, p3.nom, p1.autorite FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index  LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent WHERE r.en = 'species' AND p1.statut = 'valid'",$dbc,2)};
	
	foreach my $vfa (@vf) {
		push(@vfam, $vfa->[0]);
		$vflabels{$vfa->[0]} = "$vfa->[1] $vfa->[2]";
	}
	foreach my $vge (@vg) {
		push(@vgen, $vge->[0]);
		$vglabels{$vge->[0]} = "$vge->[1] $vge->[3] ($vge->[2])";
	}
	foreach my $vsp (@vs) {
		push(@vspe, $vsp->[0]);
		$vslabels{$vsp->[0]} = "$vsp->[2] $vsp->[1] $vsp->[4]";
	}

	foreach my $o (@{$orders}) { push(@ordlist, $o->[0]); $ordlabels{$o->[0]} = $o->[1]; }
	foreach my $f (@{$families}) { push(@famlist, $f->[0]); $famlabels{$f->[0]} = $f->[1]; }

	unless ($nb) {
		
		$back = span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"PlantsForm.action = 'Plants.pl?action=modify'; PlantsForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			);
		
		my %spefam;
		foreach my $g (@{$genera}) { push(@genlist, $g->[0]); $genlabels{$g->[0]} = "$g->[1]"; $spefam{$g->[0]} = "($g->[6])"; }

		$pagetitle = "Modify host plants";
		$action = 'update';
		$test =  "PlantsForm.action = 'Plants.pl?action=$action'; PlantsForm.submit()";
		$link = a({ -href=>"Plants.pl?action=fill", -style=>'text-decoration: none;' }, "Insert host plants");
		
		my $rankX = param('rankX');
		my $start = param('startX');
		
		if ($rankX eq 'order' or !$rankX) {
			
			my $req = "SELECT p1.index, p1.nom, r.en, p1.autorite 
					FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index 
					WHERE r.en = 'order' AND p1.nom ilike '$start%' ORDER BY p1.nom;";
			
			my $ordersX = request_tab($req,$dbc,2);
			
			$display .= table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, 'Order level'),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				) . br;
			
			my $i = 0;
			foreach my $o (@{$ordersX}) {
				
				$hidden .= hidden("idord$i", $o->[0]);
				$display .= 	div({STYLE=>'margin-bottom: 5px; clear: left; float: left; background: transparent; width: 800px;'},
							textfield(-class=>'phantomTextField', -name=>"ord$i", size=>26, -default=>$o->[1]) . " " .
							textfield(-class=>'phantomTextField', -name=>"ordauth$i", size=>40, -default=>$o->[3])
						). br({-style=>'clear: both;'}) . hr({-style=>'margin: 10px 0 10px 0; width: 700px;'});
				$i++;
			}
			
			unless ($rankX) {
				$display .= br . span(   {-onMouseover=>"document.okbtn1.src=eval('okonimg.src')",
							-onMouseout=>"document.okbtn1.src=eval('okoffimg.src')",
							-onClick=>"$test"},
							
							img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn1"})
					) . br . br;
			}
		}
		
		if ($rankX eq 'family' or !$rankX) {
			
			$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p1.autorite 
					FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index 
					WHERE r.en = 'family' AND p1.nom ilike '$start%' ORDER BY p1.nom;";
			
			my $famsX = request_tab($req,$dbc,2);

			$display .= table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, 'Family level'),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				) . br;
			
			my $i = 0;
			foreach my $f (@{$famsX}) {
						
				my $sdef;
				my $vdef;
				my $mode;
				if ($f->[2] eq 'valid') { $mode = 'none'; $sdef = 'valid'; $vdef = ''; } 
				elsif ($f->[2] eq 'not valid') { $mode = 'block'; $sdef = 'not valid'; $vdef = $f->[5]; }
				else { $mode = 'none'; $sdef = 'unknown'; $vdef = ''; }	
				
				$hidden .= hidden("idfam$i", $f->[0]);
				$display .= 	div({STYLE=>'margin-bottom: 5px; clear: left; float: left; background: transparent; width: 800px;'},
							popup_menu(-name=>"ordfam$i", -values=>[@ordlist], -default=>$f->[4], -labels=>\%ordlabels, -class=>'PopupStyle') . " &nbsp; " .
							textfield(-class=>'phantomTextField', -name=>"fam$i", size=>26, -default=>$f->[1]) . " " .
							textfield(-class=>'phantomTextField', -name=>"famauth$i", size=>40, -default=>$f->[6])
						).
						div({STYLE=>'clear: left; float: left; background: transparent; width: 160px;'},
							"status &nbsp;&nbsp;" . 
							popup_menu(-name=>"statusfam$i", -values=>["valid", "not valid","unknown"], -default=>$sdef, -class=>'PopupStyle', 
							-onChange=>"if (this.value == 'valid' || this.value == 'unknown') { 
									document.getElementById('vfdiv$i').style.display = 'none'; PlantsForm.validfam$i.value = ''; } 
								else if (this.value == 'not valid') {
									document.getElementById('vfdiv$i').style.display = 'block'; PlantsForm.validfam$i.value = '$f->[5]';}") 
						).
						div({-id=>"vfdiv$i", -STYLE=>"background: transparent; width: 800px; display:$mode;"},
							" valid name &nbsp;&nbsp;" . popup_menu(-name=>"validfam$i", 
							-values=>['', @vfam], -default=>$vdef, -labels=>\%vflabels, -class=>'PopupStyle')
						) . br({-style=>'clear: both;'}) .  hr({-style=>'margin: 10px 0 10px 0; width: 700px;'});
				$i++;
			}
			
			unless ($rankX) {
				$display .= br . span(   {-onMouseover=>"document.okbtn2.src=eval('okonimg.src')",
						-onMouseout=>"document.okbtn2.src=eval('okoffimg.src')",
						-onClick=>"$test"},
						
						img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn2"})
					)  . br . br;
			}
		}
		
		if ($rankX eq 'genus' or !$rankX) {
			
			$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p2.nom, p1.autorite 
				FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index
				LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
				WHERE r.en = 'genus' AND p1.nom ilike '$start%' ORDER BY p1.nom, p2.nom;";
			
			my $gensX = request_tab($req,$dbc,2);
			
			$display .= table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, 'Genus level'),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				) . br;
			
			my $i = 0;
			foreach my $g (@{$gensX}) {
				
				my $sdef;
				my $vdef;
				my $mode;
				if ($g->[2] eq 'valid') { $mode = 'none'; $sdef = 'valid'; $vdef = ''; } 
				elsif ($g->[2] eq 'not valid') { $mode = 'block'; $sdef = 'not valid'; $vdef = $g->[5]; }
				else { $mode = 'none'; $sdef = 'unknown'; $vdef = ''; } 
				
				$hidden .= hidden("idgen$i", $g->[0]);
				$display .= 	div({STYLE=>'margin-bottom: 5px; clear: left; float: left; background: transparent; width: 800px;'},
							popup_menu(-name=>"famgen$i", -values=>[@famlist], -default=>$g->[4], -labels=>\%famlabels, -class=>'PopupStyle') . " &nbsp; " .
							textfield(-class=>'phantomTextField', -name=>"gen$i", size=>20, -default=>$g->[1]) . " " .
							textfield(-class=>'phantomTextField', -name=>"genauth$i", size=>40, -default=>$g->[7])
						).
						div({STYLE=>'clear: left; float: left; background: transparent; width: 160px;'}, 
							"status &nbsp;&nbsp;" . popup_menu(-name=>"statusgen$i", -values=>["valid", "not valid","unknown"], 
								-default=>$sdef, -class=>'PopupStyle', 
								-onChange=>"if (this.value == 'valid' || this.value == 'unknown') { 
									document.getElementById('vgdiv$i').style.display = 'none'; PlantsForm.validgen$i.value = ''; 
								} 
								else { document.getElementById('vgdiv$i').style.display = 'block'; PlantsForm.validfam$i.value = '$g->[5]';}") 
						).
						div({-id=>"vgdiv$i", -STYLE=>"background: transparent; width: 800px; display:$mode;"},
								" valid name &nbsp;&nbsp;" . popup_menu(-name=>"validgen$i", 
								-values=>['', @vgen], -default=>$vdef, -labels=>\%vglabels, -class=>'PopupStyle') 
						) . br({-style=>'clear: both;'}) . hr({-style=>'margin: 10px 0 10px 0; width: 700px;'});
				$i++;
			}
			
			unless ($rankX) {
				$display .= br . span(   {-onMouseover=>"document.okbtn3.src=eval('okonimg.src')",
						-onMouseout=>"document.okbtn3.src=eval('okoffimg.src')",
						-onClick=>"$test"},
						
						img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn3"})
					) . br . br;
			}
		}
		
		if ($rankX eq 'species' or !$rankX) {
			
			$req = "SELECT p1.index, p1.nom, p1.statut, r.en, p1.ref_parent, p1.ref_valide, p2.nom, p3.index, p3.nom, p1.autorite
				FROM plantes AS p1 LEFT JOIN rangs AS r ON p1.ref_rang = r.index
				LEFT JOIN plantes AS p2 ON p2.index = p1.ref_parent
				LEFT JOIN plantes AS p3 ON p3.index = p2.ref_parent
				WHERE r.en = 'species' AND p1.nom ilike '$start%' ORDER BY p2.nom, p1.nom;";
			
			my $spesX = request_tab($req,$dbc,2);

			$display .= table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, 'Species level'),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				) . br;

			my $i = 0;	
			foreach my $s (@{$spesX}) {
				
				my $sdef;
				my $vdef;
				my $mode;
				if ($s->[2] eq 'valid') { $mode = 'none'; $sdef = 'valid'; $vdef = ''; } 
				elsif ($s->[2] eq 'not valid') { $mode = 'block'; $sdef = 'not valid'; $vdef = $s->[5]; }
				else { $mode = 'none'; $sdef = 'unknown'; $vdef = ''; }	
				
				$hidden .= hidden("idspe$i", $s->[0]);
				$display .= 	div({STYLE=>'margin-bottom: 5px; clear: left; float: left; background: transparent; width: 800px;'},
							popup_menu(-name=>"genspe$i", -values=>[@genlist], -default=>$s->[4], -labels=>\%genlabels, -class=>'PopupStyle') . " &nbsp; " .
							textfield(-class=>'phantomTextField', -name=>"spe$i", size=>20, -default=>$s->[1]) . " " .
							textfield(-class=>'phantomTextField', -name=>"speauth$i", size=>40, -default=>$s->[9]) .
							" " . $spefam{$s->[4]}
						).
						div({STYLE=>'clear: left; float: left; background: transparent; width: 160px;'},
							"status &nbsp;&nbsp;" . 
							popup_menu(-name=>"statusspe$i", -values=>["valid", "not valid","unknown"], -default=>$sdef, -class=>'PopupStyle', 
								-onChange=>"if (this.value == 'valid' || this.value == 'unknown') { 
										document.getElementById('vsdiv$i').style.display = 'none'; PlantsForm.validspe$i.value = ''; } 
									else { document.getElementById('vsdiv$i').style.display = 'block'; PlantsForm.validspe$i.value = '$s->[5]';}") 
						).
						div({-id=>"vsdiv$i", -STYLE=>"background: transparent; width: 800px; display:$mode;"},
							" valid name &nbsp;&nbsp;" . popup_menu(-name=>"validspe$i", 
							-values=>['', @vspe], -default=>$vdef, -labels=>\%vslabels, -class=>'PopupStyle') 
						) . br({-style=>'clear: both;'}) .  hr({-style=>'margin: 10px 0 10px 0; width: 700px;'});
				$i++;
			}
		}
	}
	else {
		
		$back = a(	{-href=>"typeSelect.pl?action=add&type=all",
				-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			);


		foreach my $g (@{$genera}) { push(@genlist, $g->[0]); $genlabels{$g->[0]} = "$g->[1] ($g->[6])"; }
		
		$pagetitle = "Insert host plants";
		$action = 'verify';
		$test = "PlantsForm.action = 'Plants.pl?action=$action'; PlantsForm.submit();";
		
		my ($mode0, $mode1, $mode2, $mode3, $mode4, $mode5, $mode6);
		
		my $i = 0;
		while ($i < $nb) {
			
			my $brs;
			unless ($i) { $brs = br.br; }
			
			my $r = param("rank$i");
			if (!$r or $r eq 'level') { $mode0 = 'none'; $mode1 = 'none'; $mode2 = 'none'; $mode3 = 'none'; $mode4 = 'none'; $mode5 = 'none'; $mode6 = 'none'; }
			else {
				$mode3 = 'inline';
				if ($r eq 'order') {
					$mode0 = 'none';
					$mode1 = 'none';
					$mode2 = 'none';
					$mode5 = 'none';
					$mode4 = 'none';
					$mode6 = 'none';
				}
				if ($r eq 'family') {
					$mode0 = 'inline';
					$mode1 = 'none';
					$mode2 = 'none';
					$mode5 = 'none';
					$mode6 = 'none';
					if (param("status$i") eq 'not valid') { $mode4 = 'inline'; }
					else { $mode4 = 'none'; }
				}
				elsif ($r eq 'genus') {
					$mode0 = 'none';
					$mode1 = 'inline';
					$mode2 = 'none';
					$mode4 = 'none';
					$mode6 = 'none';					
					if (param("status$i") eq 'not valid') { $mode5 = 'inline'; }
					else { $mode5 = 'none'; }
				}
				elsif ($r eq 'species') {
					$mode0 = 'none';
					$mode1 = 'none';
					$mode2 = 'inline';				
					$mode4 = 'none';
					$mode5 = 'none';
					if (param("status$i") eq 'not valid') { $mode6 = 'inline'; }
					else { $mode6 = 'inline'; }
				}
			} 
			
			$display .= Tr( td( br, popup_menu(	-name=>"rank$i", -values=>['level','order','family','genus','species'], -default=>'', -class=>'PopupStyle',
							-onChange=>"	if (this.value == 'level') {
										document.getElementById('orddiv$i').style.display = 'none';
										PlantsForm.ord$i.value = 'select an Order'; 
										document.getElementById('famdiv$i').style.display = 'none';
										PlantsForm.fam$i.value = 'select a Family'; 
										document.getElementById('gendiv$i').style.display = 'none';
										PlantsForm.gen$i.value = 'select a Genus';
										document.getElementById('ndiv$i').style.display = 'none';
										PlantsForm.name$i.value = 'name';
										PlantsForm.status$i.value = 'valid';
										document.getElementById('vfdiv$i').style.display = 'none';
										PlantsForm.vfam$i.value = '';
										document.getElementById('vgdiv$i').style.display = 'none';
										PlantsForm.vgen$i.value = '';
										document.getElementById('vsdiv$i').style.display = 'none';
										PlantsForm.vspe$i.value = '';
									} 
									else if (this.value == 'order') {
										document.getElementById('orddiv$i').style.display = 'none';
										PlantsForm.ord$i.value = 'select an Order'; 
										document.getElementById('famdiv$i').style.display = 'none';
										PlantsForm.fam$i.value = 'select a Family'; 
										document.getElementById('gendiv$i').style.display = 'none';
										PlantsForm.gen$i.value = 'select a Genus';
										document.getElementById('ndiv$i').style.display = 'inline';
										PlantsForm.name$i.value = 'name';
										PlantsForm.status$i.value = 'valid';
										document.getElementById('vfdiv$i').style.display = 'none';
										PlantsForm.vfam$i.value = '';
										document.getElementById('vgdiv$i').style.display = 'none';
										PlantsForm.vgen$i.value = '';
										document.getElementById('vsdiv$i').style.display = 'none';
										PlantsForm.vspe$i.value = '';
									}
									else if (this.value == 'family') {
										document.getElementById('orddiv$i').style.display = 'inline';
										PlantsForm.ord$i.value = 'select an Order'; 
										document.getElementById('famdiv$i').style.display = 'none';
										PlantsForm.fam$i.value = 'select a Family'; 
										document.getElementById('gendiv$i').style.display = 'none';
										PlantsForm.gen$i.value = 'select a Genus';
										document.getElementById('ndiv$i').style.display = 'inline';
										PlantsForm.name$i.value = 'name';
										PlantsForm.status$i.value = 'valid';
										document.getElementById('vfdiv$i').style.display = 'none';
										PlantsForm.vfam$i.value = '';
										document.getElementById('vgdiv$i').style.display = 'none';
										PlantsForm.vgen$i.value = '';
										document.getElementById('vsdiv$i').style.display = 'none';
										PlantsForm.vspe$i.value = '';
									}
									else if (this.value == 'genus') { 
										document.getElementById('orddiv$i').style.display = 'none';
										PlantsForm.ord$i.value = 'select an Order'; 
										document.getElementById('famdiv$i').style.display = 'inline';
										PlantsForm.fam$i.value = 'select a Family'; 
										document.getElementById('gendiv$i').style.display = 'none';
										PlantsForm.gen$i.value = 'select a Genus'; 						
										document.getElementById('ndiv$i').style.display = 'inline';
										PlantsForm.name$i.value = 'name';
										PlantsForm.status$i.value = 'valid';
										document.getElementById('vfdiv$i').style.display = 'none';
										PlantsForm.vfam$i.value = '';
										document.getElementById('vgdiv$i').style.display = 'none';
										PlantsForm.vgen$i.value = '';
										document.getElementById('vsdiv$i').style.display = 'none';
										PlantsForm.vspe$i.value = '';
									}
									else if (this.value == 'species') {
										document.getElementById('orddiv$i').style.display = 'none';
										PlantsForm.ord$i.value = 'select an Order'; 
										document.getElementById('famdiv$i').style.display = 'none';
										PlantsForm.fam$i.value = 'select a Family'; 
										document.getElementById('gendiv$i').style.display = 'inline';
										PlantsForm.gen$i.value = 'select a Genus'; 												
										document.getElementById('ndiv$i').style.display = 'inline';
										PlantsForm.name$i.value = 'name';
										PlantsForm.status$i.value = 'valid';
										document.getElementById('vfdiv$i').style.display = 'none';
										PlantsForm.vfam$i.value = '';
										document.getElementById('vgdiv$i').style.display = 'none';
										PlantsForm.vgen$i.value = '';
										document.getElementById('vsdiv$i').style.display = 'none';
										PlantsForm.vspe$i.value = '';
									}"
						), $brs,
						div({-id=>"ndiv$i", -style=>"display:$mode3;"},
							div({-id=>"orddiv$i", -style=>"display:$mode0;"}, 
								popup_menu(-name=>"ord$i", -values=>['select an Order', @ordlist], -default=>"select an Order", -labels=>\%ordlabels, -class=>'PopupStyle'), 
								"&nbsp; "
							), 
							div({-id=>"famdiv$i", -style=>"display:$mode1;"}, 
								popup_menu(-name=>"fam$i", -values=>['select a Family', @famlist], -default=>"select a Family", -labels=>\%famlabels, -class=>'PopupStyle'), 
								"&nbsp; "
							), 
							div({-id=>"gendiv$i", -style=>"display:$mode2;"}, 
								popup_menu(-name=>"gen$i", -values=>['select a Genus', @genlist], -default=>"select a Genus", -labels=>\%genlabels, -class=>'PopupStyle'), 
								"&nbsp; "
							),
							textfield(-class=>'phantomTextField', -name=>"name$i", size=>20, value=>'name',
							-onFocus=>"	if (this.value == 'name') { this.value = '' }",
							-onBlur=>"	if (this.value == '' || this.value == 'name') { this.value = 'name' }
									else {
										var rk = document.PlantsForm.rank$i.value
										if (rk == 'order' || rk == 'family' || rk == 'genus') { 
										this.value = this.value.substring(0,1).toUpperCase() + this.value.substring(1,this.value.length).toLowerCase();
										}
									}"
							),
							textfield(-class=>'phantomTextField', -name=>"authority$i", size=>20, value=>'authority',
								-onFocus=>"if (this.value == 'authority') { this.value = '' }",
								-onBlur=>"if (this.value == '') { this.value = 'authority' }"     
							),
							"&nbsp; status &nbsp;",
							popup_menu(-name=>"status$i", -values=>["valid", "not valid","unknown"], -class=>'PopupStyle', 
								-onChange=>"	if (this.value == 'valid' || this.value == 'unknown') {
											document.getElementById('vfdiv$i').style.display = 'none';
											PlantsForm.vfam$i.value = '';
											document.getElementById('vgdiv$i').style.display = 'none';
											PlantsForm.vgen$i.value = '';
											document.getElementById('vsdiv$i').style.display = 'none';
											PlantsForm.vspe$i.value = '';
										} 
										else if (this.value == 'not valid') {
											if (PlantsForm.rank$i.value == 'family') {
												document.getElementById('vfdiv$i').style.display = 'inline';
												document.getElementById('vgdiv$i').style.display = 'none';
												PlantsForm.vgen$i.value = '';
												document.getElementById('vsdiv$i').style.display = 'none';
												PlantsForm.vspe$i.value = '';
											}
											else if (PlantsForm.rank$i.value == 'genus') {
												document.getElementById('vfdiv$i').style.display = 'none';
												PlantsForm.vfam$i.value = '';
												document.getElementById('vgdiv$i').style.display = 'inline';
												document.getElementById('vsdiv$i').style.display = 'none';
												PlantsForm.vspe$i.value = '';
											}
											else if (PlantsForm.rank$i.value == 'species') {
												document.getElementById('vfdiv$i').style.display = 'none';
												PlantsForm.vfam$i.value = '';
												document.getElementById('vgdiv$i').style.display = 'none';
												PlantsForm.vgen$i.value = '';
												document.getElementById('vsdiv$i').style.display = 'inline';
											}
										}"
							), "&nbsp; "
						),
						div({-id=>"vfdiv$i", -style=>"display:$mode4;"}, 
						br.br. " valid name &nbsp; " . popup_menu(-name=>"vfam$i", -values=>['', @vfam], -labels=>\%vflabels, -class=>'PopupStyle') 
						),
						div({-id=>"vgdiv$i", -style=>"display:$mode5;"}, 
						br.br. " valid name &nbsp; " . popup_menu(-name=>"vgen$i", -values=>['', @vgen], -labels=>\%vglabels, -class=>'PopupStyle') 
						), 
						div({-id=>"vsdiv$i", -style=>"display:$mode6;"}, 
						br.br. " valid name &nbsp; " . popup_menu(-name=>"vspe$i", -values=>['', @vspe], -labels=>\%vslabels, -class=>'PopupStyle') 
						), p
					));
			$i++;
		}
		
		$display .= Tr( td( br.br.span({-style=>'color: blue;', -onClick=>"PlantsForm.action='Plants.pl?action=more'; PlantsForm.submit();", -onMouseOver=>"this.style.cursor = 'pointer';"}, "Add another host plant" ) ) ) . br;
		
		$hidden = hidden("nb_elem", $nb);
	}
	
	my %headerHash = (
		titre => $pagetitle,
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
			
			table({style=>"margin-bottom: 3%;", -cellspacing=>0, cellpadding=>0},
				Tr(
					td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
					td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, $pagetitle),
					td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
				)
			),
			
			$back,
			
			br, br,
			
			a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')" }, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM", -alt=>"NO"})), 
			
			br, br, br,
			
			span({-style=>'color: crimson;'}, $errors),
									
			start_form(-name=>'PlantsForm', -method=>'post',-action=>'').

			$display,
						
			$hidden,
			hidden('rankX'),
			hidden('startX'),
			
			end_form(),
			
			br,
			
			span(	{-onMouseover=>"document.okbtn4.src=eval('okonimg.src')",
				-onMouseout=>"document.okbtn4.src=eval('okoffimg.src')",
				-onClick=>"$test"
				},
				img({-border=>0, -src=>'/Editor/ok0.png', -name=>"okbtn4"})
			),

			br, br,
			
			$link,

			br, br,
		),
	
		html_footer();
}

sub updateHPform {

	my $req;
	
	my $i = 0;	
	while (param("idord$i")) {		
		
		my $auth;
		unless (param("ordauth$i")) { $auth = 'NULL' } 
		else { 
			$auth = param("ordauth$i");
	   		$auth =~ s/\(/\\\(/g;
		      	$auth =~ s/\)/\\\)/g;
			$auth =~ s/\'/\\\'/g;
			$auth = "'$auth'";
		}
		
		$req .= " UPDATE plantes SET nom = '" .param("ord$i"). "', autorite = $auth WHERE index = " .param("idord$i"). "; ";
		$i++;
	}
	
	#idfam fam statusfam validfam
	$i = 0;
	while (param("idfam$i")) {		
		
		my $auth;
		unless (param("ordfam$i")) { param("ordfam$i", 'NULL') }
		unless (param("validfam$i")) { param("validfam$i", 'NULL') }
		unless (param("famauth$i")) { $auth = 'NULL' } 
		else { 
			$auth = param("famauth$i");
	   		$auth =~ s/\(/\\\(/g;
		      	$auth =~ s/\)/\\\)/g;
			$auth =~ s/\'/\\\'/g;
			$auth = "'$auth'";
		}
		
		$req .= " UPDATE plantes SET nom = '" .param("fam$i"). "', statut = '" .param("statusfam$i"). "', 
			ref_valide = " .param("validfam$i"). ", ref_parent = " .param("ordfam$i"). ", autorite = $auth WHERE index = " .param("idfam$i"). "; ";
		$i++;
	}
	
	#idgen famgen gen statusgen validgen
	$i = 0;	
	while (param("idgen$i")) {		
		
		my $auth;
		unless (param("famgen$i")) { param("famgen$i", 'NULL') }
		unless (param("validgen$i")) { param("validgen$i", 'NULL') }
		unless (param("genauth$i")) { $auth = 'NULL' } 
		else { 
			$auth = param("genauth$i"); 
	   		$auth =~ s/\(/\\\(/g;
		      	$auth =~ s/\)/\\\)/g;
			$auth =~ s/\'/\\\'/g;
			$auth = "'$auth'";
		}
		$req .= " UPDATE plantes SET nom = '" .param("gen$i"). "', statut = '" .param("statusgen$i"). "', 
			ref_valide = " .param("validgen$i"). ", ref_parent = " .param("famgen$i"). ", autorite = $auth WHERE index = " .param("idgen$i"). "; ";
		$i++;
	}
	
	#idspe genspe spe statusspe validspe
	$i = 0;	
	while (param("idspe$i")) {		
		
		my $auth;
		unless (param("validspe$i")) { param("validspe$i", 'NULL') }
		unless (param("speauth$i")) { $auth = 'NULL' } 
		else { 
			$auth = param("speauth$i");
	   		$auth =~ s/\(/\\\(/g;
		      	$auth =~ s/\)/\\\)/g;
			$auth =~ s/\'/\\\'/g;
			$auth = "'$auth'";
		}
		$req .= " UPDATE plantes SET nom = '" .param("spe$i"). "', statut = '" .param("statusspe$i"). "', 
			ref_valide = " .param("validspe$i"). ", ref_parent = " .param("genspe$i"). ", autorite = $auth WHERE index = " .param("idspe$i"). "; ";
		$i++;
	}
						
	if ($req) {
		
		$req = "BEGIN; $req COMMIT;";
		
		my $sth = $dbc->prepare($req) or die "$req: ". $dbc->errstr;
		
		$sth->execute() or die "$req: ". $dbc->errstr;
	}
	
	my %headerHash = (
		titre => "Update host plants",
		bgcolor => $background,
		css => $css,
		jscript => $jscript_imgs . $jscript_for_hidden,
	);
	
	print 	html_header(\%headerHash),
		
		#join(br, map { "$_ = ".param($_) } param()),
		
		div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
		
		div({-class=>"wcenter"},
				
			span({-id=>'redalert', -style=>'display: none; text-decoration: blink; color: crimson; font-size: large; font-weight: bold;'}, "RELOAD"), p,
			
			img{-src=>'/Editor/done.jpg'}, p,

			span({-style=>'color: green;'}, "Modification of host plants done"), p, br,
						
			start_form(-name=>'PlantsForm', -method=>'post',-action=>'').
			
			hidden('rankX'),
			hidden('startX'),

			end_form(),		
															
			span(	{-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
				-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
				-onClick=>"PlantsForm.action = 'Plants.pl?action=change'; PlantsForm.submit();"
				},
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
			), 
			
			br, br,
			
			a({ -href=>"Plants.pl?action=fill", -style=>'text-decoration: none;' }, "Insert host plants"), p, br,
			
			a({ -href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')" }, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM", -alt=>"NO"}))
		),
	
		html_footer();
}

$dbc->disconnect();
exit;
