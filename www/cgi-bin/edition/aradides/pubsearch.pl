#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/aradides/â€˜}
use strict;
use HTML_func qw (html_header html_footer  arg_persist);
use CGI qw( -no_xhtml :standard );  #make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser );  #display errors in browser
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel);
use DBTNTcommons qw (pub_formating get_pub_params);

my $dbc = db_connection(get_connection_params($conf_file));

## HELP #######
#
#  search button of the <form> calling pubsearch.pl must create:
#  params searchFrom, searchTo
#  if you don't want the new button, param NoNew is needed
#  target <form> must treat searchPubId


my $annee = param('searchYear')  || url_param('searchYear') || param('nameyear');
Delete('searchYear');
my $authorid = param('searchAuthor') || url_param('searchAuthor');
Delete('searchAuthor');
my $from = param('searchFrom') || url_param('searchFrom');
Delete('searchFrom');
my $to = param('searchTo') || url_param('searchTo');
Delete('searchTo');

Delete('action');

#die map { "$_ = ".param($_).br } param();

if (url_param('action') eq 'getOptions') {
	
	clear_params('pub');
	
	pub_search_options($dbc, $annee, $authorid, $from);
}

elsif (url_param('action') eq 'getPub') {
	
	pub_search_form ($dbc, $annee, $authorid, $from, $to);
} 

else {
	die "No action specified ". join(' , ',param());
}

sub clear_params {

	my ($type) = @_;
	
	if ($type eq 'pub') {
		
		my $i=1;
		while (param("pubAFN$i")) { Delete("pubAFN$i"); Delete("pubALN$i"); $i++; }
		
		Delete ("pubtitle");
		Delete ("pubyear");
		Delete ("pubpgdeb");
		Delete ("pubpgfin");
		Delete ("pubnbauts");
	}
}

sub pub_search_options {

	my ($dbc, $annee, $author, $from) = @_;
	
	my $html;
	
	my @query;
	foreach (url_param()) { push(@query,"$_=".url_param($_)); }
	my $url = url()."?".join('&',@query);
	
	
	
	my $jscript = 	$jscript_imgs .
			
			"function testspc (elmt) {
				if (elmt.value == 'spc') { elmt.value = ''; }
			}
			
			function clearSearchParams (form) {
				if (form.searchYear) { form.removeChild(form.searchYear); }
				if (form.searchAuthor) { form.removeChild(form.searchAuthor); }
				if (form.searchFrom) { form.removeChild(form.searchFrom); }
				if (form.searchTo) { form.removeChild(form.searchTo); }
				if (form.NoNew) { form.removeChild(form.NoNew); }
			}";
	
	my %headerHash = (
		titre => 'Searching',
		bgcolor => $background,
		css => $css,
		jscript => $jscript,
	);
	
	my $pustyle = 'text-align: left;';
		
	# Authors fields
	my $authors = request_tab("SELECT index, nom, prenom FROM auteurs ORDER BY nom;",$dbc,3);

	my $pubAuthorOptions;
	
	my $sel = '';
	
	unless ($author) { $sel = 'SELECTED'; }
	
	$pubAuthorOptions = "<OPTION $sel VALUE='' CLASS=popupTitle STYLE='$pustyle' > First author";
	
	$pubAuthorOptions .= "<OPTION VALUE='spc' CLASS=PopupStyle STYLE='$pustyle' > --------";
	
	foreach (@{$authors}) {
		
		if ($_->[2]) { $_->[1] .= " $_->[2]"; }
		
		if (!$sel and $_->[0] == $author) { $sel = 'SELECTED'; $pubAuthorOptions .= "<OPTION $sel VALUE='$_->[0]' CLASS='PopupStyle' STYLE='$pustyle' > $_->[1]"; }
		
		else { $pubAuthorOptions .= "<OPTION VALUE='$_->[0]' CLASS='PopupStyle' STYLE='$pustyle' > $_->[1]"; }
	}	

	my $pubAOpts = table({-border=>0 , -cellspacing=>10 , bgcolor=>$rowcolor},
			Tr(
				td(
				"<SELECT NAME='searchAuthor' onChange='testspc(this.form.searchAuthor);' CLASS=PopupStyle STYLE='text-align: center;'>$pubAuthorOptions"
				),
				td("*Optional")
			)	
		);
	
	# Year field	
	my $anneeOpt = table({-border=>0 , -cellspacing=>10 , bgcolor=>$rowcolor},
			Tr(
				td({-align=>'left'},span({-class=>'textLarge'},span({-class=>'textNavy'},"Year"))),
				td(textfield(-class=>'phantomTextField', -name=>'searchYear', -value=>$annee, -maxlength=>4, size=>4, -onBlur=>"if (isNaN(this.value)) { this.value = ''; }"))
			)
		);

	my $backbtn;	
	if ($from) {
	
		$backbtn .= start_form(-name=>'backform', -method=>'post',-action=>'').
	
			arg_persist().
			
			a({	-onMouseOver=>"backimg.src=eval('backonimg.src');",
				-onMouseOut=>"backimg.src=eval('backoffimg.src');",
				-onClick=>"clearSearchParams(backform); backform.action = '$from'; backform.submit();" },
				img({-border=>0, -src=>'/Editor/back0.png', -name=>"backimg"})
			).
			
			end_form();
	}
	
	$html .= html_header(\%headerHash).
	
	div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor").
	
	#join(br, map { "$_ = ".param($_) } param()).
	
	start_form(-name=>'pubsearchform', -method=>'post',-action=>'').
	
	div({-class=>'wcenter'},
	
		table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
				td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Publication search options"),
				td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
			)
		),
		
		br, br,
		
		$anneeOpt,
		
		p,
		
		$pubAOpts,
		
		p, br,
	
		a({	-onMouseOver=>"	ok.src=eval('okonimg.src')",
			-onMouseOut=>"	ok.src=eval('okoffimg.src')",
			-onClick=>" 	if(pubsearchform.searchYear.value) { pubsearchform.action = 'pubsearch.pl?action=getPub'; pubsearchform.submit(); } else { alert('You have to select a publication year.') }" },
			img({-border=>0, -src=>'/Editor/ok0.png', -name=>"ok"})
		),
		
		arg_persist(),
		hidden('searchFrom', $from),
		hidden('searchTo', $to),
		
		end_form(),
		
		$backbtn
	).									
	
	html_footer();

	print $html;
}

sub pub_search_form {

	my ($dbc, $annee, $authorid, $from, $to) = @_;
			
	my $req = "SELECT p.index FROM publications AS p LEFT JOIN auteurs_x_publications AS axp ON axp.ref_publication = p.index WHERE axp.position = 1";
	
	if ( $annee ) { $req .= " AND p.annee = $annee"; }
	if ( $authorid ) { $req .= " AND axp.ref_auteur = $authorid"; }
	
	my $pubids = request_tab($req,$dbc,1);
	my %pubs;
		
	foreach (@{$pubids}) {
		$pubs{$_} = pub_formating(get_pub_params($dbc, $_), 'html');
	}
			
	my $display = publist(\%pubs, $to);
	
	my $html;
	
	my $jscript = 	$jscript_imgs . $jscript_for_hidden .
	
			"function clearSearchParams (form) {
				if (form.searchYear) { form.removeChild(form.searchYear); }
				if (form.searchAuthor) { form.removeChild(form.searchAuthor); }
				if (form.searchFrom) { form.removeChild(form.searchFrom); }
				if (form.searchTo) { form.removeChild(form.searchTo); }
				if (form.NoNew) { form.removeChild(form.NoNew); }
			}";
	
	$css .= "	body, html {
				margin: 0;
				height: 100%;
			}
			html {
				overflow: visible;
			}
			body {
				overflow: auto;
			}
			div[id=fixe] {
				position: fixed !important;
				background: $background;
				height: 40px;
				width: 120px;
			}
			html > body {
				overflow: visible !important;
			}";
	
	my %headerHash = (
		titre => 'Selecting',
		bgcolor => $background,
		css => $css,
		jscript => $jscript,
	);
	
	
	my $newbtn;
	
	unless (param('NoNew')) {
		
		$newbtn = div({	-onMouseOver=>"newimg.src=eval('newonimg.src');",
				-onMouseOut=>"newimg.src=eval('newoffimg.src');",
				-onClick=>"clearSearchParams(document.pubselectform);
					appendHidden(document.pubselectform, 'searchFrom', '$from');
					appendHidden(document.pubselectform, 'searchTo', '$to');
					//pubselectform.action = 'Publications.pl?action=fill&page=pub';
					pubselectform.action = 'typeSelect.pl?action=add&type=pub';
					pubselectform.submit();" },
				img({-border=>0, -src=>'/Editor/new0.png', -name=>"newimg"}));
	}	
		
	my $msgcolor = 'crimson';
	
	my $msg;
	unless ($display) { 
		$display = img({-border=>0, -src=>'/Editor/stop.jpg', -name=>"stop" , -alt=>"STOP"}) .
			span({-style=>'color: crimson; margin-left: 20px;'}, "No publication found with these criteria."); 
	}
	else {
		$msg = 'Click on the selected publication' . br . br; 
	}
	
	$html .= 	html_header(\%headerHash).
			
			#join(br, map { "$_ = ".param($_) } param()).
			
			div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor").
			
			start_form(-name=>'pubselectform', -method=>'post',-action=>'').
						
			div({-class=>'wcenter'},
			
					
				table({style=>"margin-bottom: 2%;", -cellspacing=>0, cellpadding=>0},
					Tr(
						td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
						td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Publication(s) found"),
						td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
					)
				),
				
				span({-style=>"color: $msgcolor;"}, $msg ),
								
				div({-id=>'fixe', -style=>''},
					
					table(
											
						Tr(
							td(
								div({	-onMouseOver=>"backimg.src=eval('backonimg.src');",
									-onMouseOut=>"backimg.src=eval('backoffimg.src');",
									-onClick=>"pubselectform.action = 'pubsearch.pl?action=getOptions'; pubselectform.submit();" },
									img({-border=>0, -src=>'/Editor/back0.png', -name=>"backimg"})
								)
							),
							td( $newbtn )
						)
					),
				), br,
				
				div({-style=>'margin-top: 40px;'},
					
					$display
				)
			).

			arg_persist().
				
			end_form().
						
			html_footer();

	print $html;
	
}

sub publist {

	my ($pubs, $to) = @_;
		
	my @sortedids = sort { $pubs->{$a} cmp $pubs->{$b} } keys(%{$pubs});
	
	my $display;
	
	if (scalar(@sortedids)) {
		foreach (@sortedids) {
			
			$display .= Tr( td({-style=>'padding-bottom: 10px;'}, 
						a({	-style=>'text-decoration: none; color: navy;', 
							-onMouseOver=>"this.style.cursor = 'pointer';",
							-onClick=>"	clearSearchParams(document.pubselectform); document.pubselectform.action = '$to';
									appendHidden(document.pubselectform, 'searchPubId', '$_');
									document.pubselectform.submit();"},
							"Pub n° $_ - ".$pubs->{$_}
						)
					)
				    );
		}                                     
		
		$display = table({-width=>'800px', -style=>'margin-left: 120px;'}, $display);
	}
	
	return $display;
}
