package Style;

use Carp;
use strict;
use warnings;
use DBI;
use DBCommands qw (get_connection_params read_lang db_connection request_hash request_tab request_row);
use CGI qw( -no_xhtml :standard ); # make html 4.0 page
use CGI::Carp qw( fatalsToBrowser warningsToBrowser ); # display errors in browser


BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	
	@ISA         = qw(Exporter);
	@EXPORT      = qw($background $rowcolor $css $conf_file $jscript_funcs $jscript_imgs $jscript_for_hidden $dblabel $cross_tables);
	%EXPORT_TAGS = ();
	
	# vos variables globales a etre exporter vont ici,
	# ainsi que vos fonctions, si necessaire
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la
use vars      qw($background $rowcolor $css $conf_file $jscript_imgs $jscript_for_hidden $dblabel $cross_tables);

# Initialisation de globales, en premier, celles qui seront exportees

our $dblabel = 'CIPA';

our $conf_file = '/etc/flow/cipaeditor.conf';

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
	
	.buttonSubmit { border: none; background: url('/dbtntDocs/submit.png') no-repeat top left; height: 22px; width: 78px; color: transparent; }
	.buttonClear { border: none; background: url('/dbtntDocs/clear.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonHome { border: none; background: url('/dbtntDocs/home.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonBack { border: none; background: url('/dbtntDocs/back.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonNew { border: none; background: url('/dbtntDocs/new.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonModify { border: none; background: url('/dbtntDocs/modify.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonInsert { border: none; background: url('/dbtntDocs/insert.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonUpdate { border: none; background: url('/dbtntDocs/update.png') no-repeat top left; height: 22px; width: 78px; }
	.buttonDelete { border: none; background: url('/dbtntDocs/delete.png') no-repeat top left; height: 25px; width: 22px; color: transparent; }
";

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

our $jscript_imgs = "
		var okonimg = new Image ();
		var okoffimg = new Image ();
		okonimg.src = '/Editor/ok1.png';
		okoffimg.src = '/Editor/ok0.png';
		var newonimg = new Image ();
		var newoffimg = new Image ();
		newonimg.src = '/Editor/new1.png';
		newoffimg.src = '/Editor/new0.png';
		var backonimg = new Image ();
		var backoffimg = new Image ();
		backonimg.src = '/Editor/back1.png';
		backoffimg.src = '/Editor/back0.png';
		var modifonimg = new Image ();
		var modifoffimg = new Image ();
		modifonimg.src = '/Editor/modify1.png';
		modifoffimg.src = '/Editor/modify0.png';
		var mMonimg = new Image ();
		var mMoffimg = new Image ();
		mMonimg.src = '/Editor/mainMenu1.png';
		mMoffimg.src = '/Editor/mainMenu0.png';
		var chgonimg = new Image ();
		var chgoffimg = new Image ();
		chgonimg.src = '/Editor/Change1.png';
		chgoffimg.src = '/Editor/Change0.png';
		var searchonimg = new Image ();
		var searchoffimg = new Image ();
		searchonimg.src = '/Editor/search1.png';
		searchoffimg.src = '/Editor/search0.png';		
		var clearonimg = new Image ();
		var clearoffimg = new Image ();
		clearonimg.src = '/Editor/clear1.png';
		clearoffimg.src = '/Editor/clear0.png';";
		
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

my $dbc = db_connection(get_connection_params($conf_file));

my $sexes;
make_hash ($dbc, "SELECT index, en FROM sexes;", \$sexes);
my $conservation_status;
make_hash ($dbc, "SELECT index, en FROM etats_conservation;", \$conservation_status);
my $observ_types;
make_hash ($dbc, "SELECT index, en FROM types_observation;", \$observ_types);
my $periods;
make_hash ($dbc, "SELECT index, en FROM periodes;", \$periods);
my $frekens;
make_hash ($dbc, "SELECT index, en FROM niveaux_frequence;", \$frekens);
my $typeTypes;
make_hash ($dbc, "SELECT index, en FROM types_type;", \$typeTypes);
my $depotTypes;
make_hash ($dbc, "SELECT index, en FROM types_depot;", \$depotTypes);
my $agents;
make_hash ($dbc, "SELECT a.index, a.en, t.en FROM agents_infectieux AS a LEFT JOIN types_agent_infectieux AS t ON t.index = a.ref_type_agent_infectieux;", \$agents);
my $confirm;
make_hash ($dbc, "SELECT index, en FROM niveaux_confirmation;", \$confirm);
my $habitats;
make_hash ($dbc, "SELECT index, en FROM habitats;", \$habitats);
my $captures;
make_hash ($dbc, "SELECT index, en FROM modes_capture;", \$captures);

	
our $cross_tables = {	'taxons_x_pays' => {	
							'title' => 'Taxon x country link(s)',
							'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Country',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'pays',
										'addurl' => 'generique.pl?table=pays'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page_ori',
										'length' => 4
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}, {
										'type' => 'internal',
										'title' => 'Updating page',
										'id'   => 'page_maj',
										'length' => 4
									}, {
										'type' 	=> 'foreign',
										'title' => 'Male name',
										'id' 	=> 'nom_male',
										'ref' 	=> 'ref_nom_specifique_male',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Male publication',
										'id'   => 'ref_publication_male',
									}, {
										'type' 	  => 'foreign',
										'title' => 'Female name',
										'id' 	=> 'nom_femelle',
										'ref' 	=> 'ref_nom_specifique_femelle',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Female publication',
										'id'   => 'ref_publication_femelle',
									}, {	
										'type' 	  => 'foreign',
										'title' => 'Unknown sex name',
										'id' 	=> 'nom_sexe_inconnu',
										'ref' 	=> 'ref_nom_specifique_sexe_inconnu',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Unknown sex publication',
										'id'   => 'ref_publication_sexe_inconnu',
									}, {	
										'type' => 'internal',
										'title' => 'Minimum altitude (integer)',
										'id'   => 'altitude_min',
										'length'   => 4
									}, {	
										'type' => 'internal',
										'title' => 'Maximum altitude (integer)',
										'id'   => 'altitude_max',
										'length'   => 4
									}, {	
										'type' => 'internal',
										'title' => 'Minimum minimum altitude (integer)',
										'id'   => 'altitude_min_min',
										'length'   => 4
									}, {	
										'type' => 'internal',
										'title' => 'Maximum maximum altitude (integer)',
										'id'   => 'altitude_max_max',
										'length'   => 4
									}, {	
										'type' => 'internal',
										'title' => 'abundance epoch',
										'id'   => 'epoque_abondance'
									}
								],
						'obligatory' => ['pays', 'ref_pays'],
						'foreign_fields' => ['p.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays',
						'order' => 'ORDER BY p.en'
			},		
			
			'taxons_x_plantes' => {	
						'title' => 'Taxon x host plant link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Host plant',
										'id' 	=> 'plante',
										'ref' 	=> 'ref_plante',
										'thesaurus' => 'plantes',
										'addurl' => 'plants.pl?action=fill'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page_ori',
										'length' => 4
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}, {
										'type' => 'internal',
										'title' => 'Updating page',
										'id'   => 'page_maj',
										'length' => 4
									}, {
										'type' => 'select',
										'title' => 'certainty',
										'id'   => 'certitude',
										'values' => ['', 'certain', 'uncertain']
									}
								],
						'obligatory' => ['plante', 'ref_plante'],
						'foreign_fields' => ['get_host_plant_name(ref_plante) AS fullname'],
						'foreign_joins' => '',
						'order' => 'ORDER BY fullname'
			},
			
			'taxons_x_images' => {	
						'title' => 'Taxon x image link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Image',
										'id' 	=> 'image',
										'ref' 	=> 'ref_image',
										'thesaurus' => 'images',
										'addurl' => 'generique.pl?table=images'
									}, {	
										'type' => 'internal',
										'title' => 'Image text',
										'id'   => 'commentaire'
									}
								],
						'obligatory' => ['image', 'ref_image']
			},
					
			'noms_x_images' => {	
						'title' => 'Type specimen x image link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Image',
										'id' 	=> 'image',
										'ref' 	=> 'ref_image',
										'thesaurus' => 'images',
										'addurl' => 'generique.pl?table=images'
									}, {
										'type' => 'internal',
										'title' => 'Image text',
										'id'   => 'commentaire'
									}
								],
						'obligatory' => ['image', 'ref_image']
			},
					
			'taxons_x_vernaculaires' => {
						'title' => 'Taxon x vernacular name link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Vernacular name',
										'id' 	=> 'nom',
										'ref' 	=> 'ref_nom',
										'thesaurus' => 'vernaculaires',
										'addurl' => 'generique.pl?table=noms_vernaculaires'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_pub',
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page',
										'length' => 4
									}
								],
						'obligatory' => ['nom', 'ref_nom'],
						'foreign_fields' => ['nv.nom', 'nv.transliteration'],
						'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_nom',
						'order' => 'ORDER BY nom, transliteration'
			},
			
			'taxons_x_lieux_depot' => {
						'title' => 'Taxon x repository link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Deposit place',
										'id' 	=> 'lieux_depot',
										'ref' 	=> 'ref_lieux_depot',
										'thesaurus' => 'lieux_depot',
										'addurl' => 'generique.pl?table=lieux_depot'
									}, {
										'type' 	=> 'foreign',
										'title' => 'Name used',
										'id' 	=> 'nom_utilise',
										'ref' 	=> 'ref_nom_utilise',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname'
									}, {
										'type' 	=> 'select',
										'title' => 'Sex',
										'id' 	=> 'ref_sexe',
										'values' => ['', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
										'labels' => $sexes,
										'addurl' => 'generique.pl?table=sexes'
									}, {
										'type' 	=> 'select',
										'title' => 'Conservation status',
										'id' 	=> 'ref_etat_conservation',
										'values' => ['', sort {$conservation_status->{$a} cmp $conservation_status->{$b}} keys(%{$conservation_status})],
										'labels' => $conservation_status,
										'addurl' => 'generique.pl?table=etats_conservation'
									}, {
										'type' => 'internal',
										'title' => 'Number of specimens',
										'id'   => 'quantite',
										'length' => 3
									}
								],
						'obligatory' => ['lieux_depot', 'ref_lieux_depot'],
						'foreign_fields' => ['ld.nom'],
						'foreign_joins' => 'LEFT JOIN lieux_depot AS ld ON ld.index = tx.ref_lieux_depot',
						'order' => 'ORDER BY ld.nom'
			},
			
			'taxons_x_localites' => {	
						'title' => 'Taxon x locality link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Locality',
										'id' 	=> 'localite',
										'ref' 	=> 'ref_localite',
										'thesaurus' => 'localites',
										'addurl' => 'generique.pl?table=localites'
									}, {
										'type' 	=> 'select',
										'title' => 'Observation type',
										'id' 	=> 'ref_type_observation',
										'values' => ['', sort {$observ_types->{$a} cmp $observ_types->{$b}} keys(%{$observ_types})],
										'labels' => $observ_types,
										'addurl' => 'generique.pl?table=types_observation'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['localite', 'ref_localite'],
						'foreign_fields' => ['l.nom'],
						'foreign_joins' => 'LEFT JOIN localites AS l ON l.index = tx.ref_localite',
						'order' => 'ORDER BY l.nom'
			},

			'taxons_x_periodes' => {	
						'title' => 'Taxon x geological period link(s)',
						'definition' => [
									{	'type' 	=> 'select',
										'title' => 'Geological period',
										'id' 	=> 'ref_periode',
										'values' => ['', sort {$periods->{$a} cmp $periods->{$b}} keys(%{$periods})],
										'labels' => $periods,
										'addurl' => 'generique.pl?table=periodes'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_periode'],
						'foreign_fields' => ['p.en'],
						'foreign_joins' => 'LEFT JOIN periodes AS p ON p.index = tx.ref_periode',
						'order' => 'ORDER BY p.en'
			},
			
			'taxons_x_regions' => {	
						'title' => 'Taxon x region link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Region',
										'id' 	=> 'region',
										'ref' 	=> 'ref_region',
										'thesaurus' => 'regions',
										'addurl' => 'generique.pl?table=regions'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}, {
										'type' 	=> 'foreign',
										'title' => 'Male name',
										'id' 	=> 'nom_male',
										'ref' 	=> 'ref_nom_specifique_male',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Male publication',
										'id'   => 'ref_publication_male',
									}, {
										'type' 	  => 'foreign',
										'title' => 'Female name',
										'id' 	=> 'nom_femelle',
										'ref' 	=> 'ref_nom_specifique_femelle',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Female publication',
										'id'   => 'ref_publication_femelle',
									}, {	
										'type' 	  => 'foreign',
										'title' => 'Unknown sex name',
										'id' 	=> 'nom_sexe_inconnu',
										'ref' 	=> 'ref_nom_specifique_sexe_inconnu',
										'thesaurus' => 'noms',
										'addurl' => 'typeSelect.pl?action=add&type=sciname',
										'class' => 'name'
									}, {
										'type' => 'pub',
										'title' => 'Unknown sex publication',
										'id'   => 'ref_publication_sexe_inconnu',
									}, {	
										'type' => 'internal',
										'title' => 'Minimum altitude',
										'id'   => 'altitude_min',
										'length' => 3
									}, {	
										'type' => 'internal',
										'title' => 'Maximum altitude',
										'id'   => 'altitude_max',
										'length' => 3
									}, {	
										'type' => 'internal',
										'title' => 'Minimum minimum altitude',
										'id'   => 'altitude_min_min',
										'length' => 3
									}, {	
										'type' => 'internal',
										'title' => 'Maximum maximum altitude',
										'id'   => 'altitude_max_max',
										'length' => 3
									}, {	
										'type' => 'internal',
										'title' => 'abundance epoch',
										'id'   => 'epoque_abondance',
									}, {
										'type' 	=> 'select',
										'title' => 'Frequency level',
										'id' 	=> 'ref_niveau_frequence',
										'values' => ['', sort {$frekens->{$a} cmp $frekens->{$b}} keys(%{$frekens})],
										'labels' => $frekens,
										'addurl' => 'generique.pl?table=niveaux_frequence'
									}
								],
						'obligatory' => ['region', 'ref_region'],
						'foreign_fields' => ['r.nom'],
						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region',
						'order' => 'ORDER BY r.nom'
			},
			
			'noms_x_types' => {
						'title' => 'Name x type link(s)',
						'definition' => [
									{	'type' 	=> 'select',
										'title' => 'Type',
										'id' 	=> 'ref_type',
										'values' => ['', sort {$typeTypes->{$a} cmp $typeTypes->{$b}} keys(%{$typeTypes})],
										'labels' => $typeTypes,
										'addurl' => 'generique.pl?table=types_type'
									}, {
										'type' 	=> 'select',
										'title' => 'Sex',
										'id' 	=> 'ref_sexe',
										'values' => ['', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
										'labels' => $sexes,
										'addurl' => 'generique.pl?table=sexes'
									}, {
										'type' 	=> 'foreign',
										'title' => 'Deposit place',
										'id' 	=> 'lieux_depot',
										'ref' 	=> 'ref_lieux_depot',
										'thesaurus' => 'lieux_depot',
										'addurl' => 'generique.pl?table=lieux_depot'
									}, {
										'type' 	=> 'select',
										'title' => 'Deposit type',
										'id' 	=> 'ref_type_depot',
										'values' => ['', sort {$depotTypes->{$a} cmp $depotTypes->{$b}} keys(%{$depotTypes})],
										'labels' => $depotTypes,
										'addurl' => 'generique.pl?table=types_depot'
									}, {
										'type' 	=> 'select',
										'title' => 'Conservation status',
										'id' 	=> 'ref_etat_conservation',
										'values' => ['', sort {$conservation_status->{$a} cmp $conservation_status->{$b}} keys(%{$conservation_status})],
										'labels' => $conservation_status,
										'addurl' => 'generique.pl?table=etats_conservation'
									}, {
										'type' => 'internal',
										'title' => 'Number of specimens',
										'id'   => 'quantite',
										'length' => 3
									}
								],
						'obligatory' => ['lieux_depot', 'ref_lieux_depot', 'ref_type'],
						'foreign_fields' => ['ld.nom'],
						'foreign_joins' => 'LEFT JOIN lieux_depot AS ld ON ld.index = tx.ref_lieux_depot',
						'order' => 'ORDER BY ld.nom'
			},
			
			'taxons_x_pays_x_agents_infectieux' => {
						'title' => 'Taxon x country x infectious agent link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Country',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'pays',
										'addurl' => 'generique.pl?table=pays'
									}, {
										'type' 	=> 'select',
										'title' => 'Infectious agent',
										'id' 	=> 'ref_agent_infectieux',
										'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
										'labels' => $agents,
										'addurl' => 'generique.pl?table=agents_infectieux'
									}, {
										'type' 	=> 'select',
										'title' => 'Confirmation level',
										'id' 	=> 'ref_niveau_confirmation',
										'values' => ['', sort {$confirm->{$a} cmp $confirm->{$b}} keys(%{$confirm})],
										'labels' => $confirm,
										'addurl' => 'generique.pl?table=niveaux_confirmation'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_pays', 'pays', 'ref_agent_infectieux'],
						'foreign_fields' => ['p.en', 'a.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
						'order' => 'ORDER BY p.en, a.en'
			},
			
			'taxons_x_pays_x_habitats' => {
						'title' => 'Taxon x country x habitat link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Country',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'pays',
										'addurl' => 'generique.pl?table=pays'
									}, {
										'type' 	=> 'select',
										'title' => 'Habitat',
										'id' 	=> 'ref_habitat',
										'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
										'labels' => $habitats,
										'addurl' => 'generique.pl?table=habitats'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_pays', 'pays', 'ref_habitat'],
						'foreign_fields' => ['p.en', 'h.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
						'order' => 'ORDER BY p.en, h.en'
			},
			
			'taxons_x_pays_x_modes_capture' => {
						'title' => 'Taxon x country x capture mode link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Country',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'pays',
										'addurl' => 'generique.pl?table=pays'
									}, {
										'type' 	=> 'select',
										'title' => 'Capture mode',
										'id' 	=> 'ref_mode_capture',
										'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
										'labels' => $captures,
										'addurl' => 'generique.pl?table=modes_capture'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_pays', 'pays', 'ref_mode_capture'],
						'foreign_fields' => ['p.en', 'c.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
						'order' => 'ORDER BY p.en, c.en'
			},

			'taxons_x_regions_x_agents_infectieux' => {
						'title' => 'Taxon x region x infectious agent link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Region',
										'id' 	=> 'region',
										'ref' 	=> 'ref_region',
										'thesaurus' => 'regions',
										'addurl' => 'generique.pl?table=regions'
									}, {
										'type' 	=> 'select',
										'title' => 'Infectious agent',
										'id' 	=> 'ref_agent_infectieux',
										'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
										'labels' => $agents,
										'addurl' => 'generique.pl?table=agents_infectieux'
									}, {
										'type' 	=> 'select',
										'title' => 'Confirmation level',
										'id' 	=> 'ref_niveau_confirmation',
										'values' => ['', sort {$confirm->{$a} cmp $confirm->{$b}} keys(%{$confirm})],
										'labels' => $confirm,
										'addurl' => 'generique.pl?table=niveaux_confirmation'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_region', 'region', 'ref_agent_infectieux'],
						'foreign_fields' => ['r.nom', 'a.en'],
						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
						'order' => 'ORDER BY r.nom, a.en'
			},
			
			'taxons_x_regions_x_habitats' => {
						'title' => 'Taxon x region x habitat link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Region',
										'id' 	=> 'region',
										'ref' 	=> 'ref_region',
										'thesaurus' => 'regions',
										'addurl' => 'generique.pl?table=regions'
									}, {
										'type' 	=> 'select',
										'title' => 'Habitat',
										'id' 	=> 'ref_habitat',
										'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
										'labels' => $habitats,
										'addurl' => 'generique.pl?table=habitats'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_region', 'region', 'ref_habitat'],
						'foreign_fields' => ['r.nom', 'h.en'],
						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
						'order' => 'ORDER BY r.nom, h.en'
			},
			
			'taxons_x_regions_x_modes_capture' => {
						'title' => 'Taxon x region x capture mode link(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Region',
										'id' 	=> 'region',
										'ref' 	=> 'ref_region',
										'thesaurus' => 'regions',
										'addurl' => 'generique.pl?table=regions'
									}, {
										'type' 	=> 'select',
										'title' => 'Capture mode',
										'id' 	=> 'ref_mode_capture',
										'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
										'labels' => $captures,
										'addurl' => 'generique.pl?table=modes_capture'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'pub',
										'title' => 'Updating publication',
										'id'   => 'ref_publication_maj'
									}
								],
						'obligatory' => ['ref_region', 'region', 'ref_mode_capture'],
						'foreign_fields' => ['r.nom', 'c.en'],
						'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
						'order' => 'ORDER BY r.nom, c.en'
			}

};
