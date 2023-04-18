#!/usr/bin/perl

use strict;
use warnings;
use diagnostics;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use HTML_func qw (html_header html_footer arg_persist);
use Style qw ($conf_file $background $rowcolor $css $jscript_imgs $jscript_for_hidden $dblabel $cross_tables);

# Gets parameters
#####################################################################################################################################################################
my $cell1 = 200;
my $cell2 = 200;
my $popup = '300px';

my $dbc = db_connection(get_connection_params($conf_file));

my $action = url_param('action'); Delete('action');
my $type = url_param('type'); Delete('type');

my $nameOrders = request_tab("SELECT index,en,ordre FROM rangs WHERE en in ('family', 'genus', 'subgenus', 'species', 'subspecies') ORDER BY ordre;",$dbc,2);
my $pubTypes = request_tab("SELECT en FROM types_publication ORDER BY en;",$dbc,1);

my $genusCaracs = request_tab("SELECT index,ordre FROM rangs WHERE en = 'genus';",$dbc,2);

my $gorder = $genusCaracs->[0][1];

my $reaction;
my $hidden;
my $prefix1;
my $prefix2;
my $vreaction;
if ($action eq 'insert') { $reaction = 'fill'; $vreaction = 'fill'; }
elsif ($action eq 'update') { $reaction = 'modify'; $vreaction = 'get'; }

my $genusX;
if (param("genusX")) { $genusX = param('genusX'); Delete('genusX'); } else { $genusX = 'Enter the Genus'; }

my $JSCRIPT = 	$jscript_imgs .$jscript_for_hidden ."
		
		var mMonimg = new Image ();
		var mMoffimg = new Image ();
		mMonimg.src = '/Editor/mainMenu1.png';
		mMoffimg.src = '/Editor/mainMenu0.png';
		
		function enabled(form,except) {

			if (except == 'none') {
				inactive(document.SelectNameForm,'name');
				inactive(document.SelectPubForm,'pub');
				inactive(document.CommonForm,'data')
			} else {
				if (except != 'pub') { inactive(document.SelectPubForm,'pub'); }
				if (except != 'name') { inactive(document.SelectNameForm,'name'); }
				if (except != 'data') { inactive(document.CommonForm,'data'); }
			}
		}
		
		function imgerase(type) {
			
			if (type == 'pub') {  document.getElementById('pubImgDiv').style.display = 'none' }
			if (type == 'name') { document.getElementById('nameImgDiv').style.display = 'none' }
			if (type == 'genus') { document.getElementById('genusImgDiv').style.display = 'none' }
			if (type == 'data') { document.getElementById('dataImgDiv').style.display = 'none' }

		}
		
		function imgdisplay(type) {
			
			if (type == 'name') { document.getElementById('nameImgDiv').style.display = 'block' }
			if (type == 'pub') { document.getElementById('pubImgDiv').style.display = 'block'; }
			if (type == 'genus') { document.getElementById('genusImgDiv').style.display = 'block'; }
			if (type == 'data') { document.getElementById('dataImgDiv').style.display = 'block'; }
		}
		
		function active(form,type) {
			
			if (type == 'name' ) {
				if (form.nameOrder.value && form.nameOrder.value != 'rank') { imgdisplay('name'); }
				else { enabled(form,'none'); }	
			} else if (type == 'pub') {
				if (form.pubType.value && form.pubType.value != 'type') { imgdisplay('pub'); }
				else { enabled(form,'none'); }
			} else if (type == 'data') {
				if (form.dataType.value && form.dataType.value != 'Select') { imgdisplay('data'); }
				else { enabled(form,'none'); }
			}

			document.warnForm.warning.value = '';
			document.getElementById('hep').style.display = 'none';
		}
		
		function inactive(form,type) {
			
			if (type == 'name' ) {
				imgerase('name');
				imgerase('genus');
				form.nameOrder.value = '';
				
			} else if (type == 'pub') {		
				imgerase('pub');
				form.pubType.value = '';
			} else if (type == 'data') {
				imgerase('data');
				form.dataType.value = '';
			}
		}
		
		function testRank (form) {
		
			if (form.nameOrder.value > $gorder) { 
				imgdisplay('genus');
			       	form.genusX.value = '$genusX';
			}
			else { 
				if (form.nameOrder.value == $gorder && '$reaction' == 'modify') { imgdisplay('genus'); form.genusX.value = 'Enter the Genus' }
				else { imgerase('genus'); form.genusX.value = '' }
			}
			
			active(form,'name');
		}
		
		function testName (form) {
			if (document.getElementById('genusImgDiv').style.display == 'block' && (!form.genusX.value || form.genusX.value == 'Enter the Genus') ) { alert(\"You must precise the Genus\"); }
			else { form.action = 'Names.pl?action=$reaction&page=sciname'; form.submit(); }
		}
		
		function clearGenus (form) {
			if (form.genusX.value == 'Enter the Genus') { form.genusX.value = '' };
		}
		
		function testPub (form) {
			if (form.pubType.value == 'In book') { 
				document.warnForm.warning.value = 'Make sure that the book is already in the database';
				document.getElementById('hep').style.display = 'block';
			}
		}
";

my %headerHash = (

	titre => uc($action)." DATA",
	bgcolor => $background,
	css => $css,
	background => '',
	jscript => $JSCRIPT,
	onLoad => "testRank(document.SelectNameForm)"
);

my $nameOpts;
my $pubOpts;
my $commonOpts;
my $mm;

if ($type eq 'sciname' or $type eq 'all') {
	
	my $df;
	my $selected;
	if ($df = param('nameOrder')) { 
		Delete('nameOrder'); 
	}
	else {
		$df = 'rank';
	}
	
	my $rankOptions = "	<OPTION VALUE=rank CLASS=popupTitle STYLE='text-align: center;'>Rank
				<OPTION VALUE='' CLASS='PopupStyle' STYLE='text-align: center;'>--------";
	foreach (@{$nameOrders}) {
				
		if ($_->[2] eq $df) { $selected = 'SELECTED' } else { $selected = '' }
		
		$rankOptions .= "<OPTION VALUE='$_->[2]' $selected CLASS='PopupStyle' STYLE='text-align: center;'> $_->[1]";
	}	
	
	$nameOpts = start_form(-name=>'SelectNameForm', -method=>'post',-action=>'').
	
			table({ -border=>0 , -cellspacing=>0 , bgcolor=>$rowcolor},
				Tr(
					td({-width=>$cell1, -style=>'padding-left: 5px;'}, span({-class=>'textNavy'},span({-class=>'textLarge'},b("Scientific name")))),
					td({-width=>$cell2},
						"<SELECT NAME='nameOrder' onClick=enabled(this.form,'name') onChange=testRank(this.form) CLASS='PopupStyle' STYLE='width: $popup; text-align: center;'>$rankOptions"
					),
					td(
						div(	{-id=>'genusImgDiv',
							 -style=>'display:none; margin-left: 10px;'},
							
							textfield(-class=>'phantomTextField', -name=>'genusX', -style=>'width: 160px; color: navy;  text-indent: 5px; background: #FFFFDD;', -default=>$genusX, 
							-onFocus=>'clearGenus(this.form);', -onBlur=>'if (!this.value) { this.value = "Enter the Genus" } else { this.value = this.value.substring(0,1).toUpperCase() + this.value.substring(1,this.value.length).toLowerCase(); }')
						)
					),
					td(
						div(	{-id=>'nameImgDiv',
							-style=>'display:none;',
							-onMouseover=>"document.".$action."name.src=eval('okonimg.src')",
							-onMouseout=>"document.".$action."name.src=eval('okoffimg.src')",
							-onClick=>"testName(document.SelectNameForm);"},
							
							img({-style=>'margin-left: 10px;', -border=>0, -src=>'/Editor/ok0.png', -name=>$action."name"})
						)
					)
				)
			).
			
			arg_persist().

		end_form();
}

my $otherOptions;
foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
	if($table ne 'taxons_x_pays' and $table ne 'taxons_x_plantes' and $table ne 'taxons_x_vernaculaires' and $table ne 'taxons_x_images' and $table ne 'noms_x_images') {
		$otherOptions .= "<OPTION VALUE='crosstable.pl?cross=$table&xaction=$reaction' CLASS='PopupStyle'> $cross_tables->{$table}->{'title'}  </OPTION>";
	}
}

if ($type eq 'all') {
	
        my $dataOptions = "	<OPTION VALUE='' CLASS='popupTitle'>  </OPTION>
				<OPTION VALUE='crosstable.pl?cross=taxons_x_pays&xaction=$reaction' CLASS='PopupStyle'> Taxon geographic distribution </OPTION>
				<OPTION VALUE='crosstable.pl?cross=taxons_x_plantes&xaction=$reaction' CLASS='PopupStyle'>  Taxon Host plant(s) </OPTION>
				<OPTION VALUE='crosstable.pl?cross=taxons_x_vernaculaires&xaction=$reaction' CLASS='PopupStyle'>  Taxon vernacular name(s) </OPTION>
				<OPTION VALUE='crosstable.pl?cross=taxons_x_images&xaction=$reaction' CLASS='PopupStyle'>  Taxon image(s) </OPTION>
				<OPTION VALUE='crosstable.pl?cross=noms_x_images&xaction=$reaction' CLASS='PopupStyle'>  Type specimen image(s) </OPTION>
				$otherOptions
				<OPTION VALUE='generique.pl?table=auteurs' CLASS='PopupStyle'>  Authors </OPTION>";
	
	$commonOpts = start_form(-name=>'CommonForm', -method=>'post',-action=>'').
	
			table({ -border=>0 , -cellspacing=>0 , bgcolor=>$rowcolor},
				Tr(	td({-width=>$cell1, -style=>'padding-left: 5px;'}, span({-class=>'textNavy'},span({-class=>'textLarge'}, b("Other data")))),
					td({-width=>$cell2},
						"<SELECT NAME='dataType' onClick=enabled(this.form,'data') onChange=active(this.form,'data') CLASS='PopupStyle' STYLE='width: $popup;'> $dataOptions"
					),
					td(),
					td(
						div(	{-id=>'dataImgDiv',
							-style=>'display: none;',
							-onMouseover=>"dataok.src=eval('okonimg.src')",
							-onMouseout=>"dataok.src=eval('okoffimg.src')",
							-onClick=>"CommonForm.action = CommonForm.dataType.value; CommonForm.submit();"},
							
							img({-style=>'margin-left: 10px;', -border=>0, -src=>'/Editor/ok0.png', -name=>"dataok"})
						)
					)
				),
			).

			arg_persist().
			
		end_form();
}

if ($type eq 'pub' or $type eq 'all') {
	
	my $pubOptions = "	<OPTION VALUE=type CLASS=popupTitle STYLE='text-align: center;'>Type
				<OPTION VALUE='' CLASS='PopupStyle' STYLE='text-align: center;'>--------";
	foreach (@{$pubTypes}) {
		$pubOptions .= "<OPTION VALUE='$_' CLASS='PopupStyle' STYLE='text-align: center;'> $_";
	}
	
	my $cible = "Publications.pl?action=$vreaction&page=pub";
	
	clear_params(param('pubType'));

	$pubOpts = start_form(-name=>'SelectPubForm', -method=>'post',-action=>$cible).
			
			table({ -border=>0 , -cellspacing=>0 , bgcolor=>$rowcolor},
				Tr(
					td({-width=>$cell1, -style=>'padding-left: 5px;'}, span({-class=>'textNavy'},span({-class=>'textLarge'},b("Publication")))),
					td({-width=>$cell2},
						"<SELECT NAME='pubType' onClick=enabled(this.form,'pub') onChange=\"active(this.form,'pub'); testPub(this.form)\"; CLASS=PopupStyle STYLE='width: $popup; text-align: center;'>$pubOptions"
					),
					td(),
					td(
						div(	{-id=>'pubImgDiv',
							-style=>'display:none;',
							-onMouseover=>"document.".$action."pub.src=eval('okonimg.src')",
							-onMouseout=>"document.".$action."pub.src=eval('okoffimg.src')",
							-onClick=>"document.SelectPubForm.submit();"},
							
							img({-style=>'margin-left: 10px;', -border=>0, -src=>'/Editor/ok0.png', -name=>$action."pub"})
						)
					)
				)	
			).
			
			arg_persist().
			
		end_form();
}

	
$mm = 	br.a(	{href=>"action.pl", -onMouseOver=>"mM.src=eval('mMonimg.src')", -onMouseOut=>"mM.src=eval('mMoffimg.src')"},
		img({-border=>0, -src=>'/Editor/mainMenu0.png', -name=>"mM"})
	);

print 	html_header(\%headerHash),

	#join(br, map { "$_ = ".param($_) } param()).
	
	div({-style=>'width: 1000px; height: 20px; margin: 4% auto 0 auto; padding: 30px 0; font-size: 20px; color: navy; font-style: italic; font-weight: bold;'}, "$dblabel editor"),
	
	div({-class=>"wcenter"},
	
		table({style=>"margin-bottom: 4%;", -cellspacing=>0, cellpadding=>0},
			Tr(
				td({-style=>'background: url(/Editor/pill1.png); width: 14px; height: 26px;'}),
				td({-style=>'background: url(/Editor/pill2.png) repeat-x; color: #FFFFDD; font-size: 18px; font-style: italic;'}, ucfirst($action)." data"),
				td({-style=>'background: url(/Editor/pill3.png); width: 14px; height: 26px'})
			)
		).
			
		$nameOpts, br,
		
		$pubOpts, br,
		
		$commonOpts,
		
		start_form(-name=>'warnForm', -method=>'post',-action=>''), 
				
			img({-id=>'hep', -border=>0, -src=>'/Editor/caution.jpg', -name=>"hep" , -alt=>"Caution", -style=>'display: none;'}), br,
			textfield(-name=>'warning', -style=>"background: $background; width: 800px; border: 0; color: crimson;", -onClick=>"this.blur();"),
		
		end_form(),
		
		$mm
	),p,
	
	html_footer();


$dbc->disconnect();
exit;

sub clear_params {

	my ($type) = @_;
			
	my $i=1;
	while (param("pubAFN$i")) { Delete("pubAFN$i"); Delete("pubALN$i"); $i++; }
	
	Delete ("pubtitle");
	Delete ("pubyear");
	Delete ("pubpgdeb");
	Delete ("pubpgfin");
	Delete ("pubnbauts");
	
	if ($type eq 'Article') { Delete("pubrevue"); Delete("pubvol"); Delete("pubfasc"); }
	elsif ($type eq 'Book') { Delete("pubedition"); Delete("pubvol"); }
	elsif ($type eq 'Thesis') { Delete("pubedition"); }
	elsif ($type eq 'In book') { Delete("bookid"); }
	
	Delete ("pubType");
}

