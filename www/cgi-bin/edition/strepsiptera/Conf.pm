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
	@EXPORT      = qw($css $conf_file $jscript_funcs $jscript_for_hidden $dblabel $cross_tables $single_tables &get_single_table_parameters &make_single_table_fields &get_single_table_thesaurus &html_header &html_footer &arg_persist &pub_formating &get_pub_params &make_thesaurus $authorsJscript &makeAuthorsfields &AonFocus &add_author $maintitle);
	%EXPORT_TAGS = ();
	
	@EXPORT_OK   = qw();
}
    

# Les globales non exportees iront la
use vars      qw($css $conf_file $jscript_for_hidden $dblabel $cross_tables $single_tables &get_single_table_parameters &make_single_table_fields &get_single_table_thesaurus &html_header &html_footer &arg_persist &pub_formating &get_pub_params &make_thesaurus $authorsJscript &makeAuthorsfields &AonFocus &add_author $maintitle);

# Editor name
our $dblabel = 'Strepsiptera';

# Configuration file path for database connection
our $conf_file = '/etc/flow/strepseditor.conf';

our $maintitle = div({-style=>'width: 1000px; margin: 2% auto 1% auto;'}, table(Tr(td({-style=>'font-size: 20px; font-style: italic; font-weight: bold;'}, "$dblabel editor") . td({-style=>'padding-left: 20px;'}, a({-href=>"action.pl", -style=>'text-decoration: none; padding: 0;' }, img({-border=>0, -src=>'/Editor/home.png', -name=>"mM"}))))));

my $dbh = db_connection(get_connection_params($conf_file));

my ($group) = @{request_row("SELECT orthographe FROM noms WHERE ref_rang = (SELECT index from rangs WHERE ordre = (SELECT min(ordre) FROM noms AS n LEFT JOIN rangs AS r ON r.index = n.ref_rang));", $dbh)};
my $periods;
make_hash ($dbh, "SELECT index, en || coalesce(' [' || debut, '') || coalesce('-' || fin || ' Ma]', '') FROM periodes;", \$periods);
my $sexes;
make_hash ($dbh, "SELECT index, en FROM sexes;", \$sexes);
my $associations;
make_hash ($dbh, "SELECT index, en FROM types_association;", \$associations);

my $authors = request_tab("SELECT nom, prenom FROM auteurs ORDER BY nom;",$dbh,2);

$dbh->disconnect;

# stylesheet
our $css = " 
	body {
		margin: 0;
		color: #222222;
		font-family: Arial;
		background: #FDFDFD;
	}
	.wcenter {
		width: 1000px;
		min-width: 1000px;
		margin: 0 auto;
		background: transparent;
	}
	.PopupStyle {
		background: #FFFFFF;
		color: #222222;
		font-family: Arial;
		font-size: 12pt;
	}

	.popupTitle {
		background: #FFFFFF;
		color: #222222;
		font-weight: bold;
		font-family: Arial;
		font-size: 12pt;
	}
	.phantomTextField {
		background: #FFFFFF; 
		color:#222222; 
		border: 1px solid #999;
		padding-top: 4px;
		padding-left: 4px;
		padding-bottom: 2px;
		font-size: 12pt;
		font-family: Arial;
	}
	.autocomplete {
	    font-size: normal;
	    background: #FDFDFD;
	    width: 800px;
	    cursor: default;
	    overflow: auto;
	    overflow-x: hidden;
	    border: 1px solid #222222;
	}
	.autocomplete_item {
	    padding: 1px;
	    padding-left: 5px;
	    color: #222222;
	    width: 800px;
	}
	.autocomplete_item_highlighted {
	    padding: 1px;
	    padding-left: 5px;
	    color: crimson;
	    width: 800px;
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
			-head   =>meta({-http_equiv => 'Content-Type',
					-content => 'text/html; charset=UTF-8'}),
			#-style  =>{'src'=>'/style.css'},
			#-TEXT   =>'#ffffff',
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
										'title' => 'Country',
										'id' 	=> 'pays',
										'ref' 	=> 'ref_pays',
										'thesaurus' => 'pays',
										'addurl' => 'generique.pl?table=pays&new=1'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page_ori',
										'length' => 1
									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' => 'internal',
#										'title' => 'Updating page',
#										'id'   => 'page_maj',
#										'length' => 1
#									}, {
										'type' => 'internal',
										'title' => 'Regions / Localities',
										'id'   => 'precision',
										'length' => 80
									}
								],
						'obligatory' => ['pays', 'ref_pays'],
						'foreign_fields' => ['p.en'],
						'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays',
						'order' => 'ORDER BY p.en'
			},		
			
			'taxons_x_taxons_associes' => {	
						'title' => 'host(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Host',
										'id' 	=> 'taxon_associe',
										'ref' 	=> 'ref_taxon_associe',
										'thesaurus' => 'taxons_associes',
										'addurl' => 'generique.pl?table=taxons_associes&new=1'
									}, {
										'type' 	=> 'select',
										'title' => 'Association type',
										'id' 	=> 'ref_type_association',
										'values' => ['', sort {$associations->{$a} cmp $associations->{$b}} keys(%{$associations})],
										'default' => '1',
										'display' => 'none',
										'labels' => $associations,
										'addurl' => 'generique.pl?table=types_association&new=1'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_publication_ori'
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page_ori',
										'length' => 1
									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' => 'internal',
#										'title' => 'Updating page',
#										'id'   => 'page_maj',
#										'length' => 1
#									}, {
										'type' 	=> 'select',
										'title' => 'Sex',
										'id' 	=> 'ref_sexe',
										'values' => ['', sort {$sexes->{$a} cmp $sexes->{$b}} keys(%{$sexes})],
										'labels' => $sexes,
										'addurl' => 'generique.pl?table=sexes&new=1'
#									}, {
#										'type' => 'select',
#										'title' => 'certainty',
#										'id'   => 'certitude',
#										'values' => ['', 'certain', 'uncertain']
									}
								],
						'obligatory' => ['taxon_associe', 'ref_taxon_associe'],
						'foreign_fields' => ["coalesce((get_taxon_associe(ref_taxon_associe)).nom,'') || coalesce(' ' || (get_taxon_associe(ref_taxon_associe)).autorite,'') AS fullname"],
						'foreign_joins' => '',
						'order' => 'ORDER BY fullname'
			},

#			'taxons_x_plantes' => {	
#						'title' => 'host plant(s)',
#						'definition' => [
#									{	'type' 	=> 'foreign',
#										'title' => 'Host plant',
#										'id' 	=> 'plante',
#										'ref' 	=> 'ref_plante',
#										'thesaurus' => 'plantes',
#										'addurl' => 'generique.pl?table=plantes&new=1'
#									}, {
#										'type' => 'pub',
#										'title' => 'Original publication',
#										'id'   => 'ref_publication_ori'
#									}, {
#										'type' => 'internal',
#										'title' => 'Original citation page',
#										'id'   => 'page_ori',
#										'length' => 1
#									}, {
#										'type' => 'pub',
#										'title' => 'Updating publication',
#										'id'   => 'ref_publication_maj'
#									}, {
#										'type' => 'internal',
#										'title' => 'Updating page',
#										'id'   => 'page_maj',
#										'length' => 1
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
#						'title' => 'specimen image(s)',
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
#					
#			'taxons_x_clefs' => {	
#						'title' => 'identification key(s)',
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
#					
#			'noms_x_images' => {	
#						'title' => 'Type specimen image(s)',
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
					
			'taxons_x_vernaculaires' => {
						'title' => 'vernacular name(s)',
						'definition' => [
									{	'type' 	=> 'foreign',
										'title' => 'Vernacular name',
										'id' 	=> 'vernaculaire',
										'ref' 	=> 'ref_vernaculaire',
										'thesaurus' => 'vernaculaires',
										'addurl' => 'generique.pl?table=noms_vernaculaires&new=1'
									}, {
										'type' => 'pub',
										'title' => 'Original publication',
										'id'   => 'ref_pub'
									}, {
										'type' => 'internal',
										'title' => 'Original citation page',
										'id'   => 'page',
										'length' => 1
									}
								],
						'obligatory' => ['vernaculaire', 'ref_vernaculaire'],
						'foreign_fields' => ['nv.nom', 'nv.transliteration'],
						'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_vernaculaire',
						'order' => 'ORDER BY nom, transliteration'
			},
			
#			'taxons_x_periodes' => {	
#						'title' => 'geological period(s)',
#						'definition' => [
#									{	'type' 	=> 'select',
#										'title' => 'Geological period',
#										'id' 	=> 'ref_periode',
#										'values' => ['', sort { (split(/-/, (split(/\[/, $periods->{$a}))[1]))[0] <=> (split(/-/, (split(/\[/, $periods->{$b}))[1]))[0] } keys(%{$periods})],
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
#			}

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
						'length' => 80
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
						'thesaurus' => 'villes',
						'addurl' => 'generique.pl?table=villes',
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
						'thesaurus' => 'langages',
						'addurl' => 'generique.pl?table=langages',
						'length' => 80,
						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
					}, {	
						'type' 	=> 'foreign',
						'title' => 'Country',
						'id' 	=> 'pays',
						'ref' 	=> 'ref_pays',
						'thesaurus' => 'pays',
						'addurl' => 'generique.pl?table=pays',
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
#						'addurl' => 'generique.pl?table=types_agent_infectieux',
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
						'thesaurus' => 'pays',
						'addurl' => 'generique.pl?table=pays',
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
						'title' => 'Portuguese',
						'id'   => 'pt',
						'length' => 80
					}, {	
						'type' => 'internal',
						'title' => 'Chinese',
						'id'   => 'zh',
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
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1, 'pt'=>1, 'zh'=>1, 'tdwg_level'=>1, 'tdwg'=>1, 'parent'=>1}
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
#	'lieux_depot' => {	
#		'title' => 'Repository sites',
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
#						'thesaurus' => 'pays',
#						'addurl' => 'generique.pl?table=pays',
#						'length' => 80,
#						'message' => '<span style="color: navy; font-size: 20px;"> **</span>'
#					}
#				],
#		'obligatory' => {'nom'=>1, 'ref_pays'=>1}
#	},
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
#						'addurl' => 'generique.pl?table=regions',
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
#						'thesaurus' => 'pays',
#						'addurl' => 'generique.pl?table=pays',
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
#	'periodes' => {
#		'title' => 'Geological periods',
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
#	'types_type' => {
#		'title' => 'Type types',
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
					}
				],
		'obligatory' => {'en'=>1, 'fr'=>1, 'es'=>1, 'de'=>1}
	},
#	'images' => {
#		'title' => 'Images',
#		'definition' => [	
#					{	'type' => 'internal',
#						'title' => 'Image URL',
#						'id'   => 'url',
#						'length' => 80
#					}, {	
#						'type' => 'internal',
#						'title' => 'Thumbnail URL',
#						'id'   => 'icone_url',
#						'length' => 80
#					}
#				],
#		'obligatory' => {'url'=>1, 'icone_url'=>1}
#	},
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
									document.getElementById('parent').value = '-- Search --';
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
								document.getElementById('parent').value = '-- Search --';",
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
									document.getElementById('valide').value = '-- Search --';
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
									document.getElementById('valide').value = '-- Search --';
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
		${$singular} = "taxon associated to $group";
		${$label} = "coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') || coalesce('&nbsp;  <span style=\"color: grey;\">' || (get_taxon_associe(x.index)).famille || '</span>','') || coalesce('<span style=\"color: grey;\"> (' || (get_taxon_associe(x.index)).ordre || ')</span>','')";
		${$order} =  'ORDER BY (get_taxon_associe(x.index)).nom';	
		${$champs} = $single_tables->{$table};
	}
	elsif ($table eq 'plantes') { 
		${$title} = $single_tables->{$table}{'title'};
		${$singular} = 'Host plant';
		${$label} = "coalesce((get_host_plant(x.index)).nom,'') || coalesce(' ' || (get_host_plant(x.index)).autorite,'') || coalesce('&nbsp;  <span style=\"color: grey;\">' || (get_host_plant(x.index)).famille || '</span>','') || coalesce('<span style=\"color: grey;\"> (' || (get_host_plant(x.index)).ordre || ')</span>','')";
		${$order} =  'ORDER BY (get_host_plant(x.index)).nom';
		${$champs} = $single_tables->{$table};
	}
}

sub get_single_table_thesaurus {
	
	my ($dbc, $table, $retro, $onload, $values) = @_;

	if ($table eq 'editions') { 
		make_thesaurus("SELECT v.index, coalesce(v.nom, '') || coalesce(' (' || p.en || ')', '') FROM villes AS v LEFT JOIN pays AS p ON p.index = v.ref_pays ORDER BY v.nom, p.en;", 'villes', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'noms_vernaculaires') { 
		make_thesaurus("SELECT index, en, tdwg, tdwg_level FROM pays WHERE (tdwg_level in ('1', '2', '4') OR index in (SELECT index FROM pays WHERE tdwg_level = '3' and en not in (SELECT DISTINCT en FROM pays WHERE tdwg_level = '4'))) ORDER BY en;", 'tdwg', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT l.index, l.langage FROM langages AS l ORDER BY l.langage;", 'langages', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'agents_infectieux') { 
		make_thesaurus("SELECT index, en FROM types_agent_infectieux ORDER BY en;", 'types_agent_infectieux', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'villes') { 
		make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index in (SELECT index FROM pays AS p WHERE (SELECT reencodage(en) FROM pays AS p2 WHERE p2.parent = p.tdwg LIMIT 1) NOT LIKE '%'||reencodage(p.en)||'%' OR tdwg_level = '4') ORDER BY en;", 'pays', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'lieux_depot') { 
		make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index in (SELECT index FROM pays AS p WHERE (SELECT reencodage(en) FROM pays AS p2 WHERE p2.parent = p.tdwg LIMIT 1) NOT LIKE '%'||reencodage(p.en)||'%' OR tdwg_level = '4') ORDER BY en;", 'pays', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'localites') { 
		make_thesaurus("SELECT r.index, coalesce(r.nom, '') || coalesce(' (' || p.en || ')', '') FROM regions AS r LEFT JOIN pays AS p ON p.index = r.ref_pays ORDER BY r.nom, p.en;", 'regions', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'regions') { 
		make_thesaurus("SELECT index, en, tdwg_level FROM pays WHERE index in (SELECT index FROM pays AS p WHERE (SELECT reencodage(en) FROM pays AS p2 WHERE p2.parent = p.tdwg LIMIT 1) NOT LIKE '%'||reencodage(p.en)||'%' OR tdwg_level = '4') ORDER BY en;", 'pays', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}
	elsif ($table eq 'taxons_associes') { 
		my $rang = param('ref_rang') || $values->[0][0] || 10;
		make_thesaurus("SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') FROM taxons_associes AS x LEFT JOIN rangs AS r ON r.index = x.ref_rang WHERE r.ordre < (SELECT ordre FROM rangs WHERE index = $rang) ORDER BY (get_taxon_associe(x.index)).nom;", 'higher_taxons_associes', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT x.index, coalesce((get_taxon_associe(x.index)).nom,'') || coalesce(' ' || (get_taxon_associe(x.index)).autorite,'') FROM taxons_associes AS x ORDER BY (get_taxon_associe(x.index)).nom;", 'taxons_associes', '$intitule = $row->[1];', $retro, $onload, $dbc);
	}	
	elsif ($table eq 'plantes') { 
		my $rang = param('ref_rang') || $values->[0][0] || 10;
		make_thesaurus("SELECT x.index, coalesce((get_host_plant(x.index)).nom,'') || coalesce(' ' || (get_host_plant(x.index)).autorite,'') FROM taxons_associes AS x LEFT JOIN rangs AS r ON r.index = x.ref_rang WHERE r.ordre < (SELECT ordre FROM rangs WHERE index = $rang) ORDER BY (get_host_plant(x.index)).nom;", 'higher_plantes', '$intitule = $row->[1];', $retro, $onload, $dbc);
		make_thesaurus("SELECT x.index, coalesce((get_host_plant(x.index)).nom,'') || coalesce(' ' || (get_host_plant(x.index)).autorite,'') FROM taxons_associes AS x ORDER BY (get_host_plant(x.index)).nom;", 'plantes', '$intitule = $row->[1];', $retro, $onload, $dbc);
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
				$default = ${$retro_hash}->{$_->{'thesaurus'}.${$values}->[0][$iter]} || '-- Search --';
				push(@{${$hiddens}}, [$ref, ${$values}->[0][$iter]]);
				Delete($ref);
			}
			else {
				$default = param($id);
				push(@{${$hiddens}}, [$ref, param($ref)]);
				Delete($ref);
			}
			
			my $field = textfield(
				-class => 'phantomTextField', 
				-name=> "$id", 
				-size=>$_->{'length'} || 70, 
				-value => $default, 
				-id => "$id", 
				-onFocus => "	if(this.value == '-- Search --') { this.value = ''; } AutoComplete_ShowDropdown(this.getAttribute('id'));",
				-onBlur => "	if(!this.value) { this.value = '-- Search --'; document.Form.$ref.value = ''; } ",
				-onChange=>"	if(!this.value || this.value == '-- Search --') { document.Form.$ref.value = ''; }
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
			
			${$tablerows} .= Tr({-id=>$_->{'id'}.'_row'}, td(span({-style=>'margin-right: 10px;'}, $_->{'title'} . $mark)), td(popup_menu(-class=>'phantomTextField', -style=>'padding: 0;', -name=>$_->{'id'}, -id=>$_->{'id'}, -default=>$default, values=>$_->{'values'}, -labels=>$_->{'labels'}, -onChange=>$_->{'onchange'}) . $message . $more) );
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
			
			${$tablerows} .= Tr({-id=>$_->{'id'}.'_row'}, td(span({-style=>'margin-right: 10px;'}, $_->{'title'} . $mark)), td({-colspan=>1}, textfield(-class=>'phantomTextField', -name=>$_->{'id'}, -id=>$_->{'id'}, -default=>$default, -size=>$l, -onChange=>$_->{'onchange'}) . $message) );
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
		$hashlabels .= $hash.'["'.$intitule.'"] = ' . $row->[0] . ";\n";
	}
	${$onload} .= "var $hash = {};\n$hashlabels";
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
			
			my $dbc = db_connection(get_connection_params($conf_file));
						
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
						style='font-size: 15px; background: white; color: grey; border: 1px solid #999; width: 150px; padding: 2px;' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 0; width: 150px; z-index: 2;'>
					<input 	type='text' 
						autocomplete='off' 
						name='".$prefix."AFN$i' 
						id='".$prefix."AFN$i' 
						style='font-size: 15px; background: none; border: 1px solid #999; width: 150px; padding: 2px;' 
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
						style='font-size: 15px; background: white; color: grey; border: 1px solid #999; width: 150px; padding: 2px;' 
						disabled 
					/>
				</div>
				
				<div style='position: absolute; top: 0; left: 155px; width: 150px; z-index: 2;'>
					<input autocomplete='off' type='text' 
					name='".$prefix."ALN$i' 
					id='".$prefix."ALN$i'  
					style='font-size: 15px; background: none; border: 1px solid #999; width: 150px; padding: 2px;' 
					value=".'"'.param($prefix."ALN$i").'"'.
					"onfocus=\"if(this.form.".$prefix."ALNsug$i.value == 'Initials') { this.form.".$prefix."ALN$i.disabled = true; }
						  clear_sugs('$prefix', $i);
						  availableCompletion('$prefix', 'none');
						  \" 
					onBlur=\"ToUpperFirst('$prefix', $i);\"
					/>
				</div>
				
				<div 	id='".$prefix."NEXTbtn$i' style='position: absolute; top: 2px; left:315px; z-index: 3; display: none;' 
					onClick=\"	clear_values('$prefix', $i);
							get_next_author('$prefix', $i)\" 
					onMouseOver=\"testAvailability('$prefix', $i)\"
				>
					<img src='/Editor/next.png' border='0' onMouseOver=\"this.style.cursor = 'pointer';\">
				</div>				
				
				<div 	id='".$prefix."SUGbtn$i' style='position: absolute; top: 2px; left:380px; z-index: 3; display: none;' 
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
	$name =~ s/^ +//g;
	$name =~ s/ +$//g;
	$prenom =~ s/'/\\'/g;
	$prenom =~ s/^ +//g;
	$prenom =~ s/ +$//g;
	
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

1;
