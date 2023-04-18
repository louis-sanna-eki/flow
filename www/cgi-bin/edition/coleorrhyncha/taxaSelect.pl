#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/coleorrhyncha/'} 
use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel);

my $cell1 = 250;
my $cell2 = 150;

my $dbc = db_connection(get_connection_params($conf_file));

my $target = url_param("target") || param("target");

my $ranks = request_tab("SELECT index,en,ordre FROM rangs WHERE en in ('family', 'genus', 'species') ORDER BY ordre;",$dbc,2);

my $genCar = request_tab("SELECT index,ordre FROM rangs WHERE en = 'genus';",$dbc,2);
my $gorder = $genCar->[0][1];

my $JSCRIPT = 	$jscript_imgs .$jscript_for_hidden ."
		
		var mMonimg = new Image ();
		var mMoffimg = new Image ();
		mMonimg.src = '/Editor/mainMenu1.png';
		mMoffimg.src = '/Editor/mainMenu0.png';
								
		function testRank (form) {
		
			if (form.taxonOrder.value >= $gorder) { 
				document.getElementById('genusImgDiv').style.display = 'block'; 
				if ('".param('genusX')."' != '') { form.genusX.value = '".param('genusX')."' } else { form.genusX.value = 'Enter the Genus' }
				document.getElementById('okImgDiv').style.display = 'block'; 
			}
			else if ( !isNaN(form.taxonOrder.value) ) { document.getElementById('genusImgDiv').style.display = 'none'; document.getElementById('okImgDiv').style.display = 'block'; }
			else { document.getElementById('genusImgDiv').style.display = 'none'; document.getElementById('okImgDiv').style.display = 'none'; }
		}
		
		function testInfo (form) {
			if (document.getElementById('genusImgDiv').style.display == 'block' && (!form.genusX.value || form.genusX.value == 'Enter the Genus') ) { 
				alert(\"You must precise the Genus\"); 
			}
			else { 
				if ('".url_param('action')."' == '') {
					form.action = '".url().'?action=get&'.join('&', map { qq/$_=/.url_param($_) } url_param())."';
				}
				else {
					form.action = '".url().'?'.join('&', map { qq/$_=/.url_param($_) } url_param())."';
				}
				form.submit();
			}
		}
		
		function clearGenus (form) {
			if (form.genusX.value == 'Enter the Genus') { form.genusX.value = '' };
		}
";

my %headerHash = (

	titre => "Taxon selection",
	bgcolor => $background,
	css => $css,
	background => '',
	jscript => $JSCRIPT,
	onLoad => "testRank(document.TaxonForm)"
);

my $defaut;
my $selected;
if ($defaut = param('taxonOrder')) { 
	Delete('taxonOrder'); 
}
else {
	$defaut = 'rank';
}

my $rankOptions = "	<OPTION VALUE=rank CLASS=popupTitle STYLE='text-align: center;'>Rank
			<OPTION VALUE='null' CLASS='PopupStyle' STYLE='text-align: center;'>--------";
foreach (@{$ranks}) {
			
	if ($_->[2] eq $defaut) { $selected = 'SELECTED' } else { $selected = '' }
	
	$rankOptions .= "<OPTION VALUE='$_->[2]' $selected CLASS='PopupStyle' STYLE='text-align: center;'> $_->[1]";
}	

my $taxaList;
my $hidden;

Delete("taxonX"); 

if ( url_param("target") ) { $hidden = hidden("target", url_param("target")) } 
elsif (param("target")) { $hidden = hidden("target", param("target")); Delete("target"); }

if (url_param("action") eq "get") { 

	my $genus = param("genusX");
	
	if ($genus eq '*') {$genus = ''}
	
	my $rk = request_tab("SELECT index FROM rangs WHERE ordre = $defaut;", $dbc, 1);
	
	my $req  = "	SELECT txn.ref_taxon, nc.index, nc.orthographe, nc.autorite, s.en,
       			nc2.orthographe, nc2.autorite
			FROM taxons_x_noms AS txn
			LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
			LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
			LEFT JOIN statuts AS s ON s.index = txn.ref_statut
			WHERE nc.ref_rang = $rk->[0]
			AND s.en not in ('correct use', 'misidentification')
			AND nc.orthographe like '$genus%'
			ORDER by nc.orthographe";
			
	my $taxa = request_tab($req, $dbc, 2);

	if (scalar(@{$taxa})) {
		
		$taxaList = "<SELECT CLASS=PopupStyle NAME=taxonX><OPTION>";
	
		foreach(@{$taxa}) { 
		
			$taxaList .= "<OPTION VALUE=$_->[0]> $_->[2] $_->[3]";
			
			if ($_->[4] ne 'valid') { $taxaList .= " $_->[4] related to $_->[5] $_->[6]" }
		}
		$taxaList .= "</SELECT>";
	
		$taxaList = table({ -border=>0 , -cellspacing=>0 , bgcolor=>$rowcolor},
			Tr(
				td({-style=>''}, "Select a Taxon &nbsp;" . p)
			),
			Tr (	
				td($taxaList),
				td(
					div(	{
						-onMouseover=>"document.taxonok2.src=eval('okonimg.src')",
						-onMouseout=>"document.taxonok2.src=eval('okoffimg.src')",
						-onClick=>"if (document.TaxonForm.taxonX.value) {
								if ('$target' == 'country') { 
									document.TaxonForm.action = 'taxonXcountries.pl?action=fill';
								}
								else if ('$target' == 'hostplant') { 
									document.TaxonForm.action = 'taxonXhp.pl?action=fill';
								}
								document.TaxonForm.submit(); 
							}
							else { alert('Select a taxon') }"},
						
						img({-style=>'margin-left: 10px;', -border=>0, -src=>'/Editor/ok0.png', -name=>"taxonok2"})
					)
				)			
			)
		);
	
        }
        else {
	                $taxaList = br . img{-src=>'/Editor/stop.jpg'}, p, span({-style=>'color: crimson'}, "No valid taxon matching with this scientific name") . br . br;
       }		
}

print 	html_header(\%headerHash),

	#join(br, map { "$_ = ".param($_) } param()),
	
	div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
	
	div({-class=>"wcenter"},
				
		table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
				td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'},"Select a taxon"),
				td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
			)
		),
		
		start_form(-name=>'TaxonForm', -method=>'post',-action=>''),

		table({ -border=>0 , -cellspacing=>0 , bgcolor=>$rowcolor},
			Tr(
				td({-width=>'', -style=>''}, span({-class=>'textNavy'},span({-class=>''},"Taxon &nbsp;"))),
				td({-width=>$cell2},
					"<SELECT NAME='taxonOrder' onChange=testRank(this.form) CLASS='PopupStyle' STYLE='width: 150px; text-align: center;'>$rankOptions"
				),
				td(
					div(	{-id=>'genusImgDiv',
						 -style=>'display:none; margin-left: 10px;'},
						
						textfield(-class=>'phantomTextField', -name=>'genusX', -style=>'width: 160px; color: navy;  text-indent: 5px; background: #FFFFDD;', 
						-onFocus=>'clearGenus(this.form);', -onBlur=>'if (!this.value) { this.value = "Enter the Genus" } else { this.value = this.value.substring(0,1).toUpperCase() + this.value.substring(1,this.value.length).toLowerCase(); }')
					)
				),
				td(
					div(	{-id=>'okImgDiv',
						-style=>'display:none; margin-left: 10px;',
						-onMouseover=>"document.taxonok.src=eval('okonimg.src')",
						-onMouseout=>"document.taxonok.src=eval('okoffimg.src')",
						-onClick=>"testInfo(document.TaxonForm);"},
						
						img({-border=>0, -src=>'/Editor/ok0.png', -name=>"taxonok"})
					)
				)
			)
		), 
		
		br, br,
		
		$taxaList,
		
		$hidden,
			
		arg_persist(),
		
		end_form(),		
				
		br, br, br,
		
		a(	{-href=>"typeSelect.pl?action=add&type=all",
			-onMouseover=>"document.backbtn.src=eval('backonimg.src')",
			-onMouseout=>"document.backbtn.src=eval('backoffimg.src')",
			},
			img({-border=>0, -src=>'/Editor/back0.png', -name=>"backbtn"})
		),
		
		br, br,
		
		a({href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"}, img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"}))
	),p,
	
	html_footer();

$dbc->disconnect();
exit;
