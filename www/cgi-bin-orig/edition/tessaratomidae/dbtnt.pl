#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/tessaratomidae/'} 
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use DBCommands qw (get_connection_params db_connection request_tab request_hash);
use Conf qw ($conf_file $css $jscript_for_hidden $dblabel $cross_tables $single_tables html_header html_footer arg_persist $maintitle);

# Gets parameters
#####################################################################################################################################################################
my $cell1 = 120;
my $cell2 = 200;
my $popup = '300px';

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EXPLORER');

my $action = url_param('action') || param('action') || 'insert'; Delete('action');
my $type = url_param('type') || param('type') || 'all'; Delete('type');

my $nameOrders = request_tab("SELECT index,en,ordre FROM rangs ORDER BY ordre;",$dbc,2);
my $pubTypes = request_tab("SELECT en FROM types_publication ORDER BY en;",$dbc,1);

my $reaction;
my $hidden;
my $prefix1;
my $prefix2;
my $vreaction;
if ($action eq 'insert') { $reaction = 'insert'; $vreaction = 'fill'; }
elsif ($action eq 'update') { $reaction = 'get'; $vreaction = 'get'; }

my $JSCRIPT = 	$jscript_for_hidden .
		
		"function enabled(form,except) {
			if (except == 'none') {
				inactive(document.SelectNameForm,'name');
				inactive(document.SelectPubForm,'pub');
				inactive(document.CommonForm,'cross')
				inactive(document.CommonForm,'single')
			} else {
				if (except != 'pub') { inactive(document.SelectPubForm,'pub'); }
				if (except != 'name') { inactive(document.SelectNameForm,'name'); }
				if (except != 'cross') { inactive(document.CommonForm,'cross'); }
				if (except != 'single') { inactive(document.CommonForm,'single'); }
			}
		}
		
		function imgerase(type) {
			
			if (type == 'pub') {  document.getElementById('pubImgDiv').style.display = 'none' }
			if (type == 'name') { document.getElementById('nameImgDiv').style.display = 'none' }
			if (type == 'cross') { document.getElementById('crossImgDiv').style.display = 'none' }
			if (type == 'single') { document.getElementById('singleImgDiv').style.display = 'none' }

		}
		
		function imgdisplay(type) {
			
			if (type == 'name') { document.getElementById('nameImgDiv').style.display = 'block' }
			if (type == 'pub') { document.getElementById('pubImgDiv').style.display = 'block'; }
			if (type == 'cross') { document.getElementById('crossImgDiv').style.display = 'block'; }
			if (type == 'single') { document.getElementById('singleImgDiv').style.display = 'block'; }
		}
		
		function active(form,type) {
			
			if (type == 'name' ) {
				if (form.nameOrder.value) { imgdisplay('name'); }
				else { enabled(form,'none'); }	
			} else if (type == 'pub') {
				if (form.pubType.value) { imgdisplay('pub'); }
				else { enabled(form,'none'); }
			} else if (type == 'cross') {
				if (form.crossTable.value) { imgdisplay('cross'); }
				else { enabled(form,'none'); }
			} else if (type == 'single') {
				if (form.singleTable.value) { imgdisplay('single'); }
				else { enabled(form,'none'); }
			}
			document.getElementById('hep').style.display = 'none';
		}
		
		function inactive(form,type) {
			
			if (type == 'name' ) {
				imgerase('name');
				form.nameOrder.value = '';	
			} else if (type == 'pub') {		
				imgerase('pub');
				form.pubType.value = '';
			} else if (type == 'cross') {
				imgerase('cross');
				form.crossTable.value = '';
			} else if (type == 'single') {
				imgerase('single');
				form.singleTable.value = '';
			}
		}
		
		function testRank (form) {		
			active(form,'name');
		}
		
		function testName (form) {
			form.action = 'Names.pl?action=$reaction'; form.submit();
		}
		
		function testPub (form) {
			if (form.pubType.value == 'In book') { 
				document.getElementById('warning').innerHTML = 'Make sure that the book is already in the database';
				document.getElementById('hep').style.display = 'table';
			}
		}
";

my %headerHash = (

	titre => uc($action)." DATA",
	css => $css,
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
	
	my $rankOptions = "<OPTION VALUE='' CLASS='PopupStyle' STYLE='text-align: center;'> -------- </OPTION>";
	foreach (@{$nameOrders}) {
				
		if ($_->[2] eq $df) { $selected = 'SELECTED' } else { $selected = '' }
		
		$rankOptions .= "<OPTION VALUE='$_->[2]' $selected CLASS='PopupStyle' STYLE='text-align: center;'> " . ucfirst($_->[1]) . " </OPTION>";
	}	
	
	$nameOpts = start_form(-name=>'SelectNameForm', -method=>'post',-action=>'').
	
			table({ -border=>0 , -cellspacing=>0 },
				Tr(
					td({-width=>$cell1, -style=>'padding-left: 0px;'}, "Scientific name"),
					td({-width=>$cell2},
						"<SELECT NAME='nameOrder' onClick=enabled(this.form,'name') onChange=testRank(this.form) CLASS='PopupStyle' STYLE='width: $popup; text-align: center; border: 1px solid #888888;'>$rankOptions"
					),
					td(
						div(	{-id=>'nameImgDiv',
							-style=>'display: none; margin-left: 10px;',
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleName').innerHTML = 'Submit';",
							-onMouseOut=>"document.getElementById('bulleName').innerHTML = '';",
							-onClick=>"testName(document.SelectNameForm);"},
							
							img({-border=>0, -src=>'/Editor/ok.png', -name=>$action."name"})
						)
					),
					td({-id=>"bulleName", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '') 
				)
			).
			
			arg_persist().

		end_form();
}

if ($type eq 'all') {
	
	my $Options;
	foreach my $table (sort {$cross_tables->{$a}->{'title'} cmp $cross_tables->{$b}->{'title'}} keys(%{$cross_tables})) {
		$Options .= "<OPTION VALUE='crosstable.pl?cross=$table&xaction=$vreaction' CLASS='PopupStyle'> " . ucfirst($cross_tables->{$table}->{'title'}) . " </OPTION>";
	}
        $Options = "<OPTION VALUE='' CLASS='popupTitle'> -------- </OPTION> $Options";
	
        my $Options2;
	foreach my $table (sort {$single_tables->{$a}->{'title'} cmp $single_tables->{$b}->{'title'}} keys(%{$single_tables})) {
		$Options2 .= "<OPTION VALUE='generique.pl?table=$table' CLASS='PopupStyle'> " . ucfirst($single_tables->{$table}->{'title'}) . " </OPTION>";
	}
        $Options2 = "<OPTION VALUE='' CLASS='popupTitle'> -------- </OPTION> $Options2";
	
	$commonOpts = start_form(-name=>'CommonForm', -method=>'post',-action=>'').
	
			table({ -border=>0 , -cellspacing=>0 },
				Tr(	td({-width=>$cell1, -style=>'padding-left: 0px;'}, "Taxa-related data"),
					td({-width=>$cell2},
						"<SELECT NAME='crossTable' onClick=enabled(this.form,'cross') onChange=active(this.form,'cross') CLASS='PopupStyle' STYLE='text-align: center; width: $popup; border: 1px solid #888888;'> $Options"
					),
					td(),
					td(
						div(	{-id=>'crossImgDiv',
							-style=>'display: none; margin-left: 10px;',
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleCross').innerHTML = 'Submit';",
							-onMouseOut=>"document.getElementById('bulleCross').innerHTML = '';",
							-onClick=>"CommonForm.action = CommonForm.crossTable.value; CommonForm.submit();"},
							
							img({-border=>0, -src=>'/Editor/ok.png', -name=>"dataok"})
						)
					),
					td({-id=>"bulleCross", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '') 
				),
			). p.
			
			table({ -border=>0 , -cellspacing=>0 },
				Tr(	td({-width=>$cell1, -style=>'padding-left: 0px;'}, "Single data"),
					td({-width=>$cell2},
						"<SELECT NAME='singleTable' onClick=enabled(this.form,'single') onChange=active(this.form,'single') CLASS='PopupStyle' STYLE='text-align: center; width: $popup; border: 1px solid #888888;'> $Options2"
					),
					td(),
					td(
						div(	{-id=>'singleImgDiv',
							-style=>'display: none; margin-left: 10px;',
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleSingle').innerHTML = 'Submit';",
							-onMouseOut=>"document.getElementById('bulleSingle').innerHTML = '';",
							-onClick=>"CommonForm.action = CommonForm.singleTable.value; CommonForm.submit();"},
							
							img({-border=>0, -src=>'/Editor/ok.png', -name=>"dataok"})
						)
					),
					td({-id=>"bulleSingle", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '') 
				),
			).

			arg_persist().
			
		end_form();
}

if ($type eq 'pub' or $type eq 'all') {
	
	my $pubOptions = "<OPTION VALUE='' CLASS='PopupStyle' STYLE='text-align: center;'> -------- </OPTION>";
	foreach (@{$pubTypes}) {
		$pubOptions .= "<OPTION VALUE='$_' CLASS='PopupStyle' STYLE='text-align: center;'> $_ </OPTION>";
	}
	
	my $cible = "Publications.pl?action=$vreaction&page=pub";
	
	clear_params(param('pubType'));

	$pubOpts = start_form(-name=>'SelectPubForm', -method=>'post',-action=>$cible).
			
			table({ -border=>0 , -cellspacing=>0 },
				Tr(
					td({-width=>$cell1, -style=>'padding-left: 0px;'}, "Publication"),
					td({-width=>$cell2},
						"<SELECT NAME='pubType' onClick=enabled(this.form,'pub') onChange=\"active(this.form,'pub'); testPub(this.form)\"; CLASS=PopupStyle STYLE='width: $popup; text-align: center; border: 1px solid #888888;'>$pubOptions"
					),
					td(),
					td(
						div(	{-id=>'pubImgDiv',
							-style=>'display: none; margin-left: 10px;',
							-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bullePub').innerHTML = 'Submit';",
							-onMouseOut=>"document.getElementById('bullePub').innerHTML = '';",
							-onClick=>"document.SelectPubForm.submit();"},
							
							img({-border=>0, -src=>'/Editor/ok.png', -name=>$action."pub"})
						)
					),
					td({-id=>"bullePub", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '') 
				)	
			).
			
			arg_persist().
			
		end_form();
}

my $xaction  = popup_menu(-name=>"action", -default=>$action, -values=>['insert', 'update'], onChange=>"document.actionForm.action='dbtnt.pl?type=$type'; document.actionForm.submit();" );

print 	html_header(\%headerHash),

	#join(br, map { "$_ = ".param($_) } param()).
	
	$maintitle,
	div({-class=>"wcenter"},
	
		div({-style=>'margin-bottom: 2%; font-size: 18px; font-style: italic;'}, "Action"),
		
		start_form(-name=>'actionForm', -method=>'post',-action=>''),
			
			$xaction,
		
		end_form(), p,
		
		div({-style=>'margin-bottom: 2%; font-size: 18px; font-style: italic;'}, "Data type"),
			
		$nameOpts, br,
		
		$pubOpts, br,
		
		$commonOpts,
						
		table({-id=>'hep', -style=>'display: none; margin-top: 20px;'}, Tr(
			td( img({-src=>'/Editor/caution.png', -alt=>"Caution", -style=>'width: 25px;'}) ),
			td( span({-id=>'warning', -style=>'color: Crimson;'}, '') )
		) )
	),
	
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

