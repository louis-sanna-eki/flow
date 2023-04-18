#!/usr/bin/perl

use strict;
#use warnings;
use DBI;
use CGI qw( -no_xhtml :standard start_ul); # make html 4.0 card
use CGI::Carp qw( fatalsToBrowser ); # display errors in browser
use Getopt::Long;
use utf8;
# jompo
use open ':std', ':encoding(UTF-8)';
# jompo added but removed as replace ~~ by grep
#no warnings 'experimental::smartmatch';
use DBCommands qw(get_connection_params db_connection);

my $fullhtml;
my $maprest = "https://edit.africamuseum.be/edit_wp5/v1/areas.php";

# Gets parameters
################################################################
my ($dbase, $lang, $id, $card, $alph, $from, $to, $rank, $search, $searchtable, $searchid, $mode, $privacy, $limit);

#jompo: j'ai remplace le "=" par ":" dans l'option search because message d'erreurs quand l'option manquait ;-)
GetOptions (	'db=s' => \$dbase, 'lang=s' => \$lang, 'id=s' => \$id, 'card=s' => \$card, 'alph=s' => \$alph, 'from=i' => \$from,
		'to=i' => \$to, 'rank=s' => \$rank, 'search:s' => \$search, 'searchtable=s' => \$searchtable, 'searchid=i' => \$searchid, 'mode=s' => \$mode,
		'privacy=s' => \$privacy, 'limit=s' => \$limit );


#unless ($dbase) 	{ $dbase = url_param('db') }

my %labels = (	'db' => $dbase, 'lang' => $lang, 'id' => $id, 'card' => $card, 'alph' => $alph, 'from' => $from, 'to' => $to,
		'rank' => $rank, 'search' => "$search", 'searchtable' => "$searchtable", 'searchid' => $searchid, 'mode' => $mode, 'privacy' => $privacy,
		'limit' => $limit);
		
#if ($mode) { $mode = "&mode=$mode" }
#if ($privacy) { $privacy = "&privacy=$privacy" }

# Gets config
################################################################
my ($config_file, $synop_conf, $pdfdir);

if ($dbase eq 'flow') { $config_file = '/etc/flow/flowexplorer.conf'; $synop_conf = '/etc/flow/floweditor.conf'; $pdfdir = 'flowpdf'; }
elsif ($dbase eq 'cool') { $config_file = '/etc/flow/coolexplorer.conf'; $synop_conf = '/etc/flow/cooleditor.conf'; $pdfdir = 'coolpdf'; }
elsif ($dbase eq 'psylles') { $config_file = '/etc/flow/psyllesexplorer.conf'; $synop_conf = '/etc/flow/psylleseditor.conf'; $pdfdir = 'psyllespdf'; }
elsif ($dbase eq 'aradides') { $config_file = '/etc/flow/aradides.conf'; $synop_conf = '/etc/flow/aradides.conf'; $pdfdir = 'aradpdf'; }
elsif ($dbase eq 'coleorrhyncha') { $config_file = '/etc/flow/peloridexplorer.conf'; $synop_conf = '/etc/flow/pelorideditor.conf'; $pdfdir = 'pelopdf'; }
elsif ($dbase eq 'strepsiptera') { $config_file = '/etc/flow/strepsexplorer.conf'; $synop_conf = '/etc/flow/strepseditor.conf'; }
elsif ($dbase eq 'aleurodes') { $config_file = '/etc/flow/aleurodsexplorer.conf'; $synop_conf = '/etc/flow/aleurodseditor.conf'; }
elsif ($dbase eq 'tingides') { $config_file = '/etc/flow/tingides.conf'; $synop_conf = '/etc/flow/tingides.conf'; }
elsif ($dbase eq 'tessaratomidae') { $config_file = '/etc/flow/tessaratomidae.conf'; $synop_conf = '/etc/flow/tessaratomidae.conf'; }
elsif ($dbase eq 'lucanidae') { $config_file = '/etc/flow/lucanidae.conf'; $synop_conf = '/etc/flow/lucanidae.conf'; }
elsif ($dbase eq 'brentidae') { $config_file = '/etc/flow/brentidae.conf'; $synop_conf = '/etc/flow/brentidae.conf'; }
elsif ($dbase eq 'diptera') { $config_file = '/etc/flow/diptera.conf'; $synop_conf = '/etc/flow/diptera.conf'; }
elsif ($dbase eq 'test') { $config_file = '/etc/flow/testexplorer.conf'; $synop_conf = '/etc/flow/testeditor.conf'; }
elsif ($dbase eq 'hefo') { $config_file = '/etc/flow/hefo.conf'; $synop_conf = '/etc/flow/hefo.conf'; }
elsif ($dbase eq 'cipa') { $config_file = '/etc/flow/cipaexplorer.conf'; }
elsif ($dbase eq 'dbtnt') { $config_file = '/etc/flow/dbtntexplorer.conf'; }

my %scripts = ( 
	'dbtnt'		=> '/cgi-bin/dbtntexplorer.pl?',
	'flow'		=> '?page=explorer&',
	'cool'		=> '/cool/database.php?',
	'psylles'	=> '/psyllist?',
	'aradides'	=> '/cgi-bin/aradidae.pl?',
	'coleorrhyncha'	=> '/cgi-bin/coleorrhyncha.pl?',
	'strepsiptera'	=> '/cgi-bin/strepsiptera.pl?',
	'cerambycidae'	=> '/cgi-bin/cerambycidae.pl?',
	'aleurodes'	=> '/whiteflies?',
	'tingides'	=> '/cgi-bin/Tingidae/tingidae.pl?',
	'tessaratomidae'=> '/cgi-bin/Tessaratomidae/tessaratomidae.pl?',
	'lucanidae'	=> '/cgi-bin/Lucanidae/lucanidae.pl?',
	'brentidae'	=> '/cgi-bin/Brentidae/brentidae.pl?',
	'diptera'	=> '/cgi-bin/diptera/diptera.pl?',
	'cipa'		=> '/cgi-bin/cipa/cipaexplorer.pl?',
	'hefo' => '/cgi-bin/hefo/hefo.pl?',
	'test'		=> '/cgi-bin/testexplorer.pl?'
);

my %states = (

	# They are used to call the subroutine that builds the corresponding card
	'top'          => \&topics_list, # goes to top list
	'families'     => \&families_list, # goes to families list
	'subfamilies'   => \&subfamilies_list, # goes to families list
	'tribes'   => \&tribes_list, # goes to families list
	'genera'       => \&genera_list, # goes to genera list
	'subgenera'     => \&genera_list, # goes to subgenera list
	'speciess' 	=> \&species_list, # goes to species list
	'subspeciess' 	=> \&species_list, # goes to subspecies list
	'fossils' 	=> \&fossils_list, # goes to species list
	'authors'      => \&authors_list, # goes to authors list
	'publications' => \&publications_list, # goes to publications list
	'names'        => \&names_list, # goes to names list
	'repositories' => \&repositories_list, # goes to repositories list
	'eras'         => \&eras_list, #  goes to eras list
	'countries'    => \&countries_list, # goes to countries list
	'regions'	=> \&regions_list, # goes to biogeographic regions list
	'plants'       => \&associations, # goes to plants list
	'associates'	=> \&associations,
	'bioInteract'	=> \&associations,
	'interactions'	=> \&associations,
	'vernaculars'  => \&vernaculars,
	'makeboard'    => \&makeboard, # makes the board
	'board'        => \&board, # goes to board
	'agents'       => \&agents_list, # goes to agents list
	'editions'     => \&editions_list, # goes to editions list
	'habitats'     => \&habitats_list, # goes to habitats list
	'localities'   => \&localities_list, # goes to localities list
	'captures'     => \&captures_list, # goes to capture technics list
	'images'       => \&images_list, 
	'types'       => \&types_list,
	'id_keys'      => \&keys_list,
	'morphcards'  => \&morphcards_list,
	'publist'  => \&publist,
	'updates'  => \&get_last_updates,

	'family'       => \&family_card, # goes to family card
	'subfamily'   => \&subfamily_card, # goes to subfamily card
	'supertribe'  => \&supertribe_card, # goes to tribe card
	'tribe'       => \&tribe_card, # goes to tribe card
	'taxon'       => \&taxon_card, # goes to family card
	'genus'        => \&genus_card, # goes to genus card
	'subgenus'     => \&subgenus_card, # goes to genus card
	'species'      => \&species_card, # goes to species card
	'subspecies'   => \&subspecies_card, # goes to subspecies card
	'variety'   	=> \&variety_card, # goes to variety card
	'author'       => \&author_card, # goes to author card
	'publication'  => \&publication_card, # goes to publications card
	'name'         => \&name_card, # goes to name card
	'repository'   => \&repository_card, # goes to repository card
	'era'          => \&era_card, # goes to era card
	'country'      => \&country_card, # goes to country card
	'image'	       => \&image_card, # goes to country card
	'region'       => \&region_card, # goes to region card
	'plant'        => \&plant_card, # goes to plant card
	'vernacular'   => \&vernacular_card, # goes to plant card
	'associate'	=> \&association,
	'agent'        => \&agent_card, # goes to agent card
	'edition'      => \&edition_card, # goes to edition card
	'habitat'      => \&habitat_card, # goes to habitat card
	'locality'     => \&locality_card, # goes to locality card
	'capture'      => \&capture_card, # goes to capture technic card
	'type'       => \&type_card,
	'searching'    => \&search_results, # display search string matching results
	'autotext'    => \&autotext, # display autogenerated texts for a taxon
	'classification'	=> \&classification # display autogenerated classification of all Fulgoromorpha
);

# Loads topics list contained in the configuration file
#my @topics = qw(families genera speciess names authors publications plants countries board);
my @topics;

my $totop;
my $cross_tables = [];
my $sexes;
my $conservation_status;
my $observ_types;
my $periods;
my $frekens;
my $typeTypes;
my $depotTypes;
my $agents;
my $confirm;
my $habitats;
my $captures;

# Main
################################################################
my @msg;
unless ( exists $scripts{$dbase} ) { push(@msg, "db = $dbase"); die; }
unless ( exists $states{$card} ) {  push(@msg, "card = $card"); }

# Loads connection and language data
my $config = {};
my $trans;
unless ( scalar @msg ) { 
	
	# read config file
	if ( open(CONFIG, $config_file) ) {
		while (<CONFIG>) {
			chomp;                 # no newline
			s/#.*//;               # no comments 
			s/^\s+//;              # no leading white
			s/\s+$//;              # no trailing white
			next unless length;    # anything left?
			my ($option, $value) = split(/\s*=\s*/, $_, 2);
			$config->{$option} = $value;
		}
		close(CONFIG);
	}
	else {
		die "No configuration file could be found \n";
	}
	
	@topics = split(' ', $config->{DEFAULT_TOPICS});
	unless(scalar(@topics)) { @topics = split(' ', $config->{EXPLORER_TOPICS}); }
	
	unless ( $trans = read_lang($config) ) { error_msg( "lang = $lang" ); } 
	else { 
		unless ($dbase eq 'cool' or $dbase eq 'flow' or $dbase eq 'flow2' or $dbase eq 'strepsiptera') {
			#$totop = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=top"}, $trans->{'topics'}->{$lang});
		}
		
		if ($dbase eq 'cipa') {
			
			my $dbc = db_connection($config);
			
			make_hash ($dbc, "SELECT index, $lang FROM sexes;", \$sexes);
			make_hash ($dbc, "SELECT index, $lang FROM etats_conservation;", \$conservation_status);
			make_hash ($dbc, "SELECT index, $lang FROM types_observation;", \$observ_types);
			make_hash ($dbc, "SELECT index, $lang FROM periodes;", \$periods);
			make_hash ($dbc, "SELECT index, $lang FROM niveaux_frequence;", \$frekens);
			make_hash ($dbc, "SELECT index, $lang FROM types_type;", \$typeTypes);
			make_hash ($dbc, "SELECT index, $lang FROM types_depot;", \$depotTypes);
			make_hash ($dbc, "SELECT a.index, a.$lang, t.$lang FROM agents_infectieux AS a LEFT JOIN types_agent_infectieux AS t ON t.index = a.ref_type_agent_infectieux;", \$agents);
			make_hash ($dbc, "SELECT index, $lang FROM niveaux_confirmation;", \$confirm);
			make_hash ($dbc, "SELECT index, $lang FROM habitats;", \$habitats);
			make_hash ($dbc, "SELECT index, $lang FROM modes_capture;", \$captures);
				
			$cross_tables = {	
						'taxons_x_regions' => {	
									'title' => 'Taxon x region',
									'ordre' => 1,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Region',
													'id' 	=> 'region',
													'ref' 	=> 'ref_region',
													'thesaurus' => 'regions',
													'addurl' => 'generique.pl?table=regions',
													'card' => 'region'
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
													'class' => 'name',
													'card' => 'name'
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
													'class' => 'name',
													'card' => 'name'
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
													'class' => 'name',
													'card' => 'name'
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
						
						'taxons_x_regions_x_agents_infectieux' => {
									'title' => 'Taxon x region x infectious agent',
									'ordre' => 2,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Region',
													'id' 	=> 'region',
													'ref' 	=> 'ref_region',
													'thesaurus' => 'regions',
													'addurl' => 'generique.pl?table=regions',
													'card' => 'region'
												}, {
													'type' 	=> 'select',
													'title' => 'Infectious agent',
													'id' 	=> 'ref_agent_infectieux',
													'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
													'labels' => $agents,
													'addurl' => 'generique.pl?table=agents_infectieux',
													'card' => 'agent'
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
									'foreign_fields' => ['r.nom', "a.$lang"],
									'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
									'order' => "ORDER BY r.nom, a.$lang"
						},
						
						'taxons_x_regions_x_habitats' => {
									'title' => 'Taxon x region x habitat',
									'ordre' => 3,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Region',
													'id' 	=> 'region',
													'ref' 	=> 'ref_region',
													'thesaurus' => 'regions',
													'addurl' => 'generique.pl?table=regions',
													'card' => 'region'
												}, {
													'type' 	=> 'select',
													'title' => 'Habitat',
													'id' 	=> 'ref_habitat',
													'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
													'labels' => $habitats,
													'addurl' => 'generique.pl?table=habitats',
													'card' => 'habitat'
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
									'foreign_fields' => ['r.nom', "h.$lang"],
									'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
									'order' => "ORDER BY r.nom, h.$lang"
						},
						
						'taxons_x_regions_x_modes_capture' => {
									'title' => 'Taxon x region x capture mode',
									'ordre' => 4,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Region',
													'id' 	=> 'region',
													'ref' 	=> 'ref_region',
													'thesaurus' => 'regions',
													'addurl' => 'generique.pl?table=regions',
													'card' => 'region'
												}, {
													'type' 	=> 'select',
													'title' => 'Capture mode',
													'id' 	=> 'ref_mode_capture',
													'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
													'labels' => $captures,
													'addurl' => 'generique.pl?table=modes_capture',
													'card' => 'capture'
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
									'foreign_fields' => ['r.nom', "c.$lang"],
									'foreign_joins' => 'LEFT JOIN regions AS r ON r.index = tx.ref_region LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
									'order' => "ORDER BY r.nom, c.$lang"
						},
						
						'taxons_x_pays' => {	
										'title' => 'Taxon x country',
										'ordre' => 5,
										'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Country',
													'id' 	=> 'pays',
													'ref' 	=> 'ref_pays',
													'thesaurus' => 'pays',
													'addurl' => 'generique.pl?table=pays',
													'card' => 'country'
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
													'type' => 'pub',
													'title' => 'Updating publication',
													'id'   => 'ref_publication_maj'
												}, {
													'type' => 'internal',
													'title' => 'Updating page',
													'id'   => 'page_maj',
													'length' => 1
												}, {
													'type' 	=> 'foreign',
													'title' => 'Male name',
													'id' 	=> 'nom_male',
													'ref' 	=> 'ref_nom_specifique_male',
													'thesaurus' => 'noms',
													'addurl' => 'typeSelect.pl?action=add&type=sciname',
													'class' => 'name',
													'card' => 'name'
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
													'class' => 'name',
													'card' => 'name'
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
													'class' => 'name',
													'card' => 'name'
												}, {
													'type' => 'pub',
													'title' => 'Unknown sex publication',
													'id'   => 'ref_publication_sexe_inconnu',
												}, {	
													'type' => 'internal',
													'title' => 'Minimum altitude',
													'id'   => 'altitude_min',									
												}, {	
													'type' => 'internal',
													'title' => 'Maximum altitude',
													'id'   => 'altitude_max',
												}, {	
													'type' => 'internal',
													'title' => 'Minimum minimum altitude',
													'id'   => 'altitude_min_min',
												}, {	
													'type' => 'internal',
													'title' => 'Maximum maximum altitude',
													'id'   => 'altitude_max_max',
												}, {	
													'type' => 'internal',
													'title' => 'abundance epoch',
													'id'   => 'epoque_abondance',
												}
											],
									'obligatory' => ['pays', 'ref_pays'],
									'foreign_fields' => ["p.$lang"],
									'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays',
									'order' => "ORDER BY p.$lang"
						},
						
						'taxons_x_pays_x_agents_infectieux' => {
									'title' => 'Taxon x country x infectious agent',
									'ordre' => 6,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Country',
													'id' 	=> 'pays',
													'ref' 	=> 'ref_pays',
													'thesaurus' => 'pays',
													'addurl' => 'generique.pl?table=pays',
													'card' => 'country'
												}, {
													'type' 	=> 'select',
													'title' => 'Infectious agent',
													'id' 	=> 'ref_agent_infectieux',
													'values' => ['', sort {$agents->{$a} cmp $agents->{$b}} keys(%{$agents})],
													'labels' => $agents,
													'addurl' => 'generique.pl?table=agents_infectieux',
													'card' => 'agent'
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
									'foreign_fields' => ["p.$lang", "a.$lang"],
									'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN agents_infectieux AS a ON a.index = tx.ref_agent_infectieux ',
									'order' => "ORDER BY p.$lang, a.$lang"
						},
						
						'taxons_x_pays_x_habitats' => {
									'title' => 'Taxon x country x habitat',
									'ordre' => 7,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Country',
													'id' 	=> 'pays',
													'ref' 	=> 'ref_pays',
													'thesaurus' => 'pays',
													'addurl' => 'generique.pl?table=pays',
													'card' => 'country'
												}, {
													'type' 	=> 'select',
													'title' => 'Habitat',
													'id' 	=> 'ref_habitat',
													'values' => ['', sort {$habitats->{$a} cmp $habitats->{$b}} keys(%{$habitats})],
													'labels' => $habitats,
													'addurl' => 'generique.pl?table=habitats',
													'card' => 'habitat'
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
									'foreign_fields' => ["p.$lang", "h.$lang"],
									'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN habitats AS h ON h.index = tx.ref_habitat ',
									'order' => "ORDER BY p.$lang, h.$lang"
						},
						
						'taxons_x_pays_x_modes_capture' => {
									'title' => 'Taxon x country x capture mode',
									'ordre' => 8,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Country',
													'id' 	=> 'pays',
													'ref' 	=> 'ref_pays',
													'thesaurus' => 'pays',
													'addurl' => 'generique.pl?table=pays',
													'card' => 'country'
												}, {
													'type' 	=> 'select',
													'title' => 'Capture mode',
													'id' 	=> 'ref_mode_capture',
													'values' => ['', sort {$captures->{$a} cmp $captures->{$b}} keys(%{$captures})],
													'labels' => $captures,
													'addurl' => 'generique.pl?table=modes_capture',
													'card' => 'capture'
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
									'foreign_fields' => ["p.$lang", "c.$lang"],
									'foreign_joins' => 'LEFT JOIN pays AS p ON p.index = tx.ref_pays LEFT JOIN modes_capture AS c ON c.index = tx.ref_mode_capture ',
									'order' => "ORDER BY p.$lang, c.$lang"
						},
						
						'taxons_x_localites' => {	
									'title' => 'Taxon x locality',
									'ordre' => 9,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Locality',
													'id' 	=> 'localite',
													'ref' 	=> 'ref_localite',
													'thesaurus' => 'localites',
													'addurl' => 'generique.pl?table=localites',
													'card' => 'locality'
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
									'title' => 'Taxon x geological period',
									'ordre' => 10,
									'definition' => [
												{	'type' 	=> 'select',
													'title' => 'Geological period',
													'id' 	=> 'ref_periode',
													'values' => ['', sort {$periods->{$a} cmp $periods->{$b}} keys(%{$periods})],
													'labels' => $periods,
													'addurl' => 'generique.pl?table=periodes',
													'card' => 'era'
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
									'foreign_fields' => ["p.$lang"],
									'foreign_joins' => 'LEFT JOIN periodes AS p ON p.index = tx.ref_periode',
									'order' => "ORDER BY p.$lang"
						},
						
						'noms_x_types' => {
									'title' => 'Name x type',
									'ordre' => 11,
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
													'addurl' => 'generique.pl?table=lieux_depot',
													'card' => 'repository'
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
									'foreign_joins' => 'LEFT JOIN lieux_depot AS ld ON ld.index = tx.ref_lieux_depot LEFT JOIN types_type AS tt ON tt.index = tx.ref_type',
									'order' => "ld.nom, tt.$lang"
						},
						
						'taxons_x_lieux_depot' => {
									'title' => 'Taxon x repository',
									'ordre' => 12,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Deposit place',
													'id' 	=> 'lieux_depot',
													'ref' 	=> 'ref_lieux_depot',
													'thesaurus' => 'lieux_depot',
													'addurl' => 'generique.pl?table=lieux_depot',
													'card' => 'repository'
												}, {
													'type' 	=> 'foreign',
													'title' => 'Name used',
													'id' 	=> 'nom_utilise',
													'ref' 	=> 'ref_nom_utilise',
													'thesaurus' => 'noms',
													'addurl' => 'typeSelect.pl?action=add&type=sciname',
													'class' => 'name',
													'card' => 'name'
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

						'taxons_x_vernaculaires' => {
									'title' => 'Taxon x vernacular name',
									'ordre' => 99,
									'definition' => [
												{	'type' 	=> 'foreign',
													'title' => 'Vernacular name',
													'id' 	=> 'vernaculaire',
													'ref' 	=> 'ref_vernaculaire',
													'thesaurus' => 'vernaculaires',
													'addurl' => 'generique.pl?table=noms_vernaculaires',
													'class' => 'name',
													'card' => 'name'
												}, {
													'type' => 'pub',
													'title' => 'Original publication',
													'id'   => 'ref_pub',
												}, {
													'type' => 'internal',
													'title' => 'Original citation page',
													'id'   => 'page',
													'length' => 1
												}
											],
									'obligatory' => ['nom', 'ref_nom'],
									'foreign_fields' => ['nv.nom', 'nv.transliteration'],
									'foreign_joins' => 'LEFT JOIN noms_vernaculaires AS nv ON nv.index = tx.ref_vernaculaire',
									'order' => 'ORDER BY nom, transliteration'
						}	
			};
			
			$dbc->disconnect;
		}
		my $argus;
		if($card eq 'associate' or $card eq 'associates') { $argus = 'associate' }
		elsif($card eq 'subgenera') { $argus = 'subgenus' }
		elsif($card eq 'subspeciess') { $argus = 'subspecies' }
		$states{$card}->($argus);
		exit;
	}
}
else { error_msg( join(br, @msg) );}
exit;

############# Functions ############################################################################################################################################

sub getPDF {
	my ($index) = @_;

#	if (open(TEST, "/var/www/html/Documents/$pdfdir/$index.pdf") ) {
	if (open(TEST, "/var/www/html/Documents/$pdfdir/$index.pdf") ) {
		return ' ' . a({-href=>"/$pdfdir/$index.pdf", -target=>"_blank" }, img({-style=>'border: 0; height: 12px;', -src=>"/explorerdocs/pdflogo.jpg"}));
	}
	else {
		return '';
	}
	
}

# Error message
#################################################################
sub error_msg {
	my ($msg) = @_;
	my $error = $trans->{'UNK_P'}->{$lang} || 'Unknown parameter';
	$fullhtml = 	div({-class=>'content'},
				div({-class=>'subject'}, $error),
				$msg
			);
		
	print $fullhtml;
	exit;
}

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

sub display_cross_tables {
	
	my ($xid, $dbc) = @_;
	my $retro_hash;
	my $txlist;
			
	foreach my $cross (sort {$cross_tables->{$a}{'ordre'} <=> $cross_tables->{$b}{'ordre'}} keys(%{$cross_tables})) {
		
		my $tables2;
		@{$tables2} = split(/_x_/, $cross);
		my $table1 = shift(@{$tables2});
		my $field1;
		if ($table1 eq 'taxons') { $field1 = 'ref_taxon' }
		elsif ($table1 eq 'noms') { $field1 = 'ref_nom' }
		
		my $foreign_fields = [];
		my ($foreign_joins, $order);
		if ( $cross eq 'taxons_x_pays' ) {
									
			make_thesaurus("SELECT index, $lang, tdwg_level FROM pays ORDER BY tdwg_level DESC, $lang;", 'pays', '$intitule = $row->[1];', \$retro_hash, $dbc);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, $dbc);
							
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_pays_x_agents_infectieux' or $cross eq 'taxons_x_pays_x_habitats' or $cross eq 'taxons_x_pays_x_modes_capture' ) {
									
			make_thesaurus("SELECT index, $lang, tdwg_level FROM pays ORDER BY tdwg_level DESC, $lang;", 'pays', '$intitule = $row->[1];', \$retro_hash, $dbc);
							
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}	
		elsif ( $cross eq 'taxons_x_plantes' ) {
			
						
			make_thesaurus("SELECT index, get_host_plant_name(index) AS fullname FROM plantes ORDER BY fullname;", 'plantes', '$intitule = $row->[1];', \$retro_hash, $dbc);
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_images' or $cross eq 'noms_x_images' ) {
									
			make_thesaurus("SELECT index, substring(url from \'[^/]+\$\') FROM images ORDER BY url;", 'images', '$intitule = $row->[1];', \$retro_hash, $dbc);
		}
		elsif ( $cross eq 'taxons_x_vernaculaires' ) {
					
						
			make_thesaurus("SELECT nv.index, nv.nom, nv.transliteration, l.langage, p.$lang 
					FROM noms_vernaculaires AS nv
					LEFT JOIN pays AS p ON p.index = nv.ref_pays
					LEFT JOIN langages AS l ON l.index = nv.ref_langage
					ORDER BY nv.nom, nv.transliteration, l.langage, p.$lang, remarques;",
					'vernaculaires',
					"\$intitule .= \$row->[1]; if(\$row->[2]) { \$intitule .= ' ('.\$row->[2].')'; } if(\$row->[4]) { \$intitule .= ' in '.\$row->[4]; } if(\$row->[3]) { \$intitule .= ' ('.\$row->[3].')'; }",
					\$retro_hash, 
					$dbc);
				
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_localites' ) {
									
			# thesauri definition for foreign keys
			make_thesaurus(
				"SELECT l.index, l.nom, r.nom, p.$lang 
				 FROM localites AS l 
				 LEFT JOIN regions AS r ON r.index = l.ref_region 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY l.nom, r.nom, p.$lang;",
				 'localites', 
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2]; } if(\$row->[3]) { \$row->[3] = ', '.\$row->[3].')'; } else { \$row->[3] = ')'; } \$intitule = \$row->[1].\$row->[2].\$row->[3];", 
				 \$retro_hash,
				 $dbc
			);
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_lieux_depot' or $cross eq 'noms_x_types' ) {
			
						
			# thesauri definition for foreign keys
			make_thesaurus(
				"SELECT l.index, nom, $lang 
				 FROM lieux_depot AS l 
				 LEFT JOIN pays AS p ON p.index = l.ref_pays 
				 ORDER BY nom, $lang;",
				 'lieux_depot',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 $dbc
			);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, $dbc);
			
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_periodes' ) {
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_regions' ) {
						
			# thesauri definition for foreign keys
			make_thesaurus(
				"SELECT r.index, nom, $lang
				 FROM regions AS r 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY nom, $lang;",
				 'regions',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 $dbc
			);
			make_thesaurus('SELECT index, orthographe, autorite FROM noms_complets ORDER BY orthographe, autorite;', 'noms', '$intitule = $row->[1]." ".$row->[2];', \$retro_hash, $dbc);
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
		elsif ( $cross eq 'taxons_x_regions_x_agents_infectieux' or $cross eq 'taxons_x_regions_x_habitats' or $cross eq 'taxons_x_regions_x_modes_capture' ) {
									
			# thesauri definition for foreign keys
			make_thesaurus(
				"SELECT r.index, nom, $lang 
				 FROM regions AS r 
				 LEFT JOIN pays AS p ON p.index = r.ref_pays 
				 ORDER BY nom, $lang;",
				 'regions',
				 "if(\$row->[2]) { \$row->[2] = ' ('.\$row->[2].')'; } \$intitule = \$row->[1].\$row->[2];",
				 \$retro_hash, 
				 $dbc
			);
			
			# elements needed to sort relations in case of update action
			$foreign_fields = $cross_tables->{$cross}->{'foreign_fields'};
			$foreign_joins = $cross_tables->{$cross}->{'foreign_joins'};
			$order = $cross_tables->{$cross}->{'order'};	
		}
				
		# page title
		my $ptitle = $cross_tables->{$cross}->{'title'};
		# fields definitions
		my $table_definition = $cross_tables->{$cross}->{'definition'};
		# obligatory fields
		my $obligatory = $cross_tables->{$cross}->{'obligatory'};
		
		my $table_fields;
		foreach (@{$table_definition}) {
			if ($_->{'type'} eq 'foreign') { push(@{$table_fields}, $_->{'ref'}); }
			else { push(@{$table_fields}, $_->{'id'}); }
		}	
		
		my $virgule;
		if (scalar(@{$foreign_fields})) { $virgule = ','; }
		
		my $req;
		if ($field1 eq 'ref_nom') {
			$order = join(', ', ('nc.orthographe, nc.autorite', $order));
			$req = "SELECT tx." . join(', tx.', @{$table_fields}) . $virgule . join(', ', @{$foreign_fields}) . ", nc.orthographe, nc.autorite 
				FROM $cross AS tx 
				$foreign_joins 
				LEFT JOIN noms_complets AS nc ON nc.index = tx.ref_nom
				WHERE $field1 in (select distinct ref_nom from taxons_x_noms where ref_taxon = $xid) 
				OR $field1 in (select distinct ref_nom_cible from taxons_x_noms where ref_taxon = $xid) 
				ORDER BY ($order);";
		}
		else {
			$req = "SELECT tx." . join(', tx.', @{$table_fields}) . $virgule . join(', ', @{$foreign_fields}) . " FROM $cross AS tx $foreign_joins WHERE $field1 = $xid $order;";
		}
		
		my $preexist = request_tab($req, $dbc, 2);
		
		if (scalar(@{$preexist})) {
			$txlist .= div({-class=>'titre'}, ucfirst($ptitle));
			$txlist .= start_ul({});
		
			foreach my $row (@{$preexist}) {
				my $element;
				my $i = 0;
				my $color = '#0F5286';
				foreach my $field (@{$table_definition}) {
					if($row->[$i]) {
						my $title = $field->{'title'};
						$title =~ s/ /&nbsp;/g;
						if ($field->{'type'} eq 'pub') {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
							$element .= a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[$i]"}, publication($row->[$i], 0, 1, $dbc)). ', ';
							#$element .= span({-style=>"color: #666666;"}, '[' . $row->[$i] . ']') . ', ';
						}
						elsif ($field->{'type'} eq 'foreign') {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
							if ($field->{'card'}) { $element .=  a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=".$field->{'card'}."&id=$row->[$i]"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . ', '; }
							else { $element .=  span({-style=>"color: $color;"}, $retro_hash->{$field->{'thesaurus'}.$row->[$i]}) . ', '; }
						} 
						elsif ($field->{'type'} eq 'select') {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ';
							if (exists $field->{'labels'}) {
								if ($field->{'card'}) {
									$element .= a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=".$field->{'card'}."&id=$row->[$i]"}, $field->{'labels'}->{$row->[$i]}) . ', ';
								}
								else {
									$element .= span({-style=>"color: $color;"}, $field->{'labels'}->{$row->[$i]}) . ', ';
								}

							}
							else { 
								$element .= span({-style=>"color: $color;"}, $row->[$i]) . ', '; 
							}							
						} 
						else {
							$element .= span({-style=>"color: #444444;"}, $title) . ' : ' . span({-style=>"color: $color;"}, $row->[$i]) . ', ';
						}
					}
					$i++;
				}
				my $lastfields = scalar(@{$foreign_fields}) + $i;
				if ($row->[$lastfields]) {
					$element = span({-style=>"color: #444444;"}, 'Name') . ' : ' . span({-style=>"color: $color;"}, i($row->[$lastfields]) . " " . $row->[$lastfields+1]) . ', ' . $element;
				}
				$txlist .= li(substr($element, 0, -2));
			}
			
			$txlist .= end_ul();
		}
	}
	return $txlist;
}


sub make_thesaurus {

	my ($req, $hash, $format, $retro_hash, $dbc) = @_;
	my ($res, $hashlabels);
		
	$res = request_tab($req, $dbc, 2);
	
	foreach my $row (@{$res}) {
		my $intitule;
		eval($format);
		${$retro_hash}->{$hash.$row->[0]} = $intitule;
	}
}

# Top list
#################################################################
sub topics_list {
	
	my @basesH = ('flow', 'psylles', 'aleurodes', 'tingides', 'tessaratomidae', 'lucanidae', 'brentidae', 'dbtnt', 'test', 'hefo', 'diptera');

#jompo
	if( grep $_ eq $dbase, @basesH ) {	
# if ($dbase ~~ @basesH) {
		my $wrap = 0;
		my $row = 0;
		my %topics;
		my ($bg, $txtsize);
		if ($dbase =~ m/psylles/) { $bg = 'black'; $txtsize = ' font-size: 13px;'}
		else { $bg = 'transparent'; }
		foreach (@topics) {
			my $href = "$scripts{$dbase}db=$dbase&lang=$lang&card=$_";
			#if ($dbase =~ m/psylles/ and $wrap > 5) { $row++; $wrap = 0; }
			push(@{$topics{$row}}, a({-href=>$href, -class=>'topicItem'},  ucfirst($trans->{$_}->{$lang})));
			$wrap++;
		}
		foreach (sort {$a<=>$b} keys(%topics)) {
			my $padding = $lang eq 'es' ? '4px 0' : '4px 2px';			
			$fullhtml .= 	"<TR>		<TD STYLE='text-align: center; vertical-align: middle; padding: $padding; background: $bg;$txtsize'>" . 
					join("</TD>	<TD STYLE='text-align: center; vertical-align: middle; padding: $padding; background: $bg;$txtsize'>-</TD>
							<TD STYLE='text-align: center; vertical-align: middle; padding: $padding; background: $bg;$txtsize'>", @{$topics{$_}}) . 
					"</TD></TR>";
		}
	}
	else {
		my $topics_list = start_ul({-class=>'exploul'});
		foreach (@topics) {
			my $href = "$scripts{$dbase}db=$dbase&lang=$lang&card=$_";
			my $label;
			if ($_ eq 'plants' and $dbase eq 'cool') { $label = 'plants_associated' }
			else { $label = $_; }
			$topics_list .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>$href}, ucfirst($trans->{$label}->{$lang}) ) );
		}
		$topics_list .= end_ul();
		
		my $toptitle;
		if ($dbase ne 'cool') { $toptitle = h2({-class=>'exploh2'},  $trans->{"topics"}->{$lang}); }
		
		$fullhtml = div({-class=>'explocontent', -id=>'topiclist'},
					div({-class=>'carddiv'},
						$toptitle,
						$topics_list
					)
				);
	}
	
	print $fullhtml;
}

# Families list
#################################################################
sub families_list {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;
		$rank = 'family';
		# Get the number of families to build up the list
		my $fa_numb = '';
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		my $sth = $dbc->prepare( "	SELECT count(*) 
						FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						WHERE r.en = 'family' AND s.en = 'valid'
						$bornes;" );
		$sth->execute( );
		$sth->bind_columns( \( $fa_numb ) );
		$sth->fetch();
		$sth->finish(); # finalize the request

		# Fetch families
		my ( $taxonid, $name, $autority, $docid, $doclogo );
		$sth = $dbc->prepare( "	SELECT t.index, n.orthographe, n.autorite, d.url, d.logo_url 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
					LEFT JOIN documents AS d ON d.index = txd.ref_document 				
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE r.en = 'family' 
					AND s.en = 'valid'
					AND (d.type = 'key' OR d.type IS NULL)
					ORDER BY n.orthographe
					$bornes;");
		$sth->execute( );
		$sth->bind_columns( \( $taxonid, $name, $autority, $docid, $doclogo ) );
		#my $fa_list = start_ul({});
		my $fa_list;
		while ( $sth->fetch() ){
			if ($doclogo) { $doclogo = '&nbsp;' . img({-src=>$doclogo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($docid) { $docid = a({-style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, $doclogo . " $trans->{'id_key'}->{$lang} "); }
			$fa_list .= Tr(td({-class=>'cellAsLi'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=family&id=$taxonid&loading=1"}, i("$name") . " $autority")), td({-class=>'cellAsLi'}, $docid));
		}
		#$fa_list .= end_ul();
		$fa_list = table($fa_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					div({-class=>'titre'}, ucfirst($trans->{"familys"}->{$lang})), p,
					$fa_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# Subfamilies list
#################################################################
sub subfamilies_list {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;
		$rank = 'subfamily';
		# Get the number of subfamilies to build up the list
		my $fa_numb = '';
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		my $sth = $dbc->prepare( "	SELECT count(*) 
						FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						WHERE r.en = '$rank' AND s.en = 'valid'
						$bornes;" );
		$sth->execute( );
		$sth->bind_columns( \( $fa_numb ) );
		$sth->fetch();
		$sth->finish(); # finalize the request

		# Fetch subfamilies
		my ( $taxonid, $name, $autority, $docid, $doclogo );
		$sth = $dbc->prepare( "	SELECT t.index, n.orthographe, n.autorite, d.url, d.logo_url 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
					LEFT JOIN documents AS d ON d.index = txd.ref_document 				
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE r.en = '$rank' 
					AND s.en = 'valid'
					AND (d.type = 'key' OR d.type IS NULL)
					ORDER BY n.orthographe
					$bornes;");
		$sth->execute( );
		$sth->bind_columns( \( $taxonid, $name, $autority, $docid, $doclogo ) );
		#my $fa_list = start_ul({});
		my $fa_list;
		while ( $sth->fetch() ){
			if ($doclogo) { $doclogo = '&nbsp;' . img({-src=>$doclogo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($docid) { $docid = a({-style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, $doclogo . " $trans->{'id_key'}->{$lang} "); }
			$fa_list .= Tr(td({-class=>'cellAsLi'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority")), td({-class=>'cellAsLi'}, $docid));
		}
		#$fa_list .= end_ul();
		$fa_list = table($fa_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					div({-class=>'titre'}, ucfirst($trans->{"subfamilys"}->{$lang})), p,
					$fa_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# Tribes list
#################################################################
sub tribes_list {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;
		$rank = 'tribe';
		# Get the number of subfamilies to build up the list
		my $fa_numb = '';
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		my $sth = $dbc->prepare( "	SELECT count(*) 
						FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						WHERE r.en = '$rank' AND s.en = 'valid'
						$bornes;" );
		$sth->execute( );
		$sth->bind_columns( \( $fa_numb ) );
		$sth->fetch();
		$sth->finish(); # finalize the request

		# Fetch subfamilies
		my ( $taxonid, $name, $autority, $docid, $doclogo );
		$sth = $dbc->prepare( "	SELECT t.index, n.orthographe, n.autorite, d.url, d.logo_url 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
					LEFT JOIN documents AS d ON d.index = txd.ref_document 				
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE r.en = '$rank' 
					AND s.en = 'valid'
					AND (d.type = 'key' OR d.type IS NULL)
					ORDER BY n.orthographe
					$bornes;");
		$sth->execute( );
		$sth->bind_columns( \( $taxonid, $name, $autority, $docid, $doclogo ) );
		#my $fa_list = start_ul({});
		my $fa_list;
		while ( $sth->fetch() ){
			if ($doclogo) { $doclogo = '&nbsp;' . img({-src=>$doclogo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($docid) { $docid = a({-style=>'margin-left: 20px;', -href=>$docid, -target=>'_blank'}, $doclogo . " $trans->{'id_key'}->{$lang} "); }
			$fa_list .= Tr(td({-class=>'cellAsLi'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority")), td({-class=>'cellAsLi'}, $docid));
		}
		#$fa_list .= end_ul();
		$fa_list = table($fa_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					div({-class=>'titre'}, ucfirst($trans->{"subfamilys"}->{$lang})), p,
					$fa_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# identification keys list
#################################################################
sub keys_list {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;

		# Fetch keys
		my ( $taxonid, $name, $autority, $url, $logo );
		my $sth = $dbc->prepare( "	SELECT t.index, n.orthographe, n.autorite, d.url, d.logo_url 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
					LEFT JOIN documents AS d ON d.index = txd.ref_document 				
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE s.en = 'valid'
					AND d.type = 'key'
					ORDER BY n.orthographe;");
		
		$sth->execute( );
		$sth->bind_columns( \( $taxonid, $name, $autority, $url, $logo ) );

		my $key_list;
		while ( $sth->fetch() ){
			if ($logo) { $logo = '&nbsp;' . img({-src=>$logo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($url) { $url = a({-style=>'', -href=>$url, -target=>'_blank'}, i("$name") . " $autority"); }
			$key_list .= Tr(td($url));
		}
		$key_list = table($key_list);
		
		my $prevnext;
		
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					div({-class=>'titre'}, ucfirst($trans->{'id_keys'}->{$lang})),
					$key_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# morphological card list
#################################################################
sub morphcards_list {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;
		
		# Fetch keys
		my ( $taxonid, $name, $autority, $url, $logo );
		my $sth = $dbc->prepare( "	SELECT t.index, n.orthographe, n.autorite, d.url, d.logo_url 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
					LEFT JOIN documents AS d ON d.index = txd.ref_document 				
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					WHERE s.en = 'valid'
					AND d.type = 'card'
					ORDER BY n.orthographe;");
		
		$sth->execute( );
		$sth->bind_columns( \( $taxonid, $name, $autority, $url, $logo ) );

		my $key_list;
		while ( $sth->fetch() ){
			if ($logo) { $logo = '&nbsp;' . img({-src=>$logo, -style=>'width: 14px; border: 0; margin: 0; padding: 0;'}); }
			if ($url) { $url = a({-style=>'', -href=>$url, -target=>'_blank'}, i("$name") . " $autority"); }
			$key_list .= Tr(td($url));
		}
		$key_list = table($key_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					div({-class=>'titre'}, ucfirst($trans->{'morphcards'}->{$lang})),
					$key_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# Genera list
#################################################################
sub genera_list {
	
	my $title;
	($rank) = @_;
	unless ($rank) { $rank = 'genus'; $title = 'genera'; }
	else { $title = 'subgenera'; }
	
	if ( my $dbc = db_connection($config) ) { # connection
		$dbc->{RaiseError} = 1; #TODO: enhance error message...
		# Get the number of genera to build up the list
		my $ge_numb = '';
		my $alphabet;
		
		my $sth = $dbc->prepare("SELECT count(*) FROM taxons AS t 
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = '$rank';");
		
		$sth->execute( );
		$sth->bind_columns( \( $ge_numb ) );
		$sth->fetch();
		$sth->finish(); # finalize the request
		
		if ($ge_numb > 100) {

			unless($alph) {
				my $req = "	SELECT nc.orthographe
						FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = '$rank' AND s.en = 'valid'
						ORDER by nc.orthographe
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = uc(substr($alph, 0, 1));
			}
			
			my $vlreq = "	SELECT upper(substring(orthographe,1,1)) AS letter, count(*) 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = '$rank' AND s.en = 'valid'
					GROUP BY substring(orthographe,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring(orthographe,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
			
			$sth = $dbc->prepare("SELECT count(*) FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = '$rank' AND s.en = 'valid'
						AND n.orthographe ILIKE '$alph%';");		
			
			$sth->execute( );
			$sth->bind_columns( \( $ge_numb ) );
			$sth->fetch();
			$sth->finish(); # finalize the request
			
			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }

		# Fetch genera
		my ( $taxonid, $name, $autority, $parent_name, $parent_taxon, $parent_rank, $docid, $family);

		my $req = 	"SELECT t.index, n.orthographe, n.autorite, n2.orthographe, t.ref_taxon_parent, r2.en, d.url, t.family 
				FROM taxons AS t 
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN taxons AS t2 ON t2.index = t.ref_taxon_parent
				LEFT JOIN rangs AS r2 ON r2.index = t2.ref_rang
				LEFT JOIN taxons_x_noms AS txn2 ON txn2.ref_taxon = t.ref_taxon_parent
				LEFT JOIN statuts AS s2 ON s2.index = txn2.ref_statut
				LEFT JOIN noms_complets AS n2 ON txn2.ref_nom = n2.index
				LEFT JOIN taxons_x_documents AS txd ON t.index = txd.ref_taxon
				LEFT JOIN documents AS d ON d.index = txd.ref_document 				
				WHERE r.en = '$rank' AND s.en = 'valid'
				AND s2.en = 'valid'
				AND (d.type = 'card' OR d.type IS NULL)
				AND n.orthographe ILIKE '$alph%'
				ORDER BY n.orthographe;";
	
		my $gens = request_tab($req, $dbc, 2);
		
		my $nbcols;
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'genera';", $dbc, 'element')};
		my %attributes;
		my @attributes = split('#', $display_modes{list}{attributes});
		foreach (@attributes) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}
		
		$nbcols = scalar(@{$gens}) > 25 ? $attributes{nbcols} || 3 : 1;
		
		my $seuil = scalar(@{$gens}) / $nbcols;
		$seuil = int($seuil) != $seuil ? int($seuil) + 1 : $seuil;
		
		my $ge_list;
		my $i = 0;
		my $j = 0;
		my %genera;
		my $nab;
		my $naval;
		my $test = 0;
		if ($to and $ge_numb > $to) {
			foreach ( @{$gens} ) {
				( $taxonid, $name, $autority, $parent_name, $parent_taxon, $parent_rank, $docid, $family ) = ( $_->[0], $_->[1], $_->[2], $_->[3], $_->[4], $_->[5], $_->[6], $_->[7] );
				if ($i % $to == 0 ) { $naval = substr($name, 0, 3)}
				elsif($i % $to == $to-1 or $i == $ge_numb-1) { 
					$naval .= " - " . substr($name, 0, 3);
					my $ff = int($i/$to) * $to;
					my $active;
					if ($ff == $from) { $active = 'font-size: 18px;'}
					$naval = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&from=$ff&alph=$alph"}, $naval );
					push(@{$nab}, $naval); 
					$naval = ''; 
				}

				if ($i >= $from and $i < $from + $to) {
					if ($docid) { $test = 1; $docid = a({-style=>'margin-left: 5px;', -href=>$docid, -target=>'_blank'}, img({-src=>"/explorerdocs/icon-fiche.png", -style=>'border: 0; margin: 0 0 -2px 0;'})); }					
					$ge_list .= Tr(td({-class=>'cellAsLi'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority")), td({-class=>'cellAsLi', -style=>'text-align: center;'}, $docid));
				}
				$i++;
			}
		}
		else {
			foreach ( @{$gens} ) {
				
				( $taxonid, $name, $autority, $parent_name, $parent_taxon, $parent_rank, $docid, $family ) = ( $_->[0], $_->[1], $_->[2], $_->[3], $_->[4], $_->[5], $_->[6], $_->[7] );
								
				if ($docid) { 
					$test = 1;
					$docid = a({-style=>'margin-left: 5px;', -href=>$docid, -target=>'_blank'}, img({-src=>"/explorerdocs/icon-fiche.png", -style=>'border: 0; margin: 0 0 -2px 0;'}));
				}					
				unless ($i < $seuil) { $i = 0; $j++; }
				$family = $family ? " ($family)" : undef;
				$genera{$i}{$j} = td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority ") . $family . $docid );
				$i++;
			}
		}
				
		foreach my $row (sort {$a <=> $b} keys(%genera)) {
			my $columns;
			foreach my $col (sort {$a <=> $b} keys(%{$genera{$row}})) {
					$columns .= $genera{$row}{$col};
			}
			$ge_list .= Tr($columns);
		}
		
		$ge_list = table({-style=>'margin: 0; padding: 0;'}, $ge_list);

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }		
		
		$fullhtml =  	div({-class=>'content'}, 
					$totop,
					$prevnext,
					table({-style=>'width: 100%;'},
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{$title}->{$lang})) ),
							td({-style=>'text-align: center;'}, $alphabet )
						)
					),
					div({-class=>'titre'}, ''),
					$ge_list
				);
		
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Species list
#################################################################
sub species_list {

	my $title;
	($rank) = @_;
	unless ($rank) { $rank = 'species'; $title = 'speciess'; }
	else { $title = 'subspeciess'; }

	if ( my $dbc = db_connection($config) ) {
		$dbc->{RaiseError} = 1; #TODO: enhance error message...
		# Get the number of species to build up the list
		my $sp_numb;
		my $alphabet;
		my $req = "	SELECT count(*) 
				FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.en = '$rank' AND s.en = 'valid';";
		
		my $sth = $dbc->prepare($req) or die $req;
		
		$sth->execute() or die $req;
		$sth->bind_columns( \( $sp_numb ) );
		$sth->fetch();
		$sth->finish();
				
		if ($sp_numb > 100) {
			
			unless($alph) {
				my $req = "	SELECT nc.orthographe
						FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = '$rank' AND s.en = 'valid'
						ORDER by nc.orthographe
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = uc(substr($alph, 0, 1));
			}
			
			my $vlreq = "	SELECT upper(substring(orthographe,1,1)) AS letter, count(*) 
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = '$rank' AND s.en = 'valid'
					GROUP BY substring(orthographe,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring(orthographe,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
			
			$req = "	SELECT count(*) 
					FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = '$rank' AND s.en = 'valid'
					AND nc.orthographe ILIKE '$alph%';";
			
			$sth = $dbc->prepare($req) or die $req;
			
			$sth->execute() or die $req;
			$sth->bind_columns( \( $sp_numb ) );
			$sth->fetch();
			$sth->finish();
			
			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }
		
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		$req = "SELECT t.index, nc.orthographe, nc.autorite, t.ref_taxon_parent, t.family
			FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
			LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
			LEFT JOIN rangs AS r ON t.ref_rang = r.index
			WHERE r.en = '$rank' AND s.en = 'valid'
			AND nc.orthographe ILIKE '$alph%'
			ORDER BY nc.orthographe
			$bornes;";
		
		# Fetch species from DB
		my ( $taxonid, $name, $autority, $ref_taxon_parent, $family );

		my $spes = request_tab($req, $dbc, 2);
		
		my $nbcols;
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = '$title';", $dbc, 'element')};
		my %attributes;
		my @attributes = split('#', $display_modes{list}{attributes});
		foreach (@attributes) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}
		
		$nbcols = scalar(@{$spes}) > 25 ? $attributes{nbcols} || 2 : 1;
		
		my $seuil = scalar(@{$spes}) / $nbcols;
		$seuil = int($seuil) != $seuil ? int($seuil) + 1 : $seuil;
		my $i = 0;
		my $j = 0;
		my %spes;
		
		my $sp_list;
		foreach ( @{$spes} ) {
			( $taxonid, $name, $autority, $ref_taxon_parent, $family ) = ( $_->[0], $_->[1], $_->[2], $_->[3], $_->[4] );
			
			unless ($i < $seuil) { $i = 0; $j++; }
			$family = $family ? " ($family)" : undef;
			$spes{$i}{$j} = td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority" ) . $family );
			$i++;
		}

		foreach my $row (sort {$a <=> $b} keys(%spes)) {
			my $columns;
			foreach my $col (sort {$a <=> $b} keys(%{$spes{$row}})) {
					$columns .= $spes{$row}{$col};
			}
			$sp_list .= Tr($columns);
		}
		
		$sp_list = table({-style=>'margin: 0; padding: 0;'}, $sp_list);
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table({-style=>'width: 100%;'},
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{$title}->{$lang}))),
							td({-style=>'text-align: center;'}, $alphabet )
						)
					),
					div({-class=>'titre'}, ''),
					$sp_list
				);
		
		print $fullhtml;

		$dbc->disconnect; 
	}
	else {}
}

# Species list
#################################################################
sub fossils_list {
	if ( my $dbc = db_connection($config) ) {
		$dbc->{RaiseError} = 1;
		$rank = 'species';
		
		my ($alphabet, $alphabetic, $time, $sp_list);
		
		if ($mode eq 'alpha' or !$mode) {
			$time = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=fossils&mode=time"},  ucfirst($trans->{'geoltime'}->{$lang}));
			$alphabetic = span({-class=>'xsection'},  ucfirst($trans->{'alphabetic'}->{$lang}));
			
			# Get the number of species to build up the list
			my $sp_numb;
			my $req = "	SELECT count(*) 
					FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms AS n ON txn.ref_nom = n.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					WHERE r.en = 'species'
					AND s.en = 'valid'
					AND n.fossil = true;";
			
			my $sth = $dbc->prepare($req) or die $req;
		
			$sth->execute() or die $req;
			$sth->bind_columns( \( $sp_numb ) );
			$sth->fetch();
			$sth->finish();
			
			if ($sp_numb > 1000) {	
				unless($alph) {
					my $req = "	SELECT nc.orthographe
							FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
							LEFT JOIN noms AS n ON n.index = nc.index
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							WHERE r.en = 'species' 
							AND s.en = 'valid'
							AND n.fossil = true
							ORDER by nc.orthographe
							LIMIT 1;";
							
					my $sth = $dbc->prepare($req) or die $req;
					$sth->execute() or die $req;
					$sth->bind_columns( \( $alph ) );
					$sth->fetch();
					$sth->finish();
					
					$alph = uc(substr($alph, 0, 1));
				}
				
				my $vlreq = "	SELECT upper(substring(nc.orthographe,1,1)) AS letter, count(*) 
						FROM taxons AS t 
						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms AS n ON n.index = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = 'species' 
						AND s.en = 'valid'
						AND n.fossil = true
						GROUP BY substring(nc.orthographe,1,1) 
						HAVING count(*) > 0 
						ORDER BY lower(substring(nc.orthographe,1,1));";
						
				my $vletters = request_hash($vlreq, $dbc, 'letter');
				
				$req = "	SELECT count(*) 
						FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms AS n ON n.index = nc.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON t.ref_rang = r.index
						WHERE r.en = 'species' 
						AND s.en = 'valid'
						AND n.fossil = true
						AND nc.orthographe ILIKE '$alph%';";
				
				$sth = $dbc->prepare($req) or die $req;
				
				$sth->execute() or die $req;
				$sth->bind_columns( \( $sp_numb ) );
				$sth->fetch();
				$sth->finish();
				
				$alphabet = alpha_build($vletters);
			}
			else { $alph = '' }
			
			
			my $bornes;
			if ($to) { $bornes .= "LIMIT $to"; }
			if ($from) { $bornes .= "OFFSET $from"; }
	
			$req = "SELECT t.index, nc.orthographe, nc.autorite, t.family
				FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN noms AS n ON n.index = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.en = 'species'
				AND s.en = 'valid'
				AND n.fossil = true
				AND nc.orthographe ILIKE '$alph%'
				ORDER BY nc.orthographe
				$bornes;";
			
			my $spes = request_tab($req, $dbc, 2);
			
			# Fetch species from DB
			my ( $taxonid, $name, $autority, $ref_taxon_parent, $family );
			
			my $nbcols;
			my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'fossils';", $dbc, 'element')};
			my %attributes;
			my @attributes = split('#', $display_modes{list}{attributes});
			foreach (@attributes) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			
			$nbcols = scalar(@{$spes}) > 25 ? $attributes{nbcols} || 2 : 1;
			
			my $seuil = scalar(@{$spes}) / $nbcols;
			$seuil = int($seuil) != $seuil ? int($seuil) + 1 : $seuil;
			my $i = 0;
			my $j = 0;
			my %spes;
			
			foreach ( @{$spes} ) {
				( $taxonid, $name, $autority, $family ) = ( $_->[0], $_->[1], $_->[2], $_->[3] );
				$family = $family ? " ($family)" : undef;
				unless ($i < $seuil) { $i = 0; $j++; }
				$spes{$i}{$j} = td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $autority") . $family );
				$i++;
			}
	
			foreach my $row (sort {$a <=> $b} keys(%spes)) {
				my $columns;
				foreach my $col (sort {$a <=> $b} keys(%{$spes{$row}})) {
						$columns .= $spes{$row}{$col};
				}
				$sp_list .= Tr($columns);
			}
			
			$sp_list = table({-style=>'margin: 0; padding: 0;'}, $sp_list);
		}
		else {
			$alphabetic = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=fossils&mode=alpha"}, ucfirst($trans->{'alphabetic'}->{$lang}));
			$time = span({-class=>'xsection'},  ucfirst($trans->{'geoltime'}->{$lang}));
			
			my $req = "	SELECT DISTINCT t.index, nc.orthographe, nc.autorite, p.$lang, p.debut, p.fin, p.parent, p.niveau, substring(nc.orthographe from 1 for char_length(nc.orthographe)-1), t.family
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms AS n ON n.index = nc.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON t.ref_rang = r.index
					LEFT JOIN taxons_x_periodes AS txp ON t.index = txp.ref_taxon
					LEFT JOIN periodes AS p ON txp.ref_periode = p.index
					WHERE s.en = 'valid'
					AND r.en = 'species'
					AND n.fossil = true
					ORDER BY substring(nc.orthographe from 1 for char_length(nc.orthographe)-1);";
			
			my $txp = request_tab($req, $dbc, 2);
			
			my %fossils;
			
			if (url_param('test')) { die "$req"; }
			
			foreach my $relation (@{$txp}) {
				my ($taxonid, $name, $authority, $period, $start, $end, $parent, $level, $family) = ($relation->[0], $relation->[1], $relation->[2], $relation->[3], $relation->[4], $relation->[5], $relation->[6], $relation->[7], $relation->[9]);
				if ($period) {
					unless (exists($fossils{$period})) {
						push(@{$fossils{$period}{hierarchie}}, "$period [$start-$end Ma]");
						$fossils{$period}{start} = $start**(10-$level);
						while ($parent) {
							my $data = request_tab("SELECT $lang, debut, fin, parent, niveau FROM periodes WHERE index = $parent", $dbc, 2);
							if (scalar(@{$data})) { 
								unshift(@{$fossils{$period}{hierarchie}}, "$data->[0][0] [$data->[0][1]-$data->[0][2] Ma]");
								$fossils{$period}{start} += $data->[0][1]**(10-$data->[0][4]);
								if ($data->[0][3]) { $parent = $data->[0][3] }
								else { $parent = undef; }
							}
							else { $parent = undef; }
						}
					}
					$family = $family ? " ($family)" : undef;
					push(@{$fossils{$period}{elements}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $authority" ) . $family);
				}
				else { 
					unless (exists($fossils{'not_dated'})) {
						push(@{$fossils{'not_dated'}{hierarchie}}, ucfirst($trans->{"not_dated"}->{$lang}));
						$fossils{'not_dated'}{start} = 10**30;
					}
					$family = $family ? " ($family)" : undef;
					push(@{$fossils{'not_dated'}{elements}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"}, i("$name") . " $authority" ) . $family);
				} 
			}
			
			my %done;
			my $factor = 20;
			my $test;
			foreach my $key (sort {$fossils{$a}{start} <=> $fossils{$b}{start}} keys(%fossils)) {
								
				my $indent = 0;
				foreach my $ascend (@{$fossils{$key}{hierarchie}}) {
					unless ($done{$ascend}) {
						$sp_list .= div({-class=>'titre', -style=>"margin-left: ".($indent*$factor)."px;"}, $ascend);
						$done{$ascend} = 1;
					}
					$indent++;
				}
				$indent--;
				foreach my $element (@{$fossils{$key}{elements}}) {
					$sp_list .= div({-class=>'cellAsLi', -style=>"margin-left: ".($indent*$factor)."px;"}, $element);
				}
			}
		}
				
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table(
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{"fossils"}->{$lang}) . "&nbsp; " . span({-style=>"font-size: 0.8em;"}, $trans->{'sortedby'}->{$lang}. ":") ) ),
							td( '&nbsp;&nbsp;' . $alphabetic . '&nbsp;&nbsp;' . $time ),
							td({-style=>'text-align: center;'}, $alphabet )
						)
					),
					div({-class=>'titre'}, ''),
					$sp_list
				);
		
		print $fullhtml;

		$dbc->disconnect; 
	}
	else {}
}

# Names list
#################################################################
sub names_list {
		
	my $alphab;
	my ($ordstr, $famstr, $genstr, $spestr) = ($trans->{'ord_key'}->{$lang}, $trans->{'familys'}->{$lang}, $trans->{'genuss'}->{$lang}, $trans->{'speciess'}->{$lang});
	
	unless($rank) { $rank = 'species' }
	
	#if ($rank eq 'order') { $ordstr = span({-class=>'xsection'}, $ordstr) }
	if ($rank eq 'family') { $famstr = span({-class=>'xsection'},  ucfirst($famstr)) } else  { $famstr = span({-class=>'section'},  ucfirst($famstr)) }
	if ($rank eq 'genus') { $genstr = span({-class=>'xsection'},  ucfirst($genstr)) } else  { $genstr = span({-class=>'section'},  ucfirst($genstr)) }
	if ($rank eq 'species') { $spestr = span({-class=>'xsection'},  ucfirst($spestr)) } else  { $spestr = span({-class=>'section'},  ucfirst($spestr)) }
	
	my @rankselect = (	
				#a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=order"}, $ordstr),
				a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=family&loading=1"}, $famstr),
				a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=genus"}, $genstr),
				a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=names&rank=species"}, $spestr) );
	
	unless ($alph) { $alph = 'A'; }
	
	if ( my $dbc = db_connection($config) and $rank ) {
		
		my $nanreq = "SELECT count(*) FROM noms_complets AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = '$rank' AND n.index in (SELECT distinct ref_nom from taxons_x_noms);";
		
		my $na_numb = request_row($nanreq, $dbc);
		my $alphatest;
				
		if ($na_numb->[0] > 100) {
		
			if($rank eq 'genus' or $rank eq 'species') {
				unless($alph) {
					my $req = "	SELECT nc.orthographe
							FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
							LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
							LEFT JOIN rangs AS r ON t.ref_rang = r.index
							WHERE r.en = 'genus'
							ORDER by nc.orthographe
							LIMIT 1;";
							
					my $sth = $dbc->prepare($req) or die $req;
					$sth->execute() or die $req;
					$sth->bind_columns( \( $alph ) );
					$sth->fetch();
					$sth->finish();
					
					$alph = uc(substr($alph, 0, 1));
				}
				
				my $vlreq = "	SELECT upper(substring(orthographe,1,1)) AS letter, count(*) 
						FROM taxons_x_noms AS txn
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs AS r ON n.ref_rang = r.index
						WHERE r.en = '$rank'
						AND s.en not in ( 'correct use' )
						GROUP BY substring(orthographe,1,1) 
						HAVING count(*) > 0 
						ORDER BY lower(substring(orthographe,1,1));";
						
				my $vletters = request_hash($vlreq, $dbc, 'letter');
				
				$alphatest = "AND orthographe ilike '$alph%'";
				$alphab = alpha_build($vletters);
			}
			$nanreq = "SELECT count(*) FROM noms_complets AS n LEFT JOIN rangs AS r ON n.ref_rang = r.index WHERE r.en = '$rank' $alphatest AND n.index in (SELECT distinct ref_nom from taxons_x_noms);";
			
			$na_numb = request_row($nanreq, $dbc);
		}
		else { $alph = '' }
				
		# Fetch names and their status
		my ( %ord, %fam, %gen, %spec );
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $req = "	SELECT n.index, orthographe, autorite, s.en, s.$lang, r.en, txn.ref_taxon FROM taxons_x_noms AS txn
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON n.ref_rang = r.index
				WHERE r.en = '$rank'
				$alphatest
				AND s.en not in ( 'correct use' )
				ORDER BY LOWER ( orthographe )
				$bornes;";
		
		my $names =  request_tab($req,$dbc);
		
		my $nbcols;
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'names';", $dbc, 'element')};
		my %attributes;
		my @attributes = split('#', $display_modes{list}{attributes});
		foreach (@attributes) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}
		
		$nbcols = scalar(@{$names}) > 25 ? $attributes{nbcols} || 3 : 1;
		
		my $seuil = scalar(@{$names}) / $nbcols;
		$seuil = int($seuil) != $seuil ? int($seuil) + 1 : $seuil;
		
		my $i = 0;
		my $j = 0;
		if ( $rank eq 'order' or $rank eq 'suborder' ){
			foreach my $name ( @{$names} ){
				unless ($i < $seuil) { $i = 0; $j++; }
				if ( $name->[3] eq 'valid' ){
					$ord{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );				
				}
				else {
					$ord{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
				$i++;
			}
		}
		elsif ( $rank eq 'super family' or $rank eq 'family' or $rank eq 'subfamily' ){
			foreach my $name ( @{$names} ){
				unless ($i < $seuil) { $i = 0; $j++; }
				if ( $name->[3] eq 'valid' ){
					$fam{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );				
				}
				else {
					$fam{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
				$i++;
			}
		}
		elsif ( $rank eq 'genus' or $rank eq 'subgenus' ){
			foreach my $name ( @{$names} ){	
				unless ($i < $seuil) { $i = 0; $j++; }
				if ( $name->[3] eq 'valid' ){
                                        $gen{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]") ) );
				}
				else {
					$gen{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
				$i++;
			}
		}
		elsif ( $rank eq 'super species' or $rank eq 'species' or $rank =~ m/subspecies/ ){
			foreach my $name ( @{$names} ){
				unless ($i < $seuil) { $i = 0; $j++; }
				if ( $name->[3] eq 'valid' ){
					$spec{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$name->[6]"}, i($name->[1]) . " $name->[2] &nbsp;" . b("$name->[4]")) );
				}
				else {
					$spec{$i}{$j} .= td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[0]"}, i($name->[1]) . " $name->[2] &nbsp;" . b($name->[4]) ) );
				}
				$i++;
			}
		}
				
		# conditionaly builds names lists
		my $list;
		my $html;
		my $style;
		if ($alphab) { $style = 'width: 100%;' }
		else { $style = 'width: 28%;' }
		
		if ($dbase ne 'cool') {
			$html .=	table({-style=>$style},
							Tr(
								td( div({-class=>'titre'}, ucfirst($trans->{"names"}->{$lang}))),
								td({-style=>'text-align: center;'}, '&nbsp;&nbsp;' . join('&nbsp;&nbsp;', @rankselect) ),
								td({-style=>'text-align: center;'}, join('&nbsp;&nbsp;', $alphab) )
							)
						). p;
		}
		else {
			$html .=	table({-style=>$style},
							Tr(
								td( div({-class=>'titre'}, ucfirst($trans->{"names"}->{$lang}))),
								td({-style=>'text-align: left;'}, '&nbsp;&nbsp;' . join('&nbsp;', @rankselect) )
							),
							Tr(
								td({-style=>'text-align: left; padding-top: 5px;', -colspan=>2}, join('&nbsp;', $alphab) )
							)
						). p;
		}
				
		if ( scalar(keys(%ord)) ){
			foreach my $row (sort {$a <=> $b} keys(%ord)) {
				my $columns;
				foreach my $col (sort {$a <=> $b} keys(%{$ord{$row}})) {
						$columns .= $ord{$row}{$col};
				}
				$list .= Tr($columns);
			}
		}
		elsif ( scalar(keys(%fam)) ){
			foreach my $row (sort {$a <=> $b} keys(%fam)) {
				my $columns;
				foreach my $col (sort {$a <=> $b} keys(%{$fam{$row}})) {
						$columns .= $fam{$row}{$col};
				}
				$list .= Tr($columns);
			}
		}
		elsif ( scalar(keys(%gen)) ){
			foreach my $row (sort {$a <=> $b} keys(%gen)) {
				my $columns;
				foreach my $col (sort {$a <=> $b} keys(%{$gen{$row}})) {
						$columns .= $gen{$row}{$col};
				}
				$list .= Tr($columns);
			}
		}
		elsif ( scalar(keys(%spec)) ){
			foreach my $row (sort {$a <=> $b} keys(%spec)) {
				my $columns;
				foreach my $col (sort {$a <=> $b} keys(%{$spec{$row}})) {
						$columns .= $spec{$row}{$col};
				}
				$list .= Tr($columns);
			}
		}
		$html .= table({-style=>'margin: 0; padding: 0;'},  $list);

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					$html
				);
				
		print $fullhtml;

		$dbc->disconnect; 
	}
	else {
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		my $style;
		if ($alphab) { $style = 'width: 100%;' }
		else { $style = 'width: 28%;' }

		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table({-style=>$style},
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{"names"}->{$lang}))),
							td({-style=>'text-align: center;'}, join('&nbsp;', @rankselect) )
						)
					), 
					$alphab, br,
				);
				
		print $fullhtml;
	}
}
# Authors list
#################################################################
sub authors_list {
	if ( my $dbc = db_connection($config) ) {
		
		my $au_numb = request_row("SELECT count(*) FROM auteurs;",$dbc);
		my $alphabet;
		
		if ($au_numb->[0] > 100) {
			
			unless($alph) {
				my $req = "	SELECT nom
						FROM auteurs
						WHERE index in (select distinct ref_auteur from noms_x_auteurs)
						OR index in (select distinct ref_auteur from auteurs_x_publications)
						ORDER by desaccentue
						LIMIT 1;";
						
				my $sth = $dbc->prepare($req) or die $req;
				$sth->execute() or die $req;
				$sth->bind_columns( \( $alph ) );
				$sth->fetch();
				$sth->finish();
				
				$alph = uc(substr($alph, 0, 1));
			}
			
			$au_numb = request_row("SELECT count(*) FROM auteurs WHERE desaccentue ILIKE '$alph%';",$dbc);
			
			my $vlreq = "	SELECT upper(substring(desaccentue,1,1)) AS letter, count(*) 
					FROM auteurs AS a ".
					#WHERE ((SELECT count(*) FROM noms_x_auteurs AS nxa LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxa.ref_nom WHERE nxa.ref_auteur = a.index AND txn.ref_statut != (SELECT index FROM statuts WHERE en = 'wrong spelling')) > 0
					#OR (SELECT count(*) FROM auteurs_x_publications WHERE ref_auteur = a.index) > 0)
					"GROUP BY substring(desaccentue,1,1) 
					".
					#HAVING cont(*) > 0
					"ORDER BY lower(substring(desaccentue,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');
						
			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $authors = request_tab("SELECT index, nom, prenom FROM auteurs AS a
						WHERE a.desaccentue ILIKE '$alph%'
						AND ((	SELECT count(*) 
								FROM noms_x_auteurs AS nxa 
								LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxa.ref_nom 
								WHERE nxa.ref_auteur = a.index 
								AND txn.ref_statut != (SELECT index FROM statuts WHERE en = 'wrong spelling')) > 0
						OR (SELECT count(*) FROM auteurs_x_publications WHERE ref_auteur = a.index) > 0)
						ORDER BY a.desaccentue, prenom
						$bornes;",$dbc);
						
		my %auteurs;
		my $list;
		my $nbcols;
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'authors';", $dbc, 'element')};
		my %attributes;
		my @attributes = split('#', $display_modes{list}{attributes});
		my $i = 0;
		my $j = 0;
		foreach (@attributes) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}
		
		$nbcols = scalar(@{$authors}) > 25 ? $attributes{nbcols} || 3 : 1;
		
		my $seuil = scalar(@{$authors}) / $nbcols;
		$seuil = int($seuil) != $seuil ? int($seuil) + 1 : $seuil;

		foreach my $author ( @{$authors} ){
			unless ($i < $seuil) { $i = 0; $j++; }
			$auteurs{$i}{$j} = td({-class=>'cellAsLi', -style=>'padding-right: 10px;', -width=>int(1000/$nbcols)}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=author&id=$author->[0]"}, "$author->[1] $author->[2]" ) );
			$i++;
		}
		
		foreach my $row (sort {$a <=> $b} keys(%auteurs)) {
			my $columns;
			foreach my $col (sort {$a <=> $b} keys(%{$auteurs{$row}})) {
					$columns .= $auteurs{$row}{$col};
			}
			$list .= Tr($columns);
		}
		
		my $authors_list = table({-style=>'margin: 0; padding: 0;'},  $list);
								
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table({-style=>'width: 100%;'},
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{"authors"}->{$lang}))),
							td({-style=>'text-align: center;'}, join('&nbsp;&nbsp;', $alphabet) )
						)
					),
					div({-class=>'titre'}, ''),
					$authors_list
				);
			
		print $fullhtml;			
		
		$dbc->disconnect;
	}
	else {}
}

# Publications list
#################################################################
sub publications_list {
	if ( my $dbc = db_connection($config) ) {
		
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'publications';", $dbc, 'element')};
		my %attributes;
		my @attribs = split('#', $display_modes{list}{attributes});
		foreach (@attribs) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}

		my $sections = [];		
		my $distrib;		
		
		my ($nbpubs) = @{ request_row('SELECT count(*) FROM publications WHERE index in (SELECT DISTINCT ref_publication FROM auteurs_x_publications);', $dbc)};
		my $nbsecs =  $attributes{nbsections} || 10;
		my $default = $nbpubs > 30 ? int($nbpubs/$nbsecs) : $nbpubs;
				
		my $pubids;
		my $publist = start_ul();
		
		my $dreq = 'SELECT desaccentue, count(*), substr(desaccentue, 0, 5) FROM auteurs_x_publications LEFT JOIN auteurs ON ref_auteur = index WHERE position = 1 GROUP BY desaccentue ORDER BY upper(desaccentue);';
				
		my $distrib = request_tab($dreq, $dbc);
		
		my $offset = 0;
		my $limit = 0;
		my $cut;
		my $total;
		
		if ($nbpubs > $default) {
	
			foreach my $author ( @{$distrib} ){
				
				my $substr = $author->[2];
				unless ($limit) { $cut = $substr }
				$limit += $author->[1];
				if ($limit > $default or ($offset + $limit) >= $nbpubs) { 
					if ($substr ne $cut) { $cut .= " - " . $substr }
					my $active;
					if ($offset == $from) { 
						$cut = span({-class=>'xsection', -style=>"font-size: 12px;"}, $cut);
						$pubids = request_tab("	SELECT p.index FROM publications AS p 
									LEFT JOIN auteurs_x_publications AS axp ON p.index = axp.ref_publication
									LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index 
									WHERE axp.position = 1
									ORDER BY upper(a.desaccentue), upper(a.prenom), annee, titre
									OFFSET $offset LIMIT $limit;", $dbc);
						
						foreach my $id (@{$pubids}) {
							my $pub = pub_formating($id->[0], $dbc );
							$publist .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$id->[0]"}, $pub ) . getPDF($id->[0]) );
						}
					}
					else {
						$cut = span({-class=>'section', -style=>"font-size: 12px;"}, $cut);
					}
					my $link = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&from=$offset&to=$limit"}, $cut);
					
					push (@{$sections}, $link);
						
					$offset += $limit;
					$limit = 0;
				}
			}
		}
		else {
			
			$pubids = request_tab("	SELECT p.index FROM publications AS p 
						LEFT JOIN auteurs_x_publications AS axp ON p.index = axp.ref_publication
						LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index WHERE axp.position = 1
						ORDER BY upper(a.desaccentue), upper(a.prenom), annee, titre;", $dbc);
			
			foreach my $id (@{$pubids}) {
				my $pub = pub_formating($id->[0], $dbc );
				$publist .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$id->[0]"}, $pub ) . getPDF($id->[0]) );
			}
		}
				
		$publist .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		my $table;
		if ($dbase ne 'cool') {
			$table = Tr(
					td( div({-class=>'titre'}, ucfirst($trans->{"publications"}->{$lang}))),
					td({-style=>'text-align: center;'}, join('&nbsp;',@{$sections}) )
				);
		}
		else {
			$table = Tr(
					td( div({-class=>'titre'}, ucfirst($trans->{"publications"}->{$lang})))
				).
				Tr(
					td({-style=>'text-align: left;'}, join('&nbsp;',@{$sections}) )
				);
		}
				
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table({-style=>'width: 100%;'},
						$table
					), br,
					$publist
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Plants list
#################################################################
sub associations {
	
	if ( my $dbc = db_connection($config) ) {
		
		my $associations;
		my $req;
		#my $plantsids = request_tab("SELECT index, ref_valide
		#				FROM plantes
		#				WHERE get_host_plant_name(index) ILIKE '$alph%'
		#				AND index in (SELECT distinct ref_plante FROM taxons_x_plantes)
		#				AND ref_rang != 2
		#				ORDER BY get_host_plant_name(index);",$dbc);
		#
		#my $plants;
		#foreach (@{$plantsids}) {
		#	my ($pid, $pvid) = @{$_};
		#	$pvid = $pvid || 0;
		#	push(@{$plants}, [$pid, $pvid, @{@{request_tab("SELECT p.nom, p.autorite, p.famille, p.rang, pv.nom, pv.autorite, pv.famille, pv.rang
		#					FROM get_host_plant($pid) AS p
		#					LEFT JOIN get_host_plant($pvid) AS pv ON 1=1;",$dbc)}->[0]}]);
		#}
		#		
		#my $associations .= start_ul({});
		#my $famord;
		#my $alphord;
		#if ($mode eq 'family') {
		#	my @sorted = sort {$a->[4] cmp $b->[4]} @{$plants};
		#	
		#	my $current;
		#	foreach my $row ( @sorted ){
		#		my $pdisp;
		#		my $cardid = $row->[1] || $row->[0];
		#		$pdisp = i("$row->[2]")." $row->[3]";
		#		if (!$current) { $associations .= li(div($row->[4])); $current = $row->[4]; }
		#		elsif ($row->[4] ne $current) { $associations .= li({-style=>'margin-top: 1em;'}, $row->[4]); $current = $row->[4]; }
		#		$associations .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$cardid"}, $pdisp));
		#	}
		#	
		#	$famord = span({-class=>'xsection'},  ucfirst($trans->{'family'}->{$lang}));
		#	$alphord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plants"},  ucfirst($trans->{'alphabetic'}->{$lang}));
		#}
		#else {
		#	my @sorted = sort {$a->[2] cmp $b->[2]} @{$plants};
		#	
		#	foreach my $row ( @sorted ){
		#		my $pdisp;
		#		my $cardid = $row->[1] || $row->[0];
		#		$row->[4] = $row->[4] ? " ($row->[4])" : '';
		#		$pdisp = i("$row->[2]")." $row->[3]$row->[4]";
		#		$row->[7] = $row->[7] ? " $row->[7]" : '';
		#		$row->[8] = $row->[8] ? " ($row->[8])" : '';
		#		if ($row->[1]) { $pdisp .= " [ $row->[6]$row->[7]$row->[8] ]" }
		#		$associations .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$cardid"}, $pdisp));
		#	}
		#	
		#	$famord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plants&mode=family"},  ucfirst($trans->{'family'}->{$lang}));
		#	$alphord = span({-class=>'xsection'},  ucfirst($trans->{'alphabetic'}->{$lang}));
		#}
		
		my $types = request_tab("SELECT index, $lang FROM types_association", $dbc, 2);
						
		my $title;
		my $values;
		my $card;
				
		foreach my $assocType (sort {$a->[1] cmp $b->[1]} @{$types}) {
			my $typeA = $assocType->[0];
			$req = "SELECT DISTINCT t.index, (get_taxon_associe(t.index)).*, t.ref_parent
				FROM taxons_associes AS t
				WHERE t.index";
			
			$values = "(SELECT DISTINCT ref_taxon_associe FROM taxons_x_taxons_associes WHERE ref_type_association = ".$typeA.")";	
			
			$card = 'associate';

			$title = ucfirst($assocType->[1]);
			my $txt = request_tab("$req IN $values AND t.nom NOT ILIKE 'unknown';", $dbc, 2);
			
			if(scalar(@{$txt})) {
			
				my %assocs = undef;
				foreach my $relation (@{$txt}) {
					my 	($tassid, $name, $authority, $family, $order, $rang, $validname, $parent) = 
						($relation->[0], $relation->[1], $relation->[2], $relation->[3], $relation->[4], $relation->[5], $relation->[6], $relation->[7]);
						
					my $xid = $tassid;
					my $xname =  i("$name") . " $authority";
					$xname .= $validname ? ' = '.$validname : '';
					
					$assocs{$xid}{hierarchie} = "$order$family$name";
					$assocs{$xid}{label} = "$xname";
					$assocs{$xid}{rang} = $rang;
					
					$assocs{$xid}{element} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$xid"}, $xname);
					
					while ($parent and !exists($assocs{$parent})) {
						my $data = request_tab("$req = $parent AND t.nom NOT ILIKE 'unknown';", $dbc, 2);
											
						if (scalar(@{$data})) { 
							$assocs{$parent}{hierarchie} = "$data->[0][4]$data->[0][3]$data->[0][1]";
							$assocs{$parent}{label} = i($data->[0][1])." $data->[0][2]";
							$assocs{$parent}{rang} = $data->[0][5];
							if ($assocType->[0]) {
								$assocs{$parent}{element} = i($data->[0][1]) . " " . $data->[0][2];
							} else { 
								$assocs{$parent}{element} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$parent"}, i($data->[0][1]) . " " . $data->[0][2] ); 
							}
							$parent = $data->[0][7] || undef;
						}
						else { $parent = undef; }
					}
				}
							
				my $factor = 30;
				my ($alphaord, $hierarkord);
				my ($max, $dm) = (0, 'none');
				if (!$mode and 0) {
					
					$alphaord = span({-class=>'xsection'},  ucfirst($trans->{'alphabetic'}->{$lang}));
					$hierarkord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card"."s&mode=taxonomic"},  ucfirst($trans->{'taxonomic'}->{$lang}));
					
					$associations .= br;
					foreach my $key (sort {$assocs{$a}{label} cmp $assocs{$b}{label}} keys(%assocs)) {				
						$associations .= div({-class=>'cellAsLi'}, $assocs{$key}{element});
					}
				}
				elsif ($mode eq 'taxonomic' or 1) {
					
					$hierarkord = span({-class=>'xsection'},  ucfirst($trans->{'taxonomic'}->{$lang}));
					$alphaord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card"."s"},  ucfirst($trans->{'alphabetic'}->{$lang}));
					
					my $liste;
					my $ordkey;
					foreach my $key (sort {$assocs{$a}{hierarchie} cmp $assocs{$b}{hierarchie}} keys(%assocs)) {
						my $indent = 0;
						my $p = undef;
						if ($assocs{$key}{rang} eq 'order') { 
							$p = p;
							if($ordkey) {
								if($mode eq 'full') {
									$associations .= makeRetractableArray2 ("Title$ordkey"."_$typeA", "MagicCell$ordkey"."_$typeA MagicCell", $assocs{$ordkey}{element}, $liste, 'arrowRight', 'arrowDown', $max, $dm, 'true');
								}
								else {
									$associations .= makeRetractableArray ("Title$ordkey"."_$typeA", "MagicCell$ordkey"."_$typeA MagicCell", $assocs{$ordkey}{label}, $liste, 'arrowRight', 'arrowDown', $max, $dm, 'true', 'smallTitle');
								}
							}
							$ordkey = $key;
							$liste = undef;
						}
						else {
							if ($assocs{$key}{rang} eq 'species') { $indent = 3; }
							elsif ($assocs{$key}{rang} eq 'genus') { $indent = 2; }
							elsif ($assocs{$key}{rang} eq 'family') { $indent = 1; }
							
							$liste .= Tr( td({-colspan=>2, -class=>"MagicCell$ordkey"."_$typeA MagicCell", -style=>"display: $dm;"}, div({-class=>'cellAsLi', -style=>"margin-left: ".($indent*$factor)."px;"}, $assocs{$key}{element})) );
						}
						
						#$associations .= );
					}
					if($mode eq 'full') {
						$associations .= makeRetractableArray2 ("Title$ordkey"."_$typeA", "MagicCell$ordkey"."_$typeA MagicCell", $assocs{$ordkey}{element}, $liste, 'arrowRight', 'arrowDown', $max, $dm, 'true');
					}
					else {
						$associations .= makeRetractableArray ("Title$ordkey"."_$typeA", "MagicCell$ordkey"."_$typeA MagicCell", $assocs{$ordkey}{label}, $liste, 'arrowRight', 'arrowDown', $max, $dm, 'true', 'smallTitle');
					}
				}	
				
				my $xa = $assocType->[0];
				$fullhtml .= makeRetractableArray ('assoc'.$xa.'Title', 'assoc'.$xa.'MagicCell magicCell', ucfirst($title), Tr( td({-colspan=>2, -class=>'assoc'.$xa.'MagicCell magicCell', -style=>'display: none;'}, $associations) ), 'arrowRight', 'arrowDown', 1, 'none', 'true', undef, 'none');
				$associations = undef;
			}
		} # END OF LOOP
	
		$dbc->disconnect;
					
		print div({-class=>'content'}, div({-class=>'titre'}, ucfirst($trans->{'bioInteract'}->{$lang})) . $fullhtml);		
	}
	else {}
}

# Countries list
#################################################################
sub countries_list {
	if ( my $dbc = db_connection($config) ) {
		
		my $alphabet;
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		my $cn_numb = request_row( "SELECT count(*) FROM pays
						WHERE index in (SELECT distinct ref_pays from taxons_x_pays);", $dbc);
		
		if ($cn_numb->[0] > 100) { 
		
			unless($alph) { $alph = 'A' }
			
			$cn_numb = request_row( "SELECT count(*) FROM pays
							WHERE $lang ILIKE '$alph%'
							AND index in (SELECT distinct ref_pays from taxons_x_pays)
							$bornes;", $dbc);
			
			my $vlreq = "	SELECT upper(substring($lang,1,1)) AS letter, count(*) 
					FROM pays
					WHERE index in (SELECT distinct ref_pays from taxons_x_pays)
					GROUP BY substring($lang,1,1) 
					HAVING count(*) > 0 
					ORDER BY lower(substring($lang,1,1));";
					
			my $vletters = request_hash($vlreq, $dbc, 'letter');

			$alphabet = alpha_build($vletters);
		}
		else { $alph = '' }
		
		my $countries = request_tab("SELECT index, $lang FROM pays
						WHERE $lang ILIKE '$alph%'
						AND index in (SELECT distinct ref_pays from taxons_x_pays)
						ORDER BY reencodage($lang)
						$bornes;",$dbc);

		my $countries_list;
		foreach my $row ( @{$countries} ){
			$countries_list .= div({-class=>'cellAsLi'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$row->[0]"}, $row->[1] ) );
		}

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table({-style=>'width: 100%;'},
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{"geodistribution"}->{$lang})) ),
							td({-style=>'text-align: center;'}, join('&nbsp;&nbsp;', $alphabet) )
						)
					),
					div({-class=>'titre'}, ''),
					$countries_list
				);
				
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Images list
#################################################################
sub images_list {
		
		if ( my $dbc = db_connection($config) ) {
			
			my $html = br.br;
			
			my $req = "SELECT DISTINCT i.index, i.icone_url, txn.ref_taxon, nc.index, nc.orthographe, nc.autorite, i.url, r.en, i.groupe, i.tri
				FROM noms_x_images AS nxi
				LEFT JOIN images as i ON nxi.ref_image = i.index
				LEFT JOIN noms_complets AS nc ON nc.index = nxi.ref_nom
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nxi.ref_nom
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
				ORDER BY nc.orthographe, i.groupe, i.tri, i.index";
			
			my $images = request_tab($req,$dbc);			
			
			if (scalar(@{$images})) {
				
				my $imgs = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$images->[0][2]"}, i("$images->[0][4]") .  " $images->[0][5]") . p;
				my $current = $images->[0][3];
				foreach my $row ( @{$images} ){
						if ($row->[3] ne $current) {
							$imgs .= div({-style=>'clear: both;'}) . br . p . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$row->[2]"}, i("$row->[4]") .  " $row->[5]") . p;
							$current = $row->[3];
						}
						
						if ($dbase eq 'cool') {
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[6]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'})));
						}
						else {
							my $thumbnail = $row->[1] ? img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$row->[6]", -style=>'height: 150px; border: 0; margin: 0;'});
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, 
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[0]&search=nom"}, $thumbnail)
							);
						}
				}
				$imgs .= div({-style=>'clear: both;'}) . br;
				
				$imgs = Tr( td({-colspan=>2, -class=>'imgTypeMagicCell magicCell', -style=>"display: none;"}, $imgs ) );
				$html .= makeRetractableArray ('imgsTitle', 'imgTypeMagicCell magicCell', ucfirst($trans->{"type_img(s)"}->{$lang}), $imgs, 'arrowRight', 'arrowDown', 1, 'none', 'true');
			}
						
			$req = "SELECT i.index, i.icone_url, txi.ref_taxon, nc.index, nc.orthographe, nc.autorite, i.url, r.en
				FROM taxons_x_images AS txi
				LEFT JOIN images as i ON txi.ref_image = i.index
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txi.ref_taxon
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
				WHERE txn.ref_statut = 1
				AND txi.type ilike 'collection'
				ORDER BY nc.orthographe, i.groupe, i.tri, i.index";
			
			$images = request_tab($req,$dbc);
			
			if (scalar(@{$images})) {
				
				if ($html) { $html .= br; }
				
				my $imgs = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$images->[0][2]"}, i("$images->[0][4]") .  " $images->[0][5]") . p;
				my $current = $images->[0][3];
				foreach my $row ( @{$images} ){
						if ($row->[3] ne $current) {
							$imgs .= 	div({-style=>'clear: both;'}) . br . p . 
											a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$row->[2]"}, i("$row->[4]") .  " $row->[5]"
										) . p;
							$current = $row->[3];
						}
						if ($dbase eq 'cool') {
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[6]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'})) );
						}
						else {
							my $thumbnail = $row->[1] ? img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$row->[6]", -style=>'height: 150px; border: 0; margin: 0;'});
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[0]&search=taxon"}, $thumbnail) );
						}
				}
				$imgs .= div({-style=>'clear: both;'}) . br;
				
				$imgs = Tr( td({-colspan=>2, -class=>'imgColMagicCell magicCell', -style=>"display: none;"}, $imgs ) );
				$html .= makeRetractableArray ('imgsTitle', 'imgColMagicCell magicCell', ucfirst($trans->{"specincol"}->{$lang}), $imgs, 'arrowRight', 'arrowDown', 1, 'none', 'true');
			}
			
			$req = "SELECT i.index, i.icone_url, txi.ref_taxon, nc.index, nc.orthographe, nc.autorite, i.url, r.en
				FROM taxons_x_images AS txi
				LEFT JOIN images as i ON txi.ref_image = i.index
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txi.ref_taxon
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang 
				WHERE txn.ref_statut = 1
				AND txi.type ilike 'nature'
				ORDER BY nc.orthographe, i.groupe, i.tri, i.index";
			
			$images = request_tab($req,$dbc);
			
			if (scalar(@{$images})) {
				
				if ($html) { $html .= br; }
				
				my $imgs = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$images->[0][2]"}, i("$images->[0][4]") .  " $images->[0][5]") . p;
				my $current = $images->[0][3];
				foreach my $row ( @{$images} ){
						if ($row->[3] ne $current) {
							$imgs .= 	div({-style=>'clear: both;'}) . br . p . 
											a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$images->[0][7]&id=$row->[2]"}, i("$row->[4]") .  " $row->[5]"
										) . p;
							$current = $row->[3];
						}
						if ($dbase eq 'cool') {
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[6]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'})) );
						}
						else {
							my $thumbnail = $row->[1] ? img({-src=>"$row->[1]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$row->[6]", -style=>'height: 150px; border: 0; margin: 0;'});
							$imgs .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[0]&search=taxon"}, $thumbnail) );
						}
				}
				$imgs .= div({-style=>'clear: both;'}) . br;
				
				$imgs = Tr( td({-colspan=>2, -class=>'imgNatMagicCell magicCell', -style=>"display: none;"}, $imgs ) );
				$html .= makeRetractableArray ('imgsTitle', 'imgNatMagicCell magicCell', ucfirst($trans->{"specinnatura"}->{$lang}), $imgs, 'arrowRight', 'arrowDown', 1, 'none', 'true');
			}

			my $fullhtml = 	div({-class=>'content'}, $html);
							
			print $fullhtml;
		}
}

# vernaculars list
#################################################################
sub vernaculars {
	if ( my $dbc = db_connection($config) ) { 
		$dbc->{RaiseError} = 1;
		
		# Get the number of families to build up the list
		my $numb = '';
		my $sth = $dbc->prepare( "SELECT count(*) FROM noms_vernaculaires;" );
		$sth->execute();
		$sth->bind_columns( \( $numb ) );
		$sth->fetch();
		$sth->finish(); # finalize the request
		
		my $sep;
		if ($dbase eq 'cool') { $sep = br; } 

		my ($alphord, $paysord, $langord);
		
		my ( $id, $name, $langg, $pays, $taxid, $tax, $aut, $rk, $ref_pays, $reencode );
		my $list = start_ul({});
				
		if ($mode eq 'country' or $mode eq 'language') {
			
			my $order;
			my $mode2;
			if ($mode eq 'country') {
				$langord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=language"},  ucfirst($trans->{'langage'}->{$lang}));
				$alphord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars"},  ucfirst($trans->{'alphabetic'}->{$lang}));
				$paysord = span({-class=>'xsection'},  ucfirst($trans->{'country'}->{$lang}));
				$order = 'p.en, reencodage(v.nom), l.langage';
				$mode2 = 1;
			}
			elsif ($mode eq 'language') {
				$paysord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=country"},  ucfirst($trans->{'country'}->{$lang}));
				$alphord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars"},  ucfirst($trans->{'alphabetic'}->{$lang}));
				$langord = span({-class=>'xsection'},  ucfirst($trans->{'langage'}->{$lang}));
				$order = 'l.langage, reencodage(v.nom), p.en';
				$mode2 = 0;
			}
			
			$sth = $dbc->prepare( "SELECT distinct v.index, v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, v.ref_pays, reencodage(v.nom)
						FROM noms_vernaculaires AS v
						LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_vernaculaire
						LEFT JOIN langages AS l ON v.ref_langage = l.index
						LEFT JOIN pays AS p ON v.ref_pays = p.index
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txv.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN rangs AS r ON r.index = nc.ref_rang
						WHERE txn.ref_statut = 1
						ORDER BY $order;");
			$sth->execute( );
			$sth->bind_columns( \( $id, $name, $langg, $pays, $taxid, $tax, $aut, $rk, $ref_pays, $reencode ) );

			my $current;
			while ( $sth->fetch() ){	
				if ($mode2) {
					if ($pays) {
						if (!$current) { $list .= li(span({-class=>'soustitre'}, $pays)); $current = $pays; }
						elsif ($pays ne $current) { $list .= li(br . div({-class=>'soustitre'}, $pays)); $current = $pays; }
					}
					else {
						if ($current ne 'others') { $list .= li(br . div({-class=>'soustitre'}, $trans->{'unassigned'}->{$lang})); $current = 'others'; }
					}
				}
				else {
					if (!$current) { $list .= li(div({-class=>'soustitre'}, $langg)); $current = $langg; }
					elsif ($langg ne $current) { $list .= li(br . div({-class=>'soustitre'}, $langg)); $current = $langg; }
				}

				my $xpays;
				if ($pays) { $xpays = " in " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$ref_pays"}, $pays) }
				$list .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$id"}, "$name") . $xpays . " ($langg)" .
								$sep . " vernacular name of " . 
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rk&id=$taxid"}, "$tax $aut" ) );
			}
		}
		else {
			$sth = $dbc->prepare( "SELECT distinct v.index, v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, v.ref_pays, reencodage(v.nom)
						FROM noms_vernaculaires AS v
						LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_vernaculaire
						LEFT JOIN langages AS l ON v.ref_langage = l.index
						LEFT JOIN pays AS p ON v.ref_pays = p.index
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txv.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN rangs AS r ON r.index = nc.ref_rang
						WHERE txn.ref_statut = 1
						ORDER BY reencodage(v.nom);");
			$sth->execute( );
			$sth->bind_columns( \( $id, $name, $langg, $pays, $taxid, $tax, $aut, $rk, $ref_pays, $reencode ) );
			
			while ( $sth->fetch() ){	
				my $xpays;
				if ($pays) { $xpays = " in " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$ref_pays"}, $pays) }
				$list .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$id"}, "$name") . $xpays . " ($langg)" .
								$sep . " vernacular name of " . 
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rk&id=$taxid"}, "$tax $aut" ) );
			}

			$langord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=language"},  ucfirst($trans->{'langage'}->{$lang}));
			$paysord = a({-class=>'section', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernaculars&mode=country"},  ucfirst($trans->{'country'}->{$lang}));
			$alphord = span({-class=>'xsection'},  ucfirst($trans->{'alphabetic'}->{$lang}));			
		}
		$list .= end_ul();
		
		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml =  	div({-class=>'content'},
					$totop,
					$prevnext,
					table(
						Tr(
							td( div({-class=>'titre'}, ucfirst($trans->{'vernacular(s)'}->{$lang}) . "&nbsp; " . span({-style=>"font-size: 0.8em;"}, $trans->{'sortedby'}->{$lang}. ":")) ),
							td("&nbsp;&nbsp; " . $alphord . '&nbsp;&nbsp;' . $paysord . '&nbsp;&nbsp;' . $langord )
						)
					), p,
					$list
				);
				
		print $fullhtml;
		
		$dbc->disconnect; # disconnection
	}
	else {} # Connection failed
}

# Type categories list
#################################################################
sub types_list {
	if ( my $dbc = db_connection($config) ) {
		
		# Counting the number of type categories 
		my $tc_numb = request_row( "SELECT count(*) FROM types_type;", $dbc );;

		# Fetch Type categories list from DB
		my $types = request_tab( "SELECT index, $lang FROM types_type;", $dbc ); 

		my $types_tab = start_ul({});
		foreach my $row ( @{$types} ){
			$types_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=type&id=$row->[0]"}, $row->[1] ) );
		}
		$types_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"TY_list"}->{$lang})),
					div({-class=>'titre'}, "$tc_numb->[0] $trans->{'type_cat'}->{$lang}"),
					$types_tab
				);
		
		print $fullhtml;			
		
		$dbc->disconnect;
	}
	else {}
}

# Repositories list
#################################################################
sub repositories_list {
	if ( my $dbc = db_connection($config) ) {
		
		# Counting the number of repositories
		my $de_numb = request_row("SELECT count(*) FROM lieux_depot;",$dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		# Fetch the repositories
		my $repositories = request_tab("SELECT l.index, l.nom, $lang FROM lieux_depot AS l LEFT JOIN pays as p ON (l.ref_pays = p.index)
											WHERE l.index in (SELECT DISTINCT ref_lieux_depot FROM noms_x_types)
											ORDER BY p.$lang, l.nom $bornes;",$dbc);
		# build html
		my $de_tab = start_ul({-class=>'exploul'});
		foreach my $row ( @{$repositories} ){
			my $country = $row->[2] ? ", $row->[2]" : '';
			$de_tab .= li({-class=>'exploli'}, a({-class=>'exploa', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=repository&id=$row->[0]"}, "$row->[1]" ) . "$country" );
		}
		$de_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"repositories"}->{$lang})),
					$de_tab
				);
		
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Eras list
#################################################################
sub eras_list {
	if ( my $dbc = db_connection($config) ) {
		
		# Counting the number of eras
		my $er_numb = request_row( "SELECT count(*) FROM periodes WHERE index in (SELECT DISTINCT ref_periode FROM taxons_x_periodes);", $dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		# Fetch Eras list from DB
		my $eras = request_tab("SELECT index, $lang, debut, fin FROM periodes WHERE index in (SELECT DISTINCT ref_periode FROM taxons_x_periodes) ORDER BY debut;",$dbc);

		my $eras_list = start_ul({});
		foreach my $row ( @{$eras} ){
			$eras_list .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=era&id=$row->[0]"}, "$row->[1] $row->[2]-$row->[3] Ma" ) );
		}
		$eras_list .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"eras"}->{$lang})),
					$eras_list
				);
		
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Regions list
#################################################################
sub regions_list {
	if ( my $dbc = db_connection($config) ) {

		my $re_numb = request_row("SELECT count(*) FROM regions;",$dbc);
				
		my $regions = request_tab("SELECT r.index, r.nom, p.$lang
						FROM regions AS r
						LEFT JOIN pays AS p ON p.index = r.ref_pays
						ORDER BY r.nom, p.$lang;",$dbc);


		my $re_tab = start_ul({});
		foreach my $row ( @{$regions} ){
			if ($row->[2]) { $row->[1] .= " ($row->[2])" }
			$re_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=region&id=$row->[0]"}, $row->[1] ) );
		}
		$re_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"regions"}->{$lang})),
					div({-class=>'titre'}, "$re_numb->[0] $trans->{'regions'}->{$lang}"),
					$re_tab
				);
		
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Agents list
#################################################################
sub agents_list {
	if ( my $dbc = db_connection($config) ) {

		my $a_numb = request_row("SELECT count(*) FROM agents_infectieux;",$dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }
		
		my $a_list = request_tab("	SELECT ai.index, ai.$lang, tai.$lang FROM agents_infectieux AS ai LEFT JOIN types_agent_infectieux AS tai
						ON ai.ref_type_agent_infectieux = tai.index
						ORDER BY tai.$lang, ai.$lang
						$bornes;",$dbc);

		my $a_tab .= start_ul({});
		foreach my $agent ( @{$a_list} ){
			$a_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=agent&id=$agent->[0]"}, i("$agent->[1]") ) . " $agent->[2]" );
		}
		$a_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"A_list"}->{$lang})),
					div({-class=>'titre'}, "$a_numb->[0] $trans->{'agents'}->{$lang}"),
					$a_tab
				);
		
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Editions list
#################################################################
sub editions_list {
	if ( my $dbc = db_connection($config) ) {
		my $ed_tab;
		my $ed_numb = request_row("SELECT count(*) FROM editions;;",$dbc);
		
		my $ed_list = request_tab("	SELECT e.index, e.nom, v.nom, p.$lang FROM editions AS e
						LEFT JOIN villes AS v ON e.ref_ville = v.index
						LEFT JOIN pays AS p ON v.ref_pays = p.index
						ORDER BY p.$lang, v.nom, e.nom;",$dbc);

		$ed_tab .= start_ul({});
		foreach my $edition ( @{$ed_list} ){
			$ed_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=edition&id=$edition->[0]"}, i("$edition->[1]") ) . " $edition->[2], $edition->[3]" );
		}
		$ed_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"ED_list"}->{$lang})),
					div({-class=>'titre'}, "$ed_numb->[0] $trans->{'editions'}->{$lang}"),
					$ed_tab
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Habitats list
#################################################################
sub habitats_list {
	if ( my $dbc = db_connection($config) ) {
		my $ha_tab;
		my $ha_numb = request_row("SELECT count(*) FROM habitats;",$dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		my $ha_list = request_tab("SELECT index, $lang FROM habitats ORDER BY $lang $bornes;",$dbc);

		$ha_tab .= start_ul({});
		foreach my $habitat ( @{$ha_list} ){
			$ha_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=habitat&id=$habitat->[0]"}, "$habitat->[1]" ) );
		}
		$ha_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"habitat(s)"}->{$lang})),
					div({-class=>'titre'}, "$ha_numb->[0] $trans->{'habitats'}->{$lang}"),
					$ha_tab
				);
		
		print $fullhtml;
		
		$dbc->disconnect;
	}
	else {}
}

# Localities list
#################################################################
sub localities_list {
	if ( my $dbc = db_connection($config) ) {
		my $lo_numb = request_row("SELECT count(*) FROM localites;",$dbc);

		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		my $lo_list = request_tab("	SELECT l.index, l.nom, r.nom, p.$lang FROM localites AS l
						LEFT JOIN regions AS r ON l.ref_region = r.index
						LEFT JOIN pays AS p ON r.ref_pays = p.index
						ORDER BY p.$lang, r.nom, l.nom
						$bornes;",$dbc);

		my $lo_tab = start_ul({});
		foreach my $locality ( @{$lo_list} ){
			$lo_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=locality&id=$locality->[0]"}, "$locality->[1]" ) . ", $locality->[2], $locality->[3]" );
		}
		$lo_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"LO_list"}->{$lang})),
					div({-class=>'titre'}, "$lo_numb->[0] $trans->{'localities'}->{$lang}"),
					$lo_tab
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Capture technics list
#################################################################
sub captures_list {
	if ( my $dbc = db_connection($config) ) {
		my $ca_numb = request_row("SELECT count(*) FROM modes_capture;",$dbc);
		
		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		my $ca_list = request_tab("SELECT index, $lang FROM modes_capture ORDER BY $lang $bornes;",$dbc);

		my $ca_tab = start_ul({});
		foreach my $capture ( @{$ca_list} ){
			$ca_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=capture&id=$capture->[0]"}, "$capture->[1]" ) );
		}
		$ca_tab .= end_ul();

		my $prevnext;
		if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{"CA_list"}->{$lang})),
					div({-class=>'titre'}, "$ca_numb->[0] $trans->{'captures'}->{$lang}"),
					$ca_tab
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Abstract panel
#################################################################
sub makeboard {
		
	my $dbh;
	if ($config_file eq $synop_conf) { 
		my $config2 = get_connection_params($config_file);
		$dbh = db_connection($config2, 'EDITOR') or die;
	}
	else {
		my $config2 = {};
		if ( open(CONFIG, $synop_conf) ) {
			while (<CONFIG>) { 
				chomp; s/#.*//; s/^\s+//; s/\s+$//; next unless length;
				my ($option, $value) = split(/\s*=\s*/, $_, 2);
				$config2->{$option} = $value;
			}
			close(CONFIG);
		} else { die "No configuration file for synopsis edition could be found\n";}
	
		$dbh = db_connection($config2) or die;
	}
	
	my ($nbfam) = @{request_row("SELECT count(*) FROM taxons WHERE ref_rang = (SELECT index FROM rangs where en = 'family');",$dbh)};
	my ($nbsubfam) = @{request_row("SELECT count(*) FROM taxons WHERE ref_rang = (SELECT index FROM rangs where en = 'subfamily');",$dbh)};
	
	my $sth = $dbh->prepare( 'DELETE FROM synopsis;' ) or die $dbh->errstr;
	$sth->execute() or  die $dbh->errstr;
	my $ranks_ids = get_rank_ids( $dbh );

	my $temp;
	
	if ( my $dbc = db_connection($config) ) {
		
		my $orders =  request_tab("SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
			LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
			LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
			WHERE en = 'order' AND n.orthographe NOT LIKE '%ncertae sedis%' AND txn.ref_statut = 1;",$dbc);
		
		unless (scalar(@{$orders})) { @{$orders} = ['']; }
		foreach my $order ( @{$orders} ){
		
		my $condition = $order->[0] ? "AND taxons.ref_taxon_parent = $order->[0]" : "AND taxons.ref_taxon_parent IS NULL";
		
		my $req = "	SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
                		LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				WHERE en = 'suborder' AND n.orthographe NOT LIKE '%ncertae sedis%' AND txn.ref_statut = 1 
				$condition
				ORDER BY n.orthographe;";
						
		my $suborders =  request_tab($req,$dbc);
		
		unless (scalar(@{$suborders})) { @{$suborders} = ['']; }
		foreach my $suborder ( @{$suborders} ){
		
			my $condition = $suborder->[0] ? "AND taxons.ref_taxon_parent = $suborder->[0]" : "AND taxons.ref_taxon_parent IS NULL";
			
			my $superfamilies =  request_tab("SELECT taxons.index, n.orthographe FROM taxons LEFT JOIN rangs ON taxons.ref_rang = rangs.index
										LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
										LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
										WHERE en = 'super family' AND n.orthographe NOT LIKE '%ncertae sedis%' AND txn.ref_statut = 1 $condition order by n.orthographe;",$dbc);
			$temp .= "suborder: #$suborder->[0]\n";
			unless (scalar(@{$superfamilies})) { @{$superfamilies} = ['']; }
			foreach my $superfamily ( @{$superfamilies}){
				$temp .= "	superfamily: #$superfamily->[0]\n";
				my $families;
				if ($nbfam == 1 and $nbsubfam > 1) { 
															
					my $req = "SELECT taxons.index, n.orthographe FROM taxons 
								LEFT JOIN rangs ON taxons.ref_rang = rangs.index
								LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE en in ('subfamily') AND txn.ref_statut = 1 AND n.orthographe NOT LIKE '%ncertae sedis%'
								ORDER BY n.orthographe;";
													
					$families = request_tab($req, $dbc);
					
				} else {
					
					my $condition = $superfamily->[0] ? "AND taxons.ref_taxon_parent = $superfamily->[0]" : "AND taxons.ref_taxon_parent IS NULL";
					
					my $req = "SELECT taxons.index, n.orthographe FROM taxons 
								LEFT JOIN rangs ON taxons.ref_rang = rangs.index
								LEFT JOIN taxons_x_noms AS txn ON taxons.index = txn.ref_taxon
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE en in ('family') AND txn.ref_statut = 1 AND n.orthographe NOT LIKE '%ncertae sedis%'
								$condition
								ORDER BY n.orthographe;";
								
					$families = request_tab($req, $dbc);
				}
				
				my $totnames;
				foreach my $family ( @{$families} ){
					$temp .= "		family: #$family->[0]\n";				
					$totnames = 0;	
					my $ssp_sons = son_taxa($family->[0],  $ranks_ids->{"subspecies"}->{"index"}, $dbc);
					my $sp_sons = son_taxa($family->[0],  $ranks_ids->{"species"}->{"index"}, $dbc);
					my $ge_sons = son_taxa($family->[0],  $ranks_ids->{"genus"}->{"index"}, $dbc);
					
					my $getaxa = scalar  @{$ge_sons};
					my $genames;
					my $plants = 0;
					my $pays = 0;
					my $images = 0;
					if ( $getaxa ) {					
						
						my $indexes = "(".join(',',@{$ge_sons}).")";
												
						$genames = request_row("SELECT count(distinct ref_nom) FROM taxons_x_noms WHERE ref_taxon IN $indexes;",$dbc);
						$genames = $genames->[0];
						
						my $pys = request_row("SELECT count(distinct ref_pays) FROM taxons_x_pays WHERE ref_taxon IN $indexes;",$dbc);
						$pays += $pys->[0];
						
						my $img = request_row("SELECT count(distinct ref_image) FROM taxons_x_images WHERE ref_taxon IN $indexes;",$dbc);
						$images += $img->[0];
						my $img = request_row("SELECT count(distinct ref_image) FROM noms_x_images WHERE ref_nom IN (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_taxon IN $indexes);",$dbc);
						$images += $img->[0];

						$totnames += $genames;
					}

					my $sptaxa = scalar  @{$sp_sons};
					my $spnames = 0;
					if ( $sptaxa ){
						my $indexes = "(".join(',',@{$sp_sons}).")";
						
						$spnames = request_row("SELECT count(ref_nom) FROM taxons_x_noms WHERE ref_taxon IN $indexes;",$dbc);    
						$spnames = $spnames->[0];

						my $pys = request_row("SELECT count(distinct ref_pays) FROM taxons_x_pays WHERE ref_taxon IN $indexes;",$dbc);
						$pays += $pys->[0];
						
						my $pls = request_row("SELECT count(distinct ref_taxon_associe) FROM taxons_x_taxons_associes WHERE ref_taxon IN $indexes;",$dbc);
						$plants += $pls->[0];
 
						my $img = request_row("SELECT count(distinct ref_image) FROM taxons_x_images WHERE ref_taxon IN $indexes;",$dbc);
						$images += $img->[0];
						my $img = request_row("SELECT count(distinct ref_image) FROM noms_x_images WHERE ref_nom IN (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_taxon IN $indexes);",$dbc);
						$images += $img->[0];
						
						$totnames += $spnames;
					}
					
					my $ssptaxa = scalar  @{$ssp_sons};
					my $sspnames = 0;
					if ( $ssptaxa ){
						my $indexes = "(".join(',',@{$ssp_sons}).")";
						
						$sspnames = request_row("SELECT count(ref_nom) FROM taxons_x_noms WHERE ref_taxon IN $indexes;",$dbc);    
						$sspnames = $sspnames->[0];
					
						#my $pls = request_row("SELECT count(distinct ref_taxon_associe) FROM taxons_x_taxons_associes WHERE ref_taxon IN $indexes;",$dbc);
						#$plants += $pls->[0];
                                                #
						#my $pys = request_row("SELECT count(distinct ref_pays) FROM taxons_x_pays WHERE ref_taxon IN $indexes;",$dbc);
						#$pays += $pys->[0];
						
						#my $img = request_row("SELECT count(distinct ref_image) FROM taxons_x_images WHERE ref_taxon IN $indexes;",$dbc);
						#$images += $img->[0];
						
						$totnames += $sspnames;
					}
				
					my $flist = 'ordre, sous_ordre, super_famille, famille, genres, especes, noms, publications, plantes, pays, images';
					my $vlist = "'$order->[1]', '$suborder->[1]', '$superfamily->[1]', '$family->[1]', $getaxa, $sptaxa, $totnames, Null, $plants, $pays, $images";
					my $req = "INSERT INTO synopsis ($flist) VALUES ($vlist);";
															
					my $sth = $dbh->prepare( $req ) or die "$dbh->errstr : $req";
					$sth->execute() or  die "$dbh->errstr : $req";
				}
			}
			
		}}
		
		#if ($dbase eq 'aleurodes') { die $temp; }
		
		board();
		$dbh->disconnect; 
		$dbc->disconnect; 
	}
	else {}
}

sub board {
	if ( my $dbc = db_connection($config) ) {
		my ($nbfam) = @{request_row("SELECT count(*) FROM taxons WHERE ref_rang = (SELECT index FROM rangs where en = 'family');",$dbc)};
		my ($nbsubfam) = @{request_row("SELECT count(*) FROM taxons WHERE ref_rang = (SELECT index FROM rangs where en = 'subfamily');",$dbc)};
		my $pub_numb = request_row("SELECT count(*) FROM publications;",$dbc);
		my $counts = request_row("SELECT sum(genres), sum(especes), sum(noms), sum(plantes), sum(pays), sum(images) FROM synopsis;",$dbc);
		my $rows = request_tab("SELECT ordre, sous_ordre, super_famille, famille, genres, especes, noms, publications, plantes, pays, images, modif FROM synopsis ORDER BY famille;",$dbc);
		my $last = $rows->[0][11];
		my $content;
		if ($card eq 'makeboard') { $card = 'board'}
		my $prevnext;
		my $sup;
		if (scalar(@{$rows}) >= 1) {
			if ($dbase eq 'cipa') { $prevnext = prev_next_topic($card); }
			if ($nbfam == 1) {
				if($nbsubfam) { $sup = 'subfamilys'; }
				else { $rows->[0][7] = $pub_numb->[0]; $sup = 'family'; }
			} 
			else {
				$sup = 'familys'
			}
			
			my ($ptit, $prow, $ptot, $imglbl, $imgtot);
			$ptit = td({-style=>'width: 100px;'}, b(ucfirst($trans->{'associated_taxa'}->{$lang})));
			$ptot = $counts->[3] ? td({-style=>'width: 100px;'}, b(ucfirst($counts->[3]))) : td({-style=>'width: 100px;'}, b('-'));
			$imglbl = td({-style=>'width: 100px;'}, b(ucfirst($trans->{'images'}->{$lang})));	
			$imgtot = $counts->[5] ? td({-style=>'width: 100px;'}, b(ucfirst($counts->[5]))) : td({-style=>'width: 100px;'}, b('-'));
			
			$content .=	Tr({-class=>'synodiv'},
						td({-style=>'width: 150px; padding-bottom: 5px;'}, b(ucfirst($trans->{"$sup"}->{$lang}))),
						td({-style=>'width: 100px; padding-bottom: 5px;'}, b(ucfirst($trans->{'genera'}->{$lang}))),
						td({-style=>'width: 100px; padding-bottom: 5px;'}, b(ucfirst($trans->{'speciess'}->{$lang}))),
						td({-style=>'width: 100px; padding-bottom: 5px;'}, b(ucfirst($trans->{'names'}->{$lang}))),
						td({-style=>'width: 100px; padding-bottom: 5px;'}, b(ucfirst($trans->{'countries'}->{$lang}))),
						$ptit,                                  
						$imglbl,
						td({-style=>'width: 100px; padding-bottom: 5px;'}, b(ucfirst($trans->{'publications'}->{$lang})))
					);
					
			my ($ord, $subord, $supfam) = ($rows->[0][0], $rows->[0][1], $rows->[0][2]);
			#$content .= 	span({-class=>'synoord'}, $ord).
			#		span({-class=>'synosubord'}, $subord).
			#		span({-class=>'synosupfam'}, $supfam);
			
			
			# LES TOTAUX POUR CHAQUE COLONNE EN PREMIERE LIGNE
			if ($dbase =~ m/flow/) {
				$content .= 	Tr({-class=>'synodiv'},
							td({-style=>'width: 150px;'}, b(ucfirst(scalar(@{$rows})))),
							td({-style=>'width: 100px;'}, b(ucfirst($counts->[0]))),
							td({-style=>'width: 100px;'}, b(ucfirst($counts->[1]))),
							td({-style=>'width: 100px;'}, b(ucfirst($counts->[2]))),
							td({-style=>'width: 100px;'}, b(ucfirst($counts->[4]))),
							$ptot,                                  
							$imgtot,
							td({-style=>'width: 100px;'}, b(ucfirst($pub_numb->[0])))
						) . 
						Tr(	td({-style=>'height: 20px;'}) );
			}
				
			# LES LIGNES DU SYNOPSIS
			foreach my $row (@{$rows}) {
				#unless ($row->[0] eq $ord) { $ord = $row->[0]; $content .= span({-class=>'synoord'}, $ord);}
				#unless ($row->[1] eq $subord) { $subord = $row->[1]; $content .= span({-class=>'synosubord'}, $subord);}
				#unless ($row->[2] eq $supfam) { $supfam = $row->[2]; $content .= span({-class=>'synosupfam'}, $supfam);}
				my $famlink = request_row("SELECT ref_taxon FROM taxons_x_noms WHERE ref_nom in (SELECT index FROM noms_complets WHERE orthographe = '$row->[3]') AND ref_statut = 1;",$dbc);
				$famlink = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=family&id=$famlink->[0]&loading=1"}, $row->[3]);
				
				my $prow = $row->[8] ? td({-style=>'width: 100px;'}, ucfirst($row->[8])) : td({-style=>'width: 100px; background: transparent;'}, '-');
				my $imgrow = $row->[10] ? td({-style=>'width: 100px;'}, $row->[10]) : td({-style=>'width: 100px;'}, '-');
				
				$content .= 	Tr({-class=>'synodiv'},
							td({-style=>'width: 150px;'}, ucfirst($famlink)),
							td({-style=>'width: 100px;'}, $row->[4]),
							td({-style=>'width: 100px;'}, $row->[5]),
							td({-style=>'width: 100px;'}, $row->[6]),
							td({-style=>'width: 100px;'}, $row->[9]),
							$prow,                                 
							$imgrow,
							td({-style=>'width: 100px;'}, $row->[7])
						);
			}
			
			# LES TOTAUX POUR CHAQUE COLONNE EN DERNIERE LIGNE
			if (($nbfam > 1 or ($nbfam == 1 and $nbsubfam > 1)) and $dbase !~ m/flow/) {
				$content .= 	Tr(
							td({-style=>'height: 20px;'})).
						Tr(
							td({-style=>'width: 150px;'}, b(ucfirst($trans->{'total'}->{$lang}))),
							td({-style=>'width: 100px;'}, b($counts->[0])),
							td({-style=>'width: 100px;'}, b($counts->[1])),
							td({-style=>'width: 100px;'}, b($counts->[2])),
							td({-style=>'width: 100px;'}, b($counts->[4])),
							$ptot,
							$imgtot,
							td({-style=>'width: 100px;'}, b($pub_numb->[0]))
						);
			}
		}
		my $maj;
		if($mode eq 'full'){ $maj = a({-style=>'margin-left: 25px;', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=makeboard"}, "$trans->{'uptodate'}->{$lang}"); }
		$maj = 	div({-class=>'synodiv'},
				$trans->{'dmaj'}->{$lang}." : $last ",
				$maj
			);

		
	 	$fullhtml =   	br.div({-class=>'content card'},
					$totop,
					$prevnext,
					div({-class=>'titre board'}, ucfirst($trans->{"board"}->{$lang})), br,
					table({-class=>'board', -border=>0}, $content),
					br,
					div({-class=>'board'}, $maj),
					br,
					"<a name='base'></a>"
				);
				
		print $fullhtml;
	}
}

##################################################################################################################################
# Cards
##################################################################################################################################
# Family card
#################################################################
#sub family_card {
#	if (url_param('mode') eq 'genera types') {
#		$ge_ids = son_taxa($family_id, $ranks_ids->{"genus"}->{"index"}, $dbc);
#
#		if ( scalar @{$ge_ids} ){
#		
#			my $gids = "(" . join(',', @{$ge_ids}) . ")";
#			my ( $genusid, $genusname, $genusautority, $page );
#			my $sth = $dbc->prepare( "SELECT t.index, nc.orthographe, nc.autorite, n.page_princeps FROM taxons AS t
#						LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
#						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
#						LEFT JOIN noms AS n ON n.index = nc.index
#						LEFT JOIN rangs AS r ON t.ref_rang = r.index
#						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#						WHERE s.en = 'valid' AND t.index IN $gids
#						ORDER BY n.orthographe;" );
#			$sth->execute( );
#			$sth->bind_columns( \( $genusid, $genusname, $genusautority, $page ) );
#			
#			$fam_taxa .= start_ul({});
#			while ( $sth->fetch() ){
#				$page = $page ? ": $page" : $page;
#				
#				$fam_taxa .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=genus&id=$genusid"}, i("$genusname") . " $genusautority$page"));
#				
#				my $synonyms = request_tab("	SELECT distinct nc.orthographe, nc.autorite, n.page_princeps, s.$lang
#								FROM noms_complets AS nc
#								LEFT JOIN noms AS n ON n.index = nc.index
#								LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
#								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#								WHERE s.en in ('nomen praeoccupatum','nomen nudum','synonym','nomen oblitum','previous rank', 'objective synonym')
#								AND txn.ref_taxon = $genusid;",$dbc);
#				
#				foreach my $syn (@{$synonyms}) {
#					if ($syn->[0] ne $genusname) {
#						$syn->[2] = $syn->[2] ? ": ".$syn->[2] : $syn->[2];
#						$fam_taxa .= li("= ". i($syn->[0]) . " " . $syn->[1] . $syn->[2] . " " . span({-style=>'color: #444444'}, $syn->[3]) );
#					}
#				}
#
#				my $sp_ids = request_tab("SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent = $genusid AND nom_rang_fils = 'species';",$dbc,1);
#		
#				if ( scalar @{$sp_ids} ){
#					my $ids = "(" . join(',', @{$sp_ids}) . ")";
#				
#					my ( $speciesid, $nameid, $speciesname, $speciesautority, $page_princeps, $brack );
#					my $sth2 = $dbc->prepare( "SELECT t.index, nc.index, nc.orthographe, nc.autorite, n.page_princeps, n.parentheses FROM taxons AS t 
#								LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
#								LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
#								LEFT JOIN noms AS n ON n.index = nc.index
#								LEFT JOIN rangs AS r ON t.ref_rang = r.index
#								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#								WHERE s.en = 'valid'
#								AND t.index IN $ids
#								AND n.gen_type = 't'
#								AND ( nc.orthographe NOT LIKE '%(%' OR nc.orthographe LIKE '%$genusname%$genusname%' )
#								ORDER BY n.orthographe;" );
#					$sth2->execute( );
#					$sth2->bind_columns( \( $speciesid, $nameid, $speciesname, $speciesautority, $page_princeps, $brack ) );
#				
#					while ( $sth2->fetch() ){
#						my $req = "	SELECT nc.orthographe, nc.autorite, n.page_princeps
#										FROM noms_complets AS nc
#										LEFT JOIN noms AS n ON n.index = nc.index
#										LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
#										LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#										WHERE txn.ref_taxon = $speciesid
#										AND s.en not in ('valid', 'correct use', 'misidentification', 'prevous identification')
#										AND n.gen_type = 't';";
#						
#						my $original = request_tab($req, $dbc);
#						
#						#if ($genusname eq '') { $fam_taxa .= $req; }
#						
#						if ($original->[0][0]) {
#							$speciesname = $original->[0][0]; $speciesautority = $original->[0][1]; $page_princeps = $original->[0][2];
#						}
#						else {
#							my $conditions;
#							$conditions = $brack ? "from 2 for length('$speciesautority')-2" : "from 1 for length('$speciesautority')";
#						
#							$original = request_tab("	SELECT nc.orthographe, nc.autorite, n.page_princeps
#											FROM noms_complets AS nc
#											LEFT JOIN noms AS n ON n.index = nc.index
#											LEFT JOIN taxons_x_noms AS txn ON nc.index = txn.ref_nom
#											LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#											WHERE txn.ref_taxon = $speciesid
#											AND s.en = 'previous combination'
#											AND nc.autorite = substring('$speciesautority' $conditions);",$dbc);
#						
#							if ($original->[0][0]) { $speciesname = $original->[0][0]; $speciesautority = $original->[0][1]; $page_princeps = $original->[0][2]; }
#						}
#						$page_princeps = $page_princeps ? ": $page_princeps" : $page_princeps;
#						$fam_taxa .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$speciesid"}, '&nbsp;&nbsp;&nbsp;&nbsp;' . i("$speciesname") . " $speciesautority$page_princeps " . span({-class=>'typeSpecies'}, "&nbsp;  ".$trans->{"type"}->{$lang} . p)));
#						$sps++;
#					}
#					$sth2->finish();
#				}
#			}
#			$sth->finish();
#			$fam_taxa .= end_ul();
#			
#			$fam_taxa = 	div({-class=>'titre'}, scalar @{$ge_ids} . " $trans->{'genus(s)'}->{$lang}"). p.
#					$fam_taxa;
#		}
#		else {
#			#$fam_taxa = ul( li($trans->{"UNK"}->{$lang}));
#		}
#	}
#}

sub get_vernaculars {
	
	my ($dbc, $field, $indexes, $display) = @_;
	
	# fetching vernacular names
	my $req = "SELECT nv.index, nom, l.langage, p.en, txv.ref_pub, nv.ref_pays, txv.page FROM taxons_x_vernaculaires AS txv 
			LEFT JOIN noms_vernaculaires AS nv ON nv.index = txv.ref_vernaculaire 
			LEFT JOIN langages as l ON l.index = nv.ref_langage 
			LEFT JOIN pays as p ON p.index = nv.ref_pays
			LEFT JOIN publications AS pb ON txv.ref_pub = pb.index
			WHERE $field IN ($indexes)
			ORDER BY nom, pb.annee;";

	my $vernaculars = request_tab($req, $dbc);
	my $commons;
	if (scalar @{$vernaculars}) {
			
		my %verns;
		my @order;
		foreach (@{$vernaculars}) {
			my @pub;
			if ($_->[4]) { @pub = publication($_->[4], 0, 1, $dbc); }				
			
			unless (exists $verns{$_->[0]}) { 
				push(@order, $_->[0]);
				$verns{$_->[0]} = {};
				$verns{$_->[0]}{'label'} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=vernacular&id=$_->[0]"}, $_->[1] );
				if ($_->[3]) { $verns{$_->[0]}{'label'} .= " in " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$_->[5]"}, $_->[3]); }
				$verns{$_->[0]}{'label'} .= " (" . $_->[2] . ")";
				
				$verns{$_->[0]}{'refs'} = ();
			}
			
			if (scalar @pub) {
				my $page;
				if ($_->[6]) { $page = ":&nbsp;$_->[6]" }
				push(@{$verns{$_->[0]}{'refs'}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$_->[4]"}, "$pub[1]$page" ) . getPDF($_->[4]));
			}
		}
				
		foreach (@order) {
			my $list = $verns{$_}{'label'};
			if ($verns{$_}{'refs'}) { $list .= ' according to ' . join (', ', @{$verns{$_}{'refs'}}); }
			$commons .= Tr( td({-colspan=>2, -class=>'verMagicCell magicCell', -style=>"display: $display;"}, $list) );
		}
		
		$commons = makeRetractableArray ('verTitle', 'verMagicCell magicCell', ucfirst($trans->{"vernacular(s)"}->{$lang}), $commons, 'arrowRight', 'arrowDown', 1, $display, 'true');
	}
		
	return $commons;
}

# Family card
#################################################################
sub family_card { $rank = 'family'; taxon_card(); }

# Subfamily card
#################################################################
sub subfamily_card { $rank = 'subfamily'; taxon_card(); }

# Super tribe card
#################################################################
sub supertribe_card { $rank = 'supertribe'; taxon_card(); }

# Tribe card
#################################################################
sub tribe_card { $rank = 'tribe'; taxon_card(); }

# Subtribe card
#################################################################
sub subtribe_card { $rank = 'subtribe'; taxon_card(); }

# Genus card
#################################################################
sub genus_card { $rank = 'genus'; taxon_card(); }

# Subgenus card
#################################################################
sub subgenus_card { $rank = 'subgenus'; taxon_card(); }

# Species card
#################################################################
sub species_card { $rank = 'species'; taxon_card(); }

# Subspecies card
#################################################################
sub subspecies_card { $rank = 'subspecies'; taxon_card(); }

# variety card
#################################################################
sub variety_card { $rank = 'variety'; taxon_card(); }

# Function making a retractable array (by clicking on arrow image or on title)
#################################################################
sub makeRetractableArray {
	my ($iconeID, $rowsClass, $titre, $rows, $icon0, $icon1, $colspan, $default, $sep, $titleClass, $brk) = @_;
	
	my ($icon) = $default eq 'none' ? $icon0 : $icon1;
	
	$colspan++;
	$sep = $sep eq 'false' ? 'none' : 'table-cell';
	my $brkclass;
	unless ($brk) { $brk = $default; $brkclass = $rowsClass; }
	
	$titleClass = $titleClass ? $titleClass : 'titreReactif';
	my $topMargin = 0.3;
	if($titre eq 'legTitle') { $topMargin = 0; }
	
	my $reactiv = table({-cellpadding=>0, -cellspacing=>0, -style=>'border: 0px solid #666666;'},
						Tr( td({-colspan=>$colspan, -style=>"height: $topMargin"."em; line-height: $topMargin"."em; display: $sep; border: 0px solid black;"}, '') ),
						Tr( 
							td({-colspan=>$colspan},
								table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%; border: 0px solid #666666;'},
									Tr(
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1');", -style=>'border: 0px solid black; vertical-align: middle; width: 10px;'}, div({-id=>"$iconeID", -class=>"$icon", -style=>'border: 0px solid black;'}, '')),
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1');", -style=>'border: 0px solid black; vertical-align: middle; text-align: left;'}, div({-class=>$titleClass}, $titre))
									)
								)
							)
						),
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $brk; border: 0px solid black;", -class=>"$brkclass"}, '') ),
						# Tr( td({-colspan=>2, -class=>'myMagicCell magicCell'}, ) )
						$rows
						#.Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) )
					);	
	return $reactiv;
}

# Function making a retractable array (by clicking on arrow image or on title)
#################################################################
sub makeRetractableGraph {
	my ($iconeID, $rowsClass, $titre, $rows, $icon0, $icon1, $colspan, $default, $sep, $titleClass) = @_;
	
	my ($icon) = $default eq 'none' ? $icon0 : $icon1;
	
	$colspan++;
	$sep = $sep eq 'false' ? 'none' : 'table-cell';
	
	$titleClass = $titleClass ? $titleClass : 'titreReactif';
	
	my $reactiv = table({-id=>'graphTable', -cellpadding=>0, -cellspacing=>0, -style=>'border: 0px solid #666666; display: none;'},
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $sep; border: 0px solid black;"}, '') ),
						Tr( 
							td({-colspan=>$colspan},
								table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%; border: 0px solid #666666;'},
									Tr(
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1'); document.getElementById('sc_Div').scrollLeft = 10000;", -style=>'border: 0px solid black; vertical-align: middle; width: 10px;'}, div({-id=>"$iconeID", -class=>"$icon", -style=>'border: 0px solid black;'}, '')),
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1'); document.getElementById('sc_Div').scrollLeft = 10000;", -style=>'border: 0px solid black; vertical-align: middle; text-align: left;'}, div({-class=>$titleClass}, $titre))
									)
								)
							)
						),
						#Tr( td({-colspan=>$colspan, -style=>"height: 0em; line-height: 0em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}, '') ),
						# Tr( td({-colspan=>2, -class=>'myMagicCell magicCell'}, ) )
						$rows
						#.Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) )
					);	
	return $reactiv;
}

# Function making a retractable array (by clicking on arrow image or on title)
#################################################################
sub makeRetractableArraySemiClickable {
	my ($iconeID, $rowsClass, $titre, $rows, $icon0, $icon1, $colspan, $default, $sep, $titleClass, $href) = @_;
	
	my ($icon) = $default eq 'none' ? $icon0 : $icon1;
	
	$colspan++;
	$sep = $sep eq 'false' ? 'none' : 'table-cell';
	
	$titleClass = $titleClass ? $titleClass : 'titreReactif';
		
	my $reactiv = table({-cellpadding=>0, -cellspacing=>0, -style=>'border: 0px solid #666666;'},
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $sep; border: 0px solid black;"}) ).
						Tr( 
							td({-colspan=>$colspan},
								table(
									Tr(
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1');", -style=>'border: 0px solid black; vertical-align: middle; width: 10px;'}, div({-id=>"$iconeID", -class=>"$icon", -style=>'border: 0px solid black;'}, '&nbsp;')),
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1');", -style=>'border: 0px solid black; vertical-align: middle; text-align: left; padding-left: 3px;'}, div({-class=>$titleClass}, $titre)),
										td({-style=>'padding: 0;'}, $href)
									)
								)
							)
						).
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) ).
						# Tr( td({-colspan=>2, -class=>'myMagicCell magicCell'}, ) )
						$rows
						#.Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) )
					);
	return $reactiv;
}

# Function making a retractable array (by clicking on arrow image only)
#################################################################
sub makeRetractableArray2 {
	my ($iconeID, $rowsClass, $titre, $rows, $icon0, $icon1, $colspan, $default, $sep) = @_;
	
	my ($icon) = $default eq 'none' ? $icon0 : $icon1;
	
	$colspan++;
	$sep = $sep eq 'false' ? 'none' : 'table-cell';
		
	my $reactiv = table({-cellpadding=>0, -cellspacing=>0, -style=>'border: 0px solid #666666;'},
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $sep; border: 0px solid black;"}) ).
						Tr( 
							td({-colspan=>$colspan},
								table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%; border: 0px solid #666666;'},
									Tr(
										td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"magicCells('$iconeID', '$rowsClass', '$icon0', '$icon1');", -style=>'border: 0px solid black; vertical-align: middle; width: 10px;'}, div({-id=>"$iconeID", -class=>"$icon", -style=>'border: 0px solid black;'}, '&nbsp;')),
										td({-onMouseOver=>"this.style.cursor='pointer';", -style=>'border: 0px solid black; vertical-align: middle; text-align: left; padding-left: 3px;'}, div({-class=>'Reactif'}, $titre))
									)
								)
							)
						).
						Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; line-height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) ).
						# Tr( td({-colspan=>2, -class=>'myMagicCell magicCell'}, ) )
						$rows
						#.Tr( td({-colspan=>$colspan, -style=>"height: 0.3em; display: $default; border: 0px solid black;", -class=>"$rowsClass"}) )
					);
	return $reactiv;
}		

# Taxon card
#################################################################
sub taxon_card {
		
	my $test;
	if ( my $dbc = db_connection($config) ) {
		
		my ($rktest, $rkorder) = @{request_row("SELECT index, ordre FROM rangs WHERE en = '$rank';",$dbc)};
		my ($genus_order) = @{request_tab("SELECT ordre FROM rangs WHERE en ILIKE 'genus';", $dbc, 1)};
				
		unless($rktest) { exit; }
		
		my $positions;
		my %default_order = {
			'synonymy' => 1,
			'chresonymy' => 2,
			'graphic' => 3,
			'geological' => 4,
			'descent' => 5,
			'sites' => 6,
			'tdwg' => 6,
			'map' => 7,
			'hostplants' => 8,
			'associates' => 9,
			'types' => 10,
			'vernaculars' => 11,
			'images' => 12
		};

		# Fetch taxon attributes
		my $valid_name = request_row("SELECT	nc.index,
							nc.orthographe, 
							nc.autorite, 
							nc.ref_publication_princeps,
							n.orthographe, 
							n.ref_rang,
							n.ref_nom_parent,
							n.page_princeps,
							r.ordre,
							t.distribution_complete,
							t.plantes_completes,
							t.ref_rang,
							n.fossil,
							n.gen_type,
							td.en,
							td.$lang,
							n.ref_publication_designation,
							n.page_designation,
							(SELECT nom FROM auteurs where index = (SELECT ref_auteur FROM noms_x_auteurs WHERE ref_nom = nc.index AND position = 1)),
							txn.nom_label,
							(select all_to_rank(txn.ref_nom, 'subtribe', 'suborder', '<br>', 'down', 'notfull')),
							(select all_to_rank(txn.ref_nom_cible, 'subtribe', 'suborder', '<br>', 'down', 'notfull'))
							FROM noms_complets AS nc 
							LEFT JOIN noms AS n ON n.index = nc.index
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index
							LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
							LEFT JOIN rangs AS r ON r.index = t.ref_rang
							LEFT JOIN types_designation AS td ON td.index = n.ref_type_designation
							WHERE t.index = $id
							AND txn.ref_statut = 1;",$dbc);
							
		if ($valid_name->[11] != $rktest) { print $fullhtml = "URL forbiden"; exit; }
		
		my $tsp = $valid_name->[13] ? span({-class=>'typeSpecies'}, " &nbsp; " . $trans->{"type$rank"}->{$lang}) : '';
		
		if ($valid_name->[14]) {
			$tsp .= span({-class=>'typeSpecies'}, " $valid_name->[15]");
			if ($valid_name->[14] eq 'by subsequent designation' and $valid_name->[16]) {
				my @pub = publication($valid_name->[16], 0, 1, $dbc );
				if ($pub[1]) { 
					my $page;
					if ($valid_name->[17]) { $page = ":&nbsp;$valid_name->[17]" }
					$tsp .= span({-class=>'typeSpecies'}, "&nbsp;$trans->{'dansin'}->{$lang}&nbsp;");
					$tsp .= a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$valid_name->[16]"}, "$pub[1]$page" );
					$tsp .= getPDF($valid_name->[16]);
				}
			}
		}
		
		my $nlabl = $valid_name->[19] ? "&nbsp;$valid_name->[19]" : undef;
		my $formated_name = i("$valid_name->[1]") . " $valid_name->[2]" . $nlabl;
		my $ordre = $valid_name->[8];
		
		# Fetch taxon princeps publication
		my $publication;
		if ( $valid_name->[3] ) {
			$publication = div({-class=>'titre'}, ucfirst($trans->{"ori_pub"}->{$lang}));
			my $pub = pub_formating($valid_name->[3], $dbc, $valid_name->[7] );
			$publication .= table( Tr( td( 
						a({-href=>$scripts{$dbase}."db=$dbase&lang=$lang&card=publication&id=$valid_name->[3]"}, "$pub") . getPDF($valid_name->[3])
					) ) );
		}
				
		# Get parent taxa including family
		my $req = "SELECT	h.index_taxon_parent,
					h.index_rang_parent,
					h.nom_rang_parent,
					r.ordre,
					nc.orthographe,
					nc.autorite
					FROM hierarchie AS h 
					LEFT JOIN rangs AS r ON r.index = h.index_rang_parent
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = h.index_taxon_parent
					LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
					WHERE index_taxon_fils = $id
					AND txn.ref_statut = 1
					AND r.ordre > 2
					ORDER BY r.ordre DESC;";
					
		my $highers = request_tab($req,$dbc,'index_taxon_parent',2);
		
		my $ancesters;
		# Make the list of all the taxon names in order to search specimens
		my %names;
		$names{$valid_name->[0]}{'species'} = $valid_name->[4];
		
		unshift(@{$highers}, [$id, $valid_name->[5], $rank, $ordre, $valid_name->[1], $valid_name->[2]]);
		my ($navigation, $bulleinfo);
		my $indent = scalar(@{$highers}) - 2;
		my $indentUnit = 16;
		for (my $i=0; $i<$#{$highers}+1; $i++) {
			
			my $center;
			my $xtaxon = $highers->[$i];
			my $margin = ($indent - $i) > 0 ? ($indent - $i) * $indentUnit : 0;
			my $bridge;
			my $xcard = "taxon&rank=$xtaxon->[2]";
			$xcard .= $xtaxon->[2] eq 'family' ? "&loading=1" : "";
			$xcard .= $xtaxon->[2] eq 'subfamily' ? "&loading=1" : "";
			
			if (my $parent = $highers->[$i+1]) {
				$req = "SELECT	txn.ref_taxon,
						nc.orthographe,
						nc.autorite
						FROM hierarchie AS h 
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = h.index_taxon_fils
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						WHERE txn.ref_statut = 1
						AND index_rang_fils = $xtaxon->[1] AND index_taxon_parent = $parent->[0]
						ORDER BY orthographe, nc.autorite;";
				
				$bridge = div({-class=>'bridge'}, '');
			}
			else {
				$req = "SELECT	txn.ref_taxon,
						nc.orthographe, 
						nc.autorite
						FROM taxons_x_noms AS txn
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						WHERE txn.ref_statut = 1
						AND txn.ref_taxon IN (SELECT DISTINCT index_taxon_parent FROM hierarchie WHERE nom_rang_parent = '$xtaxon->[2]')
						ORDER BY nc.orthographe, nc.autorite;";
			}
			
			$center = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$xcard&id=$xtaxon->[0]"}, i($xtaxon->[4])." ".$xtaxon->[5]);
				
			# Get previous and next taxon with the same rank and the same parent taxon
			my $taxa = request_tab($req, $dbc,2);
			if (scalar(@{$taxa}) > 1) {
				my ( $previous_id, $prev_name, $prev_autority, $next_id, $next_name, $next_autority, $found);			
				my ( $first_id, $first_name, $first_autority ) = ( $taxa->[0][0], $taxa->[0][1], $taxa->[0][2] );
				my ( $last_id, $last_name, $last_autority ) = ( $taxa->[$#{$taxa}][0], $taxa->[$#{$taxa}][1], $taxa->[$#{$taxa}][2] );
				foreach my $taxon (@{$taxa}) {
					my ( $current_id, $current_name, $current_authority ) = ( $taxon->[0], $taxon->[1], $taxon->[2] );
					
					if ($found == 1) { ( $next_id, $next_name, $next_autority ) = ( $current_id, $current_name, $current_authority ); last; }
					else {
						if ( $current_id == $xtaxon->[0] ) { $found = 1; }
						else { ( $previous_id, $prev_name, $prev_autority ) = ( $current_id, $current_name, $current_authority ); }
					}
					
				}
				unless($previous_id) { ( $previous_id, $prev_name, $prev_autority ) = ( $last_id, $last_name, $last_autority ); }
				unless($next_id) { ( $next_id, $next_name, $next_autority ) = ( $first_id, $first_name, $first_autority ); }
				
				$navigation = prev_next_card($xcard, $bridge, $previous_id, div({-class=>'hierarch'}, $center), $next_id, "prev$xtaxon->[2]", "next$xtaxon->[2]", "0 0 0 ".$margin."px") . $navigation;
				$bulleinfo .= 	div({-class=>'info', -id=>"prev$xtaxon->[2]", -style=>'position: absolute; display: none;'}, i($prev_name) . " $prev_autority").
						div({-class=>'info', -id=>"next$xtaxon->[2]", -style=>'position: absolute; display: none;'}, i($next_name) . " $next_autority");
			}
			else {
				$navigation = 	table({-style=>"margin: 0 0 0 ".$margin."px;"}, Tr(
							td({-style=>'vertical-align: top; border: 0px solid black;'}, $bridge), 
							td({-style=>'vertical-align: middle; border: 0px solid black; padding-right: 6px;'}, div({-class=>'marker', -style=>'width: 10px, height: 16px; border: 0px solid black;'}, '')),
							td({-style=>'vertical-align: middle; border: 0px solid black;'}, div({-class=>'hierarch'}, $center))
						)) . $navigation;
			}
			
			if ($xtaxon->[2] eq 'genus') { $names{$valid_name->[0]}{'genus'} = $xtaxon->[4]; }
		}
		$bulleinfo = div({-style=>'border: 0px solid black;'}, $bulleinfo);
				
		# Get display attributes for all card elements
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = '$rank';", $dbc, 'element')};
		
		my $childs;
		my $descendants;
		my @sons_ids;
		my %sons_ranks;
		my %orderedElements;
		my $parentsIDs = $id;
						
		# Get children taxa
		unless ($display_modes{descent}{skip} and $mode ne 'full') {
		
			my $dm = $display_modes{descent}{display} ? 'table-cell' : 'none';
			$dm = $limit ? 'table-cell' : $dm;
			
			my %attributes;
			my @attribs = split('#', $display_modes{descent}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $decalage = $attributes{indentation} || 22;
			$decalage += $attributes{marge} || 6;
			$decalage = $decalage / 2;
			
			my ($ranks, %ordres, $limitOrder);		
			my $g = 2;
						
			my ($ranks_req, $desc_req, $total);
					
			$req = "SELECT ordre, en, count(*) FROM hierarchie LEFT JOIN rangs ON index_rang_fils = index WHERE index_taxon_parent IN ($parentsIDs) GROUP BY ordre, en ORDER BY ordre;";
			my $compteur = request_tab($req, $dbc, 2);
			
			my $default_limit = 0;
			unless($limit) {
				$limit = $attributes{default} || 'none';
				if (scalar(@{$compteur}) == 1) { $limit = $compteur->[0][1] }
				$default_limit = 1;
			}
				
			my %nbtaxa;
			foreach (@{$compteur}) { 
				$sons_ranks{$_->[0]}{nom} = $_->[1];
				$sons_ranks{$_->[0]}{valeur} = $_->[2];
				if ($_->[1] eq $limit) { $limitOrder = $_->[0]; }
				if ($_->[1] eq 'genus' || $_->[1] eq 'species') { $nbtaxa{$_->[1]} += $_->[2]; }
				$total += $_->[2];
			}
			my $nbtaxastr = join(', ', map { $nbtaxa{$_}." ".$trans->{$_.'s'}->{$lang} } keys(%nbtaxa) );
					
			if ($limit eq 'none') {
				
				$ranks_req = "SELECT DISTINCT r.ordre, r.en FROM hierarchie AS h LEFT JOIN rangs AS r ON r.index = h.index_rang_fils WHERE index_taxon_parent IN ($parentsIDs) ORDER BY r.ordre";
				
				$desc_req = "SELECT	h.index_taxon_fils,
						h.index_rang_fils,
						h.nom_rang_fils,
						r.ordre,
						r.$lang,
						t.ref_taxon_parent,
						nc.orthographe,
						nc.autorite,
						n.gen_type,
						r.en
						FROM hierarchie AS h 
						LEFT JOIN rangs AS r ON r.index = h.index_rang_fils
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = h.index_taxon_fils
						LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN noms AS n ON n.index = nc.index
						WHERE index_taxon_parent IN ($parentsIDs)
						AND txn.ref_statut = 1
						ORDER BY r.ordre DESC, nc.orthographe, nc.autorite;";
			}
			elsif ($limit ne 'none') {
				
				#$ranks_req = "SELECT DISTINCT r.ordre, r.en FROM hierarchie AS h LEFT JOIN rangs AS r ON r.index = h.index_rang_fils 
				#		WHERE index_taxon_parent = $id
				#		AND (index_taxon_fils IN ( SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent = $id and nom_rang_fils = '$limit' )
				#		OR index_taxon_fils IN ( SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils IN 
				#		( SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent = $id and nom_rang_fils = '$limit' ) ) )
				#		ORDER BY r.ordre";
				
				$ranks_req = "SELECT DISTINCT r.ordre, r.en FROM hierarchie AS h LEFT JOIN rangs AS r ON r.index = h.index_rang_fils 
						WHERE index_taxon_parent IN ($parentsIDs)
						AND index_taxon_fils IN ( SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent IN ($parentsIDs) and nom_rang_fils = '$limit' )
						ORDER BY r.ordre";
						
				$desc_req = "SELECT DISTINCT
						h.index_taxon_fils,
						h.index_rang_fils,
						h.nom_rang_fils,
						r.ordre,
						r.$lang,
						t.ref_taxon_parent,
						nc.orthographe,
						nc.autorite,
						n.gen_type,
						r.en
						FROM hierarchie AS h 
						LEFT JOIN rangs AS r ON r.index = h.index_rang_fils
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = h.index_taxon_fils
						LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN noms AS n ON n.index = nc.index
						WHERE index_taxon_fils IN ( SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent IN ($parentsIDs) and nom_rang_fils = '$limit' )
						AND txn.ref_statut = 1
						ORDER BY r.ordre DESC, nc.orthographe, nc.autorite;";
			}

			$ranks = request_tab($ranks_req, $dbc, 2);
			$ordres{$valid_name->[8]} = 1;
			foreach (@{$ranks}) { 
				$ordres{$_->[0]} = $g; $g++;
			}
						
			my $lowers = request_tab($desc_req,$dbc,2);
									
			if (my $maxi = $attributes{max} and $default_limit) {
				if (scalar(@{$lowers}) > $maxi) { $dm = 'none' }
			}
						
			my %hierarchy;
			my $sons_title;
			my $max =  scalar(@{$ranks});
			my $n = scalar(@{$ranks});
			my %rejetons;
			my %pater;
			my %displayed;
			
			if ($n > 1) {
				my $curord;
				for (my $i=0; $i<$#{$lowers}+1; $i++) {
					my $xid = $lowers->[$i][0];
					my $xrank = $lowers->[$i][2];
					my $ordre = $lowers->[$i][3];
					my $rang = $lowers->[$i][4];
					my $parent = $lowers->[$i][5];
					my $xname = $lowers->[$i][6];
					my $fname = $xname;
					$fname =~ s/\(/-/g;
					$fname =~ s/\)/-/g;
					my $xauthority = $lowers->[$i][7];
					my $xtype = $lowers->[$i][8];
					my $rken = $lowers->[$i][9];
												
					push(@sons_ids, $xid);
					
					# Counting number of sons group by rank
					if (!$curord or $curord != $ordre) { $n--; $curord = $ordre; }

					# filling a hash table to create the hierarchy of sons
					my $superkey =  $fname;
					my $parentkey = undef;
					my @parents = ();
					my $last = 0;
					my $titer = 0;
					my $first = '';
					while ($parent != $id) {
						my $prev = $parent;
						for (my $j=$last; $j<$#{$lowers}+1; $j++) {
							if ($lowers->[$j][0] == $parent) {
								$parent = $lowers->[$j][5];
								my $spell = $lowers->[$j][6];
								$spell =~ s/\(/-/g;
								$spell =~ s/\)/-/g;
								$superkey = $spell . "/" . $superkey;
								$parentkey = $spell;
								$first = $first ? $first : $spell;
								$pater{$parentkey} = 1;
								unshift(@parents, $parentkey);
								unless ($last) {
									if (exists $rejetons{$parentkey}) { $rejetons{$parentkey}{nombre} += 1 }
									else { 
										$rejetons{$parentkey}{nombre} = 1;
										$rejetons{$parentkey}{position} = $ordres{$lowers->[$j][3]};
									}
								}
								$last = $j;
								last;
							}
						}
						if ($prev == $parent) { last; }
					}
					
					my $marge;
					# If not direct child of the taxa				
					if ($last) { 
						unshift(@parents, $valid_name->[1]);
						@{$hierarchy{$superkey}{parents}} = @parents;
					}
					else {
						$hierarchy{$superkey}{parents} = [$valid_name->[1]];
						if (exists $rejetons{$valid_name->[1]}) { $rejetons{$valid_name->[1]}{nombre} += 1 }
						else { 
							$rejetons{$valid_name->[1]}{nombre} = 1;
							$rejetons{$valid_name->[1]}{position} = $ordres{$valid_name->[8]};
						}
					}
					$hierarchy{$superkey}{position} = $ordres{$ordre};
					$hierarchy{$superkey}{firstParent} = $first;
					$hierarchy{$superkey}{order} = $ordre;
					$hierarchy{$superkey}{rank} = $rken;
					
					my $typestr;
					if ($xtype) { $typestr = span({-class=>'typeSpecies'}, "&nbsp;  ".$trans->{"type$rken"}->{$lang}) }
					$hierarchy{$superkey}{name} = $fname;
					$hierarchy{$superkey}{body} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xrank&id=$xid"}, i($xname) . " $xauthority" . $typestr);
				}
				
				my $i = 0;
				my $last = 0;
				my %dones;
				
				#foreach my $key (keys(%rejetons)) {
				#	$descendants .= "$key = $rejetons{$key}{nombre}".br; 
				#}
												
				my $indent = $attributes{indentation} || 22;
				my $marge = $attributes{marge} || 6;
												
				foreach my $key (sort {$a cmp $b} keys(%hierarchy)) {
					my ($start, $body, @mclass);
					my $sign;
					if (exists $pater{$hierarchy{$key}{name}}) {
						$sign = exists $pater{$hierarchy{$key}{name}} ? span({-id=>"$hierarchy{$key}{name}_mark", -style=>'display: block; float: left; margin-left: -2px; font-weight: bold; cursor: pointer; padding-top: 1px; border: 0px solid darkgrey; border-radius: 5px;'}, '>').'&nbsp;' : '';
						#$start .= td({-id=>$hierarchy{$key}{name}, -class=>'sonsMagicCell', -style=>"cursor: pointer; margin-left: 2px; background: transparent; width: 12px; text-align: center; vertical-align: top; display: $dm;"}, $sign);
					}
					for (my $j=0; $j<scalar(@{$hierarchy{$key}{parents}}); $j++) {
						
						my $p = $hierarchy{$key}{parents}->[$j];
						
						push(@mclass, $p);
								
						# The immediate parent
						if ($j == $#{$hierarchy{$key}{parents}}) {
							
							# Store the sons already treated
							if (exists $dones{$p}) { $dones{$p} += 1 } else { $dones{$p} = 1 }
							#else {
								# benjamin son (last)
								if ($dones{$p} == $rejetons{$p}{nombre}) { 
									# Les terminaux "|_"
									$start .= td({-class=>'sonsMagicCell', -style=>"width: ".$indent."px; vertical-align: top; display: $dm; background: transparent;"}, 
											div({-style=>"width: ".($indent-$marge)."px; height: 1.4em; line-height: 1.4em;"},
												div({-style=>"position: absolute; margin-left: ".$marge."px; width: ".($indent-$marge)."px; height: 0.6em; line-height: 0.6em; border-left: 1px solid; border-bottom: 1px solid;"}, 
													''
												)
											)
										);
								}
								else {
									# Les croisements "|-"
									$start .= td({-class=>'sonsMagicCell', -style=>"width: ".$indent."px; vertical-align: top; display: $dm;"}, 
												div({-style=>"margin-left: ".$marge."px; width: ".($indent-$marge)."px; height: 1.4em; line-height: 1.4em; border-left: 1px solid;"}, 
													div({-style=>"position: absolute; width: ".($indent-$marge)."px; height: 0.6em; line-height: 0.6em; border-bottom: 1px solid;"}, 
														''
													)
												)
											);
								}
							#}
							
							my $nu = $hierarchy{$key}{position} - $rejetons{$p}{position} - 1;
							# Les decalages "_"
							$start .= td({-class=>'sonsMagicCell', -style=>"padding-bottom: 0; width: ".$indent."px; vertical-align: top; display: $dm;"}, 
									div({-style=>"width: ".$indent."px; height: 0.6em; line-height: 0.6em; border-bottom: 1px solid;"}, '')
								) x $nu;
						}
						else {
							my $pp = $hierarchy{$key}{parents}->[$j+1];
							
							if ($dones{$p} == $rejetons{$p}{nombre}) {
								# Les blancs " " entre prolongements
								$start .= td({-class=>'sonsMagicCell', -style=>"padding-bottom: 0; width: ".$indent."px; vertical-align: top; display: $dm;"}, '');
							}
							else {
								# Les prolongements "|"
								$start .= td({-class=>'sonsMagicCell', -style=>"padding-bottom: 0; width: ".$indent."px; vertical-align: top; display: $dm;"}, 
											div({-style=>"margin-left: ".$marge."px; width: ".($indent-$marge)."px; height: 1.4em; line-height: 1.4em; border-left: 1px solid;"}, '')
									);
							}
							my $nu = $rejetons{$pp}{position} - $rejetons{$p}{position} - 1;
							# Les blancs " " jusqu'a la racine
							$start .= td({-class=>'sonsMagicCell', -style=>"width: ".$indent."px; display: $dm;"}, '') x $nu;
							
						}
					}
					
					my $oc = "
					var elmts = getElementsByClass('".join(' ', @{$hierarchy{$key}{parents}})." $hierarchy{$key}{name}');
					var mark = getElementById('$hierarchy{$key}{name}_mark');
					for ( i=0; i<elmts.length; i++ ) {
						if (elmts[i].className == '".join(' ', @{$hierarchy{$key}{parents}})." $hierarchy{$key}{name}') {
							if (elmts[i].style.display == 'table-row' || elmts[i].style.display == '') { 
								mark.innerHTML = '>';
								elmts[i].style.display = 'none'; 
							}
							else { 
								//mark.innerHTML = \"&ndash;\";
								mark.innerHTML = '<';
								elmts[i].style.display = 'table-row'; 
							}
						}
						else {
							mark.innerHTML = '>';
							elmts[i].style.display = 'none';
						}
					}
					";
					
					#my $dsp = exists $displayed{$hierarchy{$key}{firstParent}} ? 'none' : 'table-row';
					my $dsp;
					if(url_param('test')) { 
						if ($hierarchy{$key}{order} >= $genus_order and $hierarchy{$key}{firstParent}) { $dsp = 'none' } else { $dsp = 'table-row' }; 
					}
					else {
						if ($hierarchy{$key}{firstParent}) { $dsp = 'none' } else { $dsp = 'table-row' };
					}
					
					#$test .= "$hierarchy{$key}{name} :: $hierarchy{$key}{firstParent} <br>";
					#$dsp = 'table-row'; # A SUPPRIMER !!!!!!
					
					my $body = td({-colspan=>($max-$n), -class=>'sonsMagicCell', -style=>"vertical-align: top; padding-left: 3px; display: $dm;"}, $sign.$hierarchy{$key}{body});
					
					$descendants .= Tr({-class=>join(' ', @{$hierarchy{$key}{parents}}), -onClick=>"$oc", -style=>" display: $dsp;"}, $start, $body);
					$displayed{$hierarchy{$key}{name}} = 1;
					$i++;
				}
			}
			elsif (scalar(@{$ranks}) > 0) {
				my $label = $lowers->[0][9];
				if (scalar(@{$lowers}) > 1) { $label .= 's'; }
				$sons_title = scalar(@{$lowers}) . " $trans->{$label}->{$lang}";				
				my $i = 0;
				foreach (@{$lowers}) {
					my $xid = $_->[0];
					my $xrank = $_->[2];
					my $xname = $_->[6];
					my $xauthority = $_->[7];
					my $xtype = $_->[8];
					my $rken = $_->[9];
				
					push(@sons_ids, $xid);
	
					my $typestr;
					if ($xtype) { $typestr = span({-class=>'typeSpecies'}, "&nbsp;  ".$trans->{"type$rken"}->{$lang}) }
					$descendants .= Tr(
								td({-colspan=>2, -class=>'sonsMagicCell magicCell', -style=>"display: $dm;"}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xrank&id=$xid"}, i($xname) . " $xauthority" . $typestr ))
							);
					$i++;
				}
			}
						
			my $i = 0;
			my $minimum = 0;
			if (scalar(keys(%sons_ranks)) > 1) {
				if ($limit eq 'none') { 
					$sons_title = "$total $trans->{taxons}->{$lang} ($nbtaxastr)";
					$childs = makeRetractableArray ('sonsTitle', 'sonsMagicCell', $sons_title, $descendants, 'arrowRight', 'arrowDown', $max, $dm, 'true');
				}
				else {
					$childs = table({-id=>'sonsTable'}, 
							Tr( td(
									a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$id&limit=none"}, div({-class=>'arrowRight', -style=>'height: 1em; width: 10px;'}, '&nbsp;'))
								), 
								td( 
									a({-class=>'titreReactif', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$id&limit=none"}, "$total $trans->{taxons}->{$lang} ($nbtaxastr)")
								)
							)
						);
				}
				$i++;
			}
			if (!$childs) {		
				foreach my $key (sort {$a <=> $b} keys(%sons_ranks)) {
					
					my $label = $sons_ranks{$key}{nom};
					if ($sons_ranks{$key}{valeur} > 1) { $label .= 's'; }
					
					if ($sons_ranks{$key}{nom} ne $limit) {
						$childs .= table({-style=>"padding: 0 0 0 ".($decalage * $i)."px;"}, 
								Tr( 	td({-class=>'arrowRight', -style=>"cursor: pointer;", -onclick=>"location.href='$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$id&limit=$sons_ranks{$key}{nom}'"}, '&nbsp;'), 
									td( 
										a({-class=>'titreReactif', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$id&limit=".$sons_ranks{$key}{nom}}, "$sons_ranks{$key}{valeur} $trans->{$label}->{$lang}")
									)
								)
							);
					}
					elsif ($sons_ranks{$key}{nom} eq $limit) {
						my $bool = $childs ? 'false' : 'true';
						$sons_title = $sons_ranks{$limitOrder}{valeur}." ";
						if ($sons_ranks{$limitOrder}{valeur} > 1) { $sons_title .= $trans->{$limit.'s'}->{$lang}; }
						else { $sons_title .= $trans->{$limit}->{$lang}; }
						$descendants = makeRetractableArray ('sonsTitle', 'sonsMagicCell', $sons_title, $descendants, 'arrowRight', 'arrowDown', $max, $dm, $bool);
						$childs .= div({-style=>"margin-left: ".($decalage * $i)."px;"}, $descendants);
					}
					#$i++;
				}
			}
			$descendants = $childs;
			my $pos = $display_modes{descent}{position} || $default_order{descent};
			$orderedElements{$pos} = $descendants;
		}
		else {			
			$req = "SELECT	h.index_taxon_fils
					FROM hierarchie AS h 
					WHERE index_taxon_parent IN ($parentsIDs);";
						
			my $lowers = request_tab($req,$dbc,1);
			
			foreach (@{$lowers}) {
				push(@sons_ids, $_);
			}
		}

		
		# récupérer les enfants du taxon dans un tableau pour un représentation graphique circulaire
		if (url_param('test') and $dbase eq 'flow') {

		my $limit = "genus";
		
		my $sr_req = "
		SELECT en 
		FROM rangs 
		WHERE en IN (
			SELECT DISTINCT nom_rang_fils
			FROM hierarchie 
			WHERE index_taxon_parent = $id )
		AND ordre <= (SELECT ordre FROM rangs WHERE en = '$limit')
		ORDER by ordre DESC;";
		
		my $sons_ranks = request_tab($sr_req, $dbc, 1);
		push(@{$sons_ranks}, $rank);
		
		my $req = "
		SELECT
		h.index_taxon_fils,
		h.nom_rang_fils,
		t.ref_taxon_parent,
		nc.orthographe,
		nc.autorite
		FROM hierarchie AS h 
		LEFT JOIN rangs AS r ON r.index = h.index_rang_fils
		LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = h.index_taxon_fils
		LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
		LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
		LEFT JOIN noms AS n ON n.index = nc.index
		WHERE index_taxon_parent = $id
		AND h.nom_rang_fils = '$limit'
		AND txn.ref_statut = 1
		ORDER BY nc.orthographe, nc.autorite;";
		
		my $leaves = request_tab($req, $dbc, 2);
		
		my $phpstr = 'array (';
		#$phpstr .= '<br>'; #!!
		#$leaves = [$leaves->[324]];
		my $i=0;
		foreach (@{$leaves}) {
			my @phpcols;
			#http://flow.hemiptera.infosyslab.fr
			push(@phpcols, "$_->[3] ++ $_->[4] ++ /flow/?page=explorer&db=flow&lang=en&card=taxon&rank=$_->[1]&id=$_->[0]");
			my $parent = $_->[2];
			my $rank_pos = 1;
			while ($parent and $rank_pos < scalar(@{$sons_ranks})) {
				my $req = "
				SELECT
				t.ref_taxon_parent,
				r.en,
				nc.orthographe,
				nc.autorite
				FROM taxons AS t
				LEFT JOIN rangs AS r ON r.index = t.ref_rang
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = t.index
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				WHERE t.index = $parent
				AND txn.ref_statut = 1;";
				
				my $ascendant = request_tab($req, $dbc, 2);
				if($ascendant->[0]) {
					#$test .= $parent." IS A $ascendant->[0][1]<br>";
					while ($ascendant->[0][1] ne $sons_ranks->[$rank_pos] and $rank_pos < scalar(@{$sons_ranks})) {
						#$test .= "$ascendant->[0][1] VS $sons_ranks->[$rank_pos] <br>";
						push(@phpcols, "empty");
						$rank_pos++;
						#$test .= "void ADDED <br>";
					}
					if($rank_pos < scalar(@{$sons_ranks})) {
					    #http://flow.hemiptera.infosyslab.fr
						push(@phpcols, "$ascendant->[0][2] ++ $ascendant->[0][3] ++ /flow/?page=explorer&db=flow&lang=en&card=taxon&rank=$ascendant->[0][1]&id=$parent");
						$rank_pos++;
						$parent = $ascendant->[0][0];
					}
					else {
						$parent = 0;
					}
				}
				else {
					$parent = 0;
				}
			}
			@phpcols = reverse @phpcols;
			
			#$phpstr .= '&nbsp;&nbsp;&nbsp;&nbsp;'; #!!
			#$phpstr .= "array (<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'".join ("', <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'", @phpcols)."'<br>&nbsp;&nbsp;&nbsp;)"; #!! retirer les retours ligne
			$phpstr .= 'array (\"'.join ('\",\"', @phpcols).'\")';
			unless ($i == $#$leaves) { $phpstr .= ','; }
			#$phpstr .= '<br>'; #!!
			$i++;
		}
		$phpstr .= ');';
		#$test .= $phpstr . "<br><br><br><br>";
#		$test .= `php /var/www/html/Documents/php/ClassificationModule.php`;		
		$test .= `php /var/www/html/Documents/php/ClassificationModule.php`;		
		}
		
		
		
		
		
		
		my @names_index;
		my $synonyms;		
		my $synonymy;		
		my $chresonymy;	
		my $graphic;
		push(@names_index, $valid_name->[0]);
		unless ($display_modes{synonymy}{skip} and $display_modes{chresonymy}{skip} and $mode ne 'full') {
			
			my %attributes;
			my %attributes2;
			my @attribs;
			
			@attribs = split('#', $display_modes{synonymy}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			
			@attribs = split('#', $display_modes{chresonymy}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes2{$key} = $val;
			}
			
			my ($nb_syns) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_taxon = $id AND ref_statut NOT IN (3,8,17,18,14);", $dbc, 1)};
			my ($nb_uses) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_taxon = $id AND ref_statut IN (3,8,17,18);", $dbc, 1)};			
			
			# Fetch taxon synonyms and chresonyms
			my $names_list = request_tab("	SELECT 	nc.index, 
								nc.orthographe, 
								nc.autorite, 
								s.en, 
								txn.ref_publication_utilisant, 
								txn.ref_publication_denonciation,
								txn.exactitude, 
								txn.completude, 
								txn.exactitude_male, 
								txn.completude_male, 
								txn.exactitude_femelle, 
								txn.completude_femelle,
								txn.sexes_decrits, 
								txn.sexes_valides, 
								txn.ref_nom_cible, 
								nc2.orthographe, 
								nc2.autorite, 
								s.$lang, 
								n.orthographe, 
								n.ref_nom_parent,
								txn.page_utilisant,  ". #20
							    "txn.page_denonciation,
								pubd.annee,
								r.ordre,
								np.orthographe,
								np2.orthographe,
								txn.remarques, 
								txn.nom_label, 
								txn.nom_cible_label,
								CASE WHEN s.index = 2 AND (SELECT count(*) FROM taxons_x_noms WHERE ref_nom = txn.ref_nom AND ref_nom_cible != txn.ref_nom_cible AND ref_statut = 2) > 0 THEN
								'<i>pro parte</i> '
								END,
								s.index,
								pubu.annee,
								n2.orthographe, 
								n2.ref_nom_parent,
								(select all_to_rank(ref_nom, 'subtribe', 'suborder', '<br>', 'down', 'notfull')),
								(select all_to_rank(ref_nom_cible, 'subtribe', 'suborder', '<br>', 'down', 'notfull')),
								r2.ordre
							FROM taxons_x_noms AS txn 
							LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
							LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
							LEFT JOIN noms AS n ON n.index = txn.ref_nom
							LEFT JOIN noms AS n2 ON n2.index = txn.ref_nom_cible
							LEFT JOIN noms_complets AS np ON np.index = n.ref_nom_parent
							LEFT JOIN noms_complets AS np2 ON np2.index = n2.ref_nom_parent
							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
							LEFT JOIN publications AS pubd ON pubd.index = txn.ref_publication_denonciation
							LEFT JOIN publications AS pubu ON pubu.index = txn.ref_publication_utilisant
							LEFT JOIN publications AS pubo ON pubo.index = nc.ref_publication_princeps
							LEFT JOIN rangs AS r ON r.index = nc.ref_rang
							LEFT JOIN rangs AS r2 ON r2.index = nc2.ref_rang
							WHERE txn.ref_taxon = $id 
							AND s.en != 'valid'
							ORDER BY pubd.annee, n.annee, pubu.annee, txn.date_modification;",$dbc);
			
			my $max;
			$max = $attributes{max} || 0;
			my $dms = ( ( !$max or ( $max and $nb_syns <= $max ) ) and $display_modes{synonymy}{display} ) ? 'table-cell' : 'none';
			$max = $attributes2{max} || 0;
			my $dmc =( ( !$max or ( $max and $nb_uses <= $max ) ) and $display_modes{chresonymy}{display} ) ? 'table-cell' : 'none';
			
			my %chresonyms;
			if ( scalar @{$names_list} ) {
				
				if ($mode =~ m/s/) {
						
					foreach my $syn ( @{$names_list} ){
						
						unless (exists($names{$syn->[0]})) {
						
							$names{$syn->[0]}{'species'} = $syn->[18];
						
							my $val = $syn->[19];
							my $found = 0;
							while (!$found) {
								my ($father) = @{request_row("SELECT ref_nom_parent from noms where index = $val", $dbc)};
								
								unless ($father) { $found = 1; }
								else { $val = $father; }
							}
							($names{$syn->[0]}{'genus'}) = @{request_row("SELECT orthographe from noms where index = $val", $dbc)};
						}
					}
				}
				my (@statuses, @uses, %graphDone);
				
				
				# si on exclut le valide et les deux tableaux suivantes on recupere les synonymies
				# relations entre deux noms qui developpent une trame de l'historique				
				my %prevnext = (	4=>1,	# prev. comb.
							11=>1,	# nom. praeocc.
							15=>1,	# incorrect original spelling
							19=>1,	# nomen oblitum							
							22=>1, 	# comb. rev.
							23=>1	# prev. rank
				);
				# relations entre deux noms qui n'affectent pas de trame de l'historique	
				my %useslink = (
						3=>1, 
						5=>1, 
						8=>1, 
						10=>1, 
						12=>1, 
						14=>1, 
						17=>1, 
						18=>1, 
						20=>1
				);
				
				#my $i = 0;
				# Tant qu'il y a une relation entre deux noms avec une date
				#while ( $names_list->[$i] and $names_list->[$i][22]) {
				#	
				#	my $again = 1;
				#	my @ambiguous = ($names_list->[$i]);
				#	# on parcours les relations nomenclaturales suivantes pour determiner s'il y a ambiguite de date
				#	while ($again and $names_list->[$i+$again]) {
				#		if($names_list->[$i][22] == $names_list->[$i+$again][22]) {
				#			push(@ambiguous, $names_list->[$i+$again]);
				#			$again++;
				#		}
				#		else { $again = 0; }
				#	}
				#	
				#	if (scalar(@ambiguous)>1) {
				#
				#		my %pnx;
				#		my %syn;
				#		my %origin;
				#		my %alter;
				#		my %final;
				#		
				#		# recherche les points terminaux de chaque branche de l'historique pour avoir les points de depart.
				#		my $j=0;
				#		my $preFound=0;
				#		while ($j < $i) {
				#										
				#			# si le statut est de type previous => next
				#			if (exists $prevnext{$names_list->[$j][30]}) {
				#				# si le nom d'origine était dans les points terminaux potentiels le supprimer mais les mettre dans les points terminaux alternatifs.
				#				if (exists $origin{$names_list->[$j][0]}) { $alter{$names_list->[$j][0]} = $origin{$names_list->[$j][0]}; delete $origin{$names_list->[$j][0]}; }
				#				# mettre le nom cible dans les points terminaux potentiels
				#				$origin{$names_list->[$j][14]} = 1;
				#				$preFound=1;
				#			}
				#			$j++;
				#		}
				#		
				#		foreach my $current (@ambiguous){
				#			if (exists $syntoval{$current->[30]}) {
				#				$syn{$current->[0]} = {
				#					'cible' => $current->[14],
				#					'ligne' => $current
				#				};
				#			}
				#			elsif (exists $prevnext{$current->[30]}) {
				#				
				#				# s'il n'y a pas de nom cible
				#				if (!$current->[14]) {
				#					# comb. rev.
				#					if ($current->[30] == 22) {
				#						# recherche dans les lignes de même date un nom d'origine avant la comb. rev.
				#						foreach my $check (@ambiguous) {
				#							if (exists $prevnext{$check->[30]} && $check->[30] != $current->[30] && $check->[0] == $current->[0] ) {
				#								$current->[14] = $current->[0];
				#								$current->[15] = $current->[1];
				#								$current->[16] = $current->[2];
				#								$current->[25] = $current->[24];
				#								$current->[0] = $check->[14];
				#								$current->[1] = $check->[15];
				#								$current->[2] = $check->[16];
				#								$current->[18] = $check->[32];
				#								$current->[19] = $check->[33];
				#								$current->[24] = $check->[25];
				#							}
				#						}
				#						if (!$current->[14]) {
				#							my $j = $i-1;
				#							# recherche dans les lignes de date antérieure un nom d'origine avant la comb. rev.
				#							while ( $names_list->[$j] ) {
				#								if (exists $prevnext{$names_list->[$j][30]} && $names_list->[$j][0] == $current->[0] ) {
				#									$current->[14] = $current->[0];
				#									$current->[15] = $current->[1];
				#									$current->[16] = $current->[2];
				#									$current->[25] = $current->[24];
				#									$current->[0] = $names_list->[$j][14];
				#									$current->[1] = $names_list->[$j][15];
				#									$current->[2] = $names_list->[$j][16];
				#									$current->[18] = $names_list->[$j][32];
				#									$current->[19] = $names_list->[$j][33];
				#									$current->[24] = $names_list->[$j][25];
				#									last;
				#								}
				#								$j--;
				#							}
				#						}
				#					}
				#				}
				#				
				#				unless (!$current->[14]) {
				#					$pnx{$current->[0]} = {
				#						'cible' => $current->[14],
				#						'ligne' => $current
				#					};
				#					# si aucun point d'origine n'a été trouvé en amont dans l'historique, le rechercher parmi les lignes de même date
				#					unless ($preFound) {
				#						if(exists $final{$current->[0]} ) { delete $final{$current->[0]}; } else { $origin{$current->[0]} = 1; }
				#						if(exists $origin{$current->[14]} ) { delete $origin{$current->[14]}; } else { $final{$current->[14]} = 1; }
				#					}
				#				}
				#			}
				#			#$test .= $current->[0].' ['.$current->[1].' '.$current->[2].'] -- '.$current->[17].' -- '.$current->[14].' ['.$current->[15].' '.$current->[16].'] '.$current->[22].br;
				#		}
				#		#$test .= "origin: ".join(',',keys(%origin)).br;
				#		#$test .= "final: ".join(',',keys(%final)).br;
				#		
				#		my $pos = $i;
				#		
				#		$test .= join(',',keys(%origin)).br;
				#			
				#		my $found = 0;
				#		foreach my $key (keys(%origin)) {
				#			my $ck = $key;
				#			while (exists $pnx{$ck} and $ck != $pnx{$ck}{cible} && !$pnx{$ck}{done}) {
				#				$found = 0;
				#				$names_list->[$pos] = $pnx{$ck}{ligne};
				#				$pnx{$ck}{done} = 1;
				#				$ck = $pnx{$ck}{cible};
				#				$pos++;
				#			}
				#		}
				#		unless ($found) {
				#			foreach my $key (keys(%alter)) {
				#				my $ck = $key;
				#				while (exists $pnx{$ck} and $ck != $pnx{$ck}{cible} && !$pnx{$ck}{done}) {
				#					$found = 0;
				#					$names_list->[$pos] = $pnx{$ck}{ligne};
				#					$pnx{$ck}{done} = 1;
				#					$ck = $pnx{$ck}{cible};
				#					$pos++;
				#				}
				#			}
				#		}
				#		foreach my $key (keys(%syn)) {
				#			$names_list->[$pos] = $syn{$key}{ligne};
				#			$pos++;
				#		}
				#		$i += scalar(@ambiguous);
				#	}
				#	else { 
				#		$i++; 
				#	}
				#}
				## FAIL
								
				foreach my $syn ( @{$names_list} ){
					
					if ($syn->[0]) { push(@names_index, $syn->[0]); }
										
					if ( $syn->[3] eq 'synonym' or $syn->[3] eq 'junior synonym' ){
						#my $ambiguous = synonymy( $syn->[6], $syn->[8], $syn->[10] );
						#my $complete = completeness( $syn->[7], $syn->[9], $syn->[11] );
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $sl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$sl = $syn->[27] ? $sl . " $syn->[27]" : $sl;
						$sl .= "&nbsp;$syn->[17]&nbsp;$syn->[29]$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$sl = $syn->[28] ? $sl . " $syn->[28]" : $sl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$sl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$sl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $sl = $syn->[26] ? $sl . " ($syn->[26])" : $sl; }
						
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $sl) );
						
						#my $treq = "SELECT count(*) FROM taxons_x_noms AS txn WHERE txn.ref_nom in (SELECT index FROM noms WHERE orthographe = (SELECT orthographe FROM noms WHERE index = $syn->[0])) AND txn.ref_taxon = $id AND txn.ref_statut in (SELECT index FROM statuts WHERE en like '%revivisco%');";
												
						#my ($res) = @{request_tab($treq, $dbc, 1)};
						
						#if (!$res) {
							push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						#}
					}
					elsif ( $syn->[3] eq 'dead end' ){
						#$test .= "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"\"]";
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"\",\"$syn->[22]\",\"\",\"\",\"\",\"$syn->[23]\",\"$syn->[36]\"]");
					}
					elsif ( $syn->[3] eq 'wrong spelling' ){
						my @pub_use = publication($syn->[4], 0, 1, $dbc );
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $wsl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$wsl = $syn->[27] ? $wsl . " $syn->[27]" : $wsl;
						$wsl .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$wsl = $syn->[28] ? $wsl . " $syn->[28]" : $wsl;
						if ($pub_use[1]) { 
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							$wsl .= " $trans->{'dansin'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
							$wsl .= getPDF($syn->[4]);
						}
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$wsl .= " $trans->{'corrby'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$wsl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $wsl = $syn->[26] ? $wsl . " ($syn->[26])" : $wsl; }
						
						$chresonyms{$syn->[0].$syn->[4].$syn->[20].$syn->[5].$syn->[21]}{'label'} = $wsl;
						
						#push(@uses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_use[1]\",\"$syn->[31]\",\"$syn->[34]\",\"$syn->[35]\"]");
					}
					elsif ( $syn->[3] eq 'previous combination'){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $tl;
						my ($parent, $parent2) = ($syn->[34], $syn->[35]);
						$parent =~ s/<br>/, /g;
						$parent2 =~ s/<br>/, /g;
						if ($syn->[23] > $genus_order and $syn->[1].$syn->[2] ne $syn->[15].$syn->[16]) {
							$tl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]");
							$tl = $parent != $parent2 ? $tl . "&nbsp;[$parent]" : $tl;
							$tl = $syn->[27] ? $tl . " $syn->[27]" : $tl;
							$tl .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
							$tl = $parent != $parent2 ? $tl . "&nbsp;[$parent2]" : $tl;
							$tl = $syn->[28] ? $tl . " $syn->[28]" : $tl;
						}
						else {
							$tl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]");
							$tl = $syn->[27] ? $tl . " $syn->[27]" : $tl;
							$tl .= "&nbsp;$trans->{'transferfrom'}->{$lang}&nbsp;[$parent]".br."&nbsp;&nbsp;&nbsp;&nbsp;$trans->{'tovers'}->{$lang}&nbsp;[$parent2]";
							$tl = $syn->[28] ? $tl . " $syn->[28]" : $tl;
						}
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$tl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$tl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $tl = $syn->[26] ? $tl . " ($syn->[26])" : $tl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $tl) );
						
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						$graphDone{"$syn->[1] $syn->[2]"}++;
					}
					elsif ( $syn->[3] eq 'previous name'){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $tl;
						my ($parent, $parent2) = ($syn->[34], $syn->[35]);
						$parent =~ s/<br>/, /g;
						$parent2 =~ s/<br>/, /g;
						$tl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]");
						$tl .= $parent ? " ($parent)" : '';
						$tl = $syn->[27] ? $tl . " $syn->[27]" : $tl;
						$tl .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$tl = $syn->[28] ? $tl . " $syn->[28]" : $tl;
						$tl .= $parent2 ? " ($parent2)" : '';
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$tl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$tl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $tl = $syn->[26] ? $tl . " ($syn->[26])" : $tl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $tl) );
						
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						$graphDone{"$syn->[1] $syn->[2]"}++;
					}
					elsif ( $syn->[3] eq 'misidentification' ){
						my @pub_use = publication($syn->[4], 0, 1, $dbc );
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $mil .= a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]");
						$mil = $syn->[27] ? $mil . " $syn->[27]" : $mil;
						$mil .= "&nbsp;$syn->[17]";
						if ($pub_use[1]) { 
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							$mil .= " $trans->{'dansin'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
							$mil .= getPDF($syn->[4]);
						}
						if ($pub_den[1]) {
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
								$mil .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$mil .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $mil = $syn->[26] ? $mil . " ($syn->[26])" : $mil; }
						$chresonyms{$syn->[0].$syn->[4].$syn->[20].$syn->[5].$syn->[21]}{'label'} = $mil;
						
						#push(@uses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"\",\"\",\"$pub_den[1]\",\"$syn->[31]\"]");
					}
					elsif ( $syn->[3] eq 'previous identification' ){
					
						my @pub_use = publication($syn->[4], 0, 1, $dbc );
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $pil .= a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$pil = $syn->[27] ? $pil . " $syn->[27]" : $pil;
						$pil .= " $trans->{'misid'}->{$lang}&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$pil = $syn->[28] ? $pil . " $syn->[28]" : $pil;
						if ($pub_use[1]) { 
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							$pil .= " $trans->{'dansin'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
							$pil .= getPDF($syn->[4]);
						}
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$pil .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$pil .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $pil = $syn->[26] ? $pil . " ($syn->[26])" : $pil; }
						$chresonyms{$syn->[0].$syn->[4].$syn->[20].$syn->[5].$syn->[21]}{'label'} = $pil;
	
						#push(@uses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[31]\"]");
					}
					elsif ( $syn->[3] eq 'incorrect original spelling' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $iol = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$iol = $syn->[27] ? $iol . " $syn->[27]" : $iol;
						$iol .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$iol = $syn->[28] ? $iol . " $syn->[28]" : $iol;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$iol .= " $trans->{'emended'}->{$lang}&nbsp;$trans->{'BY'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$iol .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $iol = $syn->[26] ? $iol . " ($syn->[26])" : $iol; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $iol) );
	
						 push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
					}
					elsif ( $syn->[3] eq 'incorrect subsequent spelling' ){
						my @pub_use = publication($syn->[4], 0, 1, $dbc );
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $iel = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$iel = $syn->[27] ? $iel . " $syn->[27]" : $iel;
						$iel .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$iel = $syn->[28] ? $iel . " $syn->[28]" : $iel;
						if ($pub_use[1]) { 
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							$iel .= " $trans->{'dansin'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" );
							$iel .= getPDF($syn->[4]);
						}
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$iel .= " $trans->{'corrby'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$iel .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $iel = $syn->[26] ? $iel . " ($syn->[26])" : $iel; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $iel) );
						
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
					}
					elsif ( $syn->[3] eq 'correct use' ){
						
						my @pub_use = publication($syn->[4], 0, 1, $dbc );
						
						unless (exists $chresonyms{$syn->[0]}) { 
							$chresonyms{$syn->[0]} = {};
							$chresonyms{$syn->[0]}{'label'} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" ) . "&nbsp;$trans->{'cited_in'}->{$lang}&nbsp;";
							
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							$chresonyms{$syn->[0]}{'refs'} = ();
							push(@{$chresonyms{$syn->[0]}{'refs'}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));
						}
						else {
							my $page;
							if ($syn->[20]) { $page = ":&nbsp;$syn->[20]" }
							push(@{$chresonyms{$syn->[0]}{'refs'}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[4]"}, "$pub_use[1]$page" ) . getPDF($syn->[4]));						
						}
						
						#push(@uses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"\",\"\",\"$pub_use[1]\",\"$syn->[31]\",\"\"]");
					}
					elsif ( $syn->[3] eq 'homonym' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $hl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$hl = $syn->[27] ? $hl . " $syn->[27]" : $hl;
						$hl .= "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$hl = $syn->[28] ? $hl . " $syn->[28]" : $hl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$hl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$hl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $hl = $syn->[26] ? $hl . " ($syn->[26])" : $hl; }
						
						#$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $hl) );
						$chresonyms{$syn->[0].$syn->[4].$syn->[20].$syn->[5].$syn->[21]}{'label'} = $hl;
						
						my $treq = "SELECT count(*) FROM taxons_x_noms AS txn WHERE txn.ref_nom = $syn->[0] AND txn.ref_taxon = $id AND txn.ref_statut not in (SELECT index FROM statuts WHERE en like '%homonym%');";
												
						my ($res) = @{request_tab($treq, $dbc, 1)};
						
						if (!$res) {
							#$test .= "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\"]";
							push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						}
						else {
							#$test .= "[\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$syn->[3]\",\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$pub_den[1]\"]";
							push(@statuses, "[\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$syn->[3]\",\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						}
					}
					elsif ( $syn->[3] eq 'nomen nudum' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $nl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$nl = $syn->[27] ? $nl . " $syn->[27]" : $nl;
						$nl .=  "&nbsp;" . i($syn->[17]) . "&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]");
						$nl = $syn->[28] ? $nl . " $syn->[28]" : $nl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$nl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$nl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $nl = $syn->[26] ? $nl . " ($syn->[26])" : $nl; }
						
						#$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $nl) );
						
						$chresonyms{$syn->[0].$syn->[4].$syn->[20].$syn->[5].$syn->[21]}{'label'} = $nl;
	
						#push(@uses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\"]");
					}
					elsif ( $syn->[3] eq 'status revivisco' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $nl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$nl = $syn->[27] ? $nl . " $syn->[27]" : $nl;
						$nl .=  "&nbsp;";
						if (($syn->[15] and $syn->[1] ne $syn->[15]) or ($syn->[16] && $syn->[2] ne $syn->[16])) { $nl .= "&nbsp;$trans->{'ori_com'}->{$lang}&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]")." ".i($syn->[17]); }
						else { $nl .= "&nbsp;".i($syn->[17]); }
						#if ($syn->[3] eq 'combinatio revivisco' or ($syn->[3] eq 'status revivisco' and $syn->[1] eq $syn->[15])) { $nl .= " ".i($syn->[17]) }
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$nl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$nl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $nl = $syn->[26] ? $nl . " ($syn->[26])" : $nl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $nl) );
						
						#if (!$syn->[15] and $syn->[22]) {
						#	my $lreq = "SELECT nc.orthographe, nc.autorite 
						#	FROM taxons_x_noms AS txn
						#	LEFT JOIN publications AS p ON p.index = txn.ref_publication_denonciation 
						#	LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom_cible
						#	WHERE txn.ref_nom_cible not in (SELECT DISTINCT ref_nom FROM taxons_x_noms WHERE ref_taxon = $id)
						#	AND ref_taxon = $id
						#	AND p.annee <= $syn->[22]
						#	ORDER BY p.annee
						#	LIMIT 1";
						#	
						#	my $old = request_tab($lreq, $dbc, 2);
						#	
						#	#$test .= p . $lreq . p . "[\"$old->[0][0]\",\"$old->[0][1]\",\"$syn->[3]\",\"$syn->[1]\",\"$syn->[2]\",\"$pub_den[1]\"]";
						#	
						#	push(@statuses, "[\"<i>$old->[0][0]</i>\",\"$old->[0][1]\",\"$syn->[3]\",\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\"]");
						#	$graphDone{"$old->[0][0] $old->[0][1]"}++;
						#}
						#else {
							push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
							$graphDone{"$syn->[1] $syn->[2]"}++;
						#}
					}
					elsif ( $syn->[3] eq 'combinatio revivisco' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $nl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[15]) . "&nbsp;$syn->[16]" );
						$nl = $syn->[27] ? $nl . " $syn->[27]" : $nl;
						$nl .= "&nbsp;".i($syn->[17]);
						#if ($syn->[3] eq 'combinatio revivisco' or ($syn->[3] eq 'status revivisco' and $syn->[1] eq $syn->[15])) { $nl .= " ".i($syn->[17]) }
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$nl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$nl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $nl = $syn->[26] ? $nl . " ($syn->[26])" : $nl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $nl) );
						
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						$graphDone{"$syn->[1] $syn->[2]"}++;
					}
					elsif ( $syn->[3] eq 'nomen praeoccupatum' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $npl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$npl = $syn->[27] ? $npl . " $syn->[27]" : $npl;
						$npl .= "&nbsp;" . i($syn->[17]) . "&nbsp;$trans->{'fromto'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]") . "&nbsp;" . i($trans->{'nnov'}->{$lang});
						$npl = $syn->[28] ? $npl . " $syn->[28]" : $npl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$npl .= ", $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$npl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $npl = $syn->[26] ? $npl . " ($syn->[26])" : $npl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $npl) );
	
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
						$graphDone{"$syn->[1] $syn->[2]"}++;
					}
					elsif ( $syn->[3] eq 'nomen oblitum' ){
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $npl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						$npl = $syn->[27] ? $npl . " $syn->[27]" : $npl;
						$npl .= "&nbsp;" . i($syn->[17]) . ", $trans->{'synonym'}->{$lang}&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]") . "&nbsp;" . i($trans->{'nprotect'}->{$lang});
						$npl = $syn->[28] ? $npl . " $syn->[28]" : $npl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$npl .= ", $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$npl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $npl = $syn->[26] ? $npl . " ($syn->[26])" : $npl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $npl) );
	
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
					}
					elsif ($syn->[3] ne 'valid') {
						my @pub_den = publication($syn->[5], 0, 1, $dbc );
						my $ukl = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[0]"}, i($syn->[1]) . "&nbsp;$syn->[2]" );
						my ($parent, $parent2) = ($syn->[34], $syn->[35]);
						$parent =~ s/<br>/, /g;
						$parent2 =~ s/<br>/, /g;
						$ukl = $parent ne $parent2 ? $ukl . "&nbsp;[$parent]" : $ukl;
						$ukl = $syn->[27] ? $ukl . " $syn->[27]" : $ukl;
						$ukl .= $syn->[15] ? "&nbsp;$syn->[17]&nbsp;$trans->{'of'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$syn->[14]"}, i($syn->[15]) . "&nbsp;$syn->[16]") : "&nbsp;$syn->[17]";
						$ukl = $parent ne $parent2 ? $ukl . "&nbsp;[$parent2]" : $ukl;
						$ukl = $syn->[28] ? $ukl . " $syn->[28]" : $ukl;
						if ($pub_den[1]) { 
							my $page;
							if ($syn->[21]) { $page = ":&nbsp;$syn->[21]" }
							$ukl .= " $trans->{'segun'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$syn->[5]"}, "$pub_den[1]$page" );
							$ukl .= getPDF($syn->[5]);
						}
						if ($display_modes{remarks}) { $ukl = $syn->[26] ? $ukl . " ($syn->[26])" : $ukl; }
						$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"}, $ukl) );
							
						push(@statuses, "[\"<i>$syn->[1]</i>\",\"$syn->[2]\",\"$syn->[3]\",\"<i>$syn->[15]</i>\",\"$syn->[16]\",\"$pub_den[1]\",\"$syn->[22]\",\"$syn->[34]\",\"$syn->[35]\",\"$syn->[23]\",\"$syn->[36]\"]");
					}
				}
				
				my $toomuch = 0;
				foreach (keys(%graphDone)) {
					if ($graphDone{$_} > 1) { $toomuch = 0; last; }
				}
				
				# Make a graphic representation of taxon synonymy and chresonymy
				if (( !$display_modes{graphic}{skip} or $mode eq 'full') and !$toomuch) {
					
					my $legend;
					$legend .= Tr( td({-colspan=>1, -class=>'legMagicCell magicCell', -style=>"display: none;"}, 
									"<NOBR>
									<fieldset class='sc_Legend leg_boxes' STYLE='float: left;'>
										<legend> Caption </legend>
											<!--<legend> Boxes </legend>-->
											<table>
													<tr><td style='font-size: 8px;'>&nbsp;</td></tr>
													<tr>
														<td style='padding-left: 1em;'> <div class='sc_Box sc_exBox sc_BoxValid'></div></td>
														<td> Valid name </td>
														<td style='padding-left: 2em; padding-right: 1em;'> <div class='sc_Line sc_exLink sc_LinePrevious'></div></td>
														<td style='padding-right: 1em;'> Historical link </td>
														<td style='padding-left: 2em;' padding-right: 1em;'> 
															<div style='position: static; width: 41px; background:transparent; height:9px;'>
																<div class='sc_down_hi'></div><div class='sc_down_mid'></div><div class='sc_down_lo'></div>
															</div>
														</td>
														<td style='padding-right: 1em;'> Change to lower rank </td>
													</tr>
													<tr><td style='font-size: 3px;'>&nbsp;</td></tr>
													<tr>
														<td style='padding-left: 1em;'> <div class='sc_Box sc_exBox sc_BoxBasyonyme'></div></td>
														<td> Basionym </td>
														<td style='padding-left: 2em;' padding-right: 1em;'> <div class='sc_Line sc_exLink sc_LineSynonym'></div></td>
														<td style='padding-right: 1em;'> Synonymy </td>
														<td style='padding-left: 2em;' padding-right: 1em;'> 
															<div style='position: static; width: 41px; background:transparent; height:9px;'>
																<div class='sc_up_lo'></div><div class='sc_up_mid'></div><div class='sc_up_hi'></div>
															</div>
														</td>
														<td style='padding-right: 1em;'> Change to upper rank </td>
													</tr>
													<tr><td style='font-size: 3px;'>&nbsp;</td></tr>
													<tr>
														<td style='padding-left: 1em;'> </div></td>
														<td> </td>
														<td style='padding-left: 2em;' padding-right: 1em;'> <div class='sc_Line sc_exLink sc_LineHomonym'></div></td>
														<td style='padding-right: 1em;'> Homonymys </td>
													</tr>
													<!--
													<tr><td style='font-size: 3px;'>&nbsp;</td></tr>
													<tr>
														<td style='padding-left: 1em;'> <div class='sc_Box sc_exBox sc_BoxUses'></div></td>
														<td> Homonym </td>
														<td style='padding-left: 2em;'> <div class='sc_Line sc_exLink sc_LineUses'></div></td>
														<td style='padding-right: 1em;'> Usage </td>
													</tr>
													-->
											</table>
									</fieldset>
									<!--
									<fieldset class='sc_Legend leg_statuts' style='display: none;'>
										<legend> Display parameters </legend>
											<table>
												<tr>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c7' value='synonym' checked> synonym &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c3' value='previous combination' checked> previous combination &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c4' value='incorrect original spelling' checked> incorrect original spelling &nbsp;</td>
												</tr><tr>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c10' value='homonym' checked> homonym &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c2' value='nomen praeoccupatum' checked> nomen praeoccupatum &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c9' value='incorrect subsequent spelling' checked> incorrect subsequent spelling &nbsp;</td>
												</tr><tr>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c1' value='nomen nudum' checked> nomen nudum &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c15' value='previous rank' checked> previous rank &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c14' value='previous identification' > previous identification &nbsp;</td>
												</tr><tr>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c8' value='nomen oblitum' checked> nomen oblitum &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c5' value='status revivisco' checked> status revivisco &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c13' value='misidentification' > misidentification &nbsp;</td>
												</tr><tr>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c11' value='wrong spelling'> wrong spelling &nbsp;</td>
													<td><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c6' value='combinatio revivisco' checked> combinatio revivisco &nbsp;</td>
													<td style='display: none;'><input type='checkbox' onclick=\"newSchema(); document.getElementById('sc_Div').scrollLeft = 10000;\" id='c12' value='correct use'> correct use &nbsp;</td>
												</tr>
											</table>
									</fieldset>
									-->
									</NOBR>"									
									));
					
					$legend = makeRetractableArray ('legTitle', 'legMagicCell magicCell', ucfirst($trans->{'legend'}->{$lang}), $legend, 'arrowRight', 'arrowDown', 1, 'none', 'true');
					
					#$test = join('<br>',@statuses);
					if ($dbase eq 'cool') {
						$graphic .= start_form(-id=>'graphForm', -method=>'POST', -action=>'/explorerdocs/graph.php', -target=>"graphFrame", -style=>'margin: 0; padding: 0;');
						$graphic .= hidden('statuses', join(',',@statuses));
						$graphic .= hidden('uses', join(',',@uses));
						$graphic .= hidden('valid', "'<i>$valid_name->[1]</i>','$valid_name->[2]','$valid_name->[20]'");
						$graphic .= hidden('title', "$valid_name->[1] $valid_name->[2]");
						$graphic .= end_form();
						$graphic .= table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%;'},
							Tr( td({-colspan=>2, -style=>"height: 0.3em; line-height: 0.3em;"}, '') ),
							Tr( td({-colspan=>2},
									table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%; border: 0px solid #666666;'},
										Tr(
											td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('','graphFrame','toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1050, height=520'); document.forms['graphForm'].submit();", -style=>'vertical-align: middle; width: 10px;'}, div({-class=>'arrowRight'}, '')),
											td({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('','graphFrame','toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1050, height=520'); document.forms['graphForm'].submit();", -style=>'vertical-align: middle; text-align: left;'}, div({-class=>'titreReactif'}, $trans->{'graphDisplay'}->{$lang}))
										)
									)
								)
							)
						);
					}
					else {
						my $fullscreen;
						#if ($dbase eq 'flow') {
							$fullscreen .= start_form(-id=>'graphForm', -method=>'POST', -action=>'/explorerdocs/graph.php', -target=>"graphFrame", -style=>'margin: 0; padding: 0;');
							$fullscreen .= hidden('statuses', join(',',@statuses));
							$fullscreen .= hidden('uses', join(',',@uses));
							$fullscreen .= hidden('valid', "'<i>$valid_name->[1]</i>','$valid_name->[2]','$valid_name->[20]'");
							$fullscreen .= hidden('title', "$valid_name->[1] $valid_name->[2]");
							$fullscreen .= end_form();
							$fullscreen .= table({-cellpadding=>0, -cellspacing=>0, -style=>'width: 100%;'},
								Tr( 	td({-colspan=>2, -style=>"height: 0.3em; line-height: 0.3em;"}, '') ),
								Tr( 	td({-colspan=>2},
										table(Tr(
										td({	-onMouseOver=>"this.style.cursor='pointer';", 
											-onClick=>"window.open('','graphFrame','toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1'); document.forms['graphForm'].submit();",
											-style=>'vertical-align: middle; width: 10px; background: transparent;'}, 
											img({-src=>"/flowdocs/fullscr.png", -alt=>'', -style=>'border: 0; margin: 0; width: 20px;'})
										),
										td({	-onMouseOver=>"this.style.cursor='pointer';", 
											-onClick=>"window.open('','graphFrame','toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1'); document.forms['graphForm'].submit();",
											-style=>'vertical-align: middle; width: 10px; background: transparent;'}, 
											'&nbsp;fullscreen'
										)))
									),
									
								)
							);
						#}
												
						#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
						if (url_param('test') eq 'taxhis' and $dbase eq 'flow') { 
							my %parentForms;
							my @parentIds;
							my @current = ($valid_name->[0], $valid_name->[1], $valid_name->[2], $valid_name->[20]);
							for (my $i=$#{$names_list}; $i>=0; $i--) {
								if (grep {$_ eq $names_list->[$i][30]} keys(%prevnext)) {
									if($names_list->[$i][15] eq $current[1] and $names_list->[$i][16] eq $current[2] and $names_list->[$i][35] eq $current[3]) { 
										my @pub = publication($names_list->[$i][5], 0, 1, $dbc );
										$parentForms{$current[0]}{"position"} = $i+1;
										$parentForms{$current[0]}{"source"} = $pub[2];
										my $cur_parents = $current[3];
										$cur_parents =~ s/<br>/\\", \\"/g;
										$parentForms{$current[0]}{"parents"} = $cur_parents;
										$parentForms{$current[0]}{"name"} = $current[1];
										$parentForms{$current[0]}{"authority"} = $current[2];
										$parentForms{$current[0]}{"year"} = $names_list->[$i][22];
										$parentForms{$current[0]}{"concept"} = [];											
										push(@parentIds, $current[0]);										
										@current = ($names_list->[$i][0], $names_list->[$i][1], $names_list->[$i][2], $names_list->[$i][34]);
										if ($i == 0) {                                             
											$parentForms{$current[0]}{"position"} = $i;
											$parentForms{$current[0]}{"source"} = "";
											my $cur_parents = $current[3];
											$cur_parents =~ s/<br>/\\", \\"/g;
											$parentForms{$current[0]}{"parents"} = $cur_parents;
											$parentForms{$current[0]}{"name"} = $current[1];
											$parentForms{$current[0]}{"authority"} = $current[2];
											$parentForms{$current[0]}{"year"} = "";
											$parentForms{$current[0]}{"concept"} = [];											
											push(@parentIds, $current[0]);										
										}
									}
								}
							}
							@parentIds = reverse @parentIds;
							
							#$test .= "@parentIds<br>";
							
							my @cumulative;
							foreach my $parentId (@parentIds) {

								my @sonsNamesIds = @{request_tab("SELECT index FROM noms WHERE ref_nom_parent = $parentId", $dbc, 1)};
																									
								my $req = "	SELECT 	
										txn.ref_nom,
										nc.orthographe, 
										nc.autorite, 
										n.ref_nom_parent,
										(select all_to_rank(ref_nom, 'subtribe', 'super family', ', ', 'down', 'notfull')),
										n.annee,
										txn.ref_statut,
										txn.ref_nom_cible, 
										nc2.orthographe, 
										nc2.autorite, 
										n2.ref_nom_parent,
										(select all_to_rank(ref_nom_cible, 'subtribe', 'super family', ', ', 'down', 'notfull')),
										n2.annee,
										pubd.index,
										pubd.annee,
										pubu.annee								
										FROM taxons_x_noms AS txn 
										LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
										LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
										LEFT JOIN noms AS n ON n.index = txn.ref_nom
										LEFT JOIN noms AS n2 ON n2.index = txn.ref_nom_cible
										LEFT JOIN noms_complets AS np ON np.index = n.ref_nom_parent
										LEFT JOIN noms_complets AS np2 ON np2.index = n2.ref_nom_parent
										LEFT JOIN publications AS pubd ON pubd.index = txn.ref_publication_denonciation
										LEFT JOIN publications AS pubu ON pubu.index = txn.ref_publication_utilisant
										LEFT JOIN rangs AS r ON r.index = nc.ref_rang
										WHERE (ref_nom in (".join("," , @sonsNamesIds).") OR ref_nom_cible IN (".join("," , @sonsNamesIds)."))
										AND ref_statut NOT IN (".join("," , keys(%useslink)).")
										ORDER BY pubd.annee, n.annee, pubu.annee;";
										
								
												
								my $sth = $dbc->prepare($req) or $test .= $req;
								$sth->execute() or $test .= $req;
								my ($s_id, $s_spell, $s_auth, $s_parentID, $s_parent, $s_year, $statutID, $t_id, $t_spell, $t_auth, $t_parentID, $t_parent, $t_year, $pd_index, $pd_year, $pu_year);
								$sth->bind_columns( \($s_id, $s_spell, $s_auth, $s_parentID, $s_parent, $s_year, $statutID, $t_id, $t_spell, $t_auth, $t_parentID, $t_parent, $t_year, $pd_index, $pd_year, $pu_year) );
								while ( $sth->fetch ) {
									push(@cumulative, [$s_id, $s_spell, $s_auth, $s_parentID, $s_parent, $s_year, $statutID, $t_id, $t_spell, $t_auth, $t_parentID, $t_parent, $t_year, $pd_index, $pd_year, $pu_year]);
								}
							}
					
							my %done;
							foreach my $row (@cumulative) {
									
								my ($s_id, $s_spell, $s_auth, $s_parentID, $s_parent, $s_year, $statutID, $t_id, $t_spell, $t_auth, $t_parentID, $t_parent, $t_year, $pd_index, $pd_year, $pu_year) = @{$row};										
																		
								# nom 1 => nom 2 
								# si nom 1 est de parent connu:
								
								my @pub = publication($pd_index, 0, 1, $dbc);
								
								if (grep {$_ eq $s_parentID} @parentIds) {
									# si nom 1 apparait pour la premiere fois dans l'historique :
									# nom 1 associe a son parent en tant que "entrant" a la date princeps  => repertorier nom 1 comme deja rencontre en "entrant"
									unless (exists($done{"$s_spell $s_auth"})) {
										$done{"$s_spell $s_auth"} = "enter";
										push (@{$parentForms{$s_parentID}{"concept"}}, [1, "\\\"<i>$s_spell</i> $s_auth\\\"", '\"\"', $s_year]);
										# si nom 2 existe et est de parent inconnu:
										# nom 1 associe a son parent en tant que "sortant" a la date de denonciation  => repertorier nom 1 comme deja rencontre en "sortant"
										if ($t_id and !grep {$_ eq $t_parentID} @parentIds) {
											$done{"$s_spell $s_auth"} = "exit";
											push (@{$parentForms{$s_parentID}{"concept"}}, [3, "\\\"<i>$s_spell</i> $s_auth = <i>$t_spell</i> $t_auth ($t_parent) by ".$pub[2]."\\\"", '\"\"', $pd_year]);
										}
									}
									# si nom 1 deja apparu dans l'historique :
									else {
										# cas status revivisco
										if (!$t_id) { 
											if ($done{"$s_spell $s_auth"} eq "exit") { 
												$done{"$s_spell $s_auth"} = "enter";
												push (@{$parentForms{$s_parentID}{"concept"}}, [1, "\\\"<i>$s_spell</i> $s_auth ($s_parent) : ".$pub[2]."\\\"", '\"\"', $pd_year]);
											}
										}
										# si nom 2 est de parent inconnu et nom 1 deja repertorie en entrant:
										elsif (!grep {$_ eq $t_parentID} @parentIds and $done{"$s_spell $s_auth"} eq "enter") {
												$done{"$s_spell $s_auth"} = "exit";
												push (@{$parentForms{$s_parentID}{"concept"}}, [3, "\\\"<i>$s_spell</i> $s_auth = <i>$t_spell</i> $t_auth ($t_parent) : ".$pub[2]."\\\"", '\"\"', $pd_year]);
										}
									}
								}
								#si nom 1 est de parent inconnu:
								else {
									# si nom 2 apparait pour la premiere fois dans l'historique :
									unless (exists($done{"$t_spell $t_auth"})) {
										$done{"$t_spell $t_auth"} = "enter";
										push (@{$parentForms{$t_parentID}{"concept"}}, [1, "\\\"<i>$t_spell</i> $t_auth (from $s_parent) : ".$pub[2]."\\\"", '\"\"', $pd_year]);
									}
									# si nom 2 deja apparu dans l'historique :
									else {
										if ($done{"$t_spell $t_auth"} eq "exit") {
												$done{"$t_spell $t_auth"} = "enter";
												push (@{$parentForms{$t_parentID}{"concept"}}, [1, "\\\"<i>$t_spell</i> $t_auth (from $s_parent) : ".$pub[2]."\\\"", '\"\"', $pd_year]);
										}
									}
								}
							}
							
							my $pos = 0;
							my $final;
							foreach my $x (sort {$parentForms{$a}{position} <=> $parentForms{$b}{position}} keys(%parentForms)) {
								$final .= "tableau[$pos][0] = \\\"".$parentForms{$x}{"source"}."\\\";";
								$final .= "tableau[$pos][1] = new Array(\\\"".$parentForms{$x}{"parents"}."\\\");";
								$final .= "tableau[$pos][2] = \\\"".$parentForms{$x}{"name"}."\\\";";
								$final .= "tableau[$pos][3] = \\\"".$parentForms{$x}{"authority"}."\\\";";
								$final .= "tableau[$pos][4] = \\\"".scalar(@{$parentForms{$x}{"concept"}})."\\\";";
								my $j = 5;
								foreach (sort {$a->[3] cmp $b->[3] || $a->[1] cmp $b->[1]} @{$parentForms{$x}{"concept"}}) {
									$final .= "tableau[$pos][$j] = new Array(".join(',',@{$_}).");";
									$j++;
								}
								$pos++;
							}
							
							#$test .= $final;
							my $tmp;
							$tmp .= '<div id="canvas-wrap" style="position:relative; width: 950px; min-height:600px; border: 0px solid grey;">';
							$tmp .= '<canvas id="THcanvas" width="1000" height="1000" style="position:absolute; top:0; left:0; z-index:0;"></canvas>';
							$tmp .= '</div>';
							$tmp .= '<script src="/explorerdocs/js/taxonhistory.js"></script>';
							$tmp .= "<script>";
							$tmp .= "draw(\"$final\", ".scalar(keys(%parentForms)).");";
							$tmp .= "</script>";
							
							$tmp  = Tr( td({-colspan=>2, -class=>'taxhMagicCell magicCell', -style=>"display: block;"}, $tmp ) );
							
							$test .= makeRetractableArray ('taxhTitle', 'taxhMagicCell magicCell', "Taxonomic concept evolution", $tmp, 'arrowRight', 'arrowDown', 1, 'none', 'true');
						}
						
						
						$graphic .= Tr( td({-colspan=>2, -class=>'graphMagicCell magicCell', -style=>"display: none;"},
									div({-id=>'legendDiv', -style=>'background: transparent;'},
										$legend,
										$fullscreen
									),
									div({-id=>'graphDiv', -style=>'width: 950px; background: transparent; overflow: auto;'},
									"<div id='sc_Div'></div>
									<script type='text/javascript'>
										
										var synonyms = [".join(',',@statuses)."]; 
										var uses = [".join(',',@uses)."]; 
										var valid = ['<i>$valid_name->[1]</i>','$valid_name->[2]','$valid_name->[20]'];
										
										var S = document.getElementById('sc_Div');
										var L = document.getElementById('sc_Legende');
										
										function newSchema() {
											/*var displayLink = [];
											for(var i = 1; i<16; i++) {
												var sel = document.getElementById('c'+i);
												displayLink[sel.value] = sel.checked;
											}
											displayLink['dead end'] = 0;*/
											
											S.innerHTML = '';
											var formatedSynonyms = [];
											var formatedChresonyms = [];
											N = new Array();
											schemaWidth = 0;
											for(var i in synonyms) {
												//if(displayLink[synonyms[i][2]])
													formatedSynonyms.push(synonyms[i].slice(0));
											}
											for(var i in uses) {
												//if(displayLink[uses[i][2]])
													formatedChresonyms.push(uses[i].slice(0));
											}
											
											var height = _startAnalysis(formatedSynonyms, formatedChresonyms, valid);
											S.style.height = height + 'px';
											_displaySchematic(vName, schemaWidth, vName.M.high, 2, '');
										
										} newSchema();
										
										if (document.getElementById('sc_Div').innerHTML != '') {
											document.getElementById('graphTable').style.display = 'block';
										}
									</script>"
							)
						));
						
						if ($dbase =~ m/flow/) {
							$graphic = makeRetractableGraph ('graphTitle', 'graphMagicCell magicCell', i($valid_name->[1]).' '.$valid_name->[2].' '.($trans->{'graphdisp'}->{$lang}), $graphic, 'arrowRight', 'arrowDown', 1, 'none', 'true');
						}
						else {
							$graphic = makeRetractableGraph ('graphTitle', 'graphMagicCell magicCell', $trans->{'graphDisplay'}->{$lang}, $graphic, 'arrowRight', 'arrowDown', 1, 'none', 'true');
						}
					}
					
					my $pos = $display_modes{graphic}{position} || $default_order{graphic};
					$orderedElements{$pos} = $graphic;
				}
				
				unless ($display_modes{synonymy}{skip} and $mode ne 'full') {
					if ($synonyms) {
						$synonymy = makeRetractableArray ('synsTitle', 'synsMagicCell magicCell', ucfirst($trans->{'synonymie'}->{$lang}), $synonyms, 'arrowRight', 'arrowDown', 1, $dms, 'true');
						my $pos = $display_modes{synonymy}{position} || $default_order{synonymy};
						$orderedElements{$pos} = $synonymy;
					}
				}
				unless ($display_modes{chresonymy}{skip} and $mode ne 'full') {
					if (scalar keys %chresonyms) {
						foreach (keys %chresonyms) {
							my $cl = $chresonyms{$_}{'label'};
							if ($chresonyms{$_}{'refs'}) { $cl .= join (', ', @{$chresonyms{$_}{'refs'}}); }
							$chresonymy .= Tr(td({-colspan=>2, -class=>'usesMagicCell magicCell', -style=>"display: $dmc;"}, $cl) );
						}		
						$chresonymy = makeRetractableArray ('usesTitle', 'usesMagicCell magicCell', ucfirst($trans->{'Chresonym(s)'}->{$lang}), $chresonymy, 'arrowRight', 'arrowDown', 1, $dmc, 'true');
						my $pos = $display_modes{chresonymy}{position} || $default_order{chresonymy};
						$orderedElements{$pos} = $chresonymy;
					}
				}
			}
		}
				
		my $geologic;
		unless ($display_modes{geological}{skip} or !$valid_name->[12]) {
			
			my %attributes;
			my @attribs;
			@attribs = split('#', $display_modes{geological}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my ($nbgeols) = @{request_tab("SELECT count(distinct ref_periode) FROM taxons_x_periodes WHERE ref_taxon = $id;", $dbc, 1)};
			my $max = $attributes{max} || 0;
			my $dmg = ( ( !$max or ( $max and $nbgeols <= $max ) ) and $display_modes{geological}{display} ) ? 'table-cell' : 'none';
			
			my $georeq = "	SELECT 	p.$lang,
						p.debut,
						p.fin,
						txp.ref_publication_ori,
						txp.page_ori
					FROM periodes AS p 
					LEFT JOIN taxons_x_periodes AS txp ON (p.index = txp.ref_periode)
					LEFT JOIN publications AS pub ON pub.index = txp.ref_publication_ori
					WHERE txp.ref_taxon = $id
					ORDER BY p.fin, p.niveau;";
								
			my $geols = request_tab($georeq,$dbc,2);
			my $curr_g;
			my $str_g;
			my @pubs_g;
			if ( scalar @{$geols} ){
				foreach my $row ( @{$geols} ){
					my $gdisp;
					if ($row->[0] ne $curr_g) {
						if ($curr_g) {
							if (scalar(@pubs_g)) { $str_g .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs_g);  }
							$geologic .= Tr( td({-colspan=>2, -class=>'geolMagicCell magicCell', -style=>"display: $dmg;"}, "$str_g") );
						}
						$curr_g = "$row->[0]";;
						@pubs_g = ();
												
						$str_g = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=fossils&mode=time"}, "$curr_g [$row->[1]-$row->[2] Ma]"); 
					}
	
					if ($row->[3]) {
						my $page;
						if ($row->[4]) { $page = ": $row->[4]"; }
						my @p = publication($row->[3], 0, 1, $dbc);
						push(@pubs_g, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[3]"}, "$p[1]$page") . getPDF($row->[3]));
					}
				}
				
				if ($str_g) {
					if (scalar(@pubs_g)) { $str_g .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs_g);  }
					$geologic .= Tr( td({-colspan=>2, -class=>'geolMagicCell magicCell', -style=>"display: $dmg;"}, $str_g) );
				}
								
				$geologic = makeRetractableArray ('geolTitle', 'geolMagicCell magicCell', ucfirst($trans->{geoldating}->{$lang}), $geologic, 'arrowRight', 'arrowDown', 1, $dmg, 'true');
				my $pos = $display_modes{geological}{position} || $default_order{geological};
				$orderedElements{$pos} = $geologic;
			}
		}

		if ($limit) { 
				$req = "SELECT index_taxon_fils FROM hierarchie AS h WHERE index_taxon_parent IN ($parentsIDs)";
				my $tab = request_tab($req, $dbc, 1);
				@sons_ids = @{$tab};
		}
		
		my $taxsonsids = scalar(@sons_ids) ? ', ' . join(', ', @sons_ids) : undef;
		my $partial;
		my @sons_rank_names;
		foreach (sort {$a <=> $b} keys(%sons_ranks)) { push(@sons_rank_names, $sons_ranks{$_}{nom}); }
					
		if ($privacy) {
			my $r = "SELECT h.index_taxon_fils FROM hierarchie AS h WHERE index_taxon_parent IN (".join(',',split('_',$privacy)).");";
			#die $r;
			my $l = request_tab($r,$dbc,1);
			$taxsonsids = ','.join(', ', @{$l});
			#die $taxsonsids;
		}
		
		unless ($dbase eq 'psylles' and $rank eq 'subfamily') {
					
		# Fetch presence of the taxon in a TDWG region
		my $countries_list;
		my $map;
		unless ($display_modes{tdwg}{skip} and $display_modes{map}{skip} and $mode ne 'full') {	
			
			# TODO: exclude FOSSILS from distribution
			my $req = 	"SELECT ref_pays, p.$lang, p.en, p.tdwg, p.tdwg_level, p.parent, ref_publication_ori, page_ori, precision, ref_taxon, ref_publication_maj, page_maj
					FROM taxons_x_pays AS txp 
					LEFT JOIN pays AS p ON txp.ref_pays = p.index
					LEFT JOIN publications  AS pub ON pub.index = ref_publication_ori
					WHERE txp.ref_taxon in ($id $taxsonsids) 
					AND p.en != 'Unknown'
					AND (txp.origine = 'native' OR txp.origine IS NULL)
					ORDER BY p.$lang, pub.annee;";
			
			my $sth5 = $dbc->prepare( $req );
							
			#if (url_param("test")) { $test = $req; }
	
			$sth5->execute( );
			my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $precision, $ref_taxon, $ref_pub_maj, $page_maj, $isfossil );
			# jompo
			# $sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $precision, $ref_taxon, $ref_pub_maj, $page_maj, $isfossil ) );
			$sth5->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_pub_ori, $page_ori, $precision, $ref_taxon, $ref_pub_maj, $page_maj ) );
						
			my $current_id;
			my $current_name;
			my $precis;
			my $string;
			my @pubs;
			my $sup = '';
			my %tdwg4;
			my %tdwg123;
			my %tdwgF4;
			my %tdwgF123;
			my %tdwgA4;
			my %tdwgA123;
			my %pubdone;
			my %level1;
						
			my %attributes;
			my @attribs;
			my ($nb_pays) = @{request_tab("SELECT count(*) FROM taxons_x_pays WHERE ref_taxon in ($id $taxsonsids) and (SELECT en from pays where index = ref_pays) NOT ILIKE 'unknown';", $dbc, 1)};
			@attribs = split('#', $display_modes{tdwg}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmt = ( ( !$max or ( $max and $nb_pays <= $max ) ) and $display_modes{tdwg}{display} ) ? 'table-cell' : 'none';
			
			while ( $sth5->fetch ) {
				my $pdisp;
				if ($country_id != $current_id or $precision ne $precis) {
					if ($current_id) {
						if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs);  }
						if ($sup and $current_name ne $sup ) { $string = p({-style=>'margin: 0; padding: 0 0 0 1em;'}, $string); }
						$countries_list .= Tr( td({-colspan=>2, -class=>'geoMagicCell magicCell', -style=>"display: $dmt;"}, $string) );
					}
					$current_id = $country_id;
					$current_name = $country;
					$precis = $precision;
					@pubs = ();
					%pubdone = [];
					my $sep;
					$string = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$current_id"}, $current_name);
					if ($precision) { $string .= '&nbsp;' . $precision }
					unless ($current_name =~ m/$sup .*\(/) { $sup = $current_name }
				}
					
				unless (!$ref_pub_ori or exists($pubdone{"$ref_pub_ori:$page_ori"})) {
					$pubdone{"$ref_pub_ori:$page_ori"} = 1;
					my $page;
					if ($page_ori) { $page = ":&nbsp;$page_ori" }
					my @p = publication($ref_pub_ori, 0, 1, $dbc);
					my $denonce;
					if ($ref_pub_maj) { 
						my @p2 = publication($ref_pub_maj, 0, 1, $dbc);
						my $pmaj;
						if ($page_maj) { $pmaj = "$p2[1]:&nbsp;$page_maj" }
						else { $pmaj = $p2[1] }
						$denonce = " $trans->{'denounced'}->{$lang} $trans->{'BY'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_pub_maj"}, $pmaj); 
					}
					push(@pubs, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_pub_ori"}, "$p[1]$page") . getPDF($ref_pub_ori) . $denonce . getPDF($ref_pub_maj));
				}
				
				unless (exists $tdwg4{$tdwg} or $ref_pub_maj) {
					
					my @fathers;
					
					if (length($tdwg) >= 5) { 
						
						if (length($tdwg) > 5) { 
							my @p = split(',', $tdwg); 
							
							foreach (@p) {
								if (length($_) < 5) { push(@fathers, $_); }
								else { $tdwg123{$_} = 1; }
							}
							 
						}
						
						if ($parent) {
							my ($father) = request_row("SELECT en FROM pays WHERE tdwg = '$parent';",$dbc,1);
							if ($father eq $en) { push(@fathers, $parent) }
							else {
								unless (exists $tdwg4{$tdwg}) {
									if (!$isfossil) {
										if (length($tdwg) == 5) { $tdwg4{$tdwg} = 1; }
										else { $tdwg123{$tdwg} = 1; }
									}
									else {
										if (length($tdwg) == 5) { $tdwgF4{$tdwg} = 1; }
										else { $tdwgF123{$tdwg} = 1; }
									}
								}
							}
						}
						else {
							unless (exists $tdwg4{$tdwg}) {
									if (!$isfossil) {
										if (length($tdwg) == 5) { $tdwg4{$tdwg} = 1; }
										else { $tdwg123{$tdwg} = 1; }
									}
									else {
										if (length($tdwg) == 5) { $tdwgF4{$tdwg} = 1; }
										else { $tdwgF123{$tdwg} = 1; }
									}
							}
						}
					} else {
						push(@fathers, $tdwg);
					}
					
					while (scalar(@fathers)) {
						my $sons = request_tab("SELECT tdwg FROM pays WHERE parent IN ('" . join("', '",@fathers) . "');", $dbc, 1);
						
						@fathers = ();
						
						if (scalar(@{$sons})) {
							foreach (@{$sons}) {
								if (!$isfossil) {
									if (length($_) >= 5) { $tdwg123{$_} = 1; }
									else { push(@fathers, $_); }
								}	
								else {
									if (length($_) >= 5) { $tdwgF123{$_} = 1; }
									else { push(@fathers, $_); }
								}	
							}
						}
					}
				}
			}
			if (scalar(@pubs)) { $string .= "&nbsp; $trans->{'segun'}->{$lang} &nbsp;" . join(', ', @pubs); }
			if ($sup and $current_name ne $sup) { $string = p({-style=>'margin: 0; padding: 0 0 0 1em;'}, $string); }
			$countries_list .= $string ? Tr( td({-colspan=>2, -class=>'geoMagicCell magicCell', -style=>"display: $dmt;"}, $string) ) : '';
			$sth5->finish();
			
			#if ($mode eq 'fully') {
			#	
			#	my %gboard;
			#	my $req = "SELECT ref_pays, p.$lang, p.en, p.tdwg, p.tdwg_level, p.parent, ref_taxon
			#					FROM taxons_x_pays AS txp 
			#					LEFT JOIN pays AS p ON txp.ref_pays = p.index
			#					WHERE txp.ref_taxon in ($id $taxsonsids) 
			#					AND p.en != 'Unknown'
			#					ORDER  BY p.$lang;";
			#									
			#	my $sth = $dbc->prepare( $req );
		        #
			#	$sth->execute( );
			#	my ( $country_id, $country, $en, $tdwg, $level, $parent, $ref_taxon );
			#	$sth->bind_columns( \( $country_id, $country, $en, $tdwg, $level, $parent, $ref_taxon ) );
			#	
			#	while ( $sth->fetch ) {
			#		
			#		unless (exists $gboard{$en}{taxons}{$ref_taxon}) {
			#			
			#			my $req = "SELECT DISTINCT nom_rang_fils, index_taxon_fils
			#				FROM hierarchie 
			#				WHERE index_taxon_fils IN (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = $ref_taxon and nom_rang_parent IN ('".join("','",@sons_rank_names)."'))
			#				OR index_taxon_fils IN (SELECT index_taxon_fils FROM hierarchie WHERE index_taxon_parent = $ref_taxon)
			#				OR  index_taxon_fils = $ref_taxon;";
			#				
			#			my $family = request_tab($req, $dbc, 2);
			#			
			#			my ($levelI, $levelII);
			#			while ((!$levelI or !$levelII) and $parent) {
			#				my $high = request_tab("SELECT $lang, tdwg_level, parent FROM pays WHERE tdwg = '$parent';", $dbc, 2);
			#				if ($high->[0][1] eq '2') { $levelII = $high->[0][0]; }
			#				elsif ($high->[0][1] eq '1') { $levelI = $high->[0][0]; }
			#				$parent = $high->[0][2];
			#			}
			#														
			#			my @cles = split('\s*\(', $en);
			#								
			#			$gboard{$en}{label} = $country;
			#			$gboard{$en}{levelI} = $levelI;
			#			$gboard{$en}{levelII} = $levelII;
			#									
			#			foreach (@{$family}) {
			#				unless (exists $gboard{$en}{taxons}{$_->[1]}) {
			#					$gboard{$en}{taxons}{$_->[1]} = 1;
			#					$gboard{$en}{$_->[0]} += 1;
			#					if (scalar(@cles) > 1) { 
			#						if (exists $gboard{$cles[0]} ) {
			#							unless (exists $gboard{$cles[0]}{taxons}{$_->[1]}) {
			#								$gboard{$cles[0]}{taxons}{$_->[1]} = 1;
			#								$gboard{$cles[0]}{$_->[0]} += 1;
			#							}
			#						}
			#					}
			#				}
			#			}
			#		}
			#	}
			#						
			#	#foreach my $key (sort {$gboard{$a}{levelI} cmp $gboard{$b}{levelI} || $gboard{$a}{levelII} cmp $gboard{$b}{levelII}} keys(%gboard)) {
			#	#	$test .= "$gboard{$key}{levelI} $gboard{$key}{levelII} $gboard{$key}{label} [ species : $gboard{$key}{taxa} ]".br;
			#	#}
			#	
			#}
			
			my $areas;		
			my $areasF;		
			if (($dbase eq 'psylles' or $dbase eq 'cool') and !$valid_name->[9]) { $partial = "&nbsp;&nbsp;($trans->{partial}->{$lang})"; }
			if ( $countries_list ) {
								
				unless ($display_modes{tdwg}{skip} and $mode ne 'full') {
					$countries_list = makeRetractableArray ('geoTitle', 'geoMagicCell magicCell', ucfirst($trans->{"geodistribution"}->{$lang}) . $partial, $countries_list, 'arrowRight', 'arrowDown', 1, $dmt, 'true');
					my $pos = $display_modes{tdwg}{position} || $default_order{tdwg};
					$orderedElements{$pos} = $countries_list;
				}
				else { $countries_list = undef; }
				
				unless ($display_modes{map}{skip} and $mode ne 'full') {
					
					my $dmm = $display_modes{map}{display} ? 'table-cell' : 'none';
					my %attributes;
					my @attribs = split('#', $display_modes{map}{attributes});
					foreach (@attribs) {
						my ($key, $val) = split(':', $_);
						$attributes{$key} = $val;
					}
					my ($sea_color, $continent_color, $continent_borders, $area_color, $area_borders, $alien_color, $alien_borders, $area_color_np, $area_borders_np, $area_color_fsl, $area_borders_fsl, $area_color_fsl_np, $area_borders_fsl_np, $map_width);
					
					$sea_color = $attributes{sea} ? "#$attributes{sea}" : 'transparent';
					$continent_color = $attributes{continents} || 'AAAAAA';
					$continent_borders = $attributes{cborders} || 'AAAAAA';
					$map_width =  $attributes{width} || 500;

					$area_color = $attributes{areas} || '00008B';
					$area_borders = $attributes{aborders} || '00008B';
					$alien_color = $attributes{areas_alien} || '00008B';
					$alien_borders = $attributes{aborders_alien} || '00008B';
					$area_color_np = $attributes{areas_not_precise} || $area_color;
					$area_borders_np = $attributes{aborders_not_precise} || $area_borders;
					
					$area_color_fsl = $attributes{areas_fossil} || $area_color;
					$area_borders_fsl = $attributes{aborders_fossil} || $area_borders;
					$area_color_fsl_np = $attributes{areas_fossil_not_precise} || $area_color;
					$area_borders_fsl_np = $attributes{aborders_fossil_not_precise} || $area_borders;
					
					
					my $mapok;
					my $mapokF;
					if (scalar(keys(%tdwg123))) {
						$areas .= 'tdwg4:b:'.join(',', keys(%tdwg123)).'||';
						$mapok = 1;
					}					
					if (scalar(keys(%tdwg4))) {
						$areas .= 'tdwg4:a:'.join(',', keys(%tdwg4)).'||';
						$mapok = 1;
					}
					if (scalar(keys(%tdwgF123))) {
						$areasF .= 'tdwg4:b:'.join(',', keys(%tdwgF123)).'||';
						$mapokF = 1;
					}					
					if (scalar(keys(%tdwgF4))) {
						$areasF .= 'tdwg4:a:'.join(',', keys(%tdwgF4)).'||';
						$mapokF = 1;
					}					
					my $level2 = request_tab("SELECT DISTINCT get_tdwg_parent_by_level(tdwg, 2) FROM pays WHERE tdwg IN ('" . join("', '", keys(%tdwg4), keys(%tdwg123)) . "') AND get_tdwg_parent_by_level(tdwg, 2) NOT IN ('61','63') ORDER BY 1;", $dbc, 1);
					my $level2F = request_tab("SELECT DISTINCT get_tdwg_parent_by_level(tdwg, 2) FROM pays WHERE tdwg IN ('" . join("', '", keys(%tdwgF4), keys(%tdwgF123)) . "') AND get_tdwg_parent_by_level(tdwg, 2) NOT IN ('61','63') ORDER BY 1;", $dbc, 1);
					
					my $bbox;
					my $mappos;
					if ("@{$level2}" eq "42" or "@{$level2}" eq "43" or "@{$level2}" eq "42 43" or "@{$level2}" eq "60"  or "@{$level2}" eq "62" or "@{$level2}" eq "60 62") {
						$bbox = "&bbox=90,-25,186,22";
						$mappos = 'right';
					}
					#elsif ("@{$level2}" eq "21") { $bbox = "&bbox=-35,10,35,45"; }
					#elsif ("@{$level2}" eq "29") { $bbox = "&bbox=21,-27,75,0"; }
					#elsif ("@{$level2}" eq "51") { "&bbox=130,-55,180,-30" }
					elsif ("@{$level2}" eq "81") { 
						$bbox = "&bbox=-105,5,-55,30"; 
						$mappos = 'left';
					}
					
					my $bboxF;
					my $mapposF;
					if ("@{$level2F}" eq "42" or "@{$level2F}" eq "43" or "@{$level2F}" eq "42 43" or "@{$level2F}" eq "60"  or "@{$level2F}" eq "62" or "@{$level2F}" eq "60 62") {
						$bboxF = "&bbox=90,-25,186,22";
						$mapposF = 'right';
					}
					#elsif ("@{$level2}" eq "21") { $bbox = "&bbox=-35,10,35,45"; }
					#elsif ("@{$level2}" eq "29") { $bbox = "&bbox=21,-27,75,0"; }
					#elsif ("@{$level2}" eq "51") { "&bbox=130,-55,180,-30" }
					elsif ("@{$level2F}" eq "81") { 
						$bboxF = "&bbox=-105,5,-55,30"; 
						$mapposF = 'left';
					}
										
					#if ($continent_color eq $continent_borders) {
					#	$areas .= "tdwg1:c:1,2,3,4,5,6,7,8,9";
					#}
					#else {
						$areas = substr($areas,0,-2);
						$areas = "tdwg4:c:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg not in ('".join("','", keys(%tdwg4), keys(%tdwg123))."') and tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areas";
						
						$areasF = substr($areasF,0,-2);
						$areasF = "tdwg4:c:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg not in ('".join("','", keys(%tdwgF4), keys(%tdwgF123))."') and tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)})."||$areasF";
					#}
					$areas = "ad=$areas";
					$areasF = "ad=$areasF";
					
					my $styles = "as=c:$continent_color,$continent_borders,0|b:$area_color_np,$area_borders_np,0|a:$area_color,$area_borders,0";
					my $stylesF = "as=a:$area_color_fsl,$area_borders_fsl,0|b:$area_color_fsl_np,$area_borders_fsl_np,0|c:$continent_color,$continent_borders,0";
					
					my $zoom;
					my $bound;
					if ($bbox) { 
						if ($dbase eq 'cool') { $map_width = 600; } else { $map_width = 470; }
						$zoom = "<img id='cmap2' 
								style='background: $sea_color; margin-top: 0em; border: 1px solid black;' 
								src='$maprest?$areas&$styles&ms=$map_width$bbox&recalculate=false' 
								onMouseOver=".'"'."this.style.cursor='pointer';".'"'."  
								onclick=".'"'."ImageMax('$maprest?$areas&$styles&ms=1000$bbox&recalculate=false');".'"'.
							">";
						
						unless ($dbase eq 'cool') { $bound = "&nbsp;&nbsp;" } else { $bound = "<br><br>" }
					}
					
					if ($mapok) {
						$map .= "
						<script type='text/javascript'>
						function ImageMax(chemin) {
							var html = ".'"'."<html> <head> <title>Distribution</title> </head> <body style='background: $sea_color;'><IMG style='background: $sea_color;' src=".'"'."+chemin+".'"'." BORDER=0 NAME=ImageMax></body></html>".'"'.";
							var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
							popupImage.document.open();
							popupImage.document.write(html);
							popupImage.document.close()
						};
						</script>";
							
						$map .=  "<img id='cmap' 
								style='background: $sea_color; margin-top: 0em; border: 0px solid black; display: none;' 
								src='$maprest?$areas&$styles&ms=$map_width&recalculate=false' 
								onMouseOver=".'"'."this.style.cursor='pointer';".'"'."  
								onclick=".'"'."ImageMax('$maprest?$areas&$styles&ms=1000');".'"'.">";
						
						#if($dbase eq 'cool') { $map .= $bound.$zoom; } else { $map = $mappos eq 'left' ? $zoom.$bound.$map : $map.$bound.$zoom; }
							
						my $mapWidth = 720;
						my $mapHeight = 450;
						if ($dbase eq 'cool') { $mapWidth = 570; $mapHeight = 360; }
						
						#if ($mode eq 'full') {
							#die $valid_name->[1].'##'.$valid_name->[18];
							#/explorerdocs/js/compositeMaps.js
							#$map .= '<div id="map" name="map" style="width:'+$map_width+'px; height:'+$map_width+'px;"></div>';
							$map .= '<div class="olMap" id="map" name="map" style="width:'.$mapWidth.'px; height:'.$mapHeight.'px"></div>';
							#$map .= '<input type="hidden" id="hd_name_taxon" name="hd_name_taxon" value="Canis lupus##Linnaeus|Canis lupus##Linnaeus|Oryctolagus cuniculus##Linnaeus"/>';
							$map .= '<input type="hidden" id="hd_name_taxon" name="hd_name_taxon" value="'.$valid_name->[1].'##'.$valid_name->[18].'|'.$valid_name->[1].'##'.$valid_name->[18].'"/>';
							$map .= '<script type="text/javascript">';
							$map .= "urlMapREST = \"$maprest?$areas&$styles&ms=$map_width&recalculate=false&img=false\";";
							$map .= "makeCompositeMap('$dbase');";
							$map .= '</script>';
						#}

						my $lgnd;						
						if($area_color_np ne $area_color and scalar(keys(%tdwg123))) { 
							$lgnd .= table({-style=>'margin-top: 5px;'},
									Tr(
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"data_accuracy"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, div({-style=>"height: 15px; width: 30px; background-color: #$area_color;"})), 
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"precise_data"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, div({-style=>"height: 15px; width: 30px; background-color: #$area_color_np;"})), 
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"unprecise_data"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, '('.ucfirst($trans->{"tdwg_standard"}->{$lang}).')'),
										td({-style=>"padding: 3px; font-size: 10px;"}, img({-src=>"/explorerdocs/GBIFoccs.png", -style=>'border: 0; margin: 0;'})), 
										td({-style=>"padding: 3px; font-size: 10px;"}, 'GBIF occurrences')
									)
								); 
						}							
						
						$map = Tr( td({-colspan=>2, -class=>'mapMagicCell magicCell', -style=>"display: $dmm;"}, $map . $lgnd ) );
						$map = makeRetractableArray ('mapTitle', 'mapMagicCell magicCell', ucfirst($trans->{"geomap"}->{$lang}.': '.$trans->{'extant_taxa'}->{$lang}), $map, 'arrowRight', 'arrowDown', 1, $dmm, 'true');
						my $pos = $display_modes{map}{position} || $default_order{map};
						$orderedElements{$pos} .= $map;
					}
					
					if ($bboxF) { 
						if ($dbase eq 'cool') { $map_width = 600; } else { $map_width = 470; }
						$zoom = "<img id='cmap2' 
								style='background: $sea_color; margin-top: 0em; border: 1px solid black;' 
								src='$maprest?$areasF&$stylesF&ms=$map_width$bboxF&recalculate=false' 
								onMouseOver=".'"'."this.style.cursor='pointer';".'"'."  
								onclick=".'"'."ImageMax('$maprest?$areasF&$stylesF&ms=1000$bboxF&recalculate=false');".'"'.
							">";
						
						unless ($dbase eq 'cool') { $bound = "&nbsp;&nbsp;" } else { $bound = "<br><br>" }
					}
					
					if ($mapokF) {
						$map = "
						<script type='text/javascript'>
						function ImageMax(chemin) {
							var html = ".'"'."<html> <head> <title>Distribution</title> </head> <body style='background: $sea_color;'><IMG style='background: $sea_color;' src=".'"'."+chemin+".'"'." BORDER=0 NAME=ImageMax></body></html>".'"'.";
							var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
							popupImage.document.open();
							popupImage.document.write(html);
							popupImage.document.close()
						};
						</script>".
							"<img 	id='cmap' 
								style='background: $sea_color; margin-top: 0em; border: 0px solid black;' 
								src='$maprest?$areasF&$stylesF&ms=$map_width&recalculate=false' 
								onMouseOver=".'"'."this.style.cursor='pointer';".'"'."  
								onclick=".'"'."ImageMax('$maprest?$areasF&$stylesF&ms=1000');".'"'.
							">";
						
						if($dbase eq 'cool') { $map .= $bound.$zoom; } else { $map = $mapposF eq 'left' ? $zoom.$bound.$map : $map.$bound.$zoom; }						
						
						my $lgnd;						
						if($area_color_fsl ne $area_color_fsl_np and scalar(keys(%tdwgF123))) { 
							$lgnd .= table({-style=>'margin-top: 5px;'},
									Tr(
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"data_accuracy"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, div({-style=>"height: 15px; width: 30px; background-color: #$area_color_fsl;"})), 
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"precise_data"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, div({-style=>"height: 15px; width: 30px; background-color: #$area_color_fsl_np;"})), 
										td({-style=>"padding: 3px; font-size: 10px;"}, ucfirst($trans->{"unprecise_data"}->{$lang})),
										td({-style=>"padding: 3px; font-size: 10px;"}, '('.ucfirst($trans->{"tdwg_standard"}->{$lang}).')')
									)
								); 
						}							
						
						$map = Tr( td({-colspan=>2, -class=>'mapFMagicCell magicCell', -style=>"display: $dmm;"}, $map . $lgnd ) );
						$map = makeRetractableArray ('mapFTitle', 'mapFMagicCell magicCell', ucfirst($trans->{"geomap"}->{$lang}.': '.$trans->{'extinct_taxa'}->{$lang}), $map, 'arrowRight', 'arrowDown', 1, $dmm, 'true');
						my $pos = $display_modes{map}{position} || $default_order{map};
						$orderedElements{$pos} .= $map;
					}
				}
			}
		}
		
		my $associates;
		unless ($display_modes{associates}{skip} and $mode ne 'full') {
			
			my %attributes;
			my @attribs;
			my ($nb_hosts) = @{request_tab("SELECT count(*) FROM taxons_x_taxons_associes WHERE ref_taxon IN ($id $taxsonsids);", $dbc, 1)};
			@attribs = split('#', $display_modes{associates}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmh = ( ( !$max or ( $max and $nb_hosts <= $max ) ) and $display_modes{associates}{display} ) ? 'table-cell' : 'none';

			my $assocs = request_tab("	SELECT 	ta.index,
								(get_taxon_associe(ta.index)).*,
								txt.ref_publication_ori, 
								txt.page_ori, 
								txt.ref_publication_maj, 
								txt.page_maj,
								ty.index,
								ty.$lang,
								sx.$lang,
								ta.statut,
								ta.ref_valide,
								txt.certitude
							FROM taxons_associes AS ta 
							LEFT JOIN taxons_x_taxons_associes AS txt ON (ta.index = txt.ref_taxon_associe)
							LEFT JOIN types_association AS ty ON (ty.index = txt.ref_type_association)
							LEFT JOIN sexes AS sx ON (sx.index = txt.ref_sexe)
							LEFT JOIN publications AS pub ON pub.index = txt.ref_publication_ori
							WHERE txt.ref_taxon IN ($id $taxsonsids)
							ORDER BY ty.$lang, 2, txt.certitude, pub.annee;",$dbc,2);
							
	
	
			my $curr_ta;
			my $curr_ty;
			my $curr_tystr;
			my $str_ta;
			my @pubs_ta;
			my $ss_grp;
			my $curr_cert;
			if ( scalar @{$assocs} ){
				foreach my $row ( @{$assocs} ){
					if ("$row->[0]" ne $curr_ta) {
						if ($curr_ta) {
							if (scalar(@pubs_ta)) { $str_ta .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs_ta);  }
							$ss_grp .= Tr( td({-colspan=>2, -class=>'ssgrp'.$curr_ty.'_'.'MagicCell magicCell', -style=>"display: $dmh;"}, $str_ta.$confirm) );
						}
						if ($row->[11] ne $curr_ty) {
							if ($curr_ty) {
								$ss_grp = makeRetractableArray ("ssgrpTitle_$curr_ty", 'ssgrp'.$curr_ty.'_'.'MagicCell magicCell', ucfirst($curr_tystr), $ss_grp, 'arrowRight', 'arrowDown', 1, $dmh, 'true');
								$associates .= Tr( td({-colspan=>2, -class=>'assocMagicCell magicCell', -style=>"display: $dmh;"}, $ss_grp ) );
							}
							$curr_ty = $row->[11];
							$curr_tystr = $row->[12];
							$ss_grp = '';
						}
						$curr_ta = "$row->[0]";
						@pubs_ta = ();
						$curr_cert = $row->[16];
						$confirm = '';
						my $pid = $row->[0];
						my $valid;
						if ($row->[11]) { $row->[11] = " ($row->[11])"; }
						my $str = i($row->[1]);
						if($row->[2]) { $str .= " $row->[2]" }
						$str = "<span style='white-space: nowrap;'>$str</span>";
						if($row->[6]) { $str .= " = <span style='white-space: nowrap;'>$row->[6]</span>" }
						my $higher;
						if($row->[4]) {
							$higher .= "$row->[4]";
							if($row->[3]) { $higher .= ", $row->[3]" }
							$higher = " <span style='white-space: nowrap;'>($higher)</span>";
						}
						elsif ($row->[3]) {
							$higher .= " ($row->[3])";
						}
												
						$str_ta = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=associate&id=$row->[0]"}, $str . $higher); 
					}
						
					if ($row->[7]) {
						my $page;
						if ($row->[8]) { $page = ": $row->[8]" }
						my @p = publication($row->[7], 0, 1, $dbc);
						push(@pubs_ta, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[7]"}, "$p[1]$page") . getPDF($row->[7]));
					}
					
					if ($row->[16] eq 'uncertain') { $confirm = "&nbsp; [&nbsp;$trans->{'doubtful'}->{$lang}&nbsp;]"; }
					elsif ($row->[16] eq 'certain') { $confirm = "&nbsp; [&nbsp;$trans->{'confirmed'}->{$lang}&nbsp;]"; }
					
				}
	
				if (scalar(@pubs_ta)) { $str_ta .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs_ta);  }
				$ss_grp .= Tr( td({-colspan=>2, -class=>'ssgrp'.$curr_ty.'_'.'MagicCell magicCell', -style=>"display: $dmh;"}, $str_ta.$confirm) );
				$ss_grp = makeRetractableArray ("ssgrpTitle_$curr_ty", 'ssgrp'.$curr_ty.'_'.'MagicCell magicCell', ucfirst($curr_tystr), $ss_grp, 'arrowRight', 'arrowDown', 1, $dmh, 'true');
				$associates .= Tr( td({-colspan=>2, -class=>'assocMagicCell magicCell', -style=>"display: $dmh;"}, "$ss_grp" ) );
								
			}
						
			if ($associates) {
				$associates = makeRetractableArray ('assocTitle', 'assocMagicCell magicCell', ucfirst($trans->{"bioInteract"}->{$lang}), $associates, 'arrowRight', 'arrowDown', 1, $dmh, 'true', undef, 'none');
				my $pos = $display_modes{associates}{position} || $default_order{associates};
				$orderedElements{$pos} = $associates;
			}
		}
		
		my $localities;
		#unless ($display_modes{localities}{skip} and $mode ne 'full') {
		if ($dbase eq 'hefo') {
			
			my %attributes;
			my @attribs;
			my ($nb_loc) = @{request_tab("SELECT count(*) FROM taxons_x_sites WHERE ref_taxon IN ($id $taxsonsids);", $dbc, 1)};
			@attribs = split('#', $display_modes{localities}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmh = ( ( !$max or ( $max and $nb_loc <= $max ) ) and $display_modes{localities}{display} ) ? 'table-cell' : 'table-cell';
			
			my $locals = request_tab("	SELECT 	l.index,
								l.nom || ' (' || p.en || ')',
								(
									WITH RECURSIVE concat(index, en, niveau, parent) AS (
									  SELECT index, en, (select en from niveaux_litho where index = niveau), parent
									    FROM lithostrats WHERE index = txs.ref_lithostrat
									  UNION ALL
									  SELECT l.index, l.en, (select en from niveaux_litho where index = l.niveau), l.parent
									    FROM concat AS c, lithostrats AS l
									    WHERE c.parent = l.index
									)
									SELECT array_to_string(array_agg(en || ' ' || niveau),', ') AS full FROM concat
								),
								(
									WITH RECURSIVE concat(index, en, niveau, parent) AS (
									  SELECT index, en, (select en from niveaux_geologiques where index = niveau), parent
									    FROM periodes WHERE index = txs.ref_periode
									  UNION ALL
									  SELECT p.index, p.en, (select en from niveaux_geologiques where index = p.niveau), p.parent
									    FROM concat AS c, periodes AS p
									    WHERE c.parent = p.index
									)
									SELECT array_to_string(array_agg(en || ' ' || niveau),', ') AS full FROM concat
								),
								(
									WITH RECURSIVE concat(index, en, niveau, parent) AS (
									  SELECT index, en, (select en from niveaux_geologiques where index = niveau), parent
									    FROM periodes WHERE index = txs.ref_periode2
									  UNION ALL
									  SELECT p.index, p.en, (select en from niveaux_geologiques where index = p.niveau), p.parent
									    FROM concat AS c, periodes AS p
									    WHERE c.parent = p.index
									)
									SELECT array_to_string(array_agg(en || ' ' || niveau),', ') AS full FROM concat
								),
								txs.ref_pub_ori, 
								txs.page_ori, 
								txs.ref_pub_maj, 
								txs.page_maj
							FROM localites AS l 
							LEFT JOIN taxons_x_sites AS txs ON (l.index = txs.ref_localite)
							LEFT JOIN pays AS p ON (p.index = l.ref_pays)
							LEFT JOIN publications AS pub ON pub.index = txs.ref_pub_ori
							WHERE txs.ref_taxon IN ($id $taxsonsids)
							AND afficher = 'display'
							ORDER BY l.nom, pub.annee;",$dbc,2);
							
			my $curr;
			my $str;
			my @pubs;
			my $ss_grp;
			if ( scalar @{$locals} ){
				foreach my $row ( @{$locals} ){
					if ($curr ne "$row->[0]") {
						if ($curr) {
							#if (scalar(@pubs)) { $str .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs);  }
							if (scalar(@pubs)) { $str .= "Publication: " . join(', ', @pubs);  }
							$localities .= Tr( td({-colspan=>2, -class=>'locMagicCell magicCell', -style=>"display: $dmh;"}, $str ) );
						}
						$curr = "$row->[0]";
						@pubs = ();
						$str = "<div style='margin-top: 3px;'>site: $row->[1] </div>";
						if($row->[2]) { $str .= "Lithostratigraphy: $row->[2] <br>" }
						if($row->[3]) { $str .= "Chronostratigraphy start: $row->[3] <br>" }
						if($row->[4]) { $str .= "Chronostratigraphy end: $row->[4] <br>" }
						#$str = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=associate&id=$row->[0]"}, $str); 
					}
					if ($row->[5]) {
						my $page;
						if ($row->[6]) { $page = ": $row->[6]" }
						my @p = publication($row->[5], 0, 1, $dbc);
						push(@pubs, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$row->[7]"}, "$p[1]$page") . getPDF($row->[5]));
					}
				}

				#if (scalar(@pubs)) { $str .= "&nbsp;$trans->{'segun'}->{$lang}&nbsp;" . join(', ', @pubs);  }
				if (scalar(@pubs)) { $str .= "Publication: " . join(', ', @pubs);  }
				$localities .= Tr( td({-colspan=>2, -class=>'locMagicCell magicCell', -style=>"display: $dmh;"}, $str ) );								
			}
						
			if ($localities) {
				$localities = makeRetractableArray ('locTitle', 'locMagicCell magicCell', ucfirst($trans->{"fossilSites"}->{$lang}), $localities, 'arrowRight', 'arrowDown', 1, $dmh, 'true', undef, 'none');
				my $pos = $display_modes{localities}{position} || $default_order{localities};
				$orderedElements{$pos} = $localities;
			}
		}

		}

		# Fetch vernacular names
		my $vernaculars;
		unless ($display_modes{vernaculars}{skip} and $mode ne 'full') {		
			
			my %attributes;
			my @attribs;
			my ($nb_vern) = @{request_tab("SELECT count(*) FROM taxons_x_vernaculaires WHERE ref_taxon IN ($id $taxsonsids);", $dbc, 1)};
			@attribs = split('#', $display_modes{vernaculars}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmv = ( ( !$max or ( $max and $nb_vern <= $max ) ) and $display_modes{vernaculars}{display} ) ? 'table-cell' : 'none';

			$vernaculars = get_vernaculars($dbc, 'txv.ref_taxon', $id, $dmv);
			my $pos = $display_modes{vernaculars}{position} || $default_order{vernaculars};
			$orderedElements{$pos} = $vernaculars;
		}
		
		my $images;
		unless ($display_modes{images}{skip} and $mode ne 'full') {
						
			# Fetch specimen images
			my $imgs = request_tab("SELECT icone_url, index, url, commentaire FROM taxons_x_images AS txi LEFT JOIN images AS I ON txi.ref_image = I.index WHERE txi.ref_taxon = $id ORDER BY groupe, tri;",$dbc);
			
			# Fetch type specimen images
			my $type_imgs = request_tab("	SELECT icone_url, I.index, url, nc.orthographe, nc.autorite, nxi.commentaire
							FROM noms_x_images AS nxi 
							LEFT JOIN images AS I ON nxi.ref_image = I.index 
							LEFT JOIN noms_complets AS nc ON nxi.ref_nom = nc.index
							WHERE nxi.ref_nom in (".join(',', @names_index).")
                            ORDER BY groupe, tri;",$dbc);
			
			my %attributes;
			my @attribs;
			my $nb_imgs = scalar @{$imgs} + scalar @{$type_imgs};
			@attribs = split('#', $display_modes{images}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmi = ( ( !$max or ( $max and $nb_imgs <= $max ) ) and $display_modes{images}{display} ) ? 'table-cell' : 'none';
					
			if ( scalar @{$imgs} or scalar @{$type_imgs} ){
				
				$images .= "<DIV ID=imgsdiv>";
				if ($dbase eq 'cool') {
					foreach my $row ( @{$imgs} ){
						$images .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
					}
					foreach my $row ( @{$type_imgs}){
						$images .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-onMouseOver=>"this.style.cursor='pointer';", -onClick=>"window.open('$row->[2]', '', 'toolbar=0, location=0, scrollbars=1, directories=0, status=0, resizable=1, width=1100, height=800');"}, img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'})));
					}				
				}
				else {
					my $thumbnail;
					foreach my $row ( @{$imgs} ){
						$thumbnail = $row->[0] ? img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$row->[2]", -style=>'height: 150px; border: 0; margin: 0;'});
						$images .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=taxon"}, $thumbnail));
					}
					foreach my $row ( @{$type_imgs}){
						$thumbnail = $row->[0] ? img({-src=>"$row->[0]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$row->[2]", -style=>'height: 150px; border: 0; margin: 0;'});
						$images .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$row->[1]&search=nom"}, $thumbnail));
					}
				}
				$images .= '</DIV>' . div({-style=>'clear: both; float: none;'});
				
				$images = Tr( td({-colspan=>2, -class=>'imgMagicCell magicCell', -style=>"display: $dmi;"}, $images ) );
								
				$images = makeRetractableArray ('imgsTitle', 'imgMagicCell magicCell', ucfirst($trans->{"images"}->{$lang}), $images, 'arrowRight', 'arrowDown', 1, $dmi, 'true');
				
				my $pos = $display_modes{images}{position} || $default_order{images};
				$orderedElements{$pos} = $images;
			}
		}

		my $types;
		unless ($display_modes{types}{skip} and $mode ne 'full') {
			my $dmt = $display_modes{types}{display} ? 'table-cell' : 'none';
			#fetch types present in this repository
			my $typesSQL = request_tab("SELECT ref_nom, orthographe, autorite, quantite, tt.$lang, s.en, td.$lang, ld.index, ld.nom, nxt.ref_pub, nxt.page, nxt.remarques
											FROM noms_x_types AS nxt
											LEFT JOIN lieux_depot AS ld ON ld.index = nxt.ref_lieux_depot
											LEFT JOIN noms_complets AS nc ON nxt.ref_nom = nc.index
											LEFT JOIN types_type AS tt ON ( nxt.ref_type = tt.index )
											LEFT JOIN sexes AS s ON ( nxt.ref_sexe = s.index )
											LEFT JOIN types_depot AS td ON ( nxt.ref_type_depot = td.index )
											WHERE nxt.ref_nom in (".join(',', @names_index).")
											ORDER BY ld.nom, tt.$lang, quantite;",$dbc);
			
			my $sum = 0;
			foreach my $type ( @{$typesSQL} ) {
				my @more;
				if ($type->[5]) { 
					if ($type->[5] eq 'male') { push(@more, "&#9794;"); }
					elsif ($type->[5] eq 'female') { push(@more, "&#9792;"); }
				}
				
				if ($type->[6]) { push(@more, $type->[6])}
				my $lien;
				my $pluriel;
				if($type->[3] > 1) { 
					$pluriel = 's';
					$lien = $trans->{'deposited_in(s)'}->{$lang};
				}
				else {
					$lien = $trans->{deposited_in}->{$lang};
				}
				
				my $source;
				if ($type->[9]) { 
					my @p = publication($type->[9], 0, 1, $dbc);
					my $pmaj;
					if ($type->[10]) { $pmaj = "$p[1]:&nbsp;$type->[10]" }
					else { $pmaj = $p[1] }
					$source = " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$type->[9]"}, $pmaj) . getPDF($type->[9]); 
				}
				
				$types .= Tr( td({-colspan=>2, -class=>'typesMagicCell magicCell', -style=>"display: $dmt;"}, 
							"$type->[3] $type->[4]$pluriel " . join(', ',@more) . " $trans->{of}->{$lang} " . i($type->[1]) . " $type->[2]" .
							" $lien " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=repository&id=$type->[7]"}, $type->[8]) . $source . " $type->[11]" ) );
				
				$sum += $type->[3] || 1;
			}
			
			if ($types) {	
				my $subtitle = "$sum " . ucfirst($trans->{'type(s)'}->{$lang});
				$types = makeRetractableArray ('typesTitle', 'typesMagicCell magicCell', $subtitle, $types, 'arrowRight', 'arrowDown', 1, $dmt, 'true');
				my $pos = $display_modes{types}{position} || $default_order{types};
				$orderedElements{$pos} = $types;
			}
		}

		#my $rmrk;
		#if (scalar(@remarks) and ($display_modes{remarks} or $mode eq 'full')) {
		#	$rmrk = Tr( td({-colspan=>2, -class=>'remarksMagicCell magicCell', -style=>"display: table-cell;"}, join('<br>', @remarks) ) );	
		#	$rmrk = makeRetractableArray ('remarksTitle', 'remarksMagicCell magicCell', $trans->{'remarks'}->{$lang}, $rmrk, 'arrowRight', 'arrowDown', 1, 'table-cell', 'true');
		#}
			
		# Make a link to JACIM
		# my $ua = LWP::UserAgent->new;
		# $ua->agent("MNHNspec");
		# 
		# my $specimens;		
		# if ($mode =~ m/s/) {
		# 				
		# 	my %done;
		# 	
		# 	foreach (keys(%names)) {
		# 		
		# 		my $link = "https://coldb.mnhn.fr/ScientificName/" . $names{$_}{'genus'} . '/' . $names{$_}{'species'};
		# 						
		# 		my $req = HTTP::Request->new(GET => $link);
		# 	
		# 		my $res = $ua->request($req);
		# 	
		# 		if ($res->is_success) {
		# 			unless ($done{$names{$_}{'genus'} . ' ' . $names{$_}{'species'}}) {					
		# 				$specimens .= 	a({-href=>$link, -target=>'_blank'}, $trans->{'mnhn_spec_of'}->{$lang} . ' ' . $names{$_}{'genus'} . ' ' . $names{$_}{'species'} ) . br;
		# 				
		# 				$done{$names{$_}{'genus'} . ' ' . $names{$_}{'species'}} = 1;
		# 			}
		# 		}
		# 	}
		# 	
		# 	unless ($specimens) { $specimens = $trans->{'no_mnhn_spec'}->{$lang}; }
		# 				
		# 	$specimens = div({-class=>'titre'}, ucfirst($trans->{'mnhn_spec'}->{$lang})) . $specimens . p;
		# }
		# 
		# unless ($dbase eq 'cipa' or $dbase eq 'strepsiptera' or $specimens) { 
		# 	my @params;
		# 	foreach (keys(%labels)) { if ($labels{$_}) { push(@params, $_) } }
		# 	my $args = join('&', map { "$_=$labels{$_}"} @params );
		# 	
		# 	$mode .= 's';
                # 
		# 	$specimens = div({-class=>'titre'}, ucfirst($trans->{'mnhn_spec'}->{$lang})) . a({-href=>"$scripts{$dbase}$args&mode=$mode"}, $trans->{'check_mnhn_spec'}->{$lang}) . p;
		# }
		
		my $cross;
		if ($dbase eq 'cipa') { 
			$cross = display_cross_tables($id, $dbc);
		}
		
		my $elements;
		foreach my $key (sort {$a <=> $b} keys(%orderedElements)) {
			$elements .= $orderedElements{$key};
		}
		
		my $stats;
		if ($dbase eq 'flow' and $rkorder < $genus_order) { 
				$stats = a({-href=>"$scripts{$dbase}db=$dbase&lang=en&card=autotext&id=$id&loading=1"}, img({-src=>"/explorerdocs/stats.png", -style=>'width: 28px; float: right;', title=>'Taxon synopsis'}) );
		}
		
		$fullhtml = 	# FAST
				#$jscript.
				div({-class=>'content'},
					div({-id=>'navigationDiv'},
							$bulleinfo,
							$navigation
					),
						div({-id=>'mainCardDiv'},
							div({-id=>'subjectDiv'},
								$stats,
								div({-class=>'titre'}, ucfirst($trans->{$rank}->{$lang})),
								div({-class=>'subject', -style=>'display: inline;'}, $formated_name ) . $tsp,
								$publication
							),
							div({-id=>'periDiv'},
								$elements,
								$cross,
								span({-id=>'testDiv', -style=>'color: grey;'}, $test)
							)
						)
					
				);
			
		if ($rank eq 'family' or $rank eq 'subfamily') {
					#$fullhtml = header . start_html() . $fullhtml . end_html();
		}
		
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Name card
#################################################################
sub name_card {
	if ( my $dbc = db_connection($config) ) {
		#TODO: BUG: if valid goes to species card but name may be of any rank, not only species
		my $name_id = $id;
		my $req = 	"SELECT nc.orthographe, 
					CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN
						nc.autorite
					ELSE 
						coalesce(nc.autorite, '') || coalesce(' (' || (SELECT orthographe FROM noms WHERE index = (SELECT ref_nom_parent FROM noms WHERE index = nc.index)) || ')', '')
					END, 
					nc.ref_publication_princeps, 
					n.page_princeps, 
					CASE WHEN (SELECT ordre FROM rangs WHERE index = nc.ref_rang) > (SELECT ordre FROM rangs WHERE en = 'genus') THEN 1 ELSE 0 END 
					FROM noms_complets AS nc 
					LEFT JOIN noms AS n ON n.index = nc.index 
					WHERE nc.index = $name_id;";
		
		my $name = request_row($req,$dbc);
		
		my $taxa = request_tab("SELECT txn.ref_taxon, 
						s.en, 
						txn.ref_publication_utilisant, 
						txn.ref_publication_denonciation, 
						txn.exactitude,
						txn.completude, 
						txn.exactitude_male, 
						txn.completude_male, 
						txn.exactitude_femelle, 
						txn.completude_femelle, 
						txn.sexes_decrits, 
						txn.sexes_valides, 
						txn.ref_nom_cible, 
						s.$lang, 
						r.en, 
						r2.en, 
						txn.page_denonciation, 
						txn.page_utilisant,
						nc.orthographe,
						nc.autorite,
						(select get_parent_by_name(nc.index, 'family', 'notfull')),
						nc2.orthographe,
						nc2.autorite,
						(select get_parent_by_name(nc2.index, 'family', 'notfull'))
					FROM taxons_x_noms AS txn 
					LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON r.index = t.ref_rang
					LEFT JOIN rangs AS r2 ON r2.index = (select ref_rang from noms_complets where index = txn.ref_nom)
					LEFT JOIN publications AS p1 ON p1.index = txn.ref_publication_utilisant
					LEFT JOIN publications AS p2 ON p2.index = txn.ref_publication_denonciation
					LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
					LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
					WHERE (txn.ref_nom = $name_id)
					AND s.en not in ('correct use', 'status revivisco')
					ORDER BY p1.annee, p2.annee;",$dbc);
		
		if (scalar(@{$taxa}) == 1 and $taxa->[0][1] eq 'valid') {
			$dbc->disconnect;
			$id = $taxa->[0][0];
			$rank = $taxa->[0][14];
			taxon_card();
		}
		else {
	
			#my $up;
			#if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
			# 	$up = 	$totop;
			#	$up .=  makeup('names', $trans->{'names'}->{$lang}, lc(substr($name->[0], 0, 1)));
			#}
	
			# Fetch princeps publication of the name
			my $ori_pub;
			if ( $name->[2] ) {
				$ori_pub = div({-class=>'titre'}, ucfirst($trans->{'ori_pub'}->{$lang})); 
				my $pub = pub_formating($name->[2], $dbc, $name->[3]);
				$ori_pub .= ul( li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$name->[2]"}, "$pub") . getPDF($name->[2])));
			}
			else {
				#$ori_pub = ul( li($trans->{"UNK"}->{$lang}));
			}
			
			my $taxa_tab;
			my @chresos;
			my %done;
			my $origin;
			foreach my $taxon ( @{$taxa} ){
				
				if ($taxon->[12] == $name_id) { $origin = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[18]) . " $taxon->[19]" )." "; }
				if ( $taxon->[1] eq 'synonym' or $taxon->[1] eq 'junior synonym'){
					
					my $ambiguous = synonymy( $taxon->[4], $taxon->[6], $taxon->[8] );
					my $complete = completeness( $taxon->[5], $taxon->[7], $taxon->[9] );
					
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'wrong spelling'){
					
					my @pub_use = publication($taxon->[2], 0, 1, $dbc );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					if ($pub_use[1]) { 
						if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
						$tt .= " $trans->{'dansin'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
						$tt .= getPDF($taxon->[2]);
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'previous identification'){
					
					my @pub_use = publication($taxon->[2], 0, 1, $dbc );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$trans->{'misid'}->{$lang} $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					if ($pub_use[1]) { 
						if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
						$tt .= " $trans->{'dansin'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
						$tt .= getPDF($taxon->[2]);
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'previous combination' or $taxon->[1] eq 'previous name'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					
					my $tt = $name->[4] ? "$taxon->[13] $trans->{'of'}->{$lang}" : $trans->{'prevtaxpos'}->{$lang};
					$tt .= " " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					if ($taxon->[21].$taxon->[22] eq $taxon->[18].$taxon->[19]) { $tt .= " ($taxon->[23])"; }
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'misidentification' ){
					
					my $test = request_tab("SELECT count(*) from taxons_x_noms WHERE ref_nom = $name_id and ref_statut = 18",$dbc);
					
					unless ($test->[0][0]) {
					
						my @pub_use = publication($taxon->[2], 0, 1, $dbc );
						my @pub_den = publication($taxon->[3], 0, 1, $dbc );
						my $tt = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, "$taxon->[13]" );
						if ($pub_use[1]) { 
							if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
							$tt .= " $trans->{'dansin'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
							$tt .= getPDF($taxon->[2]);
						}
						if ($pub_den[1]) { 
							if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
							$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] ); 
							$tt .= getPDF($taxon->[3]);
						}
						$taxa_tab .= li($origin.$tt);
					}
				}
				elsif ( $taxon->[1] eq 'valid' ){
					$taxa_tab = li(" $trans->{'valid'}->{$lang} $trans->{'of'}->{$lang} " .a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[15]&id=$taxon->[0]"}, i($name->[0]) . " $name->[1]")) . $taxa_tab;
				}
				elsif ( $taxon->[1] eq 'incorrect original spelling' or $taxon->[1] eq 'incorrect subsequent spelling' ){
					
					my @pub_use = publication($taxon->[2], 0, 1, $dbc );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					if ($pub_use[1]) { 
						if ($taxon->[17]) { $taxon->[17] = ": ".$taxon->[17]; }
						$tt .= " $trans->{'dansin'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[2]"}, "$pub_use[1]".$taxon->[17] ); 
						$tt .= getPDF($taxon->[2]);
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'emended'}->{$lang}&nbsp;$trans->{'BY'}->{$lang}&nbsp;" . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}
					$taxa_tab = li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'homonym' and !exists($done{$taxon->[12]}) ) {
					
					$done{$taxon->[12]} = 1;
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = "$taxon->[13] $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'nomen nudum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]); 
					if ($taxon->[22]) {
						$tt .= " $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					}
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'status revivisco' or $taxon->[1] eq 'combinatio revivisco'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt; 
					if ($taxon->[12] != $id) {
						$tt .= " $trans->{'fromto'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22] ". i($taxon->[1]) );
					}
					else { $tt .= " ". i($taxon->[1]); }
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'nomen praeoccupatum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]) . " $trans->{'fromto'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" ) . ' ' . i($trans->{'nnov'}->{$lang});
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= ", $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'nomen oblitum'){
					
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					my $tt = i($taxon->[13]) . ", $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" ) . ' ' . i($trans->{'nprotect'}->{$lang});
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= ", $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'outside taxon'){
					
					my $tt = $taxon->[13];
					$taxa_tab .= li($origin.$tt);
				}
				elsif ( $taxon->[1] eq 'dead end'){
					
					my $tt = $taxon->[13];
					if ($taxon->[22]) {
						$tt .= " $trans->{'relatedto'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					}
					$taxa_tab .= li($origin.$tt);
				}
				elsif (!exists($done{$taxon->[12]})) {
					my $tt = "$trans->{'other_name'}->{$lang} $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$taxon->[14]&id=$taxon->[0]"}, i($taxon->[21]) . " $taxon->[22]" );
					my @pub_den = publication($taxon->[3], 0, 1, $dbc );
					if ($pub_den[1]) { 
						if ($taxon->[16]) { $taxon->[16] = ": ".$taxon->[16]; }
						$tt .= " $trans->{'segun'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$taxon->[3]"}, "$pub_den[1]".$taxon->[16] );
						$tt .= getPDF($taxon->[3]);
					}	
					$taxa_tab .= li($origin.$tt);
				}
			}
			
			my $chr;
			if (scalar @chresos) {
				$chr = div({-class=>'titre'}, ucfirst($trans->{'Chresonym(s)'}->{$lang}));
				$chr .= start_ul({});
				foreach (@chresos) {
					$chr .= li($_);
				}
				$chr .= end_ul();
			}
	
			my ($cardtitle, $usage);
	
			$cardtitle = $trans->{'name'}->{$lang}; 
			$usage = div({-class=>'titre'}, ucfirst("$trans->{'statu(s)'}->{$lang}")) . ul( $taxa_tab);
			
			my $drvreq = "	SELECT nc.index, nc.orthographe, nc.autorite, nc.gen_type, r.en 
					FROM noms_complets AS nc
					LEFT JOIN rangs as r ON r.index = nc.ref_rang
					WHERE nc.index in (SELECT index FROM noms WHERE ref_nom_parent = $name_id) 
					ORDER BY orthographe;";
	
			my $derives = request_tab($drvreq,$dbc);
			
			my $drvnames;
			if (scalar @{$derives}) {
				$drvnames = div({-class=>'titre'}, ucfirst($trans->{'drvname(s)'}->{$lang}));
				$drvnames .= start_ul({});
				foreach ( @{$derives} ) {
					my $typestr;
					if ($_->[3]) { $typestr = span({-class=>'typeSpecies'}, "&nbsp;  ".$trans->{"type".$_->[4]}->{$lang}) }
					$drvnames .= li( a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$_->[0]"}, "$_->[1] $_->[2]") . $typestr);
				}
				$drvnames .= end_ul();
			}
						
			
			my $subject = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$id"}, i($name->[0]) . " $name->[1]");
			my $fields = "index, orthographe ||' '|| coalesce(autorite, '')";
			my $table = "noms_complets";
			my $where = "WHERE ref_rang = (SELECT ref_rang FROM noms_complets WHERE index = $id)";
			my $order = "(orthographe, autorite)";
			my $sid = $id;
			
			$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc);
			
			$fullhtml = 	div({-class=>'content'},
						div({-id=>'mainCardDiv'},	
							div({-class=>'titre'}, ucfirst($cardtitle) ),
							$subject,
							$ori_pub,
							$usage,
							$chr,
							$drvnames
						)
					);
					
			print $fullhtml;
				
			$dbc->disconnect;
		}
	}
	else {}
}

sub trans_navigation {
	
	my ($subject, $fields, $table, $where, $order, $sid, $dbc) = @_;
	
	## Make previous & next card navigation : #########################

	my ($current_id, $current_elmnt, $previous_id, $prev_elmnt, $next_id, $next_elmnt, $stop);
	
	my $first = request_tab("SELECT $fields FROM $table $where ORDER BY $order limit 1;", $dbc, 2);
	my $last = request_tab("SELECT $fields FROM $table $where ORDER BY $order DESC limit 1;", $dbc, 2);
	
	my ( $first_id, $first_elmnt ) = ( $first->[0][0], $first->[0][1] );
	my ( $last_id, $last_elmnt ) = ( $last->[0][0], $last->[0][1] );
		
	my $sth2 = $dbc->prepare( "SELECT $fields FROM $table $where ORDER BY $order;" );
	$sth2->execute( );
	$sth2->bind_columns( \( $current_id, $current_elmnt ) );
	while ( $sth2->fetch() ){
		if ( $stop ){ ( $next_id, $next_elmnt ) = ( $current_id, $current_elmnt ); last; }
		else {
			if ( $current_id == $sid ){ $stop = 1; }
			else { ( $previous_id, $prev_elmnt ) = ( $current_id, $current_elmnt ); }
		}
	}
	$sth2->finish();
	unless($previous_id) { ( $previous_id, $prev_elmnt ) = ( $last_id, $last_elmnt ); }
	unless($next_id) { ( $next_id, $next_elmnt ) = ( $first_id, $first_elmnt ); }
				
	$subject = 	div({-class=>'info', -id=>"prevElmnt", -style=>'position: absolute; display: none;'}, $prev_elmnt).
			div({-class=>'info', -id=>"nextElmnt", -style=>'position: absolute; display: none;'}, $next_elmnt).
			prev_next_card($card, undef, $previous_id, div({-class=>'subject'}, $subject), $next_id, "prevElmnt", "nextElmnt", "0 0 0 0px");
		
	###################################################################
}

sub makeup {
	
	my ($cible, $display, $letter) = @_;
	
	if ($letter) { $letter = "&alph=$letter" }
	
 	my $up = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$cible$letter"}, $display );

	return $up;
}

# Authors card
#################################################################
sub author_card {
	if ( my $dbc = db_connection($config) ) {
		my $author_id = $id;
		my $names = request_tab("SELECT nom, prenom FROM auteurs WHERE index = $author_id;",$dbc);
		my $ranks_ids = get_rank_ids( $dbc );

		my $subject = "$names->[0][0] $names->[0][1]";
		my $fields = "index, nom ||' '|| coalesce(prenom, '')";
		my $table = "auteurs";
		my $where = "";
		my $order = "(UPPER(desaccentue), UPPER(prenom))";
		my $sid = $id;
		
		$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc);
		
		# fetch species that author described
		my $sp_list = request_tab("SELECT t.index, nc.orthographe, nc.autorite, s.$lang, s.en, r.$lang, r.en
						FROM auteurs AS a 
						LEFT JOIN noms_x_auteurs AS nxa ON a.index = nxa.ref_auteur
						LEFT JOIN noms AS n ON nxa.ref_nom = n.index
						LEFT JOIN noms_complets AS nc ON nxa.ref_nom = nc.index
						LEFT JOIN taxons_x_noms AS txn ON n.index = txn.ref_nom
						LEFT JOIN taxons AS t ON txn.ref_taxon = t.index
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN rangs as r on n.ref_rang = r.index
						WHERE s.en not in ('correct use', 'dead end', 'wrong spelling', 'misidentification', 'previous identification', 'nomen praeoccupatum') 
						AND s.en = 'valid'
						AND a.index =  $author_id
						ORDER BY r.ordre, LOWER(nc.orthographe), s.en;",$dbc);

		my $sp_tab;
		my $tmp_tab;
		my $count = 0;
		my $current = $sp_list->[0][6];
		my $curlang = $sp_list->[0][5];
		
		if ( $sp_list->[0][0] ){
			my $size = scalar @{$sp_list};
			my $subtitle;
			#if ($size == 1 ) { $subtitle = $trans->{'taxon'}->{$lang}; }
			#else { $subtitle = $trans->{'taxons'}->{$lang}; }
						
			$sp_tab .= start_ul({-style=>'margin-bottom: 10px;'});
			foreach my $sp ( @{$sp_list} ){
				if ($current ne $sp->[6]) {
					unless ($current eq $sp_list->[0][6]) { $sp_tab .= br; }
					my $sbt = $trans->{$current."(s)"}->{$lang} || $curlang; 
					$sp_tab .= li(div({-class=>'titre'}, "$count $sbt"));
					$sp_tab .= $tmp_tab;

					$tmp_tab = '';
					$count = 0;
					$current = $sp->[6];
					$curlang = $sp->[5];	
				}
				$tmp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$sp->[6]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" ) );
				$count++;
			}
		        my $sbt = $trans->{$current."(s)"}->{$lang} || $curlang;
			if ($size != $count) { $sp_tab .= div({-class=>'titre'}, ''); }
		        $sp_tab .= li(div({-class=>'titre'}, "$count $sbt"));        
			$sp_tab .= $tmp_tab;
			
			#if ($size != $count) {
			#	if ($dbase eq 'psylles') { $sp_tab .= "$size $subtitle" . $sp_tab; }
			#	else { $sp_tab = div({-class=>'titre'}, "$size $subtitle") . $sp_tab; }
			#}
			
			$sp_tab .= end_ul();
		}


		# fetch publications done by the author
		my $pub_list = request_tab("SELECT DISTINCT axp.ref_publication, p.annee FROM auteurs AS a 
						INNER JOIN auteurs_x_publications AS axp ON a.index = axp.ref_auteur
						INNER JOIN publications AS p ON p.index = axp.ref_publication
						WHERE a.index = $author_id ORDER BY p.annee;",$dbc);
		
		my $pub_tab;
		my @pubids;
		if ( scalar @{$pub_list}){
			my $size = scalar @{$pub_list};
			$pub_tab .= div({-class=>'titre'}, "$size $trans->{'publi(s)'}->{$lang}");
			$pub_tab .= start_ul({});
			foreach my $pub_id ( @{$pub_list} ){
				my $pub = pub_formating($pub_id->[0], $dbc );
				$pub_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id->[0]"}, "$pub" ) . getPDF($pub_id->[0]) );
				push(@pubids, $pub_id->[0]);
			}
			$pub_tab .= end_ul() ;
		}
		
		# fetch names done by the author
		my $na_list = request_tab("SELECT n.index, nc.orthographe, nc.autorite, s.$lang, s.en, nc2.orthographe, nc2.autorite 
						FROM auteurs AS a 
						LEFT JOIN noms_x_auteurs AS nxa ON a.index = nxa.ref_auteur
						LEFT JOIN noms AS n ON nxa.ref_nom = n.index
						LEFT JOIN noms_complets AS nc ON nxa.ref_nom = nc.index
						LEFT JOIN taxons_x_noms AS txn ON n.index = txn.ref_nom
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc2 ON nc2.index = txn.ref_nom_cible
						WHERE s.en != 'valid' AND a.index =  $author_id
						GROUP BY n.index, nc.orthographe, nc.autorite, s.$lang, s.en, nc2.orthographe, nc2.autorite
						ORDER BY LOWER ( nc.orthographe );",$dbc);
						
		my $na_tab;
		if ( scalar @{$na_list} != 0){
			my $size = scalar @{$na_list};
			$na_tab .= div({-class=>'titre'}, "$size $trans->{'name(s)'}->{$lang}");
			$na_tab .= start_ul({});
			foreach my $na ( @{$na_list} ){
				$na_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$na->[0]"}, i("$na->[1]") . " $na->[2]") . " $na->[3]" );
			}
			$na_tab .= end_ul() ;
		}
		
		$fullhtml = 	div({-class=>'content'},
					div({-id=>'mainCardDiv'},	
						div({-class=>'titre'}, ucfirst($trans->{'author'}->{$lang})),
						$subject,
						$sp_tab,
						$na_tab,
						$pub_tab
					)
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Publication card
#################################################################
sub publication_card {
	if ( my $dbc = db_connection($config) ) {
		
		my $pub_id = $id;
		my @pub = publication( $pub_id, 1, 0, $dbc );
		
		my $req;
		my $sth;
		my $princeps;
				
		my $subject = $pub[1];
		my $fields = "index, abrege";
		my $table = "publications";
		my $where = "";
		my $order = "(abrege, titre)";
		my $sid = $id;
		
		$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc) . br;
		
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'publication';", $dbc, 'element')};

		my %orderedElements;
		unless ($display_modes{princeps}{skip}) {
						
			$req = "	SELECT t.index, nc.index, nc.orthographe, nc.autorite, nc2.index, nc2.orthographe, nc2.autorite, s.en, s.$lang, r.en
					FROM taxons AS t JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN rangs AS r ON r.index = nc.ref_rang
					WHERE s.index NOT IN (3,8,14,17,18,20,21,22)
					AND nc.ref_publication_princeps = $pub_id
					ORDER BY nc.orthographe;";
			
			# Fetch names that were first published in this publication
			my $prcps = request_tab($req,$dbc,2);
			
			my %attributes;
			my @attribs;
			my $nb_prcps = scalar(@{$prcps});
			@attribs = split('#', $display_modes{princeps}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmp = ( ( !$max or ( $max and $nb_prcps <= $max ) ) and $display_modes{princeps}{display} ) ? 'table-cell' : 'none';
			
			my %done;
			foreach my $name ( @{$prcps} ){
				my $validrank = $name->[9];
				if ( $name->[7] eq 'valid' ){ 
					$princeps .= Tr( td({-colspan=>2, -class=>'prcpsMagicCell magicCell', -style=>"display: $dmp;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$name->[0]"}, i($name->[2]) . " $name->[3]" ) ) );
				}
				elsif (!exists($done{$name->[1].'/'.$name->[4]})) {
					$done{$name->[1].'/'.$name->[4]} = 1;
					$princeps .= Tr( td({-colspan=>2, -class=>'prcpsMagicCell magicCell', -style=>"display: $dmp;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$name->[1]"}, i($name->[2]) . " $name->[3]" ) . 
							" $name->[8] $trans->{'of'}->{$lang} " .
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$name->[0]"}, i($name->[5]) . " $name->[6]" ) ) );
				}
			}
			if ( $princeps ){
				$princeps = makeRetractableArray ('prcpsTitle', 'prcpsMagicCell magicCell', ucfirst($trans->{'descr_prin'}->{$lang}), $princeps, 'arrowRight', 'arrowDown', 1, $dmp, 'true');
				my $pos = $display_modes{princeps}{position} || 1;
				$orderedElements{$pos} = $princeps;
			}
		}
		
		my ( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ordre, $oriFam, $tgtFam );
		
		my $synonyms;
		# Fetch synonymy denonciation made in this publication
		unless ($display_modes{synonyms}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_syns) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 2 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{synonyms}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dms = ( ( !$max or ( $max and $nb_syns <= $max ) ) and $display_modes{synonyms}{display} ) ? 'table-cell' : 'none';
			
			my $sth = $dbc->prepare( "SELECT txn.ref_nom, txn.ref_taxon, txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en
						FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
						LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
						WHERE txn.ref_publication_denonciation = $pub_id 
						AND s.en = 'synonym' 
						ORDER BY nc.orthographe;" );
			$sth->execute;
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank ) );
			
			while ( $sth->fetch ) {
	
				my $ambiguous = synonymy( $exactitude, $exactitude_male, $exactitude_femelle );
				my $complete = completeness( $completude, $completude_male, $completude_femelle );
				$synonyms .= Tr( td({-colspan=>2, -class=>'synsMagicCell magicCell', -style=>"display: $dms;"},
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
						" $trans->{'synonym'}->{$lang} $trans->{'of'}->{$lang} " .
						a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) ) );
			}
			$sth->finish(); # finalize the request
			if ( $synonyms ){
				$synonyms = makeRetractableArray ('synsTitle', 'synsMagicCell magicCell', ucfirst($trans->{'descr_syn'}->{$lang}), $synonyms, 'arrowRight', 'arrowDown', 1, $dms, 'true');
				my $pos = $display_modes{synonyms}{position} || 2;
				$orderedElements{$pos} = $synonyms;
			}
		}
		
		my $transfers;
		# Fetch transfer made in this publication
		unless ($display_modes{transfers}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_trans) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 4 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{transfers}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmt = ( ( !$max or ( $max and $nb_trans <= $max ) ) and $display_modes{transfers}{display} ) ? 'table-cell' : 'none';
						
			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, r.ordre, (select get_parent_by_name(nc.index, 'family', 'notfull')), (select get_parent_by_name(nc2.index, 'family', 'notfull'))
					FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
					WHERE txn.ref_publication_denonciation = $pub_id 
					AND s.en = 'previous combination' 
					ORDER BY nc.orthographe;";
			
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ordre, $oriFam, $tgtFam ) = ( undef, undef, undef, undef, undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ordre, $oriFam, $tgtFam ) );
			
			while ( $sth->fetch ) {			
				if ($orthographe.$autorite ne $tax_name.$tax_autorite) {
					$transfers .= Tr( td({-colspan=>2, -class=>'transMagicCell magicCell', -style=>"display: $dmt;"},
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) .
					" $trans->{'new_comb'}->{$lang} $trans->{'of'}->{$lang} " .
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) ) );
				}
				else {
					$transfers .= Tr( td({-colspan=>2, -class=>'transMagicCell magicCell', -style=>"display: $dmt;"},
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) .
					"&nbsp;$trans->{'transferfrom'}->{$lang}&nbsp;$oriFam&nbsp;$trans->{'tovers'}->{$lang}&nbsp;$tgtFam") );
				}
			}
			$sth->finish();
			
			if ( $transfers ){
				$transfers = makeRetractableArray ('transTitle', 'transMagicCell magicCell', ucfirst($trans->{'transfer(s)'}->{$lang}), $transfers, 'arrowRight', 'arrowDown', 1, $dmt, 'true');
				my $pos = $display_modes{transfers}{position} || 3;
				$orderedElements{$pos} = $transfers;
			}
		}
		
		my $newnames;
		# Fetch transfer made in this publication
		unless ($display_modes{newnames}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_trans) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 4 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{transfers}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmt = ( ( !$max or ( $max and $nb_trans <= $max ) ) and $display_modes{transfers}{display} ) ? 'table-cell' : 'none';
						
			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, r.ordre, (select get_parent_by_name(nc.index, 'family', 'notfull')), (select get_parent_by_name(nc2.index, 'family', 'notfull'))
					FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
					WHERE txn.ref_publication_denonciation = $pub_id 
					AND s.en = 'previous name' 
					ORDER BY nc.orthographe;";
			
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ordre, $oriFam, $tgtFam ) = ( undef, undef, undef, undef, undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ordre, $oriFam, $tgtFam ) );
			
			while ( $sth->fetch ) {			
				if ($orthographe.$autorite ne $tax_name.$tax_autorite) {
					$newnames .= Tr( td({-colspan=>2, -class=>'transMagicCell magicCell', -style=>"display: $dmt;"},
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) .
					" $trans->{'new_comb'}->{$lang} $trans->{'of'}->{$lang} " .
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) ) );
				}
				else {
					$newnames .= Tr( td({-colspan=>2, -class=>'transMagicCell magicCell', -style=>"display: $dmt;"},
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) .
					"&nbsp;$trans->{'transferfrom'}->{$lang}&nbsp;$oriFam&nbsp;$trans->{'tovers'}->{$lang}&nbsp;$tgtFam") );
				}
			}
			$sth->finish();
			
			if ( $newnames ){
				$newnames = makeRetractableArray ('transTitle', 'transMagicCell magicCell', ucfirst($trans->{'transfer(s)'}->{$lang}), $newnames, 'arrowRight', 'arrowDown', 1, $dmt, 'true');
				my $pos = $display_modes{newnames}{position} || 100;
				$orderedElements{$pos} = $newnames;
			}
		}
		
		my $neonyms;		
		# Fetch neonyms made in this publication
		unless ($display_modes{neonyms}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_neo) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 11 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{neonyms}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmn = ( ( !$max or ( $max and $nb_neo <= $max ) ) and $display_modes{neonyms}{display} ) ? 'table-cell' : 'table-cell';
			
			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en
										FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
										LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
										LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
										LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
										WHERE txn.ref_publication_denonciation = $pub_id 
										AND s.index = 11
										GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en
										ORDER BY nc.orthographe;";
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank ) = ( undef, undef, undef, undef, undef, undef, undef);
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank ) );
			
			while ( $sth->fetch ) {
							
				$neonyms .= Tr( td({-colspan=>2, -class=>'neoMagicCell magicCell', -style=>"display: $dmn;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
							" $trans->{'Nomen_praeoccupatum'}->{$lang} $trans->{'fromto'}->{$lang} " . 
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) 
						) );
			}
			$sth->finish();
				
			if ( $neonyms ){
				$neonyms = makeRetractableArray ('neoTitle', 'neoMagicCell magicCell', ucfirst($trans->{'Homonym(s)'}->{$lang}), $neonyms, 'arrowRight', 'arrowDown', 1, $dmn, 'true');
				my $pos = $display_modes{neonyms}{position} || 4;
				$orderedElements{$pos} = $neonyms;
			}
		}

		my $misidentifications;
		# Fetch misidentifications made in this publication
		unless ($display_modes{misidentifications}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_misid) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 17 AND ref_publication_utilisant = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{misidentifications}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmm = ( ( !$max or ( $max and $nb_misid <= $max ) ) and $display_modes{misidentifications}{display} ) ? 'table-cell' : 'none';
			
			my %mspdone;
			
			$sth = $dbc->prepare( "SELECT txn.ref_nom, txn.ref_taxon, txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle, txn.ref_publication_utilisant, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, txn.ref_publication_denonciation
						FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
						LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
						WHERE txn.ref_publication_utilisant = $pub_id 
						AND s.en IN ('misidentification', 'previous identification') 
						ORDER BY nc.orthographe, s.en DESC;" );
			$sth->execute;
			my ( $ref_publication_utilisant, $ref_publication_denoncant );
			( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ref_publication_denoncant ) = ( undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $ref_publication_utilisant, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ref_publication_denoncant ) );
			while ( $sth->fetch ) {
				unless (exists($mspdone{$ref_publication_utilisant .'|'. $ref_publication_denoncant})) {			
					my $ambiguous = synonymy( $exactitude, $exactitude_male, $exactitude_femelle );
					my $complete = completeness( $completude, $completude_male, $completude_femelle );
					my @pub_use = publication($ref_publication_utilisant, 0, 1, $dbc );
					my @pub_denons = publication($ref_publication_denoncant, 0, 1, $dbc );
					my $target = $tax_name ? " $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite") : undef;
					my $usage = scalar(@pub_use) ? i( " $trans->{'dansin'}->{$lang} " ) . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_publication_utilisant"}, "$pub_use[1]" ) . getPDF($ref_publication_utilisant) : undef;
					my $delation = scalar(@pub_denons) ? i( " $trans->{'segun'}->{$lang} " ) . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_publication_denoncant"}, "$pub_denons[1]" ) . getPDF($ref_publication_denoncant) : undef;
					$mspdone{$ref_publication_utilisant .'|'. $ref_publication_denoncant} = 1;
					$misidentifications .=  Tr( td({-colspan=>2, -class=>'misidMagicCell magicCell', -style=>"display: $dmm;"},
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
								" $trans->{'id_error'}->{$lang}" . $target . $usage . $delation ) );
				}
			}
			$sth->finish(); 
			
			if ( $misidentifications ){
				$misidentifications = makeRetractableArray ('misidTitle', 'misidMagicCell magicCell', ucfirst($trans->{'id_error'}->{$lang}), $misidentifications, 'arrowRight', 'arrowDown', 1, $dmm, 'true');
				my $pos = $display_modes{misidentifications}{position} || 5;
				$orderedElements{$pos} = $misidentifications;
			}
		}
		
		my $cormis;
		# Fetch corrections of misidentifications made in this publication
		unless ($display_modes{misidentifications}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_misid) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 18 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{misidentifications}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmm = ( ( !$max or ( $max and $nb_misid <= $max ) ) and $display_modes{misidentifications}{display} ) ? 'table-cell' : 'none';
			
			my %mspdone;
			
			$sth = $dbc->prepare( "SELECT txn.ref_nom, txn.ref_taxon, txn.exactitude, txn.completude, txn.exactitude_male, txn.completude_male, txn.exactitude_femelle, txn.completude_femelle, txn.ref_publication_utilisant, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, txn.ref_publication_denonciation
						FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
						LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
						LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
						WHERE txn.ref_publication_denonciation = $pub_id 
						AND s.en IN ('previous identification') 
						ORDER BY nc.orthographe, s.en DESC;" );
			$sth->execute;
			my ( $ref_publication_utilisant, $ref_publication_denoncant );
			( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ref_publication_denoncant ) = ( undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $exactitude, $completude, $exactitude_male, $completude_male, $exactitude_femelle, $completude_femelle, $ref_publication_utilisant, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $ref_publication_denoncant ) );
			while ( $sth->fetch ) {
				unless (exists($mspdone{$ref_publication_utilisant .'|'. $ref_publication_denoncant})) {			
					my $ambiguous = synonymy( $exactitude, $exactitude_male, $exactitude_femelle );
					my $complete = completeness( $completude, $completude_male, $completude_femelle );
					my @pub_use = publication($ref_publication_utilisant, 0, 1, $dbc );
					my @pub_denons = publication($ref_publication_denoncant, 0, 1, $dbc );
					my $target = $tax_name ? " $trans->{'of'}->{$lang} " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite") : undef;
					my $usage = scalar(@pub_use) ? i( " $trans->{'dansin'}->{$lang} " ) . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_publication_utilisant"}, "$pub_use[1]" ) . getPDF($ref_publication_utilisant) : undef;
					my $delation = scalar(@pub_denons) ? i( " $trans->{'segun'}->{$lang} " ) . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$ref_publication_denoncant"}, "$pub_denons[1]" ) . getPDF($ref_publication_denoncant) : undef;
					$mspdone{$ref_publication_utilisant .'|'. $ref_publication_denoncant} = 1;
					$cormis .=  Tr( td({-colspan=>2, -class=>'cormisidMagicCell magicCell', -style=>"display: $dmm;"},
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
								" $trans->{'id_error'}->{$lang}" . $target . $usage . $delation ) );
				}
			}
			$sth->finish(); 
			
			if ( $cormis ){
				$cormis = makeRetractableArray ('cormisidTitle', 'cormisidMagicCell magicCell', ucfirst($trans->{'descr_err'}->{$lang}), $cormis, 'arrowRight', 'arrowDown', 1, $dmm, 'true');
				my $pos = $display_modes{misidentifications}{position} || 5;
				$orderedElements{$pos} .= $cormis;
			}
		}
		
		my $emendations;		
		# Fetch emendations made in this publication
		unless ($display_modes{emendations}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_emend) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 15 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{emendations}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dme = ( ( !$max or ( $max and $nb_emend <= $max ) ) and $display_modes{emendations}{display} ) ? 'table-cell' : 'none';
			
			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en
										FROM taxons_x_noms AS txn LEFT JOIN statuts AS s ON txn.ref_statut = s.index
										LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
										LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
										LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
										WHERE txn.ref_publication_denonciation = $pub_id 
										AND s.en = 'incorrect original spelling'
										GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en
										ORDER BY nc.orthographe;";
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank ) = ( undef, undef, undef, undef, undef, undef, undef);
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank ) );
			
			while ( $sth->fetch ) {
							
				$emendations .= Tr( td({-colspan=>2, -class=>'emendMagicCell magicCell', -style=>"display: $dme;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
							" $trans->{'emended'}->{$lang} $trans->{'toen'}->{$lang} " . 
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) 
						) );
			}
			$sth->finish();
	
			if ( $emendations ){
				$emendations = makeRetractableArray ('emendTitle', 'emendMagicCell magicCell', ucfirst($trans->{'emendation(s)'}->{$lang}), $emendations, 'arrowRight', 'arrowDown', 1, $dme, 'true');
				my $pos = $display_modes{emendations}{position} || 6;
				$orderedElements{$pos} = $emendations;
			}
		}
		
		my $misspellings = '';
		my $misspellings_corrections = '';
		# Fetch wrong spelling made in this publication
		unless ($display_modes{misspellings}{skip} and $display_modes{misspellings_corrections}{skip}) {
			
			my %attributes;
			my @attribs;
			my ($nb_wsp) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 3 AND ref_publication_utilisant = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{misspellings}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmms = ( ( !$max or ( $max and $nb_wsp <= $max ) ) and $display_modes{misspellings}{display} ) ? 'table-cell' : 'none';
			
			my ($nb_wspc) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 3 AND ref_publication_denonciation = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{misspellings_corrections}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			$max = $attributes{max} || 0;
			my $dmmc = ( ( !$max or ( $max and $nb_wspc <= $max ) ) and $display_modes{misspellings_corrections}{display} ) ? 'table-cell' : 'none';

			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, s.$lang, txn.ref_publication_denonciation
					FROM taxons_x_noms AS txn 
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN noms_complets AS nc2 ON txn.ref_nom_cible = nc2.index
					LEFT JOIN rangs AS r ON r.index = nc2.ref_rang
					WHERE s.en = 'wrong spelling'
					AND (txn.ref_publication_denonciation = $pub_id OR txn.ref_publication_utilisant = $pub_id)
					GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, nc2.orthographe, nc2.autorite, r.en, s.$lang, txn.ref_publication_denonciation
					ORDER BY nc.orthographe;";
			
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			my $statut;
			my $pubden;
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $statut, $pubden ) = ( undef, undef, undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $tax_name, $tax_autorite, $validrank, $statut, $pubden ) );
			
			while ( $sth->fetch ) {
							
				if ($pubden == $pub_id) {
					$misspellings_corrections .= Tr( td({-colspan=>2, -class=>'miscorMagicCell magicCell', -style=>"display: $dmmc;"},
									a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
									" $statut $trans->{'of'}->{$lang} " .
									a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) ) );
				}
				else {
					$misspellings .= Tr( td({-colspan=>2, -class=>'misspMagicCell magicCell', -style=>"display: $dmms;"},
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) .
								" $statut $trans->{'of'}->{$lang} " .
								a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($tax_name) . " $tax_autorite" ) ) );
				}
			}
			$sth->finish();
			
			if ( $misspellings and !$display_modes{misspellings}{skip} ){
				$misspellings = makeRetractableArray ('misspTitle', 'misspMagicCell magicCell', ucfirst($statut), $misspellings, 'arrowRight', 'arrowDown', 1, $dmms, 'true');
				my $pos = $display_modes{misspellings}{position} || 7;
				$orderedElements{$pos} = $misspellings;
			}
			if ( $misspellings_corrections and !$display_modes{misspellings_corrections}{skip} ){
				$misspellings_corrections = makeRetractableArray ('miscorTitle', 'miscorMagicCell magicCell', ucfirst($trans->{'wrong_spelling_correction'}->{$lang}), $misspellings_corrections, 'arrowRight', 'arrowDown', 1, $dmmc, 'true');
				my $pos = $display_modes{misspellings_corrections}{position} || 8;
				$orderedElements{$pos} = $misspellings_corrections;
			}
		}
		
		my $chresonyms;
		# Fetch Chresonyms in this publication
		unless ($display_modes{chresonyms}{skip}) {
		
			my %attributes;
			my @attribs;
			my ($nb_chre) = @{request_tab("SELECT count(*) FROM taxons_x_noms WHERE ref_statut = 8 AND ref_publication_utilisant = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{chresonyms}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmc = ( ( !$max or ( $max and $nb_chre <= $max ) ) and $display_modes{chresonyms}{display} ) ? 'table-cell' : 'none';
			
			$req = "SELECT DISTINCT txn.ref_nom, nc.orthographe, nc.autorite, s.$lang
					FROM taxons_x_noms AS txn 
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					WHERE txn.ref_publication_utilisant = $pub_id
					AND s.en = 'correct use'
					ORDER BY nc.orthographe;";
			
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			my $statut;
			( $ref_nom, $orthographe, $autorite, $statut ) = ( undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $orthographe, $autorite, $statut ) );
			
			while ( $sth->fetch ) {			
				$chresonyms.= Tr( td({-colspan=>2, -class=>'chresoMagicCell magicCell', -style=>"display: $dmc;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$ref_nom"}, i($orthographe) . " $autorite" ) ) );
			}
			$sth->finish();
			
			if ( $chresonyms ){
				$chresonyms = makeRetractableArray ('chresoTitle', 'chresoMagicCell magicCell', ucfirst($statut), $chresonyms, 'arrowRight', 'arrowDown', 1, $dmc, 'true');
				my $pos = $display_modes{chresonyms}{position} || 9;
				$orderedElements{$pos} = $chresonyms;
			}
		}

		my $distribution;
		# Fetch distribution documented in this publication
		unless ($display_modes{distribution}{skip}) {
		
			my %attributes;
			my @attribs;
			my ($nb_dist) = @{request_tab("SELECT count(*) FROM taxons_x_pays WHERE ref_publication_ori = $pub_id;", $dbc, 1)};
			@attribs = split('#', $display_modes{distribution}{attributes});
			foreach (@attribs) {
				my ($key, $val) = split(':', $_);
				$attributes{$key} = $val;
			}
			my $max = $attributes{max} || 0;
			my $dmd = ( ( !$max or ( $max and $nb_dist <= $max ) ) and $display_modes{distribution}{display} ) ? 'table-cell' : 'none';
			
			$req = "SELECT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, r.en
					FROM taxons_x_noms AS txn 
					LEFT JOIN taxons_x_pays AS txp ON txp.ref_taxon = txn.ref_taxon
					LEFT JOIN statuts AS s ON txn.ref_statut = s.index
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					LEFT JOIN rangs AS r ON r.index = nc.ref_rang
					WHERE txp.ref_publication_ori = $pub_id
					AND txn.ref_statut = 1
					GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, r.en
					ORDER BY nc.orthographe;";
			
			$sth = $dbc->prepare($req) or die $req;
			$sth->execute or die $req;
	
			my $statut;
			( $ref_nom, $ref_taxon, $orthographe, $autorite, $validrank ) = ( undef, undef, undef, undef, undef );
			$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $validrank ) );
			
			while ( $sth->fetch ) {			
				$distribution .= Tr( td({-colspan=>2, -class=>'distribMagicCell magicCell', -style=>"display: $dmd;"},
							a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($orthographe) . " $autorite" ) ) );
			}
			$sth->finish();
			
			if ( $distribution ){
				$distribution = makeRetractableArray ('distribTitle', 'distribMagicCell magicCell', ucfirst($trans->{'geodistribution'}->{$lang}), $distribution, 'arrowRight', 'arrowDown', 1, $dmd, 'true');
				my $pos = $display_modes{distribution}{position} || 10;
				$orderedElements{$pos} = $distribution;
			}
		}
		
		my $host_plants;
		# Fetch host plants documented in this publication
		#unless ($display_modes{hostplants}{skip}) {
		#
		#	my %attributes;
		#	my @attribs;
		#	my ($nb_hp) = @{request_tab("SELECT count(*) FROM taxons_x_plantes WHERE ref_publication_ori = $pub_id;", $dbc, 1)};
		#	@attribs = split('#', $display_modes{hostplants}{attributes});
		#	foreach (@attribs) {
		#		my ($key, $val) = split(':', $_);
		#		$attributes{$key} = $val;
		#	}
		#	my $max = $attributes{max} || 0;
		#	my $dmhp = ( ( !$max or ( $max and $nb_hp <= $max ) ) and $display_modes{hostplants}{display} ) ? 'table-cell' : 'none';
		#	
		#	$req = "SELECT DISTINCT txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, r.en
		#			FROM taxons_x_noms AS txn 
		#			LEFT JOIN taxons_x_plantes AS txp ON txp.ref_taxon = txn.ref_taxon
		#			LEFT JOIN statuts AS s ON txn.ref_statut = s.index
		#			LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
		#			LEFT JOIN rangs AS r ON r.index = nc.ref_rang
		#			WHERE txp.ref_publication_ori = $pub_id
		#			AND txn.ref_statut = 1
		#			GROUP BY txn.ref_nom, txn.ref_taxon, nc.orthographe, nc.autorite, r.en
		#			ORDER BY nc.orthographe;";
		#						
		#	$sth = $dbc->prepare($req) or die $req;
		#	$sth->execute or die $req;
	    #
		#	my $statut;
		#	( $ref_nom, $ref_taxon, $orthographe, $autorite, $validrank ) = ( undef, undef, undef, undef, undef );
		#	$sth->bind_columns( \( $ref_nom, $ref_taxon, $orthographe, $autorite, $validrank ) );
		#	
		#	while ( $sth->fetch ) {			
		#		$host_plants .= Tr( td({-colspan=>2, -class=>'plantsMagicCell magicCell', -style=>"display: $dmhp;"},
		#					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$validrank&id=$ref_taxon"}, i($orthographe) . " $autorite" ) ) );
		#	}
		#	$sth->finish();
		#	
		#	if ( $host_plants ){
		#		$host_plants = makeRetractableArray ('plantsTitle', 'plantsMagicCell magicCell', ucfirst($trans->{'hostplant(s)'}->{$lang}), $host_plants, 'arrowRight', 'arrowDown', 1, $dmhp, 'true');
		#		my $pos = $display_modes{hostplants}{position} || 11;
		#		$orderedElements{$pos} = $host_plants;
		#	}
		#}
		
		my $pub = pub_formating($pub_id, $dbc) . getPDF($pub_id);
		
		my $elements;
		foreach my $key (sort {$a <=> $b} keys(%orderedElements)) {
			$elements .= $orderedElements{$key};
		}
		
		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'publication'}->{$lang})),
					$subject,
					span({-class=>'subject'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id"}, $pub ) ),
					$elements
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

sub publist {
	my $list = url_param('list');
	my $dbc = db_connection($config);
	my $display;
	my @pubs = split(',',$list);
	foreach (@pubs) {
		$display .= pub_formating($_, $dbc)."<br>";
	}
	print $display;
}

sub get_last_updates {
		my $dbc = db_connection($config);
		my $req = "SELECT 	extract(year from max(date_modification)),
					extract(month from max(date_modification)),
					extract(day from max(date_modification))  
					FROM 	((SELECT date_modification FROM taxons_x_noms) 
						UNION (SELECT date_modification FROM taxons_x_pays) 
						UNION (SELECT date_modification FROM taxons_x_images) 
						UNION (SELECT date_modification FROM taxons_x_periodes) 
						UNION (SELECT date_modification FROM taxons_x_taxons_associes) 
						UNION (SELECT date_modification FROM noms_x_types) 
						UNION (SELECT date_modification FROM noms_x_images)) AS binded;";
		
		my ($y, $m, $d) = @{request_tab($req, $dbc, 2)->[0]};
				
		my ($ly, $lm, $ld) = ($y, $m-1, $d);
		if ($m == 1) { $lm = 12; $ly -= 1; }
		if ($d > 28) { $ld = 28; }
		
		my $orderBy;
		if ($mode eq 'family') { $orderBy = "7, 4"; } else { $orderBy = "3 DESC, 4"; }
			
		
		my $req = "SELECT 	DISTINCT txn.ref_taxon, bd.ref_nom, bd.date_modification, nc.orthographe, nc.autorite, r.en, t.family
					FROM 	(
						(SELECT ref_nom, date_modification FROM taxons_x_noms WHERE ref_statut != 20) 
						UNION (SELECT ref_nom, date_modification FROM taxons_x_pays) 
						UNION (SELECT ref_nom, date_modification FROM taxons_x_images) 
						UNION (SELECT ref_nom, date_modification FROM taxons_x_periodes) 
						UNION (SELECT ref_nom, date_modification FROM taxons_x_taxons_associes) 
						UNION (SELECT ref_nom, date_modification FROM noms_x_types) 
						UNION (SELECT ref_nom, date_modification FROM noms_x_images)
						UNION (SELECT index AS ref_nom, date_modification FROM noms)
					) AS bd
					LEFT JOIN taxons_x_noms AS txn ON (txn.ref_nom = bd.ref_nom)
					LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
					LEFT JOIN rangs AS r ON r.index = t.ref_rang
					LEFT JOIN noms_complets AS nc ON nc.index = bd.ref_nom
					WHERE bd.date_modification >= '$ly-$lm-$ld' and bd.date_modification <= '$y-$m-$d'
					ORDER BY $orderBy
					LIMIT 1000;";
		
		my $noms = request_tab($req, $dbc, 2);
		
		my %list;		
		
		if ($mode eq 'family') {
			my $pos = 1;
			foreach (@{$noms}) {
				$_->[6] = $_->[6] ? $_->[6] . ' - ' : '';
				$list{$_->[3].$_->[4].$_->[2]}{position} = $pos;
				$list{$_->[3].$_->[4].$_->[2]}{display}  = $_->[6] . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=".$_->[5]."&id=".$_->[0]}, i($_->[3]) . ' ' . $_->[4]) . ' - ' . $_->[2] . '<br>';
				$pos++;
			}
		}
		else {
			my $pos = 1;
			foreach (@{$noms}) {
				$_->[6] = $_->[6] ? ' (' . $_->[6] . ')' : '';
				$list{$_->[2].$_->[3].$_->[4]}{position} = $pos;
				$list{$_->[2].$_->[3].$_->[4]}{display}  = $_->[2] . ' - ' . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=".$_->[5]."&id=".$_->[0]}, i($_->[3]) . ' ' . $_->[4]) . $_->[6] . '<br>';
				$pos++;
			}
		}
		
		my $display;
		foreach my $x (sort {$list{$a}{position} <=> $list{$b}{position}} keys(%list)) {
			$display .= $list{$x}{display};
		}
		
		$fullhtml =  	div({-class=>'content'}, 
					div({-class=>'titre'}, ucfirst($trans->{'lastUpdates'}->{$lang})),
					$trans->{'LastModif'}->{$lang}. p .
					$trans->{'sortedby'}->{$lang} . ": " . 	
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=updates"}, $trans->{'date'}->{$lang}) . ' - ' . 
					a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=updates&mode=family"}, lcfirst($trans->{'family'}->{$lang})) . '<br><br>' . 
					$display
				);
		
		print $fullhtml;
}


# Plant card
#################################################################
sub plant_card {
	if ( my $dbc = db_connection($config) ) {
		
		my (%list, $req, $taxon_name, $taxon_parent, $taxon_rank);
		
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'plant';", $dbc, 'element')};

		my $fully_display = 0;
		if($display_modes{associations}{display} or $mode eq 'full') { $fully_display = 1; }
				
		my ($nom, $autorite, $parent, $rang, $vparent);
		my $parent = $id;
		my (@highers, $navigation, $bulleinfo);
		while ($parent) {			
			$req = "SELECT (get_host_plant(p.index)).nom, (get_host_plant(p.index)).autorite, p.ref_parent, r.en, v.ref_valide
				FROM plantes AS p 
				LEFT JOIN plantes AS v ON v.index = p.ref_parent 
				LEFT JOIN rangs AS r ON r.index = p.ref_rang 
				WHERE p.index = $parent;";
				
			my $xid = $parent;
			
			($nom, $autorite, $parent, $rang, $vparent) = @{(request_tab($req, $dbc, 2))->[0]};
			
			$parent = $vparent ? $vparent : $parent;
									
			if ($rang eq 'order') { 
				$req = "SELECT p.index, (get_host_plant(p.index)).nom, (get_host_plant(p.index)).autorite
					FROM plantes AS p 
					LEFT JOIN rangs AS r ON r.index = p.ref_rang 
					WHERE r.en = 'order'
					ORDER BY (get_host_plant(p.index)).nom;";

				$parent = undef; 
			}
			else { 
				$req = "SELECT p.index, (get_host_plant(p.index)).nom, (get_host_plant(p.index)).autorite
					FROM plantes AS p 
					WHERE p.ref_parent = $parent
					ORDER BY (get_host_plant(p.index)).nom;";
				
			}						
			
			my $taxa = request_tab($req, $dbc, 2);
			
			if (scalar(@{$taxa}) > 1) {
				my ( $previd, $prevname, $nextid, $nextname, $found);			
				foreach my $taxon (@{$taxa}) {
					my ( $currid, $currname ) = ( $taxon->[0], i($taxon->[1])." ".$taxon->[2] );
					
					if ($found == 1) { ( $nextid, $nextname ) = ( $currid, $currname); last; }
					else {
						if ( $currid == $xid ) { $found = 1; }
						else { ( $previd, $prevname ) = ( $currid, $currname ); }
					}
				}
				unless($previd) { ( $previd, $prevname ) = ( $taxa->[$#{$taxa}][0], i($taxa->[$#{$taxa}][1])." ".$taxa->[$#{$taxa}][2] ); }
				unless($nextid) { ( $nextid, $nextname ) = ( $taxa->[0][0], i($taxa->[0][1])." ".$taxa->[0][2] ); }
				
				my $label;
				unless ($taxon_name) { 
					unshift(@highers, prev_next_card('plant', undef, $previd, div({-class=>'hierarch'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$xid"}, i($nom) . " " . $autorite)), $nextid, "prev$rang", "next$rang", 0));
				}
				else {
					if (1 or $fully_display) {
						unshift(@highers, prev_next_card('plant', undef, $previd, div({-class=>'hierarch'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$xid"}, i($nom) . " " . $autorite)), $nextid, "prev$rang", "next$rang", 0));
					}
					else {
						unshift(@highers, div({-class=>'hierarch'}, i($nom) . " " . $autorite));
					}
				}
				
				$bulleinfo .= 	div({-class=>'info', -id=>"prev$rang", -style=>'position: absolute; display: none;'}, $prevname).
						div({-class=>'info', -id=>"next$rang", -style=>'position: absolute; display: none;'}, $nextname);
			}
			else {
				my $label;
				if (1 or $fully_display) { $label = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=$xid"}, i($nom) . " " . $autorite); }
				else { $label = i($nom) . " " . $autorite; }
				
				unshift(@highers, table( 
							Tr(
								td({-style=>'vertical-align: middle; border: 0px solid black; padding-right: 6px;'}, 
									div({-class=>'marker', -style=>'width: 10px, height: 16px; border: 0px solid black;'}, '')),
								td({-style=>'vertical-align: middle; border: 0px solid black;'}, div({-class=>'hierarch'}, $label)
						))));
			}
		
			unless ($taxon_name) { $taxon_name = i($nom) . " " . $autorite; $taxon_parent = $parent; $taxon_rank = $rang; }
		}
		
		$bulleinfo = div({-style=>'border: 0px solid black;'}, $bulleinfo);
		
		my $indent = 0;
		my $marge = 20;
		foreach (@highers) {
			$navigation .= div({-style=>'margin-left:'.($indent*$marge).'px;'}, $_);
			$indent++;
		}

		my $display;
		my $total;
		my @sons = ($id);
		my %notempty;
		$indent = 1;
		while (scalar(@sons)) {
			$req = "SELECT DISTINCT p.index, (get_host_plant(p.index)).nom, (get_host_plant(p.index)).autorite, r.en, p.ref_parent
				FROM plantes AS p 
				LEFT JOIN rangs AS r ON r.index = p.ref_rang 
				WHERE (p.ref_parent in (" . join(',', @sons) . ")
				OR p.ref_parent IN (SELECT DISTINCT ref_valide FROM plantes WHERE index IN (" . join(',', @sons) . "))
				OR p.ref_parent IN (SELECT DISTINCT index FROM plantes WHERE ref_valide IN (" . join(',', @sons) . ")))
				AND p.ref_valide IS NULL
				ORDER BY (get_host_plant(p.index)).nom, (get_host_plant(p.index)).autorite;";
						
			my $childs = request_tab($req, $dbc, 2);
			
			@sons = ();
			if (scalar(@{$childs})) {
				foreach my $child (@{$childs}) {
								
					if (exists($list{$child->[4]})) { $list{$child->[0]}{hierark} = $list{$child->[4]}{hierark} . $child->[1]; }
					else { $list{$child->[0]}{hierark} = $child->[1]; }
					$list{$child->[0]}{parent} = $child->[4];
					$list{$child->[0]}{rank} = $child->[3];
					$list{$child->[0]}{margin} = $indent;
					$list{$child->[0]}{label} = a({-class=>'links2', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=".$child->[0]}, i($child->[1]) . " " . $child->[2]);
					
					if($fully_display) {

						$req = "SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
							FROM taxons_x_plantes AS txp
							LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
							LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
							LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
							LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
							LEFT JOIN rangs AS r ON r.index = nc.ref_rang
							WHERE txn.ref_statut = 1
							AND txnf.ref_statut = 1
							AND (txp.ref_plante = $child->[0] OR txp.ref_plante IN (SELECT index FROM plantes WHERE ref_valide = $child->[0]))
							ORDER BY nc.orthographe, nc.autorite";
												
						my $species = request_tab($req, $dbc, 2);
						
						my $nb = scalar(@{$species});
						if ($nb) {
							if ($child->[3] eq 'genus') {
								$list{$child->[0]}{label2} = a({-class=>'links2', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=".$child->[0]}, i($child->[1]) . " " . $child->[2] . " spp.");
							}
							elsif ($child->[3] ne 'species') {
								$list{$child->[0]}{label2} = a({-class=>'links2', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=".$child->[0]}, i($child->[1]) . " " . $child->[2]);
							}
							$total += $nb;
							$list{$child->[0]}{nbtaxa} = $nb;
							foreach my $sp (@{$species}) {
								my $fam = $sp->[4] ? i($sp->[4])." ".$sp->[5] : undef;
								$fam = undef;
								push(@{$list{$child->[0]}{taxa}}, {'family' => $fam, 'label' => "$sp->[1] $sp->[2]", 'display' => '- '.a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]")." ".$sp->[2])." ($sp->[4])"});
							}
							$notempty{$child->[0]} = 1;
							$notempty{$child->[4]} = 1;
						}
					}
					
					unshift(@sons, $child->[0]);
				}
				$indent++;
			}
		}
				
		if(1 or $fully_display) {
			
			$req = "SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
				FROM taxons_x_plantes AS txp
				LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
				LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
				LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
				LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
				LEFT JOIN rangs AS r ON r.index = nc.ref_rang
				WHERE txn.ref_statut = 1
				AND txnf.ref_statut = 1
				AND (txp.ref_plante = $id OR txp.ref_plante IN (SELECT index FROM plantes WHERE ref_valide = $id))
				ORDER BY nf.orthographe, nf.autorite, nc.orthographe, nc.autorite";
									
			my $species = request_tab($req, $dbc, 2);
			
			if ($total or scalar @{$species}) {
				my $sum = $total + scalar(@{$species});
				if ($sum > 1) { 
					$display .= div({-class=>'titre'}, $sum . " " . ucfirst($trans->{'associated_taxa'}->{$lang}) );
				}
				else { 
					$display .= div({-class=>'titre'}, $sum . " " . ucfirst($trans->{'associated_taxon'}->{$lang}) );
				}
				
				my $label;
				my $nb = scalar(@{$species});
				if($nb) {
					if ($taxon_rank eq 'genus') {
						$label = a({-class=>'links2', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=".$id}, $taxon_name . " spp.");
					}
					elsif ($taxon_rank ne 'species') {
						$label = a({-class=>'links2', -href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=plant&id=".$id}, $taxon_name);
					}

					if ($label) {
						if ($nb > 1) { 
							$display .= div({-style=>"margin-left: $marge"."px;"}, $nb . " " . ucfirst($trans->{'associated_taxa'}->{$lang}) . " $trans->{assoc_with}->{$lang} " . $label );
						}
						else { 
							$display .= div({-style=>"margin-left: $marge"."px;"}, $nb . " " . ucfirst($trans->{'associated_taxon'}->{$lang}) . " $trans->{assoc_with}->{$lang} " . $label );
						}
						my $current;
						foreach my $sp (@{$species}) {
							my $family = i($sp->[4])." ".$sp->[5];
							if (!$current or $current ne $family) {
								if ($current) { $display .= div(' '); }
								$current = $family;
								$display .= div({-style=>"margin-left: ".($marge*2)."px;"}, $current);
							}
							$display .= div({-style=>"margin-left: ".($marge*3)."px;"}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]")." ".$sp->[2]));
						}
					}
					else {
						my $current;
						foreach my $sp (@{$species}) {
							my $family = i($sp->[4])." ".$sp->[5];
							if (!$current or $current ne $family) {
								if ($current) { $display .= div(' '); }
								$current = $family;
								$display .= div({-style=>""}, $current);
							}
							$display .= div({-style=>"margin-left: $marge"."px;"}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]")." ".$sp->[2]));
						}
					}
					$display .= div({-class=>"titre"}, '');
				}
			}
		}
		
		my $start;
		my $preindent = 0;
		foreach my $key (sort {$list{$a}{hierark} cmp $list{$b}{hierark}} keys(%list)) {
			
			if ($list{$key}{rank} ne 'species') { 
				unless ( $list{$key}{rank} eq 'genus' and !exists($notempty{$key}) ) {
					if ( $list{$key}{margin} < $preindent ) { 
						$display .= div({-class=>'titre', -style=>"font-size: 1em; margin-left: ".($list{$key}{margin}*$marge)."px;"}, $list{$key}{label} );
					}
					else {
						$display .= div({-class=>'cellAsLi', -style=>"margin-left: ".($list{$key}{margin}*$marge)."px;"}, $list{$key}{label} );
					}
					$preindent = $list{$key}{margin};
				}
			}
			elsif ( $list{$key}{rank} eq 'species' and !$fully_display ) {
				$display .= div({-style=>"margin-left: ".($list{$key}{margin}*$marge)."px;"}, $list{$key}{label} );
				$preindent = $list{$key}{margin};
			}
			
			if (exists $list{$key}{nbtaxa}) {
				my $sum = $list{$key}{nbtaxa};
				
				my ($label, $xmargin, $tmargin);
				if ($list{$key}{label2}) {
					$label = $list{$key}{label2};
					$xmargin = (($list{$key}{margin}+1)*$marge);
					$tmargin = (($list{$key}{margin}+2)*$marge);
				}
				else {
					$label = $list{$key}{label};
					$xmargin = ($list{$key}{margin}*$marge);
					$tmargin = (($list{$key}{margin}-1)*$marge);
				}				
				
				if ($sum > 1) { 
					$display .= div({-style=>"margin-left: $xmargin"."px;"}, $sum . " " . ucfirst($trans->{'associated_taxa'}->{$lang}) . " $trans->{assoc_with}->{$lang} " . $label );
				}
				else { 
					$display .= div({-style=>"margin-left: $xmargin"."px;"}, $sum . " " . ucfirst($trans->{'associated_taxon'}->{$lang}) . " $trans->{assoc_with}->{$lang} " . $label );
				}
				my $current;
				foreach my $xtaxon (sort {$a->{family} cmp $b->{family} || $a->{label} cmp $b->{label}} @{$list{$key}{taxa}}) {
					if (!$current or $current ne $xtaxon->{family}) {
						if ($current) { $display .= div(' '); }
						$current = $xtaxon->{family};
						$display .= div({-style=>"margin-left: $tmargin"."px;"}, $current);
					}
					$display .= div({-style=>"margin-left: ".($tmargin+$marge)."px;"}, $xtaxon->{'display'});
				}
				$display .= div({-class=>"titre"}, '');
			}
		}
		
		$fullhtml = div({-class=>'content'},
						div({-id=>'navigationDiv'},
								$bulleinfo,
								$navigation
						),
						div({-id=>'mainCardDiv'},	
							div({-class=>'titre'}, ucfirst($trans->{'plant'}->{$lang})),
							div({-class=>'subject'}, $taxon_name), 
							div({-class=>'titre'}, ''),
							$display
						)
					);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Associated taxon
#################################################################
sub association {
	
	my ($type) = @_;
	
	if ( my $dbc = db_connection($config) ) {
		my $taxon_id = $id;
		
		my (@ids, $pid, @eids);
		$pid = $taxon_id;
		push(@ids, $pid);
		while ($pid) {
			($pid) = @{request_row("SELECT ta.ref_parent FROM taxons_associes AS ta WHERE ta.index = $pid;",$dbc)};
			if ($pid) { push(@ids, $pid); }
		}
		@eids = ($taxon_id);
		while (scalar @eids) {
			@eids = @{request_tab("SELECT ta.index FROM taxons_associes AS ta WHERE ta.ref_parent IN (".join(',', @eids).");",$dbc,1)};
			if (scalar @eids) { push(@ids, @eids); }
		}
		
		my $taxon = request_row("SELECT ta.index, (get_taxon_associe(ta.index)).*
						FROM taxons_associes AS ta 
						WHERE ta.index = $taxon_id;",$dbc);
				

		my $sp_list = request_tab("SELECT distinct t.index, n.orthographe, n.autorite, t.ref_taxon_parent, r.en, LOWER ( n.orthographe ), ty.$lang
				FROM taxons AS t
				LEFT JOIN taxons_x_taxons_associes AS txt ON t.index = txt.ref_taxon
				LEFT JOIN types_association AS ty ON ty.index = txt.ref_type_association
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' 
				AND txt.ref_taxon_associe IN (".join(',', @ids).")
				ORDER BY LOWER ( n.orthographe );",$dbc);

		my $tab;
		if ( scalar @{$sp_list} != 0){
			my $size = scalar @{$sp_list};
			$tab = div({-class=>'titre'}, "$size $trans->{'species(s)'}->{$lang}");
			$tab .= start_ul({});
			foreach my $sp ( @{$sp_list} ){
				my $parent_name = [];
				$parent_name = request_row( "SELECT family from taxons where index = $sp->[3];", $dbc );
				
				$tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[4]&id=$sp->[0]"}, i("$sp->[1]"), " $sp->[2]") . "&nbsp; ($parent_name->[0])" );
			}
			$tab .= end_ul();
		}

		my $associate = i($taxon->[1]);
		if ($taxon->[2]) { $associate .= " $taxon->[2]" }
		my $higher;
		if ($taxon->[4]) { $higher .= "$taxon->[4]" }
		if ($taxon->[3]) { $higher .= $higher ? ", $taxon->[3]" : "$taxon->[3]" }
		$higher = $higher ? " ($higher)" : undef;

		$fullhtml = div({-class=>'content'},	
					div({-class=>'titre'}, ucfirst($sp_list->[0][6])),
					span({-class=>'subject'}, $associate). $higher,
					$tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}


# Country card
#################################################################
sub country_card {
	
	if ( my $dbc = db_connection($config) ) {
				
		my ($country_id, $taxnameid) = split('XX', $id);
		my ($country, $tdwg, $tdwg_level, $countrySQL, $parent);
		my $de_tab;
		
		my ($families) = @{request_row("SELECT count(*) FROM taxons WHERE ref_rang = 2;", $dbc)};
		($country, $tdwg, $tdwg_level, $parent) = @{request_row("SELECT $lang, tdwg, tdwg_level, parent FROM pays WHERE index = $country_id;", $dbc)};
				
		$countrySQL = $country;
		$countrySQL =~ s/'/''/;
				
		my %xtaxa;	
		my ($taxname, $taxauthor, $croise, $precise, $getall);
		
		if ($taxnameid) { 
			($taxname, $taxauthor) = @{request_row("SELECT orthographe, autorite FROM noms_complets WHERE index = $taxnameid;",$dbc)};
			$croise = "AND n.orthographe like '$taxname %'";
			$precise = "$trans->{'dansin'}->{$lang} $taxname $taxauthor";
			$getall = span('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$country_id"}, $trans->{'getAllSpeciesFrom'}->{$lang}));
		}
		
		my %desc;
		my $size = 0;
		my $order = 1;
		# Fetch taxa present in the parents of the TDWG area
		my $supraregions = request_tab("SELECT index, $lang, tdwg, tdwg_level FROM pays WHERE tdwg ILIKE '%$tdwg%' AND tdwg ILIKE '%,%' AND index != $country_id;", $dbc, 2);
		foreach my $supraregions (@{$supraregions}) {
			my $taxa = request_tab("SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
						FROM taxons_x_pays AS txp
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txp.ref_taxon 
						LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
						LEFT JOIN taxons AS t ON t.index = txn.ref_taxon 
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom 							
						LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
						LEFT JOIN rangs AS r ON r.index = t.ref_rang 							
						WHERE txp.ref_pays = $supraregions->[0] 
						AND txnf.ref_statut = 1
						AND txn.ref_statut = 1;", $dbc, 2);
			if (scalar(@{$taxa})) {
				unless(exists $desc{$supraregions->[0]}) {
					$desc{$supraregions->[0]}{order} = $order; $order++;
					$desc{$supraregions->[0]}{label} = $supraregions->[1];
					$desc{$supraregions->[0]}{tdwg} = $supraregions->[2];
					$desc{$supraregions->[0]}{level} = $supraregions->[3];
					$size += scalar @{$taxa};
					foreach my $xtaxon (@{$taxa}) {
						my $fam;
						if ($families > 1) { $fam = $xtaxon->[4] ? i($xtaxon->[4])." ".$xtaxon->[5] : undef; }
						push(@{$desc{$supraregions->[0]}{taxa}}, {'family' => $fam, 'label' => i($xtaxon->[1]) . " " . $xtaxon->[2], 'display' => a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2]) } );
						unless (exists $xtaxa{$xtaxon->[1].$xtaxon->[2]}) {
							$xtaxa{$xtaxon->[1].$xtaxon->[2]}{label} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2] );
							$xtaxa{$xtaxon->[1].$xtaxon->[2]}{family} = $fam;
						}
					}
				}
			}
		}

		my @highers = ($parent);
		while ($parent) {
			my ($index, $trad, $code, $level);
			($index, $trad, $code, $level, $parent) = @{request_row("SELECT index, $lang, tdwg, tdwg_level, parent FROM pays WHERE tdwg ILIKE '$parent';", $dbc)};
			
			my $taxa = request_tab("SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
						FROM taxons_x_pays AS txp
						LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txp.ref_taxon 
						LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
						LEFT JOIN taxons AS t ON t.index = txn.ref_taxon 
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom 							
						LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
						LEFT JOIN rangs AS r ON r.index = t.ref_rang 							
						WHERE txp.ref_pays = $index 
						AND txnf.ref_statut = 1
						AND txn.ref_statut = 1;", $dbc, 2);
			if (scalar(@{$taxa})) {
				unless(exists $desc{$index}) {
					$desc{$index}{order} = $order; $order++;
					$desc{$index}{label} = $trad;
					$desc{$index}{tdwg} = $code;
					$desc{$index}{level} = $level;
					$size += scalar @{$taxa};
					foreach my $xtaxon (@{$taxa}) {
						my $fam;
						if ($families > 1) { $fam = $xtaxon->[4] ? i($xtaxon->[4])." ".$xtaxon->[5] : undef; }
						push(@{$desc{$index}{taxa}}, {'family' => $fam, 'label' => i($xtaxon->[1]) . " " . $xtaxon->[2], 'display' => a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2]) } );
						unless (exists $xtaxa{$xtaxon->[1].$xtaxon->[2]}) {
							$xtaxa{$xtaxon->[1].$xtaxon->[2]}{label} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2] );
							$xtaxa{$xtaxon->[1].$xtaxon->[2]}{family} = $fam;
						}
					}
				}
			}
		}
				
		$order = 0;
		
		# Fetch taxa present in the TDWG area
		my $list = request_tab("	SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
						FROM taxons_x_pays AS txp 
						LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
						LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
						LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
						LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
						LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
						LEFT JOIN rangs AS r ON r.index = t.ref_rang
						WHERE ref_pays = $country_id 
						AND txnf.ref_statut = 1
						AND txn.ref_statut = 1;", $dbc, 2);
		
		if ( scalar @{$list}){
			$desc{$id}{order} = $order;
			$desc{$id}{label} = $country;
			$desc{$id}{tdwg} = $tdwg;
			$desc{$id}{level} = $tdwg_level;
			$size += scalar @{$list};
			foreach my $sp ( @{$list} ){
				my $fam;
				if ($families > 1) { $fam = $sp->[4] ? i($sp->[4])." ".$sp->[5] : undef; }
				push(@{$desc{$id}{taxa}}, {'family' => $fam, 'label' => i($sp->[1]) . " " . $sp->[2], 'display' => a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$sp->[3]&id=$sp->[0]"}, i($sp->[1]) . " " . $sp->[2]) } );
				$xtaxa{$sp->[1].$sp->[2]}{label} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" );
				$xtaxa{$sp->[1].$sp->[2]}{family} = $fam;
			}
		}
		
		my %display_modes = %{request_hash("SELECT * FROM display_modes WHERE card = 'country';", $dbc, 'element')};
		my $fully_display = 0;
		if($display_modes{descendants}{display} or $mode eq 'full') { $fully_display = 1; }
		
		my $aires = $tdwg;
		my $airesSQL = $tdwg;
		
		if($fully_display) {
			
			my $regions = request_tab("SELECT index, $lang, tdwg, tdwg_level FROM pays WHERE $lang like '$countrySQL %' OR (tdwg IN ('".join("','", split(/\s*,\s*/,$tdwg))."') AND tdwg != '$tdwg');", $dbc, 2);
						
			foreach my $region (@{$regions}) {
				my $taxa = request_tab("SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
							FROM taxons_x_pays AS txp
							LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txp.ref_taxon 
							LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
							LEFT JOIN taxons AS t ON t.index = txn.ref_taxon 
							LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom 							
							LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
							LEFT JOIN rangs AS r ON r.index = t.ref_rang 							
							WHERE txp.ref_pays = $region->[0] 
							AND txnf.ref_statut = 1
							AND txn.ref_statut = 1;", $dbc, 2);
				if (scalar(@{$taxa})) {
					unless(exists $desc{$region->[0]}) {
						$desc{$region->[0]}{order} = $order;
						$desc{$region->[0]}{label} = $region->[1];
						$desc{$region->[0]}{tdwg} = $region->[2];
						$desc{$region->[0]}{level} = $region->[3];
						$size += scalar @{$taxa};
						$aires .= ",".$region->[2];
						$airesSQL .= ",".$region->[2];
						foreach my $xtaxon (@{$taxa}) {
							my $fam;
							if ($families > 1) { $fam = $xtaxon->[4] ? i($xtaxon->[4])." ".$xtaxon->[5] : undef; }
							push(@{$desc{$region->[0]}{taxa}}, {'family' => $fam, 'label' => i($xtaxon->[1]) . " " . $xtaxon->[2], 'display' => a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2]) } );
							unless (exists $xtaxa{$xtaxon->[1].$xtaxon->[2]}) {
								$xtaxa{$xtaxon->[1].$xtaxon->[2]}{label} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2] );
								$xtaxa{$xtaxon->[1].$xtaxon->[2]}{family} = $fam;
							}
						}
					}
				}
			}
			
			my @sons = ($tdwg);
			while (scalar(@sons)) {	
				my $req = "SELECT index, $lang, tdwg, tdwg_level FROM pays WHERE parent in ('".join("','", @sons)."') AND tdwg != parent;";
				my $childs = request_tab($req, $dbc, 2);
				@sons = ();
				foreach my $child (@{$childs}) {
					push(@sons, $child->[2]);
					my $taxa = request_tab("SELECT DISTINCT txp.ref_taxon, nc.orthographe, nc.autorite, r.en, nf.orthographe, nf.autorite
								FROM taxons_x_pays AS txp
								LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txp.ref_taxon 
								LEFT JOIN taxons_x_noms AS txnf ON txnf.ref_taxon = (SELECT index_taxon_parent FROM hierarchie WHERE index_taxon_fils = txp.ref_taxon AND nom_rang_parent = 'family')
								LEFT JOIN taxons AS t ON t.index = txn.ref_taxon 
								LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom 							
								LEFT JOIN noms_complets AS nf ON nf.index = txnf.ref_nom 							
								LEFT JOIN rangs AS r ON r.index = nc.ref_rang 							
								WHERE txp.ref_pays = $child->[0] 
								AND txnf.ref_statut = 1
								AND txn.ref_statut = 1;", $dbc, 2);
					
					if (scalar(@{$taxa})) {
						unless(exists $desc{$child->[0]}) {
							$desc{$child->[0]}{order} = $order;
							$desc{$child->[0]}{label} = $child->[1];
							$desc{$child->[0]}{tdwg} = $child->[2];
							$desc{$child->[0]}{level} = $child->[3];
							$size += scalar @{$taxa};
							foreach my $xtaxon (@{$taxa}) {
								my $fam;
								if ($families > 1) { $fam = $xtaxon->[4] ? i($xtaxon->[4])." ".$xtaxon->[5] : undef; }
								push(@{$desc{$child->[0]}{taxa}}, {'family' => $fam, 'label' => i($xtaxon->[1]) . " " . $xtaxon->[2], 'display' => a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2]) } );
								unless (exists $xtaxa{$xtaxon->[1].$xtaxon->[2]}) {
									$xtaxa{$xtaxon->[1].$xtaxon->[2]}{label} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$xtaxon->[3]&id=$xtaxon->[0]"}, i($xtaxon->[1]) . " " . $xtaxon->[2] );
									$xtaxa{$xtaxon->[1].$xtaxon->[2]}{family} = $fam;
								}
							}
						}
					}
				}
			}
		}
		
		my $display;
		my $title;
		my $decalage = 0;
		my $dmx = 'none';
		my $sort = 'family';
		my $nb = $desc{$id} ? scalar(@{$desc{$id}{taxa}}) : 0;
		$size = scalar(keys(%xtaxa));
#		if ($size != $nb) {
		if ($size) {
			if ($size > 1) { $title = "$size $trans->{taxons}->{$lang}  $precise"; }
			else { $title = "$size $trans->{taxon}->{$lang}  $precise"; }
			
			if ($sort ne 'family') {
				foreach my $x (sort {$a->{label} cmp $b->{label}} keys(%xtaxa)) {
					$display .= Tr( td({-colspan=>2, -class=>"MagicCellT$id magicCell", -style=>"display: none;"}, $xtaxa{$x}{label} ) );
				}
			}
			else {
				my $current;
				foreach my $x (sort {$xtaxa{$a}{family} cmp $xtaxa{$b}{family} || $a cmp $b} keys(%xtaxa)) {
					if (!$current or $current ne $xtaxa{$x}{family}) {
						if ($current) { $display .= Tr( td({-colspan=>2, -class=>"MagicCellT$id magicCell", -style=>"display: none;"}, ' ') ); }
						$current = $xtaxa{$x}{family};
						$display .= Tr( td({-colspan=>2, -class=>"MagicCellT$id magicCell", -style=>"display: none;"}, $current ) );
					}
					$display .= Tr( td({-colspan=>2, -class=>"MagicCellT$id magicCell", -style=>"display: none; padding: 0 0 0 2em;"}, $xtaxa{$x}{label} ) );
				}
			}
			if ( $display ){
				$display = makeRetractableArray ("TitleT$id", "MagicCellT$id magicCell", $title, $display, 'arrowRight', 'arrowDown', 1, 'none', 'true', '');
			}
			$decalage = 1;
		}
		else {
			$dmx = 'table-cell';
		}
		
		$decalage *= 20; 
		foreach my $x (sort {$desc{$b}{order} <=> $desc{$a}{order} || $desc{$a}{label} cmp $desc{$b}{label}} keys(%desc)) {
		
			#$decalage = (int($desc{$x}{'level'}) - int($tdwg_level)) || 1;
			my $sum = scalar(@{$desc{$x}{taxa}});
			if ($sum > 1) { $title = $trans->{'taxons'}->{$lang} . " $trans->{located_ins}->{$lang} "; }
			else { 		$title = $trans->{'taxon'}->{$lang} . " $trans->{located_in}->{$lang} "; }
			$title = $sum . " " . $title . "&nbsp;";  
			my $link = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=$x"}, $desc{$x}{label});
			my $body;
			if ($sort ne 'family') {
				foreach my $xtaxon (sort {$a->{label} cmp $b->{label}} @{$desc{$x}{taxa}}) {
					$body .= Tr( td({-colspan=>2, -class=>"MagicCell$x magicCell", -style=>"display: $dmx;"}, $xtaxon->{display} ) );
				}
			}
			else {
				my $current;
				foreach my $xtaxon (sort {$a->{family} cmp $b->{family} || $a->{label} cmp $b->{label}} @{$desc{$x}{taxa}}) {
					if (!$current or $current ne $xtaxon->{family}) {
						if ($current) { $body .= Tr( td({-colspan=>2, -class=>"MagicCell$x magicCell", -style=>"display: $dmx;"}, ' ') ); }
						$current = $xtaxon->{family};
						$body .= Tr( td({-colspan=>2, -class=>"MagicCell$x magicCell", -style=>"display: $dmx;"}, $current ) );
					}
					$body .= Tr( td({-colspan=>2, -class=>"MagicCell$x magicCell", -style=>"display: $dmx; padding: 0 0 0 2em;"}, $xtaxon->{display} ) );
				}
			}
			if ( $body ){
				$display .= div({-style=>"margin-left: ".$decalage."px;"}, makeRetractableArraySemiClickable ("Title$x", "MagicCell$x magicCell", $title, $body, 'arrowRight', 'arrowDown', 1, $dmx, 'true', 'none', $link) );
			}
		}
				

#		my $up;
#		if ($dbase eq 'cipa') { 
#			$up = div(
#				$totop,
#				' > ',
#				makeup('countries', $trans->{'geodistribution'}->{$lang}, lc(substr($country, 0, 1)))
#			);
#		}
#		elsif ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
#		 	$up = 	$totop;
#			$up .=  makeup('countries', $trans->{'geodistribution'}->{$lang}, lc(substr($country, 0, 1)));
#		}

#		my $up = prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );
		
#		foreach (@{$regions}) {
#			my $sp_list = request_tab("SELECT DISTINCT txp.ref_taxon, n.orthographe, n.autorite, r.en, p.$lang, LOWER ( n.orthographe )
#							FROM taxons_x_pays AS txp 
#							LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
#							LEFT JOIN statuts AS s ON txn.ref_statut = s.index
#							LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
#							LEFT JOIN pays AS p ON p.index = txp.ref_pays
#							WHERE ref_pays = $_ 
#							AND s.fr = 'valide';",$dbc);
#			
#			if ( scalar @{$sp_list}){
#				my $nb = scalar @{$sp_list};
#				$size += $nb;
#				$sp_tab .= div({-class=>'titre'}, ucfirst($sp_list->[0][4]) . " $nb $trans->{'species(s)'}->{$lang} $precise");
#				$sp_tab .= start_ul({});
#				foreach my $sp ( @{$sp_list} ){
#					$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$sp->[3]&id=$sp->[0]"}, i("$sp->[1]") . " $sp->[2]" ) );
#				}
#				$sp_tab .= end_ul();
#			}
#		}
			
		#Fetch repositories present in the country
#		my $de_list = request_tab("SELECT l.index, l.nom, $lang FROM lieux_depot AS l LEFT JOIN pays as p ON (l.ref_pays = p.index)
#									WHERE p.index = $country_id
#									ORDER BY l.nom;",$dbc); # Fetch repositories list from DB
#                
#		if ( scalar @{$de_list} != 0){
#			my $size = scalar @{$de_list};
#			$de_tab = div({-class=>'titre'}, ucfirst($trans->{"DE_CO"}->{$lang}));
#			$de_tab .= div({-class=>'titre'}, "$size $trans->{'repos(s)'}->{$lang}");
#			$de_tab .= start_ul({});
#			foreach my $repository ( @{$de_list} ){
#				$de_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=repository&id=$repository->[0]"}, "$repository->[1], $repository->[2]" ) );
#			}
#			$de_tab .= end_ul();
#		}
#		else {
#			$de_tab = ul( li($trans->{"none"}->{$lang}));
#		}	
		
		my $vdisplay = get_vernaculars($dbc, 'nv.ref_pays', $country_id);
		
		my %attributes;
		my @attribs = split('#', $display_modes{map}{attributes});
		foreach (@attribs) {
			my ($key, $val) = split(':', $_);
			$attributes{$key} = $val;
		}
		
		my ($sea_color, $continent_color, $continent_borders, $area_color, $area_borders, $width);
		
		$sea_color = $attributes{sea} ? "#$attributes{sea}" : 'transparent';
		$continent_color = $attributes{continents} || 'AAAAAA';
		$continent_borders = $attributes{cborders} || 'AAAAAA';
		$area_color = $attributes{areas} || '00008B';
		$area_borders = $attributes{aborders} || '00008B';
		$width =  $attributes{width} || 450;
        
        $airesSQL =~ s/,/','/g;
		
		my $map;
        my $zoom;
        my $bbox;
		unless ($width eq 'none') {
			my $areas;
			if ($continent_color eq $continent_borders) {
				if ($tdwg_level > 1) { $areas .= 'tdwg'.$tdwg_level.':a:'.$aires.'||'.'tdwg1:b:1,2,3,4,5,6,7,8,9'; }
				else { $areas .= 'tdwg1:b:1,2,3,4,5,6,7,8,9'.'||'.'tdwg'.$tdwg_level.':a:'.$aires; }
			}
			else {
				#if ($tdwg ne '4') {
					if ($tdwg_level > 1) { 
						$areas .= 'tdwg'.$tdwg_level.':a:'.$aires;
						$areas .= '||';
						$areas .= "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg not in ('".$airesSQL."') and tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)});
					}
					else {
						$areas .= "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg not in ('".$airesSQL."') and tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)});
						$areas .= '||';
						$areas .= 'tdwg'.$tdwg_level.':a:'.$aires;
					}
				#}
				#else {
				#	$areas .= "tdwg4:b:".join(',',@{request_tab("SELECT tdwg FROM pays WHERE tdwg not in ('".$aires."') and tdwg_level = '4' AND parent IN (SELECT tdwg FROM pays WHERE tdwg_level = '3');", $dbc, 1)});
				#	$areas .= '||';
				#	$areas .= 'tdwg'.$tdwg_level.':a:'.$tdwg;
				#}
			}
		
			$areas = "ad=$areas";
			
			my $styles = "as=a:$area_color,$area_borders,0|b:$continent_color,$continent_borders,0";
            
            my $level2 = request_tab("SELECT DISTINCT get_tdwg_parent_by_level(tdwg, 2) FROM pays WHERE tdwg IN ('" . $airesSQL . "') AND get_tdwg_parent_by_level(tdwg, 2) NOT IN ('60','61','62','63') ORDER BY 1;", $dbc, 1);
            
            if ("@{$level2}" eq "42" or "@{$level2}" eq "43" or "@{$level2}" eq "42 43") {
                $bbox = "&bbox=90,-25,186,22";
            }
            elsif ("@{$level2}" eq "81") { $bbox = "&bbox=-105,5,-55,30" }
                        
            if ($bbox) {
                $zoom = "<img id='cmap2'
                style='background: $sea_color; margin-top: 0em; border: 1px solid black;'
                src='$maprest?$areas&$styles&ms=$width$bbox&recalculate=false'
                onMouseOver=".'"'."this.style.cursor='pointer';".'"'."
                onclick=".'"'."ImageMax('$maprest?$areas&$styles&ms=1000$bbox&recalculate=false');".'"'.
                ">";
            }
            			
            $map = 	td({-style=>'vertical-align: top; width: '.($width+20).'px; text-align: center;'},
					"<img id='cmap'
					style='background: $sea_color; margin-top: 0em; border: 0px solid black;'
					src='$maprest?$areas&$styles&ms=$width&recalculate=false'
                   onMouseOver=".'"'."this.style.cursor='pointer';".'"'."
                   onclick=".'"'."ImageMax('$maprest?$areas&$styles&ms=1000&recalculate=false');".'"'.
                   "><BR><BR>".$zoom
				);
		}
	
		my $subject = $country;
		my $fields = "index, $lang";
		my $table = "pays";
		my $where = "WHERE index IN (SELECT ref_pays FROM taxons_x_pays)";
		my $order = "$lang";
		my $sid = $id;
		
		$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc);

		
		$fullhtml = div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'geodistribution'}->{$lang})),
					$subject, $getall,
                    "<script type='text/javascript'>
                    function ImageMax(chemin) {
                    var html = ".'"'."<html> <head> <title>Distribution</title> </head> <body style='background: $sea_color;'><IMG style='background: $sea_color;' src=".'"'."+chemin+".'"'." BORDER=0 NAME=ImageMax></body></html>".'"'.";
                    var popupImage = window.open('','_blank','toolbar=0, location=0, scrollbars=0, directories=0, status=0, resizable=1, width=1020, height=520');
                        popupImage.document.open();
                        popupImage.document.write(html);
                        popupImage.document.close()
                    };
                    </script>",
                    table({-width=>'100%'},
						Tr(
							td({-style=>'vertical-align: top;'},
								$display,
								$de_tab,
								$vdisplay
							),
							$map
						)
					),
			);
				
		print $fullhtml;

		$dbc->disconnect;
	}
}

sub image_card {
	
	if ( my $dbc = db_connection($config) ) {
	
		my $req = "SELECT I.url, xxi.commentaire, nc.orthographe, nc.autorite, txn.ref_taxon, xxi.ref_nom
			FROM images AS I 
			LEFT JOIN ((SELECT ref_nom, ref_image, commentaire FROM noms_x_images) UNION (SELECT ref_nom, ref_image, commentaire FROM taxons_x_images)) AS xxi ON I.index = xxi.ref_image
			LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = xxi.ref_nom
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			WHERE I.index = $id;";
		
		my $image = request_row($req,$dbc);
		
		$req = "SELECT I.index, I.icone_url, I.url
			FROM images AS I 
			LEFT JOIN ((SELECT ref_nom, ref_image, commentaire FROM noms_x_images) UNION (SELECT ref_nom, ref_image, commentaire FROM taxons_x_images)) AS xxi ON I.index = xxi.ref_image
			WHERE I.index != $id
			AND xxi.ref_nom = $image->[5]
			ORDER BY I.groupe, I.tri;";
		
		my $mini = request_tab($req,$dbc);
		
		my $icons;
		foreach my $icon ( @{$mini} ) {
			my $thumbnail = $icon->[1] ? img({-src=>"$icon->[1]", -style=>'border: 0; margin: 0;'}) : img({-src=>"$icon->[2]", -style=>'height: 150px; border: 0; margin: 0;'});
			$icons .= div({-style=>'float: left; margin: 0 8px 8px 0;'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=image&id=$icon->[0]&search=nom"}, $thumbnail));
		}
		if ($icons) { $icons = br . br . $icons . div({-style=>'clear: both;'}); }
		
		#my $up;
		#if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		#	$up = 	$totop;
		#	$up .=  '&nbsp;';
		#	$up .=  div({-class=>'hierarch'}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$image->[4]"}, i($image->[2]) . " $image->[3]" ));
		#	$up .=  div({-class=>'hierarch'}, a({-href=>"javascript: history.go(-1)"}, i($image->[2]) . " $image->[3]" ));
		#}
		
		my $comment;
		if ($image->[1]) { $comment = $image->[1] . br . br; }

		#select (select ref_image from ((select ref_nom, ref_image from taxons_x_images) union (select ref_nom, ref_image from noms_x_images)) AS nmni where ref_nom = nms.ref_nom limit 1), nc.orthographe || coalesce(' '||nc.autorite) 
		#from ((select ref_nom from taxons_x_images) union (select ref_nom from noms_x_images)) AS nms LEFT JOIN noms_complets AS nc ON nc.index = nms.ref_nom order by 2;
		
		my $subject = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$image->[4]"}, i($image->[2]) . " $image->[3]" );
		my $fields = "(SELECT ref_image FROM ((SELECT ref_nom, ref_image FROM taxons_x_images) UNION (SELECT ref_nom, ref_image FROM noms_x_images)) AS nmni WHERE ref_nom = nms.ref_nom LIMIT 1), nc.orthographe || coalesce(' '||nc.autorite)";
		my $table = "((SELECT ref_nom FROM taxons_x_images) UNION (SELECT ref_nom FROM noms_x_images)) AS nms LEFT JOIN noms_complets AS nc ON nc.index = nms.ref_nom";
		my $where = "";
		my $order = "2";
		my $sid = $id;
		
		$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc);
		
		$fullhtml = div({-class=>'content'},	
					div({-class=>'titre'}, ucfirst($trans->{'image'}->{$lang})),
					$subject
					, br, br,
					$comment,
					img({-id=>"full", -src=>"/flowdocs/fullscr.png", -style=>'float: right; border: 0; margin: 0 0 5px 0; width: 20px;'}),
					img({-id=>"subject", -src=>"$image->[0]"}),
					"<script>
						var image = document.getElementById('subject'); 
						var width = image.clientWidth;
						if (width > 1000) { 
							image.style.width = '1000px';
						}
						document.getElementById('full').style.cursor='pointer';
						document.getElementById('full').onclick = function() { window.open(\"$image->[0]\"); };
						image.style.cursor='pointer';
						image.onclick = function() { window.open(\"$image->[0]\"); };
						
					</script>",
					$icons
				);
		
		print $fullhtml;
		$dbc->disconnect;
	}
}

sub vernacular_card {
	
	if ( my $dbc = db_connection($config) ) {
		
		my $req = "SELECT v.nom, l.langage, p.en, txn.ref_taxon, nc.orthographe, nc.autorite, r.en, txv.ref_pub, v.ref_pays
			FROM noms_vernaculaires AS v
			LEFT JOIN taxons_x_vernaculaires AS txv ON v.index = txv.ref_vernaculaire
			LEFT JOIN langages AS l ON v.ref_langage = l.index
			LEFT JOIN pays AS p ON v.ref_pays = p.index
			LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = txv.ref_taxon
			LEFT JOIN noms_complets AS nc ON nc.index = txn.ref_nom
			LEFT JOIN rangs AS r ON r.index = nc.ref_rang
			LEFT JOIN publications AS pb ON txv.ref_pub = pb.index
			WHERE txn.ref_statut = 1
			AND v.index = $id
			ORDER BY nc.orthographe, nc.autorite, pb.annee;";

		my $taxa = request_tab($req, $dbc, 2);
				
		my ($nom, $langg, $pays, $ref_pays) = ($taxa->[0][0], $taxa->[0][1], $taxa->[0][2], $taxa->[0][8]);

		#my $up;
		#if ($dbase ne 'cool' and $dbase ne 'flow' and $dbase ne 'flow2' and $dbase ne 'strepsiptera') {
		# 	$up = 	$totop;
		#	$up .=  makeup('vernaculars', $trans->{'vernaculars'}->{$lang});
		#}
		
		my $vdisplay;
		if (scalar @{$taxa}) {
				
			my %taxas;
			my @order;
			foreach (@{$taxa}) {
				my @pub;
				if ($_->[7]) {
					@pub = publication($_->[7], 0, 1, $dbc);
				}				
				
				unless (exists $taxas{$_->[3]}) { 
					push(@order, $_->[3]);
					$taxas{$_->[3]} = {};
					$taxas{$_->[3]}{'label'} = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$_->[6]&id=$_->[3]"}, "$_->[4] $_->[5]" );
					
					$taxas{$_->[3]}{'refs'} = ();
				}
				
				if (scalar @pub) {
					push(@{$taxas{$_->[3]}{'refs'}}, a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$_->[7]"}, "$pub[1]" ) . getPDF($_->[7]));
				}
			}
					
			foreach (@order) {
				my $list = $taxas{$_}{'label'};
				if ($taxas{$_}{'refs'}) { $list .= ' according to ' . join (', ', @{$taxas{$_}{'refs'}}); }
				$vdisplay .= li($list);
			}
			
			$vdisplay = ul( $vdisplay) . p;
		}
		
		my $xpays;
		if ($pays) { $xpays = " in " . a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=country&id=".$ref_pays}, $pays); }
		
		my $fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'vernacular'}->{$lang})),
					div({-class=>'subject', -style=>'display: inline;'}, $nom) . $xpays . " ($langg)",
					div({-class=>'titre'}, ucfirst($trans->{'sciname(s)'}->{$lang})),
					$vdisplay
				);
					
		print $fullhtml;
	
		$dbc->disconnect;
	}
}


# Repository card
#################################################################
sub repository_card {
	if ( my $dbc = db_connection($config) ) {
		
		# TODO: improve sorting, improve number rendering
		my $repository_id = $id;

		my $repository = request_tab("SELECT ld.nom, p.$lang FROM lieux_depot AS ld LEFT JOIN pays AS p ON ( ld.ref_pays = p.index )
										WHERE ld.index = $repository_id;",$dbc);
		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;
		my $sth2 = $dbc->prepare( "SELECT l.index, l.nom FROM lieux_depot AS l
									LEFT JOIN pays as p ON (l.ref_pays = p.index)
									ORDER BY p.$lang, l.nom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $repository_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('repositories', $trans->{'repositories'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#fetch types present in this repository
		my $req = "SELECT nxt.ref_nom, nc.orthographe, nc.autorite, nxt.quantite, tt.$lang, s.en, td.$lang, ec.$lang, txn.ref_taxon, r.en
				FROM noms_x_types AS nxt
				LEFT JOIN noms_complets AS nc ON nc.index = nxt.ref_nom
				LEFT JOIN taxons_x_noms AS txn ON txn.ref_nom = nc.index
				LEFT JOIN taxons AS t ON t.index = txn.ref_taxon
				LEFT JOIN rangs AS r ON r.index = t.ref_rang
				LEFT JOIN types_type AS tt ON ( nxt.ref_type = tt.index )
				LEFT JOIN sexes AS s ON ( nxt.ref_sexe = s.index )
				LEFT JOIN types_depot AS td ON ( nxt.ref_type_depot = td.index )
				LEFT JOIN etats_conservation AS ec ON ( nxt.ref_etat_conservation = ec.index )
				WHERE nxt.ref_lieux_depot = $repository_id
				AND txn.ref_statut = 1
				ORDER BY nc.orthographe, nc.autorite;";
		
		my $types = request_tab($req,$dbc,2);

		my $types_tab;
		my $sum = 0;
		foreach my $type ( @{$types} ) {
			my @more;
			if ($type->[5]) { 
				if ($type->[5] eq 'male') { push(@more, "&#9794;"); }
				elsif ($type->[5] eq 'female') { push(@more, "&#9792;"); }
			}
			
			if ($type->[6]) { push(@more, $type->[6])}
			if ($type->[7]) { push(@more, $type->[7])}
			my $pluriel;
			if($type->[3] > 1) { $pluriel = 's'}
			$types_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$type->[9]&id=$type->[8]"}, i($type->[1]) . " $type->[2]") . " : $type->[3] $type->[4]$pluriel " . join(', ',@more) );
			$sum += $type->[3] || 1;
		}
		
		if ($types_tab) {	
			$types_tab = div({-class=>'titre'}, "$sum " . ucfirst($trans->{'type_img(s)'}->{$lang})) . ul($types_tab);
		}
		
		my $subject = "$repository->[0][0]. $repository->[0][1]";
		my $fields = "index, nom";
		my $table = "lieux_depot";
		my $where = "WHERE index IN (SELECT ref_lieux_depot FROM noms_x_types)";
		my $order = "nom";
		my $sid = $id;
		
		$subject = trans_navigation($subject, $fields, $table, $where, $order, $sid, $dbc);

		$fullhtml = div({-class=>'content'},	
					div({-class=>'titre'}, ucfirst($trans->{'repository'}->{$lang})),
					$subject,
					$types_tab
				);
				
		print $fullhtml;
			
		$dbc->disconnect;
	}
	else {}
}

# Era card
#################################################################
sub era_card {
	if ( my $dbc = db_connection($config) ) {
		my $era_id = $id;
		my $era = request_row("SELECT index, $lang FROM periodes WHERE index = $era_id;",$dbc); # Fetch era name from DB

		my $sp_numb = request_row("SELECT count(*) FROM taxons_x_periodes AS txp
								LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE s.fr = 'valide' AND txp.ref_periode = $era_id
								AND n.orthographe ILIKE '$alph%'
								;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT index, $lang FROM periodes ORDER BY fr;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $era_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('eras', $trans->{'eras'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		#TODO: separate taxa of each rank
		my $sp_list = request_tab("	SELECT DISTINCT orthographe, autorite, txp.ref_taxon
						FROM taxons_x_periodes AS txp
						LEFT JOIN taxons_x_noms AS txn ON txp.ref_taxon = txn.ref_taxon
						LEFT JOIN statuts AS s ON txn.ref_statut = s.index
						LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
						WHERE s.fr = 'valide' AND txp.ref_periode = $era_id
						AND n.orthographe ILIKE '$alph%'
						ORDER BY orthographe
						$bornes;",$dbc);

		my $sp_tab;
		if ( scalar @{$sp_list} != 0){
			$sp_tab = div({-class=>'titre'}, ucfirst($trans->{"SP_ER"}->{$lang}));
			$sp_tab .= start_ul({});
			foreach my $sp ( @{$sp_list} ){
				$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[2]"}, i($sp->[0]) . " $sp->[1]" ) );
			}
			$sp_tab .= end_ul();
		}
		else {
			#$sp_tab = ul( li($trans->{"UNK"}->{$lang}));
		}

		#my $up = div(
		#	$totop,
		#	' > ', 
		#	makeup('eras', $trans->{'eras'}->{$lang})
		#);

		$fullhtml = div({-class=>'content'},	
					div({-class=>'titre'}, ucfirst($trans->{'era'}->{$lang})),
					div({-class=>'subject'}, $era->[1]),
					$sp_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}


# Region card
#################################################################
sub region_card {
	if ( my $dbc = db_connection($config) ) {
		my $region_id = $id;
		my $region = request_row("SELECT nom, $lang FROM regions AS r LEFT JOIN pays AS p ON p.index = r.ref_pays WHERE r.index = $region_id;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT index, nom FROM regions ORDER BY nom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $region_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		my $sp_numb = request_row("SELECT count(*) FROM taxons_x_regions AS txr
								LEFT JOIN taxons_x_noms AS txn ON txr.ref_taxon = txn.ref_taxon
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE s.fr = 'valide' AND txr.ref_region = $region_id
								AND n.orthographe ILIKE '$alph%'
								;",$dbc);

		my $bornes;
		if ($to) { $bornes .= "LIMIT $to"; }
		if ($from) { $bornes .= "OFFSET $from"; }

		my $sp_list = request_tab("SELECT txr.ref_taxon, orthographe, autorite FROM taxons_x_regions AS txr
								LEFT JOIN taxons_x_noms AS txn ON txr.ref_taxon = txn.ref_taxon
								LEFT JOIN statuts AS s ON txn.ref_statut = s.index
								LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
								WHERE s.fr = 'valide' AND txr.ref_region = $region_id
								AND n.orthographe ILIKE '$alph%'
								ORDER BY LOWER( orthographe )
								$bornes;",$dbc);

		my $sp_tab;
		if ( scalar @{$sp_list} != 0){
			my $size = $sp_numb->[0];
			$sp_tab = div({-class=>'titre'}, ucfirst($trans->{"SP_RE"}->{$lang}));
			$sp_tab .= div({-class=>'titre'}, "$size $trans->{'species(s)'}->{$lang}");
			$sp_tab .= start_ul({});
			foreach my $sp ( @{$sp_list} ){
				$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . "$sp->[3]" );
			}
			$sp_tab .= end_ul();
		}
		else {
			#$sp_tab = ul( li($trans->{"UNK"}->{$lang}));
		}
		
		if ($region->[1]) { $region->[0] .= " ($region->[1])" }

		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('regions', $trans->{'regions'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'region'}->{$lang} )),
					div({-class=>'subject'}, $region->[0] ),
					$sp_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}


# Agent card
#################################################################
sub agent_card {
	if ( my $dbc = db_connection($config) ) {
		my $agent_id = $id;
		my $agent = request_row("SELECT ai.$lang, tai.$lang FROM agents_infectieux AS ai
				LEFT JOIN types_agent_infectieux AS tai ON ai.ref_type_agent_infectieux = tai.index
				WHERE ai.index = $agent_id;",$dbc); # Fetch agent name from DB

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT ai.index, ai.$lang FROM agents_infectieux AS ai LEFT JOIN types_agent_infectieux AS tai
									ON ai.ref_type_agent_infectieux = tai.index
									ORDER BY tai.$lang, ai.$lang;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $agent_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('agents', $trans->{'A_list'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#Fetch species transmiting this infectious agent  // p.$lang, tpai.ref_publication_ori, nc.$lang 
		my $sp_list = request_tab("SELECT distinct tpai.ref_taxon, orthographe, autorite	
				FROM agents_infectieux AS ai
				LEFT JOIN taxons_x_pays_x_agents_infectieux AS tpai ON ai.index = tpai.ref_agent_infectieux
				LEFT JOIN pays AS p ON tpai.ref_pays = p.index
				LEFT JOIN niveaux_confirmation AS nc ON tpai.ref_niveau_confirmation = nc.index
				LEFT JOIN taxons_x_noms AS txn ON tpai.ref_taxon = txn.ref_taxon
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				WHERE s.fr = 'valide' AND  ai.index = $agent_id 
				ORDER BY orthographe, autorite, tpai.ref_taxon;",$dbc); # Fetch agent info from DB

		my $sp_tab;
		foreach my $sp ( @{$sp_list} ){
			my @pub = publication($sp->[4], 0, 1, $dbc );
			$sp_tab .= li( a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) );
		}
		$sp_tab = ul($sp_tab);

		if ($agent->[1]) { $agent->[1] = " ($agent->[1])"}

		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('agents', $trans->{'agents'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'agent'}->{$lang})),
					div({-class=>'subject'}, i( $agent->[0] ) . $agent->[1]),
					div({-class=>'titre'}, ucfirst($trans->{"A_SP"}->{$lang})),
					$sp_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Edition card
#################################################################
sub edition_card {
	if ( my $dbc = db_connection($config) ) {
		my $edition_id = $id;

		my $edition = request_row("SELECT v.index, e.nom, v.nom, p.$lang FROM editions AS e
							LEFT JOIN villes AS v ON e.ref_ville = v.index
							LEFT JOIN pays AS p ON v.ref_pays = p.index
							WHERE e.index = $edition_id;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT e.index, e.nom FROM editions AS e
							LEFT JOIN villes AS v ON e.ref_ville = v.index
							LEFT JOIN pays AS p ON v.ref_pays = p.index
							ORDER BY p.$lang, v.nom, e.nom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $edition_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('editions', $trans->{'ED_list'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#Fetch references published by this edition
		my $pub_list = request_tab("SELECT p.index FROM publications AS p
							RIGHT JOIN editions AS e ON p.ref_edition = e.index
							WHERE e.index = $edition_id",$dbc);

		my $pub_tab;
		$pub_tab = start_ul({});
		foreach my $pub_id ( @{$pub_list} ){
			my $pub = pub_formating($pub_id->[0], $dbc );
			$pub_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=publication&id=$pub_id->[0]"}, "$pub" ) . getPDF($pub_id->[0]) );
		}
		$pub_tab .= end_ul();

		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('editions', $trans->{'editions'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'edition'}->{$lang})),
					div({-class=>'subject'}, "$edition->[1], $edition->[2], $edition->[3]" ),
					div({-class=>'titre'}, ucfirst($trans->{"pu_ed"}->{$lang})),
					$pub_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Habitat card
#################################################################
sub habitat_card {
	if ( my $dbc = db_connection($config) ) {
		my $habitat_id = $id;
		my $habitat = request_row("SELECT $lang FROM habitats WHERE index = $habitat_id;",$dbc); # Fetch habitat name from DB

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT index, $lang FROM habitats ORDER BY $lang;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $habitat_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up =  makeup('habitats', $trans->{'habitat(s)'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#Fetch species living in this habitat
		my $sp_list = request_tab("SELECT t.index, n.orthographe, n.autorite, p.$lang FROM taxons AS t LEFT JOIN taxons_x_pays_x_habitats AS txph ON t.index = txph.ref_taxon
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN pays AS p ON txph.ref_pays = p.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' AND txph.ref_habitat = $habitat_id
				ORDER BY p.$lang, LOWER ( n.orthographe );",$dbc);

		my $sp_tab;
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . " in $sp->[3]" );
		}
		$sp_tab = ul($sp_tab);

		
		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('habitats', $trans->{'habitats'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'habitat'}->{$lang})),
					div({-class=>'subject'}, $habitat->[0]),
					div({-class=>'titre'}, ucfirst($trans->{"SP_HA"}->{$lang})),
					$sp_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Locality card
#################################################################
sub locality_card {
	if ( my $dbc = db_connection($config) ) {
		my $locality_id = $id;
		my $locality = request_row("SELECT l.nom, r.nom, p.$lang FROM localites AS l
							LEFT JOIN regions AS r ON l.ref_region = r.index
							LEFT JOIN pays AS p ON r.ref_pays = p.index
							WHERE l.index = $locality_id;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT l.index, l.nom FROM localites AS l
							LEFT JOIN regions AS r ON l.ref_region = r.index
							LEFT JOIN pays AS p ON r.ref_pays = p.index
							ORDER BY p.$lang, r.nom, l.nom;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $locality_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('localities', $trans->{'LO_list'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );

		#Fetch species that were first observed at this locality
		my $sp_list = request_tab("SELECT t.index, n.orthographe, n.autorite, tob.$lang FROM taxons AS t LEFT JOIN taxons_x_localites AS txl ON t.index = txl.ref_taxon
				LEFT JOIN types_observation AS tob ON txl.ref_type_observation = tob.index
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' AND txl.ref_localite = $locality_id
				ORDER BY LOWER ( n.orthographe );",$dbc);

		my $sp_tab;
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . ", $sp->[3]" );
		}
		$sp_tab = ul($sp_tab);
		
		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('localities', $trans->{'localities'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'locality'}->{$lang})),
					div({-class=>'subject'}, "$locality->[0], $locality->[1], $locality->[2]" ),
					div({-class=>'titre'}, ucfirst($trans->{"SP_LO"}->{$lang})),
					$sp_tab
				);
				
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Capture technics card
#################################################################
sub capture_card {
	if ( my $dbc = db_connection($config) ) {
		my $capture_id = $id;
		my $capture = request_row("SELECT $lang FROM modes_capture WHERE index = $capture_id;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT index, $lang FROM modes_capture ORDER BY $lang;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $capture_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();

		#my $up = makeup('captures', $trans->{'CA_list'}->{$lang});
		#$up .= prev_next_card( $card, $previous_id, $prev_name, $next_id, $next_name );
		
		#Fetch species captured by this mean
		my $sp_list = request_tab("SELECT t.index, n.orthographe, n.autorite, p.$lang FROM taxons AS t LEFT JOIN taxons_x_pays_x_modes_capture AS tpmc ON t.index = tpmc.ref_taxon
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS n ON txn.ref_nom = n.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				LEFT JOIN pays AS p ON tpmc.ref_pays = p.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				WHERE r.en = 'species' AND s.en = 'valid' AND tpmc.ref_mode_capture = $capture_id
				ORDER BY p.$lang, LOWER ( n.orthographe );",$dbc);

		my $sp_tab;
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=species&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) . " in $sp->[3]" );
		}
		$sp_tab = ul($sp_tab);
		
		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('captures', $trans->{'captures'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'capture'}->{$lang})),
					div({-class=>'subject'}, $capture->[0]),
					div({-class=>'titre'}, ucfirst($trans->{"SP_CA"}->{$lang})),
					$sp_tab
				);
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# Capture technics card
#################################################################
sub type_card {
	if ( my $dbc = db_connection($config) ) {
		my $type_id = $id;
		my $type = request_row("SELECT $lang FROM types_type WHERE index = $type_id;",$dbc);

		#Get previous and next id
		my ( $previous_id, $prev_name, $next_id, $next_name, $stop, $current_id, $current_name );
		$dbc->{RaiseError} = 1;

		my $sth2 = $dbc->prepare( "SELECT index, $lang FROM types_type ORDER BY $lang;" );
		$sth2->execute( );
		$sth2->bind_columns( \( $current_id, $current_name ) );
		while ( $sth2->fetch() ){
			if ( $stop ){
				( $next_id, $next_name ) = ( $current_id, $current_name );
				last;
			}
			else {
				if ( $current_id == $type_id ){
					$stop = 1;
				}
				else {
					( $previous_id, $prev_name ) = ( $current_id, $current_name );
				}
			}
		}
		$sth2->finish();
		
		#Fetch species captured by this mean
		my $sp_list = request_tab("	SELECT distinct nc.index, nc.orthographe, nc.autorite, nc.ref_rang
						FROM noms_x_types AS nxt 
						LEFT JOIN noms_complets AS nc ON nc.index = nxt.ref_nom
						WHERE nxt.ref_type = $type_id
						ORDER BY nc.orthographe, nc.autorite, nc.index, nc.ref_rang;",$dbc);

		my $sp_tab;
		foreach my $sp ( @{$sp_list} ){
			$sp_tab .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$sp->[0]"}, i($sp->[1]) . " $sp->[2]" ) );
		}
		$sp_tab = ul($sp_tab);
		
		#my $up = div(
		#		$totop,
		#		' > ',
		#		makeup('types', $trans->{'types'}->{$lang})
		#	);

		$fullhtml = 	div({-class=>'content'},
					div({-class=>'titre'}, ucfirst($trans->{'type'}->{$lang})),
					div({-class=>'subject'}, $type->[0]),
					div({-class=>'titre'}, ucfirst($trans->{'names'}->{$lang})),
					$sp_tab
				);
		print $fullhtml;

		$dbc->disconnect;
	}
	else {}
}

# 
#################################################################
sub autotext {
#	system "php /var/www/html/Documents/explorerdocs/php/autotextsbeta.php --id=$id";
	system "php /var/www/html/Documents/explorerdocs/php/autotextsbeta.php --id=$id";
}

#################################################################
sub classification {
#	system "php /var/www/html/Documents/explorerdocs/php/classification.php";
	system "php /var/www/html/Documents/explorerdocs/php/classification.php";
}

##################################################################################################################################
# Shared Subroutines
##################################################################################################################################

# Returns previous and next topic, depending on the current topic
sub prev_next_topic { #TODO: make prev_next card optional
	my ( $topic ) = @_;
	my ( $previous_topic, $next_topic, $html );
	for my $i ( 0..$#topics ){
		if ( $topic eq $topics[$i] ){
			if ( $i == 0 ){
				$previous_topic = $topics[-1];
				$next_topic = $topics[$i+1];
			}
			elsif ($i == $#topics ){
				$previous_topic = $topics[$i-1];
				$next_topic = $topics[0];
			}
			else {
				$previous_topic = $topics[$i-1];
				$next_topic = $topics[$i+1];
			}
			last;
		}
	}
	
	$html .= div (
			#span('< '),
			a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$previous_topic"}, "$trans->{$previous_topic}->{$lang}"),
			span(' / '),
			a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$next_topic"}, "$trans->{$next_topic}->{$lang}"),
			#span(' >')
		);

	return $html;
}

sub alpha_build {

	my ($vletters) = @_;
		
	my @alpha = ( 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' );
	$alph = $alph ? $alph : 'A';
		
	my @params;
	foreach (keys(%labels)) { if ($_ ne 'alph' and $labels{$_}) { push(@params, $_)}}
	my $args = join('&', map { "$_=$labels{$_}"} @params );
	
	my @links;
	foreach (my $i=0; $i<scalar(@alpha); $i++) { 
		
		unless(exists $vletters->{$alpha[$i]}) { 
			push(@links, span({-class=>'alphaletter shadow_letter'}, $alpha[$i]));
		}
		elsif($alpha[$i] eq $alph) { 
			push(@links, a({-class=>'xletter', -href=>"$scripts{$dbase}$args&alph=$alpha[$i]"}, $alpha[$i]));
		}
		else {
			push(@links, a({-class=>'alphaletter', -href=>"$scripts{$dbase}$args&alph=$alpha[$i]"}, $alpha[$i]));
		}
	}

	return 	"@links";
}


sub prev_next_page {
	
	my $html;
	
	#unless ( $from == 0 ){ 
	#	$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_left.png', -style=>'height: 10px; width: 10px;'}) );
	#	my $prev = $from - $to;
	#	my $d = $prev+1;
	#	$html .= td({-style=>'padding: 0 5px;'},  a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$topic&from=$prev&alph=$alph"}, "$d - $from" ) );
	#}
	#if ( $from + $to < $number ){
	#	unless ( $from == 0 ){ 
	#		$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_center.png', -style=>'height: 10px; width: 10px;'}) );  
	#	}
	#	else {  $html .= td({-style=>'padding-left: 20px;'}, '')}
	#	my $next = $from + $to;
	#	my $d1 = $next+1;
	#	my $d2 = $next+$to;
	#	$html .= td({-style=>'padding: 0 5px;'},   a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$topic&from=$next&alph=$alph"}, "$d1 - $d2" ) );
	#	$html .= td( img({-border=>0, -src=>'/explorerdocs/nav_right.png', -style=>'height: 10px; width: 10px;'}) );
	#}

	return $html;
}

sub prev_next_card {
	my ( $card, $bridge, $prev_id, $label, $next_id, $jsidprev, $jsidnext, $margin ) = @_;
	
	my $mouseOverPrev = "	var bulle = document.getElementById('$jsidprev');
				var pos = findPos(this);
				bulle.style.top = pos[1] - 30 + 'px';
				bulle.style.display = 'block';";
	
	my $mouseOverNext = "	var bulle = document.getElementById('$jsidnext');
				var pos = findPos(this);
				bulle.style.top = pos[1] - 30 + 'px';
				bulle.style.left = pos[0] - 72 + 'px';
				bulle.style.display = 'block';";
	
	my $prev_card = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$prev_id", -onMouseOver=>$mouseOverPrev, -onMouseOut=>"document.getElementById('$jsidprev').style.display = 'none';"}, div({-class=>'arrowLeft'}, ''));
	my $next_card = a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$card&id=$next_id", -onMouseOver=>$mouseOverNext, -onMouseOut=>"document.getElementById('$jsidnext').style.display = 'none';"}, div({-class=>'arrowRight'}, ''));

	my $border = 0;
	return table({-style=>"margin: $margin; background: transparent;"}, Tr(td({-style=>"vertical-align: top; border: ".$border."px solid black;"}, $bridge), td({-style=>"padding-right: 6px; vertical-align: middle; border: ".$border."px solid black;"}, $prev_card), td({-style=>"vertical-align: middle; border:  ".$border."px solid black;"}, $label), td({-style=>"padding-left: 6px; vertical-align: middle; border:  ".$border."px solid black;"}, $next_card)));
}

# Read localization from translation DB
####################################################################
sub read_lang { #TODO: put the params in a conf file
	my ( $conf ) = @_;
	my $tr = {};
	my $rdbms  = $conf->{TRAD_RDBMS};
	my $server = $conf->{TRAD_SERVER};
	my $db     = $conf->{TRAD_DB};
	my $port   = $conf->{TRAD_PORT};
	my $login  = $conf->{TRAD_LOGIN};
	my $pwd    = $conf->{TRAD_PWD};
	if ( my $dbc = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port",$login,$pwd) ){
		$tr = $dbc->selectall_hashref("SELECT id, $lang FROM traductions;", "id");
		$dbc->disconnect;
		return $tr;
	}
	else { # connection failed
		my $error_msg .= $DBI::errstr;

		$fullhtml = 	div({-class=>'subject'}, "Database connection error");
		
		print $fullhtml;
		
		return undef;
	}
}

# Database connection function
##############################################################################
#sub db_connection {
#	my ( $conf ) = @_;
#	my $rdbms  = $conf->{DEFAULT_RDBMS} || $conf->{EXPLORER_RDBMS};
#	my $server = $conf->{DEFAULT_SERVER} || $conf->{EXPLORER_SERVER};
#	my $db     = $conf->{DEFAULT_DB} || $conf->{EXPLORER_DB};
#	my $port   = $conf->{DEFAULT_PORT} || $conf->{EXPLORER_PORT};
#	my $login  = $conf->{DEFAULT_LOGIN} || $conf->{EXPLORER_LOGIN};
#	my $pwd    = $conf->{DEFAULT_PWD} || $conf->{EXPLORER_PWD};
#	my $webmaster = $conf->{DEFAULT_WMR} || $conf->{EXPLORER_WMR};
#	if ( my $connect = DBI->connect("DBI:$rdbms:dbname=$db;host=$server;port=$port",$login,$pwd) ){
#		return $connect;
#	}
#	else { # connection failed
#		my $error_msg .= $DBI::errstr;
#
#		$fullhtml = 	div({-class=>'subject'}, "Database connection error");
#		
#		print $fullhtml;
#			
#		return undef;
#	}
#}

# submit query in sql (return a two dimensions array ref)
###################################################################################
sub request_tab {
	my ($req,$dbh,$dim) = @_; # get query
	my $tab_ref = [];
	if ( my $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			if ($dim eq 1) {
				while ( my @row = $sth->fetchrow_array ) {
    					push(@{$tab_ref},$row[0]);
  				}
			} else {
				$tab_ref = $sth->fetchall_arrayref;
			}
			$sth->finish(); # finalize the request

		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" } # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n" } # Could'nt prepare sql request

	return $tab_ref;
}

# submit query in sql
###################################################################################
sub request_hash {
	my ($req,$dbh,$clef) = @_; # get query 
	my $i = 0;
	my $hash_ref;
	if ( my $sth = $dbh->prepare($req) ){ # prepare
		if ( $sth->execute() ){ # execute
			$hash_ref = $sth->fetchall_hashref($clef);
			$sth->finish(); # finalize the request
		}
		else { die "Could'nt execute sql request: $DBI::errstr\n--$req--\n"} # Could'nt execute sql request
	} else { die "Could'nt prepare sql request: $DBI::errstr\n--$req--\n"} # Could'nt prepare sql request

	return $hash_ref;
}

# submit sql query (return a row)
###################################################################################
sub request_row {
	my ($req,$dbh) = @_; # get query 
	my $i = 0;
	my $row_ref;
	
	unless ( $row_ref = $dbh->selectrow_arrayref($req) ){ # prepare, execute, fetch row
		# TODO: if request returns no results it dies anyway
		die "Could'nt execute sql request: $DBI::errstr\n--$req--\n" # Could'nt execute sql request
	}
	return $row_ref;
}

# Builds a string witch contains html header
############################################################################################
sub html_header {
	my ( $navi ) = @_;

	my $html = header(). $navi;
	
	return $html;
}

# Builds a string witch contains html footer
############################################################################################
sub html_footer {
	my $html;
	
	return $html;
}


# Gets ranks ids.
sub get_rank_ids {
	my ( $dbc ) = @_;
	my $ids = {};
	$ids = $dbc->selectall_hashref("SELECT en, index FROM rangs;", "en");
	return $ids;
}

# Builds a publication from database
############################################################################################
sub publication {
	my ( $id, $full, $cpct, $dbh ) = @_;
	unless ( $id ){ return "" }
	my $publication;
	my $abrev;
	my @alpha = ( 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z' );
	my $letter;
	# fetch publication data from db
	my $pre_pub = request_row("SELECT p.index, p.titre, p.annee, p.volume, p.fascicule, r.nom, e.nom, v.nom, p.page_debut, p.page_fin, t.en, p.nombre_auteurs
					FROM publications AS p LEFT JOIN types_publication AS t ON ( p.ref_type_publication = t.index )
					LEFT JOIN revues AS r ON ( p.ref_revue = r.index )
					LEFT JOIN editions AS e ON ( p.ref_edition = e.index )
					LEFT JOIN villes AS v ON ( e.ref_ville = v.index )
					WHERE p.index = $id;",$dbh);
	
	# Build authors list
	my $pre_authors = request_tab("SELECT a.nom, a.prenom, a.index, axp.position
					FROM auteurs_x_publications AS axp 
					LEFT JOIN auteurs AS a ON axp.ref_auteur = a.index
					WHERE ref_publication = $id ORDER BY axp.position;",$dbh);
	
	#my $autcond;
	#foreach (@{$pre_authors}) {
	#	$autcond = " AND (axp.position = )"
	#}
	
	#my $req = "SELECT DISTINCT index FROM publications AS p LEFT JOIN auteurs_x_publications AS axp ON p.index = axp.ref_publication WHERE p.annee = $pre_pub->[2] $autcond";
	#my $sims = request_tab();
	
	my $authors;
	my $author;
	if ( $pre_pub->[11] > 1 ){ # Test if there are several authors
		if ( $full or $pre_pub->[11] < 3){
			for my $i ( 0..$pre_pub->[11]-1 ){
				if ( $i == $pre_pub->[11]-1 ){
					$authors .= "$pre_authors->[$i][0]";
				}
				else {
					$authors .= "$pre_authors->[$i][0]&nbsp;&&nbsp;";
				}
			}
			
		}
		else {
			$authors = "$pre_authors->[0][0]&nbsp;" . i('et al.');
		}
		$author = $authors;
	}
	else {
		$authors = "$pre_authors->[0][0]";
		$author = "$pre_authors->[0][0]";
	}
	# Build publication
	unless ( $cpct ){
		if ( $pre_pub->[10] eq 'Article' ) {
			if ( $pre_pub->[4] ){
				$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].") . " $pre_pub->[5], ". strong("$pre_pub->[3]") . "($pre_pub->[4]): $pre_pub->[8]--$pre_pub->[9].";
			}
			else {
				$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].") . " $pre_pub->[5], ". strong("$pre_pub->[3]") . ": $pre_pub->[8]--$pre_pub->[9].";
			}
		}
		elsif ( $pre_pub->[10] eq 'Thesis' ) { # Todo: complete with thesis data
			$publication = "$authors ($pre_pub->[2]$letter) " . emph("$pre_pub->[1].") . " $pre_pub->[6], $pre_pub->[7]. $pre_pub->[8]--$pre_pub->[9].";
		}
		elsif ( $pre_pub->[10] eq 'Book' ) {
			$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].") . " $pre_pub->[6], $pre_pub->[7]. $pre_pub->[8]--$pre_pub->[9].";
		}
		elsif ( $pre_pub->[10] eq 'In book' ) { # Todo: recursive call of book information
			$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].") . " $pre_pub->[6], $pre_pub->[7]. $pre_pub->[8]--$pre_pub->[9].";
		}
		elsif ( $pre_pub->[10] eq 'Oral communication' ) { # Todo: recursive call of book information
			$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].");
		}
		else {
			$publication = "$authors ($pre_pub->[2]$letter) " . em({-class=>'publication'}, "$pre_pub->[1].") . " $pre_pub->[6], $pre_pub->[7]. $pre_pub->[8]--$pre_pub->[9].";
		}
# 		else {
# 			$publication = "unknown publication type : $pre_pub->[10]";
# 		}
	}
	else {
		$pre_pub->[1] =~ s/^(.{1,20}).+$/$1/;
		$publication = "$author ($pre_pub->[2]$letter) $pre_pub->[1]...";
	}
	
	$abrev = "<NOBR>$author</NOBR>&nbsp;($pre_pub->[2]$letter)";
	$author =~ s/<i>//g;
	$author =~ s/<\/i>//g;
	$author =~ s/&nbsp;/ /g;
	my $abrev2 = "$author ($pre_pub->[2]$letter)";
	
	return ( $publication, $abrev, $abrev2 );
}


# Builds a list of son taxon ids of a given rank 
############################################################################################
sub son_taxa {
	my ( $id, $rank, $dbh ) = @_;
	my $list = [];

	my ( $index, $ref_rang );
	my $sth = $dbh->prepare( "SELECT index, ref_rang FROM taxons where ref_taxon_parent = $id;" );
	$sth->execute( );
	$sth->bind_columns( \( $index, $ref_rang ) );
	while ( $sth->fetch() ){
		if ( $ref_rang == $rank ){
			push @{$list}, $index;
		}
		else {
			my $sons = son_taxa($index, $rank, $dbh );
			push @{$list}, @{$sons};
		}

	}
	$sth->finish(); # finalize the request
	return $list;
}

# Builds a list of son taxon ids of a given rank 
############################################################################################
sub son_fulltaxa {
	my ( $id, $rank, $dbh ) = @_;
	my $list = [];

	my ( $index, $ref_rang, $ortho, $auth, $doc );
	my $sth = $dbh->prepare( "	SELECT t.index, t.ref_rang, nc.orthographe, nc.autorite, d.url
					FROM taxons AS t 
					LEFT JOIN taxons_x_noms AS txn ON txn.ref_taxon = t.index
					LEFT JOIN taxons_x_documents AS txd ON txd.ref_taxon = t.index
					LEFT JOIN documents AS d ON d.index = txd.ref_document
					LEFT JOIN statuts AS st ON st.index = txn.ref_statut
					LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
					WHERE t.ref_taxon_parent = $id
					AND st.en = 'valid'
					AND (d.type = 'card' OR d.type IS NULL)
					ORDER BY nc.orthographe;" );
	$sth->execute( );
	$sth->bind_columns( \( $index, $ref_rang, $ortho, $auth, $doc) );
	while ( $sth->fetch() ){
		if ( $ref_rang == $rank ){
			push @{$list}, [$index, $ortho, $auth, $doc];
		}
		else {
			my $sons = son_fulltaxa($index, $rank, $dbh );
			foreach(@{$sons}) {
				push @{$list}, $_;
			}
		}

	}
	$sth->finish(); # finalize the request
	return $list;
}

# Fetch a parent taxon id of a given rank 
############################################################################################
sub parent_taxon {
	my ( $id, $rank, $dbh ) = @_;
	my $parent_id;
	my $parent  = request_row("SELECT t.ref_taxon_parent, r.en FROM taxons AS t LEFT JOIN rangs AS r ON t.ref_rang = r.index
							WHERE t.index = $id;",$dbh);

	if ( $parent->[1] eq $rank ){
		$parent_id = $id;
	}
	else {
		$parent_id = parent_taxon( $parent->[0], $rank, $dbh );
	}
	return $parent_id;
}

# Tests synonymy exactitude
############################################################################################
sub synonymy {
	my ( $global, $male, $female ) = @_;
	my $synonymy = "";
	if ( $global eq '' or $male eq '' or $female eq '' ){
		if ( $global eq '' and $male eq '' and $female eq '' ){
			$synonymy = "";
		}
		elsif ( $global eq '' and $male eq '' and $female ){
			$synonymy = " " . $trans->{'non_amb'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( $global eq '' and $male and $female eq '' ){
			$synonymy = " " . $trans->{'non_amb'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang};
		}
		elsif ( !$global and $male eq '' and $female eq '' ){
			$synonymy = " " . $trans->{'amb_syn'}->{$lang};
		}
		elsif ( !$global and $male eq '' and !$female ){
			$synonymy = " " . $trans->{'amb_syn'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( !$global and !$male and $female eq '' ){
			$synonymy = " " . $trans->{'amb_syn'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang};
		}
		else { # There must something wrong !
		}
	}
	else {
		if ( $global and $male and $female ){
			$synonymy = " " . $trans->{'non_amb'}->{$lang};
		}
		elsif ( !$global and !$male and !$female ){
			$synonymy = " " . $trans->{'amb_syn'}->{$lang};
		}
		elsif ( !$global and !$male and $female ){
			$synonymy = " " . $trans->{'amb_syn'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang} . " " . $trans->{'non_amb'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( !$global and $male and !$female ){
			$synonymy = " " . $trans->{'non_amb'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang} . " " . $trans->{'amb_syn'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		else { # There must something wrong !
		}
	}
	return $synonymy;
}

# Tests synonymy completeness
############################################################################################
sub completeness {
	my ( $global, $male, $female ) = @_;
	my $completeness = "";
	if ( $global eq '' or $male eq '' or $female eq '' ){
		if ( $global eq '' and $male eq '' and $female eq '' ){
			$completeness = "";
		}
		elsif ( $global eq '' and $male eq '' and $female ){
			$completeness = " " . $trans->{'complete'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( $global eq '' and $male and $female eq '' ){
			$completeness = " " . $trans->{'complete'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang};
		}
		elsif ( !$global and $male eq '' and $female eq '' ){
			$completeness = " " . $trans->{'partial'}->{$lang};
		}
		elsif ( !$global and $male eq '' and !$female ){
			$completeness = " " . $trans->{'partial'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( !$global and !$male and $female eq '' ){
			$completeness = " " . $trans->{'partial'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang};
		}
		else { # There must something wrong !
		}
	}
	else {
		if ( $global and $male and $female ){
			$completeness = " " . $trans->{'complete'}->{$lang};
		}
		elsif ( !$global and !$male and !$female ){
			$completeness = " " . $trans->{'partial'}->{$lang};
		}
		elsif ( !$global and !$male and $female ){
			$completeness = " " . $trans->{'partial'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang} . " " . $trans->{'complete'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		elsif ( !$global and $male and !$female ){
			$completeness = " " . $trans->{'complete'}->{$lang} . " " . $trans->{'amb_syn_M'}->{$lang} . " " . $trans->{'partial'}->{$lang} . " " . $trans->{'amb_syn_F'}->{$lang};
		}
		else { # There must something wrong !
		}
	}
	return $completeness;
}

#----------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------
# Get all necessary informations of a publication from his index to put it in a hash.
sub get_pub_params {
	my ( $index, $dbc ) = @_;

	# Get the type of the publication
	my $typereq = "SELECT type.en FROM types_publication as type LEFT JOIN publications as p on (p.ref_type_publication = type.index) WHERE p.index = $index;";
	my ($pub_type) = @{request_row($typereq,$dbc)};
	my $pubhash;
	
	# Get all the information concerning a publication according to his type
	if ( $pub_type eq "Article" ) {
		my $pubreq = "SELECT p.index, tp.en as type, p.titre, p.annee, p.fascicule, p.page_debut, p.page_fin, p.nombre_auteurs, r.nom as revue, p.volume 
		FROM publications as p
		LEFT JOIN revues AS r ON r.index = p.ref_revue
		LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
		WHERE p.index = $index;";

		$pubhash = request_hash($pubreq,$dbc,"index");
	}

	elsif ( $pub_type eq "Book" ) {
		my $pubreq = "SELECT p.index, tp.en as type, p.titre, p.annee, e.nom as edition, v.nom as ville, pays.en as pays, p.page_debut, p.page_fin, p.nombre_auteurs, p.volume 
		FROM publications as p
		LEFT JOIN editions AS e ON e.index = p.ref_edition
		LEFT JOIN villes as v ON v.index = e.ref_ville
		LEFT JOIN pays ON pays.index = v.ref_pays 
		LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
		WHERE p.index = $index;";

		$pubhash = request_hash($pubreq,$dbc,"index");

	}

	elsif ( $pub_type eq "In book" ) {

		my $pubreq = "SELECT p.index, tp.en as type, p.titre, p.annee, p.page_debut, p.page_fin, p.nombre_auteurs, b.index as indexlivre, b.titre as titrelivre, b.annee as anneelivre, b.volume as volumelivre, e.nom as edition, v.nom as ville, pays.en as pays, b.nombre_auteurs as nbauteurslivre
		FROM publications as p
		LEFT JOIN publications as b ON (b.index = p.ref_publication_livre)
		LEFT JOIN editions AS e ON e.index = b.ref_edition
		LEFT JOIN villes as v ON v.index = e.ref_ville
		LEFT JOIN pays ON pays.index = v.ref_pays 
		LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
		WHERE p.index = $index;";

		$pubhash = request_hash($pubreq,$dbc,"index");

		my $indexL = $pubhash->{$index}->{'indexlivre'};

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

	elsif ( $pub_type eq "Thesis" ) {

		my $pubreq = "SELECT 	p.index,
		tp.en as type,
		p.titre,
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
	else {
		my $pubreq = "SELECT p.index, tp.en as type, p.titre, p.annee, p.fascicule, p.page_debut, p.page_fin, p.nombre_auteurs, r.nom as revue, p.volume 
		FROM publications as p
		LEFT JOIN revues AS r ON r.index = p.ref_revue
		LEFT JOIN types_publication AS tp ON tp.index = p.ref_type_publication
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
	my ($id,$dbc,$xpage) = @_;
	my $pub = get_pub_params($id,$dbc);
	
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
		$author_str = span({-class=>'pubAuteurs'},join(',&nbsp;',@authors)."&nbsp;&&nbsp;$pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'}&nbsp;$pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}");
	} else {
		$author_str = span({-class=>'pubAuteurs'},"$pub->{$index}->{'auteurs'}->{$nb_authors}->{'nom'}&nbsp;$pub->{$index}->{'auteurs'}->{$nb_authors}->{'prenom'}");
	}
			
	my @strelmt;	
	# Adapt the reference citation according to the type of publication
	if ($type eq "Article") {
		
		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt, "Authors Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt, "$annee - ");} else { push(@strelmt, "&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titre'}) {
			if (substr($titre, -1) ne '.') { $titre .= '.' }
			push(@strelmt, "$titre");
		} else { push(@strelmt, "Title&nbsp;unknown. ");}
		if (my $revue = $pub->{$index}->{'revue'}) { push(@strelmt, i($revue));}
		if (my $vol = $pub->{$index}->{'volume'}) {
			$vol = $vol;
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc)";}
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt, "$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt, "$cards&nbsp;[$xpage].");
				} else {
					push(@strelmt, "$vol&nbsp;[$xpage].");
				}
			} else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt, "$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt, "$cards.");
				} else {
					push(@strelmt, "$vol.");
				}
			}
		}
		else { 
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc):";} else { $vol .= ":";}
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf"; }
					push(@strelmt, "$cards&nbsp;[$xpage].");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf"; }
					push(@strelmt, "$cards.");
				}
			}
		}
	}
	
	elsif ($type eq "Book") {

		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt, "Authors&nbsp;Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt, "$annee&nbsp;- ");} else { push(@strelmt, "&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titre'}) {
			if (substr($titre, -1) ne '.') { $titre .= '.' }
			push(@strelmt, "$titre");
		} else { push(@strelmt, "Title&nbsp;unknown. ");}
		if (my $vol = $pub->{$index}->{'volume'}) { 
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				push(@strelmt, "$vol:"); 
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf&nbsp;pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				}
				push(@strelmt, "$cards");
			} else {
				push(@strelmt, "$vol.");
			}
		} else {
			
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf&nbsp;pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
				}
				push(@strelmt, "$cards");
			}
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				if (substr($edit, -1) eq '.') { $edit = substr($edit,0,-1); }
				$edit .= ",&nbsp;$ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= "&nbsp;($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt, $edit);
		}
		if ($xpage) { push(@strelmt, "[$xpage]"); }
	}

	elsif ($type eq "In book") {

		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt, "Authors&nbsp;Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt, "$annee&nbsp;- ");} else { push(@strelmt, "&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt, "$titre.");} else { push(@strelmt, i("Title&nbsp;unknown."));}
		push(@strelmt,"In:");
				
		my $nb_authors_livre = $pub->{$index}->{'nbauteurslivre'};
		my @authors_livre;
		my $book_author_str;
		if ($nb_authors_livre > 1) {
			my $position = 1;
			while ( $position < $nb_authors_livre ) {
				push(@authors_livre, "$pub->{$index}->{'auteurslivre'}->{$position}->{'nom'}&nbsp;$pub->{$index}->{'auteurslivre'}->{$position}->{'prenom'}");
				$position++;
			}
			$book_author_str = span({-class=>'pubAuteurs'},join(',&nbsp;',@authors_livre)."&nbsp;&&nbsp;$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'}&nbsp;$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}");
		} else {
			$book_author_str = span({-class=>'pubAuteurs'},"$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'nom'}&nbsp;$pub->{$index}->{'auteurslivre'}->{$nb_authors_livre}->{'prenom'}");
		}
		
		if ($book_author_str) { push(@strelmt,$book_author_str);} else { push(@strelmt, "Book&nbsp;Authors&nbsp;Unknown");}
		if (my $annee = $pub->{$index}->{'anneelivre'}) { push(@strelmt, "$annee&nbsp;- ");} else { push(@strelmt,"&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titrelivre'}) { push(@strelmt, i("$titre,"));} else { push(@strelmt,i("Title unknown,"));}
		if (my $vol = $pub->{$index}->{'volumelivre'}) { push(@strelmt,  "$vol.");}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ",&nbsp;$ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= "&nbsp;($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt, $edit);
		}
		if ($xpage) {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				push(@strelmt, "p.&nbsp;$cards&nbsp;[$xpage]");
			}
		}
		else {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				push(@strelmt, "p.&nbsp;$cards");
			}
		}

	}
	
	elsif ($type eq "Thesis") {

		if ($author_str) { push(@strelmt, $author_str );} else { push(@strelmt,"Authors&nbsp;Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt, "$annee&nbsp;- ");} else { push(@strelmt,"&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titre'}) { push(@strelmt, i($titre).".");} else { push(@strelmt, i("Title&nbsp;unknown."));}
		push(@strelmt,"Thesis.");
		if ($xpage) {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf&nbsp;pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				}
				push(@strelmt, "$cards&nbsp;[$xpage]");
			}
		}
		else {
			if (my $cards = $pub->{$index}->{'page_debut'}) {
				if ($cards == 1 or $cards eq 'i' or $cards eq 'I') { 
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards = "$cardf&nbsp;pp.";}
				}
				else {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf.";}
				}
				push(@strelmt, "$cards");
			}
		}
		if (my $edit = $pub->{$index}->{'edition'}) {
			if (my $ville = $pub->{$index}->{'ville'}) { 
				$edit .= ",&nbsp;$ville"; 
				if (my $pays = $pub->{$index}->{'pays'}) {
					$edit .= "&nbsp;($pays)";
				}
			}
			unless (substr($edit,-1) eq ".") { $edit .= ".";}
			push(@strelmt, $edit);
		}
	}
	else {
		
		if ($author_str) { push(@strelmt, b($author_str));} else { push(@strelmt, "Authors&nbsp;Unknown");}
		if (my $annee = $pub->{$index}->{'annee'}) { push(@strelmt, "$annee&nbsp;- ");} else { push(@strelmt, "&nbsp;- ");}
		if (my $titre = $pub->{$index}->{'titre'}) {
			if (substr($titre, -1) ne '.') { $titre .= '.' }
			push(@strelmt, "$titre ");
		} else { push(@strelmt, "Title&nbsp;unknown.");}
		if (my $revue = $pub->{$index}->{'revue'}) { push(@strelmt, i($revue));}
		if (my $vol = $pub->{$index}->{'volume'}) {
			$vol = $vol;
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc)";}
			
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt,"$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards&nbsp;[$xpage].");
				} else {
					push(@strelmt,"$vol&nbsp;[$xpage].");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					push(@strelmt,"$vol:");
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards.");
				} else {
					push(@strelmt,"$vol.");
				}
			}
		}
		else { 
			if (my $fasc = $pub->{$index}->{'fascicule'}) { $vol .= "($fasc):";} else { $vol .= ":";}
			if ($xpage) {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards&nbsp;[$xpage].");
				}
			}
			else {
				if (my $cards = $pub->{$index}->{'page_debut'}) {
					if (my $cardf = $pub->{$index}->{'page_fin'}) { $cards .= "-$cardf";}
					push(@strelmt,"$cards.");
				}
			}
		}
	}
	
	# return the html refrence citation
	return join(' ',@strelmt);
}

sub search_results {
		
	my $dbc = db_connection($config);
	my $sth;
	my $content;
		
	if ($searchid) {
		$id = $searchid;
		if ($searchtable eq 'noms_complets') { 
			
			my $req = "SELECT DISTINCT t.index, nc.orthographe, nc.autorite, s.en, r.en, nc.index, s.index
				FROM taxons AS t 
				LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.en not in ('order', 'suborder', 'super family')
				AND s.en not in ('correct use', 'status revivisco')
				AND (txn.ref_nom = $id)
				ORDER BY nc.orthographe, s.index;";
						
			$sth = $dbc->prepare($req);					
			
			$sth->execute( );
			my ( $taxonid, $name, $autority, $status, $rank, $nameid, $statusid );
			$sth->bind_columns( \( $taxonid, $name, $autority, $status, $rank, $nameid, $statusid ) );
			
			my $nb = $sth->rows;
			
			if ( $nb == 0 and $id) {
				my ($label) = @{request_tab("SELECT orthographe || coalesce(' ' || autorite, '') FROM noms_complets WHERE index = $id;",$dbc,1)};
				$content .= div({-style=>'margin: 50px auto; width: 600px;'},  "$label is in the database, probably found in scientific literature,<BR>but is not yet linked to any taxon, this information will be completed as soon as possible.");
			}
			if ( $nb == 1 ) {
				$sth->fetch();
				if ( $status eq 'valid' ) { $card = $rank; $id = $taxonid; } else { $card = 'name'; }
			} else {
				my %done;
				my $rows = '';
				my $valid;
				while ( $sth->fetch() ){
					my $link = '';
					# If the name is a valid name, links to the taxon
					if ( $status eq 'valid' ){
						$valid = $taxonid;
						$done{$nameid} = 1;
						$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid";
						$rows .= li(a({-href=>$link}, i($name) . "&nbsp; " . $autority . "&nbsp; " . b($status) ));
					}
					# If the name is not valid, links to the name
					elsif (!exists($done{$nameid})) {
						$done{$nameid} = 1;
						$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$nameid";
						$rows .= li(a({-href=>$link}, i($name) . "&nbsp; " . $autority . "&nbsp; " . b($status) ));
					}
			       }
			       
			       #if ($id==10746) { die scalar(keys(%done)); }
			       
			       if ( scalar(keys(%done)) == 1){
			       	       if ($valid) { $card = $rank; $id = $valid || $taxonid; }
			       	       else { $card = 'name'; ($id) = keys(%done); }
			       }
			       else {
				       $content .= !$content ? div({-class=>'titre'},  scalar(keys(%done))." $trans->{'match_names'}->{$lang}") : '';
				       $content .= start_ul({});
				       $content .= $rows;
				       $content .= end_ul();
			       }
			       $sth->finish();
			}
		}
		elsif ($searchtable eq 'auteurs') { $card = 'author' }
		elsif ($searchtable eq 'publications') { $card = 'publication' }
		elsif ($searchtable eq 'pays') { $card = 'country' }
		elsif ($searchtable eq 'taxons_associes') { $card = 'associate' }
		elsif ($searchtable eq 'noms_vernaculaires') { $card = 'vernacular' }
		
		if ($content) {
			print 	div({-class=>'content'},
				$totop,
				$content
			);
		}
		else {
			$states{$card}->();
		}
	}
	elsif ($search) {
		
		my $query = $search;
		$query =~ s/\*/.*/g;
		$query =~ s/'/\\'/g;
		$query =~ s/\(/\\\\(/g;
		$query =~ s/\)/\\\\)/g;
				
		$query = ".*$query.*";

		my $req;
		my $nbresults;
		my ( $taxonid, $name, $autority, $status, $rank, $nameid, $xcard, $xlabel, $xid, $publist );
		if ($searchtable eq 'auteurs') {
			$req = "SELECT index, coalesce(nom || ' ', '') || coalesce(prenom, '') AS auteur from auteurs WHERE coalesce(nom || ' ', '') || coalesce(prenom, '') ~* '^$query\$';";
			$xcard = 'author';
			$sth = $dbc->prepare($req);					
			$sth->execute( );
			$sth->bind_columns( \( $xid, $xlabel ) );
			$nbresults = $sth->rows;
		}
		elsif ($searchtable eq 'pays') {
			$req = "SELECT index, $lang from pays WHERE index in (SELECT DISTINCT ref_pays FROM taxons_x_pays) AND $lang ~* '^$query\$';";
			$xcard = 'country';
			$sth = $dbc->prepare($req);					
			$sth->execute( );
			$sth->bind_columns( \( $xid, $xlabel ) );
			$nbresults = $sth->rows;
		}
		elsif ($searchtable eq 'taxons_associes') {
			$req = "SELECT index, get_taxon_associe_full_name(index) AS fullname FROM taxons_associes WHERE index in (SELECT DISTINCT ref_taxon_associe FROM taxons_x_taxons_associes) AND get_taxon_associe_full_name(index) ~* '^$query\$' ORDER BY fullname;";
			$xcard = 'associate';
			$sth = $dbc->prepare($req);					
			$sth->execute( );
			$sth->bind_columns( \( $xid, $xlabel ) );
			$nbresults = $sth->rows;
		}
		elsif ($searchtable eq 'noms_vernaculaires') {
			$req = "SELECT index, nom FROM noms_vernaculaires where nom ~* '^$query\$' ORDER BY nom;";
			$xcard = 'vernacular';
			$sth = $dbc->prepare($req);					
			$sth->execute( );
			$sth->bind_columns( \( $xid, $xlabel ) );
			$nbresults = $sth->rows;
		}
		if ($searchtable eq 'noms_complets') {
			
			my $query2;
			
			$query2 = ".*$query.*";
			$query2 = $query2.'†';

			$query =~ s/^\s*/\^/;
			$query =~ s/\s*$/\$/;
			$query2 =~ s/^\s*/\^/;
			$query2 =~ s/\s*$/\$/;
						
			$dbc->{RaiseError} = 1;
									
			$req = "SELECT DISTINCT t.index, nc.orthographe, nc.autorite, s.en, r.en, nc.index
				FROM taxons AS t LEFT JOIN taxons_x_noms AS txn ON t.index = txn.ref_taxon
				LEFT JOIN noms_complets AS nc ON txn.ref_nom = nc.index
				LEFT JOIN statuts AS s ON txn.ref_statut = s.index
				LEFT JOIN rangs AS r ON t.ref_rang = r.index
				WHERE r.en in ('family', 'genus', 'subgenus', 'species', 'subspecies')
				AND s.en not in ('correct use')
				AND nc.orthographe ~* '$query'
				OR nc.orthographe ~* '$query2'
				ORDER BY nc.orthographe;";
				
			$sth = $dbc->prepare($req);					
			$sth->execute( );
			$sth->bind_columns( \( $taxonid, $name, $autority, $status, $rank, $nameid ) );
			$nbresults = $sth->rows;
		}
		elsif ($searchtable eq 'publications') {
			my $pubids = request_tab("SELECT index from publications;", $dbc, 1);
			$xcard = 'publication';
			$nbresults = 0;
			$query = "<b><span class='pubAuteurs'>$query";
			foreach (@{$pubids}) {
				my $str = pub_formating($_, $dbc);
				if ($str =~ m/^$query$/i) {
					$publist .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$xcard&id=".$_}, $str));
					$xid = $_;
					$nbresults++;
				}
			}
		}					
				
		if ( $nbresults ){
			if ( $nbresults > 1 ){
				$content .= div({-class=>'titre'},  "$nbresults $trans->{'match_names'}->{$lang}");
				$content .= start_ul({});
				
				if ($searchtable eq 'noms_complets') {
					while ( $sth->fetch() ){
						my $link = '';
						# If the name is a valid name, links to the taxon
						if ( $status eq 'valid' ){
							$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=taxon&rank=$rank&id=$taxonid"
						}
						# If the name is not valid, links to the name
						else {
							$link = "$scripts{$dbase}db=$dbase&lang=$lang&card=name&id=$nameid"
						}
						$content .= li(a({-href=>$link}, i($name) . "&nbsp; " . $autority . "&nbsp; " . b($status) ));
					}
				}
				elsif ($searchtable eq 'publications') {
					$content .= $publist;
				}
				else {
					while ( $sth->fetch() ){
						$content .= li(a({-href=>"$scripts{$dbase}db=$dbase&lang=$lang&card=$xcard&id=$xid"}, $xlabel));
					}
				}

				if ($sth) { $sth->finish(); }
				$content .= end_ul();
			}
			else {
				if ($sth) { $sth->fetch(); }
				if ($searchtable eq 'noms_complets') {
					if ( $status eq 'valid' ){
						$card = 'taxon';
						$id = $taxonid;
					}
					else {
						$card='name'; $id=$nameid;
					}
				}
				else {
					$card=$xcard; $id=$xid;
				}
				if ($sth) { $sth->finish(); }
			}
	       }
		else {
			$content .= 	div({-style=>'margin: 50px 0 0 200px;'},  $trans->{'noresults'}->{$lang} );
	       }
	       
	       if($nbresults != 1) {
			$fullhtml =  	div({-class=>'content'},
						$totop,
						$content
					);
			
			print $fullhtml;
	       }
	       else {
		       $states{$card}->();
	       }
	}
	else { 
		$fullhtml =  	div({-class=>'content'}, 
					$totop,
					span({-class=>'subject'},  $trans->{'noresults'}->{$lang} . " no searchstring given")
				);
		print $fullhtml;
	}
}
