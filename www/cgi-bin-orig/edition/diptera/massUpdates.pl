#!/usr/bin/perl
BEGIN {push @INC, '/var/www/cgi-bin/edition/diptera/'} 
use strict;
use warnings;
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser
use CGI::Ajax;
use DBCommands qw (get_connection_params db_connection request_tab request_row);
use Conf qw ($conf_file $css $jscript_for_hidden $cross_tables html_header html_footer arg_persist $maintitle);
use utf8;

my $config = get_connection_params($conf_file);
my $dbc = db_connection($config, 'EDITOR');
my $user = remote_user();
my $test;

foreach (param()) { if ( !param($_) or param($_) =~ m/^-- / or param($_) eq 'undefined' ) { Delete($_); } }

my $cgi = new CGI();
my $pjx = new CGI::Ajax( 'getThesaurusItems' => \&getThesaurusItems, 'getPubTitle' => \&getPubTitle );	

# fast access
my $jscript = "function setThesaurusItems() { 
		var arr = arguments[0].split('_ARG_');
		var idx = arr[0]; 
		var tbl = arr[1]; 
		var str = arr[2]; 
		var nb = arr[3]; 
		var expr = arr[4]; 
		var test = expr.search('--');
		//if (nb == 0 && test == -1) { alert('No data matches \"'+expr+'\"'); }
		eval(str);
		if(__AutoComplete[idx]) { AutoComplete_HideDropdown(idx); }
		AutoComplete_Create(idx, tbl, 'origin', 'selectForm', 770, 'true');
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

mainFunction();

$dbc->disconnect();
exit;

# Functions #############################################################################################################################

sub mainFunction() {

	
	my $action = param('action') || url_param('action') || '';
	my $origin = param('origin') || url_param('origin');
	
	my $actionPopup = popup_menu(	-name=>"action", 
					-values=>['', 'insert', 'update'], 
					-labels=>{''=>'-- Select an action --', 'insert'=>'Make taxonomic transfers', 'update'=>'Change higher taxon'}, 
					-default=>$action,
					-onChange=>"if (this.value != '') { document.selectForm.submit(); }"	);
	
	my $xfield;
	if ($action) {
		$xfield .= p;
		$xfield .= textfield(
			-name=> 'elementX', 
			-id => 'elementX', 
			-style=>'width: 770px;', 
			-autocomplete=>'off',
			-value => param('elementX') || "-- Select a higher taxon --", 
			-onFocus => "document.selectForm.origin.value = ''; this.value = '';",
			-onKeyDown => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyDown(document.getElementById('elementX').getAttribute('id'), event);
					}
					else { AutoComplete_HideDropdown(document.getElementById('elementX').getAttribute('id')); }",
			-onKeyUp => "	if(event.keyCode == 9 || event.keyCode == 13 || event.keyCode == 27 || event.keyCode == 38 || event.keyCode == 40) {
						return AutoComplete_KeyUp(document.getElementById('elementX').getAttribute('id'), event);
					}
					else {
						function callServerScript() { 
							if(document.getElementById('elementX').value.length > 2) { 
								getThesaurusItems(['args__elementX', 'args__taxons', 'args__'+encodeURIComponent(document.getElementById('elementX').value), 'args__', 'NO_CACHE'], [setThesaurusItems]);
							} 
							else {  
								AutoComplete_HideDropdown(document.getElementById('elementX').getAttribute('id')); 
							}
						}
						typewatch(callServerScript, 500);
					}",
			-onBlur =>  "if(!this.value || !document.selectForm.origin.value) { this.value = '-- Select a higher taxon --'; document.selectForm.origin.value = ''; }"
		)."\n";
	}
		
	my $xhiddens = hidden(-name=>'origin', -id=>'origin');
		
	my $xsubmit;
	if ($origin) {
		$xsubmit = 	table({-cellspacing=>0, -border=>0}, Tr(
				td(img({-src=>'/dbtntDocs/submit.png', 
					-name=>'next',
					-border=>0,
					-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleSubmit').innerHTML = 'Submit';", 
					-onMouseOut=>"document.getElementById('bulleSubmit').innerHTML = '';",
					-onClick=>"if (document.selectForm.origin.value) { document.selectForm.submit(); } else { alert('Select a higher taxon'); }" })).
				td({-id=>"bulleSubmit", -style=>'width: 100px; color: darkgreen; padding-left: 5px;'}, '')
			));
	}
	
	my $html .=		
	"<HTML>".
	"<HEAD>".
	"\n	<TITLE>".ucfirst("Update taxa")." selection</TITLE>".
	"\n	<STYLE TYPE='text/css'>$css</style>".
	"\n	<SCRIPT TYPE='text/javascript' SRC='/dbtntDocs/SearchMultiValue.js'></SCRIPT>".
	"\n	<SCRIPT TYPE='text/javascript'>$jscript</SCRIPT>".
	"</HEAD>".
	"<BODY>".
	$maintitle.
	"<DIV CLASS='wcenter'>".
	#div({style=>"margin-bottom: 4%; font-size: 18px; font-style: italic;"}, "Select a higher taxon").
	start_form(-name=>'selectForm', -method=>'post', -action=>url()).
	$actionPopup.
	$xfield.
	$xhiddens.
	p. br.
	$xsubmit.
	end_form().
	#join(br, map { "$_ = ".param($_)."<BR>" } param()).
	"</DIV>".
	"</BODY>".
	"</HTML>";
	
	print 	$pjx->build_html($cgi, $html, {-charset=>'UTF-8'});
}

sub getThesaurusItems {
	
	my ($id, $table, $expr) = @_;	
	my ($req, $res, $str, $where);

	if ($id) {
		$str = "$table = {}; ";
		$expr =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
		$expr =~ s/\*/\%/g;
	}
		
	if ($table eq 'taxons') { 
		
		$req = "SELECT t.index || '#' || nc.index,
			nc.orthographe,
			nc.autorite,
			txn.ref_statut,
			CASE WHEN (SELECT count(*) FROM taxons_x_noms WHERE ref_nom = txn.ref_nom AND ref_nom_cible = txn.ref_nom_cible) > 1 THEN
			' => '||(SELECT orthographe || coalesce(' '||autorite,'') FROM noms_complets WHERE index = (SELECT ref_nom FROM taxons_x_noms where ref_taxon = txn.ref_taxon and ref_statut = 1))
			END
		FROM taxons_x_noms AS txn 
		LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
		LEFT JOIN noms_complets AS nt ON nt.index = txn.ref_nom_cible
		LEFT JOIN noms AS n ON n.index = nc.index
		LEFT JOIN noms AS n2 ON n2.index = nt.index
		LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
		WHERE txn.ref_statut = 1
		AND ordre >= (SELECT ordre from rangs WHERE en = 'subgenus')
		AND nc.orthographe ILIKE '%$expr%'
		ORDER BY 2, 3, 4, 1;";
		
		$res = request_tab($req, $dbc, 2);
				
		foreach (@{$res}) { $str .= $table.'["'.$_->[1].$_->[4].'"] = "'.$_->[0].'"; '; }
	}
		
	if ($id) { return($id.'_ARG_'.$table.'_ARG_'.$str.'_ARG_'.scalar(@{$res}).'_ARG_'.$expr); }
	else { return($str); }
}
