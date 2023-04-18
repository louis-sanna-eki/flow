package Conf;

use Carp;
use strict;
use warnings;
use DBI;
use CGI qw( -no_xhtml :standard );
use CGI::Carp qw( fatalsToBrowser warningsToBrowser );
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);

BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA         = qw(Exporter);
	@EXPORT      = qw($css $conf_file $jscript_funcs $jscript_for_hidden $dblabel $cross_tables $single_tables &request_tab_with_values &get_single_table_parameters &make_single_table_fields &get_single_table_thesaurus &html_header &html_footer &arg_persist &pub_formating &get_pub_params &make_thesaurus &multivalue_thesaurus &search_formating $maintitle %statuts $js $authorsJscript &makeAuthorsfields &AonFocus &add_author);
	%EXPORT_TAGS = ();	
	@EXPORT_OK   = qw();
}
    

use vars qw($css $conf_file $jscript_for_hidden $dblabel $cross_tables $single_tables &request_tab_with_values &get_single_table_parameters &make_single_table_fields &get_single_table_thesaurus &html_header &html_footer &arg_persist &pub_formating &get_pub_params &make_thesaurus &multivalue_thesaurus &search_formating $maintitle %statuts $js $authorsJscript &makeAuthorsfields &AonFocus &add_author);

# Configuration file path for database connection
our $conf_file = '/etc/flow/floweditor.conf';

# Editor name
my $config = get_connection_params($conf_file);
my $dbh = db_connection($config, 'DEFAULT');
our $dblabel = $config->{'DB_NAME'};

# submit query in sql (return a two dimensions array ref)
sub request_tab_with_values {	
	my ($req, $values, $dbh, $dim) = @_;

	my $tab_ref = [];
	if ( my $sth = $dbh->prepare($req) ){
		if ( $sth->execute(@{$values}) ){
			if ($dim eq 1) {
				while ( my @row = $sth->fetchrow_array ) {
    					push(@{$tab_ref}, $row[0]);
  				}
			} else {
				$tab_ref = $sth->fetchall_arrayref;
			}
			$sth->finish();
		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" }
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" }

	return $tab_ref;
}

# make a thesaurus in case of table foreign key
sub multivalue_thesaurus {

	my ($req, $hash, $format, $values, $retro, $onload, $dbc) = @_;
	my ($res, $hashlabels);
		
	$res = request_tab($req, $dbc, 2);
	
	$hashlabels = ();
	foreach my $row (@{$res}) {
		my ($intitule, $valeur);
		eval($format);
		eval($values);
		${$retro}->{$valeur} = $intitule;
		$intitule =~ s/'/\\'/g;
		$intitule =~ s/"/\\"/g;
		$intitule =~ s/\[/\\[/g;
		$intitule =~ s/\]/\\]/g;
		$intitule =~ s/  / /g;
		$hashlabels .= $hash.'["'.$intitule.'"] = "' . $valeur . '";' . "\n";
	}
	${$onload} .= "var $hash = {};\n$hashlabels\n";
}

# remove special characters for search bar
sub search_formating {
	my ($table, $arr, $load, $retro, $dbh) = @_;
			
	my $ids;
	my $values;
	foreach (@{$arr}) {
		$_->[1] =~ s/'/\\'/g;
		$_->[1] =~ s/"/\\"/g;
		$_->[1] =~ s/\[/\\[/g;
		$_->[1] =~ s/\]/\\]/g;
		$_->[1] =~ s/  / /g;
		
		push(@{$ids}, $_->[0]);
		push(@{$values}, $_->[1]);
		${$retro}->{$_->[0]} = $_->[1];
		
		if ($_->[1] =~ m|[^A-Z a-z 0-9 : , ( ) \[ \] ! _ = & ° . * ; “ " ’ ” ' \\ \/ \- – ? ‡ \n ]|) {
			my ($res) = @{request_row("SELECT reencodage('".$_->[1]."');", $dbh)};
			$res =~ s/'/\\'/g;
			$res =~ s/"/\\"/g;
			$res =~ s/\[/\\[/g;
			$res =~ s/\]/\\]/g;
			$res =~ s/  / /g;
			
			push(@{$ids}, $_->[0]);
			push(@{$values}, $res);
		}	
	}
	${$load} .= $table . "IDs = [\n'" . join("',\n'", @{$ids}) . "'\n];\n\n$table = [\n'" . join("',\n'", @{$values}) . "'\n];\n";
}

our %statuts = (
	0 	=>	'-- select --',
	1	=>	'valid name',
	2	=>	'synonymy',
	4	=>	'taxonomic transfer',
	11	=>	'nomen novum',
	12	=>	'unjustified emendation',
	14	=>	'forsaken or foreign name',
	15	=>	'justified emendation',
	19	=>	'nomen oblitum',
	23	=>	'taxonomic rank revision',

	3	=>	'misspelling',
	5	=>	'nomen nudum',
	8	=>	'correct use (chresonymy)',
	10	=>	'homonymy',
	17	=>	'misidentification (without correction)',
	18	=>	'misidentification (with correction)',
	20	=>	'foreign taxon',
	21	=>	'taxon reinstatement (status revivisco)',
	22	=>	'name reinstatement (combinatio revivisco)'
);

our $js = "
	var statdef = {};
	statdef[1]	=	'Enter a valid name';
	statdef[22]	=	'Set a name as reinstated';
	statdef[21]	=	'Set a taxon as reinstated';
	statdef[10]	=	'Link a junior homonym to the senior homonym';
	statdef[11]	=	'Link a junior homonym to the new replacement name';
	statdef[12]	=	'Link an incorrect subsequent spelling to the correct spelling';
	statdef[15]	=	'Link an incorrect original spelling to the correct spelling';
	statdef[4]	=	'Link a previous combination to the new combination';
	statdef[2]	=	'Link a junior synonym to the senior synonym';
	statdef[19]	=	'Link a nomen oblitum to the nomen protectum';
	statdef[23]	=	'Link a name with a previous taxonomic rank to the new taxonomic rank';
	statdef[8]	=	'Link a name to a source publication';
	statdef[5]	=	'Link a nomen nudum to valid name';
	statdef[3]	=	'Link a misspelling to the correct spelling';
	statdef[17]	=	'Set a name as misapplied for a taxon';
	statdef[18]	=	'Set a name as misapplied for a taxon and make the emendation';
	statdef[14]	=	'Enter a forsaken or foreign name for a taxon';
	statdef[20]	=	'Enter a \"foreign taxon\" name';

	var stattgt = {};
	stattgt[22]	=	'Name to be reinstated';
	stattgt[21]	=	'Taxon to be reinstated';
	stattgt[10]	=	'Senior homonym';
	stattgt[11]	=	'New replacement name';
	stattgt[15]	=	'Correct spelling';
	stattgt[4]	=	'New taxonomic position';
	stattgt[2]	=	'Senior synonym';
	stattgt[19]	=	'Nomen protectum';
	stattgt[23]	=	'New name';
	stattgt[5]	=	'Valid name';
	stattgt[8]	=	'Chresonym';
	stattgt[3]	=	'Correct spelling';
	stattgt[12]	=	'Correct spelling';
	stattgt[17]	=	'Misapplied name';
	stattgt[18]	=	'Valid name';
	stattgt[14]	=	'Valid name';
	
	var statori = {};
	statori[1]	=	'Valid name';
	statori[10]	=	'Junior homonym';
	statori[11]	=	'Junior homonym';
	statori[15]	=	'Incorrect original spelling';
	statori[4]	=	'Previous taxonomic position';
	statori[2]	=	'Junior synonym';
	statori[19]	=	'Nomen oblitum';
	statori[23]	=	'Previous name';
	statori[5]	=	'Nomen nudum';
	statori[3]	=	'Misspelling';
	statori[12]	=	'Incorrect subsequent spelling';
	statori[18]	=	'Misapplied name';
	statori[14]	=	'Forsaken or foreign name';
	statori[20]	=	'Foreign taxon name';
	
	var princeps = {};
	princeps[1]  = 'Original publication';
	princeps[10] = 'Original publication';
	princeps[11] = 'Original publication';
	princeps[2]  = 'Original publication';
	princeps[19] = 'Original publication';
	princeps[23] = 'Original publication';
	princeps[18] = 'Original publication';

	var denonce = {};
	denonce[22]	=	'Source publication';
	denonce[21]	=	'Source publication';
	denonce[10]	=	'Publication stating the homonymy';
	denonce[11]	=	'Publication correcting the homonymy';
	denonce[15]	=	'Publication making the emendation';
	denonce[4]	=	'Publication making the name recombination';
	denonce[2]	=	'Publication making the synonymy';
	denonce[19]	=	'Publication establishing the nomen oblitum';
	denonce[23]	=	'Publication making the rank revision';
	denonce[3]	=	'Publication correcting the mispelling';
	denonce[12]	=	'Publication invalidating the emendation';
	denonce[18]	=	'Publication correcting the misidentification';	
	denonce[5]	=	'Publication validating the nomen nudum';	
	
	var usage = {};
	usage[8]  = 'source publication';
	usage[5]  = 'source publication';
	usage[3]  = 'publication making the mispelling';
	usage[12] = 'publication making the emendation';
	usage[17] = 'publication making the misidentification';
	usage[18] = 'publication making the misidentification';
	
	var tnomstat = {};
	tnomstat[22]	= 'combinatio revivisco';
	tnomstat[21]	= 'status revivisco';
	tnomstat[10]	= 'senior homonym';
	tnomstat[11]	= 'nomen novum';
	//tnomstat[4]	= 'combinatio nova';
	tnomstat[2]	= 'senior synonym';
	tnomstat[19]	= 'nomen protectum';
	
	var snomstat = {};
	snomstat[4]	= '';
	snomstat[10]	= 'junior homonym';
	snomstat[11]	= 'nomen praeoccupatum';
	snomstat[2]	= 'junior synonym';
	snomstat[19]	= 'nomen oblitum';
	snomstat[5]	= 'nomen nudum';

	function testStatement(element) {
	
		if (element.value != 0) { 
			uncolorName();
			uncolorPub(1);
			uncolorPub(2);
			var valeur = element.value;
			
			document.getElementById('mainField').style.display = 'inherit'; 				
			document.getElementById('mainLegend').innerHTML = statdef[element.value]; 
			
			if (stattgt[element.value]) { 
				document.getElementById('targetField').style.display = 'inherit';
				document.getElementById('targetLegend').innerHTML = stattgt[element.value];
			}
			else { 
				document.getElementById('targetField').style.display = 'none';
				document.getElementById('taxon').value = '-- scientific name --';
				document.getElementById('taxonID').value = '';
				document.getElementById('targetID').value = '';
			}
								
			if (statori[element.value]) { 
				document.getElementById('nameField').style.display = 'inherit';
				document.getElementById('nameLegend').innerHTML = statori[element.value];
			}
			else { 
				document.getElementById('nameField').style.display = 'none';
				document.getElementById('sciname').value = '-- scientific name --';
				document.getElementById('nameID').value = '';
			}
								
			if (valeur == 1 || valeur == 5 || valeur == 20) {
				document.getElementById('nameSearchField').style.display = 'none';
				document.getElementById('sciname').value = '-- scientific name --';
				document.getElementById('nameID').value = '';
			}
			else {
				document.getElementById('nameSearchField').style.display = 'inherit';
			}
								
			/*if (valeur == 5) {
				document.nameForm.year.style.display = 'none';
				document.nameForm.year.value = '-- year --';
			}
			else {
				document.nameForm.year.style.display = 'inline';
			}*/
			
			if (princeps[element.value]) { 
				document.getElementById('pubField2').style.display = 'inherit';
				document.getElementById('pubLegend2').innerHTML = princeps[element.value];
			}
			else { 
				document.getElementById('pubField2').style.display = 'none';
				clearSearchedPub(2);
				clearPub(2);
				hidePub(2);
			}
			if (usage[element.value]) { 
				document.getElementById('pubField3').style.display = 'inherit';
				document.getElementById('pubLegend3').innerHTML = usage[element.value];
			}
			else { 
				document.getElementById('pubField3').style.display = 'none';
				clearSearchedPub(3);
				clearPub(3);
				hidePub(3);
			}
			if (denonce[element.value]) {
				document.getElementById('pubField4').style.display = 'inherit';
				document.getElementById('pubLegend4').innerHTML = denonce[element.value];
			}
			else { 
				document.getElementById('pubField4').style.display = 'none';
				clearSearchedPub(4);
				clearPub(4);
				hidePub(4);
			}
						
			if (tnomstat[element.value]) { 
				document.getElementById('tlabel').value = tnomstat[element.value];
			}
			else { 
				document.getElementById('tlabel').value = '-- nomenclatural status --';
			}
			
			if (snomstat[element.value]) { 
				document.getElementById('slabel').value = snomstat[element.value];
				document.getElementById('slabel2').value = snomstat[element.value];
			}
			else { 
				document.getElementById('slabel').value = '-- nomenclatural status --';
				document.getElementById('slabel2').value = '-- nomenclatural status --';
			}
						
			testPubType(1);
			testPubType(2);
			testPubType(3);
			testPubType(4);
			/*reloadSearch();*/			
		}
		else { document.getElementById('mainField').style.display = 'none'; }
	}
	
	function clearName(epithet) {
		uncolorName();
		document.getElementById('parent').value = '-- parent name --';
		document.getElementById('parentNameID').value = '';
		document.getElementById('parentName').value = '';
		document.getElementById('parentTaxonID').value = '';
		document.getElementById('parentOrder').value = '';
		
		document.getElementById('spelling').value = epithet;
		document.getElementById('year').value = '-- year --';
		
		var iter = 1;
		while (iter <= document.getElementById('authors').value) {
			document.getElementById('ref_author'+iter).value = '';
			document.getElementById('AFN'+iter).value = '-- author name --';
			document.getElementById('ALN'+iter).value = '-- author initials --';
			iter++;
		}
		
		document.getElementById('brackets').checked = false;
		document.getElementById('gentype').checked = false;
		document.getElementById('fossil').checked = false;
		
		document.getElementById('designation').style.display = 'none'; 
		document.getElementById('designation').selectedIndex = 0; 
		document.getElementById('designed').value = 0;
		document.getElementById('pubField1').style.display = 'none';
		
		clearSearchedPub(1);
		clearPub(1);
		hidePub(1);
		clearSearchedPub(2);
		clearPub(2);
		hidePub(2);
	}
	
	function clearSearchedName() {
		document.getElementById('sciname').style.border = '';
		document.getElementById('sciname').value = '-- scientific name --';
		document.getElementById('nameID').value = '';
	}
	
	function uncolorName() {
		document.getElementById('parent').style.border = '';
		document.getElementById('spelling').style.border = '';
		document.getElementById('year').style.border = '';
		document.getElementById('AFN1').style.border = '';
		document.getElementById('ALN1').style.border = '';
	}
	
	function testPubType(num) {
		uncolorPub(num);
		var valeur = document.getElementById('type'+num).value;
		// book
		if (valeur == 1) {
			document.getElementById('vol'+num).style.display = 'inline';
			
			document.getElementById('fasc'+num).style.display = 'none';
			document.getElementById('fasc'+num).value = '-- fasc --';
			
			document.getElementById('journal'+num).style.display = 'none';
			//document.getElementById('newJournal'+num).style.display = 'none';
			document.getElementById('journal'+num).value = '-- journal --';
			document.getElementById('journalID'+num).value = '';
			
			document.getElementById('edition'+num).style.display = 'inline';
			document.getElementById('city'+num).style.display = 'inline';
			document.getElementById('state'+num).style.display = 'inline';
			
			document.getElementById('book'+num).style.display = 'none';
			document.getElementById('newBook'+num).style.display = 'none';
			document.getElementById('book'+num).value = '-- book --';
			document.getElementById('ref_book'+num).value = '';
			
			document.getElementById('optionIL'+num).style.display = 'inherit';
			document.getElementById('pubDiv'+num).style.display = 'inherit';
		}
		// article
		else if (valeur == 2) {
			document.getElementById('vol'+num).style.display = 'inline';
			
			document.getElementById('fasc'+num).style.display = 'inline';
			
			document.getElementById('journal'+num).style.display = 'inline';
			//document.getElementById('newJournal'+num).style.display = 'inline';
			
			document.getElementById('edition'+num).style.display = 'none';
			document.getElementById('city'+num).style.display = 'none';
			document.getElementById('state'+num).style.display = 'none';
			document.getElementById('edition'+num).value = '-- edition name --';
			document.getElementById('editionID'+num).value = '';
			document.getElementById('city'+num).value = '-- edition city --';
			document.getElementById('cityID'+num).value = '';
			document.getElementById('state'+num).value = '-- edition country --';
			document.getElementById('stateID'+num).value = '';
			
			document.getElementById('book'+num).style.display = 'none';
			document.getElementById('newBook'+num).style.display = 'none';
			document.getElementById('book'+num).value = '-- book --';
			document.getElementById('ref_book'+num).value = '';
			
			document.getElementById('optionIL'+num).style.display = 'inherit';
			document.getElementById('pubDiv'+num).style.display = 'inherit';
		}
		// thesis
		else if (valeur == 3) {
			document.getElementById('vol'+num).style.display = 'none';
			document.getElementById('vol'+num).value = '-- vol --';
			
			document.getElementById('fasc'+num).style.display = 'none';
			document.getElementById('fasc'+num).value = '-- fasc --';
			
			document.getElementById('journal'+num).style.display = 'none';
			//document.getElementById('newJournal'+num).style.display = 'none';
			document.getElementById('journal'+num).value = '-- journal --';
			document.getElementById('journalID'+num).value = '';
			
			document.getElementById('edition'+num).style.display = 'inline';
			document.getElementById('city'+num).style.display = 'inline';
			document.getElementById('state'+num).style.display = 'inline';
			
			document.getElementById('book'+num).style.display = 'none';
			document.getElementById('newBook'+num).style.display = 'none';
			document.getElementById('book'+num).value = '-- book --';
			document.getElementById('ref_book'+num).value = '';
	
			document.getElementById('optionIL'+num).style.display = 'inherit';
			document.getElementById('pubDiv'+num).style.display = 'inherit';
		}
		// in book
		else if (valeur == 4) {
			document.getElementById('vol'+num).style.display = 'none';
			document.getElementById('vol'+num).value = '-- vol --';
			
			document.getElementById('fasc'+num).style.display = 'none';
			document.getElementById('fasc'+num).value = '-- fasc --';
			
			document.getElementById('journal'+num).style.display = 'none';
			//document.getElementById('newJournal'+num).style.display = 'none';
			document.getElementById('journal'+num).value = '-- journal --';
			document.getElementById('journalID'+num).value = '';
			
			document.getElementById('edition'+num).style.display = 'none';
			document.getElementById('city'+num).style.display = 'none';
			document.getElementById('state'+num).style.display = 'none';
			document.getElementById('edition'+num).value = '-- edition name --';
			document.getElementById('editionID'+num).value = '';
			document.getElementById('city'+num).value = '-- edition city --';
			document.getElementById('cityID'+num).value = '';
			document.getElementById('state'+num).value = '-- edition country --';
			document.getElementById('stateID'+num).value = '';
			
			document.getElementById('book'+num).style.display = 'inherit';
			document.getElementById('newBook'+num).style.display = 'inherit';
			
			document.getElementById('optionIL'+num).style.display = 'none';
			document.getElementById('pubDiv'+num).style.display = 'inherit';
		}
		else {
			clearPub(num);
			document.getElementById('optionIL'+num).style.display = 'none';
			document.getElementById('pubDiv'+num).style.display = 'none';
		}
		/*reloadSearch();*/
	}
	
	function clearSearchedPub(num) {
		document.getElementById('ref_pub'+num).style.border = '';
		document.getElementById('pub'+num).style.border = '';
		document.getElementById('ref_pub'+num).value = '-- index --';
		document.getElementById('pub'+num).value = '-- title --';
	}
	
	function uncolorPub(num) {
		document.getElementById('type'+num).style.border = '';
		document.getElementById('title'+num).style.border = '';
		document.getElementById('year'+num).style.border = '';
		document.getElementById('vol'+num).style.border = '';
		document.getElementById('fasc'+num).style.border = '';
		document.getElementById('FP'+num).style.border = '';
		document.getElementById('LP'+num).style.border = '';
		document.getElementById('journal'+num).style.border = '';
		document.getElementById('edition'+num).style.border = '';
		document.getElementById('city'+num).style.border = '';
		document.getElementById('state'+num).style.border = '';
		document.getElementById('p'+num+'AFN1').style.border = '';
		document.getElementById('p'+num+'ALN1').style.border = '';
		document.getElementById('book'+num).style.border = '';
	}
	
	function clearPub(num) {		
		uncolorPub(num);	
		document.getElementById('type'+num).selectedIndex = 0;
		document.getElementById('title'+num).value = '-- title --';
		document.getElementById('year'+num).value = '-- year --';
		document.getElementById('vol'+num).value = '-- vol --';
		document.getElementById('fasc'+num).value = '-- fasc --';
		document.getElementById('FP'+num).value = '-- page --';
		document.getElementById('LP'+num).value = '-- page --';
		document.getElementById('journal'+num).value = '-- journal --';
		document.getElementById('journalID'+num).value = '';
		document.getElementById('edition'+num).value = '-- edition name --';
		document.getElementById('editionID'+num).value = '';
		document.getElementById('city'+num).value = '-- edition city --';
		document.getElementById('cityID'+num).value = '';
		document.getElementById('state'+num).value = '-- edition country --';
		document.getElementById('stateID'+num).value = '';
		
		var iter = 1;
		while (iter <= document.getElementById('p'+num+'Authors').value) {
			document.getElementById('p'+num+'ref_author'+iter).value = '';
			document.getElementById('p'+num+'AFN'+iter).value = '-- author name --';
			document.getElementById('p'+num+'ALN'+iter).value = '-- author initials --';
			iter++;
		}
		
		document.getElementById('book'+num).value = '-- book --';
		document.getElementById('ref_book'+num).value = '';
	}
	
	function hidePub(num) {
		document.getElementById('pubCreateField'+num).style.display = 'none';
		document.getElementById('pubDiv'+num).style.display = 'none';
		document.getElementById('newPub'+num).value = 0;
	}
	
	function testPreFill() {
		var statut = document.getElementById('statusID').value;
		var reg = new RegExp('^-- ','g');
		var epithet = document.getElementById('spelling').value;
		if (epithet.match(reg) && document.getElementById('taxonID').value != '' && (statut == 3 || statut == 4 || statut == 10 || statut == 12 || statut == 15 || statut == 23)) {
			document.nameForm.style.display = 'none';
			document.getElementById('waiting').style.display = 'inherit';
			document.nameForm.action = 'Names.pl?action=preFill'; 
			document.nameForm.submit();
		}
	}
	
	function verification() {
		var reg = new RegExp('^-- ','g');
		var message = '';
		var failure = 0;
		if (!document.nameForm.action0.value) { message += 'action missing\\n'; }
		if (!document.nameForm.nameOrder.value) { message += 'name order missing\\n'; }
		if (!document.nameForm.statusID.value) { message += 'statement missing\\n'; }
		else {
			var element = document.getElementById('statusID');
			// If target name needed
			if (stattgt[element.value]) { 
				if (!document.nameForm.taxonID.value || !document.nameForm.targetID.value) {
					document.nameForm.taxon.style.border = '1px red solid';
					//message += 'taxon missing\\n';
					failure = 1;
				}
				else {
					document.nameForm.taxon.style.border = '';
				}
			}
			else {
				if (document.nameForm.taxonID.value || document.nameForm.targetID.value) {
					message += 'taxon irrelevant\\n';
					failure = 1;
				}
			}
			
			if (statori[element.value]) { 
				var found = 0;
				// If name found in search bar
				if (element.value != 1 && element.value != 5 && element.value != 20) {
					if (document.nameForm.nameID.value) {
						found = 1;
					}
				} else {
					if (document.nameForm.nameID.value) {
						message += 'name search irrelevant\\n';
						failure = 1;
					}
				}
				if (!found) {
					if (document.nameForm.nameOrder.value > 4 && element.value != 20) { 
						if(!document.nameForm.parentTaxonID.value || !document.nameForm.parentNameID.value || !document.nameForm.parentName.value || !document.nameForm.parentOrder.value) {
							document.nameForm.parent.style.border = '1px red solid';
							//message += 'parent name missing\\n';
							failure = 1;
						}
						else {
							document.nameForm.parent.style.border = '';
						}
					}
					if(!document.nameForm.spelling.value || document.nameForm.spelling.value.match(reg)) {
						document.nameForm.spelling.style.border = '1px red solid';
						//message += 'name spelling missing\\n';
						failure = 1;
					}
					else {
						document.nameForm.spelling.style.border = '';
					}
					if(element.value != 5) {
						if (!document.nameForm.year.value || document.nameForm.year.value.match(reg)) {
							document.nameForm.year.style.border = '1px red solid';
							//message += 'name year missing\\n';
							failure = 1;
						}
						else {
							var reg2 = new RegExp('[^0-9]+','g');
							if (document.nameForm.year.value.match(reg2) || document.nameForm.year.value < 1735) {
								document.nameForm.year.style.border = '1px red solid';
								message += 'invalid name year\\n';
								failure = 1;
							}
							else {
								document.nameForm.year.style.border = '';
							}
						}
						if (!document.nameForm.ref_author1.value && (!document.nameForm.AFN1.value || document.nameForm.AFN1.value.match(reg))) {
							document.nameForm.AFN1.style.border = '1px red solid';
							document.nameForm.ALN1.style.border = '1px red solid';
							//message += 'invalid name authority\\n';
							failure = 1;
						}
						else {
							document.nameForm.AFN1.style.border = '';
							document.nameForm.ALN1.style.border = '';
						}
					}
				}
			}
			else { 
				if (document.nameForm.nameID.value) {
					message += 'name search irrelevant\\n';
				}		
			}
			
			if (document.nameForm.designation && document.nameForm.designation.value == 1) { 
				failure = testPubFields(1, failure, reg);
			}
			
			if (princeps[element.value] && !document.getElementById('nameID').value) { 
				failure = testPubFields(2, failure, reg);
			}
								
			if (usage[element.value]) { 
				failure = testPubFields(3, failure, reg);
			}		
		}
		
		if (!failure) { 
			//if (confirm('confirmation:')) {
				document.nameForm.action = 'Names.pl?action=execute'; document.nameForm.submit();
			//}
		}
		else { alert('!! expected data missing !!\\n' + message); }
	}
	
	function testPubFields(num, failure, reg) {
		
		if (document.getElementById('ref_pub'+num).value && document.getElementById('ref_pub'+num).value != '-- index --') { document.getElementById('ref_pub'+num).style.border = ''; document.getElementById('pub'+num).style.border = ''; }
		else {
			if (document.getElementById('pubCreateField'+num).style.display != 'none') {
			
				document.getElementById('ref_pub'+num).style.border = '';
				document.getElementById('pub'+num).style.border = '';
	
				var pubtype = document.getElementById('type'+num).value;
										
				if (pubtype == 0) {
					failure = 1;
					document.getElementById('type'+num).style.border = '1px red solid';
				}
				else {						
					document.getElementById('type'+num).style.border = '';
					
					if(!document.getElementById('title'+num).value || document.getElementById('title'+num).value.match(reg)) {
						document.getElementById('title'+num).style.border = '1px red solid';
						failure = 1;
					}
					else {
						document.getElementById('title'+num).style.border = '';
					}
					
					if(!document.getElementById('year'+num).value || document.getElementById('year'+num).value.match(reg)) {
						document.getElementById('year'+num).style.border = '1px red solid';
						failure = 1;
					}
					else {
						document.getElementById('year'+num).style.border = '';
					}
					
					if(!document.getElementById('FP'+num).value || document.getElementById('FP'+num).value.match(reg)) {
						document.getElementById('FP'+num).style.border = '1px red solid';
						failure = 1;
					}
					else {
						document.getElementById('FP'+num).style.border = '';
					}
					
					if (!document.getElementById('p'+num+'ref_author1').value && (!document.getElementById('p'+num+'AFN1').value || document.getElementById('p'+num+'AFN1').value.match(reg))) {
						document.getElementById('p'+num+'AFN1').style.border = '1px red solid';
						document.getElementById('p'+num+'ALN1').style.border = '1px red solid';
						failure = 1;
					}
					else {
						document.getElementById('p'+num+'AFN1').style.border = '';
						document.getElementById('p'+num+'ALN1').style.border = '';
					}
												
					// book
					if (pubtype == 1) {							
						if (!document.getElementById('editionID'+num).value && (!document.getElementById('edition'+num).value || document.getElementById('edition'+num).value.match(reg))) {
							document.getElementById('edition'+num).style.border = '1px red solid';
							failure = 1;
						}
						else {
							document.getElementById('edition'+num).style.border = '';
						}
					}
					// article
					else if (pubtype == 2) {
						if(!document.getElementById('vol'+num).value || document.getElementById('vol'+num).value.match(reg)) {
							document.getElementById('vol'+num).style.border = '1px red solid';
							failure = 1;
						}
						else {
							document.getElementById('vol'+num).style.border = '';
						}
													
						if (!document.getElementById('journalID'+num).value && (!document.getElementById('journal'+num).value || document.getElementById('journal'+num).value.match(reg))) {
							document.getElementById('journal'+num).style.border = '1px red solid';
							failure = 1;
						}
						else {
							document.getElementById('journal'+num).style.border = '';
						}
					}
					// thesis
					else if (pubtype == 3) {
						document.getElementById('edition'+num).style.border = '';
					}
					// in book
					else if (pubtype == 4) {							
						if (!document.getElementById('ref_book'+num).value) {
							document.getElementById('book'+num).style.border = '1px red solid';
							failure = 1;
						}
						else {
							document.getElementById('book'+num).style.border = '';
						}
					}
				}
			}
			else {
				failure = 1;
				document.getElementById('ref_pub'+num).style.border = '1px red solid';
				document.getElementById('pub'+num).style.border = '1px red solid';
			}	
		}
		return failure;
	}
				
	String.prototype.capitalize = function() {
		return this.charAt(0).toUpperCase() + this.slice(1);
	}";

our $maintitle = div({-style=>'width: 900px; margin: 1% auto 1% auto;'}, "\n".
		table({-border=>0},"\n".Tr("\n".
				td({-style=>'font-size: 20px; font-style: italic; font-weight: bold;'}, "$dblabel editor")."\n".
				td({-style=>'padding-left: 20px;'},"\n".a({-href=>"dbtnt.pl", -style=>'text-decoration: none; padding: 0;' },"\n".
					img({	-onMouseover=>"this.style.cursor='pointer'; document.getElementById('bulleM').innerHTML = 'Main menu';", 
						-onMouseOut=>"document.getElementById('bulleM').innerHTML = '';",
						-border=>0, 
						-src=>'/Editor/home.png', 
						-name=>"mM"}
					)."\n"
				)."\n").
				td({-id=>"bulleM", -style=>'width: 100px; color: darkgreen; vertical-align: middle;'}, '')."\n"
			)."\n")."\n"
		)."\n";

my ($group) = @{request_row("SELECT orthographe FROM noms WHERE ref_rang = (SELECT index from rangs WHERE ordre = (SELECT min(ordre) FROM noms AS n LEFT JOIN rangs AS r ON r.index = n.ref_rang where ordre > (SELECT ordre from rangs where en = 'suborder')));", $dbh)};

my $sexes;
make_hash ($dbh, "SELECT index, en FROM sexes;", \$sexes);
#my $conservation_status;
#make_hash ($dbh, "SELECT index, en FROM etats_conservation;", \$conservation_status);
#my $observ_types;
#make_hash ($dbh, "SELECT index, en FROM types_observation;", \$observ_types);
my $periods;
make_hash ($dbh, "SELECT index, en || coalesce(' [' || debut, '') || coalesce('-' || fin || ' Ma]', '') FROM periodes;", \$periods);
#my $frekens;
#make_hash ($dbh, "SELECT index, en FROM niveaux_frequence;", \$frekens);
my $typeTypes;
make_hash ($dbh, "SELECT index, en FROM types_type;", \$typeTypes);
#my $depotTypes;
#make_hash ($dbh, "SELECT index, en FROM types_depot;", \$depotTypes);
#my $agents;
#make_hash ($dbh, "SELECT a.index, a.en, t.en FROM agents_infectieux AS a LEFT JOIN types_agent_infectieux AS t ON t.index = a.ref_type_agent_infectieux;", \$agents);
#my $confirm;
#make_hash ($dbh, "SELECT index, en FROM niveaux_confirmation;", \$confirm);
#my $habitats;
#make_hash ($dbh, "SELECT index, en FROM habitats;", \$habitats);
#my $captures;
#make_hash ($dbh, "SELECT index, en FROM modes_capture;", \$captures);
my $associations;
make_hash ($dbh, "SELECT index, en FROM types_association;", \$associations);

my $authors = request_tab("SELECT nom, prenom FROM auteurs ORDER BY nom;",$dbh,2);

$dbh->disconnect;

# stylesheet
our $css = " 
	body {
		margin: 0 0 1% 0;
		color: #666666;
		font-size: 14px;
		font-family: Arial;
		background: #FDFDFD;
	}
	
	FIELDSET { background: #C2C2C2; border: 1px #C2C2C2 solid; }
	FIELDSET LEGEND { background: #C2C2C2; color: #444444; padding: 2px 10px 0 10px; }
	INPUT, TEXTAREA { border: 1px solid #BBBBBB; padding: 0 2px; color: navy; font-family: Arial; font-size: 14px; }
	SELECT { border: 1px solid #BBBBBB; padding-left: 5px; color: navy; }
	
	.fieldset1 { border: 1px #D0D0D0 solid; background: #D0D0D0; }
	.fieldset2 { border: 1px transparent solid; background: transparent; padding: 6px 6px 0px 6px; }
	.fieldset1 legend { background: #D0D0D0; color: #666666; }
	.fieldset2 legend { background: transparent; color: #666666; }
	.fieldset1 .fieldset2 .fieldset1 { background: transparent; border-top: 1px #888888 solid; border-left: 1px #888888 solid; border-right: 0px #888888 solid; border-bottom: 0px #888888 solid; padding: 6px 6px 0px 6px; }
	.fieldset1 .fieldset2 .fieldset1 legend { background: transparent; color: #666666;  padding-left: 6px; padding-top: 0px; }
	.fieldset1 .fieldset2 .fieldset1 .fieldset2 { background: transparent; border: 0px #888888 solid; padding: 6px 6px 0px 0px; }
	.fieldset1 .fieldset2 .fieldset1 .fieldset2 legend { background: transparent; color: #666666; padding-left: 2px; padding-top: 0px; }
	.padding0 { padding-left: 0px; }
	
	.fieldset1 .pagep { margin-left: 10px; }
	.fieldset1 .fieldset2 .pagep { margin-left: 2px; }
	
	.round {
		-moz-border-radius: 6px;
		-webkit-border-radius: 6px;
		border-radius: 6px;
	}
	
	.wcenter {
		width: 900px;
		min-width: 900px;
		margin: 0 auto;
	}
	
	.PopupStyle {
		/*background: #FFFFFF;
		color: #222222;
		font-family: Arial;
		font-size: 12pt;*/
	}

	.popupTitle {
		background: #FFFFFF;
		color: #222222;
		font-weight: bold;
		font-family: Arial;
	}
		
	.autocomplete {
	    background: #FDFDFD;
	    cursor: default;
	    overflow: auto;
	    overflow-x: hidden;
	    border: 1px solid #222222;
	    font-size: 14px;
	}
	
	.autocomplete_item {
	    padding: 1px;
	    padding-left: 5px;
	    color: navy;
	}
	
	.autocomplete_item_highlighted {
	    padding: 1px;
	    padding-left: 5px;
	    color: crimson;
	}
	
	.buttonSubmit { border: none; background: url('/Editor/submit.png') no-repeat top left; height: 22px; width: 78px; color: transparent; }
	.buttonClear { border: none; background: url('/Editor/clear.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonHome { border: none; background: url('/Editor/home.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonBack { border: none; background: url('/Editor/back.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonNew { border: none; background: url('/Editor/new.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonModify { border: none; background: url('/Editor/modify.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonInsert { border: none; background: url('/Editor/insert.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonUpdate { border: none; background: url('/Editor/update.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonDelete { border: none; background: url('/Editor/delete.png') no-repeat top left; height: 25px; width: 22px; color: transparent; }
";

# javascript allowing to add or remove hidden fields in a form
our $jscript_for_hidden = "
	
	function appendHidden (form, hidname, hidvalue) {
		Cfield = document.createElement('input');
		Cfield.setAttribute('type', 'hidden');
		Cfield.setAttribute('name', hidname);
		Cfield.setAttribute('value', hidvalue);
		form.appendChild(Cfield);
	}
	
	function removeHidden (form, hidden) {
		form.removeChild(hidden);
	}
";

##########################################################################################################################################################
#		HTML building functions				##########################################################################################
##########################################################################################################################################################

# Builds a string witch contains html header
############################################################################################
sub html_header {
	my ($hash) = @_;

	my $html = header({-Type=>'text/html', -Charset=>'UTF-8'});
	
	$html .= start_html(-title  =>$hash->{'titre'},
			-author =>'angel_anta@hotmail.com',
			-base   =>'true',
			-style  =>{'-code'=>$hash->{'css'}},
			-head   =>meta({-http_equiv => 'Content-Type', -content => 'text/html; charset=UTF-8'}),
			-script =>$hash->{'jscript'},
			-BGCOLOR =>$hash->{'bgcolor'},
			-background =>$hash->{'background'},
			-onLoad =>$hash->{'onLoad'},
			-VLINK  =>'blue',
			-ALINK  =>'blue');
	
	return ($html);
}

# Builds a string witch contains html footer
############################################################################################
sub html_footer {
	my $html = '';
	#$html .= h5({-align=>'LEFT'},time2str("%d/%m/%Y-%X\n", time)); # Prints date
	$html .= end_html();
	return ($html);
}

# html form post arguments persistance
############################################################################################
sub arg_persist {

	my $hiddens;
	foreach (param()) {
		if (param($_)) { $hiddens .= hidden($_, param($_)); }
	}
	return $hiddens;
}

##########################################################################################################################################################
#	cross tables definitions				##########################################################################################
##########################################################################################################################################################

sub make_hash {
	my ($dbc, $req, $xhash) = @_;
	my ($xkey, $xvalue, $precise);
	my 	$sth = $dbc->prepare($req);
		$sth->execute();
		$sth->bind_columns( \( $xkey, $xvalue, $precise ) );
	while ($sth->fetch()) {
		${$xhash}->{$xkey} = $xvalue;
		if ($precise) { ${$xhash}->{$xkey} .= " ($precise)" }
	}
}
	
our $cross_tables = {	'taxons_x_pays' => {	
							'title' => 'geographical distribution',
							'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Country / Region',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'tdwg',
										'addurl' => 'generique.pl?table=pays&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'publication_ori',
										'ref'   => 'ref_publication_ori',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page_ori',
										'length' => 12
									}, {
										'type' 	=> 'pub',
										'title' => 'Denouncing publication',
										'id'   => 'publication_maj',
										'ref'   => 'ref_publication_maj',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page_maj',
										'length' => 12
#									}, {
#										'type' => 'internal',
#										'title' => 'Regions / Localities',
#										'id'   => 'precision',
#										'length' => 80
									}
								],
						'obligatory' => ['pays', 'ref_pays'],
						'foreign_fields' => ['p.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays',
						'order' => 'ORDER BY p.en'
			},		
			
			'taxons_x_plantes' => {	
						'title' => 'host plants',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Host plant',
										'id' 	=> 'plante',
										'ref' 	=> 'ref_plante',
										'thesaurus' => 'plants',
										'addurl' => 'generique.pl?table=plantes&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'publication_ori',
										'ref'   => 'ref_publication_ori',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page_ori',
										'length' => 12
									}, {
										'type' 	=> 'pub',
										'title' => 'Denouncing publication',
										'id'   => 'publication_maj',
										'ref'   => 'ref_publication_maj',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page_maj',
										'length' => 12
									}, {
										'type' => 'select',
										'title' => 'Certainty',
										'id'   => 'certitude',
										'values' => ['-- certainty --', 'certain', 'uncertain']
									}
								],
						'obligatory' => ['plante', 'ref_plante'],
						'foreign_fields' => ['get_host_plant_name(ref_plante) AS fullname'],
						'foreign_joins' => '',
						'order' => 'ORDER BY fullname'
			},
			
			'taxons_x_images' => {	
						'title' => 'specimen images',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Image',
										'id' 	=> 'image',
										'ref' 	=> 'ref_image',
										'thesaurus' => 'images',
										'addurl' => 'generique.pl?table=images&new=1'
									}, {	
										'type' => 'internal',
										'title' => 'Image text',
										'id'   => 'commentaire'
									}
								],
						'obligatory' => ['image', 'ref_image']
			},
										
			'taxons_x_periodes' => {	
						'title' => 'geological periods',
						'definition' => [
									{	'type' 	=> 'select',
										'title' => 'Geological period',
										'id' 	=> 'ref_periode',
										#'values' => ['-- geological period --', sort { (split(/-/, (split(/\[/, $periods->{$a}))[1]))[0] <=> (split(/-/, (split(/\[/, $periods->{$b}))[1]))[0] } keys(%{$periods})],
										'values' => ['-- geological period --', sort { $periods->{$a} cmp $periods->{$b} } keys(%{$periods})],
										'labels' => $periods,
										'addurl' => 'generique.pl?table=periodes&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'publication_ori',
										'ref'   => 'ref_publication_ori',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page_ori',
										'length' => 12
									}, {
										'type' 	=> 'pub',
										'title' => 'Denouncing publication',
										'id'   => 'publication_maj',
										'ref'   => 'ref_publication_maj',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}
								],
						'obligatory' => ['ref_periode'],
						'foreign_fields' => ['p.en'],
						'foreign_joins' => 'LEFT JOIN periodes AS p ON p.index = tx.ref_periode',
						'order' => 'ORDER BY p.en'
			},
			
			'noms_x_types' => {
						'title' => 'type specimens',
						'definition' => [
									{	'type' 	=> 'select',
										'title' => 'Type',
										'id' 	=> 'ref_type',
										'values' => ['-- type --', sort {$typeTypes->{$a} cmp $typeTypes->{$b}} keys(%{$typeTypes})],
										'labels' => $typeTypes,
										'addurl' => 'generique.pl?table=types_type&new=1'
									}, {
										'type' 	=> 'select',
										'title' => 'Sex',
										'id' 	=> 'ref_sexe',
										'values' => ['-- sex --', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
										'labels' => $sexes,
										'addurl' => 'generique.pl?table=sexes&new=1'
									}, {
										'type' 	=> 'foreign',
										'title' => 'Deposit place',
										'id' 	=> 'lieux_depot',
										'ref' 	=> 'ref_lieux_depot',
										'thesaurus' => 'deposits',
										'addurl' => 'generique.pl?table=lieux_depot&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'pub',
										'ref'   => 'ref_pub',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page',
										'length' => 12
									#}, {
									#	'type' 	=> 'select',
									#	'title' => 'Deposit type',
									#	'id' 	=> 'ref_type_depot',
									#	'values' => ['', sort {$depotTypes->{$a} cmp $depotTypes->{$b}} keys(%{$depotTypes})],
									#	'labels' => $depotTypes,
									#	'addurl' => 'generique.pl?table=types_depot&new=1'
									#}, {
									#	'type' 	=> 'select',
									#	'title' => 'Conservation status',
									#	'id' 	=> 'ref_etat_conservation',
									#	'values' => ['', sort {$conservation_status->{$a} cmp $conservation_status->{$b}} keys(%{$conservation_status})],
									#	'labels' => $conservation_status,
									#	'addurl' => 'generique.pl?table=etats_conservation&new=1'
									}, {
										'type' => 'internal',
										'title' => 'number',
										'id'   => 'quantite',
										'length' => 12
									}, {
										'type' => 'internal',
										'title' => 'remarks',
										'id'   => 'remarques',
										'length' => 80,
										'style' => 'area'
									}
								],
						'obligatory' => ['lieux_depot', 'ref_lieux_depot', 'ref_type'],
						'foreign_fields' => ['ld.nom'],
						'foreign_joins' => 'LEFT JOIN lieux_depot AS ld ON ld.index = tx.ref_lieux_depot',
						'order' => 'ORDER BY ld.nom'
			},
			
			'taxons_x_vernaculaires' => {
						'title' => 'vernacular names',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Vernacular name',
										'id' 	=> 'vernaculaire',
										'ref' 	=> 'ref_vernaculaire',
										'thesaurus' => 'vernaculars',
										'addurl' => 'generique.pl?table=noms_vernaculaires&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'pub',
										'ref'   => 'ref_pub',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'Pages',
										'id'   => 'page',
										'length' => 12
									}
								],
						'obligatory' => ['vernaculaire', 'ref_vernaculaire'],
						'foreign_fields' => ['nv.nom', 'nv.transliteration'],
						'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_vernaculaire',
						'order' => 'ORDER BY nom, transliteration'
			},
			
			'noms_x_images' => {	
						'title' => 'type specimen images',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Image',
										'id' 	=> 'image',
										'ref' 	=> 'ref_image',
										'thesaurus' => 'images',
										'addurl' => 'generique.pl?table=images&new=1'
									}, {
										'type' => 'internal',
										'title' => 'Image text',
										'id'   => 'commentaire'
									}
								],
						'obligatory' => ['image', 'ref_image']
			},

			'taxons_x_taxons_associes' => {	
						'title' => 'associated taxa',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Associated taxon',
										'id' 	=> 'taxon_associe',
										'ref' 	=> 'ref_taxon_associe',
										'thesaurus' => 'taxons_associes',
										'addurl' => 'generique.pl?table=taxons_associes&new=1'
									}, {
										'type' 	=> 'select',
										'title' => 'Association type',
										'id' 	=> 'ref_type_association',
										'values' => ['-- association type --', sort {$associations->{$a} cmp $associations->{$b}} keys(%{$associations})],
										'labels' => $associations,
										'addurl' => 'generique.pl?table=types_association&new=1'
									}, {
										'type' 	=> 'pub',
										'title' => 'Original publication',
										'id'   => 'pub',
										'ref'   => 'ref_publication_ori',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'page',
										'id'   => 'page_ori',
										'length' => 12
									}, {
										'type' 	=> 'pub',
										'title' => 'Updating publication',
										'id'   => 'pub',
										'ref'   => 'ref_publication_maj',
										'thesaurus' => 'publications',
										'addurl' => 'dbtnt.pl?action=insert&type=pub'
									}, {
										'type' => 'internal',
										'title' => 'page',
										'id'   => 'page_maj',
										'length' => 12
									}, {
										'type' 	=> 'select',
										'title' => 'Sex',
										'id' 	=> 'ref_sexe',
										'values' => ['-- sex --', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
										'labels' => $sexes,
										'addurl' => 'generique.pl?table=sexes&new=1'
									}, {
										'type' => 'select',
										'title' => 'certainty',
										'id'   => 'certitude',
										'values' => ['-- certainty --', 'certain', 'uncertain']
									}
								],
						'obligatory' => ['taxon_associe', 'ref_taxon_associe'],
						#'foreign_fields' => ["coalesce((get_taxon_associe(ref_taxon_associe)).nom,'') || coalesce(' ' || (get_taxon_associe(ref_taxon_associe)).autorite,'') AS taxon_associe"],
						'foreign_fields' => ['ta.nom', 'ta.autorite'],
						'foreign_joins' => 'LEFT JOIN taxons_associes AS ta ON ta.index = tx.ref_taxon_associe',
						'order' => ''
			}
};

##########################################################################################################################################################
#	single tables definitions				##########################################################################################
##########################################################################################################################################################

our $single_tables = {
	'revues' => {
		'title' => 'Journals',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 120
					}
				],
		'obligatory' => {'nom'=>1}
	},
	'auteurs' => {	
		'title' => 'Authors',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80
					}, {
						'type' => 'internal',
						'title' => 'Initials',
						'id'   => 'prenom',
						'length' => 80
					},
				],
		'obligatory' => {'nom'=>1, 'prenom'=>1}
	},
	'editions' => {	
		'title' => 'Editions',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80
					}, {	
						'type' 	=> 'foreign',
						'title' => 'City',
						'id' 	=> 'ville',
						'ref' 	=> 'ref_ville',
						'thesaurus' => 'cities',
						'addurl' => 'generique.pl?table=villes&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'

					}
				],
		'obligatory' => {'nom'=>1}
	},
	'noms_vernaculaires' => {	
		'title' => 'Vernacular names',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80
					}, {
						'type' => 'internal',
						'title' => 'Transliteration',
						'id'   => 'transliteration',
						'length' => 80
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Language',
						'id' 	=> 'langage',
						'ref' 	=> 'ref_langage',
						'thesaurus' => 'languages',
						'addurl' => 'generique.pl?table=langages&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Country',
						'id' 	=> 'pays',
						'ref' 	=> 'ref_pays',
						'thesaurus' => 'tdwg',
						'addurl' => 'generique.pl?table=pays&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}
				],
		'obligatory' => {'nom'=>1}
	},
#	'agents_infectieux' => {	
#		'title' => 'Infectious agents',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}, {	
#						'type' 	=> 'foreign',
#						'title' => 'Infectious agent type',
#						'id' 	=> 'type_agent_infectieux',
#						'ref' 	=> 'ref_type_agent_infectieux',
#						'thesaurus' => 'types_agent_infectieux',
#						'addurl' => 'generique.pl?table=types_agent_infectieux&new=1',
#						'length' => 80,
#						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'

#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1, 'ref_type_agent_infectieux'=>1}
#	},
	'villes' => {	
		'title' => 'Cities',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Country',
						'id' 	=> 'pays',
						'ref' 	=> 'ref_pays',
						'thesaurus' => 'tdwg',
						'addurl' => 'generique.pl?table=pays&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}
				],
		'obligatory' => {'nom'=>1, 'ref_pays'=>1}
	},
	'pays' => {	
		'title' => 'Countries',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'TDWG level',
						'id'   => 'tdwg_level',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'TDWG code',
						'id'   => 'tdwg',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'TDWG parent',
						'id'   => 'parent',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'ISO2',
						'id'   => 'iso',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'ISO3',
						'id'   => 'iso3',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1, 'tdwg_level'=>1, 'tdwg'=>1, 'parent'=>1}
	},
	'langages' => {	
		'title' => 'Languages',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Language',
						'id'   => 'langage',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'ISO3',
						'id'   => 'iso',
						'length' => 80
					}
				],
		'obligatory' => {'langage'=>1, 'iso'=>1}
	},
	
	'lieux_depot' => {	
		'title' => 'Repository sites',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Country',
						'id' 	=> 'pays',
						'ref' 	=> 'ref_pays',
						'thesaurus' => 'tdwg',
						'addurl' => 'generique.pl?table=pays&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}
				],
		'obligatory' => {'nom'=>1}
	},

#	'localites' => {
#		'title' => 'Localities',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'Name',
#						'id'   => 'nom',
#						'length' => 80
#					}, {	
#						'type' 	=> 'foreign',
#						'title' => 'Region',
#						'id' 	=> 'region',
#						'ref' 	=> 'ref_region',
#						'thesaurus' => 'regions',
#						'addurl' => 'generique.pl?table=regions&new=1',
#						'length' => 80,
#						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
#					}
#				],
#		'obligatory' => {'nom'=>1}
#	},
#	'regions' => {
#		'title' => 'Regions',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'Name',
#						'id'   => 'nom',
#						'length' => 80
#					}, {	
#						'type' 	=> 'foreign',
#						'title' => 'Country',
#						'id' 	=> 'pays',
#						'ref' 	=> 'ref_pays',
#						'thesaurus' => 'tdwg',
#						'addurl' => 'generique.pl?table=pays&new=1',
#						'length' => 80,
#						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
#					}
#				],
#		'obligatory' => {'nom'=>1, 'ref_pays'=>1}
#	},
	'statuts' => {
		'title' => 'Taxonomic statuses',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
	},
#	'habitats' => {
#		'title' => 'Habitats',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
	'periodes' => {
		'title' => 'Geological periods',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Level',
						'id' 	=> 'level',
						'ref' 	=> 'niveau',
						'thesaurus' => 'eras',
						'addurl' => 'generique.pl?table=niveaux_geologiques&new=1',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Parent',
						'id' 	=> 'higher',
						'ref' 	=> 'parent',
						'thesaurus' => 'periods',
						'addurl' => '',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' => 'internal',
						'title' => 'Start',
						'id'   => 'debut',
						'length' => 12,
						'message' => ' Ma'
					}, {	
						'type' => 'internal',
						'title' => 'End',
						'id'   => 'fin',
						'length' => 12,
						'message' => ' Ma'
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1, level=>1}
	},
	
	'niveaux_geologiques' => {
		'title' => 'Geological levels',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
	},

	'sexes' => {
		'title' => 'Sex',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
	},

#	'modes_capture' => {
#		'title' => 'Capture modes',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'etats_conservation' => {
#		'title' => 'Conservation states',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'niveaux_confirmation' => {
#		'title' => 'Confirmation levels',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'niveaux_frequence' => {
#		'title' => 'Frequency levels',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'types_agent_infectieux' => {
#		'title' => 'Infectious agent types',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'types_depot' => {
#		'title' => 'Repository types',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},
#	'types_observation' => {
#		'title' => 'Observation types',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'English',
#						'id'   => 'en',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'French',
#						'id'   => 'fr',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Spanish',
#						'id'   => 'es',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'German',
#						'id'   => 'de',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
#	},

	'types_type' => {
		'title' => 'Type types',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
	},

	'types_association' => {
		'title' => 'Association types',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'English',
						'id'   => 'en',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'French',
						'id'   => 'fr',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Spanish',
						'id'   => 'es',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'German',
						'id'   => 'de',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Chinese',
						'id'   => 'zh',
						'length' => 80
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1, 'zh'=>1}
	},
	'images' => {
		'title' => 'Images',
		'definition' => [	
					{	'type' => 'internal',
						'title' => 'Image URL',
						'id'   => 'url',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Thumbnail URL',
						'id'   => 'icone_url',
						'length' => 80
					}
				],
		'obligatory' => {'url'=>1, 'icone_url'=>1}
	},
#	'documents' => {
#		'title' => 'Documents',
#		'definition' => [	{	'type' => 'internal',
#						'title' => 'Title',
#						'id'   => 'titre',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'document URL',
#						'id'   => 'url',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'document type',
#						'id'   => 'type',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'titre'=>1, 'url'=>1, 'type'=>1}
#	},
	'taxons_associes' => {
		'title' => "Taxa associated to $group",
		'definition' => [	
					{	
						'type' 	=> 'select',
						'title' => 'Level',
						'id' 	=> 'ref_rang',
						'values' => ['', 10, 2, 3, 4],
						'labels' => {10 => 'order', 2 => 'family', 3 => 'genus', 4 => 'species'},
						'onload' => "	if (document.getElementById('ref_rang').value == '' || document.getElementById('ref_rang').value == 10) { 
									document.Form.ref_parent.value = 'NULL';
									document.getElementById('parent').value = '-- search --';
									document.getElementById('parent').disabled = true;
									document.getElementById('parent').style.background = '#EEEEEE';
									document.getElementById('parent').style.borderColor = '#BBBBBB';
									document.getElementById('parent').style.color = '#BBBBBB';
									document.getElementById('parent_row').style.color = '#BBBBBB';
									document.getElementById('parent_mark').style.color = '#BBBBBB';
								} 
								else {
									document.getElementById('parent').disabled = false;
									document.getElementById('parent').style.background = '#ffffff';
									document.getElementById('parent').style.borderColor = '#999';
									document.getElementById('parent').style.color = '#222222';
									document.getElementById('parent_row').style.color = '#222222';
									document.getElementById('parent_mark').style.color = '#DC143C';
								}\n",
						'onchange' => "	document.Form.ref_parent.value = '';
								document.getElementById('parent').value = '-- search --';",
						'onchangeReload' => 1
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Parent name',
						'id' 	=> 'parent',
						'ref' 	=> 'ref_parent',
						'thesaurus' => 'higher_taxons_associes',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80,
						'onload' => "	if (document.Form.ref_rang.value != 4 && document.Form.ref_rang.value != '') { document.Form.nom.value = document.Form.nom.value.charAt(0).toUpperCase() + document.Form.nom.value.slice(1); }
								else { document.Form.nom.value = document.Form.nom.value.toLowerCase(); }\n",
						'onchange' => "	if (document.Form.ref_rang.value != 4 && document.Form.ref_rang.value != '') { document.Form.nom.value = document.Form.nom.value.charAt(0).toUpperCase() + document.Form.nom.value.slice(1); }
								else { document.Form.nom.value = document.Form.nom.value.toLowerCase(); }\n"
					}, {	
						'type' => 'internal',
						'title' => 'Authority',
						'id'   => 'autorite',
						'length' => 80
					}, {
						'type' 	=> 'select',
						'title' => 'Status',
						'id' 	=> 'statut',
						'values' => ['valid', 'not valid', 'unknown'],
						'onload' => "	if (document.getElementById('statut').value == 'valid' || document.getElementById('statut').value == 'unknown') { 
									document.Form.ref_valide.value = '';
									document.getElementById('valide').value = '-- search --';
									document.getElementById('valide').disabled = true; 
									document.getElementById('valide').style.background = '#EEEEEE'; 
									document.getElementById('valide').style.borderColor = '#BBBBBB'; 
									document.getElementById('valide').style.color = '#BBBBBB'; 
									document.getElementById('valide_row').style.color = '#BBBBBB';
								} 
								else { 
									document.getElementById('valide').disabled = false;
									document.getElementById('valide').style.background = '#ffffff';
									document.getElementById('valide').style.borderColor = '#999';
									document.getElementById('valide').style.color = '#222222';
									document.getElementById('valide_row').style.color = '#222222';
								}\n",
						'onchange' => "	if (document.getElementById('statut').value == 'valid' || document.getElementById('statut').value == 'unknown') { 
									document.Form.ref_valide.value = '';
									document.getElementById('valide').value = '-- search --';
									document.getElementById('valide').disabled = true; 
									document.getElementById('valide').style.background = '#EEEEEE'; 
									document.getElementById('valide').style.borderColor = '#BBBBBB'; 
									document.getElementById('valide').style.color = '#BBBBBB'; 
									document.getElementById('valide_row').style.color = '#BBBBBB';
								} 
								else { 
									document.getElementById('valide').disabled = false;
									document.getElementById('valide').style.background = '#ffffff';
									document.getElementById('valide').style.borderColor = '#999';
									document.getElementById('valide').style.color = '#222222';
									document.getElementById('valide_row').style.color = '#222222';
								}\n"
					}, {	
						'type' 	=> 'foreign',
						'title' => "Valid name",
						'id' 	=> 'valide',
						'ref' 	=> 'ref_valide',
						'thesaurus' => 'taxons_associes',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}
				],
		'obligatory' => {'ref_rang'=>1, 'ref_parent'=>1, 'nom'=>1, 'statut'=>1}
	},
	'plantes' => {
		'title' => "Host plants",
		'definition' => [	
					{	
						'type' 	=> 'select',
						'title' => 'Level',
						'id' 	=> 'ref_rang',
						'values' => ['', 10, 2, 3, 4],
						'labels' => {10 => 'order', 2 => 'family', 3 => 'genus', 4 => 'species'},
						'onload' => "	if (document.getElementById('ref_rang').value == '-- level --' || document.getElementById('ref_rang').value == 10) { 
									document.Form.ref_parent.value = 'NULL';
									document.getElementById('parent').value = '-- search --';
									document.getElementById('parent').disabled = true;
									document.getElementById('parent').style.background = '#EEEEEE';
									document.getElementById('parent').style.borderColor = '#BBBBBB';
									document.getElementById('parent').style.color = '#BBBBBB';
									document.getElementById('parent_row').style.color = '#BBBBBB';
									document.getElementById('parent_mark').style.color = '#BBBBBB';
								} 
								else {
									document.getElementById('parent').disabled = false;
									document.getElementById('parent').style.background = document.getElementById('nom').style.background;
									document.getElementById('parent').style.borderColor = document.getElementById('nom').style.borderColor;
									document.getElementById('parent').style.color = document.getElementById('nom').style.color;
									document.getElementById('parent_row').style.color = document.getElementById('nom_row').style.color;
									document.getElementById('parent_mark').style.color = '#DC143C';
								}\n",
						'onchange' => "	document.Form.ref_parent.value = '';
								document.getElementById('parent').value = '-- search --';",
						'onchangeReload' => 1
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Parent name',
						'id' 	=> 'parent',
						'ref' 	=> 'ref_parent',
						'thesaurus' => 'higherPlants',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' => 'internal',
						'title' => 'Name',
						'id'   => 'nom',
						'length' => 80,
						'onload' => "	if (document.Form.ref_rang.value != 4 && document.Form.ref_rang.value != '-- level --') { document.Form.nom.value = document.Form.nom.value.charAt(0).toUpperCase() + document.Form.nom.value.slice(1); }
								else { document.Form.nom.value = document.Form.nom.value.toLowerCase(); }\n",
						'onchange' => "	if (document.Form.ref_rang.value != 4 && document.Form.ref_rang.value != '-- level --') { document.Form.nom.value = document.Form.nom.value.charAt(0).toUpperCase() + document.Form.nom.value.slice(1); }
								else { document.Form.nom.value = document.Form.nom.value.toLowerCase(); }\n"
					}, {	
						'type' => 'internal',
						'title' => 'Authority',
						'id'   => 'autorite',
						'length' => 80
					}, {
						'type' 	=> 'select',
						'title' => 'Status',
						'id' 	=> 'statut',
						'values' => ['valid', 'not valid', 'unknown'],
						'onload' => "	if (document.getElementById('statut').value == 'valid' || document.getElementById('statut').value == 'unknown') { 
									document.Form.ref_valide.value = '';
									document.getElementById('valide').value = '-- search --';
									document.getElementById('valide').disabled = true; 
									document.getElementById('valide').style.background = '#EEEEEE'; 
									document.getElementById('valide').style.borderColor = '#BBBBBB'; 
									document.getElementById('valide').style.color = '#BBBBBB'; 
									document.getElementById('valide_row').style.color = '#BBBBBB';
								} 
								else { 
									document.getElementById('valide').disabled = false;
									document.getElementById('valide').style.background = document.getElementById('statut').style.background;
									document.getElementById('valide').style.borderColor = document.getElementById('statut').style.borderColor;
									document.getElementById('valide').style.color = document.getElementById('statut').style.color;
									document.getElementById('valide_row').style.color = document.getElementById('statut_row').style.color;
								}\n",
						'onchange' => "	if (document.getElementById('statut').value == 'valid' || document.getElementById('statut').value == 'unknown') { 
									document.Form.ref_valide.value = '';
									document.getElementById('valide').value = '-- search --';
									document.getElementById('valide').disabled = true; 
									document.getElementById('valide').style.background = '#EEEEEE'; 
									document.getElementById('valide').style.borderColor = '#BBBBBB'; 
									document.getElementById('valide').style.color = '#BBBBBB'; 
									document.getElementById('valide_row').style.color = '#BBBBBB';
								} 
								else { 
									document.getElementById('valide').disabled = false;
									document.getElementById('valide').style.background = document.getElementById('statut').style.background;
									document.getElementById('valide').style.borderColor = document.getElementById('statut').style.borderColor;
									document.getElementById('valide').style.color = document.getElementById('statut').style.color;
									document.getElementById('valide_row').style.color = document.getElementById('statut_row').style.color;
								}\n"
					}, {	
						'type' 	=> 'foreign',
						'title' => "Valid name",
						'id' 	=> 'valide',
						'ref' 	=> 'ref_valide',
						'thesaurus' => 'plants',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}
				],
		'obligatory' => {'ref_rang'=>1, 'ref_parent'=>1, 'nom'=>1, 'statut'=>1}
	}
};

##########################################################################################################################################################
#	functions needed for generique.pl				##################################################################################
##########################################################################################################################################################

sub get_single_table_parameters { 
	
	my ($table, $title, $singular, $label, $join, $order, $champs) = @_;
	
	if ($table eq 'revues') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Journal';
		${$label} = 'x.nom';
		${$order} = 'ORDER BY upper(reencodage(x.nom))';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'auteurs') {
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Author';
		${$label} = "coalesce(x.nom || ' ', '') || coalesce(x.prenom, '')";
		${$order} = 'ORDER BY upper(reencodage(x.nom)), x.prenom';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'editions') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Edition';
		${$label} = "coalesce(x.nom, '') || coalesce(', ' || v.nom, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN villes AS v ON v.index = x.ref_ville LEFT JOIN pays AS p ON p.index = v.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), upper(reencodage(v.nom)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'noms_vernaculaires') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Vernacular name';
		${$label} = "coalesce(x.nom, '') || coalesce(' \"' || x.transliteration || '\"', '') || coalesce(' in ' || l.langage, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN langages AS l ON l.index = x.ref_langage LEFT JOIN pays AS p ON p.index = x.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), upper(reencodage(x.transliteration)), upper(reencodage(l.langage)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'agents_infectieux') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Infectious agents';
		${$label} = "coalesce(x.en, '') || coalesce(' (' || t.en || ')', '')";
		${$join} = 'LEFT JOIN types_agent_infectieux AS t ON t.index = x.ref_type_agent_infectieux';
		${$order} = 'ORDER BY x.en, t.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'villes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'City';
		${$label} = "coalesce(x.nom, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN pays AS p ON p.index = x.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'pays') {
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Country';
		${$label} = "coalesce(x.en, '') || coalesce(' (' || 'level ' || x.tdwg_level || ')', '')";
		${$join} = 'WHERE x.tdwg_level is not null';
		${$order} = 'ORDER BY x.en, x.tdwg_level DESC';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'langages') {
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Language';
		${$label} = "x.langage";
		${$order} = 'ORDER BY upper(reencodage(x.langage))';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'lieux_depot') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Repository site';
		${$label} = "coalesce(x.nom, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN pays AS p ON p.index = x.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'localites') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Locality';
		${$label} = "coalesce(x.nom, '') || coalesce(', ' || r.nom, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN regions AS r ON r.index = x.ref_region LEFT JOIN pays AS p ON p.index = r.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), upper(reencodage(r.nom)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'regions') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Region';
		${$label} = "coalesce(x.nom, '') || coalesce(' (' || p.en || ')', '')";
		${$join} = 'LEFT JOIN pays AS p ON p.index = x.ref_pays';
		${$order} = 'ORDER BY upper(reencodage(x.nom)), p.en';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'statuts') {
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Status';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'habitats') {
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Habitat';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'periodes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Geological period';
		${$label} = "x.en || coalesce(' [' || l.en || ']', '') || coalesce(' ' || x.debut || ' Ma', '') || coalesce(' - ' || x.fin || ' Ma', '')";
		${$join} = 'LEFT JOIN niveaux_geologiques AS l ON l.index = x.niveau';
		${$order} = 'ORDER BY x.niveau, x.debut';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'sexes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Sex';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'modes_capture') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Capture mode';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'etats_conservation') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Conservation state';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'niveaux_confirmation') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Confirmation level';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'niveaux_frequence') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Frequency level';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'niveaux_geologiques') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Geological level';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'types_agent_infectieux') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Infectious agent type';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'types_depot') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Repository type';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'types_observation') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Observation type';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'types_type') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Type type';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'types_association') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Association type';
		${$label} = 'x.en';
		${$order} = 'ORDER BY x.en';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'images') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Image';
		${$label} = "'<TABLE><TR><TD>' || x.url || '</TD><TD><IMG WIDTH=80 STYLE=\"margin-left: 20px;\" SRC=\"' || x.icone_url || '\"></TD></TR></TABLE>'";
		${$order} =  'ORDER BY x.url';
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'documents') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Document';
		${$label} = "x.titre || ' ' || x.url || ' ' || x.type";
		${$order} = 'ORDER BY upper(reencodage(x.titre)), x.url, x.type';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'taxons_associes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = "Taxon associated to $group";
		${$label} = "coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') || coalesce('&nbsp;  <span style=\"color: grey;\">' || (get_taxon_associe(x.index)).famille || '</span>','') || coalesce('<span style=\"color: grey;\"> (' || (get_taxon_associe(x.index)).ordre || ')</span>','')";
		${$order} =  'ORDER BY (get_taxon_associe(x.index)).nom';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'plantes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Host plant';
		${$label} = "	CASE WHEN (SELECT ordre FROM rangs WHERE index = x.ref_rang) > (SELECT ordre FROM rangs WHERE index = 2) THEN 
					coalesce((get_host_plant(x.index)).nom, '') || 
					coalesce(' ' || (get_host_plant(x.index)).autorite, '') || 
					coalesce(' <span style=\"color: grey;\">' || (get_host_plant(x.index)).famille || '</span>', '') || 
					coalesce(' <span style=\"color: grey;\">(' || (get_host_plant(x.index)).ordre || ')</span>', '')
				ELSE
					x.nom || coalesce(' ' || x.autorite, '') 
				END";
		${$order} =  'ORDER BY 2';
		${$champs} = $single_tables->{$table};
	}
}

sub get_single_table_thesaurus {
	
	my ($dbc, $table, $retro, $onload, $values) = @_;

	if ($table eq 'editions') { 
		make_thesaurus("SELECT v.index, coalesce(v.nom, '') || coalesce(' (' || p.en || ')', '') FROM villes AS v LEFT JOIN pays AS p ON p.index = v.ref_pays ORDER BY v.nom, p.en;", 'cities', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'noms_vernaculaires') { 
		make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4'))) ORDER BY en;", 'tdwg', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT l.index, l.langage FROM langages AS l ORDER BY l.langage;", 'languages', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'agents_infectieux') { 
		make_thesaurus("SELECT index, en FROM types_agent_infectieux ORDER BY en;", 'types_agent_infectieux', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'villes') { 
		make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4')));", 'tdwg', '$intitule = "$row->[1] [$row->[3]]";', $retro, $onload, $dbc);
	}
	elsif ($table eq 'regions') { 
		make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4')));", 'tdwg', '$intitule = "$row->[1] [$row->[3]]";', $retro, $onload, $dbc);
	}
	elsif ($table eq 'lieux_depot') { 
		make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4')));", 'tdwg', '$intitule = "$row->[1] [$row->[3]]";', $retro, $onload, $dbc);
	}
	elsif ($table eq 'localites') { 
		make_thesaurus("SELECT r.index, coalesce(r.nom, '') || coalesce(' (' || p.en || ')', '') FROM regions AS r LEFT JOIN pays AS p ON p.index = r.ref_pays ORDER BY r.nom, p.en;", 'regions', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'taxons_associes') { 
		my $rang = param('ref_rang') || $values->[0][0] || 10;
		make_thesaurus("SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') FROM taxons_associes AS x LEFT JOIN rangs AS r ON r.index = x.ref_rang WHERE r.ordre < (SELECT ordre FROM rangs WHERE index = $rang) ORDER BY (get_taxon_associe(x.index)).nom;", 'higher_taxons_associes', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') FROM taxons_associes AS x ORDER BY (get_taxon_associe(x.index)).nom;", 'taxons_associes', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}	
	elsif ($table eq 'plantes') { 
		my $rang = param('ref_rang') || $values->[0][0] || 10;
		make_thesaurus("SELECT x.index, coalesce((get_host_plant(x.index)).nom,'') || coalesce(' ' || (get_host_plant(x.index)).autorite,'') FROM plantes AS x LEFT JOIN rangs AS r ON r.index = x.ref_rang WHERE r.ordre < (SELECT ordre FROM rangs WHERE index = $rang) ORDER BY (get_host_plant(x.index)).nom;", 'higherPlants', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT x.index, coalesce((get_host_plant(x.index)).nom,'') || coalesce(' ' || (get_host_plant(x.index)).autorite,'') FROM plantes AS x ORDER BY (get_host_plant(x.index)).nom;", 'plants', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}	
	elsif ($table eq 'periodes') { 
		make_thesaurus("SELECT p.index, p.en FROM periodes AS p ORDER BY p.en;", 'periods', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT n.index, n.en FROM niveaux_geologiques AS n ORDER BY n.en;", 'eras', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
}

sub make_single_table_fields {
	
	my($table, $champs, $retro_hash, $values, $hiddens, $autofields, $tablerows, $dependencies, $hidrefs, $onSubmit, $reload, $etrangere) = @_;
	
	my $iter = 0;
	foreach (@{$champs->{'definition'}}) {
		
		if ($_->{'onchangeReload'}) { $_->{'onchange'} .= "document.Form.action='".url()."?table=$table$reload';\ndocument.Form.submit();\n"; }
		
		my $default;
		if ($_->{'type'} eq 'foreign') {
			${$etrangere} = 1;
			my $id = $_->{'id'};
			my $ref = $_->{'ref'};
			unless (param($ref)) {
				$default = ${$retro_hash}->{$_->{'thesaurus'}.${$values}->[0][$iter]} || '-- search --';
				push(@{${$hiddens}}, [$ref, ${$values}->[0][$iter]]);
				Delete($ref);
			}
			else {
				$default = param($id);
				push(@{${$hiddens}}, [$ref, param($ref)]);
				Delete($ref);
			}
			
			my $field = textfield(
				-name=> "$id", 
				-size=>$_->{'length'} || 70, 
				-value => $default, 
				-id => "$id",
				-autocomplete=>'off',
				-onFocus => "	if(this.value == '-- search --') { this.value = ''; } AutoComplete_HideDropdown(this.getAttribute('id')); AutoComplete_ShowDropdown(this.getAttribute('id'));",
				-onBlur => "	if(!this.value) { this.value = '-- search --'; document.Form.$ref.value = ''; } ",
				-onChange=>"	if(!this.value || this.value == '-- search --') { document.Form.$ref.value = ''; }
						else if (this.value && !AutoComplete_Testing(this.getAttribute('id'))) { this.value = '$default'; }\n
						" . $_->{'onchange'}
			);
			
			my $label = lc($_->{'title'});
			$label =~ s/ /&nbsp;/g;	
			my ($mark, $message);				
			if (exists($champs->{'obligatory'}{$ref}) or exists($champs->{'obligatory'}{$_->{'id'}})) { $mark = span({-style=>'color: crimson;', -id=>$_->{'id'}.'_mark'}, '*'); }
			if ($_->{'message'}) { $message = $_->{'message'} }
			my $more;
			if ($_->{'addurl'}) {
				$more = '&nbsp; <NOBR> ' . a({-href=>$_->{'addurl'}, 
					     -target=>'_blank', 
					     -style=>'text-decoration: none; font-size: 12px;', 
					     -onClick=>"document.getElementById('redalert').style.display = 'inline';"
					  },
					  "add " . ucfirst($label) ). '</NOBR>';
			}
			
			${$autofields} .= "AutoComplete_Create('$id', " . $_->{'thesaurus'} . ", 20, '" . $_->{'ref'} . "', 'Form');\n";
			
			${$tablerows} .= Tr({-id=>$_->{'id'}.'_row'}, td(span({-style=>'margin-right: 8px;'}, $_->{'title'} . $mark)), td($field . $message .  $more) );
			
			
		}
		elsif ($_->{'type'} eq 'select') {
			
			unless (param($_->{'id'})) {
				$default = ${$values}->[0][$iter];
			}
			else {
				$default = param($_->{'id'});
			}
			my $label = lc($_->{'title'});
			$label =~ s/ /&nbsp;/g;
			my ($mark, $message);				
			if (exists($champs->{'obligatory'}{$_->{'id'}}) or exists($champs->{'obligatory'}{$_->{'ref'}})) { $mark = span({-style=>'color: crimson;'}, '*') }
			if ($_->{'message'}) { $message = $_->{'message'} }
			my $more;
			if ($_->{'addurl'}) {
				$more = '&nbsp; <NOBR> ' . a({-href=>$_->{'addurl'}, 
				     -target=>'_blank', 
				     -style=>'text-decoration: none; font-size: 12px;', 
				     -onClick=>"document.getElementById('redalert').style.display = 'inline';"
				  },
				  "Add a " . $label ) . '</NOBR>';
			}
			
			${$tablerows} .= Tr({-id=>$_->{'id'}.'_row'}, td(span({-style=>'margin-right: 10px;'}, $_->{'title'} . $mark)), td(popup_menu(-style=>'padding: 0;', -name=>$_->{'id'}, -id=>$_->{'id'}, -default=>$default, values=>$_->{'values'}, -labels=>$_->{'labels'}, -onChange=>$_->{'onchange'}, -onKeyDown=>"if(event.keyCode == 13) { event.returnValue = false; event.preventDefault(); }") . $message . $more) );
		}
		elsif ($_->{'type'} eq 'internal') {
			
			unless (param($_->{'id'})) {
				$default = ${$values}->[0][$iter];
			}
			else {
				$default = param($_->{'id'});
			}
			my ($mark, $message);
			if (exists($champs->{'obligatory'}{$_->{'id'}}) or exists($champs->{'obligatory'}{$_->{'ref'}})) { $mark = span({-style=>'color: crimson;'}, '*') }
			if ($_->{'message'}) { $message = $_->{'message'} }
			my $l = $_->{'length'} || 70;
			
			${$tablerows} .= Tr({-id=>$_->{'id'}.'_row'}, td(span({-style=>'margin-right: 10px;'}, $_->{'title'} . $mark)), td({-colspan=>1}, 
					textfield(-name=>$_->{'id'}, -id=>$_->{'id'}, -default=>$default, -size=>$l, -onChange=>$_->{'onchange'}, -autocomplete=>'off', -onKeyDown=>"if(event.keyCode == 13) { event.returnValue = false; event.preventDefault(); }") . $message) );
		}
		Delete($_->{'id'});
		if ($_->{'onload'}) { ${$dependencies} .= $_->{'onload'} }
		$iter++;
	}
			
	foreach (@{${$hiddens}}) {
		${$hidrefs} .= hidden(-name=>"$_->[0]", -value=>"$_->[1]");
	}
	
	${$onSubmit} = 'if ('.join(' && ', map("document.Form.".$_.".value != ''", keys(%{$champs->{'obligatory'}}))).") { } else { alert('Please fill all required fileds'); }";
}

# make a thesaurus in case of table foreign key
sub make_thesaurus {

	my ($req, $hash, $format, $retro_hash, $onload, $dbc) = @_;
	my ($res, $hashlabels);
		
	$res = request_tab($req, $dbc, 2);
	
	$hashlabels = ();
	foreach my $row (@{$res}) {
		my $intitule;
		eval($format);
		${$retro_hash}->{$hash.$row->[0]} = $intitule;
		$intitule =~ s/'/\\'/g;
		$intitule =~ s/"/\\"/g;
		$intitule =~ s/\[/\\[/g;
		$intitule =~ s/\]/\\]/g;
		$intitule =~ s/  / /g;
		$hashlabels .= $hash.'["'.$intitule.'"] = "' . $row->[0] . '";';
	}
	${$onload} .= "var $hash = {}; \n $hashlabels";
}

##########################################################################################################################################################
#	Data needed to build publications references		##########################################################################################
##########################################################################################################################################################

# Get all necessary informations of a publication from his index to put it in a hash.
sub get_pub_params {

	my ($dbc, $index) = @_;
		
	# Get the type of the publication
	my $typereq = "SELECT type.en FROM types_publication as type LEFT JOIN publications as p on (p.ref_type_publication = type.index) WHERE p.index = $index;";
			
	my ($pub_type) = @{request_tab($typereq,$dbc,1)};
				
	my $pubhash;
	
	# Get all the information concerning a publication according to his type
	if ( $pub_type eq "Article" ) {
			
		my $pubreq = "SELECT 	p.index,
					tp.en as type,
					p.titre,
					p.annee,
					p.fascicule,
					p.page_debut,
					p.page_fin,
					p.nombre_auteurs,
					r.index as revueid,
					r.nom as revue,
					p.volume

					
			FROM publications as p
			LEFT JOIN revues AS r ON r.index = p.ref_revue
			LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
			WHERE p.index = $index;";
					
		$pubhash = request_hash($pubreq,$dbc,"index");
			
		
	}
	
	elsif ( $pub_type eq "Book" ) {
	
		my $pubreq = "SELECT 	p.index,
					tp.en as type,
					p.titre,
					p.annee,
					e.index as edid,
					e.nom as edition,
					v.nom as ville,
					pays.en as pays,
					p.page_debut,
					p.page_fin,
					p.nombre_auteurs,
					p.volume

					
			FROM publications as p
			LEFT JOIN editions AS e ON e.index = p.ref_edition
			LEFT JOIN villes as v ON v.index = e.ref_ville
			LEFT JOIN pays ON pays.index = v.ref_pays 
			LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
			WHERE p.index = $index;";
					
		$pubhash = request_hash($pubreq,$dbc,"index");
		
	}
	
	elsif ( $pub_type eq "In book" ) {
	
		my $pubreq = "SELECT 	p.index,
					tp.en as type,
					p.titre,
					p.annee,
					p.page_debut,
					p.page_fin,
					p.nombre_auteurs,
					b.index as indexlivre,
					b.titre as titrelivre,
					b.annee as anneelivre,
					b.volume as volumelivre,
					e.nom as edition,
					v.nom as ville,
					pays.en as pays,
					b.nombre_auteurs as nbauteurslivre
					
			FROM publications as p
			LEFT JOIN publications as b ON (b.index = p.ref_publication_livre)
			LEFT JOIN editions AS e ON e.index = b.ref_edition
			LEFT JOIN villes as v ON v.index = e.ref_ville
			LEFT JOIN pays ON pays.index = v.ref_pays 
			LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
			WHERE p.index = $index;";
					
		$pubhash = request_hash($pubreq,$dbc,"index");
		
		my $indexL = $pubhash->{$index}->{'indexlivre'};
		
		if ($indexL) {
			my $autLreq = "SELECT 	a.index,
					a.nom,
					a.prenom,
					axp.position
					
			FROM auteurs_x_publications AS axp
			LEFT JOIN auteurs AS a ON a.index = axp.ref_auteur
			WHERE axp.ref_publication = $indexL
			ORDER BY axp.position;";
		
			my $authors = request_hash($autLreq,$dbc,"position");
				
			$pubhash->{$index}->{'auteurslivre'} = $authors;
		}
		
	}

	elsif ( $pub_type eq "Thesis" ) {
	
		my $pubreq = "SELECT 	p.index,
					tp.en as type,
					p.titre,
					e.index as edid,
					e.nom as edition,
					v.nom as ville,
					pays.en as pays,
					p.page_debut,
					p.page_fin,
					p.annee,
					p.nombre_auteurs
					
			FROM publications as p
			LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
			LEFT JOIN editions AS e ON e.index = p.ref_edition
			LEFT JOIN villes as v ON v.index = e.ref_ville
			LEFT JOIN pays ON pays.index = v.ref_pays 
			WHERE p.index = $index;";
					
		$pubhash = request_hash($pubreq,$dbc,"index");
				
	}
	
	# Get the authors of the publication
	my $autreq = "SELECT 	a.index,
				a.nom,
				a.prenom,
				axp.position
				
		FROM auteurs_x_publications AS axp
		LEFT JOIN auteurs AS a ON a.index = axp.ref_auteur
		WHERE axp.ref_publication = $index
		ORDER BY axp.position;";
	
	my $authors = request_hash($autreq,$dbc,"position");
			
	$pubhash->{$index}->{'auteurs'} = $authors;
	
	# return the hash table containing the publication informations
	return $pubhash;
	
}

# Construct reference citation to a publication in html from a hash containing all the information concerning this publication
sub pub_formating {

	my ($pub, $format) = @_;
		
	my ($index) = keys(%{$pub});
		
	my $type = $pub->{$index}->{'type'};
			
	# Construct the Authority part of the reference citation
	my $nb_authors = $pub->{$index}->{'nombre_auteurs'};
	my @authors;
	my $author_str;
	if ($nb_authors > 1) {
		my $position = 1;
		while ( $position < $nb_authors ) {
			push(@authors,"$pub->{$index}->{'auteurs'}->{$position}->{'nom'} $pub->{$index}->{'auteurs'}->{$position}->{'prenom'}");
			$position++;
		}
		$author_str = join(', ',@authors)." & $pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'} $pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}";
		
		if ($format eq 'html') { $author_str = span({-class=>'pub_auteurs'}, $author_str); }
		
	} else {
		$author_str = "$pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'} $pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}";
		
		if ($format eq 'html') { $author_str = span({-class=>'pub_auteurs'}, $author_str); }
	}
			
	my @strelmt;
	
	# Adapt the reference citation according to the type of publication
	if ($type eq "Article") {
		
		if ($author_str) { push(@strelmt,$author_str); } else { push(@strelmt,"Authors Unknown"); }
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - "); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,"$titre,"); } else { push(@strelmt,"Title unknown,"); }
		if (my $revue = $pub->{$index}->{'revue'}) { if ($format eq 'html') { push(@strelmt,i("$revue,")); } else { push(@strelmt,"$revue,"); } }
		if (my $vol = $pub->{$index}->{'volume'}) {
			if ($format eq 'html') { $vol = "<SPAN STYLE='font-weight:bold;'>$vol</SPAN>"; }
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc)"; }
			if (my $pages = $pub->{$index}->{'page_debut'}) {
				push(@strelmt,"$vol:");
				if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef"; }
				push(@strelmt,"$pages.");
			} else {
				push(@strelmt,"$vol.");
			}
		}
		else { 
			if ($format eq 'html') { $vol = b("?"); } else { $vol = '?' }
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc):"; } else { $vol .= ":"; }
			if (my $pages = $pub->{$index}->{'page_debut'}) {
				push(@strelmt,$vol);
				if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef"; }
				push(@strelmt,"$pages.");
			} else {
				push(@strelmt,"$vol.");
			}
		}
	}
	
	elsif ($type eq "Book") {

		if ($author_str) { push(@strelmt,$author_str); } else { push(@strelmt,"Authors Unknown"); }
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - "); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { 	if ($format eq 'html') { push(@strelmt,i("$titre,")); } else { push(@strelmt,"$titre,"); } } 
		else { if ($format eq 'html') { push(@strelmt,i("Title unknown,")); } else { push(@strelmt,"Title unknown,"); } }
		if (my $vol = $pub->{$index}->{'volume'}) { 
			if (my $pages = $pub->{$index}->{'page_debut'}) {
				if ($format eq 'html') { push(@strelmt,"<SPAN STYLE='font-weight:bold;'>$vol</SPAN>:"); } else { push(@strelmt,"$vol:"); } 
				if ($pages == 1 or $pages eq 'i' or $pages eq 'I') { 
					if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages = "$pagef pp."; }
				}
				else {
					if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef."; }
					else { $pages = "$pages pp."; }
				}
				push(@strelmt,"$pages");
			} else {
				if ($format eq 'html') { push(@strelmt,"<SPAN STYLE='font-weight:bold;'>$vol</SPAN>"); } else { push(@strelmt,"$vol"); }
			}
		} else {
			if (my $pages = $pub->{$index}->{'page_debut'}) {
				
				if ($pages == 1 or $pages eq 'i' or $pages eq 'I') { 
					if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages = "$pagef pp."; }
				}
				else {
					if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef"; }
					else { $pages = "$pages pp."; }
				}
				push(@strelmt,"$pages");
			}
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ", $ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= " ($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= "."; }
			push(@strelmt,$edit);
		}
	}

	elsif ($type eq "In book") {
		
		if ($author_str) { push(@strelmt,$author_str); } else { push(@strelmt,"Authors Unknown"); }
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - "); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt,"$titre,"); } else { push(@strelmt,"Title unknown,"); }
		if ($format eq 'html') {  push(@strelmt,i("In: ")); } else { push(@strelmt,"In: "); }
				
		my $nb_authors_livre = $pub->{$index}->{'nbauteurslivre'};
		if ($nb_authors_livre) {
			my @authors_livre;
			my $book_author_str;
			if ($nb_authors_livre > 1) {
				my $position = 1;
				while ( $position < $nb_authors_livre ) {
					push(@authors_livre,"$pub->{$index}->{'auteurslivre'}->{$position}->{'nom'} $pub->{$index}->{'auteurslivre'}->{$position}->{'prenom'}");
					$position++;
				}
				
				$book_author_str = span({-class=>'pub_auteurs'},join(', ',@authors_livre)." & $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'} $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}");
			
			} else {
				$book_author_str = span({-class=>'pub_auteurs'},"$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'} $pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}");
			}
			
			if ($book_author_str) { push(@strelmt,$book_author_str); } else { push(@strelmt,"Book Authors Unknown"); }
			if (my $annee = $pub->{$index}->{'anneelivre'}) { push(@strelmt,"$annee - "); } else { push(@strelmt," - "); }
			if (my $titre = $pub->{$index}->{'titrelivre'}) { if ($format eq 'html') { push(@strelmt,i("$titre,")); } else { push(@strelmt,"$titre,"); } } 
			else { if ($format eq 'html') { push(@strelmt,i("Title unknown,")); } else { push(@strelmt,"Title unknown,"); } }
			if (my $vol = $pub->{$index}->{'volumelivre'}) { if ($format eq 'html') { push(@strelmt,"<SPAN STYLE='font-weight:bold;'>$vol</SPAN>."); } else { push(@strelmt,"$vol."); } }
			if (my $edit = $pub->{$index}->{'edition'}) {
				if (my $ville = $pub->{$index}->{'ville'}) { 
					$edit .= ", $ville"; 
					if (my $pays = $pub->{$index}->{'pays'}) {
						$edit .= "($pays)";
					}
				}
				unless (substr($edit,-1) eq ".") { $edit .= "."; }
				push(@strelmt,$edit);
			}
		}
		elsif ($pub->{$index}->{'indexlivre'}) { 
			
			my $dbc = db_connection(get_connection_params($conf_file), 'EXPLORER');
						
			push(@strelmt, pub_formating(get_pub_params($dbc, $pub->{$index}->{'indexlivre'}), $format)); 
			
			$dbc->disconnect;
		}
		else {
			push(@strelmt, "-");
		}
		
		if (my $pages = $pub->{$index}->{'page_debut'}) {
			if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef."; }
			push(@strelmt,"p. $pages");
		}

	}
	
	elsif ($type eq "Thesis") {

		if ($author_str) { push(@strelmt,$author_str); } else { push(@strelmt,"Authors Unknown"); }
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt,"$annee - "); } else { push(@strelmt," - "); }
		if (my $titre = $pub->{$index}->{'titre'}) { 	if ($format eq 'html') { push(@strelmt,i("$titre,")); } else { push(@strelmt,"$titre,"); } }
		else { if ($format eq 'html') { push(@strelmt,i("Title unknown,")); } else { push(@strelmt,"Title unknown,"); } }
		push(@strelmt,"Thesis.");
		if (my $pages = $pub->{$index}->{'page_debut'}) {
			if ($pages == 1 or $pages eq 'i' or $pages eq 'I') { 
				if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages = "$pagef pp."; }
			}
			else {
				if (my $pagef = $pub->{$index}->{'page_fin'}) { $pages .= "-$pagef."; }
			}
			push(@strelmt,"$pages");
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ", $ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= " ($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= "."; }
			push(@strelmt,$edit);
		}
	}
	
	# return the html refrence citation
	return join(' ',@strelmt);
	
}

1;

#our $cross_tables = {	'taxons_x_pays' => {	
#							'title' => 'Taxon x country links',
#							'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Country',
#										'id' 	=> 'pays',
#										'ref' 	=> 'ref_pays',
#										'thesaurus' => 'tdwg',
#										'addurl' => 'generique.pl?table=pays&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'internal',
#										'title' => 'Pages',
#										'id'   => 'page_ori',
#										'length' => 12
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' => 'internal',
#										'title' => 'Pages',
#										'id'   => 'page_maj',
#										'length' => 12
#									}, {
#										'type' 	=> 'foreign',
#										'title' => 'Male name',
#										'id' 	=> 'nom_male',
#										'ref' 	=> 'ref_nom_specifique_male',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Male publication',
#										'id'   => 'ref_publication_male',
#									}, {
#										'type' 	  => 'foreign',
#										'title' => 'Female name',
#										'id' 	=> 'nom_femelle',
#										'ref' 	=> 'ref_nom_specifique_femelle',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Female publication',
#										'id'   => 'ref_publication_femelle',
#									}, {	
#										'type' 	  => 'foreign',
#										'title' => 'Unknown sex name',
#										'id' 	=> 'nom_sexe_inconnu',
#										'ref' 	=> 'ref_nom_specifique_sexe_inconnu',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Unknown sex publication',
#										'id'   => 'ref_publication_sexe_inconnu',
#									}, {	
#										'type' => 'internal',
#										'title' => 'Minimum altitude (integer)',
#										'id'   => 'altitude_min',									
#									}, {	
#										'type' => 'internal',
#										'title' => 'Maximum altitude (integer)',
#										'id'   => 'altitude_max',
#									}, {	
#										'type' => 'internal',
#										'title' => 'Minimum minimum altitude (integer)',
#										'id'   => 'altitude_min_min',
#									}, {	
#										'type' => 'internal',
#										'title' => 'Maximum maximum altitude (integer)',
#										'id'   => 'altitude_max_max',
#									}, {	
#										'type' => 'internal',
#										'title' => 'abundance epoch',
#										'id'   => 'epoque_abondance',
#									}
#								],
#						'obligatory' => ['pays', 'ref_pays'],
#						'foreign_fields' => ['p.en'],
#						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays',
#						'order' => 'ORDER BY p.en'
#			},		
			
#			'taxons_x_plantes' => {	
#						'title' => 'Taxon x host plant links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Host plant',
#										'id' 	=> 'plante',
#										'ref' 	=> 'ref_plante',
#										'thesaurus' => 'plantes',
#										'addurl' => 'plants.pl?action=fill'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'internal',
#										'title' => 'Pages',
#										'id'   => 'page_ori',
#										'length' => 12
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' => 'internal',
#										'title' => 'Pages',
#										'id'   => 'page_maj',
#										'length' => 12
#									}, {
#										'type' => 'select',
#										'title' => 'certainty',
#										'id'   => 'certitude',
#										'values' => ['', 'certain', 'uncertain']
#									}
#								],
#						'obligatory' => ['plante', 'ref_plante'],
#						'foreign_fields' => ['get_host_plant_name(ref_plante) AS fullname'],
#						'foreign_joins' => '',
#						'order' => 'ORDER BY fullname'
#			},
			
#			'taxons_x_images' => {	
#						'title' => 'Taxon x image links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Image',
#										'id' 	=> 'image',
#										'ref' 	=> 'ref_image',
#										'thesaurus' => 'images',
#										'addurl' => 'generique.pl?table=images&new=1'
#									}, {	
#										'type' => 'internal',
#										'title' => 'Image text',
#										'id'   => 'commentaire'
#									}
#								],
#						'obligatory' => ['image', 'ref_image']
#			},
						
#			'taxons_x_vernaculaires' => {
#						'title' => 'Taxon x vernacular name links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Vernacular name',
#										'id' 	=> 'nom',
#										'ref' 	=> 'ref_nom',
#										'thesaurus' => 'vernaculaires',
#										'addurl' => 'generique.pl?table=noms_vernaculaires&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_pub',
#									}, {
#										'type' => 'internal',
#										'title' => 'Pages',
#										'id'   => 'page',
#										'length' => 12
#									}
#								],
#						'obligatory' => ['nom', 'ref_nom'],
#						'foreign_fields' => ['nv.nom', 'nv.transliteration'],
#						'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_nom',
#						'order' => 'ORDER BY nom, transliteration'
#			},
			
#			'taxons_x_lieux_depot' => {
#						'title' => 'Taxon x repository links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Deposit place',
#										'id' 	=> 'lieux_depot',
#										'ref' 	=> 'ref_lieux_depot',
#										'thesaurus' => 'lieux_depot',
#										'addurl' => 'generique.pl?table=lieux_depot&new=1'
#									}, {
#										'type' 	=> 'foreign',
#										'title' => 'Name used',
#										'id' 	=> 'nom_utilise',
#										'ref' 	=> 'ref_nom_utilise',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Sex',
#										'id' 	=> 'ref_sexe',
#										'values' => ['', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
#										'labels' => $sexes,
#										'addurl' => 'generique.pl?table=sexes&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Conservation status',
#										'id' 	=> 'ref_etat_conservation',
#										'values' => ['', sort {$conservation_status->{$a} cmp $conservation_status->{$b}} keys(%{$conservation_status})],
#										'labels' => $conservation_status,
#										'addurl' => 'generique.pl?table=etats_conservation&new=1'
#									}, {
#										'type' => 'internal',
#										'title' => 'Number of specimens',
#										'id'   => 'quantite',
#										'length' => 12
#									}
#								],
#						'obligatory' => ['lieux_depot', 'ref_lieux_depot'],
#						'foreign_fields' => ['ld.nom'],
#						'foreign_joins' => 'LEFT JOIN lieux_depot AS ld ON ld.index = tx.ref_lieux_depot',
#						'order' => 'ORDER BY ld.nom'
#			},
			
#			'taxons_x_localites' => {	
#						'title' => 'Taxon x locality links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Locality',
#										'id' 	=> 'localite',
#										'ref' 	=> 'ref_localite',
#										'thesaurus' => 'localites',
#										'addurl' => 'generique.pl?table=localites&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Observation type',
#										'id' 	=> 'ref_type_observation',
#										'values' => ['', sort {$observ_types->{$a} cmp $observ_types->{$b}} keys(%{$observ_types})],
#										'labels' => $observ_types,
#										'addurl' => 'generique.pl?table=types_observation&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['localite', 'ref_localite'],
#						'foreign_fields' => ['l.nom'],
#						'foreign_joins' => 'LEFT JOIN localites AS l ON l.index = tx.ref_localite',
#						'order' => 'ORDER BY l.nom'
#			},

#			'taxons_x_periodes' => {	
#						'title' => 'Taxon x geological period links',
#						'definition' => [
#									{	'type' 	=> 'select',
#										'title' => 'Geological period',
#										'id' 	=> 'ref_periode',
#										'values' => ['', sort {$periods->{$a} cmp $periods->{$b}} keys(%{$periods})],
#										'labels' => $periods,
#										'addurl' => 'generique.pl?table=periodes&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_periode'],
#						'foreign_fields' => ['p.en'],
#						'foreign_joins' => 'LEFT JOIN periodes AS p ON p.index = tx.ref_periode',
#						'order' => 'ORDER BY p.en'
#			},
			
#			'taxons_x_regions' => {	
#						'title' => 'Taxon x region links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Region',
#										'id' 	=> 'region',
#										'ref' 	=> 'ref_region',
#										'thesaurus' => 'regions',
#										'addurl' => 'generique.pl?table=regions&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' 	=> 'foreign',
#										'title' => 'Male name',
#										'id' 	=> 'nom_male',
#										'ref' 	=> 'ref_nom_specifique_male',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Male publication',
#										'id'   => 'ref_publication_male',
#									}, {
#										'type' 	  => 'foreign',
#										'title' => 'Female name',
#										'id' 	=> 'nom_femelle',
#										'ref' 	=> 'ref_nom_specifique_femelle',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Female publication',
#										'id'   => 'ref_publication_femelle',
#									}, {	
#										'type' 	  => 'foreign',
#										'title' => 'Unknown sex name',
#										'id' 	=> 'nom_sexe_inconnu',
#										'ref' 	=> 'ref_nom_specifique_sexe_inconnu',
#										'thesaurus' => 'noms',
#										'addurl' => 'dbtnt.pl?action=add&type=sciname',
#										'class' => 'name'
#									}, {
#										'type' => 'pub',
#										'title' => 'Unknown sex publication',
#										'id'   => 'ref_publication_sexe_inconnu',
#									}, {	
#										'type' => 'internal',
#										'title' => 'Minimum altitude',
#										'id'   => 'altitude_min',
#										'length' => 12
#									}, {	
#										'type' => 'internal',
#										'title' => 'Maximum altitude',
#										'id'   => 'altitude_max',
#										'length' => 12
#									}, {	
#										'type' => 'internal',
#										'title' => 'Minimum minimum altitude',
#										'id'   => 'altitude_min_min',
#										'length' => 12
#									}, {	
#										'type' => 'internal',
#										'title' => 'Maximum maximum altitude',
#										'id'   => 'altitude_max_max',
#										'length' => 12
#									}, {	
#										'type' => 'internal',
#										'title' => 'abundance epoch',
#										'id'   => 'epoque_abondance',
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Frequency level',
#										'id' 	=> 'ref_niveau_frequence',
#										'values' => ['', sort {$frekens->{$a} cmp $frekens->{$b}} keys(%{$frekens})],
#										'labels' => $frekens,
#										'addurl' => 'generique.pl?table=niveaux_frequence&new=1'
#									}
#								],
#						'obligatory' => ['region', 'ref_region'],
#						'foreign_fields' => ['r.nom'],
#						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region',
#						'order' => 'ORDER BY r.nom'
#			},
						
#			'taxons_x_pays_x_agents_infectieux' => {
#						'title' => 'Taxon x country x infectious agent links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Country',
#										'id' 	=> 'pays',
#										'ref' 	=> 'ref_pays',
#										'thesaurus' => 'tdwg',
#										'addurl' => 'generique.pl?table=pays&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Infectious agent',
#										'id' 	=> 'ref_agent_infectieux',
#										'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
#										'labels' => $agents,
#										'addurl' => 'generique.pl?table=agents_infectieux&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Confirmation level',
#										'id' 	=> 'ref_niveau_confirmation',
#										'values' => ['', sort {$confirm->{$a} cmp $confirm->{$b}} keys(%{$confirm})],
#										'labels' => $confirm,
#										'addurl' => 'generique.pl?table=niveaux_confirmation&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_pays', 'pays', 'ref_agent_infectieux'],
#						'foreign_fields' => ['p.en', 'a.en'],
#						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
#						'order' => 'ORDER BY p.en, a.en'
#			},
			
#			'taxons_x_pays_x_habitats' => {
#						'title' => 'Taxon x country x habitat links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Country',
#										'id' 	=> 'pays',
#										'ref' 	=> 'ref_pays',
#										'thesaurus' => 'tdwg',
#										'addurl' => 'generique.pl?table=pays&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Habitat',
#										'id' 	=> 'ref_habitat',
#										'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
#										'labels' => $habitats,
#										'addurl' => 'generique.pl?table=habitats&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_pays', 'pays', 'ref_habitat'],
#						'foreign_fields' => ['p.en', 'h.en'],
#						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
#						'order' => 'ORDER BY p.en, h.en'
#			},
			
#			'taxons_x_pays_x_modes_capture' => {
#						'title' => 'Taxon x country x capture mode links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Country',
#										'id' 	=> 'pays',
#										'ref' 	=> 'ref_pays',
#										'thesaurus' => 'tdwg',
#										'addurl' => 'generique.pl?table=pays&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Capture mode',
#										'id' 	=> 'ref_mode_capture',
#										'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
#										'labels' => $captures,
#										'addurl' => 'generique.pl?table=modes_capture&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_pays', 'pays', 'ref_mode_capture'],
#						'foreign_fields' => ['p.en', 'c.en'],
#						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
#						'order' => 'ORDER BY p.en, c.en'
#			},

#			'taxons_x_regions_x_agents_infectieux' => {
#						'title' => 'Taxon x region x infectious agent links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Region',
#										'id' 	=> 'region',
#										'ref' 	=> 'ref_region',
#										'thesaurus' => 'regions',
#										'addurl' => 'generique.pl?table=regions&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Infectious agent',
#										'id' 	=> 'ref_agent_infectieux',
#										'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
#										'labels' => $agents,
#										'addurl' => 'generique.pl?table=agents_infectieux&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Confirmation level',
#										'id' 	=> 'ref_niveau_confirmation',
#										'values' => ['', sort {$confirm->{$a} cmp $confirm->{$b}} keys(%{$confirm})],
#										'labels' => $confirm,
#										'addurl' => 'generique.pl?table=niveaux_confirmation&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_region', 'region', 'ref_agent_infectieux'],
#						'foreign_fields' => ['r.nom', 'a.en'],
#						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
#						'order' => 'ORDER BY r.nom, a.en'
#			},
			
#			'taxons_x_regions_x_habitats' => {
#						'title' => 'Taxon x region x habitat links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Region',
#										'id' 	=> 'region',
#										'ref' 	=> 'ref_region',
#										'thesaurus' => 'regions',
#										'addurl' => 'generique.pl?table=regions&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Habitat',
#										'id' 	=> 'ref_habitat',
#										'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
#										'labels' => $habitats,
#										'addurl' => 'generique.pl?table=habitats&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_region', 'region', 'ref_habitat'],
#						'foreign_fields' => ['r.nom', 'h.en'],
#						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
#						'order' => 'ORDER BY r.nom, h.en'
#			},

#			'taxons_x_clefs' => {	
#						'title' => 'identification keys',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Identification key',
#										'id' 	=> 'clef',
#										'ref' 	=> 'ref_clef',
#										'thesaurus' => 'clefs',
#										'addurl' => 'generique.pl?table=clefs&new=1'
#									}
#								],
#						'obligatory' => ['clef', 'ref_clef']
#			},			
#			'taxons_x_regions_x_modes_capture' => {
#						'title' => 'Taxon x region x capture mode links',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Region',
#										'id' 	=> 'region',
#										'ref' 	=> 'ref_region',
#										'thesaurus' => 'regions',
#										'addurl' => 'generique.pl?table=regions&new=1'
#									}, {
#										'type' 	=> 'select',
#										'title' => 'Capture mode',
#										'id' 	=> 'ref_mode_capture',
#										'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
#										'labels' => $captures,
#										'addurl' => 'generique.pl?table=modes_capture&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}
#								],
#						'obligatory' => ['ref_region', 'region', 'ref_mode_capture'],
#						'foreign_fields' => ['r.nom', 'c.en'],
#						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
#						'order' => 'ORDER BY r.nom, c.en'
#			}
#};

##########################################################################################################################################################
#	Data needed to build Authors fields in Names.pl	and Publications.pl	##########################################################################
##########################################################################################################################################################

my @authors_first_names;
my @authors_last_names;

foreach (@{$authors}) {
	if ($_->[0]) { push (@authors_first_names,"$_->[0]"); }
	if ($_->[1]) { push (@authors_last_names,"$_->[1]"); } else { push (@authors_last_names,""); }
}
my $first_names_str = '"'.join('","',@authors_first_names).'"';
my $last_names_str = '"'.join('","',@authors_last_names).'"';

sub AonFocus {
	my ($prefix) = @_;
	return "clear_all_sugs('$prefix');availableCompletion('$prefix', 'none');reinit('$prefix');";
}

our $authorsJscript = "

	first_names = new Array($first_names_str);
	last_names = new Array($last_names_str);
	
	var sug = '';
	var sug_disp = '';
	
	test = 0;
	
	function getAuthor(pre, num) {
		
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		
		if (phantom_field.value == 'Name') { phantom_field.value = ''; lphantom_field = ''; }
		
		var first_name = name_field.value;
		
		var lenf = first_name.length;
		//suggestion for author Initials
		sug_disp = '';
		//suggestion for author last name
		sug_displ = '';
		// memorized values
		sug = '';
		sugl = '';
		last = 0;
		
		matchings = new Array();
		
		if (first_name.length != 0) {
			// get matching author from array
			for (ele in first_names)  {
				if (first_names[ele].substr(0,lenf).toLowerCase() == first_name.toLowerCase() )  {
					if (!matchings.length) {
						if (lenf != first_names[ele].length) { sug_disp = first_name + first_names[ele].substr(lenf); }
						sug_displ = last_names[ele];
						sug = first_names[ele];
						sugl = last_names[ele];
					}
					matchings.push(ele);
				}
			}
		}
		
		if (!matchings.length) { availableCompletion(pre, 'none'); }
		else {		
			if(matchings.length == 1) {
				document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';	
			}
			else { 
				document.getElementById(pre+'NEXTbtn'+num).style.display = 'block';		
			}
		}
	    
		phantom_field.value = sug_disp;
		if (!lphantom_field.value && !lname_field.value) { 
			lphantom_field.value = sug_displ; 
		}
	
		if (!sug.length) {
			lphantom_field.value = '';
			lname_field.value = '';
			document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
		else {
			document.getElementById(pre+'SUGbtn'+num).style.display = 'block';
		}
	}
	
	function setAuthor(pre, num) {
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		name_field.value = sug;
			
		if (!lname_field.value) {lname_field.value = sugl; }
		hideCompletion(pre, num);
	}
		
	function hideCompletion (pre, num) {
		document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
		document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
	}
	
	function testAvailability (pre, num) {
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		if ((!phantom_field.value || phantom_field.value == 'Name') && (!lphantom_field.value || lphantom_field.value == 'Initials')) { 
			document.getElementById(pre+'NEXTbtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
	}
	
	function availableCompletion (pre, num) {
		var index = 1;
		var goon = 1;
		while (goon) {
			
			var image = document.getElementById(pre+'SUGbtn'+index);
			var image2 = document.getElementById(pre+'NEXTbtn'+index);
			
			if (!image) { goon = 0 }
			else { 
				if (index != num || num == 'none') { 
					image.style.display = 'none'; 
					image2.style.display = 'none'; 
				}
			}
			index = index +1;
		}
	}
	
	function clear_sugs (pre, num) {

			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
			
			phantom_field.value = ''; 
			lphantom_field.value = '';
	}
	
	function clear_all_sugs (pre) {
		
		var num = 1;
		var goon = 1;
		while (goon) {
						
			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
			
			if (!phantom_field) { goon = 0 }
			else { 
				phantom_field.value = ''; 
				lphantom_field.value = '';
			}

			num = num +1;
		}
	}
	
	function clear_values (pre, num) {

		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
		
		if(name_field.length > 1) { name_field.value = name_field[0]; }
		lname_field.value = '';
	}
	
	function reinit (pre) {
		
		var num = 1;
		
		while (document.getElementById(pre+'AFN'+num)) {
			var name_field = document.getElementById(pre+'AFN'+num);
			var phantom_field = document.getElementById(pre+'AFNsug'+num);
				
			var lname_field = document.getElementById(pre+'ALN'+num);
			var lphantom_field = document.getElementById(pre+'ALNsug'+num);
						
			if (name_field.value != '') { 
				phantom_field.value = ''; 
				lphantom_field.value = '';
			} else { 
				phantom_field.value = 'Name';
				if (lname_field.value != '') {
					lphantom_field.value = 'Initials';
				}
				else {
					lphantom_field.value = 'Initials';
				}
			}
						
			num = num +1;
		}
	}
	
	function get_next_author (pre, num) {
		
		test = 1;
		
		var name_field = document.getElementById(pre+'AFN'+num);
		var phantom_field = document.getElementById(pre+'AFNsug'+num);
			
		var lname_field = document.getElementById(pre+'ALN'+num);
		var lphantom_field = document.getElementById(pre+'ALNsug'+num);
				
		if (phantom_field.value == 'Name') { phantom_field.value = ''; lphantom_field = ''; }
		
		var first_name = name_field.value;
		
		var lenf = first_name.length;
		
		last = last +1;
		
		if (last >= matchings.length) { 
			last = 0;
		}
		
		var ii = matchings[last];
		
		if (lenf != first_names[ii].length) { sug_disp = first_name + first_names[ii].substr(lenf); }
		sug_displ = last_names[ii];
		sug = first_names[ii];
		sugl = last_names[ii];
		
		phantom_field.value = sug_disp;
		lphantom_field.value = sug_displ; 
	
		if (!sug.length) {
			document.getElementById(pre+'NEXTtn'+num).style.display = 'none';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'none';
		}
		else {
			document.getElementById(pre+'NEXTtn'+num).style.display = 'block';
			document.getElementById(pre+'SUGbtn'+num).style.display = 'block';
		}
	}
	
	function ToUpperFirst (pre, num) {
		
		var name = document.getElementById(pre+'AFN'+num);
		var lname = document.getElementById(pre+'ALN'+num);
				
		name.value = name.value.substr(0,1).toUpperCase() + name.value.substr(1,name.value.length);
		//lname.value = lname.value.substr(0,lname.value.length).toUpperCase();
	}
	
	function clear_fields (pre, num) {
		
		var name = document.getElementById(pre+'AFN'+num);
		var lname = document.getElementById(pre+'ALN'+num);
				
		name.value = '';
		lname.value = '';
	}

	function ChangeNbAuts (form,field,todo,number,targeted,taged) { 
	
		if (todo == 'more') { field.value = number+1; }
		else { if (todo == 'less' && number > 1) { field.value = number-1; } }

		form.action = targeted+'?action=fill&page='+taged;
		form.submit();
	}";

sub makeAuthorsfields {

	my ($prefix, $i) = @_;
		
	my $fields = 	"<div style='position: relative; margin: 0; padding: 0; height: 22px;' >
			
				<div style='position: absolute; top: 0; left: 0; width: 150px; z-index: 1;'>
					<input 	type='text' 
						name='".$prefix."AFNsug$i' 
						id='".$prefix."AFNsug$i' 
						style='background: white; color: grey; border: 1px solid #999; width: 150px; padding: 0 2px;' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 0; width: 150px; z-index: 2;'>
					<input 	type='text' 
						autocomplete='off' 
						name='".$prefix."AFN$i' 
						id='".$prefix."AFN$i' 
						style='background: none; border: 1px solid #999; width: 150px; padding: 0 2px;' 
						value=".'"'.param($prefix."AFN$i").'"'.
												
						"onfocus=\"this.form.".$prefix."ALN$i.disabled = false;
							  clear_all_sugs('$prefix');
							  clear_fields('$prefix', $i);
							  availableCompletion('$prefix', $i);
							  getAuthor('$prefix', $i);\"
						onkeyup=\"this.form.".$prefix."ALN$i.disabled = false;
							  clear_sugs('$prefix', $i);
							  availableCompletion('$prefix', $i);
							  getAuthor('$prefix', $i)\"
						onBlur=\"clear_all_sugs('$prefix');ToUpperFirst('$prefix', $i);reinit('$prefix');\"
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 155px; width: 150px; z-index: 1;'>
					<input 	type='text' 
						name='".$prefix."ALNsug$i' 
						id='".$prefix."ALNsug$i' 
						style='background: white; color: grey; border: 1px solid #999; width: 150px; padding: 0 2px;' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 155px; width: 150px; z-index: 2;'>
					<input autocomplete='off' type='text' 
					name='".$prefix."ALN$i' 
					id='".$prefix."ALN$i'  
					style='background: none; border: 1px solid #999; width: 150px; padding: 0 2px;' 
					value=".'"'.param($prefix."ALN$i").'"'.
					"onfocus=\"if(this.form.".$prefix."ALNsug$i.value == 'Initials') { this.form.".$prefix."ALN$i.disabled = true; }
						  clear_sugs('$prefix', $i);
						  availableCompletion('$prefix', 'none');
						  \" 
					onBlur=\"ToUpperFirst('$prefix', $i);\"
					/>
				</div>
				
				<div 	id='".$prefix."NEXTbtn$i' style='position: absolute; top: 0px; left:315px; z-index: 3; display: none;' 
					onClick=\"	clear_values('$prefix', $i);
							get_next_author('$prefix', $i)\" 
					onMouseOver=\"testAvailability('$prefix', $i)\"
				>
					<img src='/Editor/next.png' border='0' onMouseOver=\"this.style.cursor = 'pointer';\">
				</div>				
				
				<div 	id='".$prefix."SUGbtn$i' style='position: absolute; top: 0px; left:380px; z-index: 3; display: none;' 
					onClick=\"setAuthor('$prefix', $i);clear_sugs('$prefix', $i);\" 
					onMouseOver=\"testAvailability('$prefix', $i)\"
				>
					
					<img src='/Editor/ok.png' border='0' onMouseOver=\"this.style.cursor = 'pointer';\">
				</div>
			</div>";
}

sub add_author {

	my ($dbc, $name, $prenom) = @_;

	$name =~ s/'/\\'/g;
	$prenom =~ s/'/\\'/g;
	
	$name = ucfirst($name);
	$prenom = ucfirst($prenom);

	my $flist = "index, nom"; #list of fields
	my $vlist = "default,'$name'"; #list of values

	my $conditions = '';
	if ($prenom) { $flist .= ", prenom"; $vlist .= ",'$prenom'"; $conditions .= "AND prenom = '$prenom'";} else { $conditions .= "AND prenom is NULL"; }

	my $index;
	my $result = request_tab("select index from auteurs where nom = '$name' $conditions;", $dbc, 1);
		
	if (scalar(@{$result})) {
		($index) = @{$result};

	} else {			
		my $sth = $dbc->prepare( "INSERT INTO auteurs ($flist) VALUES ($vlist);" ) or print header(),start_html(),$dbc->errstr,end_html();

		$sth->execute() or print header(),start_html(),$dbc->errstr,end_html();

		my $req = "SELECT MAX(index) FROM auteurs;";
		($index) = @{request_tab($req,$dbc,1)};	
	}
	return $index;
}

